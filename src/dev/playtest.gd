extends Node
## Automated walkthrough of the vertical slice. Drives the real game screen: teleports to each
## objective, triggers interactions, reveals traces, uses the watch, plays the Host encounter,
## and saves a screenshot at each beat. Fails loudly if an objective doesn't advance.
## godot --path . res://src/dev/playtest.tscn -- --out=/tmp/pt --until=slice_end --shots=1

var gs: GameScreen
var out := "/tmp/pt"
var shots := true
var step := 0
var log_lines: Array = []
var from_point := ""

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	out = args.get("out", out)
	from_point = args.get("from", "")
	shots = args.get("shots", "1") == "1"
	if args.has("preset"): Settings.apply_preset(args.preset)
	DirAccess.make_dir_recursive_absolute(out)
	Save.start(2, "Tester")
	gs = GameScreen.new(); gs.main = self
	add_child(gs)
	gs.start()
	while not gs.ready_to_play: await get_tree().process_frame
	set_process(true)
	await run()
	_log("DONE objective=%s flags=%d clues=%d collect=%d ach=%d" % [Game.objective(), Save.profile.flags.size(), Save.profile.clues.size(), Save.profile.collectibles.size(), Save.profile.achievements.size()])
	var f := FileAccess.open(out + "/log.txt", FileAccess.WRITE); f.store_string("\n".join(log_lines))
	get_tree().quit()

func show_title() -> void: pass
func start_game(_s: int, _n := "") -> void: pass

func _process(_dt: float) -> void:
	if gs and gs.dialogue and gs.dialogue.active:
		gs.dialogue._advance = true
		if gs.dialogue._choice < 0 and gs.hud.choice_box.get_child_count() > 0: pass

func _log(s: String) -> void:
	print("[playtest] ", s); log_lines.append(s)

func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func idle() -> void:
	await get_tree().process_frame
	while gs.dialogue.active or gs.player.state != "free" or gs.doc_layer.get_child_count() > 0:
		if gs.doc_layer.get_child_count() > 0: gs.close_document()
		if Game.flag("slice_done"): Input.action_press("interact")
		await get_tree().process_frame
		Input.action_release("interact")
	await get_tree().process_frame

func shot(name: String) -> void:
	if not shots: return
	for i in 6: await get_tree().process_frame
	step += 1
	get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [out, step, name])

func go(pos: Vector3, yaw := 0.0) -> void:
	gs.player.teleport(pos, yaw)
	for i in 4: await get_tree().process_frame

func find(label: String) -> Dictionary:
	for it in gs.world.interactables:
		if String(it.get("label", "")).findn(label) >= 0 and gs.world.item_active(it) and (not it.has("cond") or it.cond.call()): return it
	return {}

func use(label: String, stand_offset := Vector3(0, 0, 0)) -> bool:
	var it := find(label)
	if it.is_empty():
		_log("!! no interactable '%s' (objective %s)" % [label, Game.objective()]); return false
	var p: Vector3 = it.pos
	await go(Vector3(p.x, p.y - 1.0, p.z) + stand_offset)
	gs.player.interacted.emit(it)
	(it.on as Callable).call(it)
	await idle()
	_log("used '%s' -> objective %s" % [label, Game.objective()])
	return true

func reveal_near(pos: Vector3, radius := 1.5) -> void:
	for t in gs.world.traces:
		if not t.revealed and (t.pos as Vector3).distance_to(pos) < radius:
			gs.player.reveal(t)
			await idle()

func watch_at(pos: Vector3) -> void:
	await go(pos)
	gs.player.use_watch()
	await idle()
	_log("watch at %s -> objective %s" % [pos, Game.objective()])

func expect(obj: String) -> void:
	if Game.objective() != obj: _log("!! expected objective %s but have %s" % [obj, Game.objective()])

