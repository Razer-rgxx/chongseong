extends Node3D
## 11단계 새 적 5종의 효과 보기(이펙트팀). Godot에서 scenes/debug/enemy_gallery.tscn을 열고 F6(지금 장면 실행)으로 띄운다.
## 규칙(Rules) 없이 돈다: 언덕(HillBuilder)과 main.tscn의 환경을 그대로 깔고, 가짜 Enemy 다섯을 북쪽에 줄지어 세워
## EnemyArt로 몸을 짓고 EnemyMotion으로 움직인다. EnemyFx의 on_* 함수를 가짜 info로 바로 부르고, 화살(Projectile)과
## 돌격병의 달리기는 여기서 30Hz 틱으로 옮긴다(EnemyFx.draw에 틱 사이 alpha를 넘긴다). 남쪽의 회색 기둥이 가짜 영주다.
## 키:
##   1 활잡이: 겨누고 쏜다(누를 때마다 영주에게 맞음 → 칼에 부러짐 → 빗나가 땅에 꽂힘)
##   2 방패병: 막기 → 막기 → 방패 깨짐
##   3 돌격병: 머리 낮추고 돌진(누를 때마다 영주에게 맞음 → 옆으로 빗나감), 끝나면 비틀거리다 제자리로 걸어온다
##   4 자폭병: 심지 → 폭발(잠시 뒤 다시 선다)
##   5 부르는 자: 불러내기 → 부르기(둘레 세 자리)
##   0 다섯 모두   N 낮/밤   C 카메라(전체 → 하나씩)   마우스 오른쪽 끌기 = 돌리기, 휠 = 가깝게·멀게
## 왼쪽 위에 키와 방금 튼 것을 적는다(화면 글자. 세계에는 글자를 띄우지 않는다).
## 찍는 도구가 부르는 것: play(i), set_night(on), focus(i), view(yaw, pitch, dist, at), fx, slots, busy(i).

const MAIN: String = "res://scenes/world/main.tscn"
const KINDS: Array[StringName] = [&"archer", &"shield", &"charger", &"bomber", &"caller"]
const NAMES: Array[String] = ["활잡이", "방패병", "돌격병", "자폭병", "부르는 자"]
## 표의 크기(칸, docs/content.md 11단계)와 갤러리에서 쓰는 색.
const RADIUS: Array[float] = [0.28, 0.34, 0.4, 0.24, 0.3]
const COLORS: Array[Color] = [Color(0.75, 0.68, 0.55), Color(0.55, 0.6, 0.68), Color(0.6, 0.3, 0.2), Color(0.9, 0.45, 0.15), Color(0.55, 0.8, 0.6)]
const XS: Array[float] = [9.0, 13.0, 17.0, 21.0, 25.0]
const ROW_Y: float = 8.0
const LORD := Vector2(17.0, 15.0)
const TICK: float = 1.0 / 30.0
## 행동 길이(초)와 빠르기(칸/초). 규칙의 첫 값.
const ARROW_SPEED: float = 11.0
const CHARGE_SPEED: float = 13.0

## 끄면 언덕의 땅·하늘·바위만 짓는다(풀과 숲 없이, 느린 컴퓨터나 찍는 도구에서 빠르게).
@export var full_hill: bool = true

var fx: EnemyFx
var slots: Array[Dictionary] = []
var cam: Camera3D
var env: Environment
var sun: DirectionalLight3D
var torch: OmniLight3D
var label: Label
var night: bool = false
var _arrows: Array[Dictionary] = []
var _acc: float = 0.0
var _alpha: float = 1.0
var _t: float = 0.0
var _cam_mode: int = -1
var _yaw: float = 0.0
var _pitch: float = 0.5
var _dist: float = 30.0
var _at := Vector3.ZERO
var _drag: bool = false
var _last: String = ""
var _ids: int = 900


func _ready() -> void:
	var data := GameData.load_default()
	Grid.size = data.run.arena_size
	# 환경: main.tscn의 것을 그대로(밤은 main._set_light와 같은 값)
	var we := WorldEnvironment.new()
	env = _main_env()
	we.environment = env
	add_child(we)
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
	_lord_marker()
	fx = EnemyFx.new()
	add_child(fx)
	fx.setup(null, func(e: Enemy) -> Dictionary: return _parts_of(e))
	for i in KINDS.size():
		_make_slot(i)
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(16, 10)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.74))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	layer.add_child(label)
	set_night(false)
	focus(-1)


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


