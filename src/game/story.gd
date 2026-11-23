class_name Story
extends Node
## The vertical slice's script: places the cast, collectibles, clues and puzzles, and runs the
## Prologue and Chapter One. Chapter Two lives in chapter2.gd. Everything restores from save flags,
## so loading a game mid-chapter rebuilds the house exactly as it was left.

var screen: Node          # GameScreen
var world: World
var player: Player
var dlg: Dialogue
var ch2: Chapter2
var npcs := {}
var clocks_seen := {}
var pip_spot := 0
var _porter_drift := 0.0
var _porter_target := Vector3.ZERO
var _jangle_t := 0.0

const PIP_SPOTS := [Vector3(-33.2, 0.2, 4.4), Vector3(-25.8, 0.2, 3.0), Vector3(-15.4, 0.2, 5.0)]

func setup(p_screen: Node) -> void:
	screen = p_screen
	world = screen.world; player = screen.player; dlg = screen.dialogue
	_build_collectibles()
	_build_prologue()
	_build_hall()
	_build_guest_wing()
	ch2 = Chapter2.new(); ch2.name = "Chapter2"; add_child(ch2)
	ch2.setup(self)
	Events.room_entered.connect(_on_room)
	Events.deduction_made.connect(_on_deduction)

# ======================================================================== helpers
func game_flag(k: String) -> bool: return Game.flag(k)

func interact(room: String, pos: Vector3, verb: String, label: String, on: Callable, opts := {}) -> Dictionary:
	var o := {"room": room, "pos": pos, "verb": verb, "label": label, "on": on}
	o.merge(opts, true)
	return world.add_interactable(o)

func say(lines: Array, opts := {}) -> void:
	await dlg.say(lines, opts)

func me() -> String: return Save.profile.get("character", "avery")

func objective(id: String) -> void:
	Game.set_objective(id)
	screen.autosave("objective")

func npc(id: String, pos: Vector3, yaw: float, parent: Node3D, costume := "") -> Character:
	var c := Character.create(id, costume)
	parent.add_child(c)
	c.global_position = pos
	c.rotation.y = yaw
	npcs[id] = c
	dlg.register(id, c)
	c.big_head = Settings.data.cheats.big_head
	if Settings.data.cheats.sunglasses and c.look == "ghost": _sunglasses(c)
	if Settings.data.cheats.ghost_costumes and c.look == "ghost": _party_hat(c)
	return c

func _sunglasses(c: Character) -> void:
	var n := Node3D.new()
	var m := MaterialLib.color(Color(0.02, 0.02, 0.03), 0.15, 0.6)
	for s in [-1, 1]:
		var g := MeshInstance3D.new(); g.mesh = MeshKit.cyl(0.028, 0.028, 0.006, 16); g.material_override = m
		g.rotation.x = PI * 0.5; g.position = Vector3(s * 0.036, 0.155, 0.125); n.add_child(g)
	var br := MeshInstance3D.new(); br.mesh = MeshKit.box(Vector3(0.05, 0.006, 0.006)); br.material_override = m; br.position = Vector3(0, 0.16, 0.126); n.add_child(br)
	c.attach(n, "head")

func _party_hat(c: Character) -> void:
	var h := MeshInstance3D.new(); h.mesh = MeshKit.cyl(0.0, 0.07, 0.2, 16)
	h.material_override = MaterialLib.color(Color.from_hsv(randf(), 0.7, 0.95), 0.5)
	h.position = Vector3(0.03, 0.33, 0); h.rotation.z = -0.25
	c.attach(h, "head")

