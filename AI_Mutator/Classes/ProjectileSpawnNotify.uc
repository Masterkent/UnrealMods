class ProjectileSpawnNotify expands SpawnNotify;

var transient float TickTime;

var transient Projectile FirstProj;
var transient int ProjCount;
var transient rotator FireRotation;

event Actor SpawnNotification(Actor A)
{
	if (Projectile(A) != none)
		AdjustProjectile(Projectile(A));

	return A;
}

event Tick(float DeltaTime)
{
	TickTime = DeltaTime;

	FirstProj = none;
	ProjCount = 0;
}

function AdjustProjectile(Projectile Proj)
{
	local float ProjSpeed, ProjAcceleration;

	if (ScriptedPawn(Proj.Instigator) != none || Bots(Proj.Instigator) != none)
	{
		if (Proj.IsA('BigRock') ||
			Proj.IsA('BruteProjectile') ||
			Proj.IsA('GasbagBelch') ||
			Proj.IsA('KraalBolt') ||
			Proj.IsA('MercRocket') ||
			Proj.IsA('QueenProjectile') ||
			Proj.IsA('SkaarjProjectile') ||
			Proj.IsA('SlithProjectile') ||
			Proj.IsA('TentacleProjectile') ||
			Proj.IsA('WarlordRocket') ||
			Proj.IsA('DispersionAmmo') ||
			Proj.IsA('RazorBlade') ||
			Proj.IsA('Rocket') ||
			Proj.IsA('StingerProjectile') ||
			Proj.IsA('TazerProj') ||
			Proj.IsA('PlasmaSphere') ||
			Proj.IsA('Razor2') ||
			Proj.IsA('RocketMk2') ||
			Proj.IsA('ShockProj') ||
			Proj.IsA('WarShell'))
		{
			ProjSpeed = FMin(VSize(Proj.Velocity), Proj.MaxSpeed);
			ProjAcceleration = VSize(Proj.Acceleration);
		}
		else if (
			Proj.IsA('UPakRocket') && !Proj.IsA('TowRocket') ||
			Proj.IsA('UPak_UPakRocket') && !Proj.IsA('UPak_TowRocket'))
		{
			ProjSpeed = Proj.MaxSpeed;
		}

		UpdateProjCount(Proj);
		if (ProjSpeed > 0 && ProjSpeed < 100000)
		{
			if (ProjCount == 1)
				FireRotation = AdjustAim(
					Proj.Instigator, ProjSpeed, ProjAcceleration, Proj.Location, 0, ShouldUseSplashDamage(Proj));
		}
		else
			return;

		if (Proj.IsA('BigRock'))
			AdjustBigRock(Proj);
		else if (Proj.IsA('Rocket'))
			AdjustRocket(Proj);
		else if (Proj.IsA('SkaarjProjectile'))
			AdjustSkaarjProjectile(Proj);
		else if (Proj.IsA('StingerProjectile'))
			AdjustStingerProjectile(Proj);
		else
			AdjustProjRotation(Proj, FireRotation);
	}
}

function UpdateProjCount(Projectile Proj)
{
	if (FirstProj == none || FirstProj.Instigator != Proj.Instigator)
	{
		FirstProj = Proj;
		ProjCount = 1;
	}
	else
		ProjCount++;
}

function AdjustBigRock(Projectile Proj)
{
	if (Proj.Instigator != Proj.Owner)
		return;

	if (ProjCount == 2 || Proj.IsA('Boulder1'))
		AdjustProjRotation(Proj, FireRotation);
}

function AdjustRocket(Projectile Proj)
{
	local float Angle;
	local rotator FireRot;
	local bool bTightWad;

	if (Eightball(Proj.Instigator.Weapon) == none || ProjCount <= 1)
	{
		AdjustProjRotation(Proj, FireRotation);
		return;
	}

	FireRot = FireRotation;
	Angle = (ProjCount - 1) * 1.0484;
	bTightWad = Eightball(Proj.Instigator.Weapon).bTightWad;

	if (Angle < 3 && !bTightWad)
		FireRot.Yaw = FireRot.Yaw - Angle * 600;
	else if ( Angle > 3.5 && !bTightWad)
		FireRot.Yaw = FireRot.Yaw + (Angle - 3)  * 600;
	else
		FireRot.Yaw = FireRot.Yaw;

	AdjustProjRotation(Proj, FireRot);
}

function AdjustSkaarjProjectile(Projectile Proj)
{
	if (ProjCount > 1)
		AdjustProjRotation(Proj, FireRotation + rot(0, 400, 0));
	else
		AdjustProjRotation(Proj, FireRotation);
}

function AdjustStingerProjectile(Projectile Proj)
{
	local rotator AltRotation;

	if (ProjCount > 1)
	{
		AltRotation = FireRotation;
		AltRotation.Pitch += FRand()*3000-1500;
		AltRotation.Yaw += FRand()*3000-1500;
		AltRotation.Roll += FRand()*9000-4500;

		AdjustProjRotation(Proj, AltRotation);
		if (ProjCount == 2 && FirstProj != Proj && FirstProj != none && !FirstProj.bDeleteMe)
			AdjustStingerProjectile(FirstProj);
	}
	else
		AdjustProjRotation(Proj, FireRotation);
}

