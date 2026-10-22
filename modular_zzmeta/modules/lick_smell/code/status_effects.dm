/datum/status_effect/sensory
	id = STATUS_EFFECT_ID_ABSTRACT
	duration = STATUS_EFFECT_PERMANENT
	tick_interval = STATUS_EFFECT_NO_TICK
	status_type = STATUS_EFFECT_UNIQUE
	alert_type = /atom/movable/screen/alert/status_effect/sensory
	/// "taste" or "smell", the dna.features[] key to fall back to for human targets
	var/dna_feature_key
	/// Detection threshold percent passed to generate_taste_message(); lower catches fainter flavors.
	var/detection_threshold = 15
	/// The other sensory emote, removed when this one is applied so click-intercepts don't stack.
	var/datum/status_effect/sensory/conflicting_type
	/// Set TRUE at the end of a successful on_apply so on_remove doesn't retract a failed apply.
	var/ready = FALSE

/atom/movable/screen/alert/status_effect/sensory
	name = "Sensing"
	desc = "Click something nearby to sense it. Click here to stop."
	clickable_glow = TRUE

/atom/movable/screen/alert/status_effect/sensory/Click(location, control, params)
	. = ..()
	if(!.)
		return
	qdel(attached_effect)

/datum/status_effect/sensory/on_apply()
	var/block_reason = get_use_block_reason()
	if(block_reason)
		to_chat(owner, span_warning(block_reason))
		return FALSE
	if(conflicting_type)
		owner.remove_status_effect(conflicting_type)
	RegisterSignal(owner, COMSIG_MOB_CLICKON, PROC_REF(on_clickon))
	show_ready_message()
	ready = TRUE
	return TRUE

/datum/status_effect/sensory/on_remove()
	UnregisterSignal(owner, COMSIG_MOB_CLICKON)
	if(ready)
		show_retract_message()
	return ..()

/datum/status_effect/sensory/proc/show_ready_message()
	return

/datum/status_effect/sensory/proc/show_retract_message()
	return

/// Returns a rejection message if the action can't be used right now, else null.
/datum/status_effect/sensory/proc/get_use_block_reason()
	return

/// Left-clicks on reachable atoms become a lick/smell instead of the usual interaction.
/datum/status_effect/sensory/proc/on_clickon(mob/living/source, atom/target, list/modifiers)
	SIGNAL_HANDLER
	if(should_ignore_click(target, modifiers))
		return
	INVOKE_ASYNC(src, PROC_REF(try_sense), target)
	return COMSIG_MOB_CANCEL_CLICKON

/datum/status_effect/sensory/proc/should_ignore_click(atom/target, list/modifiers)
	if(LAZYACCESS(modifiers, SHIFT_CLICK) || LAZYACCESS(modifiers, CTRL_CLICK) || LAZYACCESS(modifiers, ALT_CLICK) || LAZYACCESS(modifiers, MIDDLE_CLICK) || LAZYACCESS(modifiers, RIGHT_CLICK) || LAZYACCESS(modifiers, BUTTON4) || LAZYACCESS(modifiers, BUTTON5))
		return TRUE
	if(istype(target, /atom/movable/screen))
		return TRUE
	if(!target.IsReachableBy(owner))
		return TRUE
	return FALSE

/datum/status_effect/sensory/proc/try_sense(atom/target)
	if(QDELETED(src) || QDELETED(owner) || QDELETED(target))
		return
	if(INCAPACITATED_IGNORING(owner, INCAPABLE_RESTRAINTS|INCAPABLE_STASIS))
		return
	if(owner.next_move > world.time)
		return
	if(!target.IsReachableBy(owner))
		return
	var/block_reason = get_use_block_reason()
	if(block_reason)
		to_chat(owner, span_warning(block_reason))
		return
	owner.face_atom(target)
	owner.changeNext_move(CLICK_CD_MELEE)
	do_taste(target)

/datum/status_effect/sensory/proc/do_taste(atom/target)
	var/taste_text = get_taste_text(target)
	send_messages(target, taste_text)
	var/staleness_note = get_staleness_note(target)
	if(staleness_note)
		to_chat(owner, span_notice(staleness_note))
	SEND_SIGNAL(owner, get_action_signal(), target)
	if(isliving(target) && target != owner)
		SEND_SIGNAL(target, get_target_signal(), owner)