## 가짜 영주: 어두운 천 기둥과 머리. 밤에는 main처럼 횃불을 든다.
func _lord_marker() -> void:
	var holder := Node3D.new()
	holder.position = _ground(LORD)
	add_child(holder)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.32, 0.31, 0.3)
	m.roughness = 0.8
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.28
	cap.height = 1.55
	body.mesh = cap
	body.material_override = m
	body.position.y = 0.78
	holder.add_child(body)
	var head := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.14
	sp.height = 0.28
	head.mesh = sp
	head.material_override = m
	head.position.y = 1.7
	holder.add_child(head)
	torch = OmniLight3D.new()
	torch.position = Vector3(0.4, 2.2, 0.3)
	torch.light_color = Color(1.0, 0.72, 0.45)
	torch.omni_range = 9.0
	torch.shadow_enabled = true
	holder.add_child(torch)


func _make_slot(i: int) -> void:
	var kind: StringName = KINDS[i]
	var e := Enemy.new()
	e.id = i + 1
	var d := EnemyData.new()
	d.id = kind
	d.radius = RADIUS[i]
	d.color = COLORS[i]
	e.data = d
	e.radius = RADIUS[i]
	e.pos = Vector2(XS[i], ROW_Y)
	e.prev_pos = e.pos
	e.face = (LORD - e.pos).normalized()
	var holder := Node3D.new()
	add_child(holder)
	var body := Node3D.new()
	holder.add_child(body)
	var parts: Dictionary = EnemyArt.build(kind, body, 1.0, COLORS[i])
	var motion: Dictionary = EnemyMotion.rest(parts)
	slots.append({
		"kind": kind, "e": e, "holder": holder, "parts": parts, "motion": motion, "home": e.pos,
		"queue": [], "act": &"", "act_t": 0.0, "act_time": 0.0, "variant": 0, "speed": 0.0, "backing": false,
		"move": {}, "guard_down": 0.0, "stun": 0.0, "hidden": false, "pop": 1.0,
	})
	_place(slots[i])


func _parts_of(e: Enemy) -> Dictionary:
	for s in slots:
		if is_same(s["e"], e):
			return s["parts"]
	return {}


# ---------------------------------------------------------------- 차례

## i번 적(0~4)의 다음 차례를 튼다. 아직 하는 중이면 무시한다.
func play(i: int) -> void:
	if i < 0 or i >= slots.size() or busy(i):
		return
	var s: Dictionary = slots[i]
	var e: Enemy = s["e"]
	var v: int = s["variant"]
	var steps: Array = []
	var to_lord: Vector2 = (LORD - e.pos).normalized()
	match s["kind"]:
		&"archer":
			var mode: String = ["hit", "cut", "miss"][v % 3]
			var d: Vector2 = to_lord if mode != "miss" else to_lord.rotated(0.13)
			e.face = d
			steps.append({"act": &"aim", "time": 0.6, "info": {"from": e.pos, "dir": d, "time": 0.6, "length": 12.0}})
			steps.append({"act": &"shoot", "time": 0.3, "info": {"from": e.pos, "dir": d}, "go": _shoot.bind(e, d, mode)})
			_last = "활잡이: 겨누고 쏜다 — " + {"hit": "영주에게 맞음", "cut": "칼에 부러짐", "miss": "빗나가 땅에 꽂힘"}[mode]
		&"shield":
			e.face = to_lord
			if v % 3 < 2:
				steps.append({"act": &"block", "time": 0.3, "info": {"at": e.pos, "dir": to_lord}})
				_last = "방패병: 막기"
			else:
				steps.append({"act": &"guard_break", "time": 1.2, "info": {"at": e.pos, "time": 1.2}, "go": func() -> void: s["guard_down"] = 2.0})
				_last = "방패병: 방패 깨짐"
		&"charger":
			var hit: bool = v % 2 == 0
			var d: Vector2 = to_lord if hit else to_lord.rotated(0.32)
			e.face = d
			var dist: float = e.pos.distance_to(LORD) - (e.radius + 0.3) if hit else 9.0
			var to: Vector2 = e.pos + d * dist
			steps.append({"act": &"wind", "time": 0.7, "info": {"from": e.pos, "dir": d, "length": 9.0, "time": 0.7}})
			steps.append({"act": &"charge", "time": dist / CHARGE_SPEED, "info": {"from": e.pos, "to": to}, "go": func() -> void: s["move"] = {"to": to, "speed": CHARGE_SPEED}})
			steps.append({"act": &"charge_end", "time": 1.0, "info": {"at": to, "hit": hit, "time": 1.0}, "go": func() -> void: s["move"] = {}})
			steps.append({"act": &"", "time": 0.2, "info": {}, "go": func() -> void: s["move"] = {"to": s["home"], "speed": 2.0, "walk": true}})
			_last = "돌격병: 돌진 — " + ("영주에게 맞음" if hit else "옆으로 빗나감")
		&"bomber":
			e.face = to_lord
			steps.append({"act": &"fuse", "time": 0.9, "info": {"at": e.pos, "radius": 2.2, "time": 0.9}})
			steps.append({"act": &"explode", "time": 0.2, "info": {"at": e.pos, "radius": 2.2}, "go": func() -> void: s["hidden"] = true})
			steps.append({"act": &"", "time": 1.8, "info": {}})
			steps.append({"act": &"", "time": 0.4, "info": {}, "go": func() -> void: s["hidden"] = false; s["pop"] = 0.0})
			_last = "자폭병: 심지와 폭발"
		&"caller":
			e.face = to_lord
			var spots: Array[Vector2] = []
			for k in 3:
				var a: float = to_lord.angle() + PI / 3.0 + TAU * k / 3.0
				spots.append(e.pos + Vector2(cos(a), sin(a)) * 1.6)
			steps.append({"act": &"call_wind", "time": 1.0, "info": {"at": e.pos, "radius": 1.6, "time": 1.0}})
			steps.append({"act": &"call", "time": 0.6, "info": {"at": e.pos, "count": 3, "spots": spots}})
			_last = "부르는 자: 불러내기와 부르기"
	s["variant"] = v + 1
	s["queue"] = steps
	_next(s)


