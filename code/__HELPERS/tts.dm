/proc/tts_speech_filter(text)
	// Keep ASCII alphanumerics, whitespace, common punctuation, the symbols used for
	// inline TTS engine commands (DECtalk "[:ra 200]", eSpeak "[en+m3 speed=180]"),
	// and any non-ASCII character so non-Latin scripts (Japanese, Cyrillic, ...)
	// reach the engine. BYOND regex works on UTF-8 bytes, so filter char-by-char.
	// META EDIT - CHANGE - TTS_INLINE_COMMANDS
	// ORIGINAL: var/static/regex/bad_chars_regex = regex("\[^a-zA-Z0-9 ,?.!'&-]", "g")
	// ORIGINAL: return bad_chars_regex.Replace(text, " ")
	var/static/list/allowed_punctuation = list(
		" ", ",", "?", ".", "!", "'", "&", "=", "+", ":", "[", "]", "-", "<", ">", "_",
	)
	var/static/regex/ascii_alphanumeric = regex(@@^[a-zA-Z0-9]$@)
	var/list/out = list()
	for(var/i in 1 to length_char(text))
		var/char = copytext_char(text, i, i + 1)
		if(text2ascii(char) >= 128 || (char in allowed_punctuation) || ascii_alphanumeric.Find(char))
			out += char
		else
			out += " "
	return jointext(out, "")

/// Whether a message has anything a TTS engine can actually pronounce: an ASCII
/// alphanumeric, or a non-Latin (non-ASCII) character.
/proc/tts_has_speakable_text(text)
	var/static/regex/ascii_alphanumeric = regex(@@[a-zA-Z0-9]@)
	if(ascii_alphanumeric.Find(text))
		return TRUE
	for(var/i in 1 to length_char(text))
		if(text2ascii(copytext_char(text, i, i + 1)) >= 128)
			return TRUE
	return FALSE

/proc/tts_gibberish_speech_filter(text)
	// Only allow alphanumeric characters and whitespace
	var/static/regex/bad_chars_regex = regex("\[^a-zA-Z0-9 ,?.!'&-]", "g")
	return bad_chars_regex.Replace(text, "#")

/proc/tts_filter_encode(text, speaker, pitch, blips = FALSE)
	text = replacetext(text, "%PITCH%", SStts.pitch_enabled ? pitch : 0)
	text = replacetext(text, "%FEMALE%", !!findtext(speaker, "Woman"))
	text = replacetext(text, "%BLIPS%", blips)
	return url_encode(text)
