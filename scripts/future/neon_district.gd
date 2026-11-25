class_name NeonDistrict
extends RefCounted
## 네온 시가의 모양(2026-11-25 사용자: 사이버펑크 도시 사진 "이런 느낌으로", "건물 촘촘하게", "미래 오픈월드 규모 늘려").
## FutureLayout.neon_blocks()의 블록마다 Kenney City Kit 건물(CC0)을 빈틈없이 나눠 세우고(블록 = 막힘 하나라 발자국이 블록을 꽉 채운다),
## 길 쪽 면에 네온 줄·광고판(글자 없는 움직이는 도형)·지붕 붉은 등을 붙인다. 하늘길에는 차가 지나고 광장에는 홀로그램.
## 모두 MultiMesh와 셰이더 TIME으로 움직여서 프레임마다 돌리는 코드가 없다. 꾸밈 난수는 지역 RandomNumberGenerator.

const PALETTE: Array[Color] = [Color(0.15, 0.95, 1.0), Color(1.0, 0.2, 0.75), Color(1.0, 0.62, 0.18), Color(0.55, 0.35, 1.0), Color(0.35, 1.0, 0.45)]
const CENTER: Vector2 = Vector2(128, 54)   ## 가장 높은 건물이 모이는 곳(칸)
const LOT_M: Vector2 = Vector2(9.0, 15.0)  ## 건물 한 채의 가로 범위(m)
const H_MIN: float = 16.0
const H_MAX: float = 120.0
const BOARD_RANGE: float = 260.0           ## 광고판·네온 줄이 보이는 거리(m)


static func build(root: Node3D, rng: RandomNumberGenerator) -> void:
	var city := Node3D.new()
	city.name = "NeonDistrict"
	root.add_child(city)
	var groups: Dictionary = {}
	var lots: Array = []   # {rect(m, xz), h, faces: [법선 Vector2...]}
	for r in FutureLayout.neon_blocks():
		_block(groups, lots, r, rng)
	FutureBuilder._flush(city, groups, mat_buildings())
	_curbs(city)
	_streets(city, rng)
	_signs(city, lots, rng)
	_traffic(city, rng)
	_plazas(city, rng)
	_puddles(city, rng)


## 네온 시가 건물 재질: 옛 폐허와 같은 셰이더에 켜진 창을 훨씬 많이(따뜻한·차가운·분홍), 몇 창은 느리게 꺼졌다 켜진다.
static func mat_buildings() -> Material:
	var base := FutureBuilder._kit_building_mat() as ShaderMaterial
	if FutureBuilder._tex.has("neon_bld"):
		return FutureBuilder._tex.neon_bld
	var m := base.duplicate() as ShaderMaterial
	m.set_shader_parameter("tint", Color(0.42, 0.46, 0.6))
	m.set_shader_parameter("warm_r", 0.2)
	m.set_shader_parameter("cool_r", 0.38)
	m.set_shader_parameter("pink_r", 0.47)
	m.set_shader_parameter("dark_r", 0.56)
	m.set_shader_parameter("lit_energy", 3.2)
	m.set_shader_parameter("flicker", 0.05)
	m.set_shader_parameter("grid_lit", 0.32)
	m.set_shader_parameter("seed", 7.0)
	FutureBuilder._tex["neon_bld"] = m
	return m


