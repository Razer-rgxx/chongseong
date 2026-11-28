extends SceneTree
## 대장간 그림 창 확인: 룬 박기 탭(미리보기·카드·룬 타일)과 검집 탭. 저장 파일은 끝나면 되돌린다.
## xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s scripts/debug/shots/shot_forge_pic.gd

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
	var hud: Node = lobby.get("_hud")
	meta.shards = 5400
	var n: int = 0
	for s in data.swords:
		if s.grade >= 2 and s.id % 9 == 0 and n < 14:
			meta.found[str(s.id)] = 1
			n += 1
	var first: int = 0
	for s in data.swords:
		if meta.has_found(s.id) and s.grade >= 2:
			first = s.id
			break
	print("first ", first)
	# 관리 명령 '기억'과 같게: 벤 적 수를 정하고 룬을 새긴다
	for s in data.swords:
		if meta.has_found(s.id):
			meta._log(s.id)["k"] = 1000 if s.id == first else 450
			meta.sync_runes(s.id)
	meta.rune_add("keen:3")
	meta.rune_add("night:2", 2)
	meta.rune_add("hunt:1")
	meta.rune_add("wind:3")
	meta.rune_add("grit:2")
	meta.rune_add("chain:1", 3)
	meta.socket_rune(first, "keen:1")
	hud.set("_forge_tab", 1)
	hud.call("open_forge")
	await _frames(60)
	await _shot("forge_pic")
	var g: Node = hud.get("_runes_ui")
	if g:
		g.set("pick_rune", "keen:3")
		g.call("_on_socket", 0)
		await _frames(20)
		g.call("_on_socket", 0)
		await _frames(30)
		await _shot("forge_pic_set")
	hud.set("_forge_tab", 0)
	hud.call("_render_forge", "")
	await _frames(40)
	await _shot("forge_pic_sheath")
	if keep != "":
		var f := FileAccess.open(Meta.SAVE_PATH, FileAccess.WRITE)
		f.store_string(keep)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Meta.SAVE_PATH))
	quit()
