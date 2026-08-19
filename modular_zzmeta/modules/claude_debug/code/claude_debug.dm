// Ref-handle registry + generic value encode/decode, backing bespoke (non-SDQL2)
// Topic() branches on /datum/world_topic/claude_debug: find/get_var/set_var/call_proc.
//
// Added because SDQL2's own ref-literal syntax ({0x...}/[...]) can't represent a
// DF_USE_TAG object handed back from a prior SELECT, and a thrown error inside
// SDQL_function_blocking() poisons every later CALL for the rest of the session.
// These branches bypass the SDQL2 parser/tokenizer entirely for the common
// get/set/call case, guarded by try/catch, so neither problem can happen here.
// Only find() still reuses SDQL2, and only its WHERE-clause search machinery
// (PreSearch()/Search()), never Execute()/Run(), so no result-serialization or
// CALL dispatch path is ever touched.
GLOBAL_LIST_EMPTY(claude_debug_handles)
GLOBAL_LIST_EMPTY(claude_debug_handle_order)
GLOBAL_VAR_INIT(claude_debug_handle_counter, 0)

#define CLAUDE_DEBUG_MAX_HANDLES 1000
#define CLAUDE_DEBUG_MAX_LIST_DEPTH 3
#define CLAUDE_DEBUG_MAX_LIST_ITEMS 200

/// Hands out a short-lived string handle for a datum, backed by a weakref so
/// holding one never keeps an otherwise-dead object alive. Evicts the oldest
/// handle past CLAUDE_DEBUG_MAX_HANDLES so a long debug session can't leak.
/proc/claude_debug_mint_handle(datum/target)
	if(isnull(target))
		return null
	GLOB.claude_debug_handle_counter++
	var/handle = "h[GLOB.claude_debug_handle_counter]"
	GLOB.claude_debug_handles[handle] = WEAKREF(target)
	GLOB.claude_debug_handle_order += handle
	if(length(GLOB.claude_debug_handle_order) > CLAUDE_DEBUG_MAX_HANDLES)
		var/oldest = GLOB.claude_debug_handle_order[1]
		GLOB.claude_debug_handle_order.Cut(1, 2)
		GLOB.claude_debug_handles -= oldest
	return handle

/proc/claude_debug_resolve_handle(handle)
	var/datum/weakref/ref = GLOB.claude_debug_handles[handle]
	if(!ref)
		return null
	return ref.resolve()

/// Encodes any DM value into a JSON-safe list tree: ("t" = type tag, "v" = value).
/// Datums become a fresh handle rather than being inlined, so a caller can keep
/// drilling into a returned object's own vars/procs without ever needing a ref
/// literal.
/proc/claude_debug_encode_value(value, depth = 0)
	if(isnull(value))
		return list("t" = "null")
	if(isnum(value))
		return list("t" = "num", "v" = value)
	if(istext(value))
		return list("t" = "text", "v" = value)
	if(ispath(value))
		return list("t" = "path", "v" = "[value]")
	if(isdatum(value))
		var/datum/target = value
		return list("t" = "ref", "v" = claude_debug_mint_handle(target), "type" = "[target.type]", "repr" = "[target]")
	if(islist(value))
		if(depth >= CLAUDE_DEBUG_MAX_LIST_DEPTH)
			return list("t" = "text", "v" = "<list, max depth reached>")
		var/list/source = value
		var/list/items = list()
		var/truncated = FALSE
		for(var/key in source)
			if(length(items) >= CLAUDE_DEBUG_MAX_LIST_ITEMS)
				truncated = TRUE
				break
			var/assoc_value = source[key]
			if(!isnull(assoc_value))
				items += list(list("k" = claude_debug_encode_value(key, depth + 1), "v" = claude_debug_encode_value(assoc_value, depth + 1)))
			else
				items += list(claude_debug_encode_value(key, depth + 1))
		. = list("t" = "list", "v" = items)
		if(truncated)
			.["truncated"] = TRUE
		return
	return list("t" = "text", "v" = "[value]")

/// Decodes a client-sent ("t" = type tag, "v" = value) value back into a real DM
/// value. "ref" resolves through the same handle registry find()/encode_value()
/// hand out, so a value read from one call can be passed into a later one.
/proc/claude_debug_decode_value(list/encoded)
	if(!islist(encoded))
		return null
	switch(encoded["t"])
		if("null")
			return null
		if("num")
			return encoded["v"]
		if("text")
			return encoded["v"]
		if("path")
			return text2path(encoded["v"])
		if("ref")
			return claude_debug_resolve_handle(encoded["v"])
		if("list")
			var/list/out = list()
			for(var/item in encoded["v"])
				if(islist(item) && item["k"])
					out[claude_debug_decode_value(item["k"])] = claude_debug_decode_value(item["v"])
				else
					out += claude_debug_decode_value(item)
			return out
	return null

