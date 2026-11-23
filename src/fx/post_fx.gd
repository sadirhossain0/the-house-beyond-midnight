class_name PostFX
extends CanvasLayer
## Full-screen finishing pass: vignette, grain, chromatic fringe, cheat filters, and the story
## effects (Now/Then shift ripple, memory echo sepia, ghost tint, hurt, faint, fades and flashes).

var rect: ColorRect
var mat: ShaderMaterial
var player: Node
var shift := 0.0
var echo := 0.0
var ghost := 0.0
var fade := 0.0
var flash := 0.0
var faint := 0.0

func _ready() -> void:
	layer = 1
	rect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new(); mat.shader = load("res://src/fx/post.gdshader")
	rect.material = mat
	add_child(rect)

func _process(dt: float) -> void:
	var g: Dictionary = Settings.data.graphics
	var fl: float = {"full": 1.0, "reduced": 0.35, "off": 0.0}.get(g.flashing, 0.35)
	flash = maxf(0.0, flash - dt * 3.0)
	mat.set_shader_parameter("vignette", 0.38 if g.vignette else 0.0)
	mat.set_shader_parameter("grain", 0.028 if g.film_grain else 0.0)
	mat.set_shader_parameter("chroma", 1.0 if g.chromatic else 0.0)
	mat.set_shader_parameter("filter_mode", ["none", "retro", "mono", "vhs"].find(Settings.data.cheats.filter))
	mat.set_shader_parameter("motion", 0.3 if g.reduce_motion else 1.0)
	mat.set_shader_parameter("shift", shift)
	mat.set_shader_parameter("echo", echo)
	mat.set_shader_parameter("ghost", maxf(ghost, 0.6 if Settings.data.cheats.ghost_vision else 0.0))
	var hurt := 0.0
	if player and is_instance_valid(player) and player.has_method("hurt_flash"): hurt = player.hurt_flash()
	mat.set_shader_parameter("hurt", hurt)
	var f2 := faint
	if player and is_instance_valid(player) and player.get("state") == "fainted": f2 = maxf(f2, 1.0)
	mat.set_shader_parameter("faint", f2)
	mat.set_shader_parameter("fade", fade)
	mat.set_shader_parameter("flash", flash * fl)
	rect.visible = true

func fade_to(v: float, d: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "fade", v, d)
	await tw.finished

func ripple(d := 1.4) -> void:
	shift = 0.0
	var tw := create_tween()
	tw.tween_property(self, "shift", 1.0, d).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): shift = 0.0)
