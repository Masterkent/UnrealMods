class NoHealth expands Mutator
	config(NoHealth);

var const string VersionInfo;
var const string Version;

var() config bool bAlterDecorations;
var() config bool bAlterPawns;
var() config bool bAlterThingFactories;
var() config bool bNoHealingZones;
var() config bool bNoSeeds;
var() config bool bNoSuperHealth;

var class<Pickup> TournamentHealthClass;
var class<Pickup> HealthPackClass;

event BeginPlay()
{
	InitTournamentHealthClass();

	RemoveLevelHealth();
	if (bNoHealingZones)
		DisableHealingZones();
	if (bNoSeeds)
		RemoveLevelSeeds();
	if (bAlterDecorations)
		ModifyLevelDecorations();
	if (bAlterPawns)
		ModifyLevelPawns();
	if (bAlterThingFactories)
		ModifyLevelThingFactories();
}

function InitTournamentHealthClass()
{
	TournamentHealthClass = class<Pickup>(FindObject(class'Class', "Botpack.TournamentHealth"));
	if (TournamentHealthClass != none)
		HealthPackClass = class<Pickup>(FindObject(class'Class', "Botpack.HealthPack"));
}

function RemoveLevelHealth()
{
	local Pickup Pickup;

	foreach AllActors(class'Pickup', Pickup)
		if (IsHealth(Pickup) && (bNoSuperHealth || !IsSuperHealth(Pickup)))
			Pickup.Destroy();
}

function DisableHealingZones()
{
	local ZoneInfo Zone;

	foreach AllActors(class'ZoneInfo', Zone)
		if (Zone.bPainZone && Zone.DamagePerSec < 0)
			Zone.DamagePerSec = 0;
}

function RemoveLevelSeeds()
{
	local Seeds Seeds;

	foreach AllActors(class'Seeds', Seeds)
		Seeds.Destroy();
}

function ModifyLevelDecorations()
{
	local Decoration Deco;

	foreach AllActors(class'Decoration', Deco)
		ModifyDecoration(Deco);
}

function ModifyDecoration(Decoration Deco)
{
	if (IsProhibitedClass(Deco.contents))
	{
		Deco.contents = none;
		if (Deco.content2 != none)
		{
			Deco.contents = Deco.content2;
			if (Deco.content3 != none)
			{
				Deco.content2 = Deco.content3;
				Deco.content3 = none;
			}
			else
				Deco.content2 = none;
		}
		else if (Deco.content3 != none)
		{
			Deco.contents = Deco.content3;
			Deco.content3 = none;
		}
	}
	if (IsProhibitedClass(Deco.content2))
	{
		if (Deco.content3 != none)
		{
			Deco.content2 = Deco.content3;
			Deco.content3 = none;
		}
		else
			Deco.content2 = none;
	}
	if (IsProhibitedClass(Deco.content3))
		Deco.content3 = none;
}

function ModifyLevelPawns()
{
	local Pawn Pawn;

	foreach AllActors(class'Pawn', Pawn)
		ModifyPawnDropWhenKilled(Pawn);
}

function ModifyPawnDropWhenKilled(Pawn Pawn)
{
	if (IsProhibitedClass(Pawn.DropWhenKilled))
		Pawn.DropWhenKilled = none;
}

function ModifyLevelThingFactories()
{
	local ThingFactory Factory;

	foreach AllActors(class'ThingFactory', Factory)
		ModifyThingFactory(Factory);
}

function ModifyThingFactory(ThingFactory Factory)
{
	if (IsProhibitedClass(Factory.prototype))
	{
		if (Factory.bStatic || Factory.bNoDelete)
		{
			Factory.Tag = '';
			Factory.SetCollision(false);
		}
		else
			Factory.Destroy();
	}
}

function bool IsHealth(Actor Actor)
{
	return Actor.IsA('Health') || Actor.IsA('TournamentHealth');
}

function bool IsSuperHealth(Actor Actor)
{
	return Actor.IsA('SuperHealth') || Actor.IsA('HealthPack');
}

function bool IsHealthClass(class<Actor> ActorClass)
{
	if (ActorClass == none)
		return false;
	return
		ClassIsChildOf(ActorClass, class'Health') ||
		TournamentHealthClass != none && ClassIsChildOf(ActorClass, TournamentHealthClass);
}

function bool IsSuperHealthClass(class<Actor> ActorClass)
{
	if (ActorClass == none)
		return false;
	return
		ClassIsChildOf(ActorClass, class'SuperHealth') ||
		HealthPackClass != none && ClassIsChildOf(ActorClass, HealthPackClass);
}

function bool IsProhibitedClass(class<Actor> ActorClass)
{
	if (ActorClass == none)
		return false;

	return
		IsHealthClass(ActorClass) && (bNoSuperHealth || !IsSuperHealthClass(ActorClass)) ||
		bNoSeeds && ClassIsChildOf(ActorClass, class'Seeds');
}

function string GetHumanName()
{
	return "NoHealth v1.0";
}

defaultproperties
{
	VersionInfo="NoHealth v1.0 [2023-06-20]"
	Version="1.0"
	bAlterDecorations=True
	bAlterPawns=True
	bAlterThingFactories=True
	bNoHealingZones=False
	bNoSeeds=True
	bNoSuperHealth=True
}
