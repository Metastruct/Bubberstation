/// Head Shape
///
/// Purely visual: reskins the wearer's own head bodypart to look like another
/// species' head via change_appearance(), the same mechanism the IPC "Head
/// Appearance" feature already uses for its own chassis skins. Never touches
/// bodypart_overrides, never replaces the bodypart/organs, and deliberately
/// never touches head_flags/teeth_count/bodypart_traits/combat stats. The
/// wearer's own species keeps governing everything except the icon shown.

/datum/sprite_accessory/heads
	key = "head_shape"
	color_src = null
	/// Bodypart typepath to borrow purely cosmetic icon info from via initial().
	/// Never actually instantiated or swapped in.
	var/obj/item/bodypart/head/donor_head_type

/datum/sprite_accessory/heads/none
	name = SPRITE_ACCESSORY_NONE
	donor_head_type = /obj/item/bodypart/head

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

/datum/preference/choiced/mutant_choice/head_shape
	category = PREFERENCE_CATEGORY_SECONDARY_FEATURES
	savefile_key = "feature_head_shape"
	main_feature_name = "Head Shape"
	relevant_mutant_bodypart = "head_shape"
	default_accessory_type = /datum/sprite_accessory/heads/none

/datum/preference/choiced/mutant_choice/head_shape/is_part_enabled(datum/preferences/preferences)
	return TRUE

/datum/preference/choiced/mutant_choice/head_shape/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	. = ..() // standard dna.mutant_bodyparts bookkeeping, same pattern snout's own override uses
	var/obj/item/bodypart/head/our_head = target.get_bodypart(BODY_ZONE_HEAD)
	if(isnull(our_head))
		return
	var/datum/sprite_accessory/heads/chosen = SSaccessories.sprite_accessories[relevant_mutant_bodypart][value]
	if(!chosen?.donor_head_type)
		our_head.reset_appearance()
		return
	var/list/donor_appearance = our_head.get_donor_head_appearance(chosen.donor_head_type)
	our_head.change_appearance(
		donor_appearance["icon"],
		donor_appearance["limb_id"],
		donor_appearance["greyscale"],
		donor_appearance["dimorphic"],
	)

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
