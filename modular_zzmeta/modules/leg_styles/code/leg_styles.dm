#define FEATURE_LEG_STYLE "leg_style"

/// Use the species' own leg types (for synths: the chassis synth art).
#define LEG_STYLE_NATIVE "Native"
#define LEG_STYLE_ORGANIC "Organic Lizard"
#define LEG_STYLE_LIZARD "Lizard"
#define LEG_STYLE_TESHARI "Teshari"
#define LEG_STYLE_VOX "Vox"
#define LEG_STYLE_SHADEKIN "Shadekin"
#define LEG_STYLE_AQUATIC "Aquatic"
#define LEG_STYLE_LYCAN "Lycan"
#define LEG_STYLE_XENOHYBRID "Xenohybrid"

/// A selectable leg style.
/datum/leg_style
	/// The name shown in the dropdown and stored in [FEATURE_LEG_STYLE].
	var/name
	/// Plantigrade ("Normal") bodypart types. Null means "use the species' native legs".
	var/obj/item/bodypart/leg/left/left_type
	var/obj/item/bodypart/leg/right/right_type
	/// Digitigrade bodypart types. Null means "derive from the plantigrade type", and if
	/// that is null too, "use the species' native digitigrade legs".
	var/obj/item/bodypart/leg/left/digitigrade_left_type
	var/obj/item/bodypart/leg/right/digitigrade_right_type
	/// Robotic (synth) overrides for the plantigrade/digitigrade types.
	var/obj/item/bodypart/leg/left/synth_left_type
	var/obj/item/bodypart/leg/right/synth_right_type
	var/obj/item/bodypart/leg/left/synth_digitigrade_left_type
	var/obj/item/bodypart/leg/right/synth_digitigrade_right_type
	/// Species that may pick this style without "Allow Mismatched Parts".
	var/list/recommended_species = list()

/// Which bodypart type this style uses for the given species/zone/mode. Null means "fall
/// back to the species' native type".
/datum/leg_style/proc/get_limb_type(datum/species/species, body_zone, digitigrade)
	var/is_synth = istype(species, /datum/species/synthetic)
	var/left = (body_zone == BODY_ZONE_L_LEG)

	// This style's plantigrade type (null if it only ships a digitigrade type).
	var/obj/item/bodypart/leg/plantigrade_type
	if(left)
		plantigrade_type = (is_synth && synth_left_type) ? synth_left_type : left_type
	else
		plantigrade_type = (is_synth && synth_right_type) ? synth_right_type : right_type

	// This style's digitigrade type: explicit, else derived from the plantigrade type.
	var/obj/item/bodypart/leg/digitigrade_type
	if(left)
		digitigrade_type = (is_synth && synth_digitigrade_left_type) ? synth_digitigrade_left_type : digitigrade_left_type
	else
		digitigrade_type = (is_synth && synth_digitigrade_right_type) ? synth_digitigrade_right_type : digitigrade_right_type
	if(!digitigrade_type && plantigrade_type)
		digitigrade_type = initial(plantigrade_type.digitigrade_type)

	// A style that only ships a digitigrade type (like "Organic Lizard") applies it even
	// when the Legs toggle is Normal - otherwise it would silently do nothing on a species
	// without the toggle (e.g. moths).
	if(digitigrade)
		return digitigrade_type || plantigrade_type
	return plantigrade_type || digitigrade_type

/datum/leg_style/native
	name = LEG_STYLE_NATIVE

/datum/leg_style/organic
	name = LEG_STYLE_ORGANIC
	digitigrade_left_type = /obj/item/bodypart/leg/left/digitigrade
	digitigrade_right_type = /obj/item/bodypart/leg/right/digitigrade
	synth_digitigrade_left_type = /obj/item/bodypart/leg/left/synth/digitigrade/organic
	synth_digitigrade_right_type = /obj/item/bodypart/leg/right/synth/digitigrade/organic
	recommended_species = list(SPECIES_SYNTH, SPECIES_LIZARD)

/datum/leg_style/lizard
	name = LEG_STYLE_LIZARD
	left_type = /obj/item/bodypart/leg/left/lizard
	right_type = /obj/item/bodypart/leg/right/lizard
	recommended_species = list(SPECIES_LIZARD)

/datum/leg_style/teshari
	name = LEG_STYLE_TESHARI
	left_type = /obj/item/bodypart/leg/left/mutant/teshari
	right_type = /obj/item/bodypart/leg/right/mutant/teshari
	recommended_species = list(SPECIES_TESHARI)

/datum/leg_style/vox
	name = LEG_STYLE_VOX
	left_type = /obj/item/bodypart/leg/left/mutant/vox
	right_type = /obj/item/bodypart/leg/right/mutant/vox
	recommended_species = list(SPECIES_VOX)

/datum/leg_style/shadekin
	name = LEG_STYLE_SHADEKIN
	left_type = /obj/item/bodypart/leg/left/shadekin
	right_type = /obj/item/bodypart/leg/right/shadekin
	recommended_species = list(SPECIES_SHADEKIN)

