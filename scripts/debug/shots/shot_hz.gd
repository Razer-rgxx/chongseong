extends SceneTree
## 언덕 재설계 점검: 첫 구역 검 지도(이웃 줄), 깨어난 검과 다가오는 주인, 거래 창. 그림 /home/claude/shots/hz_*.png.

func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png("/home/claude/shots/hz_" + name + ".png")
	print("shot ", name)


func _init() -> void:
	change_scene_to_file("res://scenes/world/main.tscn")
	await _wait(40)
	var m: Node = current_scene
	var rules: Rules = m.get("rules")
	rules.debug_god = true
	var cam: Node = m.get("_camera")
	cam.set("blur_allowed", false)
	var h: Hilt = rules.hilts[0]
	rules.lord.pos = h.pos + Vector2(0.8, 0.8)
	rules.lord.prev_pos = rules.lord.pos
	cam.set("third_distance", 14.0)
	cam.set("pitch", deg_to_rad(40.0))
	await _wait(40)
	_shot("preview")
	rules.hz.blades[0].event = HillZone.Event.TRADE
	rules._hz_begin(0, Sword.new(rules.pick_sword(0), rules.data))
	await _wait(60)
	_shot("trade")
	rules.hz_answer(true)
	for t in 120:
		rules.step()
	await _wait(10)
	_shot("awake")
	quit()
