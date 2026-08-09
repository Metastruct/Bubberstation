
GLOBAL_LIST_EMPTY_TYPED(interaction_instances, /datum/interaction)

/datum/interaction
	/// The name to be displayed in the interaction menu for this interaction
	var/name = "broken interaction"
	/// The description of the interacton.
	var/description = "broken"
	/// If it can be done at a distance.
	var/distance_allowed = FALSE
	/// How long (in deciseconds, to match world.time) before this specific interaction can be used again. Defaults
	/// to INTERACTION_COOLDOWN; override to something longer for interactions with strong effects (status effects,
	/// decals) that shouldn't be spammable. Stored in deciseconds, but the JSON field ("cooldown") is in whole seconds.
	var/cooldown = INTERACTION_COOLDOWN
	/// A list of possible messages displayed loaded by the JSON.
	var/list/message = list()
	/// A list of possible messages displayed directly to the USER.
	var/list/user_messages = list()
	/// A list of possible messages displayed directly to the TARGET.
	var/list/target_messages = list()
	/// A list of possible messages displayed privately when this interaction is used on yourself (target ==
	/// user). Replaces user_messages/target_messages in that case, since self-targeting should only send one
	/// private message. Falls back to user_messages if empty.
	var/list/self_messages = list()
	/// What category this interaction will fall under in the menu.
	var/category = INTERACTION_CAT_HIDE
	/// Defines how we interact with ourselves or others.
	var/usage = INTERACTION_OTHER
	/// If it plays a sound, how far does it travel?
	var/sound_range = 1
	/// Stores the sound for later.
	var/sound_cache = null
	/// Is this lewd?
	var/lewd = FALSE
	/// What parts do WE need(IMPORTANT TO GET IT TO THE CORRECT DEFINE, ORGAN SLOT)?
	var/list/user_required_parts = list()
	/// What parts do they need(IMPORTANT TO GET IT TO THE CORRECT DEFINE, ORGAN SLOT)?
	var/list/target_required_parts = list()
	/// The amount of pleasure the target receives from this interaciton.
	var/target_pleasure = 0
	/// The amount of arousal the target receives from this interaction.
	var/target_arousal = 0
	/// The amount of pain the target receives.
	var/target_pain = 0
	/// The amount of pleasure the user receives.
	var/user_pleasure = 0
	/// The amount of arousal the user receives.
	var/user_arousal = 0
	/// The amount of pain the user receives.
	var/user_pain = 0
	/// Units of blood the target loses on use, via /mob/living/proc/bleed(). Unlike pleasure/arousal/pain,
	/// this applies regardless of `lewd`, since it's a combat effect rather than a romance one.
	var/target_bleed = 0
	/// Units of blood the user loses on use. Same notes as `target_bleed`.
	var/user_bleed = 0
	/// If TRUE, interrupts whatever the target is currently typing and forces them to blurt it out (see /mob/living/carbon/human/proc/force_say).
	var/target_force_say = FALSE
	/// Suffixes to blurt out when `target_force_say` triggers. Empty means the default hurt phrases ("AUGH!" etc) are used.
	var/list/target_force_say_phrases = list()
	/// Percent chance (0-100) that `target_force_say` actually triggers when TRUE. Defaults to always.
	var/target_force_say_chance = 100
	/// If TRUE, interrupts whatever the user is currently typing and forces them to blurt it out.
	var/user_force_say = FALSE
	/// Suffixes to blurt out when `user_force_say` triggers. Empty means the default hurt phrases are used.
	var/list/user_force_say_phrases = list()
	/// Percent chance (0-100) that `user_force_say` actually triggers when TRUE. Defaults to always.
	var/user_force_say_chance = 100
	/// Status effects applied to the target on use. Each entry is a list("type" = "/datum/status_effect/path",
	/// "duration" = optional_number_of_seconds, "chance" = optional_percent_0_to_100_defaults_always).
	var/list/target_status_effects = list()
	/// Status effects applied to the user on use. Same format as `target_status_effects`.
	var/list/user_status_effects = list()
	/// Decals spawned on use. Each entry is a list("type" = "/obj/effect/decal/cleanable/path", "spawn_on" = "target" (default) or "user",
	/// "icon_state" = optional_text, "color" = optional_text, "chance" = optional_percent_0_to_100_defaults_always).
	/// Spawned via /turf/proc/spawn_unique_cleanable, so they're mergeable/mopable like any other cleanable decal.
	var/list/decals = list()
	/// Optional per-zone overrides, keyed by BODY_ZONE_* (mob's zone_selected). Each entry is an associative
	/// list that may set any of: "message", "self_messages", "user_messages", "target_messages",
	/// "user_pleasure", "user_arousal", "user_pain", "target_pleasure", "target_arousal", "target_pain",
	/// "target_bleed", "user_bleed", "target_force_say", "target_force_say_phrases", "target_force_say_chance",
	/// "user_force_say", "user_force_say_phrases", "user_force_say_chance", "target_status_effects",
	/// "user_status_effects", "decals", "sound_possible". Any key a zone's entry doesn't set falls back to the
	/// matching base field. A zone can also be suffixed with "_self" (target == user), "_combat" (user has
	/// combat mode on), or "_prone" (target is lying down), e.g. "mouth_self", "mouth_combat", "head_prone".
	/// "_combat" and "_prone" can combine as "_combat_prone"; "_self" always takes priority on its own instead
	/// of combining with them. For interactions with no single natural zone (e.g. a rougher variant of an act
	/// that isn't tied to any particular BODY_ZONE), the same suffixes also work as standalone keys with no
	/// zone prefix ("_self", "_combat", "_prone", "_combat_prone"), applying regardless of what zone happens
	/// to be selected. See get_zone_data() for the exact fallback order.
	var/list/zone_overrides = list()
	/// A list of possible sounds. There's no separate on/off flag; a sound plays whenever this ends up
	/// non-empty after zone_overrides are applied.
	var/list/sound_possible = list()
	/// What requirements does this interaction have? See defines.
	var/list/interaction_requires = list()
	/// What color should the interaction button be?
	var/color = "blue"
	/// What sexuality preference do we display for.
	var/sexuality = ""

