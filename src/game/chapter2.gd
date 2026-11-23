class_name Chapter2
extends Node
## Chapter Two, "The Last Waltz": the anchor clock and Now/Then, the three missing sheets, the band's
## echo, the timing marks, the Forgotten Host (mirrors, chairs on the stars, the last dance),
## Mara on the balcony and the second chime.

var story: Story
var world: World
var player: Player
var screen: Node
var host: Character
var dancers: Array[Character] = []
var stand_sheets := {}
var encounter_active := false
var phase := 0
var _mirror_i := -1
var _mirror_t := 0.0
var _hits := 0
var _sweep := {}
var _chairs: Array = []
var _stars_done := [false, false, false]
var _star_glints: Array = []
var _beat_ui: Control
var _dance := {}
var _candles_lost_at_start := 0
var _frost_mat: StandardMaterial3D
var _mirror_mats := {}

const SHEETS := {"moon": "Moon", "star": "Star", "sun": "Sun"}
const STAND_ORDER := ["violin", "cello", "flute"]
const ANSWER := {"violin": "moon", "cello": "star", "flute": "sun"}
const BPM := 90.0

func setup(s: Story) -> void:
	story = s; world = s.world; player = s.player; screen = s.screen
	_frost_mat = StandardMaterial3D.new()
	_frost_mat.albedo_color = Color(0.75, 0.95, 1.0); _frost_mat.emission_enabled = true; _frost_mat.emission = Color(0.55, 1.0, 0.9)
	_frost_mat.emission_energy_multiplier = 2.5; _frost_mat.roughness = 0.2; _frost_mat.metallic = 0.6
	_build_ballroom()
	_build_balcony()
	if Save.profile.room_states.get("ballroom", "now") == "then": world.set_room_state("ballroom", "then")

func f(k: String) -> bool: return Game.flag(k)
func say(lines: Array, opts := {}) -> void: await story.say(lines, opts)

# ======================================================================== the ballroom
func _build_ballroom() -> void:
	var R := "ballroom"
	var r: Room = world.rooms[R]
	world.add_anchor({"room": R, "pos": world.refs.ballroom_anchor_pos + Vector3(0, 1.0, 0), "radius": 2.6, "on": func(_a): await shift()})
	# the Host waits at the edge of the floor
	host = story.npc("host", Vector3(33.6, 0.0, 6.0), -PI * 0.5, r)
	host.visible = f("host_met") and not f("host_resolved")
	world.add_observable({"room": R, "node": host, "time": 2.4, "on": func(_o):
		await say([["avery", "He hums before he moves. And he can't take his eyes off the band.", {"expr": "curious"}]])})
	# frozen dancers on the sealed night
	var spots: Array = world.refs.dancer_spots
	for i in spots.size():
		var d := story.npc("dancer_lady" if i % 2 == 0 else "dancer_gent", spots[i], randf() * TAU, r.state_then)
		d.bpm = BPM
		d.play("dance", 0.0)
		d._t = randf() * 10.0
		dancers.append(d)
		get_tree().create_timer(0.3 + i * 0.05).timeout.connect(func(): if not encounter_active: d.freeze = true)
	# star sheet: held by the dancer by the west windows
	var holder: Character = dancers[0]
	if not f("frag_star"):
		var sheet := story._pickup_mesh("sheet"); holder.attach(sheet, "hand.R"); sheet.position = Vector3(0, 0.12, 0.05)
		story.interact(R, holder.global_position + Vector3(0, 1.2, 0), "Take the sheet from", "the masked dancer", func(o):
			o.enabled = false; sheet.queue_free()
			_got_fragment("star", "The dancer's hand is ice-cold and doesn't let go until I say 'thank you'. Manners."), {"state": "then", "radius": 2.0, "cond": func(): return f("waltz_heard")})
	# moon sheet: on the broken piano, in the present
	if not f("frag_moon"):
		var ms := story._pickup_mesh("sheet"); r.state_now.add_child(ms); ms.global_position = world.refs.piano_pos
		var g := story.glint(world.refs.piano_pos + Vector3(0, 0.1, 0), r.state_now)
		story.interact(R, world.refs.piano_pos, "Take", "the sheet from the piano", func(o):
			o.enabled = false; ms.queue_free(); g.queue_free()
			_got_fragment("moon", "Torn from the score. A crescent moon drawn in the corner, in the same ink as the notes."), {"state": "now", "radius": 2.2, "cond": func(): return f("waltz_heard")})
	# sun sheet: behind the folding screen; push it aside on the sealed night
	var scr: Node3D = world.refs.screen
	if f("screen_moved"): scr.global_position = world.refs.screen_start + Vector3(-1.9, 0, -0.4)
	var push := story.interact(R, world.refs.screen_start + Vector3(0, 1.0, 0), "Push", "the folding screen", func(o):
		if Save.profile.room_states.get("ballroom", "now") != "then":
			await say([["avery", "It's wedged behind sixty years of fallen plaster. On the night itself, though...", {"expr": "curious"}]]); return
		o.enabled = false
		Audio.sfx("furniture_slide", scr.global_position)
		var tw := create_tween(); tw.tween_property(scr, "global_position", world.refs.screen_start + Vector3(-1.9, 0, -0.4), 1.2).set_trans(Tween.TRANS_SINE)
		Game.set_flag("screen_moved")
		await tw.finished
		await say([["avery", "Moved on the night it happened. So it's moved now, too. The house keeps what would have lasted.", {"expr": "delighted"}]]), {"radius": 2.2, "anim": "reach", "cond": func(): return not f("screen_moved")})
	if f("screen_moved"): push.enabled = false
	if not f("frag_sun"):
		var ss := story._pickup_mesh("sheet"); r.add_child(ss); ss.global_position = world.refs.sheet_sun_pos
		story.interact(R, world.refs.sheet_sun_pos + Vector3(0, 0.4, 0), "Take", "the sheet behind the screen", func(o):
			o.enabled = false; ss.queue_free()
			_got_fragment("sun", "A sun in the corner. Somebody hid this deliberately."), {"radius": 1.8, "anim": "pickup", "cond": func(): return f("screen_moved")})
	# the music stands
	var stands: Array = world.refs.music_stands
	for i in stands.size():
		var inst: String = STAND_ORDER[i]
		var sd: Dictionary = stands[i]
		story.interact(R, sd.pos, "Inspect", "the %s stand" % inst, func(_o): await _stand(inst, sd), {"radius": 2.0, "anim": "inspect"})
		if f("placed_" + inst): _place_sheet_mesh(inst, sd)
	_build_marks()
	# the band's echo on the stage
	world.add_echo({"room": R, "pos": Vector3(36.8, 0.8, 6.0), "radius": 3.6, "play": func(_e): await _band_echo()})
	# documents and treasures
	story.pickup("doc_menu", R, Vector3(12.0, 0.98, 11.3), "card", "then")
	story.pickup("doc_newspaper", R, world.refs.newspaper_pos, "paper", "now")
	story.pickup("rec_waltz", R, Vector3(38.6, 0.85, 14.0), "record", "then")
	story.pickup("tr_mask", R, world.refs.mask_stand_pos, "mask", "now")
	story._emblem_trace(world.refs.emblem_ballroom, R, "em_ballroom")
	story.add_code_trace(world.refs.code_disco, R, "BOOGIEWOOGIE")
	story.interact(R, world.refs.cake_pos, "Eat", "a slice of New Year cake", func(_o):
		Game.set_flag("cake_then")
		Audio.sfx("eat", world.refs.cake_pos)
		await say([["avery", "Oh, that's good. Almond, and something like snow. I'm eating cake from 1891.", {"expr": "delighted"}]]), {"state": "then", "radius": 2.0})
	story.interact(R, world.refs.cake_pos, "Go back for", "seconds", func(_o):
		Game.set_flag("cake_now")
		if f("cake_then"): Game.unlock("let_them_eat_cake")
		await say([["avery", "...Sixty years later, it's mostly mould. Never mind. Seconds were always a mistake.", {"expr": "sad"}]]), {"state": "now", "radius": 2.0, "cond": func(): return f("cake_then")})

