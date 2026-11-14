class_name CreatureMesh
extends RefCounted
## 적의 몸을 코드로 짓는 도구. 단면(타원)을 이어 붙여 매끈한 몸통·머리·다리를 만든다.
## UV: x는 단면을 한 바퀴 도는 비율, y는 시작(0)에서 끝(1)까지의 비율.
## 색: 아래쪽이 조금 밝다(배·턱 밑). 재질에서 vertex_color_use_as_albedo를 켜면 쓰인다.


## sections: [중심 Vector3, 가로 반지름, 세로 반지름]의 배열. 앞뒤 끝은 한 점으로 닫는다.
## belly: 아래쪽을 밝게 하는 정도(0이면 한 색).
static func loft(sections: Array, sides: int = 12, belly: float = 0.25, cap: bool = true) -> ArrayMesh:
	var n: int = sections.size()
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var total: float = 0.0
	var dist: Array[float] = [0.0]
	for i in range(1, n):
		total += (sections[i][0] as Vector3).distance_to(sections[i - 1][0])
		dist.append(total)
	for i in n:
		var c: Vector3 = sections[i][0]
		var t: Vector3 = (sections[mini(i + 1, n - 1)][0] as Vector3) - (sections[maxi(i - 1, 0)][0] as Vector3)
		t = t.normalized() if t.length() > 0.0001 else Vector3.FORWARD
		var ref: Vector3 = Vector3.UP if absf(t.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
		var side: Vector3 = ref.cross(t).normalized()
		var up: Vector3 = t.cross(side).normalized()
		var rx: float = sections[i][1]
		var ry: float = sections[i][2]
		for k in sides + 1:
			var a: float = TAU * k / sides
			verts.append(c + side * cos(a) * rx + up * sin(a) * ry)
			uvs.append(Vector2(float(k) / sides, dist[i] / maxf(total, 0.0001)))
			var low: float = clampf(-sin(a), 0.0, 1.0)
			cols.append(Color.WHITE.lerp(Color(1.0 + belly, 1.0 + belly * 0.9, 1.0 + belly * 0.8), low))
	var row: int = sides + 1
	for i in n - 1:
		for k in sides:
			var a: int = i * row + k
			var b: int = a + row
			idx.append_array([a, b, a + 1, a + 1, b, b + 1])
	if cap:
		for end in [0, n - 1]:
			var c: Vector3 = sections[end][0]
			var ci: int = verts.size()
			verts.append(c)
			uvs.append(Vector2(0.5, 0.0 if end == 0 else 1.0))
			cols.append(Color.WHITE)
			for k in sides:
				var a: int = end * row + k
				if end == 0:
					idx.append_array([ci, a, a + 1])
				else:
					idx.append_array([ci, a + 1, a])
	return _commit(verts, uvs, cols, idx)


## 세로축을 도는 몸(망토 같은). profile: [높이 y, 가로 반지름, 앞뒤 반지름, 뒤로 밀린 정도 z]의 배열(아래에서 위로).
static func lathe(profile: Array, sides: int = 20) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var n: int = profile.size()
	var y0: float = profile[0][0]
	var y1: float = profile[n - 1][0]
	for i in n:
		var p: Array = profile[i]
		for k in sides + 1:
			var a: float = TAU * k / sides
			verts.append(Vector3(sin(a) * p[1], p[0], p[3] - cos(a) * p[2]))
			uvs.append(Vector2(float(k) / sides, (p[0] - y0) / (y1 - y0)))
			cols.append(Color.WHITE)
	var row: int = sides + 1
	for i in n - 1:
		for k in sides:
			var a: int = i * row + k
			var b: int = a + row
			idx.append_array([a, a + 1, b, a + 1, b + 1, b])
	return _commit(verts, uvs, cols, idx)


static func _commit(verts: PackedVector3Array, uvs: PackedVector2Array, cols: PackedColorArray, idx: PackedInt32Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in verts.size():
		st.set_uv(uvs[i])
		st.set_color(cols[i])
		st.add_vertex(verts[i])
	for i in idx:
		st.add_index(i)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## 털 같은 거친 재질. 잡음 질감을 몸 색으로 칠한다.
static func fur(c: Color, dark: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var nz := FastNoiseLite.new()
	nz.frequency = 0.09
	nz.fractal_octaves = 3
	var g := Gradient.new()
	g.colors = PackedColorArray([dark, c])
	var t := NoiseTexture2D.new()
	t.noise = nz
	t.color_ramp = g
	t.seamless = true
	t.width = 128
	t.height = 128
	m.albedo_texture = t
	m.uv1_scale = Vector3(3, 6, 1)
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.6
	return m
