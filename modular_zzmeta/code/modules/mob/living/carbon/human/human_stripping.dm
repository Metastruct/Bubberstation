// Lets other players trigger a suit's alt-click behavior from the strip menu, not just the wearer.
/datum/strippable_item/mob_item_slot/suit/get_alternate_actions(atom/source, mob/user, obj/item/item)
	. = ..()
	var/obj/item/clothing/suit/suit = item
	if(!istype(suit))
		return
	if(can_adjust_suit(suit))
		. += "adjust_suit"

/datum/strippable_item/mob_item_slot/suit/perform_alternate_action(atom/source, mob/user, action_key, obj/item/item)
	if(!..())
		return
	if(action_key != "adjust_suit")
		return
	var/obj/item/clothing/suit/suit = item
	if(!istype(suit) || !can_adjust_suit(suit))
		return
	do_adjust_suit(source, user, suit)

/// Whether this suit has any known alt-click adjustment behavior (a toggle_icon component, or a bespoke click_alt override such as wintercoat zipping).
/datum/strippable_item/mob_item_slot/suit/proc/can_adjust_suit(obj/item/clothing/suit/suit)
	if(suit.GetComponent(/datum/component/toggle_icon))
		return TRUE
	var/obj/item/clothing/suit/hooded/wintercoat/coat = suit
	if(istype(coat) && coat.can_altclick_zip)
		return TRUE
	return FALSE

/datum/strippable_item/mob_item_slot/suit/proc/do_adjust_suit(atom/source, mob/user, obj/item/clothing/suit/suit)
	if(!user.Adjacent(source))
		source.balloon_alert(user, "can't reach!")
		return

	to_chat(source, span_notice("[user] is trying to adjust your [suit]."))
	if(!do_after(user, suit.strip_delay * 0.5, source))
		return
	to_chat(source, span_notice("[user] successfully adjusted your [suit]."))

	// Mirrors /mob/proc/base_click_alt's dispatch order: signal handlers first, then the click_alt() proc fallback.
	// The can_perform_action proc is skipped on purpose. Its reachability check assumes user is reaching into
	// their own inventory or a container with atom_storage, which a worn suit on another mob is not.
	if(SEND_SIGNAL(suit, COMSIG_CLICK_ALT, user) & CLICK_ACTION_ANY)
		return
	suit.click_alt(user)
