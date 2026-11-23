extends Node3D
## 언덕(한 판). 입력을 모아 규칙을 고정 틱으로 돌리고, 규칙의 상태와 신호를 받아 그린다.
## 낮: 언덕에 꽂힌 검을 E로 뽑는다. 밤(N): 뽑은 검으로 버틴다. 열 구역을 올라 정상의 언덕지기를 쓰러뜨리면 끝.
## 끝나면 조각을 마을(scenes/lobby/lobby.tscn)로 가져간다.

const LORD_SCENE: PackedScene = preload("res://scenes/lord/lord.tscn")
const LOBBY_PATH: String = "res://scenes/lobby/lobby.tscn"
## 밤의 목표와 구역 규칙의 이름(12단계, docs/content.md). 포위 변은 Rules.siege의 번호.
const GOAL_NAMES: Dictionary = {&"survive": "버티기", &"defend": "지키기", &"hunt": "사냥", &"siege": "포위"}
const RULE_NAMES: Dictionary = {&"fog": "짙은 안개", &"embers": "불씨 땅", &"graves": "무덤"}
const SIDE_NAMES: Array[String] = ["북쪽", "남쪽", "서쪽", "동쪽"]
## 갈림길 지도 창의 한 줄 설명과 길의 이름(어려움 0~2, 13단계).
const PATH_NAMES: Array[String] = ["완만한 길", "험한 길", "가파른 길"]
const RULE_TEXT: Dictionary = {&"fog": "적이 잘 보이지 않는다", &"embers": "달아오른 땅이 탄다", &"graves": "쓰러진 망령이 다시 일어난다"}
## 낮 사건의 이름과, 낮이 밝을 때의 알림(13단계).
const EVENT_NAMES: Dictionary = {&"smith": "떠돌이 대장장이", &"cursed": "저주받은 손잡이", &"pilgrim": "순례자", &"seer": "점쟁이"}
const EVENT_NEWS: Dictionary = {&"smith": "떠돌이 대장장이가 머문다", &"cursed": "검은 기운이 도는 손잡이가 꽂혔다", &"pilgrim": "순례자가 쉬어 간다", &"seer": "점쟁이가 등불을 들고 있다"}

## 0이면 시작할 때 아무 시드나 고른다. 같은 판을 다시 보고 싶으면 값을 넣는다.
@export var seed_value: int = 0
## 한 프레임에 따라잡을 틱의 최대 수. 넘치면 밀린 시간을 버린다.
@export var max_ticks_per_frame: int = 8
@export var hit_number_size: int = 40
@export var big_number_size: int = 58

@export_group("낮과 밤의 빛")
## 돌진·갈고리 때 화면 가장자리가 가운데로 빨려 드는 세기.
@export var dash_blur: float = 0.025
@export var hook_blur: float = 0.06
@export var day_sun: float = 0.75
@export var night_sun: float = 1.1
@export var day_ambient: float = 1.0
@export var night_ambient: float = 1.2
## 밤에는 하늘빛 대신 이 색을 둘레 빛으로 쓴다(밤 하늘 사진이 너무 어두워서).
@export var night_ambient_color: Color = Color(0.3, 0.36, 0.52)
@export var day_sun_color: Color = Color(1.0, 0.93, 0.84)
@export var night_sun_color: Color = Color(0.55, 0.65, 1.0)
@export var day_fog: Color = Color(0.44, 0.46, 0.48)
@export var night_fog: Color = Color(0.05, 0.06, 0.09)
@export var torch_energy: float = 2.6
@export var light_change_time: float = 1.5

## 다음에 뽑히는 검이 완벽한 뽑기였는가(검의 기록).
var _perfect_pull: bool = false
var data: GameData
var rules: Rules
var meta: Meta
var _acc: float = 0.0
var _want_attack: bool = false
var _want_dash: bool = false
var _want_jump: bool = false
var _want_hook: bool = false
var _want_pull: bool = false
var _swap_to: int = -1
var _lord: Node3D
var _hilts: Dictionary = {}
## 검 주인의 잔영들(Ghost.id → GhostView).
var _ghosts: Dictionary = {}
var _enemies: Dictionary = {}
var _dying: Array[EnemyView] = []
var _fx := HitFx.new()
var _pfx := PowerFx.new()
var _pull_fx := PullFx.new()
## 버팀 타이밍 고리(14단계). Rules의 pull_window·pull_good·pull_perfect·pull_miss를 받는다.
## 제대로 당기면 다음 창이 바로 열리는데, 하나는 새 창에 앞 고리를 지우므로 둘을 번갈아 쓴다(k번째 버팀은 k % 2).
## 그래서 닫히는 고리의 번쩍임과 다음 고리가 함께 보인다.
var _timing_fx: Array[PullTimingFx] = [PullTimingFx.new(), PullTimingFx.new()]
## 좌클릭 동작 20가지와 속성의 효과(판정 모양, 날아가는 것, 착지 먼지 …). Rules의 move_* 신호를 받는다.
var _move_fx := MoveFx.new()
## 새 적 5종의 효과(겨눈 선, 화살, 방패 불똥, 돌진 길, 심지와 폭발, 부르는 원). Rules의 enemy_act·enemy_projectile_* 신호를 받는다.
var _enemy_fx := EnemyFx.new()
## 밤의 목표와 구역 규칙의 효과(봉화가 맞고 꺼짐, 불씨 땅, 무덤, 포위 띠, 안개, 우두머리 고리). Rules의 밤 신호를 받는다.
var _night_fx := NightFx.new()
## 지키는 밤의 봉화(NightArt.beacon). 낮이 되면 거둔다.
var _beacon_node: Node3D = null
## 우두머리 고리를 붙일 적 id(그 적의 EnemyView가 생기면 붙인다). -1이면 없음.
var _ring_for: int = -1
var _fog_on: bool = false
## 지금 쥔 검(바뀔 때만 손의 칼과 효과 색을 바꾼다).
var _held: Sword = null
var _held_set: bool = false
## 뽑기 연출이 끝나는 때(밀리초). 그전에는 고르기 창과 이름 알림을 미룬다.
var _reveal_until: int = 0
var _hud_t: float = 0.0
var _altar_view: Node3D = null
## 낮 사건의 효과(쓰일 때, 사라질 때, 저주받은 손잡이의 기운). EventArt로 지은 형체를 움직인다.
var _efx := EventFx.new()
## 이 낮의 사건과 그 형체(EventArt.build가 돌려준 것), 형체를 세운 자리 노드, 저주받은 손잡이의 HiltView.
var _event: DayEvent = null
var _event_P: Dictionary = {}
var _event_holder: Node3D = null
var _cursed_view: Node3D = null
var _event_t: float = 0.0
## 저주받은 손잡이를 뽑았을 때 이름 알림 뒤에 붙일 말.
var _pull_note: String = ""
## 버팀을 모두 제대로 당겼다(이번 뽑기). 이름 알림에 최대 내구가 늘었다고 붙인다.
var _perfect_note: bool = false

@onready var _env: WorldEnvironment = $Environment
@onready var _sun: DirectionalLight3D = $Sun
@onready var _camera: Camera3D = $Camera
@onready var _sfx: Sfx = $Sfx
@onready var _hud: Hud = $UI
## 관리: 원하는 검 받기(` 또는 F6). 열려 있는 동안 싸움이 멈춘다.
var _console := SwordConsole.new()


