class_name PathMap
extends ColorRect
## 갈림길 지도 창(13단계, docs/content.md). 새벽에 다음 구역으로 오를 길 두 개를 고른다.
## 위에 두 갈래의 카드(목표·구역 규칙·보상 아이콘과 짧은 이름), 그 밑으로 지나온 구역이 점으로 이어져 아래로 내려간다(위로 오르는 길).
## 모양은 UiKit(모서리 없는 검은 판, 놋쇠빛 줄), 아이콘은 assets/ui/map/*.svg(모양팀). 규칙은 모른다: main이 글과 아이콘 id를 넣는다.
## 1 또는 2, 아니면 카드를 눌러 고른다. 열린 동안 규칙은 멈춰 있다(Rules.path_open).

signal picked(i: int)

const ICONS := "res://assets/ui/map/%s.svg"
## 창을 연 뒤 이만큼(초)은 고르지 않는다(밤의 마지막 클릭이 카드에 들어가지 않게).
@export var guard: float = 0.8
@export var card_width: float = 330.0
@export var card_gap: float = 70.0
## 카드 밑 갈래 길의 높이, 지나온 구역 점 사이(px).
@export var fork_height: float = 64.0
@export var step: float = 30.0

var _t: float = 0.0
var _title: Label
var _sub: Label
var _cards: Array[PanelContainer] = []
var _track: Control
## 지나온 구역(아래에서 위로): {text, current}
var _trail: Array = []
var _hover: int = -1
## 길과 구역 점의 그림(그리기 전에 읽어 둔다).
var _tex: Dictionary = {}


static func make(parent: Node) -> PathMap:
	var m := PathMap.new()
	m.color = Color(0.0, 0.0, 0.0, 0.72)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(m)
	m._build()
	return m


func _build() -> void:
	for id in ["path", "path_next", "zone_visited", "zone_current", "zone_next"]:
		var p: String = ICONS % id
		if ResourceLoader.exists(p):
			_tex[id] = load(p)
	var box := UiKit.center_panel(self)
	box.add_theme_constant_override("separation", 8)
	_title = UiKit.label("갈림길", 26, UiKit.TITLE)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	box.add_child(UiKit.rule())
	_sub = UiKit.label("", 14, UiKit.MUTED)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_sub)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(card_gap))
	box.add_child(row)
	for i in 2:
		var c := PanelContainer.new()
		c.custom_minimum_size = Vector2(card_width, 0)
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var k: int = i
		c.gui_input.connect(func(ev: InputEvent) -> void:
			var mb := ev as InputEventMouseButton
			if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				pick(k))
		c.mouse_entered.connect(func() -> void: _set_hover(k))
		c.mouse_exited.connect(func() -> void: _set_hover(-1 if _hover == k else _hover))
		row.add_child(c)
		_cards.append(c)
	_track = Control.new()
	_track.custom_minimum_size = Vector2(card_width * 2.0 + card_gap, fork_height)
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.draw.connect(_draw_track)
	box.add_child(_track)
	visible = false


func _process(delta: float) -> void:
	_t += delta


func is_open() -> bool:
	return visible


## title: 제목. head: 제목 밑의 한 줄. trail: 지나온 구역의 글(아래에서 위로, 마지막이 지금 선 곳).
## cards: 두 길 {label(카드 머리), goal_icon, goal, goal_text, rule_icon, rule, rule_text, reward_icon, reward}.
func open(title: String, head: String, trail: Array, cards: Array) -> void:
	_title.text = title
	_sub.text = head
	_trail = trail
	for i in 2:
		_fill(_cards[i], i, cards[i] if i < cards.size() else {})
	_track.custom_minimum_size.y = fork_height + step * maxf(0.0, trail.size() - 1) + 14.0
	_track.queue_redraw()
	_hover = -1
	_set_hover(-1)
	_t = 0.0
	visible = true


## 1, 2(0, 1) 또는 카드 클릭.
func pick(i: int) -> void:
	if not visible or _t < guard or i < 0 or i > 1:
		return
	visible = false
	picked.emit(i)


func _set_hover(i: int) -> void:
	_hover = i
	for k in _cards.size():
		var on: bool = k == i
		var s := UiKit.style(Color(UiKit.LINE, 0.9 if on else 0.4), 2 if on else 1, Color(0.06, 0.05, 0.04, 0.95) if on else UiKit.BG)
		s.content_margin_top = 12
		s.content_margin_bottom = 12
		_cards[k].add_theme_stylebox_override("panel", s)


