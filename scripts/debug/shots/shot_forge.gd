extends SceneTree
## 대장간 확인용: 대장간 앞 → 창(강화 전) → 망치질 중 → 결과. 저장 파일은 건드리지 않게 meta를 고쳐 쓰고 save하지 않는다(창은 save를 부르니 끝나면 원래 파일을 되돌린다).
## 돌리기: xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility --fixed-fps 30 -s scripts/debug/shots/shot_forge.gd
## 그림은 /home/claude/shots/forge_*.png.

const OUT: String = "/home/claude/shots/"


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(3)
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("shot ", name)


func _init() -> void:
	var keep: String = FileAccess.get_file_as_string(Meta.SAVE_PATH) if FileAccess.file_exists(Meta.SAVE_PATH) else ""
	change_scene_to_file("res://scenes/lobby/lobby.tscn")
	await _frames(30)
	var lobby: Node = current_scene
	var meta: Meta = lobby.get("meta")
	var data: GameData = lobby.get("data")
	var rules: Rules = lobby.get("rules")
	var hud: Node = lobby.get("_hud")
	var cam: Node = lobby.get("_camera")
	var at: Vector2 = lobby.get("forge_at")
	meta.shards = 5000
	for s in data.swords:
		if s.grade >= 2 and s.id % 9 == 0:
			meta.found[str(s.id)] = 1
	meta.sheath_lv = 4
	meta.fix_sheath(data)
	meta.rng.seed = 7
	hud.call("refresh_top")
	lobby.call("_refresh_anvil")
	var stand := at + Vector2(0.0, 3.0)
	rules.lord.pos = stand
	rules.lord.prev_pos = stand
	cam.set("yaw", deg_to_rad(0.0))
	cam.set("pitch", deg_to_rad(12.0))
	cam.set("third_distance", 7.0)
	await _frames(3)
	cam.call("snap")
	await _shot("forge_place")
	lobby.call("_enter", &"forge", "대장간 견습", &"apprentice", ["검집 말씀이세요? 불은 지펴 두었어요."], Callable(hud, "open_forge"))
	await _frames(40)
	await _shot("forge_panel")
	hud.call("_forge_sheath")
	var gap: float = float(hud.get("forge_gap"))
	await _frames(int(30 * (gap * 2.0 + 0.32)))
	await _shot("forge_hammer")
	await _frames(int(30 * (gap + float(hud.get("result_delay")) - 0.1)))
	await _shot("forge_result")
	for i in 4:
		hud.call("_forge_sheath")
		await _frames(int(30 * (gap * 3.0 + float(hud.get("result_delay")) + 0.6)))
		await _shot("forge_result_%d" % i)
	if keep != "":
		var f := FileAccess.open(Meta.SAVE_PATH, FileAccess.WRITE)
		f.store_string(keep)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Meta.SAVE_PATH))
	quit()
