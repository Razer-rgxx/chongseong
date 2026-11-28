class_name WebQuality
extends RefCounted
## 웹판(웨일북 같은 약한 노트북)에서만 그래픽을 가볍게 한다. PC판은 아무것도 바뀌지 않는다.
## 마을(lobby.gd)과 언덕(main.gd)의 _ready 끝에서 apply를 부른다. 나중에 생기는 빛(봉화, 불, 효과)도 잡는다.
## 아래 값은 규칙 수치가 아니라 웹판 그림 설정이다. 렉이 남으면 SCALE부터 낮춘다.

const SCALE: float = 0.5            ## 3D를 그리는 해상도 배율(글자·창은 그대로 또렷하다). 2026-11-26 렉: 0.6 → 0.5
const SHADOW_ATLAS: int = 2048      ## 해 그림자 지도 크기
const SHADOW_DISTANCE: float = 45.0 ## 해 그림자가 닿는 거리(m)
const GRASS_KEEP: float = 0.3       ## 풀 포기를 남기는 비율
const WEATHER_KEEP: float = 0.35    ## 들판 날씨 입자(비·재·불똥·반딧불이)를 남기는 비율
## 2026-11-26 사용자 "웹은 최적화 좀 시켜야겠다 렉이 너무 심한데": 해 그림자를 끄고(장면을 한 번 더 그리는 값이 가장 크다),
## 작은 빛은 멀면 끄고, 작은 물건은 멀면 안 그린다.
const SUN_SHADOW: bool = false
const LIGHT_FADE: float = 28.0      ## 이보다 먼 작은 빛(m)은 사라진다
const SMALL_SIZE: float = 5.0       ## 이보다 작은 물건(대각선 m)은
const SMALL_FAR: float = 70.0       ## 이만큼 멀면(m) 그리지 않는다

static var _hooked: bool = false
## 클라우드에서 웹판 설정을 재 보려고 켜는 스위치(scripts/debug/web_profile.gd). 게임에서는 쓰지 않는다.
static var force: bool = false


static func on() -> bool:
	return force or OS.has_feature("web")


static func apply(root: Node, env: Environment, sun: DirectionalLight3D, camera: Node) -> void:
	if not on():
		return
	var vp: Viewport = root.get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = SCALE
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_ATLAS, true)
	if sun:
		# 네 겹 그림자는 장면을 네 번 더 그린다. 한 겹으로, 그리고 웹에서는 아예 끈다(SUN_SHADOW).
		sun.shadow_enabled = SUN_SHADOW
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = minf(sun.directional_shadow_max_distance, SHADOW_DISTANCE)
	if env:
		env.glow_enabled = false
		env.ssao_enabled = false
	if camera and "blur_allowed" in camera:
		camera.set("blur_allowed", false)   # 깊이 그림을 읽는 화면 판이라 웹에서 가장 비싸다(돌진 번짐도)
	_walk(root)
	if not _hooked:
		_hooked = true
		root.get_tree().node_added.connect(_added)


static func _walk(n: Node) -> void:
	_added(n)
	for c in n.get_children():
		_walk(c)


static func _added(n: Node) -> void:
	if n is OmniLight3D or n is SpotLight3D:
		var l := n as Light3D
		l.shadow_enabled = false
		l.distance_fade_enabled = true   # 빛 하나마다 물체를 한 번 더 그리는 렌더러라, 먼 빛은 끈다
		l.distance_fade_begin = LIGHT_FADE
		l.distance_fade_length = 8.0
	elif n is DirectionalLight3D:
		(n as Light3D).shadow_enabled = SUN_SHADOW and (n as Light3D).shadow_enabled
	elif n is GeometryInstance3D and not n is MultiMeshInstance3D:
		_cull_small.call_deferred(n)
	if n is MultiMeshInstance3D and n.name == &"Grass":
		var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
		if mm:
			mm.visible_instance_count = int(mm.instance_count * GRASS_KEEP)


## 작은 물건은 멀면 그리지 않는다(이미 정한 거리가 있으면 그것과 SMALL_FAR 중 짧은 쪽). 큰 건물·땅·하늘은 그대로.
static func _cull_small(n: Node) -> void:
	if not is_instance_valid(n) or not n.is_inside_tree():
		return
	var g := n as GeometryInstance3D
	var box: AABB = g.get_aabb()
	var sc: Vector3 = g.global_transform.basis.get_scale()
	var size: float = (box.size * sc).length()
	if size <= 0.0 or size > SMALL_SIZE:
		return
	g.visibility_range_end = SMALL_FAR if g.visibility_range_end <= 0.0 else minf(g.visibility_range_end, SMALL_FAR)
