extends SceneTree
## 영주 몸의 단면을 망토 받침 좌표로 찍는다(망토 collider를 맞출 때 쓴다).
## 받침 좌표: 원점 = 망토를 다는 자리(등 뼈 + CHAR_CAPE_AT), 몸이 도는 쪽(yaw)만 따르고 숙이거나 젖힌 것은 안 따른다(LordView._sway_cape와 같다). 위 +Y, 등 쪽 +Z.
## godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s scripts/debug/dump_body_profile.gd -- rest|anim

func _frames(n: int) -> void:
	for i in n:
		await process_frame


## 스킨을 CPU로 풀어 한 자세의 몸 꼭짓점(월드)을 모은다.
func _skinned(skel: Skeleton3D) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for node in skel.get_parent().find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or "Cos" in str(mi.get_path()) or mi.get_parent() is BoneAttachment3D:
			continue
		for s in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones = arr[Mesh.ARRAY_BONES]
			var ws = arr[Mesh.ARRAY_WEIGHTS]
			var skin: Skin = mi.skin
			for i in vs.size():
				if bones == null or skin == null:
					pts.append(skel.global_transform * (mi.transform * vs[i]))
					continue
				var acc := Vector3.ZERO
				var tot: float = 0.0
				for k in 4:
					var w: float = ws[i * 4 + k]
					if w <= 0.0:
						continue
					var bi: int = skin.get_bind_bone(bones[i * 4 + k])
					if bi < 0:
						bi = skel.find_bone(skin.get_bind_name(bones[i * 4 + k]))
					var xf: Transform3D = skel.get_bone_global_pose(bi) * skin.get_bind_pose(bones[i * 4 + k])
					acc += (xf * vs[i]) * w
					tot += w
				pts.append(skel.global_transform * (acc / maxf(tot, 0.0001)))
	return pts


func _init() -> void:
	var mode: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "anim"
	var meta := Meta.new()
	meta.cos_unlock_all()
	meta.save()
	change_scene_to_file("res://scenes/lobby/lobby.tscn")
	await _frames(40)
	var lord_view: Node3D = current_scene.get("_lord")
	lord_view.call("set_cosmetics", {"cape": "cape_night"})
	await _frames(5)
	var ch: Node = lord_view.get("character")
	var skel: Skeleton3D = ch.get("_skel")
	var holder: Node3D = skel.find_child("CosCapeHolder", true, false) as Node3D
	var samples: int = 1 if mode == "rest" else 8
	var lo: Dictionary = {}
	var per: Dictionary = {}   # 칸 → 자세마다의 등 쪽 끝
	for n in samples:
		if mode == "rest":
			skel.reset_bone_poses()
		else:
			await _frames(17)
		var hg: Transform3D = holder.global_transform
		if mode == "rest":
			var rest: Transform3D = skel.get_bone_global_rest(skel.find_bone(CosmeticRig.CHAR_BACK_BONE))
			var flip := Basis(Vector3.UP, PI)
			hg = skel.global_transform * Transform3D(flip, rest.origin + flip * CosmeticRig.CHAR_CAPE_AT)
		var f: Vector3 = -hg.basis.z
		var yaw: float = atan2(-f.x, -f.z)
		var frame := Transform3D(Basis(Vector3.UP, yaw), hg.origin)
		var inv: Transform3D = frame.affine_inverse()
		var pts: PackedVector3Array = _skinned(skel)
		var local := PackedVector3Array()
		for p0 in pts:
			local.append(inv * p0)
		var cur: Dictionary = {}
		for b in 28:
			var y: float = 0.4 - 0.05 * b
			for p in local:
				if p.y > y or p.y <= y - 0.05 or absf(p.x) > 0.26 or p.z < -0.5:
					continue
				cur[b] = maxf(cur.get(b, -9.0), p.z)
				pass
		for b in cur:
			per[b] = per.get(b, []) + [cur[b]]
		if n == 0 and mode != "rest":
			print("yaw ", yaw, " holder origin ", hg.origin)
	for b in 28:
		if per.has(b):
			var a: Array = per[b]
			var mean: float = 0.0
			for v in a:
				mean += v / a.size()
			print("y %.2f back mean=%.3f min=%.3f max=%.3f" % [0.4 - 0.05 * b - 0.025, mean, a.min(), a.max()])
	quit()
