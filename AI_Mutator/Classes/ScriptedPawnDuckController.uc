//=============================================================================
// ScriptedPawnDuckController.
//=============================================================================
class ScriptedPawnDuckController expands Info;

var ScriptedPawn ControlledCreature;

function DisableDuckFor(ScriptedPawn creature, float time)
{
	ControlledCreature = creature;
	if (ControlledCreature != none)
		ControlledCreature.bCanDuck = false;
	SetTimer(time, false);
}

function Timer()
{
	if (ControlledCreature != none)
		ControlledCreature.bCanDuck = true;
	Destroy();
}

defaultproperties
{
}
