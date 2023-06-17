class UMapActorModifierBase expands Info;

var private vector VectorTmp;
var private EPhysics ActorPhysicsTmp;

final simulated function vector ConvertStringToVector(string S)
{
	SetPropertyText("VectorTmp", S);
	return VectorTmp;
}

final simulated function EPhysics ConvertStringToPhysics(string PhysicsName)
{
	SetPropertyText("ActorPhysicsTmp", PhysicsName);
	return ActorPhysicsTmp;
}

final simulated function SetActorProperty(Actor A, string PropertyName, string Value)
{
	if (Len(PropertyName) == 0)
		return;
	else if (PropertyName ~= "bBlockActors")
		A.SetCollision(A.bCollideActors, bool(Value), A.bBlockPlayers);
	else if (PropertyName ~= "bBlockPlayers")
		A.SetCollision(A.bCollideActors, A.bBlockActors, bool(Value));
	else if (PropertyName ~= "bCollideActors")
		A.SetCollision(bool(Value), A.bBlockActors, A.bBlockPlayers);
	else if (PropertyName ~= "CollisionHeight")
		A.SetCollisionSize(A.CollisionRadius, float(Value));
	else if (PropertyName ~= "CollisionRadius")
		A.SetCollisionSize(float(Value), A.CollisionHeight);
	else if (PropertyName ~= "Location")
		A.SetLocation(ConvertStringToVector(Value));
	else if (PropertyName ~= "Physics")
		A.SetPhysics(ConvertStringToPhysics(Value));
	else if (PropertyName ~= "Rotation")
		A.SetRotation(rotator(Value));
	else if (PropertyName ~= "Class" || PropertyName ~= "Name")
		{} // no effect
	else
		A.SetPropertyText(PropertyName, Value);
}

final simulated function CallActorFunction(Actor A, string FunctionName, string ArgList)
{
	local array<string> Args;
	local int DelimPos, ArgCount;

	TrimStr(ArgList);
	while (Len(ArgList) > 0)
	{
		DelimPos = InStr(ArgList, ",");
		if (DelimPos < 0)
		{
			Args[ArgCount] = ArgList;
			ArgList = "";
		}
		else
		{
			Args[ArgCount] = Left(ArgList, DelimPos);
			ArgList = Mid(ArgList, DelimPos + 1);
		}
		TrimStr(Args[ArgCount++]);
	}

	CallActorFunctionWith(A, FunctionName, Args, ArgCount);
}

final simulated function CallActorFunctionWith(Actor A, string FunctionName, out array<string> Args, int ArgCount)
{
	if (FunctionName ~= "GotoState")
		CallActorFunction_GotoState(A, FunctionName, Args, ArgCount);
	else if (FunctionName ~= "SetTimer" && ArgCount == 2)
		A.SetTimer(float(Args[0]), bool(Args[1]));
}

final simulated function CallActorFunction_GotoState(Actor A, string FunctionName, out array<string> Args, int ArgCount)
{
	local name StateName, LabelName;

	if (ArgCount == 0)
		A.GotoState();
	else if (ArgCount == 1 && GetNameFromFunctionArg(Args[0], StateName))
		A.GotoState(StateName);
	else if (ArgCount == 2 && Len(Args[0]) == 0 && GetNameFromFunctionArg(Args[1], LabelName))
		A.GotoState(, LabelName);
	else if (ArgCount == 2 && GetNameFromFunctionArg(Args[0], StateName) && GetNameFromFunctionArg(Args[1], LabelName))
		A.GotoState(StateName, LabelName);
}

final static function bool GetNameFromFunctionArg(string Arg, out name Result)
{
	if (Left(Arg, 1) == "'" && Right(Arg, 1) == "'")
	{
		Result = StringToName(Mid(Arg, 1, Len(Arg) - 2));
		return true;
	}
	return false;
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

