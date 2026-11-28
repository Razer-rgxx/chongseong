extends SceneTree
## 지도 창(13단계 갈림길)의 아이콘을 코드로 그려 assets/ui/map/*.svg로 쓴다(모양팀).
## 동작 아이콘(assets/ui/moves)과 같은 결: 투명 바탕, 놋쇠빛 #A88F61, 각진 선(square cap, miter), 작은 마름모 꾸밈.
## 다시 만들기: godot --headless --path . -s scripts/debug/build_map_icons.gd  (그다음 --import로 들여온다)
##
## 파일(이름이 곧 id):
##   zone_visited, zone_current, zone_next   구역 점(32 × 32): 지나온 곳, 지금, 다음 갈래
##   path, path_next                         구역 사이 길(16 × 64, 세로로 늘인다): 지나온 길(실선), 갈 수 있는 길(점선)
##   reward_pulls, reward_heal, reward_whet, reward_luck, reward_shards    보상(64 × 64)
##   goal_survive, goal_defend, goal_hunt, goal_siege                       밤의 목표(64 × 64)
##   rule_fog, rule_embers, rule_graves                                     구역 규칙(64 × 64)

const DIR := "res://assets/ui/map/"
const C := "#A88F61"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	# 구역 점
	_write("zone_visited", 32, [_poly(_diamond(16, 16, 6.0), 0.7)])
	_write("zone_current", 32, [_poly(_diamond(16, 16, 7.0), 1.0), _line(_diamond(16, 16, 12.5), 2.0, 1.0, true)])
	_write("zone_next", 32, [_line(_diamond(16, 16, 7.5), 2.2, 0.9, true)])
	# 길
	_write_wh("path", 16, 64, ['<path d="M8 0 L8 64" fill="none" stroke="%s" stroke-width="2.2" stroke-linecap="butt" stroke-opacity="0.75"/>' % C])
	_write_wh("path_next", 16, 64, ['<path d="M8 2 L8 64" fill="none" stroke="%s" stroke-width="2.2" stroke-linecap="butt" stroke-dasharray="5 5" stroke-opacity="0.55"/>' % C])
	# 보상
	_write("reward_pulls", 64, [
		_line([Vector2(10, 51), Vector2(54, 51)], 2.2, 0.6),
		_line([Vector2(24, 51), Vector2(21, 56)], 2.0, 0.45),
		_line([Vector2(41, 51), Vector2(44, 57)], 2.0, 0.45),
		_poly([Vector2(29.5, 29), Vector2(34.5, 29), Vector2(34.5, 46), Vector2(32, 51), Vector2(29.5, 46)], 1.0),
		_line([Vector2(21, 26), Vector2(43, 26)], 3.0, 1.0),
		_line([Vector2(32, 13), Vector2(32, 23.5)], 3.2, 1.0),
		_poly(_diamond(32, 8.5, 3.5), 1.0),
		_poly(_diamond(50, 14, 3.2), 0.9),
		_poly(_diamond(50, 24, 3.2), 0.9),
	])
	var body: Array[Vector2] = [Vector2(28, 10), Vector2(28, 26.6)]
	body.append_array(_arc(32, 40, 14.0, -106.6, -433.4, 28, true))
	body.append(Vector2(36, 10))
	var liquid: Array[Vector2] = _arc(32, 40, 10.5, 15.0, 165.0, 20)
	_write("reward_heal", 64, [
		_line([Vector2(25, 8), Vector2(39, 8)], 3.0, 1.0),
		_line(body, 3.0, 1.0),
		_poly(liquid, 0.9),
		_line([Vector2(23, 35), Vector2(27, 31)], 2.0, 0.5),
	])
	_write("reward_whet", 64, [
		_line([Vector2(10, 40), Vector2(54, 40), Vector2(54, 53), Vector2(10, 53)], 3.0, 1.0, true),
		_line([Vector2(15, 47), Vector2(30, 47)], 2.0, 0.45),
		_line([Vector2(36, 47), Vector2(46, 47)], 2.0, 0.45),
		_poly([Vector2(13, 37), Vector2(50, 14), Vector2(54, 16.5), Vector2(17, 39.5)], 1.0),
		_line([Vector2(50, 14), Vector2(56, 10)], 3.0, 1.0),
		_line([Vector2(22, 27), Vector2(18, 23)], 2.2, 0.7),
		_line([Vector2(27, 25), Vector2(26, 19)], 2.2, 0.7),
	])
	var shoe: Array[Vector2] = _arc(32, 32, 18.5, -18.0, 198.0, 30)
	shoe.append_array(_arc(32, 32, 11.0, 198.0, -18.0, 22))
	var nails: Array[String] = []
	for a: float in [12.0, 55.0, 125.0, 168.0]:
		var p := Vector2(32, 32) + Vector2(cos(deg_to_rad(a)), sin(deg_to_rad(a))) * 14.75
		nails.append(_poly(_diamond(p.x, p.y, 1.8), 1.0))
	_write("reward_luck", 64, [_line(shoe, 2.6, 1.0, true)] + nails)
	_write("reward_shards", 64, [
		_poly([Vector2(21, 53), Vector2(26, 20), Vector2(31, 17), Vector2(34, 47)], 1.0),
		_poly([Vector2(36, 54), Vector2(41, 29), Vector2(46, 27), Vector2(47, 52)], 0.75),
		_poly([Vector2(10, 54), Vector2(14, 41), Vector2(18, 40), Vector2(20, 54)], 0.5),
		_line([Vector2(8, 56), Vector2(56, 56)], 2.0, 0.5),
		_poly(_diamond(46, 14, 3.0), 0.9),
	])
	# 밤의 목표
	_write("goal_survive", 64, [
		_line([Vector2(17, 9), Vector2(47, 9)], 3.0, 1.0),
		_line([Vector2(17, 55), Vector2(47, 55)], 3.0, 1.0),
		_line([Vector2(21, 12), Vector2(43, 12), Vector2(34.5, 32), Vector2(43, 52), Vector2(21, 52), Vector2(29.5, 32)], 2.4, 1.0, true),
		_poly([Vector2(25.5, 49), Vector2(38.5, 49), Vector2(32, 41)], 1.0),
		_poly([Vector2(27, 19), Vector2(37, 19), Vector2(32, 27.5)], 0.8),
		_line([Vector2(32, 33), Vector2(32, 39)], 1.8, 0.7),
	])
	_write("goal_defend", 64, [
		_poly([Vector2(32, 5), Vector2(38.5, 14), Vector2(39, 20), Vector2(35.5, 24.5), Vector2(28.5, 24.5), Vector2(25, 20), Vector2(26.5, 15), Vector2(29.5, 17)], 1.0),
		_line([Vector2(19, 27), Vector2(45, 27)], 3.0, 1.0),
		_line([Vector2(21, 27), Vector2(27, 39), Vector2(37, 39), Vector2(43, 27)], 2.6, 1.0),
		_line([Vector2(28, 27), Vector2(30.5, 39)], 2.0, 0.6),
		_line([Vector2(36, 27), Vector2(33.5, 39)], 2.0, 0.6),
		_line([Vector2(32, 39), Vector2(32, 44)], 3.0, 1.0),
		_line([Vector2(23, 56), Vector2(25.5, 44), Vector2(38.5, 44), Vector2(41, 56)], 2.6, 1.0),
		_line([Vector2(14, 56), Vector2(50, 56)], 2.4, 0.7),
	])
	_write("goal_hunt", 64, [
		_ellipse(32, 51, 21, 6, 2.2, 0.55),
		_line([Vector2(24, 23), Vector2(32, 16), Vector2(40, 23), Vector2(40, 34), Vector2(36, 39), Vector2(28, 39), Vector2(24, 34)], 2.6, 1.0, true),
		_line([Vector2(24, 23), Vector2(17, 18), Vector2(14, 9), Vector2(20, 14)], 2.6, 1.0),
		_line([Vector2(40, 23), Vector2(47, 18), Vector2(50, 9), Vector2(44, 14)], 2.6, 1.0),
		_poly(_diamond(28.5, 28.5, 2.6), 1.0),
		_poly(_diamond(35.5, 28.5, 2.6), 1.0),
		_line([Vector2(30, 39), Vector2(30, 43)], 2.0, 0.7),
		_line([Vector2(34, 39), Vector2(34, 43)], 2.0, 0.7),
	])
	_write("goal_siege", 64, [
		_line([Vector2(12, 26), Vector2(12, 54), Vector2(52, 54), Vector2(52, 26)], 2.0, 0.45),
		_line([Vector2(10, 26), Vector2(54, 26)], 4.0, 1.0),
		_line([Vector2(20, 5), Vector2(20, 19)], 2.4, 1.0),
		_line([Vector2(16, 15), Vector2(20, 19.5), Vector2(24, 15)], 2.4, 1.0),
		_line([Vector2(32, 3), Vector2(32, 19)], 2.4, 1.0),
		_line([Vector2(28, 15), Vector2(32, 19.5), Vector2(36, 15)], 2.4, 1.0),
		_line([Vector2(44, 5), Vector2(44, 19)], 2.4, 1.0),
		_line([Vector2(40, 15), Vector2(44, 19.5), Vector2(48, 15)], 2.4, 1.0),
		_poly(_diamond(32, 41, 3.2), 0.6),
	])
	# 구역 규칙
	_write("rule_fog", 64, [
		_wave(10, 54, 20, 3.0, 1.0),
		_wave(14, 50, 32, 3.0, 0.7),
		_wave(8, 56, 44, 3.0, 0.45),
	])
	_write("rule_embers", 64, [
		_poly([Vector2(32, 8), Vector2(39, 18), Vector2(41, 28), Vector2(38.5, 35), Vector2(32, 39), Vector2(25.5, 35), Vector2(23, 28), Vector2(26, 20), Vector2(29, 25)], 1.0),
		_line([Vector2(8, 48), Vector2(56, 48)], 2.4, 0.8),
		_line([Vector2(19, 48), Vector2(16, 53), Vector2(18, 57)], 2.0, 0.6),
		_line([Vector2(33, 48), Vector2(35, 53), Vector2(32, 58)], 2.0, 0.6),
		_line([Vector2(47, 48), Vector2(50, 54)], 2.0, 0.6),
		_poly(_diamond(16, 32, 2.2), 0.75),
		_poly(_diamond(48, 26, 2.2), 0.75),
	])
	_write("rule_graves", 64, [
		_line([Vector2(8, 54), Vector2(56, 54)], 2.2, 0.6),
		_line(_arc(32, 62, 22.0, -160.0, -20.0, 18), 3.0, 1.0),
		'<g transform="rotate(-9 32 44)">' + _line([Vector2(25, 45), Vector2(25, 21), Vector2(28, 15), Vector2(36, 15), Vector2(39, 21), Vector2(39, 45)], 2.6, 1.0) + '</g>',
		_line([Vector2(30, 27), Vector2(36, 27)], 2.0, 0.5),
	])
	print("map icons written: ", ProjectSettings.globalize_path(DIR))
	quit()


