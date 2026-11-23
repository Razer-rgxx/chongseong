extends SceneTree
## 머리(Heads) 갤러리: 우두머리 열 가지(씨앗마다 빛·장식이 다르다). 그림 /home/claude/shots/heads.png.

func _init() -> void:
	var w := Node3D.new()
	root.add_child(w)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.08, 0.08, 0.09)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.5)
	w.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.5, 0)
	w.add_child(sun)
	var ids: Array = Heads.CHIEF.keys()
	for i in ids.size():
		var info := Heads.info("%s|%08x" % [ids[i], i * 7919 + 3])
		var o := ObjectHead.build(info.shape)
		ObjectHead._decorate(o, info)
		o.position = Vector3((i % 5) * 0.7 - 1.4, -(i / 5) * 0.75, 0)
		w.add_child(o)
	var cam := Camera3D.new()
	w.add_child(cam)
	cam.look_at_from_position(Vector3(0, 0.2, 3.0), Vector3(0, -0.2, 0))
	for k in 5:
		await process_frame
	root.get_texture().get_image().save_png("/home/claude/shots/heads.png")
	quit()
