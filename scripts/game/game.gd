extends Node
## ---------------------------------------------------------------------------
## Master controller for a single run. Owns the world (enemies, towers,
## effects) and the UI (built procedurally). Orchestrates waves, combat,
## economy, leveling and the synergy refresh.
## ---------------------------------------------------------------------------

const LANES = 6
const SLOT_COLS = [660, 780, 900, 1020]
const CASTLE_X = 1165.0

var _world: Node2D
var _ui: Control
var _phase = "menu"

var lane_ys = []
var slot_pos = {}      # "gx,gy" -> Vector2

# combat state
var enemies = []
var tower_nodes = {}   # serial -> {node, def}
var _cd = {}           # serial -> remaining seconds
var run_enemy_serial = 0
var fx = []            # effect list for world drawing
var spawn_queue = []
var spawn_timer = 0.0
var win = false

# skills
var _skill_cd = {}

# ui refs (created per phase)
var _menu_panel: Control
var _topbar: Control
var _skillbar: Control
var _synergy_panel: Control
var _popup: Control
var _card_panel: Control
var _attr_panel: Control

# placeholders for stat bars
var _hp_txt: Label
var _hp_bar: ColorRect
var _gold_txt: Label
var _wave_txt: Label
var _kills_txt: Label
var _lvl_txt: Label
var _synergy_txt: Label
var _msg_lbl: Label
var _msg_timer = 0.0

# onboarding / guide
var _hint_lbl: Button
var _hint_dismissed = false
var _how_panel: Control
var _how_body: Label
var _how_slide = 0

# --------------------------------------------------------------------------
# AAA theme — an Earth battlefield at golden hour: bright sky, grass, dirt,
# sandstone keep. UI is warm parchment for readability on any screen.
# --------------------------------------------------------------------------
const CLR_BG = Color("#bfd6e8")
const CLR_PANEL = Color(0.97, 0.94, 0.87, 0.96)
const CLR_PANEL_HI = Color(1.0, 0.97, 0.91, 0.98)
const CLR_PANEL_DN = Color(0.90, 0.85, 0.76, 0.97)
const CLR_BORDER = Color("#7a3b2e")
const CLR_BORDER_HI = Color("#9c4f3a")
const CLR_GOLD = Color("#b8862e")
const CLR_TXT = Color("#2a211a")
const CLR_TXT_DIM = Color(0.35, 0.30, 0.26, 0.85)

var _vs = Vector2(1280, 720)
var _scale = 1.0
var _origin = Vector2.ZERO
var _field = Rect2(0, 0, 1280, 720)
var _bg: Control

func _sb(fill: Color, border: Color, w: int, r: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(w)
	sb.set_corner_radius_all(r)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	return sb

func _skin(n: Node) -> void:
	if n is Button:
		var b: Button = n
		b.add_theme_stylebox_override("normal", _sb(CLR_PANEL, CLR_BORDER, 1, 4))
		b.add_theme_stylebox_override("hover", _sb(CLR_PANEL_HI, CLR_BORDER_HI, 2, 4))
		b.add_theme_stylebox_override("pressed", _sb(CLR_PANEL_DN, CLR_GOLD, 2, 4))
		b.add_theme_stylebox_override("disabled", _sb(Color(0.78, 0.75, 0.70, 0.8), Color(0.55, 0.52, 0.48, 0.7), 1, 4))
		b.add_theme_color_override("font_color", CLR_TXT)
		b.add_theme_color_override("font_hover_color", Color("#0f0a07"))
		b.add_theme_color_override("font_pressed_color", Color("#5a3a12"))
		b.add_theme_color_override("font_disabled_color", Color(0.42, 0.39, 0.34, 0.7))
	elif n is PanelContainer:
		n.add_theme_stylebox_override("panel", _sb(CLR_PANEL, CLR_BORDER, 2, 10))
	elif n is Label:
		if not n.has_theme_color_override("font_color"):
			n.add_theme_color_override("font_color", CLR_TXT)
	for c in n.get_children():
		_skin(c)

func _title(l: Label, size: int) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", CLR_GOLD)
	l.add_theme_color_override("font_shadow_color", Color(0.25, 0.16, 0.06, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)

# --------------------------------------------------------------------------
# Responsive full-screen layout: the battle field is kept at its 1280x720
# design aspect and centered; the rest of the screen is filled with gothic
# atmosphere so there are never black bars, in any orientation.
# --------------------------------------------------------------------------
func _build_atmosphere() -> void:
	_bg = Control.new()
	_bg.name = "_bg"
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_bg)
	# Sky: warm daylit gradient (upper sky -> warm horizon).
	var sky := TextureRect.new()
	var skytex := GradientTexture2D.new()
	skytex.gradient = Gradient.new()
	skytex.gradient.set_color(0, Color("#7fa6c9"))
	skytex.gradient.set_color(1, Color("#e6c98f"))
	skytex.fill_from = Vector2(0.5, 0.0)
	skytex.fill_to = Vector2(0.5, 1.0)
	skytex.fill = GradientTexture2D.FILL_LINEAR
	sky.texture = skytex
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.add_child(sky)
	# Warm ground haze along the bottom (reads as earth, not void).
	var ground := ColorRect.new()
	ground.color = Color(0.55, 0.42, 0.26, 0.28)
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.add_child(ground)
	# Light dust motes drifting in the sun (replaces the black embers).
	var motes := CPUParticles2D.new()
	motes.amount = 70
	motes.lifetime = 8.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(760, 420)
	motes.position = Vector2(640, 320)
	motes.direction = Vector2(0, -1)
	motes.spread = 40
	motes.gravity = Vector2(0, -6)
	motes.initial_velocity_min = 4
	motes.initial_velocity_max = 24
	motes.scale_amount_min = 0.6
	motes.scale_amount_max = 2.0
	motes.color = Color(1.0, 0.88, 0.6, 0.22)
	var mramp := Gradient.new()
	mramp.set_color(0, Color(1.0, 0.9, 0.65, 0.35))
	mramp.set_color(1, Color(0.9, 0.75, 0.5, 0.0))
	motes.color_ramp = mramp
	_bg.add_child(motes)

func _relayout() -> void:
	var vs := get_viewport().get_visible_rect().size
	if vs.x <= 0.0 or vs.y <= 0.0:
		vs = Vector2(1280, 720)
	_vs = vs
	_scale = min(vs.x / 1280.0, vs.y / 720.0)
	var fw: float = 1280.0 * _scale
	var fh: float = 720.0 * _scale
	_origin = Vector2((vs.x - fw) * 0.5, (vs.y - fh) * 0.5)
	_field = Rect2(_origin, Vector2(fw, fh))
	if is_instance_valid(_world):
		_world.position = _origin
		_world.scale = Vector2(_scale, _scale)
	_refresh_hud_layout()

func _to_world(pos: Vector2) -> Vector2:
	return (pos - _origin) / _scale

func _refresh_hud_layout() -> void:
	var portrait = _vs.y > _vs.x * 1.1
	if is_instance_valid(_topbar):
		_topbar.position = Vector2(10, 10)
		_topbar.size = Vector2(_vs.x - 20, 64 if not portrait else 80)
	var tb_h = 64.0
	if is_instance_valid(_topbar):
		tb_h = _topbar.size.y
	if is_instance_valid(_msg_lbl):
		_msg_lbl.position = Vector2(20, tb_h + 20)
		_msg_lbl.size = Vector2(_vs.x * 0.62, 22)
	if is_instance_valid(_skillbar):
		if portrait:
			_skillbar.position = Vector2(12, _vs.y - 86)
			_skillbar.size = Vector2(_vs.x - 24, 76)
		else:
			_skillbar.position = Vector2(_vs.x * 0.22, _vs.y - 86)
			_skillbar.size = Vector2(_vs.x * 0.56, 76)
	if is_instance_valid(_synergy_panel):
		if portrait:
			_synergy_panel.position = Vector2(_vs.x * 0.5 - 120, tb_h + 48)
			_synergy_panel.size = Vector2(240, min(340.0, _vs.y * 0.38))
		else:
			_synergy_panel.position = Vector2(_vs.x * 0.70, 90)
			_synergy_panel.size = Vector2(_vs.x * 0.29, max(120.0, _vs.y - 205))
	if is_instance_valid(_hint_lbl):
		var hw = min(660.0, _vs.x * 0.92)
		_hint_lbl.size = Vector2(hw, 44)
		_hint_lbl.position = Vector2((_vs.x - hw) * 0.5, _vs.y - 132)

func _center_modal(p: Control, w: float, h: float) -> void:
	p.position = Vector2((_vs.x - w) * 0.5, (_vs.y - h) * 0.5)
	p.size = Vector2(w, h)

func _ready() -> void:
	_world = Node2D.new()
	_world.name = "World"
	_world.draw.connect(_world_draw_callback)
	add_child(_world)
	_ui = Control.new()
	_ui.name = "UI"
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_ui)
	_build_atmosphere()
	_build_field_geometry()
	_relayout()
	_show_main_menu()
	get_tree().root.size_changed.connect(_relayout)

