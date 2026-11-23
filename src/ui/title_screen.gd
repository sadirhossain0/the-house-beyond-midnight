class_name TitleScreen
extends Control
## The front door: a living painting of Ashcombe in the storm, the title, and the way in.

var main: Node
var bg: ColorRect
var bg_mat: ShaderMaterial
var menu_box: VBoxContainer
var panel_host: Control
var menu: GameMenu
var _flash := 0.0
var _next_flash := 6.0

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme = UIKit.theme()
	bg = ColorRect.new(); bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg_mat = ShaderMaterial.new(); bg_mat.shader = load("res://src/fx/title_bg.gdshader")
	bg.material = bg_mat
	add_child(bg)
	var col := VBoxContainer.new()
	col.set_anchors_preset(PRESET_LEFT_WIDE)
	col.offset_left = 96; col.offset_right = 760; col.offset_top = 90; col.offset_bottom = -60
	add_child(col)
	var k := UIKit.label("THE HOUSE", 34, UIKit.GOLD_DIM, "caps")
	var t := UIKit.label("Beyond Midnight", 78, UIKit.PAPER, "deco")
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85)); t.add_theme_constant_override("shadow_offset_y", 4)
	var tag := UIKit.label("A mystery in twelve chimes", 24, UIKit.MUTED, "italic")
	col.add_child(k); col.add_child(t); col.add_child(tag)
	var sp := Control.new(); sp.custom_minimum_size.y = 50; col.add_child(sp)
	menu_box = VBoxContainer.new(); menu_box.custom_minimum_size.x = 360
	col.add_child(menu_box)
	var ver := UIKit.label("Vertical slice · Prologue to Chapter Two · build %s" % ProjectSettings.get_setting("application/config/version", "1.0"), 15, UIKit.MUTED * Color(1, 1, 1, 0.7), "body")
	ver.set_anchors_preset(PRESET_BOTTOM_RIGHT); ver.position = Vector2(-560, -40); ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; ver.custom_minimum_size.x = 520
	add_child(ver)
	menu = GameMenu.new(); menu.screen = null; menu.title_mode = true; menu.visible = false
	menu.closed.connect(func(): _build_menu(); menu_box.visible = true)
	add_child(menu)
	_build_menu()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 1.6)

func _build_menu() -> void:
	for c in menu_box.get_children(): c.queue_free()
	var slots := Save.list_slots()
	var last := int(Settings.data.meta.get("last_slot", 0))
	var latest: Variant = slots[last] if last < slots.size() else null
	if latest == null:
		for s in slots: if s != null: latest = s; break
	if latest != null:
		var p: Dictionary = latest
		var b := UIKit.button("Continue", func(): _go(int(p.slot)))
		menu_box.add_child(b)
		var info := UIKit.label("   %s · %s · %s" % [p.get("name", "Avery"), ["Prologue", "Chapter One", "Chapter Two"][clampi(int(p.chapter), 0, 2)], UIKit.fmt_time(float(p.play_time))], 16, UIKit.MUTED, "italic")
		menu_box.add_child(info)
	menu_box.add_child(UIKit.button("New Game", _new_game))
	if Save.has_any(): menu_box.add_child(UIKit.button("Load Game", func(): _open("saves")))
	menu_box.add_child(UIKit.button("Settings", func(): _open("settings")))
	menu_box.add_child(UIKit.button("Paranormal Extras", func(): _open("extras")))
	menu_box.add_child(UIKit.button("Help & Tips", func(): _open("help")))
	menu_box.add_child(UIKit.button("Credits", func(): _open("credits")))
	if not OS.has_feature("mobile") and not OS.has_feature("web"): menu_box.add_child(UIKit.button("Quit", func(): get_tree().quit()))
	for c in menu_box.get_children(): if c is Button: (c as Button).alignment = HORIZONTAL_ALIGNMENT_LEFT
	UIKit.focus_first(menu_box)

func _open(page: String) -> void:
	menu_box.visible = false
	menu.open(page)

func _go(slot: int) -> void:
	set_process(false)
	Audio.ui("start")
	var tw := create_tween(); tw.tween_property(self, "modulate:a", 0.0, 1.0)
	await tw.finished
	main.start_game(slot)

func _new_game() -> void:
	menu_box.visible = false
	for c in menu_box.get_children(): c.queue_free()
	var slots := Save.list_slots()
	var name_edit := LineEdit.new(); name_edit.text = "Avery"; name_edit.max_length = 20; name_edit.placeholder_text = "Your name for the register"
	var v := VBoxContainer.new()
	v.add_child(UIKit.label("Sign the register", 26, UIKit.GOLD, "head"))
	v.add_child(UIKit.label("The investigator is Avery Wren. The name you sign is yours.", 18, UIKit.MUTED, "italic"))
	v.add_child(name_edit)
	v.add_child(UIKit.label("Choose a save slot", 18, UIKit.GOLD_DIM, "caps"))
	for i in slots.size():
		var s: Variant = slots[i]
		var txt := "Slot %d · empty" % (i + 1) if s == null else "Slot %d · %s, %s (overwrite)" % [i + 1, s.get("name", "?"), UIKit.fmt_time(float(s.play_time))]
		var slot := i
		var b := UIKit.button(txt, func():
			var go := func():
				Audio.ui("start")
				var tw := create_tween(); tw.tween_property(self, "modulate:a", 0.0, 1.2)
				await tw.finished
				main.start_game(slot, name_edit.text.strip_edges() if name_edit.text.strip_edges() != "" else "Avery")
			if s != null: _confirm("Overwrite slot %d? The old save is kept as a backup you can restore." % (slot + 1), go)
			else: go.call())
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(b)
	v.add_child(UIKit.button("Back", func(): _build_menu(); menu_box.visible = true))
	menu_box.add_child(v)
	menu_box.visible = true
	name_edit.grab_focus.call_deferred()

func _confirm(text: String, yes: Callable) -> void:
	var d := ConfirmationDialog.new(); d.dialog_text = text; d.title = "Are you sure?"
	d.confirmed.connect(func(): yes.call())
	add_child(d); d.popup_centered()

func _process(dt: float) -> void:
	bg_mat.set_shader_parameter("res", get_viewport_rect().size)
	_next_flash -= dt
	if _next_flash <= 0.0:
		_next_flash = randf_range(9.0, 18.0)
		_flash = 1.0
		get_tree().create_timer(0.6 + randf() * 1.6).timeout.connect(func(): Audio.sfx("thunder", null, {"vol": -6.0}))
	_flash = maxf(0.0, _flash - dt * 3.0)
	var fl: float = {"full": 1.0, "reduced": 0.35, "off": 0.0}.get(Settings.data.graphics.flashing, 0.35)
	bg_mat.set_shader_parameter("flash", _flash * fl * (0.6 + 0.4 * sin(_flash * 30.0)))
