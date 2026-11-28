class_name PropKick
extends Node3D
## 들판·무덤의 꾸밈 물건(통·상자·항아리·흩어진 돌)이 베기 근처에서 화면에서만 튀거나 넘어진다(docs/hit_juice.md).
## 규칙·막힘 표와 무관하다. 막힘 표에 든 물건은 "kickable" 모임에 넣지 않는다(넣은 것만 움직인다).
## 장면: var pk := PropKick.new(); add_child(pk); pk.setup(rules)  (물건을 다 지은 뒤에)
## 물건 만들기: PropKick.make(parent, &"barrel"|&"crate"|&"jar", 자리, yaw) 또는 아무 Node3D에 PropKick.tag(n, 무게).

const GROUP: StringName = &"kickable"

var _items: Array[Dictionary] = []
var _moving: int = 0


## 물건 하나를 튀길 수 있게 표시한다. mass가 클수록 덜 튄다(1 = 통).
static func tag(n: Node3D, mass: float = 1.0) -> void:
	n.add_to_group(GROUP)
	n.set_meta("kick_mass", mass)


## 통·상자·항아리를 짓는다. Blender 모델(barrel, crate)이 있으면 그것, 없으면 기본 도형.
static func make(parent: Node3D, kind: StringName, at: Vector3, yaw: float) -> Node3D:
	var n: Node3D
	if kind != &"jar" and VillageModels.available(String(kind)):
		n = VillageModels.make(String(kind))
	else:
		n = Node3D.new()
		var mi := MeshInstance3D.new()
		var m := StandardMaterial3D.new()
		m.roughness = 0.9
		if kind == &"crate":
			var b := BoxMesh.new()
			b.size = Vector3(0.7, 0.6, 0.7)
			mi.mesh = b
			mi.position.y = 0.3
			m.albedo_color = Color(0.3, 0.22, 0.14)
		elif kind == &"barrel":
			var c := CylinderMesh.new()
			c.top_radius = 0.32
			c.bottom_radius = 0.3
			c.height = 0.9
			c.radial_segments = 10
			mi.mesh = c
			mi.position.y = 0.45
			m.albedo_color = Color(0.28, 0.2, 0.12)
		else:
			var sp := SphereMesh.new()
			sp.radius = 0.28
			sp.height = 0.62
			sp.radial_segments = 10
			sp.rings = 6
			mi.mesh = sp
			mi.position.y = 0.31
			m.albedo_color = Color(0.26, 0.17, 0.12)
		mi.material_override = m
		n.add_child(mi)
	n.position = at
	n.rotation.y = yaw
	parent.add_child(n)
	tag(n, {&"barrel": 1.3, &"crate": 1.1, &"jar": 0.7}.get(kind, 1.0))
	return n


func setup(rules: Rules) -> void:
	for n in get_tree().get_nodes_in_group(GROUP):
		if n is Node3D:
			_items.append({"n": n, "home": (n as Node3D).global_position, "vel": Vector3.ZERO, "spin": Vector3.ZERO, "t": -1.0})
	rules.move_started.connect(_on_move)
	rules.move_area.connect(_on_move)
	set_process(false)


func _on_move(_move: StringName, info: Dictionary) -> void:
	var cell: Vector2 = info.get("at", Vector2.INF)
	if cell == Vector2.INF:
		return
	var at: Vector3 = Grid.cells_to_world(cell)
	var reach: float = Grid.cells_to_meters(float(info.get("reach", info.get("radius", 3.0)))) + Juice.KICK_REACH_PAD
	for it in _items:
		if float(it.t) >= 0.0 or it.has("done") or _moving >= Juice.KICK_MAX_MOVING:
			continue
		var n: Node3D = it.n
		if not is_instance_valid(n) or not n.is_inside_tree():
			continue
		var d: Vector3 = n.global_position - at
		d.y = 0.0
		if d.length() > reach:
			continue
		var dir: Vector3 = d.normalized() if d.length() > 0.05 else Vector3(0, 0, -1)
		var mass: float = float(n.get_meta("kick_mass", 1.0))
		var rng_k: float = (hash(n.get_instance_id()) % 100) / 100.0   # 꾸밈용, 규칙 랜덤 아님
		it.vel = dir * Juice.KICK_SPEED / mass * (0.7 + 0.5 * rng_k) + Vector3(0, 3.0 / mass, 0)
		it.spin = Vector3(dir.z, 0.3, -dir.x) * (6.0 + 4.0 * rng_k) / mass
		it.t = 0.0
		_moving += 1
		set_process(true)


func _process(delta: float) -> void:
	for it in _items:
		if float(it.t) < 0.0 or it.has("done"):
			continue
		var n: Node3D = it.n
		if not is_instance_valid(n):
			it.done = true
			_moving -= 1
			continue
		it.t += delta
		var v: Vector3 = it.vel
		v.y -= 14.0 * delta
		n.global_position += v * delta
		n.rotation += (it.spin as Vector3) * delta
		it.vel = v
		var home: Vector3 = it.home
		if n.global_position.y <= home.y or float(it.t) > Juice.KICK_LIFE:
			var p: Vector3 = n.global_position
			p.y = home.y
			n.global_position = p
			# 쓰러져 눕는다(굴러 온 방향 그대로 한쪽으로 기울어 멈춘다)
			n.rotation = Vector3(clampf(n.rotation.x, -1.45, 1.45), n.rotation.y, clampf(n.rotation.z, -1.45, 1.45))
			it.done = true
			_moving -= 1
	if _moving <= 0:
		_moving = 0
		set_process(false)
