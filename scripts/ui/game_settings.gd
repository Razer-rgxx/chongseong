class_name GameSettings
extends RefCounted
## 27단계 설정: 소리 크기, 마우스 감도, 키. user://settings.cfg에 저장한다(판 기록 hill_save.json과 따로).
## 자동 로드가 없어서 장면마다 ensure()를 부른다(처음 한 번만 읽고 적용한다). 소리 크기와 키는
## AudioServer와 InputMap에 바로 들어가서 장면이 바뀌어도 남는다. 감도는 camera_rig가 mouse()로 읽는다.

const PATH: String = "user://settings.cfg"
## 설정 창에 보이는 키(행동 이름, 보이는 이름). 행동마다 첫 입력 하나만 바꾼다(나머지 예비 키는 그대로).
const ACTIONS: Array = [
	["move_up", "앞으로"], ["move_down", "뒤로"], ["move_left", "왼쪽"], ["move_right", "오른쪽"],
	["attack", "베기"], ["hook", "갈고리"], ["dash", "구르기"], ["jump", "점프"], ["pull", "뽑기 · 들르기"],
	["swap", "검 바꾸기"], ["discard", "버리기"], ["start_night", "밤 부르기"], ["map", "지도"],
]

static var volume: float = 0.8
static var mouse_k: float = 1.0
## 행동 → 바꾼 첫 입력({"key": 코드} 또는 {"mouse": 버튼}). 없으면 프로젝트 기본값.
static var keys: Dictionary = {}
static var _loaded: bool = false
## 프로젝트 기본 첫 입력(기본값으로 되돌릴 때).
static var _defaults: Dictionary = {}


## 처음 한 번 읽고 적용한다. 장면의 _ready에서 부른다.
static func ensure() -> void:
	if _loaded:
		return
	_loaded = true
	for a in ACTIONS:
		var evs := InputMap.action_get_events(a[0])
		if not evs.is_empty():
			_defaults[a[0]] = evs[0]
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		volume = clampf(float(cf.get_value("sound", "volume", volume)), 0.0, 1.0)
		mouse_k = clampf(float(cf.get_value("mouse", "sensitivity", mouse_k)), 0.2, 3.0)
		var k: Variant = cf.get_value("keys", "map", {})
		if k is Dictionary:
			keys = k
	apply()


static func mouse() -> float:
	ensure()
	return mouse_k


static func apply() -> void:
	var bus: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(bus, volume <= 0.001)
	for a in ACTIONS:
		var name: String = a[0]
		var want: InputEvent = event_of(keys[name]) if keys.has(name) else _defaults.get(name)
		if want == null:
			continue
		var evs := InputMap.action_get_events(name)
		if not evs.is_empty():
			InputMap.action_erase_event(name, evs[0])
		# 첫 자리에 넣는다: 지우고 다시 넣으면서 순서를 맞춘다
		var rest := InputMap.action_get_events(name)
		InputMap.action_erase_events(name)
		InputMap.action_add_event(name, want)
		for e in rest:
			if not _same(e, want):
				InputMap.action_add_event(name, e)


static func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("sound", "volume", volume)
	cf.set_value("mouse", "sensitivity", mouse_k)
	cf.set_value("keys", "map", keys)
	cf.save(PATH)


static func reset() -> void:
	volume = 0.8
	mouse_k = 1.0
	keys = {}
	apply()
	save()


## 행동의 첫 입력을 바꾼다. 같은 입력을 쓰던 다른 행동이 있으면 그 행동은 기본값으로 돌린다.
static func bind(action: String, ev: InputEvent) -> void:
	var d := to_dict(ev)
	if d.is_empty():
		return
	for a in ACTIONS:
		if a[0] != action and keys.get(a[0], {}) == d:
			keys.erase(a[0])
	keys[action] = d
	apply()
	save()


static func to_dict(ev: InputEvent) -> Dictionary:
	var k := ev as InputEventKey
	if k:
		var code: int = k.physical_keycode if k.physical_keycode != 0 else k.keycode
		return {"key": int(code)}
	var m := ev as InputEventMouseButton
	if m:
		return {"mouse": int(m.button_index)}
	return {}


static func event_of(d: Dictionary) -> InputEvent:
	if d.has("key"):
		var k := InputEventKey.new()
		k.physical_keycode = int(d["key"]) as Key
		return k
	if d.has("mouse"):
		var m := InputEventMouseButton.new()
		m.button_index = int(d["mouse"]) as MouseButton
		return m
	return null


## 지금 그 행동의 첫 입력을 글자로(설정 창에 보인다).
static func label_of(action: String) -> String:
	var evs := InputMap.action_get_events(action)
	if evs.is_empty():
		return "-"
	return name_of(evs[0])


static func name_of(ev: InputEvent) -> String:
	var k := ev as InputEventKey
	if k:
		var code: Key = k.physical_keycode if k.physical_keycode != 0 else k.keycode
		return OS.get_keycode_string(code)
	var m := ev as InputEventMouseButton
	if m:
		match m.button_index:
			MOUSE_BUTTON_LEFT: return "마우스 왼쪽"
			MOUSE_BUTTON_RIGHT: return "마우스 오른쪽"
			MOUSE_BUTTON_MIDDLE: return "마우스 가운데"
		return "마우스 %d" % m.button_index
	return "?"


static func _same(a: InputEvent, b: InputEvent) -> bool:
	return to_dict(a) == to_dict(b)
