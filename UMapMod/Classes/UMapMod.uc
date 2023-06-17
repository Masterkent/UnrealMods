//=============================================================================
// UMapMod v9.4                                              Author: Masterkent
//                                                             Date: 2023-06-17
//=============================================================================

class UMapMod expands Mutator
	config(UMapModOptions);

var() transient const string VersionInfo;
var() transient const string Version;

var() config array<string> ModOptions;
var int ModOptionCount;

var() class<UMapChanges> UMapChangesClass;
var() class<UMapGroup> UMapGroupClass;
var() class<UMapModInfo> UMapModInfoClass;

var private string MutatorName;
var private UMapModInfo UMapModInfo;
var private UMapChanges UMapChanges;
var private UMapGroup UMapGroup;
var private array<string> ActualMapGroups;
var private int ActualMapGroupCount;
var private string CurrentMap;
var private bool bIncludedMutator;
var private bool bClientPackageIsRegistered;
var private array<Object> LoadedObjects;
var private int LoadedObjectCount, LoadedObjectsArraySize;
var private UMapActorModifierBase ActorModifierBase;
var private UMapActorModifier ActorModifier;
var private bool bNonTravelPlayerStartsDisabled;

var private struct ActorPreModificationInfo
{
	var class<Actor> ActorClass;
	var int ParamsN;
} ActorPreModification;

var private struct ActorClassRemovalInfo
{
	var string ClassName;
	var bool bIsBaseClass; // true if ClassName denotes the base class name, false if it denotes the exact class name
	var bool bIndestructible; // true if bNoDelete or bStatic actors should be eliminated (in addition to removal of plain actors)
	var bool bAlwaysRelevant; // true if every matching indestructible actor should have bAlwaysRelevant == true
} ActorClassRemoval;

var private struct IniArrayItem
{
	var Object ArrayModObject;
	var string ArrayName;
	var int ArrayIndex;
} IniArrayItemRef;

struct ActorWithIDNameInfo
{
	var Actor Actor;
	var string IDName;
};

var private array<ActorWithIDNameInfo> ActorsWithIDName;

struct ProcedureParamInfo
{
	var string ParamName;
	var string Value;
};

var private array<ProcedureParamInfo> ProcedureParams;
var private int ProcedureParamCount;


const CHARCODE_LParen = 40; // (
const CHARCODE_RParen = 41; // )
const CHARCODE_And = 38;    // &
const CHARCODE_Or = 124;    // |
const STR_Not = "!";

const MaxRecursionDepth = 64;


event PostBeginPlay()
{
	if (RemoveDuplicatedMutator())
		return;

	MutatorName = string(Class.Outer.Name);
	UMapModInfo = Spawn(UMapModInfoClass);
	UMapChanges = UMapChangesClass.static.Construct(self);
	ActorModifierBase = Spawn(class'UMapActorModifierBase');
	CurrentMap = string(Level.Outer.Name);

	ModOptionCount = Array_Size(ModOptions);

	if (UMapModInfo == none)
		Log("Error:" @ MutatorName @ "failed to create an object of type UMapModInfo");
	else if (UMapChanges == none)
		Log("Error:" @ MutatorName @ "failed to create an object of type UMapChanges");
	else if (ActorModifierBase == none)
		Log("Error:" @ MutatorName @ "failed to create an object of type UMapActorModifierBase");
	else
	{
		IncludeThisMutator();
		ApplyMapChanges();
		ExcludeThisMutator();
		UMapChanges = none;
	}
}

function bool CheckReplacement(Actor A, out byte bSuperRelevant)
{
	if (ActorPreModification.ParamsN > 0 && A.class == ActorPreModification.ActorClass)
		PreModifyActor(A);
	return true;
}

final function bool RemoveDuplicatedMutator()
{
	local Mutator aMutator;

	for (aMutator = Level.Game.BaseMutator; aMutator != none; aMutator = aMutator.NextMutator)
		if (aMutator.Class == Class && aMutator != self)
		{
			Destroy();
			return true;
		}
	return false;
}

final function IncludeThisMutator()
{
	local Mutator aMutator, LastMutator;

	for (aMutator = Level.Game.BaseMutator; aMutator != none; aMutator = aMutator.NextMutator)
	{
		if (aMutator == self)
			return;
		LastMutator = aMutator;
	}
	if (LastMutator == none)
		Level.Game.BaseMutator = self;
	else
		LastMutator.NextMutator = self;
	bIncludedMutator = true;
}

final function ApplyMapGroupChanges()
{
	local int i;

	for (i = 0; i < ActualMapGroupCount; ++i)
	{
		UMapGroup = UMapGroupClass.static.Construct(self, ActualMapGroups[i]);
		if (UMapGroup == none)
			continue;
		IniArrayItemRef.ArrayModObject = UMapGroup;

		MapGroupAddServerPackages();
		MapGroupAddMutators();
		MapGroupLoadObjects();
		MapGroupExecuteProcedures();
		MapGroupModifyClassActors();
		MapGroupRemoveClassActors();

		UMapGroup = none;
	}
}

final function ApplyMapChanges()
{
	DetermineActualMapGroups();
	ApplyMapGroupChanges();

	IniArrayItemRef.ArrayModObject = UMapChanges;

	LoadLevelObjects();
	AddLevelServerPackages();
	ExecuteLevelProcedures();
	CreateLevelActors();
	ModifyClassActors();
	ModifyLevelActors();
	RemoveClassActors();
	RemoveLevelActors();
	ReplaceLevelActors();

	IniArrayItemRef.ArrayModObject = none;
}

final function ExcludeThisMutator()
{
	local Mutator aMutator, PriorMutator;
	if (!bIncludedMutator)
		return;
	for (aMutator = Level.Game.BaseMutator; aMutator != none; aMutator = aMutator.NextMutator)
	{
		if (aMutator == self)
		{
			if (PriorMutator == none)
				Level.Game.BaseMutator = NextMutator;
			else
				PriorMutator.NextMutator = NextMutator;
			NextMutator = none;
			bIncludedMutator = false;
			return;
		}
		PriorMutator = aMutator;
	}
}

final function DetermineActualMapGroups()
{
	local int i, n;

	n = Array_Size(UMapModInfo.MapGroup);
	for (i = 0; i < n; ++i)
	{
		if (Len(UMapModInfo.MapGroup[i].Name) == 0)
			continue;
		if (Len(UMapModInfo.MapGroup[i].DefaultGameType) > 0 &&
			(Level.DefaultGameType == none || !(UMapModInfo.MapGroup[i].DefaultGameType ~= string(Level.DefaultGameType))))
		{
			continue;
		}
		if (Len(UMapModInfo.MapGroup[i].MapPrefix) > 0 &&
			!(UMapModInfo.MapGroup[i].MapPrefix ~= Left(Level.Outer.Name, Len(UMapModInfo.MapGroup[i].MapPrefix))))
		{
			continue;
		}
		if (Len(UMapModInfo.MapGroup[i].MapSuffix) > 0 &&
			!(UMapModInfo.MapGroup[i].MapSuffix ~= Right(Level.Outer.Name, Len(UMapModInfo.MapGroup[i].MapSuffix))))
		{
			continue;
		}
		AddUniqueActualMapGroupsFromList(UMapModInfo.MapGroup[i].Name);
	}

	n = Array_Size(UMapChanges.MapGroup);
	for (i = 0; i < n; ++i)
		if (Len(UMapChanges.MapGroup[i]) > 0)
			AddUniqueActualMapGroup(UMapChanges.MapGroup[i]);
}

