class_name GameMenu
extends Control
## The pause menu and every book-like page behind it: Field Journal (objective, graduated hints,
## clues, deductions, documents, ghost cards), Map, Wardrobe, Collection, Paranormal Extras,
## Settings (generated from the settings schema), Save & Load (slots, export/import, restore codes),
## Help and Credits. On the title screen the same pages open without the game behind them.

signal closed

var screen: Node            # GameScreen, or null on the title screen
var title_mode := false
var nav: VBoxContainer
var body: MarginContainer
var page := ""
var _sel_clues: Array = []
var _preview_vp: SubViewport
var _preview_char: Character
var _capture_btn: Button
var _capture_action := ""

const PAGES := [["resume", "Resume"], ["journal", "Field Journal"], ["map", "Map"], ["wardrobe", "Wardrobe"], ["collection", "Collection"],
	["extras", "Paranormal Extras"], ["settings", "Settings"], ["help", "Help & Tips"], ["saves", "Save & Load"], ["title", "Quit to Title"]]

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UIKit.theme()
	var dim := ColorRect.new(); dim.color = Color(0.01, 0.01, 0.02, 0.78); dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	var root := HBoxContainer.new(); root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	root.offset_left = 60; root.offset_right = -60; root.offset_top = 50; root.offset_bottom = -50
	root.add_theme_constant_override("separation", 28)
	add_child(root)
	nav = VBoxContainer.new(); nav.custom_minimum_size.x = 290
	root.add_child(nav)
	var panel := PanelContainer.new(); panel.size_flags_horizontal = SIZE_EXPAND_FILL
	root.add_child(panel)
	body = MarginContainer.new()
	panel.add_child(body)

func open(p: String) -> void:
	visible = true
	_build_nav()
	show_page("resume_home" if p == "pause" else p)
	Audio.ui("open")

func close() -> void:
	visible = false
	_clear_preview()
	Audio.ui("close")
	Settings.save()
	if screen: screen.on_menu_closed()
	closed.emit()

func _unhandled_input(e: InputEvent) -> void:
	if not visible: return
	if _capture_action != "": return
	if e.is_action_pressed("pause") or e.is_action_pressed("ui_cancel"):
		if page in ["resume_home"] or title_mode: close()
		else: show_page("resume_home")
		get_viewport().set_input_as_handled()

func _input(e: InputEvent) -> void:
	if _capture_action == "" or not visible: return
	if (e is InputEventKey and e.pressed and not e.echo) or (e is InputEventMouseButton and e.pressed) or (e is InputEventJoypadButton and e.pressed):
		get_viewport().set_input_as_handled()
		if e is InputEventKey and e.keycode == KEY_ESCAPE: _capture_action = ""; show_page("settings_Controls"); return
		Controls.rebind(_capture_action, e)
		_capture_action = ""
		show_page("settings_Controls")

func _build_nav() -> void:
	for c in nav.get_children(): c.queue_free()
	var h := UIKit.heading("Paused" if not title_mode else "", 30)
	if not title_mode: nav.add_child(h)
	if title_mode:
		nav.add_child(UIKit.button("Back", close))
		return
	for pg in PAGES:
		var id: String = pg[0]
		var b := UIKit.button(pg[1], func(): _nav(id))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		nav.add_child(b)
	var obj := UIKit.label(Game.objective_text(), 17, UIKit.MUTED, "italic")
	obj.custom_minimum_size.x = 280
	nav.add_child(UIKit.rule()); nav.add_child(obj)

func _nav(id: String) -> void:
	match id:
		"resume": close()
		"title": _confirm("Return to the title screen? Your progress is saved first.", func(): visible = false; screen.quit_to_title())
		_: show_page(id)

func show_page(p: String) -> void:
	page = p
	_clear_preview()
	for c in body.get_children(): c.queue_free()
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 12)
	var key := p.split("_")[0]
	match key:
		"resume": _page_home(v)
		"journal": _page_journal(v, p.trim_prefix("journal").trim_prefix("_"))
		"map": _page_map(v)
		"wardrobe": _page_wardrobe(v)
		"collection": _page_collection(v)
		"extras": _page_extras(v)
		"settings": _page_settings(v, p.trim_prefix("settings").trim_prefix("_"))
		"saves": _page_saves(v)
		"help": _page_help(v)
		"credits": _page_credits(v)
	body.add_child(v)
	UIKit.focus_first(v if title_mode or key != "resume" else nav)

func _tabs(v: VBoxContainer, base: String, names: Array, current: String) -> void:
	var h := HBoxContainer.new()
	for n in names:
		var b := UIKit.button(n, func(): show_page(base + "_" + n))
		if n == current: b.add_theme_color_override("font_color", UIKit.GOLD)
		h.add_child(b)
	v.add_child(h)
	v.add_child(UIKit.rule())

