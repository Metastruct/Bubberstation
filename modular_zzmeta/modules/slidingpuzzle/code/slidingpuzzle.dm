/obj/item/circuitboard/computer/arcade/slidingpuzzle
	name = "Sliding Puzzle"
	greyscale_colors = CIRCUIT_COLOR_GENERIC
	build_path = /obj/machinery/computer/arcade/slidingpuzzle

#define SLIDING_PUZZLE_MIN_SIZE 3
#define SLIDING_PUZZLE_MAX_SIZE 10 // Trivial to raise: tile count (and payload size) scales with N^2, this is just a sane default ceiling.
#define SLIDING_PUZZLE_TILE_PX 48

#define SLIDINGPUZZLE_CONTINUE 0
#define SLIDINGPUZZLE_VICTORY 1
#define SLIDINGPUZZLE_IDLE 2

/* SLIDING PUZZLE MACHINE */
/// The machine itself.

/obj/machinery/computer/arcade/slidingpuzzle
	name = "Sliding Puzzle"
	desc = "An arcade machine that shatters a picture into tiles and challenges you to put it back together. Feed it a photo, or let it dig one out of its memory banks."
	icon_state = "arcade"
	circuit = /obj/item/circuitboard/computer/arcade/slidingpuzzle

	var/datum/slidingpuzzle/board

/obj/machinery/computer/arcade/slidingpuzzle/Initialize(mapload)
	. = ..()
	board = new /datum/slidingpuzzle()
	board.host = src

/obj/machinery/computer/arcade/slidingpuzzle/Destroy(force)
	board.host = null
	QDEL_NULL(board)
	. = ..()

/obj/machinery/computer/arcade/slidingpuzzle/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	. = ..()
	if(. != NONE)
		return .
	if(istype(tool, /obj/item/photo))
		var/obj/item/photo/inserted_photo = tool
		var/datum/picture/pic = inserted_photo.picture
		if(!istype(pic))
			return NONE
		if(board.loaded_icon)
			balloon_alert(user, "already has a photo!")
			to_chat(user, span_warning("[src] already has a photo loaded. Eject it first."))
			return ITEM_INTERACT_BLOCKING
		pic.log_to_file()
		to_chat(user, span_notice("[src] consumes [inserted_photo]! Press Eject Photo to get it back."))
		balloon_alert(user, "photo loaded")
		qdel(inserted_photo)
		var/photo_label = (pic.picture_name && pic.picture_name != initial(pic.picture_name)) ? pic.picture_name : "the inserted photo"
		board.load_photo(pic.picture_image, pic, photo_label)
		SStgui.update_uis(src)
		return ITEM_INTERACT_SUCCESS
	return NONE

/obj/machinery/computer/arcade/slidingpuzzle/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!is_operational)
		return
	if(!ui)
		ui = new(user, src, "SlidingPuzzle", name)
		ui.open()

/obj/machinery/computer/arcade/slidingpuzzle/ui_data(mob/user)
	var/list/data = ..()
	board.fill_ui_data(data)
	data["is_cabinet"] = TRUE
	return data

/obj/machinery/computer/arcade/slidingpuzzle/ui_static_data(mob/user)
	var/list/data = list()
	data["tile_images"] = board.tile_images
	return data

/obj/machinery/computer/arcade/slidingpuzzle/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..())
		return TRUE

	var/mob/user = ui.user

	switch(action)
		if("PRG_new_game")
			if(board.start_new_game())
				board.play_snd('modular_zubbers/sound/arcade/minesweeper_boardpress.ogg')
				ui.send_full_update(force = TRUE, always_instant = TRUE)
			return TRUE

		if("PRG_set_size")
			return board.set_size(text2num(params["width"]), text2num(params["height"]))

		if("PRG_eject_photo")
			var/datum/picture/ejected = board.eject_photo()
			if(istype(ejected))
				var/obj/item/photo/ejected_photo = new(get_turf(src))
				ejected_photo.set_picture(ejected, TRUE, TRUE)
				to_chat(user, span_notice("[src] ejects the photo."))
			else
				to_chat(user, span_notice("There's no photo loaded."))
			return TRUE

		if("PRG_move")
			return board.try_move(params["index"], user)

		if("PRG_tickets")
			board.play_snd('modular_zubbers/sound/arcade/minesweeper_boardpress.ogg')
			if(board.ticket_count >= 1)
				new /obj/item/stack/arcadeticket(loc, 1)
				to_chat(user, span_notice("[src] dispenses a ticket!"))
				board.ticket_count -= 1
			else
				to_chat(user, span_notice("You don't have any stored tickets!"))
			return TRUE

