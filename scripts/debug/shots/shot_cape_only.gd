extends SceneTree
## 망토 glb 하나만 세워 뒤·옆에서 찍는다(뼈 흔들림 켬/끔 비교). 그림: /home/claude/shots/cape_only_*.png
## godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s scripts/debug/shots/shot_cape_only.gd -- cape_night

func _init() -> void:
	var id: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "cape_night"
	var ps: PackedScene = load("res://assets/cosmetics/%s.glb" % id)
	var n: Node3D = ps.instantiate()
	root.add_child(n)
	var sk: Skeleton3D = CosmeticArt.cape_skeleton(n)
	print("skeleton ", sk, " bones ", sk.get_bone_count() if sk else -1)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		print("mesh aabb ", (mi as MeshInstance3D).get_aabb())
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.3, 0.3, 0.32)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	root.add_child(sun)
	var cam := Camera3D.new()
	root.add_child(cam)
	for mode in ["rest", "sway"]:
		if sk != null:
			if mode == "sway":
				CosmeticArt.sway(sk, -0.3)
			else:
				sk.reset_bone_poses()
		for v in [["back", Vector3(0, -0.5, 2.0)], ["side", Vector3(2.0, -0.5, 0.0)]]:
			cam.position = v[1]
			cam.look_at(Vector3(0, -0.5, 0), Vector3.UP)
			for i in 6:
				await process_frame
			root.get_texture().get_image().save_png("/home/claude/shots/cape_only_%s_%s_%s.png" % [id, mode, v[0]])
	quit()
