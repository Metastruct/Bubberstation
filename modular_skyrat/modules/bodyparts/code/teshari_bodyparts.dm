#define TESHARI_PUNCH_LOW 2 // Lower bound punch damage
#define TESHARI_PUNCH_HIGH 6
#define TESHARI_BURN_MODIFIER 1.25 // They take more damage from practically everything
#define TESHARI_BRUTE_MODIFIER 1.2

// META EDIT - ADDITION - START - TESHARI_HAIR_FIT
// Generic hairstyles are drawn centered on an odd-width head (has a middle) teshari's head is even-width
// this seems to work the best
#define TESHARI_HAIR_SCALE_X 0.95
#define TESHARI_HAIR_SHIFT_X (0.5 * TESHARI_HAIR_SCALE_X)
// META EDIT - ADDITION - END

// teshari!
/obj/item/bodypart/head/mutant/teshari
	icon_greyscale = BODYPART_ICON_TESHARI
	bodyshape = parent_type::bodyshape | BODYSHAPE_CUSTOM
	limb_id = SPECIES_TESHARI
	brute_modifier = TESHARI_BRUTE_MODIFIER
	burn_modifier = TESHARI_BURN_MODIFIER
	head_flags = HEAD_EYESPRITES|HEAD_EYECOLOR|HEAD_EYEHOLES|HEAD_DEBRAIN|HEAD_HAIR

/obj/item/bodypart/head/mutant/teshari/Initialize(mapload)
	worn_ears_offset = new(
		attached_part = src,
		feature_key = OFFSET_EARS,
		offset_y = list("north" = -4, "south" = -4, "east" = -4, "west" = -4),
	)
	worn_head_offset = new(
		attached_part = src,
		feature_key = OFFSET_HEAD,
		offset_x = list("north" = 1, "south" = 1, "east" = 1, "west" = -1, "northwest" = -1, "southwest" = -1, "northeast" = 1, "southeast" = 1),
		offset_y = list("north" = -4, "south" = -4, "east" = -4, "west" = -4),
	)
	worn_mask_offset = new(
		attached_part = src,
		feature_key = OFFSET_FACEMASK,
		offset_y = list("north" = -5, "south" = -5, "east" = -5, "west" = -5),
	)
	// META EDIT - ADDITION - START - TESHARI_HAIR_FIT
	worn_face_offset = new(
		attached_part = src,
		feature_key = OFFSET_FACE,
		offset_y = list("north" = -5, "south" = -5, "east" = -5, "west" = -5),
	)
	// META EDIT - ADDITION - END
	return ..()

// META EDIT - ADDITION - START - TESHARI_HAIR_FIT
// transforms generic hair to close the "seam" in the middle from the odd/even head-width mismatch.
/obj/item/bodypart/head/mutant/teshari/get_hair_overlays(dropped)
	. = ..()
	var/obj/item/organ/brain/brain = locate() in src
	if(QDELETED(brain) && (head_flags & HEAD_DEBRAIN))
		return .
	if(copytext(hairstyle, 1, 8) == "Teshari") // skip existing teshari headstyles
		return .

	var/matrix/hair_matrix = matrix(TESHARI_HAIR_SCALE_X, 0, TESHARI_HAIR_SHIFT_X, 0, 1, 0)
	for(var/image/hair_overlay in .)
		hair_overlay.transform = hair_matrix
		hair_overlay.appearance_flags |= PIXEL_SCALE
	for(var/mutable_appearance/gradient_overlay in .)
		gradient_overlay.transform = hair_matrix
		gradient_overlay.appearance_flags |= PIXEL_SCALE
	return .
// META EDIT - ADDITION - END


/obj/item/bodypart/chest/mutant/teshari
	icon_greyscale = BODYPART_ICON_TESHARI
	bodyshape = parent_type::bodyshape | BODYSHAPE_CUSTOM
	limb_id = SPECIES_TESHARI
	brute_modifier = TESHARI_BRUTE_MODIFIER
	burn_modifier = TESHARI_BURN_MODIFIER

/obj/item/bodypart/chest/mutant/teshari/get_butt_sprite()
	return icon('modular_skyrat/master_files/icons/mob/butts.dmi', BUTT_SPRITE_VOX)