## 블록 하나를 건물로 빈틈없이 나눈다. 높이는 CENTER에 가까울수록 높다. 블록 둘레에 닿은 면은 길 쪽(간판을 붙일 면).
static func _block(groups: Dictionary, lots: Array, r: Rect2, rng: RandomNumberGenerator) -> void:
	var x0: float = r.position.x * Grid.CELL
	var z0: float = r.position.y * Grid.CELL
	var w: float = r.size.x * Grid.CELL
	var d: float = r.size.y * Grid.CELL
	var xs: Array[float] = _cuts(w, rng)
	var zs: Array[float] = _cuts(d, rng)
	var far: float = (r.get_center() - CENTER).length()
	var top: float = lerpf(H_MAX, 38.0, clampf(far / 95.0, 0.0, 1.0))
	for ix in xs.size() - 1:
		for iz in zs.size() - 1:
			var lx: float = x0 + xs[ix]
			var lz: float = z0 + zs[iz]
			var lw: float = xs[ix + 1] - xs[ix]
			var ld: float = zs[iz + 1] - zs[iz]
			var edge: bool = ix == 0 or iz == 0 or ix == xs.size() - 2 or iz == zs.size() - 2
			var h: float = maxf(H_MIN, top * rng.randf_range(0.35, 1.0))
			if edge and rng.randf() < 0.3:
				h = maxf(H_MIN, h * 0.45)   # 길가에 낮은 가게 건물이 섞인다
			var faces: Array[Vector2] = []
			if iz == 0:
				faces.append(Vector2(0, -1))
			if iz == zs.size() - 2:
				faces.append(Vector2(0, 1))
			if ix == 0:
				faces.append(Vector2(-1, 0))
			if ix == xs.size() - 2:
				faces.append(Vector2(1, 0))
			var yaw: float = 0.0
			if not faces.is_empty():
				var f: Vector2 = faces[0]
				yaw = atan2(f.x, f.y)
			_building(groups, Rect2(lx, lz, lw, ld), h, yaw, rng)
			lots.append({"rect": Rect2(lx, lz, lw, ld), "h": h, "faces": faces})


## 길이 len(m)을 LOT_M 범위의 조각으로 자른 경계들(0부터 len까지).
static func _cuts(len: float, rng: RandomNumberGenerator) -> Array[float]:
	var n: int = maxi(1, roundi(len / rng.randf_range(LOT_M.x, LOT_M.y)))
	var out: Array[float] = [0.0]
	var acc: float = 0.0
	for i in n - 1:
		acc += len / n * rng.randf_range(0.8, 1.2)
		out.append(minf(acc, len - 4.0))
	out.append(len)
	return out


## 건물 한 채: 가로 대비 높이가 가장 가까운 Kenney 모델을 발자국에 꽉 맞춰 세운다(FutureBuilder._tower와 같은 방식).
static func _building(groups: Dictionary, lot: Rect2, h: float, yaw: float, rng: RandomNumberGenerator) -> void:
	var want: float = h / maxf(lot.size.x, lot.size.y)
	var best: String = ""
	var best_s: float = 1e9
	for nm in FutureBuilder.BLD_MODELS:
		var info: Dictionary = FutureBuilder._kit(FutureBuilder.KIT_C + nm + ".glb")
		if info.is_empty():
			continue
		var ab: AABB = info.aabb
		var sc: float = absf(log((ab.size.y / maxf(ab.size.x, ab.size.z)) / want)) + rng.randf() * 0.35
		if sc < best_s:
			best_s = sc
			best = nm
	if best == "":
		return
	var path: String = FutureBuilder.KIT_C + best + ".glb"
	var ab: AABB = FutureBuilder._kit(path).aabb
	var c: Vector3 = ab.position + ab.size * 0.5
	var turned: bool = absf(sin(yaw)) > 0.5
	var tx: float = lot.size.y if turned else lot.size.x
	var tz: float = lot.size.x if turned else lot.size.y
	var body := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(tx / ab.size.x, h / ab.size.y, tz / ab.size.z))
	var at := Vector3(lot.position.x + lot.size.x * 0.5, 0.0, lot.position.y + lot.size.y * 0.5)
	FutureBuilder._put_raw(groups, path, Transform3D(body, at) * Transform3D(Basis(), Vector3(-c.x, -ab.position.y, -c.z)))


## 블록 둘레의 보도 턱(낮은 콘크리트 판)과 가게 앞 차양 빛 줄은 _signs가 붙인다.
static func _curbs(city: Node3D) -> void:
	var pave := FutureBuilder._concrete()
	for r in FutureLayout.neon_blocks() + FutureLayout.plaza_rects():
		var w: float = r.size.x * Grid.CELL + 3.0
		var d: float = r.size.y * Grid.CELL + 3.0
		FutureBuilder._box(city, Vector3(w, 0.16, d), Vector3(r.get_center().x * Grid.CELL, 0.08, r.get_center().y * Grid.CELL), pave)


