class_name Enemy
extends Node2D
## A single enemy on the field. Holds its stats and every debuff stack.
## The game controller asks it to tick() each frame and reads its state.

var lane = 0
var xp = 0.0
var hp = 1.0
var max_hp = 1.0
var speed = 50.0
var armor = 0.0
var value = 5.0
var boss = false
var radius = 12.0

# elite affixes (from DB.AFFIXES)
var affixes = []
var elite = false
var adaptive = false
var regen_rate = 0.0
var splitter = false
var mini = false

# debuffs: key -> {pot: float, t: float, stacks: int}
var st = {}

var dead = false
var t = 0.0
var flash = 0.0
var serial = 0

const DOT_BASE = 2.2  # damage per second per potency

func setup(data: Dictionary, l: int) -> void:
	lane = l
	max_hp = data.get("hp", 40.0)
	hp = max_hp
	speed = data.get("speed", 50.0)
	armor = data.get("armor", 0.0)
	value = data.get("gold", 5.0)
	xp = data.get("xp", 6.0)
	boss = data.get("boss", false)
	mini = data.get("mini", false)
	radius = 20.0 if boss else 11.0
	affixes = data.get("affixes", [])
	elite = (not boss) and affixes.size() > 0
	adaptive = data.get("aff_adaptive", false)
	regen_rate = data.get("aff_regen", 0.0)
	splitter = data.get("aff_splitter", false) and not mini
	if data.has("aff_radius") and data["aff_radius"] > 0.0:
		radius = data["aff_radius"]
	position = Vector2(30, 0)

func is_boss() -> bool:
	return boss

func apply_status(id: String, potency: float, dur: float = 2.5) -> void:
	if not st.has(id):
		st[id] = {"pot": 0.0, "t": 0.0, "stacks": 0}
	var e: Dictionary = st[id]
	e["pot"] = max(e["pot"] + potency, 0.0)
	e["t"] = max(e["t"], dur)
	e["stacks"] = int(e.get("stacks", 0)) + 1

func has(id: String) -> bool:
	if st.has(id) and st[id]["t"] > 0.0:
		return true
	return false

func slow_factor() -> float:
	if has("slow"):
		return max(0.25, 1.0 - 0.22 * st["slow"].get("pot", 0.0))
	return 1.0

func is_frozen() -> bool:
	return has("freeze")

func is_rooted() -> bool:
	return has("root")

func effective_armor() -> float:
	var want: Dictionary = st.get("shred", {})
	if want.is_empty():
		return max(0.0, armor)
	return max(0.0, armor - 2.0 * int(want.get("stacks", 0)) * max(want.get("pot", 0.0), 0.5))

func take_hit(dmg: float) -> float:
	var actual = max(0.0, dmg)
	if adaptive:
		actual *= 0.7  # adaptive elites shrug off a third of each hit
	hp -= actual
	flash = 0.12
	if hp <= 0.0 and not dead:
		dead = true
	return actual

func tick(dt: float, dot_mult: float, tick_boost: float, freeze_all: bool) -> void:
	t += dt
	flash = max(0.0, flash - dt)
	# tick debuff timers
	for id in st.keys():
		var e: Dictionary = st[id]
		e["t"] = e.get("t", 0.0) - dt
		if e["t"] <= 0.0:
			st.erase(id)
	# DoTs
	if not dead:
		for id in ["burn", "poison", "bleed"]:
			if st.has(id) and st[id].get("t", 0.0) > 0.0:
				var e: Dictionary = st[id]
				var interval = max(0.25, 0.8 - tick_boost * 0.4)
				var dmg = DOT_BASE * e.get("pot", 0.0) * dot_mult * (dt / interval)
				hp -= dmg
				if hp <= 0.0:
					dead = true
					break
	# regen (regenerating affix)
	if not dead and regen_rate > 0.0:
		hp = min(max_hp, hp + max_hp * regen_rate * dt)
	# movement
	if not dead:
		var mov = speed * slow_factor() * dt
		if freeze_all or is_frozen() or is_rooted():
			mov = 0.0
		position.x += mov

func _draw() -> void:
	var c: Color
	if boss:
		c = Color("#cf4e3f")
	else:
		var pal = [
			Color("#d26d4a"), Color("#6a7f9a"), Color("#7aa06f"),
			Color("#9a6d8c"), Color("#8a7660"), Color("#5c7a84"),
		]
		c = pal[lane % pal.size()]
	if has("slow") or has("freeze") or has("root"):
		c = c.lerp(Color("#59b8ff"), 0.5)
	if has("burn"):
		c = c.lerp(Color("#ff5a3c"), 0.45)
	if has("poison"):
		c = c.lerp(Color("#8ed64a"), 0.4)
	if flash > 0.0:
		c = Color.WHITE
	var r = radius
	draw_circle(Vector2.ZERO, r, c)
	draw_circle(Vector2.ZERO, r - 4.0, c.darkened(0.45))
	draw_arc(Vector2.ZERO, r + (5.0 if boss else 3.0), 0, TAU, 24, Color(c.r, c.g, c.b, 0.35), 2.0)
	var ec = Color("#1a1d24")
	draw_circle(Vector2(-r * 0.3, -r * 0.2), r * 0.16, ec)
	draw_circle(Vector2(r * 0.3, -r * 0.2), r * 0.16, ec)
	if boss:
		draw_arc(Vector2.ZERO, r + 6.0, 0, TAU, 24, Color("#ffb84a"), 2.0)
	if elite:
		draw_arc(Vector2.ZERO, r + 8.0, 0, TAU, 28, Color(1.0, 0.84, 0.4), 2.5)
		for i in affixes.size():
			var a = TAU * float(i) / float(max(affixes.size(), 1))
			var dot = Vector2(cos(a), sin(a)) * (r + 11.0)
			draw_circle(dot, 2.4, Color("#ffe08a"))
	var w = r * 2.2
	var frac = clamp(hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(-w / 2, -r - 9, w, 3), Color(0, 0, 0, 0.6))
	var fc = Color("#7ff58a") if frac > 0.35 else Color("#ff6b6b")
	draw_rect(Rect2(-w / 2, -r - 9, w * frac, 3), fc)
