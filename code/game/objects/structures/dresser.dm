// META EDIT - CHANGE - START - UNDERWEAR_ITEMS
// Real storage now (composition via create_storage(), not /obj/structure/closet since this type's placed on many maps and can't be reparented), stocked with one of each real underwear item.
/obj/structure/dresser
	name = "dresser"
	desc = "A nicely-crafted wooden dresser. It's filled with lots of undies."
	icon = 'icons/obj/fluff/general.dmi'
	icon_state = "dresser"
	resistance_flags = FLAMMABLE
	density = TRUE
	anchored = TRUE
	custom_materials = list(/datum/material/wood = SHEET_MATERIAL_AMOUNT * 10)

/obj/structure/dresser/Initialize(mapload)
	. = ..()
	create_storage(max_slots = 28)
	if(mapload)
		PopulateContents()

/obj/structure/dresser/proc/PopulateContents()
	new /obj/item/clothing/underwear/underwear/male_briefs(src)
	new /obj/item/clothing/underwear/bra/bra(src)
	new /obj/item/clothing/underwear/undershirt/shirt_white(src)
	new /obj/item/clothing/underwear/socks/socks_norm(src)

/obj/structure/dresser/attackby(obj/item/attacking_item, mob/user, list/modifiers, list/attack_modifiers)
	if(attacking_item.tool_behaviour == TOOL_WRENCH)
		to_chat(user, span_notice("You begin to [anchored ? "unwrench" : "wrench"] [src]."))
		if(attacking_item.use_tool(src, user, 20, volume = 50))
			to_chat(user, span_notice("You successfully [anchored ? "unwrench" : "wrench"] [src]."))
			set_anchored(!anchored)
	else
		return ..()

/obj/structure/dresser/atom_deconstruct(disassembled = TRUE)
	new /obj/item/stack/sheet/mineral/wood(drop_location(), 10)

// META EDIT - ADDITION - UNDERWEAR_ITEMS: restores the old quick-pick menu as a convenience; runs only when create_storage()'s own attack_hand handler (storage.dm) declines. Spawns+equips real items instead of setting string vars.
/obj/structure/dresser/attack_hand(mob/user, list/modifiers)
	. = ..()
	if(.)
		return
	if(!Adjacent(user))
		return
	if(!ishuman(user))
		return
	var/mob/living/carbon/human/dressing_human = user
	if(HAS_TRAIT(dressing_human, TRAIT_NO_UNDERWEAR))
		to_chat(dressing_human, span_warning("You are not capable of wearing underwear."))
		return

	var/choice = tgui_input_list(user, "Underwear, Bra, Undershirt, or Socks?", "Changing", list("Underwear", "Underwear Color", "Bra", "Bra Color", "Undershirt", "Undershirt Color", "Socks", "Socks Color"))
	if(isnull(choice))
		return
	if(!Adjacent(user))
		return

	switch(choice)
		if("Underwear")
			var/new_undies = tgui_input_list(user, "Select your underwear", "Changing", get_underwear_items_by_name())
			if(new_undies)
				dressing_human.set_underwear(new_undies)
		if("Underwear Color")
			var/new_underwear_color = tgui_color_picker(dressing_human, "Choose your underwear color", "Underwear Color", dressing_human.underwear_color)
			if(new_underwear_color)
				dressing_human.underwear_color = sanitize_hexcolor(new_underwear_color)
				if(dressing_human.w_underwear && !dressing_human.w_underwear.use_static)
					dressing_human.w_underwear.color = dressing_human.underwear_color
					dressing_human.w_underwear.refresh_worn_appearance()
		if("Bra")
			var/new_bra = tgui_input_list(user, "Select your bra", "Changing", get_bra_items_by_name())
			if(new_bra)
				dressing_human.set_bra(new_bra)
		if("Bra Color")
			var/new_bra_color = tgui_color_picker(dressing_human, "Choose your bra color", "Bra Color", dressing_human.bra_color)
			if(new_bra_color)
				dressing_human.bra_color = sanitize_hexcolor(new_bra_color)
				if(dressing_human.w_bra && !dressing_human.w_bra.use_static)
					dressing_human.w_bra.color = dressing_human.bra_color
					dressing_human.w_bra.refresh_worn_appearance()
		if("Undershirt")
			var/new_undershirt = tgui_input_list(user, "Select your undershirt", "Changing", get_undershirt_items_by_name())
			if(new_undershirt)
				dressing_human.set_undershirt(new_undershirt)
		if("Undershirt Color")
			var/new_undershirt_color = tgui_color_picker(dressing_human, "Choose your undershirt color", "Undershirt Color", dressing_human.undershirt_color)
			if(new_undershirt_color)
				dressing_human.undershirt_color = sanitize_hexcolor(new_undershirt_color)
				if(dressing_human.w_undershirt && !dressing_human.w_undershirt.use_static)
					dressing_human.w_undershirt.color = dressing_human.undershirt_color
					dressing_human.w_undershirt.refresh_worn_appearance()
		if("Socks")
			var/new_socks = tgui_input_list(user, "Select your socks", "Changing", get_socks_items_by_name())
			if(new_socks)
				dressing_human.set_socks(new_socks)
		if("Socks Color")
			var/new_socks_color = tgui_color_picker(dressing_human, "Choose your socks color", "Socks Color", dressing_human.socks_color)
			if(new_socks_color)
				dressing_human.socks_color = sanitize_hexcolor(new_socks_color)
				if(dressing_human.w_socks && !dressing_human.w_socks.use_static)
					dressing_human.w_socks.color = dressing_human.socks_color
					dressing_human.w_socks.refresh_worn_appearance()

	add_fingerprint(dressing_human)
// META EDIT - CHANGE - END - UNDERWEAR_ITEMS
