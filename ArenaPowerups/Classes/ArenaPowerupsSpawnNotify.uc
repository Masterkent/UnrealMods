class ArenaPowerupsSpawnNotify expands SpawnNotify;

event Actor SpawnNotification(Actor A)
{
	if (A.Class.Name == 'UDamage' && A.Class.Outer.Name == 'Botpack')
		class'ArenaPowerups'.static.MakeUDamageController(Inventory(A));
	return A;
}

defaultproperties
{
	bHidden=True
	RemoteRole=ROLE_None
}
