class_name FieldMap
extends Control
## 들판 지도(38단계, docs/open_world2.md). 들판에서 M(행동 map)으로 연다. 열려 있는 동안 게임을 멈추고(SettingsPanel처럼 PROCESS_MODE_ALWAYS)
## 마우스를 풀어 주며, Esc·M으로 닫는다.
## 그림: 어두운 먹빛 바탕에 놋쇠빛 선(엘든 링 지도 느낌). 땅은 FieldBuilder.height의 음영과 높이 선, 물(개울·늪)은 땅이 물 높이보다 낮은 곳,
## 길(FieldLayout.ROAD)·돌다리·성채와 불탄 마을의 벽·채석장과 고개의 벼랑·망루·무덤 입구·목책은 FieldLayout의 표, 나무는 장면의 막힘 원(작은 것),
## 둘레의 숲 띠는 BORDER_RECTS. 곳 이름(FieldLayout.MAP_LABELS)은 화면 글자다(지도 창은 화면이라 괜찮다, 세계에는 글자 없음).
## 가 본 곳(Meta.field_seen)만 밝혀지고 나머지는 먹구름이 덮는다. 표시(markers)는 영주(보는 쪽 화살), 마을 북문·언덕길·무덤 입구, 떨군 검(늘),
## 떠도는 사람·우두머리·무덤 기사·유품 상자(본 곳에 있을 때만, 잡은 것·연 것은 흐리게).
## 휠로 확대·축소(커서 밑 자리를 붙잡고), 왼쪽 단추로 끌어서 옮긴다. 규칙은 읽기만 한다.

signal closed

## 바탕 그림: 들판 한 칸에 몇 점(칠하는 점, 높이를 재는 점), 높이 선 간격(m), 음영을 볼 때 높이를 키우는 배수(들판의 굴곡이 완만해서).
const BASE_PX: int = 4
const SAMPLE_PX: int = 2
const CONTOUR: float = 1.5
const RELIEF: float = 9.0
## 먹구름 그림: 밝힘 격자 한 칸에 몇 점, 가장자리 흔들림.
const FOG_PX: int = 4
const FOG_NOISE: float = 0.5
## 배율: 한눈에 다 보이는 배율(fit)부터 그 몇 배까지, 휠 한 칸에 곱하는 값.
const ZOOM_MAX: float = 5.0
const ZOOM_STEP: float = 1.15
## 나무로 그리는 막힘 원의 반지름(칸) 상한: 나무 둥치(0.3~0.35)만, 돌기둥·수레·사람 곁 모닥불 둘레는 뺀다.
const TREE_MAX_R: float = 0.38

## 색: 먹빛 바탕, 놋쇠빛 선.
const INK := Color(0.072, 0.064, 0.052)
const INK_HIGH := Color(0.16, 0.135, 0.1)
const ROCK := Color(0.13, 0.12, 0.11)
const WATER := Color(0.05, 0.075, 0.085)
const MARSH_WATER := Color(0.058, 0.08, 0.07)
const BRASS := Color(0.76, 0.64, 0.42)
const ROAD_C := Color(0.46, 0.37, 0.24)
const WALL_C := Color(0.72, 0.61, 0.42)
const CLIFF_C := Color(0.2, 0.18, 0.15)
const TREE_C := Color(0.028, 0.032, 0.024)
const FOG_C := Color(0.02, 0.017, 0.014)
const LORD_C := Color(0.98, 0.92, 0.78)
const CHIEF_C := Color(0.78, 0.3, 0.2)
const CACHE_C := Color(0.86, 0.72, 0.42)
## 범례 줄(표시 종류, 이름).
const LEGEND: Array = [
	[&"lord", "영주"], [&"gate", "마을 북문"], [&"trail", "언덕길"], [&"crypt", "지하 무덤"], [&"dropped", "떨군 검"],
	[&"wanderer", "떠도는 사람"], [&"chief", "우두머리"], [&"cache", "유품"],
]

var data: GameData
var meta: Meta
var rules: Rules
## 나무 둥치 자리(칸).
var trees: PackedVector2Array = PackedVector2Array()

## 땅 그림은 한 번 만들어 세션 내내 쓴다(들판의 땅은 바뀌지 않는다). 먹구름은 열 때마다.
static var _base: ImageTexture = null
static var _road_cells: PackedVector2Array = PackedVector2Array()
static var _brook_cells: PackedVector2Array = PackedVector2Array()
var _fog: ImageTexture
var _view: Control
var _legend: Control
var _zoom: float = 0.0
var _fit: float = 1.0
var _center: Vector2 = Vector2.ZERO
var _drag: bool = false
var _was_paused: bool = false
var _was_mouse: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


