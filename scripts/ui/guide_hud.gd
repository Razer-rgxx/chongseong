class_name GuideHud
extends CanvasLayer
## 길라잡이 화면(2026-11-26, docs/guide.md): 오른쪽 추적 줄, 위쪽 방향 띠, G 창, 끝났을 때의 띠·번쩍임.
## 규칙은 건드리지 않는다. Meta(Guide.sync)를 0.25초마다 보고, 장면의 Rules 신호는 Meta.guide_note로 세어 둔다.
## G = 길라잡이 창, Shift+G = 추적 줄 접기/펴기. 세계(3D)에 글자를 띄우지 않는다.

const TRACK_W: float = 262.0
const COMPASS_W: float = 360.0
const COMPASS_H: float = 30.0
## 균열 경고의 붉은색(추적 줄 한 줄과 방향 띠의 마름모).
const RED: Color = Color(0.92, 0.28, 0.22)

var meta: Meta
var rules: Rules
var scene_key: String = ""
var hud: Node = null
## 자리 이름 → 칸 좌표(없으면 Vector2.INF). 장면이 넣는다(lobby.guide_spot, field.guide_spot).
var resolver: Callable = Callable()
## true를 돌려주면 다른 창이 열려 있어 G를 먹지 않는다.
var busy: Callable = Callable()

var _track: PanelContainer
var _t_head: Label
var _t_title: Label
var _t_goal: Label
var _t_prog: Label
var _t_gem: Control
var _t_reward: Label
var _t_alert: Label   ## 균열이 열려 있을 때 추적 줄 맨 위의 붉은 줄(docs/rift_raid.md)
var _sig: String = ""
var _hint_red: bool = false
var _flash: ColorRect
var _band: Band
var _compass: Control
var _compass_text: String = ""
var _win: Control = null
var _win_box: VBoxContainer
var _sfx: AudioStreamPlayer
var _poll: float = 0.0
var _hint_cell: Vector2 = Vector2.INF
var _was_paused: bool = false
var _was_mouse: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


## 장면 끝(_ready 마지막)에서 한 줄로 붙인다. scene_key: lobby·field·hill·crypt·future·past.
static func attach(scene: Node, m: Meta, r: Rules, key: String, hud_node: Node = null, spot: Callable = Callable(), busy_fn: Callable = Callable()) -> GuideHud:
	var g := GuideHud.new()
	g.meta = m
	g.rules = r
	g.scene_key = key
	g.hud = hud_node
	g.resolver = spot
	g.busy = busy_fn
	scene.add_child(g)
	return g


func _ready() -> void:
	layer = 7
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_track()
	_build_compass()
	_band = Band.make(self, -170.0, 760.0, 46.0, 18)
	_sfx = AudioStreamPlayer.new()
	_sfx.stream = Sfx._make(98.0, 58.0, 0.34, 0.42, 0.1, 500.0)   # 낮고 부드러운 소리(종소리·올라가는 소리는 쓰지 않는다)
	_sfx.volume_db = -9.0
	add_child(_sfx)
	_wire_events()
	if scene_key == "hill":
		meta.guide_note("run_start")
	elif scene_key == "field":
		meta.guide_note("field_enter")
	elif scene_key == "future":
		meta.guide_note("future_enter")
	_check(true)
	_refresh()


func _exit_tree() -> void:
	if meta != null:
		Guide.sync(meta)
		meta.save()


## 장면의 Rules 신호를 세어 둔다(길라잡이 단계의 조건은 Meta에서 읽는다).
func _wire_events() -> void:
	if rules == null:
		return
	if scene_key == "hill":
		rules.sword_pulled.connect(func(_s: Sword) -> void: meta.guide_note("pull"))
		rules.pull_good.connect(func(_h: Hilt, _k: int) -> void: meta.guide_note("pull_good"))
		rules.path_offered.connect(func(_c: Array) -> void: meta.guide_note("night"))
		rules.run_ended.connect(func(won: bool) -> void:
			if won:
				meta.guide_note("night"))
		rules.path_chosen.connect(func(_i: int, _c: Dictionary) -> void: meta.guide_note("path"))
		rules.event_used.connect(func(_e: DayEvent, _r: Dictionary) -> void: meta.guide_note("event"))
	if scene_key == "field":
		rules.pack_cleared.connect(func(id: StringName) -> void:
			if not String(id).begins_with("rift_"):
				meta.guide_note("pack"))
	if scene_key in ["field", "future", "past", "crypt"]:
		rules.horse_called.connect(func() -> void: meta.guide_note("horse"))


