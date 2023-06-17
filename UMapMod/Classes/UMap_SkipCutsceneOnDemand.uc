class UMap_SkipCutsceneOnDemand expands Info;

var() string Events; // Space-separated list of events
var() string URL; // URL of the next level
var() bool bItems; // Whether player's inventory should travel to the next level (default is true)

event PreBeginPlay()
{
	if (Level.NetMode != NM_Standalone)
		Destroy();
	else
		super.PreBeginPlay();
}

event Tick(float DeltaTime)
{
	CheckPlayerInput();
}

function CheckPlayerInput()
{
	local PlayerPawn Player;

	Player = Level.GetLocalPlayerPawn();
	if (Player != none && (Player.bFire != 0 || Player.bAltFire != 0))
		SkipCutscene(Player);
}

function SkipCutscene(PlayerPawn Player)
{
	class'UMapMod'.static.TrimStr(Events);
	if (Len(Events) > 0)
		CauseEvents(Player);
	else
		class'UMapMod'.static.SwitchToNextLevel(Level, URL, bItems);
	Destroy();
}

function CauseEvents(PlayerPawn Player)
{
	local int DelimPos;
	local Actor A;
	local name EventName;

	while (Len(Events) > 0)
	{
		DelimPos = InStr(Events, " ");
		if (DelimPos > 0)
		{
			EventName = StringToName(Left(Events, DelimPos));
			if (EventName != '')
				foreach AllActors(class'Actor', A, EventName)
					A.Trigger(self, Player);
			Events = Mid(Events, DelimPos + 1);
			class'UMapMod'.static.TrimStr(Events);
		}
		else
		{
			EventName = StringToName(Events);
			if (EventName != '')
				foreach AllActors(class'Actor', A, EventName)
					A.Trigger(self, Player);
			return;
		}
	}
}

defaultproperties
{
	bItems=True
}
