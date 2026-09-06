/// Base type for underwear items. Concrete garment styles are generated
/// from the legacy /datum/sprite_accessory/clothing/* data, see generated/underwear_items.dm.
/obj/item/clothing/underwear
	name = "underwear"
	// modular_skyrat reopens the underwear accessories with this icon file, so it's every generated item's real resolved default.
	icon = 'modular_skyrat/master_files/icons/mob/clothing/underwear.dmi'
	worn_icon = 'modular_skyrat/master_files/icons/mob/clothing/underwear.dmi'
	lefthand_file = 'icons/mob/inhands/clothing/gloves_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/clothing/gloves_righthand.dmi'
	inhand_icon_state = "greyscale_gloves"
	abstract_type = /obj/item/clothing/underwear
	w_class = WEIGHT_CLASS_TINY
	resistance_flags = FLAMMABLE
	flags_cover = ALLOW_SURGERY_THROUGH
	/// Whether the "_d" digitigrade icon-state suffix exists for this garment and should be used on digitigrade wearers.
	var/has_digitigrade = FALSE
	/// Gender-shaping flags used when cropping this garment's sprite for a female wearer.
	var/female_sprite_flags = FEMALE_UNIFORM_FULL
	/// If TRUE, this garment's art is already fully colored and should ignore its own .color when rendering.
	var/use_static = FALSE

/obj/item/clothing/underwear/mob_can_equip(mob/living/user, slot, disable_warning = FALSE, bypass_equip_delay_self = FALSE, ignore_equipped = FALSE, indirect_action = FALSE)
	if(HAS_TRAIT(user, TRAIT_NO_UNDERWEAR))
		if(!disable_warning)
			to_chat(user, span_warning("You are not capable of wearing that!"))
		return FALSE
	return ..()

/// Clicking the underwear while holding it lets you recolor it.
/obj/item/clothing/underwear/attack_self(mob/user)
	. = ..()
	if(use_static)
		balloon_alert(user, "can't be recolored!")
		return
	var/new_color = tgui_color_picker(user, "", "Choose Color", color)
	if(!new_color || !user.can_perform_action(src) || new_color == color)
		return
	color = new_color
	refresh_worn_appearance()
	balloon_alert(user, "color changed")

/// If currently equipped, re-renders the worn overlay so a color change shows up immediately.
/obj/item/clothing/underwear/proc/refresh_worn_appearance()
	if(!ishuman(loc))
		return
	var/mob/living/carbon/human/wearer = loc
	if(wearer.w_underwear == src)
		wearer.update_worn_underwear()
	else if(wearer.w_bra == src)
		wearer.update_worn_bra()
	else if(wearer.w_undershirt == src)
		wearer.update_worn_undershirt()
	else if(wearer.w_socks == src)
		wearer.update_worn_socks()

/obj/item/clothing/underwear/underwear
	name = "underwear"
	abstract_type = /obj/item/clothing/underwear/underwear
	slot_flags = ITEM_SLOT_UNDERWEAR
	// The default quick-equip ("E" hotkey) / equip_to_best_slot() priority list in
	// code/modules/mob/inventory.dm doesn't know about the four new slots this feature adds,
	// so each category sets its own single-entry priority instead of relying on it.
	slot_equipment_priority = list(ITEM_SLOT_UNDERWEAR)
	body_parts_covered = GROIN

/obj/item/clothing/underwear/bra
	name = "bra"
	abstract_type = /obj/item/clothing/underwear/bra
	slot_flags = ITEM_SLOT_BRA
	slot_equipment_priority = list(ITEM_SLOT_BRA)
	body_parts_covered = CHEST

/obj/item/clothing/underwear/undershirt
	name = "undershirt"
	abstract_type = /obj/item/clothing/underwear/undershirt
	slot_flags = ITEM_SLOT_UNDERSHIRT
	slot_equipment_priority = list(ITEM_SLOT_UNDERSHIRT)
	body_parts_covered = CHEST | ARMS

/obj/item/clothing/underwear/socks
	name = "socks"
	abstract_type = /obj/item/clothing/underwear/socks
	slot_flags = ITEM_SLOT_SOCKS
	slot_equipment_priority = list(ITEM_SLOT_SOCKS)
	body_parts_covered = FEET

/**
 * Maps an accessory display name (e.g. "Boxers, Bee") to its item typepath, for each of the
 * four garment categories. Lazily built and cached on first call from the compiled item type
 * tree (subtypesof()), which is always fully available regardless of subsystem boot order.
 * Deliberately not a GLOB list populated during SSaccessories/PreInit(): that PreInit() runs
 * inside Master.New()'s subsystem-creation loop, which happens BEFORE GLOB itself is
 * instantiated (see code/controllers/master.dm), so GLOB is still null at that point.
 */
