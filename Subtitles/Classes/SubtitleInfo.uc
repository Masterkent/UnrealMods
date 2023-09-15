class SubtitleInfo expands ReplicationInfo;

var string Subtitle;
var SubtitleInfo NextSubtitleInfo; // for other players
var SubtitleRenderer SubtitleRenderer;

replication
{
	reliable if (Role == ROLE_Authority)
		Subtitle;
}

simulated event PostNetReceive()
{
	UpdateSubtitle();
}

simulated event Destroyed()
{
	if (SubtitleRenderer != none && --SubtitleRenderer.RefCount <= 0)
		SubtitleRenderer.Destroy();
	if (NextSubtitleInfo != none)
		NextSubtitleInfo.Destroy();
}

simulated function Init()
{
	SubtitleRenderer = SubtitleRenderer(Level.GetLocalPlayerPawn().myHUD.AddOverlay(class'SubtitleRenderer', true));
	if (SubtitleRenderer != none)
		SubtitleRenderer.RefCount += 1;
}

function SetSubtitle(string NewSubtitle)
{
	Subtitle = NewSubtitle;
	if (Level.NetMode != NM_DedicatedServer && (bAlwaysRelevant || Instigator == Level.GetLocalPlayerPawn()))
		UpdateSubtitle();
	if (NextSubtitleInfo != none)
		NextSubtitleInfo.SetSubtitle(NewSubtitle);
}

simulated function UpdateSubtitle()
{
	if (SubtitleRenderer == none)
		Init();
	if (SubtitleRenderer != none)
		SubtitleRenderer.SetSubtitle(Subtitle);
}

defaultproperties
{
	bAlwaysRelevant=False
	bNetNotify=True
	RemoteRole=ROLE_SimulatedProxy
}
