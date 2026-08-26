/// Maps icon names to ref values
/datum/asset/json/icon_ref_map
	name = "icon_ref_map"
	early = TRUE
	// META EDIT - ADDITION - START - ICON_REF_MAP_INCREMENTAL_SCAN
	/// Path -> ref map accumulated across calls to generate(), so a mid-round
	/// regen only scans resources added since the last scan instead of redoing
	/// the whole resource table (this used to cost ~770ms per regen once a
	/// round had generated a few thousand GAGS icons).
	var/list/cached_data = list()
	/// Highest resource ref index already scanned by generate().
	var/last_scanned_value = 0
	// META EDIT - ADDITION - END - ICON_REF_MAP_INCREMENTAL_SCAN

/datum/asset/json/icon_ref_map/generate()
	// META EDIT - REMOVAL - START - ICON_REF_MAP_INCREMENTAL_SCAN
	/* ORIGINAL:
	var/list/data = list() //"icons/obj/drinks.dmi" => "[0xc000020]"

	//var/start = "0xc000000"
	var/value = 0
	*/
	// META EDIT - REMOVAL - END - ICON_REF_MAP_INCREMENTAL_SCAN
	// META EDIT - ADDITION - START - ICON_REF_MAP_INCREMENTAL_SCAN
	var/value = last_scanned_value // resume from where the last scan left off instead of rescanning from 1
	// META EDIT - ADDITION - END - ICON_REF_MAP_INCREMENTAL_SCAN

	while(TRUE)
		value += 1
		var/ref = "\[0xc[num2text(value,6,16)]\]"
		var/mystery_meat = locate(ref)

		if(isicon(mystery_meat))
			if(!isfile(mystery_meat)) // Ignore the runtime icons for now
				continue
			var/path = get_icon_dmi_path(mystery_meat) //Try to get the icon path
			if(path)
				cached_data[path] = ref // META EDIT - CHANGE - accumulate into the persistent map instead of a fresh local - ICON_REF_MAP_INCREMENTAL_SCAN
		else if(mystery_meat)
			continue; //Some other non-icon resource, ogg/json/whatever
		else //Out of resources end this, could also try to end this earlier as soon as runtime generated icons appear but eh
			break;

	// META EDIT - REMOVAL - START - ICON_REF_MAP_INCREMENTAL_SCAN
	/* ORIGINAL:
	return data
	*/
	// META EDIT - REMOVAL - END - ICON_REF_MAP_INCREMENTAL_SCAN
	// META EDIT - ADDITION - START - ICON_REF_MAP_INCREMENTAL_SCAN
	// Re-check the boundary ref next time too, since a new resource can land
	// exactly on the index that was previously the "end of resources" hole.
	last_scanned_value = value - 1
	return cached_data
	// META EDIT - ADDITION - END - ICON_REF_MAP_INCREMENTAL_SCAN

// META EDIT - ADDITION - START - ICON_REF_MAP_GAGS_LATE_REGEN
// Debounced regen for GAGS combos generated after the one-shot post-mapload
// regen in SSassets/Initialize(). TIMER_UNIQUE coalesces bursts into one call.
/datum/asset/json/icon_ref_map/proc/schedule_regenerate()
	addtimer(CALLBACK(src, PROC_REF(regenerate)), 2 SECONDS, TIMER_UNIQUE)
// META EDIT - ADDITION - END - ICON_REF_MAP_GAGS_LATE_REGEN
