/// One entry per "licking this hurts you" reaction.
/datum/lick_hazard
	var/name = "hazard"

/// Applies this hazard's reaction to `target` if it applies at all.
/// Returns TRUE if it did fire.
/datum/lick_hazard/proc/try_apply(atom/target, datum/status_effect/sensory/lick/effect)
	return FALSE


/datum/lick_hazard/electric
	name = "electrified grille"

/datum/lick_hazard/electric/try_apply(atom/target, datum/status_effect/sensory/lick/effect)
	if(!istype(target, /obj/structure/grille))
		return FALSE
	var/obj/structure/grille/grille = target
	var/mob/living/licker = effect.owner
	if(!grille.shock(licker, 70))
		return FALSE
	licker.visible_message(
		span_notice("[licker] recoils as [grille] crackles with electricity!"),
		span_userdanger("You get a mouthful of live current from [grille]!"),
	)
	return TRUE


/datum/lick_hazard/supermatter
	name = "supermatter crystal"

/datum/lick_hazard/supermatter/try_apply(atom/target, datum/status_effect/sensory/lick/effect)
	if(!istype(target, /obj/machinery/power/supermatter_crystal))
		return FALSE
	var/mob/living/licker = effect.owner
	licker.visible_message(
		span_notice("[licker] touches [licker.p_their()] tongue to [target] and immediately regrets it."),
		span_userdanger("The crystal hums against your tongue. Something behind your eyes starts to feel warm."),
	)
	licker.apply_damage(8, BURN, BODY_ZONE_HEAD, wound_bonus = CANT_WOUND, attacking_item = target)
	SSradiation.irradiate(licker)
	return TRUE


/datum/lick_hazard/flame
	name = "open flame"

/datum/lick_hazard/flame/try_apply(atom/target, datum/status_effect/sensory/lick/effect)
	var/is_flame = istype(target, /obj/effect/hotspot)
	if(!is_flame)
		if(!isliving(target))
			return FALSE
		var/mob/living/living_target = target
		is_flame = living_target.on_fire || living_target.fire_stacks > 0
	if(!is_flame)
		return FALSE

	var/mob/living/licker = effect.owner
	licker.visible_message(
		span_notice("[licker] licks [target] and recoils with a sizzle!"),
		span_userdanger("You lick [target]. There is a sizzle, and then there is regret."),
	)
	licker.apply_damage(rand(4, 8), BURN, BODY_ZONE_HEAD, wound_bonus = CANT_WOUND, attacking_item = istype(target, /obj/item) ? target : null)
	return TRUE


/datum/lick_hazard/mousetrap
	name = "armed mousetrap"

/datum/lick_hazard/mousetrap/try_apply(atom/target, datum/status_effect/sensory/lick/effect)
	if(!istype(target, /obj/item/assembly/mousetrap))
		return FALSE
	var/obj/item/assembly/mousetrap/trap = target
	if(!trap.armed)
		return FALSE
	trap.armed = FALSE
	trap.update_appearance()
	playsound(trap, 'sound/effects/snap.ogg', 50, TRUE)
	trap.pulse()

	var/mob/living/licker = effect.owner
	licker.visible_message(
		span_notice("[licker] recoils as [trap] snaps shut on [licker.p_their()] tongue!"),
		span_userdanger("[trap] snaps shut on your tongue!"),
	)
	licker.apply_damage(3, BRUTE, BODY_ZONE_HEAD, wound_bonus = CANT_WOUND, attacking_item = trap)
	licker.apply_status_effect(/datum/status_effect/speech/slurring/generic, 20 SECONDS)
	return TRUE


/datum/lick_hazard/lamp
	name = "lit light fixture"

/datum/lick_hazard/lamp/try_apply(atom/target, datum/status_effect/sensory/lick/effect)
	if(!istype(target, /obj/machinery/light))
		return FALSE
	var/obj/machinery/light/lamp = target
	var/mob/living/licker = effect.owner
	if(!lamp.on || HAS_TRAIT(licker, TRAIT_RESISTHEAT))
		return FALSE

	licker.visible_message(
		span_notice("[licker] recoils, burning [licker.p_their()] tongue on [lamp]!"),
		span_userdanger("You burn your tongue on [lamp]!"),
	)
	licker.apply_damage(5, BURN, BODY_ZONE_HEAD, wound_bonus = CANT_WOUND, attacking_item = lamp)
	return TRUE


/datum/lick_hazard/ants
	name = "space ants"

/datum/lick_hazard/ants/try_apply(atom/target, datum/status_effect/sensory/lick/effect)
	var/datum/reagents/source_reagents = effect.get_reagents_source(target)
	if(!source_reagents)
		return FALSE
	var/ant_amount = source_reagents.get_reagent_amount(/datum/reagent/ants) + source_reagents.get_reagent_amount(/datum/reagent/ants/fire)
	if(isturf(target))
		qdel(source_reagents)
	if(!ant_amount)
		return FALSE

	var/mob/living/licker = effect.owner
	var/max_damage = min(10, round(ant_amount * 0.1, 0.1))
	licker.visible_message(
		span_notice("[licker] recoils as the ants bite [licker.p_their()] tongue!"),
		span_userdanger("The ants bite your tongue!"),
	)
	licker.apply_damage(rand(1, max_damage), BRUTE, BODY_ZONE_HEAD, wound_bonus = CANT_WOUND, attacking_item = target)
	return TRUE


/datum/lick_hazard/gross
	name = "filth"
	/// Chance to actually throw up after the gag. STRONG_STOMACH cuts this down.
	var/vomit_chance = 40
	var/strong_stomach_vomit_chance = 10
	var/static/list/gross_types = typecacheof(list(
		/obj/structure/toilet,
		/obj/structure/urinal,
		/obj/machinery/disposal,
		/obj/structure/closet/crate/bin,
		/obj/item/storage/bag/trash,
		/obj/effect/decal/cleanable/vomit,
	))

/datum/lick_hazard/gross/try_apply(atom/target, datum/status_effect/sensory/lick/effect)
	if(!is_type_in_typecache(target, gross_types))
		return FALSE
	if(istype(target, /obj/structure/toilet))
		var/obj/structure/toilet/toilet = target
		if(!toilet.cover_open)
			return FALSE

	var/mob/living/licker = effect.owner
	to_chat(licker, span_warning("The taste of [target] hits the back of your throat."))
	licker.emote("gag")
	if(!iscarbon(licker))
		return TRUE

	var/chance = vomit_chance
	if(HAS_TRAIT(licker, TRAIT_STRONG_STOMACH))
		chance = strong_stomach_vomit_chance
	if(!prob(chance))
		return TRUE

	var/mob/living/carbon/carbon_licker = licker
	carbon_licker.vomit(MOB_VOMIT_MESSAGE)
	return TRUE
