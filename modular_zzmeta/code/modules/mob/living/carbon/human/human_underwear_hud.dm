// A 4th row above the existing grid, reusing its 3 columns rather than adding new ones (safe span is WEST:6-WEST+2:10; going wider breaks tight aspect ratios like Square 15x15). Socks reuses the one pre-existing free cell (WEST+2:10,SOUTH+3:11).
#define ui_undershirt "WEST:6,SOUTH+4:13"
#define ui_bra "WEST+1:8,SOUTH+4:13"
#define ui_underwear "WEST+2:10,SOUTH+4:13"
#define ui_socks "WEST+2:10,SOUTH+3:11"

// The box background now uses the player's actual UI style skin (icons/hud/screen_*.dmi, "template" state, same as every other slot's filled state) via inherit_style, so it re-skins for free. Only the category icon on top (drawn when empty) comes from our own dedicated file, tinted to the theme color since we don't have a full art set per skin.
/atom/movable/screen/inventory/underwear_slot
	/// icon_state, from modular_zzmeta/icons/hud/underwear_slots.dmi, to draw over the template box when empty, so it still shows what garment goes here rather than a blank box, matching how other slots' empty-state art works.
	var/category_icon_state

/// The item-in-slot overlay (vis_contents) already shows the real garment when filled, so the category icon only needs to draw when empty. Recomputes the tint fresh each call, so it stays correct across UI style switches without needing a separate update hook.
/atom/movable/screen/inventory/underwear_slot/update_overlays()
	. = ..()
	if(!category_icon_state)
		return
	if(hud?.mymob && slot_id && hud.mymob.get_item_by_slot(slot_id))
		return
	var/mutable_appearance/category_overlay = mutable_appearance('modular_zzmeta/icons/hud/underwear_slots.dmi', category_icon_state)
	category_overlay.color = get_underwear_slot_theme_color(hud?.mymob)
	. += category_overlay

/// Mirrors the theme mapping /obj/item/proc/apply_outline() (code/game/objects/items.dm) uses for its hover-outline color.
/proc/get_underwear_slot_theme_color(mob/user)
	var/theme = LOWER_TEXT(user?.client?.prefs?.read_preference(/datum/preference/choiced/ui_style))
	switch(theme)
		if("midnight")
			return COLOR_THEME_MIDNIGHT
		if("plasmafire")
			return COLOR_THEME_PLASMAFIRE
		if("retro")
			return COLOR_THEME_RETRO
		if("slimecore")
			return COLOR_THEME_SLIMECORE
		if("operative")
			return COLOR_THEME_OPERATIVE
		if("clockwork")
			return COLOR_THEME_CLOCKWORK
		if("glass")
			return COLOR_THEME_GLASS
		if("trasen-knox")
			return COLOR_THEME_TRASENKNOX
		if("detective")
			return COLOR_THEME_DETECTIVE
	return COLOR_WHITE

/datum/inventory_slot/human/underwear_category
	abstract_type = /datum/inventory_slot/human/underwear_category
	icon_full = "template"
	screen_type = /atom/movable/screen/inventory/underwear_slot
	screen_group = HUD_GROUP_TOGGLEABLE_INVENTORY
	/// Which of underwear_slots.dmi's states this slot shows (as an overlay over the template box) when empty.
	var/category_icon_state

/datum/inventory_slot/human/underwear_category/create_element(datum/hud/hud)
	var/atom/movable/screen/inventory/underwear_slot/inv_box = ..()
	inv_box.category_icon_state = category_icon_state
	return inv_box

/// update_ui_style() swaps .icon for the box (now handled for free via inherit_style), but doesn't know to refresh our category-icon overlay's tint, so force that here.
/datum/hud/human/update_ui_style(new_ui_style)
	. = ..()
	if(!mymob)
		return
	for(var/slot_id in list(ITEM_SLOT_UNDERWEAR, ITEM_SLOT_BRA, ITEM_SLOT_UNDERSHIRT, ITEM_SLOT_SOCKS))
		var/atom/movable/screen/inventory/inv = screen_objects[HUD_KEY_ITEM_SLOT(slot_id)]
		inv?.update_appearance(UPDATE_OVERLAYS)

/datum/inventory_slot/human/underwear_category/underwear
	name = "underwear"
	category_icon_state = "underwear"
	screen_loc = ui_underwear
	slot_id = ITEM_SLOT_UNDERWEAR

/datum/inventory_slot/human/underwear_category/bra
	name = "bra"
	category_icon_state = "bra"
	screen_loc = ui_bra
	slot_id = ITEM_SLOT_BRA

/datum/inventory_slot/human/underwear_category/undershirt
	name = "undershirt"
	category_icon_state = "undershirt"
	screen_loc = ui_undershirt
	slot_id = ITEM_SLOT_UNDERSHIRT

/datum/inventory_slot/human/underwear_category/socks
	name = "socks"
	category_icon_state = "socks"
	screen_loc = ui_socks
	slot_id = ITEM_SLOT_SOCKS

#undef ui_underwear
#undef ui_bra
#undef ui_undershirt
#undef ui_socks

/// Only shows these 4 slots when there's no uniform/suit covering them. Alpha alone isn't enough: the toggle button re-adds the whole group to client.screen on open regardless of alpha, so covered slots need pulling out of the group (and client.screen, if already open) instead.
/datum/hud/human/update_locked_slots()
	. = ..()
	var/mob/living/carbon/human/human_mob = mymob
	if(!istype(human_mob))
		return
	var/covered = (human_mob.w_uniform || human_mob.wear_suit)
	for(var/slot_id in list(ITEM_SLOT_UNDERWEAR, ITEM_SLOT_BRA, ITEM_SLOT_UNDERSHIRT, ITEM_SLOT_SOCKS))
		var/atom/movable/screen/inventory/inv = screen_objects[HUD_KEY_ITEM_SLOT(slot_id)]
		if(!inv)
			continue
		if(covered)
			screen_groups[HUD_GROUP_TOGGLEABLE_INVENTORY] -= inv
			mymob.client?.screen -= inv
		else
			if(!(inv in screen_groups[HUD_GROUP_TOGGLEABLE_INVENTORY]))
				screen_groups[HUD_GROUP_TOGGLEABLE_INVENTORY] += inv
			if(inventory_shown)
				mymob.client?.screen += inv
