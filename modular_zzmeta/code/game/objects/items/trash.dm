/obj/item/trash/can/food
	hitsound = 'modular_zzmeta/sound/items/can_hit.ogg'
	item_flags = SKIP_FANTASY_ON_SPAWN

/obj/item/trash/can/Initialize(mapload)
	. = ..()
	pixel_x = rand(-4,4)
	pixel_y = rand(-4,4)
	ADD_TRAIT(src, TRAIT_CUSTOM_TAP_SOUND, INNATE_TRAIT)
