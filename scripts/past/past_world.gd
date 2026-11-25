class_name PastWorld
extends RefCounted
## 넓힌 과거(2026-11-26, PastLayout.REGIONS)를 그린다: 거인의 뼈 들, 수정 호수(하늘배 「첫 닻호」와 선착장), 잿불 능선, 용의 산맥(벼랑, 용 해골, 둥지, 하늘을 도는 용), 옛 숲과 새 땅 사이 나무 줄.
## 이야기 자리(StoryPast)의 기억의 돌·첫 대장장이 혼·봉인 제단도 여기서 짓는다. 세계에 글자 없음(새김은 무늬뿐).
## 모양은 상자·원기둥과 받은 자연 모델(assets/nature, HillBuilder._parts)만 쓴다(AI 생성 에셋 없음).

const BONE: Color = Color(0.6, 0.56, 0.46)
const ASH: Color = Color(0.09, 0.08, 0.075)
const EMBER: Color = Color(1.0, 0.45, 0.12)
const CRYSTAL: Color = Color(0.55, 0.8, 1.0)
const WATER: Color = Color(0.08, 0.2, 0.26, 0.86)
const SPIRIT: Color = Color(1.0, 0.82, 0.45, 0.5)


static func _m(p: Vector2) -> Vector3:
	return Vector3(p.x * Grid.CELL, 0.0, p.y * Grid.CELL)


static func _glow(key: String, c: Color, e: float) -> StandardMaterial3D:
	return PastBuilder._plain(key, c, 0.5, e)


## 다 짓는다. 돌려주는 것: {fires: [{light, phase}], seal, memories: {i: Node3D}, smith, captain, ship, dragons: [Node3D], hoard}.
static func build(root: Node3D, meta: Meta) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3100
	var fires: Array = []
	_edge(root, rng)
	_bones(root, rng)
	_lake(root, rng, fires)
	_ash(root, rng, fires)
	_scatter(root, rng)
	_fire_scar(root, fires)
	_dragon_realm(root, rng, fires)
	var hoard := hoard_pile(root, _m(PastLayout.hoard_at()), meta != null and meta.field_found.has(PastLayout.HOARD_ID))
	var ship := sky_ship(root)
	_dock(root)
	var cap := captain(root, _m(StoryPast.CAPTAIN_AT))
	var dragons: Array[Node3D] = []
	for i in PastLayout.SKY_DRAGONS.size():
		dragons.append(sky_dragon(root, 0.8 + 0.2 * i))
	var seal := seal_altar(root, _m(StoryPast.SEAL_AT), meta != null and meta.anchor_hand)
	fires.append({"light": seal.get_node("Light"), "phase": 1.3})
	var mem: Dictionary = {}
	for i in StoryPast.MEMORIES.size():
		mem[i] = memory_stone(root, _m(StoryPast.MEMORIES[i].at), meta != null and meta.past_memories.has(i))
	var smith := spirit(root, _m(StoryPast.SMITH_AT))
	return {"fires": fires, "seal": seal, "memories": mem, "smith": smith, "captain": cap, "ship": ship, "dragons": dragons, "hoard": hoard}


# ---------------------------------------------------------------- 나무 줄

static func _edge(root: Node3D, rng: RandomNumberGenerator) -> void:
	for t in PastLayout.edge_trees():
		PastBuilder._big_tree(root, Vector2(t.x, t.y), t.z, rng, false)
	for t in PastLayout.LAKE_TREES:
		PastBuilder._big_tree(root, Vector2(t.x, t.y), t.z, rng, true)


## 새 땅에 흩은 것(PastLayout.scatter, 막힘과 같은 자리).
static func _scatter(root: Node3D, rng: RandomNumberGenerator) -> void:
	var basalt := PastBuilder._plain("basalt", Color(0.12, 0.11, 0.1), 0.9)
	var ember := _glow("ember", EMBER, 2.6)
	for t in PastLayout.scatter():
		var p := Vector2(t.x, t.y)
		match int(t.w):
			0:
				dead_tree(root, _m(p), rng)
			1:
				PastBuilder._big_tree(root, p, t.z, rng, true)
			2:   # 현무암 기둥: 기운 오각 기둥과 잿불 금 한 줄
				var h: float = rng.randf_range(5.0, 11.0)
				var col := CylinderMesh.new()
				col.top_radius = t.z * 0.7
				col.bottom_radius = t.z * Grid.CELL * 0.6
				col.height = h
				col.radial_segments = 5
				var rot := Vector3(rng.randf_range(-7, 7), rng.randf() * 72.0, rng.randf_range(-7, 7))
				PastBuilder._put(root, col, basalt, _m(p) + Vector3(0, h * 0.45, 0), rot, 220.0)
				PastBuilder._box(root, Vector3(0.1, h * 0.6, 0.1), _m(p) + Vector3(0, h * 0.35, 0) + Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(rot.y)) * -t.z * 1.05, ember, rot)
			3:   # 용 이빨 바위: 휘어 솟은 잿빛 바위 두세 마디
				dragon_tooth(root, _m(p), t.z, rng)


# ---------------------------------------------------------------- 거인의 뼈 들

static func _bones(root: Node3D, rng: RandomNumberGenerator) -> void:
	var bone: StandardMaterial3D = PastBuilder._plain("bone", BONE, 0.85)
	var bone_dark: StandardMaterial3D = PastBuilder._plain("bone_dark", BONE.darkened(0.35), 0.9)
	var grass: StandardMaterial3D = PastBuilder._plain("dry_grass", Color(0.36, 0.31, 0.17), 1.0)
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 12
	var r: Rect2 = PastLayout.REGIONS[0].rect
	for i in 18:   # 마른 풀 자국
		var p := Vector2(rng.randf_range(r.position.x + 3.0, r.end.x - 3.0), rng.randf_range(r.position.y + 3.0, r.end.y - 3.0))
		var mi := PastBuilder._put(root, disc, grass, _m(p) + Vector3(0, 0.016, 0), Vector3.ZERO, 120.0)
		mi.scale = Vector3(rng.randf_range(5.0, 11.0), 1.0, rng.randf_range(4.0, 9.0))
	# 갈비뼈: 기둥 쌍이 안쪽으로 굽어 아치를 이룬다(세 마디로 꺾어 올린다)
	for rb in PastLayout.RIBS:
		var dir := Vector2.from_angle(rb.z)
		var side := dir.orthogonal()
		for k in PastLayout.RIB_PAIRS:
			var c := Vector2(rb.x, rb.y) + dir * (k - (PastLayout.RIB_PAIRS - 1) * 0.5) * PastLayout.RIB_GAP
			var h: float = 9.0 - absf(k - (PastLayout.RIB_PAIRS - 1) * 0.5) * 1.3   # 가운데가 높다
			for sgn in [-1.0, 1.0]:
				_rib(root, _m(c + side * PastLayout.RIB_SPAN * 0.5 * sgn), _m(c), h, bone)
			# 등뼈 마디(땅에 반쯤 묻힘)
			PastBuilder._box(root, Vector3(1.4, 0.5, 1.1), _m(c) + Vector3(0, 0.12, 0), bone_dark, Vector3(0, rad_to_deg(-rb.z), 0))
	_skull(root, bone, bone_dark)
	_giant_sword(root)
	_dead_trees(root, rng)


