class UMapFix expands UMapMod
	config(UMapFixOptions);

function string GetHumanName()
{
	return "UMapFix Base v" $ class'UMapMod'.default.Version;
}

defaultproperties
{
	VersionInfo="UMapFix v1.0 [2021-11-08]"
	Version="1.0"
	UMapChangesClass=Class'UMapFix.UMapChanges'
	UMapGroupClass=Class'UMapFix.UMapGroup'
	UMapModInfoClass=Class'UMapFix.UMapFixInfo'
}
