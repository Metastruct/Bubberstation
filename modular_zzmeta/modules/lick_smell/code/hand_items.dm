/// Shared base for lick/smell hand-items: targets any atom, resolves reagent-based taste
/// text, and falls back to a human target's DNA-feature flavor text when nothing else applies.
/obj/item/hand_item/tongue
	inhand_icon_state = "nothing"
	/// "taste" or "smell", the dna.features[] key to fall back to for human targets
	var/dna_feature_key
	/// Detection threshold percent passed to generate_taste_message(); lower catches fainter flavors.
	var/detection_threshold = 15

/obj/item/hand_item/tongue/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	var/block_reason = get_use_block_reason(user)
	if(block_reason)
		to_chat(user, span_warning(block_reason))
		return ITEM_INTERACT_SUCCESS

	do_taste(interacting_with, user)
	return ITEM_INTERACT_SUCCESS

/// Returns a rejection message if the action can't be used right now, else null.
/obj/item/hand_item/tongue/proc/get_use_block_reason(mob/living/user)
	return

/// Core dispatcher: works out taste text, fires messages, sends signals.
/obj/item/hand_item/tongue/proc/do_taste(atom/target, mob/living/user)
	var/taste_text = get_taste_text(target, user)
	send_messages(target, user, taste_text)
	var/staleness_note = get_staleness_note(target)
	if(staleness_note)
		to_chat(user, span_notice(staleness_note))
	SEND_SIGNAL(user, get_action_signal(), target)
	if(isliving(target) && target != user)
		SEND_SIGNAL(target, get_target_signal(), user)

/// Returns a note about `target` going bad, for food that's mid-decomposition (stink lines,
/// visibly rotting), or null if it's fresh or has no decomposition component at all (most
/// non-food atoms, mobs, and preserved food never do).
/obj/item/hand_item/tongue/proc/get_staleness_note(atom/target)
	var/datum/component/decomposition/decomp = target.GetComponent(/datum/component/decomposition)
	if(!decomp?.original_time)
		return
	switch(decomp.get_time() / decomp.original_time)
		if(0.5 to 0.75)
			return "It's a bit stale."
		if(0.25 to 0.5)
			return "It's pretty gross."
		if(0 to 0.25)
			return "It's barely edible at this point."
	return

/// Works out what `target` tastes/smells like from `user`'s perspective.
/// A null return means "no taste data available at all" (as opposed to a real but bland result).
/obj/item/hand_item/tongue/proc/get_taste_text(atom/target, mob/living/user)
	if(isliving(target))
		return get_living_taste_text(target, user)

	var/datum/reagents/source_reagents = get_reagents_source(target)
	var/taste_text
	if(source_reagents?.total_volume)
		taste_text = source_reagents.generate_taste_message(user, get_detection_threshold(user))
	if(isturf(target))
		qdel(source_reagents)
	if(taste_text)
		return taste_text
	if(length(target.custom_materials))
		return target.get_material_english_list(target.custom_materials)
	return

/obj/item/hand_item/tongue/proc/get_living_taste_text(mob/living/target, mob/living/user)
	var/datum/reagents/residue_reagents = get_reagents_source(target)
	if(residue_reagents?.total_volume)
		return residue_reagents.generate_taste_message(user, get_detection_threshold(user))

	var/datum/reagents/coating_preview = get_coating_preview(target)
	if(coating_preview)
		var/coating_text
		if(coating_preview.total_volume)
			coating_text = coating_preview.generate_taste_message(user, get_detection_threshold(user))
		qdel(coating_preview)
		if(coating_text)
			return coating_text

	if(!ishuman(target))
		return
	var/mob/living/carbon/human/human_target = target
	var/list/covering = get_zone_covering_items(human_target, user.zone_selected)
	if(covering)
		return get_covering_taste_text(covering, user)
	return human_target.dna?.features[dna_feature_key]

/// Returns the clothing items physically covering `zone` on `target`, or null if that zone
/// is bare skin.
/obj/item/hand_item/tongue/proc/get_zone_covering_items(mob/living/carbon/human/target, zone)
	var/obj/item/bodypart/target_part = target.get_bodypart(check_zone(zone))
	if(!target_part)
		return null
	var/list/covering = target.get_clothing_on_part(target_part)
	return length(covering) ? covering : null

