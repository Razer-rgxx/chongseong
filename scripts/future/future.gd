extends Node3D
## 녹슨 미래 구역(docs/stranger.md 3단계). 사이버 카타나를 얻은 뒤 들판의 갈라진 틈(E)으로 든다. 규칙은 Rules(들판 모드, era = future)가 돌리고,
## 이 장면은 그리고 소리 내고 Meta에 저장한다. 들판에서 쥔 검(Meta.carry_sword)을 그대로 가져온다. 틈으로 나오거나 쓰러지면 들판의 틈 앞에서 깬다.

const LORD_SCENE: PackedScene = preload("res://scenes/lord/lord.tscn")
const FIELD_PATH: String = "res://scenes/field/field.tscn"
const GLITCH_IN: float = 0.9   ## 들어올 때 글리치가 가라앉는 시간, 나갈 때 오르는 시간(초)

static var _titled: bool = false

@export var reach: float = 2.0
@export var max_ticks_per_frame: int = 8

var _held_id: int = 0
var data: GameData
var meta: Meta
var rules: Rules
var _acc: float = 0.0
var _dash_buf := PressBuffer.new()
var _atk_buf := PressBuffer.new()
var _want_jump: bool = false
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
var _neons: Array = []
var _chest: Node3D
var _ui: TimeUi
var _vault: Node3D
var _shard_nodes: Dictionary = {}
var _final_st: StrangerView = null
var _final_on: bool = false
var _glitch_fx: GlitchOverlay
var _glitch_t: float = -1.0       ## 들어올 때: 0에서 GLITCH_IN까지 가라앉는다
var _leaving: float = -1.0        ## 나갈 때: 0에서 GLITCH_IN까지 오른다
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
	Grid.size = FutureLayout.SIZE
	rules.memory = meta.memory_table()
	rules.bonus_hp = meta.recruit_hp()
	rules.era = Rules.ERA_FUTURE   # 사거리 +15%, 마무리 뒤 데이터 메아리(규칙, 테스트함)
	rules.start_field()
	rules.lord.pos = FutureLayout.START
	rules.lord.prev_pos = rules.lord.pos
	_hud.setup(data, meta)
	_ui = TimeUi.make(_hud, meta, TimeTravel.ERA_FUTURE)
	_ui.picked.connect(_on_era_picked)
	_ui.closed.connect(func() -> void: _capture(true))
	var env: Environment = ($Environment as WorldEnvironment).environment
	FutureBuilder.environment(env)
	var built: Dictionary = FutureBuilder.build(self)
	_neons = built.neons
	_chest = get_node("FutureCity/Cache") as Node3D
	if meta.field_found.has(FutureLayout.CACHE_ID):
		FutureBuilder.open_cache(_chest)
	var b: Dictionary = FutureLayout.blockers()
	rules.set_blockers(b.rects, b.circles, b.low_rects, b.low_circles)
	_blockers = b
	HillBuilder.setup(Vector2(FutureLayout.SIZE) * Grid.CELL)   # 적의 몸이 구역을 싸움터 안으로 본다
	FutureRift.make(self, Grid.cells_to_world(FutureLayout.EXIT_AT))
	_build_story()
	_lord = LORD_SCENE.instantiate()
	_lord.setup(rules)
	add_child(_lord)
	_lord.torch.light_energy = 0.8
	_lord.torch.light_color = Color(0.55, 0.75, 1.0)
	add_child(_fx)
	_pfx.setup(rules)
	add_child(_pfx)
	add_child(_move_fx)
	_move_fx.setup(rules)
	add_child(_enemy_fx)
	_enemy_fx.setup(rules, _enemy_parts)
	_hold_sword()
	var rain := WeatherFx.make(self, _camera)   # 쉬지 않는 비
	rain.set_kind(&"rain")
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
	var chain_meter := ChainMeter.make(_hud)
	rules.kill_chain.connect(func(n: int, _paid: int) -> void:
		chain_meter.bump(n, 0, data.run.chain_window, data.meta.chain_every)
		_camera.add_shake(minf(0.04 + 0.01 * n, 0.2))
		_sfx.play(&"chain", _lord.position, 0.0, ChainMeter.pitch(n)))
	rules.enemy_act.connect(_on_enemy_act)
	rules.field_boss_slain.connect(_on_guardian)
	rules.run_ended.connect(_on_down)
	rules.move_area.connect(func(_m: StringName, info: Dictionary) -> void: _sfx.play(&"thump", Grid.cells_to_world(info.get("at", rules.lord.pos)), -6.0, 0.8))
	for id in FutureLayout.PACKS:
		rules.spawn_pack(StringName(id), FutureLayout.PACKS[id])
	_flick.seed = 311
	_camera.target = Grid.cells_to_world(rules.lord.pos)
	_camera.yaw = 0.0
	_camera.snap()
	_capture(true)
	_glitch_fx = GlitchOverlay.make(self)   # 들어올 때의 글리치
	_glitch_fx.set_amount(1.0)
	_glitch_t = 0.0
	_sfx.play(&"glitch", Grid.cells_to_world(rules.lord.pos), -2.0)
	if not _titled:
		_titled = true
		_hud.area_title("녹슨 미래")
	WebQuality.apply(self, env, built.sun, _camera)


