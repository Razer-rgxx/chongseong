class_name WeatherProps
extends RefCounted
## 날씨 사건의 몸(docs/weather.md): 젖은 쇳조각, 길 잃은 순례자, 벼락 맞은 검, 반딧불이 가리키는 숨은 상자.
## 기본 도형이고 글자는 없다. 자리는 Rules.weather_spots의 at(칸). 바꿔 끼우기 쉽게 이 파일 하나에 모은다.

static func build(kind: StringName, at: Vector2, id: int) -> Node3D:
	var n: Node3D
	match kind:
		&"glint":
			n = _wet_glint(id)
		&"pilgrim":
			n = _pilgrim()
		&"struck":
			n = _struck()
		_:
			n = _cache(at)
	n.name = "wx_%d" % id
	n.position = FieldBuilder.at_cell(at, 0.0)
	return n


static func _mesh(parent: Node3D, m: Mesh, pos: Vector3, col: Color, glow: float = 0.0, rough: float = 0.9) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = rough
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = glow
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _box(parent: Node3D, size: Vector3, pos: Vector3, col: Color, glow: float = 0.0) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(parent, b, pos, col, glow)


static func _light(parent: Node3D, col: Color, energy: float, rng: float, pos: Vector3) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.position = pos
	parent.add_child(l)


static func _wet_glint(id: int) -> Node3D:
	var n := Node3D.new()
	n.rotation.y = id * 2.1
	var c := Color(0.6, 0.82, 1.0)
	_box(n, Vector3(0.12, 0.03, 0.42), Vector3(0, 0.12, 0), c, 1.8).rotation = Vector3(0.3, 0, 0.2)
	_box(n, Vector3(0.08, 0.02, 0.2), Vector3(0.18, 0.08, 0.1), c, 1.8).rotation = Vector3(-0.2, 0.8, 0.1)
	return n


static func _pilgrim() -> Node3D:
	var n := Node3D.new()
	var cloak := CylinderMesh.new()
	cloak.top_radius = 0.17
	cloak.bottom_radius = 0.44
	cloak.height = 1.4
	cloak.radial_segments = 10
	_mesh(n, cloak, Vector3(0, 0.7, 0), Color(0.24, 0.21, 0.18))
	var head := SphereMesh.new()
	head.radius = 0.17
	head.height = 0.34
	_mesh(n, head, Vector3(0, 1.55, 0), Color(0.62, 0.52, 0.44))
	var hood := CylinderMesh.new()
	hood.top_radius = 0.0
	hood.bottom_radius = 0.22
	hood.height = 0.34
	_mesh(n, hood, Vector3(0, 1.72, 0), Color(0.2, 0.17, 0.14))
	var staff := CylinderMesh.new()
	staff.top_radius = 0.03
	staff.bottom_radius = 0.035
	staff.height = 1.9
	_mesh(n, staff, Vector3(0.5, 0.95, 0.1), Color(0.3, 0.2, 0.12))
	_box(n, Vector3(0.12, 0.16, 0.12), Vector3(0.5, 1.7, 0.1), Color(1.0, 0.7, 0.3), 2.0)
	_light(n, Color(1.0, 0.7, 0.35), 0.8, 7.0, Vector3(0.5, 1.7, 0.1))
	n.rotation.y = PI
	return n


static func _struck() -> Node3D:
	var n := Node3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 1.0
	ring.bottom_radius = 1.0
	ring.height = 0.03
	ring.radial_segments = 16
	_mesh(n, ring, Vector3(0, 0.03, 0), Color(0.04, 0.04, 0.05))
	var c := Color(0.7, 0.85, 1.0)
	var blade := _box(n, Vector3(0.14, 1.7, 0.035), Vector3(0, 0.85, 0), c, 2.2)
	blade.rotation.z = 0.08
	_box(n, Vector3(0.62, 0.07, 0.07), Vector3(0, 1.62, 0), Color(0.25, 0.25, 0.28))
	_light(n, c, 1.6, 8.0, Vector3(0, 1.2, 0))
	return n


static func _cache(at: Vector2) -> Node3D:
	var n := Node3D.new()
	_box(n, Vector3(0.8, 0.4, 0.5), Vector3(0, 0.2, 0), Color(0.16, 0.11, 0.07))
	_box(n, Vector3(0.84, 0.08, 0.54), Vector3(0, 0.42, 0), Color(0.22, 0.22, 0.24))
	n.add_child(_fireflies(Vector3(0, 0.9, 0), 1.4, 16))
	var back: Vector2 = (FieldLayout.START - at).normalized()
	for k in 3:   # 반딧불이가 오던 쪽으로 줄지어 길을 보여 준다
		var d: float = 4.0 + k * 4.5
		n.add_child(_fireflies(Vector3(back.x * d, 1.1, back.y * d), 1.0, 8))
	return n


static func _fireflies(pos: Vector3, r: float, amount: int) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = int(amount * (WebQuality.WEATHER_KEEP if WebQuality.on() else 1.0)) + 1
	p.lifetime = 3.0
	p.position = pos
	p.visibility_aabb = AABB(Vector3(-8, -4, -8), Vector3(16, 8, 16))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(r, 0.5, r)
	m.direction = Vector3(0.3, 0.2, 0.1)
	m.spread = 180.0
	m.initial_velocity_min = 0.1
	m.initial_velocity_max = 0.35
	m.gravity = Vector3.ZERO
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.85, 1.0, 0.45, 0.9)
	q.material = mat
	p.draw_pass_1 = q
	return p
