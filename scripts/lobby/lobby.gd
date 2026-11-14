extends Node3D
## 언덕 아래 마을(시작 장면). 걸어 다니며 들른다.
## 대장간: 모루 위에 검집의 검이 놓여 있고, 망치질로 검집을 강화한다. 성소: 축복. 검 진열대: 도감. 언덕 길: 판을 시작한다.
## 영주의 움직임은 언덕과 같은 Rules로 돌린다(검도 적도 없는 낮). 모양은 기본 도형이고, 모델이 들어오면 _build_*만 바꾼다.
## 세계에 글자를 띄우지 않는다(간판 없음). 무엇인지는 다가가면 아래 띠가 알려 준다.
## 집, 나무, 목책, 소품은 VillageBuilder가 짓는다. 마을 안의 건물과 소품은 _blockers로 막아 영주가 뚫고 지나가지 않게 한다
## (마을은 판이 아니라 꾸밈이라 규칙 밖, 화면 쪽에서 밀어낸다).

const LORD_SCENE: PackedScene = preload("res://scenes/lord/lord.tscn")
const RUN_PATH: String = "res://scenes/world/main.tscn"

## 들를 곳(칸 좌표). 마을 크기는 언덕 싸움터와 같다(RunData.arena_size).
@export var forge_at: Vector2 = Vector2(9.5, 8.0)
@export var shrine_at: Vector2 = Vector2(24.5, 8.0)
@export var rack_at: Vector2 = Vector2(9.0, 15.0)
@export var gate_at: Vector2 = Vector2(17.0, 2.5)
@export var reach: float = 2.0

## 들를 곳 앞에 섰을 때 아래 띠에 뜨는 말.
const PROMPTS: Dictionary = {"forge": "대장간에 들른다", "shrine": "성소에서 기도한다", "rack": "검 진열대를 본다", "gate": "언덕으로 오른다"}
@export var max_ticks_per_frame: int = 8

var data: GameData
var meta: Meta
var rules: Rules
var _acc: float = 0.0
var _want_dash: bool = false
var _lord: Node3D
var _anvil_sword := Node3D.new()
var _forge_light := OmniLight3D.new()
var _near: String = ""
## 영주가 들어갈 수 없는 곳(칸 단위). Rect2와 [가운데, 반지름] 원.
var _rects: Array[Rect2] = []
var _circles: Array = []
var _deco := RandomNumberGenerator.new()

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
	_deco.seed = 7
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
	_hud.forge_hit.connect(_on_hammer)
	_hud.forge_done.connect(_on_forged)
	_hud.closed.connect(func() -> void: _capture(true))
	_camera.target = Grid.cells_to_world(rules.lord.pos)
	_camera.yaw = 0.0
	_camera.snap()
	_sun.rotation_degrees = Vector3(-35.0, -60.0, 0.0)
	_refresh_anvil()
	_hud.area_title("언덕 아래 마을")
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
		rules.lord.pos = _push_out(rules.lord.pos)
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
	_hud.set_prompt("E", PROMPTS.get(_near, ""))
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
	_sfx.play(&"anvil", Grid.cells_to_world(forge_at, 1.0), -6.0 + 2.0 * step)
	_camera.add_shake(0.08 + 0.04 * step)
	_forge_light.light_energy = 6.0
	_hud.flash(Color(1, 0.7, 0.35), 0.08 + 0.03 * step, 0.2)


func _on_forged(r: Dictionary, big: bool) -> void:
	if r.ok:
		_sfx.play(&"anvil", Grid.cells_to_world(forge_at, 1.0), 4.0)
		_hud.flash(Color(1, 0.84, 0.42), 0.7 if big else 0.35, 1.4 if big else 0.6)
		_camera.add_shake(0.5 if big else 0.25)
	else:
		_sfx.play(&"break" if r.get("dropped", false) else &"thump", Grid.cells_to_world(forge_at, 1.0), -2.0)
		_hud.flash(Color(0.45, 0.48, 0.55), 0.25, 0.4)
	_refresh_anvil()
	_lord.set_sword(meta.sheath_sword(data), data.grades)


