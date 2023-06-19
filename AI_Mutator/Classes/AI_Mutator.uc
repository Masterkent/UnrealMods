class AI_Mutator expands Mutator;

var() const string VersionInfo;
var() const string Version;

var transient float SlowTimerSeconds;
var transient float FastTimerSeconds;

const SlowTimerInterval = 0.1;
const FastTimerInterval = 0.05;

event PostBeginPlay()
{
	Spawn(class'AI_GameRules');
	Spawn(class'ProjectileSpawnNotify');
}

function Tick(float DeltaTime)
{
	SlowTimerSeconds += DeltaTime;
	FastTimerSeconds += DeltaTime;

	if (SlowTimerSeconds >= SlowTimerInterval)
	{
		SlowTimerSeconds = 0;
		UpdateScriptedPawnsAI();
	}
	if (FastTimerSeconds >= FastTimerInterval)
	{
		FastTimerSeconds = 0;
		WarnPawnsAboutProjectiles();
	}
}

function UpdateScriptedPawnsAI()
{
	local ScriptedPawn Creature;

	foreach AllActors(class'ScriptedPawn', Creature)
		UpdateScriptedPawn(Creature);
}

function UpdateScriptedPawn(ScriptedPawn Creature)
{
	if (Creature.Health <= 0 || Creature.IsA('Nali'))
		return;

	Creature.Aggressiveness = FMax(1, Creature.Aggressiveness);
	Creature.TimeBetweenAttacks = 0;

	if (Creature.Enemy != none && Creature.LineOfSightTo(Creature.Enemy) && FRand() < 0.05)
		Creature.bReadyToAttack = true;

	if (Brute(Creature) != none)
		Update_Brute(Brute(Creature));
	else if (Krall(Creature) != none)
		Update_Krall(Krall(Creature));
	else if (Queen(Creature) != none)
		Update_Queen(Queen(Creature));
	else if (Skaarj(Creature) != none)
		Update_Skaarj(Skaarj(Creature));
}

function Update_Brute(Brute Creature)
{
	if (Creature.bBerserk)
	{
		if (Creature.Enemy == none ||
			VSize(Creature.Enemy.Location - Creature.Location) > 240 + Creature.CollisionRadius + Creature.Enemy.CollisionRadius ||
			!Creature.ActorReachable(Creature.Enemy))
		{
			Creature.AccelRate = Creature.default.AccelRate;
			Creature.GroundSpeed = Creature.default.GroundSpeed;
			Creature.bBerserk = false;
			Creature.bLongBerserk = false;
		}
	}
}

function Update_Krall(Krall Creature)
{
	if (LeglessKrall(Creature) == none)
		Creature.bCanDuck = true;
}

function Update_Queen(Queen Creature)
{
	local QueenDest Dest;
	local float InitialDist, BestDist;
	local vector HitLocation, HitNormal;
	local Actor HitActor;

	if (Creature.Enemy == none)
		return;

	InitialDist = VSize(Creature.Location - Creature.Enemy.Location);
	BestDist = InitialDist;

	foreach AllActors(class'QueenDest', Dest)
	{
		HitActor = Trace(HitLocation, HitNormal, Creature.Enemy.Location, Dest.Location, false);
		if (HitActor == none && VSize(Creature.Enemy.Location - Dest.Location) < BestDist)
		{
			BestDist = VSize(Creature.Enemy.Location - Dest.Location);
			Creature.TelepDest = Dest.Location;
		}
	}

	if (Creature.IsInState('Teleporting'))
		return;

	if (InitialDist - 200 > BestDist)
	{
		Creature.GotoState('Teleporting');
		return;
	}

	if (Creature.IsInState('Charging'))
		return;

	if (VSize(Creature.Enemy.Location - Creature.Location) > 600 &&
		Creature.ActorReachable(Creature.Enemy))
	{
		Creature.GotoState('Charging');
	}

	if (Creature.AnimSequence == 'Shield' && Creature.bLeadTarget)
		Creature.GotoState('Charging');
	else if (Creature.AnimSequence != 'Shield')
		Creature.bLeadTarget = true;
}

