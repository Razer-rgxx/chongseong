class_name VillageModels
extends RefCounted
## 마을 소품의 Blender 모델(assets/village/models/<이름>.glb, tools/blender/make_village.py, docs/village_models.md).
## glb는 재질을 이름만 싣는다(wood, plank, log, stone, roof, iron, cloth ...). 여기서 이름마다 assets/village/의
## Poly Haven 질감을 입힌다(UV 1 = 1m라 tile이 곧 질감 한 장의 길이). 꼭짓점 색(COLOR_0)은 때·얼룩이라 곱해진다.
## glb가 없으면 available()이 거짓이고 VillageBuilder·VillageProps가 예전 기본 도형으로 짓는다.

const DIR: String = "res://assets/village/models/"

## 재질 이름 → [질감 폴더(없으면 ""), 질감 한 장 길이(m), 곱할 색, 거칠기, 금속, 양면]
const TABLE: Dictionary = {
	"wood": ["brown_planks_05", 1.2, Color(0.64, 0.52, 0.42), 0.9, 0.0, false],
	"plank": ["raw_plank_wall", 1.5, Color(0.58, 0.5, 0.43), 0.92, 0.0, false],
	"log": ["bark_brown_02", 1.0, Color(0.78, 0.7, 0.62), 1.0, 0.0, false],
	"logend": ["raw_plank_wall", 0.5, Color(0.72, 0.58, 0.44), 0.95, 0.0, false],
	"stone": ["mossy_stone_wall", 2.2, Color(0.95, 0.95, 0.9), 0.95, 0.0, false],
	"stone_dark": ["old_stone_wall", 2.0, Color(0.55, 0.52, 0.5), 1.0, 0.0, false],
	"mortar": ["old_stone_wall", 2.0, Color(0.38, 0.36, 0.34), 1.0, 0.0, false],
	"roof": ["roof", 1.8, Color(0.62, 0.56, 0.52), 0.95, 0.0, false],
	"iron": ["", 1.0, Color(0.36, 0.36, 0.39), 0.62, 0.75, false],
	"steel": ["", 1.0, Color(0.78, 0.8, 0.84), 0.38, 0.9, false],
	"brass": ["", 1.0, Color(0.62, 0.48, 0.24), 0.45, 0.7, false],
	"rope": ["", 1.0, Color(0.55, 0.44, 0.28), 1.0, 0.0, false],
	"sack": ["", 1.0, Color(0.46, 0.39, 0.29), 1.0, 0.0, true],
	"straw": ["", 1.0, Color(0.62, 0.5, 0.27), 1.0, 0.0, true],
	"cloth": ["", 1.0, Color(0.34, 0.12, 0.13), 1.0, 0.0, true],
	"cloth_gold": ["", 1.0, Color(0.66, 0.54, 0.2), 1.0, 0.0, true],
	"cloth_red": ["", 1.0, Color(0.46, 0.12, 0.14), 1.0, 0.0, true],
	"paper": ["", 1.0, Color(0.56, 0.5, 0.36), 1.0, 0.0, true],
	"leather": ["", 1.0, Color(0.3, 0.2, 0.12), 0.8, 0.0, false],
	"wicker": ["", 1.0, Color(0.5, 0.38, 0.2), 1.0, 0.0, false],
	"dirt": ["forest_ground_04", 3.0, Color(0.55, 0.5, 0.46), 1.0, 0.0, false],
	"burnt": ["", 1.0, Color(0.1, 0.085, 0.07), 1.0, 0.0, true],
	"water": ["", 1.0, Color(0.02, 0.03, 0.04), 0.05, 0.0, false],
	"mirror": ["", 1.0, Color(0.5, 0.56, 0.62), 0.18, 0.85, false],
	"glow": ["", 1.0, Color(1.0, 0.62, 0.3), 0.5, 0.0, false],
	"ember": ["", 1.0, Color(1.0, 0.4, 0.12), 0.6, 0.0, false],
}