func _confirm(text: String, yes: Callable) -> void:
	var d := ConfirmationDialog.new(); d.dialog_text = text; d.title = "Are you sure?"
	d.process_mode = Node.PROCESS_MODE_ALWAYS
	d.confirmed.connect(func(): yes.call())
	add_child(d); d.popup_centered()

# ------------------------------------------------------------------------------- home
func _page_home(v: VBoxContainer) -> void:
	v.add_child(UIKit.heading("The House Beyond Midnight", 34))
	var ch: int = int(Save.profile.get("chapter", 0))
	v.add_child(UIKit.label(["Prologue · Arrival", "Chapter One · The Stopped Clocks", "Chapter Two · The Last Waltz"][clampi(ch, 0, 2)], 20, UIKit.GOLD_DIM, "caps"))
	v.add_child(UIKit.label(Game.objective_text(), 26, UIKit.PAPER, "italic"))
	v.add_child(UIKit.rule())
	var stats := "Time in the house: %s\nChimes struck: %d of 12\nClues: %d    Deductions: %d    Collectibles: %d / %d    Achievements: %d / %d" % [UIKit.fmt_time(float(Save.profile.play_time)), int(Save.profile.chimes),
		Save.profile.clues.size(), Save.profile.deductions.size(), Save.profile.collectibles.size(), GameData.COLLECTIBLES.size(), Save.profile.achievements.size(), GameData.ACHIEVEMENTS.size()]
	v.add_child(UIKit.label(stats, 19, UIKit.TEXT))
	if Settings.experimental_cheats_on():
		v.add_child(UIKit.label("Experimental cheats are on: achievements are paused until you turn them off.", 17, Color(1, 0.6, 0.8), "italic"))
	var tip := UIKit.label("Tip: " + GameData.TIPS[randi() % GameData.TIPS.size()], 18, UIKit.MUTED, "italic")
	v.add_child(tip)

# ------------------------------------------------------------------------------- journal
func _page_journal(v: VBoxContainer, sub: String) -> void:
	if sub == "": sub = "Case"
	v.add_child(UIKit.heading("Field Journal"))
	_tabs(v, "journal", ["Case", "Clues", "Documents", "Ghosts"], sub)
	var inner := VBoxContainer.new()
	match sub:
		"Case":
			var o: Dictionary = GameData.OBJECTIVES.get(Game.objective(), {})
			inner.add_child(UIKit.label("CURRENT LEAD", 16, UIKit.GOLD_DIM, "caps"))
			inner.add_child(UIKit.label(Game.objective_text(), 25, UIKit.PAPER, "italic"))
			var seen: int = int(Save.profile.hints_seen.get(Game.objective(), -1))
			var hints: Array = o.get("hints", [])
			for i in hints.size():
				if i <= seen:
					inner.add_child(UIKit.label(["Notice", "Look", "Do"][i] + ": " + hints[i], 19, UIKit.TEXT))
				elif i == seen + 1:
					var tier := i
					inner.add_child(UIKit.button(["Ask the Field Guide what to notice", "Ask where to look", "Ask exactly what to do"][i], func(): Game.hint(tier); show_page("journal_Case")))
					break
			inner.add_child(UIKit.rule())
			inner.add_child(UIKit.label("DEDUCTIONS", 16, UIKit.GOLD_DIM, "caps"))
			for id in GameData.DEDUCTIONS.keys():
				var d: Dictionary = GameData.DEDUCTIONS[id]
				if Save.profile.deductions.has(id):
					inner.add_child(UIKit.label("✦ " + d.title, 21, UIKit.SPECTRAL, "head"))
					inner.add_child(UIKit.label(d.text, 18, UIKit.TEXT, "italic"))
				else:
					inner.add_child(UIKit.label("· · · an unmade connection" + (" (needed to go on)" if d.get("required", false) else ""), 18, UIKit.MUTED, "italic"))
		"Clues":
			inner.add_child(UIKit.label("Choose two clues that belong together, then link them. Wrong pairs cost nothing.", 18, UIKit.MUTED, "italic"))
			for id in Save.profile.clues:
				var c: Dictionary = GameData.CLUES[id]
				var cb := CheckButton.new(); cb.text = c.title; cb.button_pressed = _sel_clues.has(id)
				var cid: String = id
				cb.toggled.connect(func(on):
					if on and not _sel_clues.has(cid): _sel_clues.append(cid)
					elif not on: _sel_clues.erase(cid)
					while _sel_clues.size() > 2: _sel_clues.pop_front()
					show_page("journal_Clues"))
				inner.add_child(cb)
				inner.add_child(UIKit.label("    " + c.text, 17, UIKit.MUTED, "italic"))
			if Save.profile.clues.is_empty(): inner.add_child(UIKit.label("No clues yet. Inspect things. Ask questions. Look closely.", 19, UIKit.MUTED, "italic"))
			var link := UIKit.button("Link the two selected clues", func():
				var r := Game.deduce(_sel_clues[0], _sel_clues[1])
				_sel_clues.clear()
				if r == "":
					Audio.ui("wrong")
					show_page("journal_Clues")
					body.get_child(0).add_child(UIKit.label("Those don't quite connect. Not yet, anyway.", 19, Color(1, 0.7, 0.6), "italic"))
				else:
					Audio.ui("deduce")
					show_page("journal_Case"))
			link.disabled = _sel_clues.size() != 2
			inner.add_child(link)
		"Documents":
			for id in GameData.DOCUMENTS.keys():
				if not Save.profile.collectibles.has(id): continue
				var d: Dictionary = GameData.DOCUMENTS[id]
				inner.add_child(UIKit.label(d.title, 22, UIKit.GOLD, "head"))
				inner.add_child(UIKit.label(d.text, 18, UIKit.TEXT, "italic"))
				inner.add_child(UIKit.rule())
			if inner.get_child_count() == 0: inner.add_child(UIKit.label("No documents yet.", 19, UIKit.MUTED, "italic"))
		"Ghosts":
			for id in GameData.GHOST_CARDS:
				var b: Dictionary = Cast.BIOS.get(id, {})
				if Save.profile.ghost_cards.has(id):
					inner.add_child(UIKit.label(b.title, 24, UIKit.SPECTRAL, "head"))
					inner.add_child(UIKit.label(b.role, 16, UIKit.GOLD_DIM, "caps"))
					inner.add_child(UIKit.label(b.text, 18, UIKit.TEXT))
					if b.has("observed"): inner.add_child(UIKit.label("Observed: " + b.observed, 17, UIKit.MUTED, "italic"))
				else:
					inner.add_child(UIKit.label("A card still blank. Some presence in the house you haven't met.", 18, UIKit.MUTED, "italic"))
				inner.add_child(UIKit.rule())
	v.add_child(UIKit.scroll(inner))

