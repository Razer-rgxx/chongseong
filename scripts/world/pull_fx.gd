class_name PullFx
extends Node3D
## 뽑기 연출(8단계). 손잡이를 당기는 동안 땅이 갈라지고(버틸 때마다 더 갈라지고 틈의 빛이 세진다),
## 뽑히는 순간 등급만큼 커진다: 흙먼지 → 불똥 → (전설부터) 빛, 땅을 쓰는 충격파, 떠오르는 불씨, 갈라진 틈이 등급 색으로
## → (신화부터) 잠깐 느려짐 → (초월부터) 세상이 한 번 어두워졌다가 돌아온다. 글자는 띄우지 않는다.
## 우주·은하 같은 것은 쓰지 않는다. 모두 땅과 칼에서 나오는 것(먼지, 불똥, 불씨, 빛)으로.

const CRACK_SHADER: String = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform float grow = 0.0;
uniform vec3 glow : source_color = vec3(1.0, 0.5, 0.18);
uniform float energy = 0.0;
uniform float fade = 1.0;
void fragment() {
	if (UV.x > grow) { discard; }
	float core = 1.0 - abs(UV.y - 0.5) * 2.0;
	float tip = smoothstep(grow, grow - 0.08, UV.x);
	vec3 c = mix(vec3(0.015, 0.01, 0.008), glow * (0.6 + energy * 3.0), smoothstep(0.35, 0.9, core) * clamp(energy, 0.0, 1.0));
	ALBEDO = c;
	ALPHA = smoothstep(0.0, 0.35, core) * tip * fade * 0.95;
}
"""

const RING_SHADER: String = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
uniform vec3 color : source_color = vec3(1.0);
uniform float t = 0.0;
void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float band = smoothstep(t - 0.07, t, r) * smoothstep(t + 0.025, t, r);
	ALBEDO = mix(color, vec3(1.0), 0.3) * 1.2;
	ALPHA = band * (1.0 - t) * 0.45;
}
"""

## 영주를 비추는 빛과 흔들림은 main이 한다. 여기는 땅 위의 것만.
@export var crack_length: Vector2 = Vector2(1.2, 2.8)
@export var crack_count: int = 7
@export var slow_scale: float = 0.3

var env: Environment = null
var _crack: MeshInstance3D = null
var _crack_mat: ShaderMaterial = null
var _at := Vector3.ZERO
var _steps_of: int = 1
var _rng := RandomNumberGenerator.new()
var _dot: Texture2D = HitFx._soft_dot()


## 손잡이를 잡기 시작했다. 갈라짐은 처음엔 실금만.
func begin(at: Vector3, seed: int) -> void:
	_clear_crack()
	_at = at
	_rng.seed = seed
	_crack = MeshInstance3D.new()
	_crack.mesh = _crack_mesh()
	_crack_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CRACK_SHADER
	_crack_mat.shader = sh
	_crack_mat.set_shader_parameter("grow", 0.18)
	_crack_mat.set_shader_parameter("energy", 0.0)
	_crack_mat.set_shader_parameter("fade", 1.0)
	_crack_mat.set_shader_parameter("glow", Color(1.0, 0.5, 0.18))
	_crack.material_override = _crack_mat
	_crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_crack.position = at + Vector3(0, 0.025, 0)
	add_child(_crack)
	_dust(at, 8, 0.8, 0.25)


## 한 번 더 버텼다(step번째). 틈이 더 뻗고 빛이 세진다.
func step(n: int) -> void:
	if _crack_mat == null:
		return
	var k: float = clampf(0.18 + n * 0.17, 0.0, 1.0)
	var tw := create_tween().set_parallel()
	tw.tween_property(_crack_mat, "shader_parameter/grow", k, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_crack_mat, "shader_parameter/energy", 0.22 * n, 0.18)
	_dust(_at, 10 + n * 4, 1.0 + n * 0.3, 0.3)
	_pebbles(_at, 3 + n)


