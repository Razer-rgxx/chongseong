class_name SwordForest
extends RefCounted
## 검의 숲(docs/sword_hill.md 3번, 2026-11-21 사용자: "검 숲은 들판에만"). 먼저 쓰러진 이들의 검이 땅에 꽂혀 있다.
## SwordModel 네 형태 × 세 칠(녹슨 빛, 재 빛, 뼈 빛) = 열두 모양을 메시 하나씩으로 합쳐(_flatten) MultiMesh로 수천 자루를 그린다.
## 칼날이 땅에 박혀 코등이가 무릎에서 허리 높이. 기울기·깊이·크기가 자루마다 다르다. 부딪힘은 없다(꾸밈).

const TINTS: Array[Color] = [Color(0.8, 0.56, 0.4), Color(0.5, 0.5, 0.52), Color(0.86, 0.82, 0.72)]
const FORMS: Array[String] = ["res://data/forms/0_dagger.tres", "res://data/forms/1_longsword.tres", "res://data/forms/2_greatsword.tres", "res://data/forms/3_rapier.tres"]


## 열두 모양(녹슨 날, 빛나는 것은 끈다).
static func variants() -> Array[Mesh]:
	var out: Array[Mesh] = []
	for v in 12:
		var f: FormData = load(FORMS[v % FORMS.size()]) as FormData if ResourceLoader.exists(FORMS[v % FORMS.size()]) else null
		var model := SwordModel.make(f, 0, 900 + v * 17, Color.WHITE)
		out.append(_flatten(model, TINTS[v / 4 % TINTS.size()]))
		model.free()
	return out


## 땅(높이 y)에 꽂힌 한 자루: lean(라디안) 안에서 기울고, s배 크기, 칼날이 stick m만큼 땅 위로 나온 깊이.
static func stuck(rng: RandomNumberGenerator, x: float, z: float, y: float, s: float, lean: float, stick: float) -> Transform3D:
	var b := Basis.from_euler(Vector3(PI + rng.randf_range(-lean, lean), rng.randf() * TAU, rng.randf_range(-lean, lean))).scaled(Vector3.ONE * s)
	return Transform3D(b, Vector3(x, y + stick * s, z))


## 자리들을 열두 모양에 고르게 나눠 MultiMesh로 심는다. far m 밖은 그리지 않는다(0이면 늘).
static func plant(parent: Node3D, meshes: Array[Mesh], xforms: Array[Transform3D], rng: RandomNumberGenerator, shadows: bool, far: float) -> void:
	var by: Array = []
	for v in meshes.size():
		by.append([] as Array[Transform3D])
	for xf in xforms:
		(by[rng.randi() % meshes.size()] as Array[Transform3D]).append(xf)
	for v in meshes.size():
		if (by[v] as Array).is_empty():
			continue
		var mmi := HillBuilder._multi(parent, meshes[v], by[v], shadows)
		if far > 0.0:
			mmi.visibility_range_end = far


## SwordModel(노드 여러 개)을 메시 하나로 합친다. 재질마다 한 겹, 색에 tint를 곱하고 빛과 쇠붙이 느낌을 줄인다(녹슬었다).
static func _flatten(model: Node3D, tint: Color) -> ArrayMesh:
	var am := ArrayMesh.new()
	var by_mat: Dictionary = {}
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf: Transform3D = _rel(model, mi)
		for k in mi.mesh.get_surface_count():
			var mat: Material = mi.get_active_material(k)
			var st: SurfaceTool = by_mat.get(mat)
			if st == null:
				st = SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				by_mat[mat] = st
			st.append_from(mi.mesh, k, xf)
	for mat in by_mat:
		var st: SurfaceTool = by_mat[mat]
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
		var m: Material = mat
		if mat is StandardMaterial3D:
			var sm := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			sm.albedo_color = sm.albedo_color * tint
			sm.emission_enabled = false
			sm.roughness = maxf(sm.roughness, 0.75)
			sm.metallic = sm.metallic * 0.4
			m = sm
		am.surface_set_material(am.get_surface_count() - 1, m)
	return am


static func _rel(root: Node3D, node: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf
