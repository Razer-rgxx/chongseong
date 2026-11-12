extends Node3D
## 본 장면. 입력을 모아 규칙을 고정 틱으로 돌리고, 규칙의 상태와 신호를 받아 그린다.
## 2단계: 영주 손맛 시험장. 영주관 둘레에 허수아비를 세워 둔다.

const LORD_SCENE: PackedScene = preload("res://scenes/lord/lord.tscn")
const DUMMY_SCENE: PackedScene = preload("res://scenes/enemies/dummy.tscn")

## 0이면 시작할 때 아무 시드나 고른다. 같은 판을 다시 보고 싶으면 값을 넣는다.
@export var seed_value: int = 0
## 한 프레임에 따라잡을 틱의 최대 수. 넘치면 밀린 시간을 버린다.
@export var max_ticks_per_frame: int = 8
## 허수아비 자리(영주관 칸에서 떨어진 칸 수).
@export var dummy_offsets: PackedVector2Array = PackedVector2Array([Vector2(-3, 3), Vector2(0, 4), Vector2(3, 3), Vector2(-4, 0), Vector2(4, 0), Vector2(-2, -4), Vector2(2, -4)])
@export var hit_number_size: int = 56
@export var big_number_size: int = 84

var data: GameData
var rules: Rules
var _acc: float = 0.0
var _want_attack: bool = false
var _want_dash: bool = false
var _lord: Node3D
var _dummies: Dictionary = {}

@onready var _sun: DirectionalLight3D = $Sun
@onready var _camera: Camera3D = $Camera
@onready var _sfx: Sfx = $Sfx
@onready var _status: Label = $UI/Status
@onready var _hp: ProgressBar = $UI/Hp


func _ready() -> void:
	data = GameData.load_default()
	var s: int = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
	rules = Rules.new(data, s)
	_build_placeholder_world()
	_lord = LORD_SCENE.instantiate()
	_lord.setup(rules)
	add_child(_lord)
	var c := Vector2(Grid.center()) + Vector2(0.5, 0.5)
	for off in dummy_offsets:
		var u := rules.add_dummy(c + off)
		var v := DUMMY_SCENE.instantiate()
		v.unit = u
		add_child(v)
		_dummies[u.id] = v
	rules.lord_swung.connect(_on_swung)
	rules.lord_dashed.connect(_on_dashed)
	rules.unit_hit.connect(_on_hit)
	_hp.max_value = data.lord.hp
	_camera.target = Grid.cells_to_world(rules.lord.pos)
	_camera.snap()


func _unhandled_input(event: InputEvent) -> void:
	# 틱 사이에 눌렀다 뗀 것도 놓치지 않게 모아 둔다
	if event.is_action_pressed("attack"):
		_want_attack = true
	if event.is_action_pressed("dash"):
		_want_dash = true
	var k := event as InputEventKey
	if k and k.pressed and not k.echo:
		if k.physical_keycode == KEY_N:
			rules.start_night()
		elif k.physical_keycode == KEY_M:
			rules.end_night()


func _physics_process(delta: float) -> void:
	_acc += delta
	var n: int = 0
	while _acc >= rules.dt and n < max_ticks_per_frame:
		rules.step(_read_input())
		_want_attack = false
		_want_dash = false
		_acc -= rules.dt
		n += 1
	if n == max_ticks_per_frame:
		_acc = 0.0


func _read_input() -> LordInput:
	var inp := LordInput.new()
	inp.move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	inp.attack = Input.is_action_pressed("attack") or _want_attack
	inp.dash = _want_dash
	var g: Variant = _camera.ground_point(get_viewport().get_mouse_position())
	if g != null:
		inp.aim_valid = true
		inp.aim = Grid.world_to_cells(g)
	return inp


func _process(delta: float) -> void:
	var alpha: float = clampf(_acc / rules.dt, 0.0, 1.0)
	_lord.draw(alpha, delta)
	for v in _dummies.values():
		v.draw(alpha, delta)
	_camera.target = _lord.position
	_hp.value = rules.lord.hp
	var phase_text: String = "낮 · 밤까지 %d초" % ceili(rules.day_left) if rules.phase == Rules.Phase.DAY else ("밤" if rules.phase == Rules.Phase.NIGHT else "끝")
	_status.text = "%d일째 %s\n나무 %d · 돌 %d · 금화 %d\n틱 %d · 시드 %d" % [rules.day, phase_text, rules.wood, rules.stone, rules.gold, rules.tick, rules.seed_value]


func _on_swung(big: bool) -> void:
	_sfx.play(&"swish", _lord.position, -4.0 if big else -8.0)


func _on_dashed() -> void:
	_sfx.play(&"dash", _lord.position, -6.0)


func _on_hit(u: Unit, damage: float, big: bool) -> void:
	var at: Vector3 = Grid.cells_to_world(u.pos)
	if _dummies.has(u.id):
		_dummies[u.id].hit(big)
	var t := FloatText.new()
	t.text = str(roundi(damage))
	t.font_size = big_number_size if big else hit_number_size
	t.modulate = Color(1, 0.86, 0.45) if big else Color.WHITE
	add_child(t)
	t.global_position = at + Vector3(0, 2.4, 0)
	_camera.add_shake(data.lord.shake_big if big else data.lord.shake)
	_sfx.play(&"hit_big" if big else &"hit", at)


func _build_placeholder_world() -> void:
	var side: float = Grid.size * Grid.CELL
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(side, side)
	ground.mesh = plane
	ground.position = Vector3(side / 2.0, 0.0, side / 2.0)
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.2, 0.3, 0.18)
	ground.material_override = grass
	add_child(ground)

	# 영주관 자리: 가운데 칸에 상자 하나(4단계에서 진짜 영주관으로 바꾼다)
	var hall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(Grid.CELL * 1.4, 2.4, Grid.CELL * 1.4)
	hall.mesh = box
	hall.position = Grid.cell_to_world(Grid.center(), box.size.y / 2.0)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.49, 0.35, 0.53)
	hall.material_override = stone
	add_child(hall)

	_sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
