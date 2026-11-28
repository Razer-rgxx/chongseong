extends SceneTree
## 건물 안(2026-11-21) 확인용: 대장간·성소·검 보관집·집·풀무간에 들어가 마주 선 사람과 오른쪽 창, 아래 대사.
## 그림은 /home/claude/shots/inside_<종류>.png. 저장 파일을 바꾸니 지워도 되는 곳에서만 돌린다.

const OUT: String = "/home/claude/shots/"


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	change_scene_to_file("res://scenes/lobby/lobby.tscn")
	await _frames(25)
	var meta: Meta = current_scene.get("meta")
	meta.storage_house = true
	for id in [&"cottage", &"woodcutter", &"forge"]:
		meta.built[id] = true
	meta.residents = [{"name": "끝순", "look": &"peasant2", "job": &""}]
	meta.save()
	change_scene_to_file("res://scenes/lobby/lobby.tscn")
	await _frames(30)
	var lobby: Node = current_scene
	var hud: Node = lobby.get("_hud")
	for key in ["forge", "shrine", "storage", "bld_cottage", "bld_forge"]:
		lobby.set("_near", key)
		lobby.call("_interact")
		await _frames(40)
		root.get_texture().get_image().save_png(OUT + "inside_%s.png" % key)
		print("shot ", key)
		hud.call("close")
		await _frames(30)
	quit()
