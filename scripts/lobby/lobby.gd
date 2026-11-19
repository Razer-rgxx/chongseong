extends Node3D
## 언덕 아래 마을(시작 장면). 걸어 다니며 들른다.
## 대장간: 모루 위에 검집의 검이 놓여 있고, 망치질로 검집을 강화한다. 성소: 축복. 검 진열대: 도감. 언덕 길: 판을 시작한다.
## 영주의 움직임은 언덕과 같은 Rules로 돌린다(검도 적도 없는 낮). 모양은 기본 도형이고, 모델이 들어오면 _build_*만 바꾼다.
## 세계에 글자를 띄우지 않는다(간판 없음). 무엇인지는 다가가면 아래 띠가 알려 준다.
## 집, 나무, 목책, 소품은 VillageBuilder가 짓는다. 마을 안의 건물과 소품은 _blockers로 막아 영주가 뚫고 지나가지 않게 한다
## (마을은 판이 아니라 꾸밈이라 규칙 밖, 화면 쪽에서 밀어낸다).

const LORD_SCENE: PackedScene = preload("res://scenes/lord/lord.tscn")
const FIELD_PATH: String = "res://scenes/field/field.tscn"
const DUEL_PATH: String = "res://scenes/duel/duel.tscn"

## 들를 곳(칸 좌표). 마을 크기는 언덕 싸움터와 같다(RunData.arena_size).
@export var forge_at: Vector2 = Vector2(9.5, 8.0)
@export var shrine_at: Vector2 = Vector2(24.5, 8.0)
@export var rack_at: Vector2 = Vector2(9.0, 15.0)
@export var gate_at: Vector2 = Vector2(17.0, 2.5)
@export var reach: float = 2.0
## 15단계(docs/village.md): 의뢰판, 수련장(울타리 칸 rect, 서쪽 틈의 y 범위, 허수아비, 검 걸이), 상인의 수레와 상인.
@export var board_at: Vector2 = Vector2(21.5, 5.2)
@export var yard_area: Rect2 = Rect2(24.0, 14.5, 5.0, 3.5)
@export var yard_gap: Vector2 = Vector2(15.5, 17.0)
@export var yard_dummies: Array[Vector2] = [Vector2(28.0, 15.3), Vector2(28.0, 16.3), Vector2(28.0, 17.3)]
@export var yard_rack_at: Vector2 = Vector2(25.4, 14.9)
@export var cart_at: Vector2 = Vector2(13.4, 9.7)
## 결투 말뚝(21단계, docs/duel.md): 광장. E로 창을 열어 같은 PC로 겨루기 → 1P·2P 검 고르기 → 결투 장면.
@export var duel_at: Vector2 = Vector2(19.4, 10.6)
@export var merchant_at: Vector2 = Vector2(14.7, 10.4)
## 주민: id → [칸 자리, 바라볼 방향].
const VILLAGERS: Dictionary = {
	&"gatekeeper": [Vector2(19.4, 3.7), Vector2(-1, 1)],
	&"elder": [Vector2(19.6, 13.6), Vector2(1, 0.3)],
	&"drunk": [Vector2(21.0, 15.0), Vector2(0, -1)],
	&"herbalist": [Vector2(6.6, 13.5), Vector2(1, 0)],
	&"apprentice": [Vector2(11.9, 9.7), Vector2(-1, 0.4)],
}

## 34단계: 들판에서 영입한 떠도는 사람(FieldLayout.WANDERERS)이 서는 자리: id → [칸 자리, 바라볼 방향]. 들를 곳·주민의 E 거리 밖, 막힘 밖.
const RECRUITS: Dictionary = {
	&"gatherer": [Vector2(9.0, 18.0), Vector2(1, -0.6)],
	&"smith": [Vector2(12.8, 6.8), Vector2(-1, 0.35)],
	&"hunter": [Vector2(11.0, 4.0), Vector2(0.8, 1)],
	&"pilgrim": [Vector2(27.2, 10.6), Vector2(-1, -0.9)],
	&"knight": [Vector2(26.5, 13.0), Vector2(-1, -0.2)],
}

## 들를 곳 앞에 섰을 때 아래 띠에 뜨는 말.
const PROMPTS: Dictionary = {"forge": "대장간에 들른다", "shrine": "성소에서 기도한다", "rack": "검 진열대를 본다", "gate": "들판으로 나간다", "board": "의뢰판을 본다", "yard_rack": "검 걸이에서 검을 고른다", "merchant": "떠돌이 상인과 거래한다", "duel": "결투 말뚝을 본다"}
@export var max_ticks_per_frame: int = 8

## 온라인 찾기(22단계). 결투 장면으로 넘어가면 비운다.
var _online: OnlineDuel = null
var data: GameData
var meta: Meta
var rules: Rules
var _acc: float = 0.0
var _want_dash: bool = false
var _want_jump: bool = false
var _lord: Node3D
var _anvil_sword := Node3D.new()
var _forge_light := OmniLight3D.new()
var _near: String = ""
## 영주가 들어갈 수 없는 곳(칸 단위). Rect2와 [가운데, 반지름] 원.
var _rects: Array[Rect2] = []
var _circles: Array = []
## 낮은 막힘(30단계, 그린 높이 1m 이하: 수련장 울타리, 통, 궤짝, 장작더미). 공중이면 지나간다(Blockers).
var _low_rects: Array[Rect2] = []
var _low_circles: Array = []
var _deco := RandomNumberGenerator.new()
var _move_fx := MoveFx.new()
var _dummies: Array[Node3D] = []
var _dummy_enemies: Array[Enemy] = []
var _wobble: Array[float] = [0.0, 0.0, 0.0]
var _wobble_dir: Array[Vector3] = [Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT]
## 수련장 피해 기록: [시각(초), 피해].
var _yard_hits: Array = []
var _clock: float = 0.0
var _vt: float = 0.0
## 주민 id → {P, root}. 상인은 &"merchant".
var _folk: Dictionary = {}
var _talker: StringName = &""
var _talk_lines: Array[String] = []
var _talk_i: int = 0
## 영입한 사람이 마을에서 한 말의 차례(id → 다음 줄 번호, 이번에 마을에 있는 동안만).
var _recruit_said: Dictionary = {}