/datum/interaction/proc/allow_act(mob/living/carbon/human/user, mob/living/carbon/human/target)
	if(target == user && usage == INTERACTION_OTHER)
		return FALSE
	if(target != user && usage == INTERACTION_SELF)
		return FALSE

	if(user_required_parts.len)
		for(var/thing in user_required_parts)
			var/obj/item/organ/genital/required_part = user.get_organ_slot(thing)
			if(isnull(required_part))
				return FALSE
			if(!required_part.is_exposed())
				return FALSE

	if(target_required_parts.len)
		for(var/thing in target_required_parts)
			var/obj/item/organ/genital/required_part = target.get_organ_slot(thing)
			if(isnull(required_part))
				return FALSE
			if(!required_part.is_exposed())
				return FALSE

	for(var/requirement in interaction_requires)
		switch(requirement)
			if(INTERACTION_REQUIRE_SELF_HAND)
				if(!user.get_active_hand())
					return FALSE
			if(INTERACTION_REQUIRE_TARGET_HAND)
				if(!target.get_active_hand())
					return FALSE
			if(INTERACTION_REQUIRE_USER_HORNS)
				if(!user.get_organ_slot(ORGAN_SLOT_EXTERNAL_HORNS))
					return FALSE
			if(INTERACTION_REQUIRE_USER_TAIL)
				if(!user.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAIL))
					return FALSE
			else
				CRASH("Unimplemented interaction requirement '[requirement]'")
	return TRUE