/// Works out taste/smell text from whatever's covering a covered body zone: the first
/// covering item with real reagents, falling back to a material-based description, in case
/// nothing among them has usable reagents.
/obj/item/hand_item/tongue/proc/get_covering_taste_text(list/covering_items, mob/living/user)
	for(var/obj/item/covering as anything in covering_items)
		if(covering.reagents?.total_volume)
			return covering.reagents.generate_taste_message(user, get_detection_threshold(user))
	for(var/obj/item/covering as anything in covering_items)
		if(length(covering.custom_materials))
			return covering.get_material_english_list(covering.custom_materials)
	return

/// Builds a disposable reagents preview from a mob's coated_in_liquid status effect (rain,
/// showers, splashes, ...), or null if they're dry or it has no reagent identity recorded.
/obj/item/hand_item/tongue/proc/get_coating_preview(mob/living/target)
	var/datum/status_effect/coated_in_liquid/coating = target.has_status_effect(/datum/status_effect/coated_in_liquid)
	if(!length(coating?.soaked_reagents))
		return null
	var/datum/reagents/preview = new /datum/reagents(1000)
	for(var/reagent_type in coating.soaked_reagents)
		preview.add_reagent(reagent_type, coating.soaked_reagents[reagent_type], no_react = TRUE)
	return preview

/// Resolves target's reagents: face-decal residue for mobs (never their own internal
/// reagents, to avoid revealing hidden chemistry), decal shortcuts materialized via
/// lazy_init_reagents(), or the atom's own reagents otherwise.
/obj/item/hand_item/tongue/proc/get_reagents_source(atom/target)
	if(isliving(target))
		var/mob/living/living_target = target
		var/datum/component/face_decal/splat/residue = living_target.GetComponent(/datum/component/face_decal/splat)
		return residue?.tasted_reagents
	if(istype(target, /obj/effect/decal/cleanable))
		var/obj/effect/decal/cleanable/cleanable_target = target
		return cleanable_target.lazy_init_reagents()
	if(isturf(target))
		var/turf/turf_target = target
		return turf_target.liquids?.simulate_reagents_threshold(0)
	if(is_sealed_container(target))
		return null
	return target.reagents

/// True for containers that start sealed (soda cans, tinned food, capped bottles). Solid
/// food never sets these flags, so it stays tasteable regardless.
/obj/item/hand_item/tongue/proc/is_sealed_container(atom/target)
	if(!istype(target, /obj/item/reagent_containers) && !istype(target, /obj/item/food/canned))
		return FALSE
	return !target.is_open_container()

/// The detection_threshold_percent to use for this user; overridable so traits/quirks can sharpen it.
/obj/item/hand_item/tongue/proc/get_detection_threshold(mob/living/user)
	return detection_threshold

/obj/item/hand_item/tongue/proc/get_action_signal()
	CRASH("get_action_signal() not implemented")

/obj/item/hand_item/tongue/proc/get_target_signal()
	CRASH("get_target_signal() not implemented")

/// Handles the visible_message/to_chat triad. Overridden per subtype.
/obj/item/hand_item/tongue/proc/send_messages(atom/target, mob/living/user, taste_text)
	return


/obj/item/hand_item/tongue/licker
	name = "tongue"
	desc = "For up-close-and-personal tasting."
	icon = 'icons/obj/medical/organs/organs.dmi'
	icon_state = "tongue"
	dna_feature_key = "taste"
	/// How much of the target's reagents actually enter the licker's body per lick, same as a small bite.
	var/lick_transfer_amount = 1

/// A rough tongue (cat, dog, ...) laps up more per lick, checked via the tongue organ itself
/// so it also covers species that have one natively (e.g. Tajaran).
/obj/item/hand_item/tongue/licker/proc/get_transfer_amount(mob/living/user)
	if(iscarbon(user))
		var/mob/living/carbon/carbon_user = user
		var/obj/item/organ/tongue/user_tongue = carbon_user.get_organ_slot(ORGAN_SLOT_TONGUE)
		if(istype(user_tongue, /obj/item/organ/tongue/cat) || istype(user_tongue, /obj/item/organ/tongue/dog))
			return lick_transfer_amount * 2
	return lick_transfer_amount

/obj/item/hand_item/tongue/licker/do_taste(atom/target, mob/living/user)
	. = ..()
	check_ant_bite(target, user)
	check_lamp_burn(target, user)
	check_mousetrap_bite(target, user)
	consume_licked_reagents(target, user)