var _blockers: Dictionary = {}


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
		elif k.physical_keycode == KEY_T and not _over:
			_toggle_era_window()
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
		rules.lord.pos = Blockers.push_out(rules.lord.pos, _blockers.rects, _blockers.circles, _blockers.low_rects, _blockers.low_circles, rules.lord.airborne())
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
	_flicker(delta)
	_glitch(delta)
	if _final_st != null:
		_final_st.update(delta)
	if _say_t > 0.0:
		_say_t -= delta
		if _say_t <= 0.0 and not _final_on:
			_hud.say_end()
	if Meta.go_present or Meta.go_past:   # 관리 명령 `시대 현재`·`시대 과거`(과거는 들판이 이어받는다)
		Meta.go_present = false
		if not _over and _leaving < 0.0:
			_leave()
	_hud.set_hp(rules.lord.hp, rules.max_hp())
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
	var s := {"exit": FutureLayout.EXIT_AT, "terminal": FutureLayout.TERMINAL_AT}
	if not meta.field_found.has(FutureLayout.CACHE_ID):
		s["cache"] = FutureLayout.CACHE_AT
	for i in Story.SHARDS.size():
		if _shard_nodes.has(i):
			s["shard%d" % i] = Story.SHARDS[i].at
	s["vault"] = Story.VAULT_AT
	s["lock"] = Story.TIME_LOCK_AT
	return s


func _prompt(key: String) -> String:
	match key:
		"exit":
			return "틈으로 돌아간다" if meta.time_traveller else "닫힌 틈을 살핀다"
		"terminal":
			return "단말을 건드린다"
		"vault":
			return "봉인 단말을 건드린다"
		"lock":
			return "시간 고정 단말을 건드린다"
	if key.begins_with("shard"):
		return "자료 조각을 줍는다"
	return "녹슨 함을 연다"


func _interact() -> void:
	if _over or _leaving >= 0.0:
		return
	if _near == "exit":
		if meta.time_traveller:
			_leave()
		else:   # 2026-11-25 사용자: 타임트래블러를 받기 전에는 한 번 들어오면 못 나간다
			_hud.toast("틈이 닫혀 있다. 이 시대에서 돌아갈 길을 찾아야 한다.")
	elif _near == "terminal":
		if meta.future_terminal():
			_sfx.play(&"glitch", Grid.cells_to_world(FutureLayout.TERMINAL_AT), -4.0)
			_hud.toast("단말이 다음 언덕의 손잡이 조짐을 모두 알려 준다")
			_hud.flash(Color(0.4, 0.75, 1.0), 0.25, 0.6)
			meta.save()
		else:
			_hud.toast("단말은 이미 같은 말을 했다")
	elif _near.begins_with("shard"):
		_take_shard(int(_near.substr(5)))
	elif _near == "vault":
		_use_vault()
	elif _near == "lock":
		_use_lock()
	elif _near == "cache":
		var got: int = meta.future_cache()
		if got > 0:
			FutureBuilder.open_cache(_chest)
			_sfx.play(&"thump", _chest.position, -3.0, 0.7)
			_hud.toast("녹슨 함에서 조각 %d개를 얻었다" % got)
			_saved()


## 고른 검을 칸 0에 쥔다(부러지지 않는다, 들판과 같다). 미래 구역에서는 베기 빛과 동작 빛이 차가운 푸른빛이다.
func _hold_sword() -> void:
	var id: int = Meta.carry_sword if Meta.carry_sword >= 0 else meta.sheath_id
	if not meta.usable(id):
		id = 0
	_held_id = id
	var s: Sword = meta.unbreakable_sword(data, id)
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
	_lord.set_slash_override(Color(FutureLayout.TRAIL, 1.0))
	_lord.set_sword(s, data.grades)
	_move_fx.tint = FutureLayout.TRAIL