func _fill(card: PanelContainer, i: int, c: Dictionary) -> void:
	for ch in card.get_children():
		ch.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var key := PanelContainer.new()
	var ks := UiKit.style(Color(UiKit.LINE, 0.8), 1, Color(0.06, 0.05, 0.04, 0.9))
	ks.content_margin_left = 8
	ks.content_margin_right = 8
	ks.content_margin_top = 0
	ks.content_margin_bottom = 1
	key.add_theme_stylebox_override("panel", ks)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.add_child(_text(str(i + 1), 15, UiKit.TITLE))
	top.add_child(key)
	top.add_child(_text(str(c.get("label", "")), 17, UiKit.TITLE))
	v.add_child(UiKit.rule(0.0, UiKit.LINE, 0.45))
	v.add_child(_line(str(c.get("goal_icon", "")), str(c.get("goal", "")), str(c.get("goal_text", "")), 19))
	v.add_child(_line(str(c.get("rule_icon", "")), str(c.get("rule", "")), str(c.get("rule_text", "")), 16))
	v.add_child(UiKit.rule(0.0, UiKit.LINE, 0.3))
	v.add_child(_line(str(c.get("reward_icon", "")), str(c.get("reward", "")), "보상", 16, true))


## 아이콘 하나와 글 한두 줄. icon이 없으면 자리만 비운다.
func _line(icon: String, main: String, small: String, size: int, small_above: bool = false) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(40, 40)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != "" and ResourceLoader.exists(ICONS % icon):
		tr.texture = load(ICONS % icon)
	else:
		tr.modulate.a = 0.0
	h.add_child(tr)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var big := _text(main, size, UiKit.TEXT if icon != "" else UiKit.MUTED)
	if small != "" and small_above:
		col.add_child(_text(small, 12, UiKit.MUTED))
	col.add_child(big)
	if small != "" and not small_above:
		col.add_child(_text(small, 12, UiKit.MUTED))
	h.add_child(col)
	return h


func _text(t: String, size: int, c: Color) -> Label:
	var l := UiKit.label(t, size, c)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## 카드 밑에서 두 갈래 점선이 지금 선 곳으로 모이고, 지나온 구역이 실선으로 아래로 이어진다.
func _draw_track() -> void:
	var w: float = _track.size.x
	var cx: float = w / 2.0
	var a := Vector2(w / 2.0 - (card_width + card_gap) / 2.0, 4.0)
	var b := Vector2(w / 2.0 + (card_width + card_gap) / 2.0, 4.0)
	var here := Vector2(cx, fork_height)
	var dash: Texture2D = _icon("path_next")
	var solid: Texture2D = _icon("path")
	for p in [a, b]:
		_seg(dash, here, p, true)
	var nxt: Texture2D = _icon("zone_next")
	for p in [a, b]:
		if nxt:
			_track.draw_texture_rect(nxt, Rect2(p - Vector2(13, 13), Vector2(26, 26)), false)
	var font := _track.get_theme_default_font()
	var n: int = _trail.size()
	# 지금 선 곳이 맨 위, 그 밑으로 지나온 구역(아래가 1구역)
	for i in n:
		var p := Vector2(cx, fork_height + step * i)
		if i < n - 1:
			_seg(solid, p, p + Vector2(0, step), false)
	for i in n:
		var t: Dictionary = _trail[n - 1 - i]
		var p := Vector2(cx, fork_height + step * i)
		var cur: bool = bool(t.get("current", false))
		var tex: Texture2D = _icon("zone_current" if cur else "zone_visited")
		var s: float = 30.0 if cur else 28.0
		if tex:
			_track.draw_texture_rect(tex, Rect2(p - Vector2(s, s) / 2.0, Vector2(s, s)), false)
		if font:
			_track.draw_string(font, p + Vector2(22, 5), str(t.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiKit.TITLE if cur else UiKit.MUTED)


## 길 한 토막: 세로 그림(16 × 64)을 from → to로 돌려 늘인다. tile이면 점선이 늘어나지 않게 되풀이한다.
func _seg(tex: Texture2D, from: Vector2, to: Vector2, tile: bool) -> void:
	if tex == null:
		_track.draw_line(from, to, Color(UiKit.LINE, 0.6), 2.0)
		return
	var d := to - from
	_track.draw_set_transform(from, d.angle() - PI / 2.0, Vector2.ONE)
	_track.draw_texture_rect(tex, Rect2(-8, 0, 16, d.length()), tile)
	_track.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _icon(id: String) -> Texture2D:
	return _tex.get(id) as Texture2D
