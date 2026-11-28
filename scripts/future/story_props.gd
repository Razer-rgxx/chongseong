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


## 미래 2막(2026-11-26): 거리의 기록 단말. 기둥 위 기울어진 화면, 안 읽었으면 청록으로 밝고 읽었으면 어둡다(set_read).
static func log_terminal(parent: Node3D, at: Vector3, read: bool) -> Node3D:
	var n := Node3D.new()
	n.name = "LogTerminal"
	n.position = at
	var post := BoxMesh.new()
	post.size = Vector3(0.35, 1.2, 0.35)
	var pm := MeshInstance3D.new()
	pm.mesh = post
	pm.material_override = _dark()
	pm.position = Vector3(0, 0.6, 0)
	n.add_child(pm)
	var scr := BoxMesh.new()
	scr.size = Vector3(0.9, 0.6, 0.06)
	var sm := MeshInstance3D.new()
	sm.name = "Screen"
	sm.mesh = scr
	sm.position = Vector3(0, 1.4, 0)
	sm.rotation_degrees = Vector3(-20, 0, 0)
	n.add_child(sm)
	parent.add_child(n)
	set_read(n, read)
	return n


static func set_read(n: Node3D, read: bool) -> void:
	var sm := n.get_node_or_null("Screen") as MeshInstance3D
	if sm:
		sm.material_override = _glow(Color(0.25, 0.4, 0.5), 0.4) if read else _glow(Color(0.35, 0.9, 1.0), 2.6)


## 시장 광장의 정보상 렌: 좁은 노점 판과 차양, 그 위에 떠 있는 홀로그램 반신(더하는 빛).
static func fixer(parent: Node3D, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = "Fixer"
	n.position = at
	var desk := BoxMesh.new()
	desk.size = Vector3(2.2, 1.0, 0.9)
	var dm := MeshInstance3D.new()
	dm.mesh = desk
	dm.material_override = _dark()
	dm.position = Vector3(0, 0.5, 0)
	n.add_child(dm)
	var roof := BoxMesh.new()
	roof.size = Vector3(2.6, 0.08, 1.4)
	var rm := MeshInstance3D.new()
	rm.mesh = roof
	rm.material_override = _glow(Color(1.0, 0.25, 0.7), 1.6)
	rm.position = Vector3(0, 2.7, 0.2)
	n.add_child(rm)
	var holo := ShaderMaterial.new()
	holo.shader = load("res://assets/future/neon_holo.gdshader")
	holo.set_shader_parameter("tint", Color(0.3, 0.9, 1.0))
	holo.set_shader_parameter("spin", 0.0)
	holo.set_shader_parameter("alpha", 0.6)
	var body := CapsuleMesh.new()
	body.radius = 0.32
	body.height = 1.0
	var bm := MeshInstance3D.new()
	bm.mesh = body
	bm.material_override = holo
	bm.position = Vector3(0, 1.55, 0)
	n.add_child(bm)
	var head := SphereMesh.new()
	head.radius = 0.2
	head.height = 0.4
	var hm := MeshInstance3D.new()
	hm.mesh = head
	hm.material_override = holo
	hm.position = Vector3(0, 2.25, 0)
	n.add_child(hm)
	var l := OmniLight3D.new()
	l.light_color = Color(0.35, 0.85, 1.0)
	l.light_energy = 1.2
	l.omni_range = 5.0
	l.position = Vector3(0, 2.0, 0.6)
	n.add_child(l)
	parent.add_child(n)
	return n
