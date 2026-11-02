/proc/tts_speech_filter(text)
	// Minimal sanitizer: ASCII control characters become spaces and whitespace
	// runs collapse to one, but every printable character is kept - including the
	// backslash SAPI4 tags use. The text only ever leaves as a JSON body, so
	// there is no shell/injection reason to strip punctuation.
	// META EDIT - REPLACEMENT - START - TTS_MINIMAL_SPEECH_FILTER
	// ORIGINAL (upstream): var/static/regex/bad_chars_regex = regex("\[^a-zA-Z0-9 ,?.!'&-]", "g")
	// ORIGINAL (upstream): return bad_chars_regex.Replace(text, " ")
	// PREVIOUS (TTS_INLINE_COMMANDS): char-by-char allowlist of alphanumerics,
	// non-ASCII, and " , ? . ! ' & = + : [ ] - < > _"
	var/list/out = list()
	for(var/i in 1 to length_char(text))
		var/char = copytext_char(text, i, i + 1)
		var/char_code = text2ascii(char)
		if(char_code < 32 || char_code == 127)
			char = " "
		if(char == " " && length(out) && out[length(out)] == " ")
			continue
		out += char
	return jointext(out, "")
	// META EDIT - REPLACEMENT - END - TTS_MINIMAL_SPEECH_FILTER

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
