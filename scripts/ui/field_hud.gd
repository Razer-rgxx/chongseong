class_name FieldHud
extends Control
## 들판 화면(2026-11-20 사용자: "오픈월드 UI 살짝 추가"). 들판에서만 LobbyHud 위에 얹는다. 규칙은 읽기만 한다.
## - 위 가운데: 나침반 띠(엘든 링식). 보는 방향 ±90°에 동·서·남·북 눈금, 표시: 떨군 검(붉은 마름모), 떠도는 사람(주황), 마을 북문, 언덕길, 무덤 입구.
## - 왼쪽 위: 지금 있는 곳 이름(작게, 놋쇠빛)과 그 아래 낮밤 반원(해·달이 반원을 따라 지난다).
## - 왼쪽 아래(체력 막대 위): 쥔 검 이름과 등급 빛(맨손이면 "맨손").
## 세계(3D)에 글자를 띄우지 않는다. 나침반 글자는 화면 글자다.

const COMPASS_W: float = 560.0
const COMPASS_H: float = 34.0
const COMPASS_SPAN: float = PI   ## 띠 너비가 보여 주는 각(±90°)
const DIRS: Array = [[0.0, "북"], [PI * 0.5, "동"], [PI, "남"], [PI * 1.5, "서"]]
const MARK_GATE := Color(0.85, 0.78, 0.6)
const MARK_DROP := Color(1.0, 0.32, 0.22)
const MARK_PLACE := Color(0.62, 0.6, 0.56)
const MARK_WANDER := Color(1.0, 0.62, 0.3)   ## 떠도는 사람(모닥불 빛)

var data: GameData
var meta: Meta
var rules: Rules
var camera: Camera3D   ## camera_rig.gd(이름 없는 스크립트): forward_cells()를 부른다

var _area: Label
var _dial: Control
var _held: Label
var _held_dot: ColorRect
var _compass: Control
var _area_id: StringName = &""
var _bg: GradientTexture2D   ## 나침반 바탕(한 번 만들어 둔다: 그릴 때마다 만들면 첫 장이 비어 하얗게 보인다)


static func make(parent: Node, d: GameData, m: Meta, r: Rules, cam: Camera3D) -> FieldHud:
	var h := FieldHud.new()
	h.data = d
	h.meta = m
	h.rules = r
	h.camera = cam
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(h)
	parent.move_child(h, 0)   # 창·띠보다 뒤에
	h._build()
	return h


## 쓰러졌을 때 깨어나며 띄울 말. gone: 이번에 잃은 검(-1이면 없음), held: 떨군 검(0이면 맨손). m이 있으면 잃은 검이 벤 적 수를 덧붙인다.
static func drop_note(d: GameData, gone: int, held: int, m: Meta = null) -> String:
	var parts: Array[String] = []
	if held > 0:
		var s: SwordData = d.sword_by_id(held)
		parts.append("%s을(를) 쓰러진 자리에 떨궜다" % (s.display_name if s else "검"))
	if gone > 0:
		var g: SwordData = d.sword_by_id(gone)
		var k: int = m.kills_of(gone) if m else 0
		parts.append("먼저 떨군 %s은(는) 영영 잃었다%s" % [g.display_name if g else "검", (" (함께 벤 적 %d)" % k) if k > 0 else ""])
	if parts.is_empty():
		return ""
	return ". ".join(parts) + "."