/// COMPUTER SLIDING PUZZLE PROGRAM
/datum/computer_file/program/slidingpuzzle
	filename = "slidingpuzzle"
	filedesc = "Nanotrasen Micro Arcade: Sliding Puzzle"
	extended_desc = "Reassembles a scrambled picture back into place. Uses photos stored on this device, or a saved library photo if none are available."
	size = 6
	tgui_id = "NtosSlidingPuzzle"
	program_icon = "th-large"

	downloader_category = PROGRAM_CATEGORY_GAMES

	var/datum/slidingpuzzle/board

/datum/computer_file/program/slidingpuzzle/New(obj/item/modular_computer/comp)
	. = ..()
	board = new /datum/slidingpuzzle()
	board.host = comp

/datum/computer_file/program/slidingpuzzle/Destroy()
	board.host = null
	QDEL_NULL(board)
	. = ..()

/datum/computer_file/program/slidingpuzzle/ui_data(mob/user)
	var/list/data = list()
	board.fill_ui_data(data)

	var/list/available_photos = list()
	if(computer)
		var/index = 0
		for(var/datum/computer_file/file in computer.get_files(TRUE))
			if(!istype(file, /datum/computer_file/image))
				continue
			index++
			var/datum/computer_file/image/image_file = file
			available_photos += list(list("index" = index, "name" = image_file.image_name || image_file.filename))
	data["available_photos"] = available_photos

	return data

/datum/computer_file/program/slidingpuzzle/ui_static_data(mob/user)
	var/list/data = list()
	data["tile_images"] = board.tile_images
	return data

/datum/computer_file/program/slidingpuzzle/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..())
		return TRUE

	if(!board)
		return

	if(!board.host && computer)
		board.host = computer

	var/mob/user = ui.user

	switch(action)
		if("PRG_new_game")
			if(board.start_new_game())
				board.play_snd('modular_zubbers/sound/arcade/minesweeper_boardpress.ogg')
				ui.send_full_update(force = TRUE, always_instant = TRUE)
			return TRUE

		if("PRG_set_size")
			return board.set_size(text2num(params["width"]), text2num(params["height"]))

		if("PRG_eject_photo")
			board.eject_photo()
			return TRUE

		if("PRG_move")
			return board.try_move(params["index"], user)

		if("PRG_select_photo")
			if(!computer)
				return
			var/picked_index = text2num(params["index"])
			if(!picked_index)
				return
			var/list/datum/computer_file/image/images = list()
			for(var/datum/computer_file/file in computer.get_files(TRUE))
				if(istype(file, /datum/computer_file/image))
					images += file
			if(picked_index < 1 || picked_index > images.len)
				return
			var/datum/computer_file/image/chosen = images[picked_index]
			var/datum/picture/source_picture = istype(chosen.source_photo_or_painting, /datum/picture) ? chosen.source_photo_or_painting : null
			var/photo_label = "[chosen.image_name || chosen.filename]"
			if(source_picture)
				source_picture.log_to_file()
				if(source_picture.picture_name && source_picture.picture_name != initial(source_picture.picture_name))
					photo_label = source_picture.picture_name
			else if(istype(chosen.source_photo_or_painting, /datum/painting))
				var/datum/painting/source_painting = chosen.source_photo_or_painting
				if(source_painting.title)
					photo_label = source_painting.title
			board.load_photo(chosen.stored_icon, source_picture, photo_label)
			return TRUE

/datum/slidingpuzzle
	var/obj/host
	var/game_status = SLIDINGPUZZLE_IDLE

	var/width = 3
	var/height = 3
	/// Size to use for the NEXT new game. Kept separate from width/height so adjusting the sliders mid-game
	/// can't desync them from the actual board array (that's what index math and win-checks read from).
	var/pending_width = 3
	var/pending_height = 3
	/// Flattened list of tile ids by board position (1-indexed, row-major). The highest id (width*height) marks the blank slot.
	var/list/board
	var/blank_pos = 0
	/// Cached base64 PNG per tile id, generated once per new game. The id "[width*height]" is never present since it's the blank.
	var/list/tile_images

	var/move_count = 0
	var/starting_time = 0
	var/time_frozen = 0
	var/ticket_count = 0

	/// Set by a host (photo inserted / photo picked) and stays loaded across games until eject_photo() is called.
	var/icon/loaded_icon
	var/datum/picture/loaded_picture
	var/loaded_source_label
	/// What the CURRENT board was actually generated from, for display when nothing is loaded (a library/default pick).
	var/current_source_label = "no photo yet"

	COOLDOWN_DECLARE(new_game_cd)

