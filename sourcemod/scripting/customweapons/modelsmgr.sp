/*
 *  • Manage all the necessary hooks for all the model types to function properly.
 *  • Initializes client global vars that related to models.
 */

#assert defined COMPILING_FROM_MAIN

void ModelsManagerHooks()
{
	// Called in 'CBasePlayer::Spawn'.
	HookEvent("player_spawn", Event_OnPlayerSpawn);
}

// Called on 'OnClientPutInServer()'
void ModelsManagerClientHooks(int client)
{
	// Perform client SDK hooks.
	SDKHook(client, SDKHook_WeaponEquip, Hook_OnWeaponEquip);
	SDKHook(client, SDKHook_WeaponDropPost, Hook_OnWeaponDropPost);
	SDKHook(client, SDKHook_PostThinkPost, Hook_OnPostThinkPost);
}

void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client)
	{
		// Only needs to be initialized here once since CPredictedViewModel entity
		// is created for the client in 'CBasePlayer::Spawn' (`CreateViewModel();`).
		g_Players[client].InitViewModels();
	}
}

// Apply custom view model on weapons.
void ModelsMgr_OnWeaponSwitchPost(int client, int weapon)
{
	// Try to retrieve and validate the weapon customization data.
	// If it failed, that means that there are no customizations applied on this weapon.
	CustomWeaponData custom_weapon_data;
	if (!custom_weapon_data.GetMyself(weapon) || !custom_weapon_data.view_model[0])
	{
		return;
	}
	
	int predicted_view_model = g_Players[client].GetViewModel(VM_INDEX_ORIGINAL);
	if (predicted_view_model == -1)
	{
		return;
	}
	
	if (Call_OnModel(client, weapon, CustomWeaponModel_View, custom_weapon_data.view_model) >= Plugin_Handled)
	{
		return;
	}
	
	int precache_index = GetModelPrecacheIndex(custom_weapon_data.view_model);
	if (precache_index == INVALID_STRING_INDEX)
	{
		return;
	}
	
	// Remove the original model.
	SetEntProp(weapon, Prop_Send, "m_nModelIndex", -1);
	
	// Apply the new one.
	SetEntProp(predicted_view_model, Prop_Send, "m_nModelIndex", precache_index);
}

Action Hook_OnWeaponEquip(int client, int weapon)
{
	// Try to retrieve and validate the weapon customization data.
	// If it failed, that means that there are no customizations applied on this weapon.
	CustomWeaponData custom_weapon_data;
	if (!custom_weapon_data.GetMyself(weapon) || !custom_weapon_data.world_model[0])
	{
		return Plugin_Continue;
	}
	
	// A FIX for: Failed to set custom material for 'x', no matching material name found on model y
	// Not really a smart one, the real cause is unknown at the moment.
	if (custom_weapon_data.dropped_model[0] && !IsModelPrecached(custom_weapon_data.dropped_model))
	{
		PrecacheModel(custom_weapon_data.dropped_model);
	}
	
	if (Call_OnModel(client, weapon, CustomWeaponModel_World, custom_weapon_data.world_model) >= Plugin_Handled)
	{
		return Plugin_Continue;
	}
	
	int precache_index = GetModelPrecacheIndex(custom_weapon_data.world_model);
	if (precache_index == INVALID_STRING_INDEX)
	{
		return Plugin_Continue;
	}
	
	int weapon_world_model = GetEntPropEnt(weapon, Prop_Send, "m_hWeaponWorldModel");
	if (weapon_world_model != -1)
	{
		SetEntProp(weapon_world_model, Prop_Send, "m_nModelIndex", precache_index);
	}
	
	return Plugin_Continue;
}

void Hook_OnWeaponDropPost(int client, int weapon)
{
	if (weapon == -1)
	{
		return;
	}
	
	// Too early to override the dropped model here, 
	// do it in the next frame!
	RequestFrame(Frame_SetDroppedModel, EntIndexToEntRef(weapon));
}

void Frame_SetDroppedModel(any weapon_reference)
{
	int weapon = EntRefToEntIndex(weapon_reference);
	if (weapon == -1)
	{
		return;
	}
	
	// Try to retrieve and validate the weapon customization data.
	// If it failed, that means that there are no customizations applied on this weapon.
	CustomWeaponData custom_weapon_data;
	if (!custom_weapon_data.GetMyselfByReference(weapon_reference)
		 || !custom_weapon_data.dropped_model[0]
		 || Call_OnModel(0, weapon, CustomWeaponModel_Dropped, custom_weapon_data.dropped_model) >= Plugin_Handled)
	{
		return;
	}
	
	SetEntityModel(weapon, custom_weapon_data.dropped_model);
}