function Update_Skaarj(Skaarj Creature)
{
	Creature.CombatStyle = FMax(1, Creature.CombatStyle);

	if (SkaarjTrooper(Creature) != none)
		Update_SkaarjTrooper(SkaarjTrooper(Creature));
}

function Update_SkaarjTrooper(SkaarjTrooper Creature)
{
	if (Creature.Enemy != none && Creature.LineOfSightTo(Creature.Enemy))
		Creature.bReadyToAttack = true;

	if (Creature.Weapon != none &&
		Creature.IsInState('FallingState') &&
		(Creature.AnimSequence == 'LeftDodge' || Creature.AnimSequence == 'RightDodge') &&
		Creature.AnimFrame > 0.5 &&
		Creature.Enemy != none &&
		Creature.Enemy.Health > 0 &&
		Creature.AttitudeTo(Creature.Enemy) <= ATTITUDE_Frenzy &&
		VSize(Creature.Enemy.Location - Creature.Location) <= Creature.SightRadius)
	{
		SkaarjTrooper_WeaponFire(Creature);
	}
	else if (Creature.Enemy != none && Creature.Enemy.Health <= 0 ||
		Creature.Enemy == none && (Creature.Target == none || Pawn(Creature.Target) != none && Pawn(Creature.Target).Health <= 0))
	{
		Creature.bFire = 0;
		Creature.bAltFire = 0;
	}
}


function WarnPawnsAboutProjectiles()
{
	local Projectile Proj;

	ForEach AllActors(class'Projectile', Proj)
		if (Proj.Damage > 0 && Proj.Physics != PHYS_none && VSize(Proj.Velocity) > 1 && !Proj.Region.Zone.bWaterZone)
			WarnPotentialTarget(Proj);
}

function WarnPotentialTarget(Projectile Proj)
{
	local vector FireDir, HitNormal, HitLocation;
	local Pawn BestTarget;
	local float BestAim, BestDist;
	local Actor HitActor;

	FireDir = Normal(Proj.Velocity);
	HitActor = Trace(HitLocation, HitNormal, Proj.Location + 4000 * FireDir, Proj.Location, true);
	if (HitActor != none && HitActor.bProjTarget)
	{
		if (HitActor.bIsPawn)
			WarnTargetAboutProjectile(Pawn(HitActor), Proj);
		return;
	}

	BestAim = 0.93;
	if (Proj.Instigator != none)
		BestTarget = Proj.Instigator.PickTarget(BestAim, BestDist, FireDir, Proj.Location);

	if (BestTarget != none)
		WarnTargetAboutProjectile(BestTarget, Proj);
}

function WarnTargetAboutProjectile(Pawn Target, Projectile Proj)
{
	local vector X, Y, Z;
	local vector FireSpot, ProjDir;
	local Pawn.EAttitude Attitude;
	local float ProjDist, HitTime, HitDist;

	if (Target.Health <= 0)
		return;

	ProjDist = VSize(Proj.Location - Target.Location);

	if (ProjDist > Target.SightRadius ||
		Normal(Proj.Location - Target.Location) dot vector(Target.Rotation) <= 0)
	{
		return; // Target can't see Proj
	}

	if (Proj.Instigator != none)
	{
		if (Target.IsA('ScriptedPawn'))
			Attitude = ScriptedPawn(Target).AttitudeTo(Proj.Instigator);
		else if (IsA('Bots'))
			Attitude = Bots(Target).AttitudeTo(Proj.Instigator);
		if (Attitude <= ATTITUDE_Threaten)
		{
			if ( Target.intelligence >= BRAINS_Mammal )
				Target.damageAttitudeTo(Proj.Instigator);
			if (Attitude == ATTITUDE_Ignore)
				return;	
		}
	}

	// AI controlled Creatures may duck if not falling
	if (Target.Physics == PHYS_Falling || Target.Physics == PHYS_Swimming)
		return;

	GetAxes(Target.Rotation, X, Y, Z);
	ProjDir = Normal(Proj.Velocity);

	if (ProjDir dot X > -0.5)
		return;

	FireSpot = Proj.Location + ProjDist * ProjDir;
	FireSpot -= Target.Location;

	HitTime = ProjDist / VSize(Proj.Velocity);
	HitDist = VSize(FireSpot);

	if (FireSpot dot Y > 0)
	{
		Y *= -1;
		PawnTryToDuckEx(Target, Y, true, Proj, HitTime, HitDist);
	}
	else
		PawnTryToDuckEx(Target, Y, false, Proj, HitTime, HitDist);
}

