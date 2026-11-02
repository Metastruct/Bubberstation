/// The TTS voice used only while whispering. `"same"` (the default) reuses the
/// normal voice. Mirrors the whisper-blooper preference.
/datum/preference/choiced/tts_whisper_voice
	category = PREFERENCE_CATEGORY_CHARACTER_BASICS
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "tts_whisper_voice"
	should_update_preview = FALSE

/datum/preference/choiced/tts_whisper_voice/is_accessible(datum/preferences/preferences)
	if(!SStts.tts_enabled)
		return FALSE
	return ..()

/datum/preference/choiced/tts_whisper_voice/init_possible_values()
	if(SStts.tts_enabled)
		return list("same") + SStts.available_speakers
	if(fexists("data/cached_tts_voices.json"))
		var/list/cached_data = json_decode(rustg_file_read("data/cached_tts_voices.json"))
		if(cached_data)
			return list("same") + cached_data
	return list("same")

/datum/preference/choiced/tts_whisper_voice/create_default_value()
	return "same"

/datum/preference/choiced/tts_whisper_voice/compile_constant_data()
	var/list/data = ..()
	data[CHOICED_PREFERENCE_DISPLAY_NAMES] = list("same" = "Same as normal voice")
	return data

/datum/preference/choiced/tts_whisper_voice/apply_to_human(mob/living/carbon/human/target, value)
	// Stale/invalid voices fall back to the normal voice rather than erroring.
	if(value == "same" || (SStts.tts_enabled && !(value in SStts.available_speakers)))
		target.tts_whisper_voice = ""
	else
		target.tts_whisper_voice = value