# ---------------------------------------------------------------- 추적 줄

func _build_track() -> void:
	_track = PanelContainer.new()
	var st := UiKit.style(Color(UiKit.LINE, 0.45), 1, Color(0.025, 0.02, 0.016, 0.82))
	st.content_margin_left = 20
	st.content_margin_right = 18
	st.content_margin_top = 15
	st.content_margin_bottom = 15
	_track.add_theme_stylebox_override("panel", st)
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.anchor_left = 1.0
	_track.anchor_right = 1.0
	_track.anchor_top = 0.5
	_track.anchor_bottom = 0.5
	_track.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_track.offset_left = -TRACK_W - 22.0
	_track.offset_right = -22.0
	_track.offset_top = 64.0
	add_child(_track)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.add_child(box)
	_t_alert = UiKit.label("", 14, RED)
	_t_alert.visible = false
	box.add_child(_t_alert)
	_t_head = UiKit.label("", 13, UiKit.MUTED)
	box.add_child(_t_head)
	_t_title = UiKit.label("", 18, UiKit.TITLE)
	_t_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_t_title.custom_minimum_size = Vector2(TRACK_W - 38.0, 0)
	box.add_child(_t_title)
	_t_goal = UiKit.label("", 14)
	_t_goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_t_goal.custom_minimum_size = Vector2(TRACK_W - 38.0, 0)
	box.add_child(_t_goal)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	_t_prog = UiKit.label("", 14, UiKit.TITLE)
	_t_prog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_t_prog)
	_t_gem = Control.new()
	_t_gem.custom_minimum_size = Vector2(14, 14)
	_t_gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_t_gem.draw.connect(func() -> void: _draw_gem(_t_gem, Vector2(7, 8), 6.0, true, UiKit.LINE))
	row.add_child(_t_gem)
	_t_reward = UiKit.label("", 13, UiKit.LINE)
	row.add_child(_t_reward)
	_track.add_child(PanelFrame.new())
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 0.82, 0.45, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_track.add_child(_flash)


static func _draw_gem(c: Control, at: Vector2, r: float, filled: bool, col: Color) -> void:
	var pts := PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)])
	if filled:
		c.draw_colored_polygon(pts, col)
	else:
		pts.append(pts[0])
		c.draw_polyline(pts, col, 1.3)


func _refresh() -> void:
	var cur: int = Guide.current(meta)
	var total: int = Guide.shown_count(meta)
	var alert: bool = meta.rr_open or not meta.rr_ruined.is_empty()
	_t_alert.visible = alert
	if meta.rr_open:
		_t_alert.text = "시대의 균열  ·  터지기까지 %d판" % meta.rr_left
	elif alert:
		_t_alert.text = "무너진 건물 %d채  ·  고치기 전에는 못 쓴다" % meta.rr_ruined.size()
	_track.visible = (cur >= 0 or alert) and _win == null
	_hint_red = false
	if meta.rr_open:   # 방향 띠도 균열을 붉게 가리킨다(들판에서는 균열 자리, 마을에서는 북문)
		var rc: Vector2 = _resolve("raid")
		if rc != Vector2.INF:
			_hint_cell = rc
			_hint_red = true
	if cur < 0:
		if not _hint_red:
			_hint_cell = Vector2.INF
		return
	_t_head.text = "길라잡이  %d / %d" % [Guide.done_count(meta), total]
	_t_title.text = Guide.title_of(cur)
	var fold: bool = meta.guide_fold
	_t_goal.visible = not fold
	_t_prog.get_parent().visible = not fold
	if not fold:
		_t_goal.text = Guide.goal_of(cur)
		var need: int = int(Guide.STEPS[cur].need)
		_t_prog.text = "%d / %d" % [Guide.count(cur, meta), need]
		_t_reward.text = Guide.reward_text(cur)
		_t_gem.queue_redraw()
	_track.reset_size()
	if not _hint_red:
		_hint_cell = _resolve(Guide.hint_for(cur, scene_key, meta))


