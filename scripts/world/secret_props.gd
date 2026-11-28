class_name SecretProps
extends RefCounted
## 꾸미기 비밀(CosSecrets)의 모양(docs/cosmetics.md). 기본 도형만. 세계에 글자 없음.
## figure: 후드를 쓴 그림자 인물(말을 건다), cairn: 쌓은 납작한 돌 위에 은은한 빛(만진다).

const ROBE := Color(0.05, 0.05, 0.06)
const EYE := Color(0.82, 0.86, 0.78)


static func make(look: String, parent: Node3D, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = "Secret_" + look
	parent.add_child(n)
	n.position = at
	if look == "figure":
		_figure(n)
	else:
		_cairn(n)
	return n


static func _mat(c: Color, rough: float = 0.95, glow: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


static func _part(n: Node3D, mesh: Mesh, m: Material, p: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = p
	n.add_child(mi)
	return mi


static func _figure(n: Node3D) -> void:
	var body := Node3D.new()
	body.name = "Body"
	n.add_child(body)
	var robe := CylinderMesh.new()
	robe.top_radius = 0.16
	robe.bottom_radius = 0.5
	robe.height = 1.5
	_part(body, robe, _mat(ROBE), Vector3(0, 0.75, 0))
	var hood := SphereMesh.new()
	hood.radius = 0.26
	hood.height = 0.56
	_part(body, hood, _mat(ROBE), Vector3(0, 1.62, 0))
	var eye := SphereMesh.new()
	eye.radius = 0.035
	eye.height = 0.07
	var em: StandardMaterial3D = _mat(EYE, 0.5, 2.0)
	_part(body, eye, em, Vector3(-0.08, 1.64, -0.22))
	_part(body, eye, em, Vector3(0.08, 1.64, -0.22))


static func _cairn(n: Node3D) -> void:
	var rng := RandomNumberGenerator.new()   # 꾸밈용(화면 쪽)
	rng.seed = 7
	var y: float = 0.0
	for i in 3:
		var c := CylinderMesh.new()
		c.top_radius = 0.34 - i * 0.07
		c.bottom_radius = 0.38 - i * 0.07
		c.height = 0.13
		var m := _part(n, c, _mat(Color(0.2, 0.19, 0.18).lerp(Color(0.3, 0.28, 0.25), rng.randf())), Vector3(rng.randf_range(-0.03, 0.03), y + 0.065, rng.randf_range(-0.03, 0.03)))
		m.rotation.y = rng.randf() * TAU
		y += 0.12
	var core := SphereMesh.new()
	core.radius = 0.05
	core.height = 0.1
	_part(n, core, _mat(Color(0.75, 0.82, 0.9), 0.4, 2.5), Vector3(0, y + 0.1, 0))
	var l := OmniLight3D.new()
	l.light_color = Color(0.7, 0.8, 1.0)
	l.light_energy = 0.5
	l.omni_range = 3.0
	l.position = Vector3(0, y + 0.25, 0)
	n.add_child(l)
