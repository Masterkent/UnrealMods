class UMap_SpawnableUTTeleporter expands UMap_SpawnableTeleporter;

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
	bPostTouchSupported = DynamicLoadObject("Engine.Actor.SetPendingTouch", class'Function', true) != none;
}

static function UMap_SpawnableUTTeleporter StaticReplaceUTTeleporter(Teleporter OldTelep, optional bool bNoChangesYaw)
{
	local UMap_SpawnableUTTeleporter NewTelep;

	if (OldTelep == none)
		return none;

	NewTelep = OldTelep.Spawn(class'UMap_SpawnableUTTeleporter',, OldTelep.Tag);
	if (NewTelep == none)
		return none;

	NewTelep.ReplaceTeleporter(OldTelep);
	NewTelep.bChangesYaw = !bNoChangesYaw;
	return NewTelep;
}

// Accept an actor that has teleported in.
function bool Accept(Actor Incoming)
{
	return UTF_Accept(Incoming, none);
}

simulated function bool UTF_Accept(Actor Incoming, Actor Source)
{
	local rotator newRot, newVelRot;
	local int oldVelYaw;
	local Pawn P;

	if (Level.NetMode == NM_Client && !bPostTouchSupported && !CheckTeleportationDelay(Incoming))
		return false;

	Disable('Touch');
	newRot = Incoming.Rotation;
	if (bChangesYaw)
	{
		newVelRot = rotator(Incoming.Velocity);
		oldVelYaw = newVelRot.Yaw;
		newVelRot.Yaw = Rotation.Yaw;
		newRot.Yaw = Rotation.Yaw;
		if (Source != none)
		{
			newRot.Yaw += (32768 + Incoming.Rotation.Yaw - Source.Rotation.Yaw);
			newVelRot.Yaw += (32768 + oldVelYaw - Source.Rotation.Yaw);
		}
	}

	if (Pawn(Incoming) != none)
	{
		if (Role == ROLE_Authority)
			for (P = Level.PawnList; P != none; P = P.nextPawn)
			{
				if (P.Enemy == Incoming)
					P.LastSeenPos = Incoming.Location; 
			}

		if (!Pawn(Incoming).SetLocation(Location))
		{
			Enable('Touch');
			return false;
		}
		Pawn(Incoming).ViewRotation = newRot;
		Pawn(Incoming).SetRotation(newRot);
		if (UMap_SpawnableUTTeleporter(Source) == none ||
			UMap_SpawnableUTTeleporter(Source).bNonSimulated ||
			!Incoming.bCollideWorld)
		{
			Pawn(Incoming).ClientSetRotation(newRot);
		}
		Pawn(Incoming).MoveTimer = -1.0;
		Pawn(Incoming).MoveTarget = self;
		PlayTeleportEffect(Incoming, true);

		if (bChangesVelocity && (Incoming.Physics == PHYS_Walking || Incoming.Physics == PHYS_None) && !Incoming.Region.Zone.bWaterZone)
			Incoming.SetPhysics(PHYS_Falling);
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
		if (bChangesYaw)
		{
			if (Incoming.Physics == PHYS_Walking)
				newVelRot.Pitch = 0;
			Incoming.Velocity = VSize(Incoming.Velocity) * vector(newVelRot);
		} 
		if (bReversesX)
			Incoming.Velocity.X *= -1.0;
		if (bReversesY)
			Incoming.Velocity.Y *= -1.0;
		if (bReversesZ)
			Incoming.Velocity.Z *= -1.0;
	}

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
		if (InStr(URL, "/") >= 0 || InStr(URL, "#") >= 0)
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
	local UMap_SpawnableUTTeleporter Dest;
	local int i;

	// Teleport to a random teleporter in this local level, if more than one pick random.
	foreach AllActors(class'UMap_SpawnableUTTeleporter', Dest)
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

	foreach AllActors(class'UMap_SpawnableUTTeleporter', Dest)
		if (string(Dest.Tag) ~= URL && Dest != self && i-- == 0)
		{
			// Teleport the actor into the other teleporter.
			if (Other.bIsPawn)
				PlayTeleportEffect(Pawn(Other), false);
			Dest.UTF_Accept(Other, self);
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
	RemoteRole=ROLE_SimulatedProxy
}