func glint(pos: Vector3, parent: Node3D, color := Color(1.0, 0.86, 0.55)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(0.5, 0.5); mi.mesh = q
	var sm := ShaderMaterial.new(); sm.shader = load("res://src/fx/glow.gdshader")
	sm.set_shader_parameter("intensity", 0.5)
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	var tw := mi.create_tween().set_loops()
	tw.tween_method(func(v): sm.set_shader_parameter("intensity", v), 0.25, 0.8, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(v): sm.set_shader_parameter("intensity", v), 0.8, 0.25, 1.1).set_trans(Tween.TRANS_SINE)
	return mi

func add_code_trace(node: MeshInstance3D, room: String, code: String) -> void:
	if node == null: return
	var o := world.add_trace({"node": node, "pos": node.global_position, "room": room, "threshold": 1.6})
	o.on = func():
		var codes: Array = Settings.data.unlocked_codes
		if not codes.has(code): codes.append(code); Settings.save()
		Events.toast.emit("A code is written in the light: %s\nEnter it in Paranormal Extras." % code, "cheat")
		Audio.react(me(), "curious")

func chime(n: int) -> void:
	Save.profile.chimes = maxi(int(Save.profile.chimes), n)
	_light_lamps()
	Audio.sfx("clock_chime", world.refs.grand_clock_front, {"vol": 2.0, "range": 60.0})
	Events.chime_struck.emit(n)
	player.rig.shake(0.3)

func _light_lamps() -> void:
	var lamps: Array = world.refs.grand_clock.lamps
	for i in lamps.size():
		var mi: MeshInstance3D = lamps[i]
		var m := mi.material_override as StandardMaterial3D
		if m == null: m = mi.get_active_material(0) as StandardMaterial3D
		if m: m.emission_energy_multiplier = 4.0 if i < int(Save.profile.chimes) else 0.0

# ======================================================================== collectibles
const PICKUPS := {
	"doc_register": {"pos": Vector3(-4.7, 1.12, 12.2), "look": "book"},
	"doc_invitation": {"pos": Vector3(-23.2, 0.82, 0.6), "look": "card"},
	"pf_gallery": {"pos": Vector3(-1.9, 2.55, 18.4), "look": "fragment"},
	"pf_guest": {"pos": Vector3(-23.3, 0.05, -3.1), "look": "fragment"},
	"rec_hall": {"pos": Vector3(7.2, 0.05, 13.0), "look": "record"},
	"rec_porter": {"pos": Vector3(-28.4, 1.12, 9.0), "look": "record"},
	"tr_snuffbox": {"pos": Vector3(-6.0, 1.1, 12.25), "look": "box"},
	"tr_cat": {"pos": Vector3(-26.0, 2.8, 13.7), "look": "cat"},
}

func _build_collectibles() -> void:
	for id in PICKUPS.keys():
		var d: Dictionary = PICKUPS[id]
		var room: String = GameData.COLLECTIBLES[id].room
		pickup(id, room, d.pos, d.look)

## A collectible on the floor or furniture, with a soft glint. `state` limits it to Now or Then.
func pickup(id: String, room: String, pos: Vector3, look: String, state := "common", parent: Node3D = null) -> Dictionary:
	if Save.profile.collectibles.has(id): return {}
	var r: Room = world.rooms[room]
	var host: Node3D = parent if parent else (r.state_now if state == "now" else (r.state_then if state == "then" else r))
	var node := _pickup_mesh(look)
	host.add_child(node)
	node.global_position = pos
	var g := glint(pos + Vector3(0, 0.12, 0), host)
	var it := interact(room, pos, "Take", GameData.COLLECTIBLES[id].name.split(":")[0], func(o):
		o.enabled = false
		node.queue_free(); g.queue_free()
		Audio.sfx("pickup", pos)
		Game.collect(id)
		if id.begins_with("doc_"): screen.show_document(id)
		_after_collect(id), {"state": state, "radius": 1.8, "anim": "pickup"})
	return it

func _after_collect(id: String) -> void:
	var clue: String = GameData.DOCUMENTS.get(id, {}).get("clue", "")
	if clue != "": Game.add_clue(clue)
	if id == "rec_porter" or id == "rec_hall" or id == "rec_waltz":
		Audio.react(me(), "happy")

func _pickup_mesh(look: String) -> Node3D:
	var n := Node3D.new()
	var mi := MeshInstance3D.new(); n.add_child(mi)
	match look:
		"book":
			mi.mesh = MeshKit.box(Vector3(0.34, 0.05, 0.26)); mi.material_override = MaterialLib.get_mat("leather_red")
			var pg := MeshInstance3D.new(); pg.mesh = MeshKit.box(Vector3(0.32, 0.03, 0.24)); pg.material_override = MaterialLib.get_mat("paper"); pg.position.y = 0.03; n.add_child(pg)
		"card", "paper":
			mi.mesh = MeshKit.box(Vector3(0.18, 0.004, 0.13)); mi.material_override = MaterialLib.get_mat("paper"); mi.rotation.y = 0.4
		"fragment":
			mi.mesh = MeshKit.box(Vector3(0.24, 0.02, 0.3)); mi.material_override = MaterialLib.get_mat("gilt"); mi.rotation = Vector3(0.0, 0.7, 0.2)
			var c := MeshInstance3D.new(); c.mesh = MeshKit.box(Vector3(0.2, 0.025, 0.26)); c.material_override = MaterialLib.get_mat("mural"); c.position.y = 0.004; mi.add_child(c)
		"record":
			mi.mesh = MeshKit.cyl(0.15, 0.15, 0.008, 32); mi.material_override = MaterialLib.color(Color(0.03, 0.03, 0.035), 0.25)
			var lb := MeshInstance3D.new(); lb.mesh = MeshKit.cyl(0.05, 0.05, 0.01, 24); lb.material_override = MaterialLib.color(Color(0.6, 0.12, 0.1), 0.6); n.add_child(lb)
		"box":
			mi.mesh = MeshKit.box(Vector3(0.09, 0.03, 0.06)); mi.material_override = MaterialLib.get_mat("silver")
		"cat":
			mi.mesh = MeshKit.sphere(0.07, 14, 10); mi.material_override = MaterialLib.get_mat("porcelain"); mi.scale = Vector3(1, 0.8, 1.3); mi.position.y = 0.05
			var hd := MeshInstance3D.new(); hd.mesh = MeshKit.sphere(0.045, 12, 8); hd.material_override = MaterialLib.get_mat("porcelain"); hd.position = Vector3(0, 0.13, 0.06); n.add_child(hd)
		"mask":
			mi.mesh = MeshKit.sphere(0.09, 16, 8, true); mi.material_override = MaterialLib.get_mat("gilt"); mi.scale = Vector3(1.4, 0.6, 0.5); mi.rotation.x = -PI * 0.5
		"compass":
			mi.mesh = MeshKit.cyl(0.05, 0.05, 0.02, 24); mi.material_override = MaterialLib.get_mat("brass")
		"sheet":
			mi.mesh = MeshKit.box(Vector3(0.22, 0.003, 0.3)); mi.material_override = MaterialLib.get_mat("paper"); mi.rotation.y = -0.3
	for c in n.find_children("*", "MeshInstance3D", true, false): (c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n

# ======================================================================== prologue
func _build_prologue() -> void:
	var R := "exterior"
	var car: Vector3 = Vector3(2.8, -0.6, -18.5)
	interact(R, car + Vector3(-1.2, 1.0, 0.4), "Search", "the glovebox", func(o):
		o.enabled = false
		Game.set_flag("glovebox")
		Game.collect("tr_compass"); Game.collect("doc_survey")
		screen.show_document("doc_survey"), {"cond": func(): return not Game.flag("glovebox")})
	interact(R, car + Vector3(0, 0.9, -2.3), "Open", "the boot", func(o):
		o.enabled = false
		Game.set_flag("car_boot")
		Game.unlock_costume("avery", "raincoat")
		await say([["avery", "A raincoat. Bright yellow. Of course it's the one day I leave it in the boot.", {"expr": "smug"}]]), {"cond": func(): return not Game.flag("car_boot")})
	if world.refs.has("mailbox"):
		var mb: Vector3 = world.refs.mailbox
		if not Save.profile.collectibles.has("doc_sale"):
			var n := _pickup_mesh("paper"); world.rooms[R].add_child(n); n.global_position = mb
			var g := glint(mb + Vector3(0, 0.1, 0), world.rooms[R])
			interact(R, mb, "Open", "the mailbox", func(o):
				o.enabled = false; n.queue_free(); g.queue_free()
				Game.collect("doc_sale"); screen.show_document("doc_sale"); Game.add_clue("c_sale"))
	if world.refs.has("sign_pos"):
		interact(R, world.refs.sign_pos, "Read", "the sign", func(_o):
			await say([["", "ASHCOMBE HOUSE. PRIVATE. Underneath, in newer paint: SOLD."], ["avery", "Sold, and still nobody's moved in. Or out.", {"expr": "curious"}]]), {"radius": 2.4})
	if world.refs.has("silhouette"):
		world.add_observable({"room": R, "node": world.refs.silhouette, "height": 0.0, "time": 2.0, "on": func(_o):
			await say([["avery", "Someone's at the window. Someone with very good posture.", {"expr": "worried"}]])})
	# the front door
	interact(R, Vector3(0, 0.0, -1.1), "Knock at", "the front door", func(o):
		o.enabled = false
		await _enter_house(), {"radius": 2.4, "cond": func(): return not Game.flag("entered_house"), "anim": "reach"})
	add_code_trace(_code_mesh(R, "trace_tiny", Vector2(1.2, 0.3), Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(-2.2, -0.08, -4.0))), R, "TINYTERROR")

func _code_mesh(room: String, tex: String, size: Vector2, xf: Transform3D) -> MeshInstance3D:
	return GuestWingBuilder.trace_mesh(world.rooms[room], tex, size, xf, Color(1.0, 0.75, 0.9))

func intro() -> void:
	if Game.flag("intro_done"): return
	player.lock()
	screen.letterbox(true)
	var rig := player.rig
	rig.cinematic(Vector3(-6, 3.5, -34), Vector3(0, 4, 0), 48.0)
	await get_tree().create_timer(0.1).timeout
	await screen.fade_in(2.5)
	Audio.play_music("exterior", 4.0)
	await say([["", "Ashcombe House. The last job of the year."]], {})
	rig.cinematic(Vector3(4.5, 0.9, -14.5), Vector3(1.4, 0.9, -17.5), 45.0)
	player.avatar.expression = "curious"
	await say([
		["avery", "Right. Ashcombe House, condition survey, attend at eleven fifty-nine exactly.", {"expr": "determined"}],
		["avery", "Who books a survey for one minute to midnight on New Year's Eve?", {"expr": "smug"}],
		["avery", "The sort of client who pays double. Torch, notebook, tape measure. Let's be quick.", {"expr": "happy", "anim": "inspect"}]])
	rig.release()
	screen.letterbox(false)
	player.unlock()
	Game.set_flag("intro_done")
	Events.toast.emit("Walk with %s. Look around with the mouse or right stick. Inspect things with %s." % ["WASD" if Controls.last_device == "kbm" else "the left stick", Controls.label("interact")], "hint")

func _enter_house() -> void:
	player.lock()
	Audio.sfx("knock", Vector3(0, 1.4, -0.2))
	await get_tree().create_timer(1.2).timeout
	var leaves: Array = world.refs.front_door.leaves
	Audio.sfx("door_creak", Vector3(0, 1.4, 0))
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	for l in leaves: tw.tween_property(l.pivot, "rotation:y", l.dir * -1.6, 3.0)
	player.rig.cinematic(Vector3(1.6, 1.4, -4.2), Vector3(0, 1.6, 3.0), 50.0)
	await say([["avery", "...Hello? Hollins Trust. I'm expected.", {"expr": "curious"}]])
	Game.unlock("fashionably_late")
	await screen.fade_out(0.8)
	player.teleport(Vector3(0, 0.05, 1.6), 0.0)
	for l in leaves: l.pivot.rotation.y = 0.0
	world.refs.front_door_col.disabled = false
	player.rig.release()
	Audio.sfx("door_slam", Vector3(0, 1.4, 0), {"vol": 3.0})
	Game.set_flag("entered_house")
	Save.profile.chapter = 1
	await screen.fade_in(0.6)
	player.rig.shake(0.6)
	await say([["avery", "That's... fine. Doors do that. Old houses, draughts.", {"expr": "worried", "anim": "startle", "anim_dur": 0.8}]])
	await screen.chapter_card("Chapter One", "The Stopped Clocks")
	objective("ch1_look")
	player.unlock()

# ======================================================================== the hall
func _build_hall() -> void:
	var R := "hall"
	var clocks := {"grand": [world.refs.grand_clock_front + Vector3(0, 1.0, 0), "the Grand Clock"], "mantel": [world.refs.mantel_clock_pos, "the mantel clock"],
		"wall": [world.refs.wall_clock_pos, "the wall clock"], "corridor": [world.refs.corridor_clock_pos, "the hall clock"]}
	for k in clocks.keys():
		var room := "corridor" if k == "corridor" else R
		interact(room, clocks[k][0], "Inspect", clocks[k][1], func(_o): await _inspect_clock(k), {"radius": 2.6 if k == "grand" else 2.0, "anim": "inspect"})
	# the lantern nobody lit
	if not Game.flag("has_lantern"):
		var l := Lantern.new(); l.name = "TableLantern"
		world.rooms[R].add_child(l)
		l.global_position = world.refs.lantern_table_pos + Vector3(0, -0.02, 0)
		interact(R, world.refs.lantern_table_pos, "Take", "the lantern", func(o):
			o.enabled = false
			l.queue_free()
			await _take_lantern(), {"radius": 2.0, "anim": "pickup"})
	# the guest register and the Porter's desk (save point)
	interact(R, world.refs.register_pos, "Sign", "the guest register", func(_o): await _sign_register(), {"radius": 2.0, "cond": func(): return Save.profile.collectibles.has("doc_register")})
	# the wardrobe appears once the Porter has your coat
	if world.refs.has("wardrobe"):
		world.refs.wardrobe.visible = Game.flag("porter_resolved")
		interact(R, world.refs.wardrobe_pos + Vector3(0, 1.0, 0), "Open", "the wardrobe", func(_o): screen.open_menu("wardrobe"), {"cond": func(): return Game.flag("porter_resolved")})
	# hidden emblem in the gallery
	var em := GuestWingBuilder.trace_mesh(world.rooms[R], "sym_emblem", Vector2(0.6, 0.6), Transform3D(Basis(Vector3.UP, PI), Vector3(-6.0, 4.0, 19.92)), Color(1.0, 0.88, 0.54))
	_emblem_trace(em, R, "em_hall")
	# the ballroom doors
	if Game.flag("ballroom_open"): _open_ballroom(true)
	interact(R, Vector3(9.4, 1.4, 4.0), "Try", "the ballroom doors", func(_o):
		await say([["avery", "Chained. Not with iron, either. Those links are made of something that glows.", {"expr": "worried"}]]), {"cond": func(): return not Game.flag("ballroom_open")})
	_light_lamps()
	grand_clock_anchor()

func _emblem_trace(node: MeshInstance3D, room: String, id: String) -> void:
	if node == null: return
	if Save.profile.collectibles.has(id):
		(node.material_override as ShaderMaterial).set_shader_parameter("revealed", 1.0); return
	var o := world.add_trace({"node": node, "pos": node.global_position, "room": room, "threshold": 1.4})
	o.on = func():
		Game.collect(id)
		var n := 0
		for e in ["em_corridor", "em_hall", "em_ballroom"]: if Save.profile.collectibles.has(e): n += 1
		Events.toast.emit("Ashcombe emblem %d of 3" % n, "collect")

func _inspect_clock(k: String) -> void:
	var lines := {
		"grand": [["avery", "The Grand Clock. Eleven fifty-nine. The pendulum's trembling, like it's trying very hard not to swing.", {"expr": "curious"}]],
		"mantel": [["avery", "Mantel clock. Eleven fifty-nine. Stopped, and warm to the touch.", {"expr": "curious"}]],
		"wall": [["avery", "Eleven fifty-nine again. Somebody in this house really hates midnight.", {"expr": "smug"}]],
		"corridor": [["avery", "And this one too. One minute to twelve, all over the house.", {"expr": "worried"}]]}
	await say(lines[k])
	if Game.objective() == "ch1_look":
		clocks_seen[k] = true
		if clocks_seen.size() >= 3 or (k == "grand" and clocks_seen.size() >= 2):
			Game.add_clue("c_clocks")
			Game.set_flag("clue_clocks")
			await say([["avery", "Every clock in the place stopped at the same minute. That isn't a power cut. That's a decision.", {"expr": "determined"}],
				["avery", "And there's a light by the stairs that I definitely didn't see from outside.", {"expr": "curious"}]])
			objective("ch1_lantern")
	if k == "grand" and Game.objective() == "ch1_watch":
		await say([["avery", "The watch is ticking in my pocket. The clock isn't. One of them is wrong.", {"expr": "curious"}]])

func _take_lantern() -> void:
	Game.set_flag("has_lantern")
	player.give_lantern()
	Game.unlock("lights_please")
	Audio.sfx("lantern_light", player.global_position)
	await say([["avery", "Still warm. The wick's been trimmed. Somebody wanted me to have this.", {"expr": "curious"}],
		["avery", "...The flame's leaning. There's no draught, and it's leaning west.", {"expr": "surprised"}]])
	Events.toast.emit("The Gloam Lantern. Hold %s to raise it and see what's hidden. Its flame leans toward anything uncanny." % Controls.label("use_tool"), "hint")
	objective("ch1_corridor")

func _sign_register() -> void:
	if Game.flag("porter_at_desk"):
		var c: Character = npcs.get("porter")
		await say([["porter", "Sign here, if you'd be so kind. Your name, and the time. It's always the same time.", {"expr": "happy", "anim": "bow"}]])
	screen.save_at_register()

func _open_ballroom(instant := false) -> void:
	var ch: Dictionary = world.refs.ballroom_chains
	world.refs.ballroom_door_col.disabled = true
	if instant:
		ch.node.visible = false
		for l in world.refs.ballroom_door.leaves: l.pivot.rotation.y = l.dir * -1.45
		return
	var m: ShaderMaterial = ch.mat if ch.mat is ShaderMaterial else null
	Audio.sfx("chains_break", Vector3(9.8, 1.6, 4.0), {"vol": 2.0})
	var tw := create_tween()
	tw.tween_property(ch.node, "scale", Vector3(1.0, 0.01, 1.0), 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): ch.node.visible = false)
	var tw2 := create_tween().set_parallel(true)
	for l in world.refs.ballroom_door.leaves: tw2.tween_property(l.pivot, "rotation:y", l.dir * -1.45, 2.6).set_delay(0.8).set_trans(Tween.TRANS_SINE)
	if m: pass