func _ready() -> void:
	data = GameData.load_default()
	meta = Meta.load_or_new()
	ObjectHead.lord_info = Heads.info(meta.head) if meta.head != "" else {}   # 쓴 머리
	meta.fix_sheath(data)
	var s: int = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
	Rules.events_default = true   # 언덕 재설계 시험(docs/hill_events.md): 첫 구역만
	rules = Rules.new(data, s, meta)
	Rules.events_default = false
	meta.save()   # 산 물건은 이 판에서 쓰였다(Meta.pack은 Rules가 비운다)
	_build_world()
	_setup_console()
	_lord = LORD_SCENE.instantiate()
	_lord.setup(rules)
	add_child(_lord)
	add_child(_fx)
	_pfx.setup(rules)
	add_child(_pfx)
	_pull_fx.env = _env.environment
	add_child(_pull_fx)
	for fx in _timing_fx:
		add_child(fx)
	add_child(_move_fx)
	_move_fx.setup(rules)
	add_child(_enemy_fx)
	_enemy_fx.setup(rules, _enemy_parts)
	_enemy_fx.exploded.connect(func(_at: Vector3, k: float) -> void:
		_camera.add_shake(0.35 * k)
		_camera.kick(6.0 * k))
	_enemy_fx.quaked.connect(func(_at: Vector3, k: float) -> void: _camera.add_shake(0.4 * k))   # 보스 패턴의 땅 울림
	add_child(_night_fx)
	_night_fx.setup(rules)
	add_child(_efx)
	_efx.setup(rules)
	rules.path_offered.connect(_on_path_offered)
	rules.event_placed.connect(_on_event_placed)
	rules.event_used.connect(_on_event_used)
	rules.event_gone.connect(_on_event_gone)
	_hud.path_picked.connect(func(i: int) -> void:
		rules.choose_path(i)
		_capture(true))
	rules.beacon_out.connect(func() -> void:
		_hud.toast("봉화가 꺼졌다. 이 밤의 보상은 없고, 새벽 회복이 절반이다.")
		_camera.add_shake(0.3))
	rules.move_area.connect(_on_move_area)
	rules.effect.connect(_on_effect)
	rules.day_started.connect(_on_day)
	var hzv := HzView.new()   # 언덕 재설계: 검 지도의 줄·깨어남·거래 창
	add_child(hzv)
	hzv.setup(rules)
	rules.hz_event.connect(_on_hz_event)
	rules.head_found.connect(func(id: String) -> void:   # 다른 영주의 검: 그 사람 머리
		if meta.add_head(id):
			meta.save()
			_hud.toast("%s를 얻었다 · 마을 성소에서 쓴다" % Heads.info(id).name))
	if meta and meta.runs == 0:   # 첫 판: 튜토리얼
		var tut := Tutorial.new()
		add_child(tut)
		tut.setup(rules)
	rules.night_started.connect(_on_night)
	rules.run_ended.connect(_on_end)
	rules.pull_started.connect(func(h: Hilt, _g: int) -> void:
		_sfx.play(&"thump", _lord.position, -10.0)
		_pull_fx.begin(Grid.cells_to_world(h.pos), h.id))
	rules.pull_step.connect(_on_pull_step)
	rules.pull_window.connect(func(h: Hilt, o: float, c: float) -> void: _timing_fx[rules.pull_win_step % 2].on_window(Grid.cells_to_world(h.pos), o, c, rules.pull_t))
	rules.pull_good.connect(_on_pull_good)
	rules.pull_perfect.connect(_on_pull_perfect)
	rules.pull_miss.connect(func(_h: Hilt, k: int) -> void: _timing_fx[k % 2].on_miss())
	rules.omens_revealed.connect(func() -> void:
		for v: HiltView in _hilts.values():
			if is_instance_valid(v):
				v.show_omen())
	rules.pull_refused.connect(func(t: String) -> void: _hud.toast(t))
	rules.sword_pulled.connect(_on_pulled)
	rules.sword_drawn.connect(_on_drawn)
	rules.ghost_spawned.connect(_on_ghost)
	rules.ghost_swung.connect(func(g: Ghost, big: bool) -> void:
		var v: GhostView = _ghosts.get(g.id)
		if v:
			v.swing(big)
			_sfx.play(&"swish_big" if big else &"swish", v.position, -6.0, 0.85))
	rules.ghost_gone.connect(func(g: Ghost) -> void:
		var v: GhostView = _ghosts.get(g.id)
		_ghosts.erase(g.id)
		if v:
			v.leave())
	rules.draw_countered.connect(func(_at: Vector2) -> void:
		_hud.toast("발검 반격 · 뽑기 값을 돌려받았다"))
	rules.choice_needed.connect(_on_choice_needed)
	rules.slots_changed.connect(_refresh_cards)
	rules.sword_broke.connect(_on_broke)
	rules.lord_swung.connect(_on_swung)
	rules.lord_dashed.connect(func() -> void:
		_sfx.play(&"dash", _lord.position, -6.0)
		_camera.kick(4.0))
	rules.lord_landed.connect(func(_at: Vector2) -> void: _sfx.play(&"land", _lord.position, -4.0))
	rules.lord_hooked.connect(func(e: Enemy) -> void:
		_sfx.play(&"draw", _lord.position, -2.0, 1.25)
		_sfx.play(&"dash", _lord.position, -3.0, 0.85)
		_camera.kick(10.0)
		_camera.add_shake(0.1))
	rules.lord_hurt.connect(_on_lord_hurt)
	rules.enemy_hit.connect(_on_enemy_hit)
	rules.enemy_died.connect(_on_enemy_died)
	rules.elite_spawned.connect(func(e: Enemy) -> void: _hud.toast("정예를 쓰러뜨리면 공짜 뽑기"))
	rules.altar_opened.connect(_on_altar_opened)
	rules.altar_used.connect(_on_altar_used)
	rules.boss_spawned.connect(_on_boss)
	_hud.chose.connect(func(k: int) -> void: rules.choose(k); _capture(true))
	_hud.altar_chosen.connect(func(i: int) -> void: rules.use_altar(i); _capture(true))
	_hud.restart_requested.connect(_to_lobby)
	_hud.night_button().pressed.connect(func() -> void: rules.start_night())
	_sync_hilts()
	_refresh_cards()
	_set_light(false, true)
	_camera.target = _lord_world()
	_camera.snap()
	_sync_altar()
	if rules.event:
		_on_event_placed(rules.event)
	_hud.area_title(_zone_name())
	# 뽑는 법·밤 맞는 법은 손잡이 앞 E 안내와 밤 맞이하기 단추가 이미 말한다(2026-11-21 화면 글 정리)
	var from: Array[String] = []
	if rules.slots[0] and rules.forged != 0:
		from.append("검집에서 %s을(를) 꺼냈다." % rules.slots[0].label())
	if rules.forged >= 0 and rules.slots[rules.forged]:
		from.append("풀무간에서 벼린 %s을(를) 쥐었다." % rules.slots[rules.forged].label())
	if not from.is_empty():
		_hud.toast(" ".join(from))
	_capture(true)
	WebQuality.apply(self, _env.environment, _sun, _camera)   # 웹판에서만 가볍게


## 3인칭에서는 마우스를 가둬 둘러보게 한다. 창이 열리면 풀어 준다.
func _setup_console() -> void:
	_console.setup(data)
	_hud.add_child(_console)
	_console.closed.connect(func() -> void: _capture(true))
	_console.picked.connect(_on_console_pick)
	_console.shards_given.connect(func(n: int) -> void:
		meta.shards = maxi(0, meta.shards + n)
		meta.save())