## 땅의 foot에서 위로 솟아 centre 쪽으로 둥글게 굽는 갈비뼈 하나(타원 1/4을 다섯 마디로, 끝은 가운데에 못 미친다).
static func _rib(root: Node3D, foot: Vector3, centre: Vector3, h: float, mat: Material) -> void:
	var inward: Vector3 = (centre - foot)
	inward.y = 0.0
	var half: float = inward.length()
	inward = inward.normalized()
	var pts: Array[Vector3] = []
	for k in 6:
		var th: float = deg_to_rad(72.0) * k / 5.0
		pts.append(foot + inward * half * (1.0 - cos(th)) + Vector3(0, h * sin(th), 0))
	for i in 5:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var mid: Vector3 = (a + b) * 0.5
		var len: float = a.distance_to(b)
		var t := 1.0 - 0.14 * i
		var mi := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(t, len + 0.3, t * 0.8)
		mi.mesh = bx
		mi.material_override = mat
		var up: Vector3 = (b - a).normalized()
		var x_axis: Vector3 = up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
		var z_axis: Vector3 = x_axis.cross(up).normalized()
		mi.transform = Transform3D(Basis(x_axis, up, z_axis), mid)
		mi.visibility_range_end = 200.0
		root.add_child(mi)


static func _skull(root: Node3D, bone: Material, dark: Material) -> void:
	var o := _m(PastLayout.SKULL_AT)
	var g := Node3D.new()
	g.position = o
	g.rotation_degrees = Vector3(0, 200, -8)
	root.add_child(g)
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 14
	ball.rings = 8
	var cap := PastBuilder._put(g, ball, bone, Vector3(0, 3.2, 0))
	cap.scale = Vector3(7.0, 5.0, 8.0)
	PastBuilder._box(g, Vector3(9.0, 2.6, 6.0), Vector3(0, 1.0, -5.0), bone, Vector3(12, 0, 0))   # 위턱
	PastBuilder._box(g, Vector3(8.0, 1.2, 5.0), Vector3(0.4, 0.3, -6.4), dark, Vector3(-6, 6, 0))   # 아래턱(묻힘)
	for sx in [-1.0, 1.0]:
		var hole := PastBuilder._put(g, ball, PastBuilder._plain("socket", Color(0.03, 0.025, 0.02), 1.0), Vector3(2.4 * sx, 3.8, -6.2))
		hole.scale = Vector3(1.4, 1.2, 0.8)
		PastBuilder._box(g, Vector3(1.0, 6.0, 1.0), Vector3(5.2 * sx, 7.0, 0.5), bone, Vector3(-25, 0, -35.0 * sx))   # 뿔
		PastBuilder._box(g, Vector3(0.7, 3.6, 0.7), Vector3(7.6 * sx, 10.4, 1.6), bone, Vector3(-40, 0, -60.0 * sx))
	for k in 5:   # 이빨
		PastBuilder._box(g, Vector3(0.5, 1.4, 0.5), Vector3(-2.4 + k * 1.2, -0.1, -7.6), bone)


## 거인을 쓰러뜨린 첫 검: 비스듬히 꽂혀 부러진 큰 칼(녹과 금빛 손잡이).
static func _giant_sword(root: Node3D) -> void:
	var o := _m(PastLayout.GIANT_SWORD_AT)
	var g := Node3D.new()
	g.position = o
	g.rotation_degrees = Vector3(14, 35, -10)
	root.add_child(g)
	var iron := PastBuilder._plain("giant_iron", Color(0.3, 0.24, 0.2), 0.55)
	iron.metallic = 0.7
	var gold := PastBuilder._plain("giant_gold", PastLayout.GOLD.darkened(0.3), 0.4)
	gold.metallic = 0.9
	PastBuilder._box(g, Vector3(2.6, 11.0, 0.5), Vector3(0, 4.5, 0), iron)
	PastBuilder._box(g, Vector3(0.5, 11.0, 0.6), Vector3(0, 4.5, 0), PastBuilder._plain("giant_fuller", Color(0.18, 0.15, 0.13), 0.6))
	PastBuilder._box(g, Vector3(7.0, 0.9, 1.1), Vector3(0, 10.4, 0), gold)
	PastBuilder._box(g, Vector3(0.9, 4.0, 0.9), Vector3(0, 12.8, 0), PastBuilder._plain("giant_grip", Color(0.16, 0.1, 0.06), 0.9))
	PastBuilder._box(g, Vector3(1.6, 1.6, 1.6), Vector3(0, 15.4, 0), gold, Vector3(0, 45, 45))
	# 부러져 떨어진 칼끝
	PastBuilder._box(root, Vector3(2.4, 0.5, 5.0), o + Vector3(6.0, 0.25, 4.0), iron, Vector3(0, 40, 6))


static func _dead_trees(root: Node3D, rng: RandomNumberGenerator) -> void:
	for t in PastLayout.DEAD_TREES:
		dead_tree(root, _m(Vector2(t.x, t.y)), rng)
	# 쓰러진 통나무 몇(받은 모델, 낮아서 막힘 없음): 뼈 들 가장자리
	var parts: Array[Dictionary] = HillBuilder._parts("dead_tree_trunk_02")
	for at in [Vector2(88, 24), Vector2(176, 24), Vector2(120, 48)]:
		for part in parts:
			var sz: Vector3 = part.size
			var s: float = 5.0 / maxf(maxf(sz.x, sz.z), 0.1)
			var mi := MeshInstance3D.new()
			mi.mesh = part.mesh
			mi.material_override = part.mat
			mi.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * s), _m(at)) * (part.xf as Transform3D)
			mi.visibility_range_end = 160.0
			root.add_child(mi)


## 잎 없는 마른 나무: 기운 줄기와 위로 뻗은 가지 몇.
static func dead_tree(root: Node3D, o: Vector3, rng: RandomNumberGenerator) -> void:
	var bark := PastBuilder._plain("dead_bark", Color(0.19, 0.16, 0.13), 1.0)
	var g := Node3D.new()
	g.position = o
	g.rotation = Vector3(rng.randf_range(-0.08, 0.08), rng.randf() * TAU, rng.randf_range(-0.08, 0.08))
	root.add_child(g)
	var h: float = rng.randf_range(6.0, 10.0)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.12
	trunk.bottom_radius = 0.55
	trunk.height = h
	trunk.radial_segments = 6
	PastBuilder._put(g, trunk, bark, Vector3(0, h * 0.5, 0), Vector3.ZERO, 200.0)
	for k in 4:
		var y: float = h * rng.randf_range(0.45, 0.85)
		var len: float = rng.randf_range(1.8, 3.6)
		var yaw: float = k * 95.0 + rng.randf_range(-20, 20)
		var br := CylinderMesh.new()
		br.top_radius = 0.04
		br.bottom_radius = 0.16
		br.height = len
		br.radial_segments = 5
		var b := Node3D.new()
		b.position = Vector3(0, y, 0)
		b.rotation_degrees = Vector3(0, yaw, rng.randf_range(35, 60))
		g.add_child(b)
		PastBuilder._put(b, br, bark, Vector3(0, len * 0.5, 0), Vector3.ZERO, 160.0)


# ---------------------------------------------------------------- 수정 호수

