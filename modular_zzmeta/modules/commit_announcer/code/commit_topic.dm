/// Commits announced via /datum/world_topic/commits since the last summary print, so we can recap them before the next reboot.
GLOBAL_LIST_EMPTY(pending_commit_announcements)

/datum/world_topic/commits
	keyword = "commits"

/datum/world_topic/commits/Run(list/input)
	var/data_raw = input["data"]
	if(!data_raw)
		return "No data"
	var/list/commits = json_decode(data_raw)
	if(!islist(commits) || !length(commits))
		return "Invalid data"
	var/branch = input["branch"] || "unknown"
	for(var/list/commit in commits)
		var/author = commit["author"] || "unknown"
		var/message = commit["message"] || ""
		var/hash = commit["hash"] || ""
		var/short_hash = copytext(hash, 1, 8)
		to_chat(world, span_boldannounce("COMMIT ([short_hash]) \[[branch]\] by [html_encode(author)]: [html_encode(message)]"))
		GLOB.pending_commit_announcements += "[short_hash] \[[branch]\] by [html_encode(author)]: [html_encode(message)]"
	return "OK"

/// Recaps every commit announced since the last call, then clears the backlog. Call this right before a reboot actually happens.
/proc/announce_pending_commits()
	if(!length(GLOB.pending_commit_announcements))
		return
	to_chat(world, span_boldannounce("Changes to expect next restart:"))
	for(var/line in GLOB.pending_commit_announcements)
		to_chat(world, span_announce(line))
	GLOB.pending_commit_announcements.Cut()
