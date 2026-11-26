class_name LeagueWindow
extends ColorRect
## 리그 창(docs/duel_league.md 7): 내 티어 카드, 시즌과 남은 날, 이번 시즌 최고, 칭호, 기록, 위쪽 N명(온라인 순위표가 있을 때).
## 마을 결투 말뚝 창과 시작 화면에서 연다. 닫으면 스스로 지운다.

signal closed()

var _meta: Meta
var _list: VBoxContainer
var _note: Label


static func open(parent: Node, meta: Meta) -> LeagueWindow:
	var w := LeagueWindow.new()
	w._meta = meta
	parent.add_child(w)
	return w


func _ready() -> void:
	color = Color(0.0, 0.0, 0.0, 0.7)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name = "UiLeague"
	var ld: LeagueData = League.data()
	var box: VBoxContainer = UiKit.center_panel(self)
	UiKit.header(box, "결투 리그", _close)
	var st: Dictionary = League.state(_meta)
	box.add_child(LeagueUi.card(_meta, 88.0, 260.0))
	box.add_child(UiKit.rule())
	var season: int = League.season_now(_meta)
	box.add_child(UiKit.label("시즌 %d  ·  끝까지 %d일" % [season, League.days_left(Time.get_unix_time_from_system(), ld)], 16, UiKit.TEXT))
	box.add_child(UiKit.label("이번 시즌 최고  %s" % ("-" if int(st.games) < ld.placement_games else League.step_name(_peak_step(_meta, st), ld)), 15, UiKit.TEXT))
	box.add_child(UiKit.label("랭크 기록  이김 %d · 짐 %d" % [int(st.wins), int(st.losses)], 15, UiKit.MUTED))
	var titles: Array[String] = []
	var keys: Array = _meta.league_titles.keys()
	keys.sort_custom(func(a, b) -> bool: return int(a) > int(b))
	for k in keys:
		titles.append("S%s %s" % [k, League.step_name(int(_meta.league_titles[k]), ld)])
	if not titles.is_empty():
		box.add_child(UiKit.label("지난 시즌 칭호  " + " · ".join(titles), 14, UiKit.LINE))
	box.add_child(UiKit.rule())
	box.add_child(UiKit.label("위쪽 %d명 (불멸 3 안에서 %s)" % [ld.top_n, ld.top_name], 15, UiKit.TITLE))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	box.add_child(_list)
	_note = UiKit.label("순위표를 불러오는 중", 14, UiKit.MUTED)
	_list.add_child(_note)
	_fetch()


static func _peak_step(meta: Meta, st: Dictionary) -> int:
	return League.SWORD_STEP if meta.league_sword and int(st.peak) >= League.MAX_STEP else int(st.peak)


func _fetch() -> void:
	var r: Dictionary = await LeagueBoard.top(get_tree(), _meta)
	if not is_inside_tree():
		return
	fill_rows(r)


## 받은 결과를 줄로 채운다(시험과 캡처도 쓴다): {ok, rows, text}.
func fill_rows(r: Dictionary) -> void:
	for c in _list.get_children():
		c.queue_free()
	if not bool(r.get("ok", false)):
		_list.add_child(UiKit.label(str(r.get("text", "")), 14, UiKit.MUTED))
		return
	var rows: Array = r.rows
	if rows.is_empty():
		_list.add_child(UiKit.label("아직 올라온 기록이 없다", 14, UiKit.MUTED))
		return
	var ld: LeagueData = League.data()
	for i in mini(rows.size(), ld.list_rows):
		var row: Dictionary = rows[i]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.add_child(UiKit.label("%d" % (int(row.rank) + 1), 14, UiKit.MUTED))
		h.add_child(LeagueUi.emblem(League.SWORD_STEP if League.is_top(int(row.rank), int(row.step), ld) else int(row.step), 24.0))
		var t: String = str(row.get("title", ""))
		h.add_child(UiKit.label(("「%s」 %s" % [t, row.name]) if t != "" else str(row.name), 15, UiKit.TEXT))
		h.add_child(UiKit.label("%s · RR %d" % [League.step_name(int(row.step), ld), int(row.rr)], 14, UiKit.MUTED))
		_list.add_child(h)


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	closed.emit()
	queue_free()
