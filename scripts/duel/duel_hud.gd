class_name DuelHud
extends CanvasLayer
## 결투 화면의 UI(21단계). 위 가운데에 두 체력 막대와 판 점수·남은 시간, 한 줄 띠(판 결과), 끝나면 결과 창.
## 세계(3D)에는 글자를 띄우지 않는다. 막대는 1P가 왼쪽, 2P가 오른쪽(안쪽으로 줄어든다).

signal back_to_village()

const BAR_SIZE: Vector2 = Vector2(420, 16)
const COLORS: Array[Color] = [Color(0.72, 0.62, 0.3), Color(0.55, 0.2, 0.22)]
const NAMES: Array[String] = ["1P", "2P"]
## 온라인(22단계)에서 쓰는 이름: 늘 내가 "나"다. 같은 PC에서는 1P·2P 그대로.
const ONLINE_NAMES: Array[String] = ["나", "상대"]

var _bars: Array[ProgressBar] = []
var _score: Label
var _clock: Label
var _band: Band
var _result: Control
var _result_box: VBoxContainer
var _flash: ColorRect
var _name_labels: Array[Label] = []
var _names: Array[String] = NAMES.duplicate()
## 온라인: 내 자리(막대 왼쪽이 늘 나로 보이게 하지는 않는다. 자리 번호 그대로 두고 이름만 바꾼다).
var _online: bool = false


func _ready() -> void:
	UiKit.vignette(self)
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.offset_top = 22
	top.add_theme_constant_override("separation", 18)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	for i in 2:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 3)
		var name := UiKit.label(NAMES[i], 17, UiKit.TITLE)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		_name_labels.append(name)
		col.add_child(name)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = BAR_SIZE
		bar.fill_mode = ProgressBar.FILL_BEGIN_TO_END if i == 0 else ProgressBar.FILL_END_TO_BEGIN
		var bg := UiKit.style(Color(UiKit.LINE, 0.5), 1, Color(0.02, 0.018, 0.015, 0.8))
		var fill := UiKit.style(COLORS[i], 0, COLORS[i])
		for sb in [bg, fill]:
			sb.set_content_margin_all(0)
		bar.add_theme_stylebox_override("background", bg)
		bar.add_theme_stylebox_override("fill", fill)
		col.add_child(bar)
		_bars.append(bar)
		top.add_child(col)
		if i == 0:
			var mid := VBoxContainer.new()
			mid.add_theme_constant_override("separation", 0)
			_score = UiKit.label("0 : 0", 30, UiKit.TITLE)
			_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_score.custom_minimum_size = Vector2(110, 0)
			_clock = UiKit.label("90", 18, UiKit.MUTED)
			_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mid.add_child(_score)
			mid.add_child(_clock)
			top.add_child(mid)
	_band = Band.make(self, 120.0, 760.0, 60.0, 26)
	_result = ColorRect.new()
	(_result as ColorRect).color = Color(0.0, 0.0, 0.0, 0.62)
	_result.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result.visible = false
	add_child(_result)
	_result_box = UiKit.center_panel(_result)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	add_child(_flash)


## 온라인이면 이름을 "나"와 "상대"로 바꾼다(my_seat: 내 자리).
func set_online(my_seat: int) -> void:
	_online = true
	_names = ["", ""]
	_names[my_seat] = Account.display_name(ONLINE_NAMES[0])
	_names[1 - my_seat] = ONLINE_NAMES[1]
	for i in 2:
		_name_labels[i].text = _names[i]


## 두 영주의 검 이름(지은 이름이 있으면 그것)을 이름 곁에 보인다.
func set_swords(a: String, b: String) -> void:
	var sw: Array[String] = [a, b]
	for i in 2:
		_name_labels[i].text = "%s · %s" % [_names[i], sw[i]] if sw[i] != "" else _names[i]


func player_name(i: int) -> String:
	return _names[i]


## 매 화면: 체력과 점수와 남은 시간.
func set_state(hp_a: float, hp_b: float, max_hp: float, wins: Array[int], left: float) -> void:
	_bars[0].max_value = max_hp
	_bars[1].max_value = max_hp
	_bars[0].value = maxf(0.0, hp_a)
	_bars[1].value = maxf(0.0, hp_b)
	_score.text = "%d : %d" % [wins[0], wins[1]]
	_clock.text = str(maxi(0, ceili(left)))


func announce(text: String, secs: float = 1.8) -> void:
	_band.show_for(text, secs)


func flash(c: Color, strength: float, time: float = 0.4) -> void:
	_flash.color = Color(c, strength)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, time)


## 결과 창. winner: 0, 1, -1(비김). wins: 이긴 판 수, record: Meta의 이김·짐.
func show_result(winner: int, wins: Array[int], record: Vector2i) -> void:
	for c in _result_box.get_children():
		c.queue_free()
	var title: String = "비겼다" if winner < 0 else ("%s가 이겼다" % _names[winner] if _online else "%s 이김" % NAMES[winner])
	var h := UiKit.label(title, 30, UiKit.TITLE)
	_result_box.add_child(h)
	_result_box.add_child(UiKit.rule())
	_result_box.add_child(UiKit.label("판 점수  %d : %d" % [wins[0], wins[1]], 20, UiKit.TEXT))
	_result_box.add_child(UiKit.label("내 기록%s  이김 %d · 짐 %d" % ["" if _online else "(1P)", record.x, record.y], 15, UiKit.MUTED))
	_result_box.add_child(UiKit.button("마을로", func() -> void: back_to_village.emit(), 40.0))
	_result.visible = true


## 온라인이 끊겼거나 어긋나 더 못 겨룬다(기록하지 않는다). 창 하나와 마을로 버튼.
func show_notice(title: String, text: String) -> void:
	for c in _result_box.get_children():
		c.queue_free()
	_result_box.add_child(UiKit.label(title, 28, UiKit.TITLE))
	_result_box.add_child(UiKit.rule())
	var l := UiKit.label(text, 16, UiKit.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(460, 0)
	_result_box.add_child(l)
	_result_box.add_child(UiKit.button("마을로", func() -> void: back_to_village.emit(), 40.0))
	_result.visible = true
