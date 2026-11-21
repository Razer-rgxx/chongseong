extends SceneTree
## 점프를 실제로 달리며 뛰게 해서 한 장씩 찍는다(몸·다리·칼이 같이 움직이는지 보려고).
## 돌리기: xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s scripts/debug/shots/shot_jump_seq.gd -- [run|idle]
## 그림은 /home/claude/shots/jseq_<n>.png. 시간을 느리게(time_scale) 돌려 Xvfb가 느려도 여러 장 나온다.

const OUT: String = "/home/claude/shots/"


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	var run: bool = not OS.get_cmdline_user_args().has("idle")
	change_scene_to_file("res://scenes/field/field.tscn")
	await _frames(30)
	var f: Node = current_scene
	var rules: Rules = f.get("rules")
	rules.debug_god = true
	rules.field_clock = 70.0
	var cam: Node = f.get("_camera")
	(f.get("_shown") as Dictionary)[&"hamlet"] = true
	(f.get("_shown") as Dictionary)[&"grove"] = true
	var at := Vector2(168.0, 70.0)
	rules.lord.pos = at
	rules.lord.prev_pos = at
	cam.set("yaw", deg_to_rad(0.0))
	cam.set("pitch", deg_to_rad(6.0))
	cam.set("third_distance", 5.0)
	if run:
		Input.action_press("move_right")
	await _frames(40)
	cam.call("snap")
	Engine.time_scale = 0.2
	f.set("_want_jump", true)
	var n: int = 0
	var landed: int = -1
	var was_air: bool = false
	while n < 60:
		await _frames(1)
		root.get_texture().get_image().save_png(OUT + "jseq_%02d.png" % n)
		print("frame ", n, " air=", snappedf(rules.lord.air, 0.001))
		if rules.lord.air > 0.0:
			was_air = true
		elif was_air and landed < 0:
			landed = n
		if landed >= 0 and n > landed + 6:
			break
		n += 1
	Input.action_release("move_right")
	quit()