func _on_deduction(id: String) -> void:
	if id == "d_minute" and Game.objective() == "ch1_deduce":
		screen.close_menus()
		player.lock()
		await get_tree().create_timer(0.4).timeout
		await say([["avery", "Everyone signed in by 11:58. Then every clock stopped at 11:59. Whatever happened here, it happened in that minute.", {"expr": "determined"}]])
		Game.set_flag("ballroom_open")
		player.rig.cinematic(Vector3(4.0, 2.2, 6.0), Vector3(9.8, 1.6, 4.0), 46.0)
		_open_ballroom()
		Audio.sfx("waltz_distant", Vector3(12, 2, 4))
		await say([["avery", "...and that's music. A waltz, from the ballroom. At least, most of one.", {"expr": "surprised"}]])
		player.rig.release()
		Save.profile.chapter = 2
		await screen.chapter_card("Chapter Two", "The Last Waltz")
		objective("ch2_enter")
		player.unlock()
	elif id != "":
		Game.unlock("its_about_time")

func _on_room(id: String, prev: String) -> void:
	if not Save.profile.has("visited"): Save.profile["visited"] = {}
	Save.profile.visited[id] = true
	var cp := {"hall": [Vector3(0, 0.05, 2.0), 0.0], "corridor": [Vector3(-11.2, 0.05, 4.0), -PI * 0.5], "guestroom": [Vector3(-19.7, 0.05, 1.6), PI],
		"cloakroom": [Vector3(-28.5, 0.05, 6.6), 0.0], "ballroom": [Vector3(11.4, 0.05, 4.0), PI * 0.5], "balcony": [Vector3(25.0, 0.05, 19.0), 0.0], "exterior": [Vector3(0.0, -0.55, -6.0), PI]}
	if cp.has(id):
		player.set_checkpoint(Transform3D(Basis(Vector3.UP, cp[id][1]), cp[id][0]), id)
	var music: String = world.rooms[id].music if world.rooms[id].get("music") != null else ""
	if id != "ballroom" and not (ch2.encounter_active) and music != "": Audio.play_music(music)
	if id == "hall" and Game.objective() == "ch1_return":
		objective("ch1_watch")
		await say([["avery", "The Porter's back at the desk. And this watch is ticking toward a minute that never comes.", {"expr": "curious"}]])
	if id == "corridor" and prev == "hall" and Game.objective() == "ch1_corridor" and not Game.flag("corridor_seen"):
		Game.set_flag("corridor_seen")
		await say([["avery", "Cold in here. And the flame's pointing down the corridor like a dog that's seen a squirrel.", {"expr": "curious"}]])
	ch2.on_room(id, prev)

