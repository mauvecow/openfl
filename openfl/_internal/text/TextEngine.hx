package openfl._internal.text;


import haxe.Timer;
import haxe.Utf8;
import lime.graphics.cairo.CairoFont;
import lime.graphics.opengl.GLTexture;
import lime.system.System;
import lime.text.TextLayout;
import openfl.display.Tilesheet;
import openfl.events.Event;
import openfl.events.FocusEvent;
import openfl.events.MouseEvent;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.text.AntiAliasType;
import openfl.text.Font;
import openfl.text.GridFitType;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFieldType;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;

#if (js && html5)
import js.html.CanvasElement;
import js.html.CanvasRenderingContext2D;
import js.html.CSSStyleDeclaration;
import js.html.InputElement;
import js.html.KeyboardEvent in HTMLKeyboardEvent;
import js.Browser;
#end

#if sys
import haxe.io.Path;
#end

@:access(openfl.text.Font)
@:access(openfl.text.TextField)
@:access(openfl.text.TextFormat)


class TextEngine {
	
	
	private static inline var UTF8_TAB = 9;
	private static inline var UTF8_ENDLINE = 10;
	private static inline var UTF8_SPACE = 32;
	private static inline var UTF8_HYPHEN = 0x2D;
	
	private static var __defaultFonts = new Map<String, Font> ();
	
	#if (js && html5)
	private static var __canvas:CanvasElement;
	private static var __context:CanvasRenderingContext2D;
	#end
	
	public var antiAliasType:AntiAliasType;
	public var autoSize:TextFieldAutoSize;
	public var background:Bool;
	public var backgroundColor:Int;
	public var border:Bool;
	public var borderColor:Int;
	public var bottomScrollV (default, null):Int;
	public var bounds:Rectangle;
	public var caretIndex:Int;
	public var displayAsPassword:Bool;
	public var embedFonts:Bool;
	public var gridFitType:GridFitType;
	public var height:Float;
	public var layoutGroups:Array<TextLayoutGroup>;
	public var lineAscents:Array<Float>;
	public var lineBreaks:Array<Int>;
	public var lineDescents:Array<Float>;
	public var lineLeadings:Array<Float>;
	public var lineHeights:Array<Float>;
	public var lineWidths:Array<Float>;
	public var maxChars:Int;
	public var maxScrollH (default, null):Int;
	public var maxScrollV (default, null):Int;
	public var multiline:Bool;
	public var numLines (default, null):Int;
	public var restrict:String;
	public var scrollH:Int;
	public var scrollV:Int;
	public var selectable:Bool;
	public var sharpness:Float;
	public var text:String;
	public var textHeight:Float;
	public var textFormatRanges:Array<TextFormatRange>;
	public var textWidth:Float;
	public var type:TextFieldType;
	public var width:Float;
	public var wordWrap:Bool;
	
	private var textField:TextField;
	
	@:noCompletion private var __cursorPosition:Int;
	@:noCompletion private var __cursorTimer:Timer;
	@:noCompletion private var __hasFocus:Bool;
	@:noCompletion private var __isKeyDown:Bool;
	@:noCompletion private var __measuredHeight:Int;
	@:noCompletion private var __measuredWidth:Int;
	@:noCompletion private var __selectionStart:Int;
	@:noCompletion private var __showCursor:Bool;
	@:noCompletion private var __textFormat:TextFormat;
	@:noCompletion private var __textLayout:TextLayout;
	@:noCompletion private var __texture:GLTexture;
	@:noCompletion private var __tileData:Map<Tilesheet, Array<Float>>;
	@:noCompletion private var __tileDataLength:Map<Tilesheet, Int>;
	@:noCompletion private var __tilesheets:Map<Tilesheet, Bool>;
	@:noCompletion public var __cairoFont:CairoFont;
	
