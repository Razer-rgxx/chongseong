class_name GlitchOverlay
extends CanvasLayer
## 화면 글리치(docs/stranger.md): 가로로 찢어지는 줄과 색 번짐. 셰이더 한 장이라 가볍다(웹판도). amount가 0이면 숨는다.

const CODE := """
shader_type canvas_item;
uniform sampler2D scr : hint_screen_texture, filter_nearest;
uniform float amount = 0.0;
uniform float seed = 0.0;
float h(float x) { return fract(sin(x * 127.1 + seed * 311.7) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	float row = floor(uv.y * 30.0);
	float tear = step(0.8, h(row)) * (h(row + 3.0) - 0.5) * 0.14 * amount;
	float band = step(0.94, h(floor(uv.y * 7.0) + 9.0)) * 0.035 * amount;
	uv.x += tear + band;
	float ca = 0.012 * amount;
	vec3 c = vec3(texture(scr, uv + vec2(ca, 0.0)).r, texture(scr, uv).g, texture(scr, uv - vec2(ca, 0.0)).b);
	c += vec3(0.0, 0.06, 0.1) * step(0.97, h(floor(uv.y * 200.0))) * amount;
	c *= 1.0 - 0.07 * amount * step(0.5, fract(uv.y * 240.0));
	COLOR = vec4(c, 1.0);
}
"""

var _rect: ColorRect
var _mat: ShaderMaterial
var _acc: float = 0.0


static func make(parent: Node) -> GlitchOverlay:
	var g := GlitchOverlay.new()
	g.layer = 90
	parent.add_child(g)
	g._build()
	return g


func _build() -> void:
	var sh := Shader.new()
	sh.code = CODE
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	add_child(_rect)
	_rect.visible = false


## 세기 0~1. 몇 프레임마다 줄 무늬를 다시 뽑는다.
func set_amount(a: float, delta: float = 0.0) -> void:
	_rect.visible = a > 0.01
	if not _rect.visible:
		return
	_acc += delta
	if _acc > 0.05:
		_acc = 0.0
		_mat.set_shader_parameter("seed", randf() * 50.0)
	_mat.set_shader_parameter("amount", a)
