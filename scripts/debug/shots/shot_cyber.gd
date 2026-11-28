extends SceneTree
## 사이버 검 확인 그림(docs/cyber_swords.md): 위 줄은 여섯 종류(단검·카타나·오니마루·환도·중장도·대검)의 여러 등급, 아래 줄은 종류마다 무한 하나.
## /home/claude/shots/cyber_swords.png (1280×720). 돌리기:
##   Xvfb :99 -screen 0 1280x720x24 &  DISPLAY=:99 godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s scripts/debug/shots/shot_cyber.gd

const OUT: String = "/home/claude/shots/"
const TOP_GRADES: Array[int] = [1, 3, 4, 2, 3, 4]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var d := GameData.load_default()
	var w := Node3D.new()
	root.add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.04, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.3, 0.38)
	env.ambient_light_energy = 0.7
	env.glow_enabled = true
	env.glow_intensity = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.3
	key.rotation = Vector3(-0.7, -0.5, 0.0)
	w.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.55, 0.85, 1.0)
	rim.light_energy = 1.8
	rim.rotation = Vector3(-0.3, 2.6, 0.0)
	w.add_child(rim)
	var picks: Array[SwordData] = []
	for k in 6:
		picks.append(_pick(d, CyberSwords.SUBS[k], TOP_GRADES[k], 0))
	for k in 6:
		picks.append(_pick(d, CyberSwords.SUBS[k], 5, 0))
	for i in picks.size():
		var s: SwordData = picks[i]
		var m := SwordModel.make(d.forms[s.form], s.grade, s.id, d.grades.colors[s.grade])
		var col: int = i % 6
		var row: int = i / 6
		m.position = Vector3((col - 2.5) * 0.95, 1.15 - row * 2.2 - (m.blade_length - m.grip_length) * 0.5 + 0.1, 0.0)
		m.rotation = Vector3(0.0, 0.3 if row == 0 else PI + 0.35, 0.0)   # 아래 줄(Blender 무한)은 총열과 탄창이 보이는 쪽에서
		w.add_child(m)
		print("%d %s (%s, %s)" % [i, s.display_name, d.grades.names[s.grade], s.sub_type])
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.5
	w.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 0.0, 6.0), Vector3(0.0, 0.0, 0.0))
	for k in 12:
		await process_frame
	root.get_texture().get_image().save_png(OUT + "cyber_swords.png")
	print("shot cyber_swords")
	quit()


static func _pick(d: GameData, sub: String, grade: int, nth: int) -> SwordData:
	var n: int = 0
	for s in d.swords:
		if s.cyber and s.id >= CyberSwords.FIRST and s.sub_type == sub and s.grade == grade:
			if n == nth:
				return s
			n += 1
	return null