# ---------------------------------------------------------------- geometry

func _build_field_geometry() -> void:
	lane_ys.clear()
	for i in LANES:
		lane_ys.append(70 + i * (540.0 / float(LANES - 1)))
	for gx in SLOT_COLS.size():
		for gy in LANES:
			slot_pos["%d,%d" % [gx, gy]] = Vector2(SLOT_COLS[gx], lane_ys[gy])

# ------------------------------------------------------------------ menu

func _show_main_menu() -> void:
	_phase = "menu"
	_clear_ui()
	var vw = _vs.x
	var vh = _vs.y
	var portrait = vh > vw * 1.05
	var px = vw * 0.5

	var root = Control.new()
	root.name = "MenuRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(root)

	# Ambient glow behind the title (claim the screen, not a card).
	var glow = ColorRect.new()
	glow.color = Color(0.85, 0.18, 0.10, 0.05)
	glow.size = Vector2(min(760.0, vw * 0.85), 300)
	glow.position = Vector2(px - glow.size.x * 0.5, vh * (0.10 if not portrait else 0.06))
	root.add_child(glow)

	# Title — big, cinematic, two-line lockup.
	var title = Label.new()
	title.text = "CITADEL\nOF ECHOES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size = Vector2(min(860.0, vw * 0.94), 190)
	title.position = Vector2(px - title.size.x * 0.5, vh * (0.10 if not portrait else 0.06))
	_title(title, 48)
	title.add_theme_color_override("font_shadow_color", Color(0.78, 0.12, 0.08, 0.9))
	root.add_child(title)

	# Subtitle tagline.
	var band = Label.new()
	band.text = "ROGUELITE TOWER DEFENSE   ·   COMBINE 12 ESSENCES TO INVENT YOUR ARSENAL"
	band.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	band.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	band.size = Vector2(min(720.0, vw * 0.92), 64)
	band.position = Vector2(px - band.size.x * 0.5, title.position.y + title.size.y + 6)
	band.add_theme_font_size_override("font_size", 15)
	band.add_theme_color_override("font_color", CLR_TXT_DIM)
	band.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	root.add_child(band)

	# Meta chip.
	var chip = Label.new()
	chip.text = "ESSENCE SHARDS: %d     BEST WAVE: %d" % [Meta.shards, Meta.best_wave]
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.size = Vector2(min(560.0, vw * 0.94), 26)
	chip.position = Vector2(px - chip.size.x * 0.5, band.position.y + band.size.y + 6)
	chip.add_theme_font_size_override("font_size", 14)
	chip.add_theme_color_override("font_color", CLR_GOLD)
	root.add_child(chip)

	# Primary actions.
	var bw = min(430.0, vw * 0.82)
	var bh = 58
	var sep = 14
	var by = vh * (0.66 if not portrait else 0.62)

	var btn_start = Button.new()
	btn_start.text = "START A NEW RUN"
	btn_start.size = Vector2(bw, bh)
	btn_start.position = Vector2(px - bw * 0.5, by)
	btn_start.pressed.connect(_start_run)
	root.add_child(btn_start)

	var btn_meta = Button.new()
	btn_meta.text = "META PROGRESSION STORE"
	btn_meta.size = Vector2(bw, bh)
	btn_meta.position = Vector2(px - bw * 0.5, by + bh + sep)
	btn_meta.pressed.connect(_show_meta)
	root.add_child(btn_meta)

	var btn_how = Button.new()
	btn_how.text = "HOW TO PLAY"
	btn_how.size = Vector2(bw, bh)
	btn_how.position = Vector2(px - bw * 0.5, by + (bh + sep) * 2)
	btn_how.pressed.connect(func(): _show_howto())
	root.add_child(btn_how)

	# Footer.
	var foot = Label.new()
	foot.text = "CITADEL OF ECHOES  ·  v%s" % ProjectSettings.get_setting("application/config/version", "1.1.0")
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.size = Vector2(vw, 22)
	foot.position = Vector2(0, vh - 40)
	foot.add_theme_font_size_override("font_size", 12)
	foot.add_theme_color_override("font_color", Color(0.5, 0.42, 0.34, 0.7))
	root.add_child(foot)

	_skin(root)

func _show_meta() -> void:
	_clear_ui()
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-340, -240)
	panel.size = Vector2(680, 480)
	_skin(panel)
	_ui.add_child(panel)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var t = Label.new()
	t.text = "META PROGRESSION  —  Shards: %d" % Meta.shards
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title(t, 24)
	vb.add_child(t)
	for u in Meta.UNLOCKS:
		var btn = Button.new()
		if Meta.has_unlock(u.id):
			btn.text = "[OWNED] %s — %s" % [u.name, u.desc]
			btn.disabled = true
		else:
			btn.text = "%s — %s  (%d shards)" % [u.name, u.desc, u.cost]
			btn.pressed.connect(_buy_meta.bind(u.id, u.cost))
		vb.add_child(btn)
	var back = Button.new()
	back.text = "Back"
	back.pressed.connect(_show_main_menu)
	vb.add_child(back)
	_skin(panel)

func _buy_meta(id: String, cost: int) -> void:
	if Meta.unlock(id, cost):
		_show_meta()
	else:
		_message("Not enough shards.")

# ------------------------------------------------------------- how-to-play
var _HOW_SLIDES = [
	"STEP 1 — BUILD\n\nTap any glowing circle on the battlefield to open your armory.\nChoose a tower — it unlocks there and fires automatically at any enemy that gets close.",
	"STEP 2 — SYNERGY\n\nEvery tower carries one of twelve elemental essences.\nBuild towers sharing essences to earn RESONANCES (global auras).\nPlace specific tower types beside each other to trigger FUSIONS.\nCollect trifectas of tower types to ASCEND one into a legendary form.",
	"STEP 3 — WAVES & SKILLS\n\nPress START WAVE to send the horde. Use your skills from the bar at the bottom of the screen.\nEarn XP to level up, spend attribute points, choose Keystone perks,\nand equip relics on your towers. Survive as many waves as you can.",
]

func _show_howto() -> void:
	if _phase in ["combat", "reward", "levelup"]:
		return
	_close_popup()
	_how_slide = 0
	if is_instance_valid(_how_panel):
		_how_panel.queue_free()
	var panel = PanelContainer.new()
	panel.name = "HowTo"
	panel.position = Vector2(_vs.x * 0.5 - 340, _vs.y * 0.5 - 240)
	panel.size = Vector2(680, 480)
	_skin(panel)
	_ui.add_child(panel)
	_how_panel = panel
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	var t = Label.new()
	t.text = "HOW TO PLAY"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title(t, 26)
	vb.add_child(t)
	var body = Label.new()
	body.name = "HowBody"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(620, 280)
	vb.add_child(body)
	_how_body = body
	_refresh_how_body()
	var nav = HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 12)
	vb.add_child(nav)
	var back = Button.new()
	back.text = "‹ Back"
	back.pressed.connect(func():
		_how_slide = max(0, _how_slide - 1)
		_refresh_how_body())
	nav.add_child(back)
	var next = Button.new()
	next.text = "Next ›"
	next.pressed.connect(func():
		if _how_slide >= _HOW_SLIDES.size() - 1:
			_close_howto()
			return
		_how_slide += 1
		_refresh_how_body())
	nav.add_child(next)
	var done = Button.new()
	done.text = "Close"
	done.pressed.connect(_close_howto)
	nav.add_child(done)
	_skin(panel)

func _refresh_how_body() -> void:
	if is_instance_valid(_how_body):
		_how_body.text = _HOW_SLIDES[_how_slide]

func _close_howto() -> void:
	if is_instance_valid(_how_panel):
		_how_panel.queue_free()
	_how_panel = null

# ------------------------------------------------------------------ run start

func _start_run() -> void:
	Run.reset()
	_hint_dismissed = false
	# apply meta boons
	if Meta.has_unlock("u_gold"):
		Run.gold += 100.0
	if Meta.has_unlock("u_slot"):
		pass  # extra slot handled via equipped capacity
	if Meta.has_unlock("u_attr"):
		Run.player.attr["might"] += 1
		Run.player.attr["swiftness"] += 1
	if Meta.has_unlock("u_cp"):
		Run.castle.max_hp += 60.0
		Run.castle.hp = Run.castle.max_hp
	if Meta.has_unlock("u_relic"):
		_meta_relic_start()
	win = false
	enemies.clear()
	tower_nodes.clear()
	_cd.clear()
	fx.clear()
	spawn_queue.clear()
	_phase = "build"
	_build_ui()
	Synergy.refresh()
	_update_ui()
	_message("Spend gold on towers, then press Start Wave.")

