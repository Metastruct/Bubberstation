/// Lets a rake/cultivator smooth footprints back out of sand, mirroring the snow sheet "fill in footprints" interaction on /turf/open/misc/asteroid/snow.
/turf/open/misc/beach/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/cultivator))
		return ..()

	if(!(footprint_entrance_dirs || footprint_exit_dirs))
		return ..()

	user.visible_message(
		span_notice("[user] rakes over the footprints in [src]."),
		span_notice("You rake over the footprints in [src]."),
		vision_distance = COMBAT_MESSAGE_RANGE,
	)
	clear_footprints()
	return ITEM_INTERACT_SUCCESS
