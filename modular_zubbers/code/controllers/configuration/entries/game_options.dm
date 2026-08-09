/// Offsets the station time (in minutes) compared to the system clock
/datum/config_entry/number/shift_time_clock_offset
	default = 0
	min_val = 0
	max_val = 1439

/// If enabled, prevents falling back to the default title music (sound/music/lobby_music) when config/title_music/sounds is empty. Has no effect if a custom title music track is configured.
/datum/config_entry/flag/disallow_default_title_music
