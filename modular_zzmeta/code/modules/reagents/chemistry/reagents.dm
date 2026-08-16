/datum/reagent/expose_mob(mob/living/exposed_mob, methods = TOUCH, reac_volume, show_message = TRUE, touch_protection = 0)
	. = ..()
	if(!(methods & (TOUCH|VAPOR)))
		return
	exposed_mob.get_coated_in_liquid(type, reac_volume)
