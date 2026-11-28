extends SceneTree
## 마을 소품 모델 갤러리(2026-11-27): assets/village/models/의 모델을 한 줄로 세워 찍는다.
## 인자 `-- 이름 이름 ...`이면 그것만 크게 한 장씩(village2_m_<이름>.png), 없으면 전부 한 장(village2_models.png).

const OUT: String = "/home/claude/shots/"


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	var names: Array = Array(OS.get_cmdline_user_args())
	if names.is_empty():
		for f in DirAccess.get_files_at("res://assets/village/models/"):
			if f.ends_with(".glb"):
				names.append(f.get_basename())
		names.sort()
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.32, 0.34, 0.36)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.5, 0.45)
	e.ambient_light_energy = 0.7
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	world.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 30)
	floor_mi.mesh = pm
	floor_mi.material_override = VillageBuilder.dirt()
	world.add_child(floor_mi)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.fov = 45.0
	cam.make_current()
	var solo: bool = not OS.get_cmdline_user_args().is_empty()
	var x: float = 0.0
	var centers: Array = []
	for nm in names:
		var n := VillageModels.make(nm)
		world.add_child(n)
		var box := AABB()
		var first := true
		for c in n.find_children("*", "MeshInstance3D", true, false):
			var a: AABB = (c as MeshInstance3D).get_aabb()
			a = (c as MeshInstance3D).transform * a
			box = a if first else box.merge(a)
			first = false
		n.position = Vector3(x - box.get_center().x, 0, 0)
		centers.append([nm, x, box.size])
		x += box.size.x + 1.2
	if solo:
		for c in centers:
			var cx: float = c[1]
			var sz: Vector3 = c[2]
			var d: float = maxf(sz.x, maxf(sz.y, sz.z)) * 1.9 + 1.0
			cam.look_at_from_position(Vector3(cx + d * 0.35, sz.y * 0.65 + d * 0.2, d), Vector3(cx, sz.y * 0.45, 0))
			await _frames(5)
			root.get_texture().get_image().save_png(OUT + "village2_m_%s.png" % c[0])
			cam.look_at_from_position(Vector3(cx - d * 0.55, sz.y * 0.6 + d * 0.3, -d * 0.7), Vector3(cx, sz.y * 0.45, 0))
			await _frames(5)
			root.get_texture().get_image().save_png(OUT + "village2_m_%s_back.png" % c[0])
	else:
		var mid: float = x / 2.0
		cam.look_at_from_position(Vector3(mid, 4.0, x * 0.55 + 6.0), Vector3(mid, 1.0, 0))
		await _frames(5)
		root.get_texture().get_image().save_png(OUT + "village2_models.png")
	quit()