## 모루 위에 놓인 검: 검집의 검이 바뀌거나 강화되면 다시 만든다.
func _refresh_anvil() -> void:
	for c in _anvil_sword.get_children():
		c.queue_free()
	var s := meta.sheath_sword(data)
	if s == null:
		return
	var m := SwordModel.for_sword(s, data.grades)
	m.rotation = Vector3(PI / 2.0, 0, -PI / 2.0)
	m.position = Vector3(-0.2, 0.02, 0)
	_anvil_sword.add_child(m)


# ---------------------------------------------------------------- 마을 짓기

func _build_ground() -> void:
	var size := Vector2(Grid.size) * Grid.CELL
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(320.0, 320.0)
	ground.mesh = plane
	ground.material_override = VillageBuilder.grass()
	ground.position = Vector3(size.x / 2.0, 0.0, size.y / 2.0)
	add_child(ground)
	var dirt := VillageBuilder.dirt()
	# 남쪽에서 들어와 광장을 지나 북쪽 문으로, 문 너머 언덕까지 이어지는 흙길
	VillageBuilder.box(self, Vector3(5.0, 0.04, size.y + 40.0), Vector3(Grid.cells_to_world(Vector2(17, 0)).x, 0.02, size.y / 2.0 + 20.0), dirt)
	VillageBuilder.box(self, Vector3(4.0, 0.04, 70.0), Vector3(Grid.cells_to_world(Vector2(17, 0)).x, 0.02, -34.0), dirt)
	VillageBuilder.cyl(self, 11.0, 11.0, 0.05, Grid.cells_to_world(Vector2(17, 12), 0.025), dirt, 40)
	# 집 앞과 대장간 앞의 맨땅
	for c in [Vector2(9.5, 10), Vector2(24.5, 10), Vector2(6.5, 9.5), Vector2(31, 13), Vector2(12, 17.8), Vector2(22.5, 17.8), Vector2(10, 15)]:
		VillageBuilder.cyl(self, 2.6, 2.8, 0.05, Grid.cells_to_world(c, 0.02), dirt, 18)
	# 목책: 북쪽은 문 기둥에 이어지고, 남쪽은 길이 나가는 곳만 비운다
	var lines := [
		[Vector2(0.3, 2.5), Vector2(15.8, 2.5)], [Vector2(18.2, 2.5), Vector2(33.7, 2.5)],
		[Vector2(33.7, 2.5), Vector2(33.7, 21.7)], [Vector2(0.3, 2.5), Vector2(0.3, 21.7)],
		[Vector2(0.3, 21.7), Vector2(15.2, 21.7)], [Vector2(18.8, 21.7), Vector2(33.7, 21.7)],
	]
	for l in lines:
		VillageBuilder.palisade(self, Grid.cells_to_world(l[0]), Grid.cells_to_world(l[1]), _deco)
		_rects.append(Rect2(l[0], Vector2.ZERO).expand(l[1]).grow(0.35))
	_build_trees()


