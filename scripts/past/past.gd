extends Node3D
## 과거 신화 구역(docs/stranger.md 5단계). 타임트래블러의 T 창에서 "과거"를 고르면 든다. 첫 검들이 벼려지던 때의 언덕.
## 규칙은 Rules(들판 모드, era = past)가 돌리고, 이 장면은 그리고 소리 내고 Meta에 저장한다. 들판에서 쥔 검(Meta.carry_sword)을 그대로 가져온다.
## 돌문으로 나오거나 쓰러지면 들판에서 깬다(Meta.wake_at_rift, 정한 것: 미래 구역과 같은 자리).

const LORD_SCENE: PackedScene = preload("res://scenes/lord/lord.tscn")
const FIELD_PATH: String = "res://scenes/field/field.tscn"
const GLITCH_IN: float = 0.9

static var _titled: bool = false

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
var _fires: Array = []
var _motes: CPUParticles3D
var _chest: Node3D
var _ui: TimeUi
var _glitch_fx: GlitchOverlay
var _glitch_t: float = -1.0
var _leaving: float = -1.0
var _flick := RandomNumberGenerator.new()   # 꾸밈 랜덤(규칙과 무관)
var _t: float = 0.0
var _blockers: Dictionary = {}

@onready var _camera: Camera3D = $Camera
@onready var _sfx: Sfx = $Sfx
@onready var _hud: LobbyHud = $UI


func _ready() -> void:
	data = GameData.load_default()
	meta = Meta.load_or_new()
	ObjectHead.lord_info = Heads.info(meta.head) if meta.head != "" else {}
	meta.fix_sheath(data)
	meta.save()
	rules = Rules.new(data, int(Time.get_unix_time_from_system()))
	Grid.size = PastLayout.SIZE
	rules.memory = meta.memory_table()
	rules.bonus_hp = meta.recruit_hp()
	rules.era = Rules.ERA_PAST   # 맞힐 때 피해 +10%, 밀림 +25%(Powers.strike, 테스트함)
	rules.start_field()
	rules.lord.pos = PastLayout.START
	rules.lord.prev_pos = rules.lord.pos
	_hud.setup(data, meta)
	_ui = TimeUi.make(_hud, meta, TimeTravel.ERA_PAST)
	_ui.picked.connect(_on_era_picked)
	_ui.closed.connect(func() -> void: _capture(true))
	var env: Environment = ($Environment as WorldEnvironment).environment
	PastBuilder.environment(env)
	var built: Dictionary = PastBuilder.build(self)
	_fires = built.fires
	_motes = built.motes
	_chest = get_node("PastHill/Cache") as Node3D
	if meta.field_found.has(PastLayout.CACHE_ID):
		PastBuilder.open_cache(_chest)
	var b: Dictionary = PastLayout.blockers()
	rules.set_blockers(b.rects, b.circles, b.low_rects, b.low_circles)
	_blockers = b
	HillBuilder.setup(Vector2(PastLayout.SIZE) * Grid.CELL)
	_lord = LORD_SCENE.instantiate()
	_lord.setup(rules)
	add_child(_lord)
	_lord.torch.light_energy = 0.5
	_lord.torch.light_color = Color(1.0, 0.8, 0.5)
	add_child(_fx)
	_pfx.setup(rules)
	add_child(_pfx)
	add_child(_move_fx)
	_move_fx.setup(rules)
	add_child(_enemy_fx)
	_enemy_fx.setup(rules, _enemy_parts)
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
	var chain_meter := ChainMeter.make(_hud)
	rules.kill_chain.connect(func(n: int, _paid: int) -> void:
		chain_meter.bump(n, 0, data.run.chain_window, data.meta.chain_every)
		_camera.add_shake(minf(0.04 + 0.01 * n, 0.2))
		_sfx.play(&"chain", _lord.position, 0.0, ChainMeter.pitch(n)))
	rules.run_ended.connect(_on_down)
	rules.move_area.connect(func(_m: StringName, info: Dictionary) -> void: _sfx.play(&"thump", Grid.cells_to_world(info.get("at", rules.lord.pos)), -6.0, 0.8))
	for id in PastLayout.PACKS:
		rules.spawn_pack(StringName(id), PastLayout.PACKS[id])
	_flick.seed = 3000
	_camera.target = Grid.cells_to_world(rules.lord.pos)
	_camera.yaw = 0.0
	_camera.snap()
	_capture(true)
	_glitch_fx = GlitchOverlay.make(self)   # 들어올 때 시간의 글리치가 금빛으로 가라앉는다
	_glitch_fx.set_amount(1.0)
	_glitch_t = 0.0
	_sfx.play(&"glitch", Grid.cells_to_world(rules.lord.pos), -2.0)
	if not _titled:
		_titled = true
		_hud.area_title("최초의 대장간")
	WebQuality.apply(self, env, built.sun, _camera)


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
	if _motes != null:
		_motes.position = _lord.position + Vector3(0, 3.0, 0)
	if Meta.go_present or Meta.go_future:   # 관리 명령 `시대 현재`·`시대 미래`(들판이 이어받는다)
		if Meta.go_present:
			Meta.go_present = false
		if not _over and _leaving < 0.0:
			_leave()
	Meta.go_past = false
	_hud.set_hp(rules.lord.hp, rules.max_hp())
	_near = ""
	var best_d: float = PastLayout.REACH
	var spots: Dictionary = _spots()
	for key in spots:
		var d: float = rules.lord.pos.distance_to(spots[key])
		if d < best_d:
			best_d = d
			_near = key
	_hud.set_prompt("E", _prompt(_near) if _near != "" else "")


