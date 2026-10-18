// Only applies when the owner is not a teshari

#define TESHARI_LEG_FIT_SCALE_X (1 / 0.95)
#define TESHARI_LEG_FIT_SHIFT_X (-0.5)

/obj/item/bodypart/leg/left/mutant/teshari/get_limb_icon(dropped)
	. = ..()
	if(!dropped && teshari_leg_needs_fit(owner))
		fit_teshari_legs(.)
	return .

/obj/item/bodypart/leg/left/mutant/teshari/generate_icon_key()
	. = ..()
	if(teshari_leg_needs_fit(owner))
		. += "teshari_leg_fit"
	return .

/obj/item/bodypart/leg/right/mutant/teshari/get_limb_icon(dropped)
	. = ..()
	if(!dropped && teshari_leg_needs_fit(owner))
		fit_teshari_legs(.)
	return .

/obj/item/bodypart/leg/right/mutant/teshari/generate_icon_key()
	. = ..()
	if(teshari_leg_needs_fit(owner))
		. += "teshari_leg_fit"
	return .

/obj/item/bodypart/leg/left/digitigrade/teshari/get_limb_icon(dropped)
	. = ..()
	if(!dropped && teshari_leg_needs_fit(owner))
		fit_teshari_legs(.)
	return .

/obj/item/bodypart/leg/left/digitigrade/teshari/generate_icon_key()
	. = ..()
	if(teshari_leg_needs_fit(owner))
		. += "teshari_leg_fit"
	return .

/obj/item/bodypart/leg/right/digitigrade/teshari/get_limb_icon(dropped)
	. = ..()
	if(!dropped && teshari_leg_needs_fit(owner))
		fit_teshari_legs(.)
	return .

/obj/item/bodypart/leg/right/digitigrade/teshari/generate_icon_key()
	. = ..()
	if(teshari_leg_needs_fit(owner))
		. += "teshari_leg_fit"
	return .

/// TRUE when a teshari leg is worn by a non-teshari (and so needs the fit transform).
/proc/teshari_leg_needs_fit(mob/living/carbon/human/owner)
	return ishuman(owner) && owner.dna?.species?.id != SPECIES_TESHARI

/// Applies the teshari leg-fit transform to a leg's rendered overlays.
/proc/fit_teshari_legs(list/overlays)
	var/matrix/leg_matrix = matrix(TESHARI_LEG_FIT_SCALE_X, 0, TESHARI_LEG_FIT_SHIFT_X, 0, 1, 0)
	for(var/image/overlay as anything in overlays)
		overlay.transform = leg_matrix
		overlay.appearance_flags |= PIXEL_SCALE

#undef TESHARI_LEG_FIT_SCALE_X
#undef TESHARI_LEG_FIT_SHIFT_X
