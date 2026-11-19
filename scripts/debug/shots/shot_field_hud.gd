extends SceneTree
## 들판 화면(나침반·곳 이름·낮밤·쥔 검)과 떨군 검 찍기. 그림 /home/claude/shots/field_hud.png.
func _init() -> void:
	change_scene_to_file("res://scenes/field/field.tscn")
	for i in 20: await process_frame
	var f: Node = current_scene
	var rules: Rules = f.get("rules")
	var meta: Meta = f.get("meta")
	var data: GameData = f.get("data")
	rules.debug_god = true
	meta.dropped = {"id": 1, "x": 58.0, "y": 92.0}
	f.call("_build_dropped")
	rules.lord.pos = Vector2(55, 99)
	rules.lord.prev_pos = rules.lord.pos
	rules.field_clock = 200.0
	var cam: Node = f.get("_camera")
	cam.set("yaw", deg_to_rad(-20.0))
	for i in 30: await process_frame
	root.get_texture().get_image().save_png("/home/claude/shots/field_hud.png")
	quit()
