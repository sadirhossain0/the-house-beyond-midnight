extends Node
## Input actions, remapping, controller glyphs (Xbox / PlayStation / Nintendo), rumble and the
## device the player last used. Touch controls feed the same actions (see ui/touch_controls.gd).

const ACTIONS := {
	"move_forward": {"label": "Move forward", "keys": [KEY_W, KEY_UP], "axis": [JOY_AXIS_LEFT_Y, -1.0]},
	"move_back": {"label": "Move back", "keys": [KEY_S, KEY_DOWN], "axis": [JOY_AXIS_LEFT_Y, 1.0]},
	"move_left": {"label": "Move left", "keys": [KEY_A], "axis": [JOY_AXIS_LEFT_X, -1.0]},
	"move_right": {"label": "Move right", "keys": [KEY_D], "axis": [JOY_AXIS_LEFT_X, 1.0]},
	"look_left": {"label": "Camera left", "keys": [KEY_LEFT], "axis": [JOY_AXIS_RIGHT_X, -1.0]},
	"look_right": {"label": "Camera right", "keys": [KEY_RIGHT], "axis": [JOY_AXIS_RIGHT_X, 1.0]},
	"look_up": {"label": "Camera up", "keys": [KEY_PAGEUP], "axis": [JOY_AXIS_RIGHT_Y, -1.0]},
	"look_down": {"label": "Camera down", "keys": [KEY_PAGEDOWN], "axis": [JOY_AXIS_RIGHT_Y, 1.0]},
	"interact": {"label": "Interact / confirm", "keys": [KEY_E], "pad": JOY_BUTTON_A},
	"use_tool": {"label": "Use tool (Reveal / Recall)", "mouse": MOUSE_BUTTON_LEFT, "axis": [JOY_AXIS_TRIGGER_RIGHT, 1.0]},
	"focus": {"label": "Focus / Observe", "mouse": MOUSE_BUTTON_RIGHT, "axis": [JOY_AXIS_TRIGGER_LEFT, 1.0]},
	"flare": {"label": "Lantern flare", "keys": [KEY_F], "pad": JOY_BUTTON_X},
	"dodge": {"label": "Dodge / quick step", "keys": [KEY_SPACE], "pad": JOY_BUTTON_B},
	"walk": {"label": "Walk (hold)", "keys": [KEY_SHIFT], "pad": JOY_BUTTON_LEFT_STICK},
	"journal": {"label": "Field Journal", "keys": [KEY_J, KEY_TAB], "pad": JOY_BUTTON_Y},
	"wheel": {"label": "Equipment wheel", "keys": [KEY_Q], "pad": JOY_BUTTON_LEFT_SHOULDER},
	"tool_next": {"label": "Next tool", "pad": JOY_BUTTON_RIGHT_SHOULDER},
	"map": {"label": "Map", "keys": [KEY_M], "pad": JOY_BUTTON_BACK},
	"pause": {"label": "Pause", "keys": [KEY_ESCAPE, KEY_P], "pad": JOY_BUTTON_START},
	"hint": {"label": "Contextual hint", "keys": [KEY_H], "pad": JOY_BUTTON_DPAD_UP},
	"tool_lantern": {"label": "Gloam Lantern", "keys": [KEY_1], "pad": JOY_BUTTON_DPAD_LEFT},
	"tool_watch": {"label": "Midnight Watch", "keys": [KEY_2], "pad": JOY_BUTTON_DPAD_RIGHT},
	"recenter": {"label": "Recenter camera", "keys": [KEY_C], "pad": JOY_BUTTON_RIGHT_STICK},
	"skip": {"label": "Skip / fast-forward dialogue", "keys": [KEY_ENTER], "pad": JOY_BUTTON_DPAD_DOWN},
}
const REMAPPABLE := ["move_forward", "move_back", "move_left", "move_right", "interact", "use_tool", "focus", "flare", "dodge", "walk",
	"journal", "wheel", "map", "pause", "hint", "tool_lantern", "tool_watch", "recenter", "look_left", "look_right", "look_up", "look_down"]