## 마을 안 몇 그루, 목책 밖은 숲. 북쪽 길과 남쪽 길은 언덕과 들판이 보이게 비운다.
func _build_trees() -> void:
	for c in [Vector2(1.8, 12.5), Vector2(32.3, 9.0), Vector2(32.4, 16.8), Vector2(26.8, 4.0), Vector2(13.3, 4.4), Vector2(1.8, 20.4), Vector2(32.4, 20.6)]:
		VillageBuilder.tree(self, Grid.cells_to_world(c), _deco, _deco.randf() < 0.5)
		_circles.append([c, 0.5])
	VillageBuilder.dead_tree(self, Grid.cells_to_world(Vector2(26.0, 16.6)), _deco)
	_circles.append([Vector2(26.0, 16.6), 0.4])
	var size := Vector2(Grid.size) * Grid.CELL
	var mid_x: float = size.x / 2.0
	var placed: int = 0
	while placed < 170:
		var p := Vector3(_deco.randf_range(-45.0, size.x + 45.0), 0.0, _deco.randf_range(-40.0, size.y + 45.0))
		var inside: bool = p.x > -2.5 and p.x < size.x + 2.5 and p.z > -2.5 and p.z < size.y + 2.5
		var north_view: bool = p.z < 0.0 and absf(p.x - mid_x) < 16.0 + (-p.z) * 0.35
		var south_road: bool = p.z > size.y and absf(p.x - mid_x) < 6.0
		if inside or north_view or south_road:
			continue
		if _deco.randf() < 0.08:
			VillageBuilder.dead_tree(self, p, _deco)
		else:
			VillageBuilder.tree(self, p, _deco, _deco.randf() < 0.7)
		placed += 1
	for i in 30:
		var side: int = _deco.randi() % 4
		var t: float = _deco.randf_range(1.5, 32.5)
		var c: Vector2 = [Vector2(t, 3.2), Vector2(t, 21.0), Vector2(1.0, 3.0 + t * 0.55), Vector2(33.0, 3.0 + t * 0.55)][side]
		if absf(c.x - 17.0) < 3.0:
			continue
		if _deco.randf() < 0.7:
			VillageBuilder.bush(self, Grid.cells_to_world(c), _deco)
		else:
			VillageBuilder.rock(self, Grid.cells_to_world(c), _deco, 0.8)


func _build_forge() -> void:
	var at := Grid.cells_to_world(forge_at)
	# 뒤의 대장장이 집과, 앞으로 내민 차양(모루와 화덕을 덮는다)
	var top := VillageBuilder.house(self, at + Vector3(0, 0, -1.6), 0.0, Vector2(7.0, 4.4), true, _deco)
	VillageBuilder.smoke(self, top, 1.6)
	var lean := VillageBuilder.box(self, Vector3(7.6, 0.16, 3.6), at + Vector3(0, 2.35, 2.2), VillageBuilder.roof())
	lean.rotation.x = 0.32
	for x in [-3.4, 3.4]:
		VillageBuilder.box(self, Vector3(0.2, 1.9, 0.2), at + Vector3(x, 0.95, 3.7), VillageBuilder.timber())
	VillageBuilder.box(self, Vector3(7.0, 0.2, 0.2), at + Vector3(0, 1.85, 3.7), VillageBuilder.timber())
	# 화덕 옆 물통, 장작, 숫돌, 벽에 기댄 칼들
	VillageBuilder.barrel(self, at + Vector3(-3.2, 0, 2.2), _deco)
	VillageBuilder.firewood(self, at + Vector3(3.0, 0, 1.3), PI / 2.0)
	VillageBuilder.cyl(self, 0.4, 0.4, 0.15, at + Vector3(2.0, 0.75, 2.8), VillageBuilder.stone(), 14).rotation.x = PI / 2.0
	VillageBuilder.box(self, Vector3(0.2, 0.7, 0.4), at + Vector3(2.0, 0.35, 2.8), VillageBuilder.timber())
	for i in 3:
		VillageBuilder.box(self, Vector3(0.06, 1.3, 0.12), at + Vector3(-0.8 + i * 0.35, 0.65, 0.75), _mat(Color(0.6, 0.62, 0.66), 0.8, 0.35), Vector3(0.18, 0, 0))
	_rects.append(Rect2(forge_at + Vector2(-1.85, -1.95), Vector2(3.7, 2.3)))
	_circles.append([forge_at + Vector2(0.3, 1.3), 0.55])
	_circles.append([forge_at + Vector2(-1.1, 0.8), 0.6])
	_circles.append([forge_at + Vector2(-1.6, 1.1), 0.35])
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
	# 계단과 촛불
	VillageBuilder.box(self, Vector3(4.8, 0.2, 4.8), at + Vector3(0, 0.05, 0), stone)
	for p in [Vector3(-1.2, 0.5, 1.4), Vector3(1.2, 0.5, 1.4), Vector3(-1.3, 0.5, -1.3), Vector3(1.3, 0.5, -1.2)]:
		VillageBuilder.cyl(self, 0.05, 0.06, 0.25, at + p, VillageBuilder.plain(Color(0.85, 0.8, 0.7)), 8)
		VillageBuilder.ball(self, 0.04, at + p + Vector3(0, 0.17, 0), VillageBuilder.glow(Color(1.0, 0.7, 0.35), 4.0), Vector3(1, 1.6, 1))
	_rects.append(Rect2(shrine_at - Vector2(1.1, 1.1), Vector2(2.2, 2.2)))
	var light := OmniLight3D.new()
	light.light_color = Color(0.55, 0.8, 1.0)
	light.omni_range = 7.0
	light.light_energy = 1.4
	light.position = at + Vector3(0, 1.8, 0)
	add_child(light)