/datum/slidingpuzzle/proc/play_snd(sound)
	playsound(get_turf(host), sound, 25, 0, extrarange = -6)

/datum/slidingpuzzle/proc/vis_msg(msg, local_msg)
	if(istype(host, /obj/item/modular_computer))
		var/obj/item/modular_computer/comp = host
		comp.visible_message(msg)
	else
		host.visible_message(msg, local_msg)

/datum/slidingpuzzle/proc/fill_ui_data(list/data)
	data["board"] = board
	data["width"] = width
	data["height"] = height
	data["pending_width"] = pending_width
	data["pending_height"] = pending_height
	data["min_size"] = SLIDING_PUZZLE_MIN_SIZE
	data["max_size"] = SLIDING_PUZZLE_MAX_SIZE
	data["game_status"] = game_status
	data["move_count"] = move_count
	data["tickets"] = ticket_count
	data["source_label"] = loaded_source_label || current_source_label
	data["has_photo_loaded"] = !isnull(loaded_icon)
	var/display_time = (time_frozen ? time_frozen : REALTIMEOFDAY - starting_time) / 10
	data["time_string"] = starting_time ? "[add_leading(num2text(FLOOR(display_time / 60, 1)), 2, "0")]:[add_leading(num2text(display_time % 60), 2, "0")]" : "00:00"
	return data

/// Updates the size used for the NEXT new game. Doesn't touch the current board or its width/height, so it's
/// safe to call mid-game without desyncing the active board's index math.
/datum/slidingpuzzle/proc/set_size(new_width, new_height)
	if(!isnull(new_width) && new_width)
		pending_width = clamp(new_width, SLIDING_PUZZLE_MIN_SIZE, SLIDING_PUZZLE_MAX_SIZE)
	if(!isnull(new_height) && new_height)
		pending_height = clamp(new_height, SLIDING_PUZZLE_MIN_SIZE, SLIDING_PUZZLE_MAX_SIZE)
	return TRUE

/// Loads a photo to use for every new game from now on, until eject_photo() is called. source_picture is optional
/// (a bare icon with no backing picture, e.g. a painting scan, still works, it just can't be added to the library).
/datum/slidingpuzzle/proc/load_photo(icon/new_icon, datum/picture/source_picture, new_label)
	loaded_icon = new_icon
	loaded_picture = source_picture
	loaded_source_label = new_label
	if(istype(source_picture) && source_picture.id && SSpersistence.puzzle_photo_library)
		var/list/library = SSpersistence.puzzle_photo_library.get()
		if(!(source_picture.id in library))
			SSpersistence.puzzle_photo_library.insert(source_picture.id)

/// Clears the loaded photo (future games fall back to the library/default again) and returns the picture that was
/// loaded, if any, so the caller can hand it back to the player.
/datum/slidingpuzzle/proc/eject_photo()
	. = loaded_picture
	loaded_icon = null
	loaded_picture = null
	loaded_source_label = null

/datum/slidingpuzzle/proc/start_new_game()
	if(!COOLDOWN_FINISHED(src, new_game_cd))
		return FALSE
	COOLDOWN_START(src, new_game_cd, 1.5 SECONDS)

	width = pending_width
	height = pending_height

	var/icon/source_icon

	if(loaded_icon)
		source_icon = loaded_icon
		current_source_label = loaded_source_label
	else
		if(SSpersistence.puzzle_photo_library)
			var/list/library = SSpersistence.puzzle_photo_library.get()
			if(length(library))
				var/picked_id = pick(library)
				var/datum/picture/library_pic = load_picture_from_disk(picked_id)
				if(istype(library_pic))
					source_icon = library_pic.picture_image
					current_source_label = "a library photo"
		if(!source_icon)
			source_icon = icon('modular_zzmeta/modules/slidingpuzzle/icons/default.png')
			current_source_label = "the default image"

	generate_board(source_icon)
	return TRUE

