class_name ForgeTile
extends Control
## 대장간 그림 창의 타일 하나(2026-11-26): 검 카드, 보석 아이콘, 룬 무늬, 빈 보석 자리. 글자는 안 쓰고(작은 숫자 뱃지만) 설명은 마우스를 올리면 뜬다.
## 보석 그림은 코드로 그린 깎은 돌(위 면·기둥 면 6조각). 단계는 테두리 빛깔과 면 수(1단계 6면, 2단계 +결, 3단계 +결과 반짝임)로 보인다.

signal pressed

enum Kind { CARD, GEM, RUNE, SOCKET }

const RUNE_BLUE := Color(0.35, 0.72, 1.0)
const TIER_LINE: Array[Color] = [Color(0.45, 0.42, 0.38), Color(0.66, 0.56, 0.38), Color(0.98, 0.84, 0.46)]

var kind: Kind = Kind.CARD
var tex: Texture2D = null            # CARD
var col: Color = Color.WHITE         # 등급 색 / 보석 색
var tier: int = 1                    # GEM 단계
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
	return t


static func gem(key_col: Color, p_tier: int, n: int, tip: String, on_press: Callable, sz: float = 52.0) -> ForgeTile:
	var t := ForgeTile.new()
	t.kind = Kind.GEM
	t.col = key_col
	t.tier = p_tier
	t.count = n
	t.dim = n <= 0
	t.custom_minimum_size = Vector2(sz, sz)
	t.tooltip_text = tip
	t.pressed.connect(on_press)
	return t


static func rune(p_glyph: int, tip: String, locked: bool = false) -> ForgeTile:
	var t := ForgeTile.new()
	t.kind = Kind.RUNE
	t.glyph = p_glyph
	t.dim = locked
	t.custom_minimum_size = Vector2(44, 44)
	t.tooltip_text = tip
	return t


static func socket(set_gem: Array, tip: String, on_press: Callable) -> ForgeTile:
	## set_gem: 박힌 보석이면 [색, 단계], 비었으면 [].
	var t := ForgeTile.new()
	t.kind = Kind.SOCKET
	if not set_gem.is_empty():
		t.col = set_gem[0]
		t.tier = set_gem[1]
	else:
		t.dim = true
	t.custom_minimum_size = Vector2(52, 52)
	t.tooltip_text = tip
	t.pressed.connect(on_press)
	return t


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if (kind != Kind.RUNE or tooltip_text != "") else Control.MOUSE_FILTER_IGNORE
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
		Kind.GEM:
			draw_rect(r, Color(0.05, 0.045, 0.04, 0.9))
			_gem(size * 0.5 + Vector2(0, -1), size.x * 0.34, col, tier, 0.35 if dim else 1.0)
			var lc: Color = TIER_LINE[clampi(tier, 1, 3) - 1]
			var w: float = 3.0 if selected else 1.0 + (1.0 if tier == 3 else 0.0)
			draw_rect(r, Color(lc if not selected else Color(1, 0.95, 0.75), 0.4 if dim else (1.0 if (selected or hover) else 0.8)), false, w)
			if count > 0 or badge != "":
				_badge(badge if badge != "" else str(count))
		Kind.RUNE:
			draw_rect(r, Color(0.04, 0.05, 0.07, 0.9))
			_rune(size * 0.5, size.x * 0.34, glyph, 0.28 if dim else 1.0)
			draw_rect(r, Color(RUNE_BLUE, 0.2 if dim else 0.55), false, 1.0)
		Kind.SOCKET:
			draw_rect(r, Color(0.04, 0.035, 0.03, 0.9))
			if dim:
				var c: Vector2 = size * 0.5
				for i in 10:   # 끊어진 점선 고리 = 빈 자리
					var a: float = TAU * float(i) / 10.0
					draw_arc(c, size.x * 0.28, a, a + TAU / 20.0, 6, Color(0.85, 0.78, 0.6, 0.7 if hover else 0.4), 2.0)
				draw_rect(r, Color(0.66, 0.56, 0.38, 0.3), false, 1.0)
			else:
				_gem(size * 0.5 + Vector2(0, -1), size.x * 0.34, col, tier, 1.0)
				draw_rect(r, Color(TIER_LINE[clampi(tier, 1, 3) - 1], 1.0 if hover else 0.8), false, 2.0 if hover else 1.0)


func _badge(s: String) -> void:
	var f: Font = ThemeDB.fallback_font
	var w: float = maxf(16.0, f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 8.0)
	var br := Rect2(size.x - w - 2.0, size.y - 17.0, w, 15.0)
	draw_rect(br, Color(0.02, 0.02, 0.02, 0.92))
	draw_rect(br, Color(0.66, 0.56, 0.38, 0.8), false, 1.0)
	draw_string(f, br.position + Vector2(0, 12.0), s, HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(0.95, 0.9, 0.78))


## 깎은 돌: 위 면(밝음) 아래 기둥 면(어두움). 단계가 높으면 면이 늘고 반짝임이 붙는다.
func _gem(c: Vector2, s: float, base: Color, p_tier: int, a: float) -> void:
	var T1 := c + Vector2(-0.30, -0.62) * s
	var T2 := c + Vector2(0.30, -0.62) * s
	var G1 := c + Vector2(-0.68, -0.18) * s
	var G2 := c + Vector2(0.68, -0.18) * s
	var M1 := c + Vector2(-0.24, -0.18) * s
	var M2 := c + Vector2(0.24, -0.18) * s
	var P := c + Vector2(0.0, 0.78) * s
	var lite: Color = base.lightened(0.25)
	var facets: Array = [
		[[G1, T1, M1], 1.0], [[T1, T2, M2, M1], 1.35], [[T2, G2, M2], 0.8],
		[[G1, M1, P], 0.62], [[M1, M2, P], 1.0], [[M2, G2, P], 0.42],
	]
	for f in facets:
		var shade: float = f[1]
		var cc: Color = lite.lightened(clampf(shade - 1.0, 0.0, 0.6)) if shade >= 1.0 else base.darkened(1.0 - shade)
		cc.a = a
		draw_colored_polygon(PackedVector2Array(f[0]), cc)
	var ln := Color(1, 1, 1, 0.3 * a)
	draw_polyline(PackedVector2Array([G1, T1, T2, G2, P, G1]), Color(0, 0, 0, 0.55 * a), 1.5)
	draw_line(M1, M2, ln, 1.0)
	draw_line(T1, M1, ln, 1.0)
	draw_line(T2, M2, ln, 1.0)
	if p_tier >= 2:   # 결을 더 낸다: 기둥 면이 쪼개진다
		draw_line(P, c + Vector2(-0.46, -0.18) * s, ln, 1.0)
		draw_line(P, c + Vector2(0.46, -0.18) * s, ln, 1.0)
	if p_tier >= 3:   # 흠 없는 돌: 위 면도 쪼개지고 반짝인다
		draw_line(c + Vector2(0, -0.62) * s, c + Vector2(0, -0.18) * s, ln, 1.0)
		var sp: Vector2 = c + Vector2(-0.34, -0.42) * s
		var k: float = s * 0.26
		draw_line(sp + Vector2(-k, 0), sp + Vector2(k, 0), Color(1, 1, 1, 0.95 * a), 1.5)
		draw_line(sp + Vector2(0, -k), sp + Vector2(0, k), Color(1, 1, 1, 0.95 * a), 1.5)


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