## 관리 창에서 고른 검을 칸에 쥐여 준다. slot이 -1이면 지금 쥔 칸.
func _on_console_pick(d: SwordData, slot: int) -> void:
	var k: int = slot if slot >= 0 else rules.active
	rules.give(d, k)
	if rules.active != k:
		rules.swap(k)
	_hud.toast("관리: %s · %s을(를) %d번 칸에 받았다." % [data.grades.names[d.grade], d.display_name, k + 1])


func _capture(on: bool) -> void:
	var want: bool = on and _camera.third() and rules.phase != Rules.Phase.OVER and not _hud.choice_open() and not _hud.altar_is_open() and not _hud.map_open() and not _console.visible
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if want else Input.MOUSE_MODE_VISIBLE


func _to_lobby() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(LOBBY_PATH)


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
	if event.is_action_pressed("restart") and rules.phase == Rules.Phase.OVER:
		_to_lobby()
		return
	var mm := event as InputEventMouseMotion
	if mm and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_camera.look(mm.relative)
	if _hud.altar_is_open():
		var kk := event as InputEventKey
		if kk and kk.pressed and not kk.echo:
			if kk.physical_keycode >= KEY_1 and kk.physical_keycode <= KEY_9:
				_hud.pick_altar(kk.physical_keycode - KEY_1)
			elif kk.physical_keycode == KEY_ESCAPE:
				_hud.pick_altar(-1)
		return
	# 갈림길: 1 또는 2(카드 클릭은 창이 받는다)
	if _hud.map_open():
		if event.is_action_pressed("slot_1"):
			_hud.pick_path(0)
		elif event.is_action_pressed("slot_2"):
			_hud.pick_path(1)
		return
	if _hud.choice_open():
		for k in mini(4, rules.slots.size()):
			if event.is_action_pressed("slot_%d" % (k + 1)):
				_hud.pick(k)
				return
		if event.is_action_pressed("discard"):
			_hud.pick(-1)
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and _camera.third() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_capture(true)
		return
	# 틱 사이에 눌렀다 뗀 것도 놓치지 않게 모아 둔다
	if event.is_action_pressed("attack"):
		_want_attack = true
	if event.is_action_pressed("dash"):
		_want_dash = true
	if event.is_action_pressed("jump"):
		_want_jump = true
	if event.is_action_pressed("hook"):
		_want_hook = true
	if event.is_action_pressed("pull"):
		_want_pull = true
	if event.is_action_pressed("swap"):
		_swap_to = Rules.SWAP_NEXT
	for k in mini(4, rules.slots.size()):
		if event.is_action_pressed("slot_%d" % (k + 1)):
			_swap_to = k
	if event.is_action_pressed("start_night"):
		rules.start_night()
	var k := event as InputEventKey
	if k and k.pressed and not k.echo:
		match k.physical_keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_R:
				if rules.fate_reroll():
					_hud.toast("운명 베기: 다시 뽑았다")
			KEY_F1:
				_hud.toggle_help()
			KEY_V:
				_camera.toggle_mode()
				_capture(true)
				_hud.toast("카메라: " + ("3인칭" if _camera.third() else "쿼터뷰"))
			KEY_F2:
				rules.debug_god = not rules.debug_god
				_hud.toast("관리: 무적 " + ("켬" if rules.debug_god else "끔"))
			KEY_F3:
				rules.skip_night()
			KEY_QUOTELEFT, KEY_F6:
				_capture(false)
				_console.open()
				get_viewport().set_input_as_handled()
			KEY_F4:
				rules.debug_grade = rules.debug_grade + 1 if rules.debug_grade < 5 else -1
				_hud.toast("관리: 다음 뽑기 " + ("등급 굴리기" if rules.debug_grade < 0 else data.grades.names[rules.debug_grade] + "로 고정"))


func _physics_process(delta: float) -> void:
	if _console.visible:
		return
	_acc += delta
	var n: int = 0
	while _acc >= rules.dt and n < max_ticks_per_frame:
		rules.step(_read_input())
		_want_attack = false
		_want_dash = false
		_want_jump = false
		_want_hook = false
		_want_pull = false
		_swap_to = -1
		_acc -= rules.dt
		n += 1
	if n == max_ticks_per_frame:
		_acc = 0.0


func _read_input() -> LordInput:
	var inp := LordInput.new()
	inp.move = _camera.relative_move(Input.get_vector("move_left", "move_right", "move_up", "move_down"))
	inp.attack = Input.is_action_pressed("attack") or _want_attack
	inp.dash = _want_dash
	inp.jump = _want_jump
	inp.hook = _want_hook
	inp.pull = _want_pull
	# 뽑는 동안은 E나 좌클릭을 누른 순간이 버팀 타이밍이다(14단계)
	inp.pull_press = _want_pull or _want_attack
	inp.swap_to = _swap_to
	if _camera.third():
		# 3인칭: 카메라가 보는 쪽을 벤다
		inp.aim_valid = true
		inp.aim = rules.lord.pos + _camera.forward_cells() * 3.0
	else:
		var g: Variant = _camera.ground_point(get_viewport().get_mouse_position())
		if g != null:
			inp.aim_valid = true
			inp.aim = Grid.world_to_cells(g)
	return inp


func _process(delta: float) -> void:
	var alpha: float = clampf(_acc / rules.dt, 0.0, 1.0)
	_lord.draw(alpha, delta)
	for v: GhostView in _ghosts.values():
		v.draw(alpha, delta)
	# 타이밍 고리의 시계를 규칙에 맞춘다(눌린 때는 그 틱 사이의 가운데로 판정된다)
	if rules.pull_hilt != null:
		for fx in _timing_fx:
			fx.sync(rules.pull_t + alpha * rules.dt)
	_move_fx.draw(alpha)
	_enemy_fx.draw(alpha)
	_sync_enemies(alpha, delta)
	# 우두머리 고리: 그 적의 몸이 생기면 발밑에 붙인다
	if _ring_for >= 0 and _enemies.has(_ring_for):
		var v: EnemyView = _enemies[_ring_for]
		_night_fx.ring_follow(v, Grid.cells_to_meters(v.enemy.radius) * 1.7)
		_ring_for = -1
	_camera.target = _lord.position
	# 빠르게 움직일 때 화면 가장자리가 빨려 든다
	_camera.speed_blur = hook_blur if rules.lord.hook > 0.0 else (dash_blur if rules.lord.dash > 0.0 else 0.0)
	_camera.follow_boost = 24.0 if rules.lord.hook > 0.0 else 0.0
	_draw_event(delta)
	var night_draw: bool = rules.phase == Rules.Phase.NIGHT and rules.lord.move_lock <= 0.0
	var near := rules.nearest_hilt(data.run.pull_reach) if (rules.phase == Rules.Phase.DAY or night_draw) and rules.pull_hilt == null and rules.pending == null and not rules.path_open else null
	var altar_near: bool = rules.near_altar() and rules.pull_hilt == null and rules.pending == null and not rules.altar_open
	var ev_near: DayEvent = rules.near_event() if rules.pull_hilt == null and rules.pending == null and not rules.altar_open else null
	if altar_near:
		_hud.set_prompt("E", "숫돌 제단에 선다")
	elif ev_near:
		_hud.set_prompt("E", _event_prompt(ev_near))
	elif near and night_draw:
		var what: String = "꽂아 둔 %s · 공짜" % near.sword.data.display_name if near.sword else ("공짜" if rules.free_pulls > 0 or near.cursed else "체력 %d · 맞는 순간 뽑으면 반격하고 돌려받는다" % rules.pull_cost())
		_hud.set_prompt("E", "발검 · " + what)
	elif near and not near.owner.is_empty():
		var sd: SwordData = data.sword_by_id(int(near.owner.id))
		_hud.set_prompt("E", "주인 있는 %s · %s · %s" % [sd.display_name if sd else "검", Meta.fallen_line(near.owner, meta.runs, data.run.zone_names), "공짜" if rules.free_pulls > 0 else "체력 %d" % rules.pull_cost()])
	elif near and near.sword:
		_hud.set_prompt("E", "꽂아 둔 %s을(를) 뽑는다 · 공짜" % near.sword.data.display_name)
	elif near and near.cursed:
		_hud.set_prompt("E", "저주받은 손잡이 — 체력 없이 뽑는다 · 운 ×%s · 이번 밤 적이 강해지고 최대 내구 절반" % str(data.run.cursed_luck))
	elif near:
		_hud.set_prompt("E", "검을 뽑는다 · " + ("공짜" if rules.free_pulls > 0 else "체력 %d" % rules.pull_cost()))
	else:
		_hud.set_prompt("", "")
	_hud_t -= delta
	if _hud_t <= 0.0:
		_hud_t = 0.1
		_update_hud()