/datum/leg_style/aquatic
	name = LEG_STYLE_AQUATIC
	left_type = /obj/item/bodypart/leg/left/mutant/aquatic
	right_type = /obj/item/bodypart/leg/right/mutant/aquatic
	recommended_species = list(SPECIES_AQUATIC)

/datum/leg_style/lycan
	name = LEG_STYLE_LYCAN
	left_type = /obj/item/bodypart/leg/left/mutant/lycan
	right_type = /obj/item/bodypart/leg/right/mutant/lycan
	recommended_species = list(SPECIES_LYCAN)

/datum/leg_style/xenohybrid
	name = LEG_STYLE_XENOHYBRID
	left_type = /obj/item/bodypart/leg/left/mutant/xenohybrid
	right_type = /obj/item/bodypart/leg/right/mutant/xenohybrid
	recommended_species = list(SPECIES_XENO)

GLOBAL_LIST_INIT(leg_styles, build_leg_styles())

/proc/build_leg_styles()
	. = list()
	for(var/style_type in subtypesof(/datum/leg_style))
		var/datum/leg_style/style = new style_type
		.[style.name] = style

/proc/get_leg_style(style_name)
	return GLOB.leg_styles[style_name] || GLOB.leg_styles[LEG_STYLE_NATIVE]

// The limb icon cache key is built from `(limb_id, body_zone, colour, ...)` - not the sprite
// sheet - and `limb_icon_cache` is static (shared by every mob). Every digitigrade style
// shares `limb_id == "digitigrade"`, so without this the first digitigrade sprite rendered got
// cached and reused for every style (all styles rendered as the default one). Include the
// icon for digitigrade limbs so each style caches separately.
/obj/item/bodypart/generate_icon_key()
	. = ..()
	if(limb_id == BODYPART_ID_DIGITIGRADE)
		. += "[icon_greyscale || icon_static]"
	return .

/datum/species
	/// Lazily built cache of a species' *original* plantigrade/digitigrade leg types, keyed
	/// by body zone. Needed because `bodypart_overrides` is mutated in place when a leg
	/// style is applied, so re-deriving the native type a second time would be wrong.
	var/list/native_leg_types
	var/list/native_digitigrade_types

/datum/species/proc/get_native_leg_type(body_zone, digitigrade)
	if(digitigrade)
		return get_native_digitigrade_type(body_zone)
	if(isnull(native_leg_types))
		native_leg_types = list()
	if(!(body_zone in native_leg_types))
		var/datum/species/fresh = new type
		native_leg_types[body_zone] = fresh.bodypart_overrides[body_zone]
		qdel(fresh)
	return native_leg_types[body_zone]

/datum/species/proc/get_native_digitigrade_type(body_zone)
	if(isnull(native_digitigrade_types))
		native_digitigrade_types = list()
	if(!(body_zone in native_digitigrade_types))
		var/datum/species/fresh = new type
		var/obj/item/bodypart/leg/base = fresh.bodypart_overrides[body_zone]
		native_digitigrade_types[body_zone] = base ? initial(base.digitigrade_type) : null
		qdel(fresh)
	return native_digitigrade_types[body_zone]

/// Applies the selected leg style to this species' `bodypart_overrides`. Normal legs use the
/// style's plantigrade type, digitigrade legs its digitigrade type, each falling back to the
/// species' native type.
/datum/species/proc/apply_leg_style(mob/living/carbon/human/human)
	var/datum/leg_style/style = get_leg_style(human.dna.features[FEATURE_LEG_STYLE])
	var/digitigrade = (digitigrade_customization == DIGITIGRADE_FORCED) || (digitigrade_customization == DIGITIGRADE_OPTIONAL && human.dna.features[FEATURE_LEGS] == DIGITIGRADE_LEGS)
	for(var/body_zone in list(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
		var/limb_type = style.get_limb_type(src, body_zone, digitigrade) || get_native_leg_type(body_zone, digitigrade)
		if(limb_type)
			bodypart_overrides[body_zone] = limb_type

/// May this species pick this style? Native is always fine other styles need either a
/// species match or the "Allow Mismatched Parts" toggle.
/proc/is_leg_style_allowed(datum/species/species, style_name, datum/preferences/preferences)
	var/datum/leg_style/style = get_leg_style(style_name)
	if(style.name == LEG_STYLE_NATIVE)
		return TRUE
	// Prefer the species stored in the preferences: during `apply_prefs_to()` this can be
	// called before the species pref has run, so `species` may still be the old one.
	var/species_id = species?.id
	var/datum/species/species_type = preferences?.read_preference(/datum/preference/choiced/species)
	if(species_type)
		species_id = initial(species_type.id)
	if(species_id in style.recommended_species)
		return TRUE
	if(preferences?.read_preference(/datum/preference/toggle/allow_mismatched_parts))
		return TRUE
	return FALSE
