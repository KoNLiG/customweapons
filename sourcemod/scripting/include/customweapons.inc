#if defined _customweapons_included
 #endinput
#endif
#define _customweapons_included

// Enumeration for weapon entity model types.
enum CustomWeapon_ModelType
{
    CustomWeaponModel_View,		/* Visible to the weapon owner only */
    CustomWeaponModel_World,	/* General model when the weapon isn't equipped by the owner */
    CustomWeaponModel_Dropped	/* Ground model */
}

methodmap CustomWeapon
{
	// Constructor of CustomWeapon. Can be used to manipulate features of a weapon entity.
	//
	// Note that this object is representing an entity reference and NOT a handle, 
	// which means that there's no need to delete it after use.
	//
	// @param entity     	The weapon entity index to perform customizations on.
	// 						This value can be accessed by many ways; most common
	//						ones are 'GetPlayerWeaponSlot()' / m_hActiveWeapon netprop /'GivePlayerItem()'.
	//
	// @return              CustomWeapon instance to the given entity, or 0 on failure.
	public native CustomWeapon(int entity);
	
	// Retrieves the weapon raw entity index.
    //
    // This native can be used to determine whether this
    // CustomWeapon data is still valid and available to use.
    //
    // Note that if this native returns -1, this means that this CustomWeapon
    // data is corrupted and can no longer be used!
    //
    // @return             Weapon entity index, or -1 if the entity is no longer available.
    property int EntityIndex
    {
        public native get();
    }
	
	// Customize the weapon model. (view, world, dropped)
	//
	// Note that the model must be precached before using this function.
	//
	// @param model_type    Model type to apply the new model on. See the enum above.
	// @param source    	New weapon model file path.
	//
	// @error				Invalid 'CustomWeapon', invalid model type, or the given model isn't precached.
	public native void SetModel(CustomWeapon_ModelType model_type, const char source[PLATFORM_MAX_PATH]);
}

#if !defined REQUIRE_PLUGIN
public void __pl_customweapons_SetNTVOptional()
{
	MarkNativeAsOptional("CustomWeapon.CustomWeapon");
	MarkNativeAsOptional("CustomWeapon.EntityIndex.get");
	MarkNativeAsOptional("CustomWeapon.SetModel");
}
#endif

public SharedPlugin __pl_customweapons = 
{
	name = "customweapons", 
	file = "customweapons.smx", 
#if defined REQUIRE_PLUGIN
    required = 1, 
#else
    required = 0, 
#endif
};
