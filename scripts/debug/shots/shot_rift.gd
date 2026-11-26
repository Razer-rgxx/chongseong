extends SceneTree
## 시대 균열(docs/rift_raid.md) 확인용: 들판의 균열(셰이더)과 균열에 망가진 마을. 저장 파일을 바꾸니 지워도 되는 곳에서만 돌린다.
## 그림은 /home/claude/shots/rift_*.png.

const OUT: String = "/home/claude/shots/"


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(4)
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("shot ", name)


func _init() -> void:
	var d := GameData.load_default()
	var meta := Meta.new()
	meta.anchor_hand = true
	meta.harvest_down = true
	meta.storage_house = true
	meta.mats = {&"wood": 60, &"stone": 80, &"iron": 40}
	for id in [&"cottage", &"woodcutter", &"mason", &"cottage2", &"longhouse", &"forge", &"stable", &"tower"]:
		meta.built[id] = true
	for n in ["돌쇠", "끝순", "덕배", "언년", "삼월", "칠복"]:
		meta.residents.append({"name": n, "look": FieldLayout.RESIDENT_LOOKS[meta.residents.size() % 4], "job": [&"woodcutter", &"mason", &""][meta.residents.size() % 3]})
	meta.tier_seen = 2
	meta.rr_open = true
	meta.rr_spot = 0
	meta.rr_left = 2
	meta.save()
	change_scene_to_file("res://scenes/field/field.tscn")
	await _frames(40)
	var field: Node = current_scene
	var rules: Rules = field.get("rules")
	var at: Vector2 = FieldLayout.RIFT_RAID_SPOTS[0]
	rules.lord.pos = at + Vector2(-0.9, 3.4)
	rules.lord.prev_pos = rules.lord.pos
	var cam: Node = field.get("_camera")
	cam.set("yaw", 0.0)
	cam.set("pitch", deg_to_rad(8.0))
	cam.set("third_distance", 6.0)
	await _frames(4)
	cam.call("snap")
	await _frames(60)
	await _shot("rift_field")
	# 균열이 터졌다: 마을에서 망가진 건물
	meta = field.get("meta")   # 장면이 나갈 때 제 Meta를 다시 저장하니 그 Meta를 고친다
	meta.rr_open = false
	var r: Dictionary = RiftRaid.breach(meta, d)
	meta.rr_ruined[&"forge"] = 1
	meta.rr_ruined[&"stable"] = 1
	meta.rr_ruined[&"cottage"] = 1
	meta.save()
	change_scene_to_file("res://scenes/lobby/lobby.tscn")
	await _frames(60)
	var lobby: Node = current_scene
	(lobby.get("_camera") as Node).set("blur_allowed", false)
	await _shot("rift_village_news")
	var top := Camera3D.new()
	top.attributes = CameraAttributesPractical.new()
	lobby.add_child(top)
	top.fov = 50.0
	top.make_current()
	top.look_at_from_position(Grid.cells_to_world(Vector2(43, 36), 15.0), Grid.cells_to_world(Vector2(43, 12), 0.0))
	await _frames(60)
	await _shot("rift_village")
	quit()
