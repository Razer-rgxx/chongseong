extends Node3D
## 마을 밖 들판(16단계 탐험, 17단계 싸움). 걷고 구르며 찾고, 무리를 만나면 싸운다.
## 규칙은 Rules(들판 모드)가 돌리고(싸움터 크기만 들판으로), 막힌 곳은 화면 쪽에서 밀어낸다.
## 높이는 FieldBuilder.walk_height를 따라 영주와 적을 그린다. 보상과 읽음은 Meta에 저장한다.
## 마을 북문에서 고른 검(Meta.carry_sword)은 부러지지 않는 검으로 칸 0에 쥔다. 쓰러지면 잃는 것 없이 마을 북문 앞에서 깬다.

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
var _lord: Node3D
var _near: String = ""
var _rects: Array[Rect2] = []
var _circles: Array = []
var _props: Dictionary = {}
var _area: StringName = &""
var _shown: Dictionary = {}
var _reading: String = ""
var _creatures := FieldCreatures.new()
var _want_attack: bool = false
var _want_hook: bool = false
var _over: bool = false
var _enemies: Dictionary = {}
var _dying: Array[EnemyView] = []
var _fx := HitFx.new()
var _pfx := PowerFx.new()
var _move_fx := MoveFx.new()
var _enemy_fx := EnemyFx.new()

@onready var _camera: Camera3D = $Camera
@onready var _sfx: Sfx = $Sfx
@onready var _hud: LobbyHud = $UI
@onready var _sun: DirectionalLight3D = $Sun


func _ready() -> void:
	data = GameData.load_default()
	meta = Meta.load_or_new()
	meta.fix_sheath(data)
	meta.ensure_glints()
	meta.save()
	rules = Rules.new(data, int(Time.get_unix_time_from_system()))
	Grid.size = FieldLayout.SIZE   # Rules가 싸움터 크기로 영주를 가둔다: 들판 크기로
	rules.start_field()
	rules.spawn_packs(meta.packs_cleared)   # 이미 쓰러뜨린 무리는 안 생긴다
	if not meta.boss_down:
		rules.spawn_field_boss()   # 이번 판에 쓰러뜨렸으면 다시 서지 않는다(판이 끝나면 다시 선다)
	rules.lord.pos = FieldLayout.START
	if Meta.wake_at_crypt:   # 지하 무덤에서 나왔거나 쓰러졌다: 무덤 입구 앞에서 깬다
		Meta.wake_at_crypt = false
		rules.lord.pos = FieldLayout.CRYPT_WAKE
	rules.lord.prev_pos = rules.lord.pos
	_hud.setup(data, meta)
	var env: Environment = ($Environment as WorldEnvironment).environment
	HillBuilder.apply_sky(env, Color(1.0, 0.8, 0.68), 0.75)
	var blockers: Dictionary = FieldBuilder.build(self, env)
	_rects.assign(blockers.rects)
	_circles = blockers.circles
	HillBuilder.setup(Vector2(FieldLayout.SIZE) * Grid.CELL)   # 적의 몸이 들판을 싸움터 안으로 본다(비탈에서 올라오지 않는다)
	_build_props()
	add_child(_creatures)
	_lord = LORD_SCENE.instantiate()
	_lord.setup(rules)
	add_child(_lord)
	_lord.torch.light_energy = 1.2
	add_child(_fx)
	_pfx.setup(rules)
	add_child(_pfx)
	add_child(_move_fx)
	_move_fx.setup(rules)
	add_child(_enemy_fx)
	_enemy_fx.setup(rules, _enemy_parts)
	_enemy_fx.height_of = FieldBuilder.walk_height   # 땅의 빛·먼지가 들판의 땅 위에 뜬다
	_hold_sword()
	rules.lord_swung.connect(func(big: bool) -> void: _sfx.play(&"swish_big" if big else &"swish", _lord.position, -2.0 if big else -6.0))
	rules.lord_dashed.connect(func() -> void:
		_sfx.play(&"dash", _lord.position, -6.0)
		_camera.kick(4.0))
	rules.lord_hooked.connect(func(_e: Enemy) -> void:
		_sfx.play(&"draw", _lord.position, -2.0, 1.25)
		_camera.kick(10.0))
	rules.lord_hurt.connect(_on_lord_hurt)
	rules.enemy_hit.connect(_on_enemy_hit)
	rules.enemy_died.connect(_on_enemy_died)
	rules.pack_cleared.connect(_on_pack_cleared)
	rules.field_boss_slain.connect(_on_boss_slain)
	rules.enemy_act.connect(_on_enemy_act)
	rules.run_ended.connect(_on_down)
	rules.move_area.connect(func(_m: StringName, info: Dictionary) -> void: _sfx.play(&"thump", Grid.cells_to_world(info.get("at", rules.lord.pos)), -6.0, 0.8))
	_camera.target = Grid.cells_to_world(rules.lord.pos)
	_camera.yaw = 0.0
	_camera.snap()
	_sun.rotation_degrees = Vector3(-35.0, -60.0, 0.0)
	_capture(true)
	WebQuality.apply(self, env, _sun, _camera)   # 웹판에서만 가볍게


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
	if event.is_action_pressed("attack"):
		_want_attack = true
	if event.is_action_pressed("hook"):
		_want_hook = true
	if event.is_action_pressed("pull"):
		_interact()
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
		rules.lord.pos = _push_out(rules.lord.pos)
		_want_dash = false
		_want_attack = false
		_want_hook = false
		_acc -= rules.dt
		n += 1
	if n == max_ticks_per_frame:
		_acc = 0.0


