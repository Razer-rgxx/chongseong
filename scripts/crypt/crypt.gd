extends Node3D
## 지하 무덤(19단계, docs/outside.md). 방 여섯, 문은 방을 쓰러뜨려야 열린다. 규칙은 Rules(들판 모드)와 CryptRun이 돌리고,
## 이 장면은 그리고 소리 내고 Meta에 저장한다. 들판에서 쥔 검(Meta.carry_sword)을 그대로 가져온다.
## 쓰러지면 잃는 것 없이 들판의 무덤 입구 앞에서 깬다(쓰러뜨린 방과 연 관은 남는다).

const LORD_SCENE: PackedScene = preload("res://scenes/lord/lord.tscn")
const FIELD_PATH: String = "res://scenes/field/field.tscn"
const FLICKER: float = 0.18   ## 횃불 흔들림 폭(꾸밈)

static var _titled: bool = false

@export var reach: float = 2.0
@export var max_ticks_per_frame: int = 8

## 지금 쥔 검 번호(0 = 맨손). 쓰러지면 들판의 무덤 입구 앞에 떨군다.
var _held_id: int = 0
var data: GameData
var meta: Meta
var rules: Rules
var crypt: CryptRun
var _acc: float = 0.0
var _dash_buf := PressBuffer.new()
var _atk_buf := PressBuffer.new()
var _want_jump: bool = false
## 검 바꾸기(검 보관집이 있으면 칸이 여럿): Rules.SWAP_NEXT(Q) 또는 칸 번호, -1이면 없음.
var _want_swap: int = -1
var _want_hook: bool = false
var _lord: Node3D
var _near: String = ""
var _over: bool = false
var _enemies: Dictionary = {}
var _dying: Array[EnemyView] = []
var _fx := HitFx.new()
var _pfx := PowerFx.new()
var _move_fx := MoveFx.new()
var _enemy_fx := EnemyFx.new()
var _doors: Dictionary = {}
var _coffins: Dictionary = {}
var _torches: Array = []
var _flick := RandomNumberGenerator.new()   # 꾸밈 랜덤(규칙과 무관)
var _t: float = 0.0

@onready var _camera: Camera3D = $Camera
@onready var _sfx: Sfx = $Sfx
@onready var _hud: LobbyHud = $UI


func _ready() -> void:
	data = GameData.load_default()
	meta = Meta.load_or_new()
	ObjectHead.lord_info = Heads.info(meta.head) if meta.head != "" else {}   # 쓴 머리
	meta.fix_sheath(data)
	meta.save()
	rules = Rules.new(data, int(Time.get_unix_time_from_system()))
	Grid.size = CryptLayout.SIZE
	rules.memory = meta.memory_table()
	rules.bonus_hp = meta.recruit_hp()   # 34단계: 떠돌이 약초꾼(들판과 같다)
	rules.start_field()
	rules.lord.pos = CryptLayout.START
	rules.lord.prev_pos = rules.lord.pos
	crypt = CryptRun.new(rules, meta)
	_hud.setup(data, meta)
	var env: Environment = ($Environment as WorldEnvironment).environment
	CryptBuilder.environment(env)
	var built: Dictionary = CryptBuilder.build(self)
	_doors = built.doors
	_coffins = built.coffins
	_torches = built.torches
	for id in _coffins:
		if meta.crypt_opened.has(String(id)):
			CryptBuilder.open_coffin(_coffins[id], false)
	HillBuilder.setup(Vector2(CryptLayout.SIZE) * Grid.CELL)   # 적의 몸이 무덤을 싸움터 안으로 본다
	_lord = LORD_SCENE.instantiate()
	_lord.setup(rules)
	add_child(_lord)
	_lord.torch.light_energy = 1.8
	add_child(_fx)
	_pfx.setup(rules)
	add_child(_pfx)
	add_child(_move_fx)
	_move_fx.setup(rules)
	add_child(_enemy_fx)
	_enemy_fx.setup(rules, _enemy_parts)
	_enemy_fx.quaked.connect(func(_at: Vector3, k: float) -> void: _camera.add_shake(0.4 * k))   # 보스 패턴의 땅 울림
	_hold_sword()
	rules.lord_swung.connect(func(big: bool) -> void: _sfx.play(&"swish_big" if big else &"swish", _lord.position, -2.0 if big else -6.0))
	rules.lord_dashed.connect(func() -> void:
		_sfx.play(&"dash", _lord.position, -6.0)
		_camera.kick(4.0))
	rules.lord_landed.connect(func(_at: Vector2) -> void: _sfx.play(&"land", _lord.position, -4.0))
	rules.lord_hooked.connect(func(_e: Enemy) -> void:
		_sfx.play(&"draw", _lord.position, -2.0, 1.25)
		_camera.kick(10.0))
	rules.lord_hurt.connect(_on_lord_hurt)
	rules.enemy_hit.connect(_on_enemy_hit)
	rules.enemy_died.connect(_on_enemy_died)
	var chain_meter := ChainMeter.make(_hud)   # 처치 연쇄(2026-11-24): 숫자만. 조각은 언덕에서만 붙는다
	rules.kill_chain.connect(func(n: int, _paid: int) -> void:
		chain_meter.bump(n, 0, data.run.chain_window, data.meta.chain_every)
		_camera.add_shake(minf(0.04 + 0.01 * n, 0.2))
		_sfx.play(&"chain", _lord.position, 0.0, ChainMeter.pitch(n))
		if n % maxi(1, data.meta.chain_every) == 0:
			_sfx.play(&"thump", _lord.position, -2.0, 0.6)
			_camera.add_shake(0.25))
	rules.enemy_act.connect(_on_enemy_act)
	rules.run_ended.connect(_on_down)
	rules.move_area.connect(func(_m: StringName, info: Dictionary) -> void: _sfx.play(&"thump", Grid.cells_to_world(info.get("at", rules.lord.pos)), -6.0, 0.8))
	crypt.room_cleared.connect(_on_room_cleared)
	_flick.seed = 190
	_camera.target = Grid.cells_to_world(rules.lord.pos)
	_camera.yaw = 0.0   # 북쪽(위)을 본다(들판과 같다)
	_camera.snap()
	_sync_doors(false)
	_capture(true)
	if not _titled:
		_titled = true
		_hud.area_title("지하 무덤")
	GuideHud.attach(self, meta, rules, "crypt", _hud, Callable(), _hud.is_open)   # 길라잡이(docs/guide.md)
	WebQuality.apply(self, env, null, _camera)   # 웹판에서만 가볍게


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
		_dash_buf.press(rules.data.lord.buffer_time)
	if event.is_action_pressed("jump"):
		_want_jump = true
	if event.is_action_pressed("attack"):
		_atk_buf.press(rules.data.lord.buffer_time)
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
		inp.dash = _dash_buf.on()
		inp.jump = _want_jump
		inp.swap_to = _want_swap
		inp.attack = Input.is_action_pressed("attack") or _atk_buf.on()
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
		var _c0: int = rules.powers.dash_charges
		var _cd0: float = rules.lord.cooldown
		rules.step(inp)
		_dash_buf.end_tick(rules.dt, rules.powers.dash_charges < _c0)
		_atk_buf.end_tick(rules.dt, rules.lord.cooldown > _cd0)
		crypt.step()
		rules.lord.pos = crypt.push(rules.lord.pos, rules.lord.airborne())
		_want_jump = false
		_want_swap = -1
		_want_hook = false
		_acc -= rules.dt
		n += 1
	if n == max_ticks_per_frame:
		_acc = 0.0