/datum/status_effect/sensory/proc/get_staleness_note(atom/target)
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

/// Works out what `target` tastes/smells like from the owner's perspective.
/datum/status_effect/sensory/proc/get_taste_text(atom/target)
	if(isliving(target))
		return get_living_taste_text(target)

	var/datum/reagents/source_reagents = get_reagents_source(target)
	var/taste_text
	if(source_reagents?.total_volume)
		taste_text = source_reagents.generate_taste_message(owner, get_detection_threshold())
	if(isturf(target))
		qdel(source_reagents)
	var/flavor_override = get_flavor_override(target)
	if(taste_text && flavor_override)
		return "[taste_text]. It also [get_sense_verb()] like [flavor_override]"
	if(taste_text)
		return taste_text
	if(flavor_override)
		return flavor_override
	if(length(target.custom_materials))
		return target.get_material_english_list(target.custom_materials)
	return

/datum/status_effect/sensory/proc/get_flavor_override(atom/target)
	return

/// "tastes" or "smells", used when stacking reagent text with a flavour override.
/datum/status_effect/sensory/proc/get_sense_verb()
	return "tastes"

/datum/status_effect/sensory/proc/get_living_taste_text(mob/living/target)
	var/datum/reagents/residue_reagents = get_reagents_source(target)
	if(residue_reagents?.total_volume)
		return residue_reagents.generate_taste_message(owner, get_detection_threshold())

	var/datum/reagents/coating_preview = get_coating_preview(target)
	if(coating_preview)
		var/coating_text
		if(coating_preview.total_volume)
			coating_text = coating_preview.generate_taste_message(owner, get_detection_threshold())
		qdel(coating_preview)
		if(coating_text)
			return coating_text

	if(!ishuman(target))
		return
	var/mob/living/carbon/human/human_target = target
	var/list/covering = get_zone_covering_items(human_target, owner.zone_selected)
	if(covering)
		return get_covering_taste_text(covering)
	if(owner.zone_selected == BODY_ZONE_PRECISE_MOUTH)
		return get_mouth_taste_text(human_target)
	return human_target.dna?.features[dna_feature_key]

/datum/status_effect/sensory/proc/get_mouth_taste_text(mob/living/carbon/human/human_target)
	var/datum/reagents/mouth_reagents = human_target.reagents
	if(!mouth_reagents?.total_volume)
		return null
	return mouth_reagents.generate_taste_message(owner, get_detection_threshold())

/datum/status_effect/sensory/proc/get_zone_covering_items(mob/living/carbon/human/target, zone)
	var/obj/item/bodypart/target_part = target.get_bodypart(check_zone(zone))
	if(!target_part)
		return null
	var/list/covering = target.get_clothing_on_part(target_part)
	return length(covering) ? covering : null

/datum/status_effect/sensory/proc/get_covering_taste_text(list/covering_items)
	for(var/obj/item/covering as anything in covering_items)
		if(covering.reagents?.total_volume)
			return covering.reagents.generate_taste_message(owner, get_detection_threshold())
	for(var/obj/item/covering as anything in covering_items)
		if(length(covering.custom_materials))
			return covering.get_material_english_list(covering.custom_materials)
	return

/datum/status_effect/sensory/proc/get_coating_preview(mob/living/target)
	var/datum/status_effect/coated_in_liquid/coating = target.has_status_effect(/datum/status_effect/coated_in_liquid)
	if(!length(coating?.soaked_reagents))
		return null
	var/datum/reagents/preview = new /datum/reagents(1000)
	for(var/reagent_type in coating.soaked_reagents)
		preview.add_reagent(reagent_type, coating.soaked_reagents[reagent_type], no_react = TRUE)
	return preview

/datum/status_effect/sensory/proc/get_reagents_source(atom/target)
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

/datum/status_effect/sensory/proc/is_sealed_container(atom/target)
	if(!istype(target, /obj/item/reagent_containers) && !istype(target, /obj/item/food/canned))
		return FALSE
	return !target.is_open_container()

/datum/status_effect/sensory/proc/get_detection_threshold()
	return owner.get_taste_sensitivity()

/datum/status_effect/sensory/proc/get_action_signal()
	CRASH("get_action_signal() not implemented")

/datum/status_effect/sensory/proc/get_target_signal()
	CRASH("get_target_signal() not implemented")

