class_name Dialogue
extends Node
## Runs conversations: subtitles with a typewriter reveal, character voices, lip flaps and
## expressions, listeners turning to the speaker, an optional two-shot camera, and choices.
##   await dialogue.say([["porter", "Good evening.", {"expr": "happy", "anim": "bow"}], ...])
## Line options: expr, anim, anim_dur, look (Vector3), cam ([pos, look]), frame (bool), wait (secs), id.

const NAMES := {"avery": "Avery", "mara": "Mara", "porter": "The Night Porter", "pip": "Pip", "host": "The Forgotten Host",
	"edmund": "Edmund", "margaret": "Margaret", "king": "The Masked King", "guide": "Field Guide", "": ""}
const COLORS := {"avery": Color(0.95, 0.78, 0.5), "mara": Color(1.0, 0.7, 0.85), "porter": Color(0.6, 0.95, 0.85), "pip": Color(0.7, 1.0, 0.9),
	"host": Color(1.0, 0.7, 0.75), "edmund": Color(1.0, 0.88, 0.62), "margaret": Color(1.0, 0.88, 0.62), "king": Color(1.0, 0.88, 0.62), "guide": Color(0.75, 0.85, 1.0)}

var hud: HUD
var player: Player
var actors := {}
var active := false
var _advance := false
var _choice := -1
var _skip_all := false

func register(id: String, node: Node3D) -> void:
	actors[id] = node

func _unhandled_input(e: InputEvent) -> void:
	if not active: return
	if e.is_action_pressed("interact") or e.is_action_pressed("skip") or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		_advance = true
		get_viewport().set_input_as_handled()

func _actor_for(id: String) -> Node3D:
	if id == Save.profile.get("character", "avery") or id == "avery" and player: return player.avatar if player else null
	return actors.get(id)

func say(lines: Array, opts := {}) -> void:
	while active: await get_tree().process_frame
	active = true
	_skip_all = false
	Events.dialogue_started.emit()
	if player: player.lock("dialogue")
	Audio.music_duck(-6.0, 0.5)
	var framed := false
	for line in lines:
		var who: String = line[0]
		var text: String = line[1]
		var o: Dictionary = line[2] if line.size() > 2 else {}
		var speaker := _actor_for(who)
		# everyone present looks at whoever is talking
		if speaker and is_instance_valid(speaker):
			var head := (speaker as Character).head_position() if speaker is Character else speaker.global_position + Vector3(0, 1.5, 0)
			for k in actors.keys():
				var a = actors[k]
				if a is Character and a != speaker and is_instance_valid(a) and a.global_position.distance_to(speaker.global_position) < 9.0: a.look_at_target = head
			if player and speaker != player.avatar and player.avatar.global_position.distance_to(speaker.global_position) < 9.0: player.avatar.look_at_target = head
			if speaker is Character:
				var c := speaker as Character
				if o.has("expr"): c.expression = o.expr
				if o.has("anim"): c.play(o.anim, o.get("anim_dur", 1.6))
				c.talk = true
				if player and c != player.avatar: c.look_at_target = player.avatar.head_position()
				elif o.has("look"): c.look_at_target = o.look
		# camera
		if player and o.has("cam"):
			player.rig.cinematic(o.cam[0], o.cam[1], o.get("fov", 50.0)); framed = true
		elif player and (o.get("frame", opts.get("frame", false))) and speaker and speaker != player.avatar:
			_two_shot(speaker); framed = true
		var vid: String = who if Audio.VOICES.has(who) else ("avery" if who == "" else who)
		var dur := 0.0
		if who != "": dur = Audio.speak(Save.profile.get("character", "avery") if who == "avery" else vid, text, o.get("id", ""))
		var shown := text if who != "" else "[i]%s[/i]" % text
		hud.show_line(NAMES.get(who, who.capitalize()), shown, COLORS.get(who, UIKit.GOLD))
		var read := maxf(dur + 0.6, 1.4 + text.length() * 0.042)
		if o.has("wait"): read = o.wait
		var t := 0.0
		_advance = false
		while true:
			await get_tree().process_frame
			t += get_process_delta_time() / maxf(Engine.time_scale, 0.01)
			if _advance:
				_advance = false
				if not hud.line_done(): hud.finish_line()
				else: break
			if t > read and hud.line_done() and not o.get("hold", false): break
			if speaker is Character and not Audio.talking: (speaker as Character).talk = false
		if speaker is Character: (speaker as Character).talk = false
		Audio.stop_voice()
		if o.has("after"): (o.after as Callable).call()
	hud.hide_line()
	for k in actors.keys():
		var a = actors[k]
		if a is Character and is_instance_valid(a): a.look_at_target = null; a.talk = false
	if player:
		player.avatar.look_at_target = null
		if framed: player.rig.release()
		player.unlock("dialogue")
	Audio.music_duck(0.0, 0.8)
	active = false
	Events.dialogue_finished.emit()

## Ask a question; returns the index chosen.
func choose(who: String, question: String, options: Array) -> int:
	while active: await get_tree().process_frame
	active = true
	if player: player.lock("choice")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_line(NAMES.get(who, who), question, COLORS.get(who, UIKit.GOLD))
	hud.finish_line()
	_choice = -1
	hud.show_choices(options, func(i): _choice = i)
	while _choice < 0:
		await get_tree().process_frame
		for i in mini(options.size(), 4):
			if Input.is_key_pressed(KEY_1 + i): _choice = i
	hud.hide_line()
	if not Settings.data.controls.get("touch_controls", "auto") == "on": Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if player: player.unlock("choice")
	active = false
	return _choice

func _two_shot(speaker: Node3D) -> void:
	var p := player.global_position
	var s := speaker.global_position
	var d := s - p; d.y = 0
	var dist := clampf(d.length(), 1.0, 6.0)
	var dir := d.normalized() if d.length() > 0.01 else Vector3.FORWARD
	var side := dir.cross(Vector3.UP).normalized()
	if side.dot(player.rig.cam.global_position - p) < 0.0: side = -side
	var mid := (p + s) * 0.5
	var head_y := (speaker as Character).head_position().y if speaker is Character else s.y + 1.6
	var cam_pos := mid + side * (dist * 0.75 + 1.0) - dir * (dist * 0.55 + 0.6) + Vector3(0, head_y - mid.y - 0.05, 0)
	player.rig.cinematic(cam_pos, Vector3(s.x, head_y - 0.1, s.z), 42.0)
