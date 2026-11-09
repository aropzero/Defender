extends Node
## ---------------------------------------------------------------------------
## Synergy Engine: computes every active modifier from the current build.
## This is the combinatorial core — it turns "what you built" into numbers.
##
## All modifiers are additive contributions to named keys. Consumers interpret
## each key (see README/design doc). A key's total = sum of contributions.
## ---------------------------------------------------------------------------

var g = {}          # key -> total (sum of contributions)
var flags = {}      # key -> true (presence flags)
var tower_ex = {}   # serial -> {add:{}, behaviors:[], add_status:[], override_kind:""}

var active_resonances = []
var active_adjacencies = []
var active_ascensions = []

func _ready() -> void:
	pass

func add(key: String, v: float) -> void:
	g[key] = g.get(key, 0.0) + v

func flag(key: String) -> void:
	flags[key] = true

func add_val(key: String) -> float:
	return g.get(key, 0.0)

func has_flag(key: String) -> bool:
	return flags.has(key)

func reset() -> void:
	g = {}
	flags = {}
	tower_ex = {}
	active_resonances = []
	active_adjacencies = []
	active_ascensions = []

func refresh() -> void:
	reset()
	_attributes()
	_keystones()
	var pool = _build_pool()
	_resonances(pool)
	_skill_passives()
	if Run.towers.size() > 0:
		_adjacencies()
		_ascensions()

# --- helpers ----------------------------------------------------------------

func _tower_type_tags(tid: String) -> Array:
	var td = DB.towers.get(tid, {})
	return td.get("tags", [])

func _build_pool() -> Dictionary:
	var pool = {}
	var poly = {}
	for k in Run.player.keystones:
		var ks = DB.keystones
		for k2 in ks:
			if k2.get("id", "") == k and k2.get("effect", "") == "polyelement":
				poly[k2.get("tag", "")] = true
	var add_tag = func(tag: String) -> void:
		pool[tag] = pool.get(tag, 0) + (2 if poly.has(tag) else 1)
	for t in Run.towers:
		for tag in _tower_type_tags(t.id):
			add_tag.call(tag)
	for sid in Run.skills_equipped:
		var sd: Dictionary = DB.skills.get(sid, {})
		for tag in sd.get("tags", []):
			add_tag.call(tag)
	return pool

func _attributes() -> void:
	var at: Dictionary = Run.player.attr
	add("mul_dmg", 0.08 * at.get("might", 0))
	add("atk_rate", 0.07 * at.get("swiftness", 0))
	add("crit_chance", 0.015 * at.get("wits", 0))
	add("crit_mult", 0.04 * at.get("wits", 0))
	add("castle_regen", at.get("bastion", 0) * 1.0)
	add("cdr", 0.04 * at.get("mastery", 0))
	add("skill_dmg", 0.06 * at.get("mastery", 0))

func _keystones() -> void:
	for kid in Run.player.keystones:
		for kd in DB.keystones:
			if kd.id == kid and kd.get("effect", "") == "stat":
				var give: Dictionary = kd.get("give", {})
				for key in give:
					add(key, give[key])

func _resonances(pool: Dictionary) -> void:
	for r in DB.resonances:
		var ok = true
		var req: Dictionary = r.req
		for e in req:
			if pool.get(e, 0) < req[e]:
				ok = false
				break
		if ok:
			active_resonances.append(r.id)
			var give: Dictionary = r.give
			for key in give:
				var v = give[key]
				if typeof(v) == TYPE_BOOL:
					if v:
						flag(key)
				else:
					add(key, float(v))

func _skill_passives() -> void:
	for sid in Run.skills_equipped:
		var sd: Dictionary = DB.skills.get(sid, {})
		var pas = sd.get("passive", "")
		if pas == "ironresolve":
			add("castle_armor", 0.20)
		elif pas == "voidecho":
			flag("voidecho")

