/obj/item/circuitboard/computer/arcade/tetris
	name = "Tetris"
	greyscale_colors = CIRCUIT_COLOR_GENERIC
	build_path = /obj/machinery/computer/arcade/tetris

#define TETRIS_IDLE 0
#define TETRIS_PLAYING 1
#define TETRIS_GAMEOVER 2

/// Minimum plausible real time (deciseconds) per line cleared, used to sanity-check a reported
/// game so a fabricated ui_act call can't claim an implausibly high score for a tiny time window.
#define TETRIS_MIN_DS_PER_LINE 5

/// If a "PLAYING" game hasn't synced in this long, treat it as abandoned rather than a live
/// game nobody's allowed to touch. An active client syncs at least every 500ms regardless of
/// locks, so this has plenty of headroom before misfiring on a genuinely active game.
#define TETRIS_ABANDON_THRESHOLD (8 SECONDS)

/// Past this (but short of TETRIS_ABANDON_THRESHOLD), spectators get a "might be laggy" hint
/// instead of a silently frozen board.
#define TETRIS_STALE_THRESHOLD (1.5 SECONDS)

/* TETRIS MACHINE */
/// The machine itself. The board/piece/gravity logic runs client-side in tgui (like the fishing
/// minigame); the server only tracks tickets, a high score, and sanity-checks the final report.

/obj/machinery/computer/arcade/tetris
	name = "Tetris"
	desc = "An arcade machine that drops geometric blocks on you faster and faster until you inevitably fail. Strangely soothing."
	icon_state = "arcade"
	circuit = /obj/item/circuitboard/computer/arcade/tetris

	var/datum/tetris_arcade/board

/obj/machinery/computer/arcade/tetris/Initialize(mapload)
	. = ..()
	board = new /datum/tetris_arcade()
	board.host = src
	RegisterSignal(src, COMSIG_MACHINERY_POWER_LOST, PROC_REF(on_power_change))
	RegisterSignal(src, COMSIG_MACHINERY_POWER_RESTORED, PROC_REF(on_power_change))

/obj/machinery/computer/arcade/tetris/Destroy(force)
	board.host = null
	QDEL_NULL(board)
	. = ..()

/// Pushes an immediate UI update on power change, so a mid-game client pauses (see Tetris.jsx's
/// isOperational) right away instead of on its next regular poll.
/obj/machinery/computer/arcade/tetris/proc/on_power_change()
	SIGNAL_HANDLER
	SStgui.update_uis(src)

/obj/machinery/computer/arcade/tetris/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!is_operational)
		return
	if(!ui)
		ui = new(user, src, "Tetris", name)
		ui.open()

/obj/machinery/computer/arcade/tetris/ui_data(mob/user)
	var/list/data = ..()
	board.fill_ui_data(data, user)
	data["is_cabinet"] = TRUE
	return data

/obj/machinery/computer/arcade/tetris/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..())
		return TRUE

	var/mob/user = ui.user
	if(!istype(user, /mob/living))
		return TRUE

	switch(action)
		if("PRG_new_game")
			return board.start_new_game(user)

		if("PRG_game_over")
			return board.report_game_over(text2num(params["score"]), text2num(params["lines"]), params["mode"], params["completed"], user)

		if("PRG_sync")
			return board.update_snapshot(params["snapshot"], params["sfx"], text2num(params["seq"]), user)

		if("PRG_tickets")
			board.play_snd('modular_zubbers/sound/arcade/minesweeper_boardpress.ogg')
			if(board.ticket_count >= 1)
				new /obj/item/stack/arcadeticket(loc, 1)
				to_chat(user, span_notice("[src] dispenses a ticket!"))
				board.ticket_count -= 1
			else
				to_chat(user, span_notice("You don't have any stored tickets!"))
			return TRUE

