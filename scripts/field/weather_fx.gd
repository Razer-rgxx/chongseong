class_name WeatherFx
extends Node3D
## 들판 날씨의 화면(docs/weather.md): 카메라를 따라다니는 비·재·불똥 입자(가볍게, 웹은 WebQuality.WEATHER_KEEP만), 폭풍의 번개,
## 잿바람 불씨 땅 모양. 규칙은 Rules.field_weather가 맡고 여기는 그리기만 한다(꾸밈용 랜덤이라 따로 둔다).
## 글자는 없다. 천둥은 낮은 쿵 소리(Sfx thump, 느린 높이)로 field.gd가 낸다.

signal flashed(delay: float)   ## 번개가 쳤다: 화면 번쩍임과 delay초 뒤 천둥(field.gd)

var _cam: Node3D
var _rain: GPUParticles3D
var _ash: GPUParticles3D
var _spark: GPUParticles3D
var _kind: StringName = &"clear"
var _rng := RandomNumberGenerator.new()
var _bolt_t: float = 4.0


static func make(parent: Node, cam: Node3D) -> WeatherFx:
	var w := WeatherFx.new()
	w.name = "WeatherFx"
	w._cam = cam
	w._rng.seed = 7919
	parent.add_child(w)
	w._build()
	return w


func _build() -> void:
	_rain = _particles(700, 0.85, Vector3(15, 0.5, 15), Vector3(0.12, -1.0, 0.05), 23.0, 26.0, Vector2(0.018, 0.75), Color(0.72, 0.82, 0.95, 0.4), false, FIXED_Y)
	_rain.position = Vector3(0, 10, 0)
	_ash = _particles(160, 5.0, Vector3(16, 4, 16), Vector3(1, -0.05, 0.4), 0.8, 1.6, Vector2(0.07, 0.07), Color(0.62, 0.56, 0.5, 0.7), false, ENABLED)
	_ash.position = Vector3(0, 4, 0)
	_spark = _particles(60, 4.0, Vector3(14, 1, 14), Vector3(0.8, 0.5, 0.3), 0.6, 1.4, Vector2(0.05, 0.05), Color(1.0, 0.55, 0.2, 0.9), true, ENABLED)
	_spark.position = Vector3(0, 0.5, 0)
	var keep: float = WebQuality.WEATHER_KEEP if WebQuality.on() else 1.0
	for p in [_rain, _ash, _spark]:
		p.amount_ratio = keep
		p.emitting = false


const FIXED_Y: int = BaseMaterial3D.BILLBOARD_FIXED_Y
const ENABLED: int = BaseMaterial3D.BILLBOARD_ENABLED


func _particles(amount: int, life: float, box: Vector3, dir: Vector3, v0: float, v1: float, size: Vector2, col: Color, add: bool, bill: int) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.visibility_aabb = AABB(Vector3(-24, -24, -24), Vector3(48, 48, 48))
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = box
	m.direction = dir.normalized()
	m.spread = 4.0
	m.initial_velocity_min = v0
	m.initial_velocity_max = v1
	m.gravity = Vector3.ZERO
	p.process_material = m
	var q := QuadMesh.new()
	q.size = size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = col
	mat.billboard_mode = bill as BaseMaterial3D.BillboardMode
	if add:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	q.material = mat
	p.draw_pass_1 = q
	add_child(p)
	return p


## 날씨를 바꾼다(입자만 켜고 끈다. 하늘·안개·빛은 field.gd가 섞는다).
func set_kind(k: StringName) -> void:
	_kind = k
	_rain.emitting = k == &"rain" or k == &"storm"
	_rain.amount_ratio = (WebQuality.WEATHER_KEEP if WebQuality.on() else 1.0) * (1.0 if k == &"storm" else 0.6)
	_ash.emitting = k == &"ash"
	_spark.emitting = k == &"ash"
	_bolt_t = _rng.randf_range(WEATHER_BOLT.x, WEATHER_BOLT.y)


const WEATHER_BOLT: Vector2 = Vector2(6.0, 14.0)   ## 폭풍에서 번개 사이(초)


func _process(delta: float) -> void:
	if _cam == null:
		return
	var c: Vector3 = _cam.global_position
	global_position = Vector3(c.x, 0.0, c.z)
	if _kind == &"storm":
		_bolt_t -= delta
		if _bolt_t <= 0.0:
			_bolt_t = _rng.randf_range(WEATHER_BOLT.x, WEATHER_BOLT.y)
			var a: float = _rng.randf() * TAU
			strike(c + Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(25.0, 60.0))


## 번개 한 줄기: 하얀 기둥과 불빛이 짧게 번쩍이고(두 번 깜박), 멀수록 천둥이 늦다.
func strike(at: Vector3) -> void:
	var beam := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.1
	cy.bottom_radius = 0.18
	cy.height = 70.0
	cy.radial_segments = 5
	beam.mesh = cy
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.9, 0.93, 1.0)
	cy.material = m
	beam.top_level = true
	beam.position = at + Vector3(0, 35, 0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	var l := OmniLight3D.new()
	l.light_color = Color(0.8, 0.88, 1.0)
	l.light_energy = 9.0
	l.omni_range = 30.0
	l.top_level = true
	l.position = at + Vector3(0, 3, 0)
	add_child(l)
	var t := create_tween()
	t.tween_property(l, "light_energy", 1.0, 0.07)
	t.tween_property(l, "light_energy", 7.0, 0.05)
	t.tween_callback(func() -> void: beam.visible = false)
	t.tween_property(l, "light_energy", 0.0, 0.3)
	t.tween_callback(func() -> void:
		beam.queue_free()
		l.queue_free())
	var dist: float = _cam.global_position.distance_to(at) if _cam else 30.0
	flashed.emit(clampf(dist / 340.0, 0.25, 3.0))


## 잿바람의 불씨 땅 하나(Rules.ember_warn → 여기). 미리 보이는 동안 어두운 붉은 판, 타는 동안 밝게, 꺼지며 사라진다.
func ember_patch(at: Vector2, radius: float, warn: float, burn: float) -> void:
	var n := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = radius * Grid.CELL
	cy.bottom_radius = radius * Grid.CELL
	cy.height = 0.04
	cy.radial_segments = 20
	n.mesh = cy
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.9, 0.25, 0.08, 0.18)
	cy.material = m
	n.top_level = true
	n.position = FieldBuilder.at_cell(at, 0.08)
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(n)
	var t := create_tween()
	t.tween_interval(warn)
	t.tween_property(m, "albedo_color", Color(1.0, 0.42, 0.1, 0.7), 0.2)
	t.tween_property(m, "albedo_color", Color(0.4, 0.1, 0.05, 0.0), maxf(0.1, burn - 0.2))
	t.tween_callback(n.queue_free)
