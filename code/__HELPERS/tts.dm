/proc/tts_speech_filter(text)
	// Allow alphanumerics, whitespace, common punctuation, and the symbols used for
	// inline TTS engine commands (DECtalk "[:ra 200]", eSpeak "[en+m3 speed=180]").
	// META EDIT - CHANGE - TTS_INLINE_COMMANDS
	// ORIGINAL: var/static/regex/bad_chars_regex = regex("\[^a-zA-Z0-9 ,?.!'&-]", "g")
	var/static/regex/bad_chars_regex = regex(@@[^a-zA-Z0-9 ,?.!'&=+:\[\]-]@, "g")
	return bad_chars_regex.Replace(text, " ")

/proc/tts_gibberish_speech_filter(text)
	// Only allow alphanumeric characters and whitespace
	var/static/regex/bad_chars_regex = regex("\[^a-zA-Z0-9 ,?.!'&-]", "g")
	return bad_chars_regex.Replace(text, "#")

/proc/tts_filter_encode(text, speaker, pitch, blips = FALSE)
	text = replacetext(text, "%PITCH%", SStts.pitch_enabled ? pitch : 0)
	text = replacetext(text, "%FEMALE%", !!findtext(speaker, "Woman"))
	text = replacetext(text, "%BLIPS%", blips)
	return url_encode(text)
