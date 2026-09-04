/// How much brute damage a failed army crawl exit deals to the head.
#define ARMY_CRAWL_BONK_DAMAGE 3

/// Stop letting a prone mob (army crawling, or a cortical borer hiding) stand back up into whatever dense obstruction it crawled under. Bonk its head instead and stay put.
/datum/component/prone_mob/stop_army_crawl(mob/living/source)
	SIGNAL_HANDLER
	source = parent
	var/turf/current_turf = get_turf(source)
	if(current_turf?.is_blocked_turf_ignore_climbable())
		source.visible_message(
			span_danger("[source] bonks their head trying to get up!"),
			span_userdanger("You bonk your head trying to get up!"),
		)
		playsound(source, 'modular_zubbers/code/modules/emotes/sound/effects/bonk.ogg', 50, TRUE)
		source.apply_damage(ARMY_CRAWL_BONK_DAMAGE, BRUTE, BODY_ZONE_HEAD)
		return
	parent.remove_traits(list(TRAIT_PRONE, TRAIT_FLOORED, TRAIT_NO_THROWING, TRAIT_HANDS_BLOCKED, TRAIT_IGNORE_ELEVATION), type)
	passtable_off(parent, type)
	source.layer = MOB_LAYER
	qdel(src)

#undef ARMY_CRAWL_BONK_DAMAGE
