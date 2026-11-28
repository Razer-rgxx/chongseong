extends SceneTree
## 마을 소품 확인(2026-11-27): 마을을 여러 자리에서 찍는다. 인자 `-- 접두사`(before/after)로 그림 이름을 정한다.
## 그림은 /home/claude/shots/village2_<접두사>_<자리>.png. 저장 파일을 건드리지 않는다.

const OUT: String = "/home/claude/shots/"

## [이름, 보는 곳(칸), 눈 위치 오프셋(m: 보는 곳 기준)]
const VIEWS: Array = [
	["aerial", Vector2(17, 12), Vector3(0, 34, 22)],
	["forge", Vector2(9.5, 9.0), Vector3(2, 3.2, 8)],
	["plaza", Vector2(21, 12.5), Vector3(-1, 3.6, 8)],
	["well", Vector2(21, 13.6), Vector3(3, 2.6, 5)],
	["board", Vector2(21.5, 5.2), Vector3(0, 2.4, 6)],
	["yard", Vector2(26.5, 16), Vector3(-5, 3.5, 6)],
	["cart", Vector2(13.6, 10.4), Vector3(-4, 2.6, 5)],
	["props", Vector2(8, 12), Vector3(3, 2.4, 5)],
	["houses", Vector2(7, 19), Vector3(0, 6, 12)],
]


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	var tag: String = "x"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		tag = args[0]
	change_scene_to_file("res://scenes/lobby/lobby.tscn")
	await _frames(40)
	var lobby: Node = current_scene
	(lobby.get("_camera") as Node).set("blur_allowed", false)
	var cam := Camera3D.new()
	cam.attributes = CameraAttributesPractical.new()
	lobby.add_child(cam)
	cam.fov = 60.0
	cam.make_current()
	for v in VIEWS:
		var target: Vector3 = Grid.cells_to_world(v[1], 1.0)
		cam.look_at_from_position(target + (v[2] as Vector3), target)
		await _frames(6)
		root.get_texture().get_image().save_png(OUT + "village2_%s_%s.png" % [tag, v[0]])
		print("shot ", v[0])
	quit()
