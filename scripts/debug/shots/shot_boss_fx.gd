extends SceneTree
## 보스 패턴 효과만 가까이 보기(docs/boss_patterns.md): 평평한 땅에 EnemyFx 하나, 가짜 떨어지는 자리(칼비 셋, 무덤 손 둘)와 참격파 하나.
## 돌리기: xvfb-run -a godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility --fixed-fps 30 -s scripts/debug/shots/shot_boss_fx.gd
## 그림: /home/claude/shots/boss_fx_<때>.png (떨어지기 직전, 꽂힌 뒤).

const OUT: String = "/home/claude/shots/"


func _init() -> void:
	var w := Node3D.new()
	root.add_child(w)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.3, 0.28)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.45, 0.42, 0.4)
	w.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.6, 0)
	sun.shadow_enabled = true
	w.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.36, 0.31, 0.22)
	gm.roughness = 1.0
	ground.material_override = gm
	w.add_child(ground)
	var fx := EnemyFx.new()
	fx.height_of = func(_x: float, _z: float) -> float: return 0.0
	w.add_child(fx)
	var mid := Grid.world_to_cells(Vector3.ZERO)
	var shots: Array[Projectile] = []
	for i in 5:
		var p := Projectile.new()
		p.kind = &"fall"
		p.look = &"sword" if i < 3 else &"hand"
		p.id = 100 + i
		p.pos = mid + Vector2(-4.0 + i * 2.0, 0.0)
		p.prev_pos = p.pos
		p.width = 2.2
		p.max_time = 0.8 + 0.1 * i
		shots.append(p)
		fx.on_projectile_spawned(p)
	var s := Projectile.new()
	s.kind = &"shock"
	s.id = 200
	s.dir = Vector2(1, 0)
	s.pos = mid + Vector2(-6.0, 3.0)
	s.prev_pos = s.pos
	s.width = 1.0
	s.max_time = 2.0
	fx.on_projectile_spawned(s)
	var cam := Camera3D.new()
	w.add_child(cam)
	cam.look_at_from_position(Vector3(0, 7, 13), Vector3(0, 0, 1))
	var t: float = 0.0
	var saved: Array[String] = []
	for f in 90:
		await process_frame
		t += 1.0 / 30.0
		s.prev_pos = s.pos
		s.pos += s.dir * 12.0 / 30.0
		fx.draw(1.0)
		for p in shots:
			if t >= p.max_time and not p.landed:
				p.landed = true
				fx.on_projectile_ended(p, false)
		if t >= 0.72 and not saved.has("fall"):
			saved.append("fall")
			root.get_texture().get_image().save_png(OUT + "boss_fx_fall.png")
		if t >= 1.5 and not saved.has("land"):
			saved.append("land")
			root.get_texture().get_image().save_png(OUT + "boss_fx_land.png")
	quit()
