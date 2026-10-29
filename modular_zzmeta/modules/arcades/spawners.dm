/obj/effect/spawner/random/entertainment/arcade/spawn_loot(lootcount_override)
	loot |= list(
		/obj/machinery/computer/arcade/tetris = 49,
		/obj/machinery/computer/arcade/slidingpuzzle = 49,
	)
	loot[/obj/machinery/computer/arcade/amputation] += 2 // keep the odds the same because bubber demands it
	. = ..()
