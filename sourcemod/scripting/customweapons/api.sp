/*
 *  • Registeration of all natives and forwards.
 *  • Registeration of the plugin library.
 */

#if !defined COMPILING_FROM_MAIN
#error "Attemped to compile from the wrong file"
#endif

#define VALIDATE_CUSTOM_WEAPON(%1) if (EntRefToEntIndex(view_as<int>(%1)) == INVALID_ENT_REFERENCE) ThrowError("Invalid CustomWeapon")

// Global forward handles.
// GlobalForward g_OnConfigLoaded;

void InitializeAPI()
{
	CreateNatives();
	// CreateForwards();
	
	RegPluginLibrary("customweapons");
}

// Natives
void CreateNatives()
{
	// CustomWeapon(int entity)
	CreateNative("CustomWeapon.CustomWeapon", Native_CustomWeapon);
	
	CreateNative("CustomWeapon.EntityIndex.get", Native_GetEntityIndex);
	
	// void SetModel(CustomWeapon_ModelType model_type, const char[] source)
	CreateNative("CustomWeapon.SetModel", Native_SetModel);
}

any Native_CustomWeapon(Handle plugin, int numParams)
{
	// Param 1: 'entity'
	int entity = GetNativeCell(1);
	
	if (!(0 <= entity <= GetMaxEntities()))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Entity index out of bounds. (%d)", entity);
	}
	
	if (!IsValidEntity(entity))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not valid", entity);
	}
	
	if (!IsEntityWeapon(entity))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Entity %d is not a valid weapon", entity);
	}
	
	int entity_reference = EntIndexToEntRef(entity);
	if (entity_reference == INVALID_ENT_REFERENCE)
	{
		return 0;
	}
	
	return view_as<CustomWeapon>(entity_reference);
}

any Native_GetEntityIndex(Handle plugin, int numParams)
{
	// Param 1: 'CustomWeapon' [this] / entity reference
	int entity_reference = GetNativeCell(1);
	
	if (!entity_reference)
	{
		return -1;
	}
	
	return EntRefToEntIndex(entity_reference);
}

any Native_SetModel(Handle plugin, int numParams)
{
	// Param 1: 'CustomWeapon' [this]
	CustomWeapon custom_weapon = GetNativeCell(1);
	
	VALIDATE_CUSTOM_WEAPON(custom_weapon);
	
	// Param 2: 'model_type'
	CustomWeapon_ModelType model_type = GetNativeCell(2);
	
	// Param 3: 'source'
	char source[PLATFORM_MAX_PATH];
	
	// Check for any errors.
	Native_CheckStringParamLength(3, "model file path", sizeof(source));
	
	GetNativeString(3, source, sizeof(source));
	
	int model_index = GetModelPrecacheIndex(source);
	if (model_index == INVALID_STRING_INDEX)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Custom model is not precached (%s)", source);
	}
	
	switch (model_type)
	{
		case CustomWeaponModel_View:
		{
			
		}
		case CustomWeaponModel_World:
		{
			
		}
		case CustomWeaponModel_Dropped:
		{
			
		}
		// Invalid model type, throw an expection.
		default:
		{
			ThrowNativeError(SP_ERROR_NATIVE, "Invalid specified model type (%d)", model_type);
		}
	}
	
	return 0;
}

void Native_CheckStringParamLength(int param_number, const char[] item_name, int max_length, bool can_be_empty = false, int &param_length = 0)
{
	int error;
	
	if ((error = GetNativeStringLength(param_number, param_length)) != SP_ERROR_NONE)
	{
		ThrowNativeError(error, "Failed to retrieve %s.", item_name);
	}
	
	if (!can_be_empty && !param_length)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "%s cannot be empty.", item_name);
	}
	
	if (param_length >= max_length)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "%s cannot be %d characters long (max: %d)", item_name, param_length, max_length - 1);
	}
} 