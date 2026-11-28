class_name CosmeticArt
extends RefCounted
## 영주 꾸미기의 모양(docs/cosmetics.md). 에셋 없이 기본 도형과 코드로 그린 질감만 쓴다. 어두운 사실풍: 낡은 천, 거친 쇠.
## 머리는 머리 반지름 1을 기준으로 짓고(앞 -Z, 위 +Y, 머리 가운데가 원점) 몸에 붙이는 쪽(CosmeticRig)이 크기를 맞춘다.
## 망토는 어깨 가운데가 원점이고 아래(-Y)로 늘어진다(앞 -Z, 등 쪽 +Z).
## 2026-11-27: assets/cosmetics/<항목 id>.glb(tools/blender/make_cosmetics.py)가 있으면 그것을 쓰고, 없으면 아래의 기본 도형과 코드 질감으로 돌아간다.

const CAPE_W: float = 0.62
const CAPE_H: float = 1.0
const TEX_W: int = 96
const TEX_H: int = 128

static var _tex: Dictionary = {}
static var _glb_cache: Dictionary = {}   # id → PackedScene 또는 null(없음)


## Blender로 지은 모양. 없으면 null(기본 도형으로 돌아간다). 같은 크기·방향이라 바로 바꿔 끼운다.
static func glb(id: StringName) -> Node3D:
	var key: String = String(id)
	if not _glb_cache.has(key):
		var path: String = "res://assets/cosmetics/%s.glb" % key
		_glb_cache[key] = load(path) as PackedScene if ResourceLoader.exists(path) else null
	var ps: PackedScene = _glb_cache[key]
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	if n != null:
		n.name = "Glb"
	return n


# ---------------------------------------------------------------- 망토

static func cape_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx: int = 8
	var ny: int = 10
	for j in ny:
		for i in nx:
			var q: Array = [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i, j + 1), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]
			for p in q:
				var u: float = float(p.x) / nx
				var v: float = float(p.y) / ny
				# 주름: 옆으로 물결, 아래로 갈수록 크게. 어깨 줄은 곧다.
				var fold: float = sin(u * TAU * 2.0 + 0.6) * 0.035 * v
				var side: float = (2.0 * u - 1.0) * (2.0 * u - 1.0)
				var wrap: float = -0.13 * side * (0.3 + 0.7 * v)   # 어깨를 감싸 가장자리가 앞으로 휜다
				st.set_uv(Vector2(u, v))
				st.add_vertex(Vector3((u - 0.5) * CAPE_W * (1.0 + 0.5 * v), -v * CAPE_H, fold + wrap))
	st.generate_normals()
	return st.commit()


static func cape_texture(it: CosmeticItem) -> ImageTexture:
	return _cape_image(it, false)


static func _cape_image(it: CosmeticItem, glow: bool) -> ImageTexture:
	var key: String = "%s%s" % [it.id, "g" if glow else ""]
	if _tex.has(key):
		return _tex[key]
	var img := Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGBA8)
	var base: Color = it.color
	var acc: Color = it.color2
	for y in TEX_H:
		var v: float = float(y) / TEX_H
		for x in TEX_W:
			var u: float = float(x) / TEX_W
			var shade: float = 1.0 + 0.1 * sin(u * TAU * 2.0 + 0.6) - 0.16 * v
			var c: Color = base
			var a: float = 1.0
			var g: float = 0.0   # 빛나는 부분
			match String(it.style):
				"trim":
					if v > 0.9 or u < 0.04 or u > 0.96:
						c = acc
				"stripe":
					if fmod(u * 5.0, 1.0) < 0.28:
						c = acc
				"check":
					if (int(u * 6.0) + int(v * 8.0)) % 2 == 0:
						c = acc
				"emblem":
					c = _emblem(base, acc, u, v)
				"ragged":
					var edge: float = 0.9 + 0.07 * sin(u * 31.0) + 0.05 * sin(u * 13.0 + 1.3) - 0.04 * fmod(u * 9.0, 1.0)
					if v > edge:
						a = 0.0
					elif v > edge - 0.07:
						c = acc
				"rune":
					g = _rune_glyph(x, y)
					if g > 0.0:
						c = base.lerp(acc, 0.6)
					if v > 0.93:
						c = acc.darkened(0.5)
			# 짠 천의 결: 아주 가는 가로줄 잡음
			var grain: float = 0.97 + 0.03 * sin(float(y) * 2.1 + float(x) * 0.4)
			var out := Color(c.r * shade * grain, c.g * shade * grain, c.b * shade * grain, a)
			if glow:
				out = Color(acc.r * g, acc.g * g, acc.b * g, 1.0)
			img.set_pixel(x, y, out)
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t


