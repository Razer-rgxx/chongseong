extends Node3D
## 언덕(한 판). 입력을 모아 규칙을 고정 틱으로 돌리고, 규칙의 상태와 신호를 받아 그린다.
## 낮: 언덕에 꽂힌 검을 E로 뽑는다. 밤(N): 뽑은 검으로 버틴다. 열 구역을 올라 정상의 언덕지기를 쓰러뜨리면 끝.
## 끝나면 조각을 마을(scenes/lobby/lobby.tscn)로 가져간다.

const LORD_SCENE: PackedScene = preload("res://scenes/lord/lord.tscn")
const LOBBY_PATH: String = "res://scenes/lobby/lobby.tscn"

## 0이면 시작할 때 아무 시드나 고른다. 같은 판을 다시 보고 싶으면 값을 넣는다.
@export var seed_value: int = 0
## 한 프레임에 따라잡을 틱의 최대 수. 넘치면 밀린 시간을 버린다.
@export var max_ticks_per_frame: int = 8
@export var hit_number_size: int = 56
@export var big_number_size: int = 84

@export_group("낮과 밤의 빛")
@export var day_sun: float = 1.1
@export var night_sun: float = 0.1
@export var day_ambient: float = 0.55
@export var night_ambient: float = 0.1
@export var night_sun_color: Color = Color(0.55, 0.65, 1.0)
@export var torch_energy: float = 2.6
@export var light_change_time: float = 1.5

var data: GameData
var rules: Rules
var meta: Meta
var _acc: float = 0.0
var _want_attack: bool = false
var _want_dash: bool = false
var _want_pull: bool = false
var _swap_to: int = -1
var _lord: Node3D
var _hilts: Dictionary = {}
var _enemies: Dictionary = {}
var _dying: Array[EnemyView] = []
var _hud_t: float = 0.0
var _altar_view: Node3D = null

@onready var _env: WorldEnvironment = $Environment
@onready var _sun: DirectionalLight3D = $Sun
@onready var _camera: Camera3D = $Camera
@onready var _sfx: Sfx = $Sfx
@onready var _hud: Hud = $UI


func _ready() -> void:
	data = GameData.load_default()
	meta = Meta.load_or_new()
	meta.fix_sheath(data)
	var s: int = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
	rules = Rules.new(data, s, meta)
	_build_world()
	_lord = LORD_SCENE.instantiate()
	_lord.setup(rules)
	add_child(_lord)
	rules.day_started.connect(_on_day)
	rules.night_started.connect(_on_night)
	rules.run_ended.connect(_on_end)
	rules.pull_started.connect(func(_h: Hilt, _g: int) -> void: _sfx.play(&"thump", _lord.position, -10.0))
	rules.pull_step.connect(_on_pull_step)
	rules.pull_refused.connect(func(t: String) -> void: _hud.toast(t))
	rules.sword_pulled.connect(_on_pulled)
	rules.choice_needed.connect(_on_choice_needed)
	rules.slots_changed.connect(_refresh_cards)
	rules.sword_broke.connect(_on_broke)
	rules.lord_swung.connect(func(big: bool) -> void: _sfx.play(&"swish", _lord.position, -4.0 if big else -8.0))
	rules.lord_dashed.connect(func() -> void: _sfx.play(&"dash", _lord.position, -6.0))
	rules.lord_hurt.connect(_on_lord_hurt)
	rules.enemy_hit.connect(_on_enemy_hit)
	rules.enemy_died.connect(_on_enemy_died)
	rules.elite_spawned.connect(func(e: Enemy) -> void: _hud.toast("정예 %s이(가) 올라온다. 쓰러뜨리면 공짜 뽑기." % e.data.display_name))
	rules.altar_opened.connect(_on_altar_opened)
	rules.altar_used.connect(_on_altar_used)
	rules.boss_spawned.connect(func(_e: Enemy) -> void: _hud.toast("언덕지기가 올라온다."); _camera.add_shake(0.5); _sfx.play(&"night", _lord.position, 0.0))
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
	var start: String = "검집에서 %s을(를) 꺼냈다. " % rules.slots[0].label() if rules.slots[0] else ""
	_hud.area_title(_zone_name())
	_hud.toast("%s꽂힌 검 앞에서 E를 눌러 뽑는다. 한 번에 체력 %d. 준비되면 N으로 밤을 맞는다." % [start, rules.pull_cost()])
	_capture(true)


## 3인칭에서는 마우스를 가둬 둘러보게 한다. 창이 열리면 풀어 준다.
func _capture(on: bool) -> void:
	var want: bool = on and _camera.third() and rules.phase != Rules.Phase.OVER and not _hud.choice_open() and not _hud.altar_is_open()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if want else Input.MOUSE_MODE_VISIBLE


