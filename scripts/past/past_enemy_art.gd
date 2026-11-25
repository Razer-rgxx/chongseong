class_name PastEnemyArt
extends RefCounted
## 과거 신화 구역의 적 몸(docs/stranger.md 5단계). 기본 도형만: 사슴 정령(늑대 몸 위치), 돌 파수꾼(거인), 돌방패 수호자(방패병). 앞은 -Z.
## 돌려주는 것: {mats, eyes, height}(FutureEnemyArt와 같은 모양).

const EYE: Color = Color(1.0, 0.7, 0.25)


static func _mat(c: Color, rough: float = 0.95, emit: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


static func _eye() -> StandardMaterial3D:
	var m := _mat(EYE, 0.5, 2.4)
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


static func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


static func build(kind: StringName, body: Node3D, grow: float, c: Color) -> Dictionary:
	var root := Node3D.new()
	root.scale = Vector3.ONE * grow
	body.add_child(root)
	var main: StandardMaterial3D = _mat(c)
	var dark: StandardMaterial3D = _mat(c.darkened(0.5))
	var moss: StandardMaterial3D = _mat(Color(0.2, 0.26, 0.12))
	var eye_m: StandardMaterial3D = _eye()
	var eyes: Array = []
	var height: float
	if kind == &"wolf":   # 사슴 정령: 옅은 사슴 몸, 큰 뿔, 호박빛 눈
		height = 1.6
		_add(root, _box(Vector3(0.36, 0.42, 1.0)), main, Vector3(0, 0.78, 0))
		for sx in [-0.12, 0.12]:
			for sz in [-0.34, 0.34]:
				_add(root, _box(Vector3(0.07, 0.62, 0.07)), dark, Vector3(sx, 0.31, sz))
		_add(root, _box(Vector3(0.2, 0.5, 0.2)), main, Vector3(0, 1.08, -0.5), Vector3(-25, 0, 0))
		_add(root, _box(Vector3(0.2, 0.2, 0.34)), main, Vector3(0, 1.32, -0.68))
		for sx in [-1.0, 1.0]:
			_add(root, _box(Vector3(0.04, 0.5, 0.04)), moss, Vector3(0.1 * sx, 1.6, -0.6), Vector3(0, 0, -22.0 * sx))
			_add(root, _box(Vector3(0.04, 0.28, 0.04)), moss, Vector3(0.22 * sx, 1.85, -0.6), Vector3(0, 0, 38.0 * sx))
		var e := SphereMesh.new()
		e.radius = 0.04
		e.height = 0.08
		for sx in [-0.07, 0.07]:
			eyes.append(_add(root, e, eye_m, Vector3(sx, 1.36, -0.84)))
	elif kind == &"shield":   # 돌방패 수호자: 돌 몸통, 앞을 막는 큰 돌판
		height = 2.0
		_add(root, _box(Vector3(0.5, 0.8, 0.34)), main, Vector3(0, 0.4, 0))
		_add(root, _box(Vector3(0.62, 0.7, 0.4)), main, Vector3(0, 1.15, 0))
		_add(root, _box(Vector3(0.28, 0.26, 0.28)), dark, Vector3(0, 1.72, 0))
		_add(root, _box(Vector3(0.9, 1.3, 0.14)), moss, Vector3(0, 1.0, -0.38))
		var v := _box(Vector3(0.2, 0.05, 0.04))
		eyes.append(_add(root, v, eye_m, Vector3(0, 1.74, -0.15)))
	elif kind == &"grave_knight":   # 2026-11-26 시간을 먹는 짐승의 남은 몸: 검은 돌 몸에 용암 금, 등에 박힌 첫 칼들, 뿔 난 머리, 오른팔은 돌 칼날(arm 피벗)
		height = 3.0
		var ember: StandardMaterial3D = _mat(Color(1.0, 0.42, 0.12), 0.6, 1.8)
		var iron: StandardMaterial3D = _mat(Color(0.5, 0.48, 0.46), 0.35)
		iron.metallic = 0.8
		for sx in [-0.34, 0.34]:
			_add(root, _box(Vector3(0.42, 1.1, 0.48)), dark, Vector3(sx, 0.55, 0.05), Vector3(6, 0, 0))
			_add(root, _box(Vector3(0.05, 0.7, 0.04)), ember, Vector3(sx + 0.05, 0.6, -0.27), Vector3(6, 0, 8))
		_add(root, _box(Vector3(1.3, 1.1, 0.85)), main, Vector3(0, 1.55, 0.05), Vector3(10, 0, 0))
		_add(root, _box(Vector3(1.32, 0.05, 0.87)), ember, Vector3(0, 1.2, 0.05))
		_add(root, _box(Vector3(0.06, 0.6, 0.04)), ember, Vector3(-0.12, 1.6, -0.42), Vector3(10, 0, 18))
		_add(root, _box(Vector3(0.05, 0.4, 0.04)), ember, Vector3(0.14, 1.7, -0.42), Vector3(10, 0, -24))
		_add(root, _box(Vector3(0.62, 0.5, 0.6)), dark, Vector3(0, 2.35, -0.15))
		for sx in [-1.0, 1.0]:
			_add(root, _box(Vector3(0.1, 0.7, 0.1)), dark, Vector3(0.28 * sx, 2.75, -0.1), Vector3(-20, 0, -30.0 * sx))
			_add(root, _box(Vector3(0.08, 0.36, 0.08)), dark, Vector3(0.5 * sx, 3.05, -0.05), Vector3(-10, 0, -60.0 * sx))
		for k in 5:   # 등에 박힌 첫 칼들(닻)
			var x: float = -0.45 + k * 0.22
			_add(root, _box(Vector3(0.05, 1.0, 0.12)), iron, Vector3(x, 2.2 + 0.1 * (k % 2), 0.45), Vector3(28.0 + 6.0 * k, 0, -18.0 + 9.0 * k))
			_add(root, _box(Vector3(0.22, 0.05, 0.05)), dark, Vector3(x, 1.75 + 0.1 * (k % 2), 0.22), Vector3(28.0 + 6.0 * k, 0, -18.0 + 9.0 * k))
		_add(root, _box(Vector3(0.36, 0.9, 0.36)), main, Vector3(-0.85, 1.4, 0.0), Vector3(0, 0, 12))
		var arm := Node3D.new()
		arm.position = Vector3(0.82, 1.9, 0.0)
		root.add_child(arm)
		_add(arm, _box(Vector3(0.36, 0.8, 0.36)), main, Vector3(0, -0.4, 0))
		_add(arm, _box(Vector3(0.12, 1.6, 0.3)), dark, Vector3(0, -1.5, -0.05))
		_add(arm, _box(Vector3(0.04, 1.5, 0.1)), ember, Vector3(0, -1.5, -0.2))
		arm.rotation = Vector3(-2.2, 0.0, 0.0)
		var v := _box(Vector3(0.4, 0.07, 0.04))
		eyes.append(_add(root, v, eye_m, Vector3(0, 2.4, -0.46)))
		return {"mats": [main, dark, moss], "eyes": eyes, "height": height, "arm": arm}
	else:   # 돌 파수꾼: 이끼 낀 큰 돌덩이 사람
		height = 3.2
		for sx in [-0.3, 0.3]:
			_add(root, _box(Vector3(0.4, 1.2, 0.44)), dark, Vector3(sx, 0.6, 0))
		_add(root, _box(Vector3(1.2, 1.2, 0.7)), main, Vector3(0, 1.8, 0))
		_add(root, _box(Vector3(1.3, 0.2, 0.8)), moss, Vector3(0, 2.45, 0))
		for sx in [-0.85, 0.85]:
			_add(root, _box(Vector3(0.4, 1.2, 0.4)), main, Vector3(sx, 1.7, -0.1))
		_add(root, _box(Vector3(0.6, 0.5, 0.5)), dark, Vector3(0, 2.8, 0))
		var v := _box(Vector3(0.36, 0.07, 0.04))
		eyes.append(_add(root, v, eye_m, Vector3(0, 2.82, -0.26)))
	return {"mats": [main, dark, moss], "eyes": eyes, "height": height}
