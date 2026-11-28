extends SceneTree
## 결투 리그 화면 확인용(docs/duel_league.md). 리그 창(가짜 순위표)과 랭크 결투 뒤 RR 화면(승급)을 찍는다.
## 돌리기: xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s scripts/debug/shots/shot_league.gd
## 그림: /home/claude/shots/league_window.png, league_result.png, league_emblems.png


func _init() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.09, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	await process_frame
	# 문장 아홉 한 줄
	var strip := HBoxContainer.new()
	strip.position = Vector2(40, 40)
	strip.add_theme_constant_override("separation", 14)
	for s in [0, 3, 6, 9, 12, 15, 18, 21, 24]:
		strip.add_child(LeagueUi.emblem(s, 112.0))
	root.add_child(strip)
	for i in 4:
		await process_frame
	root.get_texture().get_image().save_png("/home/claude/shots/league_emblems.png")
	strip.queue_free()
	# 리그 창
	var meta := Meta.new()
	var ld: LeagueData = League.data()
	var st: Dictionary = League.state(meta)
	st.games = 18
	st.wins = 11
	st.losses = 7
	st.step = 16   # 금강 2
	st.rr = 62
	st.peak = 17
	st.season = League.season_now(meta)
	meta.league_titles = {"1": 13}
	var w: LeagueWindow = LeagueWindow.open(root, meta)
	for i in 4:
		await process_frame
	var rows: Array[Dictionary] = []
	var names: Array[String] = ["검성", "Hilt", "녹슨칼날", "안개", "달무리", "Ash", "서리검", "반딧불", "무명", "한밤"]
	for i in names.size():
		var step: int = 23 if i < 4 else 21 - i / 2
		rows.append({"rank": i, "name": names[i], "step": step, "rr": 180 - i * 14 if step == 23 else 70 - i * 3, "title": "S1 금 2" if i == 1 else ""})
	w.fill_rows({"ok": true, "rows": rows, "text": ""})
	for i in 4:
		await process_frame
	root.get_texture().get_image().save_png("/home/claude/shots/league_window.png")
	w.queue_free()
	await process_frame
	# 랭크 결과(승급): 막대가 다 차올라 번쩍인 뒤
	var hud := DuelHud.new()
	root.add_child(hud)
	await process_frame
	await process_frame
	var res := {"win": true, "placing": false, "placed_now": false, "delta": 24, "step_before": 11, "rr_before": 84, "step_after": 12, "rr_after": 8, "promoted": true, "demoted": false, "shielded": false, "games": 20}
	var wins: Array[int] = [2, 1]
	hud.show_result(0, wins, Vector2i(12, 8), res)
	var t: float = 0.0
	while t < 3.0:
		await process_frame
		t += 1.0 / 60.0
	root.get_texture().get_image().save_png("/home/claude/shots/league_result.png")
	quit()