## 길: 블록 사이 길의 가운데 줄마다 Kenney 직선 길 조각, 만나는 곳은 교차로. 길가에 가로등.
static func _streets(city: Node3D, rng: RandomNumberGenerator) -> void:
	var g: Dictionary = {}
	var lamps: Dictionary = {}
	var straight: String = FutureBuilder.KIT_R + "road-straight.glb"
	var cross: String = FutureBuilder.KIT_R + "road-crossroad.glb"
	var M: float = FutureBuilder.ROAD_M
	var flat := Basis.from_scale(Vector3(M, 0.1, M))
	var W: float = FutureLayout.SIZE.x * Grid.CELL
	var D: float = FutureLayout.SIZE.y * Grid.CELL
	var xl: Array[float] = _lanes(FutureLayout.X_SPANS, FutureLayout.SIZE.x)
	var zl: Array[float] = _lanes(FutureLayout.Y_SPANS, FutureLayout.SIZE.y)
	var old: Rect2 = Rect2(FutureLayout.OLD.position * Grid.CELL, FutureLayout.OLD.size * Grid.CELL)
	var rs := Vector3(M, M, M)
	for x in xl:   # 남북 길
		var z: float = M * 0.5
		while z < D:
			var p := Vector3(x, 0.025, z)
			if not old.has_point(Vector2(p.x, p.z)):
				var on_cross: bool = false
				for zz in zl:
					on_cross = on_cross or absf(zz - z) < M * 0.5
				_put(g, cross if on_cross else straight, Transform3D((Basis() if on_cross else Basis(Vector3.UP, PI / 2.0)) * flat, p))
				if int(z / M) % 3 == 1:
					_put(lamps, FutureBuilder.KIT_R + "light-square-double.glb", Transform3D(Basis(Vector3.UP, 0.0).scaled(rs), Vector3(x - M * 0.62, 0, z)))
			z += M
	for zz in zl:   # 동서 길(교차로는 위에서 깔았다)
		var x: float = M * 0.5
		while x < W:
			var p := Vector3(x, 0.025, zz)
			var hit: bool = false
			for xx in xl:
				hit = hit or absf(xx - x) < M * 0.5
			if not hit and not old.has_point(Vector2(p.x, p.z)):
				_put(g, straight, Transform3D(flat, p))
				if int(x / M) % 3 == 1:
					_put(lamps, FutureBuilder.KIT_R + "light-square-double.glb", Transform3D(Basis(Vector3.UP, PI / 2.0).scaled(rs), Vector3(x, 0, zz - M * 0.62)))
			x += M
	FutureBuilder._flush(city, g, FutureBuilder._kit_road_mat())
	FutureBuilder._flush(city, lamps, FutureBuilder._kit_road_mat(), 0.0, FutureBuilder.SMALL_RANGE * 1.8)


## 블록 사이 길들의 가운데(m). 마지막 블록 뒤의 길(지도 끝)까지.
static func _lanes(spans: Array[Vector2], size: int) -> Array[float]:
	var out: Array[float] = []
	var prev: float = 0.0
	for s in spans:
		if s.x - prev >= 3.0:
			out.append((prev + s.x) * 0.5 * Grid.CELL)
		prev = s.y
	if size - prev >= 3.0:
		out.append((prev + size) * 0.5 * Grid.CELL)
	return out


static func _put(g: Dictionary, path: String, xf: Transform3D) -> void:
	FutureBuilder._put(g, path, xf)


