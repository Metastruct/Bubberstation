/client/proc/playloadingmusic(volume_multiplier = 1)
	set waitfor = FALSE
	if(!SSticker.loading_music)
		return

	var/music_volume = prefs.read_preference(/datum/preference/numeric/volume/sound_lobby_volume) * volume_multiplier
	if((prefs && music_volume) && !CONFIG_GET(flag/disallow_title_music))
		SEND_SOUND(src, sound(SSticker.loading_music, repeat = 0, wait = 0, volume = music_volume, channel = CHANNEL_LOBBYMUSIC))

/// Entry point for a client that just showed up at the lobby either loading_music while the server is still starting up, or title/login music once the lobby is actually ready.
/client/proc/playlobbymusic(volume_multiplier = 1)
	set waitfor = FALSE
	UNTIL(SSticker.login_music) //wait for SSticker init to set the lobby music pools

	if(SSticker.loading_music && SSticker.current_state == GAME_STATE_STARTUP)
		playloadingmusic(volume_multiplier)
	else
		playtitlemusic(volume_multiplier)
