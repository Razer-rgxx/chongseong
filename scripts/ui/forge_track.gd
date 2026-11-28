class_name ForgeTrack
extends Control
## 대장간 검집 강화 줄(2026-11-24): +1 … +max 칸을 한 줄로 그린다. 채운 칸이 지금 단계, 각인 단계(+5, +10)는 마름모,
## 실패하면 내려가는 단계(drop_from부터)는 칸 밑에 검붉은 줄. 다음 칸은 테두리가 밝게 깜박인다. 글자는 각인 단계 숫자만.

var lv: int = 0
var peak: int = 0
var max_lv: int = 10
var drop_from: int = 5
var marks: PackedInt32Array = PackedInt32Array([5, 10])
var _t: float = 0.0

const GOLD := Color(0.93, 0.78, 0.42)
const DIM := Color(0.42, 0.38, 0.32)
const DANGER := Color(0.62, 0.16, 0.12)


func _init() -> void:
	custom_minimum_size = Vector2(500, 44)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(p_lv: int, p_peak: int, p_max: int, p_drop: int, p_marks: PackedInt32Array) -> void:
	lv = p_lv
	peak = p_peak
	max_lv = p_max
	drop_from = p_drop
	marks = p_marks
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if lv < max_lv:
		queue_redraw()


func _draw() -> void:
	var n: int = maxi(1, max_lv)
	var w: float = size.x
	var gap: float = w / float(n)
	var cy: float = 14.0
	var font := get_theme_default_font()
	# 이어 주는 줄
	draw_line(Vector2(gap * 0.5, cy), Vector2(w - gap * 0.5, cy), Color(DIM, 0.6), 2.0)
	for i in n:
		var step: int = i + 1
		var x: float = gap * (i + 0.5)
		var on: bool = step <= lv
		var mark: bool = marks.has(step)
		var r: float = 8.0 if mark else 6.0
		var col: Color = GOLD if on else DIM
		if step >= drop_from:
			draw_line(Vector2(x - gap * 0.5 + 2.0, cy + 13.0), Vector2(x + gap * 0.5 - 2.0, cy + 13.0), DANGER, 3.0)
		var pts: PackedVector2Array
		if mark:
			pts = PackedVector2Array([Vector2(x, cy - r), Vector2(x + r, cy), Vector2(x, cy + r), Vector2(x - r, cy)])
		else:
			pts = PackedVector2Array()
			for k in 12:
				pts.append(Vector2(x, cy) + Vector2.from_angle(TAU * k / 12.0) * r)
		if on:
			draw_colored_polygon(pts, col)
		else:
			draw_colored_polygon(pts, Color(0.06, 0.05, 0.04, 0.9))
		var outline := pts.duplicate()
		outline.append(pts[0])
		var edge: Color = col
		var width: float = 1.5
		if step == lv + 1:
			edge = GOLD.lerp(Color.WHITE, 0.2) * Color(1, 1, 1, 0.55 + 0.45 * sin(_t * 5.0))   # 다음 칸
			width = 2.5
		elif step <= peak and not on:
			edge = Color(GOLD, 0.5)   # 예전에 닿았던 곳(각인은 다시 안 붙는다)
		draw_polyline(outline, edge, width, true)
		if mark and font:
			var s: String = "+%d" % step
			var fs: int = 13
			var tw: float = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, Vector2(x - tw / 2.0, cy + 30.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GOLD if peak < step else DIM)