// TODO:
// Code of this function is too ugly, it should be improved
function rotator AdjustAim(
	Pawn Creature,
	float ProjSpeed,
	float ProjAcceleration,
	vector ProjStart,
	int AimError,
	bool bSplashDamage)
{
	local rotator FireRotation;
	local vector FireSpot;
	local Actor HitActor;
	local vector HitLocation, HitNormal;

	local vector InitialFireSpot, PriorFireSpot, TargetHeight;
	local float dt, dist, prior_dist;
	local int iterations;
	local vector RotationDir, LastSeenDir;
	local float DeflectionCos;
	local vector TargetVelocity, TargetTickMovement, TargetTickHorizontalMovement;

	if ( Creature.Target == none )
		Creature.Target = Creature.Enemy;
	if ( Creature.Target == none )
		return Creature.Rotation;
	if ( !Creature.Target.IsA('Pawn') )
		return rotator(Creature.Target.Location - ProjStart);

	FireSpot = Creature.Target.Location;

	// Creature.Target.Velocity.Z may be 0 while the actual Target's Z velocity is non-zero,
	// therefore, the actual Z velocity should be obtained in a different way
	TargetVelocity = Creature.Target.Velocity;
	if (TargetVelocity.Z == 0)
	{
		TargetTickMovement = Creature.Target.Location - Creature.Target.OldLocation;
		TargetTickHorizontalMovement = TargetTickMovement;
		TargetTickHorizontalMovement.Z = 0;

		if (VSize(TargetVelocity) > 0.01)
			TargetVelocity.Z = TargetTickMovement.Z * VSize(TargetVelocity) / VSize(TargetTickHorizontalMovement);
		else if (TickTime > 0)
			TargetVelocity.Z = TargetTickMovement.Z / TickTime;
	}

	AimError = AimError * (1 - 10 *  
		((Normal(Creature.Target.Location - Creature.Location) 
			Dot Normal((Creature.Target.Location + 0.5 * TargetVelocity) -
				(Creature.Location + 0.5 * Creature.Velocity))) - 1)); 

	AimError = AimError * (2.4 - 0.5 * (Creature.skill + FRand()));

	if (Pawn(Creature.Target) != none && Pawn(Creature.Target).Visibility <= 10)
		AimError *= 2;
	else
		AimError *= 0.1;

	dt = 0;
	iterations = 0;
	InitialFireSpot = Creature.Target.Location;
	dist = VSize(InitialFireSpot - ProjStart);
	HitActor = none;

	if (Pawn(Creature.Target) != none && Pawn(Creature.Target).Visibility <= 10)
		iterations = -1;
	else
	{
		if (Creature.Target.Physics == PHYS_Falling)
		{
			TargetHeight = vect(0, 0, 0);
			TargetHeight.Z = Creature.Target.CollisionHeight;
			PriorFireSpot = InitialFireSpot;

			do
			{
				prior_dist = dist;
				dt += 0.01;
				++iterations;
				InitialFireSpot = Creature.Target.Location + TargetVelocity * dt +
					Creature.Target.Region.Zone.ZoneGravity * dt * dt / 2;
				dist = Abs(VSize(InitialFireSpot - ProjStart) - (ProjSpeed + ProjAcceleration * dt / 2) * dt);
				HitActor = Trace(HitLocation, HitNormal, InitialFireSpot - TargetHeight, PriorFireSpot - TargetHeight, false);
			}
			until (prior_dist < dist || iterations > 500 || HitActor != none);

			if (iterations <= 1)
				iterations = -1;
			else if (HitActor != none)
			{
				InitialFireSpot = HitLocation;
				InitialFireSpot.Z += Creature.Target.CollisionHeight;
			}
			else if (iterations <= 500)
			{
				iterations = 0;
				do
				{
					prior_dist = dist;
					dt -= 0.001;
					++iterations;
					InitialFireSpot = Creature.Target.Location + TargetVelocity * dt +
						Creature.Target.Region.Zone.ZoneGravity * dt * dt / 2;
					dist = Abs(VSize(InitialFireSpot - ProjStart) - (ProjSpeed + ProjAcceleration * dt / 2) * dt);
				}
				until (prior_dist < dist || iterations > 10);

				if (prior_dist > 100)
					iterations = -1;
			}
		}
		else
		{
			do
			{
				prior_dist = dist;
				dt += 0.01;
				++iterations;
				InitialFireSpot = Creature.Target.Location + TargetVelocity * dt;
				dist = Abs(VSize(InitialFireSpot - ProjStart) - (ProjSpeed + ProjAcceleration * dt / 2) * dt);
			}
			until (prior_dist < dist || iterations > 500);

			if (iterations <= 1)
				iterations = -1;
			else if (iterations <= 500)
			{
				iterations = 0;
				do
				{
					prior_dist = dist;
					dt -= 0.001;
					++iterations;
					InitialFireSpot = Creature.Target.Location + TargetVelocity * dt;
					dist = Abs(VSize(InitialFireSpot - ProjStart) - (ProjSpeed + ProjAcceleration * dt / 2) * dt);
				}
				until (prior_dist < dist || iterations > 10);

				InitialFireSpot += (Creature.Target.Location - InitialFireSpot) * FMax(0, 1 - 2 * FRand()) *
					FMin(0.1 + 3 *(VSize(InitialFireSpot - ProjStart) / ProjSpeed - 0.3), 1);
				if (prior_dist > 100)
					iterations = -1;
			}
		}
	}

	if (iterations > 500 && HitActor == none || iterations < 0)
	{
		if (iterations > 0)
			ProjSpeed += ProjAcceleration * 5.0;
		InitialFireSpot = Creature.Target.Location +
			FMin(1, 0.7 + 0.6 * FRand()) * TargetVelocity * VSize(Creature.Target.Location - ProjStart)/ProjSpeed;
	}

	if (Creature.Enemy == Creature.Target && Creature.Enemy.Visibility <= 10 &&
		(VSize(Creature.Enemy.Location - Creature.Location) > 400 || VSize(Creature.Enemy.Velocity) < 10))
	{
		DeflectionCos = 0.98;
		InitialFireSpot = ProjStart + vector(Creature.Rotation) * VSize(Creature.LastSeenPos - ProjStart);
		InitialFireSpot.Z = Creature.LastSeenPos.Z;
		RotationDir = Normal(InitialFireSpot - ProjStart);
		LastSeenDir = Normal(Creature.LastSeenPos - ProjStart);

		if (RotationDir Dot LastSeenDir > DeflectionCos)
			InitialFireSpot = Creature.LastSeenPos;
		else
			InitialFireSpot = ProjStart + VSize(Creature.LastSeenPos - ProjStart) * (RotationDir * DeflectionCos +
				Normal((RotationDir Cross LastSeenDir) Cross RotationDir) * Sqrt(1 - Square(DeflectionCos)));
	}

	FireSpot = InitialFireSpot;
	HitActor = self;

	if (Creature.Target.bIsPawn)
	{
		if (bSplashDamage)
		{
			// Try to aim at feet
			HitActor = Trace(HitLocation, HitNormal, FireSpot - vect(0,0,80), FireSpot, false);
			if ( HitActor != none )
			{
				FireSpot = HitLocation + vect(0,0,3);
				HitActor = Trace(HitLocation, HitNormal, FireSpot, ProjStart, false);
			}
			else
				HitActor = self;
		}
	}
	if (HitActor != none)
	{
		// try middle
		FireSpot = InitialFireSpot;
		HitActor = Trace(HitLocation, HitNormal, FireSpot, ProjStart, false);
	}
	if (HitActor != Target && HitActor != none) 
	{
		// try head
 		FireSpot.Z = InitialFireSpot.Z + 0.9 * Creature.Target.CollisionHeight;
		HitActor = Trace(HitLocation, HitNormal, FireSpot, ProjStart, false);
	}
	if (HitActor != Creature.Target && HitActor != none && Creature.Target == Creature.Enemy)
	{
		FireSpot = Creature.LastSeenPos;
		if (Creature.Location.Z >= Creature.LastSeenPos.Z)
			FireSpot.Z -= 0.5 * Creature.Enemy.CollisionHeight;
	}

	FireRotation = rotator(FireSpot - ProjStart);

	FireRotation.Yaw = FireRotation.Yaw + 0.5 * (Rand(2 * AimError) - AimError);

	FireRotation.Yaw = FireRotation.Yaw & 65535;
	if ( (Abs(FireRotation.Yaw - (Creature.Rotation.Yaw & 65535)) > 8192)
		&& (Abs(FireRotation.Yaw - (Creature.Rotation.Yaw & 65535)) < 57343) )
	{
		if ( (FireRotation.Yaw > Creature.Rotation.Yaw + 32768) || 
			((FireRotation.Yaw < Creature.Rotation.Yaw) && (FireRotation.Yaw > Creature.Rotation.Yaw - 32768)) )
			FireRotation.Yaw = Creature.Rotation.Yaw - 8192;
		else
			FireRotation.Yaw = Creature.Rotation.Yaw + 8192;
	}
	Creature.viewRotation = FireRotation;
	return FireRotation;
}

static function bool ShouldUseSplashDamage(Projectile Proj)
{
	if (Proj.IsA('BruteProjectile') ||
		Proj.IsA('MercRocket') ||
		Proj.IsA('Razor2Alt') ||
		Proj.IsA('Rocket') ||
		Proj.IsA('RocketMk2') ||
		Proj.IsA('UPakRocket') ||
		Proj.IsA('UPak_UPakRocket') ||
		Proj.IsA('WarlordRocket') ||
		Proj.IsA('WarShell'))
	{
		return true;
	}
	return false;
}

function AdjustProjRotation(Projectile Proj, rotator NewRotation)
{
	Proj.SetRotation(NewRotation);
	Proj.Velocity = vector(Proj.Rotation) * VSize(Proj.Velocity);
}

defaultproperties
{
	bHidden=True
	RemoteRole=ROLE_None
}
