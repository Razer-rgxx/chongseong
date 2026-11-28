extends RefCounted
## 27단계 설정 테스트(소리 크기, 키 바꾸기, 기본값). run_all.gd가 부른다: run(데이터, check).
## 저장 파일은 건드리지 않게 PATH를 쓰지 않는 부분만 본다(bind·reset은 저장하므로 끝에 기본값으로 되돌린다).

var check: Callable


static func run(_game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/settings_tests.gd") as GDScript).new()
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	GameSettings.ensure()
	var keep_vol: float = GameSettings.volume
	var keep_mouse: float = GameSettings.mouse_k
	var keep_keys: Dictionary = GameSettings.keys.duplicate()
	# 키 바꾸기: 첫 입력만 바뀌고 예비 키(화살표)는 남는다
	var k := InputEventKey.new()
	k.physical_keycode = KEY_I
	GameSettings.keys = {}
	GameSettings.apply()
	var before: int = InputMap.action_get_events("move_up").size()
	GameSettings.keys["move_up"] = GameSettings.to_dict(k)
	GameSettings.apply()
	var evs := InputMap.action_get_events("move_up")
	check.call(GameSettings.label_of("move_up") == "I", "설정: 앞으로 키를 I로 바꾼다")
	check.call(evs.size() == before, "설정: 예비 키는 그대로 남는다")
	# 같은 키를 다른 행동에 주면 앞의 행동은 기본값으로
	GameSettings.keys["move_down"] = GameSettings.to_dict(k)
	for a in GameSettings.ACTIONS:
		if a[0] != "move_down" and GameSettings.keys.get(a[0], {}) == GameSettings.to_dict(k):
			GameSettings.keys.erase(a[0])
	GameSettings.apply()
	check.call(GameSettings.label_of("move_up") == "W" and GameSettings.label_of("move_down") == "I", "설정: 겹친 키는 앞의 것을 기본값으로 돌린다")
	# 마우스 버튼도 묶을 수 있다
	var m := InputEventMouseButton.new()
	m.button_index = MOUSE_BUTTON_MIDDLE
	check.call(GameSettings.event_of(GameSettings.to_dict(m)) is InputEventMouseButton, "설정: 마우스 버튼을 저장 모양으로 바꿨다 되돌린다")
	# 소리 크기 0이면 끈다
	GameSettings.volume = 0.0
	GameSettings.apply()
	check.call(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "설정: 소리 0이면 끈다")
	# 되돌리기
	GameSettings.volume = keep_vol
	GameSettings.mouse_k = keep_mouse
	GameSettings.keys = keep_keys
	GameSettings.apply()
	check.call(GameSettings.label_of("move_up") != "", "설정: 원래대로")
