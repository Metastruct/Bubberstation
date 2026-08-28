#define SHIFTING_ITEMS 1
#define SHIFTING_PARENT 2
#define TILTING_PARENT 3
// META EDIT - ADDITION - START - PIXEL_SHIFT_BUCKLE_TRANSLATE
/// Offset source key used when translating our shift onto anyone buckled to us.
#define PIXEL_SHIFT_BUCKLE_OFFSET "pixel_shift_buckled"
// META EDIT - ADDITION - END
// META EDIT - ADDITION - START - PIXEL_SHIFT_PULLED_MOB
/// Offset source key used when nudging a pulled mob's position.
#define PIXEL_SHIFT_PULLED_OFFSET "pixel_shift_pulled"
// META EDIT - ADDITION - END

/datum/component/pixel_shift
	dupe_mode = COMPONENT_DUPE_UNIQUE
	//whether or not parent is shifting
	var/shifting = FALSE
	//how tilted the parent is
	var/how_tilted
	//the maximum amount of tilt parent can achieve
	var/maximum_tilt = 45
	//the maximum amount we/an item can move
	var/maximum_pixel_shift = 16
	//If we are shifted
	var/is_shifted = FALSE
	//Amount of shift in the X axis
	var/shift_x = 0
	//Amount of shift in the Y axis
	var/shift_y = 0
	//Allows atoms entering Parent's turf to pass through freely from given directions
	var/passthroughable = NONE
	//Amount of shifting necessary to make the parent passthroughable
	var/passthrough_threshold = 8
	// META EDIT - ADDITION - START - PIXEL_SHIFT_PULLED_MOB
	/// The mob we're currently nudging via SHIFTING_ITEMS, if any.
	var/mob/living/pulled_shift_target
	/// Amount of shift we've applied to pulled_shift_target on the X axis
	var/pulled_shift_x = 0
	/// Amount of shift we've applied to pulled_shift_target on the Y axis
	var/pulled_shift_y = 0
	// META EDIT - ADDITION - END

/datum/component/pixel_shift/Initialize(...)
	. = ..()
	if(!isliving(parent))
		return COMPONENT_INCOMPATIBLE

// META EDIT - ADDITION - START - PIXEL_SHIFT_PULLED_MOB
/datum/component/pixel_shift/Destroy(force)
	reset_pulled_shift()
	return ..()
// META EDIT - ADDITION - END

/datum/component/pixel_shift/RegisterWithParent()
	RegisterSignal(parent, COMSIG_KB_LIVING_ITEM_PIXEL_SHIFT_DOWN, PROC_REF(item_pixel_shift_down))
	RegisterSignal(parent, COMSIG_KB_LIVING_ITEM_PIXEL_SHIFT_UP, PROC_REF(item_pixel_shift_up))
	RegisterSignal(parent, COMSIG_KB_LIVING_PIXEL_SHIFT_DOWN, PROC_REF(pixel_shift_down))
	RegisterSignal(parent, COMSIG_KB_LIVING_PIXEL_SHIFT_UP, PROC_REF(pixel_shift_up))
	RegisterSignal(parent, COMSIG_KB_LIVING_PIXEL_TILT_DOWN, PROC_REF(pixel_tilt_down))
	RegisterSignal(parent, COMSIG_KB_LIVING_PIXEL_TILT_UP, PROC_REF(pixel_tilt_up))
	// META EDIT - CHANGE - START - PIXEL_SHIFT_KEEP_ON_GRAB
	// Grab start/upgrade/release used to also fire unpixel_shift() on whoever gets grabbed, instantly
	// snapping back any shift they'd already applied to themselves. Movement alone still resets it.
	RegisterSignal(parent, COMSIG_MOVABLE_MOVED, PROC_REF(unpixel_shift))
	// META EDIT - CHANGE - END
	RegisterSignal(parent, COMSIG_MOB_CLIENT_PRE_LIVING_MOVE, PROC_REF(pre_move_check))
	RegisterSignal(parent, COMSIG_LIVING_CAN_ALLOW_THROUGH, PROC_REF(check_passable))
	// META EDIT - ADDITION - START - PIXEL_SHIFT_BUCKLE_TRANSLATE
	RegisterSignal(parent, COMSIG_MOVABLE_BUCKLE, PROC_REF(on_parent_buckle))
	RegisterSignal(parent, COMSIG_MOVABLE_UNBUCKLE, PROC_REF(on_parent_unbuckle))
	// META EDIT - ADDITION - END
