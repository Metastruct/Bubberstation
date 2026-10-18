// META EDIT - ADDITION - START - UPSTREAM_97789_MOTH_ARMS
#define BRUTE_MOD 1.15
#define BURN_MOD 1.15
#define WOUND_RES_LIMB_MALUS -10 // ouch
#define WOUND_RES_CORE_MALUS -20 // ouch!!!
// META EDIT - ADDITION - END - UPSTREAM_97789_MOTH_ARMS

/obj/item/bodypart/head/moth
	icon = BODYPART_ICON_MOTH
	icon_greyscale = BODYPART_ICON_MOTH
	icon_state = "moth_head_m"
	limb_id = SPECIES_MOTH
	is_dimorphic = TRUE
	head_flags = HEAD_HAIR|HEAD_FACIAL_HAIR|HEAD_LIPS|HEAD_EYESPRITES|HEAD_EYEHOLES|HEAD_DEBRAIN|HEAD_EYECOLOR //what the fuck, moths have lips?
	teeth_count = 0
	// META EDIT - ADDITION - START - UPSTREAM_97789_MOTH_ARMS
	brute_modifier = BRUTE_MOD
	burn_modifier = BURN_MOD
	wound_resistance = /obj/item/bodypart/head::wound_resistance + WOUND_RES_CORE_MALUS
	// META EDIT - ADDITION - END - UPSTREAM_97789_MOTH_ARMS

/obj/item/bodypart/chest/moth
	icon = BODYPART_ICON_MOTH
	icon_greyscale = BODYPART_ICON_MOTH
	icon_state = "moth_chest_m"
	limb_id = SPECIES_MOTH
	is_dimorphic = TRUE
	wing_types = list(/obj/item/organ/wings/functional/moth/megamoth, /obj/item/organ/wings/functional/moth/mothra)
	// META EDIT - ADDITION - START - UPSTREAM_97789_MOTH_ARMS
	brute_modifier = BRUTE_MOD
	burn_modifier = BURN_MOD
	wound_resistance = /obj/item/bodypart/chest::wound_resistance + WOUND_RES_CORE_MALUS
	can_be_disabled = TRUE // to allow disabling the chest arms

	VAR_PRIVATE/obj/item/bodypart/arm/left/moth/inner/left_inner
	VAR_PRIVATE/obj/item/bodypart/arm/right/moth/inner/right_inner
	// META EDIT - ADDITION - END - UPSTREAM_97789_MOTH_ARMS

// META EDIT - ADDITION - START - UPSTREAM_97789_MOTH_ARMS
/obj/item/bodypart/chest/moth/Initialize(mapload)
	. = ..()
	left_inner = new(src)
	right_inner = new(src)
	add_bodypart_overlay(new /datum/bodypart_overlay/simple/moth_arms())
	RegisterSignal(left_inner, COMSIG_BODYPART_POST_REMOVED, PROC_REF(slurp_up_limbs))
	RegisterSignal(right_inner, COMSIG_BODYPART_POST_REMOVED, PROC_REF(slurp_up_limbs))

/obj/item/bodypart/chest/moth/Destroy()
	QDEL_NULL(left_inner)
	QDEL_NULL(right_inner)
	return ..()

/obj/item/bodypart/chest/moth/proc/slurp_up_limbs(datum/source, mob/living/carbon/owner, special, dismembered)
	SIGNAL_HANDLER

	astype(source, /obj/item/bodypart/arm)?.forceMove(src)

/obj/item/bodypart/chest/moth/set_disabled(new_disabled, update_limbs)
	. = ..()
	left_inner.set_disabled(new_disabled, update_limbs)
	right_inner.set_disabled(new_disabled, update_limbs)

/obj/item/bodypart/chest/moth/try_attach_limb(mob/living/carbon/new_owner, special, lazy)
	. = ..()
	if(!.)
		return

	new_owner.change_number_of_hands(4)
	left_inner.try_attach_limb(new_owner, special = TRUE)
	right_inner.try_attach_limb(new_owner, special = TRUE)

/obj/item/bodypart/chest/moth/on_removal(mob/living/carbon/old_owner)
	left_inner.drop_limb(special = TRUE, dismembered = FALSE, move_to_floor = FALSE)
	right_inner.drop_limb(special = TRUE, dismembered = FALSE, move_to_floor = FALSE)
	old_owner.change_number_of_hands(2)
	. = ..()
// META EDIT - ADDITION - END - UPSTREAM_97789_MOTH_ARMS

/obj/item/bodypart/chest/moth/get_butt_sprite()
	return icon('icons/mob/butts.dmi', BUTT_SPRITE_FUZZY)

/obj/item/bodypart/arm/left/moth
	icon = BODYPART_ICON_MOTH
	icon_greyscale = BODYPART_ICON_MOTH
	icon_state = "moth_l_arm"
	limb_id = SPECIES_MOTH
	// META EDIT - ADDITION - START - UPSTREAM_97789_MOTH_ARMS
	brute_modifier = BRUTE_MOD
	burn_modifier = BURN_MOD
	wound_resistance = /obj/item/bodypart/arm/left::wound_resistance + WOUND_RES_LIMB_MALUS
	// META EDIT - ADDITION - END - UPSTREAM_97789_MOTH_ARMS

