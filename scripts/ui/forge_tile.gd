class_name ForgeTile
extends Control
## 대장간 그림 창의 타일 하나(2026-11-26): 검 카드, 룬 아이콘(주머니·사기), 룬 자리(잠김·빈 자리·박힌 룬). 글자는 안 쓰고(작은 숫자 뱃지만) 설명은 마우스를 올리면 뜬다.
## 룬 그림은 코드로 그린 차가운 푸른 각진 무늬(마름모 테두리, V 표시: CarveOverlay와 같은 4가지). 단계는 테두리 빛깔·굵기와 무늬 아래 점(1~3개)으로 보인다.

signal pressed

enum Kind { CARD, RUNE, SOCKET }

const RUNE_BLUE := Color(0.35, 0.72, 1.0)
const TIER_LINE: Array[Color] = [Color(0.45, 0.42, 0.38), Color(0.66, 0.56, 0.38), Color(0.98, 0.84, 0.46)]

var kind: Kind = Kind.CARD
var tex: Texture2D = null            # CARD / 룬 모델 그림
var col: Color = Color.WHITE         # 등급 색
var tier: int = 1                    # 룬 단계
var glyph: int = 0                   # RUNE 무늬(0~3)
var count: int = 0                   # 작은 숫자 뱃지(0이면 안 그림)
var badge: String = ""               # 숫자 대신 글자(예: "+")
var selected: bool = false
var dim: bool = false                # 없음·잠김
var plus: bool = false


static func card(tx: Texture2D, grade_col: Color, tip: String, on_press: Callable) -> ForgeTile:
	var t := ForgeTile.new()
	t.kind = Kind.CARD
	t.tex = tx
	t.col = grade_col
	t.custom_minimum_size = Vector2(64, 64)
	t.tooltip_text = tip
	t.pressed.connect(on_press)
	var tilt := CardTilt.attach(t, grade_col, 5.0)   # 커서 쪽으로 기울기·등급 색 빛 받침줄(2026-11-28)
	tilt.gap = 4.0
	tilt.lift = 1.06
	tilt.rest_glow = 0.0   # 촘촘한 격자라 받침줄은 올렸을 때만
	return t


## 룬 아이콘(주머니·사기): 무늬 번호, 단계, 개수(0이면 흐리게).
static func rune(p_glyph: int, p_tier: int, n: int, tip: String, on_press: Callable, sz: float = 52.0) -> ForgeTile:
	var t := ForgeTile.new()
	t.kind = Kind.RUNE
	t.glyph = p_glyph
	t.tier = p_tier
	t.count = n
	t.dim = n <= 0
	t.custom_minimum_size = Vector2(sz, sz)
	t.tooltip_text = tip
	t.pressed.connect(on_press)
	return t


## 룬 자리 하나. p_glyph < 0이면 빈 자리(점선 고리), locked면 아직 안 열렸다. 박힌 룬이면 무늬와 단계.
static func slot(p_glyph: int, p_tier: int, tip: String, on_press: Callable, locked: bool = false) -> ForgeTile:
	var t := ForgeTile.new()
	t.kind = Kind.SOCKET
	t.glyph = p_glyph
	t.tier = p_tier
	t.dim = locked
	t.custom_minimum_size = Vector2(52, 52)
	t.tooltip_text = tip
	if not locked:
		t.pressed.connect(on_press)
	return t


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if pressed.get_connections().size() > 0:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()