# ======================================================================== the guest wing
func _build_guest_wing() -> void:
	var C := "corridor"
	# the hidden doorway to the cloakroom
	var panel: Node3D = world.refs.hidden_panel
	if Game.flag("hidden_door"):
		if panel: panel.visible = false
		world.refs.hidden_panel_col.disabled = true
		world.refs.hidden_door_trace.visible = false
	else:
		var t := world.add_trace({"node": world.refs.hidden_door_trace, "pos": Vector3(-28.5, 1.4, 5.47), "room": C, "threshold": 1.3})
		t.on = func():
			Game.set_flag("hidden_door")
			Audio.sfx("hidden_door", Vector3(-28.5, 1.4, 5.5), {"vol": 2.0})
			player.rig.shake(0.3)
			var tw := create_tween()
			tw.tween_property(panel, "position:y", panel.position.y - 2.6, 2.2).set_trans(Tween.TRANS_SINE)
			tw.tween_callback(func(): panel.visible = false)
			world.refs.hidden_panel_col.disabled = true
			# the drawn doorway fades once the real one has opened
			var tr: MeshInstance3D = world.refs.hidden_door_trace
			var tm := tr.material_override as ShaderMaterial
			var tw2 := create_tween(); tw2.tween_interval(2.5)
			tw2.tween_method(func(v): tm.set_shader_parameter("revealed", v), 1.0, 0.0, 2.0)
			tw2.tween_callback(func(): tr.visible = false)
			await say([["avery", "A door that only exists in lantern-light. I'm writing that down. Then I'm going through it.", {"expr": "delighted"}]])
			objective("ch1_porter")
	var msg := world.add_trace({"node": world.refs.corridor_message, "pos": world.refs.corridor_message.global_position, "room": C, "threshold": 1.0})
	msg.on = func(): await say([["", "Written on the wallpaper in light: EVERY COAT RETURNED. EVERY GUEST ACCOUNTED FOR."], ["avery", "Very tidy. Very ominous.", {"expr": "smug"}]])
	_emblem_trace(world.refs.emblem_corridor, C, "em_corridor")
	add_code_trace(world.refs.code_bighead, "guestroom", "BIGTHINKER")
	add_code_trace(world.refs.code_sunglasses, "cloakroom", "COOLSPIRITS")
	# tea trolley: relight composure
	var tea: Dictionary = world.refs.corridor_tea
	interact(C, tea.pos, "Pour", "a cup of tea", func(_o):
		player.relight()
		Audio.sfx("tea_pour", tea.pos)
		Game.set_flag("relit")
		Game.unlock("tea_and_sympathy")
		Events.toast.emit("Your composure candles are relit.", "info")
		if randf() < 0.5: await say([["avery", "Still hot. I'm not going to ask how.", {"expr": "happy"}]]), {"radius": 1.8, "anim": "inspect"})
	# the guest room: the comfortable bed and the vanity
	interact("guestroom", world.refs.bed_pos, "Lie down on", "the bed", func(_o): await _nap(), {"radius": 2.0})
	interact("guestroom", world.refs.vanity_pos, "Look in", "the vanity mirror", func(_o):
		await say([["avery", "My reflection's a second late. I'll pretend I didn't see that.", {"expr": "worried"}]]), {"radius": 1.6})
	interact("guestroom", world.refs.guest_wardrobe_pos, "Open", "the wardrobe", func(_o):
		await say([["avery", "Moth-eaten evening wear and a single dancing shoe. Somebody left in a hurry, or didn't leave.", {"expr": "curious"}]]), {"radius": 1.8})
	# the guest-wing door: rocking chair rocks when you approach (cosmetic)
	_build_pip()
	_build_porter()