func _resolve(spot: String) -> Vector2:
	if spot == "":
		return Vector2.INF
	if scene_key == "hill" and rules != null:
		match spot:
			"hilt":
				var best: Vector2 = Vector2.INF
				var bd: float = INF
				for h in rules.hilts:
					if h.gone:
						continue
					var d: float = h.pos.distance_to(rules.lord.pos)
					if d < bd:
						bd = d
						best = h.pos
				return best
			"event":
				return rules.event.pos if rules.event != null else Vector2.INF
	if resolver.is_valid():
		var v: Variant = resolver.call(spot)
		if v is Vector2:
			return v
	return Vector2.INF


## 0.25초마다(또는 force) 끝난 단계를 걷어 알린다.
func _check(force: bool = false) -> void:
	var done: Array[int] = Guide.sync(meta)
	for i in done:
		_announce(i)
	if not done.is_empty():
		meta.save()
		if hud != null and hud.has_method("refresh_top"):
			hud.call("refresh_top")
	var sig: String = "%s|%d|%d|%d|%d" % [meta.rr_open, meta.rr_left, meta.rr_ruined.size(), meta.rr_spot, Guide.current(meta)]
	if force or not done.is_empty() or sig != _sig:
		_sig = sig
		_refresh()


func _announce(i: int) -> void:
	var rt: String = Guide.reward_text(i)
	_band.show_for("길라잡이: %s 완료%s" % [Guide.title_of(i), ("  ·  " + rt) if rt != "" else ""], 3.2)
	_sfx.play()
	var tw := create_tween()
	_flash.color = Color(1.0, 0.82, 0.45, 0.55)
	tw.tween_property(_flash, "color:a", 0.0, 0.9)


# ---------------------------------------------------------------- 방향 띠

func _build_compass() -> void:
	_compass = Control.new()
	_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compass.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_compass.offset_left = -COMPASS_W / 2.0
	_compass.offset_right = COMPASS_W / 2.0
	_compass.offset_top = 58.0
	_compass.offset_bottom = 58.0 + COMPASS_H
	_compass.draw.connect(_draw_compass)
	add_child(_compass)


## 방향 띠가 가리킬 칸과 눈 앞 방향의 어긋남(라디안, 오른쪽이 +). 가리킬 곳이 없으면 INF.
func bearing() -> float:
	if _hint_cell == Vector2.INF or rules == null:
		return INF
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return INF
	var f: Vector3 = -cam.global_transform.basis.z
	var heading: float = atan2(f.x, -f.z)
	var d: Vector2 = _hint_cell - rules.lord.pos
	if d.length() < 0.01:
		return 0.0
	return wrapf(atan2(d.x, -d.y) - heading, -PI, PI)


