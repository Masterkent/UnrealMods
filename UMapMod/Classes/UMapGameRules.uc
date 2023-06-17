class UMapGameRules expands GameRules;

event BeginPlay()
{
	if (Level.Game.GameRules == none)
		Level.Game.GameRules = self;
	else
		Level.Game.GameRules.AddRules(self);
}

function ModifyDamage(Pawn Injured, Pawn EventInstigator, out int Damage, vector HitLocation, name DamageType, out vector Momentum)
{
	local UMap_SafeFall UMap_SafeFall;

	if (DamageType == 'fell')
		foreach Injured.TouchingActors(class'UMap_SafeFall', UMap_SafeFall)
		{
			Damage = 0;
			return;
		}
}

defaultproperties
{
	bModifyDamage=True
}
