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
	return "OK"
