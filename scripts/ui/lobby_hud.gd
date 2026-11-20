class_name LobbyHud
extends CanvasLayer
## 마을의 화면: 오른쪽 아래 조각, 아래 가운데 안내 띠(E), 대장간(검집 강화), 성소(축복), 검 진열대(도감과 기록).
## 엘든 링의 원탁처럼 글자를 세계에 띄우지 않고 화면 띠로만 알린다. 들어설 때 마을 이름을 크게 한 번 띄운다.
## 강화는 Meta가 굴리고, 이 창은 망치 소리와 결과만 보여 준다. 연출 위에 글자를 띄우지 않는다.

signal forge_hit(step: int)
signal forge_done(result: Dictionary, big: bool)
signal closed()
## 15단계: 의뢰를 맡았다(판의 번호), 물건을 샀다(id), 수련장 검을 골랐다(SwordData.id).
signal quest_taken(i: int)
signal bought(id: StringName)
signal yard_sword_picked(id: int)
## 17단계: 북문에서 검을 골라 들판으로 나선다(SwordData.id, 0은 맨손).
signal field_go(id: int)
## 21단계: 결투 말뚝에서 1P와 2P가 들 검을 골라 겨룬다(SwordData.id, 0은 맨손).
signal duel_go(a: int, b: int)
## 22단계: 모르는 사람과 겨루기. 검을 골랐다(찾기 시작) / 찾는 도중에 창을 닫았다(취소).
signal duel_online(pick: int)
signal duel_online_cancel()

## 망치를 세 번 내리친 뒤 결과가 나온다(초).
@export var hammer_gap: float = 0.28
@export var result_delay: float = 0.4

var data: GameData
var meta: Meta
var _shards: Label
var _toast: Band
var _prompt: Band
var _title: AreaTitle
var _flash: ColorRect
var _forge: Control
var _forge_box: VBoxContainer
var _shrine: Control
var _shrine_box: VBoxContainer
var _rack: Control
var _rack_text: RichTextLabel
var _msg: Label
var _busy: bool = false
var _rack_head: Label
var _board: Control
var _board_box: VBoxContainer
var _shop: Control
var _shop_box: VBoxContainer
var _yard: Control
var _yard_box: VBoxContainer
var _yard_pick: Label
var _readout: Label
## 17단계: 검 고르기 창이 북문용인지(검 걸이 창을 같이 쓴다)와 거기서 고른 검, 들판의 체력 막대.
var _gate_mode: bool = false
var _gate_pick: int = 0
var _hp_bar: ProgressBar
## 들판 보스·우두머리의 체력 막대(18·32단계): 화면 아래 가운데, 큰 이름 한 줄과 막대.
var _boss_box: VBoxContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _say: DialogueBox
## 결투 창(21단계)과 거기서 고른 1P·2P의 검.
var _duel: Control
var _duel_box: VBoxContainer
var _duel_pick: Array[int] = [0, 0]
## 온라인 찾는 중이면 true(창을 닫으면 취소가 된다). 상태 글 칸.
var _online_busy: bool = false
var _online_label: Label


## 마을이 _ready에서 부른다(이 창의 _ready가 먼저 돈다).
func setup(d: GameData, m: Meta) -> void:
	data = d
	meta = m
	refresh_top()


