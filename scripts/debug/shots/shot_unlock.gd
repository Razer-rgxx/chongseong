extends SceneTree
## 열리는 것(2026-11-21 마을 키우기 5단계) 확인용: 들판의 막힌 길(망루 전), 언덕길의 시작 구역 창, 바깥 터의 망루와 풀무간.
## 그림은 /home/claude/shots/unlock_*.png. 저장 파일을 바꾸니 지워도 되는 곳에서만 돌린다.

const OUT: String = "/home/claude/shots/"


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(4)
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("shot ", name)


func _init() -> void:
	change_scene_to_file("res://scenes/field/field.tscn")
	await _frames(30)
	var f: Node = current_scene
	var meta: Meta = f.get("meta")
	var rules: Rules = f.get("rules")
	var cam: Node = f.get("_camera")
	rules.debug_god = true
	rules.field_clock = 70.0
	for k in FieldLayout.AREAS:
		(f.get("_shown") as Dictionary)[k] = true
	cam.set("blur_allowed", false)
	rules.lord.pos = Vector2(161.0, 95.0)
	rules.lord.prev_pos = rules.lord.pos
	cam.set("yaw", deg_to_rad(-90.0))
	cam.set("pitch", deg_to_rad(14.0))
	cam.set("third_distance", 6.0)
	await _frames(5)
	cam.call("snap")
	await _shot("unlock_barricade")
	(f.get("_hud") as Node).call("open_climb", [1, 3, 5] as Array[int], 3, func(_z: int) -> void: pass)
	await _shot("unlock_climb")
	meta.storage_house = true
	for id in [&"cottage", &"woodcutter", &"mason", &"cottage2", &"longhouse", &"wall", &"tower", &"forge"]:
		meta.built[id] = true
	meta.residents = []
	for n in ["돌쇠", "끝순", "덕배", "언년", "삼월", "칠복"]:
		meta.residents.append({"name": n, "look": FieldLayout.RESIDENT_LOOKS[meta.residents.size() % 4], "job": [&"woodcutter", &"mason", &""][meta.residents.size() % 3]})
	meta.tier_seen = 3
	meta.save()
	change_scene_to_file("res://scenes/lobby/lobby.tscn")
	await _frames(30)
	var lobby: Node = current_scene
	(lobby.get("_camera") as Node).set("blur_allowed", false)
	var top := Camera3D.new()
	top.attributes = CameraAttributesPractical.new()
	lobby.add_child(top)
	top.fov = 50.0
	top.make_current()
	top.look_at_from_position(Grid.cells_to_world(Vector2(36, 30), 22.0), Grid.cells_to_world(Vector2(43, 11), 1.0))
	await _frames(20)
	await _shot("unlock_outer")
	quit()