func _to_lobby() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(LOBBY_PATH)


func _unhandled_input(event: InputEvent) -> void:
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
	if _hud.choice_open():
		if event.is_action_pressed("slot_1"):
			_hud.pick(0)
		elif event.is_action_pressed("slot_2"):
			_hud.pick(1)
		elif event.is_action_pressed("discard"):
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
	if event.is_action_pressed("pull"):
		_want_pull = true
	if event.is_action_pressed("swap"):
		_swap_to = 2
	if event.is_action_pressed("slot_1"):
		_swap_to = 0
	if event.is_action_pressed("slot_2"):
		_swap_to = 1
	if event.is_action_pressed("start_night"):
		rules.start_night()
	var k := event as InputEventKey
	if k and k.pressed and not k.echo:
		match k.physical_keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
			KEY_F4:
				rules.debug_grade = rules.debug_grade + 1 if rules.debug_grade < 5 else -1
				_hud.toast("관리: 다음 뽑기 " + ("등급 굴리기" if rules.debug_grade < 0 else data.grades.names[rules.debug_grade] + "로 고정"))


func _physics_process(delta: float) -> void:
	_acc += delta
	var n: int = 0
	while _acc >= rules.dt and n < max_ticks_per_frame:
		rules.step(_read_input())
		_want_attack = false
		_want_dash = false
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
	inp.pull = _want_pull
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
	_sync_enemies(alpha, delta)
	_camera.target = _lord.position
	var near := rules.nearest_hilt(data.run.pull_reach) if rules.phase == Rules.Phase.DAY and rules.pull_hilt == null and rules.pending == null else null
	var altar_near: bool = rules.near_altar() and rules.pull_hilt == null and rules.pending == null and not rules.altar_open
	if altar_near:
		_hud.set_prompt("E", "숫돌 제단에 선다")
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
	if night:
		sub = ("새벽까지 %d초" % ceili(rules.night_left)) if rules.night_left > 0.0 else "언덕지기를 쓰러뜨려"
		sub += " · 적 %d" % rules.enemies.size()
	else:
		var left: int = 0
		for h in rules.hilts:
			left += 0 if h.gone else 1
		sub = "남은 검 %d · 뽑기 운 ×%s" % [left, str(snappedf(rules.luck(), 0.01))]
		if rules.free_pulls > 0:
			sub += " · 공짜 뽑기 %d" % rules.free_pulls
	var k: float = 1.0 - maxf(0.0, rules.night_left) / data.run.night_length if night else 0.0
	_hud.set_status(rules.lord.hp, rules.max_hp(), "%s · %s" % [_zone_name(), "밤" if night else "낮"], sub, k, night or rules.phase == Rules.Phase.OVER)
	var boss: Enemy = null
	for e in rules.enemies:
		if e.data.boss:
			boss = e
	_hud.set_boss(boss)
	_refresh_cards()


# ---------------------------------------------------------------- 카드

func _card(s: Sword, slot: int, held: bool) -> String:
	return SwordCard.bbcode(s, data, slot, held)


func _refresh_cards() -> void:
	var texts: Array[String] = []
	var cols: Array[Color] = []
	for k in 2:
		var s := rules.slots[k]
		texts.append(_card(s, k, k == rules.active))
		cols.append(data.grades.colors[s.grade] if s else Color(0.4, 0.45, 0.55))
	_hud.set_cards(texts, cols, rules.active)
	_lord.set_sword(rules.current(), data.grades)


# ---------------------------------------------------------------- 신호

func _on_day(_zone: int) -> void:
	for v in _hilts.values():
		v.queue_free()
	_hilts.clear()
	_sync_hilts()
	_sync_altar()
	_set_light(false)
	_hud.area_title(_zone_name())
	_hud.toast("날이 밝았다. 체력 +%d · 뽑기 운 ×%s%s" % [rules.heal_at_dawn(), str(snappedf(rules.luck(), 0.01)), " · 숫돌 제단이 섰다" if rules.altar else ""])


func _on_night(_zone: int) -> void:
	for v in _hilts.values():
		v.queue_free()
	_hilts.clear()
	_sync_altar()
	_set_light(true)
	_sfx.play(&"night", _lord.position, -2.0)
	_hud.toast("밤이 왔다. %d초를 버텨.%s" % [data.run.night_length, " 정상의 언덕지기를 쓰러뜨려야 끝난다." if rules.last_zone() else ""])