## 장면이 M에서 부른다. circles: 장면의 막힘 원([칸 자리, 반지름], 작은 것이 나무).
static func make(parent: Node, d: GameData, m: Meta, r: Rules, circles: Array) -> FieldMap:
	var f := FieldMap.new()
	f.name = "FieldMap"
	f.data = d
	f.meta = m
	f.rules = r
	f.trees = tree_spots(circles)
	parent.add_child(f)
	return f


## 막힘 원 가운데 나무 둥치(작은 원)만.
static func tree_spots(circles: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for c in circles:
		if float(c[1]) <= TREE_MAX_R:
			out.append(c[0])
	return out


## 지도에 놓을 표시(영주 빼고): [{kind, at(칸), faded}]. 마을 북문·언덕길·무덤 입구·떨군 검은 늘, 떠도는 사람·우두머리·무덤 기사·유품 상자는
## 그 자리를 본 때만(잡은 우두머리·무덤 기사와 연 상자는 흐리게).
static func markers(m: Meta) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in FieldLayout.CACHES:
		var at: Vector2 = FieldLayout.CACHES[id][0]
		if m.seen_at(at):
			out.append({"kind": &"cache", "at": at, "faded": m.field_found.has(id), "id": id})
	out.append({"kind": &"gate", "at": FieldLayout.GATE, "faded": false})
	out.append({"kind": &"trail", "at": FieldLayout.TRAILHEAD, "faded": false})
	out.append({"kind": &"crypt", "at": FieldLayout.CRYPT_DOOR, "faded": false})
	for id in FieldLayout.CHIEFS:
		var at: Vector2 = FieldLayout.CHIEFS[id].at
		if m.seen_at(at):
			out.append({"kind": &"chief", "at": at, "faded": m.chiefs_down.has(id), "id": id})
	if m.seen_at(FieldLayout.BOSS_AT):
		out.append({"kind": &"boss", "at": FieldLayout.BOSS_AT, "faded": m.boss_down, "id": String(FieldLayout.BOSS_ID)})
	if m.wanderer != "" and m.wanderer_at >= 0 and m.wanderer_at < FieldLayout.WANDERER_SPOTS.size():
		var at: Vector2 = FieldLayout.WANDERER_SPOTS[m.wanderer_at].at
		if m.seen_at(at):
			out.append({"kind": &"wanderer", "at": at, "faded": false, "id": m.wanderer})
	if not m.dropped.is_empty():
		out.append({"kind": &"dropped", "at": m.dropped_at(), "faded": false})
	return out


## 보이는 곳 이름: [곳 id, 칸 자리] (이름 자리를 본 때만).
static func labels(m: Meta) -> Array:
	var out: Array = []
	for a in FieldLayout.MAP_LABELS:
		var at: Vector2 = FieldLayout.MAP_LABELS[a]
		if m.seen_at(at):
			out.append([a, at])
	return out


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	UiKit.vignette(self)
	var p := PanelContainer.new()
	var st := UiKit.style(Color(UiKit.LINE, 0.45), 1, Color(0.025, 0.021, 0.017, 0.96))
	p.add_theme_stylebox_override("panel", st)
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.offset_left = 56
	p.offset_right = -56
	p.offset_top = 40
	p.offset_bottom = -40
	add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	p.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	var t := UiKit.label("들판 지도", 26, UiKit.TITLE)
	head.add_child(t)
	var seen: int = meta.seen_count()
	var total: int = FieldLayout.SEEN_SIZE.x * FieldLayout.SEEN_SIZE.y
	var sl := UiKit.label("가 본 곳 %d%%" % roundi(100.0 * seen / maxf(1.0, total)), 15, UiKit.MUTED)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(sl)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	head.add_child(UiKit.button("M · Esc  닫기", close, 34))
	box.add_child(head)
	box.add_child(UiKit.rule())
	_view = Control.new()
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.mouse_default_cursor_shape = Control.CURSOR_DRAG
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_view.draw.connect(_draw_map)
	_view.gui_input.connect(_on_view_input)
	_view.resized.connect(func() -> void:
		_zoom = 0.0
		_view.queue_redraw())
	box.add_child(_view)
	box.add_child(UiKit.rule(0.0, UiKit.LINE, 0.4))
	_legend = Control.new()
	_legend.custom_minimum_size = Vector2(0, 26)
	_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legend.draw.connect(_draw_legend)
	box.add_child(_legend)
	prepare()
	_fog = ImageTexture.create_from_image(fog_image(meta))


func open() -> void:
	_was_paused = get_tree().paused
	_was_mouse = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true


func close() -> void:
	get_tree().paused = _was_paused
	Input.mouse_mode = _was_mouse
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if not visible or is_queued_for_deletion():
		return
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and (k.physical_keycode == KEY_ESCAPE or event.is_action("map")):
		close()
		get_viewport().set_input_as_handled()


## 휠: 커서 밑 자리를 붙잡고 확대·축소. 왼쪽 단추를 누른 채 끌면 옮긴다.
func _on_view_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb:
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			zoom_at(mb.position, ZOOM_STEP if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP)
			_view.accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_drag = mb.pressed
			_view.accept_event()
		return
	var mm := event as InputEventMouseMotion
	if mm and _drag:
		pan_by(mm.relative)
		_view.accept_event()


## 지도 칸 자리 → 지도판(_view) 위 점.
func to_px(c: Vector2) -> Vector2:
	return _view.size / 2.0 + (c - _center) * _zoom


## 지도판 위 점 → 칸 자리.
func to_cell(p: Vector2) -> Vector2:
	return _center + (p - _view.size / 2.0) / maxf(_zoom, 0.0001)


func zoom_at(p: Vector2, k: float) -> void:
	_ensure_view()
	var keep: Vector2 = to_cell(p)
	_zoom = clampf(_zoom * k, _fit, _fit * ZOOM_MAX)
	_center = keep - (p - _view.size / 2.0) / _zoom
	_clamp_center()
	_view.queue_redraw()


func pan_by(px: Vector2) -> void:
	_ensure_view()
	_center -= px / _zoom
	_clamp_center()
	_view.queue_redraw()


func zoom() -> float:
	return _zoom


func fit_zoom() -> float:
	return _fit


## 처음(또는 창 크기가 바뀌면): 들판 전체가 한눈에 들어오는 배율, 가운데는 들판 가운데.
func _ensure_view() -> void:
	if _zoom > 0.0 or _view == null or _view.size.x < 10.0:
		return
	var S := Vector2(FieldLayout.SIZE)
	_fit = minf((_view.size.x - 24.0) / S.x, (_view.size.y - 24.0) / S.y)
	_zoom = _fit
	_center = S / 2.0


## 들판 밖으로 너무 나가지 않게(지도판보다 작으면 가운데에 둔다).
func _clamp_center() -> void:
	var S := Vector2(FieldLayout.SIZE)
	var half: Vector2 = _view.size / 2.0 / _zoom
	for a in 2:
		if S[a] <= half[a] * 2.0:
			_center[a] = S[a] / 2.0
		else:
			_center[a] = clampf(_center[a], half[a] - 6.0, S[a] - half[a] + 6.0)


static func _path_cells(meters: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in meters:
		out.append(p / Grid.CELL)
	return out


# ---------------------------------------------------------------- 그림 만들기

## 땅 그림(들판 SIZE × BASE_PX 점): 먹빛 바탕, 북서쪽 빛의 음영, 높은 곳은 조금 밝게, 물(개울·늪)은 푸른 먹, 물가와 높이 선은 놋쇠빛.
## 높이는 1m마다 재고(FieldBuilder.height) 부드럽게(삼차) 늘려 BASE_PX로 칠한다. 물가와 높이 선은 기울기로 굵기를 맞춰 가장자리를 부드럽게 그린다
## (확대해도 계단이 덜 진다). 먹의 얼룩은 잡음. 들판에 처음 들어올 때 한 번(prepare) 만들어 세션 내내 쓴다.
static func base_image() -> Image:
	var W: int = FieldLayout.SIZE.x * BASE_PX
	var H: int = FieldLayout.SIZE.y * BASE_PX
	var sw: int = FieldLayout.SIZE.x * SAMPLE_PX
	var sh: int = FieldLayout.SIZE.y * SAMPLE_PX
	var raw := PackedFloat32Array()
	raw.resize(sw * sh)
	var ss: float = Grid.CELL / SAMPLE_PX
	for j in sh:
		for i in sw:
			raw[j * sw + i] = FieldBuilder.height((i + 0.5) * ss, (j + 0.5) * ss)
	var hi := Image.create_from_data(sw, sh, false, Image.FORMAT_RF, raw.to_byte_array())
	hi.resize(W, H, Image.INTERPOLATE_CUBIC)
	var hs: PackedFloat32Array = hi.get_data().to_float32_array()
	var step: float = Grid.CELL / BASE_PX
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var light := Vector3(-0.55, 0.7, -0.45).normalized()
	var rocky: Array[Rect2] = [FieldLayout.AREAS[&"quarry"], FieldLayout.AREAS[&"pass"]]
	var marsh: Rect2 = FieldLayout.AREAS[&"marsh"]
	var ink := FastNoiseLite.new()
	ink.seed = 380
	ink.frequency = 0.05 / BASE_PX * 2.0
	ink.fractal_octaves = 4
	for j in H:
		for i in W:
			var k: int = j * W + i
			var h: float = hs[k]
			var hx: float = (hs[j * W + mini(i + 1, W - 1)] - hs[j * W + maxi(i - 1, 0)]) / (2.0 * step)
			var hz: float = (hs[mini(j + 1, H - 1) * W + i] - hs[maxi(j - 1, 0) * W + i]) / (2.0 * step)
			var g: float = maxf(Vector2(hx, hz).length() * step, 0.0005)   # 한 점에 바뀌는 높이(m)
			var n := Vector3(-hx * RELIEF, 1.0, -hz * RELIEF).normalized()
			var shade: float = clampf(n.dot(light), 0.0, 1.0)
			var cell := Vector2((i + 0.5) / BASE_PX, (j + 0.5) / BASE_PX)
			var c: Color = INK.lerp(INK_HIGH, smoothstep(-1.0, 9.0, h) * 0.7)
			for r in rocky:
				if r.has_point(cell):
					c = c.lerp(ROCK, 0.45)
			var lit: float = 0.42 + 1.0 * shade
			var blot: float = 0.88 + 0.24 * (ink.get_noise_2d(i, j) * 0.5 + 0.5)
			c = Color(c.r * lit * blot, c.g * lit * blot, c.b * lit * blot)
			# 높이 선: 가장 가까운 높이 칸 경계까지의 거리(m)를 기울기로 나눠 1점 굵기
			var dl: float = absf(h / CONTOUR - roundf(h / CONTOUR)) * CONTOUR
			c = c.lerp(BRASS, 0.15 * (1.0 - clampf(dl / (g * 0.9), 0.0, 1.0)))
			# 물: 물 높이보다 낮은 정도로 섞고(가장자리 부드럽게), 물가에 놋쇠빛 가는 줄
			var wl: float = FieldBuilder.WATER_Y
			var wc: Color = WATER
			if marsh.has_point(cell) and h < 0.3:
				wl = 0.0
				wc = MARSH_WATER
			var under: float = (wl - h) / g   # 물가에서 몇 점 안쪽인가
			var cover: float = clampf(under + 0.5, 0.0, 1.0)
			if cover > 0.0:
				var deep: float = 0.82 + 0.3 * shade
				c = c.lerp(Color(wc.r * deep, wc.g * deep, wc.b * deep), cover)
			var shore: float = 1.0 - clampf(absf(under) / 1.2, 0.0, 1.0)
			c = c.lerp(BRASS, 0.3 * shore)
			img.set_pixel(i, j, Color(c, 1.0))
	return img


## 들판에 처음 들어올 때 땅 그림을 미리 만든다(첫 M이 멈칫하지 않게). 이미 있으면 그대로.
static func prepare() -> void:
	if _base != null:
		return
	_base = ImageTexture.create_from_image(base_image())
	_road_cells = _path_cells(FieldBuilder._spline(FieldLayout.ROAD, 8))
	var bp := PackedVector2Array()
	var x: float = 0.0
	while x <= FieldLayout.WORLD_X:
		bp.append(Vector2(x, FieldBuilder.brook_z(x)))
		x += 4.0
	_brook_cells = _path_cells(bp)


## 먹구름 그림(밝힘 격자 × FOG_PX 점): 본 칸은 비고(투명), 안 본 칸은 짙은 먹. 칸을 한 번 흐리게 한 뒤 삼차로 늘려 둥글게 잇고,
## 가장자리를 잡음으로 흔든다(찢긴 구름 같은 끝).
static func fog_image(m: Meta) -> Image:
	var S: Vector2i = FieldLayout.SEEN_SIZE
	var W: int = S.x * FOG_PX
	var H: int = S.y * FOG_PX
	# 둘레에 한 칸씩 덧대고(가장 가까운 칸을 되풀이) [1 2 1] 흐림
	var pw: int = S.x + 2
	var ph: int = S.y + 2
	var a := PackedFloat32Array()
	a.resize(pw * ph)
	for j in ph:
		for i in pw:
			a[j * pw + i] = _seen_f(m, i - 1, j - 1)
	var b := PackedFloat32Array()
	b.resize(pw * ph)
	for j in ph:
		for i in pw:
			b[j * pw + i] = (a[j * pw + maxi(i - 1, 0)] + 2.0 * a[j * pw + i] + a[j * pw + mini(i + 1, pw - 1)]) * 0.25
	for j in ph:
		for i in pw:
			a[j * pw + i] = (b[maxi(j - 1, 0) * pw + i] + 2.0 * b[j * pw + i] + b[mini(j + 1, ph - 1) * pw + i]) * 0.25
	var small := Image.create_from_data(pw, ph, false, Image.FORMAT_RF, a.to_byte_array())
	small.resize(pw * FOG_PX, ph * FOG_PX, Image.INTERPOLATE_CUBIC)
	var up: PackedFloat32Array = small.get_data().to_float32_array()
	var uw: int = pw * FOG_PX
	var nz := FastNoiseLite.new()
	nz.seed = 38
	nz.frequency = 0.055
	nz.fractal_octaves = 4
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for j in H:
		for i in W:
			var s: float = up[(j + FOG_PX) * uw + i + FOG_PX]
			var nv: float = nz.get_noise_2d(i, j)
			s = s + nv * FOG_NOISE
			var al: float = 1.0 - smoothstep(0.3, 0.6, s)
			var c: Color = FOG_C.lightened(0.09 * (nv * 0.5 + 0.5))
			img.set_pixel(i, j, Color(c, al))
	return img


## 격자 밖은 가장 가까운 칸을 본다(가장자리가 비지 않게).
static func _seen_f(m: Meta, i: int, j: int) -> float:
	var S: Vector2i = FieldLayout.SEEN_SIZE
	return 1.0 if m.seen_cell(clampi(i, 0, S.x - 1), clampi(j, 0, S.y - 1)) else 0.0


# ---------------------------------------------------------------- 그리기

func _draw_map() -> void:
	_ensure_view()
	if _zoom <= 0.0:
		return
	var v: Control = _view
	var S := Vector2(FieldLayout.SIZE)
	var fr := Rect2(to_px(Vector2.ZERO), S * _zoom)
	v.draw_rect(fr, INK)
	v.draw_texture_rect(_base, fr, false)
	_draw_forest(v)
	_draw_trees(v)
	_draw_water_line(v)
	_draw_road(v)
	_draw_bridge(v)
	_draw_works(v)
	# 먹구름(본 곳 밖)
	var fs := Vector2(FieldLayout.SEEN_SIZE * FieldLayout.SEEN_CELL)
	var src := Rect2(Vector2.ZERO, Vector2(_fog.get_size()) * S / fs)
	v.draw_texture_rect_region(_fog, fr, src)
	v.draw_rect(fr.grow(3.0), Color(BRASS, 0.22), false, 1.0)
	v.draw_rect(fr, Color(BRASS, 0.55), false, 1.5)
	_draw_labels(v)
	for mk in markers(meta):
		draw_marker(v, mk.kind, to_px(mk.at), _icon_size(), bool(mk.faded))
	draw_marker(v, &"lord", to_px(rules.lord.pos), _icon_size() * 1.45, false, rules.lord.face)


func _icon_size() -> float:
	return clampf(_zoom * 1.5, 9.0, 16.0)


## 둘레의 숲 띠(BORDER_RECTS, 남쪽 목책 줄은 뺀다): 촘촘한 나무 점.
func _draw_forest(v: Control) -> void:
	var r: float = clampf(_zoom * 0.42, 1.2, 6.0)
	for b in FieldLayout.BORDER_RECTS:
		if b.position.y >= FieldLayout.SIZE.y - 2.0:
			continue   # 마을 목책(_draw_works가 그린다)
		var area := Rect2(to_px(b.position), b.size * _zoom)
		v.draw_rect(area, Color(TREE_C, 0.75))
		var s: float = 1.3
		var y: float = b.position.y + s * 0.5
		var row: int = 0
		while y < b.end.y:
			var x: float = b.position.x + s * (0.5 if row % 2 == 0 else 1.0)
			while x < b.end.x:
				var c := Vector2(x, y)
				_tree(v, to_px(c), r * (0.8 + 0.4 * fposmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0)))
				x += s
			y += s * 0.86
			row += 1


func _draw_trees(v: Control) -> void:
	var r: float = clampf(_zoom * 0.5, 1.4, 7.0)
	for t in trees:
		_tree(v, to_px(t), r)


## 나무 한 그루: 짙은 잎 덩이에 왼쪽 위 놋쇠빛 테두리 조금.
func _tree(v: Control, p: Vector2, r: float) -> void:
	v.draw_circle(p + Vector2(r * 0.25, r * 0.3), r, Color(0, 0, 0, 0.45))
	v.draw_circle(p, r, TREE_C)
	if r >= 2.5:
		v.draw_arc(p, r * 0.92, PI * 1.0, PI * 1.6, 6, Color(BRASS, 0.28), 1.0, true)


## 개울 가운데 줄(물빛 위 가는 놋쇠빛).
func _draw_water_line(v: Control) -> void:
	var pts := PackedVector2Array()
	for c in _brook_cells:
		pts.append(to_px(c))
	v.draw_polyline(pts, Color(0.42, 0.52, 0.55, 0.35), maxf(1.0, _zoom * 0.25), true)


func _draw_road(v: Control) -> void:
	var pts := PackedVector2Array()
	for c in _road_cells:
		pts.append(to_px(c))
	var w: float = maxf(2.0, _zoom * 1.0)
	v.draw_polyline(pts, Color(0, 0, 0, 0.5), w + 2.0, true)
	v.draw_polyline(pts, ROAD_C, w, true)
	if _zoom >= 9.0:
		v.draw_polyline(pts, Color(BRASS, 0.35), 1.0, true)


func _draw_bridge(v: Control) -> void:
	var bx: float = FieldLayout.BRIDGE_X / Grid.CELL
	var bz: float = FieldBuilder.brook_z(FieldLayout.BRIDGE_X) / Grid.CELL
	var r := Rect2(to_px(Vector2(bx - 1.1, bz - 3.4)), Vector2(2.2, 6.8) * _zoom)
	v.draw_rect(r, Color(0.32, 0.29, 0.24))
	v.draw_rect(r, Color(BRASS, 0.85), false, 1.2)


## 그린 것이 곧 막힘인 것들: 벼랑(돌빛에 빗금), 성채·불탄 마을의 벽(놋쇠빛), 탑·망루·무덤 입구·잘린 돌덩이, 우물, 울타리, 마을 목책.
func _draw_works(v: Control) -> void:
	var cliffs: Array[Rect2] = []
	cliffs.append_array(FieldLayout.QUARRY_CLIFFS)
	cliffs.append_array(FieldLayout.PASS_CLIFFS)
	for c in cliffs:
		var r := Rect2(to_px(c.position), c.size * _zoom)
		v.draw_rect(r, CLIFF_C)
		_hatch(v, r, Color(BRASS, 0.16))
		v.draw_rect(r, Color(BRASS, 0.5), false, 1.0)
	for b in FieldLayout.QUARRY_BLOCKS:
		_solid(v, b, Color(0.36, 0.33, 0.29), 0.7)
	var walls: Array[Rect2] = []
	walls.append_array(FieldLayout.KEEP_WALLS)
	walls.append_array(FieldLayout.HAMLET_WALLS)
	for w in walls:
		_solid(v, w, WALL_C, 0.0, 1.6)
	_solid(v, FieldLayout.KEEP_TOWER, Color(0.3, 0.27, 0.22), 0.9)
	# 망루(무너진 둥근 돌 둘레)
	var tw: Vector2 = to_px(FieldLayout.TOWER)
	v.draw_arc(tw, 3.4 * _zoom, 0.0, TAU, 32, WALL_C, maxf(1.6, _zoom * 0.35), true)
	# 무덤 입구
	_solid(v, FieldLayout.CRYPT_BLOCK, Color(0.1, 0.09, 0.08), 0.9)
	# 우물·울타리
	var wc: Vector2 = to_px(FieldLayout.HAMLET_WELL.get_center())
	v.draw_arc(wc, FieldLayout.HAMLET_WELL.size.x * 0.5 * _zoom, 0.0, TAU, 20, WALL_C, maxf(1.2, _zoom * 0.2), true)
	for f in FieldLayout.HAMLET_FENCES:
		var a: Vector2 = f.position + (Vector2(0, f.size.y / 2.0) if f.size.x >= f.size.y else Vector2(f.size.x / 2.0, 0))
		var b: Vector2 = a + (Vector2(f.size.x, 0) if f.size.x >= f.size.y else Vector2(0, f.size.y))
		v.draw_dashed_line(to_px(a), to_px(b), Color(WALL_C, 0.75), maxf(1.0, _zoom * 0.18), maxf(3.0, _zoom * 0.6))
	# 마을 목책(남쪽 둘레, 문 자리는 빈다)
	var py: float = FieldLayout.SIZE.y - 1.5
	for seg in [Vector2(0.0, FieldLayout.GATE_GAP.x), Vector2(FieldLayout.GATE_GAP.y, FieldLayout.SIZE.x)]:
		v.draw_line(to_px(Vector2(seg.x, py)), to_px(Vector2(seg.y, py)), Color(WALL_C, 0.8), maxf(1.6, _zoom * 0.3))


## 칸 rect를 채우고 놋쇠빛 테두리. edge_a: 테두리 진하기(0이면 채우기만), min_px: 너무 얇아 안 보이지 않게 지킬 두께(px).
func _solid(v: Control, c: Rect2, col: Color, edge_a: float, min_px: float = 1.0) -> void:
	var r := Rect2(to_px(c.position), c.size * _zoom)
	if r.size.x < min_px:
		r.position.x -= (min_px - r.size.x) / 2.0
		r.size.x = min_px
	if r.size.y < min_px:
		r.position.y -= (min_px - r.size.y) / 2.0
		r.size.y = min_px
	v.draw_rect(r, col)
	if edge_a > 0.0:
		v.draw_rect(r, Color(BRASS, edge_a), false, 1.0)


## 벼랑의 빗금(오른쪽 아래로).
func _hatch(v: Control, r: Rect2, col: Color) -> void:
	var gap: float = maxf(4.0, _zoom * 0.9)
	var t: float = -r.size.y
	while t < r.size.x:
		var a := Vector2(r.position.x + maxf(t, 0.0), r.position.y + maxf(-t, 0.0))
		var len: float = minf(r.size.x - maxf(t, 0.0), r.size.y - maxf(-t, 0.0))
		if len > 0.0:
			v.draw_line(a, a + Vector2(len, len), col, 1.0)
		t += gap


func _draw_labels(v: Control) -> void:
	var font: Font = get_theme_default_font()
	var size: int = clampi(roundi(_zoom * 2.9), 15, 30)
	for l in labels(meta):
		var text: String = String(FieldLayout.AREA_NAMES.get(l[0], ""))
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var p: Vector2 = to_px(l[1]) + Vector2(-w / 2.0, size * 0.35)
		v.draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(4, size / 4), Color(0, 0, 0, 0.85))
		v.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(UiKit.TITLE, 0.92))