func _nap() -> void:
	player.lock()
	player.avatar.play("sleep", 0.0)
	await screen.fade_out(1.2)
	await get_tree().create_timer(0.8).timeout
	player.avatar.clear_action()
	await screen.fade_in(1.0)
	if not Game.flag("nightcap_secret"):
		Game.set_flag("nightcap_secret")
		Game.unlock("sleepyhead")
		Game.unlock_costume("avery", "nightcap")
		await say([["avery", "I was out for one minute. It was the best minute of my life.", {"expr": "sleepy"}],
			["", "Someone has left an enormous nightcap on the pillow. It's yours now. Find it in the wardrobe."]])
	else:
		await say([["avery", "Five more minutes. Well. One more minute.", {"expr": "sleepy"}]])
	player.unlock()

# -------------------------------------------------------------------------------- Pip
func _build_pip() -> void:
	var pip := npc("pip", PIP_SPOTS[0], PI * 0.5, world.rooms.corridor)
	world.add_observable({"room": "corridor", "node": pip, "height": 0.8, "time": 2.2, "on": func(_o):
		Game.set_flag("pip_met")
		Game.add_ghost_card("pip")
		await say([["pip", "Oh! You can see me? Nobody sees me. I'm very good at hiding.", {"expr": "scared", "frame": true}],
			["avery", "You're hovering behind a curtain about a foot too short for you.", {"expr": "smug"}],
			["pip", "Don't tell Mr Porter I'm up. He's ever so sad. Somebody never came for their coat. Hook seven. He keeps going back to it.", {"expr": "worried"}],
			["pip", "Put your light down, please. It makes my buttons itch.", {"expr": "sad"}]], {"frame": true})})

