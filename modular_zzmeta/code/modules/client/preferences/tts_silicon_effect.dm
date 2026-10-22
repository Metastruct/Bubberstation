/// Which filter the TTS server applies to silicon (borg/AI) voices.
/datum/preference/choiced/tts_silicon_effect
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_identifier = PREFERENCE_PLAYER
	savefile_key = "tts_silicon_effect"

/datum/preference/choiced/tts_silicon_effect/is_accessible(datum/preferences/preferences)
	if(!SStts.tts_enabled)
		return FALSE
	return ..()

/datum/preference/choiced/tts_silicon_effect/init_possible_values()
	return list("blend", "echo", "impulse", "ringmod", "comb", "heavy", "none")

/datum/preference/choiced/tts_silicon_effect/create_default_value()
	return "blend"

/datum/preference/choiced/tts_silicon_effect/compile_constant_data()
	var/list/data = ..()
	data[CHOICED_PREFERENCE_DISPLAY_NAMES] = list(
		"blend" = "Machine (default)",
		"echo" = "Echo (classic)",
		"impulse" = "Metallic Machine",
		"ringmod" = "Robot (ring mod)",
		"comb" = "Metallic Comb",
		"heavy" = "Heavy Robot",
		"none" = "None",
	)
	return data
