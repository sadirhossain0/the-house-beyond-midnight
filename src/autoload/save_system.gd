extends Node
## Save profiles (3 slots) with a rolling backup per slot, JSON export / import, and two kinds of
## restore code:
##  • Full restore code: the whole save, deflate-compressed, base64, CRC32-checked (copy & paste).
##  • Midnight Code: a short password holding progress bits only, short enough to write on paper.

const SLOTS := 3
const VERSION := 3
const CROCKFORD := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

var profile: Dictionary = {}

func new_profile(slot: int, name := "Avery") -> Dictionary:
	return {
		"version": VERSION, "slot": slot, "name": name if name != "" else "Investigator",
		"created_at": Time.get_unix_time_from_system(), "saved_at": 0, "play_time": 0.0,
		"chapter": 0, "chimes": 0, "character": "avery",
		"costumes": {"avery": "fieldcoat", "mara": "performer"},
		"unlocked_costumes": ["avery:fieldcoat", "mara:performer"], "unlocked_characters": ["avery"],
		"flags": {}, "objective": "pro_arrive", "objectives_done": [],
		"clues": [], "deductions": [], "collectibles": [], "ghost_cards": [], "records": ["title"], "emblems": [],
		"achievements": [], "inventory": [], "hints_seen": {},
		"stats": {"candles_lost": 0, "faints": 0, "hints_used": 0, "flares": 0, "shifts": 0, "wrong_fragments": 0, "reveals": 0, "distance": 0.0},
		"room": "exterior", "pos": [0.0, -0.6, -16.0], "yaw": 0.0,
		"room_states": {"ballroom": "now"}, "obj_state": {}, "checkpoint": "", "cheat_active": false,
	}

func _path(slot: int, backup := false) -> String:
	return "user://slot_%d%s.json" % [slot, "_bak" if backup else ""]

func read_slot(slot: int) -> Variant:
	return _read(_path(slot))

func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path): return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null: return null
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else null

func _write(path: String, d: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(d))
	return true

func list_slots() -> Array:
	var out := []
	for i in SLOTS: out.append(read_slot(i))
	return out

func has_any() -> bool:
	for s in list_slots():
		if s != null: return true
	return false

func load_slot(slot: int) -> Dictionary:
	var p: Variant = read_slot(slot)
	if p == null: return {}
	profile = migrate(p)
	return profile

func start(slot: int, name: String) -> Dictionary:
	profile = new_profile(slot, name)
	write("new")
	return profile

func write(reason := "manual") -> bool:
	if profile.is_empty(): return false
	var slot: int = profile.slot
	var prev: Variant = read_slot(slot)
	if prev != null: _write(_path(slot, true), prev)
	profile.saved_at = Time.get_unix_time_from_system()
	var ok := _write(_path(slot), profile)
	Events.saved.emit(reason, ok)
	return ok

func has_backup(slot: int) -> bool: return FileAccess.file_exists(_path(slot, true))

func restore_backup(slot: int) -> bool:
	var b: Variant = _read(_path(slot, true))
	if b == null: return false
	return _write(_path(slot), b)

func delete_slot(slot: int) -> void:
	for p in [_path(slot), _path(slot, true)]:
		if FileAccess.file_exists(p): DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

## Writes the save as a readable JSON file the player can keep or move between devices.
func export_slot(slot: int, dest_path: String) -> bool:
	var p: Variant = read_slot(slot)
	if p == null: return false
	var d: Dictionary = p.duplicate(true)
	d["game"] = "the-house-beyond-midnight"
	var f := FileAccess.open(dest_path, FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(d, "\t"))
	return true

func import_file(slot: int, src_path: String) -> String:
	var f := FileAccess.open(src_path, FileAccess.READ)
	if f == null: return "Could not open that file."
	var d: Variant = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary) or d.get("game", "") != "the-house-beyond-midnight":
		return "That file is not a House Beyond Midnight save."
	d.erase("game")
	d.slot = slot
	var prev: Variant = read_slot(slot)
	if prev != null: _write(_path(slot, true), prev)
	_write(_path(slot), migrate(d))
	return ""

# ------------------------------------------------------------------------------------- codes
static func crc32(bytes: PackedByteArray) -> int:
	var crc := 0xFFFFFFFF
	for b in bytes:
		var c := (crc ^ b) & 0xFF
		for _k in 8:
			c = (0xEDB88320 ^ (c >> 1)) if (c & 1) else (c >> 1)
		crc = (crc >> 8) ^ c
	return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF

func full_restore_code(p: Dictionary) -> String:
	var raw := JSON.stringify(p).to_utf8_buffer()
	var z := raw.compress(FileAccess.COMPRESSION_DEFLATE)
	var crc := "%08x" % crc32(z)
	var body := Marshalls.raw_to_base64(z).replace("+", "-").replace("/", "_").replace("=", "")
	var wrapped := ""
	for i in range(0, body.length(), 48):
		wrapped += body.substr(i, 48) + "\n"
	return "HBMSAVE:Z:%d:%s:\n%s" % [raw.size(), crc, wrapped.strip_edges()]

