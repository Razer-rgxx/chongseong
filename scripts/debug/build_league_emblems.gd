extends SceneTree
## 결투 리그 티어 문장 아홉(8 티어 + 언덕의 검)을 코드로 그려 assets/ui/league/tier_<n>.svg로 쓴다(docs/duel_league.md).
## 놋쇠빛 테두리와 검 모양은 같고, 바깥 모양과 색이 티어마다 다르다. 투명 바탕, 96 × 96.
## 다시 만들기: godot --headless --path . -s scripts/debug/build_league_emblems.gd  (그다음 --import)
##   0 녹쇠 마름모(녹빛)   1 청동 육각형   2 은 팔각형   3 금 방패   4 백금 오각형(청록)
##   5 금강 길쭉한 보석(푸른빛)   6 승천 날개(초록)   7 불멸 가시 별(붉은빛)   8 언덕의 검 왕관과 언덕(옅은 금)

const DIR := "res://assets/ui/league/"
const BRASS := "#A88F61"
const DARK := "#14110d"
const COLORS: Array[String] = ["#8a5a3c", "#b0713a", "#b9c0c8", "#d4b04a", "#5fc7bb", "#6f9bff", "#58c78d", "#c0394d", "#f0e2a8"]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	for t in 9:
		_write(t)
	quit()


func _write(t: int) -> void:
	var col: String = COLORS[t]
	var parts: Array[String] = []
	parts.append_array(_shape(t, col))
	parts.append_array(_sword(t))
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96">\n%s\n</svg>\n' % "\n".join(parts)
	var f := FileAccess.open(DIR + "tier_%d.svg" % t, FileAccess.WRITE)
	f.store_string(svg)
	f.close()


func _pts(a: Array[Vector2]) -> String:
	var out: PackedStringArray = []
	for p in a:
		out.append("%.1f,%.1f" % [p.x, p.y])
	return " ".join(out)


func _ngon(n: int, r: float, rot: float, c: Vector2 = Vector2(48, 48)) -> Array[Vector2]:
	var a: Array[Vector2] = []
	for i in n:
		var ang: float = rot + TAU * i / n
		a.append(c + Vector2(cos(ang), sin(ang)) * r)
	return a


## 바깥 모양: 어두운 바탕 + 티어 색 면(옅게) + 놋쇠 테두리.
func _poly(a: Array[Vector2], col: String) -> Array[String]:
	return [
		'<polygon points="%s" fill="%s" fill-opacity="0.92" stroke="%s" stroke-width="4" stroke-linejoin="miter"/>' % [_pts(a), DARK, BRASS],
		'<polygon points="%s" fill="%s" fill-opacity="0.28" stroke="%s" stroke-width="2" stroke-linejoin="miter"/>' % [_pts(_scale(a, 0.82)), col, col],
	]


func _scale(a: Array[Vector2], k: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p in a:
		out.append(Vector2(48, 48) + (p - Vector2(48, 48)) * k)
	return out


func _shape(t: int, col: String) -> Array[String]:
	var s: Array[String] = []
	match t:
		0:   # 마름모
			s = _poly([Vector2(48, 6), Vector2(88, 48), Vector2(48, 90), Vector2(8, 48)], col)
		1:   # 육각형
			s = _poly(_ngon(6, 42.0, 0.0), col)
		2:   # 팔각형
			s = _poly(_ngon(8, 42.0, PI / 8.0), col)
		3:   # 방패
			s = _poly([Vector2(12, 10), Vector2(84, 10), Vector2(84, 48), Vector2(70, 72), Vector2(48, 90), Vector2(26, 72), Vector2(12, 48)], col)
		4:   # 오각형(꼭짓점이 위)
			s = _poly(_ngon(5, 44.0, -PI / 2.0), col)
		5:   # 길쭉한 보석
			s = _poly([Vector2(48, 4), Vector2(76, 26), Vector2(76, 62), Vector2(48, 92), Vector2(20, 62), Vector2(20, 26)], col)
		6:   # 날개: 가운데 마름모 + 양옆 날개깃
			s = _poly([Vector2(48, 10), Vector2(66, 30), Vector2(66, 66), Vector2(48, 86), Vector2(30, 66), Vector2(30, 30)], col)
			for side in [-1.0, 1.0]:
				var w: Array[Vector2] = [Vector2(48 + side * 19, 36), Vector2(48 + side * 44, 14), Vector2(48 + side * 40, 40), Vector2(48 + side * 46, 44), Vector2(48 + side * 38, 56), Vector2(48 + side * 19, 56)]
				s.append('<polygon points="%s" fill="%s" fill-opacity="0.9" stroke="%s" stroke-width="3" stroke-linejoin="miter"/>' % [_pts(w), DARK, BRASS])
		7:   # 가시 별(8갈래)
			var a: Array[Vector2] = []
			for i in 16:
				var ang: float = -PI / 2.0 + TAU * i / 16.0
				a.append(Vector2(48, 48) + Vector2(cos(ang), sin(ang)) * (46.0 if i % 2 == 0 else 30.0))
			s = _poly(a, col)
		8:   # 왕관 모양 윗면과 언덕 밑
			s = _poly([Vector2(10, 82), Vector2(10, 30), Vector2(28, 46), Vector2(48, 8), Vector2(68, 46), Vector2(86, 30), Vector2(86, 82), Vector2(48, 92)], col)
			s.append('<path d="M14 80 Q48 58 82 80" fill="none" stroke="%s" stroke-width="2.5"/>' % col)
	# 티어마다 점 하나씩 더 늘어나는 작은 마름모(위 8개 중 몇째인지 한눈에): 아래 가운데 줄
	if t < 8:
		for i in t + 1:
			var cx: float = 48.0 + (i - t / 2.0) * 7.0
			s.append('<polygon points="%s" fill="%s"/>' % [_pts([Vector2(cx, 86), Vector2(cx + 2.6, 88.6), Vector2(cx, 91.2), Vector2(cx - 2.6, 88.6)]), col])
	return s


## 가운데의 검(놋쇠빛 몸, 티어 색 얇은 줄).
func _sword(t: int) -> Array[String]:
	var blade: Array[Vector2] = [Vector2(48, 18), Vector2(53, 28), Vector2(53, 58), Vector2(48, 64), Vector2(43, 58), Vector2(43, 28)]
	var guard: Array[Vector2] = [Vector2(33, 58), Vector2(63, 58), Vector2(63, 63), Vector2(33, 63)]
	var grip: Array[Vector2] = [Vector2(45.5, 63), Vector2(50.5, 63), Vector2(50.5, 73), Vector2(45.5, 73)]
	var pommel: Array[Vector2] = [Vector2(48, 72), Vector2(52, 76), Vector2(48, 80), Vector2(44, 76)]
	var out: Array[String] = []
	for poly in [blade, guard, grip, pommel]:
		out.append('<polygon points="%s" fill="%s" stroke="%s" stroke-width="1.2" stroke-linejoin="miter"/>' % [_pts(poly), BRASS, DARK])
	out.append('<line x1="48" y1="24" x2="48" y2="56" stroke="%s" stroke-width="1.4" stroke-opacity="0.9"/>' % COLORS[t])
	return out
