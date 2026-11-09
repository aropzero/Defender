class_name TowerNode
extends Node2D
## Visual representation of a placed tower. Game logic lives in the controller.

var type_id = ""
var def_data = {}
var level = 1
var grid_x = 0
var grid_y = 0
var ser = 0
var pulse = 0.0

func setup(d: Dictionary, inst: Dictionary) -> void:
	type_id = inst.get("id", "")
	def_data = d
	level = int(inst.get("level", 1))
	grid_x = int(inst.get("gx", 0))
	grid_y = int(inst.get("gy", 0))
	ser = int(inst.get("serial", 0))
	position = inst.get("world_pos", Vector2.ZERO)
	queue_redraw()

func level_up(to: int) -> void:
	level = to
	queue_redraw()

func _draw() -> void:
	var shape: String = def_data.get("shape", "turret")
	var col: Color = def_data.get("color", Color.GRAY)
	var s = 1.0 + 0.06 * float(level - 1)
	match shape:
		"turret":
			_draw_turret(col, s)
		"spire":
			_draw_spire(col, s)
		"ward":
			_draw_ward(col, s)
		"monolith":
			_draw_monolith(col, s)
		"vat":
			_draw_vat(col, s)
		"font":
			_draw_font(col, s)
		"loop":
			_draw_loop(col, s)
		"ballista":
			_draw_ballista(col, s)
		"gate":
			_draw_gate(col, s)
		_:
			_draw_turret(col, s)
	# faint arcane aura ring
	draw_arc(Vector2.ZERO, 21 * s, 0, TAU, 32, Color(col.r, col.g, col.b, 0.4), 2.0)
	var n = 16
	var i = 0
	while i < level:
		var a = TAU * float(i) / float(n)
		draw_circle(Vector2(cos(a) * 30, sin(a) * 30), 2.2, Color("#fff0a8"))
		i += 1

func _draw_turret(c: Color, s: float) -> void:
	draw_circle(Vector2.ZERO, 15 * s, c.darkened(0.35))
	draw_circle(Vector2.ZERO, 11 * s, c)
	draw_rect(Rect2(-3 * s, -26 * s, 6 * s, 12 * s), Color("#d8d8e4"))
	draw_circle(Vector2(0, -26 * s), 3 * s, Color("#ff8a5c"))

func _draw_spire(c: Color, s: float) -> void:
	draw_circle(Vector2.ZERO, 13 * s, c.darkened(0.3))
	var pts = PackedVector2Array([
		Vector2(-9 * s, 8 * s), Vector2(9 * s, 8 * s), Vector2(0, -24 * s)])
	draw_colored_polygon(pts, c)
	draw_circle(Vector2(0, -24 * s), 3.5 * s, Color.WHITE)

func _draw_ward(c: Color, s: float) -> void:
	draw_circle(Vector2.ZERO, 13 * s, c.darkened(0.3))
	draw_rect(Rect2(-7 * s, -20 * s, 14 * s, 34 * s), c)
	draw_rect(Rect2(-4 * s, -26 * s, 8 * s, 6 * s), Color("#cfcfe0"))

func _draw_monolith(c: Color, s: float) -> void:
	var pts = PackedVector2Array([
		Vector2(-14 * s, 22 * s), Vector2(-6 * s, -18 * s),
		Vector2(6 * s, -18 * s), Vector2(14 * s, 22 * s)])
	draw_colored_polygon(pts, c.darkened(0.2))
	var tip = PackedVector2Array([
		Vector2(-6 * s, -18 * s), Vector2(6 * s, -18 * s), Vector2(0, -28 * s)])
	draw_colored_polygon(tip, c)
	draw_circle(Vector2(0, 2 * s), 4 * s, Color("#dcdcff"))

func _draw_vat(c: Color, s: float) -> void:
	draw_rect(Rect2(-13 * s, -20 * s, 26 * s, 30 * s), c.darkened(0.35))
	draw_rect(Rect2(-11 * s, -16 * s, 22 * s, 22 * s), Color("#3c3c44"))
	draw_rect(Rect2(-9 * s, -13 * s, 18 * s, 16 * s), c)

func _draw_font(c: Color, s: float) -> void:
	draw_circle(Vector2.ZERO, 14 * s, c.darkened(0.3))
	draw_circle(Vector2.ZERO, 9 * s, c)
	draw_circle(Vector2.ZERO, 4 * s, Color("#ffd0dc"))

func _draw_loop(c: Color, s: float) -> void:
	draw_arc(Vector2.ZERO, 15 * s, 0, TAU, 32, c, 3.0)
	draw_arc(Vector2.ZERO, 8 * s, 0, TAU, 24, c.darkened(0.2), 2.0)
	draw_circle(Vector2(0, 2 * s), 3 * s, Color("#eafffa"))

func _draw_ballista(c: Color, s: float) -> void:
	draw_circle(Vector2.ZERO, 13 * s, c.darkened(0.35))
	draw_rect(Rect2(-16 * s, -4 * s, 32 * s, 6 * s), Color("#9a9ab0"))
	draw_rect(Rect2(-2 * s, -10 * s, 6 * s, 18 * s), Color("#6a6a82"))

func _draw_gate(c: Color, s: float) -> void:
	draw_circle(Vector2.ZERO, 14 * s, c.darkened(0.3))
	draw_arc(Vector2.ZERO, 10 * s, 0, TAU, 24, c, 3.0)
	draw_circle(Vector2.ZERO, 3 * s, Color("#202033"))
