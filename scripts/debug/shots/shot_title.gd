extends SceneTree
## 시작 화면 찍기: 밝아진 뒤(아무 키나 누르세요)와 메뉴. 그림은 /home/claude/shots/title_*.png.
## Xvfb의 소프트웨어 그리기는 초당 2장쯤이라 밝아지기(트윈)를 기다리지 않고 바로 끝난 상태로 놓는다.

func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	change_scene_to_file("res://scenes/title/title.tscn")
	await _frames(4)
	var s: Node = current_scene
	(s.get("_fade") as ColorRect).color.a = 0.0
	(s.get("_title") as Control).modulate.a = 1.0
	for tw in s.get_tree().get_processed_tweens():
		tw.kill()
	await _frames(6)
	root.get_texture().get_image().save_png("/home/claude/shots/title_prompt.png")
	s.call("_show_menu")
	for tw in s.get_tree().get_processed_tweens():
		tw.custom_step(5.0)
	await _frames(4)
	root.get_texture().get_image().save_png("/home/claude/shots/title_menu.png")
	quit()
