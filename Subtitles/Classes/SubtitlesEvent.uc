class SubtitlesEvent expands Triggers;

enum EInstigatorPlayers
{
	INSTIGATOR_PLAYERS_All,
	INSTIGATOR_PLAYERS_Males,
	INSTIGATOR_PLAYERS_Females
};

enum ETargetPlayers
{
	TARGET_PLAYERS_All,
	TARGET_PLAYERS_Instigator,
	TARGET_PLAYERS_Males,
	TARGET_PLAYERS_Females
};

var() EInstigatorPlayers InstigatorPlayers;
var() ETargetPlayers TargetPlayers;
var() bool bTriggerOnceOnly;
var() array<string> Subtitles;

struct SubtitleData
{
	var float TimeStamp;
	var string Text;
};

var array<SubtitleData> SubtitlesData;
var SubtitleInfo SubtitleInfo;
var bool bNoTrigger;
var float ActivationTimeStamp;
var int CurrentSubtitleIndex;

event PostBeginPlay()
{
	InitSubtitles();
}

function Trigger(Actor A, Pawn EventInstigator)
{
	if (bNoTrigger)
		return;
	if (InstigatorPlayers == INSTIGATOR_PLAYERS_Males && (EventInstigator == none || EventInstigator.bIsFemale) ||
		InstigatorPlayers == INSTIGATOR_PLAYERS_Females && (EventInstigator == none || !EventInstigator.bIsFemale))
	{
		return;
	}

	GotoState('');
	Instigator = EventInstigator;
	GotoState('ShowingSubtitles');
	bNoTrigger = bTriggerOnceOnly;
}

function AddPlayer(PlayerPawn Player)
{
	local SubtitleInfo NewSubtitleInfo;

	if (Player == none || TargetPlayers == TARGET_PLAYERS_All)
		return;
	NewSubtitleInfo = Player.Spawn(class'SubtitleInfo');
	if (NewSubtitleInfo == none)
		return;
	NewSubtitleInfo.NextSubtitleInfo = SubtitleInfo;
	SubtitleInfo = NewSubtitleInfo;
}

function InitSubtitles()
{
	local int i, j, n;
	local float StartTimeStamp, EndTimeStamp, LastTimeStamp;
	local string Text;

	Array_Size(SubtitlesData, 0);
	n = Array_Size(Subtitles);

	for (i = 0; i < n; ++i)
	{
		if (!ParseSubtitle(Subtitles[i], StartTimeStamp, EndTimeStamp, Text) || StartTimeStamp <= LastTimeStamp)
			return;
		SubtitlesData[j].TimeStamp = StartTimeStamp;
		SubtitlesData[j].Text = Text;
		++j;

		if (EndTimeStamp > 0)
		{
			SubtitlesData[j].TimeStamp = EndTimeStamp;
			SubtitlesData[j].Text = "";
			++j;
		}

		LastTimeStamp = StartTimeStamp;
	}
}

function SetInstigatorPlayers(string Value)
{
	if (Value ~= "All" || Value ~= "Males" || Value ~= "Females")
		SetPropertyText("InstigatorPlayers", "INSTIGATOR_PLAYERS_" $ Value);
}

function SetTargetPlayers(string Value)
{
	if (Value ~= "All" || Value ~= "Instigator" || Value ~= "Males" || Value ~= "Females")
		SetPropertyText("TargetPlayers", "TARGET_PLAYERS_" $ Value);
}


static function bool ParseSubtitle(string SubtitleData, out float StartTimeStamp, out float EndTimeStamp, out string Text)
{
	local int i;

	i = InStr(SubtitleData, "|");
	if (i < 0)
	{
		if (!ParseTimeInterval(SubtitleData, StartTimeStamp, EndTimeStamp))
			return false;
		Text = "";
		return true;
	}
	else if (!ParseTimeInterval(Left(SubtitleData, i), StartTimeStamp, EndTimeStamp))
		return false;

	Text = TrimString(Mid(SubtitleData, i + 1));
	return true;
}

