/// Free-form eSpeak parameters for the TTS voice. Only shown/applied when the
/// selected voice is an eSpeak one; the TTS server ignores it for other engines.
/// Format: "<voice> [speed=<n>] [pitch=<n>] [amplitude=<n>]".
/datum/preference/text/tts_custom_voice
	category = PREFERENCE_CATEGORY_CHARACTER_BASICS
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "tts_custom_voice"
	maximum_value_length = 64
	can_randomize = FALSE

/datum/preference/text/tts_custom_voice/create_default_value()
	return ""

/datum/preference/text/tts_custom_voice/is_accessible(datum/preferences/preferences)
	if(!..())
		return FALSE
	if(!SStts.tts_enabled)
		return FALSE
	var/selected = preferences.read_preference(/datum/preference/choiced/voice)
	return istext(selected) && (findtext(selected, "eSpeak") || findtext(selected, "DECtalk"))

/datum/preference/text/tts_custom_voice/apply_to_human(mob/living/carbon/human/target, value)
	target.tts_custom_voice = value