/// find: SELECT-equivalent. Reuses SDQL2's tokenizer/parser/WHERE-evaluator for
/// the search itself (PreSearch()+Search() only), then hands out real handles
/// instead of SDQL2's text-rendered refs.
/proc/claude_debug_find(type_text, where_text, limit)
	limit = clamp(limit, 1, 200)
	var/query_text = "select [type_text][where_text ? " where [where_text]" : ""]"
	var/list/query_list = SDQL2_tokenize(query_text)
	var/list/querys = SDQL_parse(query_list)
	if(!length(querys))
		return list("error" = "Parse error, check the type path/where syntax")
	if(length(querys) > 1)
		return list("error" = "Only a single query is supported")

	// SU=TRUE, admin_interact=FALSE, options=5 (SDQL2_OPTION_SELECT_OUTPUT_SKIP_NULLS
	// | SDQL2_OPTION_HIGH_PRIORITY, both macros #undef'd outside SDQL_2.dm, so the
	// raw value is used here, same as the existing q= path in world_topic.dm).
	var/datum/sdql2_query/query = new /datum/sdql2_query(querys[1], TRUE, FALSE, 5)
	var/list/found
	var/error_text
	try
		query.state = 2 // SDQL2_STATE_PRESEARCH
		var/list/search_tree = query.PreSearch()
		query.state = 3 // SDQL2_STATE_SEARCHING
		found = query.Search(search_tree)
	catch(var/exception/e)
		error_text = "[e]"
	qdel(query)

	if(error_text)
		return list("error" = error_text)
	if(!islist(found))
		return list("error" = "Search produced no usable object list, check the type path")

	var/list/matches = list()
	for(var/i in found)
		if(length(matches) >= limit)
			break
		var/datum/d = i
		matches += list(list("handle" = claude_debug_mint_handle(d), "type" = "[d.type]", "repr" = "[d]"))
	return list("total" = length(found), "returned" = length(matches), "matches" = matches)

/// get_var: reads one var off a handle, encoded via claude_debug_encode_value().
/proc/claude_debug_get_var(handle, var_name)
	if(!var_name)
		return list("error" = "Missing var param")
	var/datum/target = claude_debug_resolve_handle(handle)
	if(!target)
		return list("error" = "Handle not found or object no longer exists")
	if(!(var_name in target.vars))
		return list("error" = "No such var on this object")
	var/value
	var/error_text
	try
		value = target.vars[var_name]
	catch(var/exception/e)
		error_text = "[e]"
	if(error_text)
		return list("error" = error_text)
	return list("ok" = TRUE, "value" = claude_debug_encode_value(value))

/// set_var: writes one var on a handle. value_json is a single client-encoded
/// ("t" = ..., "v" = ...) value, JSON-encoded as text (see claude_debug_decode_value()).
/proc/claude_debug_set_var(handle, var_name, value_json)
	if(!var_name)
		return list("error" = "Missing var param")
	var/datum/target = claude_debug_resolve_handle(handle)
	if(!target)
		return list("error" = "Handle not found or object no longer exists")
	if(!(var_name in target.vars))
		return list("error" = "No such var on this object")
	var/list/decoded = json_decode(value_json)
	if(!islist(decoded))
		return list("error" = "Bad value param, expected JSON (\"t\":..., \"v\":...)")
	var/error_text
	try
		target.vars[var_name] = claude_debug_decode_value(decoded)
	catch(var/exception/e)
		error_text = "[e]"
	if(error_text)
		return list("error" = error_text)
	return list("ok" = TRUE)

/// call_proc: calls a named proc on a handle. args_json is a JSON array of
/// client-encoded ("t" = ..., "v" = ...) values (see claude_debug_decode_value()).
/proc/claude_debug_call_proc(handle, proc_name, args_json)
	if(!proc_name)
		return list("error" = "Missing proc param")
	var/datum/target = claude_debug_resolve_handle(handle)
	if(!target)
		return list("error" = "Handle not found or object no longer exists")
	if(!hascall(target, proc_name))
		return list("error" = "No such proc on this object")
	var/list/decoded_args = list()
	if(args_json)
		var/list/raw_args = json_decode(args_json)
		if(!islist(raw_args))
			return list("error" = "Bad args param, expected a JSON array")
		for(var/raw in raw_args)
			decoded_args += list(claude_debug_decode_value(raw))
	var/result
	var/error_text
	try
		result = call(target, proc_name)(arglist(decoded_args))
	catch(var/exception/e)
		error_text = "[e]"
	if(error_text)
		return list("error" = error_text)
	return list("ok" = TRUE, "result" = claude_debug_encode_value(result))

/datum/world_topic/claude_debug/Run(list/input)
	var/find_type = input["find"]
	if(find_type)
		return claude_debug_find(find_type, input["where"], text2num(input["limit"]) || 25)

	var/get_handle = input["get_var"]
	if(get_handle)
		return claude_debug_get_var(get_handle, input["var"])

	var/set_handle = input["set_var"]
	if(set_handle)
		return claude_debug_set_var(set_handle, input["var"], input["value"])

	var/call_handle = input["call_proc"]
	if(call_handle)
		return claude_debug_call_proc(call_handle, input["proc"], input["args"])

	return ..()

#undef CLAUDE_DEBUG_MAX_HANDLES
#undef CLAUDE_DEBUG_MAX_LIST_DEPTH
#undef CLAUDE_DEBUG_MAX_LIST_ITEMS
