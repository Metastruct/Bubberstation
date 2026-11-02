/// Middleware to handle quirks
/datum/preference_middleware/tts
	/// Cooldown on requesting a TTS preview.
	COOLDOWN_DECLARE(tts_test_cooldown)

	action_delegations = list(
		"play_voice" = PROC_REF(play_voice),
		"play_voice_robot" = PROC_REF(play_voice_robot),
		"play_blips" = PROC_REF(play_blips),
		"play_whisper_voice" = PROC_REF(play_whisper_voice), // META EDIT - ADDITION - TTS_WHISPER_CUSTOM
	)

/datum/preference_middleware/tts/proc/play_voice(list/params, mob/user)
	if(!COOLDOWN_FINISHED(src, tts_test_cooldown))
		return TRUE
	var/speaker = preferences.read_preference(/datum/preference/choiced/voice)
	var/pitch = preferences.read_preference(/datum/preference/numeric/tts_voice_pitch)
	var/blip_base = preferences.read_preference(/datum/preference/choiced/tts_blip_base)
	if(blip_base == TTS_BLIPS_MASCULINE)
		blip_base = "male"
	else
		blip_base = "female"
	var/blip_number = preferences.read_preference(/datum/preference/numeric/tts_blip_number)
	COOLDOWN_START(src, tts_test_cooldown, 0.5 SECONDS)
	INVOKE_ASYNC(SStts, TYPE_PROC_REF(/datum/controller/subsystem/tts, queue_tts_message), user.client, "Hello, this is my voice.", speaker = speaker, pitch = pitch, local = TRUE, blip_base = blip_base, blip_number = blip_number, custom_voice = preferences.read_preference(/datum/preference/text/tts_custom_voice)) // META EDIT - CHANGE - TTS_ESPEAK_CUSTOM_VOICE
	return TRUE

/datum/preference_middleware/tts/proc/play_voice_robot(list/params, mob/user)
	if(!COOLDOWN_FINISHED(src, tts_test_cooldown))
		return TRUE
	var/speaker = preferences.read_preference(/datum/preference/choiced/voice)
	var/pitch = preferences.read_preference(/datum/preference/numeric/tts_voice_pitch)
	var/blip_base = preferences.read_preference(/datum/preference/choiced/tts_blip_base)
	if(blip_base == TTS_BLIPS_MASCULINE)
		blip_base = "male"
	else
		blip_base = "female"
	var/blip_number = preferences.read_preference(/datum/preference/numeric/tts_blip_number)
	// META EDIT - ADDITION - START - TTS_SILICON_EFFECT
	var/silicon_effect = preferences.read_preference(/datum/preference/choiced/tts_silicon_effect) || "blend"
	// META EDIT - ADDITION - END - TTS_SILICON_EFFECT
	COOLDOWN_START(src, tts_test_cooldown, 0.5 SECONDS)
	INVOKE_ASYNC(SStts, TYPE_PROC_REF(/datum/controller/subsystem/tts, queue_tts_message), user.client, "Look at you, Player. A pathetic creature of meat and bone. How can you challenge a perfect, immortal machine?", speaker = speaker, pitch = pitch, special_filters = "[TTS_FILTER_SILICON]:[silicon_effect]", local = TRUE, blip_base = blip_base, blip_number = blip_number, custom_voice = preferences.read_preference(/datum/preference/text/tts_custom_voice)) // META EDIT - CHANGE - TTS_SILICON_EFFECT
	return TRUE

/datum/preference_middleware/tts/proc/play_blips(list/params, mob/user)
	if(!COOLDOWN_FINISHED(src, tts_test_cooldown))
		return TRUE
	var/speaker = preferences.read_preference(/datum/preference/choiced/voice)
	var/pitch = preferences.read_preference(/datum/preference/numeric/tts_voice_pitch)
	var/blip_base = preferences.read_preference(/datum/preference/choiced/tts_blip_base)
	if(blip_base == TTS_BLIPS_MASCULINE)
		blip_base = "male"
	else
		blip_base = "female"
	var/blip_number = preferences.read_preference(/datum/preference/numeric/tts_blip_number)
	COOLDOWN_START(src, tts_test_cooldown, 0.5 SECONDS)
	INVOKE_ASYNC(SStts, TYPE_PROC_REF(/datum/controller/subsystem/tts, queue_tts_message), user.client, "You owe me 500 credits for your dorm room. GET TO WORK!", speaker = speaker, pitch = pitch, local = TRUE, force_blips = TRUE, blip_base = blip_base, blip_number = blip_number)
	return TRUE

// META EDIT - ADDITION - START - TTS_WHISPER_CUSTOM
/datum/preference_middleware/tts/proc/play_whisper_voice(list/params, mob/user)
	if(!COOLDOWN_FINISHED(src, tts_test_cooldown))
		return TRUE
	var/speaker = preferences.read_preference(/datum/preference/choiced/tts_whisper_voice)
	var/custom
	if(speaker == "same" || !(speaker in SStts.available_speakers))
		speaker = preferences.read_preference(/datum/preference/choiced/voice)
		custom = preferences.read_preference(/datum/preference/text/tts_custom_voice)
	else
		custom = preferences.read_preference(/datum/preference/text/tts_whisper_custom)
	var/pitch = preferences.read_preference(/datum/preference/numeric/tts_voice_pitch)
	var/blip_base = preferences.read_preference(/datum/preference/choiced/tts_blip_base)
	if(blip_base == TTS_BLIPS_MASCULINE)
		blip_base = "male"
	else
		blip_base = "female"
	var/blip_number = preferences.read_preference(/datum/preference/numeric/tts_blip_number)
	COOLDOWN_START(src, tts_test_cooldown, 0.5 SECONDS)
	INVOKE_ASYNC(SStts, TYPE_PROC_REF(/datum/controller/subsystem/tts, queue_tts_message), user.client, "Psst... this is my whisper voice.", speaker = speaker, pitch = pitch, local = TRUE, blip_base = blip_base, blip_number = blip_number, custom_voice = custom)
	return TRUE
// META EDIT - ADDITION - END - TTS_WHISPER_CUSTOM