final function AddUniqueActualMapGroupsFromList(string MapGroupList)
{
	local int DelimPos;

	TrimStr(MapGroupList);
	while (Len(MapGroupList) > 0)
	{
		DelimPos = InStr(MapGroupList, " ");
		if (DelimPos > 0)
		{
			AddUniqueActualMapGroup(Left(MapGroupList, DelimPos));
			MapGroupList = Mid(MapGroupList, DelimPos + 1);
			TrimStr(MapGroupList);
		}
		else // the list consists of one name
		{
			AddUniqueActualMapGroup(MapGroupList);
			return;
		}
	}
}

final function AddUniqueActualMapGroup(string MapGroupName)
{
	local int i;

	for (i = 0; i < ActualMapGroupCount; ++i)
		if (ActualMapGroups[i] ~= MapGroupName)
			return;
	ActualMapGroups[ActualMapGroupCount++] = MapGroupName;
}

final function MapGroupAddServerPackages()
{
	local int i, n;

	if (Level.NetMode == NM_Standalone)
		return;

	IniArrayItemRef.ArrayName = "ServerPackage";

	n = Array_Size(UMapGroup.ServerPackage);
	for (i = 0; i < n; ++i)
		if (UMapGroup.ServerPackage[i].Name != "")
		{
			IniArrayItemRef.ArrayIndex = i;
			if (GetConditionalExpressionValue(UMapGroup.ServerPackage[i].Condition) &&
				!AddToPackagesMap(UMapGroup.ServerPackage[i].Name))
			{
				LogIniArrError(MutatorName @ "failed to add server package" @ UMapGroup.ServerPackage[i].Name);
			}
		}
}

final function MapGroupAddMutators()
{
	local int i, n;

	IniArrayItemRef.ArrayName = "Mutator";

	n = Array_Size(UMapGroup.Mutator);
	for (i = 0; i < n; ++i)
		if (UMapGroup.Mutator[i].ClassName != "")
		{
			IniArrayItemRef.ArrayIndex = i;
			if (GetConditionalExpressionValue(UMapGroup.Mutator[i].Condition))
				AddUniqueMutator(UMapGroup.Mutator[i].ClassName);
		}
}

final function MapGroupLoadObjects()
{
	local int i, n;

	IniArrayItemRef.ArrayName = "LoadObject";

	n = Array_Size(UMapGroup.LoadObject);
	for (i = 0; i < n; ++i)
		if (UMapGroup.LoadObject[i].Name != "" && UMapGroup.LoadObject[i].ClassName != "")
		{
			IniArrayItemRef.ArrayIndex = i;
			if (GetConditionalExpressionValue(UMapGroup.LoadObject[i].Condition))
				LoadObjectInMemory(UMapGroup.LoadObject[i].Name, UMapGroup.LoadObject[i].ClassName);
		}
}

final function LoadObjectInMemory(string ObjectName, string ClassName)
{
	local class<Object> ObjectClass;
	local Object NewObject;

	if (ClassName ~= "class" || ClassName ~= "Core.class")
		ObjectClass = class'class';
	else
		ObjectClass = LoadObjectClass(ClassName, true);

	if (ObjectClass == none)
	{
		LogIniArrError(MutatorName @ "failed to load class" @ ClassName);
		return;
	}
	NewObject = DynamicLoadObject(ObjectName, ObjectClass, true);

	if (NewObject == none)
	{
		LogIniArrError(MutatorName @ "failed to load object" @ ObjectName);
		return;
	}

	if (LoadedObjectCount == LoadedObjectsArraySize)
	{
		LoadedObjectsArraySize = Max(4, LoadedObjectsArraySize * 2);
		Array_Size(LoadedObjects, LoadedObjectsArraySize);
	}
	LoadedObjects[LoadedObjectCount++] = NewObject;
}

final function MapGroupExecuteProcedures()
{
	local int i, n;

	IniArrayItemRef.ArrayName = "ExecuteProcedure";

	n = Array_Size(UMapGroup.ExecuteProcedure);
	for (i = 0; i < n; ++i)
		if (UMapGroup.ExecuteProcedure[i].Name != "")
		{
			IniArrayItemRef.ArrayIndex = i;

			if (GetConditionalExpressionValue(UMapGroup.ExecuteProcedure[i].Condition))
				ExecuteProcedure(UMapGroup.ExecuteProcedure[i].Name, UMapGroup.ExecuteProcedure[i].Params);
		}
}

final function ExecuteProcedure(string ProcName, out array<string> Params)
{
	local int i, n;
	local int AssignmentPos;

	ProcedureParamCount = 0;
	n = Array_Size(Params);
	for (i = 0; i < n; ++i)
	{
		AssignmentPos = InStr(Params[i], "=");
		if (AssignmentPos > 0)
		{
			ProcedureParams[ProcedureParamCount].ParamName = Left(Params[i], AssignmentPos);
			ProcedureParams[ProcedureParamCount].Value = Mid(Params[i], AssignmentPos + 1);
			++ProcedureParamCount;
		}
	}

	if (ProcName == "ModifyTriggerType")
		Proc_ModifyTriggerType();
	else if (ProcName == "ReplaceUTLevelTeleporters")
		Proc_ReplaceUTLevelTeleporters();
}

final function Proc_ModifyTriggerType()
{
	local string OldTriggerType;
	local string NewTriggerType;
	local string NewClassProximityType;
	local Trigger Trigger;
	local class<Actor> ClassProximityType;

	OldTriggerType = GetProcedureArgument("OldTriggerType");
	NewTriggerType = GetProcedureArgument("NewTriggerType");
	NewClassProximityType = GetProcedureArgument("NewClassProximityType");

	foreach AllActors(class'Trigger', Trigger)
		if (Trigger.GetPropertyText("TriggerType") ~= OldTriggerType)
		{
			if (Len(NewTriggerType) > 0)
				Trigger.SetPropertyText("TriggerType", NewTriggerType);
			if (Len(NewClassProximityType) > 0 && Trigger.GetPropertyText("TriggerType") ~= "TT_ClassProximity")
			{
				if (ClassProximityType == none)
				{
					ClassProximityType = class<Actor>(DynamicLoadObject(NewClassProximityType, class'Class', true));
					if (ClassProximityType == none)
					{
						LogIniArrError(MutatorName @ "failed to load actor class" @ NewClassProximityType);
						NewClassProximityType = "";
						continue;
					}
				}
				Trigger.ClassProximityType = ClassProximityType;
			}
		}
}

