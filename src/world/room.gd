class_name Room
extends Node3D
## A room of the estate: its geometry, colliders, lights, acoustics, mood and (optionally)
## separate Now and Then states for the Midnight Watch.

var id := ""
var display_name := ""
var bounds := AABB()
var neighbors: Array = []
var music := ""
var grade := ""
var ambience := {}
var acoustics := Vector3(0.4, 0.15, 0.45)  # room_size, wet, damping
var fog := {"color": Color(0.05, 0.05, 0.07), "density": 0.02, "light": Color(0.1, 0.1, 0.12), "height": 0.0}
var fog_then := {}
var ambient := {"color": Color(0.12, 0.14, 0.2), "energy": 0.3}
var ambient_then := {}
var surface := "wood"
var hidden_room := false
var map_rect := Rect2()
var state := "now"
var state_now: Node3D
var state_then: Node3D
var bodies := {}          # tag -> StaticBody3D
var floor_bodies := {}    # "tag:surface" -> StaticBody3D
var lights: Array = []    # OmniLight3D / SpotLight3D managed by LightManager
var flames := {"common": [], "now": [], "then": []}
var glows := {"common": [], "now": [], "then": []}
var flame_mm := {}
var glow_mm := {}
var updaters: Array[Callable] = []
var reflection_probe: ReflectionProbe

func setup(p_id: String, opts: Dictionary) -> Room:
	id = p_id
	name = "Room_" + p_id
	display_name = opts.get("name", p_id)
	bounds = opts.get("bounds", AABB())
	neighbors = opts.get("neighbors", [])
	music = opts.get("music", "")
	grade = opts.get("grade", p_id)
	ambience = opts.get("ambience", {})
	acoustics = opts.get("acoustics", acoustics)
	fog = opts.get("fog", fog)
	fog_then = opts.get("fog_then", {})
	ambient = opts.get("ambient", ambient)
	ambient_then = opts.get("ambient_then", {})
	surface = opts.get("surface", "wood")
	hidden_room = opts.get("hidden", false)
	map_rect = opts.get("map_rect", Rect2())
	return self

func enable_states() -> void:
	state_now = Node3D.new(); state_now.name = "Now"; add_child(state_now)
	state_then = Node3D.new(); state_then.name = "Then"; add_child(state_then)
	state_then.visible = false
	state = "now"

func set_state(s: String) -> void:
	if state_now == null: return
	state = s
	state_now.visible = s == "now"
	state_then.visible = s == "then"
	for tag in ["now", "then"]:
		var on: bool = tag == s
		for key in bodies.keys():
			if key == tag: _set_body_enabled(bodies[key], on)
		for key in floor_bodies.keys():
			if String(key).begins_with(tag + ":"): _set_body_enabled(floor_bodies[key], on)

func _set_body_enabled(b: StaticBody3D, on: bool) -> void:
	for c in b.get_children():
		if c is CollisionShape3D: c.set_deferred("disabled", not on)

func contains(p: Vector3) -> bool:
	return bounds.has_point(p)

func current_fog() -> Dictionary:
	return fog_then if state == "then" and not fog_then.is_empty() else fog

func current_ambient() -> Dictionary:
	return ambient_then if state == "then" and not ambient_then.is_empty() else ambient