func _lord_world() -> Vector3:
	return Grid.cells_to_world(rules.lord.pos)


func _zone_name() -> String:
	return "%d구역 %s" % [rules.zone + 1, data.run.zone_names[rules.zone]]


func _update_hud() -> void:
	var night: bool = rules.phase == Rules.Phase.NIGHT
	var sub: String
	# 2026-11-21 화면 글 정리: 새벽까지 남은 초는 막대가, 남은 손잡이는 언덕이, 안개·불씨는 화면이 보여 준다.
	# 여기에는 화면에 안 보이는 것만: 적 수, 뽑기 운(1배가 아닐 때), 공짜 뽑기
	var bits: Array[String] = []
	if night:
		bits.append("적 %d" % rules.enemies.size())
	else:
		if not is_equal_approx(rules.luck(), 1.0):
			bits.append("뽑기 운 ×%s" % str(snappedf(rules.luck(), 0.01)))
		if rules.free_pulls > 0:
			bits.append("공짜 뽑기 %d" % rules.free_pulls)
	sub = " · ".join(bits)
	var k: float = 1.0 - maxf(0.0, rules.night_left) / maxf(1.0, rules.night_total) if night else 0.0
	var zone_text: String = "%s · %s" % [_zone_name(), GOAL_NAMES.get(rules.goal, "밤") if not rules.last_zone() else "언덕지기"] if night else _zone_name()
	_hud.set_status(rules.lord.hp, rules.max_hp(), zone_text, sub, k, night or rules.phase == Rules.Phase.OVER)
	_update_goal_line(night)
	_refresh_cards()


## 위 가운데 목표 진행: 언덕지기·우두머리 체력, 봉화 체력, 포위 쪽. 세계에는 글자를 띄우지 않는다.
func _update_goal_line(night: bool) -> void:
	if not night:
		_hud.set_goal("")
		return
	for e in rules.enemies:
		if e.data.boss and not e.dead:
			_hud.set_goal("언덕지기", e.hp / e.max_hp)
			return
	var hb: Enemy = rules.hunt_boss
	if hb and not hb.dead:
		_hud.set_goal("우두머리 · " + hb.data.display_name, hb.hp / hb.max_hp)
		return
	match rules.goal:
		&"defend":
			if rules.beacon_hp > 0.0:
				_hud.set_goal("봉화", rules.beacon_hp / rules.beacon_max, Color(1.0, 0.56, 0.22))
			else:
				_hud.set_goal("봉화가 꺼졌다")
		&"hunt":
			_hud.set_goal("사냥 · 우두머리가 올라온다" if not rules.hunt_out else "")
		&"siege":
			if rules.siege >= 0:
				_hud.set_goal("포위 · %s에서 몰려온다" % SIDE_NAMES[rules.siege], rules.siege_left / maxf(1.0, data.run.siege_switch), Color(0.62, 0.55, 0.42))
			else:
				_hud.set_goal("")
		_:
			_hud.set_goal("")


# ---------------------------------------------------------------- 카드

func _card(s: Sword, slot: int, held: bool) -> String:
	return SwordCard.bbcode(s, data, slot, held)


func _refresh_cards() -> void:
	var texts: Array[String] = []
	var cols: Array[Color] = []
	for k in rules.slots.size():
		var s := rules.slots[k]
		texts.append(_card(s, k, k == rules.active))
		cols.append(data.grades.colors[s.grade] if s else Color(0.4, 0.45, 0.55))
	_hud.set_cards(texts, cols, rules.active)
	var s := rules.current()
	if s != _held or not _held_set:
		_held = s
		_held_set = true
		_lord.set_sword(s, data.grades)
		_move_fx.tint = MoveArt.STEEL if s == null else (Color(0.9, 0.92, 1.0) if s.grade == 0 else (data.grades.colors[s.grade] as Color).lightened(0.25))


# ---------------------------------------------------------------- 신호

func _on_day(_zone: int) -> void:
	_move_fx.clear()
	_enemy_fx.clear()
	_clear_night_view()
	for v in _hilts.values():
		v.queue_free()
	_hilts.clear()
	_sync_hilts()
	_sync_altar()
	_set_light(false)
	_clear_event_view()
	_hud.area_title(_zone_name())
	# 지난 밤의 결과와 새벽 회복은 갈림길 창이 보였다. 여기서는 고른 길의 보상과 이 낮의 것
	var parts: Array[String] = []
	if rules.path_reward != &"":
		parts.append("길의 보상: " + _path_reward_name(rules.path_reward, true))
	if rules.altar:
		parts.append("숫돌 제단이 섰다")
	if rules.event:
		parts.append(EVENT_NEWS.get(rules.event.kind, ""))
	if not parts.is_empty():
		_hud.toast(" · ".join(parts))


## 지난 밤 목표의 결과 한 마디(없으면 "").
func _reward_text(ln: Dictionary) -> String:
	var free: int = int(ln.get("free", 0))
	match ln.get("goal", &""):
		&"defend":
			return "봉화를 지켰다. 공짜 뽑기 +%d. " % free if ln.ok else "봉화가 꺼진 채 "
		&"hunt":
			return "우두머리를 쓰러뜨렸다. 공짜 뽑기 +%d · 조각 +%d. " % [free, int(ln.shards)] if ln.ok else "우두머리는 달아났다. "
		&"siege":
			return "포위를 버텼다. 공짜 뽑기 +%d. " % free
	return ""


func _on_night(_zone: int) -> void:
	# 뽑지 않은 검은 밤에도 꽂혀 있다(발검 자리, docs/sword_hill.md)
	_sync_hilts()
	_sync_altar()
	_set_light(true)
	_sfx.play(&"night", _lord.position, -2.0)
	_start_night_view()
	var goal_name: String = "언덕지기" if rules.last_zone() else GOAL_NAMES.get(rules.goal, "버티기")
	_hud.area_title("%s · %s" % [_zone_name(), goal_name])
	var line: String = _goal_line()
	if line != "":
		_hud.toast(line)


