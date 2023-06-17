class ArenaPowerupsGR expands GameRules;

var ArenaPowerups ArenaPowerups;

event BeginPlay()
{
	if (Level.Game.GameRules == none)
		Level.Game.GameRules = self;
	else
		Level.Game.GameRules.AddRules(self);

	ArenaPowerups = ArenaPowerups(Owner);
}

function bool CanPickupInventory(Pawn Pawn, Inventory Inv)
{
	local Inventory PawnInv;
	local GameRules GR;
	local int Charge;

	if (IsPowerup(Inv) && Inv.Charge > 0 && Inv.RespawnTime == 0)
	{
		PawnInv = FindInventoryType(Pawn, Inv.Class);
		if (PawnInv != none)
		{
			for (GR = NextRules; GR != none; GR = GR.NextRules)
				if (GR.bHandleInventory && !GR.CanPickupInventory(Pawn, Inv))
					return false;
			Charge = Min(Inv.default.Charge, Inv.Charge + PawnInv.Charge);
			PawnInv.HandlePickupQuery(Inv);
			if (Inv.bDeleteMe)
				PawnInv.Charge = Max(PawnInv.Charge, Charge);
			return false;
		}
	}

	return true;
}

function bool PreventDeath(Pawn Victim, Pawn Killer, name DamageType)
{
	DropPowerups(Victim);
	return false;
}

function Inventory FindInventoryType(Pawn P, class<Inventory> DesiredClass)
{
	local Inventory Inv;

	for (Inv = P.Inventory; Inv != none; Inv = Inv.Inventory)
		if (Inv.Class == DesiredClass)
			return Inv;
	return none;
}

function DropPowerups(Pawn Victim)
{
	local Inventory Inv, InvCopy;

	for (Inv = Victim.Inventory; Inv != none; Inv = Inv.Inventory)
		if (IsPowerup(Inv) && Inv.Charge > 0)
		{
			InvCopy = Victim.Spawn(Inv.Class);
			if (InvCopy == none)
				continue;

			InvCopy.Charge = Inv.Charge;
			InvCopy.RespawnTime = 0.0; // don't respawn
			InvCopy.BecomePickup();
			InvCopy.RemoteRole = ROLE_DumbProxy;
			InvCopy.SetPhysics(PHYS_Falling);
			InvCopy.bCollideWorld = true;
			InvCopy.Velocity = Victim.Velocity + VRand() * 280;
			InvCopy.SetRotation(rot(0, 1, 0) * InvCopy.Rotation.Yaw);
			InvCopy.GotoState('PickUp', 'Dropped');
		}
}

function bool IsPowerup(Inventory Inv)
{
	local int i;

	if (Pickup(Inv) == none)
		return false;

	if (Inv.Class.Name == 'UDamage' && Inv.Class.Outer.Name == 'Botpack')
		return true;

	for (i = 0; i < Array_Size(ArenaPowerups.PowerupClasses); ++i)
		if (ArenaPowerups.PowerupClasses[i] ~= string(Inv.Class))
			return true;
	return false;
}

defaultproperties
{
	bHandleDeaths=True
	bHandleInventory=True
}
