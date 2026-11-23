class_name Interior
extends Node3D
## 건물 안(2026-11-21 사용자: "상호작용할 때 건물 안으로 들어가서 대화하는 느낌"). 마을 밖 멀리(서쪽 빈 땅)에 방을 하나씩 지어 두고,
## 들어가면 문 쪽 카메라로 바꿔 안에 선 사람과 마주 본다. 방은 바닥·네 벽·천장·들보에 종류마다 다른 살림과 따뜻한 불빛.
## kind: forge(대장간: 화덕·모루·연장), shrine(성소: 제단·촛불·바랜 천), storage(검 보관집: 벽마다 검집 걸이·계산대),
## house(집: 화덕·식탁·침상·선반), smithy(풀무간: 용광로·모루·쇳덩이). 세계에 글자는 없다.

## 방 너비 × 깊이 × 높이(m). 사람은 안쪽(-Z), 카메라는 문 쪽(+Z).
const W: float = 8.0
const D: float = 7.0
const H: float = 3.4

var kind: StringName = &"house"
var cam: Camera3D = null
var _npc: Node3D = null
var _npc_P: Dictionary = {}
var _pray: bool = false
var _t: float = 0.0
## 대장간 연출(2026-11-24 사용자: "대장간 연출이 직관적이지 않다"): 모루 위의 검집 검, 망치질마다 사람이 내리치고 불똥이 튀며
## 모루가 달아오른다. 결과에 성공은 등급 빛이 솟고 불똥이 크게 터지며, 실패는 잿빛 먼지, 내려가면 금 가는 소리와 떨어지는 불똥.
const ANVIL_TOP := Vector3(0.3, 0.84, -0.3)
## 사람이 망치를 내리치는 동작: 칼 휘두르기(Sword_Attack)를 STRIKE_FROM초부터 틀면 치켜들었다가 IMPACT초 뒤에 모루에 닿는다.
## 그동안(STRIKE_TIME) 말하는 몸짓을 하지 않는다. 불똥·달아오름·흔들림·소리는 닿는 때에.
const STRIKE_FROM: float = 0.35
const IMPACT: float = 0.3
const STRIKE_TIME: float = 0.7
var _anvil_sword: Node3D = null
var _heat: OmniLight3D = null
var _strike_left: float = 0.0
var _shake: float = 0.0
var _cam_base := Transform3D.IDENTITY
var _rng := RandomNumberGenerator.new()


## 방을 짓는다(트리에 넣은 뒤).
func build(p_kind: StringName) -> void:
	kind = p_kind
	var stone_walls: bool = kind == &"shrine" or kind == &"smithy" or kind == &"forge"
	var wall_m: Material = VillageBuilder.inner_stone() if stone_walls else VillageBuilder.planks()
	var floor_m: Material = VillageBuilder.inner_stone() if kind == &"shrine" else VillageBuilder.floor_boards()
	VillageBuilder.box(self, Vector3(W, 0.2, D), Vector3(0, -0.1, 0), floor_m)
	VillageBuilder.box(self, Vector3(W, 0.2, D), Vector3(0, H + 0.1, 0), VillageBuilder.timber())
	VillageBuilder.box(self, Vector3(W, H, 0.3), Vector3(0, H / 2.0, -D / 2.0), wall_m)
	VillageBuilder.box(self, Vector3(W, H, 0.3), Vector3(0, H / 2.0, D / 2.0), wall_m)
	for sx in [-1.0, 1.0]:
		VillageBuilder.box(self, Vector3(0.3, H, D), Vector3(sx * W / 2.0, H / 2.0, 0), wall_m)
	for k in 4:   # 들보
		VillageBuilder.box(self, Vector3(W, 0.22, 0.24), Vector3(0, H - 0.12, -D / 2.0 + 0.9 + k * 1.7), VillageBuilder.timber())
	match kind:
		&"forge", &"smithy":
			_smithy(kind == &"smithy")
		&"shrine":
			_shrine()
		&"storage":
			_storage()
		_:
			_house()
	cam = Camera3D.new()
	cam.fov = 58.0
	cam.attributes = CameraAttributesPractical.new()
	add_child(cam)
	# 대장간은 모루가 대사 띠 위로 보이게 조금 내려다본다
	var look_y: float = 1.05 if kind == &"forge" else 1.3
	cam.look_at_from_position(to_global(Vector3(0.6, 1.62, D / 2.0 - 0.7)), to_global(Vector3(-0.1, look_y, -1.2)))
	_cam_base = cam.transform
	# 방을 고루 밝히는 약한 빛(위)
	_light(Vector3(0, H - 0.4, 0.5), Color(1.0, 0.78, 0.55), 0.5, 9.0)


