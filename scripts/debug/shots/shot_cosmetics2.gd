extends SceneTree
## 영주 꾸미기 2차(비밀 해금·그림자 실루엣·Blender 모양) 확인용: 거울 창, 꾸민 영주, 들판 비밀 자리. 저장 파일을 바꾸니 지워도 되는 곳에서만 돌린다.
## 돌리기: Xvfb :99 -screen 0 1600x900x24 &  DISPLAY=:99 godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s scripts/debug/shots/shot_cosmetics2.gd
## 그림: /home/claude/shots/cos2_*.png

const OUT: String = "/home/claude/shots/"


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _snap(name: String) -> void:
	await _frames(6)
	root.get_texture().get_image().save_png(OUT + "cos2_%s.png" % name)
	print("shot ", name)


func _init() -> void:
	var part: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "all"   # window | lords | field | all
	DirAccess.make_dir_recursive_absolute(OUT)
	var meta := Meta.new()
	meta.shards = 130
	meta.storage_house = true
	meta.stranger_done = true
	meta.cos_discover("well_rain")
	meta.cos_discover("neon_door")
	meta.cos_buy(&"cape_moss")
	for id in [&"cape_night", &"head_helm", &"slash_frost"]:
		meta.cos_wear(id)
	meta.note_found(196)
	meta.sheath_id = 196
	meta.sheath_lv = 1
	meta.save()
	change_scene_to_file("res://scenes/lobby/lobby.tscn")
	await _frames(40)
	var lobby: Node = current_scene
	var rules: Rules = lobby.get("rules")
	(lobby.get("_camera") as Node).set("blur_allowed", false)
	var mir: Vector2 = lobby.get("mirror_at")
	rules.lord.pos = mir + Vector2(0.0, 2.0)
	rules.lord.prev_pos = rules.lord.pos
	rules.lord.face = -PI / 2.0
	await _frames(30)
	if part == "field":
		await _field(meta)
		quit()
		return
	var hud: Node = lobby.get("_hud")
	if part == "lords":
		hud = null
	else:
		await _window(hud)
	await _lords(meta, lobby, part)
	quit()


func _window(hud: Node) -> void:
	hud.call("open_mirror")
	await _frames(20)
	await _snap("window_cape")
	var win: CosmeticWindow = root.find_child("UiCosmetics", true, false) as CosmeticWindow
	win._picked = &"cape_emblem"   # 잠긴 것을 눌러 본다: 이름은 ???, 입혀지지 않는다
	win._render()
	await _frames(12)
	await _snap("window_locked")
	for pair in [[&"head", &"head_horn"], [&"slash", &"slash_blood"]]:
		win._slot = pair[0]
		win._picked = pair[1]
		win._render()
		await _frames(12)
		await _snap("window_" + String(pair[0]))
	win.close()
	await _frames(4)


func _lords(meta: Meta, lobby: Node, part: String) -> void:
	if part == "window":
		return
	meta.cos_unlock_all()
	var cam: Node = lobby.get("_camera")
	var lord_view: Node3D = lobby.get("_lord")
	var looks: Array = [
		["night_helm", {"cape": "cape_night", "head": "head_helm"}],
		["stripe_horn", {"cape": "cape_stripe", "head": "head_horn"}],
		["knight", {"cape": "cape_knight", "head": "head_knight"}],
		["runes_visor", {"cape": "cape_runes", "head": "head_visor"}],
		["emblem_circlet", {"cape": "cape_emblem", "head": "head_circlet"}],
		["shroud_bone", {"cape": "cape_shroud", "head": "head_bone"}],
		["check_kettle", {"cape": "cape_check", "head": "head_kettle"}],
		["coat_hood", {"cape": "cape_coat", "head": "head_hood"}],
	]
	cam.set("third_distance", 3.4)
	cam.set("look_height", 1.25)
	for l in looks:
		lord_view.call("set_cosmetics", l[1])
		for side in ["back", "front"]:
			cam.set("yaw", 0.0 if side == "back" else PI)
			cam.call("snap")
			await _frames(10)
			await _snap("lord_%s_%s" % [l[0], side])


## 들판 비밀: 비 오는 날 우물, 안개 낀 날 늪의 그림자.
func _field(meta: Meta) -> void:
	for sc in [["rain", "well_rain", Vector2(192, 58.0)], ["fog", "marsh_hermit", Vector2(138, 91.0)]]:
		meta.cos_secrets.clear()
		meta.field_weather = StringName(sc[0])
		meta.field_clock = 20.0
		meta.save()
		change_scene_to_file("res://scenes/field/field.tscn")
		await _frames(50)
		var f: Node = current_scene
		var fr: Rules = f.get("rules")
		fr.lord.pos = sc[2]
		fr.lord.prev_pos = sc[2]
		fr.lord.face = -PI / 2.0
		var fc: Node = f.get("_camera")
		fc.set("third_distance", 5.0)
		fc.set("look_height", 1.2)
		fc.set("yaw", 0.0)
		fc.call("snap")
		await _frames(30)
		await _snap("field_" + String(sc[0]))
