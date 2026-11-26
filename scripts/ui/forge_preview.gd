class_name ForgePreview
extends SubViewportContainer
## 대장간 가운데: 고른 검의 진짜 모델(박은 룬 포함)을 작은 세계 하나(SubViewport)에 세워 천천히 돌린다.
## 끌면 돌고, 빈 룬 자리는 모델 위에 흐린 테두리 고리로 뜬다. 고리나 박힌 룬을 누르면 socket_clicked(번호).

signal socket_clicked(i: int)

const RING_COLOR := Color(0.85, 0.78, 0.6)

var _vp: SubViewport
var _cam: Camera3D
var _pivot: Node3D
var _model: SwordModel
var _rings: Array = []   # [슬롯 번호, Sprite3D]
var _yaw: float = 0.5
var _drag: bool = false
var _moved: float = 0.0
var _sockets: int = 0
var _hot: bool = false   # 박을 룬을 들고 있다: 빈 고리가 밝게 숨 쉰다
var _t: float = 0.0
static var _ring_tex: ImageTexture


func _init() -> void:
	custom_minimum_size = Vector2(380, 340)
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_vp)
	ForgeThumbs.light_rig(_vp)
	_cam = Camera3D.new()
	_cam.fov = 28.0
	_vp.add_child(_cam)
	_pivot = Node3D.new()
	_vp.add_child(_pivot)


## 검과 새긴 것을 바꿔 세운다. 돌린 각도는 그대로.
func show_sword(d: SwordData, game: GameData, runes: Array, sockets: int) -> void:
	if _model != null:
		_model.queue_free()
		_model = null
	for r in _rings:
		(r[1] as Node).queue_free()
	_rings.clear()
	_sockets = sockets
	_model = SwordModel.make(game.forms[d.form], d.grade, d.id, game.grades.colors[d.grade])
	_model.carve(runes)
	_model.position.y = -(_model.blade_length - _model.grip_length) * 0.5
	_pivot.add_child(_model)
	var span: float = _model.blade_length + _model.grip_length
	_cam.position = Vector3(0, 0.05, span * 0.5 / tan(deg_to_rad(_cam.fov * 0.5)) * 1.12)
	_cam.look_at(Vector3.ZERO)
	_pivot.rotation.x = deg_to_rad(10.0)
	for i in range(runes.size(), sockets):
		for p in CarveOverlay.slot_positions(_model, i):
			var s := Sprite3D.new()
			s.texture = _ring()
			s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			s.shaded = false
			s.pixel_size = 0.05 / 64.0
			s.modulate = Color(RING_COLOR, 0.5)
			s.position = p
			s.render_priority = 5
			_model.add_child(s)
			_rings.append([i, s])


func set_hot(on: bool) -> void:
	_hot = on


static func _ring() -> ImageTexture:
	if _ring_tex != null:
		return _ring_tex
	var n: int = 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var r: float = Vector2(x - 31.5, y - 31.5).length()
			var a: float = clampf(1.0 - absf(r - 24.0) / 2.5, 0.0, 1.0)   # 테두리 고리
			var dash: bool = int(atan2(y - 31.5, x - 31.5) * 5.0 / PI + 20.0) % 2 == 0   # 끊어진 테두리 = 빈 자리
			img.set_pixel(x, y, Color(1, 1, 1, a if dash else a * 0.35))
	_ring_tex = ImageTexture.create_from_image(img)
	return _ring_tex


func _process(dt: float) -> void:
	if not is_visible_in_tree():
		return
	_t += dt
	if not _drag:
		_yaw += dt * 0.45
	_pivot.rotation.y = _yaw
	var pulse: float = (0.5 + 0.5 * sin(_t * 5.0)) if _hot else 0.0
	for r in _rings:
		(r[1] as Sprite3D).modulate = Color(RING_COLOR.lerp(Color(1, 0.95, 0.7), pulse), 0.45 + 0.5 * pulse)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_drag = true
			_moved = 0.0
		else:
			_drag = false
			if _moved < 6.0:
				_click((e as InputEventMouseButton).position)
	elif e is InputEventMouseMotion and _drag:
		var rel: Vector2 = (e as InputEventMouseMotion).relative
		_moved += rel.length()
		_yaw += rel.x * 0.012
		_pivot.rotation.x = clampf(_pivot.rotation.x + rel.y * 0.006, deg_to_rad(-25), deg_to_rad(40))


## 누른 자리 가까이 있는 룬 자리(빈 고리나 박힌 룬)를 찾는다.
func _click(at: Vector2) -> void:
	if _model == null:
		return
	var best: int = -1
	var bd: float = 30.0
	for i in _sockets:
		for p in CarveOverlay.slot_positions(_model, i):
			var w: Vector3 = _model.to_global(p)
			if _cam.is_position_behind(w):
				continue
			var d: float = _cam.unproject_position(w).distance_to(at)
			if d < bd:
				bd = d
				best = i
	if best >= 0:
		socket_clicked.emit(best)