final function Proc_ReplaceUTLevelTeleporters()
{
	local Teleporter Telep;

	RegisterClientPackage();

	foreach AllActors(class'Teleporter', Telep)
		if (Telep.Class == class'Teleporter')
		{
			if (Telep.Tag != '' && Len(Telep.URL) == 0 ||
				Len(Telep.URL) > 0 && InStr(Telep.URL, "/") < 0 && InStr(Telep.URL, "#") < 0)
			{
				class'UMap_SpawnableUTTeleporter'.static.StaticReplaceUTTeleporter(Telep);
			}
		}
}

final function string GetProcedureArgument(string ParamName)
{
	local int i;

	for (i = 0; i < ProcedureParamCount; ++i)
		if (ProcedureParams[i].ParamName == ParamName)
			return ProcedureParams[i].Value;
	return "";
}

final function MapGroupModifyClassActors()
{
	local int i, n;

	IniArrayItemRef.ArrayName = "ModifyClassActors";

	n = Array_Size(UMapGroup.ModifyClassActors);
	for (i = 0; i < n; ++i)
		if (UMapGroup.ModifyClassActors[i].ClassName != "")
		{
			IniArrayItemRef.ArrayIndex = i;

			if (GetConditionalExpressionValue(UMapGroup.ModifyClassActors[i].Condition))
				ModifyActorsOfClass(
					UMapGroup.ModifyClassActors[i].ClassName,
					UMapGroup.ModifyClassActors[i].bIsBaseClass,
					UMapGroup.ModifyClassActors[i].Params);
		}
}

final function ModifyActorsOfClass(
	string ClassName,
	bool bIsBaseClass,
	out array<string> Params)
{
	local class<Actor> ActorClass;
	local name ActorClassName;
	local Actor A;

	if (InStr(ClassName, ".") >= 0)
	{
		ActorClass = class<Actor>(DynamicLoadObject(ClassName, class'Class', true));
		if (ActorClass == none)
		{
			LogIniArrError(MutatorName @ "failed to load actor class" @ ClassName);
			return;
		}

		foreach AllActors(ActorClass, A)
			if (bIsBaseClass || A.Class == ActorClass)
				ModifyActor(A, Params);
	}
	else
	{
		ActorClassName = StringToName(ClassName);
		if (ActorClassName == '')
		{
			LogIniArrError(MutatorName @ "cannot remove actors with empty class name");
			return;
		}

		if (bIsBaseClass)
		{
			foreach AllActors(class'Actor', A)
				if (A.IsA(ActorClassName))
					ModifyActor(A, Params);
		}
		else
		{
			foreach AllActors(class'Actor', A)
				if (A.Class.Name == ActorClassName)
					ModifyActor(A, Params);
		}
	}
}

final function ModifyActor(Actor A, out array<string> Params)
{
	local int i, ParamsN;

	if (A.bScriptInitialized)
		return;

	ParamsN = Array_Size(Params);
	if (ParamsN == 0)
		return;

	ActorModifier = none;
	for (i = 0; i < ParamsN; ++i)
		ApplyActorParam(A, Params[i]);
	ModifyActorNetRelevance(A);
}

final function MapGroupRemoveClassActors()
{
	local int i, n;

	IniArrayItemRef.ArrayName = "RemoveClassActors";

	n = Array_Size(UMapGroup.RemoveClassActors);
	for (i = 0; i < n; ++i)
		if (UMapGroup.RemoveClassActors[i].ClassName != "")
		{
			IniArrayItemRef.ArrayIndex = i;

			if (GetConditionalExpressionValue(UMapGroup.RemoveClassActors[i].Condition))
			{
				ActorClassRemoval.ClassName = UMapGroup.RemoveClassActors[i].ClassName;
				ActorClassRemoval.bIsBaseClass = UMapGroup.RemoveClassActors[i].bIsBaseClass;
				ActorClassRemoval.bIndestructible = UMapGroup.RemoveClassActors[i].bIndestructible;
				ActorClassRemoval.bAlwaysRelevant = UMapGroup.RemoveClassActors[i].bAlwaysRelevant;
				RemoveActorsOfClass();
			}
		}
}

// Uses global var ActorClassRemoval as input
final function RemoveActorsOfClass()
{
	local class<Actor> ActorClass;
	local name ActorClassName;
	local Actor A;

	if (InStr(ActorClassRemoval.ClassName, ".") >= 0)
	{
		ActorClass = class<Actor>(DynamicLoadObject(ActorClassRemoval.ClassName, class'Class', true));
		if (ActorClass == none)
		{
			LogIniArrError(MutatorName @ "failed to load actor class" @ ActorClassRemoval.ClassName);
			return;
		}

		foreach AllActors(ActorClass, A)
			if (ActorClassRemoval.bIsBaseClass || A.Class == ActorClass)
				RemoveClassActor(A);
	}
	else
	{
		ActorClassName = StringToName(ActorClassRemoval.ClassName);
		if (ActorClassName == '')
		{
			LogIniArrError(MutatorName @ "cannot remove actors with empty class name");
			return;
		}

		if (ActorClassRemoval.bIsBaseClass)
		{
			foreach AllActors(class'Actor', A)
				if (A.IsA(ActorClassName))
					RemoveClassActor(A);
		}
		else
		{
			foreach AllActors(class'Actor', A)
				if (A.Class.Name == ActorClassName)
					RemoveClassActor(A);
		}
	}
}

// Uses global var ActorClassRemoval as input
final function RemoveClassActor(Actor A)
{
	if (A.bScriptInitialized)
		return;

	if (A.bNoDelete || A.bStatic)
	{
		if (ActorClassRemoval.bIndestructible)
			EliminateActor(A, ActorClassRemoval.bAlwaysRelevant);
		else if (A.bStatic)
			LogIniArrError(MutatorName @ "failed to remove bStatic actor of class" @
				ActorClassRemoval.ClassName $ ":" @ A);
		else if (A.bNoDelete)
			LogIniArrError(MutatorName @ "failed to remove bNoDelete actor of class" @
				ActorClassRemoval.ClassName $ ":" @ A);
	}
	else
		A.Destroy();
}

final function LoadLevelObjects()
{
	local int i, n;

	IniArrayItemRef.ArrayName = "LoadObject";

	n = Array_Size(UMapChanges.LoadObject);
	for (i = 0; i < n; ++i)
		if (UMapChanges.LoadObject[i].Name != "" && UMapChanges.LoadObject[i].ClassName != "")
		{
			IniArrayItemRef.ArrayIndex = i;
			if (GetConditionalExpressionValue(UMapChanges.LoadObject[i].Condition))
				LoadObjectInMemory(UMapChanges.LoadObject[i].Name, UMapChanges.LoadObject[i].ClassName);
		}
}