/datum/component/pixel_shift/UnregisterFromParent()
	UnregisterSignal(parent, list(
		COMSIG_KB_LIVING_ITEM_PIXEL_SHIFT_DOWN,
		COMSIG_KB_LIVING_ITEM_PIXEL_SHIFT_UP,
		COMSIG_KB_LIVING_PIXEL_TILT_DOWN,
		COMSIG_KB_LIVING_PIXEL_TILT_UP,
		COMSIG_KB_LIVING_PIXEL_SHIFT_DOWN,
		COMSIG_KB_LIVING_PIXEL_SHIFT_UP,
		COMSIG_MOB_CLIENT_PRE_LIVING_MOVE,
		// META EDIT - REMOVAL - PIXEL_SHIFT_KEEP_ON_GRAB: COMSIG_LIVING_RESET_PULL_OFFSETS, COMSIG_LIVING_SET_PULL_OFFSET no longer registered, see RegisterWithParent
		COMSIG_MOVABLE_MOVED,
		COMSIG_LIVING_CAN_ALLOW_THROUGH,
		// META EDIT - ADDITION - START - PIXEL_SHIFT_BUCKLE_TRANSLATE
		COMSIG_MOVABLE_BUCKLE,
		COMSIG_MOVABLE_UNBUCKLE,
		// META EDIT - ADDITION - END
	))

//locks our movement when holding our keybinds
/datum/component/pixel_shift/proc/pre_move_check(mob/source, new_loc, direct)
	SIGNAL_HANDLER
	if(shifting)
		pixel_shift(source, direct)
		return COMSIG_MOB_CLIENT_BLOCK_PRE_LIVING_MOVE

//procs for tilting parent

/datum/component/pixel_shift/proc/pixel_tilt_down()
	SIGNAL_HANDLER
	shifting = TILTING_PARENT
	return COMSIG_KB_ACTIVATED

/datum/component/pixel_shift/proc/pixel_tilt_up()
	SIGNAL_HANDLER
	shifting = FALSE

//Procs for shifting items

/datum/component/pixel_shift/proc/item_pixel_shift_down()
	SIGNAL_HANDLER
	shifting = SHIFTING_ITEMS
	return COMSIG_KB_ACTIVATED

/datum/component/pixel_shift/proc/item_pixel_shift_up()
	SIGNAL_HANDLER
	shifting = FALSE

//Procs for shifting mobs

/// Checks if the parent is considered passthroughable from a direction. Projectiles will ignore the check and hit.
/datum/component/pixel_shift/proc/check_passable(mob/source, atom/movable/mover, border_dir)
	SIGNAL_HANDLER
	if(!isprojectile(mover) && !mover.throwing && passthroughable & border_dir)
		return COMPONENT_LIVING_PASSABLE

/// Activates Pixel Shift on Keybind down. Only Pixel Shift movement will be allowed.
/datum/component/pixel_shift/proc/pixel_shift_down()
	SIGNAL_HANDLER
	shifting = SHIFTING_PARENT
	return COMSIG_KB_ACTIVATED

/// Disables Pixel Shift on Keybind up. Allows to Move.
/datum/component/pixel_shift/proc/pixel_shift_up()
	SIGNAL_HANDLER
	shifting = FALSE

