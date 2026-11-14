class_name Hud
extends CanvasLayer
## 화면 위 글자와 창. 노드는 코드로 만든다(에셋이 들어오면 씬으로 바꿔도 된다).
## 모양은 UiKit(엘든 링식: 모서리 없는 검은 판, 놋쇠빛 줄). 알림과 뽑기·제단 안내는 띠(Band)로, 새 구역 이름은 AreaTitle로 띄운다.
## 규칙은 모른다. main이 값을 넣어 주고, 고르기·다시 하기는 신호로 돌려준다.

signal chose(slot: int)
signal restart_requested()
signal altar_chosen(index: int)

## 두 칸이 다 찼을 때 뜨는 창이, 연출을 넘기던 클릭을 받지 않도록 기다리는 시간.
@export var choice_guard: float = 0.8
@export var toast_time: float = 4.0

var _hp_bar: ProgressBar
var _hp_label: Label
var _zone: Label
var _sub: Label
var _night_bar: ProgressBar
var _help: Label
var _cards: Array[RichTextLabel] = []
var _card_boxes: Array[PanelContainer] = []
var _toast: Band
var _prompt: Band
var _title: AreaTitle
var _help_hint: Label
var _flash: ColorRect
var _boss_box: VBoxContainer
var _boss_bar: ProgressBar
var _choice: Control
var _ch_new: RichTextLabel
var _ch_a: RichTextLabel
var _ch_b: RichTextLabel
var _discard: Button
var _discard_armed: bool = false
var _choice_t: float = 0.0
var _over: Control
var _over_title: Label
var _over_text: Label
var _night_button: Button
var _altar: Control
var _altar_list: VBoxContainer
var _altar_t: float = 0.0


func _ready() -> void:
	UiKit.vignette(self)
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 14)
	top.add_theme_constant_override("separation", 14)
	add_child(top)
	var hp_box := _panel(VBoxContainer.new())
	hp_box.get_parent().custom_minimum_size = Vector2(260, 0)
	top.add_child(hp_box.get_parent())
	_hp_label = _label("", 16)
	hp_box.add_child(_hp_label)
	_hp_bar = _bar(Color(0.66, 0.12, 0.1))
	hp_box.add_child(_hp_bar)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var mid := _panel(VBoxContainer.new())
	mid.get_parent().custom_minimum_size = Vector2(340, 0)
	top.add_child(mid.get_parent())
	_zone = _label("", 20)
	_zone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_zone)
	_night_bar = _bar(Color(0.55, 0.47, 0.32))
	mid.add_child(_night_bar)
	_sub = _label("", 14)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.modulate = UiKit.MUTED
	mid.add_child(_sub)
	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer2)
	_night_button = Button.new()
	_night_button.text = "  밤 맞이하기 (N)  "
	_night_button.focus_mode = Control.FOCUS_NONE
	_night_button.custom_minimum_size = Vector2(260, 40)
	_night_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(_night_button)

	_boss_box = VBoxContainer.new()
	_boss_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_box.position = Vector2(-260, 112)
	_boss_box.custom_minimum_size = Vector2(520, 0)
	var bl := _label("언덕지기", 16)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(bl)
	_boss_bar = _bar(Color(1.0, 0.3, 0.42))
	_boss_box.add_child(_boss_bar)
	_boss_box.visible = false
	add_child(_boss_box)

	_toast = Band.make(self, 150.0, 1000.0, 48.0, 17)
	_prompt = Band.make(self, -200.0, 600.0, 46.0, 18)
	_title = AreaTitle.make(self)

	var bottom := HBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 14)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 10)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(bottom)
	for k in 2:
		var r := RichTextLabel.new()
		r.bbcode_enabled = true
		r.fit_content = true
		r.scroll_active = false
		r.custom_minimum_size = Vector2(380, 0)
		r.add_theme_font_size_override("normal_font_size", 15)
		r.add_theme_font_size_override("bold_font_size", 18)
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", _style(Color(UiKit.LINE, 0.25)))
		box.size_flags_vertical = Control.SIZE_SHRINK_END
		box.add_child(r)
		bottom.add_child(box)
		_cards.append(r)
		_card_boxes.append(box)

	_help = _label("WASD 걷기 · 마우스 둘러보기 · E 뽑기 · N 밤\n클릭/Space 베기 · Shift 돌진\nQ 바꿔 쥐기 · 1/2 칸 · 휠 거리 · V 카메라\nEsc 마우스 풀기 · F2 무적 · F3 밤 넘기기\nF4 다음 뽑기 등급 고정", 13)
	_help.modulate = UiKit.MUTED
	_help.position = Vector2(20, 96)
	_help.visible = false
	add_child(_help)
	_help_hint = _label("F1  조작법", 13)
	_help_hint.modulate = Color(UiKit.MUTED, 0.7)
	_help_hint.position = Vector2(20, 96)
	add_child(_help_hint)

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	add_child(_flash)

	_build_choice()
	_build_altar()
	_build_over()


