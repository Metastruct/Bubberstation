/// How much brute damage a failed army crawl exit deals to the head.
#define ARMY_CRAWL_BONK_DAMAGE 3

/mob/living/proc/is_stuck_under_furniture()
	var/turf/current_turf = get_turf(src)
	if(!current_turf)
		return FALSE
	if(current_turf.density)
		return TRUE
	for(var/atom/movable/blocker as anything in current_turf.contents)
		if(blocker == src || ismob(blocker))
			continue
		if(blocker.density)
			return TRUE
	return FALSE

/// Stop letting a prone mob (army crawling, or a cortical borer hiding) stand back up into whatever dense obstruction it crawled under. Bonk its head instead and stay put.
/datum/component/prone_mob/stop_army_crawl(mob/living/source)
	SIGNAL_HANDLER
	source = parent
	if(source.is_stuck_under_furniture())
		source.visible_message(
			span_danger("[source] bonks their head trying to get up!"),
			span_userdanger("You bonk your head trying to get up!"),
		)
		playsound(source, 'sound/effects/hit_kick.ogg', 50, TRUE)
		source.apply_damage(ARMY_CRAWL_BONK_DAMAGE, BRUTE, BODY_ZONE_HEAD)
		return
	parent.remove_traits(list(TRAIT_PRONE, TRAIT_FLOORED, TRAIT_NO_THROWING, TRAIT_HANDS_BLOCKED, TRAIT_IGNORE_ELEVATION), type)
	passtable_off(parent, type)
	source.layer = MOB_LAYER
	qdel(src)

#undef ARMY_CRAWL_BONK_DAMAGE
