extends Node3D
## 14단계 뽑기 손맛 보기(모양팀). Godot에서 scenes/debug/pull_gallery.tscn을 열고 F6(지금 장면 실행)으로 띄운다.
## 규칙의 틱과 신호 없이 돈다: 언덕(HillBuilder)과 main.tscn의 환경을 깔고, 손잡이 넷(조짐 0~3)을 HiltView로 세워
## OmenArt를 입힌다. Rules는 HiltView가 읽는 자료(data, pull_hilt, pull_t, pull_steps)를 담는 그릇으로만 쓴다.
## 영주는 기사 모델(LordCharacter, 없으면 기본 도형)이고 PullMotion으로 버틴다. 고리는 PullTimingFx, 갈라짐은 PullFx.
## 키:
##   1~4 손잡이 고르기(조짐 0~3, 영주가 그 앞으로 간다)
##   E 잡기/놓기(버티기)   W 창 열기(고리가 0.6초 뒤 표시에 닿는다)   G 제대로 당김   P 모두 제대로   M 놓침(창만 열고 둔다)
##   Space 한 번 뽑기를 처음부터(창 셋 → 모두 제대로)   N 낮/저녁/밤   C 카메라(전체 → 고른 것)
##   마우스 오른쪽 끌기 = 돌리기, 휠 = 가깝게·멀게
## 찍는 도구가 부르는 것: select(i), begin_pull(), end_pull(), window(lead), good(), perfect(), miss(lead), auto(),
##   set_light(mode), focus(mode), view(yaw, pitch, dist, at), pair(i).

const MAIN: String = "res://scenes/world/main.tscn"
const LORD_SCENE: String = "res://scenes/lord/lord_model.tscn"
const XS: Array[float] = [12.5, 15.5, 18.5, 21.5]
const ROW_Y: float = 9.0
## 영주가 손잡이 남쪽에 서는 거리(칸).
const STAND: float = 0.95
const NAMES: Array[String] = ["0 녹슬고 무디다", "1 깨끗한 쇠빛", "2 밑동의 불씨 금", "3 낮은 울림·먼지·빛"]
const LIGHTS: Array[String] = ["낮", "저녁", "밤"]

@export var full_hill: bool = true

var data: GameData
var rules: Rules
var hilts: Array[Hilt] = []
var views: Array[HiltView] = []
var timing: PullTimingFx
var pull_fx: PullFx
var model: Node3D
var character: LordCharacter = null
var motion: Dictionary = PullMotion.rest()
var cam: Camera3D
var env: Environment
var sun: DirectionalLight3D
var torch: OmniLight3D
var label: Label
var sel: int = 0
var light_mode: int = 0
var pulling: bool = false
var clock: float = 0.0
var steps: int = 0
var _sched: Array[Dictionary] = []
var _t: float = 0.0
var _yaw_now: float = 0.0
var _cam_mode: int = -1
var _yaw: float = 0.0
var _pitch: float = 0.5
var _dist: float = 14.0
var _at := Vector3.ZERO
var _drag: bool = false
var _last: String = ""


func _ready() -> void:
	data = GameData.load_default()
	Grid.size = data.run.arena_size
	rules = Rules.new(data, 14)
	rules.pull_grade = 3
	var we := WorldEnvironment.new()
	env = _main_env()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
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
	for i in 4:
		var h := Hilt.new()
		h.id = i + 1
		h.pos = Vector2(XS[i], ROW_Y)
		h.tilt = [0.05, -0.08, 0.1, -0.04][i]
		hilts.append(h)
		var v := HiltView.new()
		v.setup(rules, h)
		add_child(v)
		OmenArt.apply(v, i)
		views.append(v)
	pull_fx = PullFx.new()
	pull_fx.env = env
	add_child(pull_fx)
	timing = PullTimingFx.new()
	add_child(timing)
	_make_lord()
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(16, 10)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.74))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	layer.add_child(label)
	set_light(0)
	select(0)
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


