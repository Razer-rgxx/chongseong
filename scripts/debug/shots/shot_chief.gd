extends SceneTree
## 32단계 확인용: 곳마다 우두머리를 깨워 싸우는 화면과 아래 체력 막대.
## 돌리기: xvfb-run -a godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s scripts/debug/shots/shot_chief.gd [-- 우두머리 id …]
## 그림은 /home/claude/shots/chief_<id>.png. 첫 우두머리의 그림은 chief.png로도 남긴다. 저장 파일은 건드리지 않는다.

const OUT: String = "/home/claude/shots/"
## id → [영주가 설 자리(제자리에서), 카메라 yaw(도), 시계(초)]
const VIEW: Dictionary = {
	"chief_hamlet": [Vector2(-3, 7), 15.0, 60.0],
	"chief_tower": [Vector2(-7, 0), 270.0, 60.0],
	"chief_grove": [Vector2(0, -6), 180.0, 60.0],
	"chief_foot": [Vector2(0, 7), 0.0, 60.0],
	"chief_keep": [Vector2(-6, 0), 270.0, 60.0],
	"chief_marsh": [Vector2(0, -7), 180.0, 60.0],
	"chief_quarry": [Vector2(-7, 0), 270.0, 60.0],
	"chief_pass": [Vector2(-6, 0), 270.0, 300.0],
}


func _init() -> void:
	var ids: Array = Array(OS.get_cmdline_user_args())
	if ids.is_empty():
		ids = VIEW.keys()
	change_scene_to_file("res://scenes/field/field.tscn")
	for i in 30:
		await process_frame
	var f: Node = current_scene
	var rules: Rules = f.get("rules")
	rules.debug_god = true
	var cam: Node = f.get("_camera")
	var first: bool = true
	for id in ids:
		var v: Array = VIEW[id]
		var home: Vector2 = FieldLayout.CHIEFS[id].at
		rules.field_clock = float(v[2])
		rules.lord.pos = home + v[0]
		rules.lord.prev_pos = rules.lord.pos
		cam.set("yaw", deg_to_rad(float(v[1])))
		cam.set("distance", 14.0)
		for i in 14:
			await process_frame
		root.get_texture().get_image().save_png(OUT + "chief_" + id + ".png")
		if first:
			root.get_texture().get_image().save_png(OUT + "chief.png")
			first = false
		var c: Dictionary = rules.chiefs.get(StringName(id), {})
		print("shot ", id, " state=", c.get("state", -1), " hp=", (c.e as Enemy).hp if c.has("e") else -1)
		# 다음 곳으로 가기 전에 돌려보낸다(멀리 가면 놓아준다)
		rules.lord.pos = FieldLayout.START
		for i in 3:
			await process_frame
	quit()
