class_name PullTimingFx
extends Node3D
## 버팀 타이밍(14단계, 모양팀). docs/content.md 14단계 "버팀 타이밍".
## 손잡이 둘레 땅에 불씨빛 가는 고리가 줄어들어 안쪽 표시(놋쇠빛으로 긁힌 듯한 가는 원)에 닿는다.
## 고리가 표시에 닿는 때 = 창의 가운데((open_at + close_at) / 2). 창이 열려 있는 동안 표시가 달아오른다.
##   제대로 당김: 고리가 표시에 붙어 번쩍 사라지고, 표시 둘레에서 불똥이 튀며 짧게 빛난다.
##   모두 제대로(pull_perfect): 더 센 불똥, 더 센 빛, 땅을 쓰는 낮은 충격파와 흙먼지.
##   놓침: 창이 닫히면 고리가 표시 안쪽으로 조금 더 들어가며 식어 사라진다(손해 없음, 소리 없음).
## 글자는 없다. 땅 위의 선과 불똥, 빛만. 등급 색은 쓰지 않는다(조짐과 섞이지 않게).
## 조짐 2·3의 먼지와 빛은 OmenArt가 손잡이마다 늘 띄운다. 여기서는 그리지 않는다.
##
## main은 PullFx처럼 하나를 add_child해 두고 이렇게 쓴다(위치는 손잡이 밑동의 세계 좌표, Grid.cells_to_world(hilt.pos)):
##   Rules.pull_window(hilt, open_at, close_at) → on_window(at, open_at, close_at, now)
##       open_at, close_at, now는 같은 시계(초)여야 한다. 규칙이 뽑기 시작부터 잰 시간(rules.pull_t)을 쓰면 now = rules.pull_t.
##       고리는 now에 ring_start(m)에서 시작해 창의 가운데에 mark_radius(m)에 닿도록 곧게 줄어든다.
##       새 창이 오면 앞의 고리는 바로 지운다.
##   Rules.pull_good(hilt, step)         → on_good(at, step)        고리를 닫고 불똥(step이 클수록 조금 더)
##   Rules.pull_perfect(hilt)            → on_perfect(at)           더 센 것. on_good 다음에 와도, 혼자 와도 된다
##   뽑기가 끝나거나 끊기면(sword_pulled, 뽑기 취소) → clear()   남은 고리를 바로 지운다(불똥과 빛은 스스로 꺼진다)
##   (고르기) 매 프레임 sync(rules.pull_t + 틱 사이 alpha × dt): 시계를 규칙에 맞춘다. 부르지 않으면 on_window의 now부터
##       _process의 delta로 센다. 낮에는 느려짐·히트스톱이 없어 한 틱 안에서 맞는다.
##   (고르기) on_miss(): 놓침을 바로 보인다. 부르지 않아도 close_at이 지나면 스스로 식어 사라진다.
## 지금 고리가 떠 있는지는 showing().

## 고리가 시작하는 반지름과 안쪽 표시의 반지름(m). 표시는 밑동 둔덕(0.32m)과 OmenArt의 금(가장 길게 1.05m)을 비킨다.
@export var ring_start: float = 1.9
@export var mark_radius: float = 0.62
## 땅에서 띄우는 높이(m). 풀에 묻히면 올린다.
@export var lift: float = 0.035
## 고리(움직이는 불씨빛 선)와 표시(놋쇠빛, UiKit의 줄과 같은 집안)의 색.
@export var ring_color: Color = Color(1.0, 0.46, 0.16)
@export var mark_color: Color = Color(0.66, 0.56, 0.38)
## 제대로 당김의 빛 세기와 불똥 수. 모두 제대로는 perfect_* 배.
@export var good_light: float = 2.2
@export var good_sparks: int = 22
@export var perfect_light_mul: float = 2.2
@export var perfect_sparks_mul: float = 2.6