/// Handles the visible_message/to_chat triad. Overridden per subtype.
/datum/status_effect/sensory/proc/send_messages(atom/target, taste_text)
	return


/datum/status_effect/sensory/lick
	id = "lick"
	alert_type = /atom/movable/screen/alert/status_effect/sensory/lick
	dna_feature_key = "taste"
	conflicting_type = /datum/status_effect/sensory/smell
	/// How much of the target's reagents actually enter the licker's body per lick.
	var/lick_transfer_amount = 1
	/// Everything that hurts to lick. See [/datum/lick_hazard] to add a reaction.
	var/static/list/lick_hazards = list(
		new /datum/lick_hazard/electric(),
		new /datum/lick_hazard/supermatter(),
		new /datum/lick_hazard/flame(),
		new /datum/lick_hazard/mousetrap(),
		new /datum/lick_hazard/lamp(),
		new /datum/lick_hazard/ants(),
		new /datum/lick_hazard/gross(),
	)
	/// Letter garbling for trying to talk with your tongue hanging out of your mouth.
	var/static/list/speech_replacements = list(
		new /regex("s+", "g") = "th",
		new /regex("S+", "g") = "Th",
		new /regex("z+", "g") = "th",
		new /regex("Z+", "g") = "Th",
		new /regex("l+", "g") = "w",
		new /regex("L+", "g") = "W",
		new /regex("r+", "g") = "w",
		new /regex("R+", "g") = "W",
	)
	/// The visual tongue overlay shown while this is active.
	var/datum/bodypart_overlay/simple/emote/tongue/tongue_overlay
	/// Speechmod applied for as long as the tongue is out.
	var/datum/component/speechmod/speechmod

/atom/movable/screen/alert/status_effect/sensory/lick
	name = "Tongue Out"
	desc = "Your tongue is hanging out. Click something nearby to lick it. Click here to retract it."
	icon = 'icons/obj/medical/organs/organs.dmi'
	icon_state = "tongue"

/datum/status_effect/sensory/lick/on_apply()
	. = ..()
	if(!.)
		return
	if(ishuman(owner))
		var/mob/living/carbon/human/human_owner = owner
		tongue_overlay = human_owner.give_emote_overlay(/datum/bodypart_overlay/simple/emote/tongue)
	speechmod = owner.AddComponent(/datum/component/speechmod, replacements = speech_replacements, should_modify_speech = CALLBACK(src, PROC_REF(should_modify_speech)))

/datum/status_effect/sensory/lick/on_remove()
	QDEL_NULL(tongue_overlay)
	QDEL_NULL(speechmod)
	return ..()

/datum/status_effect/sensory/lick/get_examine_text()
	return span_notice("[owner.p_They()] [owner.p_have()] [owner.p_their()] tongue sticking out.")

/datum/status_effect/sensory/lick/show_ready_message()
	owner.visible_message(span_notice("[owner] is sticking out [owner.p_their()] tongue."), span_notice("You stick your tongue out, ready to taste something."))

/datum/status_effect/sensory/lick/show_retract_message()
	owner.visible_message("[owner] is retracting [owner.p_their()] tongue.", span_notice("You retract your tongue."))

/// Sign language doesn't need a working tongue.
/datum/status_effect/sensory/lick/proc/should_modify_speech(datum/source, list/speech_args)
	return !HAS_TRAIT(source, TRAIT_SIGN_LANG)

/// A rough tongue (cat, dog, ...) laps up more per lick.
/// so it also covers species that have one natively (e.g. Tajaran).
/datum/status_effect/sensory/lick/proc/get_transfer_amount()
	if(iscarbon(owner))
		var/mob/living/carbon/carbon_owner = owner
		var/obj/item/organ/tongue/user_tongue = carbon_owner.get_organ_slot(ORGAN_SLOT_TONGUE)
		if(istype(user_tongue, /obj/item/organ/tongue/cat) || istype(user_tongue, /obj/item/organ/tongue/dog))
			return lick_transfer_amount * 2
	return lick_transfer_amount

/datum/status_effect/sensory/lick/do_taste(atom/target)
	. = ..()
	for(var/datum/lick_hazard/hazard as anything in lick_hazards)
		hazard.try_apply(target, src)
	consume_licked_reagents(target)

/datum/status_effect/sensory/lick/get_flavor_override(atom/target)
	return target.get_lick_flavor(owner)