function PawnTryToDuckEx(
	Pawn Creature, vector DuckDir, bool bReversed, Projectile Proj, float HitTime, float HitDist)
{
	if (GasBag(Creature) != none)
		GasBag_TryToDuckEx(GasBag(Creature), DuckDir, bReversed, Proj, HitTime, HitDist);
	else if (Krall(Creature) != none)
		Krall_TryToDuckEx(Krall(Creature), DuckDir, bReversed, Proj, HitTime, HitDist);
	else if (Mercenary(Creature) != none)
		Mercenary_TryToDuckEx(Mercenary(Creature), DuckDir, bReversed, Proj, HitTime, HitDist);
	else if (Queen(Creature) != none)
		Queen_TryToDuckEx(Queen(Creature), DuckDir, bReversed, Proj, HitTime, HitDist);
	else if (SkaarjTrooper(Creature) != none)
		SkaarjTrooper_TryToDuckEx(SkaarjTrooper(Creature), DuckDir, bReversed, Proj, HitTime, HitDist);
	else if (SkaarjWarrior(Creature) != none)
		SkaarjWarrior_TryToDuckEx(SkaarjWarrior(Creature), DuckDir, bReversed, Proj, HitTime, HitDist);
	else if (Warlord(Creature) != none)
		Warlord_TryToDuckEx(Warlord(Creature), DuckDir, bReversed, Proj, HitTime, HitDist);
	else if (Creature.IsA('Predator'))
		Predator_TryToDuckEx(ScriptedPawn(Creature), DuckDir, bReversed, Proj, HitTime, HitDist);
	else if (Bots(Creature) != none)
		Bot_TryToDuckEx(Bots(Creature), DuckDir, bReversed, Proj, HitTime, HitDist);
}

function GasBag_TryToDuckEx(
	GasBag Creature, vector DuckDir, bool bReversed, Projectile Proj, float HitTime, float HitDist)
{
	local vector HitLocation, HitNormal, Extent;
	local Actor HitActor;

	if (GiantGasBag(Creature) != none)
		return;

	DuckDir.Z = 0;

	if (!Creature.bCanDuck)
	{
		Creature.Destination = Creature.Location + 200 * DuckDir;
		return;
	}

	Extent.X = Creature.CollisionRadius;
	Extent.Y = Creature.CollisionRadius;
	Extent.Z = Creature.CollisionHeight;

	HitActor = Trace(HitLocation, HitNormal, Creature.Location + 100 * DuckDir, Creature.Location, false, Extent);
	if (HitActor != none)
	{
		if (HitDist > Creature.CollisionRadius + 15)
			return;
		DuckDir *= -1;
		HitActor = Trace(HitLocation, HitNormal, Creature.Location + 100 * DuckDir, Creature.Location, false, Extent);
	}
	if (HitActor != none)
		return;

	if (Creature.AirSpeed <= Creature.default.AirSpeed ||
		Normal(DuckDir) dot Normal(Creature.Velocity) > 0.966)
	{
		Creature.TryToDuck(DuckDir, bReversed);
		Spawn(class'ScriptedPawnDuckController').DisableDuckFor(Creature, 0.7);
	}
}