/**
 * Returns `zone`'s override sub-list from `zone_overrides`, or null if it has none. `combat_mode` and
 * `prone` (target lying down) each optionally suffix the zone key with "_combat"/"_prone" (e.g.
 * "mouth_combat", "head_prone"). `is_self` (target == user) is checked first, above everything else,
 * since self-targeting is a fundamentally different framing than a combat/prone intensity change.
 * Checked most specific first:
 *   1. "[zone]_self"
 *   2. "_self" (self-targeting, zone-independent)
 *   3. "[zone]_combat_prone" (both modifiers, tied to this specific zone)
 *   4. "[zone]_combat"
 *   5. "[zone]_prone"
 *   6. "_combat_prone" (both modifiers, zone-independent, e.g. "Ass fuck" using "_combat" for a rougher
 *      variant regardless of what zone happens to be selected)
 *   7. "_combat"
 *   8. "_prone"
 *   9. the plain "[zone]" entry
 * Only defined keys need to exist. Anything not defined just falls through to the next, less specific
 * match, and ultimately to the interaction's base fields if nothing at all is defined.
 */
/datum/interaction/proc/get_zone_data(zone, combat_mode, prone, is_self)
	if(!zone_overrides?.len)
		return null
	if(is_self)
		var/list/zone_self_data = zone_overrides["[zone]_self"]
		if(islist(zone_self_data))
			return zone_self_data
		var/list/global_self_data = zone_overrides["_self"]
		if(islist(global_self_data))
			return global_self_data
	if(combat_mode && prone)
		var/list/combat_prone_data = zone_overrides["[zone]_combat_prone"]
		if(islist(combat_prone_data))
			return combat_prone_data
	if(combat_mode)
		var/list/combat_data = zone_overrides["[zone]_combat"]
		if(islist(combat_data))
			return combat_data
	if(prone)
		var/list/prone_data = zone_overrides["[zone]_prone"]
		if(islist(prone_data))
			return prone_data
	if(combat_mode && prone)
		var/list/global_combat_prone_data = zone_overrides["_combat_prone"]
		if(islist(global_combat_prone_data))
			return global_combat_prone_data
	if(combat_mode)
		var/list/global_combat_data = zone_overrides["_combat"]
		if(islist(global_combat_data))
			return global_combat_data
	if(prone)
		var/list/global_prone_data = zone_overrides["_prone"]
		if(islist(global_prone_data))
			return global_prone_data
	var/list/zone_data = zone_overrides[zone]
	return islist(zone_data) ? zone_data : null

/**
 * Returns the list to actually use for `key` (e.g. "message", "target_status_effects"): `zone`'s
 * override if it sets a non-empty list for `key`, otherwise `fallback`.
 */
/datum/interaction/proc/get_zone_pool(zone, combat_mode, prone, is_self, key, list/fallback)
	var/list/zone_data = get_zone_data(zone, combat_mode, prone, is_self)
	var/list/value = zone_data?[key]
	if(islist(value) && length(value))
		return value
	return fallback

/**
 * Returns the scalar value to actually use for `key` (e.g. "target_pain", "target_force_say"): `zone`'s
 * override if it sets one, otherwise `fallback`.
 */
/datum/interaction/proc/get_zone_value(zone, combat_mode, prone, is_self, key, fallback)
	var/list/zone_data = get_zone_data(zone, combat_mode, prone, is_self)
	var/value = zone_data?[key]
	if(!isnull(value))
		return value
	return fallback

/**
 * Computes small feedback flags for the interactions menu UI, reflecting exactly what this interaction
 * will do right now given `user`'s current zone selection/combat mode and `target`'s posture. Uses the
 * same zone/combat_mode/prone/is_self resolution act() itself uses, so the UI can show "this plays a
 * sound" or "this is a combat/prone-specialized variant right now" instead of showing nothing.
 */
/datum/interaction/proc/get_ui_feedback(mob/living/carbon/human/user, mob/living/carbon/human/target)
	var/zone = user.zone_selected
	var/combat_mode = user.combat_mode
	var/prone = target.body_position == LYING_DOWN
	var/is_self = (target == user)
	var/list/feedback = list()
	feedback["specialized"] = !isnull(get_zone_data(zone, combat_mode, prone, is_self))
	feedback["sound"] = length(get_zone_pool(zone, combat_mode, prone, is_self, "sound_possible", sound_possible)) > 0
	feedback["status_effect"] = length(get_zone_pool(zone, combat_mode, prone, is_self, "target_status_effects", target_status_effects)) > 0 \
		|| length(get_zone_pool(zone, combat_mode, prone, is_self, "user_status_effects", user_status_effects)) > 0
	feedback["decal"] = length(get_zone_pool(zone, combat_mode, prone, is_self, "decals", decals)) > 0
	feedback["force_say"] = get_zone_value(zone, combat_mode, prone, is_self, "target_force_say", target_force_say) \
		|| get_zone_value(zone, combat_mode, prone, is_self, "user_force_say", user_force_say)
	return feedback