## 길 쪽 면마다: 세로 네온 줄(모서리), 층 띠, 광고판(가로·세로 현수막), 가게 앞 차양 빛 줄, 꼭대기 붉은 등.
static func _signs(city: Node3D, lots: Array, rng: RandomNumberGenerator) -> void:
	var strips: Array = []    # [Transform3D, Color]
	var beacons: Array = []
	var boards: Array = []    # [Transform3D, Color(custom)]
	for lot in lots:
		var r: Rect2 = lot.rect
		var h: float = lot.h
		if h > 55.0 and rng.randf() < 0.8:
			beacons.append([Transform3D(Basis.from_scale(Vector3.ONE * 0.9), Vector3(r.get_center().x, h + 0.6, r.get_center().y)), Color(1.0, 0.12, 0.1)])
		for f in lot.faces:
			var n: Vector2 = f
			var t := Vector2(-n.y, n.x)   # 면을 따라가는 쪽
			var span: float = absf(t.x) * r.size.x + absf(t.y) * r.size.y
			var mid: Vector2 = r.get_center() + n * (absf(n.x) * r.size.x + absf(n.y) * r.size.y) * 0.5
			var face_yaw: float = atan2(n.x, n.y)
			var col: Color = PALETTE[rng.randi() % PALETTE.size()]
			var out: float = 0.25
			# 가게 앞 차양 빛 줄(높이 3.6m, 면 거의 전체)
			strips.append([_bar(mid + n * 0.9, 3.6, Vector3(span * 0.92, 0.14, 0.14), face_yaw), PALETTE[rng.randi() % PALETTE.size()]])
			# 모서리 세로 줄
			if rng.randf() < 0.65:
				var side: float = (1.0 if rng.randf() < 0.5 else -1.0) * (span * 0.5 - 0.4)
				var top: float = h * rng.randf_range(0.6, 0.95)
				var p2: Vector2 = mid + n * out + t * side
				strips.append([_bar(p2, (5.0 + top) * 0.5, Vector3(0.32, top - 5.0, 0.32), face_yaw), col])
			# 층 띠
			if h > 30.0 and rng.randf() < 0.5:
				var y: float = rng.randf_range(12.0, h * 0.8)
				strips.append([_bar(mid + n * out, y, Vector3(span * 0.9, 0.22, 0.2), face_yaw), col])
			# 광고판: 가로 큰 판 또는 세로 현수막
			var nb: int = 1 + (1 if span > 11.0 and rng.randf() < 0.5 else 0)
			for k in nb:
				var tall: bool = rng.randf() < 0.45
				var bw: float = rng.randf_range(2.0, 3.0) if tall else minf(span * 0.8, rng.randf_range(5.0, 12.0))
				var bh: float = rng.randf_range(7.0, 14.0) if tall else bw * rng.randf_range(0.45, 0.7)
				var y: float = rng.randf_range(6.0, maxf(7.0, minf(h - bh * 0.5 - 2.0, 48.0)))
				if y + bh * 0.5 > h:
					continue
				var along: float = rng.randf_range(-1.0, 1.0) * maxf(0.0, span * 0.5 - bw * 0.5 - 0.5)
				var p3: Vector2 = mid + n * (out + 0.35) + t * along
				var bxf := Transform3D(Basis(Vector3.UP, face_yaw) * Basis.from_scale(Vector3(bw, bh, 1.0)), Vector3(p3.x, y, p3.y))
				boards.append([bxf, Color(rng.randf(), rng.randf(), rng.randf(), rng.randf())])
	_multi(city, BoxMesh.new(), strips, _strip_mat(0.0), BOARD_RANGE)
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 8
	sphere.rings = 4
	_multi(city, sphere, beacons, _strip_mat(0.45), 0.0)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = boards.size()
	for i in boards.size():
		mm.set_instance_transform(i, boards[i][0])
		mm.set_instance_custom_data(i, boards[i][1])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var bm := ShaderMaterial.new()
	bm.shader = load("res://assets/future/neon_board.gdshader")
	mi.material_override = bm
	mi.visibility_range_end = BOARD_RANGE
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	city.add_child(mi)


## 면에 붙는 줄 하나: 바닥 자리(칸이 아닌 m 단위 xz), 높이 y, 크기(면을 따라·위·앞).
static func _bar(p: Vector2, y: float, size: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), Vector3(p.x, y, p.y))