func _process(delta: float) -> void:
	var alpha: float = clampf(_acc / rules.dt, 0.0, 1.0)
	_lord.draw(alpha, delta)
	_camera.target = _lord.position
	_move_fx.draw(alpha)
	_enemy_fx.draw(alpha)
	_sync_enemies(alpha, delta)
	_sync_doors(true)
	_flicker(delta)
	_hud.set_hp(rules.lord.hp, rules.max_hp())
	_boss_bar()
	_near = ""
	var best_d: float = reach
	var p: Vector2 = rules.lord.pos
	var spots: Dictionary = _spots()
	for key in spots:
		var d: float = p.distance_to(spots[key])
		if d < best_d:
			best_d = d
			_near = key
	_hud.set_prompt("E", _prompt(_near) if _near != "" else "")


func _spots() -> Dictionary:
	var s := {"exit": CryptLayout.EXIT_AT}
	for id in CryptLayout.ROOM_ORDER:
		if crypt.coffin_ready(id):
			s["coffin_%s" % id] = CryptLayout.ROOMS[id].coffin
	return s


func _prompt(key: String) -> String:
	if key == "exit":
		return "무덤을 나선다"
	return "돌 관을 연다"


func _interact() -> void:
	if _over:
		return
	if _near == "exit":
		_leave()
	elif _near.begins_with("coffin_"):
		var id := StringName(_near.substr(7))
		var low: bool = id == CosSecrets.CRYPT_COFFIN and not meta.crypt_opened.has(String(id)) and rules.lord.hp <= rules.max_hp() * CosSecrets.CRYPT_HP
		var r: Dictionary = meta.crypt_open(String(id))
		if int(r.shards) > 0 and low and not meta.cos_discover(CosSecrets.CRYPT_ID).is_empty():   # 꾸미기 비밀: 목숨이 간당할 때 이 관을 연다
			_hud.say("", CosSecrets.CRYPT_LINE, true)
			get_tree().create_timer(5.0).timeout.connect(_hud.say_end)
		if int(r.shards) > 0:
			CryptBuilder.open_coffin(_coffins[id])
			_sfx.play(&"thump", _coffins[id].position, -3.0, 0.7)
			_hud.toast("돌 관에서 조각 %d개%s%s" % [r.shards, ", 운 부적" if r.charm else "", _sword_note(int(r.sword))])
			if r.charm or int(r.sword) >= 0:
				_hud.flash(Color(1, 0.84, 0.42), 0.25, 0.9)
			_saved()


