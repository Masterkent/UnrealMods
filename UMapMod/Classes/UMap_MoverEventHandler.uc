class UMap_MoverEventHandler expands Info;

var name ControllerTag;
var name MoverPosChange;
var bool bPermanentChange;
var name OpenPosEvent;
var name ClosePosEvent;

function Trigger(Actor A, Pawn EventInstigator)
{
	local UMap_MoverStateController Controller;

	foreach AllActors(class'UMap_MoverStateController', Controller, ControllerTag)
	{
		if (MoverPosChange != '')
			Controller.SetCurrentChange(MoverPosChange, bPermanentChange, A, EventInstigator);
		if (OpenPosEvent != '')
			Controller.OpenPosEvent = OpenPosEvent;
		if (ClosePosEvent != '')
			Controller.ClosePosEvent = ClosePosEvent;
		OpenPosEvent = '';
		ClosePosEvent = '';
	}
}
