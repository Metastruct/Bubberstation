/**
 * Deciseconds per frame at each mood level, at the default wag_speed_base of 1 (lower = faster).
 *
 * Spaced 0.5 decisecond apart, BYOND's tick length at world.fps = 20 and the finest gap two speeds can
 * actually differ by. Neutral sits one notch below the original baked speed (2.0) to leave room for all
 * 4 happy tiers to land on distinct, non-colliding speeds.
 */
GLOBAL_LIST_INIT(wag_mood_frame_time, list(
	"[MOOD_LEVEL_SAD4]" = 4.5,
	"[MOOD_LEVEL_SAD3]" = 4,
	"[MOOD_LEVEL_SAD2]" = 3.5,
	"[MOOD_LEVEL_SAD1]" = 3,
	"[MOOD_LEVEL_NEUTRAL]" = 2.5,
	"[MOOD_LEVEL_HAPPY1]" = 2,
	"[MOOD_LEVEL_HAPPY2]" = 1.5,
	"[MOOD_LEVEL_HAPPY3]" = 1,
	"[MOOD_LEVEL_HAPPY4]" = 0.5,
))

/// Discovered split-frame counts, keyed by [icon][built icon_state] (see discover_wag_frame_count()). A tail
/// style with no split frames gets an entry of 0 and just plays its original baked animated icon_state.
GLOBAL_LIST_EMPTY(tail_wag_frame_count_cache)

/datum/bodypart_overlay/mutant/tail
	/// Player-set divisor on wag animation speed for tails with a split-frame wag animation
	/// (see discover_wag_frame_count()). 1 = unchanged, 2 = twice as fast, 0.5 = half speed.
	/// The actual speed used also factors in the wagger's current mood, see get_wag_frame_time().
	var/wag_speed_base = 1
	/// Whether mood scales wag speed on top of wag_speed_base. Opt-in, FALSE by default: wag_speed_base
	/// alone determines speed until the player turns this on, see get_wag_frame_time().
	var/wag_mood_scaling = FALSE
	/// Current frame (1-indexed) of the split-frame wag animation, if one is playing.
	var/current_wag_frame = 1
	/// Timer id for the next frame advance, so it can be cancelled when wagging stops.
	var/wag_timer_id
	/// Number of split animation frames for the current wag icon_state, populated by get_images() (forced
	/// eagerly via ensure_wag_frame_count() on wag start, see there for why). 0 if not yet discovered, or
	/// permanently if this tail style has no split frames (falls back to the baked animation).
	var/wag_frame_count = 0

/// The deciseconds-per-frame actually used for timing: the mood-based baseline scaled down by the
/// player's own wag_speed_base, floored at BYOND's own tick length so nothing gets scheduled faster
/// than the engine can actually represent.
/datum/bodypart_overlay/mutant/tail/proc/get_wag_frame_time(mob/living/carbon/organ_owner)
	var/mood_frame_time = GLOB.wag_mood_frame_time["[MOOD_LEVEL_NEUTRAL]"]
	var/datum/mood/mob_mood = wag_mood_scaling ? organ_owner?.mob_mood : null
	if(mob_mood)
		mood_frame_time = GLOB.wag_mood_frame_time["[mob_mood.mood_level]"] || mood_frame_time
	return max(0.5, mood_frame_time / max(0.1, wag_speed_base))

/// Probes how many "[base_state]_f1".."[base_state]_fN" states exist for a given icon and caches the result,
/// so any tail whose wag animation has been split into frames gets code-driven speed automatically without
/// per-accessory registration.
/datum/bodypart_overlay/mutant/tail/proc/discover_wag_frame_count(icon/icon_file, base_state)
	if(isnull(GLOB.tail_wag_frame_count_cache[icon_file]))
		GLOB.tail_wag_frame_count_cache[icon_file] = list()
	var/list/per_icon_cache = GLOB.tail_wag_frame_count_cache[icon_file]
	if(!isnull(per_icon_cache[base_state]))
		return per_icon_cache[base_state]

	var/count = 0
	while(icon_exists(icon_file, "[base_state]_f[count + 1]"))
		count++
	per_icon_cache[base_state] = count
	return count

// atom.overlays only ever holds immutable appearance snapshots, not live object references (see
// code/controllers/subsystem/overlays.dm), so animate() on an overlay image is never actually visible.
// Frame-stepping instead mutates current_wag_frame and re-triggers update_body_parts() on a timer.
/datum/bodypart_overlay/mutant/tail/get_images(image_layer, obj/item/bodypart/limb)
	. = ..()
	if(!wagging)
		return

	for(var/mutable_appearance/overlay as anything in .)
		if(!wag_frame_count)
			wag_frame_count = discover_wag_frame_count(overlay.icon, overlay.icon_state)
		if(!wag_frame_count)
			continue

		var/framed_state = "[overlay.icon_state]_f[current_wag_frame]"
		if(icon_exists(overlay.icon, framed_state))
			overlay.icon_state = framed_state

// limb_icon_cache (carbon_update_icons.dm) reuses whatever's cached under generate_icon_cache()'s key, so
// current_wag_frame has to be part of that key or every tick after the first is a cache hit that just
// redisplays the same frame.
/datum/bodypart_overlay/mutant/tail/generate_icon_cache(obj/item/bodypart/limb)
	. = ..()
	if(wagging && wag_frame_count)
		. += "wagframe[current_wag_frame]"