static func _lake(root: Node3D, rng: RandomNumberGenerator, fires: Array) -> void:
	var water := PastBuilder._plain("water", Color(0.1, 0.24, 0.3), 0.03, 0.35)
	water.metallic = 0.6
	water.emission = Color(0.12, 0.4, 0.5)
	var shore := PastBuilder._plain("shore", Color(0.42, 0.38, 0.28), 1.0)
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 40
	for l in PastLayout.LAKE:
		var o := _m(Vector2(l.x, l.y))
		var rr: float = l.z * Grid.CELL
		var s := PastBuilder._put(root, disc, shore, o + Vector3(0, 0.02, 0))
		s.scale = Vector3(rr + 2.6, 1.0, rr + 2.6)
	for l in PastLayout.LAKE:
		var o := _m(Vector2(l.x, l.y))
		var rr: float = l.z * Grid.CELL
		var w := PastBuilder._put(root, disc, water, o + Vector3(0, 0.05, 0))
		w.scale = Vector3(rr, 1.0, rr)
	var glow := _glow("crystal", CRYSTAL, 2.6)
	var deep := _glow("crystal_deep", Color(0.55, 0.45, 1.0), 1.8)
	var prism := CylinderMesh.new()
	prism.top_radius = 0.0
	prism.bottom_radius = 0.5
	prism.height = 1.0
	prism.radial_segments = 6
	for c in PastLayout.CRYSTALS:
		var o := _m(Vector2(c.x, c.y))
		var n: int = 4 + rng.randi() % 3
		for k in n:
			var h: float = rng.randf_range(3.5, 8.5) * c.z
			var off := Vector3(rng.randf_range(-1.4, 1.4), 0, rng.randf_range(-1.4, 1.4)) * c.z
			var mi := PastBuilder._put(root, prism, glow if k % 2 == 0 else deep, o + off + Vector3(0, h * 0.45, 0), Vector3(rng.randf_range(-18, 18), rng.randf() * 360.0, rng.randf_range(-18, 18)))
			mi.scale = Vector3(c.z * 2.4, h, c.z * 2.4)
		var l := OmniLight3D.new()
		l.light_color = CRYSTAL
		l.light_energy = 1.2
		l.omni_range = 9.0
		l.position = o + Vector3(0, 2.5, 0)
		root.add_child(l)
		fires.append({"light": l, "phase": float(c.x) * 0.1})


# ---------------------------------------------------------------- 잿불 능선

static func _ash(root: Node3D, rng: RandomNumberGenerator, fires: Array) -> void:
	var ash := PastBuilder._plain("ash", ASH, 1.0)
	var ember := _glow("ember", EMBER, 2.6)
	ember.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 12
	var r: Rect2 = PastLayout.REGIONS[2].rect
	for i in 46:   # 재 덮인 땅
		var p := Vector2(rng.randf_range(r.position.x + 2.0, r.end.x - 2.0), rng.randf_range(r.position.y + 4.0, r.end.y - 2.0))
		var mi := PastBuilder._put(root, disc, ash, _m(p) + Vector3(0, 0.018, 0), Vector3.ZERO, 120.0)
		mi.scale = Vector3(rng.randf_range(6.0, 13.0), 1.0, rng.randf_range(5.0, 11.0))
	var crack := BoxMesh.new()
	crack.size = Vector3(0.14, 0.03, 1.0)
	var cracks: Array[Transform3D] = []
	for i in 16:   # 용암 금(지그재그 몇 마디, 한 MultiMesh)
		var p := Vector2(rng.randf_range(r.position.x + 4.0, r.end.x - 4.0), rng.randf_range(r.position.y + 6.0, r.end.y - 4.0))
		var a: float = rng.randf() * TAU
		for k in 4:
			var len: float = rng.randf_range(1.2, 3.0)
			var q := p + Vector2.from_angle(a) * len * 0.5
			var bs := Basis(Vector3.UP, -a + PI * 0.5) * Basis.from_scale(Vector3(1.0, 1.0, len * Grid.CELL))
			cracks.append(Transform3D(bs, _m(q) + Vector3(0, 0.03, 0)))
			p += Vector2.from_angle(a) * len
			a += rng.randf_range(-0.9, 0.9)
	PastBuilder._multi(root, crack, cracks, ember)
	# 검은 바위: 받은 바위 모델을 검게(무늬는 남긴다)
	var parts: Array[Dictionary] = HillBuilder._parts("boulder_01")
	var basalt := PastBuilder._plain("basalt", Color(0.12, 0.11, 0.1), 0.9)
	for a in PastLayout.ASH_ROCKS:
		var o := _m(Vector2(a.x, a.y))
		if parts.is_empty():
			PastBuilder._box(root, Vector3(a.z * 4.0, a.z * 3.0, a.z * 3.6), o + Vector3(0, a.z, 0), basalt, Vector3(0, rng.randf() * 360.0, 0))
			continue
		for part in parts:
			var sz: Vector3 = part.size
			var s: float = a.z * Grid.CELL * 2.2 / maxf(maxf(sz.x, sz.z), 0.1)
			var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s, s * 1.2, s))
			var mi := MeshInstance3D.new()
			mi.mesh = part.mesh
			var m: Material = part.mat
			if m is StandardMaterial3D:
				var d := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				d.albedo_color = Color(0.22, 0.2, 0.19)
				m = d
			mi.material_override = m
			mi.transform = Transform3D(b, o + Vector3(0, -0.3, 0)) * (part.xf as Transform3D)
			mi.visibility_range_end = 220.0
			root.add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = EMBER
	l.light_energy = 1.0
	l.omni_range = 26.0
	l.position = _m(r.get_center()) + Vector3(0, 6.0, 0)
	root.add_child(l)
	fires.append({"light": l, "phase": 2.1})


# ---------------------------------------------------------------- 잿불 능선: 흑룡의 불이 떨어진 자리

static func _fire_scar(root: Node3D, fires: Array) -> void:
	var o := _m(PastLayout.FIRE_SCAR)
	var char_m := PastBuilder._plain("char", Color(0.05, 0.045, 0.04), 1.0)
	var ember := _glow("ember", EMBER, 2.6)
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 24
	var d := PastBuilder._put(root, disc, char_m, o + Vector3(0, 0.025, 0))
	d.scale = Vector3(9.0, 1.0, 9.0)
	for k in 12:   # 가운데서 뻗는 불 금
		var a: float = TAU * k / 12.0 + 0.2
		var len: float = 5.0 + (k % 3) * 2.0
		PastBuilder._box(root, Vector3(0.18, 0.03, len), o + Vector3(cos(a), 0, sin(a)) * len * 0.5 + Vector3(0, 0.04, 0), ember, Vector3(0, rad_to_deg(-a) + 90.0, 0))
	# 땅에 꽂힌 흑룡의 비늘 한 장(검은 육각 판, 가장자리 잿불)
	var scale_m := PastBuilder._plain("dragon_scale", Color(0.08, 0.07, 0.08), 0.35)
	scale_m.metallic = 0.5
	var hexm := CylinderMesh.new()
	hexm.top_radius = 2.2
	hexm.bottom_radius = 2.2
	hexm.height = 0.4
	hexm.radial_segments = 6
	PastBuilder._put(root, hexm, scale_m, o + Vector3(0, 1.6, 0), Vector3(70, 20, 0))
	var rim := CylinderMesh.new()
	rim.top_radius = 2.35
	rim.bottom_radius = 2.35
	rim.height = 0.12
	rim.radial_segments = 6
	PastBuilder._put(root, rim, ember, o + Vector3(0, 1.6, 0), Vector3(70, 20, 0))
	var l := OmniLight3D.new()
	l.light_color = EMBER
	l.light_energy = 1.4
	l.omni_range = 12.0
	l.position = o + Vector3(0, 2.0, 0)
	root.add_child(l)
	fires.append({"light": l, "phase": 0.4})


