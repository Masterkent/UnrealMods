class UMapGroup expands UMapChangesBase
	perobjectconfig;

struct MutatorEntry
{
	var() config string Condition;
	var() config string ClassName;
};

var() config array<ServerPackageEntry> ServerPackage;
var() config array<MutatorEntry> Mutator;
var() config array<LoadObjectEntry> LoadObject;
var() config array<ExecuteProcedureEntry> ExecuteProcedure;
var() config array<ModifyClassActorsEntry> ModifyClassActors;
var() config array<RemoveClassActorsEntry> RemoveClassActors;

static final function UMapGroup Construct(UMapMod MutatorPtr, string MapGroupName)
{
	local name ObjectName;

	ObjectName = MutatorPtr.GetMapGroupSectionName(MapGroupName);
	return new(MutatorPtr.class.outer, ObjectName) class'UMapGroup';
}
