/client
	/// TRUE while a playloadingmusic() loop is actively cycling tracks for this client. Lets a re-trigger (e.g. dragging the lobby volume slider) retune the playing channel instead of stacking a second parallel loop.
	var/loading_music_looping = FALSE

/// Plays loading-screen tracks back to back, picking a new random one (never immediately repeating) each time the previous one ends, until the lobby is ready and current_state leaves GAME_STATE_STARTUP.
/client/proc/playloadingmusic(volume_multiplier = 1)
	set waitfor = FALSE
	if(!length(SSticker.loading_music_tracks))
		return

	var/music_volume = prefs.read_preference(/datum/preference/numeric/volume/sound_lobby_volume) * volume_multiplier
	if(!prefs || !music_volume || CONFIG_GET(flag/disallow_title_music))
		return

	if(loading_music_looping)
		mob.set_sound_channel_volume(CHANNEL_LOBBYMUSIC, music_volume) // already looping, so just retune in place instead of restarting the track (e.g. we got re-triggered by a preference change)
		return

	loading_music_looping = TRUE
	var/last_track
	while(SSticker.current_state == GAME_STATE_STARTUP)
		var/list/choices = SSticker.loading_music_tracks.Copy()
		if(last_track && length(choices) > 1)
			choices -= last_track
		var/track = pick(choices)
		last_track = track
		SEND_SOUND(src, sound(track, repeat = 0, wait = 0, volume = music_volume, channel = CHANNEL_LOBBYMUSIC))

		var/track_length = SSsounds.get_sound_length(track)
		if(!track_length)
			break
		sleep(track_length)
	loading_music_looping = FALSE

/// Entry point for a client that just showed up at the lobby either loading_music while the server is still starting up, or title/login music once the lobby is actually ready.
/client/proc/playlobbymusic(volume_multiplier = 1)
	set waitfor = FALSE
	UNTIL(SSticker.login_music) //wait for SSticker init to set the lobby music pools

	if(length(SSticker.loading_music_tracks) && SSticker.current_state == GAME_STATE_STARTUP)
		playloadingmusic(volume_multiplier)
	else
		playtitlemusic(volume_multiplier)