# ---------------------------------------------------------------- 용의 산맥

const SLATE: Color = Color(0.2, 0.2, 0.24)


static func _dragon_realm(root: Node3D, rng: RandomNumberGenerator, fires: Array) -> void:
	var slate := PastBuilder._plain("slate", SLATE, 1.0)
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 12
	var r: Rect2 = PastLayout.REGIONS[3].rect
	for i in 40:   # 잿빛 바위땅
		var p := Vector2(rng.randf_range(r.position.x + 3.0, r.end.x - 2.0), rng.randf_range(r.position.y + 2.0, r.end.y - 2.0))
		var mi := PastBuilder._put(root, disc, slate, _m(p) + Vector3(0, 0.017, 0), Vector3.ZERO, 120.0)
		mi.scale = Vector3(rng.randf_range(6.0, 13.0), 1.0, rng.randf_range(5.0, 11.0))
	# 서쪽 벼랑: 받은 바위 모델을 잿빛으로 겹쳐 쌓는다(막힘 PastLayout.crags와 같은 자리)
	var parts: Array[Dictionary] = HillBuilder._parts("boulder_01")
	for c in PastLayout.crags():
		var o := _m(Vector2(c.x, c.y))
		for layer in 2:
			if parts.is_empty():
				PastBuilder._box(root, Vector3(c.z * 4.0, c.z * 3.0, c.z * 4.0), o + Vector3(0, c.z * 1.5 + layer * c.z * 2.0, 0), slate, Vector3(0, rng.randf() * 360.0, 0))
				continue
			for part in parts:
				var sz: Vector3 = part.size
				var k: float = c.z * Grid.CELL * (2.4 - layer * 0.8) / maxf(maxf(sz.x, sz.z), 0.1)
				var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(k, k * (1.6 + layer * 0.6), k))
				var mi := MeshInstance3D.new()
				mi.mesh = part.mesh
				var m: Material = part.mat
				if m is StandardMaterial3D:
					var dm := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
					dm.albedo_color = Color(0.5, 0.5, 0.58)
					m = dm
				mi.material_override = m
				mi.transform = Transform3D(b, o + Vector3(0, -0.4 + layer * c.z * 2.6, 0)) * (part.xf as Transform3D)
				mi.visibility_range_end = 260.0
				root.add_child(mi)
	_dragon_skull(root)
	_nest(root, rng, fires)


## 용 이빨 바위: 아래가 굵고 위로 휘어 가는 잿빛 바위(세 마디).
static func dragon_tooth(root: Node3D, o: Vector3, r: float, rng: RandomNumberGenerator) -> void:
	var rock := PastBuilder._plain("tooth_rock", Color(0.3, 0.29, 0.34), 0.95)
	var yaw: float = rng.randf() * TAU
	var lean := Vector3(cos(yaw), 0, sin(yaw))
	var h: float = rng.randf_range(7.0, 15.0)
	var base: float = r * Grid.CELL * 0.75
	var at := o
	for k in 3:
		var seg := CylinderMesh.new()
		seg.bottom_radius = base * (1.0 - k * 0.3)
		seg.top_radius = base * (1.0 - (k + 1) * 0.3) + 0.15
		seg.height = h / 3.0 + 0.4
		seg.radial_segments = 5
		var tilt: float = 6.0 + k * 10.0
		var mi := PastBuilder._put(root, seg, rock, at + Vector3(0, h / 6.0, 0), Vector3(0, rad_to_deg(yaw), 0), 240.0)
		mi.rotation = Basis(Vector3.UP, yaw).rotated(lean.cross(Vector3.UP).normalized(), deg_to_rad(-tilt)).get_euler()
		at += Vector3(0, h / 3.0, 0) + lean * (h / 3.0) * sin(deg_to_rad(tilt))


static func _dragon_skull(root: Node3D) -> void:
	var bone := PastBuilder._plain("bone", BONE, 0.85)
	var dark := PastBuilder._plain("bone_dark", BONE.darkened(0.35), 0.9)
	var g := Node3D.new()
	g.position = _m(PastLayout.DRAGON_SKULL_AT)
	g.rotation_degrees = Vector3(0, 140, -6)
	root.add_child(g)
	PastBuilder._box(g, Vector3(4.6, 3.4, 5.0), Vector3(0, 1.6, 1.2), bone)   # 머리뼈
	PastBuilder._box(g, Vector3(3.0, 1.8, 6.5), Vector3(0, 1.0, -4.2), bone, Vector3(-6, 0, 0))   # 긴 주둥이
	PastBuilder._box(g, Vector3(2.6, 0.9, 6.0), Vector3(0.4, 0.2, -3.6), dark, Vector3(8, 4, 0))   # 아래턱
	for sx in [-1.0, 1.0]:
		PastBuilder._box(g, Vector3(1.0, 1.0, 1.4), Vector3(1.8 * sx, 2.4, -0.6), PastBuilder._plain("socket", Color(0.03, 0.025, 0.02), 1.0))
		PastBuilder._box(g, Vector3(0.7, 0.7, 6.0), Vector3(1.6 * sx, 3.6, 4.4), bone, Vector3(28, 14.0 * sx, 0))   # 뒤로 휜 뿔
		PastBuilder._box(g, Vector3(0.45, 0.45, 3.4), Vector3(2.2 * sx, 5.6, 8.6), bone, Vector3(58, 20.0 * sx, 0))
	for k in 6:   # 이빨
		PastBuilder._box(g, Vector3(0.35, 1.1, 0.35), Vector3(-1.1 + (k % 2) * 2.2, 0.0, -2.0 - (k / 2) * 2.0), bone)


## 용의 둥지: 낮은 둥근 테(뼈와 통나무), 알 셋(용암 금), 보물 더미(hoard_pile).
static func _nest(root: Node3D, rng: RandomNumberGenerator, fires: Array) -> void:
	var o := _m(PastLayout.NEST_AT)
	var bark := PastBuilder._plain("dead_bark", Color(0.19, 0.16, 0.13), 1.0)
	var bone := PastBuilder._plain("bone", BONE, 0.85)
	var n: int = 22
	for k in n:   # 테: 둘레로 비스듬히 쌓인 통나무와 뼈(낮아서 막힘 없음)
		var a: float = TAU * k / n
		var rr: float = PastLayout.NEST_R * Grid.CELL + rng.randf_range(-0.6, 0.6)
		var at := o + Vector3(cos(a), 0, sin(a)) * rr
		PastBuilder._box(root, Vector3(0.5, 0.5, rng.randf_range(3.0, 4.5)), at + Vector3(0, 0.3, 0), bark if k % 3 else bone, Vector3(rng.randf_range(-10, 10), rad_to_deg(-a), rng.randf_range(-12, 12)))
	var shell := PastBuilder._plain("egg", Color(0.16, 0.13, 0.14), 0.4)
	var ember := _glow("ember", EMBER, 2.6)
	var egg := SphereMesh.new()
	egg.radius = 1.0
	egg.height = 2.0
	egg.radial_segments = 14
	egg.rings = 8
	for e in PastLayout.eggs():
		var c := _m(e)
		var mi := PastBuilder._put(root, egg, shell, c + Vector3(0, 1.3, 0), Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12)))
		mi.scale = Vector3(1.3, 1.8, 1.3)
		for k in 3:   # 알 껍질의 잿불 금
			PastBuilder._box(root, Vector3(0.06, 1.6, 0.06), c + Vector3(0, 1.3, 0) + Vector3(cos(k * 2.1), 0, sin(k * 2.1)) * 1.28, ember, Vector3(0, rad_to_deg(-k * 2.1), 14.0 - k * 9.0))
	var l := OmniLight3D.new()
	l.light_color = EMBER
	l.light_energy = 1.3
	l.omni_range = 14.0
	l.position = o + Vector3(0, 3.0, 0)
	root.add_child(l)
	fires.append({"light": l, "phase": 2.7})