function Krall_TryToDuckEx(
	Krall Creature, vector DuckDir, bool bReversed, Projectile Proj, float HitTime, float HitDist)
{
	local vector HitLocation, HitNormal, Extent;
	local Actor HitActor;

	if (!Creature.bCanDuck ||
		Creature.IsInState('FallingState') ||
		Level.TimeSeconds - Creature.LastDuckTime < 0.2 * Creature.MinDuckTime ||
		Level.TimeSeconds - Creature.LastDuckTime < 1.6 && ProjectileGroupDamage(Proj) < 35)
	{
		return;
	}

	DuckDir.Z = 0;

	Extent.X = Creature.CollisionRadius;
	Extent.Y = Creature.CollisionRadius;
	Extent.Z = Creature.CollisionHeight;
	HitActor = Trace(HitLocation, HitNormal, Creature.Location + 128 * DuckDir, Creature.Location, false, Extent);
	if (HitActor != none)
	{
		DuckDir *= -1;
		HitActor = Trace(HitLocation, HitNormal, Creature.Location + 128 * DuckDir, Creature.Location, false, Extent);
	}
	if (HitActor != none)
		return;
	
	HitActor = Trace(
		HitLocation,
		HitNormal,
		Creature.Location + 128 * DuckDir - Creature.MaxStepHeight * vect(0,0,1),
		Creature.Location + 128 * DuckDir,
		false,
		Extent);

	if (HitActor == none)
		return;

	Creature.LastDuckTime = Level.TimeSeconds;
	Creature.SetFall();
	Creature.TweenAnim('Jump', 0.3);
	Creature.Velocity = DuckDir * 1.5 * Creature.GroundSpeed;
	Creature.Velocity.Z = 200;
	Creature.SetPhysics(PHYS_Falling);
	Creature.GotoState('FallingState', 'Ducking');
}

function Mercenary_TryToDuckEx(
	Mercenary Creature, vector DuckDir, bool bReversed, Projectile Proj, float HitTime, float HitDist)
{
	if (Creature.IsInState('Invulnerable'))
		return;

	if (Creature.bCanDuck && !Creature.pointReachable(Creature.Location + 100 * DuckDir))
	{
		Creature.BecomeInvulnerable();
		return;
	}
	if (Creature.Enemy != none && Creature.ActorReachable(Creature.Enemy))
		DuckDir = Normal(DuckDir + 0.7 * Normal(Creature.Enemy.Location - Creature.Location));
	Creature.Destination = Creature.Location + 200 * DuckDir;

	if (!Creature.bCanDuck ||
		!Creature.bHasInvulnerableShield || Creature.bIsInvulnerable ||
		ProjectileGroupDamage(Proj) < 35 && !Creature.bCanFireWhileInvulnerable ||
		Creature.InvulnerableCharge + (Level.TimeSeconds - Creature.InvulnerableTime)/2 < 4)
	{
		if (Creature.GetAnimGroup(Creature.AnimSequence) != 'MovingAttack')
			Creature.PlayRunning();
		Creature.GotoState('TacticalMove', 'DoStrafeMove');
	}
	else
		Creature.BecomeInvulnerable();
}

function Queen_TryToDuckEx(
	Queen Creature, vector DuckDir, bool bReversed, Projectile Proj, float HitTime, float HitDist)
{
	if (Creature.Health <= 2000 || ProjectileGroupDamage(Proj) <= 220 || !Creature.bCanDuck)
		return;

	if (!Creature.IsInState('Teleporting') && Creature.AnimSequence != 'Shield' && Creature.bLeadTarget)
	{
		if (FRand() >= 0.1 || !Creature.bCanDuck)
			Creature.GotoState('Teleporting');
		else
		{
			Creature.bLeadTarget = false;
			Creature.TryToDuck(DuckDir, bReversed);
		}
	}
}

function SkaarjTrooper_TryToDuckEx(
	SkaarjTrooper Creature, vector DuckDir, bool bReversed, Projectile Proj, float HitTime, float HitDist)
{
	local vector StrafeDir;
	local vector HitLocation, HitNormal, Extent;
	local bool duckLeft;
	local Actor HitActor;

	if (!Creature.bCanDuck)
		return;

	DuckDir.Z = 0;
	StrafeDir = DuckDir;
	duckLeft = !bReversed;

	Extent.X = Creature.CollisionRadius;
	Extent.Y = Creature.CollisionRadius;
	Extent.Z = Creature.CollisionHeight;
	HitActor = Trace(HitLocation, HitNormal, Creature.Location + 200 * DuckDir, Creature.Location, false, Extent);
	if (HitActor != none && HitDist < 100)
	{
		duckLeft = !duckLeft;
		DuckDir *= -1;
		HitActor = Trace(HitLocation, HitNormal, Creature.Location + 200 * DuckDir, Creature.Location, false, Extent);
	}
	if (HitActor != none && HitTime < 0.4 && HitDist < 150)
	{
		if (Creature.AnimSequence == 'ShldUp' || Creature.AnimSequence == 'HoldShield')
			return;
		if (ProjectileGroupDamage(Proj) < 35)
		{
			SkaarjTrooper_Strafe(Creature, StrafeDir);
			return;
		}

		Creature.duckTime = HitTime + 0.2;
		Creature.Shield();
		return;
	}

	if (Creature.IsInState('FallingState'))
		return;

	HitActor = Trace(
		HitLocation,
		HitNormal,
		Creature.Location + 200 * DuckDir - Creature.MaxStepHeight * vect(0,0,1),
		Creature.Location + 200 * DuckDir,
		false,
		Extent);

	if (HitActor == none)
	{
		SkaarjTrooper_Strafe(Creature, StrafeDir);
		return;
	}

	Creature.SetFall();
	if ( duckLeft )
		Creature.PlayAnim('LeftDodge', 1.35);
	else
		Creature.PlayAnim('RightDodge', 1.35);
	Creature.Velocity = DuckDir * Creature.GroundSpeed;
	Creature.Velocity.Z = 200;
	Creature.SetPhysics(PHYS_Falling);
	Creature.GotoState('FallingState', 'Ducking');
}

