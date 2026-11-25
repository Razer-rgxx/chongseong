extends SceneTree
## 네온 시가(미래 구역, Blender 건물 tools/blender/make_city.py) 확인 그림. /home/claude/shots/neon_city_<자리>.png.
##   street: 큰길 눈높이, plaza: 가운데 광장(홀로그램), sky: 위에서 내려다본 것, edge: 옛 폐허 쪽에서 본 네온 시가, market: 시장 광장(줄 등).
## Blender 건물을 몇 채 세웠는지(Kenney로 돌아간 조각 수)를 출력한다.
## 돌리기: xvfb-run -a godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1600x900 -s scripts/debug/shots/shot_neon_city.gd

const OUT: String = "/home/claude/shots/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	Grid.size = FutureLayout.SIZE
	var w := Node3D.new()
	root.add_child(w)
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	FutureBuilder.environment(we.environment)
	w.add_child(we)
	var t0: int = Time.get_ticks_msec()
	FutureBuilder.build(w)
	print("지은 시간 %d ms" % (Time.get_ticks_msec() - t0))
	_count(w)
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.far = 1200.0
	w.add_child(cam)
	cam.current = true
	var C: float = Grid.CELL
	var shots: Array = [
		["street", Vector3(128.0 * C, 4.0, 88.0 * C), Vector3(128.0 * C, 14.0, 30.0 * C)],
		["plaza", Vector3(117.0 * C + 30.0, 7.0, 51.0 * C + 26.0), Vector3(117.0 * C, 12.0, 51.0 * C)],
		["sky", Vector3(175.0 * C, 230.0, 110.0 * C + 140.0), Vector3(124.0 * C, 0.0, 50.0 * C)],
		["edge", Vector3(81.0 * C, 4.0, 22.0 * C), Vector3(130.0 * C, 30.0, 30.0 * C)],
		["market", Vector3(139.0 * C + 16.0, 3.2, 76.0 * C + 19.0), Vector3(139.0 * C - 4.0, 5.5, 76.0 * C - 6.0)],
	]
	for s in shots:
		cam.look_at_from_position(s[1], s[2])
		for k in 8:
			await process_frame
		root.get_texture().get_image().save_png(OUT + "neon_city_%s.png" % s[0])
		print("shot neon_city_", s[0])
	quit()


## Blender 건물 MultiMesh 인스턴스 수와 Kenney 건물 수, 대략의 정점 수.
func _count(w: Node) -> void:
	var city: int = 0
	var kit: int = 0
	var verts: int = 0
	var idx: Dictionary = NeonDistrict.city_index()
	var meshes: Dictionary = {}
	for nm in idx:
		var info: Dictionary = FutureBuilder._kit(NeonDistrict.CITY + str(nm) + ".glb")
		if not info.is_empty():
			meshes[info.mesh] = nm
	var dist: Node = w.find_child("NeonDistrict", true, false)
	for n in dist.find_children("*", "MultiMeshInstance3D", true, false):
		var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
		if meshes.has(mm.mesh):
			city += mm.instance_count
			var v: int = 0
			for si in mm.mesh.get_surface_count():
				v += (mm.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			verts += v * mm.instance_count
		elif str(mm.mesh.resource_path).contains("city_commercial") or (n as MultiMeshInstance3D).material_override == NeonDistrict.mat_buildings():
			kit += mm.instance_count
	print("Blender 건물 %d종 중 세운 것 %d채(정점 약 %d), Kenney로 돌아간 것 %d" % [idx.size(), city, verts, kit])
