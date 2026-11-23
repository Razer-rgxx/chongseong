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
## 검 보관집(2026-11-21): 북동쪽 빈 터(집 가운데). 지으면 집이 올라가고 그 집 문 앞에서 검집을 산다.
@export var storage_at: Vector2 = Vector2(24.2, 4.25)
## 바깥 터(2026-11-21 마을 키우기 2단계): 동쪽 목책 너머로 마을을 넓힌다(칸 34~50). 목책 사이 문과 동서로 난 흙길.
const VILLAGE_W: int = 50
const OUTER_GATE: Vector2 = Vector2(33.7, 11.2)
const OUTER_GATE_HALF: float = 1.0
## 마을 단계(마을 키우기 4단계): 단계마다 켜지는 등불 자리(앞에서부터 MetaData.tier_lights만큼)와 걷는 사람의 길(왕복).
const TIER_LIGHTS: Array[Vector2] = [Vector2(35.8, 9.5), Vector2(35.8, 12.9), Vector2(41.8, 9.5), Vector2(41.8, 12.9), Vector2(14.2, 9.8), Vector2(20.0, 9.6)]
const WALK_PATHS: Array = [
	[Vector2(17.5, 13.8), Vector2(23.5, 11.6), Vector2(26.5, 10.2), Vector2(31.8, 10.2), Vector2(33.0, 11.2), Vector2(46.0, 11.2)],
	[Vector2(16.2, 15.2), Vector2(16.3, 21.4)],
	[Vector2(17.0, 10.6), Vector2(17.0, 4.0)],
]
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
const PROMPTS: Dictionary = {"storage": "검 보관집에 들른다", "storage_site": "검 보관집 터를 본다", "forge": "대장간에 들른다", "shrine": "성소에서 기도한다", "rack": "검 진열대를 본다", "gate": "들판으로 나간다", "board": "의뢰판을 본다", "yard_rack": "검 걸이에서 검을 고른다", "merchant": "떠돌이 상인과 거래한다", "duel": "결투 말뚝을 본다"}
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
## 검 보관집(2026-11-21)과 그 막힘이 _rects에서 몇 번째인지(지으면 바꾼다).
var _storage: StorageHouse = null
var _storage_rect: int = -1

@onready var _camera: Camera3D = $Camera
@onready var _sfx: Sfx = $Sfx
@onready var _hud: LobbyHud = $UI
@onready var _sun: DirectionalLight3D = $Sun


