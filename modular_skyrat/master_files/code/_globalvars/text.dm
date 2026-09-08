/// Ensures sentences end in appropriate punctuation (a period if none exist)
/// and that all whitespace-bounded 'i' characters are capitalized.
// META EDIT - CHANGE - START - AUTOCAPITALIZATION_PREFERENCE
// ORIGINAL: /proc/autopunct_bare(input_text)
/proc/autopunct_bare(input_text, add_punctuation = TRUE, capitalize_i = TRUE)
	if(add_punctuation && findtext(input_text, GLOB.has_no_eol_punctuation))
		input_text += "."

	if(capitalize_i)
		input_text = replacetext(input_text, GLOB.noncapital_i, "I")
	return input_text
// META EDIT - CHANGE - END
