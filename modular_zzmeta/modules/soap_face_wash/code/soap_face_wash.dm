#define SOAP_WASH_EYES_DELAY (2 SECONDS)
#define SOAP_WASH_MOUTH_DELAY (3 SECONDS)
#define SOAP_WASH_EYES_BLIND_DURATION (3 SECONDS)
#define SOAP_WASH_EYES_BLUR_DURATION (6 SECONDS)
#define SOAP_WASH_MOUTH_DURATION (45 SECONDS)

/proc/soap_wash_attempt_eyes(obj/item/washing_item, mob/living/carbon/target, mob/living/user)
	if(!target.get_organ_slot(ORGAN_SLOT_EYES))
		washing_item.balloon_alert(user, "no eyes!")
		return ITEM_INTERACT_BLOCKING

	if(target.is_eyes_covered())
		washing_item.balloon_alert(user, "eyes covered!")
		return ITEM_INTERACT_BLOCKING

	washing_item.balloon_alert(user, "washing eyes...")
	target.visible_message(
		span_danger("[user] starts scrubbing at [target]'s eyes with \the [washing_item]!"),
		span_userdanger("[user] starts scrubbing at your eyes with \the [washing_item]!"),
	)
	if(!do_after(user, SOAP_WASH_EYES_DELAY, target))
		return ITEM_INTERACT_BLOCKING

	if(target.is_eyes_covered())
		return ITEM_INTERACT_BLOCKING

	target.visible_message(
		span_danger("[user] scrubs [target]'s eyes with \the [washing_item]!"),
		span_userdanger("Your eyes sting terribly!"),
	)
	target.set_temp_blindness_if_lower(SOAP_WASH_EYES_BLIND_DURATION)
	target.set_eye_blur_if_lower(SOAP_WASH_EYES_BLUR_DURATION)
	log_combat(user, target, "washed the eyes of", washing_item)
	return ITEM_INTERACT_SUCCESS

/proc/soap_wash_attempt_mouth(obj/item/washing_item, mob/living/carbon/target, mob/living/user)
	if(target.is_mouth_covered())
		washing_item.balloon_alert(user, "mouth covered!")
		return ITEM_INTERACT_BLOCKING

	washing_item.balloon_alert(user, "washing mouth...")
	target.visible_message(
		span_danger("[user] tries to shove \the [washing_item] into [target]'s mouth!"),
		span_userdanger("[user] tries to shove \the [washing_item] into your mouth!"),
	)
	if(!do_after(user, SOAP_WASH_MOUTH_DELAY, target))
		return ITEM_INTERACT_BLOCKING

	if(target.is_mouth_covered())
		return ITEM_INTERACT_BLOCKING

	target.visible_message(
		span_danger("[user] washes out [target]'s mouth with \the [washing_item]!"),
		span_userdanger("[user] washes your mouth out with \the [washing_item]! Blech!"),
	)
	target.set_timed_status_effect(SOAP_WASH_MOUTH_DURATION, /datum/status_effect/soapy_mouth, only_if_higher = TRUE)
	log_combat(user, target, "washed the mouth of", washing_item)
	return ITEM_INTERACT_SUCCESS

/obj/item/soap/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(iscarbon(interacting_with) && interacting_with != user)
		var/mob/living/carbon/carbon_target = interacting_with
		switch(user.zone_selected)
			if(BODY_ZONE_PRECISE_EYES)
				return soap_wash_attempt_eyes(src, carbon_target, user)
			if(BODY_ZONE_PRECISE_MOUTH)
				return soap_wash_attempt_mouth(src, carbon_target, user)
	return ..()

#undef SOAP_WASH_EYES_DELAY
#undef SOAP_WASH_MOUTH_DELAY
#undef SOAP_WASH_EYES_BLIND_DURATION
#undef SOAP_WASH_EYES_BLUR_DURATION
#undef SOAP_WASH_MOUTH_DURATION
