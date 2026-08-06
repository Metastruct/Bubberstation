#define TESHARI_MARKING_SHIFT_Y -5

/datum/bodypart_overlay/simple/body_marking/get_image(layer, obj/item/bodypart/limb)
	var/mutable_appearance/marking_image = ..()
	if(istype(limb, /obj/item/bodypart/head/mutant/teshari) && copytext(icon_state, 1, 8) != "teshari")
		marking_image.pixel_z += TESHARI_MARKING_SHIFT_Y
	return marking_image

#undef TESHARI_MARKING_SHIFT_Y
