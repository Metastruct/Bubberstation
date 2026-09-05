/obj/structure/coat_rack
	name = "coat rack"
	desc = "A rack for storing uniforms, suits, and hats."
	icon = 'modular_zzmeta/icons/obj/structures/coat_rack.dmi'
	icon_state = "coat_rack"
	density = FALSE
	anchored = FALSE
	obj_flags = CAN_BE_HIT

	var/list/obj/item/body_slots
	var/list/obj/item/hat_slots
	// Whether the radial menu is currently showing the hat page instead of the body page.
	var/showing_hats = FALSE

	var/static/list/body_slot_hung_states = list("N" = "coat_rack_hung_n", "E" = "coat_rack_hung_e", "S" = "coat_rack_hung_s", "W" = "coat_rack_hung_w")
	var/static/list/hat_slot_offsets = list("N" = list(0, 14), "E" = list(5, 14), "S" = list(0, 10), "W" = list(-5, 14))
	// Hats look too big when dropped, so lets just scale them down
	var/static/hat_overlay_scale = 0.5

GLOBAL_VAR_INIT(coat_rack_recipe_registered, register_coat_rack_recipe())

/proc/register_coat_rack_recipe()
	GLOB.wood_recipes += new /datum/stack_recipe("coat rack", /obj/structure/coat_rack, 2, time = 1.5 SECONDS, crafting_flags = CRAFT_CHECK_DENSITY | CRAFT_ONE_PER_TURF | CRAFT_ON_SOLID_GROUND, category = CAT_FURNITURE)
	return TRUE

/obj/structure/coat_rack/Initialize(mapload)
	. = ..()
	body_slots = list("N" = null, "E" = null, "S" = null, "W" = null)
	hat_slots = list("N" = null, "E" = null, "S" = null, "W" = null)

/obj/structure/coat_rack/Destroy()
	for(var/key in body_slots)
		var/obj/item/hung = body_slots[key]
		hung?.forceMove(drop_location())
	for(var/key in hat_slots)
		var/obj/item/hung = hat_slots[key]
		hung?.forceMove(drop_location())
	body_slots = null
	hat_slots = null
	return ..()

/obj/structure/coat_rack/proc/is_body_slot_item(obj/item/tool)
	return istype(tool, /obj/item/clothing/under) || istype(tool, /obj/item/clothing/suit) || istype(tool, /obj/item/clothing/underwear/undershirt)

/obj/structure/coat_rack/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	. = ..()
	if(user.combat_mode)
		return NONE
	if(is_body_slot_item(tool))
		return try_hang_item(tool, user, body_slots)
	if(istype(tool, /obj/item/clothing/head))
		return try_hang_item(tool, user, hat_slots)
	return .

/obj/structure/coat_rack/proc/try_hang_item(obj/item/tool, mob/living/user, list/slots)
	for(var/key in slots)
		if(!slots[key])
			return hang_item_at(tool, user, slots, key)
	balloon_alert(user, "no free space!")
	return ITEM_INTERACT_BLOCKING

/obj/structure/coat_rack/proc/hang_item_at(obj/item/thing, mob/living/user, list/slots, key)
	if(slots[key])
		balloon_alert(user, "already something there!")
		return ITEM_INTERACT_BLOCKING
	if(!user.transferItemToLoc(thing, src))
		return ITEM_INTERACT_BLOCKING
	slots[key] = thing
	visible_message(span_notice("[user] hangs [thing] on [src]."), span_notice("You hang [thing] on [src]."))
	update_appearance(UPDATE_OVERLAYS)
	return ITEM_INTERACT_SUCCESS

