class_name PropKick
extends Node3D
## 들판·무덤·미래·과거·언덕(마을 빼고)의 작은 꾸밈 물건(통·상자·항아리·돌·뼈·잔해 …)이 베기 근처에서 화면에서만 튀거나 넘어진다(docs/hit_juice.md).
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


## 땅 높이를 알려 주는 함수(x, z) -> float. 있으면 튄 물건이 비탈에서도 제 높이 차이로 내려앉는다.
var height_of: Callable = Callable()
var _rules: Rules = null
var _grid: Dictionary = {}   # Vector2i(8m 칸) -> Array[int] (_items 번호): 근처 것만 검사하려는 공간 해시

const CELL_M: float = 8.0


## auto: true면 (마을 말고) 장면 전체의 작은 꾸밈 물건을 자동으로 모아 "kickable"에 넣는다(한 프레임 뒤에 한 번 훑는다).
func setup(rules: Rules, auto: bool = true) -> void:
	_rules = rules
	rules.move_started.connect(_on_move)
	rules.move_area.connect(_on_move)
	set_process(false)
	_collect.call_deferred(auto)


func _collect(auto: bool) -> void:
	if not is_inside_tree():
		return
	if auto:
		_scan(get_parent())
	for n in get_tree().get_nodes_in_group(GROUP):
		if n is Node3D and not (n as Node3D).has_meta("kick_seen"):
			(n as Node3D).set_meta("kick_seen", true)
			var gp: Vector3 = (n as Node3D).global_position
			_items.append({"n": n, "home": gp, "vel": Vector3.ZERO, "spin": Vector3.ZERO, "t": -1.0})
			var key := Vector2i(floori(gp.x / CELL_M), floori(gp.z / CELL_M))
			if not _grid.has(key):
				_grid[key] = []
			(_grid[key] as Array).append(_items.size() - 1)


## 훑기: 스크립트가 없는 노드만 내려가고, 하위 전체가 작으면(발자국 ≤ SCAN_XZ, 높이 SCAN_Y_MIN~SCAN_Y_MAX, 메시 ≤ SCAN_PARTS) 한 물건으로 본다.
## 불·빛·입자·뼈대·여러개메시(풀)·카메라·영역이 든 것, 이미 모임에 든 것, 막힘 표 위의 것은 뺀다. 큰 구조물·벽·나무·건물은 크기에서 걸러진다.
func _scan(n: Node) -> void:
	for c in n.get_children():
		if c == self or not (c is Node3D) or not (c as Node3D).visible:
			continue
		if c.get_script() != null or c.is_in_group(GROUP) or _skip_name(String(c.name)):
			continue
		var acc: Array = [AABB(), 0]   # [합친 상자, 메시 수]
		var ok: bool = _measure(c, acc)
		var box: AABB = acc[0]
		if ok and int(acc[1]) > 0 and box.size.y >= Juice.SCAN_Y_MIN and box.size.y <= Juice.SCAN_Y_MAX \
				and maxf(box.size.x, box.size.z) <= Juice.SCAN_XZ and maxf(box.size.x, box.size.z) >= 0.12:
			var at: Vector3 = (c as Node3D).global_position
			if _on_blocker(at):
				continue
			tag(c as Node3D, clampf(0.6 + box.size.x * box.size.y * box.size.z * 1.2, 0.7, 3.0))
		elif not ok or int(acc[1]) > 0:
			_scan(c)   # 크거나 안 맞는다: 안으로 내려가 더 작은 것을 찾는다


static func _skip_name(nm: String) -> bool:
	var l: String = nm.to_lower()
	for w in ["chest", "cache", "glint", "altar", "portal", "rift", "terminal", "vault", "gate", "door", "ship", "beacon", "npc", "fixer", "sign", "ground", "terrain", "water", "sky", "grass", "wall", "pillar", "tree", "trunk"]:
		if l.contains(w):
			return true
	return false


func _on_blocker(at: Vector3) -> bool:
	if _rules == null or _rules.nav == null:
		return false
	return not _rules.nav.free_at(Grid.world_to_cells(at), 0)


## 하위 전체의 상자를 합친다. 크기·수가 넘거나 안 되는 노드가 있으면 false(일찍 그만둔다).
func _measure(n: Node, acc: Array) -> bool:
	if n.get_script() != null:
		return false   # 스크립트가 있는 부품은 움직임·상호작용이 있는 것
	if n is Light3D or n is GPUParticles3D or n is CPUParticles3D or n is Skeleton3D or n is MultiMeshInstance3D or n is Camera3D or n is Area3D or n is CollisionObject3D or n is AnimationPlayer or n is Decal:
		return false
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mi := n as MeshInstance3D
		var box: AABB = mi.global_transform * mi.get_aabb()
		acc[0] = box if int(acc[1]) == 0 else (acc[0] as AABB).merge(box)
		acc[1] = int(acc[1]) + 1
		var sz: Vector3 = (acc[0] as AABB).size
		if int(acc[1]) > Juice.SCAN_PARTS or maxf(sz.x, sz.z) > Juice.SCAN_XZ or sz.y > Juice.SCAN_Y_MAX:
			return false
	for c in n.get_children():
		if c is Node3D and not _measure(c, acc):
			return false
	return true


func _on_move(_move: StringName, info: Dictionary) -> void:
	var cell: Vector2 = info.get("at", Vector2.INF)
	if cell == Vector2.INF or _items.is_empty():
		return
	var at: Vector3 = Grid.cells_to_world(cell)
	var reach: float = Grid.cells_to_meters(float(info.get("reach", info.get("radius", 3.0)))) + Juice.KICK_REACH_PAD
	var x0: int = floori((at.x - reach) / CELL_M)
	var x1: int = floori((at.x + reach) / CELL_M)
	var z0: int = floori((at.z - reach) / CELL_M)
	var z1: int = floori((at.z + reach) / CELL_M)
	for gx in range(x0, x1 + 1):
		for gz in range(z0, z1 + 1):
			var lst: Array = _grid.get(Vector2i(gx, gz), [])
			for idx in lst:
				_try_kick(_items[idx], at, reach)


func _try_kick(it: Dictionary, at: Vector3, reach: float) -> void:
	if float(it.t) >= 0.0 or it.has("done") or _moving >= Juice.KICK_MAX_MOVING:
		return
	var n: Node3D = it.n
	if not is_instance_valid(n) or not n.is_inside_tree():
		return
	var d: Vector3 = n.global_position - at
	d.y = 0.0
	if d.length() > reach:
		return
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
		var gy: float = home.y
		if height_of.is_valid():
			gy = home.y + float(height_of.call(n.global_position.x, n.global_position.z)) - float(height_of.call(home.x, home.z))
		if (n.global_position.y <= gy and float(it.t) > 0.05) or float(it.t) > Juice.KICK_LIFE:
			var p: Vector3 = n.global_position
			p.y = gy
			n.global_position = p
			# 쓰러져 눕는다(굴러 온 방향 그대로 한쪽으로 기울어 멈춘다)
			n.rotation = Vector3(clampf(n.rotation.x, -1.45, 1.45), n.rotation.y, clampf(n.rotation.z, -1.45, 1.45))
			it.done = true
			_moving -= 1
	if _moving <= 0:
		_moving = 0
		set_process(false)