func _ready() -> void:
	data = GameData.load_default()
	meta = Meta.load_or_new()
	ObjectHead.lord_info = Heads.info(meta.head) if meta.head != "" else {}   # 쓴 머리
	meta.fix_sheath(data)
	meta.save()
	FallenShare.sync(get_tree(), meta)   # 다른 영주의 쓰러진 검을 주고받는다(키가 없거나 실패하면 조용히, 기다리지 않는다)
	rules = Rules.new(data, 1)
	rules.hilts.clear()
	rules.yard = true
	meta.fill_board(data)
	meta.fill_stock(data)
	meta.save()
	Grid.size = Vector2i(VILLAGE_W, Grid.size.y)   # 바깥 터까지 걸을 수 있게(언덕 판은 Rules.new가 되돌린다)
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
	_build_storage()
	_build_buildings()
	_build_residents()
	_build_tier()
	_lord = LORD_SCENE.instantiate()
	_lord.setup(rules)
	add_child(_lord)
	_lord.set_sword(meta.sheath_sword(data), data.grades)
	_lord.torch.light_energy = 1.2
	_hud.forge_hit.connect(_on_hammer)
	_hud.forge_done.connect(_on_forged)
	_hud.closed.connect(func() -> void:
		if _room != null:
			_leave_inside()
		else:
			_capture(true))
	_hud.quest_taken.connect(func(_i: int) -> void: _sfx.play(&"thump", Grid.cells_to_world(board_at, 1.0), -4.0))
	_hud.bought.connect(func(_id: StringName) -> void: _sfx.play(&"thump", Grid.cells_to_world(merchant_at, 1.0), -6.0))
	_hud.yard_sword_picked.connect(_on_yard_sword)
	_hud.field_go.connect(_on_field_go)
	_hud.duel_go.connect(_on_duel_go)
	_hud.duel_online.connect(_on_duel_online)
	_hud.duel_online_cancel.connect(_cancel_online)
	_hud.storage_built.connect(_on_storage_built)
	_hud.building_built.connect(_on_building_built)
	_hud.job_set.connect(func(_i: int) -> void: _build_residents())
	_hud.sheath_bought.connect(_on_sheath_bought)
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
	_hud.area_title("언덕 아래 " + data.meta.tier_names[_tier])
	_check_tier()
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
		"board": board_at + Vector2(0, 1.3), "yard_rack": yard_rack_at + Vector2(0, 0.9), "merchant": merchant_at, "duel": duel_at + Vector2(0, 1.4),
		("storage" if meta.storage_house else "storage_site"): storage_at + Vector2(-0.3, 1.75)}
	for b in data.buildings:
		spots["bld_" + String(b.id)] = b.plot + b.facing * (b.size.y / Grid.CELL / 2.0 + 0.9)
	for i in _res.size():
		spots["r_%d" % i] = Grid.world_to_cells((_res[i].root as Node3D).position) + Vector2(0.0, 0.01)
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
		_hud.set_prompt("E", _prompt_for(_near))
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
			var smith: bool = meta.has_recruit("smith")
			_enter(&"forge", "떠돌이 대장장이" if smith else "대장간 견습", &"smith" if smith else &"apprentice",
				["모루는 식지 않았소. 검집을 두드려 볼 텐가.", "칼은 부러져도 검집은 남지. 무엇을 손볼까."] if smith else ["스승님은 언덕에서 돌아오지 않으셨어요. 망치질은 제가 할게요.", "검집 말씀이세요? 불은 지펴 두었어요."], _hud.open_forge)
		"shrine":
			var pilgrim: bool = meta.has_recruit("pilgrim")
			_enter(&"shrine", "길 잃은 순례자" if pilgrim else "성소지기", &"pilgrim" if pilgrim else &"elder",
				["불은 꺼지지 않았소. 무엇을 빌러 왔소?", "언덕의 칼들도 여기선 조용하오."], _hud.open_shrine)
		"rack":
			_hud.open_rack()
		"gate":
			_hud.open_field_pick()
		"duel":
			_hud.open_duel()
		"storage":
			_enter(&"storage", "보관집 지기", &"peasant2", ["걸이마다 기름을 먹여 두었소.", "검집은 칼보다 오래 가오. 하나 더 걸어 두겠소?"], _hud.open_storage)
		"storage_site":
			_hud.open_storage()
		_ when _near.begins_with("r_"):
			_hud.open_jobs(int(_near.substr(2)))
		_ when _near.begins_with("bld_"):
			var b: BuildingData = data.building(StringName(_near.substr(4)))
			var open := func() -> void: _hud.open_building(b)
			if b and meta.has_built(b.id) and b.kind in [&"cottage", &"longhouse"]:
				var who: Dictionary = _resident_home(b)
				_enter(&"house", who.get("name", ""), who.get("look", &""), ["들판에서 꺼내 준 은혜는 잊지 않소.", "불을 지펴 두었소. 쉬었다 가시오."] if not who.is_empty() else [], open)
			elif b and meta.has_built(b.id) and b.kind == &"forge":
				_enter(&"smithy", "풀무장이", &"smith", ["쇠가 녹는 소리가 좋지. 언덕에 오를 때 한 자루 쥐여 보내겠소."], open)
			else:
				open.call()
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
	# 목책: 북쪽은 문 기둥에 이어지고, 남쪽은 길이 나가는 곳만 비운다. 동쪽 목책은 바깥 터로 가는 문만 비우고,
	# 바깥 터(마을 키우기 2단계)를 새 목책이 둘러싼다
	var g: Vector2 = OUTER_GATE
	var lines := [
		[Vector2(0.3, 2.5), Vector2(15.8, 2.5)], [Vector2(18.2, 2.5), Vector2(33.7, 2.5)],
		[Vector2(33.7, 2.5), Vector2(33.7, g.y - OUTER_GATE_HALF)], [Vector2(33.7, g.y + OUTER_GATE_HALF), Vector2(33.7, 21.7)],
		[Vector2(0.3, 2.5), Vector2(0.3, 21.7)],
		[Vector2(0.3, 21.7), Vector2(15.2, 21.7)], [Vector2(18.8, 21.7), Vector2(33.7, 21.7)],
		[Vector2(33.7, 2.5), Vector2(VILLAGE_W - 0.3, 2.5)], [Vector2(VILLAGE_W - 0.3, 2.5), Vector2(VILLAGE_W - 0.3, 21.7)],
		[Vector2(33.7, 21.7), Vector2(VILLAGE_W - 0.3, 21.7)],
	]
	# 바깥 터의 흙길(문에서 동쪽으로)과 문 양옆 횃불
	VillageBuilder.box(self, Vector3((VILLAGE_W - 34.0) * Grid.CELL + 6.0, 0.04, 3.2), Grid.cells_to_world(Vector2((33.7 + VILLAGE_W) / 2.0 - 1.5, g.y), 0.02), dirt)
	for sy in [-1.0, 1.0]:
		VillageBuilder.torch(self, Grid.cells_to_world(g + Vector2(0.0, sy * (OUTER_GATE_HALF + 0.25))))
	_fence = Node3D.new()   # 목책(돌담을 지으면 감춘다)
	add_child(_fence)
	_fence_lines = lines
	for l in lines:
		VillageBuilder.palisade(_fence, Grid.cells_to_world(l[0]), Grid.cells_to_world(l[1]), _deco)
		_rects.append(Rect2(l[0], Vector2.ZERO).expand(l[1]).grow(0.35))
	_build_trees()


