class UMap_MoverStateController expands Info;

var name MoverName;
var name OpenPosEvent;
var name ClosePosEvent;

var private Mover ControlledMover;
var private name CurrentPos;
var private bool bChangedPermanently;

function PostBeginPlay()
{
	CurrentPos = '';
	bChangedPermanently = false;
}

function final SetControlledMover()
{
	local Mover M;

	if (MoverName == '')
		return;
	foreach AllActors(class'Mover', M)
		if (M.name == MoverName)
		{
			ControlledMover = M;
			ControlledMover.Tag = StringToName("UMap_Controlled_" @ ControlledMover.name);
			return;
		}
	log("Warning: Mover" @ Level.outer.name $ "." $ MoverName @ "is not found", 'UMapMod');
	MoverName = '';
}

function final SetCurrentChange(name MoverPosChange, bool bPermanently, Actor A, Pawn EventInstigator)
{
	if (bChangedPermanently)
		return;

	if (ControlledMover == none)
		SetControlledMover();

	if (ControlledMover == none || !ControlledMover.IsInState('TriggerToggle'))
		return;

	bChangedPermanently = bPermanently;

	if (CurrentPos == '')
		CurrentPos = GetCurrentMoverPosition(ControlledMover);

	if (MoverPosChange == 'Open' || MoverPosChange == 'Close')
	{
		if (MoverPosChange != CurrentPos)
			ChangeMoverPosition(ControlledMover, MoverPosChange, A, EventInstigator);
	}
	else if (MoverPosChange == 'Toggle')
		ChangeMoverPosition(ControlledMover, InverseMoverPosition(CurrentPos), A, EventInstigator);
}

static final function name GetCurrentMoverPosition(Mover m)
{
	if (MoverIsClosingOrClosed(m))
		return 'Close';
	return 'Open';
}

static final function name InverseMoverPosition(name MoverPos)
{
	if (MoverPos == 'Close')
		return 'Open';
	if (MoverPos == 'Open')
		return 'Close';
	return MoverPos;
}

final function ChangeMoverPosition(Mover m, name NextMoverPos, Actor A, Pawn EventInstigator)
{
	CurrentPos = NextMoverPos;

	m.SavedTrigger = A;
	m.Instigator = EventInstigator;
	if (m.SavedTrigger != none)
		m.SavedTrigger.BeginEvent();
	m.GotoState(, NextMoverPos);
}

static final function bool MoverIsClosingOrClosed(Mover m)
{
	return m.KeyNum == 0 || m.KeyNum < m.PrevKeyNum;
}

final function GenerateMoverEvent(Mover m, name EventName)
{
	local Actor A;
	foreach AllActors(class'Actor', A, EventName)
		A.Trigger(m.SavedTrigger, m.Instigator);
}

event Tick(float DeltaTime)
{
	if (ControlledMover == none)
		SetControlledMover();
	if (ControlledMover == none)
		return;

	if (ControlledMover.bInterpolating)
		CurrentPos = GetCurrentMoverPosition(ControlledMover);

	if (OpenPosEvent != '' && !MoverIsClosingOrClosed(ControlledMover))
	{
		GenerateMoverEvent(ControlledMover, OpenPosEvent);
		OpenPosEvent = '';
	}
	if (ClosePosEvent != '' && MoverIsClosingOrClosed(ControlledMover))
	{
		GenerateMoverEvent(ControlledMover, ClosePosEvent);
		ClosePosEvent = '';
	}
}
