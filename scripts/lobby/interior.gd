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
var _t: float = 0.0


## 방을 짓는다(트리에 넣은 뒤).
func build(p_kind: StringName) -> void:
	kind = p_kind
	var stone_walls: bool = kind == &"shrine" or kind == &"smithy" or kind == &"forge"
	var wall_m: Material = VillageBuilder.stone() if stone_walls else VillageBuilder.planks()
	var floor_m: Material = VillageBuilder.stone() if kind == &"shrine" else VillageBuilder.planks()
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
	cam.look_at_from_position(to_global(Vector3(0.6, 1.62, D / 2.0 - 0.7)), to_global(Vector3(-0.1, 1.3, -1.2)))
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


func _process(delta: float) -> void:
	_t += delta
	if not _npc_P.is_empty():
		EventArt.breathe(_npc_P, _t)
		VillageProps.talk(_npc_P, _t)


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