## 검 문장: 가운데 세운 칼과 가로 날밑, 아래 가장자리 가는 줄.
static func _emblem(base: Color, acc: Color, u: float, v: float) -> Color:
	if v > 0.94 or u < 0.03 or u > 0.97:
		return acc.darkened(0.25)
	var cx: float = absf(u - 0.5)
	if cx < 0.025 and v > 0.28 and v < 0.66:
		return acc                        # 칼날
	if cx < 0.13 and v > 0.66 and v < 0.7:
		return acc                        # 날밑
	if cx < 0.025 and v >= 0.7 and v < 0.8:
		return acc.darkened(0.2)          # 손잡이
	if cx < 0.04 and v >= 0.8 and v < 0.84:
		return acc.darkened(0.2)          # 꼭지
	return base


## 룬 자수: 12칸 격자에 종류가 다른 작은 글자 모양 몇 개. 있으면 1, 없으면 0.
static func _rune_glyph(x: int, y: int) -> float:
	var cw: int = 16
	var cx: int = x / cw
	var cy: int = y / cw
	if cy % 2 != 0 or cy < 1 or cy > 6 or cx < 1 or cx > 4:
		return 0.0
	var lx: int = x % cw - 8
	var ly: int = y % cw - 8
	var kind: int = (cx * 7 + cy * 3) % 4
	match kind:
		0:
			return 1.0 if (absi(lx) <= 1 and absi(ly) <= 5) or (absi(ly) <= 1 and absi(lx) <= 3) else 0.0
		1:
			return 1.0 if absi(lx + ly) <= 1 and absi(ly) <= 5 or absi(lx) <= 1 and ly > 1 and ly <= 5 else 0.0
		2:
			return 1.0 if (absi(absi(lx) + absi(ly) - 5) <= 1) else 0.0
		_:
			return 1.0 if (absi(ly) <= 1 and absi(lx) <= 5) or (absi(lx) <= 1 and ly <= 0 and ly >= -5) else 0.0


## 망토 재질. 가려진 안쪽도 보이게 양면, 해진 끝은 알파로 오린다. 룬 망토는 글자가 은은히 빛난다.
static func cape_material(it: CosmeticItem) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = cape_texture(it)
	m.roughness = 0.95
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if it.style == &"ragged":
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
	if it.style == &"rune":
		m.emission_enabled = true
		m.emission_texture = _cape_image(it, true)
		m.emission_energy_multiplier = 0.55
	return m


## Blender 망토 안의 뼈대(CapeBone0~2). 없으면 null(기본 도형 망토).
static func cape_skeleton(pivot: Node) -> Skeleton3D:
	if pivot == null:
		return null
	var sk := pivot.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null or sk.find_bone("CapeBone0") < 0:
		return null
	return sk


## 뼈 마디를 X축으로 굽힌다. total은 맨 아래 마디의 누적 각도(음수 = 뒤로), 위 마디는 조금만.
static func sway(sk: Skeleton3D, total: float) -> void:
	var share: Array[float] = [0.1, 0.35, 0.55]
	var acc: float = 0.0
	for k in 3:
		var b: int = sk.find_bone("CapeBone%d" % k)
		if b < 0:
			return
		var par: int = sk.get_bone_parent(b)
		var pg: Basis = sk.get_bone_global_rest(par).basis if par >= 0 else Basis.IDENTITY
		var g: Basis = sk.get_bone_global_rest(b).basis
		var step: float = total * share[k]
		sk.set_bone_pose_rotation(b, (pg.inverse() * Basis(Vector3.RIGHT, step) * g).get_rotation_quaternion())
		acc += step