const SHADER: String = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform float half_size = 2.0;
uniform float ring_r = 1.5;
uniform float ring_a = 0.0;
uniform float ring_heat = 0.0;
uniform float mark_r = 0.6;
uniform float mark_a = 0.0;
uniform float mark_heat = 0.0;
uniform float flash = 0.0;
uniform vec3 ring_color : source_color = vec3(1.0, 0.46, 0.16);
uniform vec3 mark_color : source_color = vec3(0.66, 0.56, 0.38);
float line(float d, float w) { return 1.0 - smoothstep(w * 0.5, w, d); }
void fragment() {
	vec2 p = (UV - 0.5) * 2.0 * half_size;
	float r = length(p);
	float ang = atan(p.y, p.x);
	// 표시: 긁힌 듯 군데군데 끊긴 가는 원, 그 밑의 그을린 자국
	float d_m = abs(r - mark_r);
	float gaps = smoothstep(-0.2, 0.35, sin(ang * 9.0) + 0.6 * sin(ang * 23.0 + 1.3));
	float m_core = line(d_m, 0.024) * mix(0.55, 1.0, gaps);
	float m_soot = line(d_m, 0.09);
	// 고리: 움직이는 불씨빛 선. 달아오를수록 굵고 밝다
	float d_r = abs(r - ring_r);
	float w = mix(0.03, 0.05, ring_heat);
	float r_core = line(d_r, w) * (0.85 + 0.15 * sin(ang * 5.0 + TIME * 3.0));
	float r_soot = line(d_r, w * 3.0);
	vec3 mc = mix(mark_color * 0.9, ring_color * 2.2 + vec3(0.25), mark_heat);
	vec3 rc = ring_color * (0.8 + 1.6 * ring_heat) + vec3(flash * 1.5);
	vec3 soot = vec3(0.02, 0.015, 0.012);
	float am = mark_a * max(m_core, m_soot * 0.35);
	vec3 cm = mix(soot, mc, clamp(m_core * 1.5, 0.0, 1.0));
	float ar = ring_a * max(r_core, r_soot * 0.3);
	vec3 cr = mix(soot, rc, clamp(r_core * 1.5, 0.0, 1.0));
	float a = ar + am * (1.0 - ar);
	ALBEDO = (cr * ar + cm * am * (1.0 - ar)) / max(a, 0.001);
	ALPHA = clamp(a, 0.0, 1.0);
}
"""

const SHOCK_SHADER: String = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform vec3 color : source_color = vec3(1.0, 0.5, 0.2);
uniform float t = 0.0;
void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float band = smoothstep(t - 0.1, t, r) * smoothstep(t + 0.02, t, r);
	vec3 soot = vec3(0.03, 0.022, 0.016);
	float hot = smoothstep(t - 0.03, t, r) * smoothstep(t + 0.015, t, r);
	ALBEDO = mix(soot, color * 2.0, hot);
	ALPHA = band * (1.0 - t) * 0.75;
}
"""

var _plane: MeshInstance3D = null
var _mat: ShaderMaterial = null
var _at := Vector3.ZERO
var _now: float = 0.0
var _t0: float = 0.0
var _open: float = 0.0
var _close: float = 0.0
## 0 없음, 1 줄어드는 중, 2 닫힘(제대로), 3 식는 중(놓침)
var _state: int = 0
var _end_t: float = 0.0
var _end_r: float = 0.0
var _synced: bool = false
var _dot: Texture2D = HitFx._soft_dot()


func _ready() -> void:
	_plane = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	var half: float = ring_start + 0.3
	pm.size = Vector2(half * 2.0, half * 2.0)
	_plane.mesh = pm
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_mat.set_shader_parameter("half_size", half)
	_mat.set_shader_parameter("mark_r", mark_radius)
	_mat.set_shader_parameter("ring_color", ring_color)
	_mat.set_shader_parameter("mark_color", mark_color)
	_plane.material_override = _mat
	_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_plane.visible = false
	add_child(_plane)


## 창이 열린다. 고리가 now에 시작해 (open_at + close_at) / 2에 표시에 닿는다.
func on_window(at: Vector3, open_at: float, close_at: float, now: float) -> void:
	_at = at
	_plane.position = at + Vector3(0, lift, 0)
	_open = open_at
	_close = close_at
	_now = now
	_t0 = now
	_synced = false
	_state = 1
	_plane.visible = true
	_mat.set_shader_parameter("flash", 0.0)
	_mat.set_shader_parameter("ring_a", 0.0)
	_mat.set_shader_parameter("mark_a", 0.0)
	_draw_ring()


## 제대로 당김(step번째 버팀). 고리를 표시에 붙여 번쩍 닫고, 표시 둘레에서 불똥이 튄다.
func on_good(at: Vector3, step: int) -> void:
	_close_ring(0.28)
	var k: float = 1.0 + 0.15 * clampf(float(step - 1), 0.0, 4.0)
	_sparks(at, int(good_sparks * k), 3.2 * k, 0.5)
	_flash(at, good_light * k, 0.14)
	_dust(at, 10, 0.9)


## 모두 제대로 당겼다. 더 센 불똥과 빛, 땅을 쓰는 낮은 충격파.
func on_perfect(at: Vector3) -> void:
	if _state == 1:
		_close_ring(0.4)
	_sparks(at, int(good_sparks * perfect_sparks_mul), 5.0, 0.7)
	_flash(at, good_light * perfect_light_mul, 0.28)
	_shock(at, 2.8, 0.45)
	_dust(at, 22, 1.6)


## 놓침을 바로 보인다(부르지 않아도 close_at이 지나면 스스로 한다).
func on_miss() -> void:
	if _state != 1:
		return
	_state = 3
	_end_t = 0.0
	_end_r = _radius()


## 고리를 바로 지운다(뽑기가 끝나거나 끊겼을 때).
func clear() -> void:
	_state = 0
	_plane.visible = false


## 규칙의 시계에 맞춘다(고르기). on_window와 같은 시계의 지금 시각.
func sync(now: float) -> void:
	_now = now
	_synced = true


func showing() -> bool:
	return _state != 0


