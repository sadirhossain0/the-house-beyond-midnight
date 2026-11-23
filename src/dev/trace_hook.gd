extends "res://src/dev/playtest.gd"
## Narrow repro: jump straight to the cloakroom with the Porter met, hang the coat, and log the
## player's lock state every frame until the objective changes.
func run() -> void:
	await idle()
	for f in ["intro_done", "entered_house", "clue_clocks", "has_lantern", "hidden_door"]: Game.set_flag(f)
	Game.set_objective("ch1_porter", false)
	await go(Vector3(-28.5, 0.05, 7.5), 0.0)
	await use("Night Porter", Vector3(0, 0, -1.4))
	var it := find("hook 7")
	await go((it.pos as Vector3) + Vector3(0, -1.0, -0.9))
	(it.on as Callable).call(it)
	for i in 400:
		_log("f%d state=%s locks=%s dlg=%s obj=%s" % [i, gs.player.state, gs.player._locks.keys(), gs.dialogue.active, Game.objective()])
		if Game.objective() == "ch1_return": break
		await get_tree().process_frame
