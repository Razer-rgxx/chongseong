extends SceneTree
## 검 보관집(2026-11-21) 확인용: 빈 터 → 집이 한 조각씩 올라가는 중 → 다 선 집과 검집 걸이 → 검집 창.
## 돌리기: xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s scripts/debug/shots/shot_storage.gd
## 그림은 /home/claude/shots/storage_*.png. 저장 파일은 건드리지 않게 meta를 새로 만들어 넣는다.

const OUT: String = "/home/claude/shots/"


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(4)
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("shot ", name)


func _init() -> void:
	change_scene_to_file("res://scenes/lobby/lobby.tscn")
	await _frames(30)
	var lobby: Node = current_scene
	var meta: Meta = lobby.get("meta")
	var rules: Rules = lobby.get("rules")
	var hud: Node = lobby.get("_hud")
	var cam: Node = lobby.get("_camera")
	var house: StorageHouse = lobby.get("_storage")
	var at: Vector2 = lobby.get("storage_at")
	meta.shards = 1000
	hud.call("refresh_top")
	var stand := at + Vector2(-2.7, 2.5)
	rules.lord.pos = stand
	rules.lord.prev_pos = stand
	rules.lord.face = -PI / 2.0
	cam.set("yaw", deg_to_rad(-40.0))
	cam.set("pitch", deg_to_rad(14.0))
	cam.set("third_distance", 8.0)
	await _frames(3)
	cam.call("snap")
	var built: bool = meta.storage_house
	if not built:
		await _shot("storage_site")
		hud.call("open_storage")
		await _shot("storage_site_panel")
		hud.call("_build_house")
		Engine.time_scale = 0.25
		var marks: Array[float] = [0.9, 1.9, 2.8]
		var mi: int = 0
		while house.raising():
			await _frames(1)
			var t: float = float(house.get("_t"))
			if mi < marks.size() and t >= marks[mi]:
				Engine.time_scale = 0.0
				await _shot("storage_raise_%d" % (mi + 1))
				Engine.time_scale = 0.25
				mi += 1
		Engine.time_scale = 1.0
	await _shot("storage_built")
	hud.call("open_storage")
	hud.call("_buy_sheath")
	await _shot("storage_panel")
	hud.call("close")
	await _shot("storage_sheath1")
	quit()