func _process(delta: float) -> void:
	if _state == 0:
		return
	if not _synced:
		_now += delta
	_synced = false
	match _state:
		1:
			if _now > _close + 0.02:
				on_miss()
			_draw_ring()
		2:
			_end_t += delta
			var k: float = clampf(_end_t / _end_r, 0.0, 1.0)   # _end_r = 닫히는 시간
			_mat.set_shader_parameter("ring_r", mark_radius)
			_mat.set_shader_parameter("ring_heat", 1.0)
			_mat.set_shader_parameter("flash", (1.0 - k) * (1.0 - k))
			_mat.set_shader_parameter("ring_a", (1.0 - k))
			_mat.set_shader_parameter("mark_heat", 1.0 - k)
			_mat.set_shader_parameter("mark_a", 0.85 * (1.0 - k))
			if k >= 1.0:
				clear()
		3:
			# 놓침: 표시 안쪽으로 조금 더 들어가며 식는다
			_end_t += delta
			var k: float = clampf(_end_t / 0.35, 0.0, 1.0)
			_mat.set_shader_parameter("ring_r", maxf(0.2, _end_r - 0.12 * k))
			_mat.set_shader_parameter("ring_heat", 0.4 * (1.0 - k))
			_mat.set_shader_parameter("ring_a", 0.8 * (1.0 - k))
			_mat.set_shader_parameter("mark_heat", 0.0)
			_mat.set_shader_parameter("mark_a", 0.6 * (1.0 - k))
			if k >= 1.0:
				clear()


## 지금 고리의 반지름(m). 시작에서 창의 가운데까지 곧게 줄고, 그 뒤로도 같은 빠르기로 조금 더 들어간다.
func _radius() -> float:
	var c: float = (_open + _close) * 0.5
	var span: float = maxf(0.05, c - _t0)
	var u: float = (_now - _t0) / span
	return maxf(0.15, ring_start + (mark_radius - ring_start) * u)


func _draw_ring() -> void:
	var r: float = _radius()
	var near: float = 1.0 - clampf((r - mark_radius) / (ring_start - mark_radius), 0.0, 1.0)
	var fade_in: float = clampf((_now - _t0) / 0.12, 0.0, 1.0)
	var inside: bool = _now >= _open and _now <= _close
	_mat.set_shader_parameter("ring_r", r)
	_mat.set_shader_parameter("ring_heat", near * near)
	_mat.set_shader_parameter("ring_a", fade_in * (0.55 + 0.45 * near))
	_mat.set_shader_parameter("mark_a", fade_in * 0.8)
	_mat.set_shader_parameter("mark_heat", 1.0 if inside else near * near * 0.25)


func _close_ring(time: float) -> void:
	_state = 2
	_end_t = 0.0
	_end_r = time
	_plane.visible = true


# ---------------------------------------------------------------- 불똥, 빛, 충격파, 흙먼지(PullFx와 같은 결)

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


## 불똥: 표시 둘레에서 쇠가 돌에 긁힌 듯 바깥 위로 튄다.
func _sparks(at: Vector3, amount: int, speed: float, life: float) -> void:
	var p := _burst(at + Vector3(0, 0.08, 0), amount, life)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = mark_radius
	p.emission_ring_inner_radius = mark_radius * 0.85
	p.emission_ring_height = 0.02
	p.direction = Vector3.UP
	p.spread = 50.0
	p.initial_velocity_min = speed * 0.45
	p.initial_velocity_max = speed
	p.radial_accel_min = 2.0
	p.radial_accel_max = 6.0
	p.gravity = Vector3(0, -11.0, 0)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.0
	var c: Color = ring_color
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(2.6, 2.2, 1.6, 1.0), Color(c.r * 2.4, c.g * 2.0, c.b * 1.6, 1.0), Color(c.r, c.g * 0.5, c.b * 0.3, 0.0)])
	p.color_ramp = g
	p.mesh = _quad(0.1, true)


## 짧은 번쩍: 밑동에서 따뜻한 빛이 한 번 켜졌다 꺼진다.
func _flash(at: Vector3, energy: float, time: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.66, 0.4)
	l.light_energy = energy
	l.omni_range = 6.0
	l.position = at + Vector3(0, 0.7, 0)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(l.queue_free)


## 땅을 쓰는 낮은 충격파(그을린 띠와 그 끝의 불씨빛 선).
func _shock(at: Vector3, radius: float, time: float) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(radius * 2.0, radius * 2.0)
	mi.mesh = pm
	var sh := Shader.new()
	sh.code = SHOCK_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("color", ring_color)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at + Vector3(0, lift + 0.01, 0)
	add_child(mi)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("t", v), mark_radius / radius, 1.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(mi.queue_free)


## 흙먼지: 땅을 따라 둥글게 퍼진다.
func _dust(at: Vector3, amount: int, speed: float) -> void:
	var p := _burst(at + Vector3(0, 0.1, 0), amount, 1.0)
	p.direction = Vector3(1, 0.2, 0)
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
	g.colors = PackedColorArray([Color(0.32, 0.27, 0.22, 0.4), Color(0.3, 0.26, 0.22, 0.0)])
	p.color_ramp = g
	p.mesh = _quad(0.5, false)