func _instance(serial: int) -> Dictionary:
	if not tower_ex.has(serial):
		tower_ex[serial] = {"add": {}, "behaviors": [], "add_status": [], "override_kind": ""}
	return tower_ex[serial]

func _inst_add(serial: int, key: String, v: float) -> void:
	var inst = _instance(serial)
	inst.add[key] = inst.add.get(key, 0.0) + v

func _inst_behavior(serial: int, b: String) -> void:
	var inst = _instance(serial)
	if not (b in inst.behaviors):
		inst.behaviors.append(b)

func _apply_give_to(serial: int, give: Dictionary) -> void:
	for key in give:
		var v = give[key]
		if typeof(v) == TYPE_BOOL:
			if v:
				_inst_behavior(serial, key)
		else:
			_inst_add(serial, key, float(v))

func _relics_to_instance(serial: int, id: String, relics: Array) -> void:
	var def = DB.towers.get(id, {})
	# base behaviors from tower definition special flags
	if def.get("hp_cost", 0.0) > 0.0:
		_inst_add(serial, "hp_cost", def.hp_cost)
	if def.get("lifesteal", 0.0) > 0.0:
		_inst_add(serial, "lifesteal", def.lifesteal)
	if def.get("pierce_armor", 0.0) > 0.0:
		_inst_add(serial, "pierce_armor", def.pierce_armor)
	if def.get("vs_tags", []) != []:
		_inst_behavior(serial, "vs_tags")
	for rid in relics:
		for rd in DB.relics:
			if rd.id == rid:
				var give: Dictionary = rd.get("give", {})
				for key in give:
					if key == "add_status":
						_instance(serial).add_status.append(give[key])
					else:
						_inst_add(serial, key, float(give[key]))

func _adjacencies() -> void:
	# precompute relic bonuses for each instance first
	for t in Run.towers:
		_relics_to_instance(t.serial, t.id, t.relics)
	# adjacency detection (4-directional grid neighbors)
	for i in Run.towers.size():
		var a: Dictionary = Run.towers[i]
		for j in range(i + 1, Run.towers.size()):
			var b: Dictionary = Run.towers[j]
			var d = absi(int(a.gx) - int(b.gx)) + absi(int(a.gy) - int(b.gy))
			if d != 1:
				continue
			for rec in DB.adjacencies:
				if (a.id == rec.pair[0] and b.id == rec.pair[1]) or \
				   (a.id == rec.pair[1] and b.id == rec.pair[0]):
					active_adjacencies.append(rec.id)
					_apply_give_to(a.serial, rec.give)
					_apply_give_to(b.serial, rec.give)
					if rec.get("behavior", "") != "":
						_inst_behavior(a.serial, rec.behavior)
						_inst_behavior(b.serial, rec.behavior)

func _ascensions() -> void:
	for asc in DB.ascensions:
		var all_present = true
		for tid in asc.req:
			if not Run.has_tower_type(tid):
				all_present = false
				break
		if not all_present:
			continue
		Run.ascensions[asc.id] = true
		active_ascensions.append(asc.id)
		var focal: String = asc.get("focal", "")
		for t in Run.towers:
			if t.id == focal:
				_instance(t.serial).override_kind = asc.l_.kind

# --- readers ----------------------------------------------------------------

func tower_local(serial: int) -> Dictionary:
	return tower_ex.get(serial, {"add": {}, "behaviors": [], "add_status": [], "override_kind": ""})

func tower_global(serial: int) -> Dictionary:
	## merged view of global + local for an instance
	var ex: Dictionary = tower_ex.get(serial, {"add": {}, "behaviors": [], "add_status": [], "override_kind": ""})
	var out: Dictionary = {"add": {}, "behaviors": [], "add_status": [], "override_kind": ex.override_kind}
	for k in g:
		out.add[k] = g[k]
	for k in ex.add:
		out.add[k] = out.add.get(k, 0.0) + ex.add[k]
	out.behaviors = ex.behaviors.duplicate()
	out.add_status = ex.add_status.duplicate()
	return out
