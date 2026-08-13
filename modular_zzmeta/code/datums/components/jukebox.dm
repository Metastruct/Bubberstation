GLOBAL_LIST_EMPTY_TYPED(jukebox_datums, /datum/jukebox)

/datum/jukebox/New(atom/new_parent)
	. = ..()
	GLOB.jukebox_datums += src

/datum/jukebox/Destroy()
	GLOB.jukebox_datums -= src
	return ..()

/// Applies a freshly rescanned track list (see rescan_jukebox_songs()) to this jukebox.
/datum/jukebox/proc/reload_songs(list/datum/track/fresh_songs)
	songs = fresh_songs
	if(selection && !(selection.song_name in songs))
		selection = length(songs) ? songs[pick(songs)] : null

/**
 * Scans CONFIG_JUKEBOX_SOUNDS fresh off disk every call, independent of the memoized
 * cache load_songs_from_config() keeps in its local var/static. That cache has no
 * external reset hook, so newly uploaded tracks never appear on existing jukeboxes
 * without this. Used by the "Reload Jukebox Music" admin verb.
 */
/proc/rescan_jukebox_songs()
	var/list/fresh_songs = list()
	var/list/tracks = flist(CONFIG_JUKEBOX_SOUNDS)
	for(var/track_file in tracks)
		var/datum/track/new_track = new()
		new_track.song_path = file("[CONFIG_JUKEBOX_SOUNDS][track_file]")
		var/list/track_data = splittext(track_file, "+")
		if(!length(track_data) || !IS_SOUND_FILE_SAFE(new_track.song_path))
			continue
		var/track_name = track_data[JUKEBOX_NAME]
		track_name = strip_filepath_extension(track_name, SSsounds.safe_formats)
		new_track.song_name = track_name
		new_track.song_length = SSsounds.get_sound_length(new_track.song_path)
		if(track_data.len >= 3) // Bandaid for legacy tracks to not use the length for the bpm rather then the actual beats.
			var/static/logged_to_admins = FALSE
			log_game("[new_track.song_path] track data seems to be using the legacy format; we will attempt to make it work.")
			if(!logged_to_admins)
				message_admins("The jukebox has tracks uploaded in a legacy format. Length is now fetched programmatically, with title and beats being the only required fields.")
				logged_to_admins = TRUE
			new_track.song_beat_deciseconds = text2num(track_data[3])
		else if(track_data.len >= 2)
			new_track.song_beat_deciseconds = text2num(track_data[JUKEBOX_BEATS])
		fresh_songs[new_track.song_name] = new_track

	if(!length(fresh_songs))
		var/datum/track/default/default_track = new()
		fresh_songs[default_track.song_name] = default_track

	return fresh_songs