## 보물 더미: 금화 무더기와 작은 상자, 금빛 빛. taken이면 무더기가 거의 비었다.
static func hoard_pile(root: Node3D, at: Vector3, taken: bool) -> Node3D:
	var g := Node3D.new()
	g.name = "Hoard"
	g.position = at
	root.add_child(g)
	var gold := PastBuilder._plain("hoard_gold", PastLayout.GOLD, 0.3, 0.5)
	gold.metallic = 0.9
	var pile := Node3D.new()
	pile.name = "Pile"
	g.add_child(pile)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.2
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 10
	for k in 5:
		var mi := PastBuilder._put(pile, cone, gold, Vector3(cos(k * 1.3) * 0.9, 0.35, sin(k * 1.3) * 0.7))
		mi.scale = Vector3(1.2 - k * 0.12, 0.7 - k * 0.06, 1.2 - k * 0.12)
	var chest := PastBuilder._plain("hoard_chest", Color(0.3, 0.18, 0.1), 0.8)
	PastBuilder._box(pile, Vector3(1.0, 0.6, 0.7), Vector3(-1.4, 0.3, 0.6), chest, Vector3(0, 25, 0))
	PastBuilder._box(pile, Vector3(1.04, 0.1, 0.74), Vector3(-1.4, 0.45, 0.6), gold, Vector3(0, 25, 0))
	var l := OmniLight3D.new()
	l.name = "Light"
	l.light_color = PastLayout.GOLD
	l.light_energy = 0.9
	l.omni_range = 6.0
	l.position = Vector3(0, 1.4, 0)
	g.add_child(l)
	set_taken(g, taken)
	return g


static func set_taken(hoard: Node3D, taken: bool) -> void:
	(hoard.get_node("Pile") as Node3D).scale = Vector3(1.0, 0.25, 1.0) if taken else Vector3.ONE
	(hoard.get_node("Light") as OmniLight3D).visible = not taken


## 하늘을 도는 용(꾸밈): 몸·목·머리·꼬리와 날개 둘(WingL·WingR, past.gd가 퍼덕이고 원을 그리게 옮긴다). 날개폭 약 14m × size.
static func sky_dragon(root: Node3D, size: float) -> Node3D:
	var g := Node3D.new()
	g.scale = Vector3.ONE * size
	root.add_child(g)
	var m := PastBuilder._plain("sky_dragon", Color(0.1, 0.09, 0.11), 0.7)
	var wm := PastBuilder._plain("sky_dragon_wing", Color(0.14, 0.11, 0.12), 0.9)
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	PastBuilder._box(g, Vector3(1.4, 1.2, 4.2), Vector3.ZERO, m)
	PastBuilder._box(g, Vector3(0.7, 0.7, 2.6), Vector3(0, 0.4, -3.0), m, Vector3(-12, 0, 0))
	PastBuilder._box(g, Vector3(0.8, 0.6, 1.4), Vector3(0, 0.7, -4.6), m)
	for k in 4:
		PastBuilder._box(g, Vector3(0.7 - k * 0.15, 0.5 - k * 0.1, 1.8), Vector3(0, -0.1 * k, 2.8 + k * 1.6), m, Vector3(4.0 * k, 0, 0))
	for sx in [-1.0, 1.0]:
		var w := Node3D.new()
		w.name = "WingL" if sx < 0.0 else "WingR"
		w.position = Vector3(0.6 * sx, 0.3, -0.6)
		g.add_child(w)
		PastBuilder._box(w, Vector3(6.5, 0.08, 3.2), Vector3(3.3 * sx, 0, 0.6), wm)
		PastBuilder._box(w, Vector3(3.2, 0.08, 2.0), Vector3(6.4 * sx, 0, 1.4), wm, Vector3(0, 18.0 * sx, 0))
		PastBuilder._box(w, Vector3(6.6, 0.2, 0.25), Vector3(3.3 * sx, 0.05, -0.9), m)
	for mi in g.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return g


# ---------------------------------------------------------------- 하늘배 「첫 닻호」

const HULL: Color = Color(0.22, 0.14, 0.09)
const DECK: Color = Color(0.4, 0.3, 0.2)
const SAIL: Color = Color(0.86, 0.8, 0.66)