func _process(delta: float) -> void:
	_choice_t += delta
	_altar_t += delta


func night_button() -> Button:
	return _night_button


func set_status(hp: float, max_hp: float, zone_text: String, sub: String, night_k: float, night: bool) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_label.text = "체력  %d / %d" % [ceili(hp), max_hp]
	_zone.text = zone_text
	_sub.text = sub
	_night_bar.value = night_k * 100.0
	_night_button.visible = not night


func set_boss(e: Enemy) -> void:
	_boss_box.visible = e != null
	if e:
		_boss_bar.max_value = e.max_hp
		_boss_bar.value = maxf(0.0, e.hp)


func set_cards(texts: Array[String], colors: Array[Color], active: int) -> void:
	for k in 2:
		_cards[k].text = texts[k]
		var col: Color = colors[k] if k == active else Color(UiKit.LINE, 0.25)
		_card_boxes[k].add_theme_stylebox_override("panel", _style(col, 2 if k == active else 1))
		_card_boxes[k].modulate.a = 1.0 if k == active else 0.75


func toast(t: String) -> void:
	_toast.show_for(t, toast_time)


## 꽂힌 검이나 제단 앞에 섰을 때 아래 띠(키 칸 + 할 일). 빈 글이면 지운다.
func set_prompt(key: String, t: String) -> void:
	if t == "":
		_prompt.hide_band()
	else:
		_prompt.show_key(key, t)


## 새 구역에 올라섰을 때 가운데 큰 글자.
## 뽑기 연출 영상을 화면 가득 튼다. 영상 길이(초)를 돌려준다(못 틀면 0).
func play_video(path: String) -> float:
	var stream := load(path) as VideoStream
	if stream == null:
		return 0.0
	var v := VideoStreamPlayer.new()
	v.stream = stream
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.expand = true
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	v.play()
	v.finished.connect(v.queue_free)
	var length: float = v.get_stream_length()
	return length if length > 0.0 else 3.0


func area_title(t: String) -> void:
	_title.show_title(t)


func toggle_help() -> void:
	_help.visible = not _help.visible
	_help_hint.visible = not _help.visible


## 큰 등급의 번쩍임(영상이 없을 때 대신).
func flash(c: Color, strength: float = 0.7, time: float = 0.5) -> void:
	_flash.color = Color(c, strength)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, time).set_ease(Tween.EASE_OUT)


func open_choice(new_text: String, a_text: String, b_text: String) -> void:
	_ch_new.text = new_text
	_ch_a.text = a_text
	_ch_b.text = b_text
	_discard_armed = false
	_discard.text = "두고 간다 (X)"
	_choice_t = 0.0
	_choice.visible = true


func choice_open() -> bool:
	return _choice.visible


## 키보드나 버튼에서. -1은 두고 가기(두 번 눌러야 한다).
func pick(k: int) -> void:
	if not _choice.visible or _choice_t < choice_guard:
		return
	if k < 0 and not _discard_armed:
		_discard_armed = true
		_discard.text = "정말 버리기 (X)"
		return
	_choice.visible = false
	chose.emit(k)


func show_over(title: String, text: String) -> void:
	_over_title.text = title
	_over_text.text = text
	_over.visible = true


