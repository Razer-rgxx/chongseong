extends SceneTree
## 38단계 들판 지도 찍기: 길을 따라 걷고 몇 곳을 둘러본 것으로 밝혀 두고(Meta.see_field) M 창을 연다.
## 돌리기: xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s scripts/debug/shots/shot_field_map.gd
## 그림 /home/claude/shots/field_map.png(한눈에), field_map_zoom.png(확대). 저장 파일은 건드리지 않게 지도에 쓸 Meta를 따로 꾸민다.

const OUT: String = "/home/claude/shots/"


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = down
		Input.parse_input_event(e)


func _init() -> void:
	change_scene_to_file("res://scenes/field/field.tscn")
	await _frames(20)
	var f: Node = current_scene
	var rules: Rules = f.get("rules")
	var meta: Meta = f.get("meta")
	rules.debug_god = true
	meta.field_seen = Meta.empty_seen()
	# 길을 따라 북쪽 언덕길까지, 개울 따라 동쪽 성채까지, 옛 싸움터와 검은 숲 가장자리 한 바퀴
	var walk: PackedVector2Array = FieldBuilder._spline(FieldLayout.ROAD, 8)
	for p in walk:
		meta.see_field(p / Grid.CELL)
	for x in range(50, 150, 3):
		meta.see_field(Vector2(x, 60))
	for p in [Vector2(84, 90), Vector2(70, 80), Vector2(96, 96), Vector2(30, 40), Vector2(18, 30), Vector2(140, 30), Vector2(150, 20), Vector2(130, 40), Vector2(94, 36)]:
		meta.see_field(p)
	meta.dropped = {"id": 1, "x": 76.0, "y": 70.0}
	meta.wanderer = "smith"
	meta.wanderer_at = 2
	meta.chiefs_down = {"chief_tower": 1}
	meta.field_found = {"cache_1": 1}
	rules.lord.pos = Vector2(96, 60)
	rules.lord.prev_pos = rules.lord.pos
	rules.lord.face = -0.6
	await _frames(5)
	_key(KEY_M)   # 들판에서 M → 지도 창(게임이 멈춘다)
	await _frames(12)
	var m: FieldMap = f.get("_hud").get_node_or_null("FieldMap")
	print("opened by M ", m != null, " paused ", paused)
	root.get_texture().get_image().save_png(OUT + "field_map.png")
	print("map zoom ", m.zoom(), " fit ", m.fit_zoom(), " seen ", meta.seen_count())
	m.zoom_at(m.to_px(Vector2(96, 60)), 2.6)
	await _frames(8)
	root.get_texture().get_image().save_png(OUT + "field_map_zoom.png")
	_key(KEY_M)   # 다시 M → 닫는다
	await _frames(4)
	print("closed by M ", not is_instance_valid(m) or m.is_queued_for_deletion(), " paused after close ", paused)
	quit()
