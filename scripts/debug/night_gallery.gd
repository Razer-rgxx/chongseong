extends Node3D
## 12·13단계 밤과 낮 사건의 모양 보기(모양팀). Godot에서 scenes/debug/night_gallery.tscn을 열고 F6(지금 장면 실행)으로 띄운다.
## 규칙(Rules) 없이 돈다: 언덕(HillBuilder)과 main.tscn의 환경을 깔고, NightArt·EventArt로 짓고 NightFx·EventFx의 함수를 바로 부른다.
## 키:
##   1 봉화가 맞는다(체력이 줄수록 불이 작아진다, 0이면 꺼진다)   2 봉화 꺼짐 / 다시 붙이기
##   3 불씨 땅(세 곳이 1초 미리 보이고 4초 탄다)   4 무덤에서 일어남   5 포위 쪽 바꾸기(북 → 남 → 서 → 동 → 없음)
##   6 짙은 안개 켜기/끄기   7 우두머리 고리 켜기/끄기(돌아다니는 큰 적)
##   8 대장장이 쓰기   9 순례자 쓰기   0 점쟁이 쓰기   H 저주받은 손잡이 기운 켜기/걷기   X 사건 셋이 사라짐(잠시 뒤 다시 선다)
##   N 낮/밤   C 카메라(전체 → 봉화 → 불씨 → 무덤 → 포위 → 우두머리 → 사건 → 손잡이)   마우스 오른쪽 끌기 = 돌리기, 휠 = 가깝게·멀게
## 왼쪽 위에 키와 방금 튼 것을 적는다(화면 글자. 세계에는 글자를 띄우지 않는다).
## 찍는 도구가 부르는 것: press(key), set_night(on), cam(i), view(yaw, pitch, dist, at), nfx, efx, beacon, events.

const MAIN: String = "res://scenes/world/main.tscn"
const BEACON := Vector2(17.0, 8.5)
const EMBERS: Array[Vector2] = [Vector2(10.5, 7.0), Vector2(12.5, 11.0), Vector2(8.0, 10.5)]
const GRAVE := Vector2(24.0, 7.5)
const BOSS := Vector2(27.0, 12.5)
const EVENT_KINDS: Array[StringName] = [&"smith", &"pilgrim", &"seer"]
const EVENT_AT: Array[Vector2] = [Vector2(13.5, 16.0), Vector2(17.0, 16.4), Vector2(20.5, 16.0)]
const HILT := Vector2(24.5, 16.2)
const NAMES: Array[String] = ["전체", "봉화", "불씨 땅", "무덤", "포위", "우두머리", "사건", "손잡이"]

## 끄면 언덕의 땅·하늘·바위만 짓는다(풀과 숲 없이).
@export var full_hill: bool = true

var nfx: NightFx
var efx: EventFx
var beacon: Dictionary = {}
var events: Array[Dictionary] = []
var cam: Camera3D
var env: Environment
var sun: DirectionalLight3D
var label: Label
var night: bool = true
var _we: WorldEnvironment
var _beacon_hp: float = 300.0
var _side: int = -1
var _fog: bool = false
var _boss: Node3D
var _boss_ring: bool = false
var _hilt: Node3D
var _hilt_sword: Node3D
var _aura: bool = false
var _later: Array[Array] = []
var _t: float = 0.0
var _cam_i: int = 0
var _yaw: float = 0.0
var _pitch: float = 0.5
var _dist: float = 30.0
var _at := Vector3.ZERO
var _drag: bool = false
var _last: String = ""


