extends SceneTree
## 조립식 집(KitHouse) 확인: 단층·2층 두 채를 앞 왼쪽과 뒤 오른쪽에서. 그림은 /home/claude/shots/kit_*.png.

func _init() -> void:
	var w := Node3D.new()
	root.add_child(w)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.5, 0.55, 0.6)
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	w.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.6, 0)
	w.add_child(sun)
	var rng := RandomNumberGenerator.new()
	var a := VillageBuilder.place(w, Vector3(-5, 0, 0), 0.0)
	KitHouse.build(a, Vector2(6, 6), false, rng)
	var b := VillageBuilder.place(w, Vector3(5, 0, 0), 0.0)
	KitHouse.build(b, Vector2(7, 4.4), true, rng)
	var cam := Camera3D.new()
	w.add_child(cam)
	cam.look_at_from_position(Vector3(2, 5, 12), Vector3(3, 3, 0))
	for i in 5:
		await process_frame
	root.get_texture().get_image().save_png("/home/claude/shots/kit_front.png")
	cam.look_at_from_position(Vector3(10, 8, -14), Vector3(0, 2.5, 0))
	for i in 5:
		await process_frame
	root.get_texture().get_image().save_png("/home/claude/shots/kit_back.png")
	quit()
