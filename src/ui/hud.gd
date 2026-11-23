class_name HUD
extends Control
## In-game overlay: objective, composure candles, current tool, interaction prompt, observe ring,
## crosshair, subtitles and dialogue, toasts, achievements and the performance overlay.

var player: Player
var world: World
var objective_box: VBoxContainer
var objective_label: Label
var chapter_label: Label
var prompt_box: PanelContainer
var prompt_label: Label
var sub_box: PanelContainer
var sub_name: Label
var sub_text: RichTextLabel
var choice_box: VBoxContainer
var toasts: VBoxContainer
var perf: Label
var tool_label: Label
var _obj_show := 0.0
var _sub_full := ""
var _sub_chars := 0.0
var _sub_speed := 45.0
var draw_layer: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	theme = UIKit.theme()
	draw_layer = Control.new(); draw_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT); draw_layer.mouse_filter = MOUSE_FILTER_IGNORE
	draw_layer.draw.connect(_draw_overlay)
	add_child(draw_layer)
	# objective (top left)
	objective_box = VBoxContainer.new(); objective_box.position = Vector2(48, 36); objective_box.custom_minimum_size.x = 560
	chapter_label = UIKit.label("", 17, UIKit.GOLD_DIM, "caps")
	objective_label = UIKit.label("", 23, UIKit.PAPER, "italic")
	objective_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8)); objective_label.add_theme_constant_override("shadow_offset_y", 2)
	objective_box.add_child(chapter_label); objective_box.add_child(objective_label)
	add_child(objective_box)
	# tool (top right, below candles)
	tool_label = UIKit.label("", 17, UIKit.MUTED, "caps"); tool_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tool_label.set_anchors_preset(PRESET_TOP_RIGHT); tool_label.position = Vector2(-360, 84); tool_label.custom_minimum_size.x = 312
	add_child(tool_label)
	# prompt (bottom centre)
	prompt_box = PanelContainer.new()
	prompt_box.add_theme_stylebox_override("panel", UIKit.style(Color(0.03, 0.03, 0.05, 0.72), UIKit.GOLD_DIM, 1, 18, 20, 8))
	prompt_label = UIKit.label("", 22, UIKit.PAPER)
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	prompt_box.add_child(prompt_label)
	prompt_box.set_anchors_preset(PRESET_CENTER_BOTTOM)
	add_child(prompt_box)
	# subtitles / dialogue
	sub_box = PanelContainer.new()
	sub_box.add_theme_stylebox_override("panel", UIKit.style(Color(0.02, 0.02, 0.04, 0.7), Color(0, 0, 0, 0), 0, 8, 26, 14))
	var sv := VBoxContainer.new()
	sub_name = UIKit.label("", 19, UIKit.GOLD, "caps")
	sub_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	sub_text = UIKit.rich("", 25)
	sub_text.custom_minimum_size.x = 900
	choice_box = VBoxContainer.new()
	sv.add_child(sub_name); sv.add_child(sub_text); sv.add_child(choice_box)
	sub_box.add_child(sv)
	sub_box.visible = false
	add_child(sub_box)
	# toasts (right)
	toasts = VBoxContainer.new(); toasts.set_anchors_preset(PRESET_CENTER_RIGHT); toasts.position = Vector2(-470, -40)
	toasts.custom_minimum_size.x = 430; toasts.alignment = BoxContainer.ALIGNMENT_END
	add_child(toasts)
	perf = UIKit.label("", 15, Color(0.7, 1, 0.8), "body"); perf.position = Vector2(12, 8); perf.visible = false
	add_child(perf)
	Events.toast.connect(toast)
	Events.objective_changed.connect(func(_id): _obj_show = 9.0; Audio.ui("objective"))
	Events.achievement_unlocked.connect(func(id): toast("Achievement: %s\n%s" % [GameData.ACHIEVEMENTS[id].name, GameData.ACHIEVEMENTS[id].desc], "achievement"))
	_obj_show = 8.0

