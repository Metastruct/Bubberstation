/datum/emote/living/carbon/lick
	key = "lick"
	key_third_person = "licks"
	can_use_flags = EMOTE_CANUSE_REQUIRE_HANDS
	cooldown = 3 SECONDS

/datum/emote/living/carbon/lick/run_emote(mob/user, params, type_override, intentional)
	. = ..()
	if(user.is_holding_item_of_type(/obj/item/hand_item/tongue/licker))
		to_chat(user, span_notice("You already have your tongue ready."))
		return
	var/obj/item/hand_item/tongue/licker/tongue_item = new(user)
	if(user.put_in_hands(tongue_item))
		to_chat(user, span_notice("You stick your tongue out, ready to taste something."))
	else
		qdel(tongue_item)
		to_chat(user, span_warning("You're incapable of licking in your current state."))

/datum/emote/living/carbon/smell
	key = "smell"
	key_third_person = "smells"
	can_use_flags = EMOTE_CANUSE_REQUIRE_HANDS
	cooldown = 3 SECONDS

/datum/emote/living/carbon/smell/run_emote(mob/user, params, type_override, intentional)
	. = ..()
	if(user.is_holding_item_of_type(/obj/item/hand_item/tongue/sniffer))
		to_chat(user, span_notice("You already have your nose ready."))
		return
	var/obj/item/hand_item/tongue/sniffer/nose_item = new(user)
	if(user.put_in_hands(nose_item))
		to_chat(user, span_notice("You lean in, ready to take a whiff of something."))
	else
		qdel(nose_item)
		to_chat(user, span_warning("You're incapable of smelling in your current state."))
