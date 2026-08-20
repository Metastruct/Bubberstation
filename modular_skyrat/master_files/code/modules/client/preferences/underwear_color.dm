// THIS FILE HAS BEEN EDITED BY SKYRAT EDIT

/datum/preference/color/underwear_color
	savefile_key = "underwear_color"
	savefile_identifier = PREFERENCE_CHARACTER
	category = PREFERENCE_CATEGORY_SUPPLEMENTAL_FEATURES

/datum/preference/color/underwear_color/apply_to_human(mob/living/carbon/human/target, value)
	target.underwear_color = value
	// META EDIT - ADDITION - START - UNDERWEAR_ITEMS
	// Underwear is a real item now (see modular_zzmeta/code/modules/clothing/underwear/) and this
	// preference may apply before or after the underwear-style preference, so also recolor
	// whatever's currently equipped rather than relying on apply order.
	if(target.w_underwear && !target.w_underwear.use_static)
		target.w_underwear.color = value
		target.w_underwear.refresh_worn_appearance()
	// META EDIT - ADDITION - END

/datum/preference/color/underwear_color/is_accessible(datum/preferences/preferences)
	if (!..(preferences))
		return FALSE

	var/species_type = preferences.read_preference(/datum/preference/choiced/species)
	var/datum/species/species = new species_type
	return !(TRAIT_NO_UNDERWEAR in species.inherent_traits)

// SKYRAT EDIT ADDITION BEGIN - Colorable Undershirt/Socks
/datum/preference/color/undershirt_color
	savefile_key = "undershirt_color"
	savefile_identifier = PREFERENCE_CHARACTER
	category = PREFERENCE_CATEGORY_SUPPLEMENTAL_FEATURES

/datum/preference/color/undershirt_color/apply_to_human(mob/living/carbon/human/target, value)
	target.undershirt_color = value
	// META EDIT - ADDITION - START - UNDERWEAR_ITEMS
	if(target.w_undershirt && !target.w_undershirt.use_static)
		target.w_undershirt.color = value
		target.w_undershirt.refresh_worn_appearance()
	// META EDIT - ADDITION - END

/datum/preference/color/undershirt_color/is_accessible(datum/preferences/preferences)
	if (!..(preferences))
		return FALSE

	var/species_type = preferences.read_preference(/datum/preference/choiced/species)
	var/datum/species/species = new species_type
	return !(TRAIT_NO_UNDERWEAR in species.inherent_traits)

/datum/preference/color/socks_color
	savefile_key = "socks_color"
	savefile_identifier = PREFERENCE_CHARACTER
	category = PREFERENCE_CATEGORY_SUPPLEMENTAL_FEATURES

/datum/preference/color/socks_color/apply_to_human(mob/living/carbon/human/target, value)
	target.socks_color = value
	// META EDIT - ADDITION - START - UNDERWEAR_ITEMS
	if(target.w_socks && !target.w_socks.use_static)
		target.w_socks.color = value
		target.w_socks.refresh_worn_appearance()
	// META EDIT - ADDITION - END

/datum/preference/color/socks_color/is_accessible(datum/preferences/preferences)
	if (!..(preferences))
		return FALSE

	var/species_type = preferences.read_preference(/datum/preference/choiced/species)
	var/datum/species/species = new species_type
	return !(TRAIT_NO_UNDERWEAR in species.inherent_traits)
// SKYRAT EDIT ADDITION END - Colorable Undershirt/Socks


/datum/preference/color/bra_color
	savefile_key = "bra_color"
	savefile_identifier = PREFERENCE_CHARACTER
	category = PREFERENCE_CATEGORY_SUPPLEMENTAL_FEATURES

/datum/preference/color/bra_color/apply_to_human(mob/living/carbon/human/target, value)
	target.bra_color = value
	// META EDIT - ADDITION - START - UNDERWEAR_ITEMS
	if(target.w_bra && !target.w_bra.use_static)
		target.w_bra.color = value
		target.w_bra.refresh_worn_appearance()
	// META EDIT - ADDITION - END

/datum/preference/color/bra_color/is_accessible(datum/preferences/preferences)
	if (!..(preferences))
		return FALSE

	var/species_type = preferences.read_preference(/datum/preference/choiced/species)
	var/datum/species/species = new species_type
	return !(TRAIT_NO_UNDERWEAR in species.inherent_traits)