/datum/slidingpuzzle/proc/generate_board(icon/source_icon)
	var/tile_count = width * height
	var/icon/scaled = new(source_icon)
	scaled.Scale(width * SLIDING_PUZZLE_TILE_PX, height * SLIDING_PUZZLE_TILE_PX)

	tile_images = list()
	for(var/id in 1 to tile_count - 1)
		var/row = round((id - 1) / width) + 1
		var/col = ((id - 1) % width) + 1
		var/row_from_bottom = height - row + 1

		var/x_start = 1 + (col - 1) * SLIDING_PUZZLE_TILE_PX
		var/x_end = x_start + SLIDING_PUZZLE_TILE_PX - 1
		var/y_start = 1 + (row_from_bottom - 1) * SLIDING_PUZZLE_TILE_PX
		var/y_end = y_start + SLIDING_PUZZLE_TILE_PX - 1

		var/icon/tile_icon = new(scaled)
		tile_icon.Crop(x_start, y_start, x_end, y_end)
		tile_images["[id]"] = icon2base64(tile_icon)

	var/list/order = list()
	for(var/id in 1 to tile_count)
		order += id
	order = shuffle(order)

	if(!is_solvable(order))
		var/first_swap = 1
		var/second_swap = 2
		if(order[first_swap] == tile_count || order[second_swap] == tile_count)
			second_swap = 3
		var/temp = order[first_swap]
		order[first_swap] = order[second_swap]
		order[second_swap] = temp

	board = order
	blank_pos = board.Find(tile_count)
	move_count = 0
	starting_time = REALTIMEOFDAY
	time_frozen = 0
	game_status = SLIDINGPUZZLE_CONTINUE

/// Standard 15-puzzle solvability check, generalized to any width/height.
/datum/slidingpuzzle/proc/is_solvable(list/order)
	var/tile_count = width * height
	var/list/values = list()
	for(var/v in order)
		if(v != tile_count)
			values += v

	var/inversions = 0
	for(var/i in 1 to values.len)
		for(var/j in i + 1 to values.len)
			if(values[j] < values[i])
				inversions++

	if(width % 2 == 1)
		return (inversions % 2) == 0

	var/blank_position = order.Find(tile_count)
	var/blank_row_from_top = round((blank_position - 1) / width) + 1
	var/blank_row_from_bottom = height - blank_row_from_top + 1
	return ((inversions + blank_row_from_bottom) % 2) == 1

/datum/slidingpuzzle/proc/is_adjacent(a, b)
	var/ax = ((a - 1) % width) + 1
	var/ay = round((a - 1) / width)
	var/bx = ((b - 1) % width) + 1
	var/by = round((b - 1) / width)
	if(ax == bx && abs(ay - by) == 1)
		return TRUE
	if(ay == by && abs(ax - bx) == 1)
		return TRUE
	return FALSE

/datum/slidingpuzzle/proc/check_victory()
	for(var/i in 1 to length(board))
		if(board[i] != i)
			return FALSE
	return TRUE

/datum/slidingpuzzle/proc/try_move(index, mob/living/user)
	if(game_status != SLIDINGPUZZLE_CONTINUE)
		return FALSE
	index = text2num(index)
	if(!index || index < 1 || index > length(board) || index == blank_pos)
		return FALSE
	if(!is_adjacent(index, blank_pos))
		return FALSE

	var/temp = board[index]
	board[index] = board[blank_pos]
	board[blank_pos] = temp
	blank_pos = index
	move_count++
	play_snd('modular_zubbers/sound/arcade/minesweeper_boardpress.ogg')

	if(check_victory())
		game_status = SLIDINGPUZZLE_VICTORY
		time_frozen = REALTIMEOFDAY - starting_time
		var/reward = max(1, round((width * height) / 4))
		ticket_count += reward
		play_snd('modular_zubbers/sound/arcade/minesweeper_win.ogg')
		vis_msg(span_notice("[host] chimes triumphantly as the picture completes!"), span_notice("You hear a triumphant chime."))

	return TRUE

#undef SLIDINGPUZZLE_CONTINUE
#undef SLIDINGPUZZLE_VICTORY
#undef SLIDINGPUZZLE_IDLE

#undef SLIDING_PUZZLE_MIN_SIZE
#undef SLIDING_PUZZLE_MAX_SIZE
#undef SLIDING_PUZZLE_TILE_PX
