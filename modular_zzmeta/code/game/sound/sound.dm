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

	var/list/remaining_to_shuffle = SSticker.loading_music_tracks.Copy()
	var/list/queue = list()
	while(length(remaining_to_shuffle))
		var/shuffled_track = pick(remaining_to_shuffle)
		queue += shuffled_track
		remaining_to_shuffle -= shuffled_track

	var/last_track
	while(SSticker.current_state == GAME_STATE_STARTUP)
		if(!length(queue))
			queue = SSticker.loading_music_tracks.Copy()
			if(last_track && length(queue) > 1)
				queue -= last_track

		var/track = queue[1]
		queue.Cut(1, 2)
		last_track = track

		var/track_length = SSsounds.get_sound_length(track)
		if(!track_length)
			break
		SEND_SOUND(src, sound(track, repeat = 0, wait = 0, volume = music_volume, channel = CHANNEL_LOBBYMUSIC))

		// Sleep in short chunks so the lobby becoming ready mid-track is noticed within a second, instead of only once the whole track finishes.
		var/elapsed = 0
		while(elapsed < track_length && SSticker.current_state == GAME_STATE_STARTUP)
			var/chunk = min(1 SECONDS, track_length - elapsed)
			sleep(chunk)
			elapsed += chunk
	loading_music_looping = FALSE
	// SSticker's own GAME_STATE_STARTUP -> GAME_STATE_PREGAME transition already calls playtitlemusic() on every new_player client, so this loop doesn't need to also trigger it, which would restart login_music a second time.

/// Entry point for a client that just showed up at the lobby either loading_music while the server is still starting up, or title/login music once the lobby is actually ready.
/client/proc/playlobbymusic(volume_multiplier = 1)
	set waitfor = FALSE
	UNTIL(SSticker.login_music) //wait for SSticker init to set the lobby music pools

	if(length(SSticker.loading_music_tracks) && SSticker.current_state == GAME_STATE_STARTUP)
		playloadingmusic(volume_multiplier)
	else
		playtitlemusic(volume_multiplier)