static func _strip_mat(blink: float) -> Material:
	var key: String = "neon_strip_%s" % blink
	if FutureBuilder._tex.has(key):
		return FutureBuilder._tex[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/future/neon_strip.gdshader")
	m.set_shader_parameter("blink", blink)
	m.set_shader_parameter("energy", 4.0 if blink > 0.0 else 3.0)
	FutureBuilder._tex[key] = m
	return m


## [Transform3D, Color] 목록을 색 있는 MultiMesh 하나로(위상은 custom.a에 난수).
static func _multi(city: Node3D, mesh: Mesh, items: Array, mat: Material, vis: float) -> void:
	if items.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
		mm.set_instance_custom_data(i, Color(0, 0, 0, fmod(i * 0.6180339, 1.0)))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.visibility_range_end = vis
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	city.add_child(mi)


## 하늘길: 길 위 높이 22~70m에 동서·남북 줄을 몇 개 긋고 줄마다 차 몇 대(셰이더가 민다).
static func _traffic(city: Node3D, rng: RandomNumberGenerator) -> void:
	var W: float = FutureLayout.SIZE.x * Grid.CELL
	var D: float = FutureLayout.SIZE.y * Grid.CELL
	var xl: Array[float] = _lanes(FutureLayout.X_SPANS, FutureLayout.SIZE.x)
	var zl: Array[float] = _lanes(FutureLayout.Y_SPANS, FutureLayout.SIZE.y)
	var cars: Array = []
	for zz in zl:
		for k in 2:
			var y: float = rng.randf_range(22.0, 70.0)
			var dir: float = 0.0 if k == 0 else PI
			var n: int = rng.randi_range(3, 6)
			for i in n:
				cars.append([Transform3D(Basis(Vector3.UP, dir), Vector3(W * 0.5, y, zz + (k - 0.5) * 3.0)), Color(rng.randf_range(16.0, 30.0), float(i) / n + rng.randf() * 0.1, W + 160.0, 0.0)])
	for xx in xl:
		if xx < FutureLayout.OLD.size.x * Grid.CELL:
			continue
		var y: float = rng.randf_range(26.0, 75.0)
		var n: int = rng.randi_range(2, 5)
		for i in n:
			cars.append([Transform3D(Basis(Vector3.UP, PI / 2.0 if rng.randf() < 0.5 else -PI / 2.0), Vector3(xx, y, D * 0.5)), Color(rng.randf_range(16.0, 30.0), float(i) / n + rng.randf() * 0.1, D + 160.0, 0.0)])
	var box := BoxMesh.new()
	box.size = Vector3(2.4, 0.7, 1.2)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = box
	mm.instance_count = cars.size()
	for i in cars.size():
		mm.set_instance_transform(i, cars[i][0])
		mm.set_instance_custom_data(i, cars[i][1])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/future/neon_flyer.gdshader")
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-W, 0, -D), Vector3(W * 3.0, 120.0, D * 3.0))   # 셰이더가 옮기니 넉넉히
	city.add_child(mi)


