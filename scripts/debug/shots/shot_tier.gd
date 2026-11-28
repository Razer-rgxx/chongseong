extends SceneTree
## 마을 단계(2026-11-21 마을 키우기 4단계) 확인용: 읍(건물 일곱, 사람 여섯)에서 돌담을 짓는다 → 목책이 가라앉고 돌담이 놓인다 → 성읍.
## 위에서 본 마을, 길가 등불과 걷는 사람. 저장 파일을 바꾸니 지워도 되는 곳에서만 돌린다.
## 그림은 /home/claude/shots/tier_*.png.

const OUT: String = "/home/claude/shots/"


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(4)
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("shot ", name)


func _aerial(lobby: Node) -> Camera3D:
	var top := Camera3D.new()
	top.attributes = CameraAttributesPractical.new()
	lobby.add_child(top)
	top.fov = 55.0
	top.make_current()
	top.look_at_from_position(Grid.cells_to_world(Vector2(22, 38), 34.0), Grid.cells_to_world(Vector2(27, 11), 0.0))
	return top


func _init() -> void:
	change_scene_to_file("res://scenes/lobby/lobby.tscn")
	await _frames(25)
	var meta: Meta = current_scene.get("meta")
	meta.storage_house = true
	for id in [&"cottage", &"woodcutter", &"mason", &"cottage2", &"longhouse"]:
		meta.built[id] = true
	meta.residents = []
	for n in ["돌쇠", "끝순", "덕배", "언년", "삼월", "칠복"]:
		meta.residents.append({"name": n, "look": FieldLayout.RESIDENT_LOOKS[meta.residents.size() % 4], "job": [&"woodcutter", &"mason", &""][meta.residents.size() % 3]})
	meta.mats = {&"wood": 60, &"stone": 80, &"iron": 20}
	meta.tier_seen = 2
	meta.save()
	change_scene_to_file("res://scenes/lobby/lobby.tscn")
	await _frames(30)
	var lobby: Node = current_scene
	var hud: Node = lobby.get("_hud")
	var data: GameData = lobby.get("data")
	(lobby.get("_camera") as Node).set("blur_allowed", false)
	_aerial(lobby)
	await _shot("tier_before")
	hud.call("open_building", data.building(&"wall"))
	hud.call("_build_building")
	var plot: Plot = (lobby.get("_plots") as Dictionary)[&"wall"]
	while plot.raising():
		await _frames(1)
		if float(plot.get("_t")) > 2.6:
			await _shot("tier_raise")
			break
	while plot.raising():
		await _frames(1)
	await _frames(20)
	await _shot("tier_after")
	lobby.get_viewport().get_camera_3d().queue_free()
	await _frames(2)
	var cam: Node = lobby.get("_camera")
	(cam as Camera3D).make_current() if cam is Camera3D else null
	var rules: Rules = lobby.get("rules")
	rules.lord.pos = Vector2(30.5, 10.6)
	rules.lord.prev_pos = rules.lord.pos
	cam.set("yaw", deg_to_rad(-100.0))
	cam.set("pitch", deg_to_rad(12.0))
	cam.set("third_distance", 7.0)
	await _frames(4)
	cam.call("snap")
	await _frames(40)
	await _shot("tier_street")
	quit()
