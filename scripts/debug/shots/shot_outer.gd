extends SceneTree
## 바깥 터(2026-11-21 마을 키우기 2단계) 확인용: 빈 터 셋 → 오두막이 올라가는 중 → 셋 다 선 모습, 위에서 본 마을, 건물 창.
## 돌리기: xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s scripts/debug/shots/shot_outer.gd
## 그림은 /home/claude/shots/outer_*.png. 저장은 새 Meta로(재료를 넉넉히).

const OUT: String = "/home/claude/shots/"


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(4)
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("shot ", name)


func _init() -> void:
	change_scene_to_file("res://scenes/lobby/lobby.tscn")
	await _frames(30)
	var lobby: Node = current_scene
	var meta: Meta = lobby.get("meta")
	var rules: Rules = lobby.get("rules")
	var hud: Node = lobby.get("_hud")
	var cam: Node = lobby.get("_camera")
	var data: GameData = lobby.get("data")
	meta.mats = {&"wood": 80, &"stone": 60, &"iron": 20}
	hud.call("refresh_top")
	var stand := Vector2(36.0, 11.2)
	rules.lord.pos = stand
	rules.lord.prev_pos = stand
	cam.set("blur_allowed", false)   # 순간 이동으로 생기는 움직임 흐림을 끈다
	cam.set("yaw", deg_to_rad(90.0))
	cam.set("pitch", deg_to_rad(20.0))
	cam.set("third_distance", 10.0)
	await _frames(3)
	cam.call("snap")
	await _shot("outer_sites")
	hud.call("open_building", data.building(&"cottage"))
	await _shot("outer_panel")
	hud.call("_build_building")
	var plot: Plot = (lobby.get("_plots") as Dictionary)[&"cottage"]
	Engine.time_scale = 0.25
	while plot.raising():
		await _frames(1)
		if float(plot.get("_t")) > 1.7:
			Engine.time_scale = 0.0
			await _shot("outer_raise")
			Engine.time_scale = 0.25
			break
	Engine.time_scale = 4.0
	while plot.raising():
		await _frames(1)
	for id in [&"woodcutter", &"mason"]:
		hud.call("open_building", data.building(id))
		hud.call("_build_building")
		var p: Plot = (lobby.get("_plots") as Dictionary)[id]
		while p.raising():
			await _frames(1)
	Engine.time_scale = 1.0
	await _shot("outer_built")
	hud.call("close")
	var top := Camera3D.new()   # 비스듬히 위에서(마을 카메라의 먼 흐림 없이)
	top.attributes = CameraAttributesPractical.new()
	lobby.add_child(top)
	top.fov = 50.0
	top.make_current()
	top.look_at_from_position(Grid.cells_to_world(Vector2(30, 30), 26.0), Grid.cells_to_world(Vector2(40, 11), 0.0))
	await _shot("outer_top")
	quit()
