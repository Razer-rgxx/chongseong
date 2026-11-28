class_name KitHouse
extends RefCounted
## 조립식 집(2026-11-21): Quaternius Medieval Village MegaKit(CC0, assets/buildings/kit/)의 벽·모서리·지붕·박공·굴뚝을 2m 칸에 맞춰 놓는다.
## 1층은 거친 돌벽, 2층은 회벽에 나무 뼈대. 앞(+Z) 가운데에 문, 나머지는 창과 벽을 섞는다.
## 빛깔은 어두운 사실풍에 맞게 낮추고 채도를 뺀다(_dim). 키트가 없으면 available()이 거짓이고 VillageBuilder.house가 상자로 짓는다.

const DIR: String = "res://assets/buildings/kit/"
const SEG: float = 2.0
const STORY: float = 3.12
## 지붕 이름에 있는 크기(너비x깊이, 칸이 아니라 m).
const ROOFS: Array[Vector2i] = [Vector2i(4, 4), Vector2i(4, 6), Vector2i(4, 8), Vector2i(6, 6), Vector2i(6, 8), Vector2i(8, 8), Vector2i(8, 10)]

static var _scenes: Dictionary = {}
static var _mats: Dictionary = {}


static func available() -> bool:
	return ResourceLoader.exists(DIR + "Wall_UnevenBrick_Straight.gltf")


static func piece(parent: Node3D, name: String, at: Vector3, yaw: float = 0.0, scale: Vector3 = Vector3.ONE) -> Node3D:
	if not _scenes.has(name):
		_scenes[name] = load(DIR + name + ".gltf")
	var ps: PackedScene = _scenes[name]
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	n.position = at
	n.rotation.y = yaw
	n.scale = scale
	parent.add_child(n)
	_dim(n)
	return n


## 키트의 밝고 고운 색을 낮춘다: 조금 어둡게, 채도를 빼고, 거칠게.
static func _dim(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if m == null:
				continue
			if not _mats.has(m):
				var d := m.duplicate() as BaseMaterial3D
				if d:
					# 텍스처 색에 곱하는 값: 붉은 기와와 흰 회벽이 튀지 않게 붉은빛을 더 누른다
					var tiles: bool = str(m.resource_name).contains("RoundTiles")
					d.albedo_color = Color(0.42, 0.4, 0.4) if tiles else Color(0.6, 0.57, 0.53)
					d.roughness = maxf(d.roughness, 0.9)
				_mats[m] = d if d else m
			mi.set_surface_override_material(s, _mats[m])
	for c in n.get_children():
		_dim(c)


## size(너비 x, 깊이 z, m)에 가장 가까운 칸 수로 집을 짓는다. h는 앞이 +Z인 노드. 굴뚝 끝(h 기준)을 돌려준다.
static func build(h: Node3D, size: Vector2, two_story: bool, rng: RandomNumberGenerator) -> Vector3:
	var r: Vector2i = _roof_for(size)
	var nx: int = r.x / 2
	var nz: int = r.y / 2
	var W: float = float(r.x)
	var D: float = float(r.y)
	var kit := Node3D.new()
	kit.name = "Kit"
	h.add_child(kit)
	# 키트 크기를 원래 터에 맞춘다(마을 배치와 막힘은 원래 크기를 쓴다)
	kit.scale = Vector3(size.x / W, 1.0, size.y / D) * Vector3(1, 0.86, 1)
	var stories: int = 2 if two_story else 1
	var door_i: int = nx / 2
	for st in stories:
		var y: float = STORY * st
		var ground: bool = st == 0
		# 앞(+Z)·뒤·옆
		for side in 4:
			var count: int = nx if side < 2 else nz
			for i in count:
				var off: float = -float(count) * SEG / 2.0 + SEG * (float(i) + 0.5)
				var at: Vector3
				var yaw: float
				match side:
					0: at = Vector3(off, y, D / 2.0); yaw = 0.0
					1: at = Vector3(-off, y, -D / 2.0); yaw = PI
					2: at = Vector3(W / 2.0, y, -off); yaw = PI / 2.0
					_: at = Vector3(-W / 2.0, y, off); yaw = -PI / 2.0
				var wn: String = _wall_name(ground, side == 0 and i == door_i, rng)
				piece(kit, wn, at, yaw)
				# 문짝·창유리는 벽과 같은 자리에 끼운다
				var fill: String = _fill_for(wn)
				if fill != "":
					piece(kit, fill, at, yaw)
		for cx in [-1.0, 1.0]:
			for cz in [-1.0, 1.0]:
				piece(kit, "Corner_Exterior_Brick" if ground else "Corner_Exterior_Wood", Vector3(cx * W / 2.0, y, cz * D / 2.0), atan2(cx, cz) - PI / 4.0)
	var top: float = STORY * float(stories)
	piece(kit, "Roof_RoundTiles_%dx%d" % [r.x, r.y], Vector3(0, top, 0))
	var gable: String = "Roof_Front_Brick%d" % r.x
	if ResourceLoader.exists(DIR + gable + ".gltf"):
		piece(kit, gable, Vector3(0, top, D / 2.0))
		piece(kit, gable, Vector3(0, top, -D / 2.0), PI)
	var cx2: float = (W / 2.0 - 1.0) * (1.0 if rng.randf() < 0.5 else -1.0)
	piece(kit, "Prop_Chimney", Vector3(cx2, top, -D / 4.0))
	return Vector3(cx2 * kit.scale.x, (top + 3.3) * kit.scale.y, -D / 4.0 * kit.scale.z)


static func _wall_name(ground: bool, door: bool, rng: RandomNumberGenerator) -> String:
	if ground:
		if door:
			return "Wall_UnevenBrick_Door_Round"
		var k: float = rng.randf()
		return "Wall_UnevenBrick_Window_Wide_Round" if k < 0.35 else ("Wall_UnevenBrick_Window_Thin_Round" if k < 0.55 else "Wall_UnevenBrick_Straight")
	var u: float = rng.randf()
	return "Wall_Plaster_Window_Wide_Flat" if u < 0.4 else ("Wall_Plaster_WoodGrid" if u < 0.7 else "Wall_Plaster_Straight")


static func _fill_for(wall: String) -> String:
	if wall.contains("Door_Round"):
		return "Door_1_Round"
	if wall.contains("Door_Flat"):
		return "Door_1_Flat"
	if wall.contains("Window_Wide_Round"):
		return "Window_Wide_Round1"
	if wall.contains("Window_Wide_Flat"):
		return "Window_Wide_Flat1"
	if wall.contains("Window_Thin_Round"):
		return "Window_Thin_Round1"
	return ""


static func _roof_for(size: Vector2) -> Vector2i:
	var best: Vector2i = ROOFS[0]
	var bd: float = INF
	for r in ROOFS:
		var dd: float = absf(float(r.x) - size.x) + absf(float(r.y) - size.y)
		if dd < bd:
			bd = dd
			best = r
	return best