static function bool ParseTimeInterval(string TimeInterval, out float StartTimeStamp, out float EndTimeStamp)
{
	local int i;

	i = InStr(TimeInterval, "-");
	if (i < 0)
	{
		if (!ParseTimeStamp(TimeInterval, StartTimeStamp))
			return false;
		EndTimeStamp = 0;
		return true;
	}
	return
		ParseTimeStamp(Left(TimeInterval, i), StartTimeStamp) &&
		ParseTimeStamp(Mid(TimeInterval, i + 1), EndTimeStamp) &&
		StartTimeStamp < EndTimeStamp;
}

static function bool ParseTimeStamp(string Str, out float TimeStamp)
{
	local int i;
	local int IntNumber;
	local int ColonsNum;

	Str = TrimString(Str);
	i = InStr(Str, ":");
	if (i < 0)
		return ParseFloatNumber(Str, TimeStamp);
	if (!ParseIntNumber(Left(Str, i), IntNumber) || !ParseTimeStamp(Mid(Str, i + 1), TimeStamp))
		return false;
	while (i >= 0)
	{
		++ColonsNum;
		Str = Mid(Str, i + 1);
		i = InStr(Str, ":");
	}
	if (ColonsNum == 1 && TimeStamp < 60)
		TimeStamp += 60 * IntNumber; // minutes
	else if (ColonsNum == 2 && TimeStamp < 60 * 60)
		TimeStamp += 60 * 60 * IntNumber; // hours
	else
		return false;
	return true;
}

static function bool ParseIntNumber(string Str, out int IntNumber)
{
	local int CharCode;

	if (Len(Str) == 0)
		return false;
	CharCode = Asc(Str);
	if (CharCode < 48 || CharCode > 57)
		return false;
	IntNumber = int(Str);
	return true;
}

static function bool ParseFloatNumber(string Str, out float FloatNumber)
{
	local int IntNumber;

	if (Len(Str) == 0)
		return false;
	if (!ParseIntNumber(Str, IntNumber) && (Left(Str, 1) != "." || !ParseIntNumber(Mid(Str, 1), IntNumber)))
		return false;
	FloatNumber = float(Str);
	return true;
}

static function string TrimString(string Str)
{
	local int StrLen;

	while (InStr(Str, " ") == 0)
		Str = Mid(Str, 1);
	while (true)
	{
		StrLen = Len(Str);
		if (StrLen == 0 || Mid(Str, StrLen - 1, 1) != " ")
			return Str;
		Str = Left(Str, StrLen - 1);
	}
}

state ShowingSubtitles
{
	event BeginState()
	{
		InitSubtitleInfo();
		ActivationTimeStamp = AppSeconds();
		CurrentSubtitleIndex = -1;
		Tick(0);
	}

	event EndState()
	{
		if (SubtitleInfo != none)
			SubtitleInfo.Destroy();
	}

	event Tick(float DeltaTime)
	{
		local float TimeStamp;
		local int NextSubtitleIndex, SubtitlesCount;

		TimeStamp = AppSeconds() - ActivationTimeStamp;
		NextSubtitleIndex = CurrentSubtitleIndex + 1;
		SubtitlesCount = Array_Size(SubtitlesData);

		if (NextSubtitleIndex < SubtitlesCount)
		{
			while (SubtitlesData[NextSubtitleIndex].TimeStamp <= TimeStamp)
			{
				CurrentSubtitleIndex = NextSubtitleIndex++;
				if (NextSubtitleIndex == SubtitlesCount)
				{
					GotoState('');
					return;
				}
			}
			if (CurrentSubtitleIndex >= 0 && SubtitleInfo != none)
				SubtitleInfo.SetSubtitle(SubtitlesData[CurrentSubtitleIndex].Text);
		}
		else
			GotoState('');
	}

	function InitSubtitleInfo()
	{
		local PlayerPawn Player;

		switch (TargetPlayers)
		{
			case TARGET_PLAYERS_All:
				SubtitleInfo = Level.Spawn(class'SubtitleInfo');
				SubtitleInfo.bAlwaysRelevant = true;
				break;

			case TARGET_PLAYERS_Instigator:
				AddPlayer(PlayerPawn(Instigator));
				break;

			case TARGET_PLAYERS_Males:
				foreach AllActors(class'PlayerPawn', Player)
					if (!Player.bIsFemale)
						AddPlayer(Player);
				break;

			case TARGET_PLAYERS_Females:
				foreach AllActors(class'PlayerPawn', Player)
					if (Player.bIsFemale)
						AddPlayer(Player);
				break;
		}
	}
}