final function AddLevelServerPackages()
{
	local int i, n;

	if (Level.NetMode == NM_Standalone)
		return;

	IniArrayItemRef.ArrayName = "ServerPackage";

	n = Array_Size(UMapChanges.ServerPackage);
	for (i = 0; i < n; ++i)
		if (UMapChanges.ServerPackage[i].Name != "")
		{
			IniArrayItemRef.ArrayIndex = i;
			if (GetConditionalExpressionValue(UMapChanges.ServerPackage[i].Condition) &&
				!AddToPackagesMap(UMapChanges.ServerPackage[i].Name))
			{
				LogIniArrError(MutatorName @ "failed to add server package" @ UMapChanges.ServerPackage[i].Name);
			}
		}
}

final function ExecuteLevelProcedures()
{
	local int i, n;

	IniArrayItemRef.ArrayName = "ExecuteProcedure";

	n = Array_Size(UMapChanges.ExecuteProcedure);
	for (i = 0; i < n; ++i)
		if (UMapChanges.ExecuteProcedure[i].Name != "")
		{
			IniArrayItemRef.ArrayIndex = i;
			if (GetConditionalExpressionValue(UMapChanges.ExecuteProcedure[i].Condition))
				ExecuteProcedure(UMapChanges.ExecuteProcedure[i].Name, UMapChanges.ExecuteProcedure[i].Params);
		}
}

final function CreateLevelActors()
{
	local int i, n;
	local int j, ParamsN;
	local class<Actor> ActorClass;
	local vector ActorLocation;
	local rotator ActorRotation;
	local name ActorTag;
	local Actor A;

	IniArrayItemRef.ArrayName = "CreateActor";

	n = Array_Size(UMapChanges.CreateActor);
	for (i = 0; i < n; ++i)
		if (UMapChanges.CreateActor[i].ClassName != "")
		{
			IniArrayItemRef.ArrayIndex = i;

			if (!GetConditionalExpressionValue(UMapChanges.CreateActor[i].Condition))
				continue;

			ActorClass = LoadActorClass(UMapChanges.CreateActor[i].ClassName, true);
			if (ActorClass == none)
			{
				LogIniArrError(MutatorName @ "failed to load class" @ UMapChanges.CreateActor[i].ClassName);
				continue;
			}
			ModifyCreatedActorClass(ActorClass);
			ActorLocation.X = UMapChanges.CreateActor[i].X;
			ActorLocation.Y = UMapChanges.CreateActor[i].Y;
			ActorLocation.Z = UMapChanges.CreateActor[i].Z;
			ActorRotation.Yaw = UMapChanges.CreateActor[i].Yaw;
			if (UMapChanges.CreateActor[i].Tag != "")
				ActorTag = StringToName(UMapChanges.CreateActor[i].Tag);

			ParamsN = Array_Size(UMapChanges.CreateActor[i].Params);
			for (j = 0; j < ParamsN; ++j)
				if (UMapChanges.CreateActor[i].Params[j] == "[=]")
					break;
			if (0 < j && j < ParamsN)
				SetActorPreModification(ActorClass, j);

			ActorModifier = none;

			A = Spawn(ActorClass,, ActorTag, ActorLocation, ActorRotation);

			if (A == none)
			{
				if (Len(UMapChanges.CreateActor[i].IDName) > 0 || ParamsN > 0)
					LogIniArrError(MutatorName @ "failed to spawn an actor of type" @ ActorClass);
				continue;
			}

			for (j = CheckActorPreModification(j, ParamsN, ActorClass); j < ParamsN; ++j)
				ApplyActorParam(A, UMapChanges.CreateActor[i].Params[j]);
			ModifyActorNetRelevance(A);
			AdjustSpawnedActor(A);

			if (Len(UMapChanges.CreateActor[i].IDName) > 0)
			{
				j = Array_Size(ActorsWithIDName);
				ActorsWithIDName[j].Actor = A;
				ActorsWithIDName[j].IDName = UMapChanges.CreateActor[i].IDName;
			}
		}
}

final function ModifyLevelActors()
{
	local int i, n;
	local int j, ParamsN;
	local Actor A;

	IniArrayItemRef.ArrayName = "ModifyActor";

	n = Array_Size(UMapChanges.ModifyActor);
	for (i = 0; i < n; ++i)
		if (Len(UMapChanges.ModifyActor[i].Name) > 0 || Len(UMapChanges.ModifyActor[i].IDName) > 0)
		{
			IniArrayItemRef.ArrayIndex = i;

			if (!GetConditionalExpressionValue(UMapChanges.ModifyActor[i].Condition))
				continue;

			if (Len(UMapChanges.ModifyActor[i].Name) > 0)
				A = LoadLevelActor(UMapChanges.ModifyActor[i].Name, true);
			else
				A = FindActorWithIDName(UMapChanges.ModifyActor[i].IDName);

			if (A == none)
			{
				if (Len(UMapChanges.ModifyActor[i].Name) > 0)
					LogIniArrError(MutatorName @ "failed to load actor" @
						CurrentMap $ "." $ UMapChanges.ModifyActor[i].Name);
				else
					LogIniArrError(MutatorName @ "failed to find actor with IDName" @
						UMapChanges.ModifyActor[i].IDName);
				continue;
			}
			ParamsN = Array_Size(UMapChanges.ModifyActor[i].Params);
			if (ParamsN == 0)
				continue;

			ActorModifier = none;
			for (j = 0; j < ParamsN; ++j)
				ApplyActorParam(A, UMapChanges.ModifyActor[i].Params[j]);
			ModifyActorNetRelevance(A);
		}
}

final function ModifyClassActors()
{
	local int i, n;

	IniArrayItemRef.ArrayName = "ModifyClassActors";

	n = Array_Size(UMapChanges.ModifyClassActors);
	for (i = 0; i < n; ++i)
		if (UMapChanges.ModifyClassActors[i].ClassName != "")
		{
			IniArrayItemRef.ArrayIndex = i;

			if (GetConditionalExpressionValue(UMapChanges.ModifyClassActors[i].Condition))
				ModifyActorsOfClass(
					UMapChanges.ModifyClassActors[i].ClassName,
					UMapChanges.ModifyClassActors[i].bIsBaseClass,
					UMapChanges.ModifyClassActors[i].Params);
		}
}

final function RemoveLevelActors()
{
	local int i, n;
	local Actor A;

	IniArrayItemRef.ArrayName = "RemoveActor";

	n = Array_Size(UMapChanges.RemoveActor);
	for (i = 0; i < n; ++i)
		if (UMapChanges.RemoveActor[i].Name != "")
		{
			IniArrayItemRef.ArrayIndex = i;

			if (!GetConditionalExpressionValue(UMapChanges.RemoveActor[i].Condition))
				continue;

			A = LoadLevelActor(UMapChanges.RemoveActor[i].Name, true);

			if (A == none)
				LogIniArrError(MutatorName @ "failed to load actor" @ CurrentMap $ "." $ UMapChanges.RemoveActor[i].Name);
			else if (A.bNoDelete || A.bStatic)
			{
				if (UMapChanges.RemoveActor[i].bIndestructible)
					EliminateActor(A, UMapChanges.RemoveActor[i].bAlwaysRelevant);
				else if (A.bStatic)
					LogIniArrError(MutatorName @ "failed to remove bStatic actor" @
						CurrentMap $ "." $ UMapChanges.RemoveActor[i].Name);
				else if (A.bNoDelete)
					LogIniArrError(MutatorName @ "failed to remove bNoDelete actor" @
						CurrentMap $ "." $ UMapChanges.RemoveActor[i].Name);
			}
			else
				A.Destroy();
		}
}

