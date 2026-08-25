/datum/controller/subsystem/ticker
	/// Full paths to all eligible loading-screen music tracks, played back to back in random order while current_state == GAME_STATE_STARTUP. Optional; if empty, login_music plays immediately as before.
	var/list/loading_music_tracks = list()

/datum/controller/subsystem/ticker/Initialize()
	. = ..()

	var/list/provisional_loading_music = flist("[global.config.directory]/loading_music/sounds/")
	var/list/music = list()
	var/use_rare_music = prob(1)

	for(var/S in provisional_loading_music)
		var/lower = LOWER_TEXT(S)
		var/list/L = splittext(lower, "+")
		switch(L.len)
			if(3) //rare+MAP+sound.ogg or MAP+rare.sound.ogg -- Rare Map-specific sounds
				if(use_rare_music)
					if(L[1] == "rare" && L[2] == SSmapping.current_map.map_name)
						music += S
					else if(L[2] == "rare" && L[1] == SSmapping.current_map.map_name)
						music += S
			if(2) //rare+sound.ogg or MAP+sound.ogg -- Rare sounds or Map-specific sounds
				if((use_rare_music && L[1] == "rare") || (L[1] == SSmapping.current_map.map_name))
					music += S
			if(1) //sound.ogg -- common sound
				if(L[1] == "exclude")
					continue
				music += S

	for(var/S in music)
		if(IS_SOUND_FILE(S))
			continue
		music -= S

	for(var/track_file in music)
		loading_music_tracks += "[global.config.directory]/loading_music/sounds/[track_file]"

	SSsounds.cache_sounds(loading_music_tracks) // pre-warm lengths so the first playloadingmusic() track isn't delayed by an uncached rustg lookup

	return SS_INIT_SUCCESS

// Core only refreshes the "Server rebooting in:" HUD while current_state is GAME_STATE_FINISHED, so a reboot_timer
// started mid-round (eg. the "Reboot World" admin verb) never gets shown to players. Cover that case here instead
// of touching core's fire() switch.
/datum/controller/subsystem/ticker/fire()
	. = ..()
	if(current_state == GAME_STATE_FINISHED)
		return
	if(!isnull(reboot_timer))
		if(isnull(reboot_hud))
			reboot_hud = new()
		for(var/client/C in GLOB.clients)
			if(!(reboot_hud in C.screen))
				C.screen += reboot_hud
		reboot_hud.maptext = MAPTEXT_PIXELLARI("<center>Server rebooting in:\n\ [DisplayTimeText(timeleft(reboot_timer), 1)]</center>")
	else if(!isnull(reboot_hud) && reboot_hud.maptext)
		reboot_hud.maptext = ""
		for(var/client/C in GLOB.clients)
			C.screen -= reboot_hud
