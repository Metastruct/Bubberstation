#define ALERT_SHAKE_OFF "shake_off"

/**
 * Tracks a mob being coated in liquid, independent of wet_stacks/fire_stacks, so a
 * reagent can mark a mob as "shake-off-able" without affecting fire-fighting mechanics
 * at all (wet_stacks doubles as negative fire_stacks; this deliberately does not).
 * Decays over time like wet_stacks does. Mammals get a HUD alert to shake it off early.
 */
/datum/status_effect/coated_in_liquid
	id = "coated_in_liquid"
	duration = STATUS_EFFECT_PERMANENT
	status_type = STATUS_EFFECT_REFRESH
	alert_type = null
	tick_interval = 2 SECONDS
	/// How coated we are. Decays over time; shaking it off (or it reaching 0) clears the effect.
	var/stacks = 0
	/// Reagents that caused the coating, so shaking off spawns the actual liquid (reagent type to amount)
	var/list/soaked_reagents

/datum/status_effect/coated_in_liquid/on_creation(mob/living/new_owner, add_stacks = 0, reagent_type, reagent_amount)
	. = ..()
	apply_coating(add_stacks, reagent_type, reagent_amount)

/datum/status_effect/coated_in_liquid/refresh(effect, add_stacks = 0, reagent_type, reagent_amount)
	apply_coating(add_stacks, reagent_type, reagent_amount)

/datum/status_effect/coated_in_liquid/proc/apply_coating(add_stacks, reagent_type, reagent_amount)
	stacks = max(stacks + add_stacks, 0)
	if(!reagent_type)
		return
	if(!soaked_reagents)
		soaked_reagents = list()
	if(!soaked_reagents[reagent_type])
		soaked_reagents[reagent_type] = 0
	soaked_reagents[reagent_type] += reagent_amount

/datum/status_effect/coated_in_liquid/on_apply()
	owner.throw_alert(ALERT_SHAKE_OFF, /atom/movable/screen/alert/shake_off)
	return TRUE

/datum/status_effect/coated_in_liquid/on_remove()
	owner.clear_alert(ALERT_SHAKE_OFF)

/datum/status_effect/coated_in_liquid/tick(seconds_between_ticks)
	stacks = max(stacks - 0.5 * seconds_between_ticks, 0)
	if(stacks <= 0)
		qdel(src)

/// Coats a mob in a liquid, marking them shake-off-able and remembering the reagent, without touching wet_stacks/fire_stacks at all.
/mob/living/proc/get_coated_in_liquid(reagent_type, amount)
	apply_status_effect(/datum/status_effect/coated_in_liquid, amount, reagent_type, amount)
