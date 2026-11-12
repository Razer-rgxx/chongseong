extends Node3D
## 화풍 시범: 설계도 세계. 본 장면 위에 종이, 설계선, 짓는 연출, 번짐을 얹어 본다. 규칙은 건드리지 않는다.
## 이야기: 영지는 펼쳐진 설계도에서 태어난다. 지으면 선이 돌로 채워지고, 밤마다 번짐(먹물)이 와서 지운다.

const PAPER: Shader = preload("res://shaders/paper.gdshader")
const SOLID: Shader = preload("res://shaders/build_solid.gdshader")
const LINES: Shader = preload("res://shaders/build_lines.gdshader")
const SKETCH: Shader = preload("res://shaders/sketch.gdshader")
const OUTLINE: Shader = preload("res://shaders/outline.gdshader")
const INK: Shader = preload("res://shaders/ink.gdshader")
const STAIN: Shader = preload("res://shaders/ink_stain.gdshader")

@export var stone: Color = Color(0.52, 0.48, 0.42)
@export var roof: Color = Color(0.5, 0.2, 0.16)
@export var wood: Color = Color(0.4, 0.28, 0.18)
@export var build_time: float = 2.6
@export var hold_time: float = 1.4

## 짓는 연출이 도는 건물들: [{boxes: [[MeshInstance3D, 바닥 높이, 높이]], top: 꼭대기 높이}]
var _loops: Array[Dictionary] = []
var _t: float = 0.0
@onready var _main: Node3D = $Main


func _ready() -> void:
	var side: float = Grid.size * Grid.CELL
	var ground := _main.get_node("Ground") as MeshInstance3D
	(ground.mesh as PlaneMesh).size = Vector2(side * 3.0, side * 3.0)
	var pm := ShaderMaterial.new()
	pm.shader = PAPER
	pm.set_shader_parameter("map_meters", side)
	ground.material_override = pm
	(_main.get_node("Hall") as Node3D).visible = false
	var env := (_main.get_node("Environment") as WorldEnvironment).environment
	env.background_color = Color(0.03, 0.07, 0.14)
	env.ambient_light_color = Color(0.7, 0.8, 0.95)
	env.ambient_light_energy = 0.4
	(_main.get_node("Sun") as DirectionalLight3D).light_energy = 0.95
	(_main.get_node("Sun") as DirectionalLight3D).light_color = Color(1.0, 0.93, 0.82)
	(_main.get_node("Camera") as Camera3D).zoom = 0.8

	var c: Vector2i = Grid.center()
	# 영주관: 다 지어진 성
	_castle(c, 1.0)
	# 첫 성벽 고리. 남쪽 한 줄은 아직 설계선만 있다.
	for y in range(c.y - 3, c.y + 4):
		for x in range(c.x - 3, c.x + 4):
			var cell := Vector2i(x, y)
			if Grid.ring_distance(cell, c) != 3:
				continue
			var planned: bool = y == c.y + 3 and x >= c.x - 1 and x <= c.x + 1
			_wall(cell, 0.0 if planned else 1.0)
	# 짓는 중인 집과 성벽 한 칸(되풀이)
	_loops.append(_house(Vector2i(c.x + 2, c.y - 1), 0.0))
	_loops.append(_wall(Vector2i(c.x + 1, c.y + 3), 0.0))
	# 번짐에게 반쯤 지워진 망루와 그 곁의 번짐
	_tower(Vector2i(c.x - 5, c.y + 2), 0.42)
	_stain(Vector2i(c.x - 5, c.y + 2), 3.2, 1.0)
	_stain(Vector2i(c.x - 6, c.y + 4), 2.0, 2.0)
	_ink(Vector2(c.x - 5.6, c.y + 3.6), 0.55)
	_ink(Vector2(c.x + 4.4, c.y + 6.2), 0.42)
	_stain(Vector2i(c.x + 4, c.y + 6), 2.2, 3.0)
	# 놓기 전 미리보기: 설계선만 있는 망루
	_tower(Vector2i(c.x + 5, c.y + 2), 0.0)
	# 아직 손대지 않은 땅: 스케치로만 있는 나무와 바위
	for p in [Vector2i(c.x - 6, c.y - 3), Vector2i(c.x - 7, c.y - 1), Vector2i(c.x - 6, c.y + 6), Vector2i(c.x + 6, c.y - 4), Vector2i(c.x + 7, c.y + 5), Vector2i(c.x + 2, c.y + 7), Vector2i(c.x - 3, c.y + 7)]:
		_tree(p)
	for p in [Vector2i(c.x + 6, c.y - 1), Vector2i(c.x - 4, c.y - 6), Vector2i(c.x + 3, c.y - 6)]:
		_rock(p)
	# 실제로 있는 것(영주, 허수아비)에는 바깥선
	_outline(_main.get("_lord"))
	for v in (_main.get("_dummies") as Dictionary).values():
		_outline(v)


func _process(delta: float) -> void:
	_t += delta
	var cyc: float = build_time + hold_time
	var p: float = clampf(fmod(_t, cyc) / build_time, 0.0, 1.0)
	for b in _loops:
		var top: float = b.top
		for e in b.boxes:
			var mi: MeshInstance3D = e[0]
			_set_progress(mi, clampf((p * top - e[1]) / e[2], 0.0, 1.0))