## 큰 관에서 얻은 오픈월드 한정 검의 이름(알림 끝에 붙인다). 없으면 "".
func _sword_note(id: int) -> String:
	if id < 0:
		return ""
	var sd := load(CryptLayout.big_coffin_sword_path()) as SwordData
	return ", 검 「%s」" % sd.display_name if sd != null else ""


## 고른 검을 칸 0에 쥔다(부러지지 않는다, 들판과 같다). 안 골랐으면 검집의 검, 0이면 맨손.
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


# ---------------------------------------------------------------- 그리기

## 문 돌판을 규칙 상태에 맞춘다(닫힘 = 영주가 들어선 방이 아직 안 쓰러뜨려졌다).
func _sync_doors(animate: bool) -> void:
	for d in _doors:
		CryptBuilder.set_door(_doors[d], crypt.door_closed(d), animate)


## 횃불이 흔들린다(꾸밈, 화면 쪽 랜덤).
func _flicker(delta: float) -> void:
	_t += delta
	for l in _torches:
		var base: float = float(l.get_meta("base", 2.0))
		l.light_energy = base * (1.0 + FLICKER * (sin(_t * 9.0 + l.position.x * 3.0) * 0.5 + _flick.randf_range(-0.5, 0.5)))


## 무덤 주인의 체력 막대(마지막 방에서 깨어 있는 동안만).
func _boss_bar() -> void:
	var b: Enemy = rules.field_boss
	if b != null and rules.field_boss_state == Rules.BOSS_AWAKE and not b.dead:
		_hud.set_boss(b.data.display_name, b.hp, b.max_hp)
	elif _hud.boss_bar_shown():
		_hud.set_boss("", 0.0, 1.0)


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
		var done: bool = _dying[i].draw(alpha, delta)
		if done:
			_dying[i].queue_free()
			_dying.remove_at(i)


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
	if e.act != &"explode":
		if e.data.wraith:
			_fx.wisp(at + Vector3(0, 1.0, 0), Vector3.UP, true)
		else:
			_fx.splat(at, true)


## 방을 다 쓰러뜨렸다: 문이 열리는 흔들림과 소리(돌판은 _sync_doors가 올린다). 저장한다.
func _on_room_cleared(_id: StringName) -> void:
	SlowMo.hit(get_tree(), data.lord.finish_slow, data.lord.finish_slow_time)   # 방의 마지막 하나
	_camera.add_shake(0.3)
	_sfx.play(&"thump", _lord.position, -2.0, 0.55)
	_hud.flash(Color(1, 0.84, 0.42), 0.12, 0.6)
	if meta.head_drop != "":   # 무덤 주인의 머리(Heads)
		_hud.toast("%s가 떨어졌다 · 마을 성소에서 쓴다" % Heads.info(meta.head_drop).name)
		meta.head_drop = ""
	_saved()


func _on_enemy_act(e: Enemy, act: StringName, _info: Dictionary) -> void:
	if e.data.id != CryptLayout.LORD_ID:
		return
	if act == &"swing" or act == &"charge_end":
		_camera.add_shake(0.3)
		_sfx.play(&"thump", Grid.cells_to_world(e.pos), -2.0, 0.7)


## 영주가 쓰러졌다: 쥔 검을 들판의 무덤 입구 앞에 떨구고(먼저 떨군 검은 잃는다) 그 앞에서 깬다(쓰러뜨린 방과 연 관은 Meta에 남아 있다).
func _on_down(_won: bool) -> void:
	_over = true
	PlayLog.down("crypt", rules, _held_id, "crypt")
	Meta.wake_note = FieldHud.drop_note(data, meta.drop_sword(data, _held_id, FieldLayout.CRYPT_WAKE + FieldLayout.CRYPT_DROP_OFFSET), _held_id, meta)
	meta.save()
	Meta.wake_at_crypt = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hud.flash(Color(0.05, 0.0, 0.0), 0.85, 1.6)
	await get_tree().create_timer(1.6).timeout
	SceneLoader.go(get_tree(), FIELD_PATH)   # 불러오기 화면(2026-11-24)


func _saved() -> void:
	meta.save()
	_hud.refresh_top()


func _leave() -> void:
	meta.save()
	Meta.wake_at_crypt = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	SceneLoader.go(get_tree(), FIELD_PATH)   # 불러오기 화면(2026-11-24)


## 검의 기억 단계를 넘었다: 한 줄과 낮은 울림(올라가는 소리 없음). 피해 배수는 다음에 쥐고 나갈 때부터.
func _memory_toast(d: SwordData, tier: int) -> void:
	var rune_text: String = meta.take_rune_news(data)   # 검의 기억: 새 룬 알림
	if rune_text != "":
		_hud.toast(rune_text)
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