func _meta_relic_start() -> void:
	if Run.towers.size() == 0:
		return
	var t: Dictionary = Run.towers[randi() % Run.towers.size()]
	t.relics.append(DB.relics[randi() % DB.relics.size()].id)

# --------------------------------------------------------------- field / world draw

func _draw_world() -> void:
	if not is_instance_valid(_world):
		return
	_world.queue_redraw()

func _world_draw() -> void:
	var w = _world
	# field base — grass
	w.draw_rect(Rect2(20, 40, 1240, 560), Color("#6f9456"), true)
	# alternate lane ribbons — mown grass bands
	for i in LANES:
		if i % 2 == 0:
			continue
		var y0 = (lane_ys[i - 1] + lane_ys[i]) * 0.5 if i > 0 else 40.0
		var y1 = (lane_ys[i] + lane_ys[i + 1]) * 0.5 if i < LANES - 1 else 600.0
		w.draw_rect(Rect2(20, y0, 1240, y1 - y0), Color("#5f8550"), true)
	# lane guide lines — dirt path
	for i in LANES:
		var y = lane_ys[i]
		w.draw_line(Vector2(20, y), Vector2(CASTLE_X + 50, y), Color("#b39060"), 3)
	# build sockets (empties) — sun-bleached stone pads
	for key in slot_pos:
		var p: Vector2 = slot_pos[key]
		if Run.tower_at(int(key.split(",")[0]), int(key.split(",")[1])).is_empty():
			w.draw_circle(p, 18, Color("#d8cba4"))
			w.draw_arc(p, 18, 0, TAU, 26, Color("#6b5a3a"), 3)
			w.draw_line(p + Vector2(-8, 0), p + Vector2(8, 0), Color("#6b5a3a"), 3)
			w.draw_line(p + Vector2(0, -8), p + Vector2(0, 8), Color("#6b5a3a"), 3)
	# castle keep — sandstone with red banners
	var cx = CASTLE_X - 10
	w.draw_rect(Rect2(cx, 40, 72, 560), Color("#c9b089"), true)
	w.draw_rect(Rect2(cx + 4, 48, 64, 12), Color("#a98f6a"), true)
	for i in range(6):
		var bxp = cx + 2 + i * 12
		w.draw_rect(Rect2(bxp, 40, 8, 20), Color("#b39a72"), true)
		w.draw_rect(Rect2(bxp + 1, 40, 6, 6), Color("#8e3b3b"), true)
	# gate
	w.draw_rect(Rect2(cx + 18, 330, 36, 270), Color("#4a3626"), true)
	w.draw_arc(Vector2(cx + 36, 330), 18, PI, TAU, 24, Color("#4a3626"), 20)
	# warm torch glow bleeding from the gate
	for i in range(12):
		var a = 0.02 * (i + 1)
		w.draw_arc(Vector2(cx + 60, 360), 26 + i * 13, PI * 0.5, PI * 1.5, 28, Color(1.0, 0.62, 0.25, a), 8.0)
	# beacon
	w.draw_circle(Vector2(cx + 82, 120), 6, Color("#ffd24a"))
	w.draw_arc(Vector2(cx + 82, 120), 10, 0, TAU, 20, Color(1.0, 0.8, 0.3, 0.4), 2)
	# distant hills along the horizon (soft blue-green, Earth not void)
	var shapes = [24, 40, 16, 34, 22]
	for i in shapes.size():
		var rx = 60 + i * 240
		var rh = shapes[i]
		var pts = PackedVector2Array([
			Vector2(rx, 40), Vector2(rx + 14, 40), Vector2(rx + 8, 40 - rh)])
		w.draw_colored_polygon(pts, Color("#8ba06b"))
	# fx
	for f in fx:
		match f.kind:
			"shot":
				w.draw_line(f.from, f.to, f.color, f.w)
			"ring":
				w.draw_arc(f.pos, f.r, 0, TAU, 32, f.color, 3.0)
			"impact":
				w.draw_circle(f.pos, f.r, Color(1, 1, 1, f.a))

func _world_process(dt: float) -> void:
	# decay fx
	for f in fx:
		f.t -= dt
	fx = fx.filter(func(f): return f.t > 0.0)

# ------------------------------------------------------------------ UI build

func _build_ui() -> void:
	_clear_ui()
	# top bar
	_topbar = PanelContainer.new()
	_topbar.position = Vector2(8, 8)
	_topbar.size = Vector2(1264, 64)
	_ui.add_child(_topbar)
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	_topbar.add_child(hb)
	_hp_bar = ColorRect.new()
	_hp_bar.custom_minimum_size = Vector2(180, 18)
	hb.add_child(_hp_bar)
	_hp_txt = Label.new()
	hb.add_child(_hp_txt)
	_gold_txt = Label.new()
	_gold_txt.add_theme_font_size_override("font_size", 17)
	hb.add_child(_gold_txt)
	_wave_txt = Label.new()
	hb.add_child(_wave_txt)
	_kills_txt = Label.new()
	hb.add_child(_kills_txt)
	_lvl_txt = Label.new()
	hb.add_child(_lvl_txt)
	var startb = Button.new()
	startb.text = "Start Wave " + str(Run.wave)
	startb.pressed.connect(_begin_wave)
	startb.name = "StartWaveBtn"
	hb.add_child(startb)
	var quitb = Button.new()
	quitb.text = "Abandon Run"
	quitb.pressed.connect(_end_run)
	hb.add_child(quitb)

	# synergy panel (right side)
	_synergy_panel = PanelContainer.new()
	_synergy_panel.position = Vector2(900, 78)
	_synergy_panel.size = Vector2(372, 0)
	_ui.add_child(_synergy_panel)
	var sb = VBoxContainer.new()
	_synergy_panel.add_child(sb)
	_synergy_txt = Label.new()
	_synergy_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_synergy_txt.custom_minimum_size = Vector2(360, 0)
	_synergy_txt.add_theme_font_size_override("font_size", 13)
	sb.add_child(_synergy_txt)

	# skills bar
	_skillbar = HBoxContainer.new()
	_skillbar.position = Vector2(20, 640)
	_skillbar.size = Vector2(1240, 70)
	_ui.add_child(_skillbar)
	_build_skillbar()

	# message label
	_msg_lbl = Label.new()
	_msg_lbl.position = Vector2(20, 620)
	_msg_lbl.size = Vector2(800, 20)
	_msg_lbl.add_theme_font_size_override("font_size", 15)
	_msg_lbl.add_theme_color_override("font_color", Color("#3a2a14"))
	_msg_lbl.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.6))
	_msg_lbl.add_theme_constant_override("shadow_offset_x", 1)
	_msg_lbl.add_theme_constant_override("shadow_offset_y", 1)
	_ui.add_child(_msg_lbl)
	# guide hint (tap to dismiss) — light parchment pill, dark text
	_hint_lbl = Button.new()
	_hint_lbl.name = "Hint"
	_hint_lbl.add_theme_font_size_override("font_size", 16)
	_hint_lbl.add_theme_color_override("font_color", Color("#2f2114"))
	_hint_lbl.add_theme_color_override("font_hover_color", Color("#160e08"))
	var hint_sb := _sb(Color(0.97, 0.94, 0.87, 0.92), Color("#8e3b3b"), 2, 20)
	_hint_lbl.add_theme_stylebox_override("normal", hint_sb)
	_hint_lbl.add_theme_stylebox_override("hover", hint_sb)
	_hint_lbl.add_theme_stylebox_override("pressed", hint_sb)
	_hint_lbl.add_theme_stylebox_override("focus", hint_sb)
	_hint_lbl.pressed.connect(func(): _hint_dismissed = true; _update_hint())
	_ui.add_child(_hint_lbl)
	_skin(_topbar)
	_skin(_synergy_panel)
	_skin(_skillbar)
	_refresh_hud_layout()
	_update_ui()

func _build_skillbar() -> void:
	for c in _skillbar.get_children():
		c.queue_free()
	var cap = 5 + (1 if Meta.has_unlock("u_slot") else 0)
	for i in cap:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(120, 60)
		if i < Run.skills_equipped.size():
			var sid: String = Run.skills_equipped[i]
			var sd: Dictionary = DB.skills.get(sid, {})
			var rank = Run.skill_rank(sid)
			btn.text = "%s\n[%d]" % [sd.get("name", sid), rank]
			btn.pressed.connect(_cast_skill.bind(sid))
		else:
			btn.text = "[ empty ]"
			btn.disabled = true
		btn.name = "Skill_%d" % i
		_skillbar.add_child(btn)
	_skin(_skillbar)

