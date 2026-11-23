extends Node
## Entry point: title screen <-> game session.

var screen: Node

func _ready() -> void:
	Game.main = self
	get_window().title = "The House Beyond Midnight"
	var cur: Texture2D = load("res://assets/ui/cursor.png")
	if cur: Input.set_custom_mouse_cursor(cur, Input.CURSOR_ARROW, Vector2(4, 2))
	get_tree().set_auto_accept_quit(true)
	var args := OS.get_cmdline_user_args()
	if args.has("--continue") and Save.has_any():
		start_game(int(Settings.data.meta.get("last_slot", 0)))
	elif args.has("--new"):
		start_game(2, "Avery")
	else:
		show_title()

func _clear() -> void:
	if screen and is_instance_valid(screen): screen.queue_free()
	screen = null
	Audio.stop_voice()

func show_title() -> void:
	_clear()
	var layer := CanvasLayer.new(); layer.name = "TitleLayer"
	var t := TitleScreen.new(); t.main = self
	layer.add_child(t)
	add_child(layer)
	screen = layer
	Audio.play_music("title", 2.0)
	Audio.set_ambience({"rain_out": 0.5, "wind": 0.4})

func start_game(slot: int, new_name := "") -> void:
	if new_name != "": Save.start(slot, new_name)
	elif Save.load_slot(slot).is_empty(): Save.start(slot, "Avery")
	Settings.data.meta.last_slot = slot
	Settings.save()
	_clear()
	var g := GameScreen.new(); g.name = "Game"; g.main = self
	add_child(g)
	screen = g
	Audio.play_music("", 1.5)
	g.start()
