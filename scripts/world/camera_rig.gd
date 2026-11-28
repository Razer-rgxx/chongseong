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
@export var follow_speed: float = 24.0
## 흔들림 1일 때 몇 m까지 흔들리는지.
@export var shake_meters: float = 0.9
@export var shake_decay: float = 2.5

@export_group("모션 블러")
## 0이면 끈다. 1이면 한 프레임 동안 움직인 만큼 그대로 번진다.
@export var motion_blur: float = 0.5
## 이 거리(m) 안은 번지지 않는다(영주와 바로 앞의 적은 또렷하게).
@export var blur_mask_near: float = 9.0
## 빠르게 움직일 때 화면 가장자리가 가운데로 빨려 드는 세기(main이 돌진·갈고리 때 올린다).
var speed_blur: float = 0.0
## false면 번짐 판을 아예 그리지 않는다(웹판, WebQuality).
var blur_allowed: bool = true
## 이 값이 follow_speed보다 크면 그만큼 빨리 따라간다(갈고리로 멀리 날아갈 때 main이 올린다).
var follow_boost: float = 0.0
## 시야각을 잠깐 넓히는 값(도). 줄어들며 원래대로 돌아온다.
var fov_kick: float = 0.0
@export var fov_kick_decay: float = 18.0
## 큰 베기·마무리 때 시야각을 잠깐 좁혔다 돌아오는 값(도, 흔들기·fov_kick과 따로). 수치는 Juice.FOV_PINCH_*.
var fov_pinch: float = 0.0
## 39단계 말: 탄 정도(0~1, 장면이 HorseData.camera_blend초에 걸쳐 바꾼다). 탔으면 거리 × ride_far, 보는 점이 ride_up m 높아진다.
var ride: float = 0.0
var ride_far: float = 1.35
var ride_up: float = 0.9

var target: Vector3 = Vector3.ZERO
var zoom: float = 1.0
var shake: float = 0.0
## 3인칭에서 바라보는 방향(라디안). 0이면 -Z(북쪽)를 본다.
var yaw: float = 0.0
var pitch: float = deg_to_rad(22.0)
var _focus: Vector3 = Vector3.ZERO
## 화면 흔들림 전용. 게임 규칙의 랜덤(Rules.rng)과 따로 둔다.
var _rng := RandomNumberGenerator.new()
var _blur: MeshInstance3D = null
var _blur_mat: ShaderMaterial = null
var _prev_xf: Transform3D = Transform3D.IDENTITY
var _base_fov: float = 75.0
var _radial: float = 0.0


func _ready() -> void:
	GameSettings.ensure()   # 27단계: 저장한 소리 크기·키를 처음 한 번 적용
	_base_fov = fov
	_blur = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 2.0)
	_blur.mesh = q
	_blur_mat = ShaderMaterial.new()
	_blur_mat.shader = preload("res://scripts/world/motion_blur.gdshader")
	# 다른 반투명(베기 빛, 불꽃)보다 먼저 그려서 그것들은 번지지 않게
	_blur_mat.render_priority = -128
	_blur.material_override = _blur_mat
	_blur.extra_cull_margin = 16384.0
	_blur.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_blur)
	_prev_xf = global_transform


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
	var sens: float = mouse_sensitivity * GameSettings.mouse()   # 27단계: 설정의 감도 배수
	yaw -= delta.x * sens
	pitch = clampf(pitch + delta.y * sens, deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))


func _process(delta: float) -> void:
	_focus = _focus.lerp(target, 1.0 - exp(-maxf(follow_speed, follow_boost) * delta))
	shake = maxf(0.0, shake - delta * shake_decay)
	var sh: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.5, 0.5), _rng.randf_range(-1, 1)) * shake * shake_meters
	if mode == Mode.THIRD:
		var back := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
		var right := Vector3(cos(yaw), 0.0, -sin(yaw))
		var pivot: Vector3 = _focus + Vector3(0.0, look_height + ride_up * ride, 0.0) + right * shoulder
		global_position = pivot + back * (third_distance * lerpf(1.0, ride_far, ride) / zoom) + sh * 0.4
		look_at(pivot + sh * 0.4, Vector3.UP)
	else:
		var p: float = deg_to_rad(pitch_deg)
		var off: Vector3 = Vector3(0.0, sin(p), cos(p)) * (distance * lerpf(1.0, ride_far, ride) / zoom)
		global_position = _focus + off + sh
		look_at(_focus + sh, Vector3.UP)
	fov_kick = maxf(0.0, fov_kick - delta * fov_kick_decay)
	fov_pinch = maxf(0.0, fov_pinch - delta * Juice.FOV_PINCH_DECAY)
	fov = _base_fov + fov_kick - fov_pinch
	_radial = lerpf(_radial, speed_blur, 1.0 - exp(-12.0 * delta))
	if _blur:
		_blur.visible = blur_allowed and (motion_blur > 0.0 or _radial > 0.001)
		_blur_mat.set_shader_parameter("prev_view", Projection(_prev_xf.affine_inverse()))
		_blur_mat.set_shader_parameter("strength", motion_blur)
		_blur_mat.set_shader_parameter("mask_near", blur_mask_near)
		_blur_mat.set_shader_parameter("radial", _radial)
	_prev_xf = global_transform


## 시야각을 deg도 좁힌다(줄어들며 돌아온다). 더 큰 값이 이미 있으면 그대로 둔다.
func pinch(deg: float) -> void:
	fov_pinch = maxf(fov_pinch, deg)


func kick(deg: float) -> void:
	fov_kick = maxf(fov_kick, deg)


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
