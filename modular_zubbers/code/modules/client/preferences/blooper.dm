/datum/preference/choiced/blooper
	category = PREFERENCE_CATEGORY_CHARACTER_BASICS
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "blooper_choice"

/datum/preference/choiced/blooper/init_possible_values()
	// no bloopers configured, return dummy list to avoid runtimes
	if(!length(SSblooper.blooper_list))
		return list("none")
	return assoc_to_keys(SSblooper.blooper_list)

/datum/preference/choiced/blooper/apply_to_human(mob/living/carbon/human/target, value)
	target.blooper = SSblooper.blooper_list[value]

/datum/preference/choiced/blooper/is_accessible(datum/preferences/preferences)
	return ..() && length(SSblooper.blooper_list)

/datum/preference/choiced/blooper/compile_constant_data()
	var/list/data = ..()
	if(!length(SSblooper.blooper_list))
		return data
	var/list/display_names = list()
	for(var/id in get_choices())
		display_names[id] = astype(SSblooper.blooper_list[id], /datum/blooper).name
	data[CHOICED_PREFERENCE_DISPLAY_NAMES] = display_names
	return data

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
	return preferences.read_preference(/datum/preference/numeric/blooper_speed)

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
	return preferences.read_preference(/datum/preference/numeric/blooper_pitch)

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
	return preferences.read_preference(/datum/preference/numeric/blooper_pitch_range)

/datum/preference/numeric/whisper_blooper_pitch_range/is_accessible(datum/preferences/preferences)
	if(!..() || !length(SSblooper.blooper_list))
		return FALSE
	return preferences.read_preference(/datum/preference/choiced/whisper_blooper) != "none"

/datum/preference/numeric/blooper_speed
	category = PREFERENCE_CATEGORY_CHARACTER_BASICS
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "blooper_speed"
	minimum = 0
	maximum = 100

/datum/preference/numeric/blooper_speed/apply_to_human(mob/living/carbon/human/target, value)
	target.blooper_speed = value

/datum/preference/numeric/blooper_speed/create_default_value()
	return 50

/datum/preference/numeric/blooper_speed/is_accessible(datum/preferences/preferences)
	return ..() && length(SSblooper.blooper_list)

/datum/preference/numeric/blooper_pitch
	category = PREFERENCE_CATEGORY_CHARACTER_BASICS
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "blooper_pitch"
	minimum = 0
	maximum = 100

/datum/preference/numeric/blooper_pitch/apply_to_human(mob/living/carbon/human/target, value)
	target.blooper_pitch = value

/datum/preference/numeric/blooper_pitch/create_default_value()
	return 50

/datum/preference/numeric/blooper_pitch/is_accessible(datum/preferences/preferences)
	return ..() && length(SSblooper.blooper_list)

/datum/preference/numeric/blooper_pitch_range
	category = PREFERENCE_CATEGORY_CHARACTER_BASICS
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "blooper_pitch_range"
	minimum = 0
	maximum = 100

/datum/preference/numeric/blooper_pitch_range/apply_to_human(mob/living/carbon/human/target, value)
	target.blooper_pitch_range = value

/datum/preference/numeric/blooper_pitch_range/create_default_value()
	return 30

/datum/preference/numeric/blooper_pitch_range/is_accessible(datum/preferences/preferences)
	return ..() && length(SSblooper.blooper_list)

// Send vocal bloopers
/datum/preference/toggle/send_blooper
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_identifier = PREFERENCE_PLAYER
	savefile_key = "blooper_send"
	default_value = TRUE

// Hear vocal bloopers
/datum/preference/toggle/hear_blooper
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_identifier = PREFERENCE_PLAYER
	savefile_key = "blooper_hear"
	default_value = TRUE
