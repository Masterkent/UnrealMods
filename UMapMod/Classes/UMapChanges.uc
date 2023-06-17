class UMapChanges expands UMapChangesBase
	perobjectconfig;

const MutatorName = "UMapMod";

struct CreateActorEntry
{
	var() config string Condition;
	var() config string IDName;
	var() config string ClassName;
	var() config float X, Y, Z;
	var() config int Yaw;
	var() config string Tag;
	var() config array<string> Params;
};

struct ModifyActorEntry
{
	var() config string Condition;
	var() config string Name;
	var() config string IDName;
	var() config array<string> Params;
};

struct RemoveActorEntry
{
	var() config string Condition;
	var() config string Name;
	var() config bool bIndestructible; // true if bNoDelete or bStatic actor should be eliminated
	var() config bool bAlwaysRelevant; // true if the indestructible actor should have bAlwaysRelevant == true
};

struct ReplaceActorEntry
{
	var() config string Condition;
	var() config string Name;
	var() config string ClassName;
	var() config array<string> Params;
};

var() config array<string> MapGroup;
var() config array<LoadObjectEntry> LoadObject;
var() config array<ServerPackageEntry> ServerPackage;
var() config array<ExecuteProcedureEntry> ExecuteProcedure;
var() config array<CreateActorEntry> CreateActor;
var() config array<ModifyActorEntry> ModifyActor;
var() config array<ModifyClassActorsEntry> ModifyClassActors;
var() config array<RemoveActorEntry> RemoveActor;
var() config array<RemoveClassActorsEntry> RemoveClassActors;
var() config array<ReplaceActorEntry> ReplaceActor;

static final function UMapChanges Construct(UMapMod MutatorPtr)
{
	local name ObjectName;

	ObjectName = MutatorPtr.GetMapSectionName(MutatorPtr.Level.Outer.Name);
	return new(MutatorPtr.class.outer, ObjectName) class'UMapChanges';
}
