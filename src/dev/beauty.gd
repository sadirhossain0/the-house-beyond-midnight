extends "res://src/dev/playtest.gd"
## Beauty shots from inside the running game: Avery in the foreground, facing the lens, with the
## room and its cast behind. godot --path . res://src/dev/beauty.tscn -- --out=/tmp/beauty --preset=high
func run() -> void:
	await idle()
	gs.hud.visible = false
	for f in ["intro_done", "entered_house", "clue_clocks", "has_lantern", "pip_met", "porter_met", "host_met"]: Game.set_flag(f)
	gs.player.give_lantern()
	var cam := gs.player.rig
	# [name, room, avatar position, what stands behind them, camera distance, side angle, camera height, raise lantern]
	var poses := [
		["drive", "exterior", Vector3(1.0, -0.55, -15.2), Vector3(2.8, 0.2, -18.6), 2.7, 0.45, 0.55, false],
		["house", "exterior", Vector3(0.2, -0.55, -7.2), Vector3(0.0, 2.2, 0.0), 3.0, -0.3, 0.45, false],
		["hall", "hall", Vector3(0.0, 0.05, 8.0), Vector3(0.0, 3.5, 19.0), 2.8, 0.35, 0.55, false],
		["hall_lantern", "hall", Vector3(-2.6, 0.05, 9.4), Vector3(-6.0, 1.2, 12.5), 2.4, -0.5, 0.45, true],
		["corridor", "corridor", Vector3(-24.0, 0.05, 4.0), Vector3(-33.0, 0.9, 4.2), 2.6, 0.25, 0.5, true],
		["cloakroom", "cloakroom", Vector3(-28.0, 0.05, 8.2), Vector3(-29.6, 0.9, 10.6), 2.4, 0.6, 0.55, false],
		["ballroom_then", "ballroom", Vector3(19.0, 0.05, 6.0), Vector3(28.0, 1.6, 6.0), 3.0, 0.35, 0.7, false],
		["ballroom_host", "ballroom", Vector3(31.6, 0.05, 5.0), Vector3(33.6, 0.9, 6.0), 2.6, 1.0, 0.5, false],
		["balcony", "balcony", Vector3(24.0, 0.05, 20.6), Vector3(25.0, 0.9, 22.6), 2.4, 0.7, 0.5, false],
	]
	for p in poses:
		if p[1] == "ballroom": gs.world.set_room_state("ballroom", "then")
		var pos: Vector3 = p[2]; var behind: Vector3 = p[3]
		var away := (pos - behind); away.y = 0; away = away.normalized().rotated(Vector3.UP, p[5])
		var cpos: Vector3 = pos + away * p[4] + Vector3(0, 0.6 + p[6], 0)
		await go(pos, atan2(cpos.x - pos.x, cpos.z - pos.z))
		gs.world.set_current(p[1], true)
		if p[7]: Input.action_press("use_tool")
		else: Input.action_release("use_tool")
		var av: Character = gs.player.avatar
		av.expression = "happy" if not p[7] else "determined"
		var look: Vector3 = pos + Vector3(0, 0.75, 0) + (behind - pos).normalized() * 0.8
		cam.cinematic(cpos, look, 50.0)
		cam._blend = 1.0
		for i in 36:
			av._idle_t = -100.0; av._idle_special = 0.0
			av.look_at_target = cpos
			await get_tree().process_frame
		await shot(p[0])