## 망토 노드 한 벌: 어깨에서 늘어지는 면. 돌려주는 노드 원점이 어깨 가운데(흔들 때 축).
static func cape(it: CosmeticItem) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "CosCapePivot"
	var g: Node3D = glb(it.id)
	if g != null:
		pivot.add_child(g)
		return pivot
	var mi := MeshInstance3D.new()
	mi.mesh = cape_mesh()
	mi.material_override = cape_material(it)
	mi.name = "Cape"
	pivot.add_child(mi)
	return pivot


# ---------------------------------------------------------------- 머리

static func _std(c: Color, metal: float = 0.0, rough: float = 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


static func _glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := _std(c.darkened(0.3), 0.0, 0.5)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


static func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func _sphere(r: float, half: bool = false) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * (1.0 if half else 2.0)
	s.is_hemisphere = half
	s.radial_segments = 20
	s.rings = 10
	return s


static func _cyl(top: float, bottom: float, h: float, seg: int = 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


static func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


static func _ring(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 24
	t.ring_segments = 8
	return t


## 머리 꾸미기 한 벌. style이 none이면 빈 노드.
static func head(it: CosmeticItem) -> Node3D:
	var root := Node3D.new()
	root.name = "CosHead"
	var g: Node3D = glb(it.id)
	if g != null:
		root.add_child(g)
		return root
	var iron: StandardMaterial3D = _std(it.color, 0.75, 0.42)
	var cloth: StandardMaterial3D = _std(it.color, 0.0, 0.95)
	var trim: StandardMaterial3D = _std(it.color2, 0.4, 0.6)
	match String(it.style):
		"band":
			_add(root, _ring(0.93, 1.07), cloth, Vector3(0, 0.34, 0), Vector3.ZERO, Vector3(1, 1.5, 1))
			_add(root, _box(0.5, 0.22, 0.04), cloth, Vector3(0.0, 0.32, 1.02), Vector3(0, 0, 8))   # 뒤로 묶은 매듭
		"hood":
			_add(root, _sphere(1.2), cloth, Vector3(0, 0.1, 0.3), Vector3.ZERO, Vector3(1.0, 1.05, 1.0))
			_add(root, _cyl(0.0, 0.5, 0.9, 10), trim_cloth(it), Vector3(0, 0.95, 1.05), Vector3(-65, 0, 0))   # 뒤로 처진 끝
			_add(root, _cyl(0.95, 1.15, 0.5, 18), cloth, Vector3(0, -0.95, 0.25))                              # 어깨로 내려오는 깃
		"kettle":
			_add(root, _sphere(1.08, true), iron, Vector3(0, 0.28, 0))
			_add(root, _cyl(1.95, 1.95, 0.07, 28), iron, Vector3(0, 0.3, 0))
			_add(root, _ring(1.0, 1.1), trim, Vector3(0, 0.34, 0), Vector3.ZERO, Vector3(1, 2.0, 1))
		"helm", "plume", "horn":
			_add(root, _sphere(1.1, true), iron, Vector3(0, 0.1, 0))
			_add(root, _ring(1.0, 1.14), trim, Vector3(0, 0.1, 0), Vector3.ZERO, Vector3(1, 1.4, 1))                   # 아래 테
			_add(root, _box(0.2, 0.95, 0.08), iron, Vector3(0, -0.28, -1.06))                                           # 코가리개
			for k in [-1.0, 1.0]:
				_add(root, _box(0.08, 0.7, 0.62), iron, Vector3(k * 1.04, -0.22, -0.18))                                 # 볼가리개
			if it.style == &"plume":
				_add(root, _box(0.12, 0.5, 1.7), _std(it.color2, 0.0, 0.9), Vector3(0, 1.15, 0.1))                       # 투구 꼬리
			if it.style == &"horn":
				for k in [-1.0, 1.0]:
					_add(root, _cyl(0.2, 0.36, 0.95, 10), trim, Vector3(k * 1.25, 0.65, 0), Vector3(0, 0, -k * 50))
					_add(root, _cyl(0.04, 0.2, 0.95, 10), trim, Vector3(k * 2.05, 1.2, 0), Vector3(0, 0, -k * 15))
		"circlet":
			_add(root, _ring(0.98, 1.08), iron, Vector3(0, 0.48, 0), Vector3.ZERO, Vector3(1, 1.6, 1))
			_add(root, _box(0.2, 0.2, 0.1), _glow(it.color2, 1.1), Vector3(0, 0.5, -1.06), Vector3(0, 0, 45))
		"spikes":
			_add(root, _ring(0.98, 1.08), iron, Vector3(0, 0.46, 0), Vector3.ZERO, Vector3(1, 1.6, 1))
			for i in 7:
				var a: float = TAU * i / 7.0 + 0.2
				var h: float = 0.55 + 0.25 * float(i % 3)
				_add(root, _cyl(0.0, 0.13, h, 8), iron, Vector3(sin(a) * 1.02, 0.46 + h / 2.0, cos(a) * 1.02), Vector3(cos(a) * -10, 0, sin(a) * 10))
		"visor":
			_add(root, _box(2.0, 0.34, 0.3), _std(it.color, 0.6, 0.4), Vector3(0, 0.05, -0.82), Vector3.ZERO)
			_add(root, _box(1.8, 0.1, 0.06), _glow(it.color2, 2.4), Vector3(0, 0.05, -0.99))
			for k in [-1.0, 1.0]:
				_add(root, _box(0.08, 0.16, 1.7), _std(it.color, 0.6, 0.4), Vector3(k * 1.0, 0.05, 0.0))
		"runeband":
			_add(root, _ring(0.93, 1.07), cloth, Vector3(0, 0.36, 0), Vector3.ZERO, Vector3(1, 1.5, 1))
			_add(root, _box(0.26, 0.26, 0.06), _glow(it.color2, 2.0), Vector3(0, 0.36, -1.09), Vector3(0, 0, 45))
	return root


static func trim_cloth(it: CosmeticItem) -> StandardMaterial3D:
	return _std(it.color2, 0.0, 0.95)


# ---------------------------------------------------------------- 썸네일과 베기 빛

## 베기 빛 그림(창 타일용): 초승달 모양 한 줄. 알파 0(검 본래 빛)은 흰 은빛.
static func slash_icon(it: CosmeticItem, size: Vector2) -> Image:
	var img := Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
	var c: Color = it.color if it.color.a > 0.0 else Color(0.82, 0.84, 0.9)
	var cx: float = size.x * 0.5
	var cy: float = size.y * 0.95
	var rx: float = size.x * 0.46   # 가로로 긴 칸에서는 납작한 초승달
	var ry: float = size.y * 0.9
	for y in int(size.y):
		for x in int(size.x):
			var p := Vector2((x - cx) / rx, (y - cy) / ry)
			var d: float = p.length()
			var a: float = atan2(p.y, p.x)   # 위쪽 부채꼴만
			if a > -0.25 or a < -PI + 0.25:
				continue
			var inner: float = 0.78 + sin((a + PI * 0.5) * 2.0) * 0.06
			if d < 1.0 and d > inner:
				var edge: float = clampf((d - inner) / (1.0 - inner), 0.0, 1.0)
				var tail: float = clampf(1.0 - absf(a + PI * 0.5) / 1.25, 0.0, 1.0)
				var k: float = pow(edge, 1.4) * (0.35 + 0.65 * tail)
				img.set_pixel(x, y, Color(c.r, c.g, c.b, clampf(k * 1.4, 0.0, 1.0)))
	return img
