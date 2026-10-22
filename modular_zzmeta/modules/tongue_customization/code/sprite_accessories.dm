/// Cosmetic tongue styles used by the tongue/lick emote overlay.
///
/// Icon rules:
/// - `USE_ONE_COLOR`: a directional state named `icon_state` (white/greyscale, tinted by color 1).
/// - `USE_MATRIXED_COLORS`: directional states named `icon_state_primary`,
///   `icon_state_secondary`, and optionally `icon_state_tertiary`.
/// - `allowed_species`: species IDs this style is meant for. Null/empty = everyone.
///   With "Allow Mismatched Parts" off, other species cannot pick it.
/datum/sprite_accessory/custom_tongue
	icon = 'modular_zzmeta/modules/tongue_customization/icons/tongue.dmi'
	key = FEATURE_CUSTOM_TONGUE
	color_src = USE_ONE_COLOR
	relevent_layers = list(EXTERNAL_ADJACENT)
	/// Species IDs this style belongs to. Null or empty means available to every species.
	var/list/allowed_species

/datum/sprite_accessory/custom_tongue/New()
	. = ..()
	if(color_src != USE_MATRIXED_COLORS)
		return
	var/list/states = SSaccessories.cached_mutant_icon_files[icon]
	if(isnull(states))
		states = icon_states(icon)
		SSaccessories.cached_mutant_icon_files[icon] = states
	color_layer_names = list()
	if("[icon_state]_primary" in states)
		color_layer_names["1"] = "primary"
	if("[icon_state]_secondary" in states)
		color_layer_names["2"] = "secondary"
	if("[icon_state]_tertiary" in states)
		color_layer_names["3"] = "tertiary"

/datum/sprite_accessory/custom_tongue/default
	name = "Default"
	icon_state = "default"

/datum/sprite_accessory/custom_tongue/centered
	name = "Centered"
	icon_state = "centered"

/datum/sprite_accessory/custom_tongue/forked
	name = "Forked"
	icon_state = "forked"
	allowed_species = list(SPECIES_LIZARD, SPECIES_LIZARD_ASH, SPECIES_LIZARD_SILVER, SPECIES_UNATHI)
	color_src = USE_MATRIXED_COLORS

/datum/sprite_accessory/custom_tongue/long
	name = "Long"
	icon_state = "long"
	color_src = USE_MATRIXED_COLORS

/datum/sprite_accessory/custom_tongue/longer
	name = "Longer"
	icon_state = "longer"
	allowed_species = list(SPECIES_INSECT, SPECIES_FLYPERSON, SPECIES_MAMMAL, SPECIES_MOTH, SPECIES_LIZARD, SPECIES_LIZARD_ASH, SPECIES_LIZARD_SILVER, SPECIES_UNATHI)

/datum/sprite_accessory/custom_tongue/longer_a
	name = "Longer (Animated)"
	icon_state = "longer_a"
	allowed_species = list(SPECIES_INSECT, SPECIES_FLYPERSON, SPECIES_MAMMAL, SPECIES_MOTH, SPECIES_LIZARD, SPECIES_LIZARD_ASH, SPECIES_LIZARD_SILVER, SPECIES_UNATHI)

/datum/sprite_accessory/custom_tongue/anteater
	name = "Anteater"
	icon_state = "anteater"
	allowed_species = list(SPECIES_INSECT, SPECIES_FLYPERSON, SPECIES_MAMMAL, SPECIES_MOTH, SPECIES_LIZARD, SPECIES_LIZARD_ASH, SPECIES_LIZARD_SILVER, SPECIES_UNATHI)

/datum/sprite_accessory/custom_tongue/wide
	name = "Wide"
	icon_state = "wide"

/datum/sprite_accessory/custom_tongue/wide_split
	name = "Wide (Split)"
	icon_state = "wide_split"
