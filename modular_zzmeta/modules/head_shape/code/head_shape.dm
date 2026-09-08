/// Head Shape
///
/// Purely visual: reskins the wearer's own head bodypart to look like another
/// species' head via change_appearance(), the same mechanism the IPC "Head
/// Appearance" feature already uses for its own chassis skins. Never touches
/// bodypart_overrides, never replaces the bodypart/organs, and deliberately
/// never touches head_flags/teeth_count/bodypart_traits/combat stats. The
/// wearer's own species keeps governing everything except the icon shown
/// (and their existing skin-tone/mutant-color preference keeps coloring it,
/// same as it always did).
///
/// Gated like ears: unchecked, nothing changes and the species' own head is
/// used. Checked, a dropdown appears. "Headless" hides the head entirely,
/// the same effect as the existing "make the head transparent" player
/// trick, formalized as a real option. Every other entry reskins to that
/// species.

/// Species whose own head is irregular enough that the _bodyparts.dm position fix (which only
/// corrects "this species' head worn by someone else") doesn't help the reverse case: THEM
/// wearing a normal (or any other) head shape on their own irregular body. Rather than trying
/// to compensate for every possible donor on top of an already-irregular wearer, just don't
/// offer Head Shape to these species at all.
/datum/preference/proc/head_shape_wearer_is_restricted(datum/preferences/preferences)
	var/species_type = preferences.read_preference(/datum/preference/choiced/species)
	return ispath(species_type, /datum/species/teshari) || ispath(species_type, /datum/species/gas)

/datum/preference/toggle/mutant_toggle/head_shape
	category = PREFERENCE_CATEGORY_SECONDARY_FEATURES
	savefile_key = "head_shape_toggle"
	relevant_mutant_bodypart = "head_shape"

/datum/preference/toggle/mutant_toggle/head_shape/is_accessible(datum/preferences/preferences)
	if(!..())
		return FALSE
	return !head_shape_wearer_is_restricted(preferences)

/datum/sprite_accessory/heads
	key = "head_shape"
	color_src = null
	/// Bodypart typepath to borrow purely cosmetic icon info from via initial().
	/// Never actually instantiated or swapped in.
	var/obj/item/bodypart/head/donor_head_type
	/// If TRUE, hides the head entirely (alpha 0) instead of reskinning it.
	var/headless = FALSE

/datum/sprite_accessory/heads/headless
	name = "Headless"
	headless = TRUE

/datum/sprite_accessory/heads/lizard
	name = "Lizard"
	donor_head_type = /obj/item/bodypart/head/lizard

/datum/sprite_accessory/heads/moth
	name = "Moth"
	donor_head_type = /obj/item/bodypart/head/moth

/datum/sprite_accessory/heads/snail
	name = "Snail"
	donor_head_type = /obj/item/bodypart/head/snail

/datum/sprite_accessory/heads/jelly
	name = "Jelly"
	donor_head_type = /obj/item/bodypart/head/jelly

/datum/sprite_accessory/heads/pod
	name = "Podperson"
	donor_head_type = /obj/item/bodypart/head/pod

/datum/sprite_accessory/heads/shadekin
	name = "Shadekin"
	donor_head_type = /obj/item/bodypart/head/shadekin

/datum/sprite_accessory/heads/skrell
	name = "Skrell"
	donor_head_type = /obj/item/bodypart/head/mutant/skrell

/datum/sprite_accessory/heads/vox
	name = "Vox"
	donor_head_type = /obj/item/bodypart/head/mutant/vox

/datum/sprite_accessory/heads/akula
	name = "Akula"
	donor_head_type = /obj/item/bodypart/head/mutant/akula

/datum/sprite_accessory/heads/serpentid
	name = "Serpentid"
	donor_head_type = /obj/item/bodypart/head/mutant/serpentid

/datum/sprite_accessory/heads/insect
	name = "Insect"
	donor_head_type = /obj/item/bodypart/head/mutant/insect

// Teshari omitted: fixing their South/North head position+width needs a scale/shift transform,
// but the same transform would also apply to East/West (already the correct width) since BYOND
// applies .transform uniformly across a single multi-directional image, incorrectly stretching
// those. A real fix needs a direction-aware transform (swap it on facing change via signal).
// That's bigger scope than this pass, so it's left out for now.

/datum/sprite_accessory/heads/aquatic
	name = "Aquatic"
	donor_head_type = /obj/item/bodypart/head/mutant/aquatic

/datum/sprite_accessory/heads/xenohybrid
	name = "Xenohybrid"
	donor_head_type = /obj/item/bodypart/head/mutant/xenohybrid

/datum/sprite_accessory/heads/ghoul
	name = "Ghoul"
	donor_head_type = /obj/item/bodypart/head/mutant/ghoul

/datum/sprite_accessory/heads/lycan
	name = "Lycan"
	donor_head_type = /obj/item/bodypart/head/mutant/lycan

/datum/sprite_accessory/heads/protean
	name = "Protean"
	donor_head_type = /obj/item/bodypart/head/mutant/protean

