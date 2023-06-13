class AI_GameRules expands GameRules;

const ATTITUDE_Friendly = 5;

event BeginPlay()
{
	if (Level.Game.GameRules == none)
		Level.Game.GameRules = self;
	else
		Level.Game.GameRules.AddRules(self);
}

function ModifyThreat(Pawn Creature, Pawn Hated, out byte Attitude)
{
	if (Hated.Enemy == Creature)
		return;

	if (IsSkaarjFamily(Creature))
	{
		if (IsSkaarjFamily(Hated))
			Attitude = ATTITUDE_Friendly;
		return;
	}

	if (GasBag(Creature) != none)
	{
		if (GasBag(Hated) != none)
			Attitude = ATTITUDE_Friendly;
		return;
	}
}

static function bool IsSkaarjFamily(Pawn Creature)
{
	return
		Pupae(Creature) != none ||
		Skaarj(Creature) != none ||
		Warlord(Creature) != none;
}

defaultproperties
{
	bModifyAI=True
}
