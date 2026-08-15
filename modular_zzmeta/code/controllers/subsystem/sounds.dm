/// Core's find_all_available_sounds() only ever walks the top-level sound/ directory, correct for
/// vanilla tgstation, which has no modular split, but this fork keeps real sound files under
/// modular_zubbers/, modular_zzmeta/, and modular_skyrat/ too, scattered across many per-feature
/// sound/ subfolders. None of those ever made it into SSsounds.all_sounds, so they were invisible
/// to the Audio Browser (and its search) even though they're perfectly playable via playsound().
/datum/controller/subsystem/sounds/find_all_available_sounds()
	. = ..()
	var/static/list/modular_sound_extensions = list(
		".ogg",
		".mp3",
		".mid",
		".midi",
		".mod",
		".it",
		".s3m",
		".xm",
		".oxm",
		".wav",
		".wma",
		".aiff",
	)
	for(var/modular_root in list("modular_zubbers/", "modular_zzmeta/", "modular_skyrat/"))
		all_sounds += pathwalk(modular_root, modular_sound_extensions)