/// Sets parent pixel offsets to default and deletes the component.
/datum/component/pixel_shift/proc/unpixel_shift()
	SIGNAL_HANDLER
	passthroughable = NONE
	if(is_shifted)
		var/mob/living/owner = parent
		owner.remove_offsets(type)
		owner.transform = turn(owner.transform, -how_tilted)
		// META EDIT - ADDITION - START - PIXEL_SHIFT_BUCKLE_TRANSLATE
		for(var/mob/living/buckled_mob as anything in owner.buckled_mobs)
			buckled_mob.remove_offsets(PIXEL_SHIFT_BUCKLE_OFFSET)
		// META EDIT - ADDITION - END
		// META EDIT - ADDITION - START - PIXEL_SHIFT_PULLED_MOB
		is_shifted = FALSE
		how_tilted = 0
		shift_x = 0
		shift_y = 0
		// META EDIT - ADDITION - END
	// META EDIT - CHANGE - START - PIXEL_SHIFT_PULLED_MOB
	// Keep the component (and its nudge on pulled_shift_target) alive across our own movement;
	// the nudge is only supposed to clear when the pulled mob itself moves, see on_pulled_target_moved.
	if(!pulled_shift_target)
		qdel(src)
	// META EDIT - CHANGE - END

// META EDIT - ADDITION - START - PIXEL_SHIFT_BUCKLE_TRANSLATE
/// Mirrors our current shift onto everyone buckled to us, so a rider (piggyback) or someone we're fireman carrying moves with our pixel shift instead of visually detaching from us.
/datum/component/pixel_shift/proc/translate_shift_to_buckled()
	var/mob/living/owner = parent
	for(var/mob/living/buckled_mob as anything in owner.buckled_mobs)
		buckled_mob.add_offsets(PIXEL_SHIFT_BUCKLE_OFFSET, x_add = shift_x, y_add = shift_y)

/// Applies our current shift the instant someone gets buckled to us mid-shift.
/datum/component/pixel_shift/proc/on_parent_buckle(atom/movable/source, mob/living/buckled_mob, force)
	SIGNAL_HANDLER
	if(is_shifted)
		buckled_mob.add_offsets(PIXEL_SHIFT_BUCKLE_OFFSET, x_add = shift_x, y_add = shift_y)

/// Cleans our translated offset off a mob once they're no longer buckled to us.
/datum/component/pixel_shift/proc/on_parent_unbuckle(atom/movable/source, mob/living/buckled_mob, force)
	SIGNAL_HANDLER
	buckled_mob.remove_offsets(PIXEL_SHIFT_BUCKLE_OFFSET)
// META EDIT - ADDITION - END

// META EDIT - ADDITION - START - PIXEL_SHIFT_PULLED_MOB
/// Clears any nudge we've applied to whatever mob we were last pulling and shifting.
/datum/component/pixel_shift/proc/reset_pulled_shift()
	if(!pulled_shift_target)
		return
	UnregisterSignal(pulled_shift_target, COMSIG_MOVABLE_MOVED)
	pulled_shift_target.remove_offsets(PIXEL_SHIFT_PULLED_OFFSET)
	pulled_shift_target = null
	pulled_shift_x = 0
	pulled_shift_y = 0

/// Snaps a pulled mob's nudge back off once they take a real step under their own power, so they don't look permanently off-tile.
/datum/component/pixel_shift/proc/on_pulled_target_moved()
	SIGNAL_HANDLER
	reset_pulled_shift()
// META EDIT - ADDITION - END

