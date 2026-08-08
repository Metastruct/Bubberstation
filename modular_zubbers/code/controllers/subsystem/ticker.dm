/datum/controller/subsystem/ticker
	var/list/job_estimation_list = list()
	/// Music played only while the server is still loading (current_state == GAME_STATE_STARTUP). Optional - if no loading tracks are configured, login_music plays immediately as before.
	var/loading_music
	/// TRUE if login_music was picked from the fallback (sound/music/lobby_music) rather than an admin-configured config/title_music/sounds track.
	var/title_music_is_default = TRUE

/datum/controller/subsystem/ticker/Initialize()
	. = ..()

	var/list/provisional_custom_title_music = flist("[global.config.directory]/title_music/sounds/")
	for(var/S in provisional_custom_title_music)
		if(LOWER_TEXT(S) == "exclude")
			continue
		if(!IS_SOUND_FILE(S))
			continue
		title_music_is_default = FALSE
		break

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

	if(length(music))
		loading_music = "[global.config.directory]/loading_music/sounds/[pick(music)]"

	return SS_INIT_SUCCESS

/datum/controller/subsystem/ticker/proc/get_job_estimation(list/players)
	var/list/player_ready_data = list()
	sortTim(players, GLOBAL_PROC_REF(cmp_text_asc))

	for(var/ckey in players)
		var/mob/dead/new_player/player = players[ckey]
		var/datum/preferences/prefs = player.client?.prefs
		var/display = null
		var/datum/job/job_estimation = prefs?.get_highest_priority_job()
		var/title = job_estimation?.title
		// If a player does not have preferences (for some reason) or they don't want to be shown on the panel, continue
		if(!job_estimation || !(prefs.read_preference(/datum/preference/toggle/ready_job)))
			continue

		// If the job the player is selecting has a special name, that name should be displayed in the menu, otherwise it should use the normal name
		switch(title)
			if(JOB_AI)
				display = prefs.read_preference(/datum/preference/name/ai)
			if(JOB_CLOWN)
				display = prefs.read_preference(/datum/preference/name/clown)
			if(JOB_CYBORG)
				display = prefs.read_preference(/datum/preference/name/cyborg)
			if(JOB_MIME)
				display = prefs.read_preference(/datum/preference/name/mime)
			else
				display = prefs.read_preference(/datum/preference/name/real_name)
		// If our player is a member of Command or a Silicon, we want to sort them to the top of the list. Otherwise, just add them to the end of the list.
		if(job_estimation.departments_bitflags & (DEPARTMENT_BITFLAG_COMMAND | DEPARTMENT_BITFLAG_SILICON))
			player_ready_data.Insert(1, "* [display] as [title]")
		else
			player_ready_data += "* [display] as [title]"

	// The title line for the job estimation panel, obviously needs to be at the top
	if(length(player_ready_data))
		player_ready_data.Insert(1, "------------------")
		player_ready_data.Insert(1, "Job Estimation:")
		player_ready_data.Insert(1, "")
	return player_ready_data