## 마주 설 사람(look: VillageProps.LOOKS). 빈 이름이면 아무도 없다(빈 집).
func set_npc(look: StringName) -> void:
	if _npc:
		_npc.queue_free()
		_npc = null
		_npc_P = {}
	if look == &"":
		return
	_npc = Node3D.new()
	add_child(_npc)
	_npc.position = Vector3(-0.1, 0.0, -1.4)
	_npc.rotation.y = PI   # 문 쪽(+Z)을 본다(사람 몸은 -Z를 본다)
	_npc_P = VillageProps.villager(look, _npc)
	_pray = kind == &"shrine"
	if kind == &"forge":
		var m: NpcModel = _npc_P.get("npc")
		if m:
			m.hold(_hammer_mesh())   # 대장장이는 망치를 쥐고 있다


func _process(delta: float) -> void:
	_t += delta
	_strike_left = maxf(0.0, _strike_left - delta)
	if not _npc_P.is_empty():
		EventArt.breathe(_npc_P, _t)
		if _pray:
			VillageProps.pose(_npc_P, "pray")   # 성소지기는 무릎 꿇고 빈다
		elif _strike_left <= 0.0:
			VillageProps.talk(_npc_P, _t)
	if _heat:
		_heat.light_energy = lerpf(_heat.light_energy, 0.0, 1.0 - exp(-2.5 * delta))
	if cam and _shake > 0.001:
		_shake = lerpf(_shake, 0.0, 1.0 - exp(-14.0 * delta))
		var o := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0.0) * _shake * 0.05
		cam.transform = Transform3D(_cam_base.basis, _cam_base.origin + _cam_base.basis * o)
	elif cam and _shake > 0.0:
		_shake = 0.0
		cam.transform = _cam_base


# ---------------------------------------------------------------- 대장간 연출

## 모루 윗면의 세계 위치(소리 자리).
func anvil_world() -> Vector3:
	return to_global(ANVIL_TOP)


## 모루 위에 검집의 검을 눕힌다(없으면 비운다).
func show_sword(s: Sword, grades: GradeTable) -> void:
	if _anvil_sword:
		_anvil_sword.queue_free()
		_anvil_sword = null
	if s == null:
		return
	_anvil_sword = Node3D.new()
	_anvil_sword.position = ANVIL_TOP + Vector3(0.0, 0.015, 0.02)
	add_child(_anvil_sword)
	var m := SwordModel.for_sword(s, grades)
	m.rotation = Vector3(PI / 2.0, 0.0, -PI / 2.0)
	m.position = Vector3(-0.35, 0.0, 0.0)
	m.scale = Vector3.ONE * 0.85
	_anvil_sword.add_child(m)


## 망치를 한 번 내리친다(step 1~3, 셀수록 세게): 사람이 내리치고 모루에서 불똥, 모루가 달아오르고 방이 조금 흔들린다.
func hammer(step: int) -> void:
	var m: NpcModel = _npc_P.get("npc")
	if m:
		m.strike(STRIKE_FROM)
		_strike_left = STRIKE_TIME
		await get_tree().create_timer(IMPACT).timeout
	_ensure_heat()
	_heat.light_color = Color(1.0, 0.55, 0.22)
	_heat.light_energy = 2.0 + 1.0 * step
	_sparks(14 + 8 * step, Color(1.0, 0.62, 0.25), 2.5 + 0.6 * step, 0.55)
	_shake = 0.6 + 0.3 * step