func _got_fragment(which: String, line: String) -> void:
	Game.set_flag("frag_" + which)
	Audio.sfx("pickup_paper", player.global_position)
	Events.toast.emit("Sheet music: the %s" % SHEETS[which], "collect")
	await say([["avery", line, {"expr": "curious"}]])
	if f("frag_moon") and f("frag_star") and f("frag_sun") and Game.objective() == "ch2_fragments":
		await say([["avery", "Three sheets. The notes are right on all of them. But which stand does each belong on?", {"expr": "determined"}]])
		story.objective("ch2_order")

func shift() -> void:
	var r: Room = world.rooms.ballroom
	var to := "then" if r.state == "now" else "now"
	player.lock()
	Audio.sfx("watch_shift", player.global_position, {"vol": 2.0})
	world.post.ripple(1.3)
	player.rig.shake(0.35)
	await get_tree().create_timer(0.55).timeout
	world.set_room_state("ballroom", to)
	Save.profile.room_states.ballroom = to
	Save.profile.stats.shifts = int(Save.profile.stats.shifts) + 1
	_update_music()
	await get_tree().create_timer(0.6).timeout
	player.unlock()
	if not f("first_shift"):
		Game.set_flag("first_shift")
		Game.unlock("then_and_now")
		await say([["avery", "Candles. Music. People. It's the party. It's still the party.", {"expr": "surprised"}],
			["avery", "And the waltz is wrong. It stumbles, every time, in the same place.", {"expr": "curious"}]])
		if Game.objective() == "ch2_anchor": story.objective("ch2_listen")

func _update_music() -> void:
	if encounter_active or world.current not in ["ballroom", "balcony"]: return
	if Audio.current_track != "ballroom": Audio.play_music("ballroom", 1.5)
	var then: bool = world.rooms.ballroom.state == "then"
	var done := f("waltz_complete")
	Audio.set_stems([1.0 if not then and not done else 0.0, 1.0 if not then and done else 0.0, 1.0 if then and not done else 0.0, 1.0 if then and done else 0.0])