/// In-turf pixel movement which can allow things to pass through if the threshold is met.
/datum/component/pixel_shift/proc/pixel_shift(mob/source, direct)
	passthroughable = NONE
	var/mob/living/owner = parent
	switch(shifting)
		if(SHIFTING_ITEMS)
			var/atom/pulled_atom = source.pulling
			if(isitem(pulled_atom))
				var/obj/item/pulled_item = pulled_atom
				switch(direct)
					if(NORTH)
						if(pulled_item.pixel_y <= maximum_pixel_shift + pulled_item.base_pixel_y)
							pulled_item.pixel_y++
					if(EAST)
						if(pulled_item.pixel_x <= maximum_pixel_shift + pulled_item.base_pixel_x)
							pulled_item.pixel_x++
					if(SOUTH)
						if(pulled_item.pixel_y >= -maximum_pixel_shift + pulled_item.base_pixel_y)
							pulled_item.pixel_y--
					if(WEST)
						if(pulled_item.pixel_x >= -maximum_pixel_shift + pulled_item.base_pixel_x)
							pulled_item.pixel_x--
			// META EDIT - ADDITION - START - PIXEL_SHIFT_PULLED_MOB
			else if(isliving(pulled_atom))
				var/mob/living/pulled_mob = pulled_atom
				if(pulled_mob != pulled_shift_target)
					reset_pulled_shift()
					pulled_shift_target = pulled_mob
					RegisterSignal(pulled_mob, COMSIG_MOVABLE_MOVED, PROC_REF(on_pulled_target_moved))
				switch(direct)
					if(NORTH)
						if(pulled_shift_y <= maximum_pixel_shift)
							pulled_shift_y++
					if(EAST)
						if(pulled_shift_x <= maximum_pixel_shift)
							pulled_shift_x++
					if(SOUTH)
						if(pulled_shift_y >= -maximum_pixel_shift)
							pulled_shift_y--
					if(WEST)
						if(pulled_shift_x >= -maximum_pixel_shift)
							pulled_shift_x--
				pulled_mob.add_offsets(PIXEL_SHIFT_PULLED_OFFSET, x_add = pulled_shift_x, y_add = pulled_shift_y)
			// META EDIT - ADDITION - END
		if(SHIFTING_PARENT)
			switch(direct)
				if(NORTH)
					if(shift_y <= maximum_pixel_shift)
						shift_y++
						owner.add_offsets(type, y_add = shift_y)
						is_shifted = TRUE
				if(EAST)
					if(shift_x <= maximum_pixel_shift)
						shift_x++
						owner.add_offsets(type, x_add = shift_x)
						is_shifted = TRUE
				if(SOUTH)
					if(shift_y >= -maximum_pixel_shift)
						shift_y--
						owner.add_offsets(type, y_add = shift_y)
						is_shifted = TRUE
				if(WEST)
					if(shift_x >= -maximum_pixel_shift)
						shift_x--
						owner.add_offsets(type, x_add = shift_x)
						is_shifted = TRUE
			// META EDIT - ADDITION - START - PIXEL_SHIFT_BUCKLE_TRANSLATE
			translate_shift_to_buckled()
			// META EDIT - ADDITION - END
		if(TILTING_PARENT)
			switch(direct)
				if(EAST)
					if(how_tilted <= maximum_tilt)
						owner.transform = turn(owner.transform, 1)
						how_tilted++
						is_shifted = TRUE
				if(WEST)
					if(how_tilted >= -maximum_tilt)
						owner.transform = turn(owner.transform, -1)
						how_tilted--
						is_shifted = TRUE

	// Yes, I know this sets it to true for everything if more than one is matched.
	// Movement doesn't check diagonals, and instead just checks EAST or WEST, depending on where you are for those.
	if(shift_y > passthrough_threshold)
		passthroughable |= EAST | SOUTH | WEST
	else if(shift_y < -passthrough_threshold)
		passthroughable |= NORTH | EAST | WEST
	if(shift_x > passthrough_threshold)
		passthroughable |= NORTH | SOUTH | WEST
	else if(shift_x < -passthrough_threshold)
		passthroughable |= NORTH | EAST | SOUTH

#undef SHIFTING_ITEMS
#undef SHIFTING_PARENT
#undef TILTING_PARENT
#undef PIXEL_SHIFT_BUCKLE_OFFSET // META EDIT - ADDITION
#undef PIXEL_SHIFT_PULLED_OFFSET // META EDIT - ADDITION