func _pip_update(dt: float) -> void:
	var pip: Character = npcs.get("pip")
	if pip == null or not world.active.has("corridor"): return
	var p := player.global_position
	var target: Vector3 = PIP_SPOTS[pip_spot]
	var d := p.distance_to(pip.global_position)
	if player.raise > 0.5 and d < 7.0:
		pip_spot = (pip_spot + 1) % PIP_SPOTS.size()
		Audio.react("pip", "gasp")
		Audio.sfx("buttons_rattle", pip.global_position, {"vol": -3.0})
		var cand: OmniLight3D = world.refs.pip_candelabra
		if cand: cand.light_energy = 0.0; get_tree().create_timer(6.0).timeout.connect(func(): cand.light_energy = 1.0)
	var to := target - pip.global_position
	pip.moving = to.length() > 0.3
	pip.speed = clampf(to.length(), 0.0, 1.0)
	if pip.moving:
		pip.global_position += to.normalized() * minf(to.length(), dt * 5.0)
		pip.rotation.y = lerp_angle(pip.rotation.y, atan2(to.x, to.z), dt * 6.0)
	else:
		pip.look_at_target = player.avatar.head_position() if d < 6.0 else null
	pip.expression = "scared" if player.raise > 0.3 else ("curious" if d < 5.0 else "neutral")