/**
 * Applies a list of status effect entries (list("type" = typepath text, "duration" = optional number of
 * seconds, "chance" = optional percent 0-100, "tether" = optional bool)) to `recipient`. Invalid/non
 * status effect types are ignored and logged.
 *
 * If "tether" is set, the effect is kept alive past its normal duration for as long as `other_party`
 * stays adjacent to `recipient` (e.g. Cover's blindness/muffle lasting until the coverer steps back),
 * and is stripped early the moment they separate. "duration" still applies as a safety cap in case the
 * tether never breaks on its own.
 */
/datum/interaction/proc/apply_zone_status_effects(list/effects, mob/living/carbon/human/recipient, mob/living/carbon/human/other_party)
	for(var/list/effect_data in effects)
		if(!islist(effect_data))
			continue
		var/chance = effect_data["chance"]
		if(isnum(chance) && !prob(chance))
			continue
		var/effect_type = effect_data["type"]
		if(!istext(effect_type))
			continue
		var/effect_path = text2path(effect_type)
		if(!ispath(effect_path, /datum/status_effect))
			message_admins("Interaction '[name]' referenced an invalid status effect type '[effect_type]'.")
			continue
		var/duration = effect_data["duration"]
		var/datum/status_effect/applied_effect
		if(isnum(duration))
			applied_effect = recipient.apply_status_effect(effect_path, duration SECONDS)
		else
			applied_effect = recipient.apply_status_effect(effect_path)
		if(effect_data["tether"] && other_party && applied_effect)
			recipient.apply_status_effect(/datum/status_effect/interaction_tether, other_party, effect_path)

/**
 * Spawns a list of decal entries (list("type" = typepath text, "spawn_on" = "target"/"user",
 * "icon_state" = optional text, "color" = optional text, "chance" = optional percent 0-100)) on the
 * relevant mob's turf. Invalid/non cleanable-decal types are ignored and logged.
 */
/datum/interaction/proc/spawn_interaction_decals(list/decal_specs, mob/living/carbon/human/user, mob/living/carbon/human/target)
	for(var/list/decal_data in decal_specs)
		if(!islist(decal_data))
			continue
		var/chance = decal_data["chance"]
		if(isnum(chance) && !prob(chance))
			continue
		var/decal_type_text = decal_data["type"]
		if(!istext(decal_type_text))
			continue
		var/decal_path = text2path(decal_type_text)
		if(!ispath(decal_path, /obj/effect/decal/cleanable))
			message_admins("Interaction '[name]' referenced an invalid decal type '[decal_type_text]'.")
			continue
		var/mob/living/carbon/human/spawn_source = (decal_data["spawn_on"] == "user") ? user : target
		var/turf/spawn_turf = get_turf(spawn_source)
		if(!spawn_turf)
			continue
		var/obj/effect/decal/cleanable/new_decal = spawn_turf.spawn_unique_cleanable(decal_path)
		if(!new_decal)
			continue
		if(istext(decal_data["icon_state"]))
			new_decal.icon_state = decal_data["icon_state"]
		if(istext(decal_data["color"]))
			new_decal.color = decal_data["color"]