func _ready() -> void:
	var data := GameData.load_default()
	Grid.size = data.run.arena_size
	_we = WorldEnvironment.new()
	env = _main_env()
	_we.environment = env
	add_child(_we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	add_child(sun)
	if full_hill:
		HillBuilder.build(self, env, data.forms)
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		HillBuilder.setup(Vector2(Grid.size) * Grid.CELL)
		HillBuilder._terrain(self)
		HillBuilder._sky(env)
		HillBuilder._rocks(self, rng)
	cam = Camera3D.new()
	cam.fov = 55.0
	cam.far = 400.0
	add_child(cam)
	cam.make_current()
	nfx = NightFx.new()
	add_child(nfx)
	nfx.setup(null)
	efx = EventFx.new()
	add_child(efx)
	# 봉화
	var bh := Node3D.new()
	bh.position = _ground(BEACON)
	add_child(bh)
	beacon = NightArt.beacon(bh)
	nfx.watch_beacon(beacon)
	# 우두머리 자리(부르는 자의 몸을 크게)
	_boss = Node3D.new()
	add_child(_boss)
	EnemyArt.build_caller(_boss, 1.45, Color(0.55, 0.8, 0.6))
	# 사건 셋과 저주받은 손잡이
	for i in EVENT_KINDS.size():
		_make_event(i)
	_hilt = Node3D.new()
	_hilt.position = _ground(HILT)
	add_child(_hilt)
	_hilt_sword = SwordModel.make(data.forms[1 % data.forms.size()], 0, 77, Color.WHITE)
	_hilt_sword.rotation = Vector3(PI, 0.0, 0.12)
	_hilt_sword.position.y = 0.55 + (_hilt_sword as SwordModel).grip_length * 0.3
	_hilt.add_child(_hilt_sword)
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(16, 10)
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.74))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	layer.add_child(label)
	set_night(true)
	cam_to(0)


func _main_env() -> Environment:
	var st: SceneState = (load(MAIN) as PackedScene).get_state()
	for i in st.get_node_count():
		if st.get_node_name(i) != &"Environment":
			continue
		for k in st.get_node_property_count(i):
			if st.get_node_property_name(i, k) == &"environment":
				return (st.get_node_property_value(i, k) as Environment).duplicate()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	return e


func _make_event(i: int) -> void:
	var h := Node3D.new()
	h.position = _ground(EVENT_AT[i])
	h.rotation.y = PI + (EVENT_AT[i].x - 17.0) * 0.06
	add_child(h)
	var P: Dictionary = EventArt.build(EVENT_KINDS[i], h)
	P["holder"] = h
	if events.size() > i:
		events[i] = P
	else:
		events.append(P)


func _process(delta: float) -> void:
	_t += delta
	for i in range(_later.size() - 1, -1, -1):
		var e: Array = _later[i]
		e[0] = float(e[0]) - delta
		if float(e[0]) <= 0.0:
			_later.remove_at(i)
			(e[1] as Callable).call()
	for P in events:
		if is_instance_valid(P.get("root")):
			EventArt.breathe(P, _t)
	# 우두머리: 작은 원을 돈다
	var a: float = _t * 0.6
	var bp: Vector2 = BOSS + Vector2(cos(a), sin(a)) * 2.0
	_boss.position = _ground(bp)
	_boss.rotation.y = -a
	label.text = "1 봉화 맞음  2 봉화 꺼짐/붙임  3 불씨 땅  4 무덤  5 포위 쪽  6 안개  7 우두머리 고리\n8 대장장이  9 순례자  0 점쟁이  H 저주받은 손잡이  X 사라짐  N 낮/밤  C 카메라(%s)\n%s   %s" % [NAMES[_cam_i], "밤" if night else "낮", _last]


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo:
		press(OS.get_keycode_string(k.keycode))
	var mb := event as InputEventMouseButton
	if mb:
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_drag = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(2.0, _dist * 0.9)
			_camera()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(120.0, _dist * 1.1)
			_camera()
	var mm := event as InputEventMouseMotion
	if mm and _drag:
		_yaw -= mm.relative.x * 0.006
		_pitch = clampf(_pitch + mm.relative.y * 0.004, 0.05, 1.45)
		_camera()


