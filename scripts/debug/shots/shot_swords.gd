extends SceneTree
## 무한 등급 칼 13자루(Blender, assets/swords/<번호>.glb) 갤러리. 그림 /home/claude/shots/swords.png.
## 돌리기: xvfb-run -a godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s scripts/debug/shots/shot_swords.gd

const IDS: Array[int] = [292, 296, 290, 294, 291, 289, 293, 297, 299, 300, 295, 288, 298]


func _init() -> void:
	var d := GameData.load_default()
	var w := Node3D.new()
	root.add_child(w)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.07, 0.07, 0.08)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.45, 0.45, 0.47)
	env.environment.glow_enabled = true
	w.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.6, 0.4, 0)
	w.add_child(sun)
	for i in IDS.size():
		var sd: SwordData = null
		for s in d.swords:
			if s.id == IDS[i]:
				sd = s
		var form: FormData = d.forms[sd.form] if sd else null
		var g: int = sd.grade if sd else 5
		var m := SwordModel.make(form, g, IDS[i], d.grades.colors[g])
		var col: int = i % 7
		var row: int = i / 7
		m.position = Vector3(col * 0.62 - 1.86, 0.2 - row * 1.75, 0)
		m.rotation = Vector3(0, 0, 0)
		w.add_child(m)
	var cam := Camera3D.new()
	w.add_child(cam)
	cam.look_at_from_position(Vector3(0, 0.15, 4.3), Vector3(0, 0.0, 0))
	for k in 8:
		await process_frame
	root.get_texture().get_image().save_png("/home/claude/shots/swords.png")
	quit()