/datum/interaction/proc/act(mob/living/carbon/human/user, mob/living/carbon/human/target, obj/body_relay = null)
	if(!allow_act(user, target))
		return
	if(!message)
		message_admins("Interaction had a null message list. '[name]'")
		return
	if(!islist(message) && istext(message))
		message_admins("Deprecated message handling for '[name]'. Correct format is a list with one entry. This message will only show once.")
		message = list(message)
	var/zone = user.zone_selected
	var/combat_mode = user.combat_mode
	var/prone = target.body_position == LYING_DOWN
	var/is_self = (target == user)
	var/list/message_pool = get_zone_pool(zone, combat_mode, prone, is_self, "message", message)
	var/msg = pick(message_pool)
	if(!isnull(body_relay))
		msg = replacetext(msg, "%TARGET%", "\the [body_relay.name]")
	// We replace %USER% with nothing because manual_emote already prepends it.
	msg = trim(replacetext(replacetext(msg, "%TARGET%", "[target]"), "%USER%", ""), INTERACTION_MAX_CHAR)
	if(lewd)
		user.emote("subtle", null, msg, TRUE)
	else
		user.manual_emote(msg)
	if(is_self)
		// Self-targeting only ever gets one private message, not both user_messages and target_messages,
		// since sending both to the same person would just duplicate the same event.
		var/list/self_message_pool = get_zone_pool(zone, combat_mode, prone, is_self, "self_messages", self_messages.len ? self_messages : user_messages)
		if(self_message_pool.len)
			var/self_msg = pick(self_message_pool)
			self_msg = replacetext(replacetext(self_msg, "%TARGET%", "[target]"), "%USER%", "[user]")
			to_chat(user, self_msg)
	else
		var/list/user_message_pool = get_zone_pool(zone, combat_mode, prone, is_self, "user_messages", user_messages)
		if(user_message_pool.len)
			var/user_msg = pick(user_message_pool)
			if(!isnull(body_relay))
				user_msg = replacetext(user_msg, "%TARGET%", "\the [body_relay.name]")
			user_msg = replacetext(replacetext(user_msg, "%TARGET%", "[target]"), "%USER%", "[user]")
			to_chat(user, user_msg)
		var/list/target_message_pool = get_zone_pool(zone, combat_mode, prone, is_self, "target_messages", target_messages)
		if(target_message_pool.len)
			var/target_msg = pick(target_message_pool)
			if(!isnull(body_relay))
				target_msg = replacetext(target_msg, "%USER%", "Unknown")
			target_msg = replacetext(replacetext(target_msg, "%TARGET%", "[target]"), "%USER%", "[user]")
			to_chat(target, target_msg)
	if(!islist(sound_possible) && istext(sound_possible))
		message_admins("Deprecated sound handling for '[name]'. Correct format is a list with one entry. This message will only show once.")
		sound_possible = list(sound_possible)
	var/list/sound_pool = get_zone_pool(zone, combat_mode, prone, is_self, "sound_possible", sound_possible)
	if(sound_pool.len)
		sound_cache = pick(sound_pool)
		// playsound()'s range is always SOUND_RANGE (15) + extrarange, so we offset by -SOUND_RANGE to make
		// extrarange effectively equal to the JSON-defined sound_range instead of stacking on top of it.
		playsound(source = user, soundin = sound_cache, vol = 50, vary = FALSE, extrarange = sound_range - SOUND_RANGE, ignore_walls = FALSE, volume_preference = /datum/preference/numeric/volume/sound_emote)

	if(get_zone_value(zone, combat_mode, prone, is_self, "target_force_say", target_force_say) && prob(get_zone_value(zone, combat_mode, prone, is_self, "target_force_say_chance", target_force_say_chance)))
		var/list/target_say_phrases = get_zone_pool(zone, combat_mode, prone, is_self, "target_force_say_phrases", target_force_say_phrases)
		target.force_say(target_say_phrases.len ? target_say_phrases : null, immediate = TRUE)
	if(get_zone_value(zone, combat_mode, prone, is_self, "user_force_say", user_force_say) && prob(get_zone_value(zone, combat_mode, prone, is_self, "user_force_say_chance", user_force_say_chance)))
		var/list/user_say_phrases = get_zone_pool(zone, combat_mode, prone, is_self, "user_force_say_phrases", user_force_say_phrases)
		user.force_say(user_say_phrases.len ? user_say_phrases : null, immediate = TRUE)

	apply_zone_status_effects(get_zone_pool(zone, combat_mode, prone, is_self, "target_status_effects", target_status_effects), target, user)
	apply_zone_status_effects(get_zone_pool(zone, combat_mode, prone, is_self, "user_status_effects", user_status_effects), user, target)

	spawn_interaction_decals(get_zone_pool(zone, combat_mode, prone, is_self, "decals", decals), user, target)

	var/target_bleed_amount = get_zone_value(zone, combat_mode, prone, is_self, "target_bleed", target_bleed)
	if(target_bleed_amount)
		target.bleed(target_bleed_amount)
	var/user_bleed_amount = get_zone_value(zone, combat_mode, prone, is_self, "user_bleed", user_bleed)
	if(user_bleed_amount)
		user.bleed(user_bleed_amount)

	if(lewd)
		user.adjust_pleasure(get_zone_value(zone, combat_mode, prone, is_self, "user_pleasure", user_pleasure))
		user.adjust_arousal(get_zone_value(zone, combat_mode, prone, is_self, "user_arousal", user_arousal))
		user.adjust_pain(get_zone_value(zone, combat_mode, prone, is_self, "user_pain", user_pain))
		target.adjust_pleasure(get_zone_value(zone, combat_mode, prone, is_self, "target_pleasure", target_pleasure))
		target.adjust_arousal(get_zone_value(zone, combat_mode, prone, is_self, "target_arousal", target_arousal))
		target.adjust_pain(get_zone_value(zone, combat_mode, prone, is_self, "target_pain", target_pain))
		if(body_relay)
			var/obj/lewd_portal_relay/body_portal_relay = body_relay
			body_portal_relay.update_visuals()

	/**
	 * Lets other systems react to any interaction without editing this file. Example hook, e.g. for a
	 * mood or achievement system tracking how often someone gets kissed:
	 *
	 *   RegisterSignal(mob, COMSIG_HUMAN_INTERACTION_RECEIVED, PROC_REF(on_interaction_received))
	 *
	 *   /datum/proc/on_interaction_received(mob/living/carbon/human/source, datum/interaction/performed, mob/living/carbon/human/user, zone)
	 *       if(performed.name == "Kiss")
	 *           track_kiss_count(source, user)
	 */
	SEND_SIGNAL(user, COMSIG_HUMAN_INTERACTION_PERFORMED, src, target, zone)
	SEND_SIGNAL(target, COMSIG_HUMAN_INTERACTION_RECEIVED, src, user, zone)

