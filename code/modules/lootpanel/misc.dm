/// Helper to open the panel
/datum/lootpanel/proc/open(turf/tile)
	// META EDIT - ADDITION - START - LOOTPANEL_STALE_ICON_REFETCH
	// Contents are already kept in sync live via the signals registered below (items
	// entering/leaving/moving, turf changes), so re-alt-clicking the same tile doesn't
	// need a full rebuild. Without this, every re-click tore down and re-fetched every
	// icon on the tile from scratch, including ones that hadn't changed (e.g. lights).
	var/turf_changed = (tile != source_turf)
	// META EDIT - ADDITION - END - LOOTPANEL_STALE_ICON_REFETCH
	if (tile != source_turf)
		if (source_turf)
			UnregisterSignal(source_turf, list(COMSIG_ATOM_ENTERED, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON))
		RegisterSignals(tile, list(COMSIG_ATOM_ENTERED, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON), PROC_REF(on_source_turf_entered))

	source_turf = tile

#if !defined(OPENDREAM) && !defined(UNIT_TESTS)
	if(!notified)
		var/build = owner.byond_build
		var/version = owner.byond_version
		if(build < 515 || (build == 515 && version < 1635))
			to_chat(owner.mob, boxed_message(span_info("\
				<span class='bolddanger'>Your version of Byond doesn't support fast image loading.</span>\n\
				Detected: [version].[build]\n\
				Required version for this feature: <b>515.1635</b> or later.\n\
				Visit <a href=\"https://secure.byond.com/download\">BYOND's website</a> to get the latest version of BYOND.\n\
			")))

			notified = TRUE
#endif

	// META EDIT - CHANGE - START - LOOTPANEL_STALE_ICON_REFETCH
	/* ORIGINAL:
	populate_contents()
	*/
	if (turf_changed || !length(contents))
		populate_contents()
	// META EDIT - CHANGE - END - LOOTPANEL_STALE_ICON_REFETCH
	ui_interact(owner.mob)


/**
 * Called by SSlooting whenever this datum is added to its backlog.
 * Iterates over to_image list to create icons, then removes them.
 * Returns boolean - whether this proc has finished the queue or not.
 */
/datum/lootpanel/proc/process_images()
	// META EDIT - CHANGE - START - LOOTPANEL_STALE_ICON_REFETCH
	/* ORIGINAL:
	for(var/datum/search_object/index as anything in to_image)
	*/
	// Removing the current element from to_image while iterating over that same live
	// list causes BYOND's for-loop to skip every other entry, so only about half the
	// queued icons were actually generated per subsystem tick; the rest lingered as
	// spinners until later ticks. Iterate a snapshot instead.
	for(var/datum/search_object/index as anything in to_image.Copy())
	// META EDIT - CHANGE - END - LOOTPANEL_STALE_ICON_REFETCH
		to_image -= index

		if(QDELETED(index) || index.icon)
			continue

		index.generate_icon(owner)

		if(TICK_CHECK)
			break

	var/datum/tgui/window = SStgui.get_open_ui(owner.mob, src)
	if(isnull(window))
		reset_contents()
		return TRUE

	window.send_update()

	return !length(to_image)