func _write(name: String, size: int, parts: Array) -> void:
	_write_wh(name, size, size, parts)


func _write_wh(name: String, w: int, h: int, parts: Array) -> void:
	var s := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n' % [w, h, w, h]
	for p: String in parts:
		s += "\t" + p + "\n"
	s += "</svg>\n"
	var f := FileAccess.open(DIR + name + ".svg", FileAccess.WRITE)
	f.store_string(s)
	f.close()


func _d(pts: Array[Vector2], close: bool) -> String:
	var s := ""
	for i in pts.size():
		s += ("M" if i == 0 else " L") + "%s %s" % [_n(pts[i].x), _n(pts[i].y)]
	if close:
		s += " Z"
	return s


func _n(v: float) -> String:
	var r: float = snappedf(v, 0.1)
	return str(int(r)) if is_equal_approx(r, roundf(r)) else "%.1f" % r


func _line(pts: Array[Vector2], width: float, opacity: float, close: bool = false) -> String:
	var op: String = "" if opacity >= 1.0 else ' stroke-opacity="%.2f"' % opacity
	return '<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="square" stroke-linejoin="miter" stroke-miterlimit="8"%s/>' % [_d(pts, close), C, _n(width), op]


func _poly(pts: Array[Vector2], opacity: float) -> String:
	var op: String = "" if opacity >= 1.0 else ' fill-opacity="%.2f"' % opacity
	return '<path d="%s" fill="%s" stroke="none"%s/>' % [_d(pts, true), C, op]