static var _scenes: Dictionary = {}
static var _mats: Dictionary = {}


static func available(name: String) -> bool:
	return ResourceLoader.exists(DIR + name + ".glb")


static func _mat(name: String, tint: Variant) -> Material:
	var key: String = "%s|%s" % [name, tint]
	if _mats.has(key):
		return _mats[key]
	var row: Array = TABLE.get(name, TABLE["wood"])
	var m: StandardMaterial3D
	var folder: String = row[0]
	var color: Color = tint if tint is Color else row[2]
	if folder != "" and VillageMaterials.has(folder):
		m = VillageMaterials.get_mat(folder, color, row[1], color).duplicate()
		m.uv1_triplanar = false
		m.uv1_world_triplanar = false
		m.uv1_scale = Vector3(1.0 / float(row[1]), 1.0 / float(row[1]), 1.0)
		m.albedo_color = color
	else:
		m = StandardMaterial3D.new()
		m.albedo_color = color
		if name in ["sack", "straw", "cloth", "cloth_gold", "cloth_red", "burnt", "paper", "wicker", "leather", "rope", "dirt"]:
			# 짠 천·짚의 잔결: 잡음 질감을 어둡게 깔아 밋밋함을 던다
			var base: StandardMaterial3D = VillageBuilder.noise_mat("vm_" + name, Color(0.62, 0.62, 0.62), Color(1.0, 1.0, 1.0), 0.6, 0.45, 1.0)
			m.albedo_texture = base.albedo_texture
			m.normal_enabled = true
			m.normal_texture = base.normal_texture
			m.uv1_triplanar = true
			m.uv1_world_triplanar = false
			m.uv1_scale = Vector3.ONE / 0.6
	m.roughness = row[3]
	m.metallic = row[4]
	m.vertex_color_use_as_albedo = true
	if bool(row[5]):
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if name == "glow" or name == "ember":
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.5 if name == "glow" else 3.0
		m.albedo_color = color * 0.12
		m.vertex_color_use_as_albedo = false
	_mats[key] = m
	return m


static func _dress(n: Node, tints: Dictionary) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			for s in mi.mesh.get_surface_count():
				var src := mi.mesh.surface_get_material(s)
				var nm: String = String(src.resource_name) if src else "wood"
				mi.set_surface_override_material(s, _mat(nm, tints.get(nm)))
	for c in n.get_children():
		_dress(c, tints)


## 모델 하나를 지어 돌려준다(원점이 발밑, 앞이 +Z). tints: {재질 이름: Color}로 그 재질만 다른 색으로.
static func make(name: String, tints: Dictionary = {}) -> Node3D:
	if not _scenes.has(name):
		_scenes[name] = load(DIR + name + ".glb")
	var ps: PackedScene = _scenes[name]
	var n: Node3D = Node3D.new()
	if ps != null:
		var inst := ps.instantiate() as Node3D
		if inst != null:
			n = inst
	_dress(n, tints)
	n.name = name
	return n


static func put(parent: Node3D, name: String, at: Vector3, yaw: float = 0.0, scale: float = 1.0, tints: Dictionary = {}) -> Node3D:
	var n := make(name, tints)
	n.position = at
	n.rotation.y = yaw
	n.scale = Vector3.ONE * scale
	parent.add_child(n)
	return n


## 첫 메시(MultiMesh용). 재질은 여기서 입혀 돌려준다.
static func mesh_of(name: String, tints: Dictionary = {}) -> Mesh:
	var n := make(name, tints)
	var found: Mesh = null
	var stack: Array[Node] = [n]
	while not stack.is_empty() and found == null:
		var c: Node = stack.pop_back()
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			var mi := c as MeshInstance3D
			var d := mi.mesh.duplicate() as Mesh
			for s in d.get_surface_count():
				d.surface_set_material(s, mi.get_surface_override_material(s))
			found = d
		for k in c.get_children():
			stack.append(k)
	n.free()
	return found