## 이 밤의 한 줄 목표(Band). 2026-11-21 화면 글 정리: 밤이 온 것(어둠), 버틸 초(막대), 안개(화면)는 말하지 않는다.
## 화면만 봐서는 모를 것만 남긴다. 없으면 "".
func _goal_line() -> String:
	var bits: Array[String] = []
	if rules.last_zone():
		bits.append("정상의 언덕지기를 쓰러뜨려야 끝난다")
	else:
		match rules.goal:
			&"defend":
				bits.append("적의 일부가 봉화를 노린다")
			&"hunt":
				bits.append("곧 올라올 우두머리를 쓰러뜨리면 바로 새벽")
	match rules.rule:
		&"embers":
			bits.append("달아오르는 땅을 피해")
		&"graves":
			bits.append("쓰러진 망령이 다시 일어난다")
	if rules.cursed_night:
		bits.append("저주가 적을 사납게 한다")
	return " · ".join(bits)


## 밤이 시작될 때: 봉화를 세우고, 안개를 짙게 한다. 두 번째 기회로 밤이 다시 시작되면 앞의 것을 거두고 다시 한다.
func _start_night_view() -> void:
	_clear_night_view()
	if rules.beacon_max > 0.0:
		_beacon_node = Node3D.new()
		_beacon_node.name = "BeaconSpot"
		add_child(_beacon_node)
		var w: Vector3 = Grid.cells_to_world(rules.beacon_pos)
		w.y = HillBuilder.height(w.x, w.z)
		_beacon_node.position = w
		_night_fx.watch_beacon(NightArt.beacon(_beacon_node))
	if rules.rule == &"fog":
		_fog_on = true
		_night_fx.fog(_env.environment, true)


## 낮이 되거나 판이 끝날 때: 밤의 효과와 봉화를 거두고 안개를 되돌린다.
func _clear_night_view() -> void:
	_night_fx.clear()
	_ring_for = -1
	if _beacon_node:
		_beacon_node.queue_free()
		_beacon_node = null
	if _fog_on:
		_fog_on = false
		_night_fx.fog(_env.environment, false)


## 언덕지기 또는 사냥의 우두머리가 나왔다. 우두머리는 발밑 붉은 고리와 큰 몸으로 알아보게 한다(세계에 글자 없음).
func _on_boss(e: Enemy) -> void:
	_camera.add_shake(0.5)
	_sfx.play(&"night", _lord.position, 0.0)
	if e.data.boss:
		return   # 위 가운데 목표 막대에 이름과 체력이 뜬다
	_ring_for = e.id


## 판이 끝났을 때 의뢰 한 줄(맡은 의뢰가 없으면 빈 글).
func _quest_line(r: Dictionary) -> String:
	if r.quest_text == "":
		return ""
	if r.quest_done:
		return "\n의뢰 완료 · %s · 조각 +%d" % [r.quest_text, r.quest_reward]
	return "\n의뢰 실패 · %s (다시 도전할 수 있다)" % r.quest_text


func _on_end(won: bool) -> void:
	var best: String = data.grades.names[rules.best_grade] if rules.best_grade >= 0 else "없음"
	var title: String = "언덕의 정상에 섰다" if won else "%d구역에서 쓰러졌다" % (rules.zone + 1)
	var r := meta.record_run(rules, data.meta)
	meta.save()
	PlayLog.hill_end(rules, won, int(r.total))
	_move_fx.clear()
	_enemy_fx.clear()
	_clear_night_view()
	_clear_event_view()
	_hud.set_goal("")
	var got_mats: Array[String] = []
	for id in Meta.MAT_IDS:
		if int(r.mats[id]) > 0:
			got_mats.append("%s +%d" % [Meta.MAT_NAMES[id], int(r.mats[id])])
	_hud.show_over(title, (" · ".join(got_mats) + "\n" if not got_mats.is_empty() else "") + "뽑은 검 %d자루 · 쓰러뜨린 적 %d · 가장 높은 등급 %s\n조각 +%d  (처치 %d · 구역 %d · 부러진 검 %d · 정예 %d · 녹인 검 %d%s)" % [rules.pulls, rules.kills, best, r.total, r.kills, r.zone, r.broken, r.elite, r.melt, (" · 사냥 %d" % r.goal if r.goal > 0 else "") + (" · 갈림길 %d" % r.path if r.path > 0 else "")] + _quest_line(r))
	_capture(false)


func _on_swung(big: bool) -> void:
	_sfx.play(&"swish_big" if big else &"swish", _lord.position, -2.0 if big else -6.0)
	if big:
		_sfx.play(&"grunt", _lord.position, 0.0)


## 늦게 터지는 판정의 소리와 흔들림. 휘두르는 소리는 _on_swung(누를 때)이 낸다.
func _on_move_area(move: StringName, info: Dictionary) -> void:
	var at: Vector3 = Grid.cells_to_world(info.get("at", rules.lord.pos))
	var echo: bool = bool(info.get("echo", false))
	var quiet: float = -6.0 if echo else 0.0
	match move:
		&"flurry", &"whirl":
			_sfx.play(&"swish", _lord.position, -10.0 + quiet, 1.15 if move == &"flurry" else 0.95)
		&"smash", &"leap":
			_sfx.play(&"thump", at, -2.0 + quiet, 0.8)
			_camera.add_shake(0.12 if echo else 0.25)
		&"quake":
			_sfx.play(&"thump", at, -8.0 + quiet, 0.7)
			_camera.add_shake(0.06 if echo else 0.12)
		&"iaido":
			_sfx.play(&"swish_big", _lord.position, -2.0 + quiet, 1.2)
		&"parry", &"draw":
			if info.get("shape", &"") == &"circle" and not echo:
				_sfx.play(&"anvil", _lord.position, -4.0, 1.4)
				_camera.add_shake(0.2)
		&"hook":
			pass


func _on_pull_step(_h: Hilt, st: int) -> void:
	_camera.add_shake(0.12 + 0.07 * st)
	_sfx.play(&"thump", _lord.position, -6.0 + st)
	_pull_fx.step(st)


## 제대로 당김(14단계): 고리가 닫히며 불똥, 영주가 한 번 크게 젖힌다(LordView), 짧은 쿵.
func _on_pull_good(h: Hilt, st: int) -> void:
	var at: Vector3 = Grid.cells_to_world(h.pos)
	_timing_fx[st % 2].on_good(at, st)
	_sfx.play(&"thump", at, -1.0, 0.8)
	_camera.kick(3.0 + st)
	_camera.add_shake(0.08)


## 버팀을 모두 제대로 당겼다: 더 센 불똥·빛·충격파. 뽑은 뒤 이름 알림에 내구가 늘었다고 붙인다.
func _on_pull_perfect(h: Hilt) -> void:
	_perfect_pull = true
	var at: Vector3 = Grid.cells_to_world(h.pos)
	_timing_fx[rules.pull_judged % 2].on_perfect(at)
	_sfx.play(&"hit_big", at, -5.0, 0.7)
	_camera.kick(8.0)
	_camera.add_shake(0.25)
	_perfect_note = true


## 등급 연출 영상(assets/video/grade_<등급>.ogv). 없으면 "".
func _reveal_video(grade: int) -> String:
	var path: String = "res://assets/video/grade_%d.ogv" % grade
	return path if ResourceLoader.exists(path) else ""