func midnight_code(p: Dictionary, registry: Dictionary) -> String:
	var bits: Array[int] = []
	var push := func(list: Array, owned: Array) -> void:
		for id in list: bits.append(1 if owned.has(id) else 0)
	var flags_on: Array = []
	for k in p.flags.keys():
		if p.flags[k]: flags_on.append(k)
	push.call(registry.flags, flags_on)
	push.call(registry.clues, p.clues)
	push.call(registry.deductions, p.deductions)
	push.call(registry.collectibles, p.collectibles)
	push.call(registry.costumes, p.unlocked_costumes)
	push.call(registry.characters, p.unlocked_characters)
	var bytes := PackedByteArray([3, (int(p.chapter) & 15) | ((int(p.chimes) & 15) << 4), int(registry.version) & 255])
	var nbytes := int(ceil(bits.size() / 8.0))
	var start := bytes.size()
	bytes.resize(start + nbytes)
	for i in bits.size():
		if bits[i]: bytes[start + (i >> 3)] |= 1 << (i & 7)
	var crc := crc32(bytes)
	bytes.append(crc & 255); bytes.append((crc >> 8) & 255)
	var s := _base32(bytes)
	var grouped := ""
	for i in range(0, s.length(), 4):
		grouped += ("-" if i > 0 else "") + s.substr(i, 4)
	return "HBM-" + grouped

func _base32(bytes: PackedByteArray) -> String:
	var out := ""; var buf := 0; var n := 0
	for b in bytes:
		buf = ((buf << 8) | b) & 0xFFFFFF; n += 8
		while n >= 5:
			out += CROCKFORD[(buf >> (n - 5)) & 31]; n -= 5
	if n > 0: out += CROCKFORD[(buf << (5 - n)) & 31]
	return out

func _unbase32(s: String) -> PackedByteArray:
	var clean := s.to_upper().replace("O", "0").replace("I", "1").replace("L", "1").replace("U", "V")
	var out := PackedByteArray(); var buf := 0; var n := 0
	for ch in clean:
		var v := CROCKFORD.find(ch)
		if v < 0:
			if ch in "- \n\t": continue
			return PackedByteArray()
		buf = ((buf << 5) | v) & 0xFFFFFF; n += 5
		if n >= 8:
			out.append((buf >> (n - 8)) & 255); n -= 8
	return out

## Restores either kind of code into `slot`. Returns "" on success or a friendly error.
func restore_from_code(slot: int, code: String, registry: Dictionary, rebuild: Callable) -> String:
	var t := code.strip_edges()
	var p: Dictionary
	if t.to_upper().begins_with("HBMSAVE:"):
		var flat := t.replace("\n", "").replace("\r", "").replace(" ", "")
		var parts := flat.split(":")
		if parts.size() < 5: return "That restore code is incomplete. Copy the whole block."
		var size := int(parts[2]); var crc := parts[3]
		var body := parts[4].replace("-", "+").replace("_", "/")
		while body.length() % 4 != 0: body += "="
		var z := Marshalls.base64_to_raw(body)
		if "%08x" % crc32(z) != crc.to_lower(): return "That restore code is incomplete or was changed. Copy the whole block."
		var raw := z.decompress(size, FileAccess.COMPRESSION_DEFLATE)
		var d: Variant = JSON.parse_string(raw.get_string_from_utf8())
		if not (d is Dictionary): return "That restore code could not be read."
		p = d
	elif t.to_upper().begins_with("HBM-"):
		var bytes := _unbase32(t.substr(4))
		if bytes.size() < 6: return "That Midnight Code is too short, or uses a letter that codes never contain."
		var data := bytes.slice(0, bytes.size() - 2)
		var crc := crc32(data)
		if bytes[bytes.size() - 2] != (crc & 255) or bytes[bytes.size() - 1] != ((crc >> 8) & 255):
			return "That Midnight Code has a typo somewhere. Check each group of four."
		if data[0] != 3: return "That code is from a different version of the game."
		p = new_profile(slot, "Investigator")
		p.chapter = data[1] & 15; p.chimes = data[1] >> 4
		var bits: Array[int] = []
		for i in range(3, data.size()):
			for b in 8: bits.append((data[i] >> b) & 1)
		var k := [0]
		var take := func(list: Array) -> Array:
			var got := []
			for id in list:
				if k[0] < bits.size() and bits[k[0]] == 1: got.append(id)
				k[0] += 1
			return got
		for f in take.call(registry.flags): p.flags[f] = true
		p.clues = take.call(registry.clues)
		p.deductions = take.call(registry.deductions)
		p.collectibles = take.call(registry.collectibles)
		for c in take.call(registry.costumes):
			if not p.unlocked_costumes.has(c): p.unlocked_costumes.append(c)
		for c in take.call(registry.characters):
			if not p.unlocked_characters.has(c): p.unlocked_characters.append(c)
		if rebuild.is_valid(): rebuild.call(p)
	else:
		return "Paste a full restore code (starts with HBMSAVE:) or type a Midnight Code (starts with HBM-)."
	p.slot = slot
	var prev: Variant = read_slot(slot)
	if prev != null: _write(_path(slot, true), prev)
	_write(_path(slot), migrate(p))
	return ""

func migrate(p: Dictionary) -> Dictionary:
	var base := new_profile(int(p.get("slot", 0)), String(p.get("name", "Avery")))
	for k in p.keys(): base[k] = p[k]
	for k in ["stats", "costumes"]:
		var def: Dictionary = new_profile(0)[k]
		for kk in def.keys():
			if not base[k].has(kk): base[k][kk] = def[kk]
	base.version = VERSION
	return base