func _ellipse(cx: float, cy: float, rx: float, ry: float, width: float, opacity: float) -> String:
	return '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="none" stroke="%s" stroke-width="%s" stroke-opacity="%.2f"/>' % [_n(cx), _n(cy), _n(rx), _n(ry), C, _n(width), opacity]


func _wave(x0: float, x1: float, y: float, width: float, opacity: float) -> String:
	var pts: Array[Vector2] = []
	for i in 25:
		var x: float = lerpf(x0, x1, i / 24.0)
		pts.append(Vector2(x, y + sin((x - x0) / (x1 - x0) * TAU * 1.5) * 3.0))
	return _line(pts, width, opacity)


func _diamond(cx: float, cy: float, r: float) -> Array[Vector2]:
	return [Vector2(cx, cy - r), Vector2(cx + r, cy), Vector2(cx, cy + r), Vector2(cx - r, cy)]


## 원호 위의 점들(도, SVG 좌표: 0 = 오른쪽, 90 = 아래). a0에서 a1까지.
func _arc(cx: float, cy: float, r: float, a0: float, a1: float, steps: int, skip_first: bool = false) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in range(1 if skip_first else 0, steps + 1):
		var a: float = deg_to_rad(lerpf(a0, a1, float(i) / steps))
		out.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	return out
