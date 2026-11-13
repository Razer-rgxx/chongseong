class_name HiltView
extends Node3D
## 땅에 꽂힌 검 하나. 뽑는 동안 흔들리며 조금씩 올라온다. 모델이 들어오면 _build()만 바꾸면 된다.

@export var rise: float = 0.55
@export var jitter: float = 0.035

var hilt: Hilt
var rules: Rules
var _sword := Node3D.new()
var _hole := MeshInstance3D.new()
## 화면 흔들림 전용. 게임 규칙의 랜덤(Rules.rng)과 따로 둔다.
var _rng := RandomNumberGenerator.new()


func setup(r: Rules, h: Hilt) -> void:
	rules = r
	hilt = h


func _ready() -> void:
	position = Grid.cells_to_world(hilt.pos)
	_build()
	_sword.rotation.z = hilt.tilt
	_sword.rotation.y = hilt.tilt * 3.0
	add_child(_sword)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.22
	disc.bottom_radius = 0.22
	disc.height = 0.02
	_hole.mesh = disc
	_hole.material_override = _mat(Color(0.05, 0.04, 0.03))
	_hole.position.y = 0.01
	add_child(_hole)


func _process(_delta: float) -> void:
	if hilt.gone:
		_sword.visible = false
		return
	if rules.pull_hilt == hilt:
		var k: float = clampf(rules.pull_t / rules.pull_duration(), 0.0, 1.0)
		var j: float = jitter * (1.0 + rules.pull_steps * 1.2)
		_sword.position = Vector3(_rng.randf_range(-j, j), k * rise, _rng.randf_range(-j, j))
	else:
		_sword.position = Vector3.ZERO


func _build() -> void:
	var steel := _mat(Color(0.72, 0.76, 0.82), 0.8, 0.3)
	var blade := _box(Vector3(0.11, 1.0, 0.035), steel)
	blade.position.y = 0.3
	_sword.add_child(blade)
	var guard := _box(Vector3(0.46, 0.07, 0.09), _mat(Color(0.42, 0.35, 0.27), 0.4, 0.5))
	guard.position.y = 0.82
	_sword.add_child(guard)
	var grip := _box(Vector3(0.07, 0.34, 0.07), _mat(Color(0.23, 0.17, 0.12)))
	grip.position.y = 1.02
	_sword.add_child(grip)
	var pommel := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.06
	s.height = 0.12
	pommel.mesh = s
	pommel.material_override = guard.material_override
	pommel.position.y = 1.22
	_sword.add_child(pommel)


static func _box(size: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	return mi


static func _mat(c: Color, metal: float = 0.0, rough: float = 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m
