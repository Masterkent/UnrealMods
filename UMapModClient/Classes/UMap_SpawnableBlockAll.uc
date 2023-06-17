class UMap_SpawnableBlockAll expands BlockAll;

simulated function PostBeginPlay()
{
	local int GameVersion;
	GameVersion = int(Level.EngineVersion);
	if (227 <= GameVersion && GameVersion < 400)
		SetPropertyText("bWorldGeometry", "true");
}

defaultproperties
{
	bAlwaysRelevant=True
	bNetTemporary=True
	bStatic=False
}