/datum/status_effect/sensory/lick/proc/consume_licked_reagents(atom/target)
	if(isturf(target))
		var/turf/turf_target = target
		if(!turf_target.liquids?.total_reagents)
			return
		var/datum/reagents/drained = turf_target.liquids.take_reagents_flat(get_transfer_amount())
		drained.trans_to(owner, drained.total_volume, methods = INGEST)
		qdel(drained)
		return

	var/datum/reagents/source_reagents = get_reagents_source(target)
	if(!source_reagents?.total_volume)
		return

	source_reagents.trans_to(owner, get_transfer_amount(), methods = INGEST)
	if(source_reagents.total_volume > 0)
		return

	if(isliving(target))
		var/mob/living/living_target = target
		qdel(living_target.GetComponent(/datum/component/face_decal/splat))
	else if(istype(target, /obj/effect/decal/cleanable))
		qdel(target)

/datum/status_effect/sensory/lick/get_use_block_reason()
	if(!iscarbon(owner))
		return
	var/mob/living/carbon/carbon_owner = owner
	if(HAS_TRAIT(carbon_owner, TRAIT_AGEUSIA))
		return "You can't taste anything!"
	if(!carbon_owner.get_organ_slot(ORGAN_SLOT_TONGUE))
		return "You don't have a tongue!"
	if(carbon_owner.is_mouth_covered())
		return "Your mouth is covered!"

/datum/status_effect/sensory/lick/get_action_signal()
	return COMSIG_LIVING_LICK_ATOM

/datum/status_effect/sensory/lick/get_target_signal()
	return COMSIG_LIVING_LICKED

/datum/status_effect/sensory/lick/send_messages(atom/target, taste_text)
	var/zone_text = get_zone_flavor(target)

	if(target == owner)
		if(isnull(taste_text))
			to_chat(owner, span_notice("You lick yourself[zone_text], but taste nothing of note."))
		else
			to_chat(owner, span_notice("You lick yourself[zone_text]. You taste like [taste_text]."))
		return

	if(isnull(taste_text))
		owner.visible_message(
			span_notice("[owner] licks [target][zone_text]."),
			span_notice("You lick [target][zone_text], but taste nothing of note."),
			span_hear("You hear a wet noise."),
			ignored_mobs = isliving(target) ? target : null,
		)
		if(isliving(target))
			to_chat(target, span_notice("[owner] licks you[zone_text]."))
		return

	owner.visible_message(
		span_notice("[owner] licks [target][zone_text]."),
		span_notice("You lick [target][zone_text]. [target] tastes like [taste_text]."),
		span_hear("You hear a wet noise."),
		ignored_mobs = isliving(target) ? target : null,
	)
	if(isliving(target))
		to_chat(target, span_notice("[owner] licks you[zone_text]!"))

/// Returns a body-zone-flavored suffix like " on the face" for mob targets, "" otherwise.
/datum/status_effect/sensory/lick/proc/get_zone_flavor(atom/target)
	if(!isliving(target))
		return ""
	switch(owner.zone_selected)
		if(BODY_ZONE_HEAD)
			return " on the head"
		if(BODY_ZONE_PRECISE_EYES, BODY_ZONE_PRECISE_MOUTH)
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


/datum/status_effect/sensory/smell
	id = "smell"
	alert_type = /atom/movable/screen/alert/status_effect/sensory/smell
	dna_feature_key = "smell"
	conflicting_type = /datum/status_effect/sensory/lick
	detection_threshold = 10

/atom/movable/screen/alert/status_effect/sensory/smell
	name = "Sniffing"
	desc = "You're leaning in for a sniff. Click something nearby to smell it. Click here to stop."
	icon = 'modular_zzmeta/modules/lick_smell/icons/items.dmi'
	icon_state = "nose"

/datum/status_effect/sensory/smell/get_examine_text()
	return span_notice("[owner.p_They()] [owner.p_are()] sniffing the air.")

/datum/status_effect/sensory/smell/show_ready_message()
	to_chat(owner, span_notice("You lean in, ready to take a whiff of something."))

/datum/status_effect/sensory/smell/show_retract_message()
	to_chat(owner, span_notice("You stop sniffing around."))

