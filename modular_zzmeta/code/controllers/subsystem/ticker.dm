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
