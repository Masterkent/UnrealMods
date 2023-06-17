class B227_MapFix expands UMapMod
	config(B227_MapFixOptions);

function string GetHumanName()
{
	return "B227_MapFix Base v" $ class'UMapMod'.default.Version;
}

defaultproperties
{
	VersionInfo="B227_MapFix v1.0 [2022-03-20]"
	Version="1.0"
	UMapChangesClass=Class'B227_MapFix.UMapChanges'
	UMapGroupClass=Class'B227_MapFix.UMapGroup'
	UMapModInfoClass=Class'B227_MapFix.B227_MapFixInfo'
}
