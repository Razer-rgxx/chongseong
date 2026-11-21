extends SceneTree
## 주민(2026-11-21 마을 키우기 3단계) 확인용: 들판 무리 자리에 묶인 사람 → 마을 바깥 터의 주민(일꾼·쉬는 사람)과 일 맡기기 창.
## 돌리기: xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s scripts/debug/shots/shot_residents.gd
## 그림은 /home/claude/shots/res_*.png. 저장 파일을 바꾸니 지워도 되는 곳에서만 돌린다.

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
	for id in [&"cottage", &"woodcutter", &"mason"]:
		meta.built[id] = true
	meta.residents = [{"name": "돌쇠", "look": &"peasant", "job": &"woodcutter"}, {"name": "끝순", "look": &"peasant2", "job": &""}]
	meta.captive_packs = ["road_south"]
	meta.packs_cleared["road_south"] = 1
	(f.get("_hud") as Node).call("refresh_top")
	FieldBuilder.captive(f, "road_south")
	var at: Vector2 = Vector2(FieldLayout.PACKS["road_south"].at) + Vector2(1.2, 4.2)
	rules.lord.pos = at
	rules.lord.prev_pos = at
	cam.set("blur_allowed", false)
	cam.set("yaw", deg_to_rad(10.0))
	cam.set("pitch", deg_to_rad(16.0))
	cam.set("third_distance", 5.5)
	await _frames(5)
	cam.call("snap")
	await _shot("res_captive")
	meta.save()
	change_scene_to_file("res://scenes/lobby/lobby.tscn")
	await _frames(30)
	var lobby: Node = current_scene
	var lr: Rules = lobby.get("rules")
	var lc: Node = lobby.get("_camera")
	var hud: Node = lobby.get("_hud")
	lc.set("blur_allowed", false)
	var stand := Vector2(44.0, 11.0)
	lr.lord.pos = stand
	lr.lord.prev_pos = stand
	lc.set("yaw", deg_to_rad(180.0))
	lc.set("pitch", deg_to_rad(14.0))
	lc.set("third_distance", 8.0)
	await _frames(5)
	lc.call("snap")
	await _shot("res_village")
	hud.call("open_jobs", 1)
	await _shot("res_jobs")
	quit()
