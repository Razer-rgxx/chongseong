extends SceneTree
## 들판 재료 자리(2026-11-21 마을 키우기 1단계) 확인용: 나무·돌·쇠 자리 하나씩 앞에 서서 찍고, 오른쪽 아래 재료 수와 +N.
## 돌리기: xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s scripts/debug/shots/shot_mats.gd
## 그림은 /home/claude/shots/mats_<n>.png.


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	change_scene_to_file("res://scenes/field/field.tscn")
	await _frames(30)
	var f: Node = current_scene
	var rules: Rules = f.get("rules")
	var meta: Meta = f.get("meta")
	var hud: Node = f.get("_hud")
	var cam: Node = f.get("_camera")
	rules.debug_god = true
	rules.field_clock = 70.0
	for k in FieldLayout.AREAS:
		(f.get("_shown") as Dictionary)[k] = true
	meta.mats = {&"wood": 12, &"stone": 7, &"iron": 3}
	hud.call("refresh_top")
	var n: int = 0
	for i in [1, 8, 16]:
		if not meta.mat_spots.has(i):
			FieldBuilder.mat_spot(f, i)
		var at: Vector2 = FieldLayout.MATS[i][0] + Vector2(0.0, 3.2)
		rules.lord.pos = at
		rules.lord.prev_pos = at
		rules.lord.face = -PI / 2.0
		cam.set("yaw", deg_to_rad(20.0))
		cam.set("pitch", deg_to_rad(18.0))
		cam.set("third_distance", 6.5)
		await _frames(6)
		cam.call("snap")
		await _frames(4)
		if n == 2:
			hud.call("got_mat", &"iron", 2)
			await _frames(3)
		root.get_texture().get_image().save_png("/home/claude/shots/mats_%d.png" % n)
		print("shot ", n)
		n += 1
	quit()
