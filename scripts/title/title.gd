extends Control
## 27단계 시작 화면. 처음 켜면 여기다: 시작(마을), 설정, 끝내기.
## 엘든 링식: 거의 검은 바탕, 가운데 제목과 놋쇠빛 줄, 글자 버튼. 소리는 내지 않는다.

const LOBBY: String = "res://scenes/lobby/lobby.tscn"

var _menu: VBoxContainer


func _ready() -> void:
	GameSettings.ensure()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.018, 0.016)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	UiKit.vignette(self)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var t := UiKit.label("검의 언덕", 64, UiKit.TITLE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	box.add_child(UiKit.rule(420))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	box.add_child(gap)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 6)
	for item in [["시작", _start], ["설정", _settings], ["끝내기", _quit]]:
		var b := UiKit.button(item[0], item[1], 42)
		b.flat = true
		b.custom_minimum_size = Vector2(240, 42)
		b.add_theme_font_size_override("font_size", 22)
		_menu.add_child(b)
	box.add_child(_menu)
	if OS.has_feature("web"):
		_menu.get_child(2).visible = false   # 웹판에는 끝내기가 없다


func _start() -> void:
	get_tree().change_scene_to_file(LOBBY)


func _settings() -> void:
	var p := SettingsPanel.new()
	p.pause_game = false
	add_child(p)
	_menu.modulate.a = 0.0
	p.closed.connect(func() -> void: _menu.modulate.a = 1.0)
	p.open()


func _quit() -> void:
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and (k.physical_keycode == KEY_ENTER or k.physical_keycode == KEY_KP_ENTER):
		_start()
