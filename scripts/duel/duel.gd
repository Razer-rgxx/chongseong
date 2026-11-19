extends Node3D
## 1대1 결투(21단계, docs/duel.md): 같은 PC에서 둘이 겨룬다. 규칙은 Rules(start_duel, step_duel)가 돌리고 여기는 입력을 모아 넘기고 그린다.
## 1P는 키보드와 마우스(마을과 같다), 2P는 게임패드 0번(왼 스틱 이동, 오른 스틱 겨눔, RT 좌클릭, LT 갈고리, A 구르기).
## 패드가 없으면 2P는 가만히 서 있는다. 카메라는 둘을 함께 담는 쿼터뷰 하나. 세계에는 글자를 띄우지 않는다(피해 숫자만 예외).
## 끝나면 Meta에 결투 기록을 적고 결과 창 → 마을.

const LORD_SCENE: PackedScene = preload("res://scenes/lord/lord.tscn")
const LOBBY_PATH: String = "res://scenes/lobby/lobby.tscn"

## 0이면 시작할 때 아무 시드나 고른다.
@export var seed_value: int = 0
@export var max_ticks_per_frame: int = 8
@export var hit_number_size: int = 40
@export var big_number_size: int = 58
@export_group("카메라")
## 둘 사이(m)에 margin을 더한 폭이 이 값이면 배율 1. 멀어지면 물러나고(배율 min까지) 가까우면 다가온다(max까지).
@export var fit_span: float = 34.0
@export var fit_margin: float = 10.0
@export var zoom_min: float = 0.6
@export var zoom_max: float = 1.1
@export var zoom_follow: float = 4.0
@export_group("2P 게임패드")
@export var pad_deadzone: float = 0.2
@export var pad_aim_min: float = 0.3
@export var pad_trigger: float = 0.5
@export_group("화면")
## 2P의 망토(기본 도형 몸)와 몸 색, 기사 모델이면 몸 전체에 곱하는 색.
@export var foe_cape: Color = Color(0.1, 0.22, 0.36)
@export var foe_body: Color = Color(0.4, 0.34, 0.36)
@export var foe_tint: Color = Color(0.55, 0.62, 0.8)
@export var result_delay: float = 1.8
@export var sun_energy: float = 0.9
@export var sun_color: Color = Color(1.0, 0.93, 0.84)
@export var ambient_color: Color = Color(0.62, 0.67, 0.78)

var data: GameData
var meta: Meta
var rules: Rules
## 1P 입력을 대신 줄 함수(Rules → LordInput). 비어 있으면 키보드와 마우스. 시험과 22단계(온라인)가 쓴다.
var p1_source: Callable = Callable()
var p2_source: Callable = Callable()
var _acc: float = 0.0
var _want_attack: bool = false
var _want_dash: bool = false
var _want_hook: bool = false
var _pad_dash: bool = false
var _lords: Array[Node3D] = []
var _fx := HitFx.new()
var _move_fx := MoveFx.new()
var _shown_phase: int = -1
var _left: bool = false
var _zoom: float = 1.0

@onready var _env: WorldEnvironment = $Environment
@onready var _sun: DirectionalLight3D = $Sun
@onready var _camera: Camera3D = $Camera
@onready var _sfx: Sfx = $Sfx
@onready var _hud: DuelHud = $UI


