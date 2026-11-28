class_name QuarterRing
extends MeshInstance3D
## 쿼터뷰(V)일 때만 영주 발밑에 뜨는 옅은 놋쇠빛 고리(docs/hit_juice.md). 3인칭에서는 숨는다. 조절은 Juice.RING_*.

const SHADER_CODE: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, depth_test_disabled;
uniform vec4 ring_color : source_color = vec4(1.0, 0.72, 0.45, 1.0);
uniform float alpha_max = 0.3;
uniform float inner = 0.9;
void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;     // 0 가운데, 1 가장자리
	float edge = smoothstep(inner - 0.04, inner, r) * (1.0 - smoothstep(0.98, 1.0, r));
	ALBEDO = ring_color.rgb;
	ALPHA = edge * alpha_max;
}
"""

var camera: Node = null


static func attach(lord: Node3D, cam: Node) -> QuarterRing:
	var q := QuarterRing.new()
	q.camera = cam
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE * Juice.RING_RADIUS * 2.0
	q.mesh = pm
	var sh := Shader.new()
	sh.code = SHADER_CODE
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("ring_color", Juice.LORD_LIGHT)
	m.set_shader_parameter("alpha_max", Juice.RING_ALPHA)
	m.set_shader_parameter("inner", 1.0 - Juice.RING_WIDTH / Juice.RING_RADIUS)
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.position = Vector3(0, 0.06, 0)
	q.visible = false
	lord.add_child(q)
	return q


func _process(_delta: float) -> void:
	visible = camera != null and "mode" in camera and int(camera.get("mode")) == 1   # 1 = QUARTER
