class_name LightManager
extends Node
## Animates candle flicker, keeps distant lamps switched off, and gives real shadows to the
## nearest / most important lamps up to the "Shadow-casting lamps" budget.

var rooms: Dictionary = {}
var focus := Vector3.ZERO
var _t := 0.0
var _active: Array = []

func register_room(r: Room) -> void:
	rooms[r.id] = r

func refresh(active_rooms: Array) -> void:
	_active = []
	for id in active_rooms:
		if rooms.has(id): _active.append(rooms[id])

func _process(dt: float) -> void:
	var time := Time.get_ticks_msec() / 1000.0
	var g: Dictionary = Settings.data.graphics
	var range_mul: float = g.light_range
	var disco: bool = Settings.data.cheats.disco
	_t -= dt
	var assign := _t <= 0.0
	if assign: _t = 0.3
	var candidates: Array = []
	for r in _active:
		for l in r.lights:
			if not is_instance_valid(l) or not l.is_visible_in_tree(): continue
			var base: float = l.get_meta("base_energy", 1.0)
			var fl: float = l.get_meta("flicker", 0.0)
			var seed: float = l.get_meta("seed", 0.0)
			if fl > 0.0:
				var k := 1.0 + fl * (sin(time * 11.0 + seed) * 0.5 + sin(time * 23.7 + seed * 2.0) * 0.3 + sin(time * 5.3 + seed * 3.0) * 0.2)
				l.light_energy = base * k
			if disco:
				l.light_color = Color.from_hsv(fmod(time * 0.25 + seed * 0.1, 1.0), 0.7, 1.0)
			l.distance_fade_begin = 20.0 * range_mul
			if assign and l.get_meta("can_shadow", true):
				var d: float = l.global_position.distance_to(focus)
				candidates.append([float(l.get_meta("priority", 1.0)) * base / (1.0 + d * d * 0.05), l])
	if assign:
		candidates.sort_custom(func(a, b): return a[0] > b[0])
		var budget: int = int(g.shadow_lights) if g.shadows != "off" else 0
		for i in candidates.size():
			var l: OmniLight3D = candidates[i][1]
			var want := i < budget
			if l.shadow_enabled != want: l.shadow_enabled = want