func _build_rack() -> void:
	var at := Grid.cells_to_world(rack_at)
	var wood := VillageMaterials.get_mat("raw_plank_wall", Color(0.36, 0.26, 0.17), 1.0, Color(0.75, 0.66, 0.58))
	var frame := _box(Vector3(0.5, 0.3, 5.0), wood)
	frame.position = at + Vector3(0, 0.15, 0)
	add_child(frame)
	var bar := _box(Vector3(0.2, 0.15, 5.0), wood)
	bar.position = at + Vector3(0, 1.4, 0)
	add_child(bar)
	# 진열대 위 작은 지붕
	for z in [-2.4, 2.4]:
		VillageBuilder.box(self, Vector3(0.14, 2.6, 0.14), at + Vector3(-0.4, 1.3, z), VillageBuilder.timber())
	VillageBuilder.box(self, Vector3(1.8, 0.12, 5.6), at + Vector3(0.1, 2.6, 0), VillageBuilder.roof(), Vector3(0, 0, -0.35))
	_rects.append(Rect2(rack_at - Vector2(0.4, 1.3), Vector2(0.7, 2.6)))
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
		var first: SwordData = null
		for i in data.swords_by_grade[g]:
			if meta.has_found(data.swords[i].id):
				first = data.swords[i]
				break
		var m := SwordModel.make(data.forms[first.form], g, first.id, data.grades.colors[g])
		m.position = at + Vector3(0, 0.5, -2.0 + shown * 0.8)
		m.rotation.x = 0.12
		add_child(m)
		shown += 1


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
	for x in [-2.4, 2.4]:
		VillageBuilder.torch(self, at + Vector3(x, 2.8, 0.55))
		_circles.append([gate_at + Vector2(x / Grid.CELL, 0), 0.45])
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