func on_room(id: String, prev: String) -> void:
	if id == "ballroom" and Game.objective() == "ch2_host" and not encounter_active and not f("host_resolved"):
		# resuming a save made mid-encounter: the marks are already revealed, so start it again here
		while not screen.ready_to_play: await get_tree().process_frame
		await get_tree().create_timer(1.2).timeout
		if world.current == "ballroom" and not encounter_active: await _start_encounter()
		return
	if id == "ballroom":
		if not encounter_active: _update_music()
		if Game.objective() == "ch2_enter":
			Game.set_flag("ballroom_entered")
			story.objective("ch2_anchor")
			await say([["avery", "The Grand Ballroom. Sixty years of dust, and one clock in the corner glowing green as a cat's eye.", {"expr": "surprised"}]])
	if id == "balcony" and prev == "ballroom": Audio.play_music("balcony", 2.0)
	if id == "hall" and Game.objective() == "ch2_return" and f("mara_freed"): _place_mara_at_clock()

# -------------------------------------------------------------------------------- stands & sheets
func _stand(inst: String, sd: Dictionary) -> void:
	match Game.objective():
		"ch2_listen":
			Game.set_flag("waltz_heard")
			Game.add_clue("c_waltz")
			await say([["avery", "One, two, three. One, two, three. One, two... and the fourth bar never gets its third beat.", {"expr": "curious"}],
				["avery", "Three stands. Violin, cello, flute. And all three are missing a page.", {"expr": "determined"}]])
			await _meet_host()
			story.objective("ch2_fragments")
		"ch2_place":
			await _place_on(inst, sd)
		_:
			if f("placed_" + inst): await say([["avery", "The %s part, in its place. You can almost hear it." % inst, {"expr": "happy"}]])
			else: await say([["avery", "A carved %s on the stand. The page that should be here is missing." % inst, {"expr": "curious"}]])

func _meet_host() -> void:
	if f("host_met"): return
	Game.set_flag("host_met")
	host.visible = true
	host.set_presence(0.0)
	var tw := create_tween(); tw.tween_method(host.set_presence, 0.0, 1.0, 1.2)
	Audio.sfx("ghost_appear", host.global_position)
	await say([["host", "Ahem. AHEM. A guest! At last, a guest who isn't stuck on the second beat.", {"expr": "delighted", "anim": "bow", "frame": true}],
		["host", "Welcome, welcome to the Ashcombe masquerade. I am your host. I have been your host for a remarkably long time.", {"expr": "proud", "anim": "gesture"}],
		["avery", "You're waiting for the waltz to end.", {"expr": "curious"}],
		["host", "A host cannot leave before the last dance, my dear. It simply isn't done. And this waltz... never... finishes.", {"expr": "sad"}],
		["host", "The band lost its pages. Lost them, or someone took them. Find them, and I shall be in your debt for at least another sixty years.", {"expr": "smug", "anim": "moustache"}]], {"frame": true})
	Game.add_clue("c_host")

func _place_on(inst: String, sd: Dictionary) -> void:
	if f("placed_" + inst): return
	var have: Array = []
	for k in ["moon", "star", "sun"]:
		var used := false
		for i in STAND_ORDER: if f("placed_" + i) and ANSWER[i] == k: used = true
		if f("frag_" + k) and not used: have.append(k)
	if have.is_empty(): return
	var opts: Array = have.map(func(k): return "Place the %s sheet" % SHEETS[k])
	opts.append("Not yet")
	var c := await story.dlg.choose("avery", "Which sheet goes on the %s stand?" % inst, opts)
	if c >= have.size(): return
	var pick: String = have[c]
	if ANSWER[inst] == pick:
		Game.set_flag("placed_" + inst)
		_place_sheet_mesh(inst, sd)
		Audio.sfx("note_" + inst, sd.pos)
		await say([["avery", "That's it. That's the %s part." % inst, {"expr": "happy"}]])
	else:
		Save.profile.stats.wrong_fragments = int(Save.profile.stats.wrong_fragments) + 1
		Game.set_flag("wrong_sheet")
		Audio.sfx("note_wrong", sd.pos)
		host.expression = "worried"
		await say([["host", "Oh dear. Oh, no. That's the right tune on entirely the wrong instrument.", {"expr": "worried"}]])
		return
	if f("placed_violin") and f("placed_cello") and f("placed_flute"):
		for t in _mark_traces: t.enabled = true
		await say([["avery", "All three in place. The notes are right... but the timing still isn't written anywhere.", {"expr": "curious"}]])
		story.objective("ch2_marks")

func _place_sheet_mesh(inst: String, sd: Dictionary) -> void:
	if stand_sheets.has(inst): return
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.quad(0.3, 0.4)
	mi.material_override = Props.decal_mat("sheet_%s" % ANSWER[inst], 0.8)
	world.rooms.ballroom.add_child(mi)
	mi.global_transform = sd.sheet_xform
	stand_sheets[inst] = mi

func _build_marks() -> void:
	var stands: Array = world.refs.music_stands
	for i in stands.size():
		var sd: Dictionary = stands[i]
		var xf: Transform3D = sd.sheet_xform
		var node := GuestWingBuilder.trace_mesh(world.rooms.ballroom, "sym_mark", Vector2(0.34, 0.34), xf * Transform3D(Basis(), Vector3(0, 0.05, 0.03)), Color(1.0, 0.85, 0.5))
		var k := "marks_%d" % (i + 1)
		if f(k):
			(node.material_override as ShaderMaterial).set_shader_parameter("revealed", 1.0); continue
		var all_placed := f("placed_violin") and f("placed_cello") and f("placed_flute")
		var t := world.add_trace({"node": node, "pos": node.global_position, "room": "ballroom", "threshold": 1.2, "enabled": all_placed})
		t.on = func(): await _mark_revealed(k)
		_mark_traces.append(t)