function SkaarjTrooper_Strafe(SkaarjTrooper Creature, vector DuckDir)
{
	if (!Creature.pointReachable(Creature.Location + 100 * DuckDir))
		return;
	if (Creature.Enemy != none && Creature.ActorReachable(Creature.Enemy))
		DuckDir = Normal(DuckDir + 0.7 * Normal(Creature.Enemy.Location - Creature.Location));
	Creature.Destination = Creature.Location + 200 * DuckDir;
	Creature.GotoState('TacticalMove', 'DoStrafeMove');
	if (Creature.GetAnimGroup(Creature.AnimSequence) != 'MovingAttack' &&
		Creature.AnimSequence != 'StrafeLeft' &&
		Creature.AnimSequence != 'StrafeRight')
	{
		Creature.PlayRunning();
	}
}

function SkaarjWarrior_TryToDuckEx(
	SkaarjWarrior Creature, vector DuckDir, bool bReversed, Projectile Proj, float HitTime, float HitDist)
{
	local vector StrafeDir;
	local vector HitLocation, HitNormal, Extent;
	local bool duckLeft, bSuccess;
	local Actor HitActor;

	if (!Creature.bCanDuck)
		return;

	if (ProjectileGroupDamage(Proj) < 41)
	{
		SkaarjWarrior_Strafe(Creature, DuckDir, Proj);
		return;
	}

	if (Creature.IsInState('FallingState'))
		return;

	DuckDir.Z = 0;
	StrafeDir = DuckDir;
	duckLeft = !bReversed;

	Extent.X = Creature.CollisionRadius;
	Extent.Y = Creature.CollisionRadius;
	Extent.Z = Creature.CollisionHeight;
	HitActor = Trace(HitLocation, HitNormal, Creature.Location + 200 * DuckDir, Creature.Location, false, Extent);
	bSuccess = ( (HitActor == none) || (VSize(HitLocation - Creature.Location) > 150) );
	if (!bSuccess && HitDist < 100)
	{
		duckLeft = !duckLeft;
		DuckDir *= -1;
		HitActor = Trace(HitLocation, HitNormal, Creature.Location + 200 * DuckDir, Creature.Location, false, Extent);
		bSuccess = ( (HitActor == none) || (VSize(HitLocation - Creature.Location) > 150) );
	}
	if (!bSuccess)
	{
		SkaarjWarrior_Strafe(Creature, StrafeDir, Proj);
		return;
	}

	if (HitActor == none)
		HitLocation = Creature.Location + 200 * DuckDir;

	HitActor = Trace(
		HitLocation,
		HitNormal,
		HitLocation - Creature.MaxStepHeight * vect(0,0,1),
		HitLocation,
		false,
		Extent);

	if (HitActor == none)
	{
		SkaarjWarrior_Strafe(Creature, StrafeDir, Proj);
		return;
	}

	Creature.SetFall();
	if ( duckLeft )
		Creature.PlayAnim('LeftDodge', 1.35);
	else
		Creature.PlayAnim('RightDodge', 1.35);
	Creature.Velocity = DuckDir * Creature.GroundSpeed;
	Creature.Velocity.Z = 200;
	Creature.SetPhysics(PHYS_Falling);
	Creature.GotoState('FallingState', 'Ducking');
}

