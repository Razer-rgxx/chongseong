extends Node3D
## 마을 밖 들판(16단계, docs/village.md 16). 싸움 없이 걷고 구르며 찾는다.
## 영주의 걷기는 마을과 같은 Rules로 돌리고(싸움터 크기만 들판으로), 막힌 곳은 화면 쪽에서 밀어낸다.
## 높이는 FieldBuilder.walk_height를 따라 영주를 그린다. 보상과 읽음은 Meta에 저장한다.

const LORD_SCENE: PackedScene = preload("res://scenes/lord/lord.tscn")
const VILLAGE_PATH: String = "res://scenes/lobby/lobby.tscn"
const RUN_PATH: String = "res://scenes/world/main.tscn"

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
	rules = Rules.new(data, 1)
	Grid.size = FieldLayout.SIZE   # Rules가 싸움터 크기로 영주를 가둔다: 들판 크기로
	rules.hilts.clear()
	rules.lord.pos = FieldLayout.START
	rules.lord.prev_pos = rules.lord.pos
	_hud.setup(data, meta)
	var env: Environment = ($Environment as WorldEnvironment).environment
	HillBuilder.apply_sky(env, Color(1.0, 0.8, 0.68), 0.75)
	var blockers: Dictionary = FieldBuilder.build(self, env)
	_rects.assign(blockers.rects)
	_circles = blockers.circles
	_build_props()
	add_child(_creatures)
	_lord = LORD_SCENE.instantiate()
	_lord.setup(rules)
	add_child(_lord)
	_lord.set_sword(meta.sheath_sword(data), data.grades)
	_lord.torch.light_energy = 1.2
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
		if _camera.third() and inp.move.length() > 0.1:
			inp.aim_valid = true
			inp.aim = rules.lord.pos + inp.move
		rules.step(inp)
		rules.lord.pos = _push_out(rules.lord.pos)
		_want_dash = false
		_acc -= rules.dt
		n += 1
	if n == max_ticks_per_frame:
		_acc = 0.0


func _process(delta: float) -> void:
	var alpha: float = clampf(_acc / rules.dt, 0.0, 1.0)
	_lord.draw(alpha, delta)
	_lord.position.y = FieldBuilder.walk_height(_lord.position.x, _lord.position.z)
	_camera.target = _lord.position
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
	var s := {"gate": FieldLayout.GATE, "trail": FieldLayout.TRAILHEAD}
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
	if key.begins_with("cache"):
		return "유품을 연다"
	if key.begins_with("stone"):
		return "비석을 읽는다"
	return "쇳조각을 줍는다"


func _interact() -> void:
	if _reading != "":
		_end_read()
		return
	if _near == "gate":
		_leave(VILLAGE_PATH)
	elif _near == "trail":
		_leave(RUN_PATH)
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


func _end_read() -> void:
	_reading = ""
	_hud.say_end()


func _saved() -> void:
	meta.save()
	_hud.refresh_top()


func _leave(path: String) -> void:
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