func _update_ui() -> void:
	if _phase in ["menu", "meta", "gameover"]:
		return
	_update_hint()
	if is_instance_valid(_hp_bar):
		var frac = clamp(Run.castle.hp / max(Run.castle.max_hp, 0.1), 0.0, 1.0)
		_hp_bar.color = Color(1, 0.25, 0.25).lerp(Color(0.2, 1, 0.4), frac)
		_hp_txt.text = "Castle %d/%d" % [int(Run.castle.hp), int(Run.castle.max_hp)]
		_gold_txt.text = "Gold %d" % int(Run.gold)
		_wave_txt.text = "Wave %d" % Run.wave
		_kills_txt.text = "Kills %d" % Run.kills
		_lvl_txt.text = "Lv %d" % Run.player.level
	if is_instance_valid(_synergy_txt):
		_synergy_txt.text = _synergy_summary()

func _update_hint() -> void:
	if not is_instance_valid(_hint_lbl):
		return
	if _hint_dismissed:
		_hint_lbl.text = ""
		return
	var txt = ""
	if _phase == "build":
		if Run.towers.size() == 0:
			txt = "①  TAP A CIRCLE on the field to build your first tower   ✕"
		else:
			txt = "②  PRESS “START WAVE” when your defenses are ready   ✕"
	elif _phase == "combat" and Run.skills_equipped.size() > 0:
		txt = "③  TAP A SKILL (bottom bar) to cast it in the fight   ✕"
	_hint_lbl.text = txt

func _synergy_summary() -> String:
	var lines = ["ACTIVE SYNERGIES"]
	var flags_active = 0
	for rid in Synergy.active_resonances:
		for r in DB.resonances:
			if r.id == rid:
				lines.append("• " + r.name + ": " + r.desc)
				flags_active += 1
				break
	for aid in Synergy.active_adjacencies:
		for a in DB.adjacencies:
			if a.id == aid:
				lines.append("• Fusion: " + a.desc)
				flags_active += 1
				break
	for ascid in Synergy.active_ascensions:
		for a in DB.ascensions:
			if a.id == ascid:
				lines.append("★ ASCENDED: " + a.name + " — " + a.desc)
				flags_active += 1
				break
	if flags_active == 0:
		lines.append("None yet. Build towers sharing elements to\ndiscover Resonances; put specific towers next\nto each other for Fusions.")
	return "\n".join(lines)

func _message(txt: String) -> void:
	if is_instance_valid(_msg_lbl):
		_msg_lbl.text = txt
	_msg_timer = 3.0

# ------------------------------------------------------------ input handling

func _unhandled_input(event: InputEvent) -> void:
	if _phase in ["menu", "meta", "gameover", "reward", "levelup"]:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_handle_click(event.position)

func _handle_click(pos: Vector2) -> void:
	# close popups if clicking elsewhere
	if _popup != null and is_instance_valid(_popup) and not _popup.get_global_rect().has_point(pos):
		_close_popup()
		return
	var wp := _to_world(pos)
	# hit test towers
	for ser in tower_nodes.keys():
		var node: Node2D = tower_nodes[ser].node
		if node.position.distance_to(wp) < 26:
			_open_tower_panel(ser)
			return
	# hit test slots
	for key in slot_pos:
		var p: Vector2 = slot_pos[key]
		if p.distance_to(wp) < 22:
			if Run.tower_at(int(key.split(",")[0]), int(key.split(",")[1])).is_empty():
				_open_build_menu(int(key.split(",")[0]), int(key.split(",")[1]))
			return

func _close_popup() -> void:
	if _popup != null and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null

# ------------------------------------------------------------- build menu

func _open_build_menu(gx: int, gy: int) -> void:
	_close_popup()
	var panel = PanelContainer.new()
	panel.name = "BuildMenu"
	panel.position = _ui.get_local_mouse_position() + Vector2(14, 10)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	panel.add_child(vb)
	var cap = Label.new()
	cap.text = "Build (%d,%d)" % [gx, gy]
	cap.add_theme_font_size_override("font_size", 16)
	vb.add_child(cap)
	for id in DB.towers.keys():
		var td: Dictionary = DB.towers[id]
		var afford = Run.gold >= td.cost
		var btn = Button.new()
		var e = Elements.name_of(td.element)
		btn.text = "%s  (%s)  — %dg  Lv1" % [td.name, e, int(td.cost)]
		btn.tooltip_text = td.desc
		btn.disabled = not afford
		btn.pressed.connect(_place_tower.bind(id, gx, gy))
		vb.add_child(btn)
	var sell_close = Button.new()
	sell_close.text = "Cancel"
	sell_close.pressed.connect(_close_popup)
	vb.add_child(sell_close)
	_popup = panel
	_skin(panel)
	_ui.add_child(panel)

func _place_tower(id: String, gx: int, gy: int) -> void:
	var td: Dictionary = DB.towers[id]
	if Run.gold < td.cost:
		return
	if not Run.tower_at(gx, gy).is_empty():
		return
	Run.gold -= td.cost
	var inst = Run.add_tower(id, gx, gy)
	inst.world_pos = slot_pos["%d,%d" % [gx, gy]]
	var node = TowerNode.new()
	node.setup(td, inst)
	_world.add_child(node)
	tower_nodes[inst.serial] = {"node": node, "def": td, "inst": inst}
	_cd[inst.serial] = 0.0
	_close_popup()
	Synergy.refresh()
	_update_ui()
	_draw_world()

func _open_tower_panel(ser: int) -> void:
	var entry = tower_nodes.get(ser)
	if entry == null:
		return
	var td: Dictionary = entry.def
	var inst: Dictionary = entry.inst
	_close_popup()
	var panel = PanelContainer.new()
	panel.name = "TowerPanel"
	panel.position = _ui.get_local_mouse_position() + Vector2(14, 10)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)
	var cap = Label.new()
	cap.text = "%s  Lv%d" % [td.name, inst.level]
	cap.add_theme_font_size_override("font_size", 16)
	vb.add_child(cap)
	var info = Label.new()
	info.text = td.desc
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(300, 0)
	vb.add_child(info)
	var b = Label.new()
	var dd: Dictionary = td.base
	b.text = "Dmg %.0f | Range %.0f | Rate %.2f | Crit %d%%" % [dd.damage, dd.range, dd.rate, int(dd.crit * 100)]
	vb.add_child(b)
	if inst.relics.size() > 0:
		var rel = Label.new()
		var names = []
		for rid in inst.relics:
			for rd in DB.relics:
				if rd.id == rid:
					names.append(rd.name)
		rel.text = "Relics: " + ", ".join(names)
		vb.add_child(rel)
	# upgrade
	var up_cost = int(td.cost * 0.8 * inst.level)
	var up = Button.new()
	up.text = "Upgrade → Lv%d  (%dg)" % [inst.level + 1, up_cost]
	up.disabled = Run.gold < up_cost or inst.level >= 12
	up.pressed.connect(_upgrade_tower.bind(ser))
	vb.add_child(up)
	# relic pick if current level in {3,6,9} and fewer relics than threshold
	var relic_threshold = inst.level / 3
	if inst.level >= 3 and inst.relics.size() < relic_threshold and _valid_relic_pending(ser):
		var rp = Button.new()
		rp.text = "Choose a Relic (free)"
		rp.pressed.connect(_offer_relic.bind(ser))
		vb.add_child(rp)
	var sell = Button.new()
	var refund = int(td.cost * 0.7 * 0.5 * (1 + inst.level - 1))
	sell.text = "Sell (+%dg)" % refund
	sell.pressed.connect(_sell_tower.bind(ser))
	vb.add_child(sell)
	var cl = Button.new()
	cl.text = "Close"
	cl.pressed.connect(_close_popup)
	vb.add_child(cl)
	_popup = panel
	_skin(panel)
	_ui.add_child(panel)

func _valid_relic_pending(ser: int) -> bool:
	var entry = tower_nodes.get(ser)
	if entry == null:
		return false
	return true

func _upgrade_tower(ser: int) -> void:
	var entry = tower_nodes.get(ser)
	if entry == null:
		return
	var td: Dictionary = entry.def
	var inst: Dictionary = entry.inst
	var up_cost = int(td.cost * 0.8 * inst.level)
	if Run.gold < up_cost:
		return
	Run.gold -= up_cost
	inst.level += 1
	entry.node.level_up(inst.level)
	_close_popup()
	_update_ui()
	_draw_world()

func _sell_tower(ser: int) -> void:
	var entry = tower_nodes.get(ser)
	if entry == null:
		return
	var td: Dictionary = entry.def
	var inst: Dictionary = entry.inst
	var refund = int(td.cost * (0.5 + 0.25 * (inst.level - 1)))
	Run.gold += refund
	var idx = Run.towers.find(inst)
	Run.remove_tower(idx)
	tower_nodes.erase(ser)
	_cd.erase(ser)
	entry.node.queue_free()
	_close_popup()
	Synergy.refresh()
	_update_ui()
	_draw_world()

