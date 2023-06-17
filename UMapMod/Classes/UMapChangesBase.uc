class UMapChangesBase expands Object;

struct ExecuteProcedureEntry
{
	var() config string Condition;
	var() config string Name;
	var() config array<string> Params; 
};

struct ModifyClassActorsEntry
{
	var() config string Condition;
	var() config string ClassName;
	var() config bool bIsBaseClass; // true if ClassName denotes the base class name, false if it denotes the exact class name
	var() config array<string> Params;
};

struct RemoveClassActorsEntry
{
	var() config string Condition;
	var() config string ClassName;
	var() config bool bIsBaseClass; // true if ClassName denotes the base class name, false if it denotes the exact class name
	var() config bool bIndestructible; // true if bNoDelete or bStatic actors should be eliminated (in addition to removal of plain actors)
	var() config bool bAlwaysRelevant; // true if every matching indestructible actor should have bAlwaysRelevant == true
};

struct LoadObjectEntry
{
	var() config string Condition;
	var() config string Name;
	var() config string ClassName;
};

struct ServerPackageEntry
{
	var() config string Condition;
	var() config string Name;
};
