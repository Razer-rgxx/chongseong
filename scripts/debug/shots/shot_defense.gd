extends SceneTree
## 마을 방어전(docs/rift_raid.md) 확인용: 균열이 터진 채 마을에 들어서 적이 쏟아지는 모습. 저장 파일을 바꾸니 지워도 되는 곳에서만 돌린다.
## 그림은 /home/claude/shots/defense.png.


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	var meta := Meta.new()
	meta.anchor_hand = true
	meta.time_traveller = true
	meta.harvest_down = true
	meta.storage_house = true
	meta.mats = {&"wood": 60, &"stone": 80, &"iron": 40}
	for id in [&"cottage", &"woodcutter", &"mason", &"cottage2", &"longhouse", &"forge", &"stable", &"tower"]:
		meta.built[id] = true
	for n in ["돌쇠", "끝순", "덕배"]:
		meta.residents.append({"name": n, "look": FieldLayout.RESIDENT_LOOKS[meta.residents.size() % 4], "job": &""})
	meta.tier_seen = 2
	meta.rr_breach_pending = true
	meta.save()
	change_scene_to_file("res://scenes/lobby/lobby.tscn")
	await _frames(30)
	var lobby: Node = current_scene
	var rules: Rules = lobby.get("rules")
	(lobby.get("_camera") as Node).set("blur_allowed", false)
	rules.lord.pos = Vector2(17.0, 9.0)
	rules.lord.prev_pos = rules.lord.pos
	for i in 45:   # 그림을 찍는 동안 영주가 쓰러지지 않게(확인용)
		rules.lord.hp = 99999.0
		await process_frame
	print("enemies ", rules.enemies.size(), " defense ", lobby.get("_defense") != null)
	root.get_texture().get_image().save_png("/home/claude/shots/defense.png")
	print("shot defense")
	quit()