/// COMPUTER TETRIS PROGRAM
/datum/computer_file/program/tetris
	filename = "tetris"
	filedesc = "Nanotrasen Micro Arcade: Tetris"
	extended_desc = "A port of the classic falling block game. Blocks fall, lines clear, and it never actually ends, it just gets faster until you do."
	size = 6
	tgui_id = "NtosTetris"
	program_icon = "th-large"

	downloader_category = PROGRAM_CATEGORY_GAMES

	var/datum/tetris_arcade/board

/datum/computer_file/program/tetris/New(obj/item/modular_computer/comp)
	. = ..()
	board = new /datum/tetris_arcade()
	board.host = comp

/datum/computer_file/program/tetris/Destroy()
	board.host = null
	QDEL_NULL(board)
	. = ..()

/datum/computer_file/program/tetris/ui_data(mob/user)
	var/list/data = list()
	board.fill_ui_data(data, user)
	return data

/datum/computer_file/program/tetris/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..())
		return TRUE

	if(!board)
		return

	if(!board.host && computer)
		board.host = computer

	var/mob/user = ui.user
	if(!istype(user, /mob/living))
		return TRUE

	switch(action)
		if("PRG_new_game")
			return board.start_new_game(user)

		if("PRG_game_over")
			return board.report_game_over(text2num(params["score"]), text2num(params["lines"]), params["mode"], params["completed"], user)

		if("PRG_sync")
			return board.update_snapshot(params["snapshot"], params["sfx"], text2num(params["seq"]), user)

/datum/tetris_arcade
	var/obj/host
	var/game_status = TETRIS_IDLE

	var/high_score = 0
	/// Display name of whoever set high_score.
	var/high_score_holder
	/// Best (highest) score achieved in a 2-minute Blitz run.
	var/blitz_high_score = 0
	/// Display name of whoever set blitz_high_score.
	var/blitz_high_score_holder
	/// Best (lowest) 40 Lines completion time, in deciseconds. 0 means no completed run yet.
	var/sprint_best_ds = 0
	/// Display name of whoever set sprint_best_ds.
	var/sprint_best_holder
	/// Best (lowest) Garbage Race completion time, in deciseconds. 0 means no completed run yet.
	var/garbage_best_ds = 0
	/// Display name of whoever set garbage_best_ds.
	var/garbage_best_holder
	/// Whether a Marathon/Blitz run has ever finished, tracked separately per mode. Without
	/// this, a mode's first game always "beats" its score = 0 baseline and fires the win
	/// jingle regardless of how badly it went; a shared flag would also let finishing
	/// Marathon make your first Blitz run "win" for free.
	var/has_finished_marathon = FALSE
	var/has_finished_blitz = FALSE
	var/last_score = 0
	var/last_lines = 0
	var/last_mode = "marathon"
	var/ticket_count = 0

	var/starting_time = 0
	/// REALTIMEOFDAY of the last accepted sync, used to detect an abandoned game. See
	/// TETRIS_ABANDON_THRESHOLD.
	var/last_sync_time = 0
	/// Sequence number of the last accepted sync (see pushSync() in Tetris.jsx). Rejects a
	/// reordered/delayed packet that would otherwise flip the board back to stale content.
	var/last_sync_seq = 0

	/// ckey of whoever most recently pressed New Game. Whoever this doesn't match sees the
	/// game as a read-only spectator instead of getting controls.
	var/player_ckey
	/// Display name of that same player, for spectators' "who's playing" label. Kept separate
	/// from player_ckey since ckeys shouldn't be shown to other players' clients.
	var/player_name
	/// Latest client-pushed {board, current, hold, queue, score, lines, level} blob, relayed
	/// verbatim to every other viewer's ui_data so they can render along a spectator.
	var/list/snapshot

	COOLDOWN_DECLARE(new_game_cd)

/datum/tetris_arcade/proc/play_snd(sound)
	playsound(get_turf(host), sound, 25, 0, extrarange = -6)