func set_selected(on: bool) -> void:
	selected = on
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var hover: bool = get_global_rect().has_point(get_global_mouse_position()) and pressed.get_connections().size() > 0
	match kind:
		Kind.CARD:
			draw_rect(r, Color(0.05, 0.045, 0.04, 0.95))
			if tex != null:
				draw_texture_rect(tex, r.grow(-3), false, Color(1, 1, 1, 1.0))
			else:
				draw_arc(size * 0.5, 9.0, 0.0, TAU * 0.75, 20, Color(col, 0.6), 2.0)   # 아직 그리는 중
			var bw: float = 3.0 if selected else 2.0
			draw_rect(r, Color(col, 1.0 if (selected or hover) else 0.65), false, bw)
			if selected:
				draw_rect(r.grow(-bw), Color(col, 0.16))
		Kind.RUNE:
			draw_rect(r, Color(0.04, 0.05, 0.07, 0.9))
			if tex != null:   # Blender 룬 모델 그림(없으면 납작한 무늬)
				draw_texture_rect(tex, r.grow(-6), false, Color(1, 1, 1, 0.3 if dim else 1.0))
			else:
				_rune(size * 0.5 + Vector2(0, -2), size.x * 0.3, glyph, 0.3 if dim else 1.0)
			_tier_dots(Vector2(size.x * 0.5, size.y - 7.0), tier, 0.3 if dim else 1.0)
			var lc: Color = TIER_LINE[clampi(tier, 1, 3) - 1]
			var w: float = 3.0 if selected else 1.0 + (1.0 if tier == 3 else 0.0)
			draw_rect(r, Color(lc if not selected else Color(1, 0.95, 0.75), 0.4 if dim else (1.0 if (selected or hover) else 0.8)), false, w)
			if selected:
				draw_rect(r.grow(-w), Color(RUNE_BLUE, 0.12))
			if count > 0 or badge != "":
				_badge(badge if badge != "" else str(count))
		Kind.SOCKET:
			draw_rect(r, Color(0.04, 0.035, 0.03, 0.9))
			if glyph >= 0:
				draw_rect(r, Color(0.04, 0.05, 0.07, 0.9))
				_rune(size * 0.5 + Vector2(0, -2), size.x * 0.3, glyph, 1.0)
				_tier_dots(Vector2(size.x * 0.5, size.y - 7.0), tier, 1.0)
				draw_rect(r, Color(TIER_LINE[clampi(tier, 1, 3) - 1], 1.0 if hover else 0.8), false, 2.0 if hover else 1.0)
			else:
				var c: Vector2 = size * 0.5
				for i in 10:   # 끊어진 점선 고리 = 빈 자리
					var a: float = TAU * float(i) / 10.0
					draw_arc(c, size.x * 0.28, a, a + TAU / 20.0, 6, Color(0.85, 0.78, 0.6, 0.7 if hover else 0.4), 2.0)
				draw_rect(r, Color(0.66, 0.56, 0.38, 0.3), false, 1.0)


## 단계 점(1~3개).
func _tier_dots(c: Vector2, n: int, a: float) -> void:
	var col_t: Color = TIER_LINE[clampi(n, 1, 3) - 1]
	col_t.a = a
	for i in clampi(n, 1, 3):
		draw_circle(c + Vector2((float(i) - (clampi(n, 1, 3) - 1) * 0.5) * 6.0, 0), 1.6, col_t)


func _badge(s: String) -> void:
	var f: Font = ThemeDB.fallback_font
	var w: float = maxf(16.0, f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 8.0)
	var br := Rect2(size.x - w - 2.0, size.y - 17.0, w, 15.0)
	draw_rect(br, Color(0.02, 0.02, 0.02, 0.92))
	draw_rect(br, Color(0.66, 0.56, 0.38, 0.8), false, 1.0)
	draw_string(f, br.position + Vector2(0, 12.0), s, HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(0.95, 0.9, 0.78))


## 룬 무늬(CarveOverlay와 같은 4가지): 0 마름모 테두리, 1 V, 2 마름모+V, 3 겹친 V 둘. 차가운 푸른 빛.
func _rune(c: Vector2, s: float, g: int, a: float) -> void:
	var glow := Color(RUNE_BLUE, 0.22 * a)
	var line := Color(RUNE_BLUE.lightened(0.15), a)
	var strokes: Array = []
	match g:
		0, 2:
			var oy: float = -0.12 if g == 2 else 0.0
			strokes.append([Vector2(0, -0.8 + oy), Vector2(0.55, oy), Vector2(0, 0.8 + oy), Vector2(-0.55, oy), Vector2(0, -0.8 + oy)])
			if g == 2:
				strokes.append([Vector2(-0.3, 0.3), Vector2(0, 0.62), Vector2(0.3, 0.3)])
		1:
			strokes.append([Vector2(-0.55, -0.45), Vector2(0, 0.55), Vector2(0.55, -0.45)])
		3:
			strokes.append([Vector2(-0.5, -0.7), Vector2(0, -0.1), Vector2(0.5, -0.7)])
			strokes.append([Vector2(-0.5, 0.0), Vector2(0, 0.6), Vector2(0.5, 0.0)])
	for st in strokes:
		var pts := PackedVector2Array()
		for p in st:
			pts.append(c + (p as Vector2) * s)
		draw_polyline(pts, glow, 6.0, true)
		draw_polyline(pts, line, 2.0, true)
