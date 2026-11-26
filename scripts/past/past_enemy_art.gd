class_name PastEnemyArt
extends RefCounted
## 과거 신화 구역의 적 몸(docs/stranger.md 5·7단계). 기본 도형만: 사슴 정령(늑대 몸 위치), 돌 파수꾼(거인), 돌방패 수호자(방패병),
## 비룡(돌격병), 시간을 먹는 흑룡(무덤 기사 행동, 오른 날개가 arm 피벗). 앞은 -Z.
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
	elif kind == &"grave_knight":   # 2026-11-26 시간을 먹는 흑룡: 뒷다리로 선 검은 용, 용암 금, 뿔 난 긴 머리, 날개 둘(오른 날개가 arm 피벗), 꼬리, 등에 박힌 옛 칼
		height = 3.4
		var ember: StandardMaterial3D = _mat(Color(1.0, 0.42, 0.12), 0.6, 1.8)
		var belly: StandardMaterial3D = _mat(c.lightened(0.25).lerp(Color(0.45, 0.3, 0.2), 0.5), 0.8)
		var horn: StandardMaterial3D = _mat(Color(0.32, 0.28, 0.24), 0.6)
		var wing_m: StandardMaterial3D = _mat(c.darkened(0.2), 0.9)
		wing_m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var iron: StandardMaterial3D = _mat(Color(0.5, 0.48, 0.46), 0.35)
		iron.metallic = 0.8
		for sx in [-1.0, 1.0]:   # 뒷다리: 허벅지, 정강이, 발톱
			_add(root, _box(Vector3(0.42, 0.8, 0.6)), main, Vector3(0.42 * sx, 0.95, 0.15), Vector3(30, 0, 0))
			_add(root, _box(Vector3(0.28, 0.75, 0.3)), dark, Vector3(0.44 * sx, 0.38, 0.3), Vector3(-25, 0, 0))
			_add(root, _box(Vector3(0.36, 0.14, 0.6)), dark, Vector3(0.44 * sx, 0.07, 0.05))
			for k in 3:
				_add(root, _box(Vector3(0.07, 0.07, 0.24)), horn, Vector3(0.44 * sx + (k - 1) * 0.12, 0.05, -0.32), Vector3(-15, 0, 0))
		_add(root, _box(Vector3(1.1, 1.5, 0.95)), main, Vector3(0, 1.75, 0.0), Vector3(-25, 0, 0))   # 몸통(앞으로 기움)
		_add(root, _box(Vector3(0.7, 1.2, 0.08)), belly, Vector3(0, 1.72, -0.48), Vector3(-25, 0, 0))   # 배 비늘
		for k in 3:
			_add(root, _box(Vector3(0.72, 0.04, 0.1)), ember, Vector3(0, 1.35 + k * 0.32, -0.5 + k * 0.15), Vector3(-25, 0, 0))
		for k in 4:   # 목: 앞위로 굽는 네 마디
			var t: float = k / 3.0
			_add(root, _box(Vector3(0.42 - k * 0.04, 0.5, 0.42 - k * 0.04)), main, Vector3(0, 2.45 + t * 0.6, -0.35 - t * 0.75), Vector3(-30.0 - k * 12.0, 0, 0))
		var head := Node3D.new()
		head.position = Vector3(0, 3.15, -1.3)
		head.rotation_degrees = Vector3(-8, 0, 0)
		root.add_child(head)
		_add(head, _box(Vector3(0.5, 0.36, 0.6)), main, Vector3(0, 0, 0))
		_add(head, _box(Vector3(0.34, 0.22, 0.55)), main, Vector3(0, -0.02, -0.5))   # 주둥이
		_add(head, _box(Vector3(0.3, 0.1, 0.7)), dark, Vector3(0, -0.22, -0.35), Vector3(14, 0, 0))   # 아래턱(벌어짐)
		_add(head, _box(Vector3(0.24, 0.03, 0.5)), ember, Vector3(0, -0.15, -0.35), Vector3(7, 0, 0))   # 입 안 불빛
		for sx in [-1.0, 1.0]:
			_add(head, _box(Vector3(0.09, 0.09, 0.7)), horn, Vector3(0.2 * sx, 0.22, 0.45), Vector3(25, 12.0 * sx, 0))
			_add(head, _box(Vector3(0.06, 0.06, 0.4)), horn, Vector3(0.24 * sx, 0.36, 0.85), Vector3(45, 18.0 * sx, 0))
			_add(head, _box(Vector3(0.05, 0.05, 0.22)), horn, Vector3(0.12 * sx, 0.12, -0.72), Vector3(-30, 0, 0))   # 코뿔
			eyes.append(_add(head, _box(Vector3(0.12, 0.05, 0.04)), eye_m, Vector3(0.17 * sx, 0.07, -0.3), Vector3(0, 0, -12.0 * sx)))
		for k in 6:   # 등 가시
			_add(root, _box(Vector3(0.06, 0.28 - k * 0.025, 0.14)), horn, Vector3(0, 2.5 - k * 0.3, 0.42 + k * 0.12), Vector3(-30, 0, 0))
		for k in 3:   # 등에 박힌 옛 칼(묶던 사슬의 칼)
			_add(root, _box(Vector3(0.05, 0.9, 0.12)), iron, Vector3(-0.3 + k * 0.3, 2.1, 0.55), Vector3(40.0 + 8.0 * k, 0, -15.0 + 15.0 * k))
		for k in 5:   # 꼬리: 뒤로 땅까지
			var t2: float = k / 4.0
			_add(root, _box(Vector3(0.44 - k * 0.08, 0.36 - k * 0.05, 0.6)), main, Vector3(0, 1.0 - t2 * 0.85, 0.75 + k * 0.52), Vector3(28.0 - k * 8.0, 0, 0))
		var spread: Array[Node3D] = []
		for sx in [-1.0, 1.0]:   # 날개: 어깨 피벗 → 펼친 각(안쪽 노드) → 뼈·막. 아래(-y)로 지어 두면 피벗이 위뒤로 든다.
			var pivot := Node3D.new()
			pivot.position = Vector3(0.5 * sx, 2.35, 0.15)
			pivot.rotation = Vector3(-2.2, 0.0, 0.0)
			root.add_child(pivot)
			var inner := Node3D.new()
			inner.rotation_degrees = Vector3(0, 0, -32.0 * sx)
			pivot.add_child(inner)
			_add(inner, _box(Vector3(0.13, 2.3, 0.13)), dark, Vector3(0, -1.15, 0))
			_add(inner, _box(Vector3(0.08, 1.4, 0.08)), dark, Vector3(0.55 * sx, -2.6, 0), Vector3(0, 0, 40.0 * sx))
			_add(inner, _box(Vector3(1.5, 2.1, 0.03)), wing_m, Vector3(0.72 * sx, -1.2, 0.02), Vector3(0, 0, 8.0 * sx))
			_add(inner, _box(Vector3(1.0, 1.2, 0.03)), wing_m, Vector3(1.1 * sx, -2.35, 0.02), Vector3(0, 0, 30.0 * sx))
			_add(inner, _box(Vector3(0.03, 1.8, 0.04)), ember, Vector3(0.8 * sx, -1.2, -0.01), Vector3(0, 0, 18.0 * sx))
			_add(inner, _box(Vector3(0.14, 0.2, 0.14)), horn, Vector3(0, -2.35, 0))   # 날개 발톱
			spread.append(pivot)
		return {"mats": [main, dark, moss], "eyes": eyes, "height": height, "arm": spread[1]}
	elif kind == &"charger":   # 2026-11-26 비룡: 네 발로 낮게 달리는 작은 용, 접은 날개, 뿔, 호박빛 눈
		height = 1.1
		var horn2: StandardMaterial3D = _mat(Color(0.3, 0.26, 0.22), 0.6)
		var belly2: StandardMaterial3D = _mat(c.lightened(0.3), 0.85)
		var wing2: StandardMaterial3D = _mat(c.darkened(0.3), 0.9)
		wing2.cull_mode = BaseMaterial3D.CULL_DISABLED
		_add(root, _box(Vector3(0.62, 0.5, 1.2)), main, Vector3(0, 0.62, 0.05))
		_add(root, _box(Vector3(0.46, 0.08, 1.0)), belly2, Vector3(0, 0.38, 0.0))
		_add(root, _box(Vector3(0.3, 0.32, 0.5)), main, Vector3(0, 0.82, -0.68), Vector3(-25, 0, 0))   # 목
		_add(root, _box(Vector3(0.32, 0.26, 0.5)), main, Vector3(0, 0.98, -1.02))   # 머리
		_add(root, _box(Vector3(0.22, 0.1, 0.36)), dark, Vector3(0, 0.84, -1.12), Vector3(12, 0, 0))   # 턱
		for sx in [-1.0, 1.0]:
			_add(root, _box(Vector3(0.06, 0.06, 0.42)), horn2, Vector3(0.12 * sx, 1.15, -0.78), Vector3(30, 10.0 * sx, 0))
			eyes.append(_add(root, _box(Vector3(0.07, 0.05, 0.04)), eye_m, Vector3(0.11 * sx, 1.03, -1.27)))
			for fz in [-0.4, 0.45]:   # 다리
				_add(root, _box(Vector3(0.16, 0.5, 0.18)), dark, Vector3(0.3 * sx, 0.25, fz), Vector3(fz * -20.0, 0, 0))
			# 접은 날개: 등 위로 비스듬한 막
			_add(root, _box(Vector3(0.04, 0.5, 0.9)), wing2, Vector3(0.22 * sx, 1.02, 0.15), Vector3(0, 0, 35.0 * sx))
		for k in 4:   # 꼬리
			_add(root, _box(Vector3(0.24 - k * 0.04, 0.2 - k * 0.03, 0.45)), main, Vector3(0, 0.6 - k * 0.1, 0.8 + k * 0.4), Vector3(10, 0, 0))
		for k in 4:   # 등 가시
			_add(root, _box(Vector3(0.04, 0.14, 0.1)), horn2, Vector3(0, 0.92, -0.3 + k * 0.25))
		return {"mats": [main, dark, moss], "eyes": eyes, "height": height}
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
