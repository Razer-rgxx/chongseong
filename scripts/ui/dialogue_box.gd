class_name DialogueBox
extends Control
## 사람과 이야기할 때의 대사(2026-11-23 다시 그림: 사용자 "솔스 RNG처럼 독창적이고 멋있게", 화풍은 어두운 대장간).
## - 말을 걸면 화면 위아래에 검은 띠가 내려와 장면을 좁힌다(영화처럼).
## - 아래 어두운 판: 위 놋쇠 줄을 빛 한 점이 천천히 훑고, 판 아래에서 불씨가 피어오른다.
## - 왼쪽 위에 말하는 이의 이름, 그 밑에 칼 한 자루가 손잡이부터 칼끝까지 그어진다(이름이 바뀔 때마다).
## - 대사는 글자마다 달군 쇠처럼 붉게 떠올랐다 식는다(ForgeTextFx). 「이름」은 놋쇠빛이 훑는다(ShineTextFx).
## - 다 나오면 오른쪽 아래에 마름모 키(KeyGlyph)와 "다음/닫기". 글자가 나오는 중에 E면 한꺼번에 다 보인다(skip).

const WIDTH: float = 1180.0
const HEIGHT: float = 190.0
const BOTTOM: float = 58.0
const LEFT: float = 150.0
const TEXT_WIDTH: float = 880.0
const FADE_IN: float = 0.2
const FADE_OUT: float = 0.3
const BAR: float = 46.0          ## 위아래 검은 띠 높이(px)
const BLADE_LEN: float = 300.0

var _name: Label
var _line: RichTextLabel
var _hint: Control
var _hint_label: Label
var _embers: CPUParticles2D
var _bars: Array[ColorRect] = []
var _bg: Texture2D
var _hold: bool = false
var _t: float = 0.0
var _t0: float = 0.0
var _chars: int = 0
var _blade: float = 1.0
var _bar: float = 0.0


static func make(parent: Node) -> DialogueBox:
	var d := DialogueBox.new()
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	d.offset_left = -WIDTH / 2.0
	d.offset_right = WIDTH / 2.0
	d.offset_bottom = -BOTTOM
	d.offset_top = -BOTTOM - HEIGHT
	for top in [true, false]:
		var b := ColorRect.new()
		b.color = Color(0, 0, 0, 0.94)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		b.offset_top = 0.0
		b.offset_bottom = 0.0
		parent.add_child(b)
		d._bars.append(b)
	parent.add_child(d)
	d._build()
	return d


func _build() -> void:
	_bg = UiKit.fade_texture(Color(0.012, 0.009, 0.007), 0.86, 0.18)
	_embers = CPUParticles2D.new()
	_embers.amount = 26
	_embers.lifetime = 2.8
	_embers.preprocess = 2.0
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_embers.emission_rect_extents = Vector2(WIDTH * 0.36, 3.0)
	_embers.position = Vector2(WIDTH / 2.0, HEIGHT - 4.0)
	_embers.direction = Vector2(0, -1)
	_embers.spread = 25.0
	_embers.gravity = Vector2(0, -6)
	_embers.initial_velocity_min = 8.0
	_embers.initial_velocity_max = 26.0
	_embers.scale_amount_min = 1.0
	_embers.scale_amount_max = 2.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.62, 0.25, 0.0))
	ramp.add_point(0.15, Color(1.0, 0.6, 0.22, 0.85))
	ramp.add_point(0.7, Color(0.9, 0.35, 0.12, 0.45))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.6, 0.2, 0.08, 0.0))
	_embers.color_ramp = ramp
	add_child(_embers)
	_name = UiKit.label("", 21, UiKit.TITLE)
	_name.position = Vector2(LEFT, 20.0)
	UiKit.soft_shadow(_name, 0.8)
	add_child(_name)
	_line = RichTextLabel.new()
	_line.bbcode_enabled = true
	_line.fit_content = true
	_line.scroll_active = false
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line.position = Vector2(LEFT, 70.0)
	_line.size = Vector2(TEXT_WIDTH, 100.0)
	_line.add_theme_font_size_override("normal_font_size", 23)
	_line.add_theme_color_override("default_color", UiKit.TEXT)
	_line.add_theme_constant_override("line_separation", 8)
	_line.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_line.add_theme_constant_override("shadow_offset_y", 2)
	_line.install_effect(ForgeTextFx.new())
	_line.install_effect(ShineTextFx.new())
	add_child(_line)
	var hint := HBoxContainer.new()
	hint.position = Vector2(WIDTH - 250.0, HEIGHT - 52.0)
	hint.size = Vector2(110.0, 36.0)
	hint.alignment = BoxContainer.ALIGNMENT_END
	hint.add_theme_constant_override("separation", 6)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key := KeyGlyph.make(34.0, 14)
	key.label.text = "E"
	hint.add_child(key)
	_hint_label = UiKit.label("다음", 14, UiKit.MUTED)
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_child(_hint_label)
	add_child(hint)
	_hint = hint
	modulate.a = 0.0
	visible = false