# ------------------------------------------------------------------------------- map
func _page_map(v: VBoxContainer) -> void:
	v.add_child(UIKit.heading("Map of Ashcombe"))
	var m := MapView.new(); m.world = screen.world if screen else null; m.player = screen.player if screen else null
	m.size_flags_vertical = SIZE_EXPAND_FILL; m.custom_minimum_size = Vector2(600, 480)
	v.add_child(m)
	v.add_child(UIKit.label("Gold stars mark rooms with secrets you haven't found. Rooms appear once you've been inside.", 17, UIKit.MUTED, "italic"))

class MapView:
	extends Control
	var world: World
	var player: Player
	func _process(_dt: float) -> void: queue_redraw()
	func _draw() -> void:
		if world == null: return
		var rect := Rect2()
		var first := true
		for r in world.rooms.values():
			if r.id == "exterior": continue
			var rr := Rect2(r.bounds.position.x, r.bounds.position.z, r.bounds.size.x, r.bounds.size.z)
			rect = rr if first else rect.merge(rr); first = false
		rect = rect.grow(3.0)
		var s := minf(size.x / rect.size.x, size.y / rect.size.y)
		var off := (size - rect.size * s) * 0.5
		var tf := func(x: float, z: float) -> Vector2: return off + (Vector2(rect.end.x - x, z - rect.position.y)) * s
		var visited: Dictionary = Save.profile.get("visited", {})
		for r in world.rooms.values():
			if r.id == "exterior": continue
			var known: bool = visited.has(r.id) or (not r.hidden_room)
			if not known: continue
			var a: Vector2 = tf.call(r.bounds.end.x, r.bounds.position.z)
			var b: Vector2 = tf.call(r.bounds.position.x, r.bounds.end.z)
			var rr := Rect2(a, b - a).abs()
			var cur: bool = world.current == r.id
			draw_rect(rr, Color(0.2, 0.18, 0.14, 0.9) if cur else Color(0.1, 0.1, 0.12, 0.85))
			draw_rect(rr, UIKit.GOLD if cur else UIKit.GOLD_DIM, false, 2.0)
			var f := UIKit.font("caps")
			draw_string(f, rr.position + Vector2(6, 22), r.display_name if visited.has(r.id) else "?", HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 8, 16, UIKit.PAPER)
			var missing := 0
			for id in GameData.COLLECTIBLES.keys():
				if GameData.COLLECTIBLES[id].room == r.id and not Save.profile.collectibles.has(id): missing += 1
			if missing > 0 and visited.has(r.id): draw_string(f, rr.end - Vector2(28, 10), "✦", HORIZONTAL_ALIGNMENT_LEFT, 30, 20, UIKit.GOLD)
		if player:
			var pp: Vector2 = tf.call(player.global_position.x, player.global_position.z)
			var d := Vector2(-sin(player.facing), cos(player.facing))
			draw_colored_polygon(PackedVector2Array([pp + d * 12, pp + d.orthogonal() * 7 - d * 6, pp - d.orthogonal() * 7 - d * 6]), UIKit.SPECTRAL)