func _on_end(won: bool) -> void:
	var best: String = data.grades.names[rules.best_grade] if rules.best_grade >= 0 else "없음"
	var title: String = "언덕의 정상에 섰다" if won else "%d구역에서 쓰러졌다" % (rules.zone + 1)
	var r := meta.record_run(rules, data.meta)
	meta.save()
	_hud.show_over(title, "뽑은 검 %d자루 · 쓰러뜨린 적 %d · 가장 높은 등급 %s\n조각 +%d  (처치 %d · 구역 %d · 부러진 검 %d · 정예 %d · 녹인 검 %d)" % [rules.pulls, rules.kills, best, r.total, r.kills, r.zone, r.broken, r.elite, r.melt])
	_capture(false)


func _on_pull_step(_h: Hilt, st: int) -> void:
	_camera.add_shake(0.12 + 0.07 * st)
	_sfx.play(&"thump", _lord.position, -6.0 + st)


func _on_pulled(s: Sword) -> void:
	meta.note_found(s.data.id)
	meta.save()
	var c: Color = data.grades.colors[s.grade]
	_sfx.play(&"draw", _lord.position, -4.0)
	if s.grade >= data.grades.reveal_from:
		# 등급 연출 영상은 6단계에서 넣는다. 그전까지는 0.5초 번쩍임.
		_hud.flash(c, 0.35 + 0.1 * s.grade)
		_camera.add_shake(0.3 + 0.08 * s.grade)
	var t := FloatText.new()
	t.text = s.data.display_name
	t.font_size = 64 + 8 * s.grade
	t.modulate = c
	t.life = 1.6
	add_child(t)
	t.global_position = _lord_world() + Vector3(0, 2.6, 0)
	_hud.toast("%s · %s %s을(를) 뽑았다." % [data.grades.names[s.grade], s.form.display_name, s.data.display_name])


func _on_choice_needed(s: Sword) -> void:
	_hud.open_choice(_card(s, -1, false), _card(rules.slots[0], 0, false), _card(rules.slots[1], 1, false))
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
	_sfx.play(&"thump", _lord.position, 0.0)
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
		_enemies[e.id].hit()
	_float(at + Vector3(0, 1.2 + Grid.cells_to_meters(e.radius) * 2.2, 0), str(roundi(damage)), Color(1, 0.86, 0.45) if big else Color.WHITE, big_number_size if big else hit_number_size)
	_camera.add_shake(data.lord.shake_big if big else data.lord.shake)
	_sfx.play(&"hit_big" if big else &"hit", at)


func _on_enemy_died(e: Enemy) -> void:
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
	tw.tween_property(_sun, "light_color", night_sun_color if night else Color.WHITE, t)
	tw.tween_property(env, "ambient_light_energy", night_ambient if night else day_ambient, t)
	tw.tween_property(env, "background_color", Color(0.01, 0.015, 0.03) if night else Color(0.06, 0.08, 0.12), t)
	tw.tween_property(_lord.torch, "light_energy", torch_energy if night else 0.0, t)


## 언덕 꼭대기(싸움터)와 그 아래 땅. 에셋이 들어오면 이 함수만 바꾼다.
func _build_world() -> void:
	var size := Vector2(Grid.size) * Grid.CELL
	var top := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size.x, 1.6, size.y)
	top.mesh = box
	top.position = Vector3(size.x / 2.0, -0.8, size.y / 2.0)
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.23, 0.29, 0.19)
	grass.roughness = 1.0
	top.material_override = grass
	add_child(top)
	var below := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size.x + 400.0, size.y + 400.0)
	below.mesh = plane
	below.position = Vector3(size.x / 2.0, -1.6, size.y / 2.0)
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color(0.11, 0.13, 0.1)
	dirt.roughness = 1.0
	below.material_override = dirt
	add_child(below)
	# 언덕 아래의 바위(꾸밈. 규칙의 랜덤과 따로 둔다)
	var deco := RandomNumberGenerator.new()
	deco.seed = 7
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.2, 0.21, 0.22)
	for i in 160:
		var p := Vector3(deco.randf_range(-40.0, size.x + 40.0), -1.6, deco.randf_range(-40.0, size.y + 40.0))
		if p.x > -2.0 and p.x < size.x + 2.0 and p.z > -2.0 and p.z < size.y + 2.0:
			continue
		var m := MeshInstance3D.new()
		var s := SphereMesh.new()
		var r: float = deco.randf_range(0.4, 1.6)
		s.radius = r
		s.height = r * 1.2
		m.mesh = s
		m.material_override = rock
		m.position = p
		add_child(m)
	_sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