func run() -> void:
	await idle()
	if from_point == "encounter":
		await encounter_and_ending(); return
	await shot("intro_done")
	expect("pro_arrive")
	await use("glovebox")
	await use("boot")
	await use("mailbox")
	await go(Vector3(0, -0.55, -8.0), 0.0); await shot("porch")
	await use("front door")
	expect("ch1_look")
	await shot("hall")
	await use("Grand Clock", Vector3(0, 0, -0.6))
	await use("mantel clock", Vector3(0, 0, -1.0))
	await use("wall clock", Vector3(0, 0, -1.0))
	expect("ch1_lantern")
	await use("register", Vector3(0, 0, -1.0))
	await use("lantern", Vector3(0.8, 0, -0.6))
	expect("ch1_corridor")
	await go(Vector3(-26.0, 0.05, 4.0), -PI * 0.5)
	gs.player.raise = 1.0; await shot("corridor_lantern")
	await reveal_near(Vector3(-28.5, 1.4, 5.47))
	expect("ch1_porter")
	await go(Vector3(-28.5, 0.05, 7.5), 0.0); await shot("cloakroom")
	await use("Night Porter", Vector3(0, 0, -1.4))
	for o in gs.world.observables:
		if o.node == gs.story.npcs.get("porter"): (o.on as Callable).call(o); await idle()
	await use("hook 7", Vector3(0, 0, -0.9))
	expect("ch1_return")
	await shot("porter_resolved")
	await use("tea", Vector3(0, 0, 0.8))
	await go(Vector3(-6.0, 0.05, 4.0), PI * 0.5)
	await idle()
	expect("ch1_watch")
	await watch_at(gs.world.refs.grand_clock_front + Vector3(0, 0.05, -0.5))
	expect("ch1_deduce")
	await shot("after_king_echo")
	var r := Game.deduce("c_clocks", "c_register")
	_log("deduce -> %s" % r)
	await get_tree().process_frame
	await idle()
	expect("ch2_enter")
	await go(Vector3(12.0, 0.05, 4.0), PI * 0.5); await idle()
	expect("ch2_anchor"); await shot("ballroom_now")
	await watch_at(gs.world.refs.ballroom_anchor_pos + Vector3(0.6, 0.05, 0))
	expect("ch2_listen"); await shot("ballroom_then")
	await use("violin stand", Vector3(-1.0, 0, 0))
	expect("ch2_fragments"); await shot("host_met")
	await use("masked dancer", Vector3(0, 0, -1.0))
	await watch_at(gs.world.refs.ballroom_anchor_pos + Vector3(0.6, 0.05, 0))
	await use("sheet from the piano", Vector3(-1.0, 0, 0))
	await watch_at(gs.world.refs.ballroom_anchor_pos + Vector3(0.6, 0.05, 0))
	await use("folding screen", Vector3(0, 0, -1.2))
	await use("behind the screen", Vector3(-0.8, 0, -0.6))
	expect("ch2_order")
	await watch_at(Vector3(36.6, 0.85, 6.0))
	expect("ch2_place")
	for inst in ["violin", "cello", "flute"]:
		var it := find("%s stand" % inst)
		await go((it.pos as Vector3) + Vector3(-1.0, -1.0, 0))
		var want: String = {"violin": "Moon", "cello": "Star", "flute": "Sun"}[inst]
		(it.on as Callable).call(it)
		for i in 30:
			await get_tree().process_frame
			if gs.hud.choice_box.get_child_count() > 0: break
		for i in gs.hud.choice_box.get_child_count():
			var b: Button = gs.hud.choice_box.get_child(i)
			if b.text.find(want) >= 0: b.pressed.emit(); break
		await idle()
	expect("ch2_marks"); await shot("sheets_placed")
	for sd in gs.world.refs.music_stands:
		await reveal_near((sd.sheet_xform as Transform3D).origin, 0.6)
	await wait(0.5)
	await encounter_and_ending()

