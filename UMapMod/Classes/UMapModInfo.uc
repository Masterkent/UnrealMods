class UMapModInfo expands Info
	config(UMapMod);

struct MapAliasEntry
{
	var() config string MapName;
	var() config string Alias;
};

struct MapGroupEntry
{
	var() config string Name;
	var() config string DefaultGameType;
	var() config string MapPrefix;
	var() config string MapSuffix;
};

var() config array<MapAliasEntry> MapAlias;
var() config array<MapGroupEntry> MapGroup;

defaultproperties
{
	RemoteRole=ROLE_None
}
