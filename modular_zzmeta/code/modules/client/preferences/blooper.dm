/**
 * Reads a PREFERENCE_CHARACTER preference's value for the slot currently being loaded, bypassing value_cache.
 *
 * load_character() clears and re-reads each preference's cache entry one at a time (not all at once), so reading
 * a sibling preference via read_preference() from inside create_informed_default_value() can return a value still
 * cached from the PREVIOUS slot if that sibling hasn't been refreshed yet in the loop.
 */
/proc/read_uncached_preference(preference_type, datum/preferences/preferences)
	var/datum/preference/sibling = GLOB.preference_entries[preference_type]
	var/save_data = preferences.get_save_data_for_savefile_identifier(sibling.savefile_identifier)
	var/value = sibling.read(save_data, preferences)
	if(isnull(value))
		value = sibling.create_default_value()
	return value

/// Alternate blooper used only while whispering. Defaults to the character's normal blooper.
/datum/preference/choiced/whisper_blooper
	category = PREFERENCE_CATEGORY_CHARACTER_BASICS
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "whisper_blooper_choice"

/datum/preference/choiced/whisper_blooper/init_possible_values()
	if(!length(SSblooper.blooper_list))
		return list("none")
	return list("none") + assoc_to_keys(SSblooper.blooper_list)

/datum/preference/choiced/whisper_blooper/create_default_value()
	return "none"

/datum/preference/choiced/whisper_blooper/apply_to_human(mob/living/carbon/human/target, value)
	if(value == "none" || !(value in SSblooper.blooper_list))
		target.whisper_blooper = null
	else
		target.whisper_blooper = SSblooper.blooper_list[value]

/datum/preference/choiced/whisper_blooper/is_accessible(datum/preferences/preferences)
	return ..() && length(SSblooper.blooper_list)

/datum/preference/choiced/whisper_blooper/compile_constant_data()
	var/list/data = ..()
	if(!length(SSblooper.blooper_list))
		return data
	var/list/display_names = list("none" = "Same as normal voice")
	for(var/id in get_choices())
		if(id == "none")
			continue
		display_names[id] = astype(SSblooper.blooper_list[id], /datum/blooper).name
	data[CHOICED_PREFERENCE_DISPLAY_NAMES] = display_names
	return data

/datum/preference/numeric/whisper_blooper_speed
	category = PREFERENCE_CATEGORY_CHARACTER_BASICS
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "whisper_blooper_speed"
	minimum = 0
	maximum = 100

/datum/preference/numeric/whisper_blooper_speed/apply_to_human(mob/living/carbon/human/target, value)
	target.whisper_blooper_speed = value

/datum/preference/numeric/whisper_blooper_speed/create_default_value()
	return 50

/// Defaults to whatever the character's normal Voice Speed is currently set to.
/datum/preference/numeric/whisper_blooper_speed/create_informed_default_value(datum/preferences/preferences)
	return read_uncached_preference(/datum/preference/numeric/blooper_speed, preferences)

/datum/preference/numeric/whisper_blooper_speed/is_accessible(datum/preferences/preferences)
	if(!..() || !length(SSblooper.blooper_list))
		return FALSE
	return preferences.read_preference(/datum/preference/choiced/whisper_blooper) != "none"

/datum/preference/numeric/whisper_blooper_pitch
	category = PREFERENCE_CATEGORY_CHARACTER_BASICS
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "whisper_blooper_pitch"
	minimum = 0
	maximum = 100

/datum/preference/numeric/whisper_blooper_pitch/apply_to_human(mob/living/carbon/human/target, value)
	target.whisper_blooper_pitch = value

/datum/preference/numeric/whisper_blooper_pitch/create_default_value()
	return 50

/// Defaults to whatever the character's normal Voice Pitch is currently set to.
/datum/preference/numeric/whisper_blooper_pitch/create_informed_default_value(datum/preferences/preferences)
	return read_uncached_preference(/datum/preference/numeric/blooper_pitch, preferences)

/datum/preference/numeric/whisper_blooper_pitch/is_accessible(datum/preferences/preferences)
	if(!..() || !length(SSblooper.blooper_list))
		return FALSE
	return preferences.read_preference(/datum/preference/choiced/whisper_blooper) != "none"

/datum/preference/numeric/whisper_blooper_pitch_range
	category = PREFERENCE_CATEGORY_CHARACTER_BASICS
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "whisper_blooper_pitch_range"
	minimum = 0
	maximum = 100

/datum/preference/numeric/whisper_blooper_pitch_range/apply_to_human(mob/living/carbon/human/target, value)
	target.whisper_blooper_pitch_range = value

/datum/preference/numeric/whisper_blooper_pitch_range/create_default_value()
	return 30

/// Defaults to whatever the character's normal Voice Range is currently set to.
/datum/preference/numeric/whisper_blooper_pitch_range/create_informed_default_value(datum/preferences/preferences)
	return read_uncached_preference(/datum/preference/numeric/blooper_pitch_range, preferences)

/datum/preference/numeric/whisper_blooper_pitch_range/is_accessible(datum/preferences/preferences)
	if(!..() || !length(SSblooper.blooper_list))
		return FALSE
	return preferences.read_preference(/datum/preference/choiced/whisper_blooper) != "none"
