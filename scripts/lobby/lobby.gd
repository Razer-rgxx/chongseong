extends Node3D
## 언덕 아래 마을(시작 장면). 걸어 다니며 들른다.
## 대장간: 모루 위에 검집의 검이 놓여 있고, 망치질로 검집을 강화한다. 성소: 축복. 검 진열대: 도감. 언덕 길: 판을 시작한다.
## 영주의 움직임은 언덕과 같은 Rules로 돌린다(검도 적도 없는 낮). 모양은 기본 도형이고, 모델이 들어오면 _build_*만 바꾼다.

const LORD_SCENE: PackedScene = preload("res://scenes/lord/lord.tscn")
const RUN_PATH: String = "res://scenes/world/main.tscn"

## 들를 곳(칸 좌표). 마을 크기는 언덕 싸움터와 같다(RunData.arena_size).
@export var forge_at: Vector2 = Vector2(9.5, 8.0)
@export var shrine_at: Vector2 = Vector2(24.5, 8.0)
@export var rack_at: Vector2 = Vector2(9.0, 15.0)
@export var gate_at: Vector2 = Vector2(17.0, 2.5)
@export var reach: float = 2.0
@export var max_ticks_per_frame: int = 8

var data: GameData
var meta: Meta
var rules: Rules
var _acc: float = 0.0
var _want_dash: bool = false
var _lord: Node3D
var _prompt := Label3D.new()
var _anvil_sword := Node3D.new()
var _anvil_label := Label3D.new()
var _forge_light := OmniLight3D.new()
var _near: String = ""

@onready var _camera: Camera3D = $Camera
@onready var _sfx: Sfx = $Sfx
@onready var _hud: LobbyHud = $UI
@onready var _sun: DirectionalLight3D = $Sun


func _ready() -> void:
	data = GameData.load_default()
	meta = Meta.load_or_new()
	meta.fix_sheath(data)
	meta.save()
	rules = Rules.new(data, 1)
	rules.hilts.clear()
	rules.lord.pos = Vector2(17.0, 13.0)
	rules.lord.prev_pos = rules.lord.pos
	_hud.setup(data, meta)
	_build_ground()
	_build_forge()
	_build_shrine()
	_build_rack()
	_build_gate()
	_build_houses()
	_lord = LORD_SCENE.instantiate()
	_lord.setup(rules)
	add_child(_lord)
	_lord.set_sword(meta.sheath_sword(data), data.grades)
	_lord.torch.light_energy = 1.2
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.font_size = 48
	_prompt.pixel_size = 0.01
	_prompt.outline_size = 10
	add_child(_prompt)
	_hud.forge_hit.connect(_on_hammer)
	_hud.forge_done.connect(_on_forged)
	_hud.closed.connect(func() -> void: _capture(true))
	_camera.target = Grid.cells_to_world(rules.lord.pos)
	_camera.yaw = 0.0
	_camera.snap()
	_sun.rotation_degrees = Vector3(-35.0, -60.0, 0.0)
	_refresh_anvil()
	_hud.toast("언덕 아래 마을. 대장간, 성소, 검 진열대에 들르고, 북쪽 길로 언덕에 오른다.")
	_capture(true)


