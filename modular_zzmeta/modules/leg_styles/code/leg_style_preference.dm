/datum/preference/choiced/leg_style
	savefile_key = "leg_style"
	savefile_identifier = PREFERENCE_CHARACTER
	category = PREFERENCE_CATEGORY_CHARACTER_BASICS
	// Must run after the species pref, or `target.dna.species` is still the previous one
	// when we validate the style (which made every non-native style reset to Native).
	priority = PREFERENCE_PRIORITY_BODYPARTS

/datum/preference/choiced/leg_style/init_possible_values()
	return get_all_leg_style_names()

/// All styles, in the order they should appear in the dropdown Native first.
/proc/get_all_leg_style_names()
	return list(
		LEG_STYLE_NATIVE,
		LEG_STYLE_ORGANIC,
		LEG_STYLE_LIZARD,
		LEG_STYLE_TESHARI,
		LEG_STYLE_VOX,
		LEG_STYLE_SHADEKIN,
		LEG_STYLE_AQUATIC,
		LEG_STYLE_LYCAN,
		LEG_STYLE_XENOHYBRID,
	)

/proc/get_leg_style_choices(datum/preferences/preferences)
	// Fail open if we somehow don't have a preferences datum (no user context): showing the
	// full list matches the pre-existing behaviour rather than hiding valid options.
	if(isnull(preferences))
		return get_all_leg_style_names()

	var/datum/species/species_type = preferences.read_preference(/datum/preference/choiced/species)
	var/species_id = species_type ? initial(species_type.id) : null
	var/mismatched = preferences.read_preference(/datum/preference/toggle/allow_mismatched_parts)

	var/list/choices = list()
	for(var/style_name in get_all_leg_style_names())
		var/datum/leg_style/style = GLOB.leg_styles[style_name]
		if(style.name == LEG_STYLE_NATIVE || mismatched || (species_id in style.recommended_species))
			choices += style.name
	return choices

/datum/preference/choiced/leg_style/create_default_value()
	return LEG_STYLE_NATIVE

/datum/preference/choiced/leg_style/is_accessible(datum/preferences/preferences)
	if(!..())
		return FALSE
	// With mismatched parts on, any species can pick any legs, normal or digitigrade.
	if(preferences.read_preference(/datum/preference/toggle/allow_mismatched_parts))
		return TRUE
	// Otherwise only species whose legs can be customised at all.
	var/datum/species/species_type = preferences.read_preference(/datum/preference/choiced/species)
	return initial(species_type.digitigrade_customization) != DIGITIGRADE_NEVER

/datum/preference/choiced/leg_style/compile_ui_data(mob/user, value)
	var/datum/preferences/preferences = user?.client?.prefs
	return list(
		"value" = serialize(value),
		"choices" = get_leg_style_choices(preferences),
	)

/datum/preference/choiced/leg_style/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	var/datum/species/species = target.dna?.species
	if(!is_leg_style_allowed(species, value, preferences))
		value = LEG_STYLE_NATIVE

	if(target.dna.features[FEATURE_LEG_STYLE] == value)
		return FALSE

	target.dna.features[FEATURE_LEG_STYLE] = value

	// Rebuild the legs so the new style (plantigrade or digitigrade) is applied.
	if(species)
		species.apply_leg_style(target)
		species.replace_body(target, species)
		target.update_body()

	return TRUE