## 결과: ok(성공)·dropped(내려감). big이면 더 크게. col은 검의 등급 빛.
func forged(ok: bool, dropped: bool, big: bool, col: Color) -> void:
	_ensure_heat()
	if ok:
		_heat.light_color = col.lerp(Color(1.0, 0.8, 0.5), 0.35)
		_heat.light_energy = 9.0 if big else 6.0
		_sparks(70 if big else 44, col.lerp(Color(1.0, 0.75, 0.35), 0.5), 5.5 if big else 4.2, 0.9)
		_rise(col)
		_shake = 1.6 if big else 1.0
	else:
		_heat.light_color = Color(0.55, 0.5, 0.45)
		_heat.light_energy = 1.2
		_smoke()
		if dropped:
			_sparks(18, Color(0.85, 0.4, 0.2), 1.2, 0.5, true)
			_shake = 0.8


func _ensure_heat() -> void:
	if _heat:
		return
	_heat = OmniLight3D.new()
	_heat.omni_range = 3.2
	_heat.light_energy = 0.0
	_heat.position = ANVIL_TOP + Vector3(0.0, 0.35, 0.25)
	add_child(_heat)


## 모루 위에서 불똥이 튄다. down이면 힘없이 흘러내린다(실패해서 내려갔을 때).
func _sparks(n: int, c: Color, speed: float, life: float, down: bool = false) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = n
	p.lifetime = life
	p.direction = Vector3(0, 1, 0.3)
	p.spread = 20.0 if down else 65.0
	p.initial_velocity_min = speed * (0.3 if down else 0.5)
	p.initial_velocity_max = speed * (0.6 if down else 1.2)
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.mesh = _spark_mesh(0.008)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.4, 1.2, 1.0))
	ramp.set_color(1, Color(c, 0.0))
	p.color_ramp = ramp
	p.position = ANVIL_TOP + Vector3(0.0, 0.05, 0.0)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)


## 성공: 모루 위로 등급 빛이 한 줄기 솟았다 사그라든다(빛 기둥 대신 낮게 깔린 불티 기둥).
func _rise(col: Color) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.4
	p.amount = 40
	p.lifetime = 1.4
	p.direction = Vector3.UP
	p.spread = 10.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.8
	p.gravity = Vector3(0, 0.4, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.5, 0.02, 0.08)
	p.mesh = _spark_mesh(0.011)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(col.lerp(Color.WHITE, 0.4), 0.0))
	ramp.add_point(0.15, col.lerp(Color.WHITE, 0.3))
	ramp.set_color(ramp.get_point_count() - 1, Color(col, 0.0))
	p.color_ramp = ramp
	p.position = ANVIL_TOP + Vector3(0.0, 0.05, 0.0)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


## 실패: 모루에서 잿빛 김이 피어오른다.
func _smoke() -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.6
	p.amount = 16
	p.lifetime = 1.6
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0, 0.25, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var q := QuadMesh.new()
	q.size = Vector2(0.3, 0.3)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.mesh = q
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.5, 0.48, 0.45, 0.0))
	ramp.add_point(0.2, Color(0.5, 0.48, 0.45, 0.35))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.4, 0.38, 0.36, 0.0))
	p.color_ramp = ramp
	p.position = ANVIL_TOP + Vector3(0.0, 0.1, 0.0)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(2.2).timeout.connect(p.queue_free)


## 불똥 하나(둥근 작은 알, 빛을 안 받고 더해 그린다. 색은 입자 색).
func _spark_mesh(r: float) -> Mesh:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 6
	sm.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	sm.material = m
	return sm