/datum/interaction/proc/load_from_json(path)
	var/fpath = path
	if(!fexists(fpath))
		message_admins("Attempted to load an interaction from json and the file does not exist")
		qdel(src)
		return FALSE
	var/file = file(fpath)
	var/list/json = json_load(file)
	name = sanitize_text(json["name"])
	description = sanitize_text(json["description"])
	distance_allowed = sanitize_integer(json["distance_allowed"], 0, 1, 0)
	cooldown = sanitize_integer(json["cooldown"], 0, 600, INTERACTION_COOLDOWN / 10) SECONDS
	message = sanitize_islist(json["message"], list("json error"))
	self_messages = sanitize_islist(json["self_messages"], list())
	zone_overrides = sanitize_islist(json["zone_overrides"], list())
	decals = sanitize_islist(json["decals"], list())
	category = sanitize_text(json["category"])
	usage = sanitize_text(json["usage"])
	sound_range = sanitize_integer(json["sound_range"], 1, 7, 1)
	sound_possible = sanitize_islist(json["sound_possible"], list())
	interaction_requires = sanitize_islist(json["interaction_requires"], list())
	color = sanitize_text(json["color"])

	user_messages = sanitize_islist(json["user_messages"], list())
	user_required_parts = sanitize_islist(json["user_required_parts"], list())
	user_arousal = sanitize_integer(json["user_arousal"], 0, 100, 0)
	user_pleasure = sanitize_integer(json["user_pleasure"], 0, 100, 0)
	user_pain = sanitize_integer(json["user_pain"], 0, 100, 0)
	user_bleed = sanitize_integer(json["user_bleed"], 0, 100, 0)
	user_force_say = sanitize_integer(json["user_force_say"], 0, 1, 0)
	user_force_say_phrases = sanitize_islist(json["user_force_say_phrases"], list())
	user_force_say_chance = sanitize_integer(json["user_force_say_chance"], 0, 100, 100)
	user_status_effects = sanitize_islist(json["user_status_effects"], list())
	target_messages = sanitize_islist(json["target_messages"], list())
	target_required_parts = sanitize_islist(json["target_required_parts"], list())
	target_arousal = sanitize_integer(json["target_arousal"], 0, 100, 0)
	target_pleasure = sanitize_integer(json["target_pleasure"], 0, 100, 0)
	target_pain = sanitize_integer(json["target_pain"], 0, 100, 0)
	target_bleed = sanitize_integer(json["target_bleed"], 0, 100, 0)
	target_force_say = sanitize_integer(json["target_force_say"], 0, 1, 0)
	target_force_say_phrases = sanitize_islist(json["target_force_say_phrases"], list())
	target_force_say_chance = sanitize_integer(json["target_force_say_chance"], 0, 100, 100)
	target_status_effects = sanitize_islist(json["target_status_effects"], list())
	lewd = sanitize_integer(json["lewd"], 0, 1, 0)
	sexuality = sanitize_text(json["sexuality"])
	return TRUE

