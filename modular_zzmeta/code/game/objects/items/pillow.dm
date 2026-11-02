///Adds rotation and missing screentips

/obj/item/pillow
	var/pillow_rotation = 0

/obj/item/pillow/Initialize(mapload)
	. = ..()
	register_context()

/obj/item/pillow/click_alt_secondary(mob/user)
	set_pillow_rotation(pillow_rotation + 90)
	return CLICK_ACTION_SUCCESS

/// Applies rotation, wrapping back to no transform at 0/360.
/obj/item/pillow/proc/set_pillow_rotation(degrees)
	pillow_rotation = degrees % 360
	if(!pillow_rotation)
		transform = null
		return
	var/matrix/rotation_matrix = matrix()
	rotation_matrix.Turn(pillow_rotation)
	transform = rotation_matrix

/obj/item/pillow/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	. = ..()
	if(pillow_trophy && user?.can_hold_items(src))
		context[SCREENTIP_CONTEXT_ALT_LMB] = "Remove tag"
	context[SCREENTIP_CONTEXT_ALT_RMB] = "Rotate"
	return CONTEXTUAL_SCREENTIP_SET