# ------------------------------------------------------------------------------- wardrobe
func _page_wardrobe(v: VBoxContainer) -> void:
	v.add_child(UIKit.heading("Wardrobe"))
	if screen == null or not Game.flag("porter_resolved"):
		v.add_child(UIKit.label("The hall wardrobe opens once the Night Porter has your coat.", 20, UIKit.MUTED, "italic")); return
	var h := HBoxContainer.new(); h.size_flags_vertical = SIZE_EXPAND_FILL
	var list := VBoxContainer.new(); list.custom_minimum_size.x = 520
	var all: bool = Settings.data.cheats.get("all_costumes", false)
	for who in Cast.PLAYABLE:
		var unlocked_char: bool = Save.profile.unlocked_characters.has(who)
		list.add_child(UIKit.label(Cast.BIOS[who].title + ("" if unlocked_char else " (not yet met)"), 24, UIKit.GOLD, "head"))
		if not unlocked_char: continue
		for cid in Cast.COSTUMES[who].keys():
			var c: Dictionary = Cast.COSTUMES[who][cid]
			var key := "%s:%s" % [who, cid]
			var have: bool = (all and not c.get("locked", false)) or Save.profile.unlocked_costumes.has(key)
			var wearing: bool = Save.profile.character == who and Save.profile.costumes.get(who, "") == cid
			var label: String = ("✓ " if wearing else "") + c.label + ("" if have else "   — " + c.unlock)
			var w: String = who; var id: String = cid
			var b := UIKit.button(label, func():
				Save.profile.character = w
				Save.profile.costumes[w] = id
				screen.player.build_avatar()
				Events.costume_changed.emit(w, id)
				show_page("wardrobe"))
			b.disabled = not have
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.focus_entered.connect(func(): if have: _preview(w, id))
			list.add_child(b)
	h.add_child(UIKit.scroll(list))
	var pv := SubViewportContainer.new(); pv.stretch = true; pv.custom_minimum_size = Vector2(420, 560); pv.size_flags_horizontal = SIZE_EXPAND_FILL
	_preview_vp = SubViewport.new(); _preview_vp.own_world_3d = true; _preview_vp.transparent_bg = true; _preview_vp.size = Vector2i(420, 560)
	pv.add_child(_preview_vp)
	var cam := Camera3D.new(); cam.fov = 30; _preview_vp.add_child(cam); cam.look_at_from_position(Vector3(0, 1.15, 4.2), Vector3(0, 0.95, 0))
	var key_l := DirectionalLight3D.new(); key_l.light_energy = 1.8; _preview_vp.add_child(key_l); key_l.look_at_from_position(Vector3(2, 3, 3), Vector3.ZERO)
	var rim := OmniLight3D.new(); rim.position = Vector3(-1.5, 2, -1.5); rim.light_color = Color(0.6, 0.8, 1); rim.light_energy = 3; rim.omni_range = 6; _preview_vp.add_child(rim)
	var env := WorldEnvironment.new(); env.environment = Environment.new(); env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.5, 0.5, 0.6); env.environment.ambient_light_energy = 0.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	_preview_vp.add_child(env)
	h.add_child(pv)
	v.add_child(h)
	_preview(Save.profile.character, Save.profile.costumes.get(Save.profile.character, "fieldcoat"))

func _preview(who: String, cid: String) -> void:
	if _preview_vp == null: return
	if _preview_char: _preview_char.queue_free()
	_preview_char = Character.create(who, cid)
	_preview_char.process_mode = Node.PROCESS_MODE_ALWAYS
	_preview_vp.add_child(_preview_char)
	_preview_char.expression = "happy"
	_preview_char._idle_t = 5.0
	var tw := _preview_char.create_tween().set_loops()
	tw.tween_property(_preview_char, "rotation:y", TAU, 9.0).from(0.0)

func _clear_preview() -> void:
	_preview_char = null
	_preview_vp = null

# ------------------------------------------------------------------------------- collection
func _page_collection(v: VBoxContainer) -> void:
	v.add_child(UIKit.heading("Collection"))
	var inner := VBoxContainer.new()
	var kinds := [["document", "Documents"], ["portrait", "Portrait fragments"], ["record", "Music records"], ["treasure", "Treasures"], ["emblem", "Hidden emblems"]]
	for k in kinds:
		var items: Array = GameData.COLLECTIBLES.keys().filter(func(id): return GameData.COLLECTIBLES[id].kind == k[0])
		var found := items.filter(func(id): return Save.profile.collectibles.has(id)).size()
		inner.add_child(UIKit.label("%s   %d / %d" % [k[1].to_upper(), found, items.size()], 17, UIKit.GOLD_DIM, "caps"))
		for id in items:
			var c: Dictionary = GameData.COLLECTIBLES[id]
			var got: bool = Save.profile.collectibles.has(id)
			var row := HBoxContainer.new()
			row.add_child(UIKit.label(("✦ " + c.name) if got else "· ? ? ?   (%s)" % _room_name(c.room), 19, UIKit.PAPER if got else UIKit.MUTED))
			if got and c.has("track"):
				var tr: String = c.track
				row.add_child(UIKit.button("Play", func(): Audio.play_music(tr, 1.0)))
			inner.add_child(row)
			if got and c.has("text"): inner.add_child(UIKit.label("    " + c.text, 16, UIKit.MUTED, "italic"))
		inner.add_child(UIKit.rule())
	inner.add_child(UIKit.label("ACHIEVEMENTS   %d / %d" % [Save.profile.achievements.size(), GameData.ACHIEVEMENTS.size()], 17, UIKit.GOLD_DIM, "caps"))
	for id in GameData.ACHIEVEMENTS.keys():
		var a: Dictionary = GameData.ACHIEVEMENTS[id]
		var got: bool = Save.profile.achievements.has(id)
		inner.add_child(UIKit.label(("✦ " if got else "○ ") + a.name + "  —  " + a.desc, 18, UIKit.GOLD if got else UIKit.MUTED))
	v.add_child(UIKit.scroll(inner))

