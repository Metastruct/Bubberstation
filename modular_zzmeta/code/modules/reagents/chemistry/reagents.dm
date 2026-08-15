/datum/reagent
	/// If TRUE, touching/spraying a mob with this reagent coats them in it (see
	/// /datum/status_effect/coated_in_liquid), shake-off-able, independent of
	/// wet_stacks/fire_stacks entirely. Defaults TRUE (blanket) since coating no longer
	/// affects fire-fighting balance at all; flip individual reagents to FALSE if a
	/// specific one genuinely shouldn't be shown as "covered in liquid".
	var/causes_liquid_coating = TRUE

/datum/reagent/expose_mob(mob/living/exposed_mob, methods = TOUCH, reac_volume, show_message = TRUE, touch_protection = 0)
	. = ..()
	if(!causes_liquid_coating || !(methods & (TOUCH|VAPOR)))
		return
	exposed_mob.get_coated_in_liquid(type, reac_volume)
