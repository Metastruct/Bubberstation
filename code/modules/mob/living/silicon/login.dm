/mob/living/silicon/Login()
	if(mind)
		mind?.remove_antags_for_borging()
	if(SStts.tts_enabled)
		var/voice_to_use = client?.prefs.read_preference(/datum/preference/choiced/voice)
		var/pitch_to_use = client?.prefs.read_preference(/datum/preference/numeric/tts_voice_pitch)
		if(voice_to_use)
			voice = voice_to_use
		if(pitch_to_use)
			pitch = pitch_to_use
		// META EDIT - ADDITION - START - TTS_ESPEAK_CUSTOM_VOICE
		var/custom_to_use = client?.prefs.read_preference(/datum/preference/text/tts_custom_voice)
		if(custom_to_use)
			tts_custom_voice = custom_to_use
		// META EDIT - ADDITION - END - TTS_ESPEAK_CUSTOM_VOICE
		// META EDIT - ADDITION - START - TTS_WHISPER_VOICE
		var/whisper_voice_to_use = client?.prefs.read_preference(/datum/preference/choiced/tts_whisper_voice)
		if(whisper_voice_to_use && whisper_voice_to_use != "same")
			tts_whisper_voice = whisper_voice_to_use
		var/whisper_custom_to_use = client?.prefs.read_preference(/datum/preference/text/tts_whisper_custom)
		if(whisper_custom_to_use)
			tts_whisper_custom = whisper_custom_to_use
		// META EDIT - ADDITION - END - TTS_WHISPER_VOICE
	return ..()


/mob/living/silicon/auto_deadmin_on_login()
	if(!client?.holder)
		return TRUE
	if(CONFIG_GET(flag/auto_deadmin_silicons) || (client.prefs?.toggles & DEADMIN_POSITION_SILICON))
		return client.holder.auto_deadmin()
	return ..()