func _ready() -> void:
	data = GameData.load_default()
	meta = Meta.load_or_new()
	meta.fix_sheath(data)
	var s: int = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
	rules = Rules.new(data, s)
	var a: Sword = meta.unbreakable_sword(data, Meta.duel_picks[0])
	var b: Sword = meta.unbreakable_sword(data, Meta.duel_picks[1])
	rules.start_duel(a, b)
	HillBuilder.build(self, _env.environment, data.forms)
	_sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	_sun.light_energy = sun_energy
	_sun.light_color = sun_color
	_env.environment.ambient_light_color = ambient_color
	for i in 2:
		var v: Node3D = LORD_SCENE.instantiate()
		v.set(&"seat", i)
		v.call(&"setup", rules)
		add_child(v)
		v.call(&"set_sword", rules.seat_sword(i), data.grades)
		if i == 1:
			_tint_foe(v)
		_lords.append(v)
	add_child(_fx)
	add_child(_move_fx)
	_move_fx.setup(rules)
	rules.duelist_hurt.connect(_on_hurt)
	rules.lord_swung.connect(func(big: bool) -> void: _sfx.play(&"swish_big" if big else &"swish", _acting().position, -2.0 if big else -6.0))
	rules.lord_dashed.connect(func() -> void: _sfx.play(&"dash", _acting().position, -6.0))
	rules.lord_hooked.connect(func(_e: Enemy) -> void: _sfx.play(&"draw", _acting().position, -2.0, 1.25))
	rules.duel_round_started.connect(func(n: int) -> void: _hud.announce("%d번째 판" % n, data.duel.ready_time))
	rules.duel_round_ended.connect(_on_round_ended)
	rules.duel_over.connect(_on_over)
	_hud.back_to_village.connect(_leave)
	_camera.set(&"mode", 1)
	_camera.set(&"zoom", 1.0)
	_camera.set(&"target", Grid.cells_to_world((rules.lords[0].pos + rules.lords[1].pos) / 2.0))
	_camera.call(&"snap")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## 지금 틱을 돌리는 영주의 몸(신호를 받는 순간).
func _acting() -> Node3D:
	return _lords[rules.cur_seat]


## 2P는 몸 색을 바꿔 구별한다: 기본 도형이면 망토와 몸, 기사 모델이면 모든 면에 색을 곱한다.
func _tint_foe(v: Node3D) -> void:
	var cape := v.get_node_or_null("Model/Cape") as MeshInstance3D
	var body := v.get_node_or_null("Model/Body") as MeshInstance3D
	if cape != null or body != null:
		for pair in [[cape, foe_cape], [body, foe_body]]:
			var m := pair[0] as MeshInstance3D
			if m == null:
				continue
			var mat := StandardMaterial3D.new()
			mat.albedo_color = pair[1]
			m.set_surface_override_material(0, mat)
		return
	_multiply(v.get_node_or_null("Model"), foe_tint)


func _multiply(n: Node, c: Color) -> void:
	if n == null:
		return
	var mi := n as MeshInstance3D
	if mi != null and mi.mesh != null:
		for k in mi.mesh.get_surface_count():
			var src := mi.get_active_material(k) as StandardMaterial3D
			if src != null:
				var mat := src.duplicate() as StandardMaterial3D
				mat.albedo_color = src.albedo_color * c
				mi.set_surface_override_material(k, mat)
	for ch in n.get_children():
		_multiply(ch, c)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		_want_attack = true
	if event.is_action_pressed("dash"):
		_want_dash = true
	if event.is_action_pressed("hook"):
		_want_hook = true
	var jb := event as InputEventJoypadButton
	if jb != null and jb.pressed and jb.button_index == JOY_BUTTON_A and jb.device == _pad():
		_pad_dash = true
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_ESCAPE:
		_leave()   # 도중에 나가면 기록하지 않는다


func _physics_process(delta: float) -> void:
	_acc += delta
	var n: int = 0
	while _acc >= rules.dt and n < max_ticks_per_frame:
		rules.step_duel(_read_p1(), _read_p2())
		_want_attack = false
		_want_dash = false
		_want_hook = false
		_pad_dash = false
		_acc -= rules.dt
		n += 1
	if n == max_ticks_per_frame:
		_acc = 0.0


## 1P: 키보드(WASD, 방향키)와 마우스(겨눔은 마우스가 가리키는 땅).
func _read_p1() -> LordInput:
	if p1_source.is_valid():
		return p1_source.call(rules) as LordInput
	var inp := LordInput.new()
	inp.move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	inp.attack = Input.is_action_pressed("attack") or _want_attack
	inp.dash = _want_dash
	inp.hook = _want_hook
	var g: Variant = _camera.call(&"ground_point", get_viewport().get_mouse_position())
	if g != null:
		inp.aim_valid = true
		inp.aim = Grid.world_to_cells(g)
	return inp