func _offer_relic(ser: int) -> void:
	var entry = tower_nodes.get(ser)
	if entry == null:
		return
	var inst: Dictionary = entry.inst
	_close_popup()
	var panel = PanelContainer.new()
	panel.name = "RelicPanel"
	panel.position = _ui.get_local_mouse_position() + Vector2(14, 10)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)
	var cap = Label.new()
	cap.text = "Choose a relic for %s" % entry.def.name
	vb.add_child(cap)
	var pool = DB.relics.duplicate()
	pool.shuffle()
	pool = pool.slice(0, 3)
	for rd in pool:
		var btn = Button.new()
		btn.text = "%s — %s" % [rd.name, rd.desc]
		btn.pressed.connect(_apply_relic.bind(ser, rd.id))
		vb.add_child(btn)
	var cl = Button.new()
	cl.text = "Skip"
	cl.pressed.connect(_close_popup)
	vb.add_child(cl)
	_popup = panel
	_skin(panel)
	_ui.add_child(panel)

func _apply_relic(ser: int, rid: String) -> void:
	var entry = tower_nodes.get(ser)
	if entry == null:
		return
	entry.inst.relics.append(rid)
	_close_popup()
	Synergy.refresh()
	_update_ui()

# --------------------------------------------------------------- waves

func _begin_wave() -> void:
	if _phase != "build":
		return
	_phase = "combat"
	var comp: Dictionary = DB.wave_composition(Run.wave, LANES)
	spawn_queue.clear()
	for i in comp.count:
		spawn_queue.append({"hp": comp.hp * (0.85 + randf() * 0.3), "speed": comp.speed * (0.9 + randf() * 0.2),
			"armor": comp.armor, "gold": comp.gold, "xp": comp.xp, "boss": comp.boss and i == 0})
	spawn_queue.shuffle()
	spawn_timer = 0.6
	var sb: Button = _topbar.find_child("StartWaveBtn", true, false)
	if sb != null:
		sb.disabled = true
	_message("Wave %d incoming!" % Run.wave)

func _spawn_enemy(data: Dictionary) -> void:
	var lane = randi() % LANES
	var e = Enemy.new()
	e.setup(data, lane)
	e.position = Vector2(24, lane_ys[lane])
	_world.add_child(e)
	e.serial = run_enemy_serial
	run_enemy_serial += 1
	enemies.append(e)

# --------------------------------------------------------------- combat tick

func _process(dt: float) -> void:
	if _msg_timer > 0.0:
		_msg_timer -= dt
		if _msg_timer <= 0.0 and is_instance_valid(_msg_lbl):
			_msg_lbl.text = ""
	if _phase != "combat":
		return
	# global freeze timer
	if Synergy.has_flag("freeze_periodic"):
		Run.freeze_global_timer -= dt
		if Run.freeze_global_timer <= 0.0:
			Run.freeze_global_timer = Synergy.add_val("freeze_periodic")
			_freezing_all(0.8)
	var freeze_all = Run.freeze_global_timer > 0.0
	# spawn
	if spawn_queue.size() > 0:
		spawn_timer -= dt
		if spawn_timer <= 0.0:
			_spawn_enemy(spawn_queue.pop_back())
			spawn_timer = max(0.2, 1.1 - Run.wave * 0.03)
	# update enemies
	var dot_mult = 1.0 + Synergy.add_val("dot_mult")
	var tick_boost = Synergy.add_val("dot_tickboost")
	for e in enemies:
		e.tick(dt, dot_mult, tick_boost, freeze_all)
		if e.position.x >= CASTLE_X and not e.dead and _phase == "combat":
			e.dead = true
			_hit_castle(e)
	# clean dead -> rewards
	_collect_deaths()
	# towers fire
	_fire_all_towers(dt)
	# skills cooldowns
	for sid in Run.skill_cds.keys():
		Run.skill_cds[sid] = max(0.0, Run.skill_cds[sid] - dt)
		_update_skill_button(sid)
	# castle regen
	var regen = Synergy.add_val("castle_regen")
	Run.castle.hp = min(Run.castle.max_hp, Run.castle.hp + regen * dt)
	_update_ui()
	_draw_world()

func _freezing_all(dur: float) -> void:
	for e in enemies:
		e.apply_status("freeze", 1.0, dur)
	fx.append({"kind": "ring", "pos": Vector2(640, 220), "r": 30, "t": 0.3, "dur": 0.3, "color": Color("#59b8ff")})

func _hit_castle(e: Enemy) -> void:
	var dmg = 12.0
	if e.boss:
		dmg = 55.0
	var armor = Synergy.add_val("castle_armor")
	dmg *= max(0.0, 1.0 - armor)
	Run.castle.hp -= dmg
	_message("An enemy breached the castle! -%d HP" % int(dmg))
	if Run.castle.hp <= 0.0:
		Run.castle.hp = 0.0
		_end_run(false)

func _collect_deaths() -> void:
	var killed = []
	for e in enemies:
		if e.dead:
			killed.append(e)
			Run.gold += e.value * (1.0 + Synergy.add_val("gold_mult"))
			Run.kills += 1
			_add_xp(e.xp)
			_on_kill(e)
	if killed.size() > 0:
		for e in killed:
			enemies.erase(e)
			e.queue_free()
		_update_ui()
	# wave complete check
	if _phase == "combat" and enemies.is_empty() and spawn_queue.is_empty():
		_wave_cleared()

func _on_kill(e: Enemy) -> void:
	if Synergy.add_val("heal_on_kill") > 0.0:
		_heal_castle(Synergy.add_val("heal_on_kill"))
	if Synergy.has_flag("voidecho"):
		_void_echo(e)
	if Synergy.has_flag("bloodecho") or _any_behavior("bloodecho"):
		fx.append({"kind": "ring", "pos": e.position, "r": 10, "t": 0.3, "dur": 0.3, "color": Color("#c23a5e")})
		for o in enemies:
			if o.position.distance_to(e.position) < 160 and not o.dead:
				o.position.x -= 18
				o.apply_status("slow", 0.8, 1.5)

func _any_behavior(b: String) -> bool:
	for ser in tower_nodes.keys():
		var ex = Synergy.tower_local(ser)
		if b in ex.behaviors:
			return true
	return false

func _void_echo(e: Enemy) -> void:
	var src = {}
	for id in e.st.keys():
		if e.st[id].t > 0.0:
			src[id] = e.st[id].pot
	if src.is_empty():
		return
	var near = null
	for o in enemies:
		if not o.dead and o.position.distance_to(e.position) < 200:
			near = o
			break
	if near != null:
		for id in src:
			near.apply_status(id, src[id])

func _heal_castle(amount: float) -> void:
	Run.castle.hp = min(Run.castle.max_hp, Run.castle.hp + amount)

func _add_xp(amount: float) -> void:
	Run.player.xp += int(amount)
	var needed = DB.xp_for_level(Run.player.level)
	while Run.player.xp >= needed:
		Run.player.xp -= needed
		Run.player.level += 1
		needed = DB.xp_for_level(Run.player.level)
		_show_levelup()
	_update_ui()

func _wave_cleared() -> void:
	_phase = "reward"
	Run.waves_cleared += 1
	Run.wave += 1
	Meta.record_wave(Run.waves_cleared)
	var shard_gain = 5 + Run.waves_cleared * 2
	Meta.add_shards(shard_gain)
	_message("Wave cleared. +%d essence shards." % shard_gain)
	_offer_reward_cards()

# --------------------------------------------------------------- leveling

func _show_levelup() -> void:
	_phase = "levelup"
	_clear_popups()
	var panel = PanelContainer.new()
	panel.name = "LevelUp"
	_center_modal(panel, 620, 300)
	_skin(panel)
	_ui.add_child(panel)
	_attr_panel = panel
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var t = Label.new()
	t.text = "LEVEL UP! You are now level %d.\nSpend an attribute point:" % Run.player.level
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title(t, 18)
	vb.add_child(t)
	for id in DB.ATTR.keys():
		var info: Dictionary = DB.attr_info(id)
		var btn = Button.new()
		btn.text = "%s: %s" % [info.name, info.desc]
		btn.pressed.connect(_spend_attr.bind(id))
		vb.add_child(btn)
	var done = Button.new()
	done.text = "Done"
	done.pressed.connect(_close_levelup)
	vb.add_child(done)
	_skin(panel)

func _spend_attr(id: String) -> void:
	Run.player.attr[id] += 1
	Synergy.refresh()
	_update_ui()
	_close_levelup()

func _close_levelup() -> void:
	if _attr_panel != null and is_instance_valid(_attr_panel):
		_attr_panel.queue_free()
	_attr_panel = null
	if _phase == "levelup":
		_phase = "combat" if _phase == "levelup" and _wave_running() else "build"

