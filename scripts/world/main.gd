extends Node3D
## 1단계 자리 잡기용 본 장면. 규칙을 고정 틱으로 돌리고, 바닥과 영주관 자리를 기본 도형으로 놓고, 상태를 글자로 보여 준다.
## N: 밤 시작, M: 밤 끝내기(습격은 4단계에서 넣는다).

## 0이면 시작할 때 아무 시드나 고른다. 같은 판을 다시 보고 싶으면 값을 넣는다.
@export var seed_value: int = 0
## 한 프레임에 따라잡을 틱의 최대 수. 넘치면 밀린 시간을 버린다.
@export var max_ticks_per_frame: int = 8

var data: GameData
var rules: Rules
var _acc: float = 0.0

@onready var _sun: DirectionalLight3D = $Sun
@onready var _camera: Camera3D = $Camera
@onready var _status: Label = $UI/Status


func _ready() -> void:
	data = GameData.load_default()
	var s: int = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
	rules = Rules.new(data, s)
	_build_placeholder_world()


func _physics_process(delta: float) -> void:
	_acc += delta
	var n: int = 0
	while _acc >= rules.dt and n < max_ticks_per_frame:
		rules.step()
		_acc -= rules.dt
		n += 1
	if n == max_ticks_per_frame:
		_acc = 0.0


func _process(_delta: float) -> void:
	var phase_text: String = "낮 · 밤까지 %d초" % ceili(rules.day_left) if rules.phase == Rules.Phase.DAY else ("밤" if rules.phase == Rules.Phase.NIGHT else "끝")
	_status.text = "%d일째 %s\n나무 %d · 돌 %d · 금화 %d\n틱 %d · 시드 %d\nN 밤 시작 · M 밤 끝내기" % [rules.day, phase_text, rules.wood, rules.stone, rules.gold, rules.tick, rules.seed_value]


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.physical_keycode == KEY_N:
		rules.start_night()
	elif k.physical_keycode == KEY_M:
		rules.end_night()


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

	# 영주관 자리: 가운데 칸에 상자 하나
	var hall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(Grid.CELL * 1.4, 2.4, Grid.CELL * 1.4)
	hall.mesh = box
	hall.position = Grid.cell_to_world(Grid.center(), box.size.y / 2.0)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.49, 0.35, 0.53)
	hall.material_override = stone
	add_child(hall)

	var focus: Vector3 = Grid.cell_to_world(Grid.center())
	_camera.position = focus + Vector3(0.0, 34.0, 30.0)
	_camera.look_at(focus)
	_sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
