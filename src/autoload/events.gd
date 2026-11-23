extends Node
## Global signal bus. Systems talk through here so they stay decoupled.

signal settings_changed(path: String, value: Variant)
signal graphics_applied
signal room_entered(room_id: String, previous: String)
signal room_state_changed(room_id: String, state: String)
signal objective_changed(id: String)
signal clue_added(id: String)
signal deduction_made(id: String)
signal collectible_found(id: String)
signal achievement_unlocked(id: String)
signal hint_shown(objective: String, tier: int)
signal composure_changed(candles: int, max_candles: int)
signal player_fainted
signal tool_changed(tool: String)
signal saved(reason: String, ok: bool)
signal toast(text: String, kind: String)
signal sound_cue(world_pos: Vector3, label: String)
signal chime_struck(count: int)
signal dialogue_started
signal dialogue_finished
signal costume_changed(character: String, costume: String)
signal cheat_toggled(key: String, on: bool)
signal pause_changed(paused: bool)
