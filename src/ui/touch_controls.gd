class_name TouchControls
extends Control
## On-screen controls for phones and tablets: a floating move stick on the left half, drag-to-look
## on the right half, and thumb-sized buttons that drive the same input actions as a gamepad.

var player: Player
var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _look_id := -1
var _look_last := Vector2.ZERO
var _buttons := []     # [{action, label, center, radius, id, hold}]
var _held := {}

const BTN := [["interact", "Use", Vector2(-150, -170), 62], ["use_tool", "Raise", Vector2(-290, -110), 54, true], ["flare", "Flare", Vector2(-290, -250), 46],
	["dodge", "Dodge", Vector2(-120, -330), 46], ["focus", "Look", Vector2(-420, -80), 42, true], ["tool_next", "Tool", Vector2(-430, -210), 40],
	["journal", "Journal", Vector2(-110, 90), 38], ["pause", "II", Vector2(-40, 90), 30], ["hint", "?", Vector2(-180, 90), 30]]

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	for b in BTN: _buttons.append({"action": b[0], "label": b[1], "offset": b[2], "radius": b[3], "hold": b.size() > 4, "id": -1})
	Events.settings_changed.connect(func(p, _v): if String(p).begins_with("controls.touch"): _refresh())
	_refresh()

static func wanted() -> bool:
	var m: String = Settings.data.controls.get("touch_controls", "auto")
	return m == "on" or (m == "auto" and (OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()))

func _refresh() -> void:
	visible = wanted()

func _center(b: Dictionary) -> Vector2:
	var vp := get_viewport_rect().size
	var s: float = Settings.data.controls.get("touch_scale", 1.0)
	var o: Vector2 = b.offset * s
	return Vector2(vp.x + o.x if o.x < 0 else o.x, (vp.y + o.y) if o.y < 0 else o.y)

func _input(e: InputEvent) -> void:
	if not visible or player == null or get_tree().paused and not (e is InputEventScreenTouch): return
	var vp := get_viewport_rect().size
	var s: float = Settings.data.controls.get("touch_scale", 1.0)
	if e is InputEventScreenTouch:
		if e.pressed:
			for b in _buttons:
				if e.position.distance_to(_center(b)) < b.radius * s * 1.15:
					b.id = e.index
					Input.action_press(b.action)
					if not b.hold: get_tree().create_timer(0.08).timeout.connect(func(): Input.action_release(b.action))
					get_viewport().set_input_as_handled(); queue_redraw(); return
			if e.position.x < vp.x * 0.42 and _stick_id < 0:
				_stick_id = e.index; _stick_origin = e.position; _stick_pos = e.position
			elif _look_id < 0:
				_look_id = e.index; _look_last = e.position
		else:
			for b in _buttons:
				if b.id == e.index:
					b.id = -1
					if b.hold: Input.action_release(b.action)
			if e.index == _stick_id:
				_stick_id = -1
				for a in ["move_left", "move_right", "move_forward", "move_back"]: Input.action_release(a)
			if e.index == _look_id: _look_id = -1
		queue_redraw()
	elif e is InputEventScreenDrag:
		if e.index == _stick_id:
			_stick_pos = e.position
			var d: Vector2 = (_stick_pos - _stick_origin) / (90.0 * s)
			if d.length() > 1.0: d = d.normalized()
			_axis("move_right", "move_left", d.x)
			_axis("move_back", "move_forward", d.y)
			queue_redraw()
		elif e.index == _look_id:
			var dl: Vector2 = e.position - _look_last
			_look_last = e.position
			var sens: float = Settings.data.controls.get("mouse_sens", 1.0) * 0.006
			player.rig.yaw -= dl.x * sens
			player.rig.pitch -= dl.y * sens * 0.8

func _axis(pos_a: String, neg_a: String, v: float) -> void:
	if v > 0.12: Input.action_press(pos_a, v); Input.action_release(neg_a)
	elif v < -0.12: Input.action_press(neg_a, -v); Input.action_release(pos_a)
	else: Input.action_release(pos_a); Input.action_release(neg_a)

func _process(_dt: float) -> void:
	if visible: queue_redraw()

func _draw() -> void:
	var a: float = Settings.data.controls.get("touch_opacity", 0.6)
	var s: float = Settings.data.controls.get("touch_scale", 1.0)
	if _stick_id >= 0:
		draw_circle(_stick_origin, 90 * s, Color(1, 1, 1, 0.08 * a))
		draw_arc(_stick_origin, 90 * s, 0, TAU, 48, UIKit.GOLD_DIM * Color(1, 1, 1, a), 2.0)
		var d := (_stick_pos - _stick_origin).limit_length(90 * s)
		draw_circle(_stick_origin + d, 36 * s, UIKit.GOLD * Color(1, 1, 1, 0.5 * a))
	else:
		var vp := get_viewport_rect().size
		draw_arc(Vector2(170, vp.y - 170) * Vector2(s, 1) + Vector2(0, 0), 70 * s, 0, TAU, 40, Color(1, 1, 1, 0.12 * a), 2.0)
	var f := UIKit.font("caps")
	for b in _buttons:
		if b.action in ["use_tool", "flare"] and (player == null or player.lantern == null) and b.action != "use_tool": continue
		var c := _center(b)
		var r: float = b.radius * s
		var down: bool = b.id >= 0
		draw_circle(c, r, Color(0.05, 0.05, 0.08, (0.55 if not down else 0.8) * a))
		draw_arc(c, r, 0, TAU, 40, (UIKit.SPECTRAL if down else UIKit.GOLD_DIM) * Color(1, 1, 1, a), 2.0)
		var fs := int(maxf(14.0, r * 0.36))
		draw_string(f, c + Vector2(-r, fs * 0.35), b.label, HORIZONTAL_ALIGNMENT_CENTER, r * 2, fs, UIKit.PAPER * Color(1, 1, 1, a))
