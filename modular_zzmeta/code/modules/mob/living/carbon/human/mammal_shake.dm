/// How many tiles out a shake-off splashes nearby mobs.
#define SHAKE_OFF_SPLASH_RADIUS 1
/// Minimum time between shake-offs.
#define SHAKE_OFF_COOLDOWN (4 SECONDS)
/// How much puddle volume each coating stack is worth when shaking off.
#define SHAKE_OFF_VOLUME_PER_STACK 2
/// Flat coating stacks/reagent volume splashed onto each nearby mob.
#define SHAKE_OFF_SPLASH_VOLUME 3
/// Fraction of the current coating a single shake actually gets rid of. The rest stays on you, so a heavy coating takes a couple of shakes.
#define SHAKE_OFF_REMOVAL_FRACTION 0.9

/mob/living/carbon/human
	/// world.time of the next allowed shake-off, to keep it from being spammed.
	var/next_shake_off = 0

/// Is this species one that counts as a mammal/anthro for the shake-off feature?
/proc/is_mammal_species(mob/living/living_mob)
	if(!ishuman(living_mob))
		return FALSE
	var/mob/living/carbon/human/human_mob = living_mob
	return human_mob.dna && (human_mob.dna.species.examine_limb_id in WET_DOG_SHAKE_LIMB_IDS)

/atom/movable/screen/alert/shake_off
	name = "Covered in Liquid"
	desc = "You're covered in liquid. If your species and instincts allow it, click this to shake it off."
	icon = 'icons/hud/screen_alert.dmi'
	icon_state = "shower_regen_catgirl"
	clickable_glow = TRUE

/atom/movable/screen/alert/shake_off/Click()
	. = ..()
	if(!.)
		return FALSE

	var/mob/living/carbon/human/human_owner = owner
	if(!istype(human_owner) || !is_mammal_species(human_owner) || !HAS_TRAIT(human_owner, TRAIT_WET_DOG_SHAKE))
		to_chat(owner, span_warning("You can't shake this off."))
		return FALSE
	if(!human_owner.can_resist())
		return FALSE
	if(!(human_owner.mobility_flags & MOBILITY_MOVE))
		return FALSE
	if(HAS_TRAIT(human_owner, TRAIT_FLOORED))
		return FALSE

	human_owner.changeNext_move(CLICK_CD_RESIST)
	return human_owner.mammal_shake_off()

/// Shakes off liquid coating, dumping the tracked liquid (or water, if untracked) as a puddle underfoot and lightly splashing nearby mobs.
/mob/living/carbon/human/proc/mammal_shake_off()
	if(!is_mammal_species(src) || !HAS_TRAIT(src, TRAIT_WET_DOG_SHAKE))
		return FALSE
	if(next_shake_off > world.time)
		return FALSE

	var/datum/status_effect/coated_in_liquid/coating = has_status_effect(/datum/status_effect/coated_in_liquid)
	if(!coating)
		return FALSE

	next_shake_off = world.time + SHAKE_OFF_COOLDOWN

	var/turf/our_turf = get_turf(src)
	var/removed_stacks = coating.stacks * SHAKE_OFF_REMOVAL_FRACTION
	var/puddle_volume = max(removed_stacks * SHAKE_OFF_VOLUME_PER_STACK, 10)
	var/datum/reagents/puddle = new(puddle_volume)

	if(LAZYLEN(coating.soaked_reagents))
		for(var/reagent_type in coating.soaked_reagents)
			puddle.add_reagent(reagent_type, coating.soaked_reagents[reagent_type] * SHAKE_OFF_REMOVAL_FRACTION)
	else
		puddle.add_reagent(/datum/reagent/water, puddle_volume)

	our_turf.add_liquid_from_reagents(puddle)
	qdel(puddle)

	manual_emote("shakes off, sending liquid flying everywhere!")
	playsound(our_turf, 'modular_zubbers/sound/misc/dogshake.ogg', 50, TRUE)

	animate(src, pixel_w = 2, time = 0.05 SECONDS, flags = ANIMATION_RELATIVE|ANIMATION_PARALLEL)
	animate(pixel_w = -4, time = 0.05 SECONDS, flags = ANIMATION_RELATIVE)
	animate(pixel_w = 4, time = 0.05 SECONDS, flags = ANIMATION_RELATIVE)
	animate(pixel_w = -4, time = 0.05 SECONDS, flags = ANIMATION_RELATIVE)
	animate(pixel_w = 4, time = 0.05 SECONDS, flags = ANIMATION_RELATIVE)
	animate(pixel_w = -2, time = 0.05 SECONDS, flags = ANIMATION_RELATIVE)

	var/list/splashed_reagents = LAZYLEN(coating.soaked_reagents) ? coating.soaked_reagents : list(/datum/reagent/water = SHAKE_OFF_SPLASH_VOLUME)
	for(var/mob/living/nearby_mob in (range(SHAKE_OFF_SPLASH_RADIUS, our_turf) - src))
		for(var/reagent_type in splashed_reagents)
			nearby_mob.get_coated_in_liquid(reagent_type, SHAKE_OFF_SPLASH_VOLUME / length(splashed_reagents))
		to_chat(nearby_mob, span_warning("You get splashed by [src]'s shake!"))

	// A shake only gets rid of most of the coating, not all of it, so a heavy coating takes a couple of shakes to fully clear.
	coating.stacks -= removed_stacks
	if(LAZYLEN(coating.soaked_reagents))
		for(var/reagent_type in coating.soaked_reagents)
			coating.soaked_reagents[reagent_type] *= (1 - SHAKE_OFF_REMOVAL_FRACTION)
	if(coating.stacks <= 0.5)
		remove_status_effect(/datum/status_effect/coated_in_liquid)

	// Only actually wet mobs (water, rain, etc) get dried off by a shake, since wet_stacks is separately fire-relevant, unrelated coatings like fuel must not touch it.
	if(HAS_TRAIT(src, TRAIT_IS_WET))
		set_wet_stacks(0)
	return TRUE

#undef SHAKE_OFF_SPLASH_RADIUS
#undef SHAKE_OFF_COOLDOWN
#undef SHAKE_OFF_VOLUME_PER_STACK
#undef SHAKE_OFF_SPLASH_VOLUME
#undef SHAKE_OFF_REMOVAL_FRACTION
