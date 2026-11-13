extends SceneTree
## assets/ui/theme.tres를 만든다: godot --headless --path . -s scripts/debug/build_theme.gd
## 글꼴(Noto Serif KR, 본문 600·굵게 800), 따뜻한 글자색, 모서리 없는 버튼(놋쇠빛 테두리).
## 굵기는 숫자 태그(2003265652 = wght)로 줘야 먹는다.

const WGHT: int = 2003265652
const LINE := Color(0.66, 0.56, 0.38)


func _init() -> void:
	var ff: FontFile = load("res://assets/ui/fonts/NotoSerifKR-subset.ttf")
	var body := FontVariation.new()
	body.base_font = ff
	body.variation_opentype = {WGHT: 600}
	var bold := FontVariation.new()
	bold.base_font = ff
	bold.variation_opentype = {WGHT: 800}
	var t := Theme.new()
	t.default_font = body
	t.set_color("font_color", "Label", Color(0.87, 0.84, 0.78))
	t.set_font("normal_font", "RichTextLabel", body)
	t.set_font("bold_font", "RichTextLabel", bold)
	t.set_color("default_color", "RichTextLabel", Color(0.87, 0.84, 0.78))
	for type in ["Button", "OptionButton"]:
		t.set_font("font", type, body)
		t.set_stylebox("normal", type, _box(Color(0.07, 0.06, 0.05, 0.85), Color(LINE, 0.35)))
		t.set_stylebox("hover", type, _box(Color(0.13, 0.105, 0.07, 0.95), Color(LINE, 0.95)))
		t.set_stylebox("pressed", type, _box(Color(0.2, 0.15, 0.09, 0.95), Color(LINE, 1.0)))
		t.set_stylebox("disabled", type, _box(Color(0.05, 0.05, 0.05, 0.6), Color(LINE, 0.12)))
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
		t.set_color("font_color", type, Color(0.86, 0.82, 0.74))
		t.set_color("font_hover_color", type, Color(1.0, 0.93, 0.78))
		t.set_color("font_pressed_color", type, Color(1.0, 0.93, 0.78))
		t.set_color("font_disabled_color", type, Color(0.45, 0.43, 0.4))
	var pm := _box(Color(0.05, 0.045, 0.035, 0.97), Color(LINE, 0.5))
	t.set_stylebox("panel", "PopupMenu", pm)
	t.set_stylebox("hover", "PopupMenu", _box(Color(0.16, 0.12, 0.08, 1.0), Color(LINE, 0.0)))
	t.set_color("font_color", "PopupMenu", Color(0.86, 0.82, 0.74))
	t.set_color("font_hover_color", "PopupMenu", Color(1.0, 0.93, 0.78))
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(LINE, 0.5)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.3)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("scroll", "VScrollBar", track)
	ResourceSaver.save(t, "res://assets/ui/theme.tres")
	print("saved theme")
	quit()


static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 6
	s.content_margin_bottom = 7
	return s
