class UMap_SafeFall expands Triggers;

event BeginPlay()
{
	AddGameRules();
}

function AddGameRules()
{
	local GameRules GR;

	for (GR = Level.Game.GameRules; GR != none; GR = GR.NextRules)
		if (UMapGameRules(GR) != none)
			return;
	Spawn(class'UMapGameRules');
}
