#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <anymap>
#include <customweapons>

#pragma semicolon 1
#pragma newdecls required

// External file compilation protection.
#define COMPILING_FROM_MAIN
#include "customweapons/structs.sp"
#include "customweapons/api.sp"
#include "customweapons/attributesmgr.sp"
#include "customweapons/modelsmgr.sp"
#include "customweapons/soundsmgr.sp"
#undef COMPILING_FROM_MAIN

// Used to call a lateload function in 'OnPluginStart()'
bool g_Lateload;

public Plugin myinfo = 
{
	name = "[CS:GO] Custom-Weapons", 
	author = "KoNLiG", 
	description = "Provides an API for custom weapons management.", 
	version = "1.0.8", 
	url = "https://github.com/KoNLiG/customweapons"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	// Lock the use of this plugin for CS:GO only.
	if (GetEngineVersion() != Engine_CSGO)
	{
		strcopy(error, err_max, "This plugin was made for use with CS:GO only.");
		return APLRes_Failure;
	}
	
	// Initialzie API stuff.
	InitializeAPI();
	
	g_Lateload = late;
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	// Initialize all global variables.
	InitializeGlobalVariables();
	
	// Perform hooks that required for sub modules.
	ModelsManagerHooks();
	SoundsManagerHooks();
	AttributesMgrHooks();
	
	// Late late function for secure measures.
	if (g_Lateload)
	{
		LateLoad();
	}
}

public void OnEntityDestroyed(int entity)
{
	// Validate the entity index. (for some reason an entity reference can by passed)
	if (entity <= 0)
	{
		return;
	}
	
	int entity_reference = EntIndexToEntRef(entity);
	
	CustomWeaponData custom_weapon_data;
	if (custom_weapon_data.GetMyselfByReference(entity_reference))
	{
		// Release the custom weapon data from the plugin.
		custom_weapon_data.RemoveMyself(entity_reference);
	}
}

public void OnClientPutInServer(int client)
{
	g_Players[client].Init(client);
	
	// Perform client hooks that required for the models manager.
	ModelsManagerClientHooks(client);
	
	// 'SDKHook_WeaponSwitchPost' SDKHook are used both in `soundsmgr.sp` and `modelsmgr.sp`,
	// theirfore we will hook it globaly and each subfile will use sepearated "callback".
	SDKHook(client, SDKHook_WeaponSwitch, Hook_OnWeaponSwitch);
	SDKHook(client, SDKHook_WeaponSwitchPost, Hook_OnWeaponSwitchPost);
}

void Hook_OnWeaponSwitch(int client, int weapon) 
{
	AttributesMgr_OnWeaponSwitch(client, weapon);
}

void Hook_OnWeaponSwitchPost(int client, int weapon)
{
	ModelsMgr_OnWeaponSwitchPost(client, weapon);
	SoundsMgr_OnWeaponSwitchPost(client, weapon);
	AttributesMgr_OnWeaponSwitchPost(client, weapon);
}

public void OnClientDisconnect(int client)
{
	// Frees the slot data.
	g_Players[client].Close();
}

/**
 * @brief Called when a clients movement buttons are being processed.
 *  
 * @param client            The client index.
 * @param iButtons          Copyback buffer containing the current commands. (as bitflags - see entity_prop_stocks.inc)
 * @param iImpulse          Copyback buffer containing the current impulse command.
 * @param flVelocity        Players desired velocity.
 * @param flAngles          Players desired view angles.    
 * @param weaponID          The entity index of the new weapon if player switches weapon, 0 otherwise.
 * @param iSubType          Weapon subtype when selected from a menu.
 * @param iCmdNum           Command number. Increments from the first command sent.
 * @param iTickCount        Tick count. A client prediction based on the server GetGameTickCount value.
 * @param iSeed             Random seed. Used to determine weapon recoil, spread, and other predicted elements.
 * @param iMouse            Mouse direction (x, y).
 **/ 
public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float flVelocity[3], float flAngles[3], int &weaponID, int &iSubType, int &iCmdNum, int &iTickCount, int &iSeed, int iMouse[2])
{
	// Initialize variables
	Action hResult; static int iLastButtons[MAXPLAYERS+1];

	// If the client is alive, than continue
	if (IsPlayerAlive(client))
	{
		// Dublicate the button buffer
		int iButton = iButtons; /// for weapon forward
		
		// Forward event to modules
		hResult = AttributesMgr_OnPlayerRunCmd(client, iButtons, iLastButtons[client]);
		
		// Store the previous button
		iLastButtons[client] = iButton;
		
		// Allow button
		return hResult;
	}

	return Plugin_Continue;
}

bool IsEntityWeapon(int entity)
{
	// Retrieve the entity classname.
	char classname[32];
	GetEntityClassname(entity, classname, sizeof(classname));
	
	// Validate the classname.
	return !StrContains(classname, "weapon_");
}

// Retrieves a model precache index.
// This is efficient since extra 'PrecacheModel()' function call isn't necessary here.
// Returns INVALID_STRING_INDEX if the model isn't precached.
stock int GetModelPrecacheIndex(const char[] filename)
{
	static int table = INVALID_STRING_TABLE;
	
	if (table == INVALID_STRING_TABLE)
	{
		table = FindStringTable("modelprecache");
	}
	
	return FindStringIndex(table, filename);
}

void LateLoad()
{
	for (int current_client = 1; current_client <= MaxClients; current_client++)
	{
		if (IsClientInGame(current_client))
		{
			OnClientPutInServer(current_client);
			
			// Late load initialization.
			g_Players[current_client].InitViewModel();
		}
	}
}

void ReEquipWeaponEntity(int weapon, int weapon_owner = -1)
{
	if ((weapon_owner == -1 && (weapon_owner = GetEntPropEnt(weapon, Prop_Data, "m_hOwnerEntity")) == -1) || !IsClientOwnWeapon(weapon_owner, weapon))
	{
		return;
	}
	
	// Remove the weapon.
	RemovePlayerItem(weapon_owner, weapon);
	
	// Equip the weapon back in a frame.
	DataPack dp = new DataPack();
	dp.WriteCell(GetClientUserId(weapon_owner));
	dp.WriteCell(EntIndexToEntRef(weapon));
	dp.Reset();
	
	RequestFrame(Frame_EquipWeapon, dp);
}

void Frame_EquipWeapon(DataPack dp)
{
	int client = GetClientOfUserId(dp.ReadCell());
	int weapon = EntRefToEntIndex(dp.ReadCell());
	
	if (client && weapon != -1)
	{
		EquipPlayerWeapon(client, weapon);
	}
	
	dp.Close();
} 

bool IsClientOwnWeapon(int client, int weapon)
{
	int max_weapons = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
	
	for (int current_weapon, ent = -1; current_weapon < max_weapons; current_weapon++)
	{
		if ((ent = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", current_weapon)) != -1 && ent == weapon)
		{
			return true;
		}
	}
	
	return false;
}