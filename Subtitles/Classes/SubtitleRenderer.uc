class SubtitleRenderer expands HUDOverlay
	config(Subtitles);

#exec OBJ LOAD FILE="UWindowFonts.utx"

var int RefCount;

var private bool bDrawText, bInitializedSubtitle;
var private string SubtitleText;
var private array<string> TextLines;
var private int TextLinesNum;
var private string FontName;
var private float ScreenWidth, ScreenHeight, BoxWidth;
var private bool bSupportsCanvasScale;
var private float CustomFontScale, FontScale;
var private Font Font;
var private Canvas Canvas;

event PostBeginPlay()
{
	bSupportsCanvasScale = DynamicLoadObject("Engine.Canvas.ScaleFactor", class'Object', true) != none;
	InitFont();
}

event PostRender(Canvas Canvas)
{
	if (!class'Subtitles'.default.bShowSubtitles)
		return;

	self.Canvas = Canvas;

	if (bDrawText)
	{
		InitSubtitle();
		DrawSubtitle();
	}
}

function InitFont()
{
	local int DesiredFontSize;
	local float DesiredFontScale;

	if (class'Subtitles'.default.Font == "" ||
		class'Subtitles'.default.Font ~= "Tahoma" ||
		class'Subtitles'.default.Font ~= "UWindowFonts.Tahoma")
	{
		if (ScreenHeight == 0)
			return;
		DesiredFontSize = GetAutoFontSize();
		DesiredFontScale = float(DesiredFontSize) / LoadNearestTahomaFont(DesiredFontSize);
		if (DesiredFontSize >= 24 && bSupportsCanvasScale && CustomFontScale == 0)
			FontScale = DesiredFontScale;
	}
	else if (class'Subtitles'.default.Font ~= "WhiteFont" ||
		class'Subtitles'.default.Font ~= "UnrealI.WhiteFont" ||
		class'Subtitles'.default.Font ~= "UnrealShare.WhiteFont")
	{
		if (ScreenHeight == 0)
			return;
		Font = Font'UnrealShare.WhiteFont';
		if (bSupportsCanvasScale && class'Subtitles'.default.FontScale == 0)
			FontScale = FMax(1.0, 2.0 * ScreenHeight / 1080);
	}
	else
		Font = Font(DynamicLoadObject(class'Subtitles'.default.Font, class'Font', true));

	if (Font == none && ScreenHeight > 0)
	{
		DesiredFontSize = GetAutoFontSize();
		DesiredFontScale = float(DesiredFontSize) / LoadNearestTahomaFont(DesiredFontSize);
		if (DesiredFontSize >= 24 && bSupportsCanvasScale && CustomFontScale == 0)
			FontScale = DesiredFontScale;
	}

	FontName = class'Subtitles'.default.Font;

	bInitializedSubtitle = false;
}

function int LoadNearestTahomaFont(int FontSize)
{
	local int i;

	i = 24;
	if (FontSize >= i && LoadTahomaFont(i))
		return i;
	i = 20;
	if (FontSize >= i && LoadTahomaFont(i))
		return i;
	i = 18;
	if (FontSize >= i && LoadTahomaFont(i))
		return i;
	i = 16;
	if (FontSize >= i && LoadTahomaFont(i))
		return i;
	i = 15;
	if (FontSize >= i && LoadTahomaFont(i))
		return i;
	i = 14;
	if (FontSize >= i && LoadTahomaFont(i))
		return i;
	i = 13;
	if (FontSize >= i && LoadTahomaFont(i))
		return i;
	i = 12;
	if (FontSize >= i && LoadTahomaFont(i))
		return i;
	i = 11;
	if (FontSize >= i && LoadTahomaFont(i))
		return i;

	Font = Font'UWindowFonts.Tahoma10';
	return 10;
}

function bool LoadTahomaFont(int FontSize)
{
	Font = Font(DynamicLoadObject("UWindowFonts.Tahoma" $ FontSize, class'Font', true));
	return Font != none;
}