func _room_name(id: String) -> String:
	if screen and screen.world and screen.world.rooms.has(id): return screen.world.rooms[id].display_name
	return id.capitalize()

# ------------------------------------------------------------------------------- extras
func _page_extras(v: VBoxContainer) -> void:
	v.add_child(UIKit.heading("Paranormal Extras"))
	v.add_child(UIKit.label("Cheats and toys. Cosmetic ones are free. Experimental gameplay cheats pause achievements while they're on; nothing is ever lost.", 18, UIKit.MUTED, "italic"))
	var code_row := HBoxContainer.new()
	var code := LineEdit.new(); code.placeholder_text = "Enter a code found in the house"; code.custom_minimum_size.x = 380
	var msg := UIKit.label("", 18, UIKit.SPECTRAL, "italic")
	var enter := func():
		var t := code.text.strip_edges().to_upper().replace(" ", "")
		if GameData.CHEAT_CODES.has(t):
			var codes: Array = Settings.data.unlocked_codes
			if not codes.has(t): codes.append(t)
			var key: String = GameData.CHEAT_CODES[t].key
			if key == "all_costumes": Settings.data.cheats["all_costumes"] = true
			else: Settings.set_v("cheats." + key, true)
			Settings.save()
			Audio.ui("unlock")
			show_page("extras")
			Events.toast.emit("Unlocked: %s" % GameData.CHEAT_CODES[t].name, "cheat")
		else:
			msg.text = "The house doesn't recognise that one. Codes are written somewhere in lantern-light."
			Audio.ui("wrong")
	code.text_submitted.connect(func(_t): enter.call())
	code_row.add_child(code); code_row.add_child(UIKit.button("Enter", enter))
	v.add_child(code_row); v.add_child(msg)
	var inner := VBoxContainer.new()
	var group := ""
	for c in GameData.CHEATS:
		if c.group != group:
			group = c.group
			inner.add_child(UIKit.label(group.to_upper(), 16, UIKit.GOLD_DIM, "caps"))
		var locked: bool = c.has("code") and not Settings.data.unlocked_codes.has(c.code)
		var path: String = "cheats." + c.key
		if c.get("type", "") == "select":
			var ob := OptionButton.new()
			for i in c.options.size():
				ob.add_item(c.options[i][1], i)
				if c.options[i][0] == Settings.get_v(path): ob.select(i)
			var opts: Array = c.options
			ob.item_selected.connect(func(i): Settings.set_v(path, opts[i][0]))
			var row := HBoxContainer.new(); row.add_child(UIKit.label(c.name, 19)); row.add_child(ob)
			inner.add_child(row)
		else:
			var cb := CheckButton.new()
			cb.text = c.name + ("  (experimental)" if c.get("experimental", false) else "") + ("   — locked: find its code" if locked else "")
			cb.button_pressed = bool(Settings.get_v(path))
			cb.disabled = locked
			cb.toggled.connect(func(on): Settings.set_v(path, on); Events.cheat_toggled.emit(c.key, on))
			inner.add_child(cb)
		inner.add_child(UIKit.label("    " + c.desc, 16, UIKit.MUTED, "italic"))
	v.add_child(UIKit.scroll(inner))