const GLYPHS := {
	"xbox": {"south": "A", "east": "B", "west": "X", "north": "Y", "lb": "LB", "rb": "RB", "lt": "LT", "rt": "RT", "start": "Menu", "back": "View", "up": "D-pad ▲", "down": "D-pad ▼", "left": "D-pad ◀", "right": "D-pad ▶", "ls": "LS", "rs": "RS"},
	"playstation": {"south": "✕", "east": "○", "west": "□", "north": "△", "lb": "L1", "rb": "R1", "lt": "L2", "rt": "R2", "start": "Options", "back": "Touchpad", "up": "▲", "down": "▼", "left": "◀", "right": "▶", "ls": "L3", "rs": "R3"},
	"nintendo": {"south": "B", "east": "A", "west": "Y", "north": "X", "lb": "L", "rb": "R", "lt": "ZL", "rt": "ZR", "start": "+", "back": "−", "up": "▲", "down": "▼", "left": "◀", "right": "▶", "ls": "L-click", "rs": "R-click"},
}

var last_device := "kbm"
var pad_name := ""
var capture_callback: Callable

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_actions()
	Events.settings_changed.connect(func(p, _v): if p == "controls.nintendo_layout" or p == "controls.deadzone": _build_actions())
	Input.joy_connection_changed.connect(func(dev, connected): if connected: pad_name = Input.get_joy_name(dev); last_device = "pad")

func _build_actions() -> void:
	var saved: Dictionary = Settings.data.controls.get("bindings", {})
	var dz: float = Settings.data.controls.get("deadzone", 0.15)
	var nin: bool = Settings.data.controls.get("nintendo_layout", false)
	for action in ACTIONS.keys():
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, dz)
		var def: Dictionary = ACTIONS[action]
		if saved.has(action):
			for s in saved[action]:
				var ev := _decode(s)
				if ev: InputMap.action_add_event(action, ev)
		else:
			for k in def.get("keys", []):
				var e := InputEventKey.new(); e.physical_keycode = k; InputMap.action_add_event(action, e)
			if def.has("mouse"):
				var m := InputEventMouseButton.new(); m.button_index = def.mouse; InputMap.action_add_event(action, m)
		if def.has("pad"):
			var jb := InputEventJoypadButton.new()
			var b: int = def.pad
			if nin and b == JOY_BUTTON_A: b = JOY_BUTTON_B
			elif nin and b == JOY_BUTTON_B: b = JOY_BUTTON_A
			jb.button_index = b
			InputMap.action_add_event(action, jb)
		if def.has("axis"):
			var ja := InputEventJoypadMotion.new(); ja.axis = def.axis[0]; ja.axis_value = def.axis[1]
			InputMap.action_add_event(action, ja)
	# menus: make confirm/back follow the Nintendo layout too
	for a in ["ui_accept", "ui_cancel"]:
		for e in InputMap.action_get_events(a):
			if e is InputEventJoypadButton: InputMap.action_erase_event(a, e)
	var acc := InputEventJoypadButton.new(); acc.button_index = JOY_BUTTON_B if nin else JOY_BUTTON_A; InputMap.action_add_event("ui_accept", acc)
	var can := InputEventJoypadButton.new(); can.button_index = JOY_BUTTON_A if nin else JOY_BUTTON_B; InputMap.action_add_event("ui_cancel", can)

func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		last_device = "kbm"
	elif event is InputEventMouseMotion:
		if event.relative.length() > 2.0: last_device = "kbm"
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.4):
		last_device = "pad"
		pad_name = Input.get_joy_name(event.device)
	elif event is InputEventScreenTouch:
		last_device = "touch"
	if capture_callback.is_valid() and event.is_pressed() and (event is InputEventKey or event is InputEventMouseButton):
		get_viewport().set_input_as_handled()
		var cb := capture_callback
		capture_callback = Callable()
		cb.call(event)