func _process(delta: float) -> void:
	var alpha: float = clampf(_acc / rules.dt, 0.0, 1.0)
	_lord.draw(alpha, delta)
	_lord.position.y = FieldBuilder.walk_height(_lord.position.x, _lord.position.z)
	_camera.target = _lord.position
	_move_fx.draw(alpha)
	_enemy_fx.draw(alpha)
	_sync_enemies(alpha, delta)
	_hud.set_hp(rules.lord.hp, rules.max_hp())
	_boss_bar()
	_creatures.step(delta, _lord.position)
	var p: Vector2 = rules.lord.pos
	var a: StringName = FieldLayout.area_at(p)
	if a != _area:
		_area = a
		if not _shown.has(a):
			_shown[a] = true
			_hud.area_title(FieldLayout.AREA_NAMES[a])
	_near = ""
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
		return
	_hud.set_prompt("E", _prompt(_near) if _near != "" else "")


func _spots() -> Dictionary:
	var s := {"gate": FieldLayout.GATE, "trail": FieldLayout.TRAILHEAD, "crypt": FieldLayout.CRYPT_DOOR}
	for id in FieldLayout.CACHES:
		if not meta.field_found.has(id):
			s[id] = FieldLayout.CACHES[id][0]
	for id in FieldLayout.STONES:
		s[id] = FieldLayout.STONES[id][0]
	for i in meta.glints:
		s["glint_%d" % i] = FieldLayout.GLINTS[i]
	return s


func _prompt(key: String) -> String:
	if key == "gate":
		return "마을로 돌아간다"
	if key == "trail":
		return "언덕으로 오른다"
	if key == "crypt":
		return "지하 무덤으로 내려간다"
	if key.begins_with("cache"):
		return "유품을 연다"
	if key.begins_with("stone"):
		return "비석을 읽는다"
	return "쇳조각을 줍는다"


func _interact() -> void:
	if _over:
		return
	if _reading != "":
		_end_read()
		return
	if _near == "gate":
		_leave(VILLAGE_PATH)
	elif _near == "trail":
		_leave(RUN_PATH)
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
		_hud.say(info[1], info[2])
		var pay: int = 0
		if not meta.lore_read.has(_near):
			pay = meta.read_stone(_near)
			FieldBuilder.read_stone(_props[_near])
			_saved()
		if pay > 0:
			_hud.toast("비석을 모두 읽었다. 조각 %d개" % pay)
	elif _near.begins_with("glint"):
		var i: int = int(_near.substr(6))
		var got: int = meta.take_glint(i)
		if got > 0:
			FieldBuilder.take_glint(_props[_near])
			_props.erase(_near)
			_sfx.play(&"thump", _lord.position, -10.0, 1.6)
			_hud.toast("쇳조각 조각 %d개" % got)
			_saved()


