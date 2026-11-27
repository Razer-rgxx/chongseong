extends SceneTree
## 영주 꾸미기 3차(천 시뮬 망토·다듬은 머리) 확인용: 영주를 크게, 망토는 뒤·옆(서 있을 때와 달릴 때), 머리는 앞·옆.
## 돌리기: Xvfb :99 -screen 0 1600x900x24 &  DISPLAY=:99 godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s scripts/debug/shots/shot_cosmetics3.gd -- capes|heads|all
## 그림: /home/claude/shots/cos3_<id>_<보기>.png (영주 둘레만 잘라 저장)

const OUT: String = "/home/claude/shots/"
const CROP: Vector2i = Vector2i(560, 640)

var _lord: Node3D
var _cam: Node


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _snap(name: String, at: Vector3) -> void:
	await _frames(6)
	var img: Image = root.get_texture().get_image()
	var sp: Vector2 = root.get_camera_3d().unproject_position(at)
	var x: int = clampi(int(sp.x) - CROP.x / 2, 0, img.get_width() - CROP.x)
	var y: int = clampi(int(sp.y) - CROP.y / 2, 0, img.get_height() - CROP.y)
	img.get_region(Rect2i(x, y, CROP.x, CROP.y)).save_png(OUT + "cos3_%s.png" % name)
	print("shot ", name)


func _init() -> void:
	var part: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "all"
	DirAccess.make_dir_recursive_absolute(OUT)
	var meta := Meta.new()
	meta.shards = 130
	meta.cos_unlock_all()
	meta.save()
	change_scene_to_file("res://scenes/lobby/lobby.tscn")
	await _frames(40)
	var lobby: Node = current_scene
	var rules: Rules = lobby.get("rules")
	_cam = lobby.get("_camera")
	_cam.set("blur_allowed", false)
	var mir: Vector2 = lobby.get("mirror_at")
	rules.lord.pos = mir + Vector2(0.0, 2.0)
	rules.lord.prev_pos = rules.lord.pos
	rules.lord.face = -PI / 2.0
	await _frames(30)
	_lord = lobby.get("_lord")
	var only: PackedStringArray = PackedStringArray(OS.get_cmdline_user_args()[1].split(",")) if OS.get_cmdline_user_args().size() > 1 else PackedStringArray()
	if part == "capes" or part == "all":
		await _capes(only)
	if part == "heads" or part == "all":
		await _heads(only)
	quit()


func _capes(only: PackedStringArray) -> void:
	var ids: Array = ["cape_red", "cape_grey", "cape_moss", "cape_night", "cape_stripe", "cape_check", "cape_emblem", "cape_knight", "cape_shroud", "cape_runes", "cape_platinum", "cape_immortal", "cape_coat", "cape_anchor"]
	if not only.is_empty():
		ids = ids.filter(func(i): return i in only)
	_cam.set("third_distance", 2.6)
	_cam.set("look_height", 1.05)
	for id in ids:
		_lord.call("set_cosmetics", {"cape": id, "head": "head_none"})
		for v in [["back", 0.0], ["side", 0.55 * PI], ["back34", 0.25 * PI]]:
			_cam.set("yaw", v[1])
			_cam.call("snap")
			await _frames(8)
			await _snap("%s_%s" % [id, v[0]], _lord.global_position + Vector3(0, 1.0, 0))
	# 달릴 때: 마지막 프레임마다 지난 자리를 뒤로 밀어 빠르게 가는 것처럼 센다(화면만)
	for id in ["cape_night", "cape_shroud"]:
		if not only.is_empty() and not id in only:
			continue
		_lord.call("set_cosmetics", {"cape": id, "head": "head_none"})
		_cam.set("yaw", 0.55 * PI)
		_cam.call("snap")
		for i in 40:
			_lord.set("_last_pos", _lord.position + Vector3(0.2, 0, 0))
			await process_frame
		await _snap("%s_run" % id, _lord.global_position + Vector3(0, 1.0, 0))


func _heads(only: PackedStringArray) -> void:
	var ids: Array = ["head_band", "head_hood", "head_kettle", "head_helm", "head_circlet", "head_horn", "head_knight", "head_bone", "head_runeband", "head_ascend", "head_visor", "head_anchor"]
	if not only.is_empty():
		ids = ids.filter(func(i): return i in only)
	_cam.set("third_distance", 1.0)
	_cam.set("look_height", 1.6)
	_cam.set("pitch", deg_to_rad(6.0))
	for id in ids:
		_lord.call("set_cosmetics", {"cape": "cape_red", "head": id})
		for v in [["front", 0.5 * PI], ["back34", 0.2 * PI], ["rear", 0.0]]:
			_cam.set("yaw", v[1])
			_cam.call("snap")
			await _frames(8)
			await _snap("%s_%s" % [id, v[0]], _lord.global_position + Vector3(0, 1.58, 0))
