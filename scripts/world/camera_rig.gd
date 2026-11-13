extends Camera3D
## 카메라. 기본은 3인칭(영주 등 뒤, 마우스로 둘러봄). V로 쿼터뷰(위에서 비스듬히)와 바꾼다.
## 목표를 부드럽게 따라가고, 휠로 거리를 바꾸고, 맞힐 때 흔들린다.

enum Mode { THIRD, QUARTER }

@export var mode: Mode = Mode.THIRD

@export_group("3인칭")
@export var third_distance: float = 8.0
## 어깨 너머로 보도록 오른쪽으로 비키는 거리(m).
@export var shoulder: float = 0.7
## 바라보는 점의 높이(m).
@export var look_height: float = 1.6
@export var pitch_min_deg: float = -5.0
@export var pitch_max_deg: float = 60.0
@export var mouse_sensitivity: float = 0.0035

@export_group("쿼터뷰")
@export var pitch_deg: float = 55.0
@export var distance: float = 22.0

@export_group("공통")
@export var zoom_min: float = 0.55
@export var zoom_max: float = 1.8
@export var follow_speed: float = 10.0
## 흔들림 1일 때 몇 m까지 흔들리는지.
@export var shake_meters: float = 0.9
@export var shake_decay: float = 2.5

var target: Vector3 = Vector3.ZERO
var zoom: float = 1.0
var shake: float = 0.0
## 3인칭에서 바라보는 방향(라디안). 0이면 -Z(북쪽)를 본다.
var yaw: float = 0.0
var pitch: float = deg_to_rad(22.0)
var _focus: Vector3 = Vector3.ZERO
## 화면 흔들림 전용. 게임 규칙의 랜덤(Rules.rng)과 따로 둔다.
var _rng := RandomNumberGenerator.new()


func snap() -> void:
	_focus = target


func add_shake(v: float) -> void:
	shake = maxf(shake, v)


func toggle_mode() -> void:
	mode = Mode.QUARTER if mode == Mode.THIRD else Mode.THIRD


func third() -> bool:
	return mode == Mode.THIRD


## 3인칭에서 카메라가 보는 앞쪽(땅 위, 칸 좌표 방향).
func forward_cells() -> Vector2:
	return Vector2(-sin(yaw), -cos(yaw))


## 입력(x 오른쪽, y 아래 = 뒤)을 카메라 기준의 땅 위 방향으로 바꾼다. 쿼터뷰는 화면 그대로.
func relative_move(v: Vector2) -> Vector2:
	if mode == Mode.QUARTER:
		return v
	var f := forward_cells()
	var r := Vector2(-f.y, f.x)
	return r * v.x + f * -v.y


func look(delta: Vector2) -> void:
	yaw -= delta.x * mouse_sensitivity
	pitch = clampf(pitch + delta.y * mouse_sensitivity, deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))


func _process(delta: float) -> void:
	_focus = _focus.lerp(target, minf(1.0, delta * follow_speed))
	shake = maxf(0.0, shake - delta * shake_decay)
	var sh: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.5, 0.5), _rng.randf_range(-1, 1)) * shake * shake_meters
	if mode == Mode.THIRD:
		var back := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
		var right := Vector3(cos(yaw), 0.0, -sin(yaw))
		var pivot: Vector3 = _focus + Vector3(0.0, look_height, 0.0) + right * shoulder
		global_position = pivot + back * (third_distance / zoom) + sh * 0.4
		look_at(pivot + sh * 0.4, Vector3.UP)
	else:
		var p: float = deg_to_rad(pitch_deg)
		var off: Vector3 = Vector3(0.0, sin(p), cos(p)) * (distance / zoom)
		global_position = _focus + off + sh
		look_at(_focus + sh, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom = clampf(zoom * 1.1, zoom_min, zoom_max)
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom = clampf(zoom / 1.1, zoom_min, zoom_max)


## 화면 위의 한 점이 가리키는 땅(높이 0) 위치. 땅을 안 가리키면 null. 쿼터뷰에서 마우스로 겨눌 때 쓴다.
func ground_point(screen: Vector2) -> Variant:
	var o: Vector3 = project_ray_origin(screen)
	var d: Vector3 = project_ray_normal(screen)
	if absf(d.y) < 0.0001:
		return null
	var t: float = -o.y / d.y
	if t < 0.0:
		return null
	return o + d * t