func _on_pulled(s: Sword) -> void:
	for fx in _timing_fx:
		fx.clear()
	meta.note_found(s.data.id)
	meta.log_pull(s.data.id, _perfect_pull)
	_perfect_pull = false
	meta.save()
	var c: Color = data.grades.colors[s.grade]
	_sfx.play(&"draw", _lord.position, -4.0)
	# 땅에서 나오는 연출(먼지·불똥·불씨·빛). 전설부터는 영상이 있으면 영상을 튼다
	var hold: float = _pull_fx.reveal(s.grade, c, SwordModel.for_sword(s, data.grades), _lord.position)
	var video: String = _reveal_video(s.grade) if s.grade >= data.grades.reveal_from else ""
	if video != "":
		hold = maxf(hold, _hud.play_video(video))
	if s.grade >= data.grades.reveal_from:
		_camera.add_shake(0.3 + 0.08 * s.grade)
	_reveal_until = Time.get_ticks_msec() + int(hold * 1000.0)
	# 연출 중에는 글자를 띄우지 않는다. 끝나면 이름을 알린다
	var text: String = "%s · %s %s을(를) 뽑았다." % [data.grades.names[s.grade], s.form.display_name, s.data.display_name]
	if _perfect_note:
		_perfect_note = false
		if s.breakable():
			text += " 모두 제대로 당겨 최대 내구가 늘었다."
	if _pull_note != "":
		text += " " + _pull_note
		_pull_note = ""
	get_tree().create_timer(hold, true, false, true).timeout.connect(func() -> void: _hud.toast(text))


## 언덕 재설계: 검을 뽑아 사건이 시작되는 순간. 땅이 갈라지고(뽑기 먼지·불똥), 쿵 울리고, 잠깐 느려진다.
func _on_hz_event(zi: int, _kind: int) -> void:
	var h := rules.hilt_of(zi)
	var at: Vector3 = Grid.cells_to_world(h.pos) if h else _lord.position
	_sfx.play(&"draw", at, 0.0, 0.85)
	_sfx.play(&"hit_big", at, -6.0, 0.6)
	_camera.add_shake(0.45)
	_pull_fx.begin(at, zi)
	_pull_fx.reveal(0, Color(0.85, 0.25, 0.15), null, at)
	Engine.time_scale = 0.3
	get_tree().create_timer(0.22, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)


## 검 주인의 잔영이 나왔다(밤이 오는 순간이나 주인 있는 검을 발검한 순간).
func _on_ghost(g: Ghost) -> void:
	var v := GhostView.new()
	v.setup(rules, g)
	add_child(v)
	_ghosts[g.id] = v
	v.draw(1.0, 0.0)
	_sfx.play(&"grunt", v.position, -10.0, 0.7)
	_hud.toast("옛 주인의 잔영이 함께 싸운다")


## 밤의 발검: 연출 없이 소리·흔들림·이름 한 줄. 쥐던 검이 꽂힌 새 손잡이를 그린다.
func _on_drawn(s: Sword, _h: Hilt, _planted: Hilt) -> void:
	meta.note_found(s.data.id)
	meta.log_pull(s.data.id, false)
	_sync_hilts()
	_sfx.play(&"draw", _lord.position, -2.0, 1.15)
	_camera.add_shake(0.08 + 0.04 * s.grade)
	_hud.toast("%s · %s %s" % [data.grades.names[s.grade], s.form.display_name, s.data.display_name])


func _on_choice_needed(s: Sword) -> void:
	# 뽑기 연출이 끝난 뒤에 연다(연출을 보다가 누른 키가 창에 들어가지 않게)
	var wait: float = maxf(0.0, (_reveal_until - Time.get_ticks_msec()) / 1000.0)
	if wait > 0.0:
		get_tree().create_timer(wait, true, false, true).timeout.connect(func() -> void: _open_choice(s))
	else:
		_open_choice(s)


func _open_choice(s: Sword) -> void:
	if rules.pending != s:
		return
	var slot_texts: Array = []
	for k in rules.slots.size():
		slot_texts.append(_card(rules.slots[k], k, false))
	_hud.open_choice(_card(s, -1, false), slot_texts)
	_capture(false)


func _on_altar_opened() -> void:
	var texts: Array[String] = []
	var s := rules.current()
	var o := rules.slots[1 - rules.active]
	for opt in rules.altar_options():
		match opt.kind:
			"melt":
				var w := rules.slots[opt.slot]
				texts.append("녹이기: %s → 조각 %d" % [w.label(), data.meta.melt[w.grade]])
			"repair":
				texts.append("벼리기: %s을(를) 바쳐 %s의 내구를 다 채운다" % [o.label(), s.label()])
			"transfer":
				texts.append("옮기기: %s을(를) 바쳐 「%s」 각인을 %s에" % [o.label(), opt.key, s.label()])
	if texts.is_empty():
		rules.use_altar(-1)
		_hud.toast("제단에 바칠 검이 없다.")
		return
	_hud.open_altar(texts)
	_capture(false)


func _on_altar_used(kind: String, text: String) -> void:
	_sfx.play(&"anvil", _lord.position, -2.0)
	_hud.flash(Color(1, 0.91, 0.66), 0.25)
	match kind:
		"melt":
			_hud.toast("%s을(를) 녹였다. 판이 끝나면 조각이 된다." % text)
		"repair":
			_hud.toast("%s의 날이 새것처럼 섰다." % text)
		"transfer":
			_hud.toast("「%s」 각인이 새겨졌다." % text)
	_sync_altar()


func _on_broke(_k: int, s: Sword) -> void:
	meta.log_break(s.data.id)
	_sfx.play(&"break", _lord.position, 0.0)
	_camera.add_shake(0.3)
	_hud.toast(s.data.display_name + "이(가) 부러졌다." + ("" if rules.current() else " 이제 맨손이야."))


func _on_lord_hurt(d: float) -> void:
	_sfx.play(&"hurt", _lord.position, -4.0)
	_camera.add_shake(0.25)
	_hud.flash(Color(1, 0.2, 0.25), 0.18, 0.3)
	_float(_lord_world() + Vector3(0, 2.4, 0), "-%d" % roundi(d), Color(1, 0.42, 0.42), hit_number_size)


func _on_enemy_hit(e: Enemy, damage: float, big: bool) -> void:
	var at: Vector3 = Grid.cells_to_world(e.pos)
	if _enemies.has(e.id):
		_enemies[e.id].hit(big)
	var chest: Vector3 = at + Vector3(0, 0.9 + Grid.cells_to_meters(e.radius) * 1.2, 0)
	var dir: Vector3 = (at - _lord.position).normalized()
	if e.data.wraith:
		_fx.wisp(chest, dir, big)
	else:
		_fx.blood(chest, dir, big)
	_float(at + Vector3(0, 1.2 + Grid.cells_to_meters(e.radius) * 2.2, 0), str(roundi(damage)), Color(1, 0.86, 0.45) if big else Color.WHITE, big_number_size if big else hit_number_size)
	_camera.add_shake(data.lord.shake_big if big else data.lord.shake)
	_hit_sound(e, big, at)


## 때리는 소리: 칼날 소리(hit) 위에 맞는 쪽의 소리를 겹친다. 유령은 칼날만, 거인과 언덕지기는 묵직하게,
## 나머지는 살 베는 소리. 무거운 형태일수록 낮게, 단검일수록 높게(형태 피해 배수의 제곱근에 반비례).
func _hit_sound(e: Enemy, big: bool, at: Vector3) -> void:
	var s := rules.current()
	var pitch: float = 1.0 / sqrt(s.form.damage) if s else 1.1
	if s == null:
		_sfx.play(&"hit_flesh", at, 0.0, pitch)
		return
	_sfx.play(&"hit_big" if big else &"hit", at, 0.0, pitch * (1.15 if e.data.wraith else 1.0))
	if e.data.wraith:
		return
	if e.data.big or e.data.boss or big:
		_sfx.play(&"hit_heavy", at, -2.0 if big else -4.0, pitch)
	else:
		_sfx.play(&"hit_flesh", at, -2.0, pitch)


