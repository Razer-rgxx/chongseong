class_name UiKit
extends RefCounted
## 코드로 만드는 창의 모양(어두운 판, 둥근 모서리). 언덕과 마을이 같이 쓴다.


static func style(border: Color, width: int = 1, bg: Color = Color(0.035, 0.045, 0.07, 0.92)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(10)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


static func label(t: String, size: int, col: Color = Color(0.9, 0.92, 0.96)) -> Label:
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


## 화면 가운데의 판. 돌려주는 VBoxContainer에 내용을 넣는다.
static func center_panel(parent: Node, border: Color = Color(1, 1, 1, 0.1)) -> VBoxContainer:
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