/datum/tetris_arcade/proc/vis_msg(msg, local_msg)
	if(istype(host, /obj/item/modular_computer))
		var/obj/item/modular_computer/comp = host
		comp.visible_message(msg)
	else
		host.visible_message(msg, local_msg)

/// FALSE only for the cabinet form, and only once it's actually lost power (BROKEN/no power
/// channel etc.). The NTOS program form has no such concept and is always powered.
/datum/tetris_arcade/proc/is_powered()
	if(!istype(host, /obj/machinery))
		return TRUE
	var/obj/machinery/machine_host = host
	return machine_host.is_operational

/datum/tetris_arcade/proc/fill_ui_data(list/data, mob/user)
	data["is_operational"] = is_powered()
	data["game_status"] = game_status
	data["high_score"] = high_score
	data["high_score_holder"] = high_score_holder
	data["blitz_high_score"] = blitz_high_score
	data["blitz_high_score_holder"] = blitz_high_score_holder
	data["sprint_best_ds"] = sprint_best_ds
	data["sprint_best_holder"] = sprint_best_holder
	data["garbage_best_ds"] = garbage_best_ds
	data["garbage_best_holder"] = garbage_best_holder
	data["last_score"] = last_score
	data["last_lines"] = last_lines
	data["last_mode"] = last_mode
	data["tickets"] = ticket_count
	// isliving(), not just a ckey match: SStgui reassigns ui.user to a dead player's ghost
	// while ckey stays the same, and the client-side board would let that ghost keep
	// visibly playing (no scoring exploit, PRG_sync/PRG_game_over are server-gated).
	data["is_player"] = !isnull(player_ckey) && isliving(user) && (user.ckey == player_ckey)
	data["player_name"] = player_name
	data["snapshot"] = snapshot
	data["is_abandoned"] = (game_status == TETRIS_PLAYING) && (REALTIMEOFDAY - last_sync_time > TETRIS_ABANDON_THRESHOLD)
	data["is_stale"] = (game_status == TETRIS_PLAYING) && (REALTIMEOFDAY - last_sync_time > TETRIS_STALE_THRESHOLD)
	return data

/datum/tetris_arcade/proc/start_new_game(mob/user)
	if(!is_powered())
		return FALSE

	// Claim the "player" seat regardless of cooldown, so a client already running its own
	// game (started just under the cooldown) doesn't flip to spectator view on its next poll.
	player_ckey = user?.ckey
	player_name = user?.name

	if(!COOLDOWN_FINISHED(src, new_game_cd))
		return FALSE
	COOLDOWN_START(src, new_game_cd, 1.5 SECONDS)

	game_status = TETRIS_PLAYING
	starting_time = REALTIMEOFDAY
	last_sync_time = REALTIMEOFDAY
	last_sync_seq = 0
	snapshot = null
	play_snd('modular_zubbers/sound/arcade/minesweeper_boardpress.ogg')
	return TRUE

/// Stores the latest client-side board snapshot for other viewers to render, and plays any
/// accompanying sound effect. Only the current player's client is trusted to push one; sfx is
/// matched against a fixed allowlist rather than ever touching a client-supplied file path.
/datum/tetris_arcade/proc/update_snapshot(list/new_snapshot, sfx, seq, mob/user)
	if(!is_powered())
		return FALSE
	if(game_status != TETRIS_PLAYING)
		return FALSE
	if(!user || isnull(player_ckey) || user.ckey != player_ckey)
		return FALSE
	last_sync_time = REALTIMEOFDAY

	// A reordered/delayed sync that already lost to a newer one: don't let its board data step
	// the display backward, but still relay its sound/effects below, since a real clear/lock/
	// spin happened and deserves feedback either way.
	if(seq > last_sync_seq)
		snapshot = new_snapshot
		last_sync_seq = seq
	else if(snapshot && new_snapshot)
		for(var/effect_key in list("banner", "comboBanner", "glow", "flashRows", "particles"))
			snapshot[effect_key] = new_snapshot[effect_key]

	switch(sfx)
		if("lock")
			play_snd('sound/machines/click.ogg')
		if("clear")
			play_snd('sound/machines/terminal/terminal_select.ogg')
		if("tetris")
			play_snd('sound/machines/terminal/terminal_success.ogg')
		if("spin")
			play_snd('modular_skyrat/modules/subsystems/sounds/soft_ping.ogg')
	// Without this, spectators only see a new snapshot on SStgui's own background tick
	// (~900ms), on top of however long the player's own sync was already delayed by.
	SStgui.update_uis(host)
	return TRUE

