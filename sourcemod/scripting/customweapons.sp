#include <sourcemod>
#include <sdktools>
#include <customweapons>

#pragma semicolon 1
#pragma newdecls required

// External file compilation protection.
#define COMPILING_FROM_MAIN
#include "customweapons/api.sp"
#undef COMPILING_FROM_MAIN

// Used to turn off weapon shoot sounds that are client sided.
// During a use of a custom weapon shoot sound this convar will
// be replicated to the weapon owner.
ConVar weapon_sound_falloff_multiplier;

public Plugin myinfo = 
{
	name = "[CS:GO] Custom-Weapons", 
	author = "KoNLiG", 
	description = "Provides an API for custom weapons management.", 
	version = "1.0.0", 
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
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	if (!(weapon_sound_falloff_multiplier = FindConVar("weapon_sound_falloff_multiplier")))
	{
		SetFailState("Failed to find convar 'weapon_sound_falloff_multiplier'");
	}
	
	#pragma unused weapon_sound_falloff_multiplier
}

bool IsEntityWeapon(int entity)
{
	// Retrieve the entity classname.
	char classname[32];
	GetEntityClassname(entity, classname, sizeof(classname));
	
	// Remove all the characters after the 7th one. (In assume that all the first 7 characters creates 'weapon_' str)
	ReplaceString(classname, sizeof(classname), classname[7], "");
	
	// Validate the classname.
	return StrEqual(classname, "weapon_");
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
