class_name ChainMeter
extends Control
## 처치 연쇄 숫자(2026-11-24, docs/dopamine.md). 화면 오른쪽 가운데에 "×N"과 남은 시간 막대.
## 이어질 때마다 튀어 오르고(연쇄가 길수록 더 크게, 더 뜨거운 색), chain_every의 배수에서는 금빛으로 크게 터지며
## 붙은 조각을 잠깐 보여 준다. 시간이 다 되면 조용히 사라진다. 소리는 부르는 쪽이 낸다(올라가는 음은 쓰지 않는다).

const GOLD := Color(1.0, 0.84, 0.42)
const HOT := Color(1.0, 0.45, 0.22)
const W := 180.0
const H := 118.0

var _num: Label
var _head: Label
var _paid: Label
var _left: float = 0.0
var _window: float = 3.0
var _col: Color = UiKit.TEXT
var _pop: Tween


## parent: HUD(CanvasLayer)나 Control. 화면 오른쪽 가운데에서 조금 위.
static func make(parent: Node) -> ChainMeter:
	var m := ChainMeter.new()
	m.anchor_left = 1.0
	m.anchor_right = 1.0
	m.anchor_top = 0.5
	m.anchor_bottom = 0.5
	m.offset_left = -W - 40.0
	m.offset_right = -40.0
	m.offset_top = -H * 0.5 - 40.0
	m.offset_bottom = H * 0.5 - 40.0
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(m)
	return m


func _ready() -> void:
	_head = UiKit.label("연쇄", 15, UiKit.MUTED)
	_head.position = Vector2(0, 0)
	_head.size = Vector2(W, 20)
	_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_head)
	_num = UiKit.label("", 46, UiKit.TEXT)
	_num.position = Vector2(0, 16)
	_num.size = Vector2(W, 56)
	_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_num.pivot_offset = Vector2(W * 0.5, 30)
	_num.add_theme_constant_override("outline_size", 8)
	_num.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	add_child(_num)
	_paid = UiKit.label("", 18, GOLD)
	_paid.position = Vector2(0, 92)
	_paid.size = Vector2(W, 22)
	_paid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_paid.add_theme_constant_override("outline_size", 5)
	_paid.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_paid.modulate.a = 0.0
	add_child(_paid)
	modulate.a = 0.0


## 연쇄가 n이 되었다. paid > 0이면 이 처치로 붙은 조각(chain_every의 배수). window: 다음 처치까지 남은 초.
func bump(n: int, paid: int, window: float, every: int) -> void:
	_window = maxf(0.1, window)
	_left = _window
	var milestone: bool = every > 0 and n % every == 0
	var heat: float = clampf(float(n - 2) / 14.0, 0.0, 1.0)
	_col = GOLD if milestone else UiKit.TEXT.lerp(HOT, heat)
	_num.text = "×%d" % n
	_num.add_theme_color_override("font_color", _col)
	modulate.a = 1.0
	if _pop:
		_pop.kill()
	_pop = create_tween()
	var big: float = (1.75 if milestone else 1.22 + 0.25 * heat)
	_num.scale = Vector2.ONE * big
	_pop.tween_property(_num, "scale", Vector2.ONE, 0.22 if not milestone else 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if paid > 0:
		_paid.text = "조각 +%d" % paid
		_paid.modulate.a = 1.0
		_paid.position.y = 94
		var tw := create_tween().set_parallel()
		tw.tween_property(_paid, "position:y", 84.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_paid, "modulate:a", 0.0, 0.5).set_delay(0.9)
	queue_redraw()


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta
	if _left <= 0.0:
		create_tween().tween_property(self, "modulate:a", 0.0, 0.35)
	queue_redraw()


## 남은 시간 막대: 숫자 아래 가는 줄이 오른쪽에서 줄어든다. 얼마 안 남으면 깜빡인다.
func _draw() -> void:
	if _left <= 0.0:
		return
	var k: float = clampf(_left / _window, 0.0, 1.0)
	var w: float = 120.0
	var x: float = (W - w) * 0.5
	var y: float = 76.0
	draw_rect(Rect2(x, y, w, 3), Color(0, 0, 0, 0.45))
	var a: float = 1.0 if k > 0.3 else 0.45 + 0.55 * absf(sin(_left * 18.0))
	draw_rect(Rect2(x, y, w * k, 3), Color(_col, a))