## 호수 위에 뜬 하늘배: 배 몸, 선루, 돛대 셋과 돛(닻 무늬), 배 밑의 빛나는 수정 용골, 뱃머리에서 호수의 닻(첫 칼)까지 사슬.
## 돌려주는 것은 배 노드(past.gd가 천천히 띄워 흔든다). 닻 칼은 호수에 따로 서 있다.
static func sky_ship(root: Node3D) -> Node3D:
	var base := _m(PastLayout.SHIP_AT)
	var hull := PastBuilder._plain("ship_hull", HULL, 0.8)
	var deck := PastBuilder._plain("ship_deck", DECK, 0.9)
	var gold := PastBuilder._plain("ship_gold", PastLayout.GOLD.darkened(0.15), 0.4, 0.6)
	gold.metallic = 0.8
	var sail := PastBuilder._plain("ship_sail", SAIL, 1.0)
	sail.cull_mode = BaseMaterial3D.CULL_DISABLED
	var crystal := _glow("crystal", CRYSTAL, 2.6)
	var g := Node3D.new()
	g.name = "Ship"
	g.position = base + Vector3(0, PastLayout.SHIP_HEIGHT, 0)
	g.rotation.y = PastLayout.SHIP_YAW
	root.add_child(g)
	# 배 몸: 넓은 몸통, 좁은 바닥, 뾰족한 뱃머리, 높은 고물
	PastBuilder._box(g, Vector3(5.6, 2.6, 18.0), Vector3(0, 0, 0.5), hull)
	PastBuilder._box(g, Vector3(3.6, 1.6, 16.0), Vector3(0, -1.9, 0.5), hull)
	PastBuilder._box(g, Vector3(1.6, 0.9, 14.0), Vector3(0, -3.0, 0.5), hull)
	for sx in [-1.0, 1.0]:
		PastBuilder._box(g, Vector3(0.5, 2.4, 6.4), Vector3(1.75 * sx, 0.1, -10.4), hull, Vector3(0, 24.0 * sx, 0))
	PastBuilder._box(g, Vector3(0.4, 0.4, 5.0), Vector3(0, 1.6, -14.2), hull, Vector3(-18, 0, 0))   # 뱃머리 장대
	PastBuilder._box(g, Vector3(5.8, 3.0, 5.0), Vector3(0, 2.4, 8.6), hull)   # 고물 선루
	PastBuilder._box(g, Vector3(5.4, 0.2, 17.0), Vector3(0, 1.35, 0.0), deck)
	for sx in [-1.0, 1.0]:   # 금빛 줄(꾸밈 띠)과 난간
		PastBuilder._box(g, Vector3(0.08, 0.16, 18.0), Vector3(2.84 * sx, 0.6, 0.5), gold)
		PastBuilder._box(g, Vector3(0.12, 0.6, 15.0), Vector3(2.7 * sx, 1.7, -0.6), hull)
	for k in 3:   # 고물 창(따뜻한 빛)
		PastBuilder._box(g, Vector3(0.9, 0.7, 0.06), Vector3(-1.6 + k * 1.6, 2.6, 11.12), _glow("ship_window", Color(1.0, 0.75, 0.4), 2.0))
	# 돛대와 돛: 돛마다 위아래 두 장, 가운데 큰 돛에 닻 무늬(글자 아님)
	var masts: Array[Vector2] = [Vector2(-6.0, 12.0), Vector2(0.0, 15.0), Vector2(5.5, 10.0)]
	for mz in masts:
		var pole := CylinderMesh.new()
		pole.top_radius = 0.16
		pole.bottom_radius = 0.26
		pole.height = mz.y
		pole.radial_segments = 6
		PastBuilder._put(g, pole, hull, Vector3(0, 1.4 + mz.y * 0.5, mz.x))
		for k in 2:
			var w: float = 7.0 - k * 1.6
			var h: float = mz.y * 0.32
			var y: float = 1.4 + mz.y * (0.38 + k * 0.36)
			PastBuilder._box(g, Vector3(w + 0.6, 0.18, 0.18), Vector3(0, y + h * 0.5, mz.x), hull)   # 활대
			var sl := PastBuilder._box(g, Vector3(w, h, 0.06), Vector3(0, y, mz.x - 0.35), sail, Vector3(-6, 0, 0))
			sl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var emblem_y: float = 1.4 + 15.0 * 0.38
	PastBuilder._box(g, Vector3(0.22, 2.2, 0.04), Vector3(0, emblem_y + 0.2, -0.42), gold)   # 닻 무늬: 자루
	PastBuilder._box(g, Vector3(1.3, 0.2, 0.04), Vector3(0, emblem_y + 0.9, -0.42), gold)   # 가로대
	for sx in [-1.0, 1.0]:
		PastBuilder._box(g, Vector3(0.9, 0.2, 0.04), Vector3(0.45 * sx, emblem_y - 0.75, -0.42), gold, Vector3(0, 0, 30.0 * sx))   # 갈고리 팔
	# 수정 용골: 배 밑에서 빛나며 배를 띄우는 수정들
	var prism := CylinderMesh.new()
	prism.top_radius = 0.0
	prism.bottom_radius = 0.6
	prism.height = 1.0
	prism.radial_segments = 6
	for k in 5:
		var mi := PastBuilder._put(g, prism, crystal, Vector3(0, -4.0, -5.0 + k * 2.5), Vector3(180, 0, 0))
		mi.scale = Vector3(1.0, 2.2 - absf(k - 2) * 0.4, 1.0)
	var l := OmniLight3D.new()
	l.light_color = CRYSTAL
	l.light_energy = 1.6
	l.omni_range = 16.0
	l.position = Vector3(0, -5.0, 0)
	g.add_child(l)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.75, 0.4)
	lamp.light_energy = 1.0
	lamp.omni_range = 8.0
	lamp.position = Vector3(0, 3.5, 11.5)
	g.add_child(lamp)
	# 닻 사슬: 뱃머리 아래에서 호수의 닻 칼 고리까지(배에 붙어 같이 흔들린다)
	var iron := PastBuilder._plain("chain", Color(0.24, 0.22, 0.2), 0.5)
	iron.metallic = 0.8
	var link := TorusMesh.new()
	link.inner_radius = 0.22
	link.outer_radius = 0.42
	link.rings = 8
	link.ring_segments = 6
	var top := Vector3(0, -1.0, -11.0)
	var ring_world: Vector3 = base + Vector3(0, ANCHOR_RING_Y, 0)
	var bottom: Vector3 = g.transform.affine_inverse() * ring_world
	var links: Array[Transform3D] = []
	var n: int = int(top.distance_to(bottom) / 0.62)
	for k in n:
		var t: float = (k + 0.5) / n
		var q: Vector3 = top.lerp(bottom, t) + Vector3(0, 0, sin(t * PI) * 1.2)
		var dir: Vector3 = (bottom - top).normalized()
		var bs := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD) * Basis(Vector3.FORWARD, PI * 0.5 * (k % 2))
		links.append(Transform3D(bs, q))
	PastBuilder._multi(g, link, links, iron)
	_anchor_sword(root, base)
	return g


const ANCHOR_RING_Y: float = 12.5


## 호수 가운데의 닻: 벼리의 첫 칼. 물에 비스듬히 박힌 큰 칼, 가로대 끝이 닻의 갈고리처럼 휘었고 칼자루 끝에 사슬 고리.
static func _anchor_sword(root: Node3D, base: Vector3) -> void:
	var g := Node3D.new()
	g.position = base
	g.rotation_degrees = Vector3(8, 30, -6)
	root.add_child(g)
	var steel := PastBuilder._plain("anchor_steel", Color(0.62, 0.64, 0.68), 0.25, 0.15)
	steel.metallic = 0.9
	var gold := PastBuilder._plain("ship_gold", PastLayout.GOLD.darkened(0.15), 0.4, 0.6)
	PastBuilder._box(g, Vector3(2.0, 9.0, 0.4), Vector3(0, 3.5, 0), steel)
	PastBuilder._box(g, Vector3(0.3, 9.0, 0.44), Vector3(0, 3.5, 0), _glow("anchor_rune", CRYSTAL, 1.6))
	PastBuilder._box(g, Vector3(6.0, 0.7, 0.8), Vector3(0, 8.3, 0), gold)
	for sx in [-1.0, 1.0]:   # 닻 갈고리처럼 휜 가로대 끝
		PastBuilder._box(g, Vector3(0.6, 1.8, 0.8), Vector3(3.2 * sx, 7.7, 0), gold, Vector3(0, 0, 30.0 * sx))
	PastBuilder._box(g, Vector3(0.7, 3.2, 0.7), Vector3(0, 10.3, 0), PastBuilder._plain("giant_grip", Color(0.16, 0.1, 0.06), 0.9))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.6
	ring.outer_radius = 1.0
	PastBuilder._put(g, ring, gold, Vector3(0, 12.4, 0), Vector3(90, 0, 0))


## 선착장: 물가에서 호수 쪽으로 뻗은 잔교와 기둥, 옆에 매인 작은 배.
static func _dock(root: Node3D) -> void:
	var wood := PastBuilder._plain("dock_wood", Color(0.34, 0.25, 0.17), 1.0)
	var a := _m(PastLayout.DOCK_FROM)
	var b := _m(PastLayout.DOCK_TO)
	var mid := (a + b) * 0.5
	var len: float = a.distance_to(b)
	var yaw: float = rad_to_deg(atan2(b.x - a.x, b.z - a.z))
	PastBuilder._box(root, Vector3(2.6, 0.22, len), mid + Vector3(0, 0.45, 0), wood, Vector3(0, yaw, 0))
	var dir := (b - a).normalized()
	var side := dir.cross(Vector3.UP).normalized()
	var k: float = 0.0
	while k <= len:
		for sx in [-1.0, 1.0]:
			PastBuilder._box(root, Vector3(0.24, 1.6, 0.24), a + dir * k + side * 1.25 * sx + Vector3(0, 0.3, 0), wood)
		k += 2.4
	var boat := Node3D.new()
	boat.position = b - side * 2.6 - dir * 1.5 + Vector3(0, 0.15, 0)
	boat.rotation_degrees = Vector3(0, yaw + 8.0, 2)
	root.add_child(boat)
	var hull := PastBuilder._plain("ship_hull", HULL, 0.8)
	PastBuilder._box(boat, Vector3(1.4, 0.5, 3.6), Vector3(0, 0.2, 0), hull)
	PastBuilder._box(boat, Vector3(1.0, 0.4, 1.0), Vector3(0, 0.15, -2.0), hull, Vector3(0, 45, 0))
	PastBuilder._box(boat, Vector3(1.3, 0.08, 0.3), Vector3(0, 0.45, 0.4), wood)


