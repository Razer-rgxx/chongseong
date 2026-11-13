class_name EnemyView
extends Node3D
## 적 하나. 종류마다 기본 도형으로 몸을 만들고(나중에 모델로 바꿔 끼운다), 규칙의 위치를 틱 사이로 이어 그린다.
## 눈은 스스로 빛나서 어두운 밤에도 보인다.

@export var flash_time: float = 0.09
@export var die_time: float = 0.25

var enemy: Enemy
var _mats: Array[StandardMaterial3D] = []
var _base: Array[Color] = []
var _flash: float = 0.0
var _dying: float = -1.0
var _body := Node3D.new()
var _t: float = 0.0


func setup(e: Enemy) -> void:
	enemy = e


func _ready() -> void:
	add_child(_body)
	var D := enemy.data
	var r: float = Grid.cells_to_meters(enemy.radius)
	match D.id:
		&"wolf":
			_build_wolf(r, D.color)
		&"giant", &"boss":
			_build_giant(r, D.color, D.boss)
		_:
			_build_wraith(r, D.color)
	if enemy.elite:
		# 정예: 발밑에 금빛 고리, 몸이 은은하게 빛난다
		var ring := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = r * 1.5
		t.outer_radius = r * 1.75
		ring.mesh = t
		ring.material_override = _mat(Color(1.0, 0.84, 0.42), true)
		ring.position.y = 0.05
		add_child(ring)
		for m in _mats:
			m.emission_enabled = true
			m.emission = Color(1.0, 0.8, 0.4)
			m.emission_energy_multiplier = 0.25
	position = Grid.cells_to_world(enemy.pos)


func hit() -> void:
	_flash = flash_time


func die() -> void:
	_dying = 0.0


## main이 매 프레임 부른다. 다 사라졌으면 true.
func draw(alpha: float, delta: float) -> bool:
	_t += delta
	if _dying >= 0.0:
		_dying += delta
		var k: float = _dying / die_time
		_body.scale = Vector3.ONE * maxf(0.01, 1.0 - k)
		_body.position.y = -k * 0.5
		return k >= 1.0
	position = Grid.cells_to_world(enemy.prev_pos.lerp(enemy.pos, alpha))
	rotation.y = atan2(-enemy.face.x, -enemy.face.y)
	if enemy.data.wraith:
		_body.position.y = 0.25 + sin(_t * 2.5 + enemy.id) * 0.12
	_flash -= delta
	var w: float = clampf(_flash / flash_time, 0.0, 1.0)
	for i in _mats.size():
		_mats[i].albedo_color = _base[i].lerp(Color.WHITE, w)
	return false


func _mat(c: Color, glow: bool = false, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 3.0
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		_mats.append(m)
		_base.append(m.albedo_color)
	return m


func _add(mesh: Mesh, m: Material, at: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	mi.rotation = rot
	_body.add_child(mi)
	return mi


func _eyes(at: Vector3, gap: float, size: float, c: Color) -> void:
	var s := SphereMesh.new()
	s.radius = size
	s.height = size * 2.0
	var m := _mat(c, true)
	_add(s, m, at + Vector3(-gap, 0, 0))
	_add(s, m, at + Vector3(gap, 0, 0))


func _build_wraith(r: float, c: Color) -> void:
	var cap := CapsuleMesh.new()
	cap.radius = r * 0.85
	cap.height = r * 3.4
	cap.radial_segments = 16
	var robe := _mat(c, false, 0.88)
	_add(cap, robe, Vector3(0, r * 1.7, 0))
	var hood := SphereMesh.new()
	hood.radius = r * 0.62
	hood.height = r * 1.2
	_add(hood, _mat(Color(0.1, 0.06, 0.18)), Vector3(0, r * 2.75, -r * 0.42))
	_eyes(Vector3(0, r * 2.8, -r * 0.95), r * 0.22, r * 0.09, Color(0.93, 0.9, 1.0))


func _build_wolf(r: float, c: Color) -> void:
	var body := BoxMesh.new()
	body.size = Vector3(r * 1.5, r * 1.3, r * 3.2)
	var m := _mat(c)
	_add(body, m, Vector3(0, r * 1.7, 0))
	var head := BoxMesh.new()
	head.size = Vector3(r * 1.2, r * 1.1, r * 1.3)
	_add(head, m, Vector3(0, r * 2.3, -r * 2.0))
	var dark := _mat(c.darkened(0.45))
	var leg := BoxMesh.new()
	leg.size = Vector3(r * 0.35, r * 1.2, r * 0.35)
	for p in [Vector3(-0.5, 0.6, -1.1), Vector3(0.5, 0.6, -1.1), Vector3(-0.5, 0.6, 1.1), Vector3(0.5, 0.6, 1.1)]:
		_add(leg, dark, p * r)
	var tail := BoxMesh.new()
	tail.size = Vector3(r * 0.3, r * 0.3, r * 1.3)
	_add(tail, dark, Vector3(0, r * 2.2, r * 2.0), Vector3(0.6, 0, 0))
	_eyes(Vector3(0, r * 2.45, -r * 2.66), r * 0.3, r * 0.12, Color(1.0, 0.85, 0.4))


func _build_giant(r: float, c: Color, boss: bool) -> void:
	r *= 0.75
	var m := _mat(c)
	var dark := _mat(c.darkened(0.5))
	var leg := BoxMesh.new()
	leg.size = Vector3(r * 0.55, r * 1.3, r * 0.55)
	_add(leg, dark, Vector3(-r * 0.4, r * 0.65, 0))
	_add(leg, dark, Vector3(r * 0.4, r * 0.65, 0))
	var torso := CapsuleMesh.new()
	torso.radius = r * 0.8
	torso.height = r * 2.6
	_add(torso, m, Vector3(0, r * 2.4, 0))
	var arm := CapsuleMesh.new()
	arm.radius = r * 0.25
	arm.height = r * 1.9
	_add(arm, dark, Vector3(-r * 1.0, r * 2.4, 0), Vector3(0, 0, 0.15))
	_add(arm, dark, Vector3(r * 1.0, r * 2.4, 0), Vector3(0, 0, -0.15))
	var head := SphereMesh.new()
	head.radius = r * 0.42
	head.height = r * 0.84
	_add(head, m, Vector3(0, r * 4.0, -r * 0.1))
	if boss:
		var horn := CylinderMesh.new()
		horn.top_radius = 0.0
		horn.bottom_radius = r * 0.12
		horn.height = r * 0.8
		var hm := _mat(Color(0.1, 0.02, 0.03))
		_add(horn, hm, Vector3(-r * 0.3, r * 4.5, 0), Vector3(0, 0, 0.5))
		_add(horn, hm, Vector3(r * 0.3, r * 4.5, 0), Vector3(0, 0, -0.5))
	_eyes(Vector3(0, r * 4.05, -r * 0.48), r * 0.15, r * 0.07, Color(1.0, 0.8, 0.35) if boss else Color(0.75, 0.9, 1.0))