void Hook_OnPostThinkPost(int client)
{
	static int last_weapon[MAXPLAYERS + 1];
	static int last_sequecne[MAXPLAYERS + 1];
	static float last_cycle[MAXPLAYERS + 1];
	
	int original_vm = g_Players[client].GetViewModel(VM_INDEX_ORIGINAL), 
	custom_vm = g_Players[client].GetViewModel(VM_INDEX_CUSTOM);
	
	if (original_vm == -1 || custom_vm == -1)
	{
		return;
	}
	
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	int sequence = GetEntProp(original_vm, Prop_Send, "m_nSequence");
	float cycle = GetEntPropFloat(original_vm, Prop_Data, "m_flCycle");
	
	if (weapon <= 0)
	{
		PrintToChatAll("Pre: (weapon <= 0)");
		
		int EntEffects = GetEntProp(custom_vm, Prop_Send, "m_fEffects");
		EntEffects |= EF_NODRAW;
		SetEntProp(custom_vm, Prop_Send, "m_fEffects", EntEffects);
		
		last_weapon[client] = weapon;
		last_sequecne[client] = sequence;
		last_cycle[client] = cycle;
		
		return;
	}
	
	int entity_reference = EntIndexToEntRef(weapon);
	if (entity_reference == -1)
	{
		return;
	}
	
	// Try to retrieve and validate the weapon customization data.
	// If it failed, that means that there are no customizations applied on this weapon.
	CustomWeaponData custom_weapon_data;
	if (!g_CustomWeapons.GetArray(entity_reference, custom_weapon_data, sizeof(custom_weapon_data)))
	{
		// return;
	}
	
	/*
	int weapon = GetEntPropEnt(original_vm, Prop_Send, "m_hWeapon");
	if (weapon == -1)
	{
		return;
	}
	*/
	
	/*
	static int m_nSequenceOffset, m_flCycleOffset;
	
	if (!m_nSequenceOffset)
	{
		m_nSequenceOffset = FindSendPropInfo("CPredictedViewModel", "m_nSequence");
	}
	
	if (!m_flCycleOffset)
	{
		m_flCycleOffset = FindDataMapInfo(predicted_view_model, "m_flCycle");
	}
	
	int sequence = GetEntData(predicted_view_model, m_nSequenceOffset);
	float cycle = GetEntDataFloat(predicted_view_model, m_flCycleOffset);
	
	*/
	
	if (weapon != last_weapon[client])
	{
		PrintToChatAll("Pre: (weapon != last_weapon[client])");
		
		int EntEffects = GetEntProp(original_vm, Prop_Send, "m_fEffects");
		EntEffects |= EF_NODRAW;
		SetEntProp(original_vm, Prop_Send, "m_fEffects", EntEffects);
		
		//EntEffects = GetEntProp(custom_vm, Prop_Send, "m_fEffects");
		//EntEffects &= ~EF_NODRAW;
		//SetEntProp(custom_vm, Prop_Send, "m_fEffects", EntEffects);
		
		int precache_index = GetModelPrecacheIndex(custom_weapon_data.view_model);
		if (precache_index == INVALID_STRING_INDEX)
		{
			return;
		}
		
		// m_iViewModelIndex
		SetEntProp(weapon, Prop_Send, "m_nViewModelIndex", 0);
		// SetEntProp(weapon, Prop_Send, "m_iViewModelIndex", precache_index);
		PrintToChatAll("%d ?= %d", GetEntProp(weapon, Prop_Send, "m_iViewModelIndex"), precache_index);
		
		SetEntProp(custom_vm, Prop_Send, "m_nSequence", GetEntProp(original_vm, Prop_Send, "m_nSequence"));
		SetEntPropFloat(custom_vm, Prop_Send, "m_flPlaybackRate", GetEntPropFloat(original_vm, Prop_Send, "m_flPlaybackRate"));
	}
	else
	{
		SetEntProp(custom_vm, Prop_Send, "m_nSequence", GetEntProp(original_vm, Prop_Send, "m_nSequence"));
		SetEntPropFloat(custom_vm, Prop_Send, "m_flPlaybackRate", GetEntPropFloat(original_vm, Prop_Send, "m_flPlaybackRate"));
		
		if (cycle < last_cycle[client] && sequence == last_sequecne[client])
		{
			SetEntProp(custom_vm, Prop_Send, "m_nSequence", 0);
		}
	}
	
	last_weapon[client] = weapon;
	last_sequecne[client] = sequence;
	last_cycle[client] = cycle;
} 