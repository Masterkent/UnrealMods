class UMapActorElimination expands Info;

var private Actor ActorRef;

replication
{
	reliable if (Role == ROLE_Authority)
		ActorRef;
}

final function AssignActor(Actor A)
{
	ActorRef = A;
}

static function EliminateActor(Actor A)
{
	A.SetCollision(false);
	A.AmbientSound = none;
	A.Event = '';
	A.LightType = LT_None;
	A.Tag = '';

	if (A.Level.NetMode != NM_Client)
		A.RemoteRole = ROLE_DumbProxy;

	if (Brush(A) != none)
	{
		if (A.Brush != none)
		{
			A.bHidden = false;
			A.DrawType = DT_Brush;
		}
		else
			A.bHidden = true;
		A.SetLocation(vect(0, 0, -100000.0));
		A.bAlwaysRelevant = true;
	}
	else
		A.DrawType = DT_None;

	if (PlayerStart(A) != none)
	{
		PlayerStart(A).bCoopStart = false;
		PlayerStart(A).bSinglePlayerStart = false;
		PlayerStart(A).bEnabled = false;
	}
}

static function bool IsBlockingActor(Actor A)
{
	if (!A.bCollideActors)
		return false;
	if (A.bBlockActors ||
		A.bBlockPlayers ||
		A.bProjTarget ||
		bool(A.GetPropertyText("bWorldGeometry")))
	{
		return true;
	}

	return false;
}

simulated event Tick(float DeltaTime)
{
	if (Level.NetMode == NM_Client)
	{
		if (ActorRef != none)
		{
			EliminateActor(ActorRef);
			Disable('Tick');
		}
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