/obj/item/bodypart/arm/right/moth
	icon = BODYPART_ICON_MOTH
	icon_greyscale = BODYPART_ICON_MOTH
	icon_state = "moth_r_arm"
	limb_id = SPECIES_MOTH
	// META EDIT - ADDITION - START - UPSTREAM_97789_MOTH_ARMS
	brute_modifier = BRUTE_MOD
	burn_modifier = BURN_MOD
	wound_resistance = /obj/item/bodypart/arm/right::wound_resistance + WOUND_RES_LIMB_MALUS
	// META EDIT - ADDITION - END - UPSTREAM_97789_MOTH_ARMS

/obj/item/bodypart/leg/left/moth
	icon = BODYPART_ICON_MOTH
	icon_greyscale = BODYPART_ICON_MOTH
	icon_state = "moth_l_leg"
	limb_id = SPECIES_MOTH
	// META EDIT - ADDITION - START - UPSTREAM_97789_MOTH_ARMS
	brute_modifier = BRUTE_MOD
	burn_modifier = BURN_MOD
	wound_resistance = /obj/item/bodypart/leg/left::wound_resistance + WOUND_RES_LIMB_MALUS
	// META EDIT - ADDITION - END - UPSTREAM_97789_MOTH_ARMS

/obj/item/bodypart/leg/right/moth
	icon = BODYPART_ICON_MOTH
	icon_greyscale = BODYPART_ICON_MOTH
	icon_state = "moth_r_leg"
	limb_id = SPECIES_MOTH
	// META EDIT - ADDITION - START - UPSTREAM_97789_MOTH_ARMS
	brute_modifier = BRUTE_MOD
	burn_modifier = BURN_MOD
	wound_resistance = /obj/item/bodypart/leg/right::wound_resistance + WOUND_RES_LIMB_MALUS
	// META EDIT - ADDITION - END - UPSTREAM_97789_MOTH_ARMS

// META EDIT - ADDITION - START - UPSTREAM_97789_MOTH_ARMS
/obj/item/bodypart/arm/left/moth/inner
	body_zone = null
	held_index = 3
	bodypart_flags = BODYPART_UNREMOVABLE | BODYPART_ABSTRACT | BODYPART_VIRGIN
	plaintext_zone = "left chest-arm"

/obj/item/bodypart/arm/left/moth/inner/Initialize(mapload)
	name = "left chest-arm"
	held_hand_offset =  new(
		attached_part = src,
		feature_key = OFFSET_HELD,
		offset_x = list("north" = 2, "south" = -2, "east" = 2, "west" = -8),
		offset_y = list("south" = -12), // shhh
	)
	return ..()

/obj/item/bodypart/arm/left/moth/inner/drop_limb(special, dismembered, move_to_floor)
	if(special)
		return ..()
	return FALSE

/obj/item/bodypart/arm/left/moth/inner/generate_icon_key()
	return list()

/obj/item/bodypart/arm/right/moth/inner
	body_zone = null
	held_index = 4
	bodypart_flags = BODYPART_UNREMOVABLE | BODYPART_ABSTRACT | BODYPART_VIRGIN
	plaintext_zone = "right chest-arm"

/obj/item/bodypart/arm/right/moth/inner/Initialize(mapload)
	name = "left chest-arm"
	held_hand_offset = new (
		attached_part = src,
		feature_key = OFFSET_HELD,
		offset_x = list("north" = -2, "south" = 2, "east" = 8, "west" = -2),
		offset_y = list("south" = -12),
	)
	return ..()

/obj/item/bodypart/arm/right/moth/inner/drop_limb(special, dismembered, move_to_floor)
	if(special)
		return ..()
	return FALSE

/obj/item/bodypart/arm/right/moth/inner/generate_icon_key()
	return list()

// TODO: should be mutant overlay at some point?
/datum/bodypart_overlay/simple/moth_arms
	layers = list(
		EXTERNAL_FRONT = BODY_FRONT_LAYER,
	)
	offset_location = UPPER_BODY
	icon = 'icons/mob/human/species/moth/moth_arms.dmi'
	// META EDIT - CHANGE - START - UPSTREAM_97789_MOTH_ARMS
	// The fork's /datum/bodypart_overlay/simple/get_image ignores the layer postfix,
	// unlike upstream which appends "_[layer_index]". Use the full state name directly.
	// ORIGINAL: icon_state = "m_moth_arms_generic"
	icon_state = "m_moth_arms_generic_FRONT"
	// META EDIT - CHANGE - END - UPSTREAM_97789_MOTH_ARMS

// The arm sprite is greyscale; tint it with the owning limb's draw colour so it
// follows the same mutant-colour/skin-tone logic as the rest of the body.
/datum/bodypart_overlay/simple/moth_arms/color_image(image/overlay, obj/item/bodypart/limb, layer_index)
	overlay.color = isnull(limb?.draw_color) ? draw_color : limb.draw_color

/datum/bodypart_overlay/simple/moth_arms/icon_render_key(obj/item/bodypart/limb)
	. = ..()
	. += "[limb?.draw_color]"

#undef BRUTE_MOD
#undef BURN_MOD
#undef WOUND_RES_LIMB_MALUS
#undef WOUND_RES_CORE_MALUS
// META EDIT - ADDITION - END - UPSTREAM_97789_MOTH_ARMS
