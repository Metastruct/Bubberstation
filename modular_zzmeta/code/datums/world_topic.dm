/// Cache lifetime for a generated mugshot
#define META_HEADSHOT_CACHE_TIME 5 MINUTES

/mob/living
	/// Cached `data:image/png;base64,...` mugshot for the player list.
	var/meta_headshot_cache
	/// `world.time` the cache was built at.
	var/meta_headshot_cache_time = 0

/datum/world_topic/playerlist
	keyword = "playerlist"

/datum/world_topic/playerlist/Run(list/input)
	. = list()
	for(var/client/C as anything in GLOB.clients)
		var/mob/character = C.mob
		if(!istype(character) || isnewplayer(character) || !character.mind) // skip lobby/character-setup connections, nothing to report yet
			continue

		var/list/entry = list()
		entry["name"] = character.real_name || character.name
		entry["job"] = character.mind.assigned_role?.title
		entry["afk"] = !!C.is_afk()

		if(C.prefs?.read_preference(/datum/preference/toggle/chat_examine_headshot))
			var/headshot = meta_playerlist_headshot(character)
			if(headshot)
				entry["headshot"] = headshot

		. += list(entry)

/// A player-supplied headshot URL if the character has one, otherwise a freshly rendered
/// (and cached) mugshot data URI. Returns null when neither is available.
/proc/meta_playerlist_headshot(mob/character)
	if(!isliving(character))
		return null

	var/mob/living/living_character = character

	if(ishuman(living_character))
		var/mob/living/carbon/human/human = living_character
		var/uploaded = human.dna?.features?["headshot"]
		if(istext(uploaded) && length(uploaded))
			return uploaded
	else if(issilicon(living_character))
		var/mob/living/silicon/silicon = living_character
		if(istext(silicon.headshot_snapshot) && length(silicon.headshot_snapshot))
			return silicon.headshot_snapshot

	if(living_character.meta_headshot_cache && world.time < living_character.meta_headshot_cache_time + META_HEADSHOT_CACHE_TIME)
		return living_character.meta_headshot_cache

	// Force a south-facing render so the headshot is consistent regardless of where the
	// character happens to be looking (same trick as `record.make_photo()`).
	var/mutable_appearance/appearance = new(living_character.appearance)
	appearance.setDir(SOUTH)

	// `no_anim` keeps animated overlays (e.g. the typing indicator) from turning the flat
	// icon into a multi-frame icon, which `icon2base64()` would export as every frame tiled side by side.
	var/icon/rendered = getFlatIcon(appearance, no_anim = TRUE)
	if(!rendered || !rendered.Width() || !rendered.Height())
		return null

	var/result = "data:image/png;base64,[icon2base64(rendered)]"
	living_character.meta_headshot_cache = result
	living_character.meta_headshot_cache_time = world.time
	return result

#undef META_HEADSHOT_CACHE_TIME