func toast(text: String, kind := "info") -> void:
	if text == "": return
	var p := PanelContainer.new()
	var accent: Color = {"achievement": UIKit.GOLD, "clue": UIKit.SPECTRAL, "collect": Color(0.95, 0.8, 0.5), "objective": UIKit.PAPER, "hint": Color(0.75, 0.85, 1.0), "cheat": Color(1, 0.6, 0.85)}.get(kind, UIKit.MUTED)
	p.add_theme_stylebox_override("panel", UIKit.style(Color(0.03, 0.03, 0.05, 0.85), accent * Color(1, 1, 1, 0.7), 1, 5, 16, 10))
	var head := {"achievement": "ACHIEVEMENT", "clue": "NEW CLUE", "collect": "COLLECTED", "objective": "OBJECTIVE", "hint": "FIELD GUIDE", "cheat": "PARANORMAL EXTRAS"}.get(kind, "")
	var v := VBoxContainer.new()
	if head != "": v.add_child(UIKit.label(head, 14, accent, "caps"))
	var l := UIKit.label(text.replace("Achievement: ", "").replace("Clue: ", "").replace("Found: ", ""), 19, UIKit.TEXT)
	l.custom_minimum_size.x = 390
	v.add_child(l)
	p.add_child(v)
	p.modulate.a = 0.0
	toasts.add_child(p)
	if kind == "achievement": Audio.ui("achievement")
	elif kind in ["clue", "collect"]: Audio.ui("clue")
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.3)
	tw.tween_interval(4.5 if kind != "hint" else 7.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)
	while toasts.get_child_count() > 4:
		var old := toasts.get_child(0)
		toasts.remove_child(old)
		old.queue_free()

# ------------------------------------------------------------------------------- subtitles
func show_line(speaker: String, text: String, color := UIKit.GOLD) -> void:
	sub_box.visible = Settings.data.audio.subtitles or speaker == ""
	sub_name.visible = Settings.data.audio.speaker_labels and speaker != ""
	sub_name.text = speaker.to_upper()
	sub_name.add_theme_color_override("font_color", color)
	_sub_full = text
	_sub_chars = 0.0
	sub_text.text = text
	sub_text.visible_characters = 0
	var sz: int = {"small": 21, "medium": 25, "large": 31, "xl": 38}.get(Settings.data.audio.subtitle_size, 25)
	for k in ["normal_font_size", "italics_font_size", "bold_font_size"]: sub_text.add_theme_font_size_override(k, int(sz * UIKit.text_scale()))
	var st := sub_box.get_theme_stylebox("panel") as StyleBoxFlat
	st.bg_color.a = Settings.data.audio.subtitle_bg

func line_done() -> bool:
	return sub_text.visible_characters < 0 or sub_text.visible_characters >= sub_text.get_total_character_count()

func finish_line() -> void:
	sub_text.visible_characters = -1

func hide_line() -> void:
	sub_box.visible = false
	for c in choice_box.get_children(): c.queue_free()

func show_choices(options: Array, cb: Callable) -> void:
	for c in choice_box.get_children(): c.queue_free()
	for i in options.size():
		var b := UIKit.button("  %d.  %s" % [i + 1, options[i]], func(): cb.call(i))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		choice_box.add_child(b)
	sub_box.visible = true
	UIKit.focus_first(choice_box)

# ------------------------------------------------------------------------------- frame
func _process(dt: float) -> void:
	var hs: Dictionary = Settings.data.hud
	var vp := get_viewport_rect().size
	var safe: float = hs.safe_area * 0.06
	var m := Vector2(vp.x * safe, vp.y * safe)
	scale = Vector2.ONE * float(hs.scale) if false else Vector2.ONE
	if sub_text.visible_characters >= 0:
		_sub_chars += dt * _sub_speed * (3.0 if Input.is_action_pressed("skip") else 1.0)
		sub_text.visible_characters = int(_sub_chars)
		if sub_text.visible_characters >= sub_text.get_total_character_count(): sub_text.visible_characters = -1
	sub_box.size = Vector2.ZERO
	sub_box.position = Vector2((vp.x - sub_box.size.x) * 0.5, vp.y - sub_box.size.y - 70 - m.y)
	objective_box.position = Vector2(48, 36) + m
	tool_label.position = Vector2(vp.x - 360 - m.x, 86 + m.y)
	toasts.position = Vector2(vp.x - 470 - m.x, vp.y * 0.38)
	var in_play := player != null and is_instance_valid(player)
	# objective: fades in when it changes, or when the player stands still holding the hint key
	_obj_show = maxf(0.0, _obj_show - dt)
	var obj := Game.objective_text()
	objective_label.text = obj
	var ch: int = int(Save.profile.get("chapter", 0))
	chapter_label.text = ["Prologue", "Chapter One · The Stopped Clocks", "Chapter Two · The Last Waltz"][clampi(ch, 0, 2)]
	var show_obj: bool = hs.objective and (_obj_show > 0.0 or (in_play and Input.is_action_pressed("hint")) or (in_play and player.velocity.length() < 0.1 and player.state == "free" and Game.time_since_progress > 40.0))
	objective_box.modulate.a = move_toward(objective_box.modulate.a, 1.0 if show_obj and obj != "" else 0.0, dt * 1.5)
	# prompt
	var ptxt := ""
	if in_play and hs.prompts and player.prompt != "": ptxt = "%s   %s" % [Controls.label("interact"), player.prompt]
	prompt_label.text = ptxt
	prompt_box.visible = ptxt != "" and not sub_box.visible
	prompt_box.size = Vector2.ZERO
	prompt_box.position = Vector2((vp.x - prompt_box.size.x) * 0.5, vp.y - 150 - m.y)
	# tool
	tool_label.visible = in_play and hs.tool and player.tool != "none"
	if tool_label.visible:
		var name_: String = {"lantern": "Gloam Lantern", "watch": "Midnight Watch"}.get(player.tool, "")
		var hint_: String = {"lantern": "%s raise   %s flare" % [Controls.label("use_tool"), Controls.label("flare")], "watch": "%s use" % Controls.label("use_tool")}.get(player.tool, "")
		tool_label.text = "%s\n%s" % [name_, hint_]
	perf.visible = Settings.data.graphics.show_fps or Settings.data.graphics.perf_overlay
	if perf.visible:
		var t := "%d fps" % Engine.get_frames_per_second()
		if Settings.data.graphics.perf_overlay and world and world.gfx:
			var s: Dictionary = world.gfx.stats()
			t += "   %s" % "  ".join(s.keys().map(func(k): return "%s %s" % [k, s[k]]))
		perf.text = t
	draw_layer.queue_redraw()

