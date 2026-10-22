/// Gag flavour text for tasting/smelling an atom. Stacks with reagent taste when both exist
/// ("tastes like water. It also tastes like you should have known better.").
///
/// Return the bit after "tastes/smells like ", without the word "like" itself.
/atom/proc/get_lick_flavor(mob/living/licker)
	return

/// See [/atom/proc/get_lick_flavor].
/atom/proc/get_smell_flavor(mob/living/sniffer)
	return


/obj/item/clothing/mask/gas/clown_hat/get_lick_flavor(mob/living/licker)
	return "greasepaint, rubber, and a joke that went on far too long"

/obj/item/clothing/mask/gas/clown_hat/get_smell_flavor(mob/living/sniffer)
	return "greasepaint and other people's desperation"

/// The mime mask shuts you up for a moment.
/obj/item/clothing/mask/gas/mime/get_lick_flavor(mob/living/licker)
	licker.apply_status_effect(/datum/status_effect/silenced, 10 SECONDS)
	licker.visible_message(
		span_notice("[licker] licks [src]. [licker.p_They()] open[licker.p_s()] [licker.p_their()] mouth to comment, and nothing comes out."),
		span_notice("You lick [src]. You open your mouth to comment, and nothing comes out."),
	)
	return "silence, somehow"

/obj/item/clothing/mask/gas/mime/get_smell_flavor(mob/living/sniffer)
	return "dust and a determination to be left alone"

/obj/item/toy/plush/get_lick_flavor(mob/living/licker)
	return "dust, old fabric, and unconditional love"

/obj/item/toy/plush/get_smell_flavor(mob/living/sniffer)
	return "dust and old fabric"

/obj/item/book/bible/get_lick_flavor(mob/living/licker)
	return "communion wine and judgement"

/obj/item/melee/baton/get_lick_flavor(mob/living/licker)
	return "copper and consequences"

/obj/item/soap/get_lick_flavor(mob/living/licker)
	return "soap, which raises several questions about what you expected"

/obj/item/gibtonite/get_lick_flavor(mob/living/licker)
	return "sulphur and bad decisions"

/obj/item/stack/ore/plasma/get_lick_flavor(mob/living/licker)
	return "licking a battery that hates you"

/obj/item/organ/tongue/get_lick_flavor(mob/living/licker)
	return "whoever used to own it"

/obj/item/organ/brain/get_lick_flavor(mob/living/licker)
	return "copper and unfinished homework"

/obj/structure/toilet/get_lick_flavor(mob/living/licker)
	return "you should have known better"

/obj/structure/toilet/get_smell_flavor(mob/living/sniffer)
	return "every mistake that led you here"

/obj/structure/urinal/get_lick_flavor(mob/living/licker)
	return "ammonia and poor life choices"

/obj/structure/urinal/get_smell_flavor(mob/living/sniffer)
	return "ammonia and regret"

/obj/machinery/disposal/get_lick_flavor(mob/living/licker)
	return "old banana peels and secrets people thought they'd flushed"

/obj/machinery/disposal/get_smell_flavor(mob/living/sniffer)
	return "warm rot and recycled air"

/obj/structure/closet/crate/bin/get_lick_flavor(mob/living/licker)
	return "yesterday's lunch and whoever didn't take the trash out"

/obj/structure/closet/crate/bin/get_smell_flavor(mob/living/sniffer)
	return "stale wrappers and neglect"

/obj/item/storage/bag/trash/get_lick_flavor(mob/living/licker)
	return "plastic and every shift's worst decisions"

/obj/item/storage/bag/trash/get_smell_flavor(mob/living/sniffer)
	return "warm plastic and old food"

/obj/effect/decal/cleanable/vomit/get_lick_flavor(mob/living/licker)
	return "someone else's bad night"

/obj/effect/decal/cleanable/vomit/get_smell_flavor(mob/living/sniffer)
	return "acid and poor judgement"

/obj/machinery/computer/get_lick_flavor(mob/living/licker)
	return "ozone and unresolved compile errors"

/obj/machinery/computer/get_smell_flavor(mob/living/sniffer)
	return "hot dust and ozone"