func _process(delta: float) -> void:
	_t += delta
	if _hold:
		modulate.a = minf(1.0, modulate.a + delta / FADE_IN)
		_bar = minf(1.0, _bar + delta / 0.35)
	else:
		modulate.a = maxf(0.0, modulate.a - delta / FADE_OUT)
		_bar = maxf(0.0, _bar - delta / 0.3)
		visible = modulate.a > 0.0
	var e: float = 1.0 - pow(1.0 - _bar, 3.0)
	for i in _bars.size():
		var b := _bars[i]
		if i == 0:
			b.offset_bottom = BAR * e
		else:
			b.offset_top = -BAR * e
		b.visible = _bar > 0.0
	_blade = minf(1.0, _blade + delta / 0.45)
	_hint.modulate.a = lerpf(_hint.modulate.a, 0.0 if is_typing() else 1.0, minf(1.0, delta * 10.0))
	_hint.position.y = HEIGHT - 52.0 + sin(_t * 3.2) * 2.0
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(_bg, Rect2(Vector2.ZERO, size), false)
	var x0: float = size.x * 0.06
	var x1: float = size.x * 0.94
	# 위·아래 놋쇠 줄, 위 줄을 빛 한 점이 훑는다
	draw_line(Vector2(x0, 0.5), Vector2(x1, 0.5), Color(UiKit.LINE, 0.5), 1.0)
	draw_line(Vector2(x0, size.y - 0.5), Vector2(x1, size.y - 0.5), Color(UiKit.LINE, 0.25), 1.0)
	var g: float = fmod(_t * 0.22, 1.7)
	if g < 1.0:
		var gx: float = lerpf(x0, x1, g)
		for i in range(-14, 15):
			var a: float = (1.0 - absf(float(i)) / 14.0)
			draw_line(Vector2(gx + i * 5.0, 0.5), Vector2(gx + i * 5.0 + 5.0, 0.5), Color(1.0, 0.86, 0.58, a * a * 0.95), 2.0)
	# 이름 밑의 칼: 마름모 칼자루 끝 → 손잡이 → 코등이 → 가늘어지는 칼날
	if _name.text == "":
		return
	var y: float = 56.0
	var bx: float = LEFT - 4.0
	var len: float = BLADE_LEN * (1.0 - pow(1.0 - _blade, 3.0))
	var col := Color(UiKit.LINE, 0.85)
	draw_colored_polygon(PackedVector2Array([Vector2(bx - 6, y), Vector2(bx, y - 4), Vector2(bx + 6, y), Vector2(bx, y + 4)]), col)
	if len > 8.0:
		draw_line(Vector2(bx + 6, y), Vector2(bx + minf(len, 34.0), y), Color(UiKit.LINE, 0.6), 2.0)
	if len > 34.0:
		draw_line(Vector2(bx + 34, y - 7), Vector2(bx + 34, y + 7), col, 2.0)
		var tip: float = bx + 36.0 + (len - 34.0)
		draw_colored_polygon(PackedVector2Array([Vector2(bx + 36, y - 2.5), Vector2(tip - 14, y - 1.2), Vector2(tip, y), Vector2(tip - 14, y + 1.2), Vector2(bx + 36, y + 2.5)]), Color(0.8, 0.78, 0.74, 0.8))
		draw_line(Vector2(bx + 40, y), Vector2(tip - 16, y), Color(0.25, 0.22, 0.18, 0.7), 1.0)


## 대사 한 줄을 띄운다. who가 비면 이름 줄을 감춘다. last면 오른쪽 아래가 "닫기".
func show_line(who: String, text: String, last: bool = false) -> void:
	if who != _name.text:
		_blade = 0.0
	_name.text = who
	_name.visible = who != ""
	_hint_label.text = "닫기" if last else "다음"
	_t0 = Time.get_ticks_msec() / 1000.0
	_chars = text.length()
	_set_text(text)
	_hold = true
	visible = true


func _set_text(text: String) -> void:
	var t: String = text.replace("[", "[lb]")
	var re := RegEx.create_from_string("「[^」]*」")
	t = re.sub(t, "[shine]$0[/shine]", true)
	_line.text = "[forge t0=%f]%s[/forge]" % [_t0, t]
	set_meta("plain", text)


## 글자가 아직 나오는 중인가.
func is_typing() -> bool:
	return _hold and Time.get_ticks_msec() / 1000.0 - _t0 < float(_chars) * ForgeTextFx.STEP + ForgeTextFx.APPEAR


## 나오는 중이면 한꺼번에 다 보인다.
func finish_typing() -> void:
	_t0 -= 1000.0
	_set_text(str(get_meta("plain", "")))


func hide_box() -> void:
	_hold = false


func is_showing() -> bool:
	return _hold