# ------------------------------------------------------------------------------- settings
func _page_settings(v: VBoxContainer, sub: String) -> void:
	var sch: Dictionary = Settings.schema()
	if sub == "" or not sch.has(sub): sub = sch.keys()[0]
	v.add_child(UIKit.heading("Settings"))
	_tabs(v, "settings", sch.keys(), sub)
	var inner := VBoxContainer.new()
	for item in sch[sub]:
		if item.has("group"):
			inner.add_child(UIKit.label(String(item.group).to_upper(), 16, UIKit.GOLD_DIM, "caps")); continue
		if item.has("note"):
			inner.add_child(UIKit.label(item.note, 17, UIKit.MUTED, "italic")); continue
		if item.get("type", "") == "bindings":
			_bindings(inner); continue
		var path: String = item.path
		var row := HBoxContainer.new()
		var name := UIKit.label(item.label, 19); name.custom_minimum_size.x = 360; name.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(name)
		var cur: Variant = Settings.get_v(path)
		match item.type:
			"toggle":
				var cb := CheckButton.new(); cb.button_pressed = bool(cur)
				cb.toggled.connect(func(on): Settings.set_v(path, on))
				row.add_child(cb)
			"select":
				var ob := OptionButton.new(); ob.custom_minimum_size.x = 320
				var opts: Array = item.options
				for i in opts.size():
					ob.add_item(str(opts[i][1]), i)
					if GameMenu.same_value(opts[i][0], cur): ob.select(i)
				ob.item_selected.connect(func(i):
					if path == "graphics.preset": Settings.apply_preset(str(opts[i][0])); show_page("settings_" + sub)
					else: Settings.set_v(path, opts[i][0]))
				row.add_child(ob)
			"range":
				var sl := HSlider.new(); sl.min_value = item.min; sl.max_value = item.max; sl.step = item.get("step", 0.01)
				sl.value = float(cur); sl.custom_minimum_size.x = 260
				var val := UIKit.label(_fmt(float(cur), item.get("fmt", "")), 18, UIKit.MUTED); val.custom_minimum_size.x = 80
				var fmt: String = item.get("fmt", "")
				sl.value_changed.connect(func(x): val.text = _fmt(x, fmt); Settings.set_v(path, x))
				row.add_child(sl); row.add_child(val)
		inner.add_child(row)
		if item.has("desc"): inner.add_child(UIKit.label("    " + item.desc, 15, UIKit.MUTED, "italic"))
	v.add_child(UIKit.scroll(inner))

