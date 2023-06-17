class UMapActorModifier expands UMapActorModifierBase;

var private Actor ActorRef;
var private string Params;

const ParamListDelimiterCode = 0xFFFF;

replication
{
	reliable if (Role == ROLE_Authority)
		ActorRef,
		Params;
}

final function AssignActor(Actor A)
{
	ActorRef = A;
}

final function AddParam(string Param)
{
	if (Len(Params) == 0)
		Params = Param;
	else
		Params = Params $ Chr(ParamListDelimiterCode) $ Param;
}

final simulated function ModifyActorParams(Actor A)
{
	local int DelimPos;
	local string DelimChar;

	if (A == none || A.bDeleteMe || Len(Params) == 0)
		return;

	if (GameInfo(A) != none ||
		GameReplicationInfo(A) != none ||
		PlayerPawn(A) != none)
	{
		return;
	}

	DelimChar = Chr(ParamListDelimiterCode);

	while (Len(Params) > 0)
	{
		DelimPos = InStr(Params, DelimChar);
		if (DelimPos > 0)
			ApplyActorParam(A, Left(Params, DelimPos));
		else if (DelimPos < 0)
		{
			ApplyActorParam(A, Params);
			return;
		}
		Params = Mid(Params, DelimPos + 1);
	}
}

final simulated function ApplyActorParam(Actor A, string Param)
{
	local int AssignmentPos;
	local int CallingPos;
	local int RParenPos;

	AssignmentPos = InStr(Param, ":=");
	CallingPos = InStr(Param, ":(");

	if (AssignmentPos > 0 && (CallingPos < 0 || AssignmentPos < CallingPos))
		SetActorProperty(
			A,
			Left(Param, AssignmentPos),
			Mid(Param, AssignmentPos + 2));
	else if (CallingPos > 0)
	{
		RParenPos = InStr(Param, ")");
		if (RParenPos > CallingPos)
			CallActorFunction(
				A,
				Left(Param, CallingPos),
				Mid(Param, CallingPos + 2, RParenPos - CallingPos - 2));
	}
}

simulated event Tick(float DeltaTime)
{
	if (Level.NetMode == NM_Client)
	{
		ModifyActorParams(ActorRef);
		Disable('Tick');
	}
	else if (ActorRef == none || ActorRef.bDeleteMe)
		Destroy();
}

defaultproperties
{
	bAlwaysRelevant=True
	NetPriority=1
	RemoteRole=ROLE_SimulatedProxy
}
