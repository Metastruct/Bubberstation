/datum/preference/toggle/extra_arms
	category = PREFERENCE_CATEGORY_SECONDARY_FEATURES
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "extra_arms_toggle"
	default_value = FALSE
	// Runs after PREFERENCE_PRIORITY_SPECIES so the chest bodypart already exists.
	priority = PREFERENCE_PRIORITY_BODYPARTS

/datum/preference/toggle/extra_arms/create_default_value()
	return FALSE

/datum/preference/toggle/extra_arms/is_accessible(datum/preferences/preferences)
	if(!..(preferences))
		return FALSE
	if(CONFIG_GET(flag/disable_mismatched_parts))
		return FALSE
	if(!preferences.read_preference(/datum/preference/toggle/allow_mismatched_parts))
		return FALSE
	// Moths get their chest arms from the bodypart itself
	var/datum/species/species = preferences.read_preference(/datum/preference/choiced/species)
	if(ispath(species, /datum/species/moth))
		return FALSE
	return TRUE

/datum/preference/toggle/extra_arms/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	var/enabled = value \
		&& !istype(target.dna?.species, /datum/species/moth) \
		&& preferences.read_preference(/datum/preference/toggle/allow_mismatched_parts)
	target.set_extra_arms(enabled)