var _mark_traces: Array = []

func _mark_revealed(k: String) -> void:
	Game.set_flag(k)
	Audio.sfx("mark_reveal", player.global_position)
	if f("marks_1") and f("marks_2") and f("marks_3"):
		Game.set_flag("waltz_complete")
		if Save.profile.stats.wrong_fragments == 0: Game.unlock("perfect_pitch")
		_update_music()
		await say([["avery", "Breath marks. A held note in the fourth bar. The third beat was never missing. They just never waited for it.", {"expr": "delighted"}]])
		await _start_encounter()

# -------------------------------------------------------------------------------- the band's echo
func _band_echo() -> void:
	if Game.objective() != "ch2_order" and not f("echo_band"):
		Events.toast.emit("The watch hums. The stage remembers, but not yet clearly enough.", "info"); return
	player.lock()
	Audio.sfx("watch_open", player.global_position)
	world.post.ripple(1.0)
	var tw := create_tween(); tw.tween_property(world.post, "echo", 1.0, 1.0)
	Audio.play_music("echo", 1.0)
	var band: Array[Character] = []
	var acts := ["play_violin", "play_cello", "play_flute"]
	var stands: Array = world.refs.music_stands
	var signs: Array = []
	for i in 3:
		var m := Character.create("musician")
		world.rooms.ballroom.add_child(m)
		var sp: Vector3 = stands[i].pos
		m.global_position = Vector3(sp.x + 0.9, sp.y - 1.1, sp.z)
		m.rotation.y = -PI * 0.5
		m.bpm = BPM
		m.play(acts[i], 0.0)
		band.append(m)
		var s := MeshInstance3D.new(); s.mesh = MeshKit.quad(0.45, 0.6)
		s.material_override = Props.decal_mat("sheet_%s" % ANSWER[STAND_ORDER[i]], 0.6, 1.5, true)
		world.rooms.ballroom.add_child(s)
		s.global_position = m.global_position + Vector3(0, 2.4, 0); s.rotation.y = -PI * 0.5
		signs.append(s)
	player.rig.cinematic(Vector3(31.5, 2.4, 6.0), Vector3(37.2, 1.4, 6.0), 50.0)
	await say([["", "Through the watch: the band, on the night itself. Each player holds up their page as the waltz begins.", {"wait": 4.0}],
		["avery", "Violin: the moon. Cello: the star. Flute: the sun.", {"expr": "determined", "wait": 3.5}]])
	var back := create_tween(); back.tween_property(world.post, "echo", 0.0, 1.0)
	for m in band: m.queue_free()
	for s in signs: s.queue_free()
	player.rig.release()
	_update_music()
	player.unlock()
	if not f("echo_band"):
		Game.set_flag("echo_band")
		story.objective("ch2_place")

# ======================================================================== the Forgotten Host
func _start_encounter() -> void:
	if encounter_active or f("host_resolved"): return
	if Game.objective() != "ch2_host": story.objective("ch2_host")
	player.lock()
	if world.rooms.ballroom.state != "then":
		world.post.ripple(1.0)
		world.set_room_state("ballroom", "then"); Save.profile.room_states.ballroom = "then"
	host.visible = true; host.set_presence(1.0)
	host.global_position = Vector3(30.0, 0, 6.0)
	player.rig.cinematic(Vector3(21.0, 2.0, 2.0), Vector3(30.0, 1.6, 6.0), 46.0)
	await say([["host", "It's... it's whole. The whole waltz. Do you know what this means?", {"expr": "surprised", "frame": false}],
		["host", "It means it will END. And then the night ends, and then... no. No, no. Not yet!", {"expr": "scared", "anim": "cower"}],
		["host", "One more minute! I simply must insist on one more minute!", {"expr": "angry", "anim": "sweep", "anim_dur": 1.2}]])
	player.rig.release()
	encounter_active = true
	_candles_lost_at_start = int(Save.profile.stats.candles_lost)
	Audio.play_music("boss", 1.0)
	Audio.set_stems([1.0, 0.0, 0.0])
	host.visible = false
	phase = 1; _hits = 0; _mirror_i = -1; _mirror_t = 1.5
	Events.toast.emit("He's hiding in the mirrors. When one frosts over, flare it with %s." % Controls.label("flare"), "hint")
	player.flared.connect(_on_flare)
	player.unlock()
	screen.autosave("encounter")

func _timing() -> float: return 1.5 if Settings.data.assist.extended_timing else 1.0
func _aggr() -> float: return {"none": 0.5, "reduced": 0.7, "normal": 1.0}.get(Settings.data.assist.ghost_aggression, 1.0)

func _process(dt: float) -> void:
	if not encounter_active: return
	match phase:
		1: _phase_mirrors(dt)
		2: _phase_chairs(dt)
		3: _phase_dance(dt)
	if _sweep.size() > 0: _do_sweep(dt)