## 대장장이의 망치(나무 자루 + 쇠 머리). 손뼈에 단다.
func _hammer_mesh() -> Node3D:
	var h := Node3D.new()
	var wood := VillageBuilder.timber()
	var iron := VillageBuilder.plain(Color(0.2, 0.2, 0.21), 0.45, 0.85)
	VillageBuilder.cyl(h, 0.018, 0.022, 0.42, Vector3(0.0, 0.12, 0.0), wood, 8)
	VillageBuilder.box(h, Vector3(0.16, 0.07, 0.07), Vector3(0.0, 0.32, 0.0), iron)
	return h


func _light(at: Vector3, c: Color, e: float, r: float) -> void:
	var o := OmniLight3D.new()
	o.light_color = c
	o.light_energy = e
	o.omni_range = r
	o.position = at
	add_child(o)


func _smithy(furnace: bool) -> void:
	var st := VillageBuilder.stone()
	var coal := VillageBuilder.glow(Color(1.0, 0.36, 0.1), 3.0)
	# 안쪽 벽에 화덕(또는 용광로)과 빛
	if furnace:
		VillageBuilder.box(self, Vector3(2.0, 2.4, 1.4), Vector3(-2.2, 1.2, -D / 2.0 + 0.85), st)
		VillageBuilder.box(self, Vector3(0.9, 0.7, 0.1), Vector3(-2.2, 0.8, -D / 2.0 + 1.56), coal)
	else:
		VillageBuilder.box(self, Vector3(2.4, 0.9, 1.3), Vector3(-2.0, 0.45, -D / 2.0 + 0.8), st)
		VillageBuilder.box(self, Vector3(1.9, 0.1, 0.9), Vector3(-2.0, 0.92, -D / 2.0 + 0.8), coal)
		VillageBuilder.box(self, Vector3(1.6, 1.6, 0.8), Vector3(-2.0, 2.6, -D / 2.0 + 0.55), st)   # 갓
	_light(Vector3(-2.1, 1.2, -D / 2.0 + 1.7), Color(1.0, 0.5, 0.2), 2.2, 7.0)
	# 모루(사람 앞)
	var iron := VillageBuilder.plain(Color(0.18, 0.18, 0.19), 0.45, 0.85)
	VillageBuilder.cyl(self, 0.32, 0.38, 0.6, Vector3(0.3, 0.3, -0.3), VillageBuilder.bark(), 10)
	VillageBuilder.box(self, Vector3(0.8, 0.24, 0.34), Vector3(0.3, 0.72, -0.3), iron)
	VillageBuilder.box(self, Vector3(0.26, 0.16, 0.2), Vector3(0.78, 0.72, -0.3), iron)
	# 벽의 연장들과 칼날 감
	var wood := VillageBuilder.timber()
	VillageBuilder.box(self, Vector3(2.6, 0.1, 0.1), Vector3(1.8, 2.1, -D / 2.0 + 0.2), wood)
	for k in 6:
		var x: float = 0.8 + k * 0.4
		VillageBuilder.box(self, Vector3(0.05, 0.6, 0.04), Vector3(x, 1.75, -D / 2.0 + 0.24), wood)
		VillageBuilder.box(self, Vector3(0.16, 0.1, 0.08), Vector3(x, 1.45, -D / 2.0 + 0.24), iron)
	VillageBuilder.box(self, Vector3(1.6, 0.1, 0.8), Vector3(2.6, 0.85, -0.8), wood)   # 탁자
	for sx in [-0.7, 0.7]:
		for sz in [-0.3, 0.3]:
			VillageBuilder.box(self, Vector3(0.08, 0.85, 0.08), Vector3(2.6 + sx, 0.42, -0.8 + sz), wood)
	for k in 4:
		VillageBuilder.box(self, Vector3(0.06, 0.02, 0.95), Vector3(2.2 + k * 0.25, 0.92, -0.8), VillageBuilder.plain(Color(0.5, 0.5, 0.52), 0.35, 0.9), Vector3(0, 0.1 * k, 0))
	VillageBuilder.cyl(self, 0.32, 0.3, 0.7, Vector3(-3.2, 0.35, 0.8), VillageBuilder.bark(), 12)   # 물통
	if furnace:
		for k in 5:   # 쌓인 쇳덩이
			VillageBuilder.box(self, Vector3(0.4, 0.14, 0.2), Vector3(2.9, 0.07 + (k / 2) * 0.14, 1.6 + (k % 2) * 0.22), iron)


