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
	# 칼이 박힌 자리의 흙 둔덕(땅 질감을 어둡게)
	var mound := SphereMesh.new()
	mound.radius = 0.32
	mound.height = 0.16
	mound.radial_segments = 12
	mound.rings = 4
	_hole.mesh = mound
	_hole.material_override = _dirt()
	_hole.position.y = -0.02
	_hole.scale = Vector3(1.0, 1.0, 0.85)
	_hole.rotation.y = float(hilt.id) * 1.7
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


## 뽑기 전에는 무엇인지 모르니 모두 흔함(녹슨 쇠)의 모습으로, 형태와 생김새만 자리마다 다르게.
## 칼날이 땅에 박히도록 뒤집어 세운다(코등이가 무릎 높이).
func _build() -> void:
	var forms: Array[FormData] = rules.data.forms
	var m := SwordModel.make(forms[hilt.id % forms.size()], 0, hilt.id * 31 + 7, Color.WHITE)
	m.rotation.x = PI
	m.position.y = 0.55 + m.grip_length * 0.3
	_sword.add_child(m)


static var _dirt_mat: StandardMaterial3D = null


static func _dirt() -> StandardMaterial3D:
	if _dirt_mat:
		return _dirt_mat
	var m := StandardMaterial3D.new()
	var base: String = "res://assets/hill/forest_ground_04/forest_ground_04"
	if ResourceLoader.exists(base + "_diff.jpg"):
		m.albedo_texture = load(base + "_diff.jpg")
		m.albedo_color = Color(0.32, 0.29, 0.26)
		m.normal_enabled = true
		m.normal_texture = load(base + "_nor_gl.jpg")
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE / 1.5
	else:
		m.albedo_color = Color(0.1, 0.08, 0.06)
	m.roughness = 1.0
	_dirt_mat = m
	return m


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