## 마을 안 몇 그루, 목책 밖은 숲. 북쪽 길과 남쪽 길은 언덕과 들판이 보이게 비운다.
func _build_trees() -> void:
	for c in [Vector2(1.8, 12.5), Vector2(32.3, 9.0), Vector2(32.4, 16.8), Vector2(26.8, 4.0), Vector2(13.3, 4.4), Vector2(1.8, 20.4), Vector2(32.4, 20.6)]:
		VillageBuilder.tree(self, Grid.cells_to_world(c), _deco, _deco.randf() < 0.5)
		_circles.append([c, 0.5])
	var size := Vector2(Grid.size) * Grid.CELL
	var mid_x: float = Grid.cells_to_world(Vector2(17, 0)).x   # 북쪽 길(마을 가운데 칸 17)
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
		if absf(c.x - 17.0) < 3.0 or Rect2(storage_at - Vector2(1.8, 1.6), Vector2(3.6, 3.2)).has_point(c):
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
	for p in [Vector2(7.6, 11.6), Vector2(7.9, 12.2), Vector2(26.9, 21.0), Vector2(32.7, 14.2), Vector2(14.8, 20.6), Vector2(7.3, 17.3)]:
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


## 검 보관집(2026-11-21): 지었으면 집, 아니면 말뚝을 친 빈 터. 막힘은 _rects 한 칸(지으면 바꾼다)과 검집 걸이.
func _build_storage() -> void:
	_storage = StorageHouse.new()
	add_child(_storage)
	_storage.position = Grid.cells_to_world(storage_at)
	_storage.build_with(meta.storage_house, meta.storage_lv)
	_storage_rect = _rects.size()
	_rects.append(_storage.rect(storage_at))
	if meta.storage_house:
		_rects.append(_rack_rect())
	_storage.piece_placed.connect(func(at: Vector3) -> void: _sfx.play(&"thump", at, -8.0))
	_storage.raised.connect(func() -> void:
		_sfx.play(&"anvil", Grid.cells_to_world(storage_at, 1.0), -8.0)
		_hud.toast("검 보관집이 섰다. 문 앞에서 검집을 산다."))


## 바깥 터의 마을 건물(마을 키우기 2단계): 지었으면 집, 아니면 그 건물에 쓸 더미를 쌓은 빈 터.
var _plots: Dictionary = {}
var _plot_rect: Dictionary = {}