func _draw_compass() -> void:
	var b: float = bearing()
	if b == INF or _win != null:
		return
	var w: float = _compass.size.x
	var cx: float = w / 2.0
	_compass.draw_rect(Rect2(0, 0, w, COMPASS_H), Color(0.02, 0.016, 0.012, 0.6))
	_compass.draw_line(Vector2(0, COMPASS_H - 1), Vector2(w, COMPASS_H - 1), Color(UiKit.LINE, 0.45), 1.0)
	_compass.draw_line(Vector2(cx, 2), Vector2(cx, 9), Color(UiKit.LINE, 0.6), 1.0)   # 눈 앞 눈금
	var half: float = PI / 2.0
	var x: float = cx + clampf(b / half, -1.0, 1.0) * (cx - 14.0)
	var y: float = 15.0
	var col := Color(RED, 0.95) if _hint_red else Color(UiKit.TITLE, 0.95)
	if absf(b) <= half:
		_draw_gem(_compass, Vector2(x, y), 6.0, true, col)
	else:   # 뒤쪽이면 가장자리에서 바깥(그쪽으로 돌라는 뜻)을 가리키는 쐐기
		var s: float = signf(b)
		_compass.draw_colored_polygon(PackedVector2Array([Vector2(x + s * 7.0, y), Vector2(x - s * 4.0, y - 8.0), Vector2(x - s * 4.0, y + 8.0)]), col)
	var font: Font = _compass.get_theme_default_font()
	var d: float = _hint_cell.distance_to(rules.lord.pos) * Grid.CELL
	var txt: String = "%dm" % roundi(d)
	var tx: float = x + (12.0 if x < cx + cx * 0.5 else -48.0)
	_compass.draw_string(font, Vector2(tx, y + 5.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(UiKit.TEXT, 0.85))


# ---------------------------------------------------------------- G 창

func _input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	var k: InputEventKey = ev
	if _win != null and k.physical_keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()
		return
	if k.physical_keycode != KEY_G or k.ctrl_pressed or k.alt_pressed:
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if _win != null:
		_close()
	elif k.shift_pressed:
		meta.guide_fold = not meta.guide_fold
		_refresh()
	elif not (busy.is_valid() and busy.call()) and not get_tree().paused:
		_open()
	get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _win != null


func _open() -> void:
	if _win != null:
		return
	_was_paused = get_tree().paused
	_was_mouse = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_win = Control.new()
	_win.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_win.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_win.add_child(dim)
	add_child(_win)
	_win_box = UiKit.center_panel(_win)
	_win_box.custom_minimum_size = Vector2(640, 0)
	build_window(_win_box)
	_refresh()


func _close() -> void:
	if _win == null:
		return
	_win.queue_free()
	_win = null
	get_tree().paused = _was_paused
	Input.mouse_mode = _was_mouse
	meta.save()
	_refresh()


## 창 안쪽을 채운다(장: 마을 / 언덕 / 들판 / 이야기. 끝난 것은 표시, 지금 것은 놋쇠 테, 앞날은 흐리게).
func build_window(box: VBoxContainer) -> void:
	UiKit.header(box, "길라잡이", _close)
	var cur: int = Guide.current(meta)
	box.add_child(UiKit.label("%d / %d 마침  ·  G 창 닫기  ·  Shift+G 추적 줄 접기" % [Guide.done_count(meta), Guide.shown_count(meta)], 14, UiKit.MUTED))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for ch in Guide.CHAPTERS.size():
		var idx: Array[int] = []
		for i in Guide.size():
			if int(Guide.STEPS[i].ch) == ch and Guide.shown(i, meta):
				idx.append(i)
		if idx.is_empty():
			continue
		var n_done: int = 0
		for i in idx:
			n_done += 1 if Guide.is_done(i, meta) else 0
		var head := UiKit.label("%s  %d / %d" % [Guide.CHAPTERS[ch], n_done, idx.size()], 19, UiKit.TITLE)
		list.add_child(head)
		list.add_child(UiKit.rule())
		for i in idx:
			list.add_child(_row(i, cur))


func _row(i: int, cur: int) -> Control:
	var done: bool = Guide.is_done(i, meta)
	var now: bool = i == cur
	var p := PanelContainer.new()
	var st := UiKit.style(Color(UiKit.LINE, 0.8) if now else Color(0, 0, 0, 0), 1 if now else 0, Color(0.1, 0.075, 0.04, 0.55) if now else Color(0, 0, 0, 0))
	st.content_margin_top = 6
	st.content_margin_bottom = 7
	p.add_theme_stylebox_override("panel", st)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	p.add_child(row)
	var mark := Control.new()
	mark.custom_minimum_size = Vector2(18, 18)
	mark.draw.connect(func() -> void:
		var at := Vector2(9, 12)
		if done:
			_draw_gem(mark, at, 7.0, true, Color(UiKit.LINE, 0.9))
		elif now:
			_draw_gem(mark, at, 7.0, false, UiKit.TITLE)
			_draw_gem(mark, at, 2.5, true, UiKit.TITLE)
		else:
			_draw_gem(mark, at, 5.0, false, Color(UiKit.MUTED, 0.5)))
	row.add_child(mark)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var tcol: Color = UiKit.TITLE if now else (UiKit.TEXT if done else Color(UiKit.MUTED, 0.75))
	var title: String = "%d. %s" % [i + 1, Guide.title_of(i)]
	if now:
		title += "   (%d / %d)" % [Guide.count(i, meta), int(Guide.STEPS[i].need)]
	col.add_child(UiKit.label(title, 17, tcol))
	var g := UiKit.label(Guide.goal_of(i), 13, UiKit.TEXT if now else UiKit.MUTED)
	g.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	g.custom_minimum_size = Vector2(430, 0)
	col.add_child(g)
	var rw := UiKit.label(("완료" if done else Guide.reward_text(i)), 13, UiKit.MUTED if done else UiKit.LINE)
	rw.custom_minimum_size = Vector2(100, 0)
	rw.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(rw)
	return p


func _process(delta: float) -> void:
	_poll += delta
	if _poll >= 0.25:
		_poll = 0.0
		_check()
		_hint_cell = _resolve(Guide.hint_for(Guide.current(meta), scene_key, meta))
	_compass.queue_redraw()