@onready var _camera: Camera3D = $Camera
@onready var _sfx: Sfx = $Sfx
@onready var _hud: LobbyHud = $UI
@onready var _sun: DirectionalLight3D = $Sun


func _ready() -> void:
	data = GameData.load_default()
	meta = Meta.load_or_new()
	meta.fix_sheath(data)
	meta.save()
	rules = Rules.new(data, 1)
	rules.hilts.clear()
	rules.yard = true
	meta.fill_board(data)
	meta.fill_stock(data)
	meta.save()
	rules.lord.pos = Vector2(17.0, 13.0)
	rules.lord.prev_pos = rules.lord.pos
	_hud.setup(data, meta)
	_deco.seed = 7
	# 언덕과 같은 하늘 사진을 저녁빛으로
	HillBuilder.apply_sky(($Environment as WorldEnvironment).environment, Color(1.0, 0.8, 0.68), 0.75)
	_build_ground()
	_build_forge()
	_build_shrine()
	_build_rack()
	_build_gate()
	_build_houses()
	_build_village_extras()
	_lord = LORD_SCENE.instantiate()
	_lord.setup(rules)
	add_child(_lord)
	_lord.set_sword(meta.sheath_sword(data), data.grades)
	_lord.torch.light_energy = 1.2
	_hud.forge_hit.connect(_on_hammer)
	_hud.forge_done.connect(_on_forged)
	_hud.closed.connect(func() -> void: _capture(true))
	_hud.quest_taken.connect(func(_i: int) -> void: _sfx.play(&"thump", Grid.cells_to_world(board_at, 1.0), -4.0))
	_hud.bought.connect(func(_id: StringName) -> void: _sfx.play(&"thump", Grid.cells_to_world(merchant_at, 1.0), -6.0))
	_hud.yard_sword_picked.connect(_on_yard_sword)
	_hud.field_go.connect(_on_field_go)
	_hud.duel_go.connect(_on_duel_go)
	_hud.duel_online.connect(_on_duel_online)
	_hud.duel_online_cancel.connect(_cancel_online)
	add_child(_move_fx)
	_move_fx.setup(rules)
	rules.enemy_hit.connect(_on_dummy_hit)
	rules.lord_swung.connect(func(big: bool) -> void: _sfx.play(&"swish_big" if big else &"swish", _lord.position, -4.0))
	rules.lord_landed.connect(func(_at: Vector2) -> void: _sfx.play(&"land", _lord.position, -4.0))
	_apply_yard_sword()
	_camera.target = Grid.cells_to_world(rules.lord.pos)
	_camera.yaw = 0.0
	_camera.snap()
	_sun.rotation_degrees = Vector3(-35.0, -60.0, 0.0)
	_refresh_anvil()
	_hud.area_title("언덕 아래 마을")
	if Meta.wake_at_gate:   # 들판에서 쓰러졌다: 잃은 것 없이 북문 앞에서 깬다
		Meta.wake_at_gate = false
		rules.lord.pos = gate_at + FieldLayout.WAKE_OFFSET
		rules.lord.prev_pos = rules.lord.pos
		_camera.target = Grid.cells_to_world(rules.lord.pos)
		_camera.snap()
		_hud.toast(Meta.wake_note if Meta.wake_note != "" else "들판에서 쓰러졌다. 북문 앞에서 깨어났다.")
		Meta.wake_note = ""
	_capture(true)
	WebQuality.apply(self, ($Environment as WorldEnvironment).environment, _sun, _camera)   # 웹판에서만 가볍게