# -------------------------------------------------------------------------------- the Night Porter
func _build_porter() -> void:
	var at_desk := Game.flag("porter_resolved")
	var pos: Vector3 = Vector3(-5.0, 0.0, 13.15) if at_desk else world.refs.porter_home
	var parent: Node3D = world.rooms.hall if at_desk else world.rooms.cloakroom
	var porter := npc("porter", pos, PI if at_desk else PI, parent)
	_porter_target = pos
	if at_desk:
		Game.set_flag("porter_at_desk")
		interact("hall", Vector3(-5.0, 1.1, 11.9), "Talk to", "the Night Porter", func(_o): await _porter_desk_talk(), {"radius": 2.2, "anim": ""})
		return
	world.add_observable({"room": "cloakroom", "node": porter, "time": 2.6, "on": func(_o):
		Game.set_flag("porter_observed")
		await say([["avery", "He keeps drifting back to the same hook. Number seven. The only empty one.", {"expr": "curious"}]])
		Events.toast.emit("Observation added to the Field Journal: the Night Porter keeps returning to hook 7.", "clue")})
	interact("cloakroom", porter.global_position + Vector3(0, 1.4, 0), "Talk to", "the Night Porter", func(o): await _porter_talk(o), {"radius": 2.4, "anim": "", "cond": func(): return not Game.flag("porter_resolved")})
	var hook: Dictionary = world.refs.hook7
	interact("cloakroom", hook.pos, "Hang your coat on", "hook 7", func(o):
		o.enabled = false
		await _resolve_porter(), {"radius": 1.9, "cond": func(): return Game.flag("porter_met") and not Game.flag("porter_resolved"), "anim": "reach"})

func _porter_talk(_o: Dictionary) -> void:
	var first := not Game.flag("porter_met")
	Game.set_flag("porter_met")
	if first:
		await say([["porter", "Good evening, good evening. Welcome to Ashcombe. May I take your coat?", {"expr": "happy", "anim": "bow"}],
			["avery", "You're... see-through.", {"expr": "surprised"}],
			["porter", "Am I? How embarrassing. I do apologise. It's been a very long minute.", {"expr": "worried"}],
			["porter", "Every guest's coat is on its hook. Every guest but one. I can't finish my shift with a hook still empty, you understand.", {"expr": "sad"}],
			["porter", "The master never took his off. Said he'd be leaving at midnight.", {"expr": "neutral"}]], {"frame": true})
		Game.add_clue("c_master")
		Game.add_ghost_card("porter")
	else:
		await say([["porter", "Your coat, madam, sir? I really must insist. Hook seven is so very lonely.", {"expr": "worried", "anim": "hold", "anim_dur": 2.0}]], {"frame": true})

func _porter_update(dt: float) -> void:
	var porter: Character = npcs.get("porter")
	if porter == null or Game.flag("porter_resolved") or not world.active.has("cloakroom"): return
	_porter_drift -= dt
	if _porter_drift <= 0.0:
		_porter_drift = randf_range(5.0, 8.0)
		var hook: Dictionary = world.refs.hook7
		var at_hook := porter.global_position.distance_to(hook.pos * Vector3(1, 0, 1)) < 1.0
		_porter_target = world.refs.porter_home if at_hook else Vector3(hook.pos.x, 0.0, hook.pos.z - 0.6)
	var to := _porter_target - porter.global_position; to.y = 0
	porter.moving = to.length() > 0.2
	porter.speed = 0.5
	if porter.moving:
		_jangle_t -= dt
		if _jangle_t <= 0.0:
			_jangle_t = randf_range(1.2, 2.0)
			Audio.sfx("keys_jangle", porter.global_position + Vector3(0, 0.6, 0), {"vol": -6.0})
		porter.global_position += to.normalized() * minf(to.length(), dt * 1.1)
		porter.rotation.y = lerp_angle(porter.rotation.y, atan2(to.x, to.z), dt * 3.0)
		porter.expression = "sad"
	elif porter.global_position.distance_to(world.refs.porter_home) > 1.0:
		porter.rotation.y = lerp_angle(porter.rotation.y, 0.0, dt * 2.0)
	if player.global_position.distance_to(porter.global_position) < 4.0 and not dlg.active: porter.look_at_target = player.avatar.head_position()

func _resolve_porter() -> void:
	player.lock()
	var porter: Character = npcs.porter
	var hook: Dictionary = world.refs.hook7
	Audio.sfx("coat_hang", hook.pos)
	var coat_on_hook := Node3D.new(); world.rooms.cloakroom.add_child(coat_on_hook)
	world.refs.hook7_coat = coat_on_hook
	var cb := RoomBuilder.new(world, world.rooms.cloakroom).into(coat_on_hook, "common")
	Props.coat_on_hook(cb, hook.pos + Vector3(0, 0.05, -0.13), PI, Color(0.42, 0.35, 0.21), 1.1)
	cb.finalize_batches()
	# the coat really is gone: Avery continues in shirtsleeves
	Game.unlock_costume("avery", "shirtsleeves")
	if me() == "avery" and Save.profile.costumes.avery == "fieldcoat":
		Save.profile.costumes.avery = "shirtsleeves"
		player.build_avatar()
	porter.play("celebrate", 1.6)
	porter.expression = "delighted"
	await say([["porter", "Oh. Oh, that's... that's every hook. Every single one.", {"expr": "delighted"}],
		["porter", "Sixty years I've been waiting to say it. Cloakroom closed!", {"expr": "delighted", "anim": "bow"}],
		["porter", "Here. The master left this at the desk, the night the clocks stopped. It's been ticking ever since, poor thing.", {"expr": "happy", "anim": "hold"}],
		["avery", "A pocket watch. Stopped at... no. It's moving. Barely.", {"expr": "surprised"}],
		["porter", "It remembers, you see. Hold it up to a clock that remembers too, and you'll see what it saw.", {"expr": "proud"}],
		["porter", "I'll be at the front desk, should you need me. Do sign the register. It keeps your place.", {"expr": "happy", "anim": "bow"}]], {"frame": true})
	Game.set_flag("porter_resolved")
	Game.set_flag("has_watch")
	Game.unlock("coat_check")
	Events.toast.emit("The Midnight Watch. Select it with %s and use it at clocks that remember." % Controls.label("tool_watch"), "hint")
	player.set_tool("watch")
	# the Porter fades and reappears at the desk
	var tw := create_tween()
	tw.tween_method(porter.set_presence, 1.0, 0.0, 1.4)
	await tw.finished
	porter.reparent(world.rooms.hall)
	porter.global_position = Vector3(-5.0, 0.0, 13.15); porter.rotation.y = PI
	porter.set_presence(1.0)
	porter.visible = true
	Game.set_flag("porter_at_desk")
	interact("hall", Vector3(-5.0, 1.1, 11.9), "Talk to", "the Night Porter", func(_o): await _porter_desk_talk(), {"radius": 2.2, "anim": ""})
	if world.refs.has("wardrobe"): world.refs.wardrobe.visible = true
	player.unlock()
	objective("ch1_return")

