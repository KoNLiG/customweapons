/*
 *  • Provide hook to block or override original weapon command like ZP does
 */

#if !defined COMPILING_FROM_MAIN
#error "Attemped to compile from the wrong file"
#endif

void AttributesMgrHooks()
{
	HookEvent("weapon_fire", AttributesMgr_OnWeaponFire, EventHookMode_Pre);
}

Action AttributesMgr_OnPlayerRunCmd(int client, int &iButtons, int iLastButtons)
{
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

	// Validate weapon and access to hook
	if (weapon == -1 || !g_Players[client].run_cmd)
	{
		return Plugin_Continue;
	}

	// Try to retrieve and validate the weapon customization data.
	// If it failed, that means that there are no customizations applied on this weapon.
	CustomWeaponData custom_weapon_data;
	if (!custom_weapon_data.GetMyself(weapon))
	{
		return Plugin_Continue;
	}

	return Call_OnRunCmd(client, weapon, iButtons, iLastButtons);
}

void AttributesMgr_OnWeaponSwitch(int client, int weapon)
{
	// Block button hook
	g_Players[client].run_cmd = false;

	// Validate weapon
	if (IsValidEdict(weapon))
	{
		// Gets last weapon index from the client
		int last = EntRefToEntIndex(g_Players[client].last_weapon_reference);

		// Validate last weapon
		if (last != -1)
		{
			if (last != weapon)
			{
				// Call forward
				Call_OnHolster(client, last);
			}
		}

		g_Players[client].last_weapon_reference = INVALID_ENT_REFERENCE;

		// Try to retrieve and validate the weapon customization data.
		// If it failed, that means that there are no customizations applied on this weapon.
		CustomWeaponData custom_weapon_data;
		if (!custom_weapon_data.GetMyself(weapon))
		{
			return;
		}

		g_Players[client].last_weapon_reference = EntIndexToEntRef(weapon);

		// Gets weapon deploy
		float flDeploy = custom_weapon_data.deploy;
		if (flDeploy != 0.0)
		{
			// Resets the instant value 
			if (flDeploy < 0.0) flDeploy = 0.0;

			// Sets next attack on the weapon
			if (flDeploy > 0.0)
			{
				flDeploy += GetGameTime();

				// Sets weapon deploy time
				AttributesSetWeaponDelay(weapon, flDeploy);

				// Sets client deploy time
				AttributesSetWeaponDelay(client, flDeploy);
			}
		}

		return;
	}

	// only trigger when weapon is not valid here
	g_Players[client].last_weapon_reference = INVALID_ENT_REFERENCE;
}

void AttributesMgr_OnWeaponSwitchPost(int client, int weapon)
{
	// Validate weapon
	if (!IsValidEdict(weapon))
	{
		return;
	}

	if (EntRefToEntIndex(g_Players[client].last_weapon_reference) == weapon)
	{
		// Allow button hook on switch finish
		g_Players[client].run_cmd = true;

		if (IsClientInGame(client) && IsPlayerAlive(client))
		{
			Call_OnDeploy(client, weapon);
		}
	}
}

Action AttributesMgr_OnWeaponReload(int weapon) 
{
	RequestFrame(AttributesMgr_OnWeaponReloadPost, EntIndexToEntRef(weapon))

	return Plugin_Continue;
}

void AttributesMgr_OnWeaponReloadPost(int refID) 
{
	// Gets weapon index from the reference
	int weapon = EntRefToEntIndex(refID);

	// Validate weapon
	if (weapon != -1)
	{
		// Try to retrieve and validate the weapon customization data.
		// If it failed, that means that there are no customizations applied on this weapon.
		CustomWeaponData custom_weapon_data;
		if (!custom_weapon_data.GetMyself(weapon))
		{
			return;
		}

		// Gets weapon owner
		int client = GetEntPropEnt(weapon, Prop_Send, "m_hOwner");
		
		// Validate owner
		if (!IsClientConnected(client) || !IsPlayerAlive(client)) 
		{
			return;
		}

		// If custom reload speed exist, then apply it
		float flReload = custom_weapon_data.reload;
		if (flReload)
		{
			// Resets the instant value 
			if (flReload < 0.0) flReload = 0.0;

			// Sets next attack on the weapon
			if (flReload > 0.0)
			{
				flReload += GetGameTime();

				// Sets weapon reload time
				AttributesSetWeaponDelay(weapon, flReload);

				// Sets client reload time
				AttributesSetClientAttack(client, flReload);
			}
		}
	}
}

public Action AttributesMgr_OnWeaponFire(Event hEvent, char[] sName, bool dontBroadcast) 
{
	// Gets all required event info
	int client = GetClientOfUserId(hEvent.GetInt("userid"));

	// Validate client
	if (!IsClientConnected(client) || IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}

	// Gets active weapon index from the client
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	
	// Validate weapon
	if (weapon == -1)
	{
		return Plugin_Continue;
	}

	AttributesMgr_OnWeaponFirePost(client, weapon);
	return Plugin_Continue;
}

void AttributesMgr_OnWeaponFirePost(int client, int weapon)
{
	// Try to retrieve and validate the weapon customization data.
	// If it failed, that means that there are no customizations applied on this weapon.
	CustomWeaponData custom_weapon_data;
	if (!custom_weapon_data.GetMyself(weapon))
	{
		return;
	}

	// Gets weapon fire speed
	float flSpeed = custom_weapon_data.speed;
	if (flSpeed != 0.0)
	{
		// Resets the instant value 
		if (flSpeed < 0.0) flSpeed = 0.0;

		// Sets next attack on the weapon
		if (flSpeed > 0.0)
		{
			flSpeed += GetGameTime();

			// Sets weapon fire time
			AttributesSetWeaponDelay(weapon, flSpeed);

			// Sets client fire time
			AttributesSetWeaponDelay(client, flSpeed);
		}
	}
}

void AttributesSetClientAttack(int client, float flDelay)
{
	SetEntPropFloat(client, Prop_Send, "m_flNextAttack", flDelay);
}

void AttributesSetWeaponDelay(int weapon, float flDelay)
{
	// Sets value on the weapon
	SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", flDelay);
	SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", flDelay);
	SetEntPropFloat(weapon, Prop_Send, "m_flTimeWeaponIdle", flDelay);
}