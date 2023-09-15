class LevelSubtitles expands Info;

var private string LocalizationFileName;

event PostBeginPlay()
{
	local int i, SubtitlesEventsNum;
	local SubtitlesEvent SubtitlesEvent;

	SubtitlesEventsNum = int(Localize("LevelSubtitles", "SubtitlesEventsNum", GetLocalizationFileName()));
	for (i = 0; i < SubtitlesEventsNum; ++i)
	{
		SubtitlesEvent = Spawn(class'SubtitlesEvent');
		if (SubtitlesEvent == none)
			break;
		InitSubtitlesEvent(SubtitlesEvent, "SubtitlesEvent" $ i);
	}
}

function string GetLocalizationFileName()
{
	if (Len(LocalizationFileName) > 0)
		return LocalizationFileName;
	LocalizationFileName = ReplaceStr(class'Subtitles'.default.LocalizationFileName, "%MapName%", string(Level.Outer.Name), true);
	if (Len(LocalizationFileName) == 0)
		LocalizationFileName = string(Level.Outer.Name);
	return LocalizationFileName;
}

function bool InitSubtitlesEvent(SubtitlesEvent SubtitlesEvent, string SectionName)
{
	local string Value;
	local int i, SubtitlesNum;

	if (!GetNonEmptyLocalizedProperty(SectionName, "Tag", Value))
		return FailedToInitializeSubtitlesEvent(SubtitlesEvent);
	SubtitlesEvent.Tag = StringToName(Value);

	if (!GetNonEmptyLocalizedProperty(SectionName, "SubtitlesNum", Value) || int(Value) == 0)
		return FailedToInitializeSubtitlesEvent(SubtitlesEvent);
	SubtitlesNum = int(Value);

	if (GetLocalizedProperty(SectionName, "InstigatorPlayers", Value))
		SubtitlesEvent.SetInstigatorPlayers(Value);

	if (GetLocalizedProperty(SectionName, "TargetPlayers", Value))
		SubtitlesEvent.SetTargetPlayers(Value);

	if (GetLocalizedProperty(SectionName, "bTriggerOnceOnly", Value))
		SubtitlesEvent.bTriggerOnceOnly = bool(Value);

	for (i = 0; i < SubtitlesNum && GetLocalizedProperty(SectionName, "Subtitles[" $ i $ "]", Value); ++i)
		SubtitlesEvent.Subtitles[i] = Value;
	if (i == 0)
		return FailedToInitializeSubtitlesEvent(SubtitlesEvent);

	SubtitlesEvent.InitSubtitles();
	return true;
}

static function bool FailedToInitializeSubtitlesEvent(SubtitlesEvent SubtitlesEvent)
{
	SubtitlesEvent.Destroy();
	return false;
}

function bool GetLocalizedProperty(string SectionName, string PropertyName, out string Result)
{
	Result = Localize(SectionName, PropertyName, LocalizationFileName);
	return !StrStartsWith(Result, "<?");
}

function bool GetNonEmptyLocalizedProperty(string SectionName, string PropertyName, out string Result)
{
	return GetLocalizedProperty(SectionName, PropertyName, Result) && Len(Result) > 0;
}

function bool StrStartsWith(coerce string S, coerce string Substr)
{
	return InStr(S, Substr) == 0;
}