func _build_buildings() -> void:
	for b in data.buildings:
		var p := BuildingPlot.new()
		p.setup(b)
		if b.kind == &"wall":
			p.wall_lines = _fence_lines
		add_child(p)
		p.position = Grid.cells_to_world(b.plot)
		p.rotation.y = VillageBuilder.facing_to(b.facing)
		p.build(meta.has_built(b.id))
		if b.kind == &"wall" and meta.has_built(b.id):
			_fence.visible = false
		p.piece_placed.connect(func(at: Vector3) -> void: _sfx.play(&"thump", at, -8.0))
		var nm: String = b.display_name
		p.raised.connect(func() -> void:
			_sfx.play(&"anvil", p.global_position + Vector3(0, 1, 0), -8.0)
			_hud.toast("%s이(가) 섰다." % nm)
			_check_tier())
		_plots[b.id] = p
		_plot_rect[b.id] = _rects.size()
		_rects.append(p.rect(b.plot))


func _prompt_for(key: String) -> String:
	if key.begins_with("r_"):
		var i: int = int(key.substr(2))
		return "%s에게 일을 맡긴다" % meta.residents[i].name if i < meta.residents.size() else ""
	if key.begins_with("bld_"):
		var b: BuildingData = data.building(StringName(key.substr(4)))
		if b == null:
			return ""
		return ("%s에 들른다" if meta.has_built(b.id) else "%s 터를 본다") % b.display_name
	return PROMPTS.get(key, "")


# ---------------------------------------------------------------- 건물 안(2026-11-21 사용자: "건물 안으로 들어가서 대화하는 느낌")

## 종류별 방(처음 들어갈 때 마을 서쪽 멀리에 짓고 둔다).
var _rooms: Dictionary = {}
## 지금 들어가 있는 방(없으면 null)과 나올 때 되돌릴 카메라·빛.
var _room: Interior = null
var _out_cam: Camera3D = null
var _out_sun: float = 1.0
var _out_amb: float = 1.0


## 들어간다: 검게 덮고 → 방의 카메라로 바꾸고 사람을 세우고 → 창(오른쪽)과 사람의 첫마디(아래) → 걷는다.
## 창이 닫히면(_hud.closed) 같은 길로 나온다. lines가 비면 아무 말 없이(빈 집).
func _enter(kind: StringName, who: String, look: StringName, lines: Array, open: Callable) -> void:
	if _room != null:
		return
	_capture(false)
	var t := _hud.fade_to(1.0, 0.22)
	t.finished.connect(func() -> void:
		var room: Interior = _rooms.get(kind)
		if room == null:
			room = Interior.new()
			add_child(room)
			room.position = Vector3(-420.0 - 40.0 * _rooms.size(), 0.0, -420.0)
			room.build(kind)
			_rooms[kind] = room
		room.set_npc(look)
		_room = room
		_out_cam = get_viewport().get_camera_3d()
		room.cam.make_current()
		var env: Environment = ($Environment as WorldEnvironment).environment
		_out_sun = _sun.light_energy
		_out_amb = env.ambient_light_energy
		_sun.light_energy = _out_sun * 0.12
		env.ambient_light_energy = _out_amb * 0.35
		_sfx.play(&"thump", _lord.position, -14.0, 0.7)   # 문
		_hud.set_inside(true)
		open.call()
		if not lines.is_empty():
			_hud.say(who, lines[_deco.randi() % lines.size()], true)
		_hud.fade_to(0.0, 0.35))


func _leave_inside() -> void:
	if _room == null:
		return
	var t := _hud.fade_to(1.0, 0.2)
	t.finished.connect(func() -> void:
		_room.set_npc(&"")
		_room = null
		if _out_cam:
			_out_cam.make_current()
		_sun.light_energy = _out_sun
		($Environment as WorldEnvironment).environment.ambient_light_energy = _out_amb
		_hud.set_inside(false)
		_hud.say_end()
		_hud.fade_to(0.0, 0.3)
		_capture(true))


## 이 집에 사는 사람(쉬는 사람 중 그 집에 든 순서대로). 없으면 빈 사전.
func _resident_home(b: BuildingData) -> Dictionary:
	var start: int = 0
	for o in data.buildings:
		if o == b:
			break
		if meta.has_built(o.id):
			start += o.housing
	var rest: Array = meta.residents.filter(func(r: Dictionary) -> bool: return r.job == &"")
	var all: Array = meta.residents
	return all[start] if start < all.size() else (rest[0] if not rest.is_empty() else {})