func _shrine() -> void:
	var st := VillageBuilder.stone()
	VillageBuilder.box(self, Vector3(2.4, 1.0, 1.0), Vector3(0, 0.5, -D / 2.0 + 0.9), st)   # 제단
	VillageBuilder.box(self, Vector3(2.6, 0.12, 1.1), Vector3(0, 1.06, -D / 2.0 + 0.9), VillageBuilder.plain(Color(0.4, 0.38, 0.35), 0.9))
	var flame := VillageBuilder.glow(Color(1.0, 0.72, 0.35), 3.0)
	var wax := VillageBuilder.plain(Color(0.86, 0.82, 0.72), 0.8)
	for k in 7:
		var x: float = -1.0 + k * 0.33
		var h: float = 0.2 + 0.08 * float((k * 5) % 3)
		VillageBuilder.cyl(self, 0.035, 0.04, h, Vector3(x, 1.12 + h / 2.0, -D / 2.0 + 0.75 + 0.1 * (k % 2)), wax, 8)
		VillageBuilder.ball(self, 0.03, Vector3(x, 1.14 + h + 0.04, -D / 2.0 + 0.75 + 0.1 * (k % 2)), flame, Vector3(1, 1.6, 1))
	_light(Vector3(0, 1.6, -D / 2.0 + 1.2), Color(1.0, 0.66, 0.34), 1.8, 7.0)
	var cloth := VillageBuilder.plain(Color(0.28, 0.06, 0.05), 1.0)
	for sx in [-1.0, 1.0]:   # 바랜 붉은 천
		VillageBuilder.box(self, Vector3(0.9, 2.2, 0.04), Vector3(sx * 2.4, H - 1.4, -D / 2.0 + 0.18), cloth)
	# 꽂힌 옛 검 하나(제단 위 가운데)
	VillageBuilder.box(self, Vector3(0.05, 1.0, 0.02), Vector3(0, 1.62, -D / 2.0 + 0.95), VillageBuilder.plain(Color(0.55, 0.55, 0.58), 0.35, 0.9))
	VillageBuilder.box(self, Vector3(0.32, 0.04, 0.05), Vector3(0, 2.1, -D / 2.0 + 0.95), VillageBuilder.plain(Color(0.4, 0.36, 0.3), 0.5, 0.8))
	for sx in [-1.0, 1.0]:   # 긴 의자
		VillageBuilder.box(self, Vector3(1.8, 0.1, 0.45), Vector3(sx * 1.7, 0.45, 1.0), VillageBuilder.timber())
		VillageBuilder.box(self, Vector3(1.8, 0.45, 0.08), Vector3(sx * 1.7, 0.22, 1.0), VillageBuilder.timber())


