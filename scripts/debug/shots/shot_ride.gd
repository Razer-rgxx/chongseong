extends SceneTree
## 탈 검 화면 점검: 부른 검이 곁에 뜬 모습, 올라선 모습, 빠르게 나는 모습(빠르기를 강제로 준다).
## 돌리기: xvfb-run -a godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s scripts/debug/shots/shot_ride.gd
## 그림은 /home/claude/shots/ride_<이름>.png.

const OUT: String = "/home/claude/shots/"


func _init() -> void:
	change_scene_to_file("res://scenes/field/field.tscn")
	for i in 30:
		await process_frame
	var f: Node = current_scene
	var rules: Rules = f.get("rules")
	rules.debug_god = true
	rules.field_clock = 60.0
	var cam: Node = f.get("_camera")
	var at := Vector2(40, 40)
	rules.lord.pos = at
	rules.lord.prev_pos = at
	rules.lord.face = 0.0
	cam.set("yaw", deg_to_rad(200.0))
	f.call("horse_key")
	var n: int = 0
	while rules.horse.state == Horse.COMING and n < 400:
		await process_frame
		n += 1
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(OUT + "ride_stand.png")
	rules.lord.pos = rules.horse.pos + Vector2(0.4, 0)
	rules.mount()
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_png(OUT + "ride_on.png")
	for i in 60:
		rules.lord.ride_vel = Vector2.RIGHT * rules.data.lord.speed * rules.data.horse.speed_mult
		rules.horse.speed = rules.lord.ride_vel.length()
		await process_frame
	root.get_texture().get_image().save_png(OUT + "ride_run.png")
	print("ride shots done")
	quit()
