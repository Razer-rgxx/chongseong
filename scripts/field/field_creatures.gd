class_name FieldCreatures
extends Node3D
## 들판의 까마귀와 사슴(화면 꾸밈, 규칙 없음). 영주가 다가오면 까마귀는 날아오르고 사슴은 달아난다.
## 몸은 기본 도형 몇 개이고 움직임은 코드다. 랜덤은 따로 둔 꾸밈용 rng.

const CROW_FLEE: float = 9.0
const DEER_FLEE: float = 16.0
## 까마귀 자리(칸): 망루, 옛 싸움터, 안개 늪(넷), 까마귀 고개(넷)와 불탄 마을(둘)(끝 여섯, 28단계). 사슴 자리: 개울과 숲가.
const CROW_SPOTS: PackedVector2Array = [Vector2(90, 34), Vector2(94, 38), Vector2(88, 40), Vector2(80, 84), Vector2(86, 90), Vector2(98, 80), Vector2(74, 78), Vector2(95, 33), Vector2(118, 90), Vector2(134, 78), Vector2(146, 102), Vector2(160, 88), Vector2(180, 96), Vector2(196, 94), Vector2(210, 97), Vector2(222, 92), Vector2(190, 48), Vector2(216, 75)]
const DEER_SPOTS: PackedVector2Array = [Vector2(30, 58), Vector2(22, 66), Vector2(36, 38)]

var _rng := RandomNumberGenerator.new()
var _crows: Array[Dictionary] = []
var _deer: Array[Dictionary] = []


func _init() -> void:
	_rng.seed = 99
	name = "Creatures"


func _ready() -> void:
	var black := _mat(Color(0.03, 0.03, 0.04))
	for c in CROW_SPOTS:
		var n := Node3D.new()
		add_child(n)
		var p: Vector3 = FieldBuilder.at_cell(c)
		if c.distance_to(FieldLayout.TOWER) < 7.0:
			p.y += 0.0
		_part(n, Vector3(0.18, 0.14, 0.4), Vector3(0, 0.2, 0), black)
		_part(n, Vector3(0.1, 0.1, 0.12), Vector3(0, 0.3, 0.22), black)
		var wl := Node3D.new()
		wl.position = Vector3(-0.08, 0.26, 0)
		n.add_child(wl)
		_part(wl, Vector3(0.4, 0.02, 0.22), Vector3(-0.2, 0, 0), black)
		var wr := Node3D.new()
		wr.position = Vector3(0.08, 0.26, 0)
		n.add_child(wr)
		_part(wr, Vector3(0.4, 0.02, 0.22), Vector3(0.2, 0, 0), black)
		n.position = p
		n.rotation.y = _rng.randf() * TAU
		_crows.append({"n": n, "home": p, "wl": wl, "wr": wr, "fly": 0.0, "dir": Vector3.ZERO, "back": 0.0})
	var brown := _mat(Color(0.28, 0.19, 0.11))
	for c in DEER_SPOTS:
		var n := Node3D.new()
		add_child(n)
		_part(n, Vector3(0.5, 0.5, 1.2), Vector3(0, 1.0, 0), brown)
		_part(n, Vector3(0.2, 0.7, 0.2), Vector3(0, 1.45, 0.65), brown, Vector3(0.5, 0, 0))
		_part(n, Vector3(0.2, 0.22, 0.38), Vector3(0, 1.85, 0.9), brown)
		var legs: Array[Node3D] = []
		for lx in [-0.18, 0.18]:
			for lz in [-0.45, 0.45]:
				var leg := Node3D.new()
				leg.position = Vector3(lx, 0.8, lz)
				n.add_child(leg)
				_part(leg, Vector3(0.1, 0.8, 0.1), Vector3(0, -0.4, 0), brown)
				legs.append(leg)
		var p: Vector3 = FieldBuilder.at_cell(c)
		n.position = p
		n.rotation.y = _rng.randf() * TAU
		_deer.append({"n": n, "home": p, "legs": legs, "run": 0.0, "t": 0.0})


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