func _wave_running() -> bool:
	return spawn_queue.size() > 0 or enemies.size() > 0

func _clear_popups() -> void:
	if _popup != null and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null

# keystone offers every 3 levels
func _maybe_keystone() -> void:
	if Run.player.level % 3 != 0:
		return
	_phase = "keystone"
	var opts = DB.keystones.duplicate()
	opts = opts.filter(func(k): return not (k.id in Run.player.keystones))
	if opts.is_empty():
		return
	opts.shuffle()
	opts = opts.slice(0, 3)
	var panel = PanelContainer.new()
	_center_modal(panel, 700, 340)
	_skin(panel)
	_ui.add_child(panel)
	var vb = VBoxContainer.new()
	panel.add_child(vb)
	var t = Label.new()
	t.text = "Choose a Keystone perk:"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title(t, 18)
	vb.add_child(t)
	for k in opts:
		var btn = Button.new()
		btn.text = "%s — %s" % [k.name, k.desc]
		btn.pressed.connect(_pick_keystone.bind(k.id, panel))
		vb.add_child(btn)
	var skip = Button.new()
	skip.text = "Skip"
	skip.pressed.connect(func(): panel.queue_free(); _phase = _wave_running() if _wave_running() else "build")
	vb.add_child(skip)
	_skin(panel)

func _pick_keystone(id: String, panel: Control) -> void:
	if not (id in Run.player.keystones):
		Run.player.keystones.append(id)
	Synergy.refresh()
	panel.queue_free()
	_phase = "combat" if _wave_running() else "build"
	_update_ui()

# --------------------------------------------------------------- reward cards

func _offer_reward_cards() -> void:
	_phase = "reward"
	var cards = _generate_reward_cards()
	var panel = PanelContainer.new()
	panel.name = "Rewards"
	_center_modal(panel, 1040, 380)
	_skin(panel)
	_ui.add_child(panel)
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	panel.add_child(hb)
	var t = Label.new()
	t.text = "Wave cleared! Choose a reward:"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title(t, 18)
	hb.add_child(t)
	# separate header
	for c in cards:
		var b = Button.new()
		b.custom_minimum_size = Vector2(260, 240)
		b.text = "%s\n\n%s" % [c.name, c.desc]
		b.pressed.connect(_apply_reward.bind(c, panel))
		hb.add_child(b)
	_skin(panel)

func _generate_reward_cards() -> Array:
	var cards = []
	cards.append({"kind": "gold", "v": 140 + Run.wave * 20, "name": "Treasure Hoard", "desc": "+%d gold" % (140 + Run.wave * 20)})
	cards.append({"kind": "xp", "v": 40 + Run.wave * 12, "name": "Tome of Knowledge", "desc": "+%d XP" % (40 + Run.wave * 12)})
	cards.append({"kind": "heal", "v": 40.0, "name": "Repair", "desc": "Restore 40 castle HP."})
	# unowned skills
	var owned: Array = Run.skills_owned.duplicate()
	var pool_skills = []
	for id in DB.skills.keys():
		if not (id in owned):
			pool_skills.append(id)
	if pool_skills.size() > 0:
		var sid: String = pool_skills[randi() % pool_skills.size()]
		var sd: Dictionary = DB.skills[sid]
		cards.append({"kind": "skill", "v": sid, "name": "Recruit: " + sd.name, "desc": sd.desc})
	if Run.towers.size() > 0:
		cards.append({"kind": "relic", "v": Run.towers[randi() % Run.towers.size()].serial, "name": "Mystery Relic", "desc": "Grant a random relic to one of your towers."})
	# attribute point
	cards.append({"kind": "attr", "v": 1, "name": "Discipline", "desc": "Gain +1 attribute point."})
	cards.shuffle()
	return cards.slice(0, 3)

func _apply_reward(card: Dictionary, panel: Control) -> void:
	match card.kind:
		"gold":
			Run.gold += card.v
		"xp":
			_add_xp(card.v)
		"heal":
			_heal_castle(card.v)
		"skill":
			var sid: String = card.v
			if not (sid in Run.skills_owned):
				Run.skills_owned.append(sid)
				if Run.skills_equipped.size() < 5 + (1 if Meta.has_unlock("u_slot") else 0):
					Run.equip_skill(sid)
			_build_skillbar()
		"relic":
			var ser: int = card.v
			if tower_nodes.has(ser):
				_apply_relic(ser, DB.relics[randi() % DB.relics.size()].id)
		"attr":
			_show_levelup()
	panel.queue_free()
	_phase = "build"
	var sb: Button = _topbar.find_child("StartWaveBtn", true, false) if is_instance_valid(_topbar) else null
	if sb != null:
		sb.text = "Start Wave " + str(Run.wave)
		sb.disabled = false
	Synergy.refresh()
	_update_ui()
	_maybe_keystone()

# --------------------------------------------------------------- skills

func _cast_skill(sid: String) -> void:
	if _phase != "combat":
		return
	if Run.skill_cds.get(sid, 0.0) > 0.0:
		return
	var sd: Dictionary = DB.skills.get(sid, {})
	if sd.get("type", "") != "active":
		return
	var cd = sd.get("cooldown", 10.0)
	cd *= max(0.25, 1.0 - Synergy.add_val("cdr"))
	Run.skill_cds[sid] = cd
	var call = sd.get("cast", "")
	if has_method(call):
		call(call)
	_update_skill_button(sid)
	_draw_world()

func _update_skill_button(sid: String) -> void:
	if not is_instance_valid(_skillbar):
		return
	var idx = Run.skills_equipped.find(sid)
	for i in _skillbar.get_child_count():
		var b = _skillbar.get_child(i)
		if i == idx:
			var rem = Run.skill_cds.get(sid, 0.0)
			b.text = "%s\n[%d]  %s" % [DB.get_skill(sid).get("name", sid), Run.skill_rank(sid), "R" if rem > 0.0 else "READY"]
			b.disabled = rem > 0.0

func _skill_power() -> float:
	return 1.0 + Synergy.add_val("skill_dmg")

func _elem_tower_count(tag: String) -> int:
	var n = 0
	for t in Run.towers:
		var td: Dictionary = DB.towers[t.id]
		if tag in td.get("tags", []):
			n += 1
	return n

func cast_meteor() -> void:
	var n = 3 + _elem_tower_count("fire")
	var dmg = 34.0 * _skill_power() * (1.0 + 0.2 * _elem_tower_count("fire"))
	for i in n:
		var target = _random_enemy()
		if target == null:
			return
		var p: Vector2 = target.position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
		fx.append({"kind": "impact", "pos": p, "r": 22, "t": 0.25, "dur": 0.25, "a": 0.5})
		_area_hit(p, 70, dmg, {"burn": 1.5})

func cast_blizzard() -> void:
	for e in enemies:
		if e.position.distance_to(Vector2(640, 240)) < 420:
			e.apply_status("freeze", 1.0, 1.8)
			e.apply_status("slow", 1.5, 4.0)
	fx.append({"kind": "ring", "pos": Vector2(640, 240), "r": 60, "t": 0.6, "dur": 0.6, "color": Color("#59b8ff")})

func cast_chaincall() -> void:
	var start = _random_enemy()
	if start == null:
		return
	var n = 6
	var dmg = 30.0 * _skill_power()
	var current = start
	var prev = start.position
	for i in n:
		if current == null:
			break
		_apply_hit(current, dmg, {}, {}, 0.05, 1.5, -1, {"shock": 1.0})
		fx.append({"kind": "shot", "from": prev, "to": current.position, "t": 0.3, "dur": 0.3, "color": Color("#efe94a"), "w": 3})
		prev = current.position
		var nx = null
		var bd = 1e9
		for e in enemies:
			if not e.dead and e != current and e.position.distance_to(current.position) < 260 and e.position.distance_to(current.position) < bd:
				bd = e.position.distance_to(current.position)
				nx = e
		current = nx

func cast_soulreap() -> void:
	var dmg = 60.0 * _skill_power()
	for e in enemies:
		if e.hp < e.max_hp * (0.45 + 0.05 * _elem_tower_count("shadow")) and not e.dead and not e.boss:
			e.hp = 0.0
			e.dead = true
			_heal_castle(3.0)
		else:
			_apply_hit(e, dmg * 0.4, {}, {}, 0.05, 1.5, -1, {})
	fx.append({"kind": "ring", "pos": Vector2(640, 240), "r": 90, "t": 0.5, "dur": 0.5, "color": Color("#9a5df0")})

