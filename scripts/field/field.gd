extends Node3D
## 마을 밖 들판(16단계 탐험, 17단계 싸움). 걷고 구르며 찾고, 무리를 만나면 싸운다.
## 규칙은 Rules(들판 모드)가 돌리고(싸움터 크기만 들판으로), 막힌 곳은 화면 쪽에서 밀어낸다.
## 높이는 FieldBuilder.walk_height를 따라 영주와 적을 그린다. 보상과 읽음은 Meta에 저장한다.
## 마을 북문에서 고른 검(Meta.carry_sword)은 부러지지 않는 검으로 칸 0에 쥔다. 쓰러지면 잃는 것 없이 마을 북문 앞에서 깬다.
## 낮밤(29단계): Rules의 들판 시계(Meta.field_clock에서 이어 가고 떠날 때 저장)를 받아 해·하늘·환경광·안개·영주 횃불을 천천히 바꾸고, 해 질 때와 밝을 때 한 줄을 띄운다.
## 날이 밝으면 Meta.packs_cleared를 비운다(Rules가 쓰러뜨린 낮 무리를 다시 세운다).
## 떠도는 사람(34단계): 아직 영입하지 않은 사람 하나가 후보 자리에 서 있다(Meta.wanderer). E로 말을 걸고, 조건이 맞으면 E로 데려간다(마을에 선다).
## 날이 밝으면 다른 사람(또는 같은 사람이 다른 자리)으로 바뀐다.
## 들판 지도(38단계): M으로 지도 창(FieldMap, 게임을 멈춘다)을 연다. 걸으면 영주 둘레가 밝혀진다(FieldLayout.SEEN_TICKS틱마다 Meta.see_field).
## 탈 검(39단계 말을 2026-11-21에 바꿈): H로 부르면(덤비는 적이 없을 때) 막힘을 피한 자리에서 날아와 곁에 뜬다(RideSwordView, 규칙은 Horse 그대로). 곁에서 E로 올라서고, 탄 채 H나 E로 내린다.
## 탄 채 맞으면 떨어진다(규칙). 탄 동안 카메라는 조금 멀고 높게, 발굽 소리와 흙먼지. 말은 들판에만 있고 저장하지 않는다.

const LORD_SCENE: PackedScene = preload("res://scenes/lord/lord.tscn")
const VILLAGE_PATH: String = "res://scenes/lobby/lobby.tscn"
const RUN_PATH: String = "res://scenes/world/main.tscn"
const CRYPT_PATH: String = "res://scenes/crypt/crypt.tscn"

@export var reach: float = 2.0
@export var max_ticks_per_frame: int = 8

var data: GameData
var meta: Meta
var rules: Rules
var _acc: float = 0.0
var _want_dash: bool = false
var _want_jump: bool = false
## 검 바꾸기(검 보관집이 있으면 칸이 여럿): Rules.SWAP_NEXT(Q) 또는 칸 번호, -1이면 없음.
var _want_swap: int = -1
var _lord: Node3D
var _near: String = ""
var _rects: Array[Rect2] = []
var _circles: Array = []
## 낮은 막힘(30단계): 공중이면 지나간다(Blockers).
var _low_rects: Array[Rect2] = []
var _low_circles: Array = []
var _props: Dictionary = {}
## 지금 쥔 검 번호(0 = 맨손). 쓰러지면 이것을 떨군다.
var _held_id: int = 0
## 떨군 검의 모양(꽂힌 검·빛·불씨). 주우면 지운다.
var _dropped_node: Node3D
## 들판 화면(곳 이름, 낮밤, 쥔 검, 나침반).
var _field_hud: FieldHud
var _area: StringName = &""
var _shown: Dictionary = {}
var _reading: String = ""
var _creatures := FieldCreatures.new()
var _env: Environment
var _fog_base: float = 0.0
var _fog_color: Color = Color.WHITE
var _fog_k: float = 0.0   ## 안개 늪의 짙은 안개 정도(0~1, 늪에 들어서면 천천히 오르고 나가면 내린다. 화면만)
var _night_k: float = -1.0   ## 마지막으로 맞춘 밤의 정도(바뀔 때만 해·하늘을 다시 맞춘다)
var _ambient_day: Color = Color.WHITE
var _ambient_day_energy: float = 0.45
var _sky_tint: Color = Color(1.0, 0.8, 0.68)   ## 낮의 하늘빛(밤·해질녘으로 섞는다)
var _want_attack: bool = false
var _want_hook: bool = false
var _over: bool = false
var _enemies: Dictionary = {}
var _dying: Array[EnemyView] = []
var _fx := HitFx.new()
var _pfx := PowerFx.new()
var _move_fx := MoveFx.new()
var _enemy_fx := EnemyFx.new()
## 떠도는 사람(34단계): 몸(VillageProps 주민 모양), 곁의 작은 모닥불 빛, 선 자리(칸), 막힘 원, 말 상대 id와 말 단계(0 없음, 1 인사, 2 조건, 3 영입한 뒤).
var _wander: Node3D = null
var _wander_P: Dictionary = {}
var _wander_fire: OmniLight3D = null
var _wander_at: Vector2 = Vector2.ZERO
var _wander_circle: Array = []
var _wander_id: String = ""
var _wander_step: int = 0
var _wt: float = 0.0
var _flicker := RandomNumberGenerator.new()   ## 모닥불 흔들림(꾸밈, 규칙과 따로)
var _seen_t: int = 0   ## 38단계: 다음 밝힘까지 남은 틱
var _horse: RideSwordView   ## 탈 검의 몸(규칙 이름은 39단계 말 그대로 horse)

@onready var _camera: Camera3D = $Camera
@onready var _sfx: Sfx = $Sfx
@onready var _hud: LobbyHud = $UI
@onready var _sun: DirectionalLight3D = $Sun


