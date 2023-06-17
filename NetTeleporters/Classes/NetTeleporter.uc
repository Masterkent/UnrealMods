class NetTeleporter expands Teleporter;

var bool bPostTouchSupported;
var bool bNonSimulated;
var float LastTeleportationTimestamp;

var byte RepFlags;
var int RepRotationYaw;
var vector RepTargetVelocity;
var name RepTag;
var string RepURL;

replication
{
	reliable if (Role == ROLE_Authority)
		RepFlags,
		RepRotationYaw,
		RepTargetVelocity,
		RepTag,
		RepURL;
}

simulated event PostBeginPlay()
{
	if (!bPostTouchSupported)
	{
		bPostTouchSupported = DynamicLoadObject("Engine.Actor.SetPendingTouch", class'Function', true) != none;
		default.bPostTouchSupported = bPostTouchSupported;
	}
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

static function NetTeleporter StaticReplaceTeleporter(Teleporter OldTelep)
{
	local NetTeleporter NewTelep;

	if (OldTelep == none)
		return none;

	NewTelep = OldTelep.Spawn(class'NetTeleporter',, OldTelep.Tag);
	if (NewTelep == none)
		return none;

	NewTelep.ReplaceTeleporter(OldTelep);
	return NewTelep;
}

simulated function bool Accept(Actor Incoming)
{
	local rotator NewRot, NewVelRot;
	local Pawn P;

	if (Level.NetMode == NM_Client && !bPostTouchSupported && !CheckTeleportationDelay(Incoming))
		return false;

	Disable('Touch');
	NewRot = Incoming.Rotation;

	if (bChangesYaw)
	{
		NewVelRot = rotator(Incoming.Velocity);
		NewVelRot.Yaw = Rotation.Yaw;
		NewRot.Yaw = Rotation.Yaw;
	}

	if (Pawn(Incoming) != none)
	{
		if (Role == ROLE_Authority)
			for (P = Level.PawnList; P != none; P=P.nextPawn)
				if (P.Enemy == Incoming)
					P.LastSeenPos = Incoming.Location;
		if (!Pawn(Incoming).SetLocation(Location))
		{
			Enable('Touch');
			return false;
		}
		Pawn(Incoming).ViewRotation = newRot;
		Pawn(Incoming).SetRotation(newRot);
		Pawn(Incoming).MoveTimer = -1.0;
		Pawn(Incoming).MoveTarget = self;
	}
	else
	{
		if (!Incoming.SetLocation(Location))
		{
			Enable('Touch');
			return false;
		}
		if (bChangesYaw)
			Incoming.SetRotation(newRot);
	}

	Enable('Touch');

	if (bChangesVelocity)
		Incoming.Velocity = TargetVelocity;
	else
	{
		if ( bChangesYaw )
		{
			if (Incoming.Physics == PHYS_Walking)
				NewVelRot.Pitch = 0;
			Incoming.Velocity = VSize(Incoming.Velocity) * vector(NewVelRot);
		}
		if ( bReversesX )
			Incoming.Velocity.X *= -1.0;
		if ( bReversesY )
			Incoming.Velocity.Y *= -1.0;
		if ( bReversesZ )
			Incoming.Velocity.Z *= -1.0;
	}

	// Play teleport-in effect.
	PlayTeleportEffect(Incoming, true);
	return true;
}

simulated function bool CheckTeleportationDelay(Actor Incoming) // hack for 227i
{
	if (PlayerPawn(Incoming) == none)
		return false;
	if (PlayerPawn(Incoming).bUpdatePosition)
		return true;
	if ((Level.TimeSeconds - LastTeleportationTimestamp) / FMax(0.1, Level.TimeDilation) < 0.5)
		return false;
	LastTeleportationTimestamp = Level.TimeSeconds;
	return true;
}

simulated event Touch(Actor Other)
{
	if (!bEnabled)
		return;

	if (Level.NetMode == NM_Client)
	{
		if (!Other.bCollideWorld || PlayerPawn(Other) == none || Other.Role < ROLE_AutonomousProxy)
			return;
		if (!bPostTouchSupported && !CheckTeleportationDelay(Other))
			return;
	}

	if (Other.bCanTeleport && !Other.PreTeleport(self))
	{
		if (InStr(URL, "/" ) >= 0 || InStr(URL, "#") >= 0)
		{
			// Teleport to a level on the net.
			if (Role == ROLE_Authority && PlayerPawn(Other) != none)
				Level.Game.SendPlayer(PlayerPawn(Other), URL);
		}
		else if (bPostTouchSupported)
			SetPendingTouch(Other);
		else
			TeleportActor(Other);
	}
}

simulated event PostTouch(Actor Other)
{
	TeleportActor(Other);
}

simulated function TeleportActor(Actor Other)
{
	local NetTeleporter Dest;
	local int i;

	// Teleport to a random teleporter in this local level, if more than one pick random.
	foreach AllActors(class'NetTeleporter', Dest)
		if (string(Dest.Tag) ~= URL && Dest != self)
			i++;
	if (i == 0)
	{
		if (Level.NetMode != NM_Client)
			Pawn(Other).ClientMessage("Teleport destination for URL '" $ URL $ "' not found!");
		return;
	}
	bNonSimulated = i > 1;
	if (bNonSimulated && Level.NetMode == NM_Client)
		return;

	i = rand(i);

	foreach AllActors(class'NetTeleporter', Dest)
		if (string(Dest.Tag) ~= URL && Dest != self && i-- == 0)
		{
			if (Other.bIsPawn)
				PlayTeleportEffect(Pawn(Other), false);

			Other.bCanTeleport = false;
			Dest.Accept(Other);
			Other.bCanTeleport = true;

			if (Role == ROLE_Authority && Event != '' && Other.bIsPawn)
				TriggerEvent(Event, Other, Other.Instigator);
			return;
		}
}

simulated event Tick(float DeltaTime)
{
	if (Level.NetMode == NM_DedicatedServer || Level.NetMode == NM_ListenServer)
	{
		RepFlags =
			byte(bChangesVelocity) +
			(byte(bChangesYaw) << 1) +
			(byte(bEnabled) << 2) +
			(byte(bReversesX) << 3) +
			(byte(bReversesY) << 4) +
			(byte(bReversesZ) << 5);
		RepRotationYaw = Rotation.Yaw;
		RepTargetVelocity = TargetVelocity;
		if (RepTag != Tag)
			RepTag = Tag;
		if (RepURL != URL)
			RepURL = URL;
	}
	else if (Level.NetMode == NM_Client)
	{
		bChangesVelocity = bool(RepFlags & 1);
		bChangesYaw = bool(RepFlags & 2);
		bEnabled = bool(RepFlags & 4);
		bReversesX = bool(RepFlags & 8);
		bReversesY = bool(RepFlags & 16);
		bReversesZ = bool(RepFlags & 32);
		if (Rotation.Yaw != RepRotationYaw)
			SetRotation(rot(0, 1, 0) * RepRotationYaw);
		TargetVelocity = RepTargetVelocity;
		if (Tag != RepTag)
			Tag = RepTag;
		if (URL != RepURL)
			URL = RepURL;
	}
	else
		Disable('Tick');
}

defaultproperties
{
	bAlwaysRelevant=True
	bCollideWhenPlacing=False
	bStatic=False
	RemoteRole=ROLE_SimulatedProxy
}