	#if (js && html5)
	private var __hiddenInput:InputElement;
	#end
	
	
	public function new (textField:TextField) {
		
		this.textField = textField;
		
		width = 100;
		height = 100;
		text = "";
		
		bounds = new Rectangle (0, 0, 0, 0);
		
		type = TextFieldType.DYNAMIC;
		autoSize = TextFieldAutoSize.NONE;
		displayAsPassword = false;
		embedFonts = false;
		selectable = true;
		borderColor = 0x000000;
		border = false;
		backgroundColor = 0xffffff;
		background = false;
		gridFitType = GridFitType.PIXEL;
		maxChars = 0;
		multiline = false;
		sharpness = 0;
		scrollH = 0;
		scrollV = 1;
		wordWrap = false;
		
		lineAscents = new Array ();
		lineBreaks = new Array ();
		lineDescents = new Array ();
		lineLeadings = new Array ();
		lineHeights = new Array ();
		lineWidths = new Array ();
		layoutGroups = new Array ();
		textFormatRanges = new Array ();
		
		#if (js && html5)
		__canvas = cast Browser.document.createElement ("canvas");
		__context = __canvas.getContext ("2d");
		#end
		
	}
	
	
	private static function findFont (name:String):Font {
		
		#if (cpp || neko || nodejs)
		
		for (registeredFont in Font.__registeredFonts) {
			
			if (registeredFont == null) continue;
			
			if (registeredFont.fontName == name || (registeredFont.__fontPath != null && (registeredFont.__fontPath == name || Path.withoutDirectory (registeredFont.__fontPath) == name))) {
				
				return registeredFont;
				
			}
			
		}
		
		var font = Font.fromFile (name);
		
		if (font != null) {
			
			Font.__registeredFonts.push (font);
			return font;
			
		}
		
		#end
		
		return null;
		
	}
	
	
	public static function getFont (format:TextFormat):String {
		
		var font = format.italic ? "italic " : "normal ";
		font += "normal ";
		font += format.bold ? "bold " : "normal ";
		font += format.size + "px";
		font += "/" + (format.size + format.leading + 6) + "px ";
		
		font += "" + switch (format.font) {
			
			case "_sans": "sans-serif";
			case "_serif": "serif";
			case "_typewriter": "monospace";
			default: "'" + format.font + "'";
			
		}
		
		return font;
		
	}
	
	
	public static function getFontInstance (format:TextFormat):Font {
		
		#if (cpp || neko || nodejs)
		
		var instance = null;
		var fontList = null;
		
		if (format != null && format.font != null) {
			
			if (__defaultFonts.exists (format.font)) {
				
				return __defaultFonts.get (format.font);
				
			}
			
			instance = findFont (format.font);
			if (instance != null) return instance;
			
			var systemFontDirectory = System.fontsDirectory;
			
			switch (format.font) {
				
				case "_sans":
					
					#if windows
					if (format.bold) {
						
						if (format.italic) {
							
							fontList = [ systemFontDirectory + "/arialbi.ttf" ];
							
						} else {
							
							fontList = [ systemFontDirectory + "/arialbd.ttf" ];
							
						}
						
					} else {
						
						if (format.italic) {
							
							fontList = [ systemFontDirectory + "/ariali.ttf" ];
							
						} else {
							
							fontList = [ systemFontDirectory + "/arial.ttf" ];
							
						}
						
					}
					#elseif (mac || ios)
					fontList = [ systemFontDirectory + "/Arial Black.ttf", systemFontDirectory + "/Arial.ttf", systemFontDirectory + "/Helvetica.ttf" ];
					#elseif linux
					fontList = [ new sys.io.Process('fc-match', ['sans', '-f%{file}']).stdout.readLine() ];
					#elseif android
					fontList = [ systemFontDirectory + "/DroidSans.ttf" ];
					#elseif blackberry
					fontList = [ systemFontDirectory + "/arial.ttf" ];
					#end
				
				case "_serif":
					
					// pass through
				
				case "_typewriter":
					
					#if windows
					if (format.bold) {
						
						if (format.italic) {
							
							fontList = [ systemFontDirectory + "/courbi.ttf" ];
							
						} else {
							
							fontList = [ systemFontDirectory + "/courbd.ttf" ];
							
						}
						
					} else {
						
						if (format.italic) {
							
							fontList = [ systemFontDirectory + "/couri.ttf" ];
							
						} else {
							
							fontList = [ systemFontDirectory + "/cour.ttf" ];
							
						}
						
					}
					#elseif (mac || ios)
					fontList = [ systemFontDirectory + "/Courier New.ttf", systemFontDirectory + "/Courier.ttf" ];
					#elseif linux
					fontList = [ new sys.io.Process('fc-match', ['mono', '-f%{file}']).stdout.readLine() ];
					#elseif android
					fontList = [ systemFontDirectory + "/DroidSansMono.ttf" ];
					#elseif blackberry
					fontList = [ systemFontDirectory + "/cour.ttf" ];
					#end
				
				default:
					
					fontList = [ systemFontDirectory + "/" + format.font ];
				
			}
			
			if (fontList != null) {
				
				for (font in fontList) {
					
					instance = findFont (font);
					
					if (instance != null) {
						
						__defaultFonts.set (format.font, instance);
						return instance;
						
					}
					
				}
				
			}
			
			instance = findFont ("_serif");
			if (instance != null) return instance;
			
		}
		
		var systemFontDirectory = System.fontsDirectory;
		
		#if windows
		if (format.bold) {
			
			if (format.italic) {
				
				fontList = [ systemFontDirectory + "/timesbi.ttf" ];
				
			} else {
				
				fontList = [ systemFontDirectory + "/timesb.ttf" ];
				
			}
			
		} else {
			
			if (format.italic) {
				
				fontList = [ systemFontDirectory + "/timesi.ttf" ];
				
			} else {
				
				fontList = [ systemFontDirectory + "/times.ttf" ];
				
			}
			
		}
		#elseif (mac || ios)
		fontList = [ systemFontDirectory + "/Georgia.ttf", systemFontDirectory + "/Times.ttf", systemFontDirectory + "/Times New Roman.ttf" ];
		#elseif linux
		fontList = [ new sys.io.Process('fc-match', ['serif', '-f%{file}']).stdout.readLine() ];
		#elseif android
		fontList = [ systemFontDirectory + "/DroidSerif-Regular.ttf", systemFontDirectory + "NotoSerif-Regular.ttf" ];
		#elseif blackberry
		fontList = [ systemFontDirectory + "/georgia.ttf" ];
		#else
		fontList = [];
		#end
		
		for (font in fontList) {
			
			instance = findFont (font);
			
			if (instance != null) {
				
				__defaultFonts.set (format.font, instance);
				return instance;
				
			}
			
		}
		
		__defaultFonts.set (format.font, null);
		
		#end
		
		return null;
		
	}
	
	
	public function getLine (index:Int):String {
		
		if (index < 0 || index > lineBreaks.length + 1) {
			
			return null;
			
		}
		
		if (lineBreaks.length == 0) {
			
			return text;
			
		} else {
			
			return text.substring (index > 0 ? lineBreaks[index - 1] : 0, lineBreaks[index]);
			
		}
		
	}
	
	
	private function getLineMeasurements ():Void {
		
		lineAscents.splice (0, lineAscents.length);
		lineDescents.splice (0, lineDescents.length);
		lineLeadings.splice (0, lineLeadings.length);
		lineHeights.splice (0, lineHeights.length);
		lineWidths.splice (0, lineWidths.length);
		
		var currentLineAscent = 0.0;
		var currentLineDescent = 0.0;
		var currentLineLeading = 0.0;
		var currentLineHeight = 0.0;
		var currentLineWidth = 0.0;
		
		textWidth = 0;
		textHeight = 0;
		numLines = 1;
		bottomScrollV = 0;
		maxScrollH = 0;
		
		for (group in layoutGroups) {
			
			while (group.lineIndex > numLines - 1) {
				
				lineAscents.push (currentLineAscent);
				lineDescents.push (currentLineDescent);
				lineLeadings.push (currentLineLeading);
				lineHeights.push (currentLineHeight);
				lineWidths.push (currentLineWidth);
				
				currentLineAscent = 0;
				currentLineDescent = 0;
				currentLineLeading = 0;
				currentLineHeight = 0;
				currentLineWidth = 0;
				
				numLines++;
				
				if (textHeight <= height - 2) {
					
					bottomScrollV++;
					
				}
				
			}
			
			currentLineAscent = Math.max (currentLineAscent, group.ascent);
			currentLineDescent = Math.max (currentLineDescent, group.descent);
			currentLineLeading = Math.max (currentLineLeading, group.leading);
			currentLineHeight = Math.max (currentLineHeight, group.height);
			currentLineWidth += group.width;
			
			if (currentLineWidth > textWidth) {
				
				textWidth = currentLineWidth;
				
			}
			
			textHeight = group.offsetY + group.ascent + group.descent;
			
		}
		
		lineAscents.push (currentLineAscent);
		lineDescents.push (currentLineDescent);
		lineLeadings.push (currentLineLeading);
		lineHeights.push (currentLineHeight);
		lineWidths.push (currentLineWidth);
		
		if (textHeight <= height - 2) {
			
			bottomScrollV++;
			
		}
		
		if (textWidth > width - 4) {
			
			maxScrollH = Std.int (textWidth - width + 4);
			
		} else {
			
			maxScrollH = 0;
			
		}
		
		maxScrollV = numLines;
		
	}
	
	
	private function getLayoutGroups ():Void {
		
		layoutGroups.splice (0, layoutGroups.length);
		
		var rangeIndex = -1;
		var formatRange:TextFormatRange = null;
		var font = null;
		
		var ascent, descent, leading, layoutGroup;
		var advances, widthValue, heightValue;
		
		var spaceWidth = 0.0;
		var previousSpaceIndex = 0;
		var spaceIndex = text.indexOf (" ");
		var breakIndex = text.indexOf ("\n");
		
		var marginRight = 0.0;
		var offsetX = 2.0;
		var offsetY = 2.0;
		var textIndex = 0;
		var lineIndex = 0;
		
		var getAdvances = function (text:String, startIndex:Int, endIndex:Int):Array<Float> {
			
			// TODO: optimize
			
			var advances = [];
			
			#if (js && html5)
			
			for (i in startIndex...endIndex) {
				
				advances.push (__context.measureText (text.charAt (i)).width);
				
			}
			
			#else
			
			if (__textLayout == null) {
				
				__textLayout = new TextLayout ();
				
			}
			
			var width = 0.0;
			
			__textLayout.text = null;
			__textLayout.font = font;
			__textLayout.size = formatRange.format.size;
			__textLayout.text = text.substring (startIndex, endIndex);
			
			for (position in __textLayout.positions) {
				
				advances.push (position.advance.x);
				
			}
			
			#end
			
			return advances;
			
		}
		
		var getAdvancesWidth = function (advances:Array<Float>):Float {
			
			var width = 0.0;
			
			for (advance in advances) {
				
				width += advance;
				
			}
			
			return width;
			
		}
		
		var getTextWidth = function (text:String):Float {
			
			#if (js && html5)
			
			return __context.measureText (text).width;
			
			#else
			
			if (__textLayout == null) {
				
				__textLayout = new TextLayout ();
				
			}
			
			var width = 0.0;
			
			__textLayout.text = null;
			__textLayout.font = font;
			__textLayout.size = formatRange.format.size;
			__textLayout.text = text;
			
			for (position in __textLayout.positions) {
				
				width += position.advance.x;
				
			}
			
			return width;
			
			#end
			
		}
		
		var nextFormatRange = function ():Void {
			
			if (rangeIndex < textFormatRanges.length - 1) {
				
				rangeIndex++;
				formatRange = textFormatRanges[rangeIndex];
				
				#if (js && html5)
				
				__context.font = getFont (formatRange.format);
				
				ascent = formatRange.format.size * 0.8;
				descent = formatRange.format.size * 0.2;
				leading = formatRange.format.leading;
				heightValue = Std.int (ascent + descent + leading);
				
				#elseif (cpp || neko || nodejs)
				
				font = getFontInstance (formatRange.format);
				
				ascent = (font.ascender / font.unitsPerEM) * formatRange.format.size;
				descent = Math.abs ((font.descender / font.unitsPerEM) * formatRange.format.size);
				leading = formatRange.format.leading;
				
				//TODO: Why is this necessary?
				
				if (formatRange.format != null && __defaultFonts.exists (formatRange.format.font) && formatRange.format.size == 12) {
					
					ascent += 2;
					offsetY -= 1;
					
				}
				
				heightValue = Std.int (ascent + descent + leading);
				
				#end
				
				if (spaceIndex > -1) {
					
					spaceWidth = getTextWidth (" ");
					
				}
				
			}
			
		}
		
		nextFormatRange ();
		
		var wrap;
		
		while (textIndex < text.length) {
			
			if ((breakIndex > -1) && (spaceIndex == -1 || breakIndex < spaceIndex) && (formatRange.end >= breakIndex)) {
				
				layoutGroup = new TextLayoutGroup (formatRange.format, textIndex, breakIndex);
				layoutGroup.advances = getAdvances (text, textIndex, breakIndex);
				layoutGroup.offsetX = offsetX;
				layoutGroup.ascent = ascent;
				layoutGroup.descent = descent;
				layoutGroup.leading = leading;
				layoutGroup.lineIndex = lineIndex;
				layoutGroup.offsetY = offsetY;
				layoutGroup.width = getAdvancesWidth (layoutGroup.advances);
				layoutGroup.height = heightValue;
				layoutGroups.push (layoutGroup);
				
				// TODO: Why is this different (or necessary?)
				
				#if (cpp || neko || nodejs)
				offsetY += heightValue;
				#else
				offsetY += heightValue + 4;
				#end
				
				offsetX = 2;
				
				if (wordWrap && (layoutGroup.offsetX + layoutGroup.width > width - 4)) {
					
					layoutGroup.offsetY = offsetY;
					layoutGroup.offsetX = offsetX;
					
					// TODO: Why is this different (or necessary?)
					
					#if (cpp || neko || nodejs)
					offsetY += heightValue;
					#else
					offsetY += heightValue + 4;
					#end
					
					lineIndex++;
					
				}
				
				textIndex = breakIndex + 1;
				breakIndex = text.indexOf ("\n", textIndex);
				lineIndex++;
				
				if (formatRange.end == breakIndex) {
					
					nextFormatRange ();
					
				}
				
			} else if (formatRange.end >= spaceIndex) {
				
				layoutGroup = null;
				wrap = false;
				
				while (true) {
					
					if (spaceIndex == -1) spaceIndex = formatRange.end;
					
					advances = getAdvances (text, textIndex, spaceIndex);
					widthValue = getAdvancesWidth (advances);
					
					if (wordWrap) {
						
						if (offsetX + widthValue > width - 4) {
							
							wrap = true;
							
						}
						
					}
					
					if (wrap) {
						
						// TODO: Why is this different (or necessary?)
						
						#if (cpp || neko || nodejs)
						offsetY += heightValue;
						#else
						offsetY += heightValue + 4;
						#end
						
						var i = layoutGroups.length - 1;
						var offsetCount = 0;
						
						while (true) {
							
							layoutGroup = layoutGroups[i];
							
							if (i > 0 && layoutGroup.startIndex > previousSpaceIndex) {
								
								offsetCount++;
								
							} else {
								
								break;
								
							}
							
							i--;
							
						}
						
						lineIndex++;
						
						offsetX = 2;
						
						if (offsetCount > 0) {
							
							var bumpX = layoutGroups[layoutGroups.length - offsetCount].offsetX;
							
							for (i in (layoutGroups.length - offsetCount)...layoutGroups.length) {
								
								layoutGroup = layoutGroups[i];
								layoutGroup.offsetX -= bumpX;
								layoutGroup.offsetY = offsetY;
								layoutGroup.lineIndex = lineIndex;
								offsetX += layoutGroup.width;
								
							}
							
						}
						
						layoutGroup = new TextLayoutGroup (formatRange.format, textIndex, spaceIndex);
						layoutGroup.advances = advances;
						layoutGroup.offsetX = offsetX;
						layoutGroup.ascent = ascent;
						layoutGroup.descent = descent;
						layoutGroup.leading = leading;
						layoutGroup.lineIndex = lineIndex;
						layoutGroup.offsetY = offsetY;
						layoutGroup.width = widthValue;
						layoutGroup.height = heightValue;
						layoutGroups.push (layoutGroup);
						
						offsetX += widthValue + spaceWidth;
						marginRight = spaceWidth;
						
						wrap = false;
						
					} else {
						
						if (layoutGroup == null) {
							
							layoutGroup = new TextLayoutGroup (formatRange.format, textIndex, spaceIndex);
							layoutGroup.advances = advances;
							layoutGroup.offsetX = offsetX;
							layoutGroup.ascent = ascent;
							layoutGroup.descent = descent;
							layoutGroup.leading = leading;
							layoutGroup.lineIndex = lineIndex;
							layoutGroup.offsetY = offsetY;
							layoutGroup.width = widthValue;
							layoutGroup.height = heightValue;
							layoutGroups.push (layoutGroup);
							
							marginRight = spaceWidth;
							
						} else {
							
							layoutGroup.endIndex = spaceIndex;
							
							if (textIndex == spaceIndex) {
								
								marginRight += spaceWidth;
								
							} else {
								
								layoutGroup.advances.push (spaceWidth);
								layoutGroup.advances = layoutGroup.advances.concat (advances);
								layoutGroup.width += marginRight + widthValue;
								marginRight = spaceWidth;
								
							}
							
						}
						
						offsetX += widthValue + spaceWidth;
						
					}
					
					textIndex = spaceIndex + 1;
					
					previousSpaceIndex = spaceIndex;
					spaceIndex = text.indexOf (" ", previousSpaceIndex + 1);
					
					if (formatRange.end <= previousSpaceIndex) {
						
						nextFormatRange ();
						
					}
					
					if ((spaceIndex > breakIndex && breakIndex > -1) || textIndex > text.length || spaceIndex > formatRange.end || (spaceIndex == -1 && breakIndex > -1)) {
						
						break;
						
					}
					
				}
				
			} else {
				
				layoutGroup = new TextLayoutGroup (formatRange.format, textIndex, formatRange.end);
				layoutGroup.advances = getAdvances (text, textIndex, formatRange.end);
				layoutGroup.offsetX = offsetX;
				layoutGroup.ascent = ascent;
				layoutGroup.descent = descent;
				layoutGroup.leading = leading;
				layoutGroup.lineIndex = lineIndex;
				layoutGroup.offsetY = offsetY;
				layoutGroup.width = getAdvancesWidth (layoutGroup.advances);
				layoutGroup.height = heightValue;
				layoutGroups.push (layoutGroup);
				
				offsetX += layoutGroup.width;
				
				textIndex = formatRange.end + 1;
				
				nextFormatRange ();
				
			}
			
		}
		
		lineIndex = 0;
		offsetX = 0;
		
	}
	
	
	private function setTextAlignment ():Void {
		
		var lineIndex = -1;
		var offsetX = 0.0;
		
		for (group in layoutGroups) {
			
			if (group.lineIndex != lineIndex) {
				
				lineIndex = group.lineIndex;
				
				switch (group.format.align) {
					
					case CENTER:
						
						if (lineWidths[lineIndex] < width - 4) {
							
							offsetX = Math.round ((width - 4 - lineWidths[lineIndex]) / 2);
							
						} else {
							
							offsetX = 0;
							
						}
					
					case RIGHT:
						
						if (lineWidths[lineIndex] < width) {
							
							offsetX = Math.round (width - 4 - lineWidths[lineIndex]);
							
						} else {
							
							offsetX = 0;
							
						}
					
					default:
						
						offsetX = 0;
					
				}
				
			}
			
			if (offsetX > 0) {
				
				group.offsetX += offsetX;
				
			}
			
		}
		
	}
	
	
	private function update ():Void {
		
		if (text == null || StringTools.trim (text) == "" || textFormatRanges.length == 0) {
			
			lineAscents.splice (0, lineAscents.length);
			lineBreaks.splice (0, lineBreaks.length);
			lineDescents.splice (0, lineDescents.length);
			lineLeadings.splice (0, lineLeadings.length);
			lineHeights.splice (0, lineHeights.length);
			lineWidths.splice (0, lineWidths.length);
			layoutGroups.splice (0, layoutGroups.length);
			
			textWidth = 0;
			textHeight = 0;
			numLines = 1;
			maxScrollH = 0;
			maxScrollV = 1;
			
		} else {
			
			getLayoutGroups ();
			getLineMeasurements ();
			setTextAlignment ();
			
		}
		
		if (autoSize != TextFieldAutoSize.NONE) {
			
			bounds.width = (textWidth + 4) + (border ? 1 : 0);
			bounds.height = (textHeight + 4) + (border ? 1 : 0);
			
		} else {
			
			bounds.width = width;
			bounds.height = height;
			
		}
		
	}
	
	
}