## 2P: 게임패드 0번. 없으면 빈 입력(가만히 선다).
func _read_p2() -> LordInput:
	if p2_source.is_valid():
		return p2_source.call(rules) as LordInput
	var inp := LordInput.new()
	var dev: int = _pad()
	if dev < 0:
		return inp
	var mv := Vector2(Input.get_joy_axis(dev, JOY_AXIS_LEFT_X), Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y))
	inp.move = mv.limit_length(1.0) if mv.length() > pad_deadzone else Vector2.ZERO
	var look := Vector2(Input.get_joy_axis(dev, JOY_AXIS_RIGHT_X), Input.get_joy_axis(dev, JOY_AXIS_RIGHT_Y))
	var me: Vector2 = rules.lords[1].pos
	if look.length() > pad_aim_min:
		inp.aim_valid = true
		inp.aim = me + look.normalized() * 3.0
	elif inp.move.length() > pad_aim_min:
		inp.aim_valid = true
		inp.aim = me + inp.move.normalized() * 3.0
	inp.attack = Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT) > pad_trigger
	inp.hook = Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_LEFT) > pad_trigger
	inp.dash = _pad_dash
	return inp


func _pad() -> int:
	var pads: Array[int] = Input.get_connected_joypads()
	return 0 if pads.has(0) else -1


func _process(delta: float) -> void:
	var alpha: float = clampf(_acc / rules.dt, 0.0, 1.0)
	for v in _lords:
		v.call(&"draw", alpha, delta)
	_move_fx.draw(alpha)
	_follow_camera(delta)
	var left: float = rules.duel_left if rules.duel_phase == Rules.DUEL_FIGHT else data.duel.round_time
	_hud.set_state(rules.lords[0].hp, rules.lords[1].hp, rules.max_hp(), rules.duel_wins, left)
	if rules.duel_phase != _shown_phase:
		if rules.duel_phase == Rules.DUEL_FIGHT and _shown_phase == Rules.DUEL_READY:
			_hud.announce("시작", 1.0)
		_shown_phase = rules.duel_phase


## 둘 사이 가운데를 보고, 멀어지면 물러난다.
func _follow_camera(delta: float) -> void:
	var a: Vector3 = _lords[0].position
	var b: Vector3 = _lords[1].position
	var sep: float = a.distance_to(b)
	var want: float = clampf(fit_span / (sep + fit_margin), zoom_min, zoom_max)
	_zoom = lerpf(_zoom, want, minf(1.0, delta * zoom_follow))
	_camera.set(&"zoom", _zoom)
	_camera.set(&"target", (a + b) / 2.0)


func _on_hurt(seat: int, damage: float, big: bool) -> void:
	var v: Node3D = _lords[seat]
	var from: Node3D = _lords[1 - seat]
	var chest: Vector3 = v.position + Vector3(0, 1.1, 0)
	var dir: Vector3 = (v.position - from.position).normalized()
	_fx.blood(chest, dir, big)
	var t := FloatText.new()
	t.text = str(roundi(damage))
	t.font_size = big_number_size if big else hit_number_size
	t.modulate = Color(1, 0.86, 0.45) if big else Color.WHITE
	add_child(t)
	t.global_position = v.position + Vector3(0, 2.6, 0)
	_camera.call(&"add_shake", data.lord.shake_big if big else data.lord.shake)
	_sfx.play(&"hit_big" if big else &"hit", v.position, 0.0)
	_hud.flash(Color(1, 0.2, 0.25), 0.1, 0.2)


func _on_round_ended(winner: int) -> void:
	var text: String = "비겼다" if winner < 0 else "%dP가 판을 이겼다" % (winner + 1)
	_hud.announce(text, data.duel.break_time)
	_hud.flash(Color(1, 0.84, 0.42), 0.2, 0.6)
	_move_fx.clear()


func _on_over(winner: int) -> void:
	meta.record_duel(winner)
	meta.save()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(result_delay).timeout
	if _left:
		return
	_hud.show_result(winner, rules.duel_wins, Vector2i(meta.duel_wins, meta.duel_losses))


func _leave() -> void:
	_left = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(LOBBY_PATH)