/datum/interaction/proc/json_save(path)
	var/fpath = path
	if(fexists(fpath))
		fdel(fpath)
	var/list/json = list(
		"name" = name,
		"description" = description,
		"distance_allowed" = distance_allowed,
		"cooldown" = cooldown / 10,
		"message" = message,
		"self_messages" = self_messages,
		"zone_overrides" = zone_overrides,
		"decals" = decals,
		"category" = category,
		"usage" = usage,
		"sound_range" = sound_range,
		"sound_possible" = sound_possible,
		"interaction_requires" = interaction_requires,
		"color" = color,
		"user_messages" = user_messages,
		"user_required_parts" = user_required_parts,
		"user_arousal" = user_arousal,
		"user_pleasure" = user_pleasure,
		"user_pain" = user_pain,
		"user_bleed" = user_bleed,
		"user_force_say" = user_force_say,
		"user_force_say_phrases" = user_force_say_phrases,
		"user_force_say_chance" = user_force_say_chance,
		"user_status_effects" = user_status_effects,
		"target_messages" = target_messages,
		"target_required_parts" = target_required_parts,
		"target_arousal" = target_arousal,
		"target_pleasure" = target_pleasure,
		"target_pain" = target_pain,
		"target_bleed" = target_bleed,
		"target_force_say" = target_force_say,
		"target_force_say_phrases" = target_force_say_phrases,
		"target_force_say_chance" = target_force_say_chance,
		"target_status_effects" = target_status_effects,
		"lewd" = lewd,
		"sexuality" = sexuality,
	)
	var/file = file(fpath)
	WRITE_FILE(file, json_encode(json))
	return TRUE

/mob/living/carbon/human/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/interactable)

/// Global loading procs
/proc/populate_interaction_instances()
	for(var/spath in subtypesof(/datum/interaction))
		var/datum/interaction/interaction = new spath()
		GLOB.interaction_instances[interaction.name] = interaction
	populate_interaction_jsons(INTERACTION_JSON_FOLDER)

/proc/populate_interaction_jsons(directory)
	for(var/file in flist(directory))
		if(flist(directory + file) && !findlasttext(directory + file, ".json"))
			populate_interaction_instances(directory + file)
			continue
		if(findlasttext(directory + file, ".master.json")) // This is a master json which has special handling
			populate_interaction_jsons_master(directory + file)
			continue
		var/datum/interaction/interaction = new()
		if(interaction.load_from_json(directory + file))
			GLOB.interaction_instances[interaction.name] = interaction
		else message_admins("Error loading interaction from file: '[directory + file]'. Inform coders.")

