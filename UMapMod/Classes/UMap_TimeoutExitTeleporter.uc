class UMap_TimeoutExitTeleporter expands UMap_SpawnableTeleporter;

var() float TimeoutSeconds;
var() bool bItems; // Whether player's inventory should travel to the next level (default is true)

var private bool bTriggered;

event Touch(Actor A);

function Trigger(Actor A, Pawn EventInstigator)
{
	if (bTriggered)
		return;
	bTriggered = true;
	SetTimer(TimeoutSeconds, false);
}

event Timer()
{
	class'UMapMod'.static.SwitchToNextLevel(Level, URL, bItems);
}

event Tick(float DeltaTime)
{
	if (Tag == '' || Tag == Class.Name)
		Trigger(none, none);
	Disable('Tick');
}

defaultproperties
{
	bCollideActors=False
	bItems=True
}