func _draw_overlay() -> void:
	var dl := draw_layer
	if player == null or not is_instance_valid(player): return
	var vp := get_viewport_rect().size
	var hs: Dictionary = Settings.data.hud
	var safe: float = hs.safe_area * 0.06
	# composure candles (top right)
	var show_c: bool = hs.candles == "always" or (hs.candles == "auto" and (player.candles < Game.max_candles() or player.state != "free" or (Game.world and Game.world.current == "ballroom")))
	if show_c:
		var n := Game.max_candles()
		var x0 := vp.x - 60 - vp.x * safe
		var y0 := 40 + vp.y * safe
		var t := Time.get_ticks_msec() / 1000.0
		for i in n:
			var x := x0 - (n - 1 - i) * 34
			var lit := i < player.candles
			dl.draw_rect(Rect2(x - 7, y0 + 14, 14, 28), Color(0.92, 0.88, 0.78) if lit else Color(0.45, 0.43, 0.4), true)
			dl.draw_rect(Rect2(x - 9, y0 + 40, 18, 4), UIKit.GOLD_DIM, true)
			if lit:
				var fl := sin(t * 9.0 + i * 1.7) * 1.5
				var pts := PackedVector2Array([Vector2(x - 5, y0 + 12), Vector2(x + fl, y0 - 6), Vector2(x + 5, y0 + 12), Vector2(x, y0 + 15)])
				dl.draw_colored_polygon(pts, Color(1.0, 0.7, 0.3, 0.95))
				dl.draw_circle(Vector2(x, y0 + 8), 10, Color(1.0, 0.7, 0.3, 0.12))
			else:
				dl.draw_line(Vector2(x, y0 + 13), Vector2(x + sin(t * 2 + i) * 3, y0), Color(0.6, 0.6, 0.6, 0.35), 1.5)
	# crosshair while aiming
	var c := vp * 0.5
	if hs.crosshair and (player.raise > 0.4 or player.focus > 0.4):
		dl.draw_arc(c, 10, 0, TAU, 24, Color(1, 1, 1, 0.45), 1.5)
		dl.draw_circle(c, 2, Color(1, 1, 1, 0.7))
	if player.observe_progress > 0.0 and not player.observe_item.is_empty():
		var p: float = player.observe_progress / float(player.observe_item.get("time", 2.5))
		dl.draw_arc(c, 26, -PI * 0.5, -PI * 0.5 + TAU * p, 48, UIKit.SPECTRAL, 3.0)
		dl.draw_string(UIKit.font("caps"), c + Vector2(-40, 56), "Observing", HORIZONTAL_ALIGNMENT_CENTER, 80, 16, UIKit.SPECTRAL)
	if player.flare_cd > 0.0 and player.tool == "lantern":
		dl.draw_arc(vp - Vector2(80, 80) - vp * safe, 18, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - player.flare_cd / 2.6), 32, UIKit.GOLD_DIM, 3.0)
