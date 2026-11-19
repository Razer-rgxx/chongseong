class_name WebQuality
extends RefCounted
## 웹판(웨일북 같은 약한 노트북)에서만 그래픽을 가볍게 한다. PC판은 아무것도 바뀌지 않는다.
## 마을(lobby.gd)과 언덕(main.gd)의 _ready 끝에서 apply를 부른다. 나중에 생기는 빛(봉화, 불, 효과)도 잡는다.
## 아래 값은 규칙 수치가 아니라 웹판 그림 설정이다. 렉이 남으면 SCALE부터 낮춘다.

const SCALE: float = 0.6            ## 3D를 그리는 해상도 배율(글자·창은 그대로 또렷하다)
const SHADOW_ATLAS: int = 2048      ## 해 그림자 지도 크기
const SHADOW_DISTANCE: float = 45.0 ## 해 그림자가 닿는 거리(m)
const GRASS_KEEP: float = 0.3       ## 풀 포기를 남기는 비율

static var _hooked: bool = false


static func on() -> bool:
	return OS.has_feature("web")


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
		# 네 겹 그림자는 장면을 네 번 더 그린다. 한 겹으로.
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
		(n as Light3D).shadow_enabled = false
	elif n is MultiMeshInstance3D and n.name == &"Grass":
		var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
		if mm:
			mm.visible_instance_count = int(mm.instance_count * GRASS_KEEP)