# ---------------------------------------------------------------- 마을 단계(마을 키우기 4단계)

var _fence: Node3D = null
var _fence_lines: Array = []
var _tier: int = 0
var _tier_node: Node3D = null
## 걷는 사람: [{P, root, path(칸), len(칸), s(칸), speed(칸/초)}]
var _walkers: Array = []


## 지금 단계의 등불과 걷는 사람을 세운다(단계가 오르면 다시).
func _build_tier() -> void:
	_tier = meta.village_tier(data)
	if _tier_node:
		_tier_node.queue_free()
	_tier_node = Node3D.new()
	add_child(_tier_node)
	var md := data.meta
	for i in mini(md.tier_lights[_tier], TIER_LIGHTS.size()):
		var c: Vector2 = TIER_LIGHTS[i]
		var to_street: Vector2 = Vector2(c.x, OUTER_GATE.y) - c if c.x > 33.0 else Vector2(17, 12) - c
		VillageBuilder.lantern(_tier_node, Grid.cells_to_world(c), VillageBuilder.facing_to(to_street), true)
	_walkers = []
	var looks: Array[StringName] = FieldLayout.RESIDENT_LOOKS
	for i in md.tier_walkers[_tier]:
		var path: Array = WALK_PATHS[i % WALK_PATHS.size()]
		var holder := Node3D.new()
		_tier_node.add_child(holder)
		var body := Node3D.new()
		holder.add_child(body)
		var P: Dictionary = VillageProps.villager(looks[(i + 1) % looks.size()], body)
		VillageProps.pose(P, "walk")
		var len: float = 0.0
		for k in path.size() - 1:
			len += (path[k] as Vector2).distance_to(path[k + 1])
		_walkers.append({"P": P, "root": holder, "path": path, "len": len, "s": len * float(i) * 0.37, "speed": 0.5 + 0.08 * float(i % 3)})


## 걷는 사람: 길을 따라 오가며(끝에서 돌아선다) 걸음마다 살짝 출렁인다.
func _walk(delta: float) -> void:
	for w in _walkers:
		w.s += float(w.speed) * delta
		var L: float = maxf(0.01, float(w.len))
		var u: float = fmod(float(w.s), 2.0 * L)
		var back: bool = u > L
		var dist: float = 2.0 * L - u if back else u
		var path: Array = w.path
		var at: Vector2 = path[0]
		var dir := Vector2(0, 1)
		for k in path.size() - 1:
			var a: Vector2 = path[k]
			var b: Vector2 = path[k + 1]
			var seg: float = a.distance_to(b)
			if dist <= seg or k == path.size() - 2:
				at = a.lerp(b, clampf(dist / maxf(seg, 0.001), 0.0, 1.0))
				dir = (b - a).normalized() * (-1.0 if back else 1.0)
				break
			dist -= seg
		var root: Node3D = w.root
		root.position = Grid.cells_to_world(at, 0.0 if w.P.has("npc") else absf(sin(float(w.s) * 9.0)) * 0.04)
		root.rotation.y = VillageBuilder.facing_to(dir) + PI
		EventArt.breathe(w.P, _vt)


## 단계가 올랐으면 알리고(큰 글자 한 번, 소리) 등불과 걷는 사람을 늘린다.
func _check_tier() -> void:
	var t: int = meta.village_tier(data)
	if t > meta.tier_seen:
		meta.tier_seen = t
		meta.save()
		_hud.area_title("%s이 되었다" % data.meta.tier_names[t])
		_sfx.play(&"anvil", _lord.position if _lord else Vector3.ZERO, -4.0)
	if t != _tier:
		_build_tier()


## 촌장의 첫 줄: 지금 단계와 다음 단계까지 모자란 것.
func _tier_line() -> String:
	var md := data.meta
	var need: Dictionary = meta.next_tier_need(data)
	if need.is_empty():
		return "이제 이곳은 %s이오. 언덕 아래에 이만한 곳은 없소." % md.tier_names[_tier]
	var bits: Array[String] = []
	if int(need.buildings) > 0:
		bits.append("집 %d채" % int(need.buildings))
	if int(need.residents) > 0:
		bits.append("사는 사람 %d" % int(need.residents))
	if bool(need.wall):
		bits.append("돌담")
	return "지금 이곳은 %s이오. %s이 되려면 %s이(가) 더 있어야 하오." % [md.tier_names[_tier], md.tier_names[int(need.tier)], ", ".join(bits)]


