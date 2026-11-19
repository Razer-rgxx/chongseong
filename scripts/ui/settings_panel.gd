class_name SettingsPanel
extends Control
## 27단계 설정 창(UiKit 모양). 시작 화면과 마을·언덕(F10)에서 연다.
## 열려 있는 동안 게임을 멈추고(pause_game이면) 마우스를 풀어 준다. 닫으면 closed.
## 키 바꾸기: 키 칸을 누르고 새 키나 마우스 버튼을 누른다. Esc는 바꾸기를 그만둔다.

signal closed

var pause_game: bool = true
var _vol: HSlider
var _vol_text: Label
var _mouse: HSlider
var _mouse_text: Label
var _key_buttons: Dictionary = {}
var _waiting: String = ""
var _was_paused: bool = false
var _was_mouse: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	GameSettings.ensure()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := UiKit.center_panel(self)
	box.custom_minimum_size = Vector2(520, 0)
	UiKit.header(box, "설정", close)

	box.add_child(UiKit.label("소리", 18, UiKit.TITLE))
	var r1 := HBoxContainer.new()
	_vol = _slider(0.0, 1.0, 0.05, GameSettings.volume)
	_vol.value_changed.connect(_on_volume)
	_vol_text = UiKit.label("", 16)
	_vol_text.custom_minimum_size = Vector2(60, 0)
	r1.add_child(_vol)
	r1.add_child(_vol_text)
	box.add_child(r1)

	box.add_child(UiKit.label("마우스 감도", 18, UiKit.TITLE))
	var r2 := HBoxContainer.new()
	_mouse = _slider(0.2, 3.0, 0.05, GameSettings.mouse_k)
	_mouse.value_changed.connect(_on_mouse)
	_mouse_text = UiKit.label("", 16)
	_mouse_text.custom_minimum_size = Vector2(60, 0)
	r2.add_child(_mouse)
	r2.add_child(_mouse_text)
	box.add_child(r2)

	box.add_child(UiKit.rule())
	box.add_child(UiKit.label("키", 18, UiKit.TITLE))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	for a in GameSettings.ACTIONS:
		var l := UiKit.label(a[1], 15, UiKit.MUTED)
		l.custom_minimum_size = Vector2(110, 0)
		grid.add_child(l)
		var b := UiKit.button("", _start_wait.bind(a[0]), 30)
		b.custom_minimum_size = Vector2(120, 30)
		grid.add_child(b)
		_key_buttons[a[0]] = b
	box.add_child(grid)
	box.add_child(UiKit.label("키 칸을 누르고 새 키를 누릅니다. 예비 키(화살표 등)는 그대로 남습니다.", 13, UiKit.MUTED))
	box.add_child(UiKit.rule())
	box.add_child(UiKit.button("기본값으로", _reset, 34))
	_refresh()


func open() -> void:
	_was_paused = get_tree().paused
	_was_mouse = Input.mouse_mode
	if pause_game:
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true


func close() -> void:
	if _waiting != "":
		_waiting = ""
		_refresh()
		return
	GameSettings.save()
	if pause_game:
		get_tree().paused = _was_paused
	Input.mouse_mode = _was_mouse
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var k := event as InputEventKey
	var mb := event as InputEventMouseButton
	if _waiting != "":
		if k and k.pressed and not k.echo:
			if k.physical_keycode != KEY_ESCAPE:
				GameSettings.bind(_waiting, k)
			_waiting = ""
			_refresh()
			get_viewport().set_input_as_handled()
		elif mb and mb.pressed and mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]:
			# 키 칸을 누른 그 클릭은 버튼이 먼저 받으니, 기다리기 시작한 뒤의 클릭만 온다
			GameSettings.bind(_waiting, mb)
			_waiting = ""
			_refresh()
			get_viewport().set_input_as_handled()
		return
	if k and k.pressed and not k.echo and (k.physical_keycode == KEY_ESCAPE or k.physical_keycode == KEY_F10):
		close()
		get_viewport().set_input_as_handled()


func _start_wait(action: String) -> void:
	# 버튼을 누른 클릭이 바로 키로 잡히지 않게 한 프레임 뒤에 기다린다
	await get_tree().process_frame
	_waiting = action
	_refresh()


func _on_volume(v: float) -> void:
	GameSettings.volume = v
	GameSettings.apply()
	_refresh()


func _on_mouse(v: float) -> void:
	GameSettings.mouse_k = v
	_refresh()


func _reset() -> void:
	GameSettings.reset()
	_vol.set_value_no_signal(GameSettings.volume)
	_mouse.set_value_no_signal(GameSettings.mouse_k)
	_refresh()


func _refresh() -> void:
	_vol_text.text = "%d%%" % roundi(GameSettings.volume * 100.0)
	_mouse_text.text = "×%.2f" % GameSettings.mouse_k
	for a in _key_buttons:
		var b: Button = _key_buttons[a]
		b.text = "…누르세요" if a == _waiting else GameSettings.label_of(a)


func _slider(lo: float, hi: float, step: float, v: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = v
	s.focus_mode = Control.FOCUS_NONE
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(360, 24)
	return s