## Wait for the next key / mouse button (used by the remapping menu).
func capture(cb: Callable) -> void:
	capture_callback = cb

func rebind(action: String, event: InputEvent) -> void:
	var list: Array = []
	list.append(_encode(event))
	# keep a secondary binding if it was different
	for e in InputMap.action_get_events(action):
		if (e is InputEventKey or e is InputEventMouseButton) and _encode(e) != list[0] and list.size() < 2:
			list.append(_encode(e))
	Settings.data.controls.bindings[action] = list
	Settings.save()
	_build_actions()
	Events.settings_changed.emit("controls.bindings", action)

func reset_bindings() -> void:
	Settings.data.controls.bindings = {}
	Settings.save()
	_build_actions()

func _encode(e: InputEvent) -> String:
	if e is InputEventKey: return "key:%d" % (e.physical_keycode if e.physical_keycode else e.keycode)
	if e is InputEventMouseButton: return "mouse:%d" % e.button_index
	return ""

func _decode(s: String) -> InputEvent:
	var p := s.split(":")
	if p.size() != 2: return null
	if p[0] == "key":
		var e := InputEventKey.new(); e.physical_keycode = int(p[1]); return e
	if p[0] == "mouse":
		var m := InputEventMouseButton.new(); m.button_index = int(p[1]); return m
	return null

func glyph_family() -> String:
	var pref: String = Settings.data.controls.glyphs
	if pref != "auto": return pref
	if last_device == "touch": return "touch"
	if last_device != "pad": return "keyboard"
	var n := pad_name.to_lower()
	if n.contains("ps") or n.contains("dualshock") or n.contains("dualsense") or n.contains("playstation") or n.contains("wireless controller") or n.contains("054c"):
		return "playstation"
	if n.contains("nintendo") or n.contains("pro controller") or n.contains("joy-con") or n.contains("switch") or n.contains("057e"):
		return "nintendo"
	return "xbox"

## Human-readable label for an action in the current glyph family.
func label(action: String) -> String:
	var fam := glyph_family()
	if fam == "touch":
		return {"interact": "Use", "use_tool": "Tool", "focus": "Focus", "flare": "Flare", "dodge": "Dodge", "journal": "Journal", "hint": "Hint", "pause": "Pause"}.get(action, action)
	if fam == "keyboard":
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(e.physical_keycode) if e.physical_keycode else e.keycode)
			if e is InputEventMouseButton:
				return {MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB"}.get(e.button_index, "Mouse %d" % e.button_index)
		return "—"
	var g: Dictionary = GLYPHS[fam]
	var nin: bool = Settings.data.controls.nintendo_layout or fam == "nintendo"
	var pos := {
		"interact": "east" if nin else "south", "dodge": "south" if nin else "east", "flare": "west", "journal": "north",
		"use_tool": "rt", "focus": "lt", "wheel": "lb", "tool_next": "rb", "map": "back", "pause": "start", "hint": "up", "skip": "down",
		"recenter": "rs", "walk": "ls", "tool_lantern": "left", "tool_watch": "right",
	}.get(action, "")
	return g.get(pos, action)

func binding_text(action: String) -> String:
	var parts: Array[String] = []
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			parts.append(OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(e.physical_keycode) if e.physical_keycode else e.keycode))
		elif e is InputEventMouseButton:
			parts.append({MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB"}.get(e.button_index, "Mouse %d" % e.button_index))
	return " / ".join(parts) if parts.size() else "—"

func rumble(strength := 0.5, seconds := 0.18) -> void:
	if not Settings.data.controls.vibration: return
	for d in Input.get_connected_joypads():
		Input.start_joy_vibration(d, clampf(strength * 0.6, 0, 1), clampf(strength, 0, 1), seconds)
	if last_device == "touch" and OS.has_feature("mobile"):
		Input.vibrate_handheld(int(seconds * 600))
