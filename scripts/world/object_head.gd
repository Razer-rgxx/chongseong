class_name ObjectHead
extends SkeletonModifier3D
## 오브젝트 헤드(2026-11-22): 머리 대신 그 사람을 나타내는 물건. 영주는 검, 대장장이는 망치, 촌장은 등불….
## 머리뼈를 거의 0으로 줄이고(이 모디파이어), 같은 뼈에 BoneAttachment3D로 물건을 단다. 물건은 기본 도형으로 만든다(AI 에셋 없음).
## 쓰는 법: ObjectHead.attach(skeleton, &"smith")

const FOR_KIND: Dictionary = {
	&"lord": &"sword", &"smith": &"hammer", &"apprentice": &"tongs", &"elder": &"lantern",
	&"merchant": &"pouch", &"herbalist": &"mortar", &"gatherer": &"basket", &"hunter": &"antlers",
	&"knight": &"helm", &"gatekeeper": &"spear", &"pilgrim": &"candle", &"drunk": &"jug",
	&"peasant": &"bucket", &"peasant2": &"wheat", &"peasant3": &"pot", &"peasant4": &"wheat",
}

var bone_name: String = ""
var holder: Node3D
## 몸 전체 크기(사람 키 1.75m 기준)에 맞춰 물건 크기를 곱한다.
var size: float = 2.1


static func head_bone(skel: Skeleton3D) -> int:
	for i in skel.get_bone_count():
		var n: String = skel.get_bone_name(i)
		if n.ends_with("Head") or n == "head":
			return i
	return -1


## 머리를 물건으로 바꾼다. kind가 사람 종류면 FOR_KIND로 물건을 고른다.
static func attach(skel: Skeleton3D, kind: StringName) -> Node3D:
	if skel == null:
		return null
	var bi: int = head_bone(skel)
	if bi < 0:
		return null
	var mod := ObjectHead.new()
	mod.bone_name = skel.get_bone_name(bi)
	skel.add_child(mod)
	var obj: StringName = FOR_KIND.get(kind, kind)
	var o := build(obj)
	# 목깃: 줄인 머리 자리를 가리고 물건이 목에서 자라난 것처럼(요즘 오브젝트헤드는 목과 물건 사이를 천·쇠고리로 잇는다)
	var collar := MeshInstance3D.new()
	var tm := TorusMesh.new()
	# 사진 속 등불머리처럼: 목 대신 주름 깃(러프)이 물건을 받친다
	tm.inner_radius = 0.03
	tm.outer_radius = 0.085
	tm.rings = 24
	collar.mesh = tm
	collar.scale = Vector3(1, 0.55, 1)
	collar.material_override = _m(Color(0.72, 0.68, 0.6))
	o.add_child(collar)
	# 머리뼈는 줄어 있으니 그 뼈에 달지 않는다. 매 갱신마다 머리뼈 자리에 크기 1로 세운다(top_level)
	var holder := Node3D.new()
	holder.top_level = true
	skel.add_child(holder)
	holder.add_child(o)
	mod.holder = holder
	return holder


func _process_modification() -> void:
	var s := get_skeleton()
	if s == null:
		return
	var i: int = s.find_bone(bone_name)
	if i < 0:
		return
	s.set_bone_pose_scale(i, Vector3.ONE * 0.001)
	if holder:
		var g: Transform3D = s.global_transform * s.get_bone_global_pose(i)
		holder.global_transform = Transform3D(g.basis.orthonormalized().scaled(Vector3.ONE * size), g.origin)