func _make_lord() -> void:
	var holder := Node3D.new()
	holder.name = "Lord"
	add_child(holder)
	if LordCharacter.available():
		model = Node3D.new()
		holder.add_child(model)
		character = LordCharacter.new()
		model.add_child(character)
	else:
		model = (load(LORD_SCENE) as PackedScene).instantiate()
		holder.add_child(model)
		var blade := model.get_node_or_null("Hand") as Node3D
		if blade:
			blade.visible = false   # 두 손으로 손잡이를 잡는다(쥔 칼은 숨긴다)
	torch = OmniLight3D.new()
	torch.position = Vector3(0.4, 2.2, 0.3)
	torch.light_color = Color(1.0, 0.72, 0.45)
	torch.omni_range = 9.0
	torch.shadow_enabled = true
	holder.add_child(torch)


# ---------------------------------------------------------------- 차례

## i번 손잡이(0~3)를 고른다. 영주가 그 남쪽에 서서 손잡이를 본다.
func select(i: int) -> void:
	end_pull()
	sel = clampi(i, 0, 3)
	var lord := get_node("Lord") as Node3D
	lord.position = Grid.cells_to_world(hilts[sel].pos + Vector2(0.0, STAND))
	_yaw_now = PullMotion.face_yaw(lord.position, _hilt_at())
	_last = "손잡이 " + NAMES[sel]
	if _cam_mode >= 0:
		focus(sel)


func begin_pull() -> void:
	if pulling:
		return
	pulling = true
	clock = 0.0
	steps = 0
	rules.pull_hilt = hilts[sel]
	rules.pull_t = 0.0
	rules.pull_steps = 0
	pull_fx.begin(_hilt_at(), hilts[sel].id)
	if character:
		character.play("pull")
	_last = "잡았다: 버틴다"


func end_pull() -> void:
	pulling = false
	rules.pull_hilt = null
	if timing:
		timing.clear()
	if character:
		character.play("idle")


## 창을 연다: lead초 뒤에 고리가 표시에 닿는다(±0.08초가 창).
func window(lead: float = 0.6) -> void:
	if not pulling:
		begin_pull()
	timing.on_window(_hilt_at(), clock + lead - 0.08, clock + lead + 0.08, clock)
	_last = "창: %.2f초 뒤" % lead


func good() -> void:
	if not pulling:
		begin_pull()
	steps += 1
	rules.pull_steps = steps
	timing.on_good(_hilt_at(), steps)
	PullMotion.good(motion, steps)
	pull_fx.step(steps)
	_last = "제대로 당김 %d" % steps


func perfect() -> void:
	timing.on_perfect(_hilt_at())
	PullMotion.perfect(motion)
	_last = "모두 제대로"


## 창만 열고 아무것도 하지 않는다(고리가 지나가 식는다).
func miss(lead: float = 0.5) -> void:
	window(lead)
	_last = "놓침(창을 그냥 보낸다)"


## 한 번 뽑기: 창 셋을 모두 제대로 당기고 마지막에 모두 제대로.
func auto() -> void:
	_sched.clear()
	select(sel)
	begin_pull()
	var t: float = 0.25
	for i in 3:
		_at_time(t, window.bind(0.5))
		_at_time(t + 0.5, good)
		t += 0.8
	_at_time(t - 0.8 + 0.53, perfect)
	_at_time(t - 0.8 + 0.62, end_pull)
	_last = "한 번 뽑기"


func _at_time(after: float, f: Callable) -> void:
	_sched.append({"t": _t + after, "f": f})


func _hilt_at() -> Vector3:
	return Grid.cells_to_world(hilts[sel].pos)