func _spots() -> Dictionary:
	var s := {"exit": PastLayout.EXIT_AT, "altar": PastLayout.ALTAR_AT}
	if not meta.field_found.has(PastLayout.CACHE_ID):
		s["cache"] = PastLayout.CACHE_AT
	return s


func _prompt(key: String) -> String:
	match key:
		"exit":
			return "돌문으로 돌아간다"
		"altar":
			return "첫 대장간에서 검을 다시 벼린다"
	return "성스러운 숲의 함을 연다"


func _interact() -> void:
	if _over or _leaving >= 0.0:
		return
	if _near == "exit":
		_leave()
	elif _near == "altar":
		_use_altar()
	elif _near == "cache":
		var got: int = meta.past_cache()
		if got > 0:
			PastBuilder.open_cache(_chest)
			_sfx.play(&"thump", _chest.position, -3.0, 0.7)
			_hud.toast("성스러운 숲의 함에서 조각 %d개를 얻었다" % got)
			_saved()


## 첫 대장간 제단(E): 조각 PastLayout.REFORGE_COST개로 검집의 검을 다시 벼린다. 검 번호마다 한 번.
func _use_altar() -> void:
	var r: Dictionary = meta.reforge(data)
	var d: SwordData = data.sword_by_id(meta.sheath_id)
	match String(r.why):
		"ok":
			_sfx.play(&"thump", Grid.cells_to_world(PastLayout.ALTAR_AT), -2.0, 0.6)
			_hud.flash(Color(1.0, 0.75, 0.35), 0.3, 0.8)
			_hud.toast("%s이(가) 최초의 불에 다시 벼려졌다. 내구 +%d%%" % [d.display_name, roundi(PastLayout.REFORGE_DUR * 100.0)])
			_saved()
		"none":
			_hud.toast("검집에 든 검이 없다. 마을 대장간에서 검을 검집에 꽂아 두어야 한다.")
		"done":
			_hud.toast("%s은(는) 이미 최초의 불을 거쳤다." % d.display_name)
		_:
			_hud.toast("조각이 모자란다. (%d개 필요)" % PastLayout.REFORGE_COST)


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
	_lord.set_slash_override(Color(PastLayout.TRAIL, 1.0))   # 과거의 베기 빛은 따뜻한 금빛
	_lord.set_sword(s, data.grades)
	_move_fx.tint = PastLayout.TRAIL


# ---------------------------------------------------------------- 그리기

## 화로 불빛이 일렁인다(꾸밈, 화면 쪽 랜덤).
func _flicker(delta: float) -> void:
	_t += delta
	for f in _fires:
		var l: OmniLight3D = f.light
		var base: float = 0.8 if l.light_energy < 1.2 else 1.6
		l.light_energy = base * (0.85 + 0.15 * sin(_t * 7.0 + float(f.phase)) + _flick.randf_range(-0.05, 0.05))


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
	_float(at + Vector3(0, 1.2 + Grid.cells_to_meters(e.radius) * 2.2, 0), str(roundi(damage)), Color(1.0, 0.85, 0.5) if big else Color.WHITE, 52 if big else 34)
	_camera.add_shake(data.lord.shake_big if big else data.lord.shake)
	_sfx.play(&"hit_big" if big else &"hit", at, 0.0)


func _on_enemy_died(e: Enemy) -> void:
	if _held_id > 0:
		var tier: int = meta.log_kill(_held_id)
		var d: SwordData = data.sword_by_id(_held_id)
		if tier > 0 and d != null:
			_hud.toast("%s · 벤 적 %d" % [meta.memory_title(d), int(Meta.MEMORY[tier - 1][0])])
	if e.act != &"explode":
		_fx.splat(Grid.cells_to_world(e.pos), true)


## 영주가 쓰러졌다: 쥔 검을 들판에 떨구고 그 앞에서 깬다(미래 구역과 같은 자리).
func _on_down(_won: bool) -> void:
	_over = true
	PlayLog.down("past", rules, _held_id, "past")
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


func _on_slots() -> void:
	var s: Sword = rules.current()
	_held_id = s.data.id if s and s.data else 0
	_lord.set_sword(s, data.grades)
	_move_fx.tint = PastLayout.TRAIL


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


## 현재는 들판으로, 미래는 들판을 거쳐(Meta.go_future를 들판이 이어받는다) 건넌다.
func _on_era_picked(era: StringName) -> void:
	_ui.close()
	if _over or _leaving >= 0.0 or era == TimeTravel.ERA_PAST:
		return
	if not meta.can_travel(rules):
		_hud.toast("싸움 중에는 시간이 열리지 않는다.")
		return
	if era == TimeTravel.ERA_FUTURE:
		Meta.go_future = true
	_leave()