func cast_consecrate() -> void:
	_heal_castle(25.0 * (1.0 + 0.3 * _elem_tower_count("holy")))
	for e in enemies:
		var dtags: Array = []
		if e.has("shred") or e.has("mark"):
			dtags = ["shadow", "void"]
		if e.boss or e.has("shred"):
			_apply_hit(e, 20.0 * _skill_power(), {}, {}, 0.05, 1.5, -1, {})
	fx.append({"kind": "ring", "pos": Vector2(CASTLE_X - 10, 300), "r": 120, "t": 0.5, "dur": 0.5, "color": Color("#fff0a8")})

func cast_gale() -> void:
	for e in enemies:
		if not e.dead:
			e.position.x -= 70
			e.apply_status("root", 1.0, 1.2)
	fx.append({"kind": "ring", "pos": Vector2(500, 300), "r": 90, "t": 0.4, "dur": 0.4, "color": Color("#66c266")})

func cast_arcoverload() -> void:
	Run.arcoverload_timer = 6.0
	_message("Arc Overload: towers at +100% attack speed for 6s!")

func cast_miasma() -> void:
	var ox = 0.0
	for e in enemies:
		if e.position.x > ox and not e.dead:
			ox = e.position.x
	for e in enemies:
		if e.position.x > ox - 260 and not e.dead:
			e.apply_status("poison", 2.0, 4.0)
	fx.append({"kind": "impact", "pos": Vector2(max(ox - 120, 200), 300), "r": 120, "t": 0.5, "dur": 0.5, "a": 0.25})

func cast_bloodpact() -> void:
	var sac = Run.castle.max_hp * 0.05
	Run.castle.hp = max(1.0, Run.castle.hp - sac)
	var dmg = 120.0 * _skill_power() * (1.0 + 0.25 * _elem_tower_count("blood"))
	Run.lifesteal_temp = 0.10
	for e in enemies:
		if not e.dead:
			_apply_hit(e, dmg, {}, {}, 0.05, 1.5, -1, {"bleed": 2.0})
	fx.append({"kind": "ring", "pos": Vector2(600, 300), "r": 80, "t": 0.6, "dur": 0.6, "color": Color("#c23a5e")})

func cast_timelock() -> void:
	for e in enemies:
		e.apply_status("freeze", 1.0, 3.0)
	_message("Time is frozen!")

func _random_enemy() -> Enemy:
	for e in enemies:
		if not e.dead:
			return e
	return null

# --------------------------------------------------------------- tower firing

func _fire_all_towers(dt: float) -> void:
	for ser in _cd.keys():
		var entry = tower_nodes.get(ser)
		if entry == null:
			continue
		var ex = Synergy.tower_global(ser)
		var def: Dictionary = entry.def
		var base: Dictionary = def.base
		var rate = base.rate * (1.0 + ex.add.get("atk_rate", 0.0) + (0.5 if Run.arcoverload_timer > 0.0 else 0.0))
		_cd[ser] -= dt
		if _cd[ser] > 0.0:
			continue
		_cd[ser] = 1.0 / max(0.1, rate)
		_fire_tower(ser, entry, ex, base)

func _fire_tower(ser: int, entry: Dictionary, ex: Dictionary, base: Dictionary) -> void:
	var def: Dictionary = entry.def
	var inst: Dictionary = entry.inst
	var range = base.range * (1.0 + ex.add.get("range_mult", 0.0))
	var pos: Vector2 = entry.node.position
	# find targets in range
	var targets = []
	for e in enemies:
		if not e.dead and e.position.distance_to(pos) <= range:
			targets.append(e)
	if targets.is_empty():
		return
	var dmg = base.damage * (1.0 + ex.add.get("mul_dmg", 0.0)) * (1.0 + 0.18 * (inst.level - 1))
	var crit_chance = base.get("crit", 0.05) + ex.add.get("crit_chance", 0.0)
	var crit_mult = 1.0 + ex.add.get("crit_mult", 0.0)
	# choose kind
	var kind: String = def.behavior.get("kind", "single")
	var override_kind: String = ex.override_kind
	if override_kind != "":
		kind = override_kind
	match kind:
		"single":
			_fire_single(pos, targets[0], dmg, crit_chance, crit_mult, def, ex, ser)
		"chain":
			var chain = def.behavior.get("chain", 2) + int(ex.add.get("chain_bonus", 0.0))
			_fire_chain(pos, targets, chain, dmg, crit_chance, crit_mult, def, ex, ser)
		"splash":
			_fire_splash(pos, targets[0], def.behavior.get("radius", 46), dmg, crit_chance, crit_mult, def, ex, ser)
		"lane":
			var pierce = def.behavior.get("pierce", 4)
			_fire_lane(pos, targets, pierce, dmg, crit_chance, crit_mult, def, ex, ser)
		"bomb":
			_fire_splash(pos, targets[0], 60 + (30 if ex.override_kind == "asc_zero" else 0), dmg * 1.6, crit_chance, crit_mult, def, ex, ser)
			if ex.override_kind == "asc_zero":
				for e in targets:
					e.apply_status("freeze", 1.0, 1.2)
		"asc_infernal", "asc_refraction", "asc_arbelest":
			_fire_ascension(ser, pos, targets, dmg, crit_chance, crit_mult, def, ex, kind)
		"asc_aegis":
			_heal_castle(0.8)
			_fire_single(pos, targets[0], dmg, crit_chance, crit_mult, def, ex, ser)
		"asc_bloom":
			_fire_splash(pos, targets[0], 60, dmg, crit_chance, crit_mult, def, ex, ser)
			for e in targets:
				e.apply_status("poison", 1.5, 2.5)
		"asc_nightmare":
			_fire_lane(pos, targets, 6, dmg, crit_chance, crit_mult, def, ex, ser)
			for e in targets:
				_heal_castle(0.6) if not e.dead else null
		"asc_ebon":
			_fire_splash(pos, targets[0], 60, dmg * 1.2, crit_chance, crit_mult, def, ex, ser)
			for e in targets:
				e.apply_status("burn", 1.2, 2.5)
				e.apply_status("slow", 0.8, 2.0)
		_:
			_fire_single(pos, targets[0], dmg, crit_chance, crit_mult, def, ex, ser)

func _fire_single(pos: Vector2, target: Enemy, dmg: float, cc: float, cm: float, def: Dictionary, ex: Dictionary, ser: int) -> void:
	var p: Vector2 = target.position
	fx.append({"kind": "shot", "from": pos, "to": p, "t": 0.25, "dur": 0.25, "color": def.color, "w": 2.5})
	_apply_hit(target, dmg, def, ex, cc, cm, ser)

func _fire_chain(pos: Vector2, targets: Array, chain: int, dmg: float, cc: float, cm: float, def: Dictionary, ex: Dictionary, ser: int) -> void:
	var current = targets[0]
	var prev = pos
	for i in chain + 1:
		if current == null or current.dead:
			break
		_apply_hit(current, dmg * (1.0 - 0.15 * i), def, ex, cc, cm, ser)
		fx.append({"kind": "shot", "from": prev, "to": current.position, "t": 0.2, "dur": 0.2, "color": def.color, "w": 2.5})
		prev = current.position
		var nx = null
		var bd = 1e9
		var hop = Synergy.has_flag("chain_hop") or ("chain_hop" in ex.behaviors)
		for e in enemies:
			if e.dead or e == current:
				continue
			var d = e.position.distance_to(current.position)
			if not hop and absf(e.position.y - current.position.y) > 30:
				continue
			if d < bd and d < 240:
				bd = d
				nx = e
		current = nx

func _fire_splash(pos: Vector2, target: Enemy, radius: float, dmg: float, cc: float, cm: float, def: Dictionary, ex: Dictionary, ser: int) -> void:
	_area_hit(target.position, radius, dmg, {}, def, ex, cc, cm, ser)

func _fire_lane(pos: Vector2, targets: Array, pierce: int, dmg: float, cc: float, cm: float, def: Dictionary, ex: Dictionary, ser: int) -> void:
	var hit = 0
	var prev = pos
	for e in targets:
		if hit >= pierce:
			break
		if e.dead:
			continue
		_apply_hit(e, dmg, def, ex, cc, cm, ser)
		fx.append({"kind": "shot", "from": prev, "to": e.position, "t": 0.2, "dur": 0.2, "color": def.color, "w": 2.5})
		prev = e.position
		hit += 1

