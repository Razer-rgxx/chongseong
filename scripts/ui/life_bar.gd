class_name LifeBar
extends Control
## 영주 체력 막대(2026-11-21, 같은 날 다시 그림: "체력바 UI 구리다"): 글자 없이 막대만.
## 상자 테두리 대신 위아래 놋쇠 실선과 양 끝 놋쇠 마개(왼쪽은 마름모), 붉은 채움은 위가 밝고 아래가 짙은 결,
## 맨 위 한 줄 빛. 깎인 몫은 옅은 금빛으로 잠깐 남았다 따라 줄고, 차오르면 잠깐 밝아지고, 30% 아래면 막대 둘레가 숨쉬듯 붉게 번진다.
## 최대 체력이 늘면 막대가 길어진다(자란 만큼 눈에 보이게). 언덕(hud)·들판·마을·무덤(lobby_hud)이 같이 쓴다.

const H: float = 8.0
## 막대 둘레 여백(왼쪽 마름모 자리 포함).
const PAD_L: float = 12.0
const PAD_R: float = 5.0
const PAD_Y: float = 5.0
## 기본 체력(140)일 때 막대 너비, 가장 긴 너비.
const BASE_W: float = 260.0
const BASE_HP: float = 140.0
const MAX_W: float = 500.0
## 깎인 몫이 머무는 초, 따라 줄어드는 빠르기(최대 체력의 몫/초), 낮은 체력의 기준.
const HOLD: float = 0.45
const LAG_SPEED: float = 0.6
const LOW: float = 0.3

const TOP: Color = Color(0.74, 0.17, 0.13)
const BOTTOM: Color = Color(0.4, 0.05, 0.05)
const LAG: Color = Color(0.86, 0.7, 0.48, 0.34)
const HEAL: Color = Color(0.98, 0.88, 0.64)
const BACK: Color = Color(0.035, 0.022, 0.02, 0.78)
const BRASS: Color = Color(0.72, 0.6, 0.4)

var hp: float = -1.0
var max_hp: float = 1.0
var lag: float = -1.0
var _hold: float = 0.0
var _heal: float = 0.0
var _t: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(BASE_W + PAD_L + PAD_R, H + PAD_Y * 2.0)


## 최대 체력에 맞는 막대 너비(px, 여백 빼고).
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
	var sz := Vector2(width_for(m) + PAD_L + PAD_R, H + PAD_Y * 2.0)
	if not custom_minimum_size.is_equal_approx(sz):
		custom_minimum_size = sz
		size = sz


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
	var x0: float = PAD_L
	var y0: float = PAD_Y
	var k: float = clampf(hp / max_hp, 0.0, 1.0)
	var lk: float = clampf(lag / max_hp, 0.0, 1.0)
	# 낮은 체력: 막대 둘레가 붉게 번진다(숨쉬듯)
	if k < LOW and k > 0.0:
		var p: float = 0.5 + 0.5 * sin(_t * 5.0)
		for i in 3:
			var g: float = 2.0 + i * 2.5
			draw_rect(Rect2(x0 - g, y0 - g, w + g * 2.0, H + g * 2.0), Color(0.9, 0.12, 0.08, (0.1 - i * 0.03) * p))
	# 바탕
	draw_rect(Rect2(x0, y0, w, H), BACK)
	# 깎인 몫
	if lk > k:
		draw_rect(Rect2(x0 + w * k, y0, w * (lk - k), H), LAG)
	# 채움: 위가 밝고 아래가 짙은 결
	if k > 0.0:
		var fw: float = w * k
		var top: Color = TOP
		var bot: Color = BOTTOM
		if _heal > 0.0:
			var h: float = _heal / 0.4 * 0.6
			top = top.lerp(HEAL, h)
			bot = bot.lerp(HEAL.darkened(0.3), h)
		draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x0 + fw, y0), Vector2(x0 + fw, y0 + H), Vector2(x0, y0 + H)]),
			PackedColorArray([top, top, bot, bot]))
		draw_line(Vector2(x0, y0 + 0.5), Vector2(x0 + fw, y0 + 0.5), Color(1.0, 0.62, 0.52, 0.35), 1.0)   # 맨 위 빛
		draw_line(Vector2(x0 + fw - 0.5, y0), Vector2(x0 + fw - 0.5, y0 + H), Color(1.0, 0.7, 0.6, 0.3), 1.0)   # 끝 날
	# 위아래 놋쇠 실선(양 끝으로 갈수록 옅다)
	for y in [y0 - 1.5, y0 + H + 1.5]:
		draw_polyline_colors(PackedVector2Array([Vector2(x0 - 2.0, y), Vector2(x0 + w * 0.5, y), Vector2(x0 + w + 2.0, y)]),
			PackedColorArray([Color(BRASS, 0.85), Color(BRASS, 0.55), Color(BRASS, 0.85)]), 1.0)
	# 양 끝 마개: 오른쪽은 세로 놋쇠 줄, 왼쪽은 작은 마름모
	draw_line(Vector2(x0 + w + 2.5, y0 - 2.5), Vector2(x0 + w + 2.5, y0 + H + 2.5), Color(BRASS, 0.9), 1.5)
	var c := Vector2(x0 - 5.5, y0 + H / 2.0)
	var dia := PackedVector2Array([c + Vector2(0, -5), c + Vector2(4, 0), c + Vector2(0, 5), c + Vector2(-4, 0)])
	draw_colored_polygon(dia, Color(0.08, 0.05, 0.04))
	draw_polyline(dia + PackedVector2Array([dia[0]]), BRASS, 1.2)
	draw_circle(c, 1.4, TOP.lerp(Color.WHITE, 0.15) if k > 0.0 else Color(0.3, 0.3, 0.3))