/proc/populate_interaction_jsons_master(path)
	if(!fexists(path))
		message_admins("We are attempting to load an interaction master without the file existing! '[path]'")
		return
	var/file = file(path)
	var/list/json = json_load(file)

	for(var/iname in json)
		if(GLOB.interaction_instances[iname])
			message_admins("Interaction Master '[path]' contained a duplicate interaction! '[iname]'")
			continue

		var/list/ijson = json[iname]
		if(ijson["name"] != iname)
			message_admins("Interaction Master '[path]' contained an invalid interaction! '[iname]'")
			continue

		var/datum/interaction/interaction = new()

		interaction.distance_allowed = sanitize_integer(ijson["distance_allowed"], 0, 1, 0)
		interaction.cooldown = sanitize_integer(ijson["cooldown"], 0, 600, INTERACTION_COOLDOWN / 10) SECONDS
		interaction.message = sanitize_islist(ijson["message"], list("json error"))
		interaction.self_messages = sanitize_islist(ijson["self_messages"], list())
		interaction.zone_overrides = sanitize_islist(ijson["zone_overrides"], list())
		interaction.decals = sanitize_islist(ijson["decals"], list())
		interaction.category = sanitize_text(ijson["category"])
		interaction.usage = sanitize_text(ijson["usage"])
		interaction.sound_range = sanitize_integer(ijson["sound_range"], 1, 7, 1)
		interaction.sound_possible = sanitize_islist(ijson["sound_possible"], list())
		interaction.interaction_requires = sanitize_islist(ijson["interaction_requires"], list())
		interaction.color = sanitize_text(ijson["color"])

		interaction.user_messages = sanitize_islist(ijson["user_messages"], list())
		interaction.user_required_parts = sanitize_islist(ijson["user_required_parts"], list())
		interaction.user_arousal = sanitize_integer(ijson["user_arousal"], 0, 100, 0)
		interaction.user_pleasure = sanitize_integer(ijson["user_pleasure"], 0, 100, 0)
		interaction.user_pain = sanitize_integer(ijson["user_pain"], 0, 100, 0)
		interaction.user_bleed = sanitize_integer(ijson["user_bleed"], 0, 100, 0)
		interaction.user_force_say = sanitize_integer(ijson["user_force_say"], 0, 1, 0)
		interaction.user_force_say_phrases = sanitize_islist(ijson["user_force_say_phrases"], list())
		interaction.user_force_say_chance = sanitize_integer(ijson["user_force_say_chance"], 0, 100, 100)
		interaction.user_status_effects = sanitize_islist(ijson["user_status_effects"], list())
		interaction.target_messages = sanitize_islist(ijson["target_messages"], list())
		interaction.target_required_parts = sanitize_islist(ijson["target_required_parts"], list())
		interaction.target_arousal = sanitize_integer(ijson["target_arousal"], 0, 100, 0)
		interaction.target_pleasure = sanitize_integer(ijson["target_pleasure"], 0, 100, 0)
		interaction.target_pain = sanitize_integer(ijson["target_pain"], 0, 100, 0)
		interaction.target_bleed = sanitize_integer(ijson["target_bleed"], 0, 100, 0)
		interaction.target_force_say = sanitize_integer(ijson["target_force_say"], 0, 1, 0)
		interaction.target_force_say_phrases = sanitize_islist(ijson["target_force_say_phrases"], list())
		interaction.target_force_say_chance = sanitize_integer(ijson["target_force_say_chance"], 0, 100, 100)
		interaction.target_status_effects = sanitize_islist(ijson["target_status_effects"], list())
		interaction.lewd = sanitize_integer(ijson["lewd"], 0, 1, 0)
		interaction.sexuality = sanitize_text(ijson["sexuality"])

		GLOB.interaction_instances[iname] = interaction

ADMIN_VERB(reload_interactions, R_DEBUG, "Reload Interactions", "Force reload interactions.", ADMIN_CATEGORY_DEBUG)
	populate_interaction_instances()
