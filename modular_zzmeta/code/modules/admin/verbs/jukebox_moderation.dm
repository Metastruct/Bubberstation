ADMIN_VERB(reload_jukebox_music, R_SERVER, "Jukebox Reload Music", "Rescans the jukebox music folder and refreshes all active jukeboxes.", ADMIN_CATEGORY_SERVER)
	var/list/datum/jukebox/all_jukeboxes = GLOB.jukebox_datums.Copy()
	if(!length(all_jukeboxes))
		to_chat(user, span_warning("No active jukeboxes were found to reload."))
		return

	var/list/fresh_songs = rescan_jukebox_songs()
	for(var/datum/jukebox/jukebox as anything in all_jukeboxes)
		jukebox.reload_songs(fresh_songs)

	var/msg = "[key_name_admin(user)] reloaded the jukebox music list ([length(all_jukeboxes)] jukebox(es) refreshed)."
	message_admins(msg)
	log_admin(msg)