## 표시 하나(지도와 범례가 같이 쓴다). s: 크기(px), face: 영주가 보는 쪽(라디안, 0 = 동, PI/2 = 남).
static func draw_marker(ci: CanvasItem, kind: StringName, p: Vector2, s: float, faded: bool, face: float = 0.0) -> void:
	var a: float = 0.32 if faded else 1.0
	var shadow := Color(0, 0, 0, 0.7 * a)
	match kind:
		&"lord":
			var f := Vector2.from_angle(face)
			var side := f.orthogonal()
			var pts := PackedVector2Array([p + f * s, p - f * s * 0.6 + side * s * 0.62, p - f * s * 0.25, p - f * s * 0.6 - side * s * 0.62])
			ci.draw_circle(p, s * 1.5, Color(LORD_C, 0.08))
			ci.draw_arc(p, s * 1.15, 0.0, TAU, 28, Color(LORD_C, 0.45), 1.2, true)
			var sh := PackedVector2Array()
			for q in pts:
				sh.append(q + Vector2(1.5, 1.5))
			ci.draw_colored_polygon(sh, Color(0, 0, 0, 0.7))
			ci.draw_colored_polygon(pts, LORD_C)
			pts.append(pts[0])
			ci.draw_polyline(pts, Color(0.35, 0.25, 0.1), 1.0, true)
		&"gate":
			# 문: 두 기둥과 위의 들보
			var w: float = s * 0.75
			ci.draw_rect(Rect2(p - Vector2(w, s * 0.7) + Vector2(1, 1), Vector2(w * 2.0, s * 1.4)), shadow, false, 3.0)
			ci.draw_line(p + Vector2(-w, s * 0.7), p + Vector2(-w, -s * 0.5), Color(FieldHud.MARK_GATE, a), 2.0)
			ci.draw_line(p + Vector2(w, s * 0.7), p + Vector2(w, -s * 0.5), Color(FieldHud.MARK_GATE, a), 2.0)
			ci.draw_line(p + Vector2(-w * 1.35, -s * 0.6), p + Vector2(w * 1.35, -s * 0.6), Color(FieldHud.MARK_GATE, a), 2.4)
		&"trail":
			# 언덕: 위로 솟은 두 겹 꺾쇠
			var pts := PackedVector2Array([p + Vector2(-s, s * 0.55), p + Vector2(0, -s * 0.75), p + Vector2(s, s * 0.55)])
			ci.draw_polyline(pts, shadow, 4.0, true)
			ci.draw_polyline(pts, Color(BRASS, a), 2.0, true)
			ci.draw_polyline(PackedVector2Array([p + Vector2(-s * 0.5, s * 0.55), p + Vector2(0, -s * 0.05), p + Vector2(s * 0.5, s * 0.55)]), Color(BRASS, 0.6 * a), 1.4, true)
		&"crypt":
			# 무덤: 위가 둥근 비석 모양
			var w: float = s * 0.6
			var body := PackedVector2Array([p + Vector2(-w, s * 0.7), p + Vector2(-w, -s * 0.1)])
			for k in 9:
				var ang: float = PI + PI * k / 8.0
				body.append(p + Vector2(0, -s * 0.1) + Vector2(cos(ang), sin(ang)) * w)
			body.append(p + Vector2(w, s * 0.7))
			ci.draw_colored_polygon(body, Color(0.05, 0.045, 0.04, a))
			body.append(body[0])
			ci.draw_polyline(body, Color(BRASS, a), 1.6, true)
		&"cache":
			var r := Rect2(p - Vector2(s * 0.6, s * 0.42), Vector2(s * 1.2, s * 0.84))
			ci.draw_rect(Rect2(r.position + Vector2(1.5, 1.5), r.size), shadow)
			ci.draw_rect(r, Color(0.16, 0.12, 0.07, a))
			ci.draw_rect(r, Color(CACHE_C, a), false, 1.4)
			ci.draw_line(r.position + Vector2(0, r.size.y * 0.38), r.position + Vector2(r.size.x, r.size.y * 0.38), Color(CACHE_C, a), 1.2)
		&"chief", &"boss":
			# 우두머리: 어두운 해골(둥근 머리, 눈 구멍 둘, 턱). 잡은 것은 흐리고 비스듬한 줄
			var k: float = 1.25 if kind == &"boss" else 1.0
			var rr: float = s * 0.62 * k
			var c := p + Vector2(0, -s * 0.1 * k)
			ci.draw_circle(c + Vector2(1.5, 1.5), rr, shadow)
			ci.draw_rect(Rect2(c + Vector2(-rr * 0.55, rr * 0.55), Vector2(rr * 1.1, rr * 0.55)), Color(0.09, 0.07, 0.06, a))
			ci.draw_circle(c, rr, Color(0.09, 0.07, 0.06, a))
			ci.draw_arc(c, rr, 0.0, TAU, 20, Color(CHIEF_C if not faded else UiKit.MUTED, a), 1.6, true)
			for sx in [-1.0, 1.0]:
				ci.draw_circle(c + Vector2(sx * rr * 0.38, rr * 0.05), rr * 0.24, Color(CHIEF_C if not faded else UiKit.MUTED, a))
			ci.draw_line(c + Vector2(-rr * 0.2, rr * 0.78), c + Vector2(-rr * 0.2, rr * 1.05), Color(CHIEF_C, a), 1.0)
			ci.draw_line(c + Vector2(rr * 0.2, rr * 0.78), c + Vector2(rr * 0.2, rr * 1.05), Color(CHIEF_C, a), 1.0)
			if faded:
				ci.draw_line(c + Vector2(-rr * 1.2, rr * 1.1), c + Vector2(rr * 1.2, -rr * 1.1), Color(UiKit.MUTED, 0.7), 1.4)
		&"wanderer":
			# 떠도는 사람: 모닥불(주황 점과 빛)
			ci.draw_circle(p, s * 1.0, Color(FieldHud.MARK_WANDER, 0.16 * a))
			ci.draw_circle(p + Vector2(1.2, 1.2), s * 0.42, shadow)
			ci.draw_circle(p, s * 0.42, Color(FieldHud.MARK_WANDER, a))
			ci.draw_circle(p + Vector2(0, -s * 0.08), s * 0.18, Color(1.0, 0.9, 0.65, a))
		&"dropped":
			# 떨군 검: 붉은 마름모(나침반과 같다)와 빛
			ci.draw_circle(p, s * 1.2, Color(FieldHud.MARK_DROP, 0.18))
			var d := PackedVector2Array([p + Vector2(0, -s * 0.85), p + Vector2(s * 0.6, 0), p + Vector2(0, s * 0.85), p + Vector2(-s * 0.6, 0)])
			ci.draw_colored_polygon(d, FieldHud.MARK_DROP)
			d.append(d[0])
			ci.draw_polyline(d, Color(0.3, 0.05, 0.03), 1.0, true)


## 범례: 표시와 이름을 한 줄로, 오른쪽 끝에 다루는 법.
func _draw_legend() -> void:
	var font: Font = get_theme_default_font()
	var x: float = 14.0
	var y: float = _legend.size.y / 2.0
	for e in LEGEND:
		draw_marker(_legend, e[0], Vector2(x + 7.0, y), 7.5, false, -PI / 2.0)
		_legend.draw_string(font, Vector2(x + 20.0, y + 5.5), e[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiKit.MUTED)
		x += 20.0 + font.get_string_size(e[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 22.0
	var hint: String = "휠 확대 · 끌어서 옮기기"
	var hw: float = font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	_legend.draw_string(font, Vector2(_legend.size.x - hw - 14.0, y + 5.5), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(UiKit.MUTED, 0.8))