# ------------------------------------------------- phase 1: mirrors
func _phase_mirrors(dt: float) -> void:
	var mirrors: Array = world.refs.ballroom_mirrors
	_mirror_t -= dt
	if _mirror_i < 0:
		if _mirror_t <= 0.0 and _sweep.is_empty():
			_mirror_i = randi() % mirrors.size()
			_mirror_t = 3.6 * _timing() / _aggr()
			_frost(_mirror_i, true)
			Audio.sfx("host_hum", mirrors[_mirror_i].center, {"vol": 2.0, "range": 40.0})
	elif _mirror_t <= 0.0:
		# too slow: he sweeps out across the floor
		var m: Dictionary = mirrors[_mirror_i]
		_frost(_mirror_i, false)
		_mirror_i = -1
		_mirror_t = 2.2 / _aggr()
		_begin_sweep(m.center * Vector3(1, 0, 1), player.global_position)

func _frost(i: int, on: bool) -> void:
	var m: Dictionary = world.refs.ballroom_mirrors[i]
	for key in ["glass", "top"]:
		var mi: MeshInstance3D = m.get(key)
		if mi == null: continue
		if on:
			_mirror_mats[mi] = mi.material_override
			mi.material_override = _frost_mat
		elif _mirror_mats.has(mi):
			mi.material_override = _mirror_mats[mi]

func _on_flare(origin: Vector3, dir: Vector3) -> void:
	if phase == 1 and _mirror_i >= 0:
		var m: Dictionary = world.refs.ballroom_mirrors[_mirror_i]
		var to: Vector3 = m.center - origin
		if to.length() < 18.0 and to.normalized().dot(dir) > 0.86 - (0.06 if Settings.data.assist.aim_assist else 0.0):
			_frost(_mirror_i, false)
			_mirror_i = -1
			_hits += 1
			_stun(m.center)
	elif phase > 0 and host.visible:
		var to2 := host.global_position + Vector3(0, 1.2, 0) - origin
		if to2.length() < 9.0 and to2.normalized().dot(dir) > 0.85:
			host.set_flash(1.0)
			get_tree().create_timer(0.3).timeout.connect(func(): host.set_flash(0.0))
			Audio.react("host", "hurt")

func _stun(at: Vector3) -> void:
	host.visible = true
	host.global_position = at * Vector3(1, 0, 1) + (Vector3(25, 0, 6) - at * Vector3(1, 0, 1)).normalized() * 1.2
	host.play("dizzy", 1.8)
	host.set_flash(1.0)
	Audio.sfx("host_stun", at)
	Audio.react("host", "hurt")
	var lines := ["Ow! Rude!", "My eyes! My monocle!", "That was entirely uncalled for!"]
	Events.toast.emit("\"%s\"" % lines[mini(_hits - 1, 2)], "info")
	Audio.set_stems([1.0, 1.0 if _hits >= 1 else 0.0, 1.0 if _hits >= 2 else 0.0])
	await get_tree().create_timer(1.8).timeout
	host.set_flash(0.0)
	if _hits >= 3:
		await _to_phase2()
	else:
		host.visible = false
		_mirror_t = 1.4

func _begin_sweep(from: Vector3, to: Vector3) -> void:
	host.visible = true
	host.global_position = from
	var d := (to - from); d.y = 0
	_sweep = {"from": from, "dir": d.normalized(), "t": 0.0, "len": d.length() + 6.0, "speed": 7.5 * _aggr()}
	host.rotation.y = atan2(d.x, d.z)
	host.play("sweep", 0.0)
	host.expression = "angry"
	Audio.sfx("host_sweep", from, {"vol": 2.0})

func _do_sweep(dt: float) -> void:
	_sweep.t += dt * _sweep.speed
	var p: Vector3 = _sweep.from + _sweep.dir * _sweep.t
	p.x = clampf(p.x, 11.0, 34.0); p.z = clampf(p.z, -5.0, 17.0)
	host.global_position = p
	if player.global_position.distance_to(p) < 1.1: player.hurt(p)
	if _sweep.t >= _sweep.len:
		_sweep = {}
		host.clear_action()
		if phase == 1: host.visible = false

# ------------------------------------------------- phase 2: chairs on the stars
func _to_phase2() -> void:
	phase = 0
	player.lock()
	host.clear_action()
	host.global_position = Vector3(25.0, 0, 6.0)
	await say([["host", "Fine! FINE. But a host cannot dance without his guests seated. Chairs! On the stars! It is TRADITION.", {"expr": "angry", "anim": "point"}]], {"frame": true})
	host.visible = false
	var stars: Array = world.refs.star_spots
	var B := RoomBuilder.new(world, world.rooms.ballroom).into(world.rooms.ballroom.state_then, "then")
	for i in 3:
		var sp: Vector3 = stars[i]
		var g := story.glint(sp + Vector3(0, 0.08, 0), world.rooms.ballroom.state_then, Color(0.6, 1.0, 0.9))
		g.scale = Vector3.ONE * 3.0
		_star_glints.append(g)
		var start: Vector3 = sp + Vector3(cos(i * 2.1) * 3.4, 0, sin(i * 2.1) * 3.4)
		start.x = clampf(start.x, 12.5, 32.0); start.z = clampf(start.z, -4.0, 16.0)
		var chair := Props.gilt_chair(B, {"pos": start, "ry": randf() * TAU}, {"mat": "velvet_red", "collide": false, "dynamic": true})
		var ch := {"node": chair, "done": false}
		_chairs.append(ch)
		ch.item = story.interact("ballroom", start + Vector3(0, 0.6, 0), "Push", "the chair", func(o): _push_chair(ch, o), {"state": "then", "radius": 1.7, "anim": "reach"})
	B.finalize_batches()
	# the dancers wake and waltz in wide loops, leaving gaps on the third beat
	for d in dancers:
		d.freeze = false
	_dance_t = 0.0
	phase = 2
	player.unlock()
	Audio.set_stems([1.0, 1.0, 0.0])
	Events.toast.emit("Push the three chairs onto the glowing stars. Mind the dancers.", "hint")