/datum/preference/choiced/mutant_choice/head_shape
	category = PREFERENCE_CATEGORY_SECONDARY_FEATURES
	savefile_key = "feature_head_shape"
	main_feature_name = "Head Shape"
	relevant_mutant_bodypart = "head_shape"
	type_to_check = /datum/preference/toggle/mutant_toggle/head_shape
	default_accessory_type = /datum/sprite_accessory/heads/headless
	// Must apply after species (which recreates the head bodypart from scratch on every
	// preview refresh, not just on an actual species change) or our change_appearance()
	// call lands on a bodypart object that's about to be discarded. Same fix quad_eyes/
	// taur_mechanics use for the same reason.
	priority = PREFERENCE_PRIORITY_BODYPARTS + 0.1

/datum/preference/choiced/mutant_choice/head_shape/is_accessible(datum/preferences/preferences)
	if(!..())
		return FALSE
	return !head_shape_wearer_is_restricted(preferences)

/datum/preference/choiced/mutant_choice/head_shape/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	var/bodypart_is_visible = ..()
	var/obj/item/bodypart/head/our_head = target.get_bodypart(BODY_ZONE_HEAD)
	// Toggle off (or species-mismatched-parts-off): leave the bodypart exactly as species
	// application already set it up moments ago in this same pass. Nothing to undo later,
	// since every refresh recreates it fresh regardless of what a prior refresh did to it.
	if(isnull(our_head) || !bodypart_is_visible)
		return bodypart_is_visible
	// our_head.limb_alpha itself gets recalculated from this dna.features key on every redraw.
	// It's the same key the existing "Limb Transparency" slider writes to, so route through
	// that preference's own current value rather than a hardcoded 255 when not headless, to
	// avoid fighting a transparency value the player set deliberately for another reason.
	var/datum/sprite_accessory/heads/chosen = SSaccessories.sprite_accessories[relevant_mutant_bodypart][value]
	if(chosen?.headless)
		target.dna.features["limb_alpha_[BODY_ZONE_HEAD]"] = 0
		return bodypart_is_visible
	target.dna.features["limb_alpha_[BODY_ZONE_HEAD]"] = preferences?.read_preference(/datum/preference/numeric/limb_alpha/head) || 255
	if(!chosen?.donor_head_type)
		return bodypart_is_visible
	var/list/donor_appearance = our_head.get_donor_head_appearance(chosen.donor_head_type)
	our_head.change_appearance(
		donor_appearance["icon"],
		donor_appearance["limb_id"],
		donor_appearance["greyscale"],
		donor_appearance["dimorphic"],
	)
	our_head.apply_donor_head_offsets(chosen.donor_head_type)
	return bodypart_is_visible

/// Reads the purely-cosmetic icon vars off another head bodypart TYPE (never instantiated) via initial(),
/// mirroring get_limb_icon()'s own used_icon selection so the borrowed look renders exactly like it does
/// on the donor species. Defined here (rather than read directly by the preference) since icon_static/
/// icon_greyscale are VAR_PROTECTED.
/obj/item/bodypart/head/proc/get_donor_head_appearance(obj/item/bodypart/head/donor_type)
	var/effective_greyscale = !!(initial(donor_type.should_draw_greyscale) && initial(donor_type.icon_greyscale))
	return list(
		"icon" = effective_greyscale ? initial(donor_type.icon_greyscale) : initial(donor_type.icon_static),
		"greyscale" = effective_greyscale,
		"limb_id" = initial(donor_type.limb_id),
		"dimorphic" = initial(donor_type.is_dimorphic),
	)

/// Some species heads (Teshari, notably) are an unusual size/shape and carry worn_feature_offset
/// datums (see code/modules/surgery/bodyparts/worn_feature_offset.dm) that reposition hats/masks/
/// glasses/ears/face overlays to fit. Those offsets only ever get set at runtime inside the donor
/// type's own Initialize(), never as a static initial() value, so the only way to read them is to
/// briefly instantiate the donor type, copy whatever offsets it actually ended up with, and clean
/// up. Also explicitly clears our own offsets for keys the donor doesn't set, so a species with its
/// own special offsets (e.g. an actual Teshari picking a normal head shape) doesn't keep them.
/obj/item/bodypart/head/proc/apply_donor_head_offsets(obj/item/bodypart/head/donor_type)
	var/obj/item/bodypart/head/temp_donor = new donor_type()
	for(var/feature_key in list(OFFSET_EARS, OFFSET_GLASSES, OFFSET_FACEMASK, OFFSET_HEAD, OFFSET_FACE))
		var/datum/worn_feature_offset/existing_offset = feature_offsets[feature_key]
		if(existing_offset)
			qdel(existing_offset)
		var/datum/worn_feature_offset/donor_offset = temp_donor.feature_offsets[feature_key]
		if(donor_offset)
			new /datum/worn_feature_offset(src, feature_key, donor_offset.offset_x, donor_offset.offset_y)
	qdel(temp_donor)