final function RemoveClassActors()
{
	local int i, n;

	IniArrayItemRef.ArrayName = "RemoveClassActors";

	n = Array_Size(UMapChanges.RemoveClassActors);
	for (i = 0; i < n; ++i)
		if (UMapChanges.RemoveClassActors[i].ClassName != "")
		{
			IniArrayItemRef.ArrayIndex = i;

			if (GetConditionalExpressionValue(UMapChanges.RemoveClassActors[i].Condition))
			{
				ActorClassRemoval.ClassName = UMapChanges.RemoveClassActors[i].ClassName;
				ActorClassRemoval.bIsBaseClass = UMapChanges.RemoveClassActors[i].bIsBaseClass;
				ActorClassRemoval.bIndestructible = UMapChanges.RemoveClassActors[i].bIndestructible;
				ActorClassRemoval.bAlwaysRelevant = UMapChanges.RemoveClassActors[i].bAlwaysRelevant;
				RemoveActorsOfClass();
			}
		}
}

final function ReplaceLevelActors()
{
	local int i, n;
	local int j, ParamsN;
	local Actor A, NewA;
	local class<Actor> ActorClass;

	IniArrayItemRef.ArrayName = "ReplaceActor";

	n = Array_Size(UMapChanges.ReplaceActor);
	for (i = 0; i < n; ++i)
		if (UMapChanges.ReplaceActor[i].Name != "" && UMapChanges.ReplaceActor[i].ClassName != "")
		{
			IniArrayItemRef.ArrayIndex = i;

			if (!GetConditionalExpressionValue(UMapChanges.ReplaceActor[i].Condition))
				continue;

			A = LoadLevelActor(UMapChanges.ReplaceActor[i].Name, true);
			if (A == none)
			{
				LogIniArrError(MutatorName @ "failed to load actor" @
					CurrentMap $ "." $ UMapChanges.ReplaceActor[i].Name);
				continue;
			}
			ActorClass = LoadActorClass(UMapChanges.ReplaceActor[i].ClassName, true);
			if (ActorClass == none)
			{
				LogIniArrError(MutatorName @ "failed to load class" @ UMapChanges.ReplaceActor[i].ClassName);
				continue;
			}
			ModifyCreatedActorClass(ActorClass);

			if (A.bStatic)
			{
				LogIniArrError(MutatorName @ "failed to replace bStatic actor" @
					CurrentMap $ "." $ UMapChanges.ReplaceActor[i].Name);
				continue;
			}
			if (A.bNoDelete)
			{
				LogIniArrError(MutatorName @ "failed to replace bNoDelete actor" @
					CurrentMap $ "." $ UMapChanges.ReplaceActor[i].Name);
				continue;
			}

			ParamsN = Array_Size(UMapChanges.ReplaceActor[i].Params);
			for (j = 0; j < ParamsN; ++j)
				if (UMapChanges.ReplaceActor[i].Params[j] == "[=]")
					break;
			if (0 < j && j < ParamsN)
				SetActorPreModification(ActorClass, j);

			ActorModifier = none;

			NewA = ReplaceWithC(A, ActorClass);
			if (NewA == none)
				LogIniArrError(MutatorName @ "failed to replace actor" @ A @ "with an actor of type" @ ActorClass);
			A.Destroy();
			A = NewA;

			if (A == none)
				continue;
			for (j = CheckActorPreModification(j, ParamsN, ActorClass); j < ParamsN; ++j)
				ApplyActorParam(A, UMapChanges.ReplaceActor[i].Params[j]);
			ModifyActorNetRelevance(A);
		}
}

final function class<Actor> LoadActorClass(string ClassName, bool bNoFailureWarning)
{
	local class<Actor> Result;

	if (ClassName == "")
		return none;
	if (InStr(ClassName, ".") >= 0)
		return class<Actor>(DynamicLoadObject(ClassName, class'class', bNoFailureWarning));
	Result = GetSpecialActorClass(ClassName);
	if (Result != none)
		return Result;
	Result = class<Actor>(DynamicLoadObject("UnrealI." $ ClassName, class'class', true));
	if (Result != none)
		return Result;
	Result = class<Actor>(DynamicLoadObject("Engine." $ ClassName, class'class', true));
	if (Result != none)
		return Result;
	Result = class<Actor>(DynamicLoadObject("UPak." $ ClassName, class'class', true));
	if (Result == none && !bNoFailureWarning)
		Log("Warning: class" @ ClassName @ "is not found", name);
	return Result;
}

final function class<Object> LoadObjectClass(string ClassName, bool bNoFailureWarning)
{
	local class<Object> Result;

	if (ClassName == "")
		return none;
	if (ClassName ~= "class")
		return class'class';
	if (InStr(ClassName, ".") >= 0)
		return class<Object>(DynamicLoadObject(ClassName, class'class', bNoFailureWarning));
	Result = GetSpecialActorClass(ClassName);
	if (Result != none)
		return Result;
	Result = class<Object>(DynamicLoadObject("UnrealI." $ ClassName, class'class', true));
	if (Result != none)
		return Result;
	Result = class<Object>(DynamicLoadObject("Engine." $ ClassName, class'class', true));
	if (Result != none)
		return Result;
	Result = class<Object>(DynamicLoadObject("UPak." $ ClassName, class'class', true));
	if (Result == none && !bNoFailureWarning)
		Log("Warning: class" @ ClassName @ "is not found", name);
	return Result;
}

final function Actor LoadLevelActor(string ActorName, bool bNoFailureWarning)
{
	return Actor(DynamicLoadObject(CurrentMap $ "." $ ActorName, class'Actor', bNoFailureWarning));
}

final function Actor FindActorWithIDName(string IDName)
{
	local int i, n;

	n = Array_Size(ActorsWithIDName);
	for (i = 0; i < n; ++i)
		if (ActorsWithIDName[i].IDName ~= IDName)
			return ActorsWithIDName[i].Actor;
	return none;
}