function SkaarjWarrior_Strafe(SkaarjWarrior Creature, vector DuckDir, Projectile Proj)
{
	if (!Creature.pointReachable(Creature.Location + 100 * DuckDir))
		return;
	if (Creature.Enemy != none && Creature.ActorReachable(Creature.Enemy))
		DuckDir = Normal(DuckDir + 0.7 * Normal(Creature.Enemy.Location - Creature.Location));
	Creature.Destination = Creature.Location + 200 * DuckDir;

	if (Creature.bHasRangedAttack && Creature.bMovingRangedAttack &&
		Creature.AnimSequence != 'LeftDodge' && Creature.AnimSequence != 'RightDodge' &&
		Creature.GetAnimGroup(Creature.AnimSequence) != 'MovingAttack' &&
		Creature.Enemy != none && Proj.Instigator == Creature.Enemy &&
		Creature.AttitudeTo(Creature.Enemy) <= ATTITUDE_Frenzy &&
		VSize(Creature.Enemy.Location - Creature.Location) <= Creature.SightRadius)
	{
		Creature.PlayMovingAttack();
	}
	Creature.GotoState('TacticalMove', 'DoStrafeMove');
}

function Warlord_TryToDuckEx(
	Warlord Creature, vector DuckDir, bool bReversed, Projectile Proj, float HitTime, float HitDist)
{
	if (Creature.bCanDuck &&
		Creature.AnimSequence != 'Fly' &&
		Creature.AnimSequence != 'FDodgeUp' &&
		Creature.AnimSequence != 'FDodgeL' &&
		Creature.AnimSequence != 'FDodgeR' &&
		!Creature.IsInState('Teleporting'))
	{
		Creature.TryToDuck(DuckDir, bReversed);
	}
}

function Predator_TryToDuckEx(
	ScriptedPawn Creature, vector DuckDir, bool bReversed, Projectile Proj, float HitTime, float HitDist)
{
	local vector HitLocation, HitNormal, Extent;
	local bool duckLeft, bSuccess;
	local Actor HitActor;

	if (ProjectileGroupDamage(Proj) < 30 || Creature.IsInState('FallingState') || !Creature.bCanDuck)
		return;

	if (Creature.Enemy != none)
	{
		if (VSize(Creature.Location - Creature.Enemy.Location) < 200 ||
			VSize(Creature.Location - Creature.Enemy.Location) < 350 && Proj.IsA('GLGrenade'))
		{
			return;
		}
	}

	if (Creature.Enemy != none && Creature.ActorReachable(Creature.Enemy))
		DuckDir = Normal(DuckDir + Normal(Creature.Enemy.Location - Creature.Location));

	DuckDir.Z = 0;
	duckLeft = !bReversed;

	Extent.X = Creature.CollisionRadius;
	Extent.Y = Creature.CollisionRadius;
	Extent.Z = Creature.CollisionHeight;
	HitActor = Creature.Trace(
		HitLocation, HitNormal, Creature.Location + 200 * DuckDir, Creature.Location, false, Extent);
	bSuccess = ( (HitActor == none) || (VSize(HitLocation - Creature.Location) > 150) );

	if ( !bSuccess )
		return;
	
	if ( HitActor == none )
		HitLocation = Creature.Location + 200 * DuckDir;
	HitActor = Creature.Trace(
		HitLocation, HitNormal, HitLocation - Creature.MaxStepHeight * vect(0,0,1), HitLocation, false, Extent);
	if (HitActor == none)
		return;

	Creature.SetFall();

	Creature.PlayAnim('Jump');
	Creature.Velocity = DuckDir * Creature.GroundSpeed;
	Creature.Velocity.Z = 200;
	Creature.SetPhysics(PHYS_Falling);
	Creature.GotoState('FallingState', 'Ducking');
}