static func _part(parent: Node3D, size: Vector3, at: Vector3, m: Material, rot: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = at
	mi.rotation = rot
	parent.add_child(mi)


## 영주의 월드 위치를 받아 한 프레임 움직인다.
func step(delta: float, lord: Vector3) -> void:
	for c in _crows:
		_step_crow(c, delta, lord)
	for d in _deer:
		_step_deer(d, delta, lord)


func _step_crow(c: Dictionary, delta: float, lord: Vector3) -> void:
	var n: Node3D = c.n
	var flat: Vector3 = n.position - lord
	flat.y = 0.0
	if c.fly <= 0.0 and c.back <= 0.0 and flat.length() < CROW_FLEE:
		c.fly = 7.0 + _rng.randf() * 4.0
		var away: Vector3 = flat.normalized() if flat.length() > 0.1 else Vector3.RIGHT
		c.dir = (away.rotated(Vector3.UP, _rng.randf_range(-0.8, 0.8)) * 5.0 + Vector3(0, 3.0, 0))
	if c.fly > 0.0:
		c.fly -= delta
		n.position += c.dir * delta
		c.dir.y = maxf(c.dir.y - delta * 0.15, 0.4)
		n.rotation.y = atan2(c.dir.x, c.dir.z)
		var f: float = sin(Time.get_ticks_msec() * 0.03 + n.get_instance_id()) * 0.9
		(c.wl as Node3D).rotation.z = f
		(c.wr as Node3D).rotation.z = -f
		if c.fly <= 0.0:
			c.back = 20.0
	elif c.back > 0.0:
		c.back -= delta
		var to: Vector3 = (c.home as Vector3) - n.position
		if to.length() > 0.5 and c.back > 0.0:
			n.position += to.normalized() * minf(to.length(), 6.0 * delta)
			n.rotation.y = atan2(to.x, to.z)
			var f: float = sin(Time.get_ticks_msec() * 0.03) * 0.8
			(c.wl as Node3D).rotation.z = f
			(c.wr as Node3D).rotation.z = -f
		else:
			n.position = c.home
			c.back = 0.0
			(c.wl as Node3D).rotation.z = 0.0
			(c.wr as Node3D).rotation.z = 0.0
		if flat.length() < CROW_FLEE * 0.6 and c.back > 0.0:
			c.back = 0.0
			c.fly = 6.0
			c.dir = flat.normalized() * 5.0 + Vector3(0, 3.0, 0)


func _step_deer(d: Dictionary, delta: float, lord: Vector3) -> void:
	var n: Node3D = d.n
	var flat: Vector3 = n.position - lord
	flat.y = 0.0
	var dist: float = flat.length()
	if dist < DEER_FLEE:
		d.run = 4.0
	if d.run > 0.0:
		d.run -= delta
		var away: Vector3 = flat.normalized() if dist > 0.1 else Vector3.LEFT
		var np: Vector3 = n.position + away * 9.0 * delta
		np.x = clampf(np.x, 14.0, FieldLayout.WORLD_X - 14.0)
		np.z = clampf(np.z, 30.0, FieldLayout.WORLD_Z - 30.0)
		if absf(np.z - FieldBuilder.brook_z(np.x)) < 2.0:
			np.z += 3.0 * delta   # 물가를 건널 때만 걸린 듯 지나간다
		np.y = FieldBuilder.height(np.x, np.z)
		n.position = np
		n.rotation.y = lerp_angle(n.rotation.y, atan2(away.x, away.z), delta * 8.0)
		d.t += delta * 14.0
		var i: int = 0
		for leg in d.legs:
			(leg as Node3D).rotation.x = sin(d.t + (0.0 if i % 3 == 0 else PI)) * 0.7
			i += 1
	else:
		for leg in d.legs:
			(leg as Node3D).rotation.x = lerpf((leg as Node3D).rotation.x, 0.0, delta * 6.0)