# ---------------------------------------------------------------- 그리기

## 네온이 꺼져 가며 깜빡인다(꾸밈, 화면 쪽 랜덤).
func _flicker(delta: float) -> void:
	_t += delta
	for n in _neons:
		var f: float = 0.55 + 0.45 * sin(_t * float(n.rate) + float(n.phase))
		if _flick.randf() < 0.012:
			f = 0.0   # 툭 꺼졌다 켜진다
		match String(n.get("mode", "flicker")):
			"half":   # 대부분 죽어 있다가 가끔 지직 켜진다
				f = 1.0 if fposmod(_t * 0.23 + float(n.phase), 1.0) < 0.12 and _flick.randf() < 0.7 else 0.05
			"steady":
				f = 0.8 + 0.2 * f
		var m: StandardMaterial3D = n.mat
		m.emission_energy_multiplier = 2.2 * f
		var l: OmniLight3D = n.light
		if l != null:
			l.light_energy = 1.1 * f


## 들어올 때 글리치가 가라앉고, 나갈 때 오른다.
func _glitch(delta: float) -> void:
	if _glitch_t >= 0.0:
		_glitch_t += delta
		_glitch_fx.set_amount(1.0 - clampf(_glitch_t / GLITCH_IN, 0.0, 1.0), delta)
		if _glitch_t >= GLITCH_IN:
			_glitch_t = -1.0
			_glitch_fx.set_amount(0.0)
	elif _leaving >= 0.0:
		_leaving += delta
		_glitch_fx.set_amount(clampf(_leaving / GLITCH_IN, 0.0, 1.0), delta)
		if _leaving >= GLITCH_IN:
			_leaving = -1.0
			SceneLoader.go(get_tree(), FIELD_PATH)


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
	_fx.blood(chest, dir, big)
	_float(at + Vector3(0, 1.2 + Grid.cells_to_meters(e.radius) * 2.2, 0), str(roundi(damage)), Color(0.6, 0.85, 1.0) if big else Color.WHITE, 52 if big else 34)
	_camera.add_shake(data.lord.shake_big if big else data.lord.shake)
	_sfx.play(&"hit_big" if big else &"hit", at, 0.0)


func _on_enemy_died(e: Enemy) -> void:
	if _held_id > 0:
		_memory_toast(data.sword_by_id(_held_id), meta.log_kill(_held_id))
	if e.act != &"explode":
		_fx.splat(Grid.cells_to_world(e.pos), true)


func _on_enemy_act(_e: Enemy, _act: StringName, _info: Dictionary) -> void:
	pass


## 영주가 쓰러졌다: 쥔 검을 들판의 틈 앞에 떨구고 그 앞에서 깬다(조각 상자와 단말은 그대로).
func _on_down(_won: bool) -> void:
	_over = true
	PlayLog.down("future", rules, _held_id, "future")
	if not meta.time_traveller:   # 못 나가는 동안은 미래 구역 처음 자리에서 다시 깬다(검은 그대로 쥔다)
		meta.save()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_hud.flash(Color(0.05, 0.0, 0.0), 0.85, 1.6)
		await get_tree().create_timer(1.6).timeout
		SceneLoader.go(get_tree(), scene_file_path)
		return
	Meta.wake_note = FieldHud.drop_note(data, meta.drop_sword(data, _held_id, FutureLayout.RIFT_WAKE + FutureLayout.DROP_OFFSET), _held_id, meta)
	meta.save()
	Meta.wake_at_rift = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hud.flash(Color(0.05, 0.0, 0.0), 0.85, 1.6)
	await get_tree().create_timer(1.6).timeout
	SceneLoader.go(get_tree(), FIELD_PATH)


func _saved() -> void:
	meta.save()
	_hud.refresh_top()


func _leave() -> void:
	meta.save()
	Meta.wake_at_rift = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_sfx.play(&"glitch", _lord.position, 0.0)
	_leaving = 0.0


func _memory_toast(d: SwordData, tier: int) -> void:
	if tier <= 0 or d == null:
		return
	_hud.toast("%s · 벤 적 %d" % [meta.memory_title(d), int(Meta.MEMORY[tier - 1][0])])
	_sfx.play(&"thump", Grid.cells_to_world(rules.lord.pos), -6.0, 0.7)


func _on_slots() -> void:
	var s: Sword = rules.current()
	_held_id = s.data.id if s and s.data else 0
	_lord.set_sword(s, data.grades)
	_move_fx.tint = FutureLayout.TRAIL


