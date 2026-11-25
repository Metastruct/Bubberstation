/datum/preference/choiced/custom_tongue
	category = PREFERENCE_CATEGORY_SECONDARY_FEATURES
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "feature_custom_tongue"
	can_randomize = FALSE
	randomize_by_default = FALSE

/datum/preference/choiced/custom_tongue/init_possible_values()
	return assoc_to_keys_features(SSaccessories.sprite_accessories[FEATURE_CUSTOM_TONGUE])

/datum/preference/choiced/custom_tongue/create_default_value()
	return /datum/sprite_accessory/custom_tongue/default::name

/datum/preference/choiced/custom_tongue/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	target.dna.features[FEATURE_CUSTOM_TONGUE] = value

/datum/preference/choiced/custom_tongue/compile_constant_data()
	. = ..()
	var/list/allowed = list()
	for(var/name in get_choices())
		var/datum/sprite_accessory/custom_tongue/accessory = SSaccessories.sprite_accessories[FEATURE_CUSTOM_TONGUE][name]
		allowed[name] = accessory?.allowed_species || list()
	.["allowed_species"] = allowed

/datum/preference/tri_color/custom_tongue
	category = PREFERENCE_CATEGORY_SECONDARY_FEATURES
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "custom_tongue_color"
	check_mode = TRICOLOR_NO_CHECK
	can_randomize = FALSE
	randomize_by_default = FALSE

/datum/preference/tri_color/custom_tongue/create_default_value()
	return list(COLOR_TONGUE_PINK, COLOR_TONGUE_PINK, COLOR_TONGUE_PINK)

/datum/preference/tri_color/custom_tongue/apply_to_human(mob/living/carbon/human/target, value)
	target.dna.features[FEATURE_CUSTOM_TONGUE_COLOR] = list(sanitize_hexcolor(value[1]), sanitize_hexcolor(value[2]), sanitize_hexcolor(value[3]))