function InitSubtitle()
{
	local bool bRefresh;

	if (CustomFontScale != class'Subtitles'.default.FontScale)
	{
		CustomFontScale = class'Subtitles'.default.FontScale;

		if (bSupportsCanvasScale)
			FontScale = FClamp(CustomFontScale, 1.0, 16.0);
		else
			FontScale = 1.0;

		bRefresh = true;
	}
	else if (FontScale < 1)
		FontScale = 1;

	if (ScreenWidth != Canvas.SizeX || ScreenHeight != Canvas.SizeY)
	{
		ScreenWidth = Canvas.SizeX;
		ScreenHeight = Canvas.SizeY;
		BoxWidth = FMin(ScreenWidth, ScreenHeight * 4 / 3);
		bRefresh = true;
	}

	if (Font == none || FontName != class'Subtitles'.default.Font || bRefresh)
		InitFont();

	if (bRefresh || !bInitializedSubtitle)
	{
		SplitSubtitleText(SubtitleText);
		bInitializedSubtitle = true;
	}
}

function int GetAutoFontSize()
{
	return ScreenHeight / 54;
}

function SetSubtitle(string Text)
{
	bDrawText = Len(Text) > 0;
	bInitializedSubtitle = false;
	if (bDrawText)
		SubtitleText = NormalizeSubtitleText(Text);
}

function string NormalizeSubtitleText(string Text)
{
	local int CodeStart, CodeEnd;
	local int CharCode;
	local string NormalizedText;

	Text = ReplaceStr(Text, "[br]", Chr(10), true);

	while (Len(Text) > 0)
	{
		CodeStart = InStr(Text, "&#");
		if (CodeStart >= 0)
		{
			CodeEnd = InStr(Mid(Text, CodeStart + 2), ";");
			if (CodeEnd >= 0)
			{
				CharCode = int(Mid(Text, CodeStart + 2, CodeEnd));
				if (CharCode > 0)
				{
					NormalizedText $= Left(Text, CodeStart) $ Chr(CharCode);
					Text = Mid(Text, CodeStart + CodeEnd + 3);
					continue;
				}
			}
		}
		break;
	}
	NormalizedText $= Text;
	return NormalizedText;
}

function SplitSubtitleText(string Text)
{
	local int i;
	local string LineBreak;

	TextLinesNum = 0;
	LineBreak = Chr(10);
	Canvas.Font = Font;

	while (Len(Text) > 0)
	{
		i = InStr(Text, LineBreak);
		if (i < 0)
		{
			AddTextLine(Text);
			break;
		}
		AddTextLine(Left(Text, i));
		Text = Mid(Text, i + 1);
	}
}

function AddTextLine(string Text)
{
	while (true)
	{
		Text = class'SubtitlesEvent'.static.TrimString(Text);
		if (Len(Text) == 0)
			return;

		if (FitsDesiredMaxWidth(Text))
		{
			AppendLine(Text);
			return;
		}
		else
			AppendLine(GetFittingString(Text));
	}
}

function string GetFittingString(out string Text)
{
	local string Str;
	local int StrSize, MinStrSize, MaxStrSize, TextSize;
	local int i, CharCode;

	TextSize = Len(Text);
	MaxStrSize = TextSize;

	while (true)
	{
		StrSize = Max(1, (MinStrSize + MaxStrSize) / 2);
		Str = Left(Text, StrSize);
		if (FitsDesiredMaxWidth(Str))
		{
			if (MaxStrSize - StrSize <= 1)
				break;
			MinStrSize = StrSize;
		}
		else
			MaxStrSize = StrSize;
	}

	CharCode = Asc(Mid(Str, StrSize, 1));
	if (CharCode == 9 || CharCode == 32)
	{
		Text = Mid(Text, StrSize + 1);
		return Str;
	}

	for (i = StrSize - 1; i >= 0; --i)
	{
		CharCode = Asc(Mid(Str, i, 1));
		if (CharCode == 9 || CharCode == 32)
		{
			Text = Mid(Text, i + 1);
			return Left(Str, i);
		}
	}

	for (i = StrSize; i < TextSize; ++i)
	{
		Str = Left(Text, i);
		if (!FitsInScreen(Str))
		{
			Str = Left(Str, i - 1);
			Text = Mid(Text, i - 1);
			return Str;
		}

		CharCode = Asc(Mid(Text, i, 1));
		if (CharCode == 9 || CharCode == 32)
		{
			Text = Mid(Text, i + 1);
			return Str;
		}
	}

	Str = Text;
	Text = "";
	return Str;
}

