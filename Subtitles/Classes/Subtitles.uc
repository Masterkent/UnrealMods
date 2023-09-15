class Subtitles expands Mutator
	config(Subtitles);

var() const string VersionInfo;
var() const string Version;

var() config string LocalizationFilename;

var() config Color BackgroundColor;
var() config bool bShowSubtitles;
var() config string Font;
var() config Color FontColor;
var() config float FontScale;
var() config int FontSpacing;
var() config float MaxLineWidth;
var() config float VerticalPosition;


event PostBeginPlay()
{
	Spawn(class'LevelSubtitles');
	SaveConfig();
	class'SubtitleRenderer'.static.StaticSaveConfig();
	if (Level.NetMode != NM_Standalone)
		AddToPackagesMap(string(Class.Outer.Name));
}

function string GetHumanName()
{
	return "Subtitles v2.0";
}

defaultproperties
{
	VersionInfo="Subtitles version 2.0 [2023-09-15]"
	Version="2.0"
	LocalizationFilename="%MapName%_subs"
	BackgroundColor=(R=0,G=0,B=0,A=128)
	bShowSubtitles=True
	Font="UWindowFonts.Tahoma"
	FontColor=(R=255,G=255,B=255,A=255)
	FontScale=0.0
	FontSpacing=1
	MaxLineWidth=0.8
	VerticalPosition=0.8
}
