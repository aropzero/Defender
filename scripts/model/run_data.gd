extends Node
## Mutable state for the current run. The synergy engine reads this; the
## game controller writes it. Everything is reset at run start.

var player = {
	"level": 1, "xp": 0, "attr": {"might": 0, "swiftness": 0, "wits": 0, "bastion": 0, "mastery": 0},
	"keystones": [],
}
var gold = 120.0
var castle = {"hp": 220.0, "max_hp": 220.0}
var wave = 1
var kills = 0
var waves_cleared = 0

# campaign layer: wave omens, permanent pacts, kill-streak combo
var omen_id = ""
var omen_give = {}   # wave omen bonus dict (key -> value), injected on refresh
var give_bonus = {}  # permanent pact bonuses (key -> value), injected on refresh
var pacts = []       # pact ids already taken this run
var combo = 0        # kill streak without a castle breach

# Tower instances. Each: {id, level, relics: [], gx:int, gy:int}
var towers = []
var tower_index = {}   # key "gx,gy" -> index in towers (or -1)
var next_tower_serial = 1

var skills_owned = []
var skills_equipped = []   # active slots
var skill_ranks = {}
var skill_cds = {}         # id -> remaining seconds

var ascensions = {}        # id -> true

# transient combat state
var freeze_global_timer = 0.0
var arcoverload_timer = 0.0
var lifesteal_temp = 0.0

func reset() -> void:
	player = {"level": 1, "xp": 0, "attr": {"might": 0, "swiftness": 0, "wits": 0, "bastion": 0, "mastery": 0}, "keystones": []}
	gold = 120.0
	castle = {"hp": 220.0, "max_hp": 220.0}
	wave = 1
	kills = 0
	waves_cleared = 0
	omen_id = ""
	omen_give = {}
	give_bonus = {}
	pacts = []
	combo = 0
	towers = []
	tower_index = {}
	next_tower_serial = 1
	skills_owned = []
	skills_equipped = []
	skill_ranks = {}
	skill_cds = {}
	ascensions = {}
	freeze_global_timer = 0.0
	arcoverload_timer = 0.0
	lifesteal_temp = 0.0

func add_tower(id: String, gx: int, gy: int) -> Dictionary:
	var key = "%d,%d" % [gx, gy]
	if tower_index.has(key):
		return {}
	var inst = {"id": id, "level": 1, "relics": [], "gx": gx, "gy": gy, "serial": next_tower_serial}
	next_tower_serial += 1
	towers.append(inst)
	tower_index[key] = towers.size() - 1
	return inst

func remove_tower(index: int) -> void:
	if index < 0 or index >= towers.size():
		return
	var key = "%d,%d" % [towers[index].gx, towers[index].gy]
	towers.remove_at(index)
	tower_index.erase(key)
	# rebuild index
	tower_index.clear()
	for i in towers.size():
		tower_index["%d,%d" % [towers[i].gx, towers[i].gy]] = i

func tower_key(gx: int, gy: int) -> String:
	return "%d,%d" % [gx, gy]

func tower_at(gx: int, gy: int) -> Dictionary:
	var key = tower_key(gx, gy)
	if tower_index.has(key):
		return towers[tower_index[key]]
	return {}

func has_tower_type(id: String) -> bool:
	for t in towers:
		if t.id == id:
			return true
	return false

func tower_type_count(id: String) -> int:
	var n = 0
	for t in towers:
		if t.id == id:
			n += 1
	return n

func equip_skill(id: String) -> void:
	if id in skills_owned and not (id in skills_equipped):
		skills_equipped.append(id)
		skill_cds[id] = 0.0

func unequip_skill(id: String) -> void:
	skills_equipped.erase(id)

func rank_skill(id: String) -> void:
	skill_ranks[id] = skill_ranks.get(id, 0) + 1

func skill_rank(id: String) -> int:
	return skill_ranks.get(id, 0)