/obj/item/hand_item/tongue/licker/proc/check_mousetrap_bite(atom/target, mob/living/user)
	if(!istype(target, /obj/item/assembly/mousetrap))
		return
	var/obj/item/assembly/mousetrap/trap = target
	if(!trap.armed)
		return
	trap.armed = FALSE
	trap.update_appearance()
	playsound(trap, 'sound/effects/snap.ogg', 50, TRUE)
	trap.pulse()

	user.visible_message(
		span_danger("[user] recoils as [trap] snaps shut on [user.p_their()] tongue!"),
		span_userdanger("[trap] snaps shut on your tongue!"),
	)
	user.apply_damage(3, BRUTE, BODY_ZONE_HEAD, wound_bonus = CANT_WOUND, attacking_item = trap)
	user.apply_status_effect(/datum/status_effect/speech/slurring/generic, 20 SECONDS)

/// Licking a lit light fixture burns your tongue. Reimplemented instead of calling
/// /obj/machinery/light/attack_hand_secondary() directly, since that proc also pops the bulb
/// out into the caller's hand.
/obj/item/hand_item/tongue/licker/proc/check_lamp_burn(atom/target, mob/living/user)
	if(!istype(target, /obj/machinery/light))
		return
	var/obj/machinery/light/lamp = target
	if(!lamp.on || HAS_TRAIT(user, TRAIT_RESISTHEAT))
		return

	user.visible_message(
		span_danger("[user] recoils, burning [user.p_their()] tongue on [target]!"),
		span_userdanger("You burn your tongue on [target]!"),
	)
	user.apply_damage(5, BURN, BODY_ZONE_HEAD, wound_bonus = CANT_WOUND, attacking_item = target)

/// Space ants bite back: licking a pile of them hurts, mirroring the leg damage anyone who
/// steps in them takes from /datum/component/caltrop, scaled off reagent volume the same way.
/obj/item/hand_item/tongue/licker/proc/check_ant_bite(atom/target, mob/living/user)
	var/datum/reagents/source_reagents = get_reagents_source(target)
	if(!source_reagents)
		return
	var/ant_amount = source_reagents.get_reagent_amount(/datum/reagent/ants) + source_reagents.get_reagent_amount(/datum/reagent/ants/fire)
	if(isturf(target))
		qdel(source_reagents)
	if(!ant_amount)
		return

	var/max_damage = min(10, round(ant_amount * 0.1, 0.1))
	user.visible_message(
		span_danger("[user] recoils as the ants bite [user.p_their()] tongue!"),
		span_userdanger("The ants bite your tongue!"),
	)
	user.apply_damage(rand(1, max_damage), BRUTE, BODY_ZONE_HEAD, wound_bonus = CANT_WOUND, attacking_item = target)

/// Transfers (not just previews) a bit of the target's reagents into the licker, like a small
/// bite. Enough licks empty the source entirely, cleaning up any pie residue or floor smudge
/// it came from too.
/obj/item/hand_item/tongue/licker/proc/consume_licked_reagents(atom/target, mob/living/user)
	if(isturf(target))
		var/turf/turf_target = target
		if(!turf_target.liquids?.total_reagents)
			return
		var/datum/reagents/drained = turf_target.liquids.take_reagents_flat(get_transfer_amount(user))
		drained.trans_to(user, drained.total_volume, methods = INGEST)
		qdel(drained)
		return

	var/datum/reagents/source_reagents = get_reagents_source(target)
	if(!source_reagents?.total_volume)
		return

	source_reagents.trans_to(user, get_transfer_amount(user), methods = INGEST)
	if(source_reagents.total_volume > 0)
		return

	if(isliving(target))
		var/mob/living/living_target = target
		qdel(living_target.GetComponent(/datum/component/face_decal/splat))
	else if(istype(target, /obj/effect/decal/cleanable))
		qdel(target)

/obj/item/hand_item/tongue/licker/get_use_block_reason(mob/living/user)
	if(!iscarbon(user))
		return
	var/mob/living/carbon/carbon_user = user
	if(HAS_TRAIT(carbon_user, TRAIT_AGEUSIA))
		return "You can't taste anything!"
	if(!carbon_user.get_organ_slot(ORGAN_SLOT_TONGUE))
		return "You don't have a tongue!"
	if(carbon_user.is_mouth_covered())
		return "Your mouth is covered!"

/obj/item/hand_item/tongue/licker/get_action_signal()
	return COMSIG_LIVING_LICK_ATOM

