class UMap_DisableLESunlight expands Info;

simulated event BeginPlay()
{
	local Light L;

	if (Level.NetMode == NM_DedicatedServer)
		return;

	foreach AllActors(class'Light', L)
		if ((L.bStatic || L.bNoDelete) && L.LightEffect == LE_Sunlight)
			L.LightEffect = LE_None;
}

simulated event Tick(float DeltaTime)
{
	if (Level.NetMode == NM_DedicatedServer)
	{
		Disable('Tick');
		return;
	}
	if (Level.GetLocalPlayerPawn() != none)
	{
		Level.GetLocalPlayerPawn().ConsoleCommand("Flush");
		if (Level.NetMode == NM_ListenServer)
			Disable('Tick');
		else // standalone game or network client
			Destroy();
	}
}

defaultproperties
{
	bAlwaysRelevant=True
	bNetTemporary=True
	RemoteRole=ROLE_SimulatedProxy
}