func _ready() -> void:
	data = GameData.load_default()
	meta = Meta.load_or_new()
	meta.fix_sheath(data)
	meta.ensure_glints()
	meta.ensure_mat_spots()
	meta.ensure_captives()
	meta.ensure_wanderer()   # 34단계: 아무도 없으면 한 사람이 선다
	meta.save()
	rules = Rules.new(data, int(Time.get_unix_time_from_system()))
	Grid.size = FieldLayout.SIZE   # Rules가 싸움터 크기로 영주를 가둔다: 들판 크기로
	rules.memory = meta.memory_table()
	rules.bonus_hp = meta.recruit_hp()   # 34단계: 떠돌이 약초꾼을 영입했으면 들판 체력 +
	rules.start_field(meta.field_clock)   # 시계는 지난번 떠난 데서 이어 간다(밤이면 밤 무리도 서 있다)
	rules.spawn_packs(meta.packs_cleared)   # 이미 쓰러뜨린 무리는 안 생긴다
	if not meta.boss_down:
		rules.spawn_field_boss()   # 이번 판에 쓰러뜨렸으면 다시 서지 않는다(판이 끝나면 다시 선다)
	rules.spawn_chiefs(meta.chiefs_down)   # 32단계 곳마다 우두머리: 이번 판에 쓰러뜨린 것은 안 선다
	rules.allow_horse = true   # 39단계: 말은 들판에서만
	rules.lord.pos = FieldLayout.START
	if Meta.wake_at_crypt:   # 지하 무덤에서 나왔거나 쓰러졌다: 무덤 입구 앞에서 깬다
		Meta.wake_at_crypt = false
		rules.lord.pos = FieldLayout.CRYPT_WAKE
	rules.lord.prev_pos = rules.lord.pos
	meta.see_field(rules.lord.pos)   # 38단계: 깬 자리 둘레는 처음부터 보인다
	_hud.setup(data, meta)
	_build_dropped()
	_field_hud = FieldHud.make(_hud, data, meta, rules, _camera)
	if Meta.wake_note != "":   # 무덤에서 쓰러져 검을 떨궜다
		_hud.toast(Meta.wake_note)
		Meta.wake_note = ""
	var env: Environment = ($Environment as WorldEnvironment).environment
	HillBuilder.apply_sky(env, Color(1.0, 0.8, 0.68), 0.75)
	_env = env
	_ambient_day = env.ambient_light_color
	_ambient_day_energy = env.ambient_light_energy
	_fog_base = env.fog_density
	_fog_color = env.fog_light_color
	var blockers: Dictionary = FieldBuilder.build(self, env)
	if not meta.has_built(&"tower"):   # 망루를 짓기 전에는 까마귀 고개로 가는 길이 막혀 있다(마을 키우기 5단계)
		for r in FieldLayout.PASS_BARRICADES:
			FieldBuilder.barricade(self, r)
			(blockers.rects as Array).append(r)
	_rects.assign(blockers.rects)
	_circles = blockers.circles
	_low_rects.assign(blockers.low_rects)
	_low_circles = blockers.low_circles
	rules.set_blockers(blockers.rects, blockers.circles, blockers.low_rects, blockers.low_circles)   # 37단계: 적도 같은 표로 막힘을 돌아온다
	HillBuilder.setup(Vector2(FieldLayout.SIZE) * Grid.CELL)   # 적의 몸이 들판을 싸움터 안으로 본다(비탈에서 올라오지 않는다)
	_build_props()
	_build_wanderer()
	add_child(_creatures)
	_lord = LORD_SCENE.instantiate()
	_lord.setup(rules)
	add_child(_lord)
	_horse = RideSwordView.new()
	_horse.setup(rules)
	_horse.height_of = FieldBuilder.walk_height
	add_child(_horse)
	_lord.horse_view = _horse
	var H: HorseData = data.horse
	_camera.ride_far = H.camera_far
	_camera.ride_up = H.camera_up
	_lord.torch.light_energy = FieldLayout.FIELD_TORCH_DAY   # 밤이 오면 _light가 켠다
	add_child(_fx)
	_pfx.setup(rules)
	add_child(_pfx)
	add_child(_move_fx)
	_move_fx.setup(rules)
	_move_fx.height_of = FieldBuilder.walk_height   # 땅 자국·흙먼지(내려앉기 포함)가 들판의 땅 위에
	add_child(_enemy_fx)
	_enemy_fx.setup(rules, _enemy_parts)
	_enemy_fx.height_of = FieldBuilder.walk_height   # 땅의 빛·먼지가 들판의 땅 위에 뜬다
	_hold_sword()
	rules.lord_swung.connect(func(big: bool) -> void: _sfx.play(&"swish_big" if big else &"swish", _lord.position, -2.0 if big else -6.0))
	rules.lord_dashed.connect(func() -> void:
		_sfx.play(&"dash", _lord.position, -6.0)
		_camera.kick(4.0))
	rules.lord_landed.connect(func(_at: Vector2) -> void: _sfx.play(&"land", _lord.position, -4.0))
	rules.horse_called.connect(func() -> void: _sfx.play(&"draw", _lord.position, -3.0, 0.8))
	rules.horse_mounted.connect(func() -> void: _sfx.play(&"thump", _lord.position, -12.0, 1.4))
	rules.horse_dismounted.connect(_on_dismounted)
	rules.lord_hooked.connect(func(_e: Enemy) -> void:
		_sfx.play(&"draw", _lord.position, -2.0, 1.25)
		_camera.kick(10.0))
	rules.lord_hurt.connect(_on_lord_hurt)
	rules.enemy_hit.connect(_on_enemy_hit)
	rules.enemy_died.connect(_on_enemy_died)
	rules.pack_cleared.connect(_on_pack_cleared)
	rules.field_boss_slain.connect(_on_boss_slain)
	rules.chief_slain.connect(_on_chief_slain)
	rules.chief_woke.connect(_on_chief_woke)
	rules.field_dusk.connect(_on_dusk)
	rules.field_dawn.connect(_on_dawn)
	rules.enemy_act.connect(_on_enemy_act)
	rules.run_ended.connect(_on_down)
	rules.move_area.connect(func(_m: StringName, info: Dictionary) -> void: _sfx.play(&"thump", Grid.cells_to_world(info.get("at", rules.lord.pos)), -6.0, 0.8))
	_camera.target = Grid.cells_to_world(rules.lord.pos)
	_camera.yaw = 0.0
	_camera.snap()
	_light(0.0, true)
	_capture(true)
	WebQuality.apply(self, env, _sun, _camera)   # 웹판에서만 가볍게
	FieldMap.prepare()   # 38단계: 지도의 땅 그림(세션에 한 번, 첫 M이 멈칫하지 않게)