## 각인·고유 능력이 낸 일 중 화면 전체에 걸치는 것(번쩍임, 흔들림, 알림). 땅과 공중의 그림은 PowerFx.
func _on_effect(kind: StringName, at: Vector2, info: Dictionary) -> void:
	match kind:
		&"flash":
			_hud.flash(info.get("color", Color.WHITE), 0.5)
			_camera.add_shake(0.5)
		&"fall":
			_camera.add_shake(0.6)
			_sfx.play(&"hit_heavy", Grid.cells_to_world(at), 4.0, 0.7)
		&"zap":
			_sfx.play(&"anvil", Grid.cells_to_world(info.to), -6.0, 1.6)
		&"stop":
			_hud.flash(Color(0.6, 0.8, 1.0), 0.25)
			_hud.toast("멈춘 순간. 나만 움직인다.")
		&"saved":
			_hud.flash(Color(1.0, 0.9, 0.6), 0.4)
			_hud.toast({"충신": "충신이 대신 부러졌다.", "영원한 파수": "영원한 파수: 10초 동안 쓰러지지 않는다. 벤 만큼 체력을 되찾는다.", "두 번째 기회": "두 번째 기회: 이 밤을 처음부터 다시 한다."}.get(info.get("by", ""), "버텼다."))
		&"echo":
			_lord.echo_arc(at, info.face, info.arc, info.reach)
		&"free_pull":
			_hud.toast("산 자의 몫: 공짜 뽑기 +1")
		&"dex_all":
			for sw in data.swords:
				if not sw.field_only:   # 언덕의 검만(오픈월드 한정 검은 들판에서만 얻는다)
					meta.note_found(sw.id)
			meta.save()
			_hud.toast("언덕의 모든 검이 함께 뽑혀 나왔다. 도감이 다 채워졌다.")


## EnemyFx가 방패·배·지팡이 끝의 실제 자리를 읽는 그 적의 몸 부품(EnemyArt). 새 적이 아니면 빈 것.
func _enemy_parts(e: Enemy) -> Dictionary:
	var v: EnemyView = _enemies.get(e.id)
	return v.parts if v else {}


func _on_enemy_died(e: Enemy) -> void:
	if rules.current():
		_memory_toast(rules.current().data, meta.log_kill(rules.current().data.id))   # 검의 기록: 쥔 검이 벤 것으로 센다
	var at: Vector3 = Grid.cells_to_world(e.pos)
	# 터진 자폭병은 EnemyFx가 폭발을 그린다
	if e.act == &"explode":
		return
	if e.data.wraith:
		_fx.wisp(at + Vector3(0, 1.0, 0), Vector3.UP, true)
	else:
		_fx.splat(at, true)
	if e.elite:
		_float(_lord_world() + Vector3(0, 2.8, 0), "공짜 뽑기 +1", Color(1, 0.84, 0.42), big_number_size)
		_hud.flash(Color(1, 0.84, 0.42), 0.25)
	if e.data.boss:
		_camera.add_shake(0.7)
		_hud.flash(Color.WHITE, 0.6, 0.8)


func _float(at: Vector3, text: String, c: Color, size: int) -> void:
	var t := FloatText.new()
	t.text = text
	t.font_size = size
	t.modulate = c
	add_child(t)
	t.global_position = at


# ---------------------------------------------------------------- 갈림길과 낮 사건(13단계)

## 새벽: 밤의 것을 거두고 지도 창을 연다. 길을 고르기 전에는 규칙이 멈춰 있다(Rules.path_open).
func _on_path_offered(cards: Array) -> void:
	_move_fx.clear()
	_enemy_fx.clear()
	_clear_night_view()
	_hud.set_goal("")
	_set_light(false)
	var trail: Array = []
	var n: int = rules.path_log.size()
	for i in n:
		var e: Dictionary = rules.path_log[i]
		var z: int = int(e.zone)
		trail.append({"text": "%d구역 %s · %s" % [z + 1, data.run.zone_names[z], GOAL_NAMES.get(e.goal, "버티기")], "current": i == n - 1})
	var made: Array = []
	for c in cards:
		made.append(_path_card(c))
	var ln: Dictionary = rules.last_night
	var left: int = rules.zone_count() - rules.zone
	var heal: int = roundi(float(ln.get("heal", 0.0)))
	var head: String = "%s날이 밝았다.%s 정상까지 %d구역 — 오를 길을 고른다." % [_reward_text(ln), " 체력 +%d." % heal if heal > 0 else "", left]
	_hud.open_map("갈림길 · %d구역 %s" % [rules.zone + 1, data.run.zone_names[rules.zone]], head, trail, made)
	_capture(false)


## 지도 창 카드 하나의 글과 아이콘 id(PathMap.open).
func _path_card(c: Dictionary) -> Dictionary:
	var R := data.run
	var top: bool = rules.last_zone()
	var g: StringName = c.goal
	var goal_text: String
	match g:
		&"defend":
			goal_text = "봉화를 지킨다"
		&"hunt":
			goal_text = "우두머리를 쓰러뜨린다"
		&"siege":
			goal_text = "한쪽에서 몰려온다 · %d초" % roundi(R.siege_night)
		_:
			goal_text = "%d초를 버틴다" % roundi(R.night_length)
	return {
		"label": PATH_NAMES[clampi(R.path_hardness(g, c.rule), 0, PATH_NAMES.size() - 1)],
		"goal_icon": "goal_hunt" if top else "goal_" + String(g),
		"goal": "언덕지기" if top else GOAL_NAMES.get(g, "버티기"),
		"goal_text": "정상을 지키는 자를 쓰러뜨린다" if top else goal_text,
		"rule_icon": "" if c.rule == &"" else "rule_" + String(c.rule),
		"rule": RULE_NAMES.get(c.rule, "구역 규칙 없음"),
		"rule_text": RULE_TEXT.get(c.rule, ""),
		"reward_icon": "reward_" + String(c.reward),
		"reward": _path_reward_name(c.reward),
	}


## now면 그 낮에 받은 것(운은 "오늘").
func _path_reward_name(r: StringName, now: bool = false) -> String:
	var R := data.run
	match r:
		&"pulls":
			return "공짜 뽑기 +%d" % R.reward_pulls
		&"heal":
			return "체력 +%d" % roundi(R.reward_heal)
		&"whet":
			return "두 칸 검의 내구를 모두 채운다"
		&"luck":
			return "%s 뽑기 운 ×%s" % ["오늘" if now else "다음 낮", str(R.reward_luck)]
		&"shards":
			return "판이 끝날 때 조각 +%d" % R.reward_shards
	return ""


## 숫자 뒤의 을/를(일·삼·육·칠·팔·십·백 … 은 받침이 있다).
func _obj(n: int) -> String:
	return "%d를" % n if [2, 4, 5, 9].has(absi(n) % 10) else "%d을" % n


## 사건 앞에 섰을 때의 안내(Band).
func _event_prompt(ev: DayEvent) -> String:
	var R := data.run
	match ev.kind:
		&"smith":
			if rules.current() == null:
				return "떠돌이 대장장이 — 벼릴 검을 쥐고 있지 않다"
			return "떠돌이 대장장이 — 체력 %s 내고 쥔 검을 벼린다 · 이번 밤 피해 +%d%%" % [_obj(roundi(R.smith_cost)), roundi(R.smith_damage * 100.0)]
		&"pilgrim":
			var k: int = rules.pilgrim_slot()
			if k < 0:
				return "순례자 — 바칠 검이 없다"
			return "순례자 — %s을(를) 바치고 체력 +%d · 공짜 뽑기 +%d" % [rules.slots[k].label(), roundi(rules.max_hp() * R.pilgrim_heal), R.pilgrim_free]
		&"seer":
			return "점쟁이 — 체력 %s 내고 오늘 손잡이의 참된 조짐을 본다" % _obj(roundi(R.seer_cost))
	return EVENT_NAMES.get(ev.kind, "")