## 이 적이 아직 차례를 도는 중인지.
func busy(i: int) -> bool:
	var s: Dictionary = slots[i]
	return not (s["queue"] as Array).is_empty() or s["act"] != &"" or not (s["move"] as Dictionary).is_empty() or float(s["act_time"]) > float(s["act_t"])


func _next(s: Dictionary) -> void:
	var q: Array = s["queue"]
	if q.is_empty():
		s["act"] = &""
		s["act_t"] = 0.0
		s["act_time"] = 0.0
		return
	var st: Dictionary = q.pop_front()
	s["act"] = st["act"]
	s["act_t"] = 0.0
	s["act_time"] = float(st["time"])
	if st.has("go"):
		(st["go"] as Callable).call()
	if st["act"] != &"":
		fx.on_act(s["e"], st["act"], st["info"])


func _shoot(e: Enemy, d: Vector2, mode: String) -> void:
	var p := Projectile.new()
	p.kind = &"arrow"
	p.pos = e.pos + d * 0.35
	p.prev_pos = p.pos
	p.dir = d
	_ids += 1
	p.id = _ids
	fx.on_projectile_spawned(p)
	_arrows.append({"p": p, "mode": mode, "gone": 0.0})


# ---------------------------------------------------------------- 매 화면

func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	var n: int = 0
	while _acc >= TICK and n < 8:
		_acc -= TICK
		n += 1
		_tick()
	_alpha = clampf(_acc / TICK, 0.0, 1.0)
	for s in slots:
		s["act_t"] = float(s["act_t"]) + delta
		s["guard_down"] = maxf(0.0, float(s["guard_down"]) - delta)
		if float(s["act_time"]) > 0.0 and float(s["act_t"]) >= float(s["act_time"]):
			_next(s)
		_place(s)
		_animate(s, delta)
	fx.draw(_alpha)
	_camera(delta)
	label.text = "1 활잡이  2 방패병  3 돌격병  4 자폭병  5 부르는 자  0 모두  N 낮/밤  C 카메라  오른쪽 끌기 돌리기  휠 거리\n%s   %s" % ["밤" if night else "낮", _last]


func _tick() -> void:
	for s in slots:
		var e: Enemy = s["e"]
		e.prev_pos = e.pos
		var mv: Dictionary = s["move"]
		s["speed"] = 0.0
		if mv.is_empty():
			continue
		var to: Vector2 = mv["to"]
		var step: float = float(mv["speed"]) * TICK
		var go: Vector2 = to - e.pos
		if bool(mv.get("walk", false)):
			e.face = e.face.slerp(go.normalized(), 0.2) if go.length() > 0.05 else e.face
		if go.length() <= step:
			e.pos = to
			s["move"] = {}
			if bool(mv.get("walk", false)):
				e.face = (LORD - e.pos).normalized()
		else:
			e.pos += go.normalized() * step
			s["speed"] = Grid.cells_to_meters(float(mv["speed"]))
	for i in range(_arrows.size() - 1, -1, -1):
		var a: Dictionary = _arrows[i]
		var p: Projectile = a["p"]
		p.prev_pos = p.pos
		p.pos += p.dir * ARROW_SPEED * TICK
		a["gone"] = float(a["gone"]) + ARROW_SPEED * TICK
		var to_lord: float = p.pos.distance_to(LORD)
		var mode: String = a["mode"]
		if mode == "hit" and to_lord < 0.4:
			fx.on_projectile_ended(p, true)
			_arrows.remove_at(i)
		elif mode == "cut" and to_lord < 1.2:
			fx.on_projectile_ended(p, false, true)
			_arrows.remove_at(i)
		elif float(a["gone"]) >= 12.0:
			fx.on_projectile_ended(p, false)
			_arrows.remove_at(i)


