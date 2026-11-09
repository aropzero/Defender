extends Node
## Cross-run progression: Essence Shards earned from performance, spent to
## carry small permanent advantages into future runs.

const SAVE_PATH = "user://citadel_meta.cfg"

var shards = 0
var best_wave = 0
var unlocks = {}   # unlock id -> true

func _ready() -> void:
	load_save()

func load_save() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		shards = int(cfg.get_value("meta", "shards", 0))
		best_wave = int(cfg.get_value("meta", "best_wave", 0))
		var un = cfg.get_value("meta", "unlocks", {})
		if un is Dictionary:
			unlocks = un

func save_save() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("meta", "shards", shards)
	cfg.set_value("meta", "best_wave", best_wave)
	cfg.set_value("meta", "unlocks", unlocks)
	cfg.save(SAVE_PATH)

func add_shards(n: int) -> void:
	shards += n
	save_save()

func record_wave(w: int) -> void:
	if w > best_wave:
		best_wave = w
		save_save()

func has_unlock(id: String) -> bool:
	return unlocks.get(id, false)

func unlock(id: String, cost: int) -> bool:
	if has_unlock(id) or shards < cost:
		return false
	shards -= cost
	unlocks[id] = true
	save_save()
	return true

# The unlock table (permanent small boons).
const UNLOCKS = [
	{"id": "u_gold", "name": "Treasury", "desc": "Start each run with +100 gold.", "cost": 80, "effect": "gold_start", "value": 100},
	{"id": "u_slot", "name": "Echo Slot", "desc": "Equip one extra active skill slot.", "cost": 120, "effect": "extra_skill_slot", "value": 1},
	{"id": "u_attr", "name": "Prodigy", "desc": "Start each run with +2 attribute points.", "cost": 100, "effect": "attr_start", "value": 2},
	{"id": "u_cp", "name": "Stronghold", "desc": "Start with +60 castle max HP.", "cost": 100, "effect": "castle_start", "value": 60},
	{"id": "u_relic", "name": "Antique Relic", "desc": "Start the run with a free tower relic.", "cost": 150, "effect": "relic_start", "value": 1},
]
