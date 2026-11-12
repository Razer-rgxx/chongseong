extends Camera3D
## 쿼터뷰 카메라. 목표를 부드럽게 따라가고, 휠로 확대하고, 맞힐 때 흔들린다.

@export var pitch_deg: float = 55.0
@export var distance: float = 22.0
@export var zoom_min: float = 0.55
@export var zoom_max: float = 1.8
@export var follow_speed: float = 6.0
## 흔들림 1일 때 몇 m까지 흔들리는지.
@export var shake_meters: float = 0.9
@export var shake_decay: float = 2.5

var target: Vector3 = Vector3.ZERO
var zoom: float = 1.0
var shake: float = 0.0
var _focus: Vector3 = Vector3.ZERO
## 화면 흔들림 전용. 게임 규칙의 랜덤(Rules.rng)과 따로 둔다.
var _rng := RandomNumberGenerator.new()


func snap() -> void:
	_focus = target


func add_shake(v: float) -> void:
	shake = maxf(shake, v)


func _process(delta: float) -> void:
	_focus = _focus.lerp(target, minf(1.0, delta * follow_speed))
	shake = maxf(0.0, shake - delta * shake_decay)
	var p: float = deg_to_rad(pitch_deg)
	var off: Vector3 = Vector3(0.0, sin(p), cos(p)) * (distance / zoom)
	var sh: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.5, 0.5), _rng.randf_range(-1, 1)) * shake * shake_meters
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


## 화면 위의 한 점이 가리키는 땅(높이 0) 위치. 땅을 안 가리키면 null.
func ground_point(screen: Vector2) -> Variant:
	var o: Vector3 = project_ray_origin(screen)
	var d: Vector3 = project_ray_normal(screen)
	if absf(d.y) < 0.0001:
		return null
	var t: float = -o.y / d.y
	if t < 0.0:
		return null
	return o + d * t