func _capture(on: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on and _camera.third() and not _hud.is_open() else Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_camera.look(mm.relative)
	var k := event as InputEventKey
	if _hud.is_open():
		if k and k.pressed and k.physical_keycode == KEY_ESCAPE:
			_hud.close()
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and _camera.third() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_capture(true)
	if event.is_action_pressed("dash"):
		_want_dash = true
	if event.is_action_pressed("pull"):
		_interact()
	if k and k.pressed and not k.echo:
		if k.physical_keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif k.physical_keycode == KEY_V:
			_camera.toggle_mode()
			_capture(true)


func _physics_process(delta: float) -> void:
	if _hud.is_open():
		return
	_acc += delta
	var n: int = 0
	while _acc >= rules.dt and n < max_ticks_per_frame:
		var inp := LordInput.new()
		inp.move = _camera.relative_move(Input.get_vector("move_left", "move_right", "move_up", "move_down"))
		inp.dash = _want_dash
		if _camera.third() and inp.move.length() > 0.1:
			inp.aim_valid = true
			inp.aim = rules.lord.pos + inp.move
		rules.step(inp)
		_want_dash = false
		_acc -= rules.dt
		n += 1
	if n == max_ticks_per_frame:
		_acc = 0.0


func _process(delta: float) -> void:
	var alpha: float = clampf(_acc / rules.dt, 0.0, 1.0)
	_lord.draw(alpha, delta)
	_camera.target = _lord.position
	var p: Vector2 = rules.lord.pos
	_near = ""
	var spots := {"forge": forge_at + Vector2(0, 2.2), "shrine": shrine_at + Vector2(0, 1.8), "rack": rack_at + Vector2(1.6, 0), "gate": gate_at + Vector2(0, 1.0)}
	for key in spots:
		if p.distance_to(spots[key]) < reach:
			_near = key
	_prompt.visible = _near != "" and not _hud.is_open()
	if _prompt.visible:
		_prompt.text = {"forge": "E  대장간", "shrine": "E  성소", "rack": "E  검 진열대", "gate": "E  언덕 오르기"}[_near]
		_prompt.position = Grid.cells_to_world(spots[_near], 2.4)
	_forge_light.light_energy = lerpf(_forge_light.light_energy, 1.6, delta * 3.0)


func _interact() -> void:
	match _near:
		"forge":
			_hud.open_forge()
		"shrine":
			_hud.open_shrine()
		"rack":
			_hud.open_rack()
		"gate":
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().change_scene_to_file(RUN_PATH)
			return
		_:
			return
	_capture(false)


func _on_hammer(step: int) -> void:
	_sfx.play(&"thump", Grid.cells_to_world(forge_at, 1.0), -2.0 + step)
	_camera.add_shake(0.08 + 0.04 * step)
	_forge_light.light_energy = 6.0
	_hud.flash(Color(1, 0.7, 0.35), 0.08 + 0.03 * step, 0.2)


func _on_forged(r: Dictionary, big: bool) -> void:
	if r.ok:
		_sfx.play(&"hit_big", Grid.cells_to_world(forge_at, 1.0), 2.0)
		_hud.flash(Color(1, 0.84, 0.42), 0.7 if big else 0.35, 1.4 if big else 0.6)
		_camera.add_shake(0.5 if big else 0.25)
	else:
		_sfx.play(&"break" if r.get("dropped", false) else &"hurt", Grid.cells_to_world(forge_at, 1.0), -2.0)
		_hud.flash(Color(0.45, 0.48, 0.55), 0.25, 0.4)
	_refresh_anvil()
	_lord.set_sword(meta.sheath_sword(data), data.grades)


## 모루 위에 놓인 검: 검집의 검이 바뀌거나 강화되면 다시 만든다.
func _refresh_anvil() -> void:
	for c in _anvil_sword.get_children():
		c.queue_free()
	var s := meta.sheath_sword(data)
	if s == null:
		_anvil_label.text = "검집 +%d · 빈 모루" % meta.sheath_lv
		return
	var col: Color = data.grades.colors[s.grade]
	var blade := _box(Vector3(s.form.blade_length, 0.04, s.form.blade_width * 1.4), _mat(Color(0.82, 0.85, 0.9), 0.85, 0.25))
	blade.position = Vector3(s.form.blade_length / 2.0 - 0.15, 0, 0)
	_anvil_sword.add_child(blade)
	var guard := _box(Vector3(0.07, 0.06, 0.38), _mat(col, 0.5, 0.4, true))
	guard.position = Vector3(-0.18, 0, 0)
	_anvil_sword.add_child(guard)
	var grip := _box(Vector3(0.3, 0.05, 0.06), _mat(Color(0.25, 0.18, 0.12)))
	grip.position = Vector3(-0.37, 0, 0)
	_anvil_sword.add_child(grip)
	_anvil_label.text = "%s · %s" % [s.label(), data.grades.names[s.grade]]
	_anvil_label.modulate = col


# ---------------------------------------------------------------- 마을 짓기

func _build_ground() -> void:
	var size := Vector2(Grid.size) * Grid.CELL
	var g := _box(Vector3(size.x, 1.0, size.y), VillageMaterials.get_mat("grass", Color(0.26, 0.3, 0.2), 3.0))
	g.position = Vector3(size.x / 2.0, -0.5, size.y / 2.0)
	add_child(g)
	var plaza := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 9.0
	cyl.bottom_radius = 9.0
	cyl.height = 0.04
	plaza.mesh = cyl
	plaza.material_override = VillageMaterials.get_mat("dirt", Color(0.42, 0.38, 0.32), 3.0)
	plaza.position = Grid.cells_to_world(Vector2(17, 11), 0.02)
	add_child(plaza)
	var path := _box(Vector3(3.0, 0.03, 18.0), plaza.material_override)
	path.position = Grid.cells_to_world(Vector2(17, 5.5), 0.02)
	add_child(path)
	var outside := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size.x + 300.0, size.y + 300.0)
	outside.mesh = plane
	outside.material_override = _mat(Color(0.12, 0.15, 0.1), 0.0, 1.0)
	outside.position = Vector3(size.x / 2.0, -1.0, size.y / 2.0)
	add_child(outside)
	# 마을 울타리
	var wood := _mat(Color(0.33, 0.24, 0.16))
	for i in 34:
		for side in [Vector2(i + 0.5, 0.3), Vector2(i + 0.5, 21.7)]:
			if side.y < 1.0 and absf(side.x - 17.0) < 2.0:
				continue
			var post := _box(Vector3(0.18, 1.1, 0.18), wood)
			post.position = Grid.cells_to_world(side, 0.55)
			add_child(post)
	for i in 22:
		for side in [Vector2(0.3, i + 0.5), Vector2(33.7, i + 0.5)]:
			var post := _box(Vector3(0.18, 1.1, 0.18), wood)
			post.position = Grid.cells_to_world(side, 0.55)
			add_child(post)


