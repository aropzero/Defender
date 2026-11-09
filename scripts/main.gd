extends Node
## Entry point. Builds the game controller. If CITADEL_SELFTEST=1, runs a
## deterministic headless stress test: several waves, reward picks, level-ups
## and skill casts — to catch runtime errors without needing a human.

var game: Node

func _ready() -> void:
	game = load("res://scripts/game/game.gd").new()
	game.name = "Game"
	add_child(game)
	if OS.get_environment("CITADEL_SELFTEST") == "1":
		_run_selftest()
	if OS.get_environment("CITADEL_MENUTEST") == "1":
		_run_menutest()

func _run_menutest() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	game._show_howto()
	await get_tree().create_timer(0.2).timeout
	game._close_howto()
	game._show_meta()
	await get_tree().create_timer(0.2).timeout
	game._show_main_menu()
	await get_tree().create_timer(0.2).timeout
	print("[MENUTEST OK]")
	get_tree().quit()

func _resolve_phase() -> void:
	# drive any open modal UI deterministically
	while true:
		if game._phase == "reward":
			var cards: Array = game._generate_reward_cards()
			if cards.size() > 0:
				game._apply_reward(cards[0], Control.new())
		elif game._phase == "levelup":
			game._close_levelup()
		elif game._phase == "keystone":
			var opts := []
			for kd in DB.keystones:
				if not (kd.id in Run.player.keystones):
					opts.append(kd)
			if opts.size() > 0:
				var chosen = opts[randi() % opts.size()]
				Run.player.keystones.append(chosen.id)
				Synergy.refresh()
			game._phase = "combat" if game._wave_running() else "build"
		elif game._phase in ["combat", "build", "menu", "meta"]:
			return
		else:
			return

func _run_selftest() -> void:
	await get_tree().process_frame
	game._start_run()
	await get_tree().process_frame
	Run.gold += 20000.0

	game._place_tower("ember", 0, 0)
	game._place_tower("cryo", 1, 0)
	game._place_tower("storm", 0, 1)
	game._place_tower("bone", 1, 1)
	game._place_tower("ballista", 2, 0)
	game._place_tower("nullgate", 2, 1)
	game._place_tower("monolith", 3, 0)
	game._place_tower("chrono", 3, 1)

	for sid in ["meteor", "blizzard", "chaincall", "timelock", "consecrate"]:
		Run.skills_owned.append(sid)
		Run.equip_skill(sid)
	game._build_skillbar()
	game._update_ui()

	var waves_ran := 0
	while waves_ran < 5 and Run.castle.hp > 0.0:
		if game._phase != "combat":
			game._begin_wave()
		var start := Time.get_ticks_msec()
		while Time.get_ticks_msec() - start < 6000 and Run.castle.hp > 0.0:
			if game._phase != "combat":
				_resolve_phase()
			if game._phase == "gameover":
				break
			if game._phase == "combat" and randi() % 40 == 0:
				var sids: Array = Run.skills_equipped
				if sids.size() > 0:
					game._cast_skill(sids[randi() % sids.size()])
			if randi() % 200 == 0 and game.tower_nodes.size() > 0:
				var keys: Array = game.tower_nodes.keys()
				var ser = keys[randi() % keys.size()]
				game._upgrade_tower(ser)
			await get_tree().process_frame
		# force-resolve if the wave lingers (test determinism, not balance)
		if game._phase == "combat" and Run.castle.hp > 0.0:
			for e in game.enemies:
				if not e.dead:
					e.hp = 0.0
					e.dead = true
			game._collect_deaths()
			_resolve_phase()
		if game._phase == "gameover":
			break
		waves_ran += 1

	print("[SELFTEST OK] waves_ran=%d hp=%.0f kills=%d gold=%.0f syn_active=%d asc=%d" % [
		waves_ran, Run.castle.hp, Run.kills, Run.gold,
		Synergy.active_resonances.size() + Synergy.active_adjacencies.size() + Synergy.active_ascensions.size(),
		Synergy.active_ascensions.size()])
	get_tree().quit()