## 뽑혔다. 등급(0~5)과 등급 색, 뽑힌 칼의 모양. 연출이 끝날 때까지 걸리는 시간(초)을 돌려준다.
## 뽑힌 칼이 땅에서 솟아 잠깐 떠 있다가(등급이 높을수록 오래) 영주 쪽으로 사라진다.
func reveal(grade: int, color: Color, sword: SwordModel = null, to: Vector3 = Vector3.ZERO) -> float:
	var g: int = grade
	_dust(_at, 16 + g * 10, 1.6 + g * 0.7, 0.4 + g * 0.06)
	if g >= 1:
		_sparks(_at, 14 + g * 12, color.lerp(Color(1.0, 0.85, 0.6), 0.6 if g < 2 else 0.25))
	var hold: float = 0.35
	if _crack_mat:
		var tw := create_tween()
		if g >= 2:
			_crack_mat.set_shader_parameter("glow", color)
			tw.tween_property(_crack_mat, "shader_parameter/grow", 1.0, 0.12)
			tw.parallel().tween_property(_crack_mat, "shader_parameter/energy", 1.0 + g * 0.3, 0.12)
			tw.tween_interval(0.4 + g * 0.15)
		else:
			tw.tween_property(_crack_mat, "shader_parameter/energy", 0.0, 0.3)
		tw.tween_property(_crack_mat, "shader_parameter/fade", 0.0, 1.2 + g * 0.3)
		tw.tween_callback(_clear_crack)
	if g >= 2:
		_ring(_at, 3.0 + g * 1.6, color, 0.5 + g * 0.08)
		_embers(_at, 18 + g * 14, color, 1.4 + g * 0.35)
		_light(_at, color, 2.5 + g * 1.8, 0.45 + g * 0.15)
		hold = 0.7 + g * 0.15
	if g >= 3:
		_slow(0.25 + (g - 3) * 0.12)
	if g >= 4 and env:
		# 세상이 한 번 숨을 죽였다가 돌아온다(칼의 빛이 도드라지게)
		var was: bool = env.adjustment_enabled
		env.adjustment_enabled = true
		var b0: float = env.adjustment_brightness
		env.adjustment_brightness = 0.5 if g == 4 else 0.38
		var tw2 := create_tween()
		tw2.tween_interval(0.25)
		tw2.tween_property(env, "adjustment_brightness", b0, 1.3).set_trans(Tween.TRANS_SINE)
		tw2.tween_callback(func() -> void: env.adjustment_enabled = was)
		hold += 0.5
	if sword:
		_float_sword(sword, hold, to)
	return hold


func _float_sword(sw: SwordModel, hold: float, to: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = _at + Vector3(0, 0.2, 0)
	holder.scale = Vector3.ONE * 1.3
	add_child(holder)
	holder.add_child(sw)
	sw.position.y = -sw.blade_length * 0.5
	var top: Vector3 = _at + Vector3(0, 2.3, 0)
	var tw := create_tween()
	tw.tween_property(holder, "position", top, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(holder, "rotation:y", TAU * 0.5, hold + 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.0, hold - 0.35))
	tw.tween_property(holder, "position", to + Vector3(0, 1.2, 0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(holder, "scale", Vector3.ONE * 0.05, 0.25)
	tw.tween_callback(holder.queue_free)


func _clear_crack() -> void:
	if _crack:
		_crack.queue_free()
		_crack = null
		_crack_mat = null


# ---------------------------------------------------------------- 갈라진 틈

## 가운데에서 뻗는 금 여러 줄(가지 포함). UV.x: 가운데에서 끝까지(0~1), UV.y: 금의 폭.
func _crack_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var maxlen: float = crack_length.y
	for i in crack_count:
		var a: float = TAU * i / crack_count + _rng.randf_range(-0.35, 0.35)
		var L: float = _rng.randf_range(crack_length.x, crack_length.y)
		var pts := _crack_line(Vector2.ZERO, a, L)
		_ribbon(st, pts, 0.0, L, maxlen, 0.1)
		# 가지 하나
		if _rng.randf() < 0.7:
			var j: int = _rng.randi_range(1, pts.size() - 2)
			var d0: float = L * float(j) / (pts.size() - 1)
			var bl: float = L * _rng.randf_range(0.3, 0.5)
			var bpts := _crack_line(pts[j], a + _rng.randf_range(0.5, 0.9) * (1.0 if _rng.randf() < 0.5 else -1.0), bl)
			_ribbon(st, bpts, d0, bl, maxlen, 0.05)
	return st.commit()


func _crack_line(from: Vector2, a: float, L: float) -> Array[Vector2]:
	var pts: Array[Vector2] = [from]
	var segs: int = 6
	var p: Vector2 = from
	for s in segs:
		a += _rng.randf_range(-0.45, 0.45)
		p += Vector2(cos(a), sin(a)) * (L / segs)
		pts.append(p)
	return pts


func _ribbon(st: SurfaceTool, pts: Array[Vector2], d0: float, L: float, maxlen: float, w0: float) -> void:
	var n: int = pts.size()
	for i in n - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var dir: Vector2 = (b - a).normalized()
		var side := Vector2(-dir.y, dir.x)
		var t0: float = float(i) / (n - 1)
		var t1: float = float(i + 1) / (n - 1)
		var wa: float = w0 * (1.0 - t0 * 0.85)
		var wb: float = w0 * (1.0 - t1 * 0.85)
		var u0: float = (d0 + L * t0) / maxlen
		var u1: float = (d0 + L * t1) / maxlen
		var v := [
			[Vector3(a.x - side.x * wa, 0, a.y - side.y * wa), Vector2(u0, 0)],
			[Vector3(a.x + side.x * wa, 0, a.y + side.y * wa), Vector2(u0, 1)],
			[Vector3(b.x - side.x * wb, 0, b.y - side.y * wb), Vector2(u1, 0)],
			[Vector3(b.x + side.x * wb, 0, b.y + side.y * wb), Vector2(u1, 1)],
		]
		for k in [0, 2, 1, 1, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(v[k][1])
			st.add_vertex(v[k][0])


# ---------------------------------------------------------------- 알갱이

func _burst(at: Vector3, amount: int, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = maxi(1, amount)
	p.lifetime = life
	p.local_coords = false
	p.position = at
	add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.3, true, false, true).timeout.connect(p.queue_free)
	return p


func _quad(size: float, add: bool) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _dot
	q.material = m
	return q


## 흙먼지: 땅을 따라 둥글게 퍼진다.
func _dust(at: Vector3, amount: int, speed: float, size: float) -> void:
	var p := _burst(at + Vector3(0, 0.1, 0), amount, 1.1)
	p.direction = Vector3(1, 0.25, 0)
	p.spread = 180.0
	p.flatness = 0.85
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.8
	p.damping_max = speed * 1.2
	p.gravity = Vector3(0, 0.15, 0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.4
	var c := Curve.new()
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = c
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.32, 0.27, 0.22, 0.45), Color(0.3, 0.26, 0.22, 0.0)])
	p.color_ramp = g
	p.mesh = _quad(size * 2.0, false)


## 흙덩이: 몇 개가 튀어 오른다.
func _pebbles(at: Vector3, amount: int) -> void:
	var p := _burst(at + Vector3(0, 0.05, 0), amount, 0.7)
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, -9.8, 0)
	var b := BoxMesh.new()
	b.size = Vector3(0.05, 0.04, 0.05)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.13, 0.1)
	b.material = m
	p.mesh = b
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0


