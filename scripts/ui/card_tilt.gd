class_name CardTilt
extends Node2D
## 카드 손맛(2026-11-28, 사용자가 보낸 영상의 카드 모션에서 가져옴): 카드(Control)에 붙이면
## - 마우스를 올리면 카드가 커서 쪽으로 몇 도 기울고 조금 커지며, 떠나면 0.25초쯤에 걸쳐 감속하며 똑바로 돌아온다.
## - 카드 아래에 조금 떨어진 빛 받침줄(등급 색)을 그려 카드가 떠 있는 것처럼 보이게 하고, 기울면 받침줄이 반대로 살짝 어긋난다.
## 규칙과 무관한 화면 꾸밈. Node2D라 컨테이너 배치에 끼지 않는다(카드의 rotation·scale만 만진다).

## 기울기 최대(도), 올렸을 때 크기, 따라가는 빠르기(클수록 빠름: 12면 약 0.25초에 거의 다 돌아온다).
@export var max_deg: float = 3.0
@export var lift: float = 1.03
@export var speed: float = 12.0
## 받침줄: 카드 아래 간격(px), 색, 너비 몫.
@export var gap: float = 7.0
@export var glow: Color = Color(0.72, 0.6, 0.4)
@export var glow_width: float = 0.84
## 올리지 않았을 때 받침줄 밝기 몫(0이면 올렸을 때만 보인다: 촘촘한 대장간 타일).
@export var rest_glow: float = 0.55

var _card: Control
var _tilt: float = 0.0   # -1(왼쪽) ~ 1(오른쪽)
var _up: float = 0.0     # 0 ~ 1(올림)


## card에 붙인다(이미 붙어 있으면 그것을 돌려주고 색만 바꾼다).
static func attach(card: Control, color: Color = Color(0.72, 0.6, 0.4), deg: float = 3.0) -> CardTilt:
	for c in card.get_children():
		if c is CardTilt:
			(c as CardTilt).glow = color
			(c as CardTilt).queue_redraw()
			return c as CardTilt
	var t := CardTilt.new()
	t.glow = color
	t.max_deg = deg
	t.name = "CardTilt"
	card.add_child(t)
	return t


func _ready() -> void:
	_card = get_parent() as Control
	show_behind_parent = true   # 받침줄은 카드 판 뒤(아래)에
	set_process(_card != null)


func _process(delta: float) -> void:
	if not _card.is_visible_in_tree():
		return
	var r: Rect2 = _card.get_global_rect()
	var m: Vector2 = _card.get_global_mouse_position()
	var on: bool = r.has_point(m)
	var want_t: float = 0.0
	if on and r.size.x > 1.0:
		want_t = clampf((m.x - r.get_center().x) / (r.size.x * 0.5), -1.0, 1.0)
	var k: float = 1.0 - exp(-speed * delta)
	var nt: float = lerpf(_tilt, want_t, k)
	var nu: float = lerpf(_up, 1.0 if on else 0.0, k)
	if absf(nt - _tilt) < 0.0005 and absf(nu - _up) < 0.0005 and not on:
		return
	_tilt = nt
	_up = nu
	_card.pivot_offset = _card.size * 0.5
	_card.rotation = deg_to_rad(max_deg) * _tilt
	_card.scale = Vector2.ONE * lerpf(1.0, lift, _up)
	queue_redraw()


func _draw() -> void:
	if _card == null:
		return
	var s: Vector2 = _card.size
	var w: float = s.x * glow_width
	var y: float = s.y + gap + 3.0 * _up   # 올리면 조금 더 떠 보인다
	var shift: float = -_tilt * 5.0         # 기울면 반대로 어긋난다(아래 판이 멀리 있는 것처럼)
	var a: Vector2 = Vector2((s.x - w) * 0.5 + shift, y)
	var b: Vector2 = Vector2((s.x + w) * 0.5 + shift, y)
	var on: float = lerpf(rest_glow, 1.0, _up)
	if on <= 0.01:
		return
	draw_line(a, b, Color(glow, 0.1 * on), 9.0)
	draw_line(a, b, Color(glow, 0.28 * on), 4.0)
	draw_line(a + Vector2(w * 0.06, 0), b - Vector2(w * 0.06, 0), Color(glow.lightened(0.25), 0.85 * on), 1.5)


## 확인 그림용: 기울기(-1~1)와 올림(0~1)을 바로 정한다.
func pose(tilt: float, up: float) -> void:
	_tilt = tilt
	_up = up
	_card.pivot_offset = _card.size * 0.5
	_card.rotation = deg_to_rad(max_deg) * _tilt
	_card.scale = Vector2.ONE * lerpf(1.0, lift, _up)
	queue_redraw()
