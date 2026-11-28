class_name SlashFx
extends Node3D
## 칼을 휘두를 때의 꾸밈 두 가지.
## 1. 궤적: 칼날의 두 끝을 매 화면 모아 부드러운 곡선(캣멀롬)으로 이은 띠. 지금 쪽이 밝고 오래된 쪽으로 사라진다.
## 2. 베기 빛: 규칙이 실제로 벤 범위(겨눈 쪽 ± 호, 사거리)를 공중에 그리는 초승달. 한 번에 쓸고 지나가며 사라진다.
##    애니메이션과 상관없이 규칙이 판정한 그 순간 그 범위에 나와서, 무엇을 벴는지 바로 읽힌다.
## 색은 쥔 칼의 등급 색(흔함은 흰빛). 모든 노드는 세계 좌표(top_level)로 그린다.

@export var trail_life: float = 0.14
## 궤적을 몇 번 쪼개 매끄럽게 할지(화면 한 장 사이).
@export var trail_subdiv: int = 6
@export var arc_sweep: float = 0.08
@export var arc_fade: float = 0.2
@export var arc_height: float = 1.05

const TRAIL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	float age = UV.x;
	float across = UV.y;
	float fade = pow(clamp(1.0 - age, 0.0, 1.0), 1.6);
	float body = smoothstep(0.0, 1.0, across) * 0.45;
	float edge = smoothstep(0.78, 0.97, across) * (1.0 - smoothstep(0.985, 1.0, across) * 0.6);
	ALBEDO = tint.rgb;
	ALPHA = clamp((body + edge * 1.2) * fade, 0.0, 1.0);
}
"""

const ARC_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform float progress = 0.0;
uniform float fade = 1.0;
void fragment() {
	float u = UV.x;
	float r = UV.y;
	float behind = progress - u;
	float seen = step(0.0, behind);
	float tail = exp(-max(behind, 0.0) * 3.0);
	float rim = pow(r, 2.2) * (1.0 - smoothstep(0.9, 1.0, r));
	float head = (1.0 - smoothstep(0.0, 0.06, abs(behind))) * r;
	ALBEDO = tint.rgb * 1.6;
	ALPHA = clamp((rim * tail * 1.3 + head) * seen * fade, 0.0, 1.0);
}
"""

static var _trail_shader: Shader
static var _arc_shader: Shader

var color: Color = Color(0.92, 0.92, 1.0)
var _pts: Array = []   # [손잡이 쪽, 칼끝, 나이]
var _trail := MeshInstance3D.new()
var _trail_mesh := ImmediateMesh.new()
var _trail_mat := ShaderMaterial.new()


func _ready() -> void:
	if _trail_shader == null:
		_trail_shader = Shader.new()
		_trail_shader.code = TRAIL_SHADER
		_arc_shader = Shader.new()
		_arc_shader.code = ARC_SHADER
	_trail_mat.shader = _trail_shader
	_trail.mesh = _trail_mesh
	_trail.top_level = true
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)


## 매 화면 부른다. active일 때만 칼날의 두 끝(base, tip)을 모은다.
func trail_step(delta: float, active: bool, base: Vector3, tip: Vector3) -> void:
	for p in _pts:
		p[2] += delta
	while not _pts.is_empty() and _pts[0][2] > trail_life:
		_pts.pop_front()
	if active:
		_pts.append([base, tip, 0.0])
	_draw_trail()


func clear_trail() -> void:
	_pts.clear()
	_trail_mesh.clear_surfaces()


func _draw_trail() -> void:
	_trail_mesh.clear_surfaces()
	if _pts.size() < 2:
		return
	_trail_mat.set_shader_parameter("tint", color)
	# 캣멀롬으로 화면 사이를 채운다(빨리 휘두르면 각이 지지 않게)
	var bases: Array[Vector3] = []
	var tips: Array[Vector3] = []
	var ages: Array[float] = []
	var n: int = _pts.size()
	for i in n - 1:
		var i0: int = maxi(0, i - 1)
		var i3: int = mini(n - 1, i + 2)
		for s in trail_subdiv:
			var t: float = float(s) / trail_subdiv
			bases.append(_cr(_pts[i0][0], _pts[i][0], _pts[i + 1][0], _pts[i3][0], t))
			tips.append(_cr(_pts[i0][1], _pts[i][1], _pts[i + 1][1], _pts[i3][1], t))
			ages.append(lerpf(_pts[i][2], _pts[i + 1][2], t))
	bases.append(_pts[n - 1][0])
	tips.append(_pts[n - 1][1])
	ages.append(_pts[n - 1][2])
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _trail_mat)
	for i in bases.size():
		var age: float = ages[i] / trail_life
		_trail_mesh.surface_set_uv(Vector2(age, 0.0))
		_trail_mesh.surface_add_vertex(bases[i])
		_trail_mesh.surface_set_uv(Vector2(age, 1.0))
		_trail_mesh.surface_add_vertex(tips[i])
	_trail_mesh.surface_end()


static func _cr(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


## 규칙이 벤 범위를 공중에 그린다. face와 arc는 규칙의 각도(칸 좌표계, 라디안), reach는 미터.
## sweep_dir: 1이면 오른쪽에서 왼쪽, -1이면 반대로 쓴다. tilt: 앞 축으로 기울이는 각(사선 베기).
func arc(at: Vector3, face: float, arc_rad: float, reach: float, sweep_dir: float, tilt: float, big: bool) -> void:
	var m := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = _arc_shader
	mat.set_shader_parameter("tint", color)
	m.mesh = im
	m.top_level = true
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fwd := Vector3(cos(face), 0.0, sin(face))
	var turn := Basis(fwd, tilt)
	var r_in: float = reach * (0.35 if big else 0.5)
	var r_out: float = reach * 1.02
	var seg: int = 28
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, mat)
	for i in seg + 1:
		var u: float = float(i) / seg
		var a: float = face + sweep_dir * arc_rad * (0.5 - u)
		var d := turn * Vector3(cos(a), 0.0, sin(a))
		im.surface_set_uv(Vector2(u, 0.0))
		im.surface_add_vertex(at + d * r_in)
		im.surface_set_uv(Vector2(u, 1.0))
		im.surface_add_vertex(at + d * r_out)
	im.surface_end()
	add_child(m)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("progress", v), 0.0, 1.25, arc_sweep)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 1.0, 0.0, arc_fade)
	tw.tween_callback(m.queue_free)
