class_name CryptBuilder
extends RefCounted
## 지하 무덤의 모양(19단계). 기본 도형과 HillBuilder의 바위 질감·바위 조각을 빌린다. 천장 없이 위는 어둡고, 벽은 낮다
## (3인칭 카메라가 걸리지 않게). 모든 자리는 CryptLayout에서 읽는다. 세계에 글자 없음.
## 돌판 문은 내려와 막고(닫힘) 올라가 열린다(open_door/close_door).

const WALL_H: float = 1.5
const WALL_T: float = 0.8
const SLAB_H: float = 3.0
const SLAB_RISE: float = 4.2
const DOOR_TIME: float = 0.9
const TORCH_ENERGY: float = 5.0
const TORCH_RANGE: float = 30.0
const TORCH_COLOR: Color = Color(1.0, 0.62, 0.3)

static var _mats: Dictionary = {}


## 어둡게: 하늘 없이 거의 검은 바탕, 약한 환경빛, 짙은 안개.
static func environment(env: Environment) -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.008, 0.012)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.34, 0.46)
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color(0.015, 0.014, 0.02)
	env.fog_density = 0.012
	env.fog_sky_affect = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.8


## 돌 질감: HillBuilder의 이끼 낀 바위(lichen_rock)를 어둡게 쓴다. 파일이 없으면 색만.
static func stone(tint: float = 0.7) -> StandardMaterial3D:
	var key: String = "stone%.2f" % tint
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(tint, tint * 0.97, tint * 0.94)
	m.roughness = 1.0
	var base: String = HillBuilder.HILL_DIR + "lichen_rock/lichen_rock"
	if ResourceLoader.exists(base + "_diff.jpg"):
		m.albedo_texture = load(base + "_diff.jpg")
		if ResourceLoader.exists(base + "_nor_gl.jpg"):
			m.normal_enabled = true
			m.normal_texture = load(base + "_nor_gl.jpg")
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.35
	_mats[key] = m
	return m