# ---------------------------------------------------------------- 타임트래블러 이야기 (docs/stranger.md 4단계)

func _build_story() -> void:
	for i in Story.SHARDS.size():
		if not meta.story_shards.has(i):
			_shard_nodes[i] = StoryProps.shard(self, Grid.cells_to_world(Story.SHARDS[i].at))
	_vault = StoryProps.vault(self, Grid.cells_to_world(Story.VAULT_AT), meta.vault_open)
	if meta.vault_open and not meta.time_traveller:
		_spawn_guardian()


func _spawn_guardian() -> void:
	rules.spawn_field_boss(Story.GUARDIAN_AT, Story.GUARDIAN_ID, Story.GUARDIAN_ZONE)


func _take_shard(i: int) -> void:
	if not meta.take_shard(i):
		return
	if _shard_nodes.has(i):
		(_shard_nodes[i] as Node).queue_free()
		_shard_nodes.erase(i)
	_sfx.play(&"glitch", Grid.cells_to_world(Story.SHARDS[i].at), -6.0)
	_hud.flash(Color(0.4, 0.75, 1.0), 0.2, 0.5)
	_hud.say("", String(Story.SHARDS[i].text), true)
	_say_t = 5.0
	_saved()


var _say_t: float = 0.0


func _use_vault() -> void:
	if meta.time_traveller:
		_hud.toast(Story.VAULT_DONE)
	elif meta.open_vault():
		StoryProps.set_open(_vault, true)
		_sfx.play(&"thump", Grid.cells_to_world(Story.VAULT_AT), -2.0, 0.6)
		_hud.flash(Color(0.4, 0.75, 1.0), 0.3, 0.8)
		_hud.say("", Story.VAULT_OPEN, true)
		_say_t = 4.0
		_spawn_guardian()
		_saved()
	elif meta.vault_open:
		_hud.toast("금고는 열려 있다. 지키는 것이 깨어 있다.")
	else:
		_hud.toast(Story.VAULT_SEALED % meta.story_shards.size())


func _use_lock() -> void:
	if meta.time_lock:
		_hud.toast(Story.LOCK_HELD)
	elif meta.buy_time_lock():
		_sfx.play(&"glitch", Grid.cells_to_world(Story.TIME_LOCK_AT), -4.0)
		_hud.flash(Color(0.4, 0.75, 1.0), 0.25, 0.6)
		_hud.toast(Story.LOCK_DONE)
		_saved()
	elif meta.shards < Story.TIME_LOCK_COST:
		_hud.toast(Story.LOCK_POOR % Story.TIME_LOCK_COST)


## 금고지기가 쓰러졌다: 낯선 사람이 마지막으로 서서 말하고 타임트래블러를 준다(한 번만).
func _on_guardian(_e: Enemy) -> void:
	if _final_on or not meta.guardian_slain():
		return
	_final_on = true
	meta.save()
	var st := StrangerView.make(self, Grid.cells_to_world(Story.FINAL_AT), _lord.position)
	_final_st = st
	_ui.refresh()
	_final_scene(st)


func _final_scene(st: StrangerView) -> void:
	for line in Story.FINAL_LINES:
		if not is_inside_tree():
			return
		_hud.say("", line, true)
		await get_tree().create_timer(3.0).timeout
	if not is_inside_tree():
		return
	_hud.say("", Story.GOT_LINE, true)
	_sfx.play(&"glitch", _lord.position, -2.0)
	_hud.flash(Color(0.4, 0.75, 1.0), 0.3, 0.9)
	st.fade()
	await get_tree().create_timer(3.2).timeout
	if is_inside_tree():
		_hud.say_end()
		_ui.refresh()


func _toggle_era_window() -> void:
	if not meta.time_traveller or _leaving >= 0.0:
		return
	if _ui.is_open():
		_ui.close()
		return
	if TimeTravel.in_combat(rules):
		_hud.toast("싸움 중에는 시간이 열리지 않는다.")
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_ui.toggle()


func _on_era_picked(era: StringName) -> void:
	_ui.close()
	if (era == TimeTravel.ERA_NOW or era == TimeTravel.ERA_PAST) and not _over and _leaving < 0.0:
		if meta.can_travel(rules):
			Meta.go_past = era == TimeTravel.ERA_PAST   # 과거는 들판을 거쳐 건넌다(들판이 이어받는다)
			_leave()
		else:
			_hud.toast("싸움 중에는 시간이 열리지 않는다.")
