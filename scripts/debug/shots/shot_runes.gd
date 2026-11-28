extends SceneTree
## 룬 조각 모델(assets/runes/<키>.glb, tools/blender/make_runes.py) 확인 그림. /home/claude/shots/에 남긴다.
##   runes.png: 8종을 한 장에(위 줄 keen night day hunt, 아래 줄 wind grit chain elite, 모두 3단계), 맨 아래 작은 줄은 keen의 1·2·3단계.
##   runes_sword.png: 룬 셋(사냥 1단계, 밤 2단계, 예리 3단계)이 박힌 검 전체와 runes_sword_zoom.png 가까이.
## 돌리기: xvfb-run -a godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1600x900 -s scripts/debug/shots/shot_runes.gd

const OUT: String = "/home/claude/shots/"


func _env(w: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.04, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.35, 0.42)
	env.ambient_light_energy = 0.7
	env.glow_enabled = true
	env.glow_intensity = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.6
	key.rotation = Vector3(-0.7, 0.5, 0.0)
	w.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.4
	fill.rotation = Vector3(-0.2, -2.4, 0.0)
	w.add_child(fill)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var keys: PackedStringArray = Meta.rt().rune_order
	var w := Node3D.new()
	root.add_child(w)
	_env(w)
	for i in keys.size():
		var ps := CarveOverlay.model_of(keys[i])
		if ps == null:
			print("없음 ", keys[i])
			continue
		var n := ps.instantiate() as Node3D
		n.scale = Vector3.ONE * 0.026   # 모델은 가장 긴 변 1.0
		n.position = Vector3(-0.054 + 0.036 * float(i % 4), 0.024 - 0.042 * float(i / 4), 0.0)
		n.rotation = Vector3(0.12, -0.18, 0.0)
		CarveOverlay.show_tier(n, 3)
		w.add_child(n)
	for tier in [1, 2, 3]:
		var n := CarveOverlay.model_of(keys[0]).instantiate() as Node3D
		n.scale = Vector3.ONE * 0.6 * 0.026
		n.position = Vector3(-0.02 + 0.02 * float(tier - 1), -0.052, 0.0)
		n.rotation = Vector3(0.12, -0.18, 0.0)
		CarveOverlay.show_tier(n, tier)
		w.add_child(n)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.125
	w.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, -0.006, 0.5), Vector3(0.0, -0.006, 0.0))
	for k in 10:
		await process_frame
	root.get_texture().get_image().save_png(OUT + "runes.png")
	print("shot runes")
	w.queue_free()
	await process_frame
	# 검에 박힌 모습
	var d := GameData.load_default()
	var sd: SwordData = null
	for s in d.swords:
		if s.grade == 1 and not s.cyber and s.form == 1:
			sd = s
			break
	var w2 := Node3D.new()
	root.add_child(w2)
	_env(w2)
	var sw := Sword.new(sd, d)
	var m := SwordModel.make(d.forms[sd.form], sd.grade, sd.id, d.grades.colors[sd.grade])
	m.carve(["hunt:1", "night:2", "keen:3"])
	m.position = Vector3(0, -0.5, 0)
	m.rotation.y = 0.35
	w2.add_child(m)
	var cam2 := Camera3D.new()
	cam2.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam2.size = 1.6
	w2.add_child(cam2)
	cam2.look_at_from_position(Vector3(0.0, 0.05, 6.0), Vector3(0.0, 0.05, 0.0))
	for k in 10:
		await process_frame
	root.get_texture().get_image().save_png(OUT + "runes_sword.png")
	cam2.size = 0.42
	var mid := m.to_global(Vector3(m.tip_x * 0.3, 0.1 + 0.54 * (m.blade_length - 0.1) * 0.9, 0.0))
	cam2.look_at_from_position(mid + Vector3(0.0, 0.0, 6.0), mid)
	for k in 6:
		await process_frame
	root.get_texture().get_image().save_png(OUT + "runes_sword_zoom.png")
	print("shot runes_sword ", sd.id, " ", sw.label())
	quit()