static func _plain(key: String, c: Color, glow: float = 0.0, rough: float = 0.9, metal: float = 0.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	_mats[key] = m
	return m


static func _box(parent: Node3D, size: Vector3, at: Vector3, m: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return VillageBuilder.box(parent, size, at, m, rot)


## 칸 좌표 → 월드(바닥 높이 0).
static func _w(c: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(c.x * Grid.CELL, y, c.y * Grid.CELL)


## 칸 단위 Rect2의 가운데와 크기(m)로 상자를 놓는다.
static func _slab(parent: Node3D, r: Rect2, y: float, h: float, m: Material) -> MeshInstance3D:
	return _box(parent, Vector3(r.size.x * Grid.CELL, h, r.size.y * Grid.CELL), _w(r.get_center(), y), m)


## 지하 무덤 전체를 짓는다. {doors: id → 돌판 Node3D, coffins: id → 관 Node3D, torches: [OmniLight3D], root}를 돌려준다.
static func build(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "CryptBuild"
	parent.add_child(root)
	var st: StandardMaterial3D = stone()
	var dark: StandardMaterial3D = stone(0.5)
	for id in CryptLayout.ROOM_ORDER:
		_slab(root, CryptLayout.ROOMS[id].rect, -0.2, 0.4, st)
	for d in CryptLayout.DOORS:
		_slab(root, CryptLayout.DOORS[d].gap, -0.2, 0.4, dark)
	_walls(root, dark)
	_rubble(root)
	_props(root)
	_exit_arch(root, st)
	var out := {"doors": {}, "coffins": {}, "torches": [], "root": root}
	for d in CryptLayout.DOORS:
		out.doors[d] = _door(root, d)
	for id in CryptLayout.ROOM_ORDER:
		out.coffins[id] = _coffin(root, id)
		for t in _torches(root, id):
			out.torches.append(t)
	return out


# ---------------------------------------------------------------- 벽

## 방 가장자리의 낮은 벽: 문(gap)이 닿은 자리는 비운다. 복도 양옆에도 벽.
static func _walls(root: Node3D, m: Material) -> void:
	for id in CryptLayout.ROOM_ORDER:
		var R: Rect2 = CryptLayout.ROOMS[id].rect
		# 네 변: [시작, 끝, 고정 좌표, 가로(x축 방향)인가, 문 닿는 변인가를 가리는 함수에 쓸 변 이름]
		for side in 4:
			var along_x: bool = side < 2
			var fixed: float
			var lo: float
			var hi: float
			if side == 0:
				fixed = R.position.y
			elif side == 1:
				fixed = R.end.y
			elif side == 2:
				fixed = R.position.x
			else:
				fixed = R.end.x
			lo = R.position.x if along_x else R.position.y
			hi = R.end.x if along_x else R.end.y
			var cuts: Array = []
			for d in CryptLayout.DOORS:
				var G: Rect2 = CryptLayout.DOORS[d].gap
				if not (CryptLayout.DOORS[d].rooms as Array).has(id):
					continue
				if along_x and (is_equal_approx(G.end.y, fixed) or is_equal_approx(G.position.y, fixed)):
					cuts.append([G.position.x, G.end.x])
				elif not along_x and (is_equal_approx(G.end.x, fixed) or is_equal_approx(G.position.x, fixed)):
					cuts.append([G.position.y, G.end.y])
			cuts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
			var at: float = lo
			for c in cuts:
				if c[0] > at:
					_wall(root, along_x, fixed, at, c[0], m)
				at = maxf(at, c[1])
			if hi > at:
				_wall(root, along_x, fixed, at, hi, m)
	# 복도 양옆
	for d in CryptLayout.DOORS:
		var G: Rect2 = CryptLayout.DOORS[d].gap
		var ra: Rect2 = CryptLayout.ROOMS[CryptLayout.DOORS[d].rooms[0]].rect
		var rb: Rect2 = CryptLayout.ROOMS[CryptLayout.DOORS[d].rooms[1]].rect
		var vertical: bool = absf(ra.get_center().y - rb.get_center().y) > absf(ra.get_center().x - rb.get_center().x)
		if vertical:
			_wall(root, false, G.position.x, G.position.y, G.end.y, m)
			_wall(root, false, G.end.x, G.position.y, G.end.y, m)
		else:
			_wall(root, true, G.position.y, G.position.x, G.end.x, m)
			_wall(root, true, G.end.y, G.position.x, G.end.x, m)


static func _wall(root: Node3D, along_x: bool, fixed: float, lo: float, hi: float, m: Material) -> void:
	var len_m: float = (hi - lo) * Grid.CELL + WALL_T
	var mid: float = (lo + hi) / 2.0
	if along_x:
		_box(root, Vector3(len_m, WALL_H, WALL_T), _w(Vector2(mid, fixed), WALL_H / 2.0), m)
	else:
		_box(root, Vector3(WALL_T, WALL_H, len_m), _w(Vector2(fixed, mid), WALL_H / 2.0), m)


## 모서리와 구석의 무너진 돌(HillBuilder의 바위 조각을 빌린다. 없으면 건너뛴다).
static func _rubble(root: Node3D) -> void:
	var parts: Array[Dictionary] = HillBuilder.rock_parts()
	if parts.is_empty():
		return
	var rng := RandomNumberGenerator.new()   # 꾸밈 랜덤(규칙과 무관)
	rng.seed = 19
	for id in CryptLayout.ROOM_ORDER:
		var R: Rect2 = CryptLayout.ROOMS[id].rect
		for k in 5:
			var c := Vector2(R.position.x + (1.5 if k % 2 == 0 else R.size.x - 1.5), R.position.y + (1.5 if k < 2 else R.size.y - 1.5 if k < 4 else R.size.y * 0.5))
			c += Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.8, 0.8))
			var rock := HillBuilder.put_flat(root, parts[rng.randi() % parts.size()], _w(c), rng.randf() * TAU, rng.randf_range(0.35, 0.7), 0.35)
			if rock != null:
				PropKick.tag(rock, 2.2)   # 베기 근처면 화면에서만 튄다(docs/hit_juice.md)


## 방 왼쪽 모서리 둘레에 통·상자·항아리(막힘 아님, 관 가까이는 뺀다). 꾸밈 랜덤은 따로 둔다.
static func _props(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var kinds: Array[StringName] = [&"barrel", &"crate", &"jar", &"jar", &"crate"]
	for id in CryptLayout.ROOM_ORDER:
		var R: Rect2 = CryptLayout.ROOMS[id].rect
		var coffin: Vector2 = CryptLayout.ROOMS[id].coffin
		for k in 3:
			var c := Vector2(R.position.x + 2.6 + rng.randf_range(0.0, 1.0), R.position.y + [2.8, R.size.y * 0.5, R.size.y - 2.8][k] + rng.randf_range(-0.6, 0.6))
			var kind: StringName = kinds[rng.randi() % kinds.size()]
			if c.distance_to(coffin) > 3.5:
				PropKick.make(root, kind, _w(c), rng.randf() * TAU)


## 나가는 문: 남쪽 벽에 돌 틀과 희미한 푸른 빛(밖에서 들어오는 빛).
static func _exit_arch(root: Node3D, m: Material) -> void:
	var at: Vector3 = _w(CryptLayout.EXIT_AT + Vector2(0, 0.6))
	for s in [-1.0, 1.0]:
		_box(root, Vector3(0.9, 3.4, 0.9), at + Vector3(s * 2.6, 1.7, 0), m)
	_box(root, Vector3(6.4, 0.7, 0.9), at + Vector3(0, 3.5, 0), m)
	var glow := _plain("exit_glow", Color(0.35, 0.45, 0.62), 1.4)
	_box(root, Vector3(4.2, 3.0, 0.2), at + Vector3(0, 1.5, 0.15), glow)
	var l := OmniLight3D.new()
	l.light_color = Color(0.5, 0.62, 0.85)
	l.light_energy = 1.0
	l.omni_range = 9.0
	l.position = at + Vector3(0, 2.0, -2.5)
	root.add_child(l)


# ---------------------------------------------------------------- 문

## 돌판 문. 처음에는 올라가 있다(열림). 닫힘은 내려와 복도를 막는다.
static func _door(root: Node3D, id: StringName) -> Node3D:
	var G: Rect2 = CryptLayout.DOORS[id].gap
	var ra: Rect2 = CryptLayout.ROOMS[CryptLayout.DOORS[id].rooms[0]].rect
	var rb: Rect2 = CryptLayout.ROOMS[CryptLayout.DOORS[id].rooms[1]].rect
	var vertical: bool = absf(ra.get_center().y - rb.get_center().y) > absf(ra.get_center().x - rb.get_center().x)
	var n := Node3D.new()
	n.name = "door_%s" % id
	n.position = _w(G.get_center())
	root.add_child(n)
	var size: Vector3 = Vector3(G.size.x * Grid.CELL if vertical else 0.9, SLAB_H, 0.9 if vertical else G.size.y * Grid.CELL)
	var slab := _box(n, size, Vector3(0, SLAB_H / 2.0, 0), stone(0.42))
	slab.name = "Slab"
	# 돌판에 새긴 가로 홈(빛을 받는 줄) 둘
	var groove := _plain("groove", Color(0.04, 0.04, 0.045))
	for y in [0.9, 2.0]:
		var gs: Vector3 = size + Vector3(0.0, 0.0, 0.0)
		gs.y = 0.12
		gs.x = size.x + 0.02 if vertical else size.x + 0.04
		gs.z = size.z + 0.04 if vertical else size.z + 0.02
		_box(n, gs, Vector3(0, y, 0), groove)
	n.set_meta("closed", false)
	n.position.y = SLAB_RISE
	n.visible = false
	return n


## 닫는다(돌판이 내려온다) / 연다(올라가 사라진다). animate가 거짓이면 바로.
static func set_door(n: Node3D, closed: bool, animate: bool = true) -> void:
	if bool(n.get_meta("closed", false)) == closed:
		return
	n.set_meta("closed", closed)
	if n.has_meta("tween"):
		var tw: Tween = n.get_meta("tween") as Tween
		if tw != null and tw.is_valid():
			tw.kill()
	if closed:
		n.visible = true
		if animate:
			var t := n.create_tween()
			t.tween_property(n, "position:y", 0.0, DOOR_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			n.set_meta("tween", t)
		else:
			n.position.y = 0.0
	else:
		if animate:
			var t := n.create_tween()
			t.tween_property(n, "position:y", SLAB_RISE, DOOR_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_callback(func() -> void: n.visible = false)
			n.set_meta("tween", t)
		else:
			n.position.y = SLAB_RISE
			n.visible = false


# ---------------------------------------------------------------- 관

## 돌 관. 마지막 방(big)은 더 크고 가장자리에 희미한 빛 줄이 있다.
static func _coffin(root: Node3D, id: StringName) -> Node3D:
	var R: Dictionary = CryptLayout.ROOMS[id]
	var big: bool = bool(R.get("big", false))
	var k: float = 1.5 if big else 1.0
	var n := Node3D.new()
	n.name = "coffin_%s" % id
	n.position = _w(R.coffin)
	root.add_child(n)
	var st: StandardMaterial3D = stone(0.5)
	_box(n, Vector3(2.6 * k, 0.9, 1.3 * k), Vector3(0, 0.45, 0), st)
	_box(n, Vector3(3.0 * k, 0.25, 1.7 * k), Vector3(0, 0.12, 0), stone(0.4))
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0, 0.95, 0)
	n.add_child(lid)
	_box(lid, Vector3(2.8 * k, 0.28, 1.5 * k), Vector3(0, 0.0, 0), st)
	_box(lid, Vector3(1.9 * k, 0.1, 0.18 * k), Vector3(0, 0.2, 0), stone(0.38))
	_box(lid, Vector3(0.18 * k, 0.1, 0.9 * k), Vector3(0.5 * k, 0.2, 0), stone(0.38))
	if big:
		var trim := _plain("coffin_trim", Color(0.9, 0.62, 0.25), 1.2)
		_box(n, Vector3(3.1 * k, 0.06, 0.08), Vector3(0, 0.3, 0.86 * k), trim)
		_box(n, Vector3(3.1 * k, 0.06, 0.08), Vector3(0, 0.3, -0.86 * k), trim)
	return n


## 연 관: 뚜껑이 밀려 열린다.
static func open_coffin(n: Node3D, animate: bool = true) -> void:
	var lid: Node3D = n.get_node("Lid")
	if animate:
		var t := n.create_tween()
		t.set_parallel(true)
		t.tween_property(lid, "position:x", 1.3, 0.6)
		t.tween_property(lid, "rotation:y", 0.45, 0.6)
	else:
		lid.position.x = 1.3
		lid.rotation.y = 0.45


# ---------------------------------------------------------------- 횃불

## 방마다 둘: 방 가운데 줄의 1/4, 3/4 자리에 선 쇠 화로와 불꽃, 그리고 빛(흔들림은 화면이 한다).
static func _torches(root: Node3D, id: StringName) -> Array[OmniLight3D]:
	var R: Rect2 = CryptLayout.ROOMS[id].rect
	var out: Array[OmniLight3D] = []
	var iron := _plain("iron", Color(0.1, 0.1, 0.11), 0.0, 0.6, 0.6)
	var flame := _plain("flame", Color(1.0, 0.55, 0.18), 3.0)
	for fx in [0.25, 0.75]:
		var c := Vector2(R.position.x + R.size.x * fx, R.position.y + CryptLayout.TORCH_INSET)
		var n := Node3D.new()
		n.position = _w(c)
		root.add_child(n)
		_box(n, Vector3(0.22, 1.5, 0.22), Vector3(0, 0.75, 0), iron)
		var bowl := CylinderMesh.new()
		bowl.top_radius = 0.5
		bowl.bottom_radius = 0.22
		bowl.height = 0.4
		var bm := MeshInstance3D.new()
		bm.mesh = bowl
		bm.material_override = iron
		bm.position = Vector3(0, 1.6, 0)
		n.add_child(bm)
		var fl := SphereMesh.new()
		fl.radius = 0.32
		fl.height = 0.9
		var fm := MeshInstance3D.new()
		fm.mesh = fl
		fm.material_override = flame
		fm.position = Vector3(0, 2.0, 0)
		fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(fm)
		var l := OmniLight3D.new()
		l.light_color = TORCH_COLOR
		l.light_energy = TORCH_ENERGY
		l.omni_range = TORCH_RANGE
		l.omni_attenuation = Juice.TORCH_ATTEN
		l.position = Vector3(0, 2.4, 0)
		l.set_meta("base", TORCH_ENERGY)
		n.add_child(l)
		out.append(l)
	return out