func _build_choice() -> void:
	_choice = _dim()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var panel := _panel(box).get_parent() as PanelContainer
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_choice.add_child(panel)
	var head := HBoxContainer.new()
	var title := _label("두 손이 다 찼다", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_discard = Button.new()
	_discard.focus_mode = Control.FOCUS_NONE
	_discard.pressed.connect(func() -> void: pick(-1))
	head.add_child(_discard)
	box.add_child(head)
	box.add_child(_label("새 검을 어느 칸에 들까? 바꾸면 그 칸의 검은 버린다. 카드를 눌러서는 바뀌지 않는다.", 14))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	box.add_child(cols)
	var made: Array[RichTextLabel] = []
	for i in 3:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		col.add_child(_label(["지금 1번 칸", "새로 뽑은 검", "지금 2번 칸"][i], 14))
		var r := RichTextLabel.new()
		r.bbcode_enabled = true
		r.fit_content = true
		r.scroll_active = false
		r.custom_minimum_size = Vector2(320, 0)
		r.add_theme_font_size_override("normal_font_size", 14)
		r.add_theme_font_size_override("bold_font_size", 17)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style(Color(1, 0.84, 0.42) if i == 1 else Color(0.2, 0.23, 0.3), 2 if i == 1 else 1))
		card.add_child(r)
		col.add_child(card)
		made.append(r)
		if i != 1:
			var slot: int = 0 if i == 0 else 1
			var b := Button.new()
			b.text = "%d번 칸과 바꾸기 (%d)" % [slot + 1, slot + 1]
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(0, 40)
			b.pressed.connect(func() -> void: pick(slot))
			col.add_child(b)
		cols.add_child(col)
	_ch_a = made[0]
	_ch_new = made[1]
	_ch_b = made[2]
	_choice.visible = false


func open_altar(texts: Array[String]) -> void:
	for c in _altar_list.get_children():
		c.queue_free()
	for i in texts.size():
		var b := Button.new()
		b.text = "%d.  %s" % [i + 1, texts[i]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(560, 40)
		var k: int = i
		b.pressed.connect(func() -> void: pick_altar(k))
		_altar_list.add_child(b)
	var close := Button.new()
	close.text = "그냥 간다 (Esc)"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(0, 36)
	close.pressed.connect(func() -> void: pick_altar(-1))
	_altar_list.add_child(close)
	_altar_t = 0.0
	_altar.visible = true


func altar_is_open() -> bool:
	return _altar.visible


func pick_altar(i: int) -> void:
	if not _altar.visible or _altar_t < 0.4:
		return
	_altar.visible = false
	altar_chosen.emit(i)


func _build_altar() -> void:
	_altar = _dim()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var panel := _panel(box).get_parent() as PanelContainer
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_altar.add_child(panel)
	var at := _label("숫돌 제단", 26)
	at.add_theme_color_override("font_color", UiKit.TITLE)
	box.add_child(at)
	box.add_child(UiKit.rule())
	box.add_child(_label("한 번만 쓸 수 있다. 바친 검은 사라진다.", 14))
	_altar_list = VBoxContainer.new()
	_altar_list.add_theme_constant_override("separation", 6)
	box.add_child(_altar_list)
	_altar.visible = false


func _build_over() -> void:
	_over = _dim()
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	var panel := _panel(box).get_parent() as PanelContainer
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_over.add_child(panel)
	_over_title = _label("", 34)
	_over_title.add_theme_color_override("font_color", UiKit.TITLE)
	_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_over_title)
	_over_text = _label("", 17)
	_over_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_over_text)
	var again := Button.new()
	again.text = "  마을로 (R)  "
	again.focus_mode = Control.FOCUS_NONE
	again.custom_minimum_size = Vector2(0, 44)
	again.pressed.connect(func() -> void: restart_requested.emit())
	box.add_child(again)
	_over.visible = false


func _dim() -> Control:
	var c := ColorRect.new()
	c.color = Color(0.0, 0.0, 0.0, 0.78)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	return c


func _panel(inner: Control) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(Color(1, 1, 1, 0.08)))
	p.add_child(inner)
	return inner


func _style(border: Color, width: int = 1) -> StyleBoxFlat:
	var s := UiKit.style(border, width)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 9
	s.content_margin_bottom = 10
	return s


func _label(t: String, size: int) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	return l


func _bar(c: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 8)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.045, 0.04, 0.9)
	bg.border_color = Color(UiKit.LINE, 0.35)
	bg.set_border_width_all(1)
	var fg := StyleBoxFlat.new()
	fg.bg_color = c.darkened(0.15)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b
