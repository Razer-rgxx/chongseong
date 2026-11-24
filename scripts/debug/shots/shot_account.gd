extends SceneTree
## 로그인 창 확인용(docs/account.md). 돌리기: xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s scripts/debug/shots/shot_account.gd
## 그림은 /home/claude/shots/account.png. 가입 모드·인증 칸을 펼쳐 찍는다.


func _init() -> void:
	change_scene_to_file("res://scenes/title/title.tscn")
	var n: int = 0
	while (current_scene == null or current_scene.find_child("UiAccount", true, false) == null) and n < 600:
		await process_frame
		n += 1
	var w: AccountWindow = current_scene.find_child("UiAccount", true, false) as AccountWindow if current_scene else null
	if w == null:
		push_error("로그인 창이 없다")
		quit(1)
		return
	w._on_register()
	w._code_row.visible = true
	w._btn_resend.visible = true
	w._mail.text = "player@example.com"
	w._pass.text = "abc"
	for i in 5:
		await process_frame
	root.get_texture().get_image().save_png("/home/claude/shots/account.png")
	quit()