func _ready() -> void:
	UiKit.vignette(self)
	var sb := PanelContainer.new()
	var st := UiKit.style(Color(UiKit.LINE, 0.35), 1, Color(0.02, 0.018, 0.015, 0.75))
	st.content_margin_top = 6
	st.content_margin_bottom = 7
	sb.add_theme_stylebox_override("panel", st)
	sb.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	sb.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	sb.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sb.offset_right = -28
	sb.offset_bottom = -26
	add_child(sb)
	_shards = UiKit.label("", 20, UiKit.TITLE)
	sb.add_child(_shards)
	_toast = Band.make(self, 96.0, 980.0, 50.0, 18)
	_prompt = Band.make(self, -110.0, 640.0, 50.0, 19)
	_say = DialogueBox.make(self)   # 대사: 이름 + 줄, 화면 아래 자막
	_title = AreaTitle.make(self)
	_forge = _layer()
	_forge_box = UiKit.center_panel(_forge)
	_shrine = _layer()
	_shrine_box = UiKit.center_panel(_shrine)
	_board = _layer()
	_board_box = UiKit.center_panel(_board)
	_shop = _layer()
	_shop_box = UiKit.center_panel(_shop)
	_yard = _layer()
	_yard_box = UiKit.center_panel(_yard)
	_duel = _layer()
	_duel_box = UiKit.center_panel(_duel)
	_rack = _layer()
	var rb := UiKit.center_panel(_rack)
	UiKit.header(rb, "검 진열대", close)
	_rack_head = UiKit.label("", 15, UiKit.MUTED)
	rb.add_child(_rack_head)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(820, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rack_text = UiKit.rich(14, 800)
	scroll.add_child(_rack_text)
	rb.add_child(scroll)
	_readout = UiKit.label("", 20, UiKit.TITLE)
	_readout.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_readout.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_readout.offset_top = 150
	_readout.visible = false
	add_child(_readout)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	add_child(_flash)


func is_open() -> bool:
	return _forge.visible or _shrine.visible or _rack.visible or _board.visible or _shop.visible or _yard.visible or _duel.visible


func close() -> void:
	if _busy:
		return
	_gate_mode = false
	if _online_busy:
		_online_busy = false
		duel_online_cancel.emit()
	_forge.visible = false
	_shrine.visible = false
	_rack.visible = false
	_board.visible = false
	_shop.visible = false
	_yard.visible = false
	_duel.visible = false
	closed.emit()


## 들판의 체력 막대(17단계). 글자 없이 줄만 그린다.
func set_hp(hp: float, max_hp: float) -> void:
	if _hp_bar == null:
		_hp_bar = ProgressBar.new()
		_hp_bar.show_percentage = false
		_hp_bar.custom_minimum_size = Vector2(300, 12)
		_hp_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		_hp_bar.offset_left = 28
		_hp_bar.offset_right = 328
		_hp_bar.offset_top = -40
		_hp_bar.offset_bottom = -28
		var bg := UiKit.style(Color(UiKit.LINE, 0.4), 1, Color(0.02, 0.018, 0.015, 0.75))
		var fill := UiKit.style(Color(0.7, 0.16, 0.14), 0, Color(0.7, 0.16, 0.14))
		for sb in [bg, fill]:
			sb.set_content_margin_all(0)
		_hp_bar.add_theme_stylebox_override("background", bg)
		_hp_bar.add_theme_stylebox_override("fill", fill)
		add_child(_hp_bar)
	_hp_bar.max_value = max_hp
	_hp_bar.value = maxf(0.0, hp)


## 들판 보스·곳마다 우두머리의 체력 막대(18·32단계, 엘든 링식). 화면 아래 가운데에 또렷한 큰 이름 한 줄, 그 아래 양 끝이 사라지는 놋쇠 줄과 긴 막대.
## name이 ""이면 감춘다. 이름이 바뀌면(다른 우두머리) 글을 바꾼다.
func set_boss(boss_name: String, hp: float, max_hp: float) -> void:
	if _boss_box == null:
		if boss_name == "":
			return
		_boss_box = VBoxContainer.new()
		_boss_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_boss_box.offset_left = -360
		_boss_box.offset_right = 360
		_boss_box.offset_top = -104
		_boss_box.offset_bottom = -38
		_boss_box.add_theme_constant_override("separation", 5)
		_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_boss_name = UiKit.label("", 28, UiKit.TITLE)
		_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_boss_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 어두운 땅·밤하늘 위에서도 또렷하게: 검은 테두리와 그림자
		_boss_name.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		_boss_name.add_theme_constant_override("outline_size", 7)
		_boss_name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
		_boss_name.add_theme_constant_override("shadow_offset_x", 0)
		_boss_name.add_theme_constant_override("shadow_offset_y", 2)
		_boss_name.add_theme_constant_override("shadow_outline_size", 12)
		_boss_box.add_child(_boss_name)
		var line := UiKit.rule(640.0, UiKit.LINE, 0.7)
		line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_boss_box.add_child(line)
		_boss_bar = ProgressBar.new()
		_boss_bar.show_percentage = false
		_boss_bar.custom_minimum_size = Vector2(720, 14)
		_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bg := UiKit.style(Color(UiKit.LINE, 0.6), 1, Color(0.02, 0.018, 0.015, 0.85))
		var fill := UiKit.style(Color(0.62, 0.13, 0.08), 0, Color(0.62, 0.13, 0.08))
		for sb in [bg, fill]:
			sb.set_content_margin_all(0)
		_boss_bar.add_theme_stylebox_override("background", bg)
		_boss_bar.add_theme_stylebox_override("fill", fill)
		_boss_box.add_child(_boss_bar)
		add_child(_boss_box)
	_boss_box.visible = boss_name != ""
	if boss_name == "":
		return
	if _boss_name.text != boss_name:
		_boss_name.text = boss_name
	_boss_bar.max_value = max_hp
	_boss_bar.value = maxf(0.0, hp)


func boss_bar_name() -> String:
	return _boss_name.text if boss_bar_shown() else ""


func boss_bar_shown() -> bool:
	return _boss_box != null and _boss_box.visible


func toast(t: String) -> void:
	_toast.show_for(t, 4.0)


## 들를 곳 앞에 섰을 때 아래 띠(키 칸 + 할 일). 빈 글이면 지운다.
func set_prompt(key: String, t: String) -> void:
	if t == "" or is_open():
		_prompt.hide_band()
	else:
		_prompt.show_key(key, t)


## 주민의 말 한 줄(띠, E로 다음). 한 줄이 길면 가운데에서 끊는다.
## 대사 한 줄(이름 + 말). last면 오른쪽 아래 안내가 "닫기".
func say(who: String, text: String, last: bool = false) -> void:
	_say.show_line(who, text, last)


func say_end() -> void:
	_say.hide_box()


func area_title(t: String) -> void:
	_title.show_title(t)


func flash(c: Color, strength: float, time: float = 0.5) -> void:
	_flash.color = Color(c, strength)
	create_tween().tween_property(_flash, "color:a", 0.0, time)


func refresh_top() -> void:
	_shards.text = "조각  %s" % _num(meta.shards)


# ---------------------------------------------------------------- 대장간

func open_forge() -> void:
	_forge.visible = true
	_render_forge("")


func _render_forge(msg: String) -> void:
	for c in _forge_box.get_children():
		c.queue_free()
	var md := data.meta
	UiKit.header(_forge_box, "대장간 · 검집 +%d" % meta.sheath_lv, close)
	var cands := meta.sheath_candidates(data)
	if cands.is_empty():
		_forge_box.add_child(_wrap(UiKit.label("검집에는 찾아 본 전설 이상의 검만 넣을 수 있다(언덕에서 뽑았거나 들판에서 얻은 검). 아직 없다.\n검집 강화는 미리 해 둘 수 있다. 나중에 넣는 검에 그 단계가 붙는다.", 15, UiKit.MUTED)))
	else:
		var pick := OptionButton.new()
		pick.focus_mode = Control.FOCUS_NONE
		for id in cands:
			var d := data.sword_by_id(id)
			pick.add_item("%s · %s (%s)" % [data.grades.names[d.grade], d.display_name, data.forms[d.form].display_name], id)
			if id == meta.sheath_id:
				pick.select(pick.item_count - 1)
		pick.item_selected.connect(func(i: int) -> void:
			meta.sheath_id = pick.get_item_id(i)
			meta.save()
			_render_forge(""))
		_forge_box.add_child(pick)
		var card := PanelContainer.new()
		var s := meta.sheath_sword(data)
		card.add_theme_stylebox_override("panel", UiKit.style(data.grades.colors[s.grade] if s else Color.GRAY, 2))
		var r := UiKit.rich(15, 520)
		r.text = SwordCard.bbcode(s, data)
		card.add_child(r)
		_forge_box.add_child(card)
	var ins: String = ", ".join(meta.sheath_ins) if not meta.sheath_ins.is_empty() else "없음"
	_forge_box.add_child(UiKit.label("검집 효과: 피해 +%d%% · 내구 +%d%% · 붙은 각인 %s" % [roundi(md.sheath_damage * 100 * meta.sheath_lv), roundi(md.sheath_durability * 100 * meta.sheath_lv), ins], 15, UiKit.TEXT))
	if meta.sheath_lv < md.sheath_max:
		var b := UiKit.button("망치질 · 조각 %s · 성공 %d%%" % [_num(meta.sheath_cost(md)), roundi(meta.sheath_rate(md))], _forge_sheath, 46)
		b.disabled = _busy
		_forge_box.add_child(b)
		var note: String = "실패하면 한 단계 내려간다." if meta.sheath_lv >= md.sheath_drop_from else "+%d부터는 실패하면 한 단계 내려간다." % md.sheath_drop_from
		_forge_box.add_child(UiKit.label(note + " +5, +10에 처음 닿으면 각인이 붙는다.", 13, UiKit.MUTED))
		if meta.has_recruit("smith"):
			_forge_box.add_child(UiKit.label("떠돌이 대장장이가 거든다: 망치질 값 -%d%%" % roundi((1.0 - FieldLayout.RECRUIT_FORGE) * 100.0), 13, UiKit.MUTED))
	else:
		_forge_box.add_child(UiKit.label("끝까지 벼렸다.", 16, UiKit.TITLE))
	_msg = UiKit.label(msg, 18, UiKit.TITLE)
	_forge_box.add_child(_msg)


func _forge_sheath() -> void:
	if _busy:
		return
	if meta.shards < meta.sheath_cost(data.meta):
		_render_forge("조각이 %s 모자라." % _num(meta.sheath_cost(data.meta) - meta.shards))
		return
	_busy = true
	_render_forge("")
	for i in 3:
		await get_tree().create_timer(hammer_gap).timeout
		forge_hit.emit(i + 1)
		_msg.text = "…".repeat(i + 1)
	await get_tree().create_timer(result_delay).timeout
	var lv0: int = meta.sheath_lv
	var r := meta.forge_sheath(data)
	meta.save()
	_busy = false
	var msg: String
	if r.ok:
		msg = "성공! 검집 +%d." % meta.sheath_lv + (" 각인 「%s」이(가) 붙었다." % r.ins if r.ins != "" else "")
	elif r.dropped:
		msg = "실패. 검집이 +%d(으)로 내려갔다." % meta.sheath_lv
	else:
		msg = "실패. 조각만 날아갔다."
	forge_done.emit(r, r.ok and meta.sheath_lv >= 7 and meta.sheath_lv > lv0)
	refresh_top()
	_render_forge(msg)


# ---------------------------------------------------------------- 성소

func open_shrine() -> void:
	_shrine.visible = true
	_render_shrine("")


func _render_shrine(msg: String) -> void:
	for c in _shrine_box.get_children():
		c.queue_free()
	var md := data.meta
	UiKit.header(_shrine_box, "성소 · 축복", close, Color(0.8, 0.84, 0.88))
	_shrine_box.add_child(UiKit.label("실패해도 내려가지 않는다." + ("  길 잃은 순례자가 함께 빈다: 축복 값 -%d%%" % roundi((1.0 - FieldLayout.RECRUIT_BLESS) * 100.0) if meta.has_recruit("pilgrim") else ""), 13, UiKit.MUTED))
	for i in md.bless_keys.size():
		var key: String = md.bless_keys[i]
		var lv: int = meta.bless_level(key)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var txt := UiKit.label("%s  %d / %d\n%s" % [md.bless_names[i], lv, md.bless_max[i], _bless_text(i, lv) + ("" if lv >= md.bless_max[i] else "  →  " + _bless_text(i, lv + 1))], 15)
		txt.custom_minimum_size = Vector2(380, 0)
		row.add_child(txt)
		if lv < md.bless_max[i]:
			var b := UiKit.button("조각 %s · %d%%" % [_num(meta.bless_cost(md, key)), roundi(meta.bless_rate(md, key))], func() -> void: _forge_bless(key))
			b.custom_minimum_size = Vector2(180, 40)
			b.disabled = _busy
			row.add_child(b)
		else:
			row.add_child(UiKit.label("끝", 15, UiKit.MUTED))
		_shrine_box.add_child(row)
	_msg = UiKit.label(msg, 18, UiKit.TITLE)
	_shrine_box.add_child(_msg)


func _bless_text(i: int, lv: int) -> String:
	var v: float = data.meta.bless_step[i] * lv
	match data.meta.bless_keys[i]:
		"hp":
			return "최대 체력 +%d" % v
		"luck":
			return "뽑기 운 +%d%%" % roundi(v * 100)
		"cost":
			return "뽑을 때 체력 -%d" % v
		_:
			return "새벽 회복 +%d" % v


func _forge_bless(key: String) -> void:
	if _busy:
		return
	var md := data.meta
	if meta.shards < meta.bless_cost(md, key):
		_render_shrine("조각이 %s 모자라." % _num(meta.bless_cost(md, key) - meta.shards))
		return
	_busy = true
	_render_shrine("")
	for i in 2:
		await get_tree().create_timer(hammer_gap).timeout
		forge_hit.emit(i + 1)
		_msg.text = "…".repeat(i + 1)
	await get_tree().create_timer(result_delay).timeout
	var r := meta.forge_bless(md, key)
	meta.save()
	_busy = false
	var n: String = md.bless_names[md.bless_keys.find(key)]
	forge_done.emit(r, false)
	refresh_top()
	_render_shrine("성공! %s %d." % [n, meta.bless_level(key)] if r.ok else "실패. 조각만 날아갔다.")


# ---------------------------------------------------------------- 진열대(도감)

func open_rack() -> void:
	var t: String = _my_swords()
	for g in data.grades.names.size():
		var ids: PackedInt32Array = data.swords_by_grade[g]
		var n: int = 0
		for i in ids:
			n += 1 if meta.has_found(data.swords[i].id) else 0
		var col: String = data.grades.colors[g].to_html(false)
		t += "[b][color=#%s]%s[/color][/b]  [color=#99917f]%d / %d · 1/%s[/color]\n" % [col, data.grades.names[g], n, ids.size(), _num(int(data.grades.odds[g]))]
		var names: Array[String] = []
		for i in ids:
			var sd := data.swords[i]
			names.append(sd.display_name + ("" if int(meta.found.get(str(sd.id), 0)) < 2 else " ×%d" % int(meta.found[str(sd.id)])) if meta.has_found(sd.id) else "[color=#4d4740]???[/color]")
		t += "  ·  ".join(names) + "\n\n"
	t += _field_row()
	_rack_text.text = t
	var best: String = "없음" if meta.best == 0 else ("정상" if meta.best > data.run.zone_names.size() else "%d구역" % meta.best)
	_rack_head.text = "도감 %d / %d  ·  최고 기록 %s  ·  오른 횟수 %d" % [meta.found.size(), data.swords.size(), best, meta.runs]
	_rack.visible = true


## 도감 맨 위 "내 검"(2026-11-20): 가장 많이 벤 검 다섯과 그 기록, 그리고 잃은 검(묘비처럼). 기록이 없으면 빈 줄.
func _my_swords() -> String:
	var ids: Array[int] = []
	for k in meta.sword_log:
		if meta.kills_of(int(k)) > 0 and not meta.lost.has(str(k)):
			ids.append(int(k))
	ids.sort_custom(func(a: int, b: int) -> bool: return meta.kills_of(a) > meta.kills_of(b))
	var t: String = ""
	if not ids.is_empty():
		t += "[b][color=#c8b27a]내 검[/color][/b]\n"
		for i in mini(5, ids.size()):
			var sd: SwordData = data.sword_by_id(ids[i])
			if sd == null:
				continue
			var col: String = data.grades.colors[sd.grade].to_html(false)
			var mark: String = "  [color=#c8b27a]· 검집[/color]" if ids[i] == meta.sheath_id else ""
			t += "  [color=#%s]%s[/color]%s  [color=#99917f]%s[/color]\n" % [col, sd.display_name, mark, meta.log_line(ids[i])]
		t += "\n"
	if not meta.lost.is_empty():
		t += "[b][color=#8a3b30]잃은 검[/color][/b]\n"
		for k in meta.lost:
			var ld: SwordData = data.sword_by_id(int(k))
			if ld == null:
				continue
			var line: String = meta.log_line(int(k))
			t += "  [color=#6b625a]%s[/color]  [color=#5a524a]%s[/color]\n" % [ld.display_name, line if line != "" else "기록 없음"]
		t += "\n"
	return t


## 도감의 "들판의 검" 줄(33단계): 언덕에서는 뽑히지 않는 오픈월드 한정 검. 찾은 것은 제 등급 빛으로 쓴다.
func _field_row() -> String:
	var ids: PackedInt32Array = data.field_swords
	if ids.is_empty():
		return ""
	var n: int = 0
	var names: Array[String] = []
	for i in ids:
		var sd := data.swords[i]
		if meta.has_found(sd.id):
			n += 1
			names.append("[color=#%s]%s[/color]" % [(data.grades.colors[sd.grade] as Color).to_html(false), sd.display_name])
		else:
			names.append("[color=#4d4740]???[/color]")
	var t: String = "[b][color=#%s]들판의 검[/color][/b]  [color=#99917f]%d / %d · 언덕에서는 뽑히지 않는다[/color]\n" % [UiKit.TITLE.to_html(false), n, ids.size()]
	return t + "  ·  ".join(names) + "\n"


## 수련장 위 가운데 줄("5초 피해 N"). 빈 글이면 숨긴다.
func set_readout(t: String) -> void:
	_readout.text = t
	_readout.visible = t != ""


# ---------------------------------------------------------------- 의뢰판 · 상인 · 검 걸이 (15단계)

func open_board() -> void:
	_board.visible = true
	_render_board("")


func _render_board(msg: String) -> void:
	for c in _board_box.get_children():
		c.queue_free()
	UiKit.header(_board_box, "의뢰판", close)
	_board_box.add_child(_wrap(UiKit.label("하나만 맡을 수 있다. 다음 판에서 센다. 이루면 조각을 받고, 못 이루면 그대로 남는다.", 14, UiKit.MUTED)))
	for i in meta.quest_board.size():
		var q: QuestData = data.village.quests[meta.quest_board[i]]
		var on: bool = i == meta.quest_active
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiKit.style(UiKit.TITLE if on else Color(UiKit.LINE, 0.4), 2 if on else 1))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var t := UiKit.label("%s\n조각 +%d" % [Meta.quest_text(q), q.reward], 17, UiKit.TEXT)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.custom_minimum_size = Vector2(430, 0)
		row.add_child(t)
		var b := UiKit.button("맡는 중" if on else "맡는다", func() -> void:
			if meta.take_quest(i):
				meta.save()
				quest_taken.emit(i)
				_render_board("의뢰를 맡았다."), 40.0)
		b.disabled = on or meta.quest_active >= 0
		b.custom_minimum_size = Vector2(110, 40)
		row.add_child(b)
		card.add_child(row)
		_board_box.add_child(card)
	if meta.quest_active >= 0:
		_board_box.add_child(UiKit.button("맡은 의뢰를 내려놓는다", func() -> void:
			meta.drop_quest()
			meta.save()
			_render_board("의뢰를 내려놓았다."), 34.0))
	_board_box.add_child(UiKit.label(msg, 17, UiKit.TITLE))