func _porter_desk_talk() -> void:
	var lines := [["porter", "Welcome back. Ashcombe at your service, more or less.", {"expr": "happy", "anim": "bow"}]]
	match Game.objective():
		"ch1_watch": lines.append(["porter", "The Grand Clock remembers more than most. It's on the landing. Do mind the third stair.", {"expr": "neutral"}])
		"ch1_deduce": lines.append(["porter", "Thinking, are we? The Field Journal is very good for that. Put two true things side by side.", {"expr": "curious"}])
		"ch2_enter", "ch2_anchor", "ch2_listen": lines.append(["porter", "The ballroom. He's still in there, the Host. Hasn't left the floor since the band stopped.", {"expr": "worried"}])
		_: lines.append(["porter", "Shall I take your name for the register? It keeps your place in the house.", {"expr": "curious"}])
	await say(lines, {"frame": true})
	screen.save_at_register()

# ======================================================================== the Midnight Watch at the Grand Clock
func grand_clock_anchor() -> void:
	world.add_anchor({"room": "hall", "pos": world.refs.grand_clock_front, "radius": 3.0, "on": func(_a): await _grand_clock_watch()})

func _grand_clock_watch() -> void:
	match Game.objective():
		"ch1_watch":
			await _king_echo()
		"ch2_return":
			await ch2.second_chime()
		_:
			if Game.flag("echo_king"):
				await _king_echo(true)

func _king_echo(replay := false) -> void:
	player.lock()
	Audio.sfx("watch_open", player.global_position)
	Audio.play_music("echo", 1.0)
	world.post.ripple(1.2)
	var tw := create_tween(); tw.tween_property(world.post, "echo", 1.0, 1.2)
	await tw.finished
	var king := Character.create("king")
	world.rooms.hall.add_child(king)
	king.global_position = Vector3(0, 0, 1.5); king.rotation.y = 0.3
	king.moving = true; king.speed = 0.45; king.mps = 1.2
	player.rig.cinematic(Vector3(-4.0, 4.6, 15.5), Vector3(3.0, 0.8, 6.0), 52.0)
	var path := [Vector3(0, 0, 1.5), Vector3(2.0, 0, 5.5), Vector3(6.5, 0, 5.0), Vector3(9.6, 0, 4.0)]
	var walk := create_tween()
	for i in range(1, path.size()):
		var a: Vector3 = path[i - 1]; var b: Vector3 = path[i]
		walk.tween_callback(func(): king.rotation.y = atan2(b.x - a.x, b.z - a.z))
		walk.tween_property(king, "global_position", b, a.distance_to(b) / 1.2)
	await get_tree().create_timer(2.5).timeout
	await say([["king", "One more minute. That's all. Just one more minute.", {"wait": 3.2}]])
	await walk.finished
	king.moving = false
	var fade := create_tween(); fade.tween_method(king.set_presence, 1.0, 0.0, 1.0)
	await fade.finished
	king.queue_free()
	var back := create_tween(); back.tween_property(world.post, "echo", 0.0, 1.0)
	player.rig.release()
	Audio.play_music("hall", 2.0)
	if not replay:
		Game.add_clue("c_king")
		Game.set_flag("echo_king")
		chime(1)
		Game.set_flag("chime1")
		await say([["avery", "A king in a white mask, walking to the ballroom one minute before midnight.", {"expr": "determined"}],
			["avery", "And the clock struck. One chime. One lamp lit. Eleven to go.", {"expr": "surprised"}],
			["avery", "Right. Notebook. Two facts about time, side by side.", {"expr": "determined", "anim": "inspect"}]])
		Events.toast.emit("Open the Field Journal (%s) and link two clues to make a deduction." % Controls.label("journal"), "hint")
		objective("ch1_deduce")
	player.unlock()

func _process(dt: float) -> void:
	if world == null or player == null: return
	_pip_update(dt)
	_porter_update(dt)
	# the Grand Clock's pendulum trembles until it is allowed to swing
	var pend: Node3D = world.refs.grand_clock.pendulum
	if pend and world.active.has("hall"):
		var t := Time.get_ticks_msec() / 1000.0
		pend.rotation.z = sin(t * 23.0) * 0.004 + (sin(t * 2.2) * 0.12 if int(Save.profile.chimes) >= 2 else 0.0)
