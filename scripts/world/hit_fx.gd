class_name HitFx
extends Node3D
## 맞힌 자리의 꾸밈: 튀는 피, 땅에 남는 핏자국, 유령을 벨 때 흩어지는 빛 조각.
## 규칙과 상관없는 꾸밈이라 랜덤은 이 노드의 것을 쓴다. 에셋 없이 기본 도형으로 그린다.

@export var blood_color: Color = Color(0.45, 0.02, 0.03)
@export var splat_color: Color = Color(0.16, 0.01, 0.01, 0.85)
@export var wisp_color: Color = Color(0.72, 0.84, 1.0)
## 핏방울 수(크게 벨 때는 두 배).
@export var drops: int = 28
@export var drop_speed: float = 4.5
## 땅의 핏자국이 남아 있는 시간과 최대 개수.
@export var splat_life: float = 9.0
@export var max_splats: int = 40

var _rng := RandomNumberGenerator.new()
var _drop_mesh := SphereMesh.new()
var _drop_mat := StandardMaterial3D.new()
var _wisp_mesh := QuadMesh.new()
var _wisp_mat := StandardMaterial3D.new()
var _splat_mesh := PlaneMesh.new()
var _splat_tex: GradientTexture2D
var _splats: Array[MeshInstance3D] = []


func _ready() -> void:
	_rng.randomize()
	_drop_mesh.radius = 0.05
	_drop_mesh.height = 0.1
	_drop_mesh.radial_segments = 6
	_drop_mesh.rings = 3
	_drop_mat.albedo_color = blood_color
	_drop_mat.roughness = 0.25
	_drop_mat.metallic_specular = 0.8
	_drop_mesh.material = _drop_mat
	_wisp_mesh.size = Vector2(0.12, 0.12)
	_wisp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wisp_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_wisp_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_wisp_mat.vertex_color_use_as_albedo = true
	_wisp_mat.albedo_texture = _soft_dot()
	_wisp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wisp_mesh.material = _wisp_mat
	_splat_mesh.size = Vector2.ONE
	_splat_tex = _soft_dot()


## 살을 벴을 때: dir 쪽(칼이 지나간 쪽)으로 피가 튀고 떨어진다.
func blood(at: Vector3, dir: Vector3, big: bool) -> void:
	var p := _burst(at, dir, drops * (2 if big else 1), drop_speed * (1.3 if big else 1.0))
	p.mesh = _drop_mesh
	p.gravity = Vector3(0, -16, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	if big or _rng.randf() < 0.6:
		splat(at + dir * _rng.randf_range(0.3, 0.9), big)


## 유령을 벴을 때: 창백한 빛 조각이 흩어지며 위로 사라진다.
func wisp(at: Vector3, dir: Vector3, big: bool) -> void:
	var p := _burst(at, dir, 16 * (2 if big else 1), 2.2)
	p.mesh = _wisp_mesh
	p.gravity = Vector3(0, 2.5, 0)
	p.lifetime = 0.8
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(wisp_color, 0.9), Color(wisp_color, 0.0)])
	p.color_ramp = g


## 땅에 남는 핏자국. 오래된 것부터 지운다.
func splat(at: Vector3, big: bool) -> void:
	var m := MeshInstance3D.new()
	m.mesh = _splat_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = splat_color
	mat.albedo_texture = _splat_tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.3
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var s: float = _rng.randf_range(0.5, 1.0) * (1.6 if big else 1.0)
	m.scale = Vector3(s * _rng.randf_range(0.7, 1.3), 1.0, s)
	m.rotation.y = _rng.randf() * TAU
	add_child(m)
	m.global_position = Vector3(at.x, 0.02 + 0.001 * _splats.size(), at.z)
	_splats.append(m)
	if _splats.size() > max_splats:
		_splats.pop_front().queue_free()
	var tw := create_tween()
	tw.tween_interval(splat_life)
	tw.tween_property(mat, "albedo_color:a", 0.0, 2.0)
	tw.tween_callback(func() -> void:
		_splats.erase(m)
		m.queue_free())


func _burst(at: Vector3, dir: Vector3, amount: int, speed: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = maxi(1, amount)
	p.lifetime = 0.7
	p.explosiveness = 0.95
	p.randomness = 0.5
	var d := (Vector3(dir.x, 0, dir.z).normalized() + Vector3(0, 0.6, 0)).normalized()
	p.direction = d
	p.spread = 38.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.12
	p.local_coords = false
	add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)
	return p


## 가운데가 진하고 가장자리로 사라지는 둥근 점.
static func _soft_dot() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.75), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t