/// Called once when the client's local game ends. The board is entirely client-side, so this
/// just sanity-checks the reported score/lines against elapsed time before paying out.
/// `mode` is "marathon"/"sprint"/"blitz"/"garbage"; `completed` means the client hit its
/// actual goal rather than topping out. Time is never taken from the client: sprint/garbage
/// records use the server's own REALTIMEOFDAY delta since start_new_game.
/datum/tetris_arcade/proc/report_game_over(score, lines, mode, completed, mob/living/user)
	if(game_status != TETRIS_PLAYING)
		return FALSE
	game_status = TETRIS_GAMEOVER

	score = max(0, score)
	lines = max(0, lines)
	completed = completed ? TRUE : FALSE
	if(!(mode in list("marathon", "sprint", "blitz", "garbage")))
		mode = "marathon"

	var/elapsed = REALTIMEOFDAY - starting_time
	// Garbage Race starts most of the board pre-filled with near-complete rows, so clearing
	// lines far faster than the marathon-tuned pace below is the entire point, not a red flag.
	if(mode != "garbage")
		var/max_plausible_lines = round(elapsed / TETRIS_MIN_DS_PER_LINE) + 1
		lines = min(lines, max_plausible_lines)

	last_score = score
	last_lines = lines
	last_mode = mode

	var/reward = clamp(round(lines / 2), lines ? 1 : 0, 15)
	if(completed && (mode == "sprint" || mode == "garbage"))
		reward += 3
	ticket_count += reward

	var/is_record = FALSE
	var/is_success = FALSE
	switch(mode)
		if("blitz")
			if(has_finished_blitz && score > blitz_high_score)
				blitz_high_score = score
				blitz_high_score_holder = user?.name
				is_record = TRUE
			else
				blitz_high_score = max(blitz_high_score, score)
			has_finished_blitz = TRUE
		if("sprint")
			if(completed)
				is_success = TRUE
				if(!sprint_best_ds || elapsed < sprint_best_ds)
					sprint_best_ds = elapsed
					sprint_best_holder = user?.name
					is_record = TRUE
		if("garbage")
			if(completed)
				is_success = TRUE
				if(!garbage_best_ds || elapsed < garbage_best_ds)
					garbage_best_ds = elapsed
					garbage_best_holder = user?.name
					is_record = TRUE
		else
			if(has_finished_marathon && score > high_score)
				high_score = score
				high_score_holder = user?.name
				is_record = TRUE
			else
				high_score = max(high_score, score)
			has_finished_marathon = TRUE

	if(is_record)
		vis_msg(span_notice("[host] flashes a new [mode] record!"), span_notice("You hear a triumphant chime."))
		play_snd('modular_zubbers/sound/arcade/minesweeper_win.ogg')
	else if(is_success)
		play_snd('sound/machines/ding.ogg')
	else
		play_snd('sound/machines/arcade/lose.ogg')

	if(user)
		to_chat(user, span_notice("Game over! You scored [score] points and cleared [lines] line\s, earning [reward] ticket\s."))

	return TRUE

#undef TETRIS_IDLE
#undef TETRIS_PLAYING
#undef TETRIS_GAMEOVER

#undef TETRIS_MIN_DS_PER_LINE
#undef TETRIS_ABANDON_THRESHOLD
#undef TETRIS_STALE_THRESHOLD