/obj/item/hand_item/tongue/licker/get_target_signal()
	return COMSIG_LIVING_LICKED

/obj/item/hand_item/tongue/licker/send_messages(atom/target, mob/living/user, taste_text)
	var/zone_text = get_zone_flavor(target, user)

	if(target == user)
		if(isnull(taste_text))
			to_chat(user, span_notice("You lick yourself[zone_text], but taste nothing of note."))
		else
			to_chat(user, span_notice("You lick yourself[zone_text]. You taste like [taste_text]."))
		return

	if(isnull(taste_text))
		user.visible_message(
			span_notice("[user] licks [target][zone_text]."),
			span_notice("You lick [target][zone_text], but taste nothing of note."),
			span_hear("You hear a wet noise."),
			ignored_mobs = isliving(target) ? target : null,
		)
		if(isliving(target))
			to_chat(target, span_notice("[user] licks you[zone_text]."))
		return

	user.visible_message(
		span_notice("[user] licks [target][zone_text]."),
		span_notice("You lick [target][zone_text]. [target] tastes like [taste_text]."),
		span_hear("You hear a wet noise."),
		ignored_mobs = isliving(target) ? target : null,
	)
	if(isliving(target))
		to_chat(target, span_notice("[user] licks you[zone_text]!"))

/// Returns a body-zone-flavored suffix like " on the face" for mob targets, "" otherwise.
/obj/item/hand_item/tongue/licker/proc/get_zone_flavor(atom/target, mob/living/user)
	if(!isliving(target))
		return ""
	switch(user.zone_selected)
		if(BODY_ZONE_HEAD, BODY_ZONE_PRECISE_MOUTH)
			return " on the face"
		if(BODY_ZONE_PRECISE_L_HAND, BODY_ZONE_PRECISE_R_HAND)
			return " on the hand"
		if(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM)
			return " on the arm"
		if(BODY_ZONE_CHEST)
			return " on the chest"
		if(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
			return " on the leg"
		if(BODY_ZONE_PRECISE_L_FOOT, BODY_ZONE_PRECISE_R_FOOT)
			return " on the foot"
		else
			return ""


/obj/item/hand_item/tongue/sniffer
	name = "nose"
	desc = "For catching a whiff."
	icon = 'modular_zzmeta/modules/lick_smell/icons/items.dmi'
	icon_state = "nose"
	dna_feature_key = "smell"
	// Matches get_sniff_examine()'s threshold; smell picks up fainter scents than direct tasting does.
	detection_threshold = 10

/obj/item/hand_item/tongue/sniffer/get_use_block_reason(mob/living/user)
	if(HAS_TRAIT(user, TRAIT_ANOSMIA))
		return "You can't smell anything!"
	if(!iscarbon(user))
		return
	var/mob/living/carbon/carbon_user = user
	if(!carbon_user.get_bodypart(BODY_ZONE_HEAD))
		return "You don't have a nose to smell with!"
	if(carbon_user.is_mouth_covered())
		return "Your face is covered, you can't get a good whiff!"

/// Keen Nose picks up fainter scents than the baseline threshold allows.
/obj/item/hand_item/tongue/sniffer/get_detection_threshold(mob/living/user)
	if(HAS_TRAIT(user, TRAIT_KEEN_NOSE))
		return detection_threshold * 0.5
	return detection_threshold

/obj/item/hand_item/tongue/sniffer/get_action_signal()
	return COMSIG_LIVING_SMELL_ATOM

/obj/item/hand_item/tongue/sniffer/get_target_signal()
	return COMSIG_LIVING_SMELLED

/obj/item/hand_item/tongue/sniffer/send_messages(atom/target, mob/living/user, taste_text)
	if(target == user)
		if(isnull(taste_text))
			to_chat(user, span_notice("You take a whiff of yourself, but smell nothing of note."))
		else
			to_chat(user, span_notice("You take a whiff of yourself. You smell like [taste_text]."))
		return

	if(isnull(taste_text))
		to_chat(user, span_notice("[target] doesn't seem to have a smell."))
		return

	user.visible_message(
		span_notice("[user] leans in and sniffs [target]."),
		span_notice("You sniff [target]. [target] smells like [taste_text]."),
		span_hear("You hear sniffing."),
		ignored_mobs = isliving(target) ? target : null,
	)
	if(isliving(target))
		to_chat(target, span_notice("[user] leans in and sniffs you."))
