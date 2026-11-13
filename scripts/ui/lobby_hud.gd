class_name LobbyHud
extends CanvasLayer
## 마을의 화면: 위의 기록 줄, 대장간(검집 강화), 성소(축복), 검 진열대(도감).
## 강화는 Meta가 굴리고, 이 창은 망치 소리와 결과만 보여 준다. 연출 위에 글자를 띄우지 않는다.

signal forge_hit(step: int)
signal forge_done(result: Dictionary, big: bool)
signal closed()

## 망치를 세 번 내리친 뒤 결과가 나온다(초).
@export var hammer_gap: float = 0.28
@export var result_delay: float = 0.4

var data: GameData
var meta: Meta
var _top: Label
var _toast: Label
var _toast_box: PanelContainer
var _toast_t: float = 0.0
var _flash: ColorRect
var _forge: Control
var _forge_box: VBoxContainer
var _shrine: Control
var _shrine_box: VBoxContainer
var _rack: Control
var _rack_text: RichTextLabel
var _msg: Label
var _busy: bool = false
var _help: Label


## 마을이 _ready에서 부른다(이 창의 _ready가 먼저 돈다).
func setup(d: GameData, m: Meta) -> void:
	data = d
	meta = m
	refresh_top()


func _ready() -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UiKit.style(Color(1, 1, 1, 0.08)))
	bar.position = Vector2(16, 14)
	add_child(bar)
	_top = UiKit.label("", 17)
	bar.add_child(_top)
	_help = UiKit.label("WASD 걷기 · 마우스 둘러보기 · E 들어가기 · Esc 닫기/마우스 풀기 · V 카메라", 13, Color(0.6, 0.65, 0.75))
	_help.position = Vector2(18, 62)
	add_child(_help)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	center.offset_top = 110
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_toast_box = PanelContainer.new()
	_toast_box.add_theme_stylebox_override("panel", UiKit.style(Color(1, 1, 1, 0.06)))
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast = UiKit.label("", 17)
	_toast_box.add_child(_toast)
	_toast_box.modulate.a = 0.0
	center.add_child(_toast_box)
	_forge = _layer()
	_forge_box = UiKit.center_panel(_forge, Color(1, 0.75, 0.4, 0.5))
	_shrine = _layer()
	_shrine_box = UiKit.center_panel(_shrine, Color(0.6, 0.8, 1, 0.5))
	_rack = _layer()
	var rb := UiKit.center_panel(_rack)
	var head := HBoxContainer.new()
	var t := UiKit.label("검 진열대 · 도감", 24)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UiKit.button("닫기 (Esc)", close))
	rb.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(820, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rack_text = UiKit.rich(14, 800)
	scroll.add_child(_rack_text)
	rb.add_child(scroll)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	add_child(_flash)


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast_box.modulate.a = clampf(_toast_t / 0.4, 0.0, 1.0)


func is_open() -> bool:
	return _forge.visible or _shrine.visible or _rack.visible


func close() -> void:
	if _busy:
		return
	_forge.visible = false
	_shrine.visible = false
	_rack.visible = false
	closed.emit()


func toast(t: String) -> void:
	_toast.text = t
	_toast_t = 4.0
	_toast_box.modulate.a = 1.0


func flash(c: Color, strength: float, time: float = 0.5) -> void:
	_flash.color = Color(c, strength)
	create_tween().tween_property(_flash, "color:a", 0.0, time)


func refresh_top() -> void:
	var dex: int = meta.found.size()
	var best: String = "없음" if meta.best == 0 else ("정상" if meta.best > data.run.zone_names.size() else "%d구역" % meta.best)
	_top.text = "조각 %s  ·  최고 기록 %s  ·  도감 %d / %d  ·  오른 횟수 %d" % [_num(meta.shards), best, dex, data.swords.size(), meta.runs]


# ---------------------------------------------------------------- 대장간

func open_forge() -> void:
	_forge.visible = true
	_render_forge("")


func _render_forge(msg: String) -> void:
	for c in _forge_box.get_children():
		c.queue_free()
	var md := data.meta
	var head := HBoxContainer.new()
	var t := UiKit.label("대장간 · 검집 +%d" % meta.sheath_lv, 26, Color(1, 0.86, 0.5))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UiKit.button("닫기 (Esc)", close))
	_forge_box.add_child(head)
	var cands := meta.sheath_candidates(data)
	if cands.is_empty():
		_forge_box.add_child(_wrap(UiKit.label("검집에는 언덕에서 뽑아 본 전설 이상의 검만 넣을 수 있다. 아직 없다.\n검집 강화는 미리 해 둘 수 있다. 나중에 넣는 검에 그 단계가 붙는다.", 15, Color(0.7, 0.74, 0.82))))
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
	_forge_box.add_child(UiKit.label("검집 효과: 피해 +%d%% · 내구 +%d%% · 붙은 각인 %s" % [roundi(md.sheath_damage * 100 * meta.sheath_lv), roundi(md.sheath_durability * 100 * meta.sheath_lv), ins], 15, Color(0.8, 0.84, 0.92)))
	if meta.sheath_lv < md.sheath_max:
		var b := UiKit.button("망치질 · 조각 %s · 성공 %d%%" % [_num(meta.sheath_cost(md)), roundi(meta.sheath_rate(md))], _forge_sheath, 46)
		b.disabled = _busy
		_forge_box.add_child(b)
		var note: String = "실패하면 한 단계 내려간다." if meta.sheath_lv >= md.sheath_drop_from else "+%d부터는 실패하면 한 단계 내려간다." % md.sheath_drop_from
		_forge_box.add_child(UiKit.label(note + " +5, +10에 처음 닿으면 각인이 붙는다.", 13, Color(0.6, 0.65, 0.75)))
	else:
		_forge_box.add_child(UiKit.label("끝까지 벼렸다.", 16, Color(1, 0.86, 0.5)))
	_msg = UiKit.label(msg, 18, Color(1, 0.89, 0.63))
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
	var head := HBoxContainer.new()
	var t := UiKit.label("성소 · 축복", 26, Color(0.7, 0.85, 1))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UiKit.button("닫기 (Esc)", close))
	_shrine_box.add_child(head)
	_shrine_box.add_child(UiKit.label("실패해도 내려가지 않는다.", 13, Color(0.6, 0.65, 0.75)))
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
			row.add_child(UiKit.label("끝", 15, Color(0.6, 0.65, 0.75)))
		_shrine_box.add_child(row)
	_msg = UiKit.label(msg, 18, Color(0.75, 0.88, 1))
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
	var t: String = ""
	for g in data.grades.names.size():
		var ids: PackedInt32Array = data.swords_by_grade[g]
		var n: int = 0
		for i in ids:
			n += 1 if meta.has_found(data.swords[i].id) else 0
		var col: String = data.grades.colors[g].to_html(false)
		t += "[b][color=#%s]%s[/color][/b]  [color=#8b96b3]%d / %d · 1/%s[/color]\n" % [col, data.grades.names[g], n, ids.size(), _num(int(data.grades.odds[g]))]
		var names: Array[String] = []
		for i in ids:
			var sd := data.swords[i]
			names.append(sd.display_name + ("" if int(meta.found.get(str(sd.id), 0)) < 2 else " ×%d" % int(meta.found[str(sd.id)])) if meta.has_found(sd.id) else "[color=#4a5060]???[/color]")
		t += "  ·  ".join(names) + "\n\n"
	_rack_text.text = t
	_rack.visible = true


func _layer() -> Control:
	var c := ColorRect.new()
	c.color = Color(0.02, 0.025, 0.05, 0.6)
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
