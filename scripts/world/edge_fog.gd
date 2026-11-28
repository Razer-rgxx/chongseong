class_name EdgeFog
extends RefCounted
## 언덕 싸움터 가장자리의 낮은 안개 장막(docs/hit_juice.md): 싸움터 네 변을 따라 땅에서 위로 갈수록 옅어지는 어두운 띠.
## 규칙과 무관하고 그림자도 없다. 웹판은 만들지 않는다. 조절은 Juice.EDGE_FOG_*.

const SHADER_CODE: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec4 fog_color : source_color = vec4(0.03, 0.04, 0.06, 1.0);
uniform float alpha_max = 0.85;
void fragment() {
	float up = clamp(UV.y, 0.0, 1.0);          // 0 = 땅, 1 = 꼭대기
	float a = pow(1.0 - up, 1.6) * alpha_max * UV.x;   // UV.x = 이 장막의 진하기 배수
	ALBEDO = fog_color.rgb;
	ALPHA = a;
}
"""


static func build(parent: Node3D, size_m: Vector2) -> MeshInstance3D:
	if Juice.web():
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in [[0.0, 1.0], [Juice.EDGE_FOG_INSET, 0.55]]:
		_curtain(st, size_m, float(layer[0]), float(layer[1]))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var sh := Shader.new()
	sh.code = SHADER_CODE
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("fog_color", Juice.EDGE_FOG_COLOR)
	m.set_shader_parameter("alpha_max", Juice.EDGE_FOG_ALPHA)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "EdgeFog"
	parent.add_child(mi)
	return mi


## 싸움터 가장자리에서 inset(m)만큼 안쪽 사각형을 따라 선 장막. k = 진하기 배수.
static func _curtain(st: SurfaceTool, size_m: Vector2, inset: float, k: float) -> void:
	var pts: Array[Vector2] = []
	var step: float = 2.0
	var w: float = size_m.x - inset
	var d: float = size_m.y - inset
	var x: float = inset
	while x < w:
		pts.append(Vector2(x, inset))
		x += step
	var z: float = inset
	while z < d:
		pts.append(Vector2(w, z))
		z += step
	x = w
	while x > inset:
		pts.append(Vector2(x, d))
		x -= step
	z = d
	while z > inset:
		pts.append(Vector2(inset, z))
		z -= step
	pts.append(pts[0])
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var ha: float = HillBuilder.height(a.x, a.y)
		var hb: float = HillBuilder.height(b.x, b.y)
		var va0 := Vector3(a.x, ha - 0.4, a.y)
		var va1 := Vector3(a.x, ha + Juice.EDGE_FOG_HEIGHT, a.y)
		var vb0 := Vector3(b.x, hb - 0.4, b.y)
		var vb1 := Vector3(b.x, hb + Juice.EDGE_FOG_HEIGHT, b.y)
		for tri in [[va0, 0.0, vb0, 0.0, va1, 1.0], [vb0, 0.0, vb1, 1.0, va1, 1.0]]:
			for k_i in 3:
				st.set_uv(Vector2(k, float(tri[k_i * 2 + 1])))
				st.add_vertex(tri[k_i * 2])