final function ApplyActorParam(Actor A, string Param)
{
	local int AssignmentPos;
	local int LParenPos, RParenPos;
	local int ColonPos;
	local int DelimPos;

	if (Param == "[=]")
		return;

	LParenPos = InStr(Param, "(");
	AssignmentPos = InStr(Param, "=");
	ColonPos = InStr(Param, ":");

	if (AssignmentPos > 0 && (LParenPos < 0 || AssignmentPos < LParenPos))
	{
		if (ColonPos == AssignmentPos - 1)
			DelimPos = ColonPos;
		else
			DelimPos = AssignmentPos;
		if (DelimPos > 0)
		{
			ActorModifierBase.SetActorProperty(A, Left(Param, DelimPos), Mid(Param, AssignmentPos + 1));
			if (DelimPos == ColonPos && Level.NetMode != NM_Standalone)
				AddClientActorModification(A, Param);
			return;
		}
	}
	else if (LParenPos > 0)
	{
		RParenPos = InStr(Param, ")");
		if (RParenPos > LParenPos)
		{
			if (ColonPos == LParenPos - 1)
				DelimPos = ColonPos;
			else
				DelimPos = LParenPos;
			if (DelimPos > 0)
			{
				ActorModifierBase.CallActorFunction(A, Left(Param, DelimPos), Mid(Param, LParenPos + 1, RParenPos - LParenPos - 1));
				if (DelimPos == ColonPos && Level.NetMode != NM_Standalone)
					AddClientActorModification(A, Param);
				return;
			}
		}
	}

	LogIniArrError("Invalid actor modifier:" @ Param);
}

final function AddClientActorModification(Actor A, string Param)
{
	if (ActorModifier == none)
	{
		RegisterClientPackage();
		ActorModifier = Spawn(class'UMapActorModifier');
		if (ActorModifier == none)
			return;
		ActorModifier.AssignActor(A);
	}
	ActorModifier.AddParam(Param);
}

final function ModifyActorNetRelevance(Actor A)
{
	if (ActorModifier != none && !A.bStatic)
	{
		A.bAlwaysRelevant = true;
		if (A.NetPriority < class'UMapActorModifier'.default.NetPriority + 1)
			A.NetPriority = class'UMapActorModifier'.default.NetPriority + 1;
	}
}

final function AdjustSpawnedActor(Actor A)
{
	if (UMap_TravelPlayerStart(A) != none)
		AdjustTravelPlayerStart(UMap_TravelPlayerStart(A));
	else
		bNonTravelPlayerStartsDisabled = false;
}

final function AdjustTravelPlayerStart(UMap_TravelPlayerStart A)
{
	local Teleporter Telep;

	if (A.TravelTag == '')
	{
		Telep = GetStartTeleporter();
		if (Telep == none)
		{
			A.Destroy();
			return;
		}
		A.SetLocation(Telep.Location);
		DisableNonTravelPlayerStarts();
	}
	else if (!(GetIncomingTag() ~= string(A.TravelTag)))
		A.Destroy();
	else
		DisableNonTravelPlayerStarts();
}

final function DisableNonTravelPlayerStarts()
{
	local PlayerStart PStart;

	if (bNonTravelPlayerStartsDisabled)
		return;
	foreach AllActors(class'PlayerStart', PStart)
		if (UMap_TravelPlayerStart(PStart) == none)
		{
			PStart.bCoopStart = false;
			PStart.bSinglePlayerStart = false;
			PStart.bEnabled = false;
		}
	bNonTravelPlayerStartsDisabled = true;
}

final function EliminateActor(Actor A, bool bMakeAlwaysRelevant)
{
	local UMapActorElimination ActorElimination;

	if (A.bStatic && Level.NetMode != NM_Standalone)
	{
		RegisterClientPackage();
		ActorElimination = A.Spawn(class'UMapActorElimination');
		if (ActorElimination != none)
			ActorElimination.AssignActor(A);
	}

	class'UMapActorElimination'.static.EliminateActor(A);

	if (bMakeAlwaysRelevant && Level.NetMode != NM_Standalone && !A.bStatic)
		A.bAlwaysRelevant = true;
}

final function class<Actor> GetSpecialActorClass(string ClassName)
{
	local class<Actor> Result;

	if (!(Left(ClassName, 5) ~= "UMap_"))
		return none;

	Result = class<Actor>(DynamicLoadObject(ClientPackageName() $ "." $ ClassName, class'class', true));
	if (Result != none)
		return Result;
	return class<Actor>(DynamicLoadObject(MutatorName $ "." $ ClassName, class'class', true));
}

final function ModifyCreatedActorClass(out class<Actor> ActorClass)
{
	local class<Actor> ModifiedActorClass;

	if (ActorClass == class'BlockAll')
		ModifiedActorClass = class'UMap_SpawnableBlockAll';
	else if (ActorClass == class'PlayerStart')
		ModifiedActorClass = class'UMap_SpawnablePlayerStart';
	else if (ActorClass == class'Teleporter')
		ModifiedActorClass = class'UMap_SpawnableTeleporter';
	else if (ActorClass == class'VisibilityNotify')
		ModifiedActorClass = class'UMap_SpawnableVisibilityNotify';

	if (ModifiedActorClass != none)
	{
		ActorClass = ModifiedActorClass;
		if (ModifiedActorClass.Outer != Class.Outer)
			RegisterClientPackage();
	}
}

function string GetIncomingTag()
{
	local string S;
	local int Offset;

	S = Level.GetLocalURL();

	while (true)
	{
		Offset = InStr(S, "#");
		if (Offset < 0)
			return "";
		S = Mid(S, Offset + 1);

		Offset = InStr(S, "?");
		if (Offset < 0)
			return S;
		S = Mid(S, Offset + 1);
	}
	return "";
}

function Teleporter GetStartTeleporter()
{
	local string IncomingTag;
	local Teleporter Telep;

	IncomingTag = GetIncomingTag();
	if (IncomingTag == "")
		return none;

	foreach AllActors(class'Teleporter', Telep)
		if (string(Telep.Tag) ~= IncomingTag)
			return Telep;
}

final function Actor ReplaceWithC(Actor Src, class<Actor> ActorClass)
{
	local Actor Dst;
	local bool bNonBlockingActors;

	if (Level.Game.Difficulty == 0 && !Src.bDifficulty0 ||
		Level.Game.Difficulty == 1 && !Src.bDifficulty1 ||
		Level.Game.Difficulty == 2 && !Src.bDifficulty2 ||
		Level.Game.Difficulty >= 3 && !Src.bDifficulty3 ||
		!Src.bSinglePlayer && Level.NetMode == NM_Standalone || 
		!Src.bNet && (Level.NetMode == NM_DedicatedServer || Level.NetMode == NM_ListenServer))
	{
		return none;
	}

	if (Src.Instigator != none &&
		Src.Location == Src.Instigator.Location &&
		Inventory(Src) != none)
	{
		if (Src.Instigator.PlayerReplicationInfo == none)
			GiveInventoryToCreature(Src.Instigator, class<Inventory>(ActorClass));
		return none;
	}

	bNonBlockingActors = !Src.bBlockActors && !Src.bBlockPlayers && !Src.bProjTarget &&
		!ActorClass.default.bBlockActors && ActorClass.default.bBlockPlayers && !ActorClass.default.bProjTarget;

	Src.SetCollision(false);

	Dst = Src.Spawn(ActorClass, Src.Owner, Src.Tag);

	if (Dst == none)
		return none;

	if (bNonBlockingActors && Src.CollisionRadius != Src.default.CollisionRadius)
		Dst.SetCollisionSize(Src.CollisionRadius, Dst.CollisionHeight);

	if (bNonBlockingActors && Src.CollisionHeight != Src.default.CollisionHeight)
		Dst.SetCollisionSize(Dst.CollisionRadius, Src.CollisionHeight);
	else if (Src.bCollideWorld && Dst.bCollideWorld || Inventory(Src) != none && Inventory(Dst) != none)
		Dst.Move((Dst.CollisionHeight - Src.CollisionHeight) * vect(0, 0, 1));

	Dst.Event = Src.Event;

	if (Inventory(Src) != none)
		CopyInventoryProperties(Inventory(Src), Inventory(Dst)); // Inventory(Dst) may be none
	else if (Src.bIsPawn && Dst.bIsPawn)
		CopyPawnProperties(Pawn(Src), Pawn(Dst));

	return Dst;
}

