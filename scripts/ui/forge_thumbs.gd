class_name ForgeThumbs
extends Node
## 대장간 그림 창(2026-11-26): 검 하나하나를 작은 오프스크린 뷰포트 하나로 한 번씩 그려 ImageTexture로 남긴다.
## 처음 보일 때만(게으르게) 한 장씩 그리고, 다시는 안 그린다(static 캐시). 웹에서도 가볍게: 뷰포트는 하나, 112px.

signal done(id: int)

const SIZE: int = 112
static var cache: Dictionary = {}   # 검 번호 → ImageTexture
static var rune_cache: Dictionary = {}   # 룬 종류 → ImageTexture
static var inst: ForgeThumbs = null

var _vp: SubViewport
var _cam: Camera3D
var _queue: Array = []   # [id, form, grade, color]
var _busy: bool = false


static func ensure(host: Node) -> ForgeThumbs:
	if inst == null or not is_instance_valid(inst) or not inst.is_inside_tree():
		inst = ForgeThumbs.new()
		host.add_child(inst)
	return inst


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	ForgeThumbs.light_rig(_vp)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.position = Vector3(0, 0, 4)
	_vp.add_child(_cam)


## 뷰포트에 해·채움빛·환경을 단다(미리보기와 같이 쓴다).
static func light_rig(vp: SubViewport) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.66)
	env.ambient_light_energy = 1.5
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	sun.light_energy = 2.2
	vp.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, -140, 0)
	fill.light_energy = 1.2
	fill.light_color = Color(0.7, 0.8, 1.0)
	vp.add_child(fill)


## 검 d의 그림. 아직 없으면 null을 주고 줄을 세운다(다 그리면 done 신호).
func want(d: SwordData, game: GameData) -> Texture2D:
	if cache.has(d.id):
		return cache[d.id]
	for q in _queue:
		if q[0] == d.id:
			return null
	_queue.append([d.id, game.forms[d.form], d.grade, game.grades.colors[d.grade]])
	if not _busy:
		_pump()
	return null


## 룬 종류의 그림(assets/runes/<종류>.glb가 있을 때만). 없으면 null이고 줄도 안 세운다(타일이 납작한 무늬를 그린다).
## 다 그리면 done(-1).
func want_rune(type: String) -> Texture2D:
	if CarveOverlay.model_of(type) == null:
		return null
	if rune_cache.has(type):
		return rune_cache[type]
	for q in _queue:
		if q[0] is String and q[0] == type:
			return null
	_queue.append([type])
	if not _busy:
		_pump()
	return null


func _pump() -> void:
	_busy = true
	while not _queue.is_empty():
		var q: Array = _queue.pop_front()
		if q[0] is String:   # 룬 모델: 앞(+Z)에서 정사영으로
			var sc: PackedScene = CarveOverlay.model_of(q[0])
			if sc == null or rune_cache.has(q[0]):
				continue
			var rn := sc.instantiate() as Node3D
			CarveOverlay.show_tier(rn, 1)   # 단계는 타일이 테두리·점으로 보인다
			_vp.add_child(rn)
			_cam.size = 1.15
			_cam.position = Vector3(0, 0, 4)
			_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var rimg: Image = _vp.get_texture().get_image()
			rn.queue_free()
			if rimg != null and not rimg.is_empty():
				rune_cache[q[0]] = ImageTexture.create_from_image(rimg)
				done.emit(-1)
			continue
		if cache.has(q[0]):
			continue
		var m := SwordModel.make(q[1], q[2], q[0], q[3])
		var pivot := Node3D.new()
		pivot.rotation = Vector3(0.0, deg_to_rad(28.0), deg_to_rad(-42.0))
		pivot.add_child(m)
		var span: float = m.blade_length + m.grip_length
		var mid := Vector3(0, (m.blade_length - m.grip_length) * 0.5, 0)
		pivot.position = -(pivot.basis * mid)
		_vp.add_child(pivot)
		_cam.size = span * 0.98
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img: Image = _vp.get_texture().get_image()
		pivot.queue_free()
		if img != null and not img.is_empty():
			cache[q[0]] = ImageTexture.create_from_image(img)
			done.emit(q[0])
	_busy = false
