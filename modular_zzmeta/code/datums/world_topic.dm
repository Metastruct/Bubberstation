/// Cache lifetime for a generated mugshot
#define META_HEADSHOT_CACHE_TIME 2 MINUTES

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
		entry["ckey"] = C.ckey

		if(C.prefs?.read_preference(/datum/preference/toggle/chat_examine_headshot))
			var/headshot = meta_playerlist_headshot(character)
			if(headshot)
				entry["headshot"] = headshot

		. += list(entry)

/proc/get_genital_overlay_icons(mob/living/carbon/human/human)
	var/list/genital_icons = list()
	for(var/obj/item/bodypart/bodypart as anything in human.bodyparts)
		for(var/datum/bodypart_overlay/mutant/genital/genital_overlay in bodypart.bodypart_overlays)
			var/icon_file = genital_overlay.sprite_datum?.get_special_icon(human)
			if(icon_file)
				genital_icons[icon_file] = TRUE
	return genital_icons

/proc/strip_overlay_icons(list/overlays, list/blocked_icons)
	var/list/kept = list()
	for(var/mutable_appearance/overlay as anything in overlays)
		if(blocked_icons[overlay.icon])
			continue
		if(length(overlay.overlays))
			var/mutable_appearance/copy = new(overlay)
			copy.overlays = strip_overlay_icons(overlay.overlays, blocked_icons)
			kept += copy
		else
			kept += overlay
	return kept

/// A player-supplied headshot URL if the character has one, otherwise a freshly rendered
/// (and cached) mugshot data URI. Returns null when neither is available.
/proc/meta_playerlist_headshot(mob/character)
	if(!isliving(character))
		return null

	var/mob/living/living_character = character

	if(ishuman(living_character))
		var/mob/living/carbon/human/human = living_character
		var/uploaded = human.dna?.features?["headshot"]
		if(istext(uploaded) && length(uploaded)) return uploaded
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

	if(ishuman(living_character))
		var/list/genital_icons = get_genital_overlay_icons(living_character)
		if(length(genital_icons) && length(appearance.overlays))
			appearance.overlays = strip_overlay_icons(appearance.overlays, genital_icons)

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