func _build() -> void:
	_bg = UiKit.fade_texture(Color(0.01, 0.008, 0.006), 0.72, 0.25)
	# 왼쪽 위 바탕: 왼쪽 끝은 화면 밖으로 빼서 오른쪽으로만 사라지는 검은 띠(밝은 땅 위에서도 글자가 읽히게)
	var back := TextureRect.new()
	back.texture = _bg
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_SCALE
	back.position = Vector2(-160, 12)
	back.size = Vector2(420, 96)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	# 왼쪽 위: 곳 이름 + 낮밤
	var tl := VBoxContainer.new()
	tl.position = Vector2(28, 22)
	tl.add_theme_constant_override("separation", 6)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tl)
	_area = UiKit.label("", 18, UiKit.TITLE)
	_area.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_area.add_theme_constant_override("outline_size", 5)
	tl.add_child(_area)
	var rule := UiKit.rule(150.0, UiKit.LINE, 0.45)
	tl.add_child(rule)
	_dial = Control.new()
	_dial.custom_minimum_size = Vector2(72, 40)
	_dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dial.draw.connect(_draw_dial)
	tl.add_child(_dial)
	# 왼쪽 아래: 쥔 검(체력 막대 바로 위)
	var bl := HBoxContainer.new()
	bl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bl.offset_left = 28
	bl.offset_top = -74
	bl.offset_bottom = -50
	bl.offset_right = 520
	bl.add_theme_constant_override("separation", 8)
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bl)
	_held_dot = ColorRect.new()
	_held_dot.custom_minimum_size = Vector2(8, 8)
	_held_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_held_dot.rotation = PI / 4.0
	_held_dot.pivot_offset = Vector2(4, 4)
	bl.add_child(_held_dot)
	_held = UiKit.label("", 16, UiKit.TEXT)
	_held.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_held.add_theme_constant_override("outline_size", 5)
	bl.add_child(_held)
	# 위 가운데: 나침반
	_compass = Control.new()
	_compass.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_compass.offset_left = -COMPASS_W / 2.0
	_compass.offset_right = COMPASS_W / 2.0
	_compass.offset_top = 18
	_compass.offset_bottom = 18 + COMPASS_H
	_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compass.draw.connect(_draw_compass)
	add_child(_compass)


func _process(_delta: float) -> void:
	if rules == null:
		return
	var a: StringName = FieldLayout.area_at(rules.lord.pos)
	if a != _area_id:
		_area_id = a
		_area.text = String(FieldLayout.AREA_NAMES.get(a, "들판"))
	var s: Sword = rules.slots[0] if rules.slots.size() > 0 else null
	if s == null:
		_held.text = "맨손"
		_held_dot.color = Color(0.6, 0.58, 0.55)
	else:
		_held.text = "%s · %s" % [data.grades.names[s.grade], s.data.display_name]
		_held_dot.color = data.grades.colors[s.grade]
	_dial.queue_redraw()
	_compass.queue_redraw()


## 낮밤 반원: 낮에는 해(놋쇠빛)가 왼쪽에서 오른쪽으로, 밤에는 달(희푸른빛)이 같은 길을 지난다. 바닥 줄은 땅.
func _draw_dial() -> void:
	var w: float = _dial.size.x
	var h: float = _dial.size.y
	var c := Vector2(w / 2.0, h - 4.0)
	var r: float = minf(w / 2.0 - 4.0, h - 8.0)
	_dial.draw_arc(c, r, PI, TAU, 32, Color(0, 0, 0, 0.5), 3.0, true)   # 밝은 땅 위에서도 보이게 그림자 먼저
	_dial.draw_arc(c, r, PI, TAU, 32, Color(UiKit.LINE, 0.7), 1.2, true)
	_dial.draw_line(Vector2(0, c.y), Vector2(w, c.y), Color(0, 0, 0, 0.5), 3.0)
	_dial.draw_line(Vector2(0, c.y), Vector2(w, c.y), Color(UiKit.LINE, 0.8), 1.2)
	var cycle: float = FieldLayout.FIELD_DAY + FieldLayout.FIELD_NIGHT
	var t: float = fposmod(rules.field_clock, cycle)
	var night: bool = t >= FieldLayout.FIELD_DAY
	var f: float = (t - FieldLayout.FIELD_DAY) / FieldLayout.FIELD_NIGHT if night else t / FieldLayout.FIELD_DAY
	var ang: float = PI + f * PI
	var p := c + Vector2(cos(ang), sin(ang)) * r
	if night:
		_dial.draw_circle(p, 5.0, Color(0.78, 0.84, 0.95))
		_dial.draw_circle(p + Vector2(2.2, -1.5), 4.2, Color(0.03, 0.03, 0.05))   # 초승달
	else:
		_dial.draw_circle(p, 6.0, Color(1.0, 0.78, 0.4, 0.25))
		_dial.draw_circle(p, 4.0, Color(1.0, 0.8, 0.45))


