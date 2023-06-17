class UMap_MoverStateSensor expands Info;

var name MoverName;
var bool bCanTriggerWhenOpening;
var bool bCanTriggerWhenClosing;
var bool bCanTriggerWhenOpened;
var bool bCanTriggerWhenClosed;

var private Mover ControlledMover;

function Trigger(Actor Other, Pawn EventInstigator)
{
	local Actor A;

	SetControlledMover();
	if (ControlledMover == none)
		return;

	if (ControlledMover.bInterpolating)
	{
		if (ControlledMover.bOpening && !bCanTriggerWhenOpening)
			return;
		if (!ControlledMover.bOpening && !bCanTriggerWhenClosing)
			return;
	}
	else if (ControlledMover.bDelaying && !bCanTriggerWhenOpening)
		return;
	else
	{
		if (!MoverIsClosingOrClosed(ControlledMover) && !bCanTriggerWhenOpened)
			return;
		if (MoverIsClosingOrClosed(ControlledMover) && !bCanTriggerWhenClosed)
			return;
	}

	if (Event == '')
		Event = ControlledMover.Tag;

	foreach AllActors(class 'Actor', A, Event)
		A.Trigger(self, EventInstigator);
}

function final SetControlledMover()
{
	local Mover M;

	if (ControlledMover != none || MoverName == '')
		return;
	foreach AllActors(class'Mover', M)
		if (M.name == MoverName)
		{
			ControlledMover = M;
			return;
		}
	log("Warning: Mover" @ Level.outer.name $ "." $ MoverName @ "is not found", 'UMapMod');
	MoverName = '';
}

static final function bool MoverIsClosingOrClosed(Mover m)
{
	return m.KeyNum == 0 || m.KeyNum < m.PrevKeyNum;
}


defaultproperties
{
}