func _build_forge() -> void:
	var at := Grid.cells_to_world(forge_at)
	var wall := _box(Vector3(7.0, 4.0, 5.0), VillageMaterials.get_mat("raw_plank_wall", Color(0.35, 0.27, 0.2), 2.0))
	wall.position = at + Vector3(0, 2.0, -1.2)
	add_child(wall)
	var roof := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(7.6, 2.0, 5.6)
	roof.mesh = pm
	roof.material_override = VillageMaterials.get_mat("roof", Color(0.22, 0.12, 0.1), 2.0)
	roof.position = at + Vector3(0, 5.0, -1.2)
	add_child(roof)
	var chimney := _box(Vector3(1.0, 3.0, 1.0), VillageMaterials.get_mat("stone_wall", Color(0.3, 0.29, 0.28), 2.0))
	chimney.position = at + Vector3(2.2, 5.5, -2.2)
	add_child(chimney)
	var furnace := _box(Vector3(1.6, 1.4, 1.2), VillageMaterials.get_mat("stone_wall", Color(0.2, 0.18, 0.17), 1.5, Color(0.6, 0.55, 0.5)))
	furnace.position = at + Vector3(-2.2, 0.7, 1.6)
	add_child(furnace)
	var fire := _box(Vector3(0.9, 0.5, 0.1), _mat(Color(1.0, 0.45, 0.15), 0.0, 1.0, true))
	fire.position = at + Vector3(-2.2, 0.6, 2.21)
	add_child(fire)
	_forge_light.light_color = Color(1.0, 0.55, 0.25)
	_forge_light.omni_range = 9.0
	_forge_light.light_energy = 1.6
	_forge_light.shadow_enabled = true
	_forge_light.position = at + Vector3(-1.4, 1.6, 2.6)
	add_child(_forge_light)
	# 모루: 받침, 몸통, 뿔. 그 위에 검집의 검이 눕는다
	var iron := _mat(Color(0.18, 0.19, 0.21), 0.7, 0.45)
	var stump := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = 0.45
	sc.bottom_radius = 0.5
	sc.height = 0.6
	stump.mesh = sc
	stump.material_override = _mat(Color(0.3, 0.22, 0.15))
	stump.position = at + Vector3(0.6, 0.3, 2.6)
	add_child(stump)
	var body := _box(Vector3(1.1, 0.35, 0.45), iron)
	body.position = at + Vector3(0.6, 0.78, 2.6)
	add_child(body)
	var horn := MeshInstance3D.new()
	var hc := CylinderMesh.new()
	hc.top_radius = 0.0
	hc.bottom_radius = 0.18
	hc.height = 0.55
	horn.mesh = hc
	horn.material_override = iron
	horn.rotation.z = PI / 2.0
	horn.position = at + Vector3(1.42, 0.86, 2.6)
	add_child(horn)
	_anvil_sword.position = at + Vector3(0.55, 0.98, 2.6)
	_anvil_sword.rotation.y = 0.25
	add_child(_anvil_sword)
	_anvil_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_anvil_label.font_size = 40
	_anvil_label.pixel_size = 0.01
	_anvil_label.outline_size = 8
	_anvil_label.position = at + Vector3(0.6, 1.7, 2.6)
	add_child(_anvil_label)
	_sign("대장간", at + Vector3(0, 4.2, 2.2))