## 나침반 띠: 가운데가 진한 검은 띠 위에 눈금·방위 글자·표시. 가운데 위 작은 삼각형이 보는 방향.
func _draw_compass() -> void:
	var w: float = _compass.size.x
	var h: float = _compass.size.y
	var fwd: Vector2 = camera.call("forward_cells") if camera and camera.has_method("forward_cells") else Vector2(0, -1)
	var heading: float = atan2(fwd.x, -fwd.y)   # 0 = 북(칸 y가 작아지는 쪽), 시계 방향
	_compass.draw_texture_rect(_bg, Rect2(0, 0, w, h), false)
	_compass.draw_line(Vector2(0, h - 1), Vector2(w, h - 1), Color(UiKit.LINE, 0.35), 1.0)
	var font: Font = _compass.get_theme_default_font()
	# 눈금: 15°마다, 방위 글자는 90°마다
	for i in 24:
		var a: float = i * PI / 12.0
		var x: float = _x_of(a, heading, w)
		if x < 0.0:
			continue
		var fade: float = 1.0 - absf(x - w / 2.0) / (w / 2.0)
		if i % 6 == 0:
			var txt: String = DIRS[i / 6][1]
			var col := Color(UiKit.TITLE if i == 0 else UiKit.TEXT, 0.25 + 0.75 * fade)
			_compass.draw_string(font, Vector2(x - 8.0, h - 10.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
		else:
			_compass.draw_line(Vector2(x, h - 9.0), Vector2(x, h - 3.0), Color(UiKit.LINE, 0.15 + 0.5 * fade), 1.0)
	# 표시
	var me: Vector2 = rules.lord.pos
	_mark(FieldLayout.GATE, me, heading, w, h, MARK_GATE, 4.0)
	_mark(FieldLayout.TRAILHEAD, me, heading, w, h, MARK_PLACE, 3.0)
	_mark(FieldLayout.CRYPT_DOOR, me, heading, w, h, MARK_PLACE, 3.0)
	if meta.wanderer != "" and meta.wanderer_at >= 0 and meta.wanderer_at < FieldLayout.WANDERER_SPOTS.size():
		_mark(FieldLayout.WANDERER_SPOTS[meta.wanderer_at].at, me, heading, w, h, MARK_WANDER, 4.0)
	if not meta.dropped.is_empty():
		_mark(meta.dropped_at(), me, heading, w, h, MARK_DROP, 6.0)
	# 보는 방향
	_compass.draw_colored_polygon(PackedVector2Array([Vector2(w / 2.0 - 5, 0), Vector2(w / 2.0 + 5, 0), Vector2(w / 2.0, 6)]), Color(UiKit.TITLE, 0.9))


## 방위각 a(라디안)가 띠의 어디(x)에 오는가. 띠 밖이면 -1.
func _x_of(a: float, heading: float, w: float) -> float:
	var d: float = wrapf(a - heading, -PI, PI)
	if absf(d) > COMPASS_SPAN / 2.0:
		return -1.0
	return w / 2.0 + d / (COMPASS_SPAN / 2.0) * (w / 2.0)


## 들판 칸 target 쪽 표시(마름모). 띠 밖이면 가장자리에 붙여 반쯤 흐리게.
func _mark(target: Vector2, me: Vector2, heading: float, w: float, h: float, col: Color, size: float) -> void:
	var dv: Vector2 = target - me
	if dv.length() < 1.0:
		return
	var a: float = atan2(dv.x, -dv.y)
	var d: float = wrapf(a - heading, -PI, PI)
	var edge: bool = absf(d) > COMPASS_SPAN / 2.0
	var x: float = w / 2.0 + clampf(d / (COMPASS_SPAN / 2.0), -1.0, 1.0) * (w / 2.0 - size - 2.0)
	var y: float = h * 0.38
	var c := Color(col, 0.45 if edge else 1.0)
	_compass.draw_colored_polygon(PackedVector2Array([Vector2(x, y - size), Vector2(x + size * 0.7, y), Vector2(x, y + size), Vector2(x - size * 0.7, y)]), c)
