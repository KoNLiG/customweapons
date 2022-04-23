/*
 *  • Overrides the default game shoot sound with a custom ones.
 *  • 
 */

#if !defined COMPILING_FROM_MAIN
#error "Attemped to compile from the wrong file"
#endif

// 'm_hActiveWeapon' netprop offset.
int m_hActiveWeaponOffset;

void SoundsManagerHooks()
{
	if ((m_hActiveWeaponOffset = FindSendPropInfo("CBasePlayer", "m_hActiveWeapon")) <= 0)
	{
		SetFailState("Failed to find offset 'CBasePlayer::m_hActiveWeapon'");
	}
	
	// Hook shoots temp entity to prevent their sound effect. (CTEFireBullets)
	AddTempEntHook("Shotgun Shot", Hook_OnShotgunShot);
}

// Client side.
void SoundsMgr_OnWeaponSwitchPost(int client, int weapon)
{
	CheckPlayerWeaponSounds(client, weapon);
}

void CheckPlayerWeaponSounds(int client, int weapon)
{
	CustomWeaponData custom_weapon_data;
	
	if (custom_weapon_data.GetMyself(weapon) && custom_weapon_data.HasCustomShootSound())
	{
		if (g_Players[client].default_sounds_enabled)
		{
			CreateToggleDefaultSoundsTimer(client, weapon, false);
			
			g_Players[client].default_sounds_enabled = false;
		}
	}
	else if (!g_Players[client].default_sounds_enabled)
	{
		CreateToggleDefaultSoundsTimer(client, weapon, true);
		
		g_Players[client].default_sounds_enabled = true;
	}
}

void CreateToggleDefaultSoundsTimer(int client, int weapon, bool value)
{
	// Truncates the old timer. (if exists)
	delete g_Players[client].toggle_sounds_timer;
	
	// Create a new one!
	DataPack dp;
	g_Players[client].toggle_sounds_timer = CreateDataTimer(GetEntPropFloat(client, Prop_Send, "m_flNextAttack") - GetGameTime() - 0.1, Timer_ToggleDefaultSounds, dp);
	dp.WriteCell(GetClientUserId(client));
	dp.WriteCell(EntIndexToEntRef(weapon));
	dp.WriteCell(value);
	dp.Reset();
}

Action Timer_ToggleDefaultSounds(Handle timer, DataPack dp)
{
	int client = GetClientOfUserId(dp.ReadCell());
	if (!client)
	{
		return Plugin_Continue;
	}
	
	int weapon = EntRefToEntIndex(dp.ReadCell())
	if (weapon == -1)
	{
		return Plugin_Continue;
	}
	
	g_Players[client].ToggleDefaultShootSounds(dp.ReadCell());
	
	g_Players[client].toggle_sounds_timer = null;
	
	return Plugin_Continue;
}

// Server side.
Action Hook_OnShotgunShot(const char[] teName, const int[] players, int numClients, float delay)
{
	int client = TE_ReadNum("m_iPlayer") + 1;
	
	int weapon = GetEntDataEnt2(client, m_hActiveWeaponOffset);
	
	// Weapon is unavailable?
	if (weapon == -1)
	{
		return Plugin_Continue;
	}
	
	// Try to retrieve and validate the weapon customization data.
	// If it failed, that means that there are no customizations applied on this weapon.
	CustomWeaponData custom_weapon_data;
	if (!custom_weapon_data.GetMyself(weapon) || !custom_weapon_data.HasCustomShootSound())
	{
		return Plugin_Continue;
	}
	
	if (Call_OnSound(client, weapon, custom_weapon_data.shoot_sound) >= Plugin_Handled)
	{
		g_Players[client].ToggleDefaultShootSounds(true);
		
		g_Players[client].default_sounds_enabled = false;
		
		return Plugin_Continue;
	}
	
	float origin[3];
	GetClientAbsOrigin(client, origin);
	EmitAmbientSound(custom_weapon_data.shoot_sound, origin, client, .vol = 0.2);
	
	// Block the original sound
	return Plugin_Stop;
} 