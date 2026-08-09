/datum/bodypart_overlay/simple/emote/get_image(layer, obj/item/bodypart/limb)
	var/image/emote_image = ..()
	if(!istype(limb, /obj/item/bodypart/head/mutant/teshari))
		return emote_image

	if(istype(src, /datum/bodypart_overlay/simple/emote/cry))
		emote_image.transform = matrix(1.5, 0, 1, 0, 1, -1)
	else if(istype(src, /datum/bodypart_overlay/simple/emote/blush))
		emote_image.transform = matrix(1.5, 0, 1, 0, 1, -1)

	return emote_image
