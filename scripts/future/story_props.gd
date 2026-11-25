class_name StoryProps
extends RefCounted
## 타임트래블러 이야기의 소품(docs/stranger.md 4단계): 자료 조각(천천히 도는 푸른 결정)과 봉인 금고(문판). 기본 도형만, 세계에 글자 없음.


static func _glow(c: Color, e: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func _dark() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = FutureLayout.CONCRETE.darkened(0.4)
	m.roughness = 0.8
	m.metallic = 0.5
	return m


## 자료 조각 하나. 떠서 도는 작은 마름모 결정.
static func shard(parent: Node3D, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at + Vector3(0, 1.0, 0)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.32, 0.32, 0.32)
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = _glow(Color(0.45, 0.85, 1.0), 2.2)
	mi.rotation_degrees = Vector3(45, 0, 45)
	n.add_child(mi)
	n.set_script(load("res://scripts/future/story_spin.gd"))
	parent.add_child(n)
	return n


## 봉인 금고의 문판. 닫혀 있으면 붉은 줄이 켜져 있고, 열리면 푸른 줄로 바뀌며 판이 내려간다.
static func vault(parent: Node3D, at: Vector3, open: bool) -> Node3D:
	var n := Node3D.new()
	n.name = "Vault"
	n.position = at
	var slab := BoxMesh.new()
	slab.size = Vector3(4.0, 3.2, 0.5)
	var door := MeshInstance3D.new()
	door.name = "Door"
	door.mesh = slab
	door.material_override = _dark()
	door.position = Vector3(0, 1.6, 0)
	n.add_child(door)
	var bar := BoxMesh.new()
	bar.size = Vector3(0.12, 2.4, 0.06)
	var led := MeshInstance3D.new()
	led.name = "Led"
	led.mesh = bar
	led.position = Vector3(0, 1.6, -0.3)
	n.add_child(led)
	parent.add_child(n)
	set_open(n, open)
	return n


static func set_open(n: Node3D, open: bool) -> void:
	var led := n.get_node("Led") as MeshInstance3D
	led.material_override = _glow(Color(0.4, 0.8, 1.0) if open else Color(1.0, 0.25, 0.2), 2.0)
	(n.get_node("Door") as Node3D).position.y = -1.2 if open else 1.6
