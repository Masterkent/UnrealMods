class ArenaPowerups expands Mutator
	config(ArenaPowerups);

var const string VersionInfo;
var const string Version;

var() config array<string> PowerupClasses;

event BeginPlay()
{
	Spawn(class'ArenaPowerupsGR', self);
	Spawn(class'ArenaPowerupsSpawnNotify', self);
	AdjustUDamage();
}

function AdjustUDamage()
{
	local Pickup Inv;

	foreach AllActors(class'Pickup', Inv)
		if (Inv.Class.Name == 'UDamage' && Inv.Class.Outer.Name == 'Botpack')
			MakeUDamageController(Inv);
}

static function MakeUDamageController(Inventory A)
{
	A.Spawn(class'UDamageController', A);
}

function string GetHumanName()
{
	return "ArenaPowerups v1.1";
}

defaultproperties
{
	VersionInfo="ArenaPowerups v1.1 [2022-06-20]"
	Version="1.1"
}
