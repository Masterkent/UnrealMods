class UDamageController expands Info;

var Inventory UDamage;

event BeginPlay()
{
	UDamage = Inventory(Owner);
	if (UDamage == none)
	{
		Destroy();
		return;
	}

	UDamage.bUnlit = true;
	UDamage.LightEffect = LE_NonIncidence;
	UDamage.LightBrightness = 255;
	UDamage.LightHue = 210;
	UDamage.LightRadius = 10;
	UDamage.LightSaturation = 0;
	UDamage.LightType = LT_None;
	UDamage.Style = STY_Translucent;
	UDamage.Texture = Texture(DynamicLoadObject("Botpack227_Base.Belt_fx.UDamageFX", class'Texture', true));
	if (UDamage.Texture == none)
		UDamage.Texture = Texture'UnrealShare.Belt_fx.UDamageFX';
}

event Tick(float DeltaTime)
{
	if (UDamage == none || UDamage.bDeleteMe)
	{
		Destroy();
		return;
	}

	if (UDamage.IsInState('Pickup'))
		UDamage.LightType = LT_Steady;
	else
		UDamage.LightType = LT_None;
}

defaultproperties
{
	RemoteRole=ROLE_None
}