var _dance_t := 0.0

func _push_chair(ch: Dictionary, it: Dictionary) -> void:
	if ch.done: return
	var n: Node3D = ch.node
	var d := n.global_position - player.global_position; d.y = 0
	var target := n.global_position + d.normalized() * 1.5
	target.x = clampf(target.x, 12.0, 33.0); target.z = clampf(target.z, -4.5, 16.5)
	var stars: Array = world.refs.star_spots
	var snap := -1
	for i in 3:
		if not _stars_done[i] and (stars[i] as Vector3).distance_to(target) < 1.25: snap = i
	if snap >= 0: target = stars[snap]
	Audio.sfx("furniture_slide", n.global_position)
	var tw := create_tween(); tw.tween_property(n, "global_position", target, 0.45).set_trans(Tween.TRANS_QUAD)
	it.pos = target + Vector3(0, 0.6, 0)
	if snap >= 0:
		ch.done = true; it.enabled = false
		_stars_done[snap] = true
		_star_glints[snap].queue_free()
		Audio.sfx("star_lock", target)
		var n_done := 0
		for s in _stars_done: if s: n_done += 1
		Audio.set_stems([1.0, 1.0, 1.0 if n_done >= 2 else 0.0])
		if n_done >= 3:
			await tw.finished
			await _to_phase3()

func _phase_chairs(dt: float) -> void:
	_dance_t += dt
	var c := Vector3(25.0, 0, 6.0)
	for i in dancers.size():
		var d := dancers[i]
		var pair := i / 2
		var rad := 4.8 + pair * 2.2
		var spd := (0.32 + pair * 0.05) * _aggr() * (1.0 if pair % 2 == 0 else -1.0)
		var a := _dance_t * spd + i * PI + pair * 0.7
		var p := c + Vector3(cos(a), 0, sin(a) * 0.82) * rad + Vector3(cos(a * 3.0), 0, sin(a * 3.0)) * 0.6 * (i % 2 * 2 - 1)
		var prev := d.global_position
		d.global_position = p
		var v := p - prev
		if v.length() > 0.001: d.rotation.y = atan2(v.x, v.z) + PI * 0.5
		if player.global_position.distance_to(p) < 0.75: player.hurt(p)

# ------------------------------------------------- phase 3: the last dance
func _to_phase3() -> void:
	phase = 0
	player.lock()
	for d in dancers:
		d.play("bow", 1.5)
	host.visible = true
	host.global_position = Vector3(25.0, 0, 7.6)
	host.rotation.y = PI
	player.teleport(Vector3(25.0, 0.05, 5.2), 0.0)
	host.clear_action()
	host.expression = "sad"
	await say([["host", "Everyone seated. The band ready. Well then.", {"expr": "sad", "frame": true}],
		["host", "I do not remember how it ends. I never got that far. Would you... would you count it for me?", {"expr": "worried", "anim": "bow"}],
		["avery", "One, two, three. I'll take the one.", {"expr": "determined"}]], {"frame": true})
	Events.toast.emit("Press %s on every ONE. Listen for the low note." % Controls.label("interact"), "hint")
	_beat_ui = BeatRing.new(); _beat_ui.ch = self
	screen.hud.add_child(_beat_ui)
	_dance = {"bar": 0, "good": 0, "miss": 0, "last_bar": -1, "hit_bar": -1, "t0": 0.0}
	Audio.play_music("lastdance", 0.0)
	_dance.t0 = Time.get_ticks_msec() / 1000.0
	host.bpm = BPM; player.avatar.bpm = BPM
	host.play("dance", 0.0)
	player.avatar.play("dance", 0.0)
	player.state = "dance"
	phase = 3

func beat_pos() -> float:
	var t := Audio.music_position()
	if t <= 0.0: t = Time.get_ticks_msec() / 1000.0 - _dance.t0
	return t * BPM / 60.0