# ---------------------------------------------------------------- 주민(마을 키우기 3단계)

## 주민의 몸: [{P, root, circle}]. 일을 바꾸면 다시 세운다.
var _res: Array = []


## 주민을 세운다: 일꾼은 제 일터 앞(일터를 보고), 쉬는 사람은 오두막 앞(길을 보고). 오두막이 없으면 광장 가.
func _build_residents() -> void:
	for r in _res:
		(r.root as Node3D).queue_free()
		_circles.erase(r.circle)
	_res = []
	var counts: Dictionary = {}
	for i in meta.residents.size():
		var res: Dictionary = meta.residents[i]
		var key: StringName = res.job if res.job != &"" else &"cottage"
		var k: int = int(counts.get(key, 0))
		counts[key] = k + 1
		var b: BuildingData = data.building(key) if meta.has_built(key) else null
		var cell := Vector2(19.0 + k * 1.2, 15.5)
		var face := Vector2(0, -1)
		if b:
			var side := Vector2(-b.facing.y, b.facing.x)
			cell = b.plot + b.facing * (b.size.y / Grid.CELL / 2.0 + 1.6) + side * (-1.0 + 2.0 * float(k % 2)) * (0.9 if res.job != &"" else 1.6)
			face = -b.facing if res.job != &"" else b.facing
		var holder := VillageBuilder.place(self, Grid.cells_to_world(cell), VillageBuilder.facing_to(face) + PI)
		var P: Dictionary = VillageProps.villager(res.look, holder)
		var circ := [cell, 0.4]
		_circles.append(circ)
		_res.append({"P": P, "root": holder, "circle": circ})


func _on_building_built(id: StringName) -> void:
	var p: BuildingPlot = _plots.get(id)
	if p == null:
		return
	p.raise()
	var b: BuildingData = data.building(id)
	if b.kind == &"wall":   # 목책이 가라앉고 그 자리에 돌담이 한 조각씩 놓인다
		var t := _fence.create_tween()
		t.tween_property(_fence, "position:y", -3.2, 1.2).set_ease(Tween.EASE_IN)
		t.tween_callback(func() -> void:
			_fence.visible = false
			_fence.position.y = 0.0)
	_rects[_plot_rect[id]] = p.rect(b.plot)
	rules.lord.pos = _push_out(rules.lord.pos)
	rules.lord.prev_pos = rules.lord.pos


func _rack_rect() -> Rect2:
	var at: Vector2 = storage_at + Vector2(StorageHouse.RACK_AT.x, StorageHouse.RACK_AT.z) / Grid.CELL
	return Rect2(at - Vector2(0.4, 0.12), Vector2(0.8, 0.24))


func _on_storage_built() -> void:
	_storage.raise()
	_rects[_storage_rect] = _storage.rect(storage_at)
	_rects.append(_rack_rect())
	rules.lord.pos = _push_out(rules.lord.pos)   # 터 안에 서 있었으면 집 밖으로
	rules.lord.prev_pos = rules.lord.pos
	_hud.toast("검 보관집을 짓는다.")


func _on_sheath_bought(level: int) -> void:
	_storage.set_level(level)
	_sfx.play(&"draw", Grid.cells_to_world(storage_at, 1.0), -6.0)


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
	_walk(delta)
	for r in _res:
		EventArt.breathe(r.P, _vt)
		var rr: Node3D = r.root
		VillageProps.look_at(r.P, rr, eye, 1.0 if rr.position.distance_to(_lord.position) < 8.0 else 0.0)
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
	if id == &"elder":   # 촌장은 먼저 마을 단계와 다음 단계까지 모자란 것을 말한다
		lines.insert(0, _tier_line())
	if lines.is_empty():
		return
	meta.save()
	_talker = id
	_talk_lines = lines
	_talk_i = 0
	_hud.say(_talk_name(), lines[0], lines.size() == 1)


func _end_talk() -> void:
	if _talker != &"" and _folk.has(_talker):
		VillageProps.still(_folk[_talker].P)
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
