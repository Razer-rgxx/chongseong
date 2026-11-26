extends SceneTree
## 영주 꾸미기 확인용(docs/cosmetics.md): 거울 창과 꾸민 영주 사진. 저장 파일을 바꾸니 지워도 되는 곳에서만 돌린다.
## 돌리기: Xvfb :99 -screen 0 1600x900x24 &  DISPLAY=:99 godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s scripts/debug/shots/shot_cosmetics.gd
## 그림: /home/claude/shots/cosmetics_*.png

const OUT: String = "/home/claude/shots/"


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _snap(name: String) -> void:
	await _frames(6)
	root.get_texture().get_image().save_png(OUT + "cosmetics_%s.png" % name)
	print("shot ", name)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var only: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""   # "slash"면 마을과 베기 빛만
	var meta := Meta.new()
	meta.shards = 130
	meta.boss_first = true
	meta.stranger_done = true
	meta.time_traveller = true
	meta.storage_house = true
	meta.cos_unlock_all()
	for id in [&"cape_stripe", &"head_helm", &"slash_ember"]:
		meta.cos_wear(id)
	meta.cos_owned.erase("cape_check")   # 잠긴 타일도 보이게
	meta.cos_owned.erase("head_horn")
	meta.cos_owned.erase("cape_emblem")
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
	await _snap("village")
	var hud: Node = lobby.get("_hud")
	if only == "slash":
		await _slash_shots(lobby, rules)
		quit()
		return
	hud.call("open_mirror")
	await _frames(20)
	await _snap("window_cape")
	var win: CosmeticWindow = root.find_child("UiCosmetics", true, false) as CosmeticWindow
	for pair in [[&"head", &"head_horn", "head"]]:
		win._slot = pair[0]
		win._picked = pair[1]
		win._render()
		await _frames(12)
		await _snap("window_" + pair[2])
	win._slot = &"cape"
	win._picked = &"cape_runes"
	win._render()
	await _frames(12)
	await _snap("window_locked")
	win.close()
	await _frames(4)
	# 꾸민 영주 가까이(앞·뒤)
	var cam: Node = lobby.get("_camera")
	var lord_view: Node3D = lobby.get("_lord")
	var looks: Array = [
		["stripe_helm", {"cape": "cape_stripe", "head": "head_helm", "slash": "slash_ember"}],
		["horn_runes", {"cape": "cape_runes", "head": "head_horn", "slash": "slash_frost"}],
		["knight", {"cape": "cape_knight", "head": "head_knight", "slash": "slash_grave"}],
		["visor_coat", {"cape": "cape_coat", "head": "head_visor", "slash": "slash_neon"}],
		["circlet_emblem", {"cape": "cape_immortal", "head": "head_circlet", "slash": "slash_gold"}],
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
	quit()


## 수련장에서 허수아비를 베는 모습: 꾸민 베기 빛(핏빛)이 칼 궤적과 베기 초승달에 칠해진다.
func _slash_shots(lobby: Node, rules: Rules) -> void:
	var lord_view: Node3D = lobby.get("_lord")
	lord_view.call("set_cosmetics", {"cape": "cape_stripe", "head": "head_helm", "slash": "slash_blood"})
	lobby.call("_on_yard_sword", 196)   # 수련장 칼(걸이에서 고른 것)
	var dummies: Array = lobby.get("yard_dummies")
	var d0: Vector2 = dummies[1]
	rules.lord.pos = d0 + Vector2(-1.4, 0.0)
	rules.lord.prev_pos = rules.lord.pos
	rules.lord.face = 0.0
	var cam: Node = lobby.get("_camera")
	cam.set("yaw", -PI / 2.0)
	cam.set("third_distance", 5.5)
	cam.set("look_height", 1.3)
	cam.call("snap")
	await _frames(20)
	Input.action_press("attack")
	for i in 6:
		await _frames(5)
		await _snap("slash_%d" % i)
	Input.action_release("attack")