/datum/status_effect/sensory/smell/get_use_block_reason()
	if(HAS_TRAIT(owner, TRAIT_ANOSMIA))
		return "You can't smell anything!"
	if(!iscarbon(owner))
		return
	var/mob/living/carbon/carbon_owner = owner
	if(!carbon_owner.get_bodypart(BODY_ZONE_HEAD))
		return "You don't have a nose to smell with!"
	if(carbon_owner.is_mouth_covered())
		return "Your face is covered, you can't get a good whiff!"

/// Keen Nose picks up fainter scents than the baseline threshold allows.
/datum/status_effect/sensory/smell/get_detection_threshold()
	if(HAS_TRAIT(owner, TRAIT_KEEN_NOSE))
		return detection_threshold * 0.5
	return detection_threshold

/datum/status_effect/sensory/smell/get_flavor_override(atom/target)
	return target.get_smell_flavor(owner)

/datum/status_effect/sensory/smell/get_sense_verb()
	return "smells"

/datum/status_effect/sensory/smell/do_taste(atom/target)
	play_sniff_sound()
	. = ..()
	var/trail_note = get_scent_trail_note(target)
	if(trail_note)
		to_chat(owner, span_notice(trail_note))

/datum/status_effect/sensory/smell/proc/play_sniff_sound()
	if(HAS_TRAIT(owner, TRAIT_MUTE) || HAS_MIND_TRAIT(owner, TRAIT_MIMING))
		return
	var/soundfile
	if(iscarbon(owner))
		soundfile = (owner.gender == MALE) ? 'modular_skyrat/modules/emotes/sound/emotes/male/male_sniff.ogg' : 'modular_skyrat/modules/emotes/sound/emotes/female/female_sniff.ogg'
	if(!soundfile)
		return
	playsound(owner, soundfile, 50, TRUE)

/// Keen noses can follow a blood trail: returns a line describing the strongest nearby scent,
/// or null if there's nothing to follow. Only reacts to floors and blood decals.
/datum/status_effect/sensory/smell/proc/get_scent_trail_note(atom/target)
	if(!HAS_TRAIT(owner, TRAIT_KEEN_NOSE))
		return
	var/sniffing_for_trail = istype(target, /obj/effect/decal/cleanable/blood)
	if(!sniffing_for_trail && !isturf(target))
		return

	var/obj/effect/decal/cleanable/blood/strongest
	for(var/obj/effect/decal/cleanable/blood/trail in range(KEEN_NOSE_TRACK_RANGE, owner))
		if(trail.dried || trail.bloodiness < KEEN_NOSE_MIN_BLOODINESS)
			continue
		if(trail.z != owner.z)
			continue
		if(!strongest || trail.bloodiness > strongest.bloodiness)
			strongest = trail

	if(!strongest)
		return sniffing_for_trail ? "You can't pick up any trail from here." : null

	var/freshness = "faint"
	if(strongest.bloodiness >= BLOOD_AMOUNT_PER_DECAL)
		freshness = "fresh"
	else if(strongest.bloodiness >= BLOOD_AMOUNT_PER_DECAL * 0.5)
		freshness = "recent"

	if(get_turf(strongest) == get_turf(owner))
		return "Your keen nose picks up a [freshness] scent trail, strongest right where you're standing."
	return "Your keen nose picks up a [freshness] scent trail leading [dir2text(get_dir(owner, strongest))]."

/datum/status_effect/sensory/smell/get_action_signal()
	return COMSIG_LIVING_SMELL_ATOM

/datum/status_effect/sensory/smell/get_target_signal()
	return COMSIG_LIVING_SMELLED

/datum/status_effect/sensory/smell/send_messages(atom/target, taste_text)
	if(target == owner)
		if(isnull(taste_text))
			to_chat(owner, span_notice("You take a whiff of yourself, but smell nothing of note."))
		else
			to_chat(owner, span_notice("You take a whiff of yourself. You smell like [taste_text]."))
		return

	if(isnull(taste_text))
		to_chat(owner, span_notice("[target] doesn't seem to have a smell."))
		return

	owner.visible_message(
		span_notice("[owner] leans in and sniffs [target]."),
		span_notice("You sniff [target]. [target] smells like [taste_text]."),
		span_hear("You hear sniffing."),
		ignored_mobs = isliving(target) ? target : null,
	)
	if(isliving(target))
		to_chat(target, span_notice("[owner] leans in and sniffs you."))
