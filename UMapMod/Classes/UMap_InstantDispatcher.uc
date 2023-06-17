class UMap_InstantDispatcher expands Dispatcher;

var name TriggerName;
var bool bDiscardInstigator;
var bool bTriggerOnceOnly;

var private Trigger ConditionTrigger;

function SetConditionTrigger()
{
	local Trigger T;

	if (ConditionTrigger != none || TriggerName == '')
		return;
	foreach AllActors(class'Trigger', T)
		if (T.name == TriggerName)
		{
			ConditionTrigger = T;
			break;
		}
	if (ConditionTrigger == none)
		log("Warning: Trigger" @ Level.outer.name $ "." $ TriggerName @ "is not found", 'UMapMod');
	TriggerName = '';
}

function Trigger(Actor A, Pawn EventInstigator)
{
	SetConditionTrigger();
	if (ConditionTrigger != none && !ConditionTrigger.bInitiallyActive)
		return;

	if (bDiscardInstigator)
		EventInstigator = none;

	Disable('Trigger');
	for (i = 0; i < ArrayCount(OutEvents); ++i)
		TriggerEvent(OutEvents[i], self, EventInstigator);
	if (!bTriggerOnceOnly)
		Enable('Trigger');
	else
		Disable('UnTrigger');
}

function UnTrigger(Actor A, Pawn EventInstigator)
{
	SetConditionTrigger();
	if (ConditionTrigger != none && !ConditionTrigger.bInitiallyActive)
		return;

	if (bDiscardInstigator)
		EventInstigator = none;

	Disable('UnTrigger');
	for (i = 0; i < ArrayCount(OutEvents); ++i)
		UnTriggerEvent(OutEvents[i], self, EventInstigator);
	Enable('UnTrigger');
}
