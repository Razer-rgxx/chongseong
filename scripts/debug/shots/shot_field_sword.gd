extends SceneTree
## 33단계 확인용: 마을 검 진열대(도감)의 "들판의 검" 줄과 북문 검 고르기의 한정 검 카드.
## 돌리기: xvfb-run -a godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s scripts/debug/shots/shot_field_sword.gd
## 그림은 /home/claude/shots/field_sword.png(도감), field_sword_card.png(북문 카드). 저장 파일은 건드리지 않는다(Meta만 고친다).

const OUT: String = "/home/claude/shots/"


func _init() -> void:
	change_scene_to_file("res://scenes/lobby/lobby.tscn")
	for i in 20:
		await process_frame
	var lobby: Node = current_scene
	var meta: Meta = lobby.get("meta")
	var data: GameData = lobby.get("data")
	# 언덕에서 뽑은 것 몇 자루와 들판에서 얻은 한정 검 다섯
	for sd in data.swords:
		if not sd.field_only and sd.id % 3 == 0:
			meta.note_found(sd.id)
	for id in [301, 303, 306, 308, 310]:
		meta.note_found(id)
	var hud: LobbyHud = lobby.get("_hud")
	hud.open_rack()
	for i in 12:
		await process_frame
	var scroll := _find_scroll(hud)
	if scroll:
		scroll.scroll_vertical = 100000
	for i in 12:
		await process_frame
	root.get_texture().get_image().save_png(OUT + "field_sword.png")
	print("shot field_sword")
	hud.close()
	Meta.carry_sword = 310
	hud.open_field_pick()
	for i in 12:
		await process_frame
	root.get_texture().get_image().save_png(OUT + "field_sword_card.png")
	print("shot field_sword_card")
	quit()


func _find_scroll(n: Node) -> ScrollContainer:
	for c in n.find_children("*", "ScrollContainer", true, false):
		if (c as Control).is_visible_in_tree():
			return c as ScrollContainer
	return null