func _phase_dance(_dt: float) -> void:
	var b := beat_pos()
	var bar := int(b / 3.0)
	var phase_in_bar := fmod(b, 3.0)
	var win := 0.32 * _timing()
	# slow turn around the floor together
	var a := b / 3.0 * 0.35
	var c := Vector3(25.0, 0, 6.4)
	player.global_position = c + Vector3(sin(a), 0, cos(a)) * -0.7 + Vector3(0, 0.05, 0)
	host.global_position = c + Vector3(sin(a), 0, cos(a)) * 0.7
	player.facing = a; player.avatar.rotation.y = a
	host.rotation.y = a + PI
	if bar != _dance.last_bar:
		if _dance.last_bar >= 1 and _dance.hit_bar != _dance.last_bar:
			_dance.miss += 1
			host.expression = "worried"
			Audio.sfx("dance_miss", host.global_position)
		_dance.last_bar = bar
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("use_tool"):
		var off := minf(phase_in_bar, 3.0 - phase_in_bar)
		var target_bar := bar if phase_in_bar < 1.5 else bar + 1
		if off < win and _dance.hit_bar != target_bar and target_bar >= 1:
			_dance.hit_bar = target_bar
			_dance.good += 1
			host.expression = "delighted"
			if _beat_ui: _beat_ui.flash = 1.0
			Audio.sfx("dance_step", host.global_position, {"vol": -4.0})
		else:
			if _beat_ui: _beat_ui.flash = -1.0
	if _dance.miss >= 3:
		_dance.miss = 0; _dance.good = 0
		Events.toast.emit("\"From the top, if you'd be so kind. One, two, three...\"", "info")
	if _dance.good >= 8:
		phase = 0
		_end_encounter()

func _end_encounter() -> void:
	encounter_active = false
	player.flared.disconnect(_on_flare)
	if _beat_ui: _beat_ui.queue_free(); _beat_ui = null
	player.lock()
	player.avatar.clear_action()
	host.clear_action()
	for d in dancers: d.play("bow", 2.0)
	Audio.play_music("victory", 0.5)
	host.expression = "happy"
	await say([["host", "Oh. Oh, my. It ended. The waltz ended, and I'm... still here. How wonderfully disappointing.", {"expr": "delighted", "frame": true}],
		["host", "I remember now. That night, the master asked for one more minute. And the whole house gave it to him.", {"expr": "sad"}],
		["host", "Here. I found this in my pocket after the clocks stopped. I think it belongs to whoever is brave enough to look.", {"expr": "neutral", "anim": "hold"}],
		["host", "And this key opens the mirror on the north wall. There's someone on the balcony who's been waiting even longer than I have.", {"expr": "proud", "anim": "point"}],
		["host", "Thank you for the dance. You count beautifully.", {"expr": "happy", "anim": "bow"}]], {"frame": true})
	Game.add_clue("c_memory")
	Game.set_flag("host_resolved")
	Game.add_ghost_card("host"); Game.add_ghost_card("dancers")
	Game.unlock("last_dance")
	if int(Save.profile.stats.candles_lost) == _candles_lost_at_start: Game.unlock("unflappable")
	Game.unlock_costume("avery", "masquerade")
	if Save.profile.get("character", "avery") == "mara": Game.unlock_costume("mara", "masquerade")
	var tw := create_tween(); tw.tween_method(host.set_presence, 1.0, 0.0, 2.5)
	tw.tween_callback(func(): host.visible = false)
	for d in dancers:
		var tw2 := create_tween(); tw2.tween_method(d.set_presence, 1.0, 0.0, 2.5); tw2.tween_callback(func(): d.visible = false)
		d.freeze = true
	_open_mirror_door()
	player.unlock()
	_update_music()
	story.objective("ch2_balcony")

func _open_mirror_door(instant := false) -> void:
	Game.set_flag("balcony_open")
	world.refs.mirror_door_col.disabled = true
	var leaf: Node3D = world.refs.mirror_door
	if instant: leaf.rotation.y = -1.5; return
	Audio.sfx("door_creak", leaf.global_position)
	var tw := create_tween(); tw.tween_property(leaf, "rotation:y", -1.5, 2.4).set_trans(Tween.TRANS_SINE)

# ======================================================================== the balcony
var mara: Character

func _build_balcony() -> void:
	if f("host_resolved"):
		host.visible = false
		for d in dancers: d.visible = false
		_open_mirror_door(true)
	story.pickup("doc_letter", "balcony", world.refs.letter_pos, "paper")
	story.pickup("pf_balcony", "balcony", world.refs.portrait_fragment_balcony, "fragment")
	if not f("mara_freed"):
		mara = story.npc("mara_frozen", world.refs.mara_spot, PI, world.rooms.balcony)
		story.dlg.register("mara", mara)
		mara.play("sing", 0.0)
		mara.expression = "happy"
		get_tree().create_timer(0.4).timeout.connect(func(): mara.freeze = true)
		story.interact("balcony", world.refs.mara_spot + Vector3(0, 1.4, 0), "Show the watch to", "the singer", func(o):
			o.enabled = false
			await _free_mara(), {"radius": 2.4, "anim": ""})