## 광장: 가운데 광장은 빛기둥과 도는 고리 홀로그램, 시장 광장은 차양·파라솔과 줄 등, 남쪽 광장은 네온 문. 광장마다 색 빛 둘.
static func _plazas(city: Node3D, rng: RandomNumberGenerator) -> void:
	var rects: Array[Rect2] = FutureLayout.plaza_rects()
	for i in rects.size():
		var r: Rect2 = rects[i]
		var c := Vector3(r.get_center().x * Grid.CELL, 0, r.get_center().y * Grid.CELL)
		var col: Color = PALETTE[i % PALETTE.size()]
		for k in 2:
			var l := OmniLight3D.new()
			l.light_color = PALETTE[(i + k * 2) % PALETTE.size()]
			l.light_energy = 2.2
			l.omni_range = 20.0
			l.shadow_enabled = false
			l.position = c + Vector3((k - 0.5) * 12.0, 5.0, (0.5 - k) * 8.0)
			city.add_child(l)
		match i:
			0:
				_holo(city, c, col)
			1:
				var g: Dictionary = {}
				var s := Vector3.ONE * 4.0
				for k in 8:
					var at := c + Vector3(rng.randf_range(-11.0, 11.0), 0, rng.randf_range(-11.0, 11.0))
					var nm: String = ["detail-awning", "detail-parasol-a", "detail-parasol-b", "detail-awning-wide"][k % 4]
					FutureBuilder._put(g, FutureBuilder.KIT_C + nm + ".glb", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(s), at))
				FutureBuilder._flush(city, g, mat_buildings(), 0.0, FutureBuilder.SMALL_RANGE * 1.5)
				var lights: Array = []
				for k in 6:
					var z: float = c.z - 12.0 + k * 4.8
					lights.append([Transform3D(Basis.from_scale(Vector3(r.size.x * Grid.CELL * 0.9, 0.08, 0.08)), Vector3(c.x, 4.6 + 0.3 * sin(k), z)), PALETTE[(k + 1) % PALETTE.size()]])
				_multi(city, BoxMesh.new(), lights, _strip_mat(0.0), BOARD_RANGE)
			_:
				var gate: Array = []
				var w: float = 14.0
				gate.append([Transform3D(Basis.from_scale(Vector3(0.5, 9.0, 0.5)), c + Vector3(-w * 0.5, 4.5, 0)), col])
				gate.append([Transform3D(Basis.from_scale(Vector3(0.5, 9.0, 0.5)), c + Vector3(w * 0.5, 4.5, 0)), col])
				gate.append([Transform3D(Basis.from_scale(Vector3(w + 0.5, 0.5, 0.5)), c + Vector3(0, 9.0, 0)), PALETTE[(i + 1) % PALETTE.size()]])
				gate.append([Transform3D(Basis.from_scale(Vector3(w - 3.0, 0.25, 0.25)), c + Vector3(0, 7.6, 0)), col])
				_multi(city, BoxMesh.new(), gate, _strip_mat(0.0), BOARD_RANGE)


## 빛기둥 하나와 서로 다르게 도는 고리 셋(더하는 빛).
static func _holo(city: Node3D, c: Vector3, col: Color) -> void:
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.2
	cyl.bottom_radius = 2.4
	cyl.height = 26.0
	cyl.cap_top = false
	cyl.cap_bottom = false
	beam.mesh = cyl
	beam.position = c + Vector3(0, 13.0, 0)
	beam.material_override = _holo_mat(col, 0.0, 0.35)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	city.add_child(beam)
	for k in 3:
		var ring := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 4.0 + k * 1.6
		tor.outer_radius = 4.35 + k * 1.6
		tor.rings = 48
		ring.mesh = tor
		ring.position = c + Vector3(0, 8.0 + k * 4.5, 0)
		ring.rotation_degrees = Vector3(18.0 * (k - 1), 0, 12.0 * k)
		ring.material_override = _holo_mat(PALETTE[(k + 1) % PALETTE.size()], 0.3 + 0.25 * k * (1.0 if k % 2 == 0 else -1.0), 0.7)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		city.add_child(ring)


static func _holo_mat(col: Color, spin: float, alpha: float) -> Material:
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/future/neon_holo.gdshader")
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("spin", spin)
	m.set_shader_parameter("alpha", alpha)
	return m


## 길 위 젖은 웅덩이(거울처럼 매끈한 판): 블록·광장 밖의 길에만.
static func _puddles(city: Node3D, rng: RandomNumberGenerator) -> void:
	var wet := StandardMaterial3D.new()
	wet.albedo_color = Color(0.02, 0.025, 0.035)
	wet.metallic = 0.9
	wet.roughness = 0.04
	var rects: Array[Rect2] = FutureLayout.neon_blocks()
	var xs: Array[Transform3D] = []
	var tries: int = 0
	while xs.size() < 60 and tries < 600:
		tries += 1
		var at := Vector2(rng.randf_range(2.0, FutureLayout.SIZE.x - 2.0), rng.randf_range(2.0, FutureLayout.SIZE.y - 2.0))
		if FutureLayout.OLD.has_point(at):
			continue
		var bad: bool = false
		for r in rects:
			bad = bad or r.grow(1.5).has_point(at)
		if bad:
			continue
		var s: float = rng.randf_range(1.8, 4.5)
		xs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, 1.0, s * rng.randf_range(0.5, 1.0))), Vector3(at.x * Grid.CELL, 0.045, at.y * Grid.CELL)))
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 20
	FutureBuilder._multi(city, disc, xs, wet, FutureBuilder.SMALL_RANGE * 1.5)
