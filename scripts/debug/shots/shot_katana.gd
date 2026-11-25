extends SceneTree
## 사이버 카타나(311, Blender assets/swords/311.glb) 확인 그림. /home/claude/shots/에 남긴다.
##   katana.png: 제품 사진처럼 비스듬히(어두운 배경, 앞빛과 뒤의 찬 테두리빛). katana_detail.png·katana_tip.png: 같은 자세로 가까이.
##   katana_full.png: 칼 전체를 가로로 크게(3200×1000).
##   katana_check.png: 정면 직교 투영. 왼쪽이 Blender 모델, 오른쪽이 코드 카타나(파일이 없을 때 쓰는 것).
##     둘 다 원점(코등이)이 가로줄 위에 있고, 주황 점은 blade_points(베기 궤적의 두 끝)다.
## 돌리기: xvfb-run -a godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1600x900 -s scripts/debug/shots/shot_katana.gd

const OUT: String = "/home/claude/shots/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var d := GameData.load_default()
	var form: FormData = null
	for s in d.swords:
		if s.id == SwordModel.KATANA_SEED:
			form = d.forms[s.form]
	var w := Node3D.new()
	root.add_child(w)
	var we := WorldEnvironment.new()
	we.environment = _env()
	w.add_child(we)
	_backdrop(w)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.97, 0.93)
	key.light_energy = 1.5
	key.rotation = Vector3(-0.75, -0.6, 0.0)
	w.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.6, 0.85, 1.0)
	rim.light_energy = 2.2
	rim.rotation = Vector3(-0.35, 2.6, 0.0)
	w.add_child(rim)
	# 제품 사진: 칼을 제 축으로 조금 돌리고(평면과 덮개가 입체로 보이게), 칼끝이 오른쪽 위로 가게 눕히고, 앞으로 살짝 기울인다
	var pivot := Node3D.new()
	w.add_child(pivot)
	var m := SwordModel.make(form, 4, SwordModel.KATANA_SEED, d.grades.colors[4])
	m.position = Vector3(0.0, -0.53, 0.0)
	pivot.add_child(m)
	pivot.basis = Basis(Vector3.RIGHT, 0.22) * Basis(Vector3.BACK, -1.08) * Basis(Vector3.UP, 0.55)
	var cam := Camera3D.new()
	cam.fov = 17.0
	w.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 0.05, 4.4), Vector3(0.0, 0.0, 0.0))
	for k in 10:
		await process_frame
	print("katana grip=%.3f tip_x=%.3f blade=%.2f points=%s" % [m.grip_length, m.tip_x, m.blade_length, str(m.blade_points())])
	root.get_texture().get_image().save_png(OUT + "katana.png")
	print("shot katana")
	# 가까이: 덮개·코등이·손잡이 윗부분(katana_detail.png), 킷사키(katana_tip.png)
	for shot in [["katana_detail", Vector3(0.0, 0.0, 0.0), 0.95], ["katana_tip", Vector3(-0.05, 1.36, 0.0), 0.5]]:
		var at: Vector3 = m.global_transform * (shot[1] as Vector3)
		cam.look_at_from_position(at + Vector3(0.0, 0.02, float(shot[2])), at)
		for k in 6:
			await process_frame
		root.get_texture().get_image().save_png(OUT + str(shot[0]) + ".png")
		print("shot ", shot[0])
	cam.look_at_from_position(Vector3(0.0, 0.05, 4.4), Vector3(0.0, 0.0, 0.0))
	# 전체: 칼 한 자루를 가로로 눕혀 넓은 그림(3200×1000) 가득(katana_full.png). 칼끝 오른쪽, 날 아래, 제 축으로 돌려 덮개 판이 보이게
	pivot.basis = Basis(Vector3.RIGHT, 0.3) * Basis(Vector3.BACK, -PI / 2.0) * Basis(Vector3.UP, 0.5)
	var vp := SubViewport.new()
	vp.size = Vector2i(3200, 1000)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	w.add_child(vp)
	var wide := Camera3D.new()
	wide.fov = 12.0
	vp.add_child(wide)
	wide.look_at_from_position(Vector3(0.0, 0.02, 2.95), Vector3(0.0, 0.0, 0.0))
	wide.current = true
	for k in 10:
		await process_frame
	vp.get_texture().get_image().save_png(OUT + "katana_full.png")
	print("shot katana_full")
	vp.queue_free()
	# 맞춤 확인: 정면 직교, 왼쪽 Blender, 오른쪽 코드 카타나
	pivot.visible = false
	var glb := SwordModel.make(form, 4, SwordModel.KATANA_SEED, d.grades.colors[4])
	glb.position = Vector3(-0.25, 0.0, 0.0)
	w.add_child(glb)
	var old := SwordModel.new()
	old.blade_length = form.blade_length
	old.position = Vector3(0.25, 0.0, 0.0)
	w.add_child(old)
	old._katana(form.blade_length)
	for s in [glb, old]:
		for p in (s as SwordModel).blade_points():
			_dot(w, p, Color(1.0, 0.5, 0.1))
	var line := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(1.2, 0.002, 0.002)
	line.mesh = lm
	w.add_child(line)
	key.rotation = Vector3(-0.3, 0.0, 0.0)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.95
	cam.look_at_from_position(Vector3(0.0, 0.53, 3.0), Vector3(0.0, 0.53, 0.0))
	for k in 8:
		await process_frame
	root.get_texture().get_image().save_png(OUT + "katana_check.png")
	print("shot katana_check grip old=%.3f new=%.3f" % [old.grip_length, glb.grip_length])
	quit()


func _env() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.024, 0.03)
	var sky := Sky.new()
	var pm := PanoramaSkyMaterial.new()
	pm.panorama = load("res://assets/sky/overcast_soil_puresky.hdr")
	pm.energy_multiplier = 0.45   # 반사만 쓰는 하늘: 너무 밝으면 검은 끈과 건메탈이 회색으로 뜬다
	sky.sky_material = pm
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.35
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.6
	e.glow_hdr_threshold = 1.0
	return e


## 뒤의 어두운 판(가운데가 조금 밝은 둥근 번짐).
func _backdrop(w: Node3D) -> void:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.11, 0.125, 0.15), Color(0.02, 0.024, 0.03)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 512
	t.height = 512
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = t
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(8.0, 5.0)
	q.mesh = qm
	q.material_override = mat
	q.position = Vector3(0.0, 0.0, -2.5)
	w.add_child(q)


func _dot(w: Node3D, p: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.012
	s.height = 0.024
	mi.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.no_depth_test = true
	mi.material_override = m
	mi.position = p
	w.add_child(mi)
