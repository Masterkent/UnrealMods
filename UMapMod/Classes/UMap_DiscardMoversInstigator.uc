class UMap_DiscardMoversInstigator expands Info;

var private bool bInitialized;
var private array<Mover> ControlledMovers;

event Tick(float DeltaTime)
{
	if (!bInitialized)
		Init();
	bInitialized = true;
	Disable('Tick');
}

event Trigger(Actor A, Pawn EventInstigator)
{
	local int i;
	for (i = 0; i < Array_Size(ControlledMovers); ++i)
		ControlledMovers[i].Trigger(self, none);
}

event UnTrigger(Actor A, Pawn EventInstigator)
{
	local int i;
	for (i = 0; i < Array_Size(ControlledMovers); ++i)
		ControlledMovers[i].UnTrigger(self, none);
}

function Init()
{
	local Mover M;
	local int n;
	foreach AllActors(class'Mover', M, Tag)
	{
		Array_Size(ControlledMovers, n + 1);
		ControlledMovers[n] = M;
		++n;
		M.Instigator = none;
		M.Tag = StringToName("UMap_Controlled_" @ M.name);
	}
}