func _free_mara() -> void:
	player.lock()
	player.set_tool("watch")
	player.avatar.hold_watch = true
	player.rig.cinematic(world.refs.mara_spot + Vector3(2.2, 1.6, -2.6), world.refs.mara_spot + Vector3(0, 1.5, 0), 44.0)
	await say([["avery", "She's not a ghost. She's... paused. Mid-note.", {"expr": "worried"}],
		["avery", "The watch is ticking faster. Come on. One more minute. Yours, this time.", {"expr": "determined"}]])
	Audio.sfx("watch_shift", player.global_position, {"vol": 3.0})
	world.post.ripple(1.6)
	await get_tree().create_timer(0.8).timeout
	mara.freeze = false
	mara.clear_action()
	mara.play("startle", 1.0)
	mara.expression = "surprised"
	player.avatar.hold_watch = false
	await say([["mara", "...-ight! Oh! Oh my goodness. Where did the audience go?", {"expr": "surprised"}],
		["avery", "How long do you think you've been standing here?", {"expr": "curious"}],
		["mara", "Since the second verse? Three minutes? Why are you looking at me like that?", {"expr": "worried"}],
		["avery", "It's a long story. It's mostly one minute long.", {"expr": "smug"}],
		["mara", "Mara Bell. Singer, between engagements. I followed a waltz in here and the whole world held its breath.", {"expr": "happy", "anim": "curtsy"}],
		["mara", "You've got the watch. The clock wants it, I can hear it from here. I'll come with you.", {"expr": "determined"}]])
	player.rig.release()
	Game.set_flag("mara_freed")
	Game.unlock("duet")
	if not Save.profile.unlocked_characters.has("mara"): Save.profile.unlocked_characters.append("mara")
	Game.unlock_costume("mara", "gown")
	Events.toast.emit("Mara Bell joins you. Switch character at the hall wardrobe.", "collect")
	var tw := create_tween(); tw.tween_property(mara, "modulate", Color(1, 1, 1, 1), 0.1)
	player.unlock()
	story.objective("ch2_return")
	mara.queue_free()
	mara = null

func _place_mara_at_clock() -> void:
	if story.npcs.has("mara_hall") or Save.profile.get("character", "avery") == "mara": return
	var m := story.npc("mara_frozen", Vector3(1.6, 2.5, 16.8), PI * 0.8, world.rooms.hall)
	story.npcs["mara_hall"] = m
	story.dlg.register("mara", m)
	m.expression = "curious"

func second_chime() -> void:
	player.lock()
	player.rig.cinematic(Vector3(-2.5, 4.0, 12.5), Vector3(0, 5.0, 19.2), 48.0)
	await say([["mara", "Go on. Hold it up. I'll count you in.", {"expr": "happy"}],
		["avery", "One more minute.", {"expr": "determined"}]])
	world.post.ripple(1.4)
	story.chime(2)
	Game.set_flag("chime2")
	Game.unlock("two_chimes")
	await get_tree().create_timer(1.2).timeout
	await say([["", "The Grand Clock strikes twice. Two of twelve lamps burn on its face. Somewhere above, a door that wasn't there unlocks."],
		["mara", "Two chimes. Ten to go. Ten more rooms like that one, ten more ghosts who can't let go of midnight.", {"expr": "determined"}],
		["avery", "Then we'd better get counting.", {"expr": "smug"}]])
	player.rig.release()
	Game.set_flag("slice_done")
	await screen.end_card()
	story.objective("slice_end")
	player.unlock()
	var all := true
	for k in GameData.COLLECTIBLES.keys(): if not Save.profile.collectibles.has(k): all = false
	if all: Game.unlock("curiosity")

class BeatRing:
	extends Control
	var ch: Chapter2
	var flash := 0.0
	func _ready() -> void:
		set_anchors_and_offsets_preset(PRESET_FULL_RECT); mouse_filter = MOUSE_FILTER_IGNORE
	func _process(dt: float) -> void:
		flash = move_toward(flash, 0.0, dt * 3.0)
		queue_redraw()
	func _draw() -> void:
		var vp := get_viewport_rect().size
		var c := Vector2(vp.x * 0.5, vp.y * 0.72)
		var b := ch.beat_pos()
		var ph := fmod(b, 3.0)
		for i in 3:
			var p := c + Vector2((i - 1) * 70, 0)
			var active := int(ph) == i
			var r := 16.0 + (10.0 if active else 0.0) * (1.0 - fmod(ph, 1.0))
			var col := UIKit.GOLD if i == 0 else UIKit.MUTED
			if active: col = col.lightened(0.3)
			draw_circle(p, r, col * Color(1, 1, 1, 0.25))
			draw_arc(p, r, 0, TAU, 32, col, 2.0)
			draw_string(UIKit.font("head"), p + Vector2(-8, 8), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 16, 22, col)
		var approach := 1.0 - fmod(b, 3.0) / 3.0
		draw_arc(c + Vector2(-70, 0), 16.0 + approach * 60.0, 0, TAU, 48, UIKit.SPECTRAL * Color(1, 1, 1, 0.6), 2.0)
		if flash > 0.0: draw_circle(c + Vector2(-70, 0), 30, UIKit.SPECTRAL * Color(1, 1, 1, flash * 0.6))
		elif flash < 0.0: draw_circle(c + Vector2(-70, 0), 30, Color(1, 0.3, 0.3, -flash * 0.4))
		var good: int = ch._dance.get("good", 0)
		draw_string(UIKit.font("caps"), c + Vector2(-150, 70), "Steps in time: %d / 8" % good, HORIZONTAL_ALIGNMENT_CENTER, 300, 20, UIKit.PAPER)
