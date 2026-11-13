class_name UiKit
extends RefCounted
## 코드로 만드는 창의 모양. 언덕과 마을이 같이 쓴다.
## 엘든 링·다크 소울류를 본떴다: 모서리 없는 거의 검은 판, 놋쇠빛 가는 테두리, 따뜻한 글자색.
## 버튼과 글꼴은 assets/ui/theme.tres(scripts/debug/build_theme.gd로 만든다)가 맡는다.

const BG := Color(0.035, 0.03, 0.025, 0.9)
const LINE := Color(0.66, 0.56, 0.38)
const TITLE := Color(0.93, 0.85, 0.66)
const TEXT := Color(0.87, 0.84, 0.78)
const MUTED := Color(0.6, 0.57, 0.51)


static func style(border: Color = Color(LINE, 0.4), width: int = 1, bg: Color = BG) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s


static func label(t: String, size: int, col: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


static func rich(size: int = 15, width: float = 360.0) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.custom_minimum_size = Vector2(width, 0)
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size + 3)
	return r


static func button(t: String, f: Callable, h: float = 38.0) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, h)
	b.pressed.connect(f)
	return b


## 가운데가 진하고 양 끝으로 사라지는 가로줄(제목 밑줄, 띠의 위아래).
static func rule(width: float = 0.0, col: Color = LINE, alpha: float = 0.7) -> TextureRect:
	var t := TextureRect.new()
	t.texture = fade_texture(col, alpha, 0.3)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.custom_minimum_size = Vector2(width, 1)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## 가로로 양 끝이 투명해지는 한 줄짜리 그림. inner는 진한 부분이 시작하는 자리(0~0.5).
static func fade_texture(col: Color, alpha: float, inner: float = 0.25) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, inner, 1.0 - inner, 1.0])
	g.colors = PackedColorArray([Color(col, 0.0), Color(col, alpha), Color(col, alpha), Color(col, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 1
	return t


## 창의 머리: 왼쪽 제목, 오른쪽 닫기, 아래 가는 줄.
static func header(box: VBoxContainer, title: String, close: Callable, col: Color = TITLE) -> Label:
	var head := HBoxContainer.new()
	var t := label(title, 26, col)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(button("Esc  닫기", close, 34))
	box.add_child(head)
	box.add_child(rule())
	return t


## 화면 가운데의 판. 돌려주는 VBoxContainer에 내용을 넣는다.
static func center_panel(parent: Node, border: Color = Color(LINE, 0.4)) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(border))
	center.add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	p.add_child(box)
	return box
