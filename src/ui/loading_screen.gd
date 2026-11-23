class_name LoadingScreen
extends Control
## A loading screen worth looking at: the Grand Clock's face holding at 11:59 while its second hand
## creeps, what the house is doing right now ("Hanging the chandeliers"), a tip, and a line from the
## Ashcombe archive. The gilt progress line fills along the bottom.

var progress := 0.0
var shown := 0.0
var category := "world"
var line := ""
var tip := ""
var lore := ""
var _line_t := 0.0
var _tip_t := 0.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	modulate.a = 0.0
	visible = false
	_rng.randomize()
	tip = GameData.TIPS[_rng.randi() % GameData.TIPS.size()]
	lore = GameData.LORE[_rng.randi() % GameData.LORE.size()]

func begin() -> void:
	visible = true
	var tw := create_tween(); tw.tween_property(self, "modulate:a", 1.0, 0.6)
	await tw.finished
	await get_tree().process_frame

func set_progress(p: float, cat: String, label: String) -> void:
	progress = p
	if cat != category or label != "":
		category = cat
		var list: Array = GameData.LOADING_LINES.get(cat, ["Preparing the house"])
		line = label if label != "" and label != "done" else list[_rng.randi() % list.size()]
		_line_t = 0.0
	queue_redraw()

func finish() -> void:
	progress = 1.0
	while shown < 0.995: await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	var tw := create_tween(); tw.tween_property(self, "modulate:a", 0.0, 1.0)
	await tw.finished
	visible = false

func _process(dt: float) -> void:
	if not visible: return
	_t += dt; _line_t += dt; _tip_t += dt
	shown = move_toward(shown, progress, dt * 0.6)
	if _tip_t > 9.0:
		_tip_t = 0.0
		tip = GameData.TIPS[_rng.randi() % GameData.TIPS.size()]
		lore = GameData.LORE[_rng.randi() % GameData.LORE.size()]
	if _line_t > 3.5 and progress < 1.0:
		var list: Array = GameData.LOADING_LINES.get(category, [])
		if list.size() > 0: line = list[_rng.randi() % list.size()]; _line_t = 0.0
	queue_redraw()

func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.018, 0.02, 0.035))
	# faint vignette rings
	for i in 6:
		draw_circle(vp * Vector2(0.5, 0.42), vp.y * (0.55 - i * 0.07), Color(0.05, 0.06, 0.09, 0.08))
	var c := vp * Vector2(0.5, 0.4)
	var r := minf(vp.y * 0.22, 220.0)
	# the clock face
	draw_circle(c, r * 1.08, Color(0.12, 0.1, 0.07))
	draw_arc(c, r * 1.08, 0, TAU, 96, UIKit.GOLD_DIM, 3.0)
	draw_arc(c, r * 0.98, 0, TAU, 96, UIKit.GOLD * Color(1, 1, 1, 0.6), 1.5)
	draw_circle(c, r * 0.97, Color(0.9, 0.86, 0.76))
	var numerals := ["XII", "I", "II", "III", "IIII", "V", "VI", "VII", "VIII", "IX", "X", "XI"]
	var f := UIKit.font("head")
	for i in 12:
		var a := TAU * i / 12.0
		var p := c + Vector2(sin(a), -cos(a)) * r * 0.78
		var fs := int(r * 0.13)
		draw_string(f, p + Vector2(-r * 0.15, fs * 0.35), numerals[i], HORIZONTAL_ALIGNMENT_CENTER, r * 0.3, fs, Color(0.15, 0.1, 0.07))
	for i in 60:
		var a := TAU * i / 60.0
		var len := 0.08 if i % 5 == 0 else 0.035
		draw_line(c + Vector2(sin(a), -cos(a)) * r * 0.93, c + Vector2(sin(a), -cos(a)) * r * (0.93 - len), Color(0.2, 0.14, 0.1), 2.0 if i % 5 == 0 else 1.0)
	# 11:59, held. The minute hand trembles; the second hand creeps but never reaches twelve.
	var tremble := sin(_t * 31.0) * 0.004
	_hand(c, TAU * (11.0 + 59.0 / 60.0) / 12.0, r * 0.5, 7.0, Color(0.1, 0.07, 0.05))
	_hand(c, TAU * 59.0 / 60.0 + tremble, r * 0.78, 4.0, Color(0.1, 0.07, 0.05))
	var sec := TAU * (50.0 + shown * 9.8) / 60.0
	_hand(c, sec, r * 0.85, 1.5, Color(0.55, 0.12, 0.1))
	draw_circle(c, 9, UIKit.GOLD)
	# glow of the chime lamps, one per finished stage
	for i in 12:
		var a := TAU * i / 12.0
		var lit := float(i) < shown * 12.0
		draw_circle(c + Vector2(sin(a), -cos(a)) * r * 1.2, 6, UIKit.SPECTRAL if lit else Color(0.25, 0.22, 0.18))
		if lit: draw_circle(c + Vector2(sin(a), -cos(a)) * r * 1.2, 14, UIKit.SPECTRAL * Color(1, 1, 1, 0.15))
	# words
	var y := c.y + r * 1.5
	var head := UIKit.font("deco_r")
	draw_string(head, Vector2(0, y), line + "…", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 34, UIKit.PAPER)
	var body := UIKit.font("italic")
	_wrapped(tip, y + 70, vp, body, 22, UIKit.TEXT)
	_wrapped(lore, vp.y - 110, vp, body, 18, UIKit.MUTED)
	# progress line
	var w := vp.x * 0.5
	var x0 := (vp.x - w) * 0.5
	draw_line(Vector2(x0, vp.y - 50), Vector2(x0 + w, vp.y - 50), Color(0.25, 0.22, 0.18), 2.0)
	draw_line(Vector2(x0, vp.y - 50), Vector2(x0 + w * shown, vp.y - 50), UIKit.GOLD, 2.0)
	draw_circle(Vector2(x0 + w * shown, vp.y - 50), 4, UIKit.GOLD)

func _hand(c: Vector2, a: float, length: float, width: float, col: Color) -> void:
	var d := Vector2(sin(a), -cos(a))
	draw_line(c - d * length * 0.12, c + d * length, col, width, true)

func _wrapped(text: String, y: float, vp: Vector2, f: Font, size: int, col: Color) -> void:
	var w := minf(vp.x * 0.62, 1100.0)
	draw_multiline_string(f, Vector2((vp.x - w) * 0.5, y), text, HORIZONTAL_ALIGNMENT_CENTER, w, size, 3, col)
