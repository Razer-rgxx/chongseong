class_name LifeBar
extends Control
## 영주 체력 막대(2026-11-21): 글자 없이 막대만(숫자·"체력"을 옆에 적지 않는다, 막대가 곧 그 말이다).
## 깎인 몫은 옅게 잠깐 남았다 따라 줄고, 차오르면 잠깐 밝아지고, 30% 아래면 숨쉬듯 밝아진다.
## 최대 체력이 늘면 막대가 길어진다(자란 만큼 눈에 보이게). 언덕(hud)·들판·마을·무덤(lobby_hud)이 같이 쓴다.

const H: float = 10.0
const PAD: float = 2.0
## 기본 체력(140)일 때 너비, 가장 긴 너비.
const BASE_W: float = 280.0
const BASE_HP: float = 140.0
const MAX_W: float = 520.0
## 깎인 몫이 머무는 초, 따라 줄어드는 빠르기(최대 체력의 몫/초), 낮은 체력의 기준.
const HOLD: float = 0.45
const LAG_SPEED: float = 0.6
const LOW: float = 0.3

const FILL: Color = Color(0.7, 0.16, 0.14)
const FILL_LOW: Color = Color(0.95, 0.32, 0.22)
const LAG: Color = Color(0.86, 0.78, 0.64, 0.6)
const HEAL: Color = Color(0.96, 0.86, 0.62)

var hp: float = -1.0
var max_hp: float = 1.0
var lag: float = -1.0
var _hold: float = 0.0
var _heal: float = 0.0
var _t: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(BASE_W, H + PAD * 2.0)


## 최대 체력에 맞는 막대 너비(px).
static func width_for(m: float) -> float:
	return clampf(BASE_W * m / BASE_HP, BASE_W, MAX_W)


func set_hp(v: float, m: float) -> void:
	v = maxf(0.0, v)
	m = maxf(1.0, m)
	if hp < 0.0:
		lag = v
	elif v < hp - 0.01:
		_hold = HOLD
	elif v > hp + 0.01:
		_heal = 0.4
	hp = v
	max_hp = m
	var w: float = width_for(m)
	if not is_equal_approx(custom_minimum_size.x, w):
		custom_minimum_size = Vector2(w, H + PAD * 2.0)
		size = custom_minimum_size


func _process(delta: float) -> void:
	_t += delta
	if _hold > 0.0:
		_hold -= delta
	elif lag > hp:
		lag = move_toward(lag, hp, max_hp * LAG_SPEED * delta)
	lag = maxf(lag, hp)
	_heal = maxf(0.0, _heal - delta)
	queue_redraw()


func _draw() -> void:
	if hp < 0.0:
		return
	var w: float = width_for(max_hp)
	var outer := Rect2(Vector2.ZERO, Vector2(w, H + PAD * 2.0))
	draw_rect(outer, Color(0.02, 0.018, 0.015, 0.82))
	draw_rect(outer, Color(UiKit.LINE, 0.55), false, 1.0)
	var iw: float = w - PAD * 2.0
	var k: float = clampf(hp / max_hp, 0.0, 1.0)
	var lk: float = clampf(lag / max_hp, 0.0, 1.0)
	if lk > k:
		draw_rect(Rect2(Vector2(PAD + iw * k, PAD), Vector2(iw * (lk - k), H)), LAG)
	var c: Color = FILL
	if k < LOW:
		c = FILL.lerp(FILL_LOW, 0.5 + 0.5 * sin(_t * 6.0))
	if _heal > 0.0:
		c = c.lerp(HEAL, _heal / 0.4 * 0.7)
	draw_rect(Rect2(Vector2(PAD, PAD), Vector2(iw * k, H)), c)
	draw_rect(Rect2(Vector2(PAD, PAD), Vector2(iw * k, 2.0)), Color(1.0, 0.7, 0.6, 0.16))   # 위 가장자리 빛