// wag_frame_count is only discovered inside get_images(), but a same-key start right after a stop is a
// cache hit in update_body_parts() that skips calling get_images() at all, so discovery never happens.
// Calling get_images() directly here forces discovery regardless of that cache.
/datum/bodypart_overlay/mutant/tail/proc/ensure_wag_frame_count(obj/item/bodypart/limb)
	if(wag_frame_count || !limb)
		return
	// get_overlay(), not get_images() directly: it converts the EXTERNAL_FRONT bitflag to an actual
	// layer number via bitflag_to_layer() first, same as the real render path does.
	get_overlay(EXTERNAL_FRONT, limb) // unused return value, called only for its discovery side effect

/datum/bodypart_overlay/mutant/tail/proc/begin_frame_cycle(mob/living/carbon/organ_owner)
	// Cancel a stray timer directly rather than calling end_frame_cycle(), since that also zeroes
	// wag_frame_count, erasing the count get_images() just populated earlier in this same start_wag() call.
	if(wag_timer_id)
		deltimer(wag_timer_id)
		wag_timer_id = null
	current_wag_frame = 1
	schedule_next_wag_frame(organ_owner)

/datum/bodypart_overlay/mutant/tail/proc/schedule_next_wag_frame(mob/living/carbon/organ_owner)
	var/frame_time = get_wag_frame_time(organ_owner)
	wag_timer_id = addtimer(CALLBACK(src, PROC_REF(advance_wag_frame), organ_owner), frame_time, TIMER_STOPPABLE)

/datum/bodypart_overlay/mutant/tail/proc/advance_wag_frame(mob/living/carbon/organ_owner)
	wag_timer_id = null
	if(QDELETED(organ_owner) || !wagging || !wag_frame_count)
		return

	current_wag_frame++
	if(current_wag_frame > wag_frame_count)
		current_wag_frame = 1
	organ_owner.update_body_parts()
	schedule_next_wag_frame(organ_owner)

/datum/bodypart_overlay/mutant/tail/proc/end_frame_cycle()
	current_wag_frame = 1
	wag_frame_count = 0 // rediscover next time, in case the tail style/sprite_datum changed while stopped
	if(wag_timer_id)
		deltimer(wag_timer_id)
		wag_timer_id = null

/obj/item/organ/tail/start_wag(mob/living/carbon/organ_owner, stop_after = INFINITY)
	. = ..()
	if(!.)
		return .
	var/datum/bodypart_overlay/mutant/tail/accessory = bodypart_overlay
	accessory.ensure_wag_frame_count(bodypart_owner)
	if(accessory.wag_frame_count)
		accessory.begin_frame_cycle(organ_owner)
		organ_owner.update_body_parts() // the ..() redraw above may have been a cache hit before wag_frame_count existed to bust it; force a real one now

/obj/item/organ/tail/stop_wag(mob/living/carbon/organ_owner)
	var/datum/bodypart_overlay/mutant/tail/accessory = bodypart_overlay
	accessory?.end_frame_cycle()
	return ..()

/// Sets the player's baseline wag speed (mood still scales on top of this unless wag_mood_scaling is off).
/// Takes effect on the next frame tick if already wagging, or the next time wagging starts otherwise.
/obj/item/organ/tail/proc/set_wag_speed(new_speed)
	var/datum/bodypart_overlay/mutant/tail/accessory = bodypart_overlay
	accessory.wag_speed_base = new_speed

/// Sets whether mood scales wag speed on top of wag_speed_base, see get_wag_frame_time().
/obj/item/organ/tail/proc/set_wag_mood_scaling(new_value)
	var/datum/bodypart_overlay/mutant/tail/accessory = bodypart_overlay
	accessory.wag_mood_scaling = new_value

/mob/living/carbon/human/verb/set_tail_wag_speed()
	set name = "Set Tail Wag Speed"
	set category = "IC"
	set desc = "Adjust how fast your tail wags, if you have one that can."

	if(incapacitated)
		to_chat(src, span_warning("You can't do that right now!"))
		return

	var/obj/item/organ/tail/tail = get_organ_slot(ORGAN_SLOT_EXTERNAL_TAIL)
	if(!tail || !(tail.wag_flags & WAG_ABLE))
		to_chat(src, span_warning("You don't have a tail that can wag."))
		return

	var/mood_scaling = tgui_alert(src, "Should your mood affect your tail's wag speed?", "Tail Wag Speed", list("Yes", "No")) == "Yes"
	if(QDELETED(src) || QDELETED(tail))
		return
	tail = get_organ_slot(ORGAN_SLOT_EXTERNAL_TAIL)
	if(!tail || !(tail.wag_flags & WAG_ABLE))
		return

	var/wag_percent = tgui_input_number(src, "How fast should your tail wag (percent of normal speed)?", "Tail Wag Speed", 100, 400, 25)
	if(!isnum(wag_percent) || QDELETED(src) || QDELETED(tail))
		return
	tail = get_organ_slot(ORGAN_SLOT_EXTERNAL_TAIL)
	if(!tail || !(tail.wag_flags & WAG_ABLE))
		return

	tail.set_wag_speed(wag_percent / 100)
	tail.set_wag_mood_scaling(mood_scaling)
	to_chat(src, span_notice("You adjust your tail's wagging speed to [wag_percent]% of normal[mood_scaling ? ", scaled further by your mood" : " (mood ignored)"]."))
