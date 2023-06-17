class UMap_SpawnableTeleporter expands Teleporter;

// base class implementation must be overridden
event PostBeginPlay() {}

event Touch(Actor A)
{
	if (URL != "")
		super.Touch(A);
}

function ReplaceTeleporter(Teleporter OldTelep)
{
	URL = OldTelep.URL;
	Tag = OldTelep.Tag;
	SetCollision(OldTelep.bCollideActors, OldTelep.bBlockActors, OldTelep.bBlockPlayers);
	SetCollisionSize(OldTelep.CollisionRadius, OldTelep.CollisionHeight);
	bChangesVelocity = OldTelep.bChangesVelocity;
	bChangesYaw = OldTelep.bChangesYaw;
	bReversesX = OldTelep.bReversesX;
	bReversesY = OldTelep.bReversesY;
	bReversesZ = OldTelep.bReversesZ;
	bEnabled = OldTelep.bEnabled;
	TargetVelocity = OldTelep.TargetVelocity;
	if (Len(URL) == 0)
		SetCollision(false, false, false); // destination only

	OldTelep.Tag = '';
	OldTelep.URL = "";
	OldTelep.SetCollision(false);
}

defaultproperties
{
	bStatic=False
	bCollideWhenPlacing=False
}