## 불똥: 쇠가 돌에 긁힌 듯 튄다.
func _sparks(at: Vector3, amount: int, c: Color) -> void:
	var p := _burst(at + Vector3(0, 0.3, 0), amount, 0.55)
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.5
	p.gravity = Vector3(0, -12.0, 0)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 0.9
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(c.r * 3.0, c.g * 3.0, c.b * 3.0, 1.0), Color(c.r, c.g * 0.6, c.b * 0.4, 0.0)])
	p.color_ramp = g
	p.mesh = _quad(0.1, true)


## 불씨: 칼이 뽑힌 자리에서 천천히 떠오른다.
func _embers(at: Vector3, amount: int, c: Color, life: float) -> void:
	var p := _burst(at + Vector3(0, 0.2, 0), amount, life)
	p.explosiveness = 0.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.8
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0, 0.4, 0)
	p.damping_min = 0.3
	p.damping_max = 0.8
	p.tangential_accel_min = -0.6
	p.tangential_accel_max = 0.6
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.8
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	g.colors = PackedColorArray([Color(c.r * 2.5, c.g * 2.5, c.b * 2.5, 0.0), Color(c.r * 2.5, c.g * 2.5, c.b * 2.5, 1.0), Color(c, 0.0)])
	p.color_ramp = g
	p.mesh = _quad(0.15, true)


## 땅을 쓸고 지나가는 둥근 충격파.
func _ring(at: Vector3, radius: float, c: Color, time: float) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(radius * 2.0, radius * 2.0)
	mi.mesh = pm
	var sh := Shader.new()
	sh.code = RING_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("color", c)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at + Vector3(0, 0.06, 0)
	add_child(mi)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("t", v), 0.05, 1.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(mi.queue_free)


func _light(at: Vector3, c: Color, energy: float, time: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energy
	l.omni_range = 10.0
	l.position = at + Vector3(0, 1.4, 0)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)


## 잠깐 느려진다(낮이라 규칙에 영향이 없다).
func _slow(time: float) -> void:
	Engine.time_scale = slow_scale
	get_tree().create_timer(time, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)
