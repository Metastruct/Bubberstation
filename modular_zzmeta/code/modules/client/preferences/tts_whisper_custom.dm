/// Free-form eSpeak parameters for the whisper TTS voice. Only shown/applied
/// when the whisper voice is itself an eSpeak one. See tts_custom_voice.
/datum/preference/text/tts_whisper_custom
	category = PREFERENCE_CATEGORY_CHARACTER_BASICS
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "tts_whisper_custom"
	maximum_value_length = 64
	can_randomize = FALSE

/datum/preference/text/tts_whisper_custom/create_default_value()
	return ""

/datum/preference/text/tts_whisper_custom/is_accessible(datum/preferences/preferences)
	if(!..() || !SStts.tts_enabled)
		return FALSE
	var/selected = preferences.read_preference(/datum/preference/choiced/tts_whisper_voice)
	return istext(selected) && selected != "same" && (findtext(selected, "eSpeak") || findtext(selected, "DECtalk"))

/datum/preference/text/tts_whisper_custom/apply_to_human(mob/living/carbon/human/target, value)
	target.tts_whisper_custom = value
