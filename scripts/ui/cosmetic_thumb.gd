class_name CosmeticThumb
extends RefCounted
## 꾸미기 창의 타일 그림(docs/cosmetics.md): 항목 하나를 작은 3D 그림으로. 망토는 어깨 막대 아래에, 머리는 어두운 마네킹 머리 위에 걸쳐 한 번만 그린다.


static func make(it: CosmeticItem, size: Vector2i) -> SubViewportContainer:
	var cont := SubViewportContainer.new()
	cont.stretch = true
	var vp := SubViewport.new()
	vp.size = size
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	cont.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.66, 0.62)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	sun.light_energy = 1.0
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 32.0
	vp.add_child(cam)
	var dummy := StandardMaterial3D.new()
	dummy.albedo_color = Color(0.2, 0.19, 0.18)
	dummy.roughness = 0.9
	if it.slot == &"cape":
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.82, 0.12, 0.3)
		bar.mesh = bm
		bar.material_override = dummy
		bar.position = Vector3(0, 0.04, -0.02)
		vp.add_child(bar)
		var c: Node3D = CosmeticArt.cape(it)
		vp.add_child(c)
		cam.position = Vector3(0.2, -0.45, 2.6)
		cam.look_at_from_position(cam.position, Vector3(0, -0.45, 0))
	else:
		var head := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		head.mesh = sm
		head.material_override = dummy
		vp.add_child(head)
		var h: Node3D = CosmeticArt.head(it)
		vp.add_child(h)
		var wide: float = 4.4 if it.style == &"kettle" else 3.2
		cam.position = Vector3(-1.6, 1.0, -wide - 1.2)
		cam.look_at_from_position(cam.position, Vector3(0, 0.2, 0))
	return cont