func _capture(on: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on and _camera.third() and not _hud.is_open() else Input.MOUSE_MODE_VISIBLE


## 27단계: F10으로 설정 창(게임을 멈춘다).
func _open_settings() -> void:
	if _hud.get_node_or_null("Settings"):
		return
	var p := SettingsPanel.new()
	p.name = "Settings"
	_hud.add_child(p)
	p.open()


func _unhandled_input(event: InputEvent) -> void:
	var kf := event as InputEventKey
	if kf and kf.pressed and not kf.echo and kf.physical_keycode == KEY_F10:
		_open_settings()
		return
	var mm := event as InputEventMouseMotion
	if mm and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_camera.look(mm.relative)
	var k := event as InputEventKey
	if _hud.is_open():
		if k and k.pressed and k.physical_keycode == KEY_ESCAPE:
			_hud.close()
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and _camera.third() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_capture(true)
	if event.is_action_pressed("dash"):
		_want_dash = true
	if event.is_action_pressed("jump"):
		_want_jump = true
	if event.is_action_pressed("pull"):
		_interact()
	if k and k.pressed and not k.echo:
		if k.physical_keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif k.physical_keycode == KEY_V:
			_camera.toggle_mode()
			_capture(true)


func _physics_process(delta: float) -> void:
	if _hud.is_open():
		return
	_acc += delta
	var n: int = 0
	while _acc >= rules.dt and n < max_ticks_per_frame:
		var inp := LordInput.new()
		inp.move = _camera.relative_move(Input.get_vector("move_left", "move_right", "move_up", "move_down"))
		inp.dash = _want_dash
		inp.jump = _want_jump and _talker == &""
		inp.attack = _talker == &"" and Input.is_action_pressed("attack") and _in_yard()
		if _camera.third() and inp.attack:
			inp.aim_valid = true
			inp.aim = rules.lord.pos + _camera.forward_cells() * 3.0
		elif not _camera.third() and inp.attack:
			var g: Variant = _camera.ground_point(get_viewport().get_mouse_position())
			if g != null:
				inp.aim_valid = true
				inp.aim = Grid.world_to_cells(g)
		elif _camera.third() and inp.move.length() > 0.1:
			inp.aim_valid = true
			inp.aim = rules.lord.pos + inp.move
		rules.step(inp)
		rules.lord.pos = _push_out(rules.lord.pos, rules.lord.airborne())
		_want_dash = false
		_want_jump = false
		_acc -= rules.dt
		n += 1
		_clock += rules.dt
	if n == max_ticks_per_frame:
		_acc = 0.0


func _process(delta: float) -> void:
	var alpha: float = clampf(_acc / rules.dt, 0.0, 1.0)
	_lord.draw(alpha, delta)
	_camera.target = _lord.position
	var p: Vector2 = rules.lord.pos
	_near = ""
	var spots := {"forge": forge_at + Vector2(0, 2.2), "shrine": shrine_at + Vector2(0, 1.8), "rack": rack_at + Vector2(1.6, 0), "gate": gate_at + Vector2(0, 1.0),
		"board": board_at + Vector2(0, 1.3), "yard_rack": yard_rack_at + Vector2(0, 0.9), "merchant": merchant_at, "duel": duel_at + Vector2(0, 1.4)}
	for id in VILLAGERS:
		spots["v_" + id] = VILLAGERS[id][0]
	for id in RECRUITS:
		if meta.has_recruit(String(id)):
			spots["v_" + id] = RECRUITS[id][0]
	var best_d: float = reach
	for key in spots:
		var d: float = p.distance_to(spots[key])
		if d < best_d:
			best_d = d
			_near = key
	if _talker != &"" and (p.distance_to(_talker_cell()) > reach * 1.8):
		_end_talk()
	if _talker != &"":
		_hud.set_prompt("", "")
	elif _near.begins_with("v_"):
		_hud.set_prompt("E", "%s에게 말을 건다" % _folk_name(StringName(_near.substr(2))))
	else:
		_hud.set_prompt("E", PROMPTS.get(_near, ""))
	_move_fx.draw(alpha)
	_animate_village(delta)
	_forge_light.light_energy = lerpf(_forge_light.light_energy, 1.6, delta * 3.0)


func _interact() -> void:
	if _talker != &"":
		_talk_i += 1
		if _talk_i >= _talk_lines.size():
			_end_talk()
		else:
			_hud.say(_talk_name(), _talk_lines[_talk_i], _talk_i == _talk_lines.size() - 1)
		return
	if _near.begins_with("v_"):
		_start_talk(StringName(_near.substr(2)))
		return
	match _near:
		"board":
			_hud.open_board()
		"yard_rack":
			_hud.open_yard_rack()
		"merchant":
			_hud.open_shop()
		"forge":
			_hud.open_forge()
		"shrine":
			_hud.open_shrine()
		"rack":
			_hud.open_rack()
		"gate":
			_hud.open_field_pick()
		"duel":
			_hud.open_duel()
		_:
			return
	_capture(false)


func _on_hammer(step: int) -> void:
	_sfx.play(&"anvil", Grid.cells_to_world(forge_at, 1.0), -6.0 + 2.0 * step)
	_camera.add_shake(0.08 + 0.04 * step)
	_forge_light.light_energy = 6.0
	_hud.flash(Color(1, 0.7, 0.35), 0.08 + 0.03 * step, 0.2)


func _on_forged(r: Dictionary, big: bool) -> void:
	if r.ok:
		_sfx.play(&"anvil", Grid.cells_to_world(forge_at, 1.0), 4.0)
		_hud.flash(Color(1, 0.84, 0.42), 0.7 if big else 0.35, 1.4 if big else 0.6)
		_camera.add_shake(0.5 if big else 0.25)
	else:
		_sfx.play(&"break" if r.get("dropped", false) else &"thump", Grid.cells_to_world(forge_at, 1.0), -2.0)
		_hud.flash(Color(0.45, 0.48, 0.55), 0.25, 0.4)
	_refresh_anvil()
	_lord.set_sword(meta.sheath_sword(data), data.grades)


## 모루 위에 놓인 검: 검집의 검이 바뀌거나 강화되면 다시 만든다.
func _refresh_anvil() -> void:
	for c in _anvil_sword.get_children():
		c.queue_free()
	var s := meta.sheath_sword(data)
	if s == null:
		return
	var m := SwordModel.for_sword(s, data.grades)
	m.rotation = Vector3(PI / 2.0, 0, -PI / 2.0)
	m.position = Vector3(-0.2, 0.02, 0)
	_anvil_sword.add_child(m)


# ---------------------------------------------------------------- 마을 짓기

func _build_ground() -> void:
	var size := Vector2(Grid.size) * Grid.CELL
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(320.0, 320.0)
	ground.mesh = plane
	ground.material_override = VillageBuilder.grass()
	ground.position = Vector3(size.x / 2.0, 0.0, size.y / 2.0)
	add_child(ground)
	var dirt := VillageBuilder.dirt()
	# 남쪽에서 들어와 광장을 지나 북쪽 문으로, 문 너머 언덕까지 이어지는 흙길
	VillageBuilder.box(self, Vector3(5.0, 0.04, size.y + 40.0), Vector3(Grid.cells_to_world(Vector2(17, 0)).x, 0.02, size.y / 2.0 + 20.0), dirt)
	VillageBuilder.box(self, Vector3(4.0, 0.04, 70.0), Vector3(Grid.cells_to_world(Vector2(17, 0)).x, 0.02, -34.0), dirt)
	VillageBuilder.cyl(self, 11.0, 11.0, 0.05, Grid.cells_to_world(Vector2(17, 12), 0.025), dirt, 40)
	# 집 앞과 대장간 앞의 맨땅
	for c in [Vector2(9.5, 10), Vector2(24.5, 10), Vector2(6.5, 9.5), Vector2(31, 13), Vector2(12, 17.8), Vector2(22.5, 17.8), Vector2(10, 15)]:
		VillageBuilder.cyl(self, 2.6, 2.8, 0.05, Grid.cells_to_world(c, 0.02), dirt, 18)
	# 목책: 북쪽은 문 기둥에 이어지고, 남쪽은 길이 나가는 곳만 비운다
	var lines := [
		[Vector2(0.3, 2.5), Vector2(15.8, 2.5)], [Vector2(18.2, 2.5), Vector2(33.7, 2.5)],
		[Vector2(33.7, 2.5), Vector2(33.7, 21.7)], [Vector2(0.3, 2.5), Vector2(0.3, 21.7)],
		[Vector2(0.3, 21.7), Vector2(15.2, 21.7)], [Vector2(18.8, 21.7), Vector2(33.7, 21.7)],
	]
	for l in lines:
		VillageBuilder.palisade(self, Grid.cells_to_world(l[0]), Grid.cells_to_world(l[1]), _deco)
		_rects.append(Rect2(l[0], Vector2.ZERO).expand(l[1]).grow(0.35))
	_build_trees()


## 마을 안 몇 그루, 목책 밖은 숲. 북쪽 길과 남쪽 길은 언덕과 들판이 보이게 비운다.
func _build_trees() -> void:
	for c in [Vector2(1.8, 12.5), Vector2(32.3, 9.0), Vector2(32.4, 16.8), Vector2(26.8, 4.0), Vector2(13.3, 4.4), Vector2(1.8, 20.4), Vector2(32.4, 20.6)]:
		VillageBuilder.tree(self, Grid.cells_to_world(c), _deco, _deco.randf() < 0.5)
		_circles.append([c, 0.5])
	var size := Vector2(Grid.size) * Grid.CELL
	var mid_x: float = size.x / 2.0
	var placed: int = 0
	while placed < 170:
		var p := Vector3(_deco.randf_range(-45.0, size.x + 45.0), 0.0, _deco.randf_range(-40.0, size.y + 45.0))
		var inside: bool = p.x > -2.5 and p.x < size.x + 2.5 and p.z > -2.5 and p.z < size.y + 2.5
		var north_view: bool = p.z < 0.0 and absf(p.x - mid_x) < 16.0 + (-p.z) * 0.35
		var south_road: bool = p.z > size.y and absf(p.x - mid_x) < 6.0
		if inside or north_view or south_road:
			continue
		if _deco.randf() < 0.08:
			VillageBuilder.dead_tree(self, p, _deco)
		else:
			VillageBuilder.tree(self, p, _deco, _deco.randf() < 0.7)
		placed += 1
	for i in 30:
		var side: int = _deco.randi() % 4
		var t: float = _deco.randf_range(1.5, 32.5)
		var c: Vector2 = [Vector2(t, 3.2), Vector2(t, 21.0), Vector2(1.0, 3.0 + t * 0.55), Vector2(33.0, 3.0 + t * 0.55)][side]
		if absf(c.x - 17.0) < 3.0:
			continue
		if _deco.randf() < 0.7:
			VillageBuilder.bush(self, Grid.cells_to_world(c), _deco)
		else:
			VillageBuilder.rock(self, Grid.cells_to_world(c), _deco, 0.8)


func _build_forge() -> void:
	var at := Grid.cells_to_world(forge_at)
	# 뒤의 대장장이 집과, 앞으로 내민 차양(모루와 화덕을 덮는다)
	var top := VillageBuilder.house(self, at + Vector3(0, 0, -1.6), 0.0, Vector2(7.0, 4.4), true, _deco)
	VillageBuilder.smoke(self, top, 1.6)
	var lean := VillageBuilder.box(self, Vector3(7.6, 0.16, 3.6), at + Vector3(0, 2.35, 2.2), VillageBuilder.roof())
	lean.rotation.x = 0.32
	for x in [-3.4, 3.4]:
		VillageBuilder.box(self, Vector3(0.2, 1.9, 0.2), at + Vector3(x, 0.95, 3.7), VillageBuilder.timber())
	VillageBuilder.box(self, Vector3(7.0, 0.2, 0.2), at + Vector3(0, 1.85, 3.7), VillageBuilder.timber())
	# 화덕 옆 물통, 장작, 숫돌, 벽에 기댄 칼들
	VillageBuilder.barrel(self, at + Vector3(-3.2, 0, 2.2), _deco)
	VillageBuilder.firewood(self, at + Vector3(3.0, 0, 1.3), PI / 2.0)
	VillageBuilder.cyl(self, 0.4, 0.4, 0.15, at + Vector3(2.0, 0.75, 2.8), VillageBuilder.stone(), 14).rotation.x = PI / 2.0
	VillageBuilder.box(self, Vector3(0.2, 0.7, 0.4), at + Vector3(2.0, 0.35, 2.8), VillageBuilder.timber())
	for i in 3:
		VillageBuilder.box(self, Vector3(0.06, 1.3, 0.12), at + Vector3(-0.8 + i * 0.35, 0.65, 0.75), _mat(Color(0.6, 0.62, 0.66), 0.8, 0.35), Vector3(0.18, 0, 0))
	_rects.append(Rect2(forge_at + Vector2(-1.85, -1.95), Vector2(3.7, 2.3)))
	_circles.append([forge_at + Vector2(0.3, 1.3), 0.55])
	_circles.append([forge_at + Vector2(-1.1, 0.8), 0.6])
	_low_circles.append([forge_at + Vector2(-1.6, 1.1), 0.35])   # 물통(1m)
	var furnace := _box(Vector3(1.6, 1.4, 1.2), VillageMaterials.get_mat("stone_wall", Color(0.2, 0.18, 0.17), 1.5, Color(0.6, 0.55, 0.5)))
	furnace.position = at + Vector3(-2.2, 0.7, 1.6)
	add_child(furnace)
	var fire := _box(Vector3(0.9, 0.5, 0.1), _mat(Color(1.0, 0.45, 0.15), 0.0, 1.0, true))
	fire.position = at + Vector3(-2.2, 0.6, 2.21)
	add_child(fire)
	_forge_light.light_color = Color(1.0, 0.55, 0.25)
	_forge_light.omni_range = 9.0
	_forge_light.light_energy = 1.6
	_forge_light.shadow_enabled = true
	_forge_light.position = at + Vector3(-1.4, 1.6, 2.6)
	add_child(_forge_light)
	# 모루: 받침, 몸통, 뿔. 그 위에 검집의 검이 눕는다
	var iron := _mat(Color(0.18, 0.19, 0.21), 0.7, 0.45)
	var stump := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = 0.45
	sc.bottom_radius = 0.5
	sc.height = 0.6
	stump.mesh = sc
	stump.material_override = _mat(Color(0.3, 0.22, 0.15))
	stump.position = at + Vector3(0.6, 0.3, 2.6)
	add_child(stump)
	var body := _box(Vector3(1.1, 0.35, 0.45), iron)
	body.position = at + Vector3(0.6, 0.78, 2.6)
	add_child(body)
	var horn := MeshInstance3D.new()
	var hc := CylinderMesh.new()
	hc.top_radius = 0.0
	hc.bottom_radius = 0.18
	hc.height = 0.55
	horn.mesh = hc
	horn.material_override = iron
	horn.rotation.z = PI / 2.0
	horn.position = at + Vector3(1.42, 0.86, 2.6)
	add_child(horn)
	_anvil_sword.position = at + Vector3(0.55, 0.98, 2.6)
	_anvil_sword.rotation.y = 0.25
	add_child(_anvil_sword)


func _build_shrine() -> void:
	var at := Grid.cells_to_world(shrine_at)
	var stone := VillageMaterials.get_mat("medieval_blocks_03", Color(0.5, 0.52, 0.56), 2.0)
	var base := _box(Vector3(4.0, 0.4, 4.0), stone)
	base.position = at + Vector3(0, 0.2, 0)
	add_child(base)
	for p in [Vector3(-1.5, 0, -1.5), Vector3(1.5, 0, -1.5), Vector3(-1.5, 0, 1.5), Vector3(1.5, 0, 1.5)]:
		var pillar := _box(Vector3(0.4, 3.2, 0.4), stone)
		pillar.position = at + p + Vector3(0, 2.0, 0)
		add_child(pillar)
	var top := _box(Vector3(4.2, 0.4, 4.2), stone)
	top.position = at + Vector3(0, 3.8, 0)
	add_child(top)
	var orb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.45
	sm.height = 0.9
	orb.mesh = sm
	orb.material_override = _mat(Color(0.55, 0.8, 1.0), 0.0, 0.3, true)
	orb.position = at + Vector3(0, 1.6, 0)
	add_child(orb)
	# 계단과 촛불
	VillageBuilder.box(self, Vector3(4.8, 0.2, 4.8), at + Vector3(0, 0.05, 0), stone)
	for p in [Vector3(-1.2, 0.5, 1.4), Vector3(1.2, 0.5, 1.4), Vector3(-1.3, 0.5, -1.3), Vector3(1.3, 0.5, -1.2)]:
		VillageBuilder.cyl(self, 0.05, 0.06, 0.25, at + p, VillageBuilder.plain(Color(0.85, 0.8, 0.7)), 8)
		VillageBuilder.ball(self, 0.04, at + p + Vector3(0, 0.17, 0), VillageBuilder.glow(Color(1.0, 0.7, 0.35), 4.0), Vector3(1, 1.6, 1))
	_rects.append(Rect2(shrine_at - Vector2(1.1, 1.1), Vector2(2.2, 2.2)))
	var light := OmniLight3D.new()
	light.light_color = Color(0.55, 0.8, 1.0)
	light.omni_range = 7.0
	light.light_energy = 1.4
	light.position = at + Vector3(0, 1.8, 0)
	add_child(light)


func _build_rack() -> void:
	var at := Grid.cells_to_world(rack_at)
	var wood := VillageMaterials.get_mat("raw_plank_wall", Color(0.36, 0.26, 0.17), 1.0, Color(0.75, 0.66, 0.58))
	var frame := _box(Vector3(0.5, 0.3, 5.0), wood)
	frame.position = at + Vector3(0, 0.15, 0)
	add_child(frame)
	var bar := _box(Vector3(0.2, 0.15, 5.0), wood)
	bar.position = at + Vector3(0, 1.4, 0)
	add_child(bar)
	# 진열대 위 작은 지붕
	for z in [-2.4, 2.4]:
		VillageBuilder.box(self, Vector3(0.14, 2.6, 0.14), at + Vector3(-0.4, 1.3, z), VillageBuilder.timber())
	VillageBuilder.box(self, Vector3(1.8, 0.12, 5.6), at + Vector3(0.1, 2.6, 0), VillageBuilder.roof(), Vector3(0, 0, -0.35))
	_rects.append(Rect2(rack_at - Vector2(0.4, 1.3), Vector2(0.7, 2.6)))
	# 도감에서 찾은 등급마다 한 자루씩 세워 둔다(등급 색). 오픈월드 한정 검(33단계)을 찾았으면 끝에 한 자루 더
	var show: Array[SwordData] = []
	for g in data.grades.names.size():
		for i in data.swords_by_grade[g]:
			if meta.has_found(data.swords[i].id):
				show.append(data.swords[i])
				break
	for i in data.field_swords:
		if meta.has_found(data.swords[i].id):
			show.append(data.swords[i])
			break
	var gap: float = minf(0.8, 4.0 / maxf(1.0, float(show.size() - 1)))
	for k in show.size():
		var sd: SwordData = show[k]
		var m := SwordModel.make(data.forms[sd.form], sd.grade, sd.id, data.grades.colors[sd.grade])
		m.position = at + Vector3(0, 0.5, -2.0 + k * gap)
		m.rotation.x = 0.12
		add_child(m)


func _build_gate() -> void:
	var at := Grid.cells_to_world(gate_at)
	var stone := VillageMaterials.get_mat("stone_wall", Color(0.42, 0.42, 0.44), 2.5)
	for x in [-2.4, 2.4]:
		var p := _box(Vector3(0.8, 5.0, 0.8), stone)
		p.position = at + Vector3(x, 2.5, 0)
		add_child(p)
	var beam := _box(Vector3(5.8, 0.8, 1.0), stone)
	beam.position = at + Vector3(0, 5.2, 0)
	add_child(beam)
	for x in [-2.4, 2.4]:
		VillageBuilder.torch(self, at + Vector3(x, 2.8, 0.55))
		_circles.append([gate_at + Vector2(x / Grid.CELL, 0), 0.45])
	# 문 너머의 언덕: 꼭대기에 검이 잔뜩 꽂힌 큰 둔덕
	var hill := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 40.0
	sm.height = 36.0
	hill.mesh = sm
	hill.material_override = _mat(Color(0.2, 0.24, 0.17), 0.0, 1.0)
	hill.position = at + Vector3(0, -6.0, -70.0)
	add_child(hill)
	var steel := _mat(Color(0.7, 0.72, 0.76), 0.8, 0.3)
	var deco := RandomNumberGenerator.new()
	deco.seed = 11
	for i in 60:
		var a: float = deco.randf_range(-0.9, 0.9)
		var r: float = deco.randf_range(0.0, 16.0)
		var p := at + Vector3(sin(a) * r * 2.0, 0, -70.0 + cos(a) * r)
		p.y = -6.0 + sqrt(maxf(0.0, 40.0 * 40.0 - pow(p.x - at.x, 2) - pow(p.z - at.z + 70.0, 2))) * 0.45
		var s := _box(Vector3(0.15, 2.0, 0.3), steel)
		s.position = p + Vector3(0, 0.8, 0)
		s.rotation.z = deco.randf_range(-0.3, 0.3)
		add_child(s)


## 집(가운데 칸, 너비 × 깊이 m, 앞이 보는 쪽, 2층인지), 광장의 우물과 장터, 등불, 소품.
func _build_houses() -> void:
	var houses := [
		[Vector2(4.0, 9.5), Vector2(6, 5), Vector2(1, 0), true],
		[Vector2(3.8, 15.8), Vector2(6, 5), Vector2(1, 0), false],
		[Vector2(3.8, 4.8), Vector2(6, 4.6), Vector2(1, 0), false],
		[Vector2(5.0, 19.6), Vector2(7, 5), Vector2(0, -1), true],
		[Vector2(12.0, 19.6), Vector2(6, 5), Vector2(0, -1), false],
		[Vector2(22.5, 19.6), Vector2(6, 5), Vector2(0, -1), true],
		[Vector2(29.0, 19.4), Vector2(7, 5), Vector2(0, -1), false],
		[Vector2(30.5, 13.0), Vector2(6, 5), Vector2(-1, 0), true],
		[Vector2(30.3, 5.6), Vector2(6, 5), Vector2(-1, 0), true],
	]
	for h in houses:
		var c: Vector2 = h[0]
		var sz: Vector2 = h[1]
		var dir: Vector2 = h[2]
		var top := VillageBuilder.house(self, Grid.cells_to_world(c), VillageBuilder.facing_to(dir), sz, h[3], _deco)
		if _deco.randf() < 0.7:
			VillageBuilder.smoke(self, top, 1.0)
		var half := (Vector2(sz.x, sz.y) if dir.y != 0.0 else Vector2(sz.y, sz.x)) / Grid.CELL / 2.0
		_rects.append(Rect2(c - half - Vector2(0.15, 0.15), half * 2.0 + Vector2(0.3, 0.3)))
	# 광장: 우물, 의자, 장터 좌판 둘
	var well_at := Vector2(21.0, 13.6)
	VillageBuilder.well(self, Grid.cells_to_world(well_at))
	_circles.append([well_at, 0.75])
	VillageBuilder.bench(self, Grid.cells_to_world(Vector2(21.0, 15.4)), 0.0)
	VillageBuilder.bench(self, Grid.cells_to_world(Vector2(22.8, 13.6)), -PI / 2.0)
	VillageBuilder.stall(self, Grid.cells_to_world(Vector2(13.0, 14.0)), PI / 2.0, Color(0.24, 0.1, 0.08), _deco)
	_rects.append(Rect2(Vector2(12.4, 13.2), Vector2(1.0, 1.6)))
	VillageBuilder.stall(self, Grid.cells_to_world(Vector2(21.4, 9.6)), -PI / 2.0, Color(0.16, 0.19, 0.24), _deco)
	_rects.append(Rect2(Vector2(20.9, 8.8), Vector2(1.0, 1.6)))
	# 등불(빛은 몇 개만: 빛이 많으면 느려진다)
	var lamps := [[Vector2(15.0, 5.5), true], [Vector2(19.0, 5.5), false], [Vector2(11.5, 11.5), true], [Vector2(22.6, 11.0), false], [Vector2(15.0, 18.0), true], [Vector2(19.0, 18.0), false]]
	for l in lamps:
		var c: Vector2 = l[0]
		VillageBuilder.lantern(self, Grid.cells_to_world(c), VillageBuilder.facing_to(Vector2(17, 12) - c), l[1])
		_circles.append([c, 0.25])
	# 집 둘레의 통, 상자, 건초, 장작
	# 통(1m)·궤짝(0.95m 안)·장작더미(0.8m)는 낮은 막힘이라 점프로 넘는다(30단계). 건초(1.2m)는 높다.
	for p in [Vector2(7.6, 11.6), Vector2(7.9, 12.2), Vector2(26.9, 21.0), Vector2(32.6, 11.0), Vector2(14.8, 20.6), Vector2(7.3, 17.3)]:
		VillageBuilder.barrel(self, Grid.cells_to_world(p), _deco)
		_low_circles.append([p, 0.3])
	for p in [Vector2(8.3, 11.9), Vector2(25.6, 20.7), Vector2(15.0, 21.0), Vector2(33.0, 7.8)]:
		VillageBuilder.crate(self, Grid.cells_to_world(p), _deco, _deco.randf_range(0.7, 0.95))
		_low_circles.append([p, 0.4])
	for p in [Vector2(33.0, 18.0)]:
		VillageBuilder.hay(self, Grid.cells_to_world(p), _deco)
		_circles.append([p, 0.45])
	VillageBuilder.firewood(self, Grid.cells_to_world(Vector2(6.4, 7.0)), PI / 2.0)
	_low_circles.append([Vector2(6.4, 7.0), 0.5])


# ---------------------------------------------------------------- 15단계: 의뢰판 · 수련장 · 상인 · 주민

func _build_village_extras() -> void:
	VillageProps.board(self, Grid.cells_to_world(board_at), 0.0, _deco)
	_rects.append(Rect2(board_at + Vector2(-0.75, -0.2), Vector2(1.5, 0.45)))
	_dummies = VillageProps.yard(self, yard_area, yard_gap, yard_dummies, yard_rack_at, _deco)
	for d in yard_dummies:
		_circles.append([d, 0.35])
		_dummy_enemies.append(rules.spawn_dummy(d))
	var a := yard_area
	# 수련장 울타리(1m)는 낮은 막힘(30단계)
	_low_rects.append(Rect2(a.position.x, a.position.y - 0.1, a.size.x, 0.2))
	_low_rects.append(Rect2(a.position.x, a.end.y - 0.1, a.size.x, 0.2))
	_low_rects.append(Rect2(a.end.x - 0.1, a.position.y, 0.2, a.size.y))
	_low_rects.append(Rect2(a.position.x - 0.1, a.position.y, 0.2, yard_gap.x - a.position.y))
	_low_rects.append(Rect2(a.position.x - 0.1, yard_gap.y, 0.2, a.end.y - yard_gap.y))
	_rects.append(Rect2(yard_rack_at - Vector2(0.9, 0.2), Vector2(1.8, 0.4)))
	VillageProps.duel_post(self, Grid.cells_to_world(duel_at))
	_circles.append([duel_at, 0.4])
	VillageProps.cart(self, Grid.cells_to_world(cart_at), VillageBuilder.facing_to(Vector2(1, 0)))
	_rects.append(Rect2(cart_at - Vector2(0.6, 0.7), Vector2(1.2, 2.0)))
	_add_folk(&"merchant", merchant_at, Vector2(1, 0))
	for id in VILLAGERS:
		_add_folk(id, VILLAGERS[id][0], VILLAGERS[id][1])
	for id in RECRUITS:   # 34단계: 들판에서 데려온 사람
		if meta.has_recruit(String(id)):
			_add_folk(id, RECRUITS[id][0], RECRUITS[id][1])


func _add_folk(id: StringName, cell: Vector2, dir: Vector2) -> void:
	var holder := VillageBuilder.place(self, Grid.cells_to_world(cell), VillageBuilder.facing_to(dir) + PI)
	_folk[id] = {"P": VillageProps.villager(id, holder), "root": holder}
	_circles.append([cell, 0.4])


func _animate_village(delta: float) -> void:
	_vt += delta
	var eye: Vector3 = _lord.position + Vector3(0, 1.5, 0)
	for id in _folk:
		var f: Dictionary = _folk[id]
		var root: Node3D = f.root
		EventArt.breathe(f.P, _vt)
		var close: bool = root.position.distance_to(_lord.position) < 8.0
		VillageProps.look_at(f.P, root, eye, 1.0 if close else 0.0)
		if id == _talker:
			VillageProps.talk(f.P, _vt)
	for i in _dummies.size():
		_wobble[i] = maxf(0.0, _wobble[i] - delta * 1.6)
		VillageProps.dummy_wobble(_dummies[i], _wobble_dir[i], _wobble[i])
	# 수련장 위 줄: 최근 N초 피해 합(마지막으로 때린 뒤 몇 초 지나면 사라진다)
	var win: float = data.village.yard_window
	var sum: float = 0.0
	var last: float = -999.0
	for h in _yard_hits:
		last = maxf(last, h[0])
		if _clock - h[0] <= win:
			sum += h[1]
	_hud.set_readout("%d초 피해 %d" % [roundi(win), roundi(sum)] if _clock - last < win + 3.0 else "")


func _in_yard() -> bool:
	return yard_area.grow(-0.2).has_point(rules.lord.pos)


## 수련장에서 쥘 검: 고른 검이 없으면 검집의 검. 부러지지 않는다.
func _apply_yard_sword() -> void:
	if meta.yard_sword < 0:
		meta.yard_sword = meta.sheath_id
	var s: Sword = meta.yard_sword_made(data)
	rules.slots[0] = s
	rules.active = 0
	rules.lord.combo = 0
	_lord.set_sword(s, data.grades)
	_move_fx.tint = MoveArt.STEEL if s == null else (Color(0.9, 0.92, 1.0) if s.grade == 0 else (data.grades.colors[s.grade] as Color).lightened(0.25))
	if s != null and rules.moves != null:
		rules.moves.clear()


## 북문에서 검을 골랐다: 들판으로 나선다(고른 검은 Meta.carry_sword로 넘어간다).
func _on_field_go(id: int) -> void:
	Meta.carry_sword = id
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(FIELD_PATH)


## 결투 말뚝에서 1P·2P의 검을 골랐다: 결투 장면으로(고른 검은 Meta.duel_picks로 넘어간다).
func _on_duel_go(a: int, b: int) -> void:
	Meta.duel_picks = [a, b]
	meta.save()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(DUEL_PATH)


## 모르는 사람과 겨루기(22단계): 검을 골랐다. 접속하고 방을 찾아 둘이 모이면 결투 장면으로 간다.
func _on_duel_online(id: int) -> void:
	_cancel_online()
	_online = OnlineDuel.new(data, meta)
	_online.status_text.connect(_hud.set_online_text)
	_online.failed.connect(_on_online_failed)
	_online.ready.connect(_on_online_ready)
	_online.start(id)


func _on_online_failed(text: String) -> void:
	if _online != null:
		_online.cancel()
		_online = null
	_hud.show_online_failed(text)


func _on_online_ready() -> void:
	_online = null   # 결투 장면이 OnlineDuel.current로 이어받는다
	meta.save()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(DUEL_PATH)


func _cancel_online() -> void:
	if _online != null:
		_online.cancel()
		_online = null


func _exit_tree() -> void:
	_cancel_online()


func _on_yard_sword(id: int) -> void:
	meta.yard_sword = id
	_apply_yard_sword()


func _on_dummy_hit(e: Enemy, damage: float, big: bool) -> void:
	var i: int = _dummy_enemies.find(e)
	if i < 0:
		return
	var at: Vector3 = Grid.cells_to_world(e.pos)
	var d: Vector3 = at - _lord.position
	d.y = 0.0
	_wobble_dir[i] = d.normalized() if d.length() > 0.01 else Vector3.RIGHT
	_wobble[i] = 1.0
	_yard_hits.append([_clock, damage])
	if _yard_hits.size() > 400:
		_yard_hits = _yard_hits.slice(200)
	var t := FloatText.new()
	t.text = str(roundi(damage))
	t.font_size = 52 if big else 34
	t.modulate = Color(1, 0.86, 0.45) if big else Color.WHITE
	add_child(t)
	t.global_position = at + Vector3(0, 2.2, 0)
	_sfx.play(&"hit_big" if big else &"hit", at + Vector3(0, 1.0, 0), -4.0)


func _start_talk(id: StringName) -> void:
	var lines: Array[String] = meta.talk(data, id) if not RECRUITS.has(id) else _recruit_line(id)
	if lines.is_empty():
		return
	meta.save()
	_talker = id
	_talk_lines = lines
	_talk_i = 0
	_hud.say(_talk_name(), lines[0], lines.size() == 1)


func _end_talk() -> void:
	if _talker != &"" and _folk.has(_talker):
		var P: Dictionary = _folk[_talker].P
		for f: Node3D in P.get("forearms", []):
			if P.rest.has(f):
				f.transform = P.rest[f]
	_talker = &""
	_hud.say_end()


func _talk_name() -> String:
	return _folk_name(_talker)


## 주민의 이름(마을 주민은 VillageData, 데려온 사람은 FieldLayout.WANDERERS).
func _folk_name(id: StringName) -> String:
	if RECRUITS.has(id):
		return String(FieldLayout.WANDERERS[String(id)].name)
	var v := data.village.villager(id)
	return v.display_name if v else ""


## 데려온 사람의 한 줄(마을 말을 돌아가며).
func _recruit_line(id: StringName) -> Array[String]:
	var lines: Array = FieldLayout.WANDERERS[String(id)].village
	var i: int = int(_recruit_said.get(id, 0))
	_recruit_said[id] = (i + 1) % lines.size()
	var out: Array[String] = [String(lines[i])]
	return out


func _talker_cell() -> Vector2:
	return RECRUITS[_talker][0] if RECRUITS.has(_talker) else VILLAGERS[_talker][0]


## 영주를 막힌 곳 밖으로 민다(Blockers, 가장 가까운 가장자리로). 공중이면 낮은 막힘은 지나간다.
func _push_out(p: Vector2, airborne: bool = false) -> Vector2:
	return Blockers.push_out(p, _rects, _circles, _low_rects, _low_circles, airborne)


static func _box(size: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	return mi


static func _mat(c: Color, metal: float = 0.0, rough: float = 0.8, glow: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	if glow:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 1.2
	return m
