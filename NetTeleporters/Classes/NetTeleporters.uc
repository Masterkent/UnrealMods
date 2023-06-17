class NetTeleporters expands Mutator;

var() const string VersionInfo;
var() const string Version;

var private bool bClientPackageIsRegistered;

event BeginPlay()
{
	ReplaceLevelTeleporters();
}

final function ReplaceLevelTeleporters()
{
	local Teleporter Telep;

	foreach AllActors(class'Teleporter', Telep)
		if (Telep.Class == class'Teleporter' && !bool(Telep.GetPropertyText("bUTRotationMode")))
		{
			if (Telep.Tag != '' && Len(Telep.URL) == 0 ||
				Len(Telep.URL) > 0 && InStr(Telep.URL, "/") < 0 && InStr(Telep.URL, "#") < 0)
			{
				RegisterClientPackage();
				class'NetTeleporter'.static.StaticReplaceTeleporter(Telep);
			}
		}
}

final function RegisterClientPackage()
{
	if (bClientPackageIsRegistered)
		return;

	AddToPackagesMap(string(Class.Outer.Name));
	bClientPackageIsRegistered = true;
}

function string GetHumanName()
{
	return "NetTeleporters v1.0";
}

defaultproperties
{
	VersionInfo="NetTeleporters v1.0 [2023-06-17]"
	Version="1.0"
}