extends SceneTree
## 검의 기억 확인 그림(docs/sword_memory.md): 룬 셋과 보석 둘이 박힌 검(전체, 확대)과 대장간 보석 박기 창.
## /home/claude/shots/memory_sword.png, memory_sword_zoom.png, memory_forge.png. 돌리기:
##   Xvfb :99 -screen 0 1280x720x24 &  DISPLAY=:99 godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s scripts/debug/shots/shot_memory.gd

const OUT: String = "/home/claude/shots/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var d := GameData.load_default()
	var meta := Meta.new()
	var sd: SwordData = null
	for s in d.swords:
		if s.grade == 3 and not s.cyber:
			sd = s
			break
	meta.note_found(sd.id)
	meta.sheath_id = sd.id
	meta.shards = 640
	meta.use_note(sd.id, "boss", 20)
	meta.use_note(sd.id, "night", 12)
	meta.set_memory(sd.id, 1000)
	meta.gem_add("ruby:3")
	meta.gem_add("lapis:2")
	meta.gem_add("amber:1")
	meta.socket_gem(sd.id, "ruby:3")
	meta.socket_gem(sd.id, "lapis:2")
	meta.set_sword_name(sd, "새벽의 맹세", d.grades)
	print("runes ", meta.runes_of(sd.id), " gems ", meta.gems_of(sd.id), " name ", Meta.shown_name(sd))
	var w := Node3D.new()
	root.add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.035, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.33, 0.4)
	env.ambient_light_energy = 0.8
	env.glow_enabled = true
	env.glow_intensity = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.4
	key.rotation = Vector3(-0.6, 0.4, 0.0)
	w.add_child(key)
	var sw := Sword.new(sd, d)
	var m := SwordModel.for_sword(sw, d.grades)
	m.position = Vector3(0, -0.5, 0)
	w.add_child(m)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.9
	w.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 0.1, 6.0), Vector3(0.0, 0.1, 0.0))
	for k in 12:
		await process_frame
	root.get_texture().get_image().save_png(OUT + "memory_sword.png")
	cam.size = 0.55
	cam.look_at_from_position(Vector3(0.0, -0.25, 6.0), Vector3(0.0, -0.25, 0.0))
	for k in 6:
		await process_frame
	root.get_texture().get_image().save_png(OUT + "memory_sword_zoom.png")
	w.queue_free()
	await process_frame
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var hud := LobbyHud.new()
	root.add_child(hud)
	hud.setup(d, meta)
	hud.set("_forge_tab", 1)
	hud.open_forge()
	for k in 12:
		await process_frame
	root.get_texture().get_image().save_png(OUT + "memory_forge.png")
	print("shot memory")
	quit()