func _storage() -> void:
	var wood := VillageBuilder.timber()
	var leather := VillageBuilder.plain(Color(0.17, 0.09, 0.05), 0.7)
	var iron := VillageBuilder.plain(Color(0.42, 0.4, 0.37), 0.45, 0.8)
	# 세 벽에 걸이와 걸린 검집
	for side in 3:
		for row in 2:
			var y: float = 1.2 + row * 1.15
			for k in 7:
				var t: float = -2.4 + k * 0.8
				var at: Vector3
				var yaw: float = 0.0
				if side == 0:
					at = Vector3(t, y, -D / 2.0 + 0.22)
				else:
					var sx: float = -1.0 if side == 1 else 1.0
					at = Vector3(sx * (W / 2.0 - 0.22), y, t * 0.8)
					yaw = PI / 2.0
				if (k + row + side) % 4 == 3:
					continue
				VillageBuilder.box(self, Vector3(0.09, 0.85, 0.05), at + Vector3(0, -0.4, 0), leather, Vector3(0, yaw, 0.05 * float(k % 2)))
				VillageBuilder.box(self, Vector3(0.24, 0.04, 0.05), at + Vector3(0, 0.05, 0), iron, Vector3(0, yaw, 0))
			if side == 0:
				VillageBuilder.box(self, Vector3(W - 1.0, 0.08, 0.1), Vector3(0, y + 0.12, -D / 2.0 + 0.2), wood)
	# 계산대
	VillageBuilder.box(self, Vector3(3.0, 1.0, 0.7), Vector3(0, 0.5, -0.6), VillageBuilder.planks())
	VillageBuilder.box(self, Vector3(3.2, 0.08, 0.8), Vector3(0, 1.04, -0.6), wood)
	VillageBuilder.box(self, Vector3(0.1, 0.9, 0.06), Vector3(0.9, 1.1, -0.6), leather, Vector3(0, 0, PI / 2.0 - 0.15))   # 계산대 위에 눕힌 검집
	VillageBuilder.lantern(self, Vector3(-1.6, 0.0, -0.9), 0.0, false)
	_light(Vector3(-1.0, 2.3, -0.5), Color(1.0, 0.7, 0.42), 1.3, 7.0)


func _house() -> void:
	var st := VillageBuilder.stone()
	var wood := VillageBuilder.timber()
	VillageBuilder.box(self, Vector3(1.8, 1.4, 0.9), Vector3(-2.4, 0.7, -D / 2.0 + 0.6), st)   # 화덕
	VillageBuilder.box(self, Vector3(1.0, 0.5, 0.2), Vector3(-2.4, 0.45, -D / 2.0 + 1.06), VillageBuilder.glow(Color(1.0, 0.42, 0.14), 2.0))
	VillageBuilder.box(self, Vector3(0.9, H - 1.4, 0.7), Vector3(-2.4, 1.4 + (H - 1.4) / 2.0, -D / 2.0 + 0.5), st)
	_light(Vector3(-2.3, 0.9, -D / 2.0 + 1.6), Color(1.0, 0.52, 0.24), 1.8, 7.0)
	VillageBuilder.box(self, Vector3(1.6, 0.08, 0.9), Vector3(0.6, 0.78, -0.2), wood)   # 식탁
	for sx in [-0.7, 0.7]:
		for sz in [-0.35, 0.35]:
			VillageBuilder.box(self, Vector3(0.08, 0.78, 0.08), Vector3(0.6 + sx, 0.39, -0.2 + sz), wood)
	VillageBuilder.cyl(self, 0.07, 0.09, 0.18, Vector3(0.4, 0.91, -0.2), VillageBuilder.plain(Color(0.32, 0.22, 0.14), 0.7), 8)   # 그릇
	VillageBuilder.cyl(self, 0.2, 0.2, 0.06, Vector3(0.9, 0.85, -0.1), VillageBuilder.plain(Color(0.45, 0.35, 0.22), 0.8), 12)
	for k in 2:   # 걸상
		VillageBuilder.cyl(self, 0.18, 0.18, 0.45, Vector3(0.0 + k * 1.3, 0.22, 0.55), wood, 8)
	VillageBuilder.box(self, Vector3(1.0, 0.45, 2.0), Vector3(2.9, 0.22, -2.2), wood)   # 침상
	VillageBuilder.box(self, Vector3(0.95, 0.12, 1.9), Vector3(2.9, 0.5, -2.2), VillageBuilder.plain(Color(0.36, 0.3, 0.22), 1.0))
	VillageBuilder.box(self, Vector3(1.6, 0.06, 0.35), Vector3(2.6, 1.8, -D / 2.0 + 0.22), wood)   # 선반
	for k in 4:
		VillageBuilder.cyl(self, 0.08, 0.1, 0.22, Vector3(2.0 + k * 0.38, 1.94, -D / 2.0 + 0.24), VillageBuilder.plain(Color(0.3 + 0.05 * k, 0.22, 0.14), 0.7), 8)