final function GiveInventoryToCreature(Pawn P, class<Inventory> InventoryClass)
{
	local Inventory Inv;
	local Weapon Weap;
	local sound PickupSound, SelectSound;

	if (InventoryClass == none)
		return;
	Inv = P.Spawn(InventoryClass);
	if (Inv == none || Inv.bDeleteMe)
		return;
	Weap = Weapon(Inv);

	PickupSound = Inv.PickupSound;
	Inv.PickupSound = none;
	if (Weap != none)
	{
		SelectSound = Weap.SelectSound;
		Weap.SelectSound = none;
	}
	P.Touch(Inv);
	if (Inv.Owner != P)
		Inv.Touch(P);
	if (Inv.Owner != P)
	{
		Inv.Destroy();
		return;
	}
	Inv.PickupSound = PickupSound;
	if (Weap != none)
		Weap.SelectSound = SelectSound;
}

final function CopyInventoryProperties(Inventory Src, Inventory Dst)
{
	if (Src.MyMarker != none)
	{
		Src.MyMarker.markedItem = Dst;
		if (Dst != none)
			Dst.MyMarker = Src.MyMarker;
		Src.MyMarker = none;
	}
	if (Dst != none)
	{
		Dst.RotationRate = Src.RotationRate;
		if (Src.bHeldItem)
		{
			Dst.bHeldItem = true;
			Dst.Respawntime = 0;
		}
		else if (Src.RespawnTime == 0)
			Dst.RespawnTime = 0;
	}
}

final function CopyPawnProperties(Pawn Src, Pawn Dst)
{
	// AI
	Dst.AttitudeToPlayer = Src.AttitudeToPlayer;

	// Orders
	Dst.AlarmTag = Src.AlarmTag;
	Dst.SharedAlarmTag = Src.SharedAlarmTag;

	// Pawn
	if (Src.DropWhenKilled != none)
		Dst.DropWhenKilled = Src.DropWhenKilled;

	if (ScriptedPawn(Src) != none && ScriptedPawn(Dst) != none)
		CopyScriptedPawnProperties(ScriptedPawn(Src), ScriptedPawn(Dst));
}

final function CopyScriptedPawnProperties(ScriptedPawn Src, ScriptedPawn Dst)
{
	// AI
	Dst.bHateWhenTriggered = Src.bHateWhenTriggered;
	Dst.bTeamLeader = Src.bTeamLeader;
	Dst.FirstHatePlayerEvent = Src.FirstHatePlayerEvent;
	Dst.TeamTag = Src.TeamTag;

	// Orders
	Dst.bDelayedPatrol = Src.bDelayedPatrol;
	Dst.bNoWait = Src.bNoWait;
	Dst.Orders = Src.Orders;
	Dst.OrderTag = Src.OrderTag;
}

final function SetActorPreModification(class<Actor> ActorClass, int ParamsN)
{
	if (ActorClass.default.bGameRelevant)
		ActorClass.default.bGameRelevant = false;
	ActorPreModification.ActorClass = ActorClass;
	ActorPreModification.ParamsN = ParamsN;
}

final function PreModifyActor(Actor A)
{
	local int i;

	if (IniArrayItemRef.ArrayName == "CreateActor")
	{
		for (i = 0; i < ActorPreModification.ParamsN; ++i)
			ApplyActorParam(A, UMapChanges.CreateActor[IniArrayItemRef.ArrayIndex].Params[i]);
	}
	else if (IniArrayItemRef.ArrayName == "ReplaceActor")
	{
		for (i = 0; i < ActorPreModification.ParamsN; ++i)
			ApplyActorParam(A, UMapChanges.ReplaceActor[IniArrayItemRef.ArrayIndex].Params[i]);
	}
	else
		LogInternalMutatorError("PreModifyActor", "Unknown ArrayName:" @ IniArrayItemRef.ArrayName);
	ActorPreModification.ParamsN = 0;
}

final function int CheckActorPreModification(int i, int ParamsN, class<Actor> ActorClass)
{
	if (i == ParamsN)
		return 0;
	if (0 < i && i < ParamsN && ActorPreModification.ParamsN > 0)
	{
		ActorPreModification.ParamsN = 0;
		LogIniArrError("Cannot modify actor of type" @ ActorClass @ "during execution of PreBeginPlay");
		return 0;
	}
	ActorPreModification.ParamsN = 0;
	return i + 1;
}

final function bool GetConditionalExpressionValue(string Expression)
{
	local int ErrorCode;

	if (Len(Expression) == 0)
		return true;
	TrimStr(Expression);
	if (Len(Expression) == 0)
		return true;

	if (ConditionalExpressionValue(Expression, 0, ErrorCode) != 0 && ErrorCode == 0)
		return true;
	else if (ErrorCode > 0)
	{
		if (ErrorCode == 1)
			LogIniArrError(MutatorName @ "detected a syntax error in Expression" @ Expression);
		else if (ErrorCode == 2)
			LogIniArrError(MutatorName @ "cannot parse overly complicated Expression" @ Expression);
		else
			LogIniArrError(MutatorName @ "detected an error in Expression" @ Expression);
	}
	return false;
}

