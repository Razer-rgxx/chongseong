extends SceneTree
## 길라잡이(2026-11-26) 확인용: 마을의 추적 줄·방향 띠·끝남 띠, G 창. 그림은 /home/claude/shots/guide_*.png.
## 저장 파일을 바꾸니 지워도 되는 곳에서만 돌린다.

const OUT: String = "/home/claude/shots/"


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(4)
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("shot ", name)


func _init() -> void:
	Meta.wipe()
	change_scene_to_file("res://scenes/lobby/lobby.tscn")
	await _frames(40)
	var lobby: Node = current_scene
	var meta: Meta = lobby.get("meta")
	var g: GuideHud = null
	for c in lobby.get_children():
		if c is GuideHud:
			g = c
	meta.heard["gatekeeper"] = [0]   # 첫 단계가 끝나는 모습
	await _frames(30)
	await _shot("guide_lobby")
	meta.guide_note("rack")
	meta.guide_note("run_start")
	meta.guide_note("pull")
	meta.guide_note("pull_good")
	meta.guide_note("night")
	await _frames(40)
	g.call("_open")
	await _shot("guide_window")
	quit()