/obj/structure/coat_rack/interact(mob/living/user)
	. = ..()
	if(.)
		return

	var/list/slots = showing_hats ? hat_slots : body_slots

	var/static/image/body_placeholder
	var/static/image/hat_placeholder
	if(!body_placeholder)
		body_placeholder = create_silhouette_of(/obj/item/clothing/under/color/grey)
	if(!hat_placeholder)
		hat_placeholder = create_silhouette_of(/obj/item/clothing/head/soft/grey)
	var/image/placeholder = showing_hats ? hat_placeholder : body_placeholder

	var/list/choices = list()
	for(var/key in slots)
		var/obj/item/exists = slots[key]
		choices[key] = exists ? image(exists.icon, icon_state = exists.icon_state) : placeholder
	choices["flip"] = icon('icons/hud/radial.dmi', "radial_next")

	var/choice = show_radial_menu(
		user,
		src,
		choices,
		custom_check = CALLBACK(src, PROC_REF(check_interactable), user),
		require_near = TRUE,
		autopick_single_option = FALSE,
	)

	if(!choice)
		return

	if(choice == "flip")
		showing_hats = !showing_hats
		return interact(user)

	var/obj/item/exists = slots[choice]
	if(exists)
		slots[choice] = null
		try_put_in_hand(exists, user)
		update_appearance(UPDATE_OVERLAYS)
	else
		var/obj/item/held = user.get_active_held_item()
		var/matches_category = showing_hats ? istype(held, /obj/item/clothing/head) : is_body_slot_item(held)
		if(held && matches_category)
			hang_item_at(held, user, slots, choice)
		else if(held)
			balloon_alert(user, "wrong item for this slot!")

	return interact(user)

/obj/structure/coat_rack/proc/check_interactable(mob/user)
	return !QDELETED(src) && user.Adjacent(src)

/// Same fallback as /obj/machinery/proc/try_put_in_hand() (code/game/machinery/_machinery.dm)
/obj/structure/coat_rack/proc/try_put_in_hand(obj/item/hung, mob/living/user)
	visible_message(span_notice("[user] takes [hung] off [src]."), span_notice("You take [hung] off [src]."))
	hung.do_pickup_animation(user, src)
	if(!user.put_in_hands(hung))
		hung.forceMove(drop_location())

/// Taken from /obj/machinery/suit_storage_unit/proc/create_silhouette_of() (code/game/machinery/suit_storage_unit.dm)
/obj/structure/coat_rack/proc/create_silhouette_of(atom/item)
	var/image/silhouette = image(initial(item.icon), initial(item.icon_state))
	silhouette.alpha = 128
	silhouette.color = COLOR_RED
	return silhouette

/obj/structure/coat_rack/proc/get_hanger_tint_colors(obj/item/hung)
	if(hung.greyscale_colors) // GAGS colours
		var/list/split_colors = splittext(hung.greyscale_colors, "#")
		if(length(split_colors) >= 2)
			var/list/colors = list()
			for(var/i in 2 to length(split_colors))
				colors += "#[split_colors[i]]"
			return colors
	if(istext(hung.color)) // item colour
		return list(hung.color)
	var/sampled_color = sample_icon_color(hung.icon, hung.icon_state)
	if(sampled_color)
		return list(sampled_color)
	return null

/obj/structure/coat_rack/proc/sample_icon_color(icon_path, icon_state_name)
	var/icon/sample = icon(icon_path, icon_state_name)
	sample.Scale(1, 1)
	return sample.GetPixel(1, 1)

/obj/structure/coat_rack/update_overlays()
	. = ..()
	underlays = list()

	for(var/key in body_slots)
		var/obj/item/hung = body_slots[key]
		if(!hung)
			continue
		var/hung_state = body_slot_hung_states[key]
		var/mutable_appearance/hung_overlay = mutable_appearance(icon, hung_state)
		var/list/tint_colors = get_hanger_tint_colors(hung)
		if(tint_colors)
			hung_overlay.color = tint_colors[1]
		. += hung_overlay

		var/mutable_appearance/accent_overlay = mutable_appearance(icon, "[hung_state]_accent")
		if(tint_colors && length(tint_colors) >= 2)
			accent_overlay.color = tint_colors[2]
		. += accent_overlay

	for(var/key in hat_slots)
		var/obj/item/hung = hat_slots[key]
		if(!hung)
			continue
		var/offset = hat_slot_offsets[key]
		var/mutable_appearance/hat_overlay = mutable_appearance(hung.icon, hung.icon_state)
		hat_overlay.pixel_x = offset[1]
		hat_overlay.pixel_y = offset[2]
		hat_overlay.transform = matrix().Scale(hat_overlay_scale)
		if(key == "N")
			// move it behind the rack
			underlays += hat_overlay
		else
			// make sure stuff is in front of the rack
			hat_overlay.layer = layer + 0.1
			. += hat_overlay