function Bot_TryToDuckEx(
	Bots Creature, vector DuckDir, bool bReversed, Projectile Proj, float HitTime, float HitDist)
{
	local vector HitLocation, HitNormal, Extent;
	local Actor HitActor;
	local bool bSuccess, bDuckLeft;

	if (!Creature.bCanDuck || Creature.IsInState('FallingState'))
		return;

	if (ProjectileGroupDamage(Proj) < 41 || HitDist > 40)
	{
		if (!Creature.pointReachable(Creature.Location + 100 * DuckDir))
			return;
		Creature.Destination = Creature.Location + 200 * DuckDir;
		Creature.GotoState('TacticalMove', 'DoStrafeMove');
		return;
	}

	DuckDir.Z = 0;
	bDuckLeft = !bReversed;
	Extent.X = Creature.CollisionRadius;
	Extent.Y = Creature.CollisionRadius;
	Extent.Z = Creature.CollisionHeight;
	HitActor = Creature.Trace(
		HitLocation, HitNormal, Creature.Location + 240 * DuckDir, Creature.Location, false, Extent);
	bSuccess = ( (HitActor == none) || (VSize(HitLocation - Creature.Location) > 150) );
	if ( !bSuccess )
	{
		bDuckLeft = !bDuckLeft;
		DuckDir *= -1;
		HitActor = Creature.Trace(
			HitLocation, HitNormal, Creature.Location + 240 * DuckDir, Creature.Location, false, Extent);
		bSuccess = ( (HitActor == none) || (VSize(HitLocation - Creature.Location) > 150) );
	}
	if ( !bSuccess )
		return;

	if ( HitActor == none )
		HitLocation = Creature.Location + 240 * DuckDir;

	HitActor = Creature.Trace(
		HitLocation, HitNormal, HitLocation - Creature.MaxStepHeight * vect(0,0,1), HitLocation, false, Extent);
	if (HitActor == none)
		return;

	Creature.SetFall();
	Creature.Velocity = DuckDir * 400;
	Creature.Velocity.Z = 160;
	Creature.PlayDodge(bDuckLeft);
	Creature.SetPhysics(PHYS_Falling);

	if (Creature.Weapon != none && Creature.Weapon.bSplashDamage &&
		(Creature.bFire != 0 || Creature.bAltFire != 0) &&
		Creature.Enemy != none)
	{
		HitActor = Trace(HitLocation, HitNormal, Creature.Enemy.Location, HitLocation, false);
		if ( HitActor != none )
		{
			HitActor = Creature.Trace(HitLocation, HitNormal, Creature.Enemy.Location, Creature.Location, false);
			if ( HitActor == none )
			{
				Creature.bFire = 0;
				Creature.bAltFire = 0;
			}
		}
	}

	Creature.GotoState('FallingState', 'Ducking');
}


function SkaarjTrooper_WeaponFire(SkaarjTrooper Creature)
{
	local Actor HitActor;
	local vector HitLocation, HitNormal;
	local int bUseAltMode;

	if (Creature.Enemy == none || Creature.Enemy.Health <= 0 || Creature.bFire != 0 || Creature.bAltFire != 0)
		return;

	HitActor = Trace(HitLocation, HitNormal, Creature.LastSeenPos, Creature.Location, false);
	if (HitActor != none && HitActor != Creature.Enemy)
		return;

	if (Creature.Weapon.AmmoType != none)
		Creature.Weapon.AmmoType.AmmoAmount = Creature.Weapon.AmmoType.Default.AmmoAmount;
	Creature.Weapon.RateSelf(bUseAltMode);

	if (bUseAltMode == 0) 
	{
		Creature.bFire = 1;
		Creature.bAltFire = 0;
		Creature.Weapon.Fire(1.0);
	}
	else
	{
		Creature.bFire = 0;
		Creature.bAltFire = 1;
		Creature.Weapon.AltFire(1.0);
	}
}

function int ProjectileGroupDamage(Projectile Proj)
{
	local Projectile nearProj;
	local int ProjGroupDamage;

	foreach RadiusActors(class'Projectile', nearProj, 10, Proj.Location)
		ProjGroupDamage += nearProj.Damage;
	return ProjGroupDamage;
}

function string GetHumanName()
{
	return "AI_Mutator v2.0";
}

defaultproperties
{
	VersionInfo="AI_Mutator v2.0 [2023-06-19]"
	Version="2.0"
}