## 집(가운데 칸, 너비 × 깊이 m, 앞이 보는 쪽, 2층인지), 광장의 우물과 장터, 등불, 소품.
func _build_houses() -> void:
	var houses := [
		[Vector2(4.0, 9.5), Vector2(6, 5), Vector2(1, 0), true],
		[Vector2(3.8, 15.8), Vector2(6, 5), Vector2(1, 0), false],
		[Vector2(3.8, 4.8), Vector2(6, 4.6), Vector2(1, 0), false],
		[Vector2(5.0, 19.6), Vector2(7, 5), Vector2(0, -1), true],
		[Vector2(12.0, 19.6), Vector2(6, 5), Vector2(0, -1), false],
		[Vector2(22.5, 19.6), Vector2(6, 5), Vector2(0, -1), true],
		[Vector2(29.0, 19.4), Vector2(7, 5), Vector2(0, -1), false],
		[Vector2(30.5, 13.0), Vector2(6, 5), Vector2(-1, 0), true],
		[Vector2(30.3, 5.6), Vector2(6, 5), Vector2(-1, 0), true],
	]
	for h in houses:
		var c: Vector2 = h[0]
		var sz: Vector2 = h[1]
		var dir: Vector2 = h[2]
		var top := VillageBuilder.house(self, Grid.cells_to_world(c), VillageBuilder.facing_to(dir), sz, h[3], _deco)
		if _deco.randf() < 0.7:
			VillageBuilder.smoke(self, top, 1.0)
		var half := (Vector2(sz.x, sz.y) if dir.y != 0.0 else Vector2(sz.y, sz.x)) / Grid.CELL / 2.0
		_rects.append(Rect2(c - half - Vector2(0.15, 0.15), half * 2.0 + Vector2(0.3, 0.3)))
	# 광장: 우물, 의자, 장터 좌판 둘
	var well_at := Vector2(21.0, 13.6)
	VillageBuilder.well(self, Grid.cells_to_world(well_at))
	_circles.append([well_at, 0.75])
	VillageBuilder.bench(self, Grid.cells_to_world(Vector2(21.0, 15.4)), 0.0)
	VillageBuilder.bench(self, Grid.cells_to_world(Vector2(22.8, 13.6)), -PI / 2.0)
	VillageBuilder.stall(self, Grid.cells_to_world(Vector2(13.0, 14.0)), PI / 2.0, Color(0.3, 0.09, 0.08), _deco)
	_rects.append(Rect2(Vector2(12.4, 13.2), Vector2(1.0, 1.6)))
	VillageBuilder.stall(self, Grid.cells_to_world(Vector2(21.4, 9.6)), -PI / 2.0, Color(0.16, 0.19, 0.24), _deco)
	_rects.append(Rect2(Vector2(20.9, 8.8), Vector2(1.0, 1.6)))
	# 등불(빛은 몇 개만: 빛이 많으면 느려진다)
	var lamps := [[Vector2(15.0, 5.5), true], [Vector2(19.0, 5.5), false], [Vector2(11.5, 11.5), true], [Vector2(22.6, 11.0), false], [Vector2(15.0, 18.0), true], [Vector2(19.0, 18.0), false]]
	for l in lamps:
		var c: Vector2 = l[0]
		VillageBuilder.lantern(self, Grid.cells_to_world(c), VillageBuilder.facing_to(Vector2(17, 12) - c), l[1])
		_circles.append([c, 0.25])
	# 집 둘레의 통, 상자, 건초, 장작
	for p in [Vector2(7.6, 11.6), Vector2(7.9, 12.2), Vector2(26.9, 21.0), Vector2(32.6, 11.0), Vector2(14.8, 20.6), Vector2(7.3, 17.3)]:
		VillageBuilder.barrel(self, Grid.cells_to_world(p), _deco)
		_circles.append([p, 0.3])
	for p in [Vector2(8.3, 11.9), Vector2(25.6, 20.7), Vector2(15.0, 21.0), Vector2(33.0, 7.8)]:
		VillageBuilder.crate(self, Grid.cells_to_world(p), _deco, _deco.randf_range(0.7, 0.95))
		_circles.append([p, 0.4])
	for p in [Vector2(26.2, 17.6), Vector2(27.2, 17.2), Vector2(33.0, 18.0)]:
		VillageBuilder.hay(self, Grid.cells_to_world(p), _deco)
		_circles.append([p, 0.45])
	VillageBuilder.firewood(self, Grid.cells_to_world(Vector2(6.4, 7.0)), PI / 2.0)
	_circles.append([Vector2(6.4, 7.0), 0.5])


## 영주를 막힌 곳 밖으로 민다(가장 가까운 가장자리로).
func _push_out(p: Vector2) -> Vector2:
	var r: float = 0.3
	for c in _circles:
		var d: Vector2 = p - c[0]
		var min_d: float = c[1] + r
		if d.length() < min_d:
			p = c[0] + (d.normalized() if d.length() > 0.001 else Vector2.DOWN) * min_d
	for rect in _rects:
		var g := rect.grow(r)
		if g.has_point(p):
			var left: float = p.x - g.position.x
			var right: float = g.end.x - p.x
			var up: float = p.y - g.position.y
			var down: float = g.end.y - p.y
			var m: float = minf(minf(left, right), minf(up, down))
			if m == left:
				p.x = g.position.x
			elif m == right:
				p.x = g.end.x
			elif m == up:
				p.y = g.position.y
			else:
				p.y = g.end.y
	return p


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
