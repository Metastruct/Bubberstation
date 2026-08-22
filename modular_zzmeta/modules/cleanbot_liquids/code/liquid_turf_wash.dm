/obj/effect/abstract/liquid_turf/wash(clean_types)
	. = ..()
	if(clean_types & CLEAN_TYPE_LIQUIDS)
		if(src.liquid_state == LIQUID_STATE_PUDDLE)
			qdel(src, TRUE)
			return TRUE
