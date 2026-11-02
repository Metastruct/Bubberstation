/// How far the passing mob is offset to one side of the tile in pixels.
#define MOB_PASSBY_OFFSET 8
/// How far each mob is offset when squeezing past in a gap.
#define MOB_PASSBY_SQUEEZE_OFFSET 4
/// How long the offset takes to slide in/out, in deciseconds.
#define MOB_PASSBY_SLIDE_TIME 1
#define MOB_PASSBY_ANIM_TAG "meta_passby_offset"
/// cooldown like it used to have
#define MOB_SHOVE_COOLDOWN (5 SECONDS)

/mob/living
	var/passby_offset_x = 0
	var/passby_offset_y = 0
	var/passby_moving = FALSE
	var/next_mob_shove = 0

/mob/living/proc/try_mob_pass_by(mob/blocker)
	if(isnull(blocker.loc))
		return FALSE

	var/travel_dir = get_dir(src, blocker)
	if(!travel_dir)
		return FALSE

	if(shoves_physically(blocker) && can_shove_past(blocker) && try_shove_past(blocker, travel_dir))
		return TRUE

	var/was_passmob = (pass_flags & PASSMOB)

	now_pushing = TRUE
	pass_flags |= PASSMOB
	passby_moving = TRUE
	var/moved = Move(blocker.loc)
	passby_moving = FALSE
	if(!was_passmob)
		pass_flags &= ~PASSMOB
	now_pushing = FALSE

	if(!moved)
		return FALSE

	apply_passby_offset(travel_dir, blocker)
	return TRUE

/mob/living/proc/apply_passby_offset(travel_dir, mob/blocker)
	var/side_dir = pick_passby_side(travel_dir)
	var/squeezed = get_step(src, side_dir)?.is_blocked_turf(TRUE)
	var/magnitude = squeezed ? MOB_PASSBY_SQUEEZE_OFFSET : MOB_PASSBY_OFFSET
	var/list/delta = passby_pixel_delta(side_dir, magnitude)

	if(squeezed)
		set_passby_offset(delta[1], delta[2])
		if(isliving(blocker))
			var/mob/living/living_blocker = blocker
			living_blocker.set_passby_offset(-delta[1], -delta[2])
		return

	if(can_shove_past(blocker))
		var/mob/living/living_blocker = blocker
		living_blocker.set_passby_offset(delta[1], delta[2])
		return

	set_passby_offset(delta[1], delta[2])

/mob/living/proc/passes_by_shoving(mob/blocker)
	return HAS_TRAIT(src, TRAIT_EVIL) || has_quirk(/datum/quirk/defensive)

/mob/living/proc/shoves_physically(mob/blocker)
	return has_quirk(/datum/quirk/defensive)

/mob/living/proc/try_shove_past(mob/blocker, travel_dir)
	if(world.time < next_mob_shove)
		return FALSE

	var/mob/living/living_blocker = blocker
	if(!can_disarm(living_blocker))
		return FALSE

	var/side_dir = pick_passby_side(travel_dir)
	var/turf/destination = get_step(living_blocker.loc, side_dir)
	if(isnull(destination) || destination.is_blocked_turf(TRUE, living_blocker))
		return FALSE

	var/turf/old_blocker_turf = living_blocker.loc
	disarm(living_blocker, null, side_dir)
	next_mob_shove = world.time + MOB_SHOVE_COOLDOWN

	if(get_turf(living_blocker) != old_blocker_turf)
		Move(old_blocker_turf, travel_dir)
	return TRUE

/mob/living/proc/can_shove_past(mob/blocker)
	if(!isliving(blocker))
		return FALSE
	if(!passes_by_shoving(blocker))
		return FALSE
	if(!(blocker.status_flags & CANPUSH))
		return FALSE
	if(HAS_TRAIT(blocker, TRAIT_PUSHIMMUNE))
		return FALSE
	if(blocker.move_resist > move_force)
		return FALSE
	return TRUE

/mob/living/proc/set_passby_offset(offset_x, offset_y)
	if(offset_x == passby_offset_x && offset_y == passby_offset_y)
		return

	var/base_x = pixel_x - passby_offset_x
	var/base_y = pixel_y - passby_offset_y
	animate(src, tag = MOB_PASSBY_ANIM_TAG)
	pixel_x = base_x
	pixel_y = base_y
	passby_offset_x = offset_x
	passby_offset_y = offset_y
	animate(src, pixel_x = base_x + offset_x, pixel_y = base_y + offset_y, time = MOB_PASSBY_SLIDE_TIME, easing = SINE_EASING, tag = MOB_PASSBY_ANIM_TAG)

	RegisterSignal(src, COMSIG_MOVABLE_MOVED, PROC_REF(on_passby_moved))

/mob/living/proc/pick_passby_side(travel_dir)
	var/left = turn(travel_dir, 90)
	var/right = turn(travel_dir, -90)
	// exclude_mobs = TRUE: only terrain/structures should push our sprite around.
	var/left_blocked = get_step(src, left)?.is_blocked_turf(TRUE)
	var/right_blocked = get_step(src, right)?.is_blocked_turf(TRUE)
	if(left_blocked && !right_blocked)
		return right
	if(right_blocked && !left_blocked)
		return left
	return left

/// Converts a cardinal [direction] and pixel [magnitude] into an (x, y) delta.
/mob/living/proc/passby_pixel_delta(direction, magnitude)
	switch(direction)
		if(NORTH)
			return list(0, magnitude)
		if(SOUTH)
			return list(0, -magnitude)
		if(EAST)
			return list(magnitude, 0)
		if(WEST)
			return list(-magnitude, 0)
	return list(0, 0)

/mob/living/proc/on_passby_moved(datum/source)
	SIGNAL_HANDLER
	if(passby_moving)
		return
	clear_passby_offset()

/mob/living/proc/clear_passby_offset()
	if(!passby_offset_x && !passby_offset_y)
		return
	UnregisterSignal(src, COMSIG_MOVABLE_MOVED)
	animate(src, pixel_x = pixel_x - passby_offset_x, pixel_y = pixel_y - passby_offset_y, time = MOB_PASSBY_SLIDE_TIME, easing = SINE_EASING, tag = MOB_PASSBY_ANIM_TAG)
	passby_offset_x = 0
	passby_offset_y = 0

#undef MOB_PASSBY_OFFSET
#undef MOB_PASSBY_SQUEEZE_OFFSET
#undef MOB_PASSBY_SLIDE_TIME
#undef MOB_PASSBY_ANIM_TAG
#undef MOB_SHOVE_COOLDOWN
