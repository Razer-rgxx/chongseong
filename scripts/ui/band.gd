class_name Band
extends Control
## 엘든 링식 띠. 양 끝으로 사라지는 검은 띠 위아래에 놋쇠빛 가는 줄, 가운데 글자.
## 알림(show_for)과 다가갔을 때의 안내(show_key: "E" 같은 키 칸 + 할 일)에 쓴다.

@export var fade_in: float = 0.15
@export var fade_out: float = 0.35

var _label: Label
var _key_box: PanelContainer
var _key_label: Label
var _t: float = 0.0
var _hold: bool = false


## 화면 가로 가운데에 놓는다. y가 0 이상이면 위에서, 음수면 아래에서 잰다.
static func make(parent: Node, y: float, width: float, height: float, font_size: int) -> Band:
	var b := Band.new()
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.set_anchors_preset(Control.PRESET_CENTER_TOP if y >= 0.0 else Control.PRESET_CENTER_BOTTOM)
	b.offset_left = -width / 2.0
	b.offset_right = width / 2.0
	b.offset_top = y if y >= 0.0 else y - height
	b.offset_bottom = b.offset_top + height
	parent.add_child(b)
	b._build(font_size)
	return b


func _build(font_size: int) -> void:
	var bg := TextureRect.new()
	bg.texture = UiKit.fade_texture(Color(0.01, 0.008, 0.006), 0.78, 0.22)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	for top in [true, false]:
		var r := UiKit.rule(0.0, UiKit.LINE, 0.55)
		r.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		r.offset_top = 0.0 if top else -1.0
		r.offset_bottom = 1.0 if top else 0.0
		add_child(r)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(row)
	_key_box = PanelContainer.new()
	var ks := UiKit.style(Color(UiKit.LINE, 0.8), 1, Color(0.06, 0.05, 0.04, 0.9))
	ks.content_margin_left = 9
	ks.content_margin_right = 9
	ks.content_margin_top = 1
	ks.content_margin_bottom = 2
	_key_box.add_theme_stylebox_override("panel", ks)
	_key_label = UiKit.label("", font_size - 2, UiKit.TITLE)
	_key_box.add_child(_key_label)
	row.add_child(_key_box)
	_label = UiKit.label("", font_size)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_label)
	modulate.a = 0.0
	visible = false


func _process(delta: float) -> void:
	if _hold:
		modulate.a = minf(1.0, modulate.a + delta / fade_in)
		return
	if _t > 0.0:
		_t -= delta
		modulate.a = minf(1.0, modulate.a + delta / fade_in)
		return
	modulate.a = maxf(0.0, modulate.a - delta / fade_out)
	visible = modulate.a > 0.0


## 잠깐 띄웠다가 사라진다.
func show_for(t: String, secs: float) -> void:
	_label.text = t
	_key_box.visible = false
	_hold = false
	_t = secs
	visible = true


## 끌 때까지 띄워 둔다. key가 있으면 앞에 키 칸을 그린다.
func show_key(key: String, t: String) -> void:
	if _hold and _label.text == t and _key_label.text == key:
		return
	_label.text = t
	_key_label.text = key
	_key_box.visible = key != ""
	_hold = true
	visible = true


func hide_band() -> void:
	_hold = false
	_t = 0.0