func _box(parent: Node3D, center: Vector3, size: Vector3, color: Color, progress: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var solid := ShaderMaterial.new()
	solid.shader = SOLID
	solid.set_shader_parameter("half_size", size / 2.0)
	solid.set_shader_parameter("base_color", color)
	var lines := ShaderMaterial.new()
	lines.shader = LINES
	lines.set_shader_parameter("half_size", size / 2.0)
	solid.next_pass = lines
	mi.material_override = solid
	parent.add_child(mi)
	mi.position = center
	_set_progress(mi, progress)
	return mi


func _set_progress(mi: MeshInstance3D, p: float) -> void:
	var s := mi.material_override as ShaderMaterial
	s.set_shader_parameter("progress", p)
	(s.next_pass as ShaderMaterial).set_shader_parameter("progress", p)


## 상자들을 아래부터 차례로 채우는 건물 하나로 묶는다. parts: [가운데(칸 기준 m), 크기, 색]
func _group(cell: Vector2i, parts: Array, progress: float) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	root.position = Grid.cell_to_world(cell)
	var boxes: Array = []
	var top: float = 0.0
	for part in parts:
		var size: Vector3 = part[1]
		var mi := _box(root, part[0], size, part[2], progress)
		var bottom: float = (part[0] as Vector3).y - size.y / 2.0
		boxes.append([mi, bottom, size.y])
		top = maxf(top, bottom + size.y)
	var g := {"boxes": boxes, "top": top}
	if progress < 1.0 and progress > 0.0:
		for e in boxes:
			_set_progress(e[0], clampf((progress * top - e[1]) / e[2], 0.0, 1.0))
	return g


func _castle(cell: Vector2i, progress: float) -> Dictionary:
	var parts: Array = [[Vector3(0, 1.4, 0), Vector3(2.7, 2.8, 2.7), stone], [Vector3(0, 3.2, 0), Vector3(1.6, 0.8, 1.6), roof]]
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			parts.append([Vector3(sx * 1.35, 1.9, sz * 1.35), Vector3(0.9, 3.8, 0.9), stone])
	for i in range(-2, 3):
		parts.append([Vector3(i * 0.55, 3.0, 1.2), Vector3(0.3, 0.4, 0.3), stone])
		parts.append([Vector3(i * 0.55, 3.0, -1.2), Vector3(0.3, 0.4, 0.3), stone])
	return _group(cell, parts, progress)


func _wall(cell: Vector2i, progress: float) -> Dictionary:
	return _group(cell, [[Vector3(0, 0.65, 0), Vector3(1.96, 1.3, 1.96), stone], [Vector3(-0.5, 1.5, 0), Vector3(0.5, 0.4, 1.9), stone], [Vector3(0.5, 1.5, 0), Vector3(0.5, 0.4, 1.9), stone]], progress)


func _house(cell: Vector2i, progress: float) -> Dictionary:
	return _group(cell, [[Vector3(0, 0.6, 0), Vector3(1.7, 1.2, 1.5), wood], [Vector3(0, 1.45, 0), Vector3(1.9, 0.5, 1.7), roof], [Vector3(0, 1.9, 0), Vector3(1.1, 0.4, 1.0), roof]], progress)


func _tower(cell: Vector2i, progress: float) -> Dictionary:
	return _group(cell, [[Vector3(0, 1.3, 0), Vector3(1.1, 2.6, 1.1), stone], [Vector3(0, 2.8, 0), Vector3(1.5, 0.4, 1.5), wood], [Vector3(0, 3.25, 0), Vector3(0.9, 0.5, 0.9), roof]], progress)


func _sketch_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SKETCH
	return m


func _tree(cell: Vector2i) -> void:
	var at := Grid.cell_to_world(cell)
	var crown := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.85
	cone.height = 2.2
	crown.mesh = cone
	crown.material_override = _sketch_mat()
	crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crown)
	crown.position = at + Vector3(0, 1.75, 0)
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.14
	cyl.height = 0.7
	trunk.mesh = cyl
	trunk.material_override = _sketch_mat()
	trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trunk)
	trunk.position = at + Vector3(0, 0.35, 0)


func _rock(cell: Vector2i) -> void:
	var mi := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.7
	sp.height = 1.0
	sp.radial_segments = 7
	sp.rings = 4
	mi.mesh = sp
	mi.material_override = _sketch_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.position = Grid.cell_to_world(cell) + Vector3(0, 0.3, 0)
	mi.rotation = Vector3(0.2, 0.7, 0.1)


func _ink(at: Vector2, r: float) -> void:
	var mi := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = r
	sp.height = r * 1.7
	mi.mesh = sp
	var m := ShaderMaterial.new()
	m.shader = INK
	mi.material_override = m
	add_child(mi)
	mi.position = Grid.cells_to_world(at, r * 0.8)
	for s in [-1, 1]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = r * 0.12
		em.height = r * 0.24
		eye.mesh = em
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0.95, 0.85)
		mat.emission_enabled = true
		mat.emission = Color(1, 0.9, 0.7)
		mat.emission_energy_multiplier = 2.0
		eye.material_override = mat
		mi.add_child(eye)
		eye.position = Vector3(s * r * 0.32, r * 0.2, r * 0.82)


func _stain(cell: Vector2i, size: float, seed: float) -> void:
	var mi := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(size, size)
	mi.mesh = pl
	var m := ShaderMaterial.new()
	m.shader = STAIN
	m.set_shader_parameter("seed", seed)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.position = Grid.cell_to_world(cell, 0.02)


func _outline(n: Node) -> void:
	if n == null:
		return
	var o := ShaderMaterial.new()
	o.shader = OUTLINE
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var base: Material = m.get_surface_override_material(0) if m.get_surface_override_material_count() > 0 else null
		if base == null:
			base = m.material_override
		if base == null:
			continue
		var dup := base.duplicate() as Material
		dup.next_pass = o
		m.set_surface_override_material(0, dup)