## 닻의 선장(2026-11-26): 마을 사람과 같은 몸(NpcModel: Quaternius 순찰자, CC0, Universal Animation Library 동작)에
## 머리는 오브젝트헤드 닻(ObjectHead "captain" → "anchor"), 옷은 남색 연미복(NpcModel.COSTUME). 사용자: "머리는 원래처럼 닻으로",
## "원래 오브젝트헤드잖아", "원래랑 맞는 모델을 써야지". 몸 모델이 없으면 도형 선장(머리는 같은 닻).
static func captain(root: Node3D, at: Vector3) -> Node3D:
	var g := Node3D.new()
	g.name = "Captain"
	g.position = at
	root.add_child(g)
	if NpcModel.available():
		var npc := NpcModel.new()
		npc.name = "Model"
		npc.model = "man"
		npc.head = &"captain"
		g.add_child(npc)
		g.set_meta("npc", npc)
		return g
	_captain_shapes(g)
	return g


## 말을 걸면 말하는 동작, 말이 끝나면 다시 서 있기(past.gd가 부른다). 몸 모델이 없으면 아무것도 안 한다.
static func captain_talk(cap: Node3D, talking: bool) -> void:
	var npc: NpcModel = cap.get_meta("npc", null)
	if npc != null:
		npc.play("talk" if talking else "idle")


static func _captain_shapes(g: Node3D) -> void:
	var coat := PastBuilder._plain("cap_coat", Color(0.12, 0.15, 0.3), 0.85)
	var trim := PastBuilder._plain("ship_gold", PastLayout.GOLD.darkened(0.15), 0.4, 0.6)
	var boot := PastBuilder._plain("cap_boot", Color(0.08, 0.06, 0.05), 0.7)
	var skin := PastBuilder._plain("cap_skin", Color(0.78, 0.6, 0.48), 0.8)
	var hair := PastBuilder._plain("cap_hair", Color(0.12, 0.08, 0.06), 0.9)
	var shirt := PastBuilder._plain("cap_shirt", Color(0.86, 0.82, 0.74), 0.9)
	for sx in [-1.0, 1.0]:
		PastBuilder._box(g, Vector3(0.2, 0.62, 0.24), Vector3(0.13 * sx, 0.31, 0), boot)
	var skirt := CylinderMesh.new()
	skirt.top_radius = 0.28
	skirt.bottom_radius = 0.42
	skirt.height = 0.75
	skirt.radial_segments = 10
	PastBuilder._put(g, skirt, coat, Vector3(0, 0.85, 0))   # 외투 자락
	PastBuilder._box(g, Vector3(0.6, 0.62, 0.34), Vector3(0, 1.45, 0), coat)   # 몸통
	PastBuilder._box(g, Vector3(0.22, 0.5, 0.02), Vector3(0, 1.45, -0.18), shirt)
	PastBuilder._box(g, Vector3(0.62, 0.07, 0.36), Vector3(0, 1.2, 0), boot)   # 허리띠
	PastBuilder._box(g, Vector3(0.1, 0.09, 0.02), Vector3(0, 1.2, -0.19), trim)
	for sx in [-1.0, 1.0]:
		PastBuilder._box(g, Vector3(0.04, 1.3, 0.04), Vector3(0.29 * sx, 0.95, -0.17), trim)   # 외투 단
	PastBuilder._box(g, Vector3(0.7, 0.14, 0.38), Vector3(0, 1.78, 0), trim)   # 견장
	PastBuilder._box(g, Vector3(0.16, 0.6, 0.16), Vector3(-0.38, 1.45, 0), coat, Vector3(0, 0, -8))
	PastBuilder._box(g, Vector3(0.16, 0.5, 0.16), Vector3(0.36, 1.55, -0.18), coat, Vector3(-55, 0, 10))   # 망원경 든 팔
	var glass := CylinderMesh.new()
	glass.top_radius = 0.05
	glass.bottom_radius = 0.07
	glass.height = 0.5
	glass.radial_segments = 8
	PastBuilder._put(g, glass, trim, Vector3(0.38, 1.78, -0.46), Vector3(-80, 0, 0))
	PastBuilder._box(g, Vector3(0.05, 0.9, 0.08), Vector3(-0.36, 0.85, 0.12), PastBuilder._plain("anchor_steel", Color(0.62, 0.64, 0.68), 0.25, 0.15), Vector3(18, 0, -6))   # 허리 칼
	var head := ObjectHead.build(&"anchor")   # 머리는 닻(오브젝트헤드)
	head.position = Vector3(0, 1.86, 0)
	head.scale = Vector3.ONE * 1.25
	g.add_child(head)


# ---------------------------------------------------------------- 이야기 자리

## 아홉 돌 고리와 봉인 제단: 돌마다 잿불 무늬 띠, 돌에서 가운데 기둥으로 이어진 사슬. quiet면(짐승을 쓰러뜨림) 불이 식는다.
static func seal_altar(root: Node3D, at: Vector3, quiet: bool) -> Node3D:
	var g := Node3D.new()
	g.name = "Seal"
	root.add_child(g)
	var basalt := PastBuilder._plain("seal_stone", Color(0.14, 0.13, 0.12), 0.9)
	var rune := _glow("seal_rune", EMBER, 2.4)
	var iron := PastBuilder._plain("chain", Color(0.24, 0.22, 0.2), 0.5)
	iron.metallic = 0.8
	var link := TorusMesh.new()
	link.inner_radius = 0.12
	link.outer_radius = 0.22
	link.rings = 8
	link.ring_segments = 6
	var dais := CylinderMesh.new()
	dais.top_radius = 4.0
	dais.bottom_radius = 4.6
	dais.height = 0.5
	dais.radial_segments = 18
	PastBuilder._put(g, dais, basalt, at + Vector3(0, 0.25, 0))
	PastBuilder._box(g, Vector3(1.2, 2.4, 1.2), at + Vector3(0, 1.6, 0), basalt, Vector3(0, 45, 0))
	var core := PastBuilder._box(g, Vector3(0.5, 0.5, 0.5), at + Vector3(0, 3.1, 0), rune, Vector3(45, 45, 0))
	core.name = "Core"
	var runes: Array[MeshInstance3D] = [core]
	var links: Array[Transform3D] = []
	for i in PastLayout.SEAL_STONES:
		var p := _m(PastLayout.seal_stone(i))
		var face: float = rad_to_deg(-TAU * i / PastLayout.SEAL_STONES)
		if i == PastLayout.SEAL_GAP:
			PastBuilder._box(g, Vector3(1.6, 0.6, 1.4), p + Vector3(0, 0.3, 0), basalt, Vector3(8, face, 4))   # 무너진 돌(들어가는 길)
			continue
		PastBuilder._box(g, Vector3(1.6, 5.0, 1.2), p + Vector3(0, 2.4, 0), basalt, Vector3(0, face, 0))
		runes.append(PastBuilder._box(g, Vector3(1.64, 0.18, 1.24), p + Vector3(0, 3.6, 0), rune, Vector3(0, face, 0)))
		runes.append(PastBuilder._box(g, Vector3(0.18, 2.0, 1.24), p + Vector3(0, 2.0, 0), rune, Vector3(0, face, 0)))
		# 사슬: 돌 허리에서 가운데 기둥으로 처지며 이어진다(고리는 한 MultiMesh)
		var a: Vector3 = p + Vector3(0, 2.6, 0)
		var b: Vector3 = at + Vector3(0, 2.0, 0)
		var n: int = 16
		for k in n:
			var t: float = (k + 0.5) / n
			var q: Vector3 = a.lerp(b, t) - Vector3(0, sin(t * PI) * 1.2, 0)
			links.append(Transform3D(Basis.from_euler(Vector3(PI * 0.5 if k % 2 == 0 else 0.0, deg_to_rad(face), 0)), q))
	PastBuilder._multi(g, link, links, iron)
	var l := OmniLight3D.new()
	l.name = "Light"
	l.light_color = EMBER
	l.light_energy = 1.6
	l.omni_range = 16.0
	l.position = at + Vector3(0, 3.5, 0)
	g.add_child(l)
	g.set_meta("runes", runes)
	set_quiet(g, quiet)
	return g