func _build_shrine() -> void:
	var at := Grid.cells_to_world(shrine_at)
	var stone := VillageMaterials.get_mat("medieval_blocks_03", Color(0.5, 0.52, 0.56), 2.0)
	var base := _box(Vector3(4.0, 0.4, 4.0), stone)
	base.position = at + Vector3(0, 0.2, 0)
	add_child(base)
	for p in [Vector3(-1.5, 0, -1.5), Vector3(1.5, 0, -1.5), Vector3(-1.5, 0, 1.5), Vector3(1.5, 0, 1.5)]:
		var pillar := _box(Vector3(0.4, 3.2, 0.4), stone)
		pillar.position = at + p + Vector3(0, 2.0, 0)
		add_child(pillar)
	var top := _box(Vector3(4.2, 0.4, 4.2), stone)
	top.position = at + Vector3(0, 3.8, 0)
	add_child(top)
	var orb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.45
	sm.height = 0.9
	orb.mesh = sm
	orb.material_override = _mat(Color(0.55, 0.8, 1.0), 0.0, 0.3, true)
	orb.position = at + Vector3(0, 1.6, 0)
	add_child(orb)
	var light := OmniLight3D.new()
	light.light_color = Color(0.55, 0.8, 1.0)
	light.omni_range = 7.0
	light.light_energy = 1.4
	light.position = at + Vector3(0, 1.8, 0)
	add_child(light)
	_sign("성소", at + Vector3(0, 4.6, 0))


func _build_rack() -> void:
	var at := Grid.cells_to_world(rack_at)
	var wood := _mat(Color(0.36, 0.26, 0.17))
	var frame := _box(Vector3(0.5, 0.3, 5.0), wood)
	frame.position = at + Vector3(0, 0.15, 0)
	add_child(frame)
	var bar := _box(Vector3(0.2, 0.15, 5.0), wood)
	bar.position = at + Vector3(0, 1.4, 0)
	add_child(bar)
	# 도감에서 찾은 등급마다 한 자루씩 세워 둔다(등급 색)
	var shown: int = 0
	for g in data.grades.names.size():
		var any := false
		for i in data.swords_by_grade[g]:
			if meta.has_found(data.swords[i].id):
				any = true
				break
		if not any:
			continue
		var blade := _box(Vector3(0.06, 1.6, 0.12), _mat(Color(0.8, 0.83, 0.88), 0.8, 0.3))
		blade.position = at + Vector3(0, 1.0, -2.0 + shown * 0.8)
		add_child(blade)
		var guard := _box(Vector3(0.1, 0.06, 0.4), _mat(data.grades.colors[g], 0.5, 0.4, true))
		guard.position = at + Vector3(0, 1.75, -2.0 + shown * 0.8)
		add_child(guard)
		shown += 1
	_sign("검 진열대 · 도감 %d / %d" % [meta.found.size(), data.swords.size()], at + Vector3(0, 2.6, 0))


