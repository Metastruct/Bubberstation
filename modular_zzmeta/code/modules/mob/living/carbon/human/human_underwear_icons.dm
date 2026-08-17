/// New overlays_standing slots for the four underwear-category items. Values are plain
/// integers appended after the existing TOTAL_LAYERS range (see code/__DEFINES/mobs.dm),
/// not related to the visual draw layer used on the rendered appearance itself (which stays
/// -BODY_LAYER for all four, matching the legacy cosmetic system's stacking exactly).
#define UNDERWEAR_LAYER 30
#define BRA_LAYER 31
#define UNDERSHIRT_LAYER 32
#define SOCKS_LAYER 33

/mob/living/carbon/human/regenerate_icons()
	. = ..()
	update_worn_underwear()
	update_worn_bra()
	update_worn_undershirt()
	update_worn_socks()
	// Re-evaluates the 4 HUD slots' visibility too, since spawn-time equips don't reliably trigger it on their own.
	hud_used?.update_locked_slots()

/mob/living/carbon/human/proc/update_worn_underwear()
	remove_overlay(UNDERWEAR_LAYER)
	hud_used?.update_inventory_slot(ITEM_SLOT_UNDERWEAR)
	if(HAS_TRAIT(src, TRAIT_HUSK) || HAS_TRAIT(src, TRAIT_INVISIBLE_MAN) || HAS_TRAIT(src, TRAIT_NO_UNDERWEAR))
		return
	if(w_underwear)
		var/obj/item/clothing/underwear/underwear/worn_item = w_underwear
		var/underwear_icon_state = worn_item.icon_state
		var/mutable_appearance/underwear_overlay
		var/female_sprite_flags = FEMALE_UNIFORM_FULL
		if(worn_item.has_digitigrade && (bodyshape & BODYSHAPE_DIGITIGRADE))
			underwear_icon_state += "_d"
			female_sprite_flags = FEMALE_UNIFORM_TOP_ONLY
		if(dna.species.sexes && physique == FEMALE && worn_item.gender == MALE)
			underwear_overlay = mutable_appearance(wear_female_version(underwear_icon_state, worn_item.icon, female_sprite_flags), layer = -BODY_LAYER)
		else
			underwear_overlay = mutable_appearance(worn_item.icon, underwear_icon_state, -BODY_LAYER)
		if(!worn_item.use_static)
			underwear_overlay.color = worn_item.color
		overlays_standing[UNDERWEAR_LAYER] = underwear_overlay
	apply_overlay(UNDERWEAR_LAYER)

/mob/living/carbon/human/proc/update_worn_bra()
	remove_overlay(BRA_LAYER)
	hud_used?.update_inventory_slot(ITEM_SLOT_BRA)
	if(HAS_TRAIT(src, TRAIT_HUSK) || HAS_TRAIT(src, TRAIT_INVISIBLE_MAN) || HAS_TRAIT(src, TRAIT_NO_UNDERWEAR))
		return
	if(w_bra)
		var/obj/item/clothing/underwear/bra/worn_item = w_bra
		var/mutable_appearance/bra_overlay = mutable_appearance(worn_item.icon, worn_item.icon_state, -BODY_LAYER)
		if(!worn_item.use_static)
			bra_overlay.color = worn_item.color
		overlays_standing[BRA_LAYER] = bra_overlay
	apply_overlay(BRA_LAYER)

/mob/living/carbon/human/proc/update_worn_undershirt()
	remove_overlay(UNDERSHIRT_LAYER)
	hud_used?.update_inventory_slot(ITEM_SLOT_UNDERSHIRT)
	if(HAS_TRAIT(src, TRAIT_HUSK) || HAS_TRAIT(src, TRAIT_INVISIBLE_MAN) || HAS_TRAIT(src, TRAIT_NO_UNDERWEAR))
		return
	if(w_undershirt)
		var/obj/item/clothing/underwear/undershirt/worn_item = w_undershirt
		var/mutable_appearance/undershirt_overlay
		if(dna.species.sexes && physique == FEMALE)
			undershirt_overlay = mutable_appearance(wear_female_version(worn_item.icon_state, worn_item.icon), layer = -BODY_LAYER)
		else
			undershirt_overlay = mutable_appearance(worn_item.icon, worn_item.icon_state, -BODY_LAYER)
		if(!worn_item.use_static)
			undershirt_overlay.color = worn_item.color
		overlays_standing[UNDERSHIRT_LAYER] = undershirt_overlay
	apply_overlay(UNDERSHIRT_LAYER)

/mob/living/carbon/human/proc/update_worn_socks()
	remove_overlay(SOCKS_LAYER)
	hud_used?.update_inventory_slot(ITEM_SLOT_SOCKS)
	if(HAS_TRAIT(src, TRAIT_HUSK) || HAS_TRAIT(src, TRAIT_INVISIBLE_MAN) || HAS_TRAIT(src, TRAIT_NO_UNDERWEAR))
		return
	if(w_socks && num_legs >= 2 && !dna.species.mutant_bodyparts[FEATURE_TAUR])
		var/obj/item/clothing/underwear/socks/worn_item = w_socks
		var/socks_icon_state = worn_item.icon_state
		if(bodyshape & BODYSHAPE_DIGITIGRADE)
			socks_icon_state += "_d"
		var/mutable_appearance/socks_overlay = mutable_appearance(worn_item.icon, socks_icon_state, -BODY_LAYER)
		if(!worn_item.use_static)
			socks_overlay.color = worn_item.color
		overlays_standing[SOCKS_LAYER] = socks_overlay
	apply_overlay(SOCKS_LAYER)

/// Returns the currently-rendered underwear/bra/undershirt/socks overlays (whichever are worn), for
/// external code (e.g. lewd furniture) that needs to composite them without reaching into the
/// individual overlays_standing slots directly.
/mob/living/carbon/human/proc/get_underwear_category_overlays()
	var/list/overlays = list()
	if(overlays_standing[UNDERWEAR_LAYER])
		overlays += overlays_standing[UNDERWEAR_LAYER]
	if(overlays_standing[BRA_LAYER])
		overlays += overlays_standing[BRA_LAYER]
	if(overlays_standing[UNDERSHIRT_LAYER])
		overlays += overlays_standing[UNDERSHIRT_LAYER]
	if(overlays_standing[SOCKS_LAYER])
		overlays += overlays_standing[SOCKS_LAYER]
	return overlays

#undef UNDERWEAR_LAYER
#undef BRA_LAYER
#undef UNDERSHIRT_LAYER
#undef SOCKS_LAYER
