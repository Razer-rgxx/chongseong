class_name FutureEnemyArt
extends RefCounted
## 녹슨 미래 구역의 적 몸(docs/stranger.md 3단계). 기본 도형만, 무딘 쇠빛에 차가운 눈빛 하나. EnemyView가 EnemyData.future일 때 부른다.
## 앞은 -Z. 돌려주는 것: {mats(맞으면 하얘지는 재질), eyes(눈 메시), height}.

const EYE: Color = Color(0.4, 0.8, 1.0)


static func _metal(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.6
	m.roughness = 0.55
	return m


static func _eye() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = EYE
	m.emission_enabled = true
	m.emission = EYE
	m.emission_energy_multiplier = 2.2
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func _add(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


## kind: &"wolf"이면 빠른 드론, 아니면(archer) 사수. grow는 몸 배율.
static func build(kind: StringName, body: Node3D, grow: float, c: Color) -> Dictionary:
	var root := Node3D.new()
	root.scale = Vector3.ONE * grow
	body.add_child(root)
	var hull: StandardMaterial3D = _metal(c)
	var dark: StandardMaterial3D = _metal(c.darkened(0.45))
	var rust: StandardMaterial3D = _metal(FutureLayout.RUST)
	var eye_m: StandardMaterial3D = _eye()
	var eyes: Array = []
	var height: float
	if kind == &"wolf":
		height = 1.5
		var core := SphereMesh.new()
		core.radius = 0.34
		core.height = 0.62
		_add(root, core, hull, Vector3(0, 1.0, 0))
		var ring := TorusMesh.new()
		ring.inner_radius = 0.42
		ring.outer_radius = 0.52
		_add(root, ring, dark, Vector3(0, 1.0, 0))
		var fin := BoxMesh.new()
		fin.size = Vector3(0.06, 0.34, 0.5)
		_add(root, fin, rust, Vector3(0, 1.25, 0.2), Vector3(-20, 0, 0))
		var arm := BoxMesh.new()
		arm.size = Vector3(0.9, 0.05, 0.12)
		_add(root, arm, dark, Vector3(0, 0.78, 0.1))
		var e := SphereMesh.new()
		e.radius = 0.1
		e.height = 0.2
		eyes.append(_add(root, e, eye_m, Vector3(0, 1.03, -0.3)))
	else:
		height = 2.0
		var leg := BoxMesh.new()
		leg.size = Vector3(0.16, 0.8, 0.18)
		for sx in [-0.17, 0.17]:
			_add(root, leg, dark, Vector3(sx, 0.4, 0))
		var torso := BoxMesh.new()
		torso.size = Vector3(0.62, 0.78, 0.34)
		_add(root, torso, hull, Vector3(0, 1.2, 0))
		var plate := BoxMesh.new()
		plate.size = Vector3(0.5, 0.3, 0.06)
		_add(root, plate, rust, Vector3(0, 1.3, -0.2))
		var head := BoxMesh.new()
		head.size = Vector3(0.3, 0.26, 0.3)
		_add(root, head, dark, Vector3(0, 1.78, 0))
		var visor := BoxMesh.new()
		visor.size = Vector3(0.2, 0.06, 0.04)
		eyes.append(_add(root, visor, eye_m, Vector3(0, 1.8, -0.16)))
		var gun := BoxMesh.new()
		gun.size = Vector3(0.1, 0.12, 0.95)
		_add(root, gun, dark, Vector3(0.3, 1.25, -0.4))
		var arm2 := BoxMesh.new()
		arm2.size = Vector3(0.12, 0.12, 0.5)
		_add(root, arm2, hull, Vector3(0.3, 1.3, -0.05))
	return {"mats": [hull, dark, rust], "eyes": eyes, "height": height}