/proc/get_underwear_items_by_name()
	var/static/list/cache
	if(isnull(cache))
		cache = list()
		for(var/obj/item/clothing/underwear/underwear/item_type as anything in subtypesof(/obj/item/clothing/underwear/underwear))
			if(initial(item_type.abstract_type) == item_type)
				continue
			cache[initial(item_type.name)] = item_type
	return cache

/proc/get_bra_items_by_name()
	var/static/list/cache
	if(isnull(cache))
		cache = list()
		for(var/obj/item/clothing/underwear/bra/item_type as anything in subtypesof(/obj/item/clothing/underwear/bra))
			if(initial(item_type.abstract_type) == item_type)
				continue
			cache[initial(item_type.name)] = item_type
	return cache

/proc/get_undershirt_items_by_name()
	var/static/list/cache
	if(isnull(cache))
		cache = list()
		for(var/obj/item/clothing/underwear/undershirt/item_type as anything in subtypesof(/obj/item/clothing/underwear/undershirt))
			if(initial(item_type.abstract_type) == item_type)
				continue
			cache[initial(item_type.name)] = item_type
	return cache

/proc/get_socks_items_by_name()
	var/static/list/cache
	if(isnull(cache))
		cache = list()
		for(var/obj/item/clothing/underwear/socks/item_type as anything in subtypesof(/obj/item/clothing/underwear/socks))
			if(initial(item_type.abstract_type) == item_type)
				continue
			cache[initial(item_type.name)] = item_type
	return cache

/// Sets a human's underwear to the named style ("Nude" or null removes it), preserving any existing color if the new item isn't use_static.
/mob/living/carbon/human/proc/set_underwear(garment_name)
	if(w_underwear)
		qdel(w_underwear)
	if(isnull(garment_name) || garment_name == "Nude")
		return
	var/item_type = get_underwear_items_by_name()[garment_name]
	if(!item_type)
		return
	var/obj/item/clothing/underwear/underwear/new_item = new item_type()
	if(!new_item.use_static)
		new_item.color = underwear_color
	equip_to_slot_or_del(new_item, ITEM_SLOT_UNDERWEAR, TRUE, indirect_action = TRUE)

/mob/living/carbon/human/proc/set_bra(garment_name)
	if(w_bra)
		qdel(w_bra)
	if(isnull(garment_name) || garment_name == "Nude")
		return
	var/item_type = get_bra_items_by_name()[garment_name]
	if(!item_type)
		return
	var/obj/item/clothing/underwear/bra/new_item = new item_type()
	if(!new_item.use_static)
		new_item.color = bra_color
	equip_to_slot_or_del(new_item, ITEM_SLOT_BRA, TRUE, indirect_action = TRUE)

/mob/living/carbon/human/proc/set_undershirt(garment_name)
	if(w_undershirt)
		qdel(w_undershirt)
	if(isnull(garment_name) || garment_name == "Nude")
		return
	var/item_type = get_undershirt_items_by_name()[garment_name]
	if(!item_type)
		return
	var/obj/item/clothing/underwear/undershirt/new_item = new item_type()
	if(!new_item.use_static)
		new_item.color = undershirt_color
	equip_to_slot_or_del(new_item, ITEM_SLOT_UNDERSHIRT, TRUE, indirect_action = TRUE)

/mob/living/carbon/human/proc/set_socks(garment_name)
	if(w_socks)
		qdel(w_socks)
	if(isnull(garment_name) || garment_name == "Nude")
		return
	var/item_type = get_socks_items_by_name()[garment_name]
	if(!item_type)
		return
	var/obj/item/clothing/underwear/socks/new_item = new item_type()
	if(!new_item.use_static)
		new_item.color = socks_color
	equip_to_slot_or_del(new_item, ITEM_SLOT_SOCKS, TRUE, indirect_action = TRUE)

/// Removes and deletes all four underwear-category items, if any are worn.
/mob/living/carbon/human/proc/remove_all_underwear_items()
	set_underwear("Nude")
	set_bra("Nude")
	set_undershirt("Nude")
	set_socks("Nude")

/// Applies underwear/bra/undershirt/socks style + color preferences from the given prefs datum onto this human, without touching anything else (body, loadout, other clothing).
/mob/living/carbon/human/proc/apply_underwear_prefs(datum/preferences/preference_source)
	if(!preference_source)
		return
	// Colors are read onto the mob first since set_*() build their new garment's color from these vars.
	underwear_color = preference_source.read_preference(/datum/preference/color/underwear_color)
	bra_color = preference_source.read_preference(/datum/preference/color/bra_color)
	undershirt_color = preference_source.read_preference(/datum/preference/color/undershirt_color)
	socks_color = preference_source.read_preference(/datum/preference/color/socks_color)
	set_underwear(preference_source.read_preference(/datum/preference/choiced/underwear))
	set_bra(preference_source.read_preference(/datum/preference/choiced/bra))
	set_undershirt(preference_source.read_preference(/datum/preference/choiced/undershirt))
	set_socks(preference_source.read_preference(/datum/preference/choiced/socks))
