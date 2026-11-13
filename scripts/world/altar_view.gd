class_name AltarView
extends Node3D
## 숫돌 제단. 쓰기 전에는 윗면이 은은하게 빛난다. 모델이 들어오면 _ready()만 바꾸면 된다.

var altar: Altar
var _glow := OmniLight3D.new()
var _top_mat := StandardMaterial3D.new()
var _t: float = 0.0


func _ready() -> void:
	position = Grid.cells_to_world(altar.pos)
	var base := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(1.6, 0.9, 1.1)
	base.mesh = b
	base.material_override = VillageMaterials.get_mat("medieval_blocks_03", Color(0.36, 0.35, 0.33), 1.2, Color(0.8, 0.8, 0.8))
	base.position.y = 0.45
	add_child(base)
	var top := MeshInstance3D.new()
	var t := BoxMesh.new()
	t.size = Vector3(1.2, 0.12, 0.7)
	top.mesh = t
	_top_mat.albedo_color = Color(0.55, 0.52, 0.47)
	_top_mat.emission_enabled = true
	_top_mat.emission = Color(1.0, 0.84, 0.5)
	top.material_override = _top_mat
	top.position.y = 0.96
	add_child(top)
	_glow.light_color = Color(1.0, 0.8, 0.5)
	_glow.omni_range = 4.0
	_glow.position.y = 1.4
	add_child(_glow)


func _process(delta: float) -> void:
	_t += delta
	var k: float = 0.0 if altar.used else 0.6 + 0.4 * sin(_t * 3.0)
	_top_mat.emission_energy_multiplier = k * 1.5
	_glow.light_energy = k * 1.2