func _place(s: Dictionary) -> void:
	var e: Enemy = s["e"]
	var h: Node3D = s["holder"]
	h.position = _ground(e.prev_pos.lerp(e.pos, _alpha))
	h.rotation.y = lerp_angle(h.rotation.y, atan2(-e.face.x, -e.face.y), 0.35)
	h.visible = not bool(s["hidden"])
	var pop: float = s["pop"]
	if pop < 1.0:
		s["pop"] = minf(1.0, pop + get_process_delta_time() / 0.4)
		h.scale = Vector3.ONE * maxf(0.01, 1.0 - pow(1.0 - float(s["pop"]), 3.0))
	else:
		h.scale = Vector3.ONE


func _animate(s: Dictionary, delta: float) -> void:
	var e: Enemy = s["e"]
	var act: StringName = s["act"]
	var state: Dictionary = {
		"act": act, "act_t": s["act_t"], "act_time": s["act_time"], "speed": s["speed"], "side": 0.0,
		"backing": false, "t": _t, "id": e.id, "guard": float(s["guard_down"]) <= 0.0, "stunned": false,
		"recoil": 0.0, "attack": -1.0, "hit": -1.0,
	}
	EnemyMotion.animate(s["parts"], s["motion"], s["kind"], state, delta)


# ---------------------------------------------------------------- 입력, 카메라, 빛

func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo:
		match k.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				var i: int = k.keycode - KEY_1
				play(i)
				if _cam_mode >= 0:
					focus(i)
			KEY_0:
				for i in slots.size():
					play(i)
				_last = "다섯 모두"
			KEY_N:
				set_night(not night)
			KEY_C:
				focus(_cam_mode + 1 if _cam_mode + 1 < slots.size() else -1)
	var mb := event as InputEventMouseButton
	if mb:
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_drag = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(3.0, _dist * 0.9)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(80.0, _dist * 1.1)
	var mm := event as InputEventMouseMotion
	if mm and _drag:
		_yaw -= mm.relative.x * 0.006
		_pitch = clampf(_pitch + mm.relative.y * 0.005, 0.05, 1.45)


## 카메라: -1 = 다섯과 영주가 다 보이는 전체, 0~4 = 그 적의 일이 잘 보이게(활잡이·돌격병은 영주까지의 길을 옆에서).
func focus(i: int) -> void:
	_cam_mode = i
	if i < 0:
		view(0.0, 0.62, 30.0, _ground(Vector2(17.0, 10.5)) + Vector3(0.0, 1.0, 0.0))
		return
	var e: Enemy = slots[i]["e"]
	var home: Vector2 = slots[i]["home"]
	var to_lord: Vector2 = (LORD - home).normalized()
	# 영주 쪽을 옆에서 보는 방향(왼쪽 = 남서쪽 옆)
	var side: Vector2 = Vector2(to_lord.y, -to_lord.x) * -1.0
	match i:
		0:
			view(atan2(side.x, side.y), 0.36, 15.0, _ground(home.lerp(LORD, 0.5)) + Vector3(0.0, 0.8, 0.0))
		1:
			view(atan2(to_lord.x, to_lord.y) + 0.65, 0.28, 5.5, _ground(home + to_lord * 0.3) + Vector3(0.0, 1.1, 0.0))
		2:
			view(atan2(-side.x, -side.y) - 0.35, 0.5, 15.0, _ground(home.lerp(LORD, 0.45)) + Vector3(0.0, 0.6, 0.0))
		3:
			view(atan2(to_lord.x, to_lord.y) + 0.5, 0.5, 12.0, _ground(e.pos) + Vector3(0.0, 0.8, 0.0))
		_:
			view(atan2(to_lord.x, to_lord.y) + 0.4, 0.45, 9.0, _ground(e.pos) + Vector3(0.0, 1.0, 0.0))


## yaw(라디안, 0 = 남쪽에서 북쪽을 본다), pitch(라디안, 내려다보는 각), dist(m), at(보는 점).
func view(yaw: float, pitch: float, dist: float, at: Vector3) -> void:
	_yaw = yaw
	_pitch = pitch
	_dist = dist
	_at = at
	_camera(0.0)


func _camera(_delta: float) -> void:
	var off := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _dist
	cam.global_position = _at + off
	cam.look_at(_at, Vector3.UP)


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
	torch.light_energy = 2.6 if on else 0.0
	if HillBuilder.sky_material:
		HillBuilder.sky_material.set_shader_parameter("night", 1.0 if on else 0.0)


func _ground(c: Vector2) -> Vector3:
	var w: Vector3 = Grid.cells_to_world(c)
	w.y = HillBuilder.height(w.x, w.z)
	return w