static func set_quiet(seal: Node3D, quiet: bool) -> void:
	var runes: Array = seal.get_meta("runes", [])
	var m := _glow("seal_rune_quiet", Color(0.35, 0.5, 0.7), 0.8) if quiet else _glow("seal_rune", EMBER, 2.4)
	for r in runes:
		(r as MeshInstance3D).material_override = m
	var l := seal.get_node("Light") as OmniLight3D
	l.light_color = Color(0.5, 0.7, 1.0) if quiet else EMBER
	l.light_energy = 0.6 if quiet else 1.6


## 기억의 돌: 무릎 높이 넘는 기운 돌, 금빛 홈 무늬. 안 읽었으면 위에 빛 알갱이가 떠 있다.
static func memory_stone(root: Node3D, at: Vector3, read: bool) -> Node3D:
	var g := Node3D.new()
	g.position = at
	root.add_child(g)
	var stone := PastBuilder._plain("memory_stone", Color(0.3, 0.29, 0.26), 0.9)
	PastBuilder._box(g, Vector3(1.3, 2.2, 0.7), Vector3(0, 1.0, 0), stone, Vector3(-6, 20, 4))
	PastBuilder._box(g, Vector3(1.6, 0.3, 1.0), Vector3(0, 0.1, 0), PastBuilder._plain("moss_stone", Color(0.22, 0.26, 0.14), 1.0))
	var groove := _glow("memory_groove", PastLayout.GOLD, 2.0)
	var marks := Node3D.new()
	marks.name = "Marks"
	marks.rotation_degrees = Vector3(-6, 20, 4)
	g.add_child(marks)
	for k in 4:   # 감긴 홈(글자 아님): 작아지는 네모를 비껴 겹친다
		var s: float = 0.8 - k * 0.17
		PastBuilder._box(marks, Vector3(s, 0.05, 0.02), Vector3(0, 1.0 + s * 0.5, -0.36), groove, Vector3(0, 0, k * 22.0))
		PastBuilder._box(marks, Vector3(0.05, s, 0.02), Vector3(-s * 0.5, 1.0, -0.36), groove, Vector3(0, 0, k * 22.0))
	var orb := SphereMesh.new()
	orb.radius = 0.16
	orb.height = 0.32
	var o := PastBuilder._put(g, orb, _glow("memory_orb", PastLayout.GOLD, 3.0), Vector3(0, 2.8, 0))
	o.name = "Orb"
	var l := OmniLight3D.new()
	l.name = "Light"
	l.light_color = PastLayout.GOLD
	l.light_energy = 0.9
	l.omni_range = 6.0
	l.position = Vector3(0, 2.4, -0.6)
	g.add_child(l)
	set_read(g, read)
	return g


static func set_read(n: Node3D, read: bool) -> void:
	(n.get_node("Orb") as Node3D).visible = not read
	(n.get_node("Light") as OmniLight3D).light_energy = 0.25 if read else 0.9
	for c in (n.get_node("Marks") as Node3D).get_children():
		(c as MeshInstance3D).material_override = _glow("memory_groove_read", PastLayout.GOLD.darkened(0.4), 0.6) if read else _glow("memory_groove", PastLayout.GOLD, 2.0)


## 첫 대장장이의 혼(벼리): 금빛으로 비치는 앞치마 두른 사람과 망치. 위아래로 천천히 떠 있다(past.gd가 흔든다).
static func spirit(root: Node3D, at: Vector3) -> Node3D:
	var g := Node3D.new()
	g.name = "Smith"
	g.position = at
	g.rotation_degrees.y = 200.0
	root.add_child(g)
	var body := Node3D.new()
	body.name = "Body"
	g.add_child(body)
	var m := StandardMaterial3D.new()
	m.albedo_color = SPIRIT
	m.emission_enabled = true
	m.emission = PastLayout.GOLD
	m.emission_energy_multiplier = 1.2
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var apron := m.duplicate() as StandardMaterial3D
	apron.albedo_color = Color(0.9, 0.55, 0.25, 0.55)
	var robe := CylinderMesh.new()
	robe.top_radius = 0.32
	robe.bottom_radius = 0.55
	robe.height = 1.4
	robe.radial_segments = 10
	PastBuilder._put(body, robe, m, Vector3(0, 0.9, 0))
	PastBuilder._box(body, Vector3(0.8, 0.5, 0.42), Vector3(0, 1.75, 0), m)   # 어깨
	PastBuilder._box(body, Vector3(0.5, 1.0, 0.06), Vector3(0, 1.2, -0.33), apron)
	var head := SphereMesh.new()
	head.radius = 0.22
	head.height = 0.46
	PastBuilder._put(body, head, m, Vector3(0, 2.2, 0))
	PastBuilder._box(body, Vector3(0.36, 0.3, 0.12), Vector3(0, 2.02, -0.16), m)   # 수염
	PastBuilder._box(body, Vector3(0.16, 0.7, 0.16), Vector3(0.5, 1.45, -0.1), m, Vector3(0, 0, 10))   # 오른팔
	PastBuilder._box(body, Vector3(0.06, 0.8, 0.06), Vector3(0.58, 1.05, -0.3), apron, Vector3(-60, 0, 0))   # 망치 자루
	PastBuilder._box(body, Vector3(0.18, 0.18, 0.36), Vector3(0.58, 0.92, -0.66), m, Vector3(-60, 0, 0))   # 망치 머리
	PastBuilder._box(body, Vector3(0.16, 0.7, 0.16), Vector3(-0.5, 1.45, 0), m, Vector3(0, 0, -10))
	var l := OmniLight3D.new()
	l.light_color = PastLayout.GOLD
	l.light_energy = 0.7
	l.omni_range = 5.0
	l.position = Vector3(0, 1.6, -0.8)
	g.add_child(l)
	return g