## 고른 검을 칸 0에 쥔다(부러지지 않는다). 안 골랐으면 검집의 검, 0이면 맨손.
func _hold_sword() -> void:
	var id: int = Meta.carry_sword if Meta.carry_sword >= 0 else meta.sheath_id
	var s: Sword = meta.unbreakable_sword(data, id)
	rules.slots[0] = s
	rules.active = 0
	rules.lord.combo = 0
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
	_saved()


## 들판 보스가 깨어 있는 동안만 화면 아래 가운데에 체력 막대를 그린다(쓰러뜨리거나 멀어져 돌아가면 사라진다).
func _boss_bar() -> void:
	var b: Enemy = rules.field_boss
	if b != null and rules.field_boss_state == Rules.BOSS_AWAKE and not b.dead:
		_hud.set_boss(b.data.display_name, b.hp, b.max_hp)
	elif _hud.boss_bar_shown():
		_hud.set_boss("", 0.0, 1.0)


## 무덤 기사를 쓰러뜨렸다: 조각과 운 부적(Meta.boss_defeat)을 토스트로 알린다.
func _on_boss_slain(_e: Enemy) -> void:
	var r: Dictionary = meta.boss_defeat()
	_camera.add_shake(data.lord.shake_big * 2.0)
	_hud.flash(Color(1, 0.84, 0.42), 0.25, 0.9)
	_hud.toast("무덤 기사를 쓰러뜨렸다. 조각 %d개%s" % [r.shards, ", 운 부적" if r.charm else ""])
	_saved()


## 무덤 기사의 큰 일(휘두르기 내려침, 돌진)에 흔들림과 소리를 더한다(꾸밈).
func _on_enemy_act(e: Enemy, act: StringName, _info: Dictionary) -> void:
	if e.data.id != FieldLayout.BOSS_ID:
		return
	if act == &"swing" or act == &"charge_end":
		_camera.add_shake(0.35)
		_sfx.play(&"thump", Grid.cells_to_world(e.pos), -2.0, 0.7)


## 영주가 쓰러졌다: 잃는 것 없이 마을 북문 앞에서 깬다(record_run을 부르지 않는다).
func _on_down(_won: bool) -> void:
	_over = true
	Meta.carry_sword = -1
	meta.save()
	Meta.wake_at_gate = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hud.flash(Color(0.05, 0.0, 0.0), 0.85, 1.6)
	await get_tree().create_timer(1.6).timeout
	get_tree().change_scene_to_file(VILLAGE_PATH)


func _end_read() -> void:
	_reading = ""
	_hud.say_end()


func _saved() -> void:
	meta.save()
	_hud.refresh_top()


func _leave(path: String) -> void:
	Meta.carry_sword = -1   # 들판을 떠나면 검을 내려놓는다
	meta.save()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(path)


func _push_out(p: Vector2) -> Vector2:
	var r: float = 0.3
	for c in _circles:
		var d: Vector2 = p - c[0]
		var min_d: float = c[1] + r
		if d.length() < min_d:
			p = c[0] + (d.normalized() if d.length() > 0.001 else Vector2.DOWN) * min_d
	for rect in _rects:
		var g := rect.grow(r)
		if g.has_point(p):
			var left: float = p.x - g.position.x
			var right: float = g.end.x - p.x
			var up: float = p.y - g.position.y
			var down: float = g.end.y - p.y
			var m: float = minf(minf(left, right), minf(up, down))
			if m == left:
				p.x = g.position.x
			elif m == right:
				p.x = g.end.x
			elif m == up:
				p.y = g.position.y
			else:
				p.y = g.end.y
	return p