## Settings values round-trip through JSON as floats (60 becomes 60.0), so compare numbers numerically.
static func same_value(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return absf(float(a) - float(b)) < 0.001
	return str(a) == str(b)

func _fmt(x: float, fmt: String) -> String:
	match fmt:
		"pct": return "%d%%" % roundi(x * 100.0)
		"deg": return "%d°" % roundi(x)
		"x": return "%.2f×" % x
		"s": return "%.1fs" % x
	return ("%d" % x) if absf(x - roundf(x)) < 0.001 else "%.2f" % x

func _bindings(inner: VBoxContainer) -> void:
	for a in Controls.REMAPPABLE:
		var row := HBoxContainer.new()
		var l := UIKit.label(Controls.ACTIONS[a].label, 18); l.custom_minimum_size.x = 360; l.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(l)
		var act: String = a
		var b := Button.new(); b.text = Controls.binding_text(a)
		b.pressed.connect(func():
			Audio.ui("click")
			b.text = "Press a key or button… (Esc to cancel)"
			_capture_action = act)
		b.custom_minimum_size.x = 300
		row.add_child(b)
		inner.add_child(row)
	inner.add_child(UIKit.button("Reset all bindings", func(): Controls.reset_bindings(); show_page("settings_Controls")))

# ------------------------------------------------------------------------------- saves
func _page_saves(v: VBoxContainer) -> void:
	v.add_child(UIKit.heading("Save & Load"))
	v.add_child(UIKit.label("Three slots, each with an automatic backup. Export a slot to a file, or write down a Midnight Code: either one brings your progress back on any device.", 17, UIKit.MUTED, "italic"))
	var inner := VBoxContainer.new()
	var slots := Save.list_slots()
	for i in slots.size():
		var s: Variant = slots[i]
		var slot := i
		var box := VBoxContainer.new()
		var head := "Slot %d" % (i + 1)
		if s == null:
			box.add_child(UIKit.label(head + " · empty", 22, UIKit.MUTED, "head"))
		else:
			var p: Dictionary = s
			var when := Time.get_datetime_string_from_unix_time(int(p.get("saved_at", 0)), true)
			box.add_child(UIKit.label("%s · %s" % [head, p.get("name", "?")], 22, UIKit.GOLD, "head"))
			box.add_child(UIKit.label("%s · %s · %d chimes · saved %s" % [["Prologue", "Chapter One", "Chapter Two"][clampi(int(p.chapter), 0, 2)], UIKit.fmt_time(float(p.play_time)), int(p.chimes), when], 17, UIKit.TEXT))
			box.add_child(UIKit.label(GameData.OBJECTIVES.get(p.objective, {}).get("text", ""), 16, UIKit.MUTED, "italic"))
		var row := HBoxContainer.new()
		if s != null:
			row.add_child(UIKit.button("Load", func():
				var go := func():
					visible = false
					if screen: get_tree().paused = false; screen.main.start_game(slot)
					else: Game.main.start_game(slot)
				if screen: _confirm("Load slot %d? Unsaved progress since your last save will be lost." % (slot + 1), go)
				else: go.call()))
		if screen: row.add_child(UIKit.button("Save here", func():
			var go := func():
				Save.profile.slot = slot
				screen.snapshot(); Save.write("manual"); Settings.data.meta.last_slot = slot
				Events.toast.emit("Saved to slot %d." % (slot + 1), "info"); show_page("saves")
			if s != null and int(s.slot) != int(Save.profile.slot): _confirm("Overwrite slot %d? It is kept as a backup." % (slot + 1), go)
			else: go.call()))
		if s != null:
			row.add_child(UIKit.button("Export", func(): _export(slot)))
			row.add_child(UIKit.button("Codes", func(): _codes(slot)))
		row.add_child(UIKit.button("Import", func(): _import(slot)))
		if Save.has_backup(slot): row.add_child(UIKit.button("Restore backup", func(): _confirm("Swap slot %d with its backup?" % (slot + 1), func(): Save.restore_backup(slot); show_page("saves"))))
		if s != null: row.add_child(UIKit.button("Delete", func(): _confirm("Delete slot %d and its backup? This cannot be undone." % (slot + 1), func(): Save.delete_slot(slot); show_page("saves"))))
		box.add_child(row)
		inner.add_child(box)
		inner.add_child(UIKit.rule())
	inner.add_child(UIKit.label("RESTORE FROM A CODE", 16, UIKit.GOLD_DIM, "caps"))
	inner.add_child(UIKit.label("Paste a full restore code (HBMSAVE:…) or type a Midnight Code (HBM-…).", 16, UIKit.MUTED, "italic"))
	var te := TextEdit.new(); te.custom_minimum_size = Vector2(0, 110); te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	inner.add_child(te)
	var r := HBoxContainer.new()
	var result := UIKit.label("", 17, UIKit.SPECTRAL, "italic")
	for i in 3:
		var slot := i
		r.add_child(UIKit.button("Restore into slot %d" % (i + 1), func():
			var err := Save.restore_from_code(slot, te.text, GameData.CODE_REGISTRY, GameMenu.rebuild_from_flags)
			result.text = err if err != "" else "Restored into slot %d. Load it from the list above." % (slot + 1)
			if err == "": show_page("saves")))
	inner.add_child(r); inner.add_child(result)
	v.add_child(UIKit.scroll(inner))

func _export(slot: int) -> void:
	var fd := FileDialog.new(); fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE; fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray(["*.hbmsave ; House Beyond Midnight save"]); fd.current_file = "ashcombe_slot%d.hbmsave" % (slot + 1)
	fd.process_mode = Node.PROCESS_MODE_ALWAYS
	fd.file_selected.connect(func(path): Events.toast.emit("Exported to %s" % path if Save.export_slot(slot, path) else "Export failed.", "info"))
	add_child(fd); fd.popup_centered_ratio(0.7)

func _import(slot: int) -> void:
	var fd := FileDialog.new(); fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE; fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray(["*.hbmsave, *.json ; House Beyond Midnight save"])
	fd.process_mode = Node.PROCESS_MODE_ALWAYS
	fd.file_selected.connect(func(path):
		var err := Save.import_file(slot, path)
		Events.toast.emit(err if err != "" else "Imported into slot %d." % (slot + 1), "info"); show_page("saves"))
	add_child(fd); fd.popup_centered_ratio(0.7)

func _codes(slot: int) -> void:
	var p: Variant = Save.read_slot(slot)
	if p == null: return
	for c in body.get_children(): c.queue_free()
	var v := VBoxContainer.new()
	v.add_child(UIKit.heading("Codes for slot %d" % (slot + 1)))
	var mc := Save.midnight_code(p, GameData.CODE_REGISTRY)
	v.add_child(UIKit.label("MIDNIGHT CODE", 16, UIKit.GOLD_DIM, "caps"))
	v.add_child(UIKit.label("Short enough to write down. Restores chapter, chimes, clues, collectibles, costumes and progress flags (not your exact position).", 16, UIKit.MUTED, "italic"))
	var ml := UIKit.label(mc, 30, UIKit.SPECTRAL, "head"); v.add_child(ml)
	v.add_child(UIKit.button("Copy Midnight Code", func(): DisplayServer.clipboard_set(mc); Events.toast.emit("Copied.", "info")))
	v.add_child(UIKit.rule())
	var full := Save.full_restore_code(p)
	v.add_child(UIKit.label("FULL RESTORE CODE", 16, UIKit.GOLD_DIM, "caps"))
	v.add_child(UIKit.label("Everything, exactly. Paste it into a note or email to yourself.", 16, UIKit.MUTED, "italic"))
	var te := TextEdit.new(); te.text = full; te.editable = false; te.custom_minimum_size = Vector2(0, 220); te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	v.add_child(te)
	v.add_child(UIKit.button("Copy full restore code", func(): DisplayServer.clipboard_set(full); Events.toast.emit("Copied.", "info")))
	v.add_child(UIKit.button("Back", func(): show_page("saves")))
	body.add_child(v)

## Midnight Codes carry flags only; work out the objective and a safe place to stand from them.
static func rebuild_from_flags(p: Dictionary) -> void:
	var fl: Dictionary = p.flags
	var order := [["slice_done", "slice_end"], ["mara_freed", "ch2_return"], ["host_resolved", "ch2_balcony"], ["waltz_complete", "ch2_host"],
		["placed_flute", "ch2_marks"], ["echo_band", "ch2_place"], ["frag_sun", "ch2_order"], ["waltz_heard", "ch2_fragments"], ["first_shift", "ch2_listen"],
		["ballroom_entered", "ch2_anchor"], ["ballroom_open", "ch2_enter"], ["echo_king", "ch1_deduce"], ["porter_resolved", "ch1_watch"],
		["hidden_door", "ch1_porter"], ["has_lantern", "ch1_corridor"], ["clue_clocks", "ch1_lantern"], ["entered_house", "ch1_look"]]
	p.objective = "pro_arrive"
	for o in order:
		if fl.get(o[0], false): p.objective = o[1]; break
	if fl.get("porter_resolved", false): fl["has_watch"] = true; fl["porter_at_desk"] = true
	if fl.get("entered_house", false): fl["intro_done"] = true
	if p.objective in ["ch2_order", "ch2_place", "ch2_marks"] and not (fl.get("frag_moon", false) and fl.get("frag_star", false)): p.objective = "ch2_fragments"
	if fl.get("entered_house", false):
		p.room = "hall"; p.pos = [0.0, 0.05, 2.0]; p.yaw = 0.0
	if fl.get("waltz_complete", false) and not fl.get("host_resolved", false):
		p.room = "ballroom"; p.pos = [11.4, 0.05, 4.0]; p.yaw = PI * 0.5

# ------------------------------------------------------------------------------- help & credits
func _page_help(v: VBoxContainer) -> void:
	v.add_child(UIKit.heading("Help & Tips"))
	var inner := VBoxContainer.new()
	inner.add_child(UIKit.label("CONTROLS", 16, UIKit.GOLD_DIM, "caps"))
	for a in ["move_forward", "interact", "use_tool", "flare", "focus", "dodge", "walk", "tool_lantern", "tool_watch", "journal", "map", "hint", "recenter", "pause"]:
		var row := HBoxContainer.new()
		var l := UIKit.label(Controls.ACTIONS[a].label, 18); l.custom_minimum_size.x = 380
		row.add_child(l); row.add_child(UIKit.label(Controls.binding_text(a), 18, UIKit.PAPER))
		inner.add_child(row)
	inner.add_child(UIKit.rule())
	inner.add_child(UIKit.label("HOW THE HOUSE WORKS", 16, UIKit.GOLD_DIM, "caps"))
	for t in ["The Gloam Lantern: raise it to reveal writing, symbols and doorways that only exist in its light. Its flame leans toward anything uncanny. Flare it to startle a ghost.",
		"The Midnight Watch: use it at a clock that remembers to see an echo of the sealed night. At a green anchor clock, it shifts the whole room between Now and Then.",
		"Composure: your candles. Frights blow them out; tea relights them. Run out and you faint, then wake a little way back. Nothing is lost.",
		"The Field Journal: clues collect themselves. Link two that belong together to make a deduction. The Field Guide gives three tiers of hint, from a nudge to the answer.",
		"Saving: the game saves at every new objective and every few minutes. Sign the register at the hall desk to save by hand and get a Midnight Code."]:
		inner.add_child(UIKit.label("· " + t, 18, UIKit.TEXT))
	inner.add_child(UIKit.rule())
	inner.add_child(UIKit.label("TIPS", 16, UIKit.GOLD_DIM, "caps"))
	for t in GameData.TIPS: inner.add_child(UIKit.label("· " + t, 17, UIKit.TEXT, "italic"))
	inner.add_child(UIKit.rule())
	inner.add_child(UIKit.label("FROM THE ARCHIVE", 16, UIKit.GOLD_DIM, "caps"))
	for t in GameData.LORE: inner.add_child(UIKit.label(t, 17, UIKit.MUTED, "italic"))
	v.add_child(UIKit.scroll(inner))

func _page_credits(v: VBoxContainer) -> void:
	v.add_child(UIKit.heading("Credits"))
	var t := """The House Beyond Midnight: vertical slice.

Built with Godot Engine 4 (MIT licence) and Blender.
Textures, HDRI skies and furniture models from Poly Haven (polyhaven.com), released under CC0. Thank you to everyone who contributes there.
Fonts: Cinzel and Cinzel Decorative by Natanael Gama; Alegreya by Juan Pablo del Peral (Huerta Tipográfica); IM Fell English SC by Igino Marini. All under the SIL Open Font License.
Characters, rooms, music, sound and voices were built for this game.

No ghosts were harmed. Several were settled."""
	v.add_child(UIKit.label(t, 19, UIKit.TEXT))