function AppendLine(string Text)
{
	Text = class'SubtitlesEvent'.static.TrimString(Text);
	if (Len(Text) > 0)
		TextLines[TextLinesNum++] = Text;
}

function bool FitsDesiredMaxWidth(string Text)
{
	local float XL, YL;

	Canvas.TextSize(Text, XL, YL);
	XL += Max(0, Len(Text) - 1);
	return XL <= GetBoxWidth() * class'Subtitles'.default.MaxLineWidth || Len(Text) <= 1;
}

function bool FitsInScreen(string Text)
{
	local float XL, YL;

	Canvas.TextSize(Text, XL, YL);
	XL += Max(0, Len(Text) - 1);
	return XL <= GetBoxWidth() - 4 || Len(Text) <= 1;
}

function float GetBoxWidth()
{
	return BoxWidth / FontScale;
}

function float GetBoxHeight()
{
	return ScreenHeight / FontScale;
}

function DrawSubtitle()
{
	local int i;
	local float HorizontalOffset, VerticalOffset, VerticalSize;
	local float XL, YL;

	Canvas.Reset();
	Canvas.Font = Font;
	Canvas.SpaceX = class'Subtitles'.default.FontSpacing;

	if (bSupportsCanvasScale && FontScale > 1.0)
		Canvas.PushCanvasScale(FontScale, true);

	VerticalSize = 2;

	for (i = 0; i < TextLinesNum; ++i)
	{
		Canvas.TextSize(TextLines[i], XL, YL);
		VerticalSize += YL * 1.4;
	}

	VerticalOffset = GetBoxHeight() * FClamp(class'Subtitles'.default.VerticalPosition, 0, 1);
	if (VerticalOffset < 2)
		VerticalOffset = 2;
	if (VerticalOffset > GetBoxHeight() - VerticalSize)
		VerticalOffset = GetBoxHeight() - VerticalSize;

	for (i = 0; i < TextLinesNum; ++i)
	{
		// Draw subtitle box
		Canvas.TextSize(TextLines[i], XL, YL);
		XL += Max(0, Len(TextLines[i]) - 1);
		HorizontalOffset = (Canvas.SizeX - XL - YL) / 2;
		Canvas.SetPos(HorizontalOffset, VerticalOffset - YL * 0.2);
		Canvas.DrawColor = class'Subtitles'.default.BackgroundColor;
		Canvas.Style = ERenderStyle.STY_AlphaBlend;
		Canvas.DrawTile(Texture'WhiteTexture', XL + YL, YL * 1.4, 0, 0, 1, 1);

		// Draw text
		HorizontalOffset = (Canvas.SizeX - XL) / 2;
		Canvas.SetPos(HorizontalOffset, VerticalOffset);
		Canvas.DrawColor = class'Subtitles'.default.FontColor;
		Canvas.Style = ERenderStyle.STY_AlphaBlend;
		Canvas.DrawText(TextLines[i], false);

		VerticalOffset += YL * 1.4;
	}

	if (bSupportsCanvasScale && FontScale > 1.0)
		Canvas.PopCanvasScale();

	Canvas.Reset();
}
