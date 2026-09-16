SUBSYSTEM_DEF(assets)
	name = "Assets"
	dependencies = list(
		/datum/controller/subsystem/atoms,
		/datum/controller/subsystem/persistent_paintings,
		/datum/controller/subsystem/greyscale_previews,
	)
	ss_flags = SS_NO_FIRE
	var/list/datum/asset_cache_item/cache = list()
	var/list/preload = list()
	var/datum/asset_transport/transport = new()

/datum/controller/subsystem/assets/OnConfigLoad()
	var/newtransporttype = /datum/asset_transport
	switch (CONFIG_GET(string/asset_transport))
		if ("webroot")
			newtransporttype = /datum/asset_transport/webroot

	if (newtransporttype == transport.type)
		return

	var/datum/asset_transport/newtransport = new newtransporttype ()
	if (newtransport.validate_config())
		transport = newtransport
	transport.Load()

/datum/controller/subsystem/assets/Initialize()
	for(var/datum/asset/asset_type as anything in valid_subtypesof(/datum/asset))
		load_asset_datum(asset_type)

	transport.Initialize(cache)

	// META EDIT - ADDITION - START - ICON_REF_MAP_GAGS_LATE_REGEN
	// icon_ref_map's early pass runs before mapping/atoms, so GAGS colors only
	// generated lazily by map-placed instances aren't interned yet. Regenerate now
	// that atoms (thus mapping) has finished. Client picks up the new url via the
	// normal per-window asset resend, see tgui's assets.ts handler.
	var/datum/asset/json/icon_ref_map/icon_ref_map = get_asset_datum(/datum/asset/json/icon_ref_map)
	icon_ref_map.regenerate()
	// META EDIT - ADDITION - END - ICON_REF_MAP_GAGS_LATE_REGEN

	return SS_INIT_SUCCESS

/datum/controller/subsystem/assets/Recover()
	cache = SSassets.cache
	preload = SSassets.preload
