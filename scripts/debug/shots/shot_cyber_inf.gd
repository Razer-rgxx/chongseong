extends SceneTree
## 사이버 검 무한 12자루(Blender assets/swords/<번호>.glb, tools/blender/make_cyber_swords.py) 확인 그림. /home/claude/shots/에 남긴다.
##   cyber_inf.png: 12자루를 한 장에(위 줄 긴 칼: 카타나·중장도·대검, 아래 줄 짧은 칼: 단검·오니마루·환도). 총열·탄창이 있는 쪽(Godot -Z)에서 본다.
##   cyber_inf_<번호>.png: 몇 자루를 가까이(덮개·총몸·총열·코등이).
## 손잡이 길이와 칼끝(blade_points)이 종류 값(CyberModel.SHAPE)과 같은지 찍기 전에 출력한다.
## 돌리기: xvfb-run -a godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1600x900 -s scripts/debug/shots/shot_cyber_inf.gd

const OUT: String = "/home/claude/shots/"
const IDS: Array[int] = [349, 487, 352, 490, 329, 377, 384, 486, 470, 482, 423, 453]
const CLOSE: Array[int] = [470, 377]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var d := GameData.load_default()
	var w := Node3D.new()
	root.add_child(w)
	var we := WorldEnvironment.new()
	we.environment = _env()
	w.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.97, 0.93)
	key.light_energy = 1.5
	key.rotation = Vector3(-0.7, 0.5, 0.0)
	w.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.6, 0.85, 1.0)
	rim.light_energy = 2.0
	rim.rotation = Vector3(-0.35, -2.6, 0.0)
	w.add_child(rim)
	var models: Dictionary = {}
	for i in IDS.size():
		var sd: SwordData = d.sword_by_id(IDS[i])
		var m := SwordModel.make(d.forms[sd.form], sd.grade, sd.id, d.grades.colors[sd.grade])
		var col: int = i % 6
		var row: int = i / 6
		m.position = Vector3((col - 2.5) * 0.86, 0.1 if row == 0 else -1.53, 0.0)
		m.rotation = Vector3(0.0, PI - 0.3, 0.0)   # 총열·탄창 쪽(Godot -Z)이 보이게 돌리고 조금 비스듬히
		w.add_child(m)
		models[IDS[i]] = m
	var vp := SubViewport.new()
	vp.size = Vector2i(2400, 1500)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	w.add_child(vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.85
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, -0.05, 6.0), Vector3(0.0, -0.05, 0.0))
	cam.current = true
	for k in 12:
		await process_frame
	for id in IDS:
		var m: SwordModel = models[id]
		var sd: SwordData = d.sword_by_id(id)
		var S: Dictionary = CyberModel.SHAPE[sd.sub_type]
		var tip: Vector3 = m.global_transform.affine_inverse() * m.blade_points()[1]
		print("%d %s grip=%.3f(종류 %.3f) tip_x=%.4f(종류 %.4f) 칼끝 %s" % [id, sd.sub_type, m.grip_length, float(S.grip), m.tip_x, -float(S.sori) * m.blade_length, str(tip)])
	vp.get_texture().get_image().save_png(OUT + "cyber_inf.png")
	print("shot cyber_inf")
	vp.queue_free()
	# 가까이: 그 칼만 남기고 덮개·총몸 쪽을 비스듬히
	var cam2 := Camera3D.new()
	cam2.fov = 24.0
	w.add_child(cam2)
	cam2.current = true
	for id in CLOSE:
		for k in models:
			(models[k] as SwordModel).visible = k == id
		var m: SwordModel = models[id]
		var at: Vector3 = m.global_transform * Vector3(0.0, 0.24, 0.0)
		cam2.look_at_from_position(at + Vector3(-0.55, 0.3, 1.15), at)   # 칼을 돌려 두었으니 총열 쪽은 +Z
		for k in 6:
			await process_frame
		root.get_texture().get_image().save_png(OUT + "cyber_inf_%d.png" % id)
		print("shot cyber_inf_%d" % id)
	quit()


func _env() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.035, 0.04, 0.05)
	var sky := Sky.new()
	var pm := PanoramaSkyMaterial.new()
	pm.panorama = load("res://assets/sky/overcast_soil_puresky.hdr")
	pm.energy_multiplier = 0.45   # 반사만 쓰는 하늘(검은 쇠가 회색으로 뜨지 않게)
	sky.sky_material = pm
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.4
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.6
	e.glow_hdr_threshold = 1.0
	return e
