/// Last known "mainwindow" size string (see SKIN_MAINWINDOW), cached by SSchat_resize_watcher to detect a resize.
/client/var/chat_resize_watcher_last_size

/datum/preference/toggle/auto_fix_chat_resize
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_key = "auto_fix_chat_resize"
	savefile_identifier = PREFERENCE_PLAYER
	// /datum/preference/toggle defaults default_value to TRUE, this one is opt-in due to the winget() polling cost
	default_value = FALSE

/**
 * Periodically checks opted-in clients' main window size and, if it changed since the last check,
 * redocks the chat panel (see /client/proc/nuke_chat(), same thing the "Fix chat" verb does).
 *
 * BYOND has no resize event DM code can hook into, so this has to poll instead of reacting to a signal.
 * This is the same limitation /client/proc/attempt_auto_fit_viewport() works around for the map viewport,
 * except that one only re-fits after a DM-triggered zoom/fullscreen change, since there's nothing else it
 * can hook either, it just happens to cover the common cases. A manual window drag needs actual polling.
 */
SUBSYSTEM_DEF(chat_resize_watcher)
	name = "Chat Resize Watcher"
	wait = 10 SECONDS
	priority = FIRE_PRIORITY_DEFAULT
	init_stage = INITSTAGE_LAST

/datum/controller/subsystem/chat_resize_watcher/fire()
	for(var/client/watched_client as anything in GLOB.clients)
		if(!watched_client.prefs?.read_preference(/datum/preference/toggle/auto_fix_chat_resize))
			continue
		var/current_size = winget(watched_client, SKIN_MAINWINDOW, "size")
		if(watched_client.chat_resize_watcher_last_size && watched_client.chat_resize_watcher_last_size != current_size)
			watched_client.nuke_chat()
		watched_client.chat_resize_watcher_last_size = current_size
		if(MC_TICK_CHECK)
			return
