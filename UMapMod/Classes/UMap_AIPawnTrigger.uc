class UMap_AIPawnTrigger expands Trigger;

var() string TriggerName;
var() int MinIntelligence; // for ScriptedPawns only

var private array<Pawn> TriggeredPawns;
var private int TriggeredPawnCount; // Is used instead of Array_Size(TriggeredPawns), because 227i's Array_Size causes memory leaks

function bool IsRelevant(Actor Other)
{
	if (!bInitiallyActive || !Other.bIsPawn)
		return false;
	if (ScriptedPawn(Other) != none && Pawn(Other).Intelligence >= MinIntelligence)
		return true;
	if (Other.IsA('Bot') || Other.IsA('Bots'))
		return true;
	return false;
}

function Actor SpecialHandling(Pawn Other)
{
	local Pawn P;

	if (bTriggerOnceOnly && !bCollideActors)
		return None;

	if (!bInitiallyActive)
	{
		if (TriggerActor == None)
			FindTriggerActor();
		if (TriggerActor == None)
			return None;
		if (TriggerActor2 != None &&
			VSize(TriggerActor2.Location - Other.Location) < VSize(TriggerActor.Location - Other.Location))
		{
			return TriggerActor2;
		}
		else
			return TriggerActor;
	}

	// can other trigger it right away?
	if (IsRelevant(Other))
	{
		foreach TouchingActors(class'Pawn', P)
			if (P == Other)
			{
				Touch(Other);
				UnTouch(Other);
				break;
			}
		return self;
	}

	return self;
}

event Touch(Actor Other)
{
	local Actor A;
	local Pawn InstigatorPawn;

	if (IsRelevant(Other))
	{
		if (ReTriggerDelay > 0)
		{
			if (Level.TimeSeconds - TriggerTime < ReTriggerDelay)
				return;
			TriggerTime = Level.TimeSeconds;
		}

		// Broadcast the Trigger message to all matching actors.
		if (Event != '')
			foreach AllActors(class 'Actor', A, Event)
				A.Trigger(Other, Other.Instigator);

		InstigatorPawn = Pawn(Other);
		AddTriggeredPawn(InstigatorPawn);

		if (InstigatorPawn.SpecialGoal == self)
			InstigatorPawn.SpecialGoal = none;

		if (RepeatTriggerTime > 0)
			SetTimer(RepeatTriggerTime, false);
	}
}

event UnTouch(Actor Other)
{
	local Actor A;

	if (RemoveTriggeredPawn(Pawn(Other)))
	{
		// Untrigger all matching actors.
		if (Event != '')
			foreach AllActors(class 'Actor', A, Event)
				A.UnTrigger(Other, Other.Instigator);
	}
}

event Timer()
{
	local bool bKeepTiming;
	local Pawn P;

	bKeepTiming = false;

	foreach TouchingActors(class'Pawn', P)
		if (IsRelevant(P))
		{
			bKeepTiming = true;
			Touch(P);
			UnTouch(P);
		}

	if (bKeepTiming)
		SetTimer(RepeatTriggerTime, false);
}

event Tick(float DeltaTime)
{
	InitTrigger();
	Disable('Tick');
}

function InitTrigger()
{
	local Trigger SourceTrigger;

	if (Len(TriggerName) > 0)
		SourceTrigger = Trigger(DynamicLoadObject(Outer.Name $ "." $ TriggerName, class'Trigger', true));
	if (SourceTrigger == none)
	{
		Destroy();
		return;
	}

	if (GetStateName() != SourceTrigger.GetStateName())
		GotoState(SourceTrigger.GetStateName());
	SetLocation(SourceTrigger.Location);
	SetCollision(true);
	SetCollisionSize(SourceTrigger.CollisionRadius, SourceTrigger.CollisionHeight);
	bInitiallyActive = SourceTrigger.bInitiallyActive;
	Event = SourceTrigger.Event;
}

function AddTriggeredPawn(Pawn P)
{
	local int i;

	for (i = 0; i < TriggeredPawnCount; ++i)
		if (TriggeredPawns[i] == none)
		{
			TriggeredPawns[i] = P;
			return;
		}

	TriggeredPawns[TriggeredPawnCount++] = P;
}

function bool RemoveTriggeredPawn(Pawn P)
{
	local int i;

	// Note: TriggeredPawns may contain P more than once
	for (i = 0; i < TriggeredPawnCount; ++i)
		if (TriggeredPawns[i] == P)
		{
			TriggeredPawns[i] = none;
			return true;
		}
	return false;
}

defaultproperties
{
	bCollideActors=False
	MinIntelligence=2 // BRAINS_MAMMAL
	RepeatTriggerTime=0.5
}