func encounter_and_ending() -> void:
	if from_point == "encounter":
		for f in GameData.CODE_REGISTRY.flags:
			if f in ["host_met", "host_resolved", "balcony_open", "mara_freed", "chime2", "slice_done", "waltz_complete", "marks_1", "marks_2", "marks_3"]: continue
			Game.set_flag(f)
		for k in ["frag_moon", "frag_star", "frag_sun"]: Game.set_flag(k)
		Save.profile.chimes = 1
		Game.set_objective("ch2_marks", false)
		await go(Vector3(30.0, 0.85, 6.0), PI * 0.5)
		for sd in gs.world.refs.music_stands: gs.story.ch2._place_sheet_mesh(gs.story.ch2.STAND_ORDER[gs.world.refs.music_stands.find(sd)], sd)
		for t in gs.story.ch2._mark_traces: t.enabled = true
		gs.story.ch2._meet_host()
		await idle()
		for sd in gs.world.refs.music_stands:
			await reveal_near((sd.sheet_xform as Transform3D).origin, 0.6)
		await wait(0.5)
	_log("encounter active=%s phase=%d" % [gs.story.ch2.encounter_active, gs.story.ch2.phase])
	await shot("encounter_start")
	var ch2 := gs.story.ch2
	# phase 1: flare the frosted mirror three times
	var guard := 0
	while ch2.phase == 1 and guard < 4000:
		guard += 1
		if ch2._mirror_i >= 0 and ch2.host.visible == false:
			var m: Dictionary = gs.world.refs.ballroom_mirrors[ch2._mirror_i]
			await go(Vector3(25.0, 0.05, 6.0))
			ch2._on_flare(Vector3(25, 1.5, 6), ((m.center as Vector3) - Vector3(25, 1.5, 6)).normalized())
		await get_tree().process_frame
	_log("phase after mirrors: %d hits=%d" % [ch2.phase, ch2._hits])
	await idle(); await shot("chairs")
	guard = 0
	while ch2.phase == 2 and guard < 60:
		guard += 1
		for ch in ch2._chairs:
			if ch.done: continue
			var n: Node3D = ch.node
			var stars: Array = gs.world.refs.star_spots
			var best: Vector3 = stars[0]; var bd := 1e9
			for i in 3:
				if not ch2._stars_done[i] and (stars[i] as Vector3).distance_to(n.global_position) < bd: bd = (stars[i] as Vector3).distance_to(n.global_position); best = stars[i]
			var dir := (best - n.global_position); dir.y = 0
			gs.player.global_position = n.global_position - dir.normalized() * 0.9
			ch2._push_chair(ch, ch.item)
			await wait(0.5)
		await get_tree().process_frame
	_log("phase after chairs: %d" % ch2.phase)
	while ch2.phase != 3: await get_tree().process_frame
	await shot("last_dance")
	guard = 0
	while ch2.phase == 3 and guard < 20000:
		guard += 1
		var b := ch2.beat_pos()
		if fmod(b, 3.0) < 0.28 and int(b / 3.0) >= 1 and ch2._dance.hit_bar != int(b / 3.0):
			Input.action_press("interact"); await get_tree().process_frame; Input.action_release("interact")
		await get_tree().process_frame
	_log("dance done: phase %d good=%s" % [ch2.phase, ch2._dance.get("good", -1)])
	await idle()
	expect("ch2_balcony"); await shot("host_settled")
	await go(Vector3(25.0, 0.05, 19.5), 0.0)
	await use("singer", Vector3(0, 0, -1.4))
	expect("ch2_return"); await shot("mara_freed")
	await go(Vector3(-2.0, 0.05, 6.0), 0.0); await idle()
	await watch_at(gs.world.refs.grand_clock_front + Vector3(0, 0.05, -0.5))
	await wait(1.0)
	while not Game.flag("slice_done") or gs.player.state != "free":
		Input.action_press("interact"); await get_tree().process_frame; Input.action_release("interact")
		await get_tree().process_frame
	await idle()
	expect("slice_end"); await shot("slice_end")