func _build_props() -> void:
	for id in FieldLayout.CACHES:
		if not meta.field_found.has(id):
			_props[id] = FieldBuilder.cache(self, id)
		else:
			var n := FieldBuilder.cache(self, id)
			FieldBuilder.open_cache(n)
			_props[id] = n
	for id in FieldLayout.STONES:
		var n := FieldBuilder.stone(self, id)
		if meta.lore_read.has(id):
			FieldBuilder.read_stone(n)
		_props[id] = n
	for i in meta.glints:
		_props["glint_%d" % i] = FieldBuilder.glint(self, i)
	for i in meta.mat_spots:
		_props["mat_%d" % i] = FieldBuilder.mat_spot(self, i)
	for pk in meta.captive_packs:
		if meta.captive_waiting(pk):
			_props["captive_" + pk] = FieldBuilder.captive(self, pk)


func _capture(on: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on and _camera.third() else Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_camera.look(mm.relative)
	var k := event as InputEventKey
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and _camera.third() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_capture(true)
	if event.is_action_pressed("dash"):
		_want_dash = true
	if event.is_action_pressed("jump"):
		_want_jump = true
	if event.is_action_pressed("attack"):
		_want_attack = true
	if event.is_action_pressed("hook"):
		_want_hook = true
	if event.is_action_pressed("pull"):
		_interact()
	if rules.slots.size() > 1:
		if event.is_action_pressed("swap"):
			_want_swap = Rules.SWAP_NEXT
		for sk in mini(4, rules.slots.size()):
			if event.is_action_pressed("slot_%d" % (sk + 1)):
				_want_swap = sk
	if event.is_action_pressed("map") and not _over:
		open_map()
	if event.is_action_pressed("horse"):
		horse_key()
	if k and k.pressed and not k.echo:
		if k.physical_keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif k.physical_keycode == KEY_V:
			_camera.toggle_mode()
			_capture(true)


func _physics_process(delta: float) -> void:
	_acc += delta
	var n: int = 0
	while _acc >= rules.dt and n < max_ticks_per_frame:
		var inp := LordInput.new()
		inp.move = _camera.relative_move(Input.get_vector("move_left", "move_right", "move_up", "move_down"))
		inp.dash = _want_dash
		inp.jump = _want_jump
		inp.swap_to = _want_swap
		inp.attack = Input.is_action_pressed("attack") or _want_attack
		inp.hook = _want_hook
		if _camera.third():
			if inp.attack or inp.hook:
				inp.aim_valid = true
				inp.aim = rules.lord.pos + _camera.forward_cells() * 3.0
			elif inp.move.length() > 0.1:
				inp.aim_valid = true
				inp.aim = rules.lord.pos + inp.move
		else:
			var g: Variant = _camera.ground_point(get_viewport().get_mouse_position())
			if g != null:
				inp.aim_valid = true
				inp.aim = Grid.world_to_cells(g)
		rules.step(inp)
		rules.lord.pos = _push_out(rules.lord.pos, rules.lord.airborne(), data.horse.body_r if rules.lord.riding else Blockers.BODY)
		if rules.horse.waiting():   # 39단계: 내린 말도 나무·벽을 뚫지 않는다
			rules.horse.pos = _push_out(rules.horse.pos, false, data.horse.body_r)
		_seen_t -= 1
		if _seen_t <= 0:
			_seen_t = FieldLayout.SEEN_TICKS
			meta.see_field(rules.lord.pos)
		_want_dash = false
		_want_jump = false
		_want_swap = -1
		_want_attack = false
		_want_hook = false
		_acc -= rules.dt
		n += 1
	if n == max_ticks_per_frame:
		_acc = 0.0


func _process(delta: float) -> void:
	var alpha: float = clampf(_acc / rules.dt, 0.0, 1.0)
	_horse.draw(alpha, delta)   # 39단계: 말 먼저(영주가 안장 높이를 읽는다)
	_camera.ride = move_toward(_camera.ride, 1.0 if rules.lord.riding else 0.0, delta / maxf(data.horse.camera_blend, 0.01))
	_lord.draw(alpha, delta)
	_lord.position.y = FieldBuilder.walk_height(_lord.position.x, _lord.position.z)
	_camera.target = _lord.position
	_move_fx.draw(alpha)
	_enemy_fx.draw(alpha)
	_sync_enemies(alpha, delta)
	_hud.set_hp(rules.lord.hp, rules.max_hp())
	_boss_bar()
	_creatures.step(delta, _lord.position)
	_light(delta)
	_animate_wanderer(delta)
	var p: Vector2 = rules.lord.pos
	var a: StringName = FieldLayout.area_at(p)
	if a != _area:
		_area = a
		if not _shown.has(a):
			_shown[a] = true
			_hud.area_title(FieldLayout.AREA_NAMES[a])
	_near = ""
	if rules.lord.riding:   # 39단계: 탄 채로는 들를 곳 안내를 내린다(E는 내리기)
		_hud.set_prompt("E", "")
		return
	var best_d: float = reach
	var spots: Dictionary = _spots()
	for key in spots:
		var d: float = p.distance_to(spots[key])
		if d < best_d:
			best_d = d
			_near = key
	if _reading != "" and _near != _reading:
		_end_read()
	if _reading != "":
		_hud.set_prompt("E", "")   # 읽거나 말하는 동안은 안내 띠를 내린다(말 띠와 겹치지 않게)
		return
	_hud.set_prompt("E", _prompt(_near) if _near != "" else "")


## 낮밤(29단계)과 안개 늪(20단계)을 한 번에 섞는다. 시계의 밤의 정도(FieldLayout.night_amount)로 해 기울기·빛 세기와 빛깔·하늘·환경광·안개·영주 횃불을 바꾸고,
## 영주가 늪에 있으면 그 위에 안개를 천천히 짙게 한다(규칙과 상관없는 화면, 나가면 되돌린다). now가 참이면 안개 늪의 변화도 바로 맞춘다.
func _light(delta: float, now: bool = false) -> void:
	var k: float = FieldLayout.night_amount(rules.field_clock)
	var want: float = 1.0 if FieldLayout.area_at(rules.lord.pos) == &"marsh" else 0.0
	if now:
		_fog_k = want
	if is_equal_approx(k, _night_k) and is_equal_approx(_fog_k, want):
		return
	_fog_k = move_toward(_fog_k, want, delta / FieldLayout.MARSH_FOG_TIME)
	if not is_equal_approx(k, _night_k):
		_night_k = k
		_apply_day_night(k)
	var mk: float = smoothstep(0.0, 1.0, _fog_k)
	var dens: float = _fog_base * lerpf(1.0, FieldLayout.FIELD_FOG_NIGHT_MULT, k)
	var col: Color = _fog_color.lerp(FieldLayout.FIELD_FOG_NIGHT, smoothstep(0.0, 1.0, k))
	col = col.lerp(FieldLayout.FIELD_SUN_COLOR_DUSK * 0.45, sin(k * PI) * 0.5)
	_env.fog_density = lerpf(dens, dens * FieldLayout.MARSH_FOG_MULT, mk)
	_env.fog_light_color = col.lerp(FieldLayout.MARSH_FOG_COLOR.darkened(0.75 * k), mk)


## k(0 낮 ~ 1 밤)에 맞게 해, 하늘, 환경광, 횃불을 바꾼다. 해질녘(k 0.5 근처)은 해가 낮고 붉다.
func _apply_day_night(k: float) -> void:
	var E: Vector3 = FieldLayout.FIELD_SUN_ENERGY
	_sun.light_energy = lerpf(E.x, E.y, smoothstep(0.0, 0.55, k)) if k < 0.55 else lerpf(E.y, E.z, smoothstep(0.55, 1.0, k))
	var c: Color = FieldLayout.FIELD_SUN_COLOR_DAY.lerp(FieldLayout.FIELD_SUN_COLOR_NIGHT, smoothstep(0.4, 1.0, k))
	_sun.light_color = c.lerp(FieldLayout.FIELD_SUN_COLOR_DUSK, sin(k * PI) * 0.7)
	var T: Vector3 = FieldLayout.FIELD_SUN_TILT
	var tilt: float = lerpf(T.x, T.y, smoothstep(0.0, 0.5, k)) if k < 0.5 else lerpf(T.y, T.z, smoothstep(0.5, 1.0, k))
	_sun.rotation_degrees = Vector3(tilt, FieldLayout.FIELD_SUN_YAW.x if k < 0.5 else FieldLayout.FIELD_SUN_YAW.y, 0.0)
	if HillBuilder.sky_material:
		HillBuilder.sky_material.set_shader_parameter("night", k)
		var tint: Color = _sky_tint.lerp(FieldLayout.FIELD_SKY_TINT_NIGHT, smoothstep(0.3, 1.0, k))
		HillBuilder.sky_material.set_shader_parameter("tint", tint.lerp(FieldLayout.FIELD_SKY_TINT_DUSK, sin(k * PI) * 0.6))
	_env.ambient_light_color = _ambient_day.lerp(FieldLayout.FIELD_AMBIENT_NIGHT, k)
	_env.ambient_light_energy = lerpf(_ambient_day_energy, FieldLayout.FIELD_AMBIENT_NIGHT_ENERGY, k)
	_env.ambient_light_sky_contribution = lerpf(1.0, FieldLayout.FIELD_AMBIENT_NIGHT_SKY, k)
	_lord.torch.light_energy = lerpf(FieldLayout.FIELD_TORCH_DAY, FieldLayout.FIELD_TORCH_NIGHT, smoothstep(0.2, 0.9, k))


## 해가 졌다: 밤 소리(하늘과 왼쪽 위 해·달이 보여 주니 글은 없다). 밤 무리는 Rules가 세웠다.
func _on_dusk() -> void:
	_sfx.play(&"night", _lord.position, -2.0)


## 날이 밝았다(글 없음). 쓰러뜨린 낮 무리는 Rules가 다시 세웠으니 기록(Meta.packs_cleared)도 맞춘다(영주 곁이라 건너뛴 것만 남는다).
## 상자·조각·보스·무덤은 판이 끝날 때까지 그대로.
func _on_dawn() -> void:
	meta.packs_cleared = rules.field_cleared_ids()
	meta.place_wanderer()   # 34단계: 새벽마다 다른 사람이 선다
	if _reading == "wanderer":
		_end_read()
	_build_wanderer()
	_saved()


## 38단계: 들판 지도 창을 연다(게임을 멈춘다, M·Esc로 닫는다). 여는 김에 가 본 곳을 저장한다.
func open_map() -> FieldMap:
	if _hud.get_node_or_null("FieldMap"):
		return null
	meta.see_field(rules.lord.pos)
	_saved()
	var m := FieldMap.make(_hud, data, meta, rules, _circles, rules.horse.pos if rules.horse.waiting() and not rules.lord.riding else Vector2.INF)
	m.open()
	return m


# ---------------------------------------------------------------- 말 (39단계)

## H: 탔으면 내리고, 아니면 부른다. 덤비는 적이 있으면 띠로 알린다(규칙이 막는다).
func horse_key() -> void:
	if _over:
		return
	if rules.lord.riding:
		rules.dismount()
		return
	var why: StringName = rules.call_horse(_horse_from())
	if why == &"fight":
		_hud.toast("덤벼드는 적이 있어 탈 검을 부를 수 없다")


## 말이 나타날 자리: 영주 뒤에서 좌우로 30°씩 돌려 가며 call_from칸(못 찾으면 절반, 1/4) 떨어진 들판 안에서,
## 그 자리에서 영주까지 곧은 길에 막힘(낮은 것도: 오는 말은 뛰지 않는다)이 없는 곳. 없으면 INF(규칙이 영주 뒤에 세우고, 막혀서 못 오면 곁에 선다).
func _horse_from() -> Vector2:
	var H: HorseData = data.horse
	var me: Vector2 = rules.lord.pos
	var near_rects: Array = []
	var near_circles: Array = []
	var span: float = H.call_from + 3.0
	for list in [_rects, _low_rects]:
		for r: Rect2 in list:
			if r.grow(span).has_point(me):
				near_rects.append(r)
	for list in [_circles, _low_circles]:
		for c in list:
			if (c[0] as Vector2).distance_to(me) < span + float(c[1]):
				near_circles.append(c)
	var inside := Rect2(Vector2(4, 4), Vector2(FieldLayout.SIZE) - Vector2(8, 8))
	for dist in [H.call_from, H.call_from * 0.5, H.call_from * 0.25]:
		for k in 12:
			var turn: float = floorf((k + 1) / 2.0) * (PI / 6.0) * (1.0 if k % 2 == 0 else -1.0)
			var p: Vector2 = me - Vector2.from_angle(rules.lord.face + turn) * float(dist)
			if inside.has_point(p) and _line_clear(p, me, H.body_r, near_rects, near_circles):
				return p
	return Vector2.INF


func _line_clear(a: Vector2, b: Vector2, r: float, rects: Array, circles: Array) -> bool:
	var n: int = maxi(1, ceili(a.distance_to(b) / 0.5))
	for i in n + 1:
		var q: Vector2 = a.lerp(b, float(i) / n)
		if q.distance_to(b) < 1.2:
			break
		if Blockers.inside(q, rects, circles, [], [], false, r):
			return false
	return true


## 내렸다: 떨어졌으면(맞아서) 흔들림과 쿵 소리, 그냥 내렸으면 작은 발소리.
func _on_dismounted(fell: bool) -> void:
	if fell:
		_camera.add_shake(0.35)
		_sfx.play(&"thump", _lord.position, -3.0, 0.85)
		_sfx.play(&"land", _lord.position, -2.0)
	else:
		_sfx.play(&"land", _lord.position, -8.0)


func _spots() -> Dictionary:
	var s := {"gate": FieldLayout.GATE, "trail": FieldLayout.TRAILHEAD, "crypt": FieldLayout.CRYPT_DOOR}
	if not meta.dropped.is_empty():
		s["dropped"] = meta.dropped_at()
	if rules.horse.waiting():
		s["horse"] = rules.horse.pos
	if _wander != null:
		s["wanderer"] = _wander_at
	for id in FieldLayout.CACHES:
		if not meta.field_found.has(id):
			s[id] = FieldLayout.CACHES[id][0]
	for id in FieldLayout.STONES:
		s[id] = FieldLayout.STONES[id][0]
	for i in meta.glints:
		s["glint_%d" % i] = FieldLayout.GLINTS[i]
	for i in meta.mat_spots:
		s["mat_%d" % i] = FieldLayout.MATS[i][0]
	for pk in meta.captive_packs:
		if meta.captive_waiting(pk):
			s["captive_" + pk] = Vector2(FieldLayout.PACKS[pk].at) + Vector2(1.2, 0.8)
	return s


func _prompt(key: String) -> String:
	if key == "gate":
		return "마을로 돌아간다"
	if key == "trail":
		return "언덕으로 오른다"
	if key == "crypt":
		return "지하 무덤으로 내려간다"
	if key == "dropped":
		return "떨군 검을 줍는다"
	if key == "horse":
		return "검에 올라선다"
	if key == "wanderer":
		return "%s에게 말을 건다" % FieldLayout.WANDERERS[_wander_id].name
	if key.begins_with("cache"):
		return "유품을 연다"
	if key.begins_with("stone"):
		return "비석을 읽는다"
	if key.begins_with("captive_"):
		if meta.housing(data) == 0:
			return "마을에 지낼 집이 없다"
		return "풀어 준다" if meta.has_room(data) else "오두막이 다 찼다"
	if key.begins_with("mat_"):
		return {&"wood": "나무를 벤다", &"stone": "돌을 깬다", &"iron": "녹슨 쇠를 거둔다"}[FieldLayout.MATS[int(key.substr(4))][1]]
	return "쇳조각을 줍는다"


func _interact() -> void:
	if _over:
		return
	if rules.lord.riding:   # 39단계: 탄 채 E는 내리기
		rules.dismount()
		return
	if _reading == "wanderer":
		_wander_next()
		return
	if _reading != "":
		_end_read()
		return
	if _near == "gate":
		_leave(VILLAGE_PATH)
	elif _near == "trail":
		var starts: Array[int] = meta.start_zones(data)
		if starts.size() > 1:   # 마을 단계가 오르면 더 깊은 구역부터 오를 수 있다(마을 키우기 5단계)
			_hud.open_climb(starts, meta.start_zone, func(z: int) -> void:
				meta.start_zone = z
				_leave(RUN_PATH))
		else:
			meta.start_zone = 1
			_leave(RUN_PATH)
	elif _near == "dropped":
		var id: int = meta.pick_dropped()
		if _dropped_node:
			_dropped_node.queue_free()
			_dropped_node = null
		var d: SwordData = data.sword_by_id(id)
		_sfx.play(&"thump", Grid.cells_to_world(rules.lord.pos), -4.0, 1.3)
		_hud.toast("떨군 검을 되찾았다: %s" % (d.display_name if d else "?"))
		_saved()
	elif _near == "horse":
		rules.mount()
	elif _near == "wanderer":
		_wander_talk()
	elif _near == "crypt":
		meta.save()   # 쥔 검(Meta.carry_sword)은 그대로 무덤으로 가져간다
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file(CRYPT_PATH)
	elif _near.begins_with("cache"):
		var got: int = meta.field_open(_near, FieldLayout.CACHES[_near][1])
		if got > 0:
			FieldBuilder.open_cache(_props[_near])
			_sfx.play(&"thump", _props[_near].position, -3.0)
			_hud.toast("유품에서 조각 %d개를 얻었다" % got)
			_saved()
	elif _near.begins_with("stone"):
		var info: Array = FieldLayout.STONES[_near]
		_reading = _near
		_hud.say(info[1], info[2], true)
		var pay: int = 0
		if not meta.lore_read.has(_near):
			pay = meta.read_stone(_near)
			FieldBuilder.read_stone(_props[_near])
			_saved()
		if pay > 0:
			_hud.toast("비석을 모두 읽었다. 조각 %d개" % pay)
	elif _near.begins_with("captive_"):
		var r: Dictionary = meta.free_captive(_near.substr(8), data)
		if not r.is_empty():
			var node: Node3D = _props.get(_near)
			if node:
				FieldBuilder.take_glint(node)
			_props.erase(_near)
			_sfx.play(&"draw", _lord.position, -8.0, 1.2)
			_hud.got_resident()   # 오른쪽 아래 주민 수 위에 +1
			_hud.toast("%s · 마을로 간다" % r.name)
			_saved()
	elif _near.begins_with("mat_"):
		var got: Array = meta.take_mat(int(_near.substr(4)))
		if int(got[1]) > 0:
			FieldBuilder.take_glint(_props[_near])
			_props.erase(_near)
			_sfx.play(&"thump", _lord.position, -4.0, 0.8)
			_hud.got_mat(got[0], int(got[1]))   # 오른쪽 아래 숫자 위에 +N(글 알림은 없다)
			_saved()
	elif _near.begins_with("glint"):
		var i: int = int(_near.substr(6))
		var got: int = meta.take_glint(i)
		if got > 0:
			FieldBuilder.take_glint(_props[_near])
			_props.erase(_near)
			_sfx.play(&"thump", _lord.position, -10.0, 1.6)
			_hud.toast("쇳조각 조각 %d개" % got)
			_saved()


# ---------------------------------------------------------------- 떠도는 사람 (34단계)

## Meta.wanderer를 그 자리에 세운다(있던 몸은 치운다). 마을 쪽(들판 시작 자리)을 보고 서고, 곁에 꺼져 가는 작은 모닥불.
func _build_wanderer() -> void:
	if _wander != null:
		_wander.queue_free()
		_circles.erase(_wander_circle)
		_wander = null
		_wander_P = {}
		_wander_fire = null
	_wander_id = meta.wanderer
	if _wander_id == "":
		return
	_wander_at = FieldLayout.WANDERER_SPOTS[meta.wanderer_at].at
	var p: Vector3 = Grid.cells_to_world(_wander_at)
	p.y = FieldBuilder.walk_height(p.x, p.z)
	var dir: Vector2 = FieldLayout.START - _wander_at
	_wander = VillageBuilder.place(self, p, VillageBuilder.facing_to(dir.normalized() if dir.length() > 0.5 else Vector2.DOWN) + PI)
	_wander_P = VillageProps.villager(StringName(_wander_id), _wander)
	# 모닥불: 돌 몇 개와 그을린 장작, 낮게 깔리는 불빛(밤에 멀리서 보인다). 앞은 -Z(몸이 보는 쪽)
	var fire := Node3D.new()
	fire.position = Vector3(0.7, 0.0, -0.9)
	_wander.add_child(fire)
	var stone := VillageBuilder.plain(Color(0.25, 0.24, 0.23), 0.95)
	for i in 6:
		var a: float = TAU * i / 6.0
		VillageBuilder.box(fire, Vector3(0.16, 0.1, 0.12), Vector3(cos(a) * 0.3, 0.05, sin(a) * 0.3), stone, Vector3(0.0, -a, 0.0))
	var wood := VillageBuilder.plain(Color(0.12, 0.08, 0.05), 0.9)
	for k in 3:
		VillageBuilder.box(fire, Vector3(0.06, 0.06, 0.45), Vector3(0.0, 0.07, 0.0), wood, Vector3(0.0, k * 1.05, 0.12))
	VillageBuilder.ball(fire, 0.09, Vector3(0.0, 0.12, 0.0), VillageBuilder.glow(Color(1.0, 0.45, 0.15), 3.0), Vector3(1.0, 0.6, 1.0))
	_wander_fire = OmniLight3D.new()
	_wander_fire.light_color = Color(1.0, 0.55, 0.25)
	_wander_fire.omni_range = 6.0
	_wander_fire.light_energy = 1.2
	_wander_fire.position = Vector3(0.0, 0.5, 0.0)
	fire.add_child(_wander_fire)
	_wander_circle = [_wander_at, 0.4]
	_circles.append(_wander_circle)
	_flicker.seed = hash(_wander_id)


## 숨 쉬고, 영주가 가까우면 고개를 돌리고, 말하는 동안 손짓. 모닥불은 흔들린다.
func _animate_wanderer(delta: float) -> void:
	if _wander == null or _wander_P.is_empty():
		return
	_wt += delta
	EventArt.breathe(_wander_P, _wt)
	var close: bool = _wander.position.distance_to(_lord.position) < 10.0
	VillageProps.look_at(_wander_P, _wander, _lord.position + Vector3(0, 1.5, 0), 1.0 if close else 0.0)
	if _wander_step > 0:
		VillageProps.talk(_wander_P, _wt)
	if _wander_fire:
		_wander_fire.light_energy = lerpf(_wander_fire.light_energy, _flicker.randf_range(0.9, 1.5), 1.0 - exp(-12.0 * delta))


## E로 말을 건다: 한 줄 인사(띠).
func _wander_talk() -> void:
	var W: Dictionary = FieldLayout.WANDERERS[_wander_id]
	_reading = "wanderer"
	_wander_step = 1
	_hud.say(W.name, W.greet)


## 다음 E: 인사 → 조건(맞으면 "데려갈 수 있다") → 조건이 맞으면 데려간다(Meta.recruit) → 끝.
func _wander_next() -> void:
	var W: Dictionary = FieldLayout.WANDERERS[_wander_id]
	match _wander_step:
		1:
			_wander_step = 2
			if meta.wanderer_ready(data):
				_hud.say("%s · E로 데려간다" % W.name, W.ready)
			else:
				_hud.say("%s · %s" % [W.name, meta.wanderer_progress(data)], W.ask)
		2:
			if not meta.wanderer_ready(data):
				_end_read()
				return
			var r: Dictionary = meta.recruit(data)
			if not r.ok:
				_end_read()
				return
			_wander_step = 3
			_hud.say(W.name, W.join)
			if rules.bonus_hp != meta.recruit_hp():   # 약초꾼: 들판 체력 +는 바로
				rules.lord.hp += meta.recruit_hp() - rules.bonus_hp
				rules.bonus_hp = meta.recruit_hp()
			var t: String = "%s 마을로 간다 · %s" % [UiKit.josa(W.name, "이", "가"), W.gift]
			if int(r.paid) > 0:
				t += " · 조각 %d개를 냈다" % r.paid
			if int(r.sword) > 0:
				t += " 「%s」" % data.sword_by_id(int(r.sword)).display_name
			_hud.toast(t)
			_hud.flash(Color(1, 0.84, 0.42), 0.18, 0.8)
			_sfx.play(&"thump", _wander.position, -6.0, 0.8)
			_saved()
		_:
			_end_read()


## 고른 검을 칸 0에 쥔다(부러지지 않는다). 안 골랐으면 검집의 검, 0이면 맨손. 떨구거나 잃은 검이면 맨손.
func _hold_sword() -> void:
	var id: int = Meta.carry_sword if Meta.carry_sword >= 0 else meta.sheath_id
	if not meta.usable(id):
		id = 0
	_held_id = id
	var s: Sword = meta.unbreakable_sword(data, id)
	# 검 보관집(2026-11-21): 칸이 늘고, 북문에서 고른 나머지 검(Meta.carry_more)이 칸 1부터 든다
	rules.set_slot_count(meta.field_slots())
	rules.slots[0] = s
	var k: int = 1
	for more in Meta.carry_more:
		if k >= rules.slots.size():
			break
		if more > 0 and more != id and meta.usable(more):
			rules.slots[k] = meta.unbreakable_sword(data, more)
			k += 1
	rules.active = 0
	rules.lord.combo = 0
	rules.slots_changed.connect(_on_slots)
	_lord.set_sword(s, data.grades)
	_move_fx.tint = MoveArt.STEEL if s == null else (Color(0.9, 0.92, 1.0) if s.grade == 0 else (data.grades.colors[s.grade] as Color).lightened(0.25))


## 규칙의 적 목록과 맞춘다(main과 같다). 들판의 높이에 세운다.
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
			_stand(v)
	for i in range(_dying.size() - 1, -1, -1):
		var done: bool = _dying[i].draw(alpha, delta)
		_stand(_dying[i])
		if done:
			_dying[i].queue_free()
			_dying.remove_at(i)


func _stand(v: EnemyView) -> void:
	v.position.y = FieldBuilder.walk_height(v.position.x, v.position.z)


func _enemy_parts(e: Enemy) -> Dictionary:
	var v: EnemyView = _enemies.get(e.id)
	return v.parts if v else {}


func _float(at: Vector3, text: String, c: Color, size: int) -> void:
	var t := FloatText.new()
	t.text = text
	t.font_size = size
	t.modulate = c
	add_child(t)
	t.global_position = at


func _on_lord_hurt(d: float) -> void:
	_sfx.play(&"hurt", _lord.position, -4.0)
	_camera.add_shake(0.25)
	_hud.flash(Color(1, 0.2, 0.25), 0.18, 0.3)
	_float(_lord.position + Vector3(0, 2.4, 0), "-%d" % roundi(d), Color(1, 0.42, 0.42), 34)


func _on_enemy_hit(e: Enemy, damage: float, big: bool) -> void:
	var at: Vector3 = Grid.cells_to_world(e.pos)
	at.y = FieldBuilder.walk_height(at.x, at.z)
	if _enemies.has(e.id):
		_enemies[e.id].hit(big)
	var chest: Vector3 = at + Vector3(0, 0.9 + Grid.cells_to_meters(e.radius) * 1.2, 0)
	var dir: Vector3 = (at - _lord.position).normalized()
	if e.data.wraith:
		_fx.wisp(chest, dir, big)
	else:
		_fx.blood(chest, dir, big)
	_float(at + Vector3(0, 1.2 + Grid.cells_to_meters(e.radius) * 2.2, 0), str(roundi(damage)), Color(1, 0.86, 0.45) if big else Color.WHITE, 52 if big else 34)
	_camera.add_shake(data.lord.shake_big if big else data.lord.shake)
	_sfx.play(&"hit_big" if big else &"hit", at, 0.0)


func _on_enemy_died(e: Enemy) -> void:
	if _held_id > 0:
		_memory_toast(data.sword_by_id(_held_id), meta.log_kill(_held_id))   # 검의 기록
	var at: Vector3 = Grid.cells_to_world(e.pos)
	at.y = FieldBuilder.walk_height(at.x, at.z)
	if e.act != &"explode":
		if e.data.wraith:
			_fx.wisp(at + Vector3(0, 1.0, 0), Vector3.UP, true)
		else:
			_fx.splat(at, true)
	if e.pack != &"":
		meta.field_kill()
		_hud.refresh_top()


func _on_pack_cleared(id: StringName) -> void:
	var n: int = meta.field_clear(String(id))
	if n > 0:
		_hud.toast("무리를 쓰러뜨렸다. 조각 %d개" % n)
		_hud.flash(Color(1, 0.84, 0.42), 0.2, 0.6)
	var pk := String(id)
	if meta.captive_waiting(pk) and not _props.has("captive_" + pk):   # 묶여 있던 사람이 보인다
		_props["captive_" + pk] = FieldBuilder.captive(self, pk)
	_saved()


## 들판 보스나 곳마다 우두머리(32단계)가 깨어 있는 동안만 화면 아래 가운데에 체력 막대를 그린다(쓰러뜨리거나 멀어져 돌아가면 사라진다).
## 둘 다 깨어 있으면 무덤 기사, 우두머리가 여럿이면 영주에게 가까운 것.
func _boss_bar() -> void:
	var b: Enemy = rules.field_boss
	if b == null or rules.field_boss_state != Rules.BOSS_AWAKE or b.dead:
		b = rules.awake_chief()
	if b != null:
		_hud.set_boss(b.data.display_name, b.hp, b.max_hp)
	elif _hud.boss_bar_shown():
		_hud.set_boss("", 0.0, 1.0)


## 우두머리가 깨어났다: 낮은 소리와 작은 흔들림(꾸밈). 이름은 체력 막대가 띄운다.
func _on_chief_woke(_id: StringName, e: Enemy) -> void:
	_camera.add_shake(0.2)
	_sfx.play(&"thump", Grid.cells_to_world(e.pos), -4.0, 0.6)


## 우두머리를 쓰러뜨렸다(32단계): 조각과, 처음이면 그 곳의 오픈월드 한정 검(Meta.chief_defeat)을 토스트로 알린다.
func _on_chief_slain(id: StringName, e: Enemy) -> void:
	PlayLog.chief(String(id), rules, _held_id)
	var r: Dictionary = meta.chief_defeat(String(id))
	_camera.add_shake(data.lord.shake_big * 2.0)
	_hud.flash(Color(1, 0.84, 0.42), 0.25, 0.9)
	var t: String = "%s 쓰러뜨렸다. 조각 %d개" % [UiKit.josa(e.data.display_name, "을", "를"), r.shards]
	if int(r.sword) > 0:
		t += " · 들판의 검 「%s」" % data.sword_by_id(int(r.sword)).display_name
	_hud.toast(t)
	_saved()


## 무덤 기사를 쓰러뜨렸다: 조각과 운 부적(Meta.boss_defeat)을 토스트로 알린다.
func _on_boss_slain(_e: Enemy) -> void:
	var r: Dictionary = meta.boss_defeat()
	_camera.add_shake(data.lord.shake_big * 2.0)
	_hud.flash(Color(1, 0.84, 0.42), 0.25, 0.9)
	_hud.toast("무덤 기사를 쓰러뜨렸다. 조각 %d개%s" % [r.shards, ", 운 부적" if r.charm else ""])
	_saved()


## 무덤 기사의 큰 일(휘두르기 내려침, 돌진)에 흔들림과 소리를 더한다(꾸밈).
func _on_enemy_act(e: Enemy, act: StringName, _info: Dictionary) -> void:
	if e.data.id != FieldLayout.BOSS_ID and e.chief == &"":   # 우두머리(32단계)도 큰 일에 흔들린다
		return
	if act == &"swing" or act == &"charge_end":
		_camera.add_shake(0.35)
		_sfx.play(&"thump", Grid.cells_to_world(e.pos), -2.0, 0.7)


## 영주가 쓰러졌다: 쥔 검을 이 자리에 떨구고(먼저 떨군 검이 있으면 그것은 잃는다) 마을 북문 앞에서 깬다(record_run을 부르지 않는다).
func _on_down(_won: bool) -> void:
	_over = true
	PlayLog.down("field", rules, _held_id, String(FieldLayout.area_at(rules.lord.pos)))
	Meta.wake_note = FieldHud.drop_note(data, meta.drop_sword(data, _held_id, rules.lord.pos), _held_id, meta)
	Meta.carry_sword = -1
	meta.field_clock = rules.field_clock
	meta.save()
	Meta.wake_at_gate = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hud.flash(Color(0.05, 0.0, 0.0), 0.85, 1.6)
	await get_tree().create_timer(1.6).timeout
	get_tree().change_scene_to_file(VILLAGE_PATH)


func _end_read() -> void:
	_reading = ""
	_hud.say_end()
	if _wander_step > 0:
		var left: bool = _wander_step == 3
		_wander_step = 0
		if left:
			_build_wanderer()   # 데려갔다: 들판에서 사라진다(마을에 선다)
		elif not _wander_P.is_empty():
			for f: Node3D in _wander_P.get("forearms", []):
				if _wander_P.rest.has(f):
					f.transform = _wander_P.rest[f]


func _saved() -> void:
	meta.field_clock = rules.field_clock
	meta.save()
	_hud.refresh_top()


func _leave(path: String) -> void:
	Meta.carry_sword = -1   # 들판을 떠나면 검을 내려놓는다
	meta.field_clock = rules.field_clock   # 시계는 들판 밖에서 흐르지 않고 다시 들어오면 이어 간다
	meta.save()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(path)


## 막힌 곳에서 밀어낸다(Blockers). 공중이면 낮은 막힘(울타리·무너진 낮은 벽 …)은 지나간다. r: 몸 반지름(칸, 말은 HorseData.body_r).
func _push_out(p: Vector2, airborne: bool = false, r: float = Blockers.BODY) -> Vector2:
	return Blockers.push_out(p, _rects, _circles, _low_rects, _low_circles, airborne, r)


# ---------------------------------------------------------------- 떨군 검 (2026-11-20)

## 떨군 검: 날이 땅에 박혀 기울어 있고, 붉은 숨 같은 빛과 위로 흩어지는 재가 멀리서도 보인다(세계에 글자 없음).
func _build_dropped() -> void:
	if meta.dropped.is_empty():
		return
	var at: Vector2 = meta.dropped_at()
	var d: SwordData = data.sword_by_id(meta.dropped_id())
	var root := Node3D.new()
	var w: Vector3 = Grid.cells_to_world(at)
	root.position = Vector3(w.x, FieldBuilder.height(w.x, w.z), w.z)
	add_child(root)
	var col: Color = data.grades.colors[d.grade] if d and d.grade < data.grades.colors.size() else Color(0.9, 0.9, 0.9)
	var sw := SwordModel.make(data.forms[d.form] if d else null, d.grade if d else 0, d.id if d else 1, col)
	sw.basis = Basis.from_euler(Vector3(PI + 0.18, 0.4, 0.1))
	sw.position = Vector3(0.0, 0.5, 0.0)
	root.add_child(sw)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.25, 0.15)
	light.light_energy = 2.6
	light.omni_range = 6.0
	light.position = Vector3(0.0, 1.0, 0.0)
	root.add_child(light)
	var p := CPUParticles3D.new()
	p.amount = 70
	p.lifetime = 3.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.5
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0.0, 0.6, 0.0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	ramp.colors = PackedColorArray([Color(1, 0.3, 0.15, 0), Color(1, 0.3, 0.15, 0.9), Color(0.5, 0.1, 0.05, 0)])
	p.color_ramp = ramp
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _dot_texture()
	m.emission_enabled = true
	m.emission = Color(1.0, 0.3, 0.15)
	m.emission_energy_multiplier = 3.0
	q.material = m
	p.mesh = q
	p.position = Vector3(0.0, 0.3, 0.0)
	root.add_child(p)
	# 땅에 번진 붉은 빛 웅덩이(멀리서도 보이게, 낮에도)
	var pool := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.4, 2.4)
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.albedo_texture = _dot_texture()
	pmat.albedo_color = Color(0.9, 0.12, 0.06, 0.55)
	pm.material = pmat
	pool.mesh = pm
	pool.position = Vector3(0.0, 0.04, 0.0)
	root.add_child(pool)
	_dropped_node = root


## 가운데가 진하고 가장자리로 사라지는 둥근 점(불씨·빛 웅덩이).
static func _dot_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


## 검의 기억 단계를 넘었다: 한 줄과 낮은 울림(올라가는 소리 없음). 피해 배수는 다음에 쥐고 나갈 때부터.
func _memory_toast(d: SwordData, tier: int) -> void:
	if tier <= 0 or d == null:
		return
	_hud.toast("%s · 벤 적 %d" % [meta.memory_title(d), int(Meta.MEMORY[tier - 1][0])])
	_sfx.play(&"thump", Grid.cells_to_world(rules.lord.pos), -6.0, 0.7)


## 검을 바꿔 쥐었다(검 보관집): 쥔 검의 모습·기록·쓰러질 때 떨굴 검을 따라 바꾼다.
func _on_slots() -> void:
	var s: Sword = rules.current()
	_held_id = s.data.id if s and s.data else 0
	_lord.set_sword(s, data.grades)
	_move_fx.tint = MoveArt.STEEL if s == null else (Color(0.9, 0.92, 1.0) if s.grade == 0 else (data.grades.colors[s.grade] as Color).lightened(0.25))