func _fire_ascension(ser: int, pos: Vector2, targets: Array, dmg: float, cc: float, cm: float, def: Dictionary, ex: Dictionary, kind: String) -> void:
	var t0 = targets[0]
	match kind:
		"asc_infernal":
			for i in 3:
				if i >= targets.size():
					break
				var e = targets[i]
				_apply_hit(e, dmg * 0.85, def, ex, cc, cm, ser, {"burn": 2.0})
				fx.append({"kind": "shot", "from": pos, "to": e.position, "t": 0.2, "dur": 0.2, "color": Color("#ff5a3c"), "w": 3})
		"asc_refraction":
			_apply_hit(t0, dmg, def, ex, cc, cm, ser)
			var extra = []
			for e in enemies:
				if not e.dead and e != t0 and e.position.distance_to(t0.position) < 240:
					extra.append(e)
				if extra.size() >= 2:
					break
			for e in extra:
				_apply_hit(e, dmg * 0.7, def, ex, cc, cm, ser)
			fx.append({"kind": "shot", "from": pos, "to": t0.position, "t": 0.2, "dur": 0.2, "color": Color("#efe94a"), "w": 3})
		"asc_arbelest":
			_apply_hit(t0, dmg * 1.4, def, ex, cc, cm, ser, {}, true)

# ---- hit resolution (the core damage/status engine) ----------------------

# safe accessors for modifier dicts (defensive for empty dicts from skill casts)
func _ek(ex: Dictionary, key: String, d: float = 0.0) -> float:
	if ex.has("add") and ex["add"] is Dictionary:
		return ex["add"].get(key, d)
	return d

func _eb(ex: Dictionary, b: String) -> bool:
	if ex.has("behaviors") and ex["behaviors"] is Array:
		return b in ex["behaviors"]
	return false

func _eas(ex: Dictionary) -> Array:
	if ex.has("add_status") and ex["add_status"] is Array:
		return ex["add_status"]
	return []

func _apply_hit(e: Enemy, dmg: float, def: Dictionary, ex: Dictionary, cc: float = 0.05, cm: float = 1.5, ser: int = -1, extra_status: Dictionary = {}, ignore_armor: bool = false) -> void:
	if e.dead:
		return
	# crit
	var crit = randf() < cc
	if crit:
		dmg *= cm
	# multi-hit (siege engine / relic)
	if randf() < _ek(ex, "multi_hit"):
		dmg *= 1.2
	# armor mitigation
	var armor = e.effective_armor()
	var pierce = _ek(ex, "pierce_armor")
	if ignore_armor:
		pierce = 1.0
	armor *= max(0.0, 1.0 - pierce)
	var mitigated = max(0.0, dmg - armor * 1.5)
	var actual = e.take_hit(mitigated)
	# enemy vulnerability global
	actual *= (1.0 + Synergy.add_val("enemy_vuln"))
	# statuses from tower def
	var def_status: Dictionary = def.get("status", {})
	for id in def_status.keys():
		var pot = def_status[id] * (1.0 + _status_bonus(ex, id))
		_apply_status_wrapper(e, id, pot)
	# extra relic statuses
	for sid in _eas(ex):
		_apply_status_wrapper(e, sid, 0.8)
	# extra (skill/cast) statuses
	for id in extra_status.keys():
		_apply_status_wrapper(e, id, extra_status[id])
	# behaviors
	_process_behaviors(e, ex, def, actual)
	# lifesteal
	var ls = _ek(ex, "lifesteal") + Synergy.add_val("lifesteal") + Run.lifesteal_temp
	if ls > 0.0:
		_heal_castle(actual * ls)
	# per-shot castle heal
	var hp_shot = _ek(ex, "castle_heal_per_shot")
	if hp_shot > 0.0:
		_heal_castle(hp_shot)
	# on kill hook (owned by tower def)
	if e.dead and def.get("on_kill", "") != "":
		_on_kill(e)
	if e.dead and ser >= 0:
		var entry = tower_nodes.get(ser)
		if entry != null and entry.def.get("on_kill", "") != "":
			_on_kill(e)

func _apply_status_wrapper(e: Enemy, id: String, pot: float) -> void:
	var dur = 2.5
	var p = pot
	match id:
		"burn":
			p *= 1.0 + Synergy.add_val("burn_str") + 0.15
		"poison":
			p *= 1.0 + Synergy.add_val("poison_str") + 0.15
		"slow":
			p *= 1.0 + Synergy.add_val("slow_str")
		"root":
			p *= 1.0 + Synergy.add_val("root_str")
		"shred":
			p *= 1.0 + Synergy.add_val("shred_str")
	e.apply_status(id, p, dur)

func _status_bonus(ex: Dictionary, id: String) -> float:
	match id:
		"burn":
			return Synergy.add_val("burn_str")
		"poison":
			return Synergy.add_val("poison_str")
		"slow":
			return Synergy.add_val("slow_str")
		"root":
			return Synergy.add_val("root_str")
		"shred":
			return Synergy.add_val("shred_str")
	return 0.0

func _process_behaviors(e: Enemy, ex: Dictionary, def: Dictionary, actual: float) -> void:
	# vaporize (quench): freeze + burn => burst
	if _eb(ex, "vaporize") and e.has("burn") and e.has("freeze"):
		e.take_hit(actual * 1.5)
		fx.append({"kind": "impact", "pos": e.position, "r": 14, "t": 0.2, "dur": 0.2, "a": 0.4})
	# lightning_ignites (conduction): if enemy has shock and it was a lightning hit
	if (Synergy.has_flag("lightning_ignites") or _eb(ex, "lightning_ignites")) and e.has("shock"):
		e.apply_status("burn", 1.2)
	# burn_slows / slow_burns
	if Synergy.has_flag("burn_slows") and e.has("burn") and not e.has("slow"):
		e.apply_status("slow", 0.6, 1.5)
	if Synergy.has_flag("slow_burns") and e.has("slow") and not e.has("burn"):
		e.apply_status("burn", 0.6, 1.5)
	# root_shocks
	if Synergy.has_flag("root_shocks") and e.has("root") and not e.has("shock"):
		e.apply_status("shock", 1.0)
	# dreadwinter slow_bleed
	if Synergy.has_flag("slow_bleed") and e.has("slow") and not e.has("bleed"):
		e.apply_status("bleed", 0.8)
	# burn_bleed (ember+bone)
	if _eb(ex, "burn_bleed") and e.has("burn") and not e.has("bleed"):
		e.apply_status("bleed", 0.8)
	# root_poisons
	if _eb(ex, "root_poisons") and e.has("root") and not e.has("poison"):
		e.apply_status("poison", 1.0)
	# shred_ignites
	if Synergy.has_flag("shred_ignites") and e.has("shred") and not e.has("burn"):
		e.apply_status("burn", 1.0)
	# root_armor (ironwood): rooted enemies take more
	if Synergy.has_flag("root_armor") and e.has("root"):
		e.take_hit(actual * 0.3)

func _area_hit(pos: Vector2, radius: float, dmg: float, extra_status: Dictionary = {}, def: Dictionary = {}, ex: Dictionary = {}, cc: float = 0.05, cm: float = 1.5, ser: int = -1) -> void:
	fx.append({"kind": "impact", "pos": pos, "r": radius, "t": 0.2, "dur": 0.2, "a": 0.3})
	for e in enemies:
		if not e.dead and e.position.distance_to(pos) <= radius:
			_apply_hit(e, dmg, def, ex, cc, cm, ser, extra_status)

# ------------------------------------------------------------------ end

func _end_run(victory: bool = false) -> void:
	_phase = "gameover"
	var shard_gain = Meta.best_wave if false else 10 + Run.waves_cleared * 3
	Meta.add_shards(shard_gain)
	_clear_ui()
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-340, -200)
	panel.size = Vector2(680, 400)
	_skin(panel)
	_ui.add_child(panel)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var t = Label.new()
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title(t, 30)
	if victory or Run.castle.hp > 0.0 and Run.wave > 60:
		t.text = "VICTORY"
	else:
		t.text = "THE CITADEL HAS FALLEN"
	vb.add_child(t)
	var stat = Label.new()
	stat.text = "Waves cleared: %d\nKills: %d\nPlayer level: %d\nActive synergies discovered: %d\n\nEssence Shards earned this run: +%d\nTotal shards: %d" % [
		Run.waves_cleared, Run.kills, Run.player.level,
		Synergy.active_resonances.size() + Synergy.active_adjacencies.size() + Synergy.active_ascensions.size(),
		shard_gain, Meta.shards]
	stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(stat)
	var mb = Button.new()
	mb.text = "Return to Main Menu"
	mb.pressed.connect(_show_main_menu)
	vb.add_child(mb)
	_skin(panel)

func _clear_ui() -> void:
	for c in _ui.get_children():
		if c.name == "_bg":
			continue
		c.queue_free()
	_topbar = null
	_skillbar = null
	_synergy_panel = null
	_synergy_txt = null
	_popup = null
	_card_panel = null
	_attr_panel = null
	_msg_lbl = null
	_hint_lbl = null
	_how_panel = null
	_how_body = null
	_hp_bar = null
	_hp_txt = null
	_gold_txt = null
	_wave_txt = null
	_kills_txt = null
	_lvl_txt = null

# world draw callback hook
func _world_draw_callback() -> void:
	_world_draw()