func _process(delta: float) -> void:
	_t += delta
	for i in range(_sched.size() - 1, -1, -1):
		if _t >= float(_sched[i].t):
			var f: Callable = _sched[i].f
			_sched.remove_at(i)
			f.call()
	if pulling:
		clock += delta
		rules.pull_t = minf(clock, rules.pull_duration() * 0.9)
	timing.sync(clock)
	var add: Dictionary = PullMotion.pose(motion, {"pulling": pulling, "steps": steps}, delta, character)
	var pose: Dictionary = PullMotion.add(MoveMotion.pose({}, 0.0, 0.0), add)
	MoveMotion.apply(model, pose, _yaw_now, 0.0)
	_camera()
	label.text = "1~4 손잡이  E 잡기/놓기  W 창  G 제대로  P 모두 제대로  M 놓침  Space 한 번 뽑기  N 낮/저녁/밤  C 카메라\n%s · %s · %s" % [LIGHTS[light_mode], NAMES[sel], _last]


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo:
		match k.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4:
				select(k.keycode - KEY_1)
			KEY_E:
				if pulling:
					end_pull()
					_last = "놓았다"
				else:
					begin_pull()
			KEY_W:
				window(0.6)
			KEY_G:
				good()
			KEY_P:
				perfect()
			KEY_M:
				miss(0.5)
			KEY_SPACE:
				auto()
			KEY_N:
				set_light((light_mode + 1) % 3)
			KEY_C:
				focus(-1 if _cam_mode >= 0 else sel)
	var mb := event as InputEventMouseButton
	if mb:
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_drag = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(1.5, _dist * 0.9)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(60.0, _dist * 1.1)
	var mm := event as InputEventMouseMotion
	if mm and _drag:
		_yaw -= mm.relative.x * 0.006
		_pitch = clampf(_pitch + mm.relative.y * 0.004, 0.05, 1.45)


# ---------------------------------------------------------------- 카메라와 빛

## -1 = 손잡이 넷 전체, 0~3 = 그 손잡이와 영주(영주 뒤 비스듬히, 게임의 3인칭처럼).
func focus(i: int) -> void:
	_cam_mode = i
	if i < 0:
		var mid: Vector3 = Grid.cells_to_world(Vector2((XS[0] + XS[3]) * 0.5, ROW_Y + 0.3))
		view(0.0, 0.32, 11.0, mid + Vector3(0, 0.4, 0))
		return
	var h: Vector3 = Grid.cells_to_world(hilts[i].pos)
	view(0.55, 0.42, 4.6, h + Vector3(0, 0.45, 0.9))


## 두 손잡이(i, i+1)를 가까이.
func pair(i: int) -> void:
	_cam_mode = -2
	var a: Vector3 = Grid.cells_to_world(hilts[i].pos)
	var b: Vector3 = Grid.cells_to_world(hilts[i + 1].pos)
	view(0.0, 0.3, 5.2, (a + b) * 0.5 + Vector3(0, 0.45, 0))


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


## 0 낮(main._set_light의 낮), 1 저녁(해가 낮고 붉다, 마을의 하늘빛), 2 밤(main의 밤, 영주가 횃불을 든다).
## 뽑기는 낮에만 하지만, 저녁빛에서 조짐이 너무 세거나 묻히지 않는지 본다.
func set_light(mode: int) -> void:
	light_mode = mode
	var night: bool = mode == 2
	match mode:
		0:
			sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
			sun.light_energy = 0.75
			sun.light_color = Color(1.0, 0.93, 0.84)
			env.fog_light_color = Color(0.44, 0.46, 0.48)
		1:
			sun.rotation_degrees = Vector3(-13.0, -120.0, 0.0)
			sun.light_energy = 0.6
			sun.light_color = Color(1.0, 0.62, 0.38)
			env.fog_light_color = Color(0.36, 0.27, 0.22)
		_:
			sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
			sun.light_energy = 1.1
			sun.light_color = Color(0.55, 0.65, 1.0)
			env.fog_light_color = Color(0.05, 0.06, 0.09)
	env.ambient_light_color = Color(0.3, 0.36, 0.52)
	env.ambient_light_sky_contribution = 0.15 if night else (0.7 if mode == 1 else 1.0)
	env.ambient_light_energy = 1.2 if night else (0.75 if mode == 1 else 1.0)
	env.background_color = Color(0.01, 0.015, 0.03) if night else Color(0.06, 0.08, 0.12)
	torch.light_energy = 2.6 if night else 0.0
	if HillBuilder.sky_material:
		HillBuilder.sky_material.set_shader_parameter("night", 1.0 if night else (0.35 if mode == 1 else 0.0))
		HillBuilder.sky_material.set_shader_parameter("tint", Color(1.0, 0.72, 0.55) if mode == 1 else Color.WHITE)
	_last = LIGHTS[mode]
