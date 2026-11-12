shader_type spatial;
render_mode unshaded, cull_front;
// 바깥선(뒤집은 껍질). 실제로 있는 것(영주, 사람, 지어진 것)을 종이에서 떼어 보이게 한다.

uniform vec3 color : source_color = vec3(0.03, 0.07, 0.15);
uniform float thickness = 0.035;

void vertex() {
	VERTEX += NORMAL * thickness;
}

void fragment() {
	ALBEDO = color;
}