static func _m(c: Color, metal: float = 0.0, rough: float = 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


static func _box(p: Node3D, size: Vector3, at: Vector3, m: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = at
	mi.rotation = rot
	mi.material_override = m
	p.add_child(mi)
	return mi


static func _cyl(p: Node3D, r_top: float, r_bot: float, h: float, at: Vector3, m: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = 12
	mi.mesh = c
	mi.position = at
	mi.rotation = rot
	mi.material_override = m
	p.add_child(mi)
	return mi


static func _ball(p: Node3D, r: float, at: Vector3, m: Material, squash: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	mi.mesh = s
	mi.position = at
	mi.scale = squash
	mi.material_override = m
	p.add_child(mi)
	return mi


## 물건 하나(바닥이 원점, 위로 0.3~0.5m). 색은 어둡고 바랬다.
static func build(obj: StringName) -> Node3D:
	var n := Node3D.new()
	var steel := _m(Color(0.55, 0.56, 0.58), 0.85, 0.35)
	var iron := _m(Color(0.22, 0.22, 0.23), 0.7, 0.55)
	var wood := _m(Color(0.3, 0.2, 0.12))
	var leather := _m(Color(0.22, 0.14, 0.09))
	var brass := _m(Color(0.55, 0.42, 0.2), 0.8, 0.4)
	var cloth := _m(Color(0.42, 0.38, 0.3))
	var clay := _m(Color(0.42, 0.26, 0.17))
	match obj:
		&"sword":
			# 칼끝이 위. 칼자루 끝(구슬) → 감은 손잡이 → 코등이(끝이 말림) → 칼날(가운데 홈, 끝은 뾰족)
			_ball(n, 0.04, Vector3(0, -0.005, 0), brass)
			_cyl(n, 0.026, 0.03, 0.1, Vector3(0, 0.06, 0), leather)
			for k in 4:
				_cyl(n, 0.031, 0.031, 0.008, Vector3(0, 0.025 + k * 0.025, 0), brass)
			_box(n, Vector3(0.3, 0.045, 0.07), Vector3(0, 0.125, 0), brass)
			for sx in [-1.0, 1.0]:
				_ball(n, 0.035, Vector3(sx * 0.16, 0.14, 0), brass, Vector3(1, 1.3, 1))
			_cyl(n, 0.05, 0.06, 0.03, Vector3(0, 0.155, 0), brass)
			_box(n, Vector3(0.15, 0.36, 0.035), Vector3(0, 0.33, 0), steel)
			_box(n, Vector3(0.03, 0.3, 0.04), Vector3(0, 0.32, 0), iron)
			_box(n, Vector3(0.106, 0.106, 0.035), Vector3(0, 0.51, 0), steel, Vector3(0, 0, PI / 4))
		&"hammer":
			_cyl(n, 0.035, 0.04, 0.12, Vector3(0, 0.06, 0), wood)
			_cyl(n, 0.045, 0.045, 0.03, Vector3(0, 0.12, 0), iron)
			_box(n, Vector3(0.24, 0.2, 0.2), Vector3(0, 0.22, 0), iron)
			for sx in [-1.0, 1.0]:
				_cyl(n, 0.1, 0.11, 0.06, Vector3(sx * 0.15, 0.22, 0), iron, Vector3(0, 0, PI / 2))
				_cyl(n, 0.112, 0.112, 0.012, Vector3(sx * 0.1, 0.22, 0), brass, Vector3(0, 0, PI / 2))
			_cyl(n, 0.03, 0.03, 0.05, Vector3(0, 0.33, 0), wood)
		&"tongs":
			# 집게가 달군 쇳덩이를 물고 있다: 엇갈린 두 자루, 가운데 못, 벌어진 입, 빨갛게 빛나는 쇠
			for sx in [-1.0, 1.0]:
				_box(n, Vector3(0.045, 0.2, 0.04), Vector3(sx * 0.035, 0.1, 0), iron, Vector3(0, 0, sx * 0.25))
				_box(n, Vector3(0.05, 0.16, 0.045), Vector3(-sx * 0.045, 0.27, 0), iron, Vector3(0, 0, -sx * 0.2))
			_cyl(n, 0.03, 0.03, 0.06, Vector3(0, 0.19, 0), brass, Vector3(PI / 2, 0, 0))
			var hot := _m(Color(1.0, 0.4, 0.12))
			hot.emission_enabled = true
			hot.emission = Color(1.0, 0.32, 0.06)
			hot.emission_energy_multiplier = 3.0
			_box(n, Vector3(0.2, 0.09, 0.09), Vector3(0, 0.37, 0), hot)
			var hl := OmniLight3D.new()
			hl.light_color = Color(1.0, 0.4, 0.15)
			hl.omni_range = 2.0
			hl.position = Vector3(0, 0.37, 0.1)
			n.add_child(hl)
		&"lantern":
			# 사진의 가로등 등불: 놋쇠 받침 → 여섯 모 유리(빛남) + 모서리 살 → 처마 → 여섯 모 지붕 → 꼭지
			_cyl(n, 0.1, 0.07, 0.05, Vector3(0, 0.025, 0), iron)
			_cyl(n, 0.13, 0.13, 0.025, Vector3(0, 0.06, 0), brass)
			var glass := _m(Color(1.0, 0.82, 0.5))
			glass.emission_enabled = true
			glass.emission = Color(1.0, 0.68, 0.3)
			glass.emission_energy_multiplier = 2.2
			var g := _cyl(n, 0.12, 0.1, 0.22, Vector3(0, 0.18, 0), glass)
			(g.mesh as CylinderMesh).radial_segments = 6
			for k in 6:
				var a: float = float(k) / 6.0 * TAU
				_box(n, Vector3(0.018, 0.24, 0.018), Vector3(cos(a) * 0.112, 0.18, sin(a) * 0.112), iron, Vector3(0, -a, 0))
			_cyl(n, 0.16, 0.16, 0.025, Vector3(0, 0.3, 0), brass)
			var roof := _cyl(n, 0.03, 0.17, 0.12, Vector3(0, 0.37, 0), _m(Color(0.42, 0.22, 0.12), 0.6, 0.4))
			(roof.mesh as CylinderMesh).radial_segments = 6
			_cyl(n, 0.035, 0.035, 0.05, Vector3(0, 0.45, 0), iron)
			_ball(n, 0.035, Vector3(0, 0.5, 0), brass)
			_cyl(n, 0.0, 0.015, 0.06, Vector3(0, 0.55, 0), brass)
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.7, 0.35)
			l.omni_range = 3.5
			l.light_energy = 1.2
			l.position = Vector3(0, 0.18, 0)
			n.add_child(l)
		&"pouch":
			_ball(n, 0.15, Vector3(0, 0.13, 0), leather, Vector3(1, 0.9, 1))
			_cyl(n, 0.05, 0.07, 0.06, Vector3(0, 0.27, 0), leather)
		&"mortar":
			_cyl(n, 0.15, 0.1, 0.16, Vector3(0, 0.08, 0), _m(Color(0.45, 0.43, 0.4)))
			_cyl(n, 0.025, 0.035, 0.24, Vector3(0.04, 0.22, 0), wood, Vector3(0, 0, -0.35))
		&"basket":
			_cyl(n, 0.17, 0.13, 0.16, Vector3(0, 0.08, 0), _m(Color(0.45, 0.34, 0.18)))
			_box(n, Vector3(0.3, 0.02, 0.025), Vector3(0, 0.25, 0), _m(Color(0.45, 0.34, 0.18)), Vector3(0, 0, 0))
		&"antlers":
			_ball(n, 0.1, Vector3(0, 0.08, 0), leather)
			for sx in [-1.0, 1.0]:
				_cyl(n, 0.012, 0.025, 0.3, Vector3(sx * 0.1, 0.22, 0), _m(Color(0.6, 0.52, 0.4)), Vector3(0, 0, -sx * 0.5))
				_cyl(n, 0.01, 0.015, 0.12, Vector3(sx * 0.12, 0.3, 0.04), _m(Color(0.6, 0.52, 0.4)), Vector3(0.6, 0, -sx * 0.2))
		&"helm":
			_cyl(n, 0.13, 0.14, 0.22, Vector3(0, 0.11, 0), iron)
			_ball(n, 0.13, Vector3(0, 0.22, 0), iron, Vector3(1, 0.6, 1))
			_box(n, Vector3(0.2, 0.025, 0.02), Vector3(0, 0.13, 0.135), _m(Color(0.02, 0.02, 0.02)))
		&"spear":
			_cyl(n, 0.03, 0.03, 0.12, Vector3(0, 0.06, 0), wood)
			_cyl(n, 0.0, 0.11, 0.34, Vector3(0, 0.29, 0), steel)
		&"candle":
			# 사진의 촛불머리: 굵은 초, 위에서 흘러내린 촛농, 심지, 물방울 모양 불꽃과 빛
			var wax := _m(Color(0.82, 0.86, 0.9), 0.0, 0.35)
			_cyl(n, 0.13, 0.14, 0.3, Vector3(0, 0.15, 0), wax)
			_cyl(n, 0.15, 0.15, 0.04, Vector3(0, 0.3, 0), wax)
			for k in 9:
				var a: float = float(k) / 9.0 * TAU + 0.3
				var len: float = 0.06 + fmod(float(k) * 0.37, 1.0) * 0.14
				_cyl(n, 0.026, 0.02, len, Vector3(cos(a) * 0.14, 0.3 - len / 2.0, sin(a) * 0.14), wax)
				_ball(n, 0.024, Vector3(cos(a) * 0.14, 0.3 - len, sin(a) * 0.14), wax, Vector3(1, 1.3, 1))
			_cyl(n, 0.006, 0.006, 0.05, Vector3(0, 0.34, 0), _m(Color(0.05, 0.04, 0.03)))
			var fl := _m(Color(1, 0.6, 0.2))
			fl.emission_enabled = true
			fl.emission = Color(1.0, 0.55, 0.15)
			fl.emission_energy_multiplier = 4.0
			_ball(n, 0.045, Vector3(0, 0.4, 0), fl, Vector3(1, 1.5, 1))
			_cyl(n, 0.0, 0.03, 0.08, Vector3(0, 0.47, 0), fl)
			var cl := OmniLight3D.new()
			cl.light_color = Color(1.0, 0.62, 0.28)
			cl.omni_range = 3.0
			cl.light_energy = 1.3
			cl.position = Vector3(0, 0.42, 0)
			n.add_child(cl)
		&"jug":
			_ball(n, 0.14, Vector3(0, 0.14, 0), clay)
			_cyl(n, 0.04, 0.06, 0.1, Vector3(0, 0.3, 0), clay)
		&"pot":
			_cyl(n, 0.16, 0.12, 0.18, Vector3(0, 0.09, 0), iron)
			_box(n, Vector3(0.36, 0.02, 0.02), Vector3(0, 0.2, 0), iron)
		&"wheat":
			for k in 7:
				var a: float = float(k) / 7.0 * TAU
				_cyl(n, 0.006, 0.008, 0.32, Vector3(cos(a) * 0.03, 0.16, sin(a) * 0.03), _m(Color(0.62, 0.5, 0.26)), Vector3(sin(a) * 0.15, 0, cos(a) * 0.15))
				_ball(n, 0.02, Vector3(cos(a) * 0.055, 0.34, sin(a) * 0.055), _m(Color(0.66, 0.52, 0.25)), Vector3(1, 2.5, 1))
			_cyl(n, 0.045, 0.045, 0.04, Vector3(0, 0.1, 0), cloth)
		_:
			# bucket
			_cyl(n, 0.15, 0.12, 0.2, Vector3(0, 0.1, 0), wood)
			_cyl(n, 0.155, 0.155, 0.02, Vector3(0, 0.06, 0), iron)
			_cyl(n, 0.155, 0.155, 0.02, Vector3(0, 0.16, 0), iron)
	return n