final function int ConditionalExpressionValue(string Expression, int RecursionDepth, out int ErrorCode)
{
	local int i, n, c;
	local int OrPos, AndPos;
	local int LLParenPos, RRParenPos, Nesting;

	if (RecursionDepth > MaxRecursionDepth)
		return CondExprErrorReturnValue(ErrorCode, 2);

	OrPos = -1;
	AndPos = -1;
	LLParenPos = -1;
	RRParenPos = -1;
	Nesting = 0;

	TrimStr(Expression);
	n = Len(Expression);

	if (n == 0)
		CondExprErrorReturnValue(ErrorCode, 1);

	// find RightOperandEnd
	for (i = n - 1; i >= 0; --i)
	{
		c = Asc(Mid(Expression, i, 1));
		if (c == CHARCODE_LParen)
		{
			--Nesting;
			LLParenPos = i;
			if (Nesting < 0)
				return CondExprErrorReturnValue(ErrorCode, 1);
		}
		else if (c == CHARCODE_RParen)
		{
			++Nesting;
			if (RRParenPos < 0)
				RRParenPos = i;
		}
		else if (Nesting == 0)
		{
			if (c == CHARCODE_Or)
			{
				if (OrPos < 0)
					OrPos = i;
			}
			else if (c == CHARCODE_And)
			{
				if (AndPos < 0)
					AndPos = i;
			}
		}
	}
	if (Nesting != 0)
		return CondExprErrorReturnValue(ErrorCode, 1);
	if (OrPos >= 0)
		return ConditionalExpressionValue(Left(Expression, OrPos), RecursionDepth + 1, ErrorCode) |
			ConditionalExpressionValue(Mid(Expression, OrPos + 1), RecursionDepth + 1, ErrorCode);
	if (AndPos >= 0)
		return ConditionalExpressionValue(Left(Expression, AndPos), RecursionDepth + 1, ErrorCode) &
			ConditionalExpressionValue(Mid(Expression, AndPos + 1), RecursionDepth + 1, ErrorCode);
	if (Left(Expression, 1) == STR_Not)
		return int(ConditionalExpressionValue(Mid(Expression, 1), RecursionDepth + 1, ErrorCode) == 0);
	if (LLParenPos > 0 || RRParenPos > 0 && RRParenPos < n - 1)
		return CondExprErrorReturnValue(ErrorCode, 1);
	if (LLParenPos == 0)
		return ConditionalExpressionValue(Mid(Expression, 1, n - 2), RecursionDepth + 1, ErrorCode);

	return int(FindModOption(Expression));
}

final function bool FindModOption(string OptionName)
{
	local int i;

	for (i = 0; i < ModOptionCount; ++i)
		if (ModOptions[i] ~= OptionName)
			return true;
	if (StrStartsWith(OptionName, "$"))
	{
		if (OptionName ~= "$net_game")
			return Level.NetMode != NM_Standalone;
		if (StrStartsWith(OptionName, "$difficulty"))
			return OptionName ~= ("$difficulty" $ Clamp(Level.Game.Difficulty, 0, 3));
	}
	return false;
}

final function int CondExprErrorReturnValue(out int ErrorCode, int ErrorCodeValue)
{
	ErrorCode = ErrorCodeValue;
	return 0;
}

final function bool StrStartsWith(coerce string Str, coerce string SubStr, optional bool bCaseInsensitive)
{
	if (bCaseInsensitive)
		return Left(Str, Len(SubStr)) ~= SubStr;
	return Left(Str, Len(SubStr)) == SubStr;
}

final static function TrimStr(out string Str)
{
	local int StrLen;

	while (InStr(Str, " ") == 0)
		Str = Mid(Str, 1);
	while (true)
	{
		StrLen = Len(Str);
		if (StrLen == 0 || Mid(Str, StrLen - 1, 1) != " ")
			break;
		Str = Left(Str, StrLen - 1);
	}
}

final function LogIniArrError(string Message)
{
	Log("Warning:" @ Message, name);
	Log(
		"    specified in" @ GetIniArrSectionHeader() @ IniArrayItemRef.ArrayName $ "[" $ IniArrayItemRef.ArrayIndex $ "]",
		name);
}

final function string GetIniArrSectionHeader()
{
	if (IsUnreal227jPlus())
		return "[" $ IniArrayItemRef.ArrayModObject.Class.Name @ IniArrayItemRef.ArrayModObject.Name $ "]";
	return "[" $ IniArrayItemRef.ArrayModObject.Name $ "]";
}

final function LogInternalMutatorError(string FunctionName, string Message)
{
	Log("Internal error in" @ class $ "." $ FunctionName $ ":" @ Message, name);
}

final static function string ClientPackageName()
{
	local class<Actor> ClientClass;
	ClientClass = class'UMap_SpawnablePlayerStart';
	return string(ClientClass.outer.name);
}

final function RegisterClientPackage()
{
	if (Level.NetMode == NM_Standalone || bClientPackageIsRegistered)
		return;

	AddToPackagesMap(ClientPackageName());
	bClientPackageIsRegistered = true;
}

final function name GetMapSectionName(name MapName)
{
	local int i, n;
	local string MapNameStr;

	MapNameStr = string(MapName);

	n = Array_Size(UMapModInfo.MapAlias);
	for (i = 0; i < n; ++i)
		if (UMapModInfo.MapAlias[i].MapName ~= MapNameStr && Len(UMapModInfo.MapAlias[i].Alias) > 0)
		{
			MapNameStr = UMapModInfo.MapAlias[i].Alias;
			break;
		}
	if (IsUnreal227jPlus())
		return StringToName(MapNameStr);
	return StringToName("UMapChanges_" $ MapNameStr);
}

final function name GetMapGroupSectionName(string MapGroupName)
{
	if (IsUnreal227jPlus())
		return StringToName(MapGroupName);
	return StringToName("UMapGroup_" $ MapGroupName);
}

final function AddUniqueMutator(string MutatorClassName)
{
	local class<Mutator> MutatorClass;
	local Mutator Mutator;

	MutatorClass = class<Mutator>(LoadActorClass(MutatorClassName, true));
	if (MutatorClass == none)
		LogIniArrError(MutatorName @ "failed to load mutator class" @ MutatorClassName);
	else
	{
		foreach AllActors(class'Mutator', Mutator)
			if (Mutator.Class == MutatorClass)
				return;
		Mutator = Spawn(MutatorClass);
		if (Mutator != none)
			AddMutator(Mutator);
		else
			LogIniArrError(MutatorName @ "failed to spawn a mutator of class" @ MutatorClassName);
	}
}

final static function SwitchToNextLevel(LevelInfo Level, string URL, bool bItems)
{
	local Teleporter Telep;

	if (Len(URL) == 0)
	{
		foreach Level.AllActors(class'Teleporter', Telep)
			if (InStr(Telep.URL, "/") > 0 || InStr(Telep.URL, "#") > 0)
			{
				URL = Telep.URL;
				break;
			}
	}
	else if (InStr(URL, "/") <= 0 && InStr(URL, "#") <= 0)
		return;

	if (Len(URL) == 0)
		return;

	if (Level.NetMode == NM_Standalone)
		Level.GetLocalPlayerPawn().ClientTravel(URL, TRAVEL_Relative, bItems);
	else
		Level.ServerTravel(URL, bItems);
}

final function bool IsUnreal227jPlus()
{
	return int(Level.EngineVersion) == 227 && int(Level.EngineSubVersion) >= 10 || int(Level.EngineVersion) > 227;
}

function string GetHumanName()
{
	return "UMapMod v9.4";
}

defaultproperties
{
	UMapChangesClass=Class'UMapMod.UMapChanges'
	UMapGroupClass=Class'UMapMod.UMapGroup'
	UMapModInfoClass=Class'UMapMod.UMapModInfo'
	VersionInfo="UMapMod v9.4 [2023-06-17]"
	Version="9.4"
}