func _build_gate() -> void:
	var at := Grid.cells_to_world(gate_at)
	var stone := VillageMaterials.get_mat("stone_wall", Color(0.42, 0.42, 0.44), 2.5)
	for x in [-2.4, 2.4]:
		var p := _box(Vector3(0.8, 5.0, 0.8), stone)
		p.position = at + Vector3(x, 2.5, 0)
		add_child(p)
	var beam := _box(Vector3(5.8, 0.8, 1.0), stone)
	beam.position = at + Vector3(0, 5.2, 0)
	add_child(beam)
	# 문 너머의 언덕: 꼭대기에 검이 잔뜩 꽂힌 큰 둔덕
	var hill := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 40.0
	sm.height = 36.0
	hill.mesh = sm
	hill.material_override = _mat(Color(0.2, 0.24, 0.17), 0.0, 1.0)
	hill.position = at + Vector3(0, -6.0, -70.0)
	add_child(hill)
	var steel := _mat(Color(0.7, 0.72, 0.76), 0.8, 0.3)
	var deco := RandomNumberGenerator.new()
	deco.seed = 11
	for i in 60:
		var a: float = deco.randf_range(-0.9, 0.9)
		var r: float = deco.randf_range(0.0, 16.0)
		var p := at + Vector3(sin(a) * r * 2.0, 0, -70.0 + cos(a) * r)
		p.y = -6.0 + sqrt(maxf(0.0, 40.0 * 40.0 - pow(p.x - at.x, 2) - pow(p.z - at.z + 70.0, 2))) * 0.45
		var s := _box(Vector3(0.15, 2.0, 0.3), steel)
		s.position = p + Vector3(0, 0.8, 0)
		s.rotation.z = deco.randf_range(-0.3, 0.3)
		add_child(s)
	_sign("언덕으로", at + Vector3(0, 6.2, 0.6))


func _build_houses() -> void:
	var deco := RandomNumberGenerator.new()
	deco.seed = 5
	var spots := [Vector2(27, 15), Vector2(30, 6), Vector2(4, 5), Vector2(4, 19), Vector2(29, 19), Vector2(21, 19)]
	for c in spots:
		var at := Grid.cells_to_world(c)
		var dk: float = deco.randf_range(0.0, 0.3)
		var w := _box(Vector3(5.0, 3.0, 4.0), VillageMaterials.get_mat("medieval_red_brick", Color(0.5, 0.44, 0.36).darkened(dk), 2.0, Color.WHITE.darkened(dk * 0.6)))
		w.position = at + Vector3(0, 1.5, 0)
		add_child(w)
		var roof := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(5.6, 1.8, 4.6)
		roof.mesh = pm
		roof.material_override = VillageMaterials.get_mat("roof", Color(0.3, 0.16, 0.13).darkened(deco.randf_range(0.0, 0.3)), 2.0)
		roof.position = at + Vector3(0, 3.9, 0)
		add_child(roof)
	for c in [Vector2(13, 11), Vector2(21, 11), Vector2(17, 7)]:
		var post := _box(Vector3(0.15, 2.6, 0.15), _mat(Color(0.2, 0.18, 0.16)))
		post.position = Grid.cells_to_world(c, 1.3)
		add_child(post)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.75, 0.45)
		lamp.omni_range = 7.0
		lamp.light_energy = 1.0
		lamp.position = Grid.cells_to_world(c, 2.7)
		add_child(lamp)


func _sign(t: String, at: Vector3) -> void:
	var l := Label3D.new()
	l.text = t
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 56
	l.pixel_size = 0.012
	l.outline_size = 12
	l.position = at
	add_child(l)


static func _box(size: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	return mi


static func _mat(c: Color, metal: float = 0.0, rough: float = 0.8, glow: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	if glow:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 1.2
	return m