func open_shop() -> void:
	_shop.visible = true
	_render_shop("")


func _render_shop(msg: String) -> void:
	for c in _shop_box.get_children():
		c.queue_free()
	UiKit.header(_shop_box, "떠돌이 상인", close)
	_shop_box.add_child(_wrap(UiKit.label("산 것은 다음 판 하나에만 쓰인다. 판이 끝날 때마다 물건이 바뀐다.", 14, UiKit.MUTED)))
	for id in meta.stock:
		var g := data.village.goods_by_id(id)
		var have: bool = meta.pack.has(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var t := UiKit.label("%s\n%s" % [g.display_name, g.text], 16, UiKit.MUTED if have else UiKit.TEXT)
		t.custom_minimum_size = Vector2(470, 0)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		var b := UiKit.button("산 것" if have else "조각 %d" % g.price, func() -> void:
			var why: String = meta.buy(data, id)
			if why == "":
				meta.save()
				refresh_top()
				bought.emit(id)
				_render_shop("%s을(를) 샀다." % g.display_name)
			else:
				_render_shop(why), 40.0)
		b.disabled = have
		b.custom_minimum_size = Vector2(120, 40)
		row.add_child(b)
		_shop_box.add_child(row)
	_shop_box.add_child(UiKit.label(msg, 17, UiKit.TITLE))


## 수련장 검 걸이: 검집의 검과 도감에서 찾은 검 중 하나를 고른다.
func open_yard_rack() -> void:
	_yard.visible = true
	_render_yard_rack()


## 북문(17단계): 들고 나갈 검을 고른다. 목록은 검 걸이와 같다(검집의 검 + 도감에서 찾은 검 + 맨손).
func open_field_pick() -> void:
	_gate_mode = true
	_gate_pick = Meta.carry_sword if Meta.carry_sword >= 0 else maxi(0, meta.sheath_id)
	if not meta.usable(_gate_pick):
		_gate_pick = 0   # 떨구거나 잃은 검은 못 들고 나간다
	_yard.visible = true
	_render_yard_rack()


func _render_yard_rack() -> void:
	for c in _yard_box.get_children():
		c.queue_free()
	UiKit.header(_yard_box, "들판으로 나선다" if _gate_mode else "수련장 검 걸이", func() -> void:
		_gate_mode = false
		close())
	if _gate_mode:
		_yard_box.add_child(_wrap(UiKit.label("고른 검은 들판에서만 쥔다. 부러지지 않는다. 쓰러지면 그 자리에 떨구고, 줍기 전에 또 쓰러지면 영영 잃는다.", 14, UiKit.MUTED)))
		if not meta.dropped.is_empty():
			var dd: SwordData = data.sword_by_id(meta.dropped_id())
			_yard_box.add_child(_wrap(UiKit.label("들판에 떨군 검: %s" % (dd.display_name if dd else "?"), 14, Color(1.0, 0.45, 0.35))))
	else:
		_yard_box.add_child(_wrap(UiKit.label("고른 검은 마을에서만 쥔다. 울타리 안에서 좌클릭으로 허수아비를 친다.", 14, UiKit.MUTED)))
	var ids := meta.yard_swords(data)
	if ids.is_empty() and not _gate_mode:
		_yard_box.add_child(UiKit.label("걸어 둘 검이 없다. 언덕에서 뽑아 와야 한다.", 16, UiKit.TEXT))
		return
	var chosen: int = _gate_pick if _gate_mode else meta.yard_sword
	var pick := OptionButton.new()
	pick.focus_mode = Control.FOCUS_NONE
	pick.custom_minimum_size = Vector2(520, 36)
	pick.add_item("맨손", 0)
	for id in ids:
		var d := data.sword_by_id(id)
		pick.add_item("%s%s · %s (%s)" % ["[검집] " if id == meta.sheath_id else "", data.grades.names[d.grade], d.display_name, data.forms[d.form].display_name], id)
		if id == chosen:
			pick.select(pick.item_count - 1)
	pick.item_selected.connect(func(i: int) -> void:
		var id: int = pick.get_item_id(i)
		if _gate_mode:
			_gate_pick = id
		else:
			yard_sword_picked.emit(id)
		_render_yard_rack())
	_yard_box.add_child(pick)
	if chosen > 0:
		var s: Sword = meta.unbreakable_sword(data, chosen)
		if s:
			var card := PanelContainer.new()
			card.add_theme_stylebox_override("panel", UiKit.style(data.grades.colors[s.grade], 2))
			var r := UiKit.rich(15, 520)
			r.text = SwordCard.bbcode(s, data)
			card.add_child(r)
			_yard_box.add_child(card)
	if _gate_mode:
		_yard_box.add_child(UiKit.button("나선다", func() -> void: field_go.emit(_gate_pick), 40.0))


## 결투 말뚝(21단계): 같은 PC로 겨루기, 모르는 사람과 겨루기(22단계까지 흐리게).
func open_duel() -> void:
	_duel.visible = true
	_render_duel(false)


func _render_duel(picking: bool) -> void:
	for c in _duel_box.get_children():
		c.queue_free()
	UiKit.header(_duel_box, "결투 말뚝", close)
	if not picking:
		_duel_box.add_child(_wrap(UiKit.label("1대1로 겨룬다. 3판 2선승, 각인과 고유 능력은 쓰지 않는다. 지고 이겨도 얻는 것은 기록뿐이다.", 14, UiKit.MUTED)))
		_duel_box.add_child(UiKit.label("내 기록  이김 %d · 짐 %d" % [meta.duel_wins, meta.duel_losses], 15, UiKit.TEXT))
		_duel_box.add_child(UiKit.button("같은 PC로 겨루기", func() -> void:
			_duel_pick = [0, 0]
			var s := meta.sheath_sword(data)
			if s != null:
				_duel_pick = [meta.sheath_id, meta.sheath_id]
			_render_duel(true), 40.0))
		_duel_box.add_child(UiKit.button("모르는 사람과 겨루기", _render_online_pick, 40.0))
		return
	_duel_box.add_child(_wrap(UiKit.label("1P는 키보드와 마우스, 2P는 게임패드. 검집의 검이나 맨손을 든다. 결투에서는 부러지지 않는다.", 14, UiKit.MUTED)))
	var ids: Array[int] = [0]
	var names: Array[String] = ["맨손"]
	if meta.sheath_sword(data) != null:
		ids.append(meta.sheath_id)
		var d := data.sword_by_id(meta.sheath_id)
		names.append("[검집] %s · %s (%s)" % [data.grades.names[d.grade], d.display_name, data.forms[d.form].display_name])
	for who in 2:
		_duel_box.add_child(UiKit.label("1P" if who == 0 else "2P", 18, UiKit.TITLE))
		var pick := OptionButton.new()
		pick.focus_mode = Control.FOCUS_NONE
		pick.custom_minimum_size = Vector2(520, 36)
		for k in ids.size():
			pick.add_item(names[k], ids[k])
			if ids[k] == _duel_pick[who]:
				pick.select(k)
		pick.item_selected.connect(func(i: int) -> void: _duel_pick[who] = pick.get_item_id(i))
		_duel_box.add_child(pick)
	_duel_box.add_child(UiKit.button("겨룬다", func() -> void: duel_go.emit(_duel_pick[0], _duel_pick[1]), 40.0))


## 모르는 사람과 겨루기(22단계): 키가 없으면 안내만, 있으면 내 검을 고르고 찾는다.
func _render_online_pick() -> void:
	for c in _duel_box.get_children():
		c.queue_free()
	UiKit.header(_duel_box, "모르는 사람과 겨루기", func() -> void: _render_duel(false))
	if not GdSyncLink.has_keys():
		show_online_failed(OnlineDuel.key_help())
		return
	_duel_box.add_child(_wrap(UiKit.label("검집의 검이나 맨손을 들고 간다. 각자 3인칭으로 보고, 입력이 조금(약 0.13초) 늦게 먹는다. 3판 2선승, 이기고 져도 기록뿐이다.", 14, UiKit.MUTED)))
	var ids: Array[int] = [0]
	var names: Array[String] = ["맨손"]
	if meta.sheath_sword(data) != null:
		ids.append(meta.sheath_id)
		var d := data.sword_by_id(meta.sheath_id)
		names.append("[검집] %s · %s (%s)" % [data.grades.names[d.grade], d.display_name, data.forms[d.form].display_name])
	var pick_id: Array[int] = [ids[ids.size() - 1]]
	var pick := OptionButton.new()
	pick.focus_mode = Control.FOCUS_NONE
	pick.custom_minimum_size = Vector2(520, 36)
	for k in ids.size():
		pick.add_item(names[k], ids[k])
	pick.select(ids.size() - 1)
	pick.item_selected.connect(func(i: int) -> void: pick_id[0] = pick.get_item_id(i))
	_duel_box.add_child(pick)
	_duel_box.add_child(UiKit.button("상대를 찾는다", func() -> void: _render_online_wait(pick_id[0]), 40.0))


func _render_online_wait(pick_id: int) -> void:
	for c in _duel_box.get_children():
		c.queue_free()
	UiKit.header(_duel_box, "모르는 사람과 겨루기", close)
	_online_label = UiKit.label("서버에 접속하는 중", 18, UiKit.TEXT)
	_duel_box.add_child(_online_label)
	_duel_box.add_child(_wrap(UiKit.label("창을 닫으면 찾기를 그만둔다.", 14, UiKit.MUTED)))
	_duel_box.add_child(UiKit.button("취소", close, 40.0))
	_online_busy = true
	duel_online.emit(pick_id)


## 찾는 중의 한 줄(접속, 찾는 중, 기다리는 중, 준비).
func set_online_text(text: String) -> void:
	if _online_label != null and is_instance_valid(_online_label) and _online_busy:
		_online_label.text = text


## 찾기가 안 된다(키 없음, 접속 실패 …). 한 줄과 안내를 보여 주고 뒤로 간다.
func show_online_failed(text: String) -> void:
	_online_busy = false
	var lines: PackedStringArray = text.split("\n")
	var kids: Array[Node] = _duel_box.get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
	for i in range(2, kids.size()):   # 머리글과 줄은 남긴다
		kids[i].queue_free()
	_duel_box.add_child(UiKit.label(lines[0], 18, UiKit.TITLE))
	for i in range(1, lines.size()):
		_duel_box.add_child(_wrap(UiKit.label(lines[i], 14, UiKit.MUTED)))
	_duel_box.add_child(UiKit.button("뒤로", func() -> void: _render_duel(false), 40.0))


func _layer() -> Control:
	var c := ColorRect.new()
	c.color = Color(0.0, 0.0, 0.0, 0.62)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.visible = false
	add_child(c)
	return c


func _wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(520, 0)
	return l


static func _num(v: int) -> String:
	var s: String = str(absi(v))
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out