## 사건이 섰다: 형체를 그 자리에 짓는다. 저주받은 손잡이는 그 손잡이를 검게 칠하고 기운을 두른다.
func _on_event_placed(ev: DayEvent) -> void:
	_clear_event_view()
	_event = ev
	if ev.kind == &"cursed":
		var v: Node3D = _hilts.get(ev.hilt.id) if ev.hilt else null
		if v:
			EventArt.curse_hilt(v)
			_efx.aura(v)
			_cursed_view = v
		return
	var holder := Node3D.new()
	holder.name = "Event_" + String(ev.kind)
	add_child(holder)
	var w: Vector3 = Grid.cells_to_world(ev.pos)
	w.y = HillBuilder.height(w.x, w.z)
	holder.position = w
	holder.rotation.y = _yaw_to(w, _lord.position)
	_event_holder = holder
	_event_P = EventArt.build(ev.kind, holder)
	_event_t = 0.0


## -Z를 보는 몸이 from에서 to를 보게 하는 rotation.y.
func _yaw_to(from: Vector3, to: Vector3) -> float:
	var d: Vector3 = to - from
	return atan2(-d.x, -d.z) if Vector2(d.x, d.z).length() > 0.01 else 0.0


## 매 화면: 사건의 형체가 숨 쉬며 영주 쪽으로 천천히 돈다(쓰인 뒤에는 EventFx가 움직인다).
func _draw_event(delta: float) -> void:
	if _event_P.is_empty() or not is_instance_valid(_event_holder) or not is_instance_valid(_event_P.get("root")):
		return
	if _event == null or _event.used:
		return
	_event_t += delta
	EventArt.breathe(_event_P, _event_t)
	var want: float = _yaw_to(_event_holder.position, _lord.position)
	_event_holder.rotation.y = lerp_angle(_event_holder.rotation.y, want, 1.0 - exp(-2.5 * delta))


func _on_event_used(ev: DayEvent, result: Dictionary) -> void:
	var R := data.run
	match ev.kind:
		&"cursed":
			if is_instance_valid(_cursed_view):
				_efx.aura_off(_cursed_view, true)
			_camera.add_shake(0.2)
			_pull_note = "저주가 서렸다. 최대 내구가 절반이 되었고, 이번 밤 적이 더 강하다."
			return
		&"smith":
			var s: Sword = result.get("sword")
			_hud.toast("대장장이가 %s을(를) 벼렸다. 내구가 다 찼고, 이번 밤 피해 +%d%%." % [s.label() if s else "검", roundi(R.smith_damage * 100.0)])
		&"pilgrim":
			var s: Sword = result.get("sword")
			_hud.toast("순례자가 %s을(를) 받아 갔다. 체력 +%d · 공짜 뽑기 +%d." % [s.label() if s else "검", roundi(float(result.get("heal", 0.0))), int(result.get("free", 0))])
			_hud.flash(Color(1.0, 0.9, 0.7), 0.2)
		&"seer":
			_hud.toast("점쟁이가 등불을 들었다. 오늘 손잡이의 참된 조짐이 보인다.")
	if not _event_P.is_empty():
		_efx.used(_event_P)
		_efx.vanish(_event_P)


## 사건이 사라졌다. 쓰지 않고 밤이 왔으면 형체가 흩어지고 손잡이의 기운이 걷힌다.
func _on_event_gone(ev: DayEvent) -> void:
	if ev.used:
		return
	if ev.kind == &"cursed":
		if is_instance_valid(_cursed_view):
			_efx.aura_off(_cursed_view, false)
		_cursed_view = null
	elif not _event_P.is_empty():
		_efx.vanish(_event_P)
	_event = null


## 낮이 바뀌거나 판이 끝날 때: 사건의 형체와 효과를 거둔다.
func _clear_event_view() -> void:
	_efx.clear()
	if is_instance_valid(_event_holder):
		_event_holder.queue_free()
	_event_holder = null
	_event_P = {}
	_cursed_view = null
	_event = null


# ---------------------------------------------------------------- 그리기

func _sync_hilts() -> void:
	for h in rules.hilts:
		if _hilts.has(h.id):
			continue
		var v := HiltView.new()
		v.setup(rules, h)
		add_child(v)
		_hilts[h.id] = v


func _sync_altar() -> void:
	if _altar_view:
		_altar_view.queue_free()
		_altar_view = null
	if rules.altar:
		_altar_view = AltarView.new()
		_altar_view.altar = rules.altar
		add_child(_altar_view)


## 규칙의 적 목록과 맞춘다: 새로 나온 적은 만들고, 없어진 적은 쓰러지는 모습을 보여 주고 지운다.
func _sync_enemies(alpha: float, delta: float) -> void:
	var alive := {}
	for e in rules.enemies:
		alive[e.id] = true
		if not _enemies.has(e.id):
			var v := EnemyView.new()
			v.setup(e)
			add_child(v)
			_enemies[e.id] = v
	for id in _enemies.keys():
		var v: EnemyView = _enemies[id]
		if not alive.has(id) or v.enemy.dead:
			_enemies.erase(id)
			v.die()
			_dying.append(v)
		else:
			v.draw(alpha, delta)
	for i in range(_dying.size() - 1, -1, -1):
		if _dying[i].draw(alpha, delta):
			_dying[i].queue_free()
			_dying.remove_at(i)


func _set_light(night: bool, instant: bool = false) -> void:
	var env := _env.environment
	var t: float = 0.0 if instant else light_change_time
	var tw := create_tween().set_parallel()
	tw.tween_property(_sun, "light_energy", night_sun if night else day_sun, t)
	tw.tween_property(_sun, "light_color", night_sun_color if night else day_sun_color, t)
	tw.tween_property(env, "fog_light_color", night_fog if night else day_fog, t)
	env.ambient_light_color = night_ambient_color
	tw.tween_property(env, "ambient_light_sky_contribution", 0.15 if night else 1.0, t)
	tw.tween_property(env, "ambient_light_energy", night_ambient if night else day_ambient, t)
	tw.tween_property(env, "background_color", Color(0.01, 0.015, 0.03) if night else Color(0.06, 0.08, 0.12), t)
	tw.tween_property(_lord.torch, "light_energy", torch_energy if night else 0.0, t)
	if HillBuilder.sky_material:
		tw.tween_property(HillBuilder.sky_material, "shader_parameter/night", 1.0 if night else 0.0, t)


## 언덕 꼭대기(싸움터)와 둘레의 땅, 하늘, 바위, 꽂힌 검. 에셋을 바꿀 때는 HillBuilder만 고친다.
func _build_world() -> void:
	HillBuilder.build(self, _env.environment, data.forms)
	_sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)


## 검의 기억 단계를 넘었다: 한 줄과 낮은 울림(올라가는 소리 없음). 피해 배수는 다음에 쥐고 나갈 때부터.
func _memory_toast(d: SwordData, tier: int) -> void:
	if tier <= 0 or d == null:
		return
	_hud.toast("%s · 벤 적 %d" % [meta.memory_title(d), int(Meta.MEMORY[tier - 1][0])])
	_sfx.play(&"thump", Grid.cells_to_world(rules.lord.pos), -6.0, 0.7)
