/obj/effect/abstract/liquid_turf/wash(clean_types)
	. = ..()
	if(clean_types & CLEAN_TYPE_LIQUIDS)
		qdel(src.take_reagents_flat(src.total_reagents))
		return TRUE
