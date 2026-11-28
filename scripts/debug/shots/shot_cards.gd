extends SceneTree
## 카드 손맛(CardTilt, blur_dim.gdshader, 2026-11-28) 확인 그림: 흐리고 어두워진 뒤 화면 위에 고르기 창 비슷한 카드 셋
## (가운데는 커서를 올려 오른쪽으로 기운 모습)과 대장간 검 타일 한 줄(하나를 올린 모습). /home/claude/shots/cards.png
## 돌리기: xvfb-run -a godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1600x900 -s scripts/debug/shots/shot_cards.gd


func _card(text: String, w: float, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.028, 0.025, 0.96)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_content_margin_all(14)
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(w, 130)
	l.add_theme_color_override("font_color", Color(0.93, 0.88, 0.78))
	p.add_child(l)
	return p


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("/home/claude/shots")
	var ui := Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(ui)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/loading/hill.jpg") as Texture2D
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ui.add_child(bg)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://assets/ui/blur_dim.gdshader") as Shader
	dim.material = sm
	ui.add_child(dim)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	row.position = Vector2(230, 260)
	ui.add_child(row)
	var cols: Array = [Color(0.55, 0.6, 0.7), Color(0.98, 0.78, 0.3), Color(0.62, 0.4, 0.95)]
	var tilts: Array = []
	for i in 3:
		var c := _card(["칸 1 · 노병의 장검", "새로 뽑은 검 · 들불", "칸 2 · 굶주린 땅"][i], 300.0, cols[i])
		row.add_child(c)
		tilts.append(CardTilt.attach(c, cols[i]))
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 10)
	tiles.position = Vector2(560, 560)
	ui.add_child(tiles)
	var tt: Array = []
	for i in 6:
		var t := ForgeTile.card(null, cols[i % 3], "", func() -> void: pass)
		tiles.add_child(t)
		tt.append(t.get_node("CardTilt"))
	for k in 6:
		await process_frame
	for i in 3:
		(tilts[i] as CardTilt).set_process(false)
		(tilts[i] as CardTilt).pose(0.85 if i == 1 else 0.0, 1.0 if i == 1 else 0.0)
	for t in tt:
		(t as CardTilt).set_process(false)
	(tt[2] as CardTilt).pose(-0.7, 1.0)
	for k in 6:
		await process_frame
	root.get_texture().get_image().save_png("/home/claude/shots/cards.png")
	print("shot cards")
	quit()