## 키 하나(찍는 도구도 부른다): "1"~"0", "H", "X", "N", "C".
func press(key: String) -> void:
	match key:
		"1":
			_beacon_hp = maxf(0.0, _beacon_hp - 45.0)
			if _beacon_hp <= 0.0:
				nfx.on_beacon_out()
				_last = "봉화가 꺼졌다"
			else:
				nfx.on_beacon_hit(_beacon_hp, 300.0)
				_last = "봉화 맞음 %d/300" % _beacon_hp
		"2":
			if float(beacon.get("fire", 1.0)) > 0.05 and _beacon_hp > 0.0:
				_beacon_hp = 0.0
				nfx.on_beacon_out()
				_last = "봉화가 꺼졌다"
			else:
				_beacon_hp = 300.0
				nfx.relight_beacon()
				_last = "봉화에 다시 불을 붙였다"
		"3":
			for p in EMBERS:
				nfx.on_ember_warn(p, 1.5, 1.0)
			_later.append([1.0, func() -> void:
				for p in EMBERS:
					nfx.on_ember_burn(p, 1.5, 4.0)])
			_last = "불씨 땅: 미리 보임 1초 → 4초 탐"
		"4":
			nfx.on_grave_rise(GRAVE)
			_last = "무덤에서 일어남"
		"5":
			_side = _side + 1 if _side < 3 else -1
			nfx.on_siege_side(_side)
			_last = "포위: %s" % ["없음", "북", "남", "서", "동"][_side + 1]
		"6":
			_fog = not _fog
			nfx.fog(env, _fog)
			_last = "짙은 안개 %s" % ("켬" if _fog else "끔")
		"7":
			_boss_ring = not _boss_ring
			if _boss_ring:
				nfx.ring_follow(_boss, 1.6)
			else:
				nfx.ring_drop(_boss)
			_last = "우두머리 고리 %s" % ("켬" if _boss_ring else "끔")
		"8", "9", "0":
			var i: int = {"8": 0, "9": 1, "0": 2}[key]
			if is_instance_valid(events[i].get("root")) and (events[i].root as Node3D).visible:
				efx.used(events[i])
				_last = "%s 쓰기" % ["대장장이", "순례자", "점쟁이"][i]
		"H":
			_aura = not _aura
			if _aura:
				EventArt.curse_hilt(_hilt_sword)
				efx.aura(_hilt)
				_last = "저주받은 손잡이"
			else:
				efx.aura_off(_hilt, true)
				EventArt.uncurse_hilt(_hilt_sword)
				_last = "검은 기운이 걷혔다"
		"X":
			for i in events.size():
				efx.vanish(events[i])
			_later.append([3.0, func() -> void:
				for i in EVENT_KINDS.size():
					var h: Variant = events[i].get("holder")
					if h is Node3D and is_instance_valid(h):
						(h as Node3D).queue_free()
					_make_event(i)])
			_last = "사건 셋이 사라진다"
		"N":
			set_night(not night)
		"C":
			cam_to((_cam_i + 1) % NAMES.size())


## 밤/낮: main._set_light와 같은 값(바로 바꾼다).
func set_night(on: bool) -> void:
	night = on
	sun.light_energy = 1.1 if on else 0.75
	sun.light_color = Color(0.55, 0.65, 1.0) if on else Color(1.0, 0.93, 0.84)
	env.fog_light_color = Color(0.05, 0.06, 0.09) if on else Color(0.44, 0.46, 0.48)
	env.ambient_light_color = Color(0.3, 0.36, 0.52)
	env.ambient_light_sky_contribution = 0.15 if on else 1.0
	env.ambient_light_energy = 1.2 if on else 1.0
	env.background_color = Color(0.01, 0.015, 0.03) if on else Color(0.06, 0.08, 0.12)
	if HillBuilder.sky_material:
		HillBuilder.sky_material.set_shader_parameter("night", 1.0 if on else 0.0)


func cam_to(i: int) -> void:
	_cam_i = i
	match i:
		0:
			view(0.0, 0.62, 36.0, _ground(Vector2(17.0, 12.0)) + Vector3(0, 1, 0))
		1:
			view(0.45, 0.22, 6.5, _ground(BEACON) + Vector3(0, 1.3, 0))
		2:
			view(-0.25, 0.5, 15.0, _ground(Vector2(10.5, 9.5)) + Vector3(0, 0.5, 0))
		3:
			view(0.6, 0.38, 6.5, _ground(GRAVE) + Vector3(0, 0.4, 0))
		4:
			view(0.0, 1.0, 52.0, _ground(Vector2(17.0, 11.0)))
		5:
			view(0.3, 0.42, 10.0, _ground(BOSS) + Vector3(0, 0.8, 0))
		6:
			view(0.0, 0.18, 11.5, _ground(Vector2(17.0, 16.2)) + Vector3(0, 1.0, 0))
		_:
			view(0.5, 0.32, 3.6, _ground(HILT) + Vector3(0, 0.7, 0))


## yaw(라디안, 0 = 남쪽에서 북쪽을 본다), pitch(내려다보는 각), dist(m), at(보는 점).
func view(yaw: float, pitch: float, dist: float, at: Vector3) -> void:
	_yaw = yaw
	_pitch = pitch
	_dist = dist
	_at = at
	_camera()


func _camera() -> void:
	var off := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _dist
	cam.global_position = _at + off
	cam.look_at(_at, Vector3.UP)


func _ground(c: Vector2) -> Vector3:
	var w: Vector3 = Grid.cells_to_world(c)
	w.y = HillBuilder.height(w.x, w.z)
	return w
