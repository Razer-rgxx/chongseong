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
## 맞은 자리 점광원 풀(docs/hit_juice.md): 빛마다 [남은 초, 처음 세기]를 같은 칸에 둔다.
var _lights: Array[OmniLight3D] = []
var _light_t: Array[float] = []
var _light_e: Array[float] = []
## 멈춤 프레임 동안 붙잡힌 알갱이: [CPUParticles3D, 지난 초, 붙잡는 초]
var _held: Array = []
var _spark_mesh := QuadMesh.new()
var _spark_mat := StandardMaterial3D.new()
var _shard_mesh := BoxMesh.new()
var _shard_mat := StandardMaterial3D.new()


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
	_spark_mesh.size = Vector2(0.05, 0.05)
	_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_spark_mat.vertex_color_use_as_albedo = true
	_spark_mat.albedo_color = Juice.SPARK_COLOR
	_spark_mesh.material = _spark_mat
	_shard_mesh.size = Vector3(0.035, 0.012, 0.06)
	_shard_mat.albedo_color = Color(0.32, 0.32, 0.35)
	_shard_mat.metallic = 0.8
	_shard_mat.roughness = 0.4
	_shard_mesh.material = _shard_mat
	if not Juice.web():
		for i in Juice.HIT_LIGHT_POOL:   # 웹판은 점광원을 아예 만들지 않는다(빛 하나마다 물체를 한 번 더 그린다)
			var l := OmniLight3D.new()
			l.light_color = Juice.FIRE_WARM
			l.omni_range = Juice.HIT_LIGHT_RANGE
			l.omni_attenuation = Juice.TORCH_ATTEN
			l.shadow_enabled = false
			l.light_energy = 0.0
			l.visible = false
			add_child(l)
			_lights.append(l)
			_light_t.append(0.0)
			_light_e.append(0.0)


func _process(delta: float) -> void:
	for i in _lights.size():
		if _light_t[i] > 0.0:
			_light_t[i] = maxf(0.0, _light_t[i] - delta)
			var k: float = _light_t[i] / Juice.HIT_LIGHT_TIME   # 1 → 0, 바로 켜지고 빠르게 꺼진다
			_lights[i].light_energy = _light_e[i] * k * k
			if _light_t[i] <= 0.0:
				_lights[i].visible = false
	for i in range(_held.size() - 1, -1, -1):
		var h: Array = _held[i]
		var p: CPUParticles3D = h[0]
		if not is_instance_valid(p):
			_held.remove_at(i)
			continue
		h[1] += delta
		var over: float = h[1] - float(h[2])
		p.speed_scale = Juice.HOLD_SPEED if over < 0.0 else lerpf(Juice.HOLD_SPEED, 1.0, clampf(over / Juice.HOLD_RELEASE, 0.0, 1.0))
		if over >= Juice.HOLD_RELEASE:
			_held.remove_at(i)


## 맞은 순간 0.1초쯤 켜졌다 꺼지는 따뜻한 점광원. 가장 오래된 빛을 돌려 쓴다.
func hit_light(at: Vector3, big: bool, scale: float = 1.0, color: Color = Juice.FIRE_WARM) -> void:
	if _lights.is_empty():
		return
	var best: int = 0
	for i in _lights.size():
		if _light_t[i] <= 0.0:
			best = i
			break
		if _light_t[i] < _light_t[best]:
			best = i
	var l: OmniLight3D = _lights[best]
	_light_e[best] = (Juice.HIT_LIGHT_ENERGY_BIG if big else Juice.HIT_LIGHT_ENERGY) * scale
	_light_t[best] = Juice.HIT_LIGHT_TIME
	l.light_color = color
	l.global_position = at + Vector3(0, 0.3, 0)   # 살짝 위: 땅과 벽이 같이 밝아진다
	l.light_energy = _light_e[best]
	l.visible = true


## 알갱이를 멈춤 프레임 동안 그 자리에 붙잡았다가 풀어 흩어지게 한다.
func _hold(p: CPUParticles3D, big: bool) -> void:
	var t: float = Juice.HOLD_TIME_BIG if big else Juice.HOLD_TIME
	p.speed_scale = Juice.HOLD_SPEED
	_held.append([p, 0.0, t])


func _amount(n: int) -> int:
	return maxi(1, int(n * Juice.WEB_KEEP)) if Juice.web() else n


## 갑옷 입은 적의 타격이면 불꽃·쇳조각을 더하고, 큰 타격·쓰러뜨림이면 카메라 화각을 조인다(장면의 _on_enemy_hit가 부른다).
func struck(e: Enemy, chest: Vector3, dir: Vector3, big: bool, camera: Node) -> void:
	if Juice.armored(e):
		sparks(chest, dir, big)
	if camera != null and camera.has_method("pinch"):
		if e.hp <= 0.0:
			camera.call("pinch", Juice.FOV_PINCH_FINISH)
		elif big:
			camera.call("pinch", Juice.FOV_PINCH_BIG)


## 짧은 주황 불꽃과 작은 쇳조각(칼과 쇠가 부딪힐 때, 갑옷 타격).
func sparks(at: Vector3, dir: Vector3, big: bool) -> void:
	var n: int = Juice.SPARK_COUNT_BIG if big else Juice.SPARK_COUNT
	var p := _burst(at, -Vector3(dir.x, 0, dir.z).normalized() * 0.5 + Vector3(0, 0.4, 0), _amount(n), 6.0)
	p.mesh = _spark_mesh
	p.lifetime = Juice.SPARK_LIFE
	p.gravity = Vector3(0, -9, 0)
	p.spread = 70.0
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1.0, 0.85, 0.5, 1.0), Color(Juice.SPARK_COLOR, 0.0)])
	p.color_ramp = g
	var q := _burst(at, dir + Vector3(0, 0.3, 0), _amount(Juice.SHARD_COUNT), 4.5)
	q.mesh = _shard_mesh
	q.lifetime = 0.55
	q.gravity = Vector3(0, -14, 0)
	q.angular_velocity_min = -540.0
	q.angular_velocity_max = 540.0
	hit_light(at, big, 0.8, Juice.SPARK_COLOR)


## 살을 벴을 때: dir 쪽(칼이 지나간 쪽)으로 피가 튀고 떨어진다.
func blood(at: Vector3, dir: Vector3, big: bool) -> void:
	var p := _burst(at, dir, _amount(drops * (2 if big else 1)), drop_speed * (1.3 if big else 1.0))
	p.mesh = _drop_mesh
	_hold(p, big)
	hit_light(at, big)
	p.gravity = Vector3(0, -16, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	if big or _rng.randf() < 0.6:
		splat(at + dir * _rng.randf_range(0.3, 0.9), big)


## 유령을 벴을 때: 창백한 빛 조각이 흩어지며 위로 사라진다.
func wisp(at: Vector3, dir: Vector3, big: bool) -> void:
	var p := _burst(at, dir, _amount(16 * (2 if big else 1)), 2.2)
	p.mesh = _wisp_mesh
	_hold(p, big)
	hit_light(at, big, 0.6)
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