/obj/item/bodypart/chest/mutant/teshari/Initialize(mapload)
	worn_back_offset = new(
		attached_part = src,
		feature_key = OFFSET_BACK,
		offset_y = list("north" = -4, "south" = -4, "east" = -4, "west" = -4),
	)
	worn_accessory_offset = new(
		attached_part = src,
		feature_key = OFFSET_ACCESSORY,
		offset_y = list("north" = -4, "south" = -4, "east" = -4, "west" = -4),
	)
	return ..()

/obj/item/bodypart/arm/left/mutant/teshari/Initialize(mapload)
	held_hand_offset =  new(
		attached_part = src,
		feature_key = OFFSET_HELD,
		offset_x = list("north" = 0, "south" = 0, "east" = 0, "west" = -6, "northwest" = -6, "southwest" = -6, "northeast" = 0, "southeast" = 0),
		offset_y = list("north" = -3, "south" = -3, "east" = -3, "west" = -3),
	)
	return ..()

/obj/item/bodypart/arm/right/mutant/teshari/Initialize(mapload)
	held_hand_offset =  new(
		attached_part = src,
		feature_key = OFFSET_HELD,
		offset_x = list("north" = 0, "south" = 0, "east" = 6, "west" = 0, "northwest" = 0, "southwest" = 0, "northeast" = 6, "southeast" = 6),
		offset_y = list("north" = -3, "south" = -3, "east" = -3, "west" = -3),
	)
	return ..()

/obj/item/bodypart/arm/left/mutant/teshari
	icon_greyscale = BODYPART_ICON_TESHARI
	bodyshape = parent_type::bodyshape | BODYSHAPE_CUSTOM
	limb_id = SPECIES_TESHARI
	unarmed_damage_low = TESHARI_PUNCH_LOW
	unarmed_damage_high = TESHARI_PUNCH_HIGH
	brute_modifier = TESHARI_BRUTE_MODIFIER
	burn_modifier = TESHARI_BURN_MODIFIER


/obj/item/bodypart/arm/right/mutant/teshari
	icon_greyscale = BODYPART_ICON_TESHARI
	bodyshape = parent_type::bodyshape | BODYSHAPE_CUSTOM
	limb_id = SPECIES_TESHARI
	unarmed_damage_low = TESHARI_PUNCH_LOW
	unarmed_damage_high = TESHARI_PUNCH_HIGH
	brute_modifier = TESHARI_BRUTE_MODIFIER
	burn_modifier = TESHARI_BURN_MODIFIER


/obj/item/bodypart/leg/left/mutant/teshari
	icon_greyscale = BODYPART_ICON_TESHARI
	bodyshape = parent_type::bodyshape | BODYSHAPE_CUSTOM
	limb_id = SPECIES_TESHARI
	digitigrade_type = /obj/item/bodypart/leg/left/digitigrade/teshari
	brute_modifier = TESHARI_BRUTE_MODIFIER
	burn_modifier = TESHARI_BURN_MODIFIER

/obj/item/bodypart/leg/right/mutant/teshari
	icon_greyscale = BODYPART_ICON_TESHARI
	bodyshape = parent_type::bodyshape | BODYSHAPE_CUSTOM
	limb_id = SPECIES_TESHARI
	digitigrade_type = /obj/item/bodypart/leg/right/digitigrade/teshari
	brute_modifier = TESHARI_BRUTE_MODIFIER
	burn_modifier = TESHARI_BURN_MODIFIER

/obj/item/bodypart/leg/left/digitigrade/teshari
	icon_greyscale = BODYPART_ICON_TESHARI
	bodyshape = parent_type::bodyshape | BODYSHAPE_CUSTOM
	base_limb_id = SPECIES_TESHARI
	brute_modifier = TESHARI_BRUTE_MODIFIER
	burn_modifier = TESHARI_BURN_MODIFIER

/obj/item/bodypart/leg/right/digitigrade/teshari
	icon_greyscale = BODYPART_ICON_TESHARI
	bodyshape = parent_type::bodyshape | BODYSHAPE_CUSTOM
	base_limb_id = SPECIES_TESHARI
	brute_modifier = TESHARI_BRUTE_MODIFIER
	burn_modifier = TESHARI_BURN_MODIFIER

#undef TESHARI_PUNCH_LOW
#undef TESHARI_PUNCH_HIGH
#undef TESHARI_BURN_MODIFIER
#undef TESHARI_BRUTE_MODIFIER
// META EDIT - ADDITION - START - TESHARI_HAIR_FIT
#undef TESHARI_HAIR_SCALE_X
#undef TESHARI_HAIR_SHIFT_X
// META EDIT - ADDITION - END
