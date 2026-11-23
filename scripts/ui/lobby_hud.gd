class_name LobbyHud
extends CanvasLayer
## 마을의 화면: 오른쪽 아래 조각, 아래 가운데 안내 띠(E), 대장간(검집 강화), 성소(축복), 검 진열대(도감과 기록).
## 엘든 링의 원탁처럼 글자를 세계에 띄우지 않고 화면 띠로만 알린다. 들어설 때 마을 이름을 크게 한 번 띄운다.
## 강화는 Meta가 굴리고, 이 창은 망치 소리와 결과만 보여 준다. 연출 위에 글자를 띄우지 않는다.

signal forge_hit(step: int)
signal forge_done(result: Dictionary, big: bool)
## 대장간 창에서 검집에 넣을 검을 바꿨다(모루 위 검을 다시 놓는다).
signal forge_changed
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
## 검 보관집(2026-11-21): 터에 집을 지었다(마을이 집을 올린다), 검집을 샀다(그 단계).
signal storage_built()
## 바깥 터 건물을 지었다(마을이 집을 올린다).
signal building_built(id: StringName)
## 주민 i의 일을 바꿨다(마을이 그 사람을 일터로 옮긴다).
signal job_set(i: int)
signal sheath_bought(level: int)

## 망치를 세 번 내리친 뒤 결과가 나온다(초).
@export var hammer_gap: float = 0.28
@export var result_delay: float = 0.5
## 대장간 망치질 사이(초): 대장장이가 한 번씩 내리치는 동작이 보이게 축복보다 느리다.
@export var forge_gap: float = 0.6

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
var _storage: Control
var _storage_box: VBoxContainer
var _bld: Control
var _bld_box: VBoxContainer
var _bld_data: BuildingData = null
var _jobs: Control
var _jobs_box: VBoxContainer
var _jobs_i: int = -1
var _rack: Control
var _rack_text: RichTextLabel
var _msg: Label
var _busy: bool = false
## 대장간 창의 마지막 결과(제목·색·아랫줄). 창을 새로 열거나 검을 바꾸면 비운다.
var _forge_last: Dictionary = {}
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
## 검 보관집(2026-11-21): 북문에서 고르는 나머지 칸의 검(칸 2부터, 0은 빈 칸).
var _gate_more: Array[int] = []
var _hp_bar: LifeBar
var _mats: MatsBar
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
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	sb.add_child(row)
	_mats = MatsBar.new()   # 나무·돌·쇠(마을 키우기 1단계)
	row.add_child(_mats)
	_shards = UiKit.label("", 20, UiKit.TITLE)
	row.add_child(_shards)
	_toast = Band.make(self, 96.0, 980.0, 50.0, 18)
	_prompt = Band.make(self, -110.0, 640.0, 50.0, 19)
	_say = DialogueBox.make(self)   # 대사: 이름 + 줄, 화면 아래 자막
	_title = AreaTitle.make(self)
	_forge = _layer()
	_forge_box = UiKit.center_panel(_forge)
	_shrine = _layer()
	_shrine_box = UiKit.center_panel(_shrine)
	_storage = _layer()
	_storage_box = UiKit.center_panel(_storage)
	_bld = _layer()
	_bld_box = UiKit.center_panel(_bld)
	_jobs = _layer()
	_jobs_box = UiKit.center_panel(_jobs)
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
	return _forge.visible or _shrine.visible or _storage.visible or _bld.visible or _jobs.visible or _rack.visible or _board.visible or _shop.visible or _yard.visible or _duel.visible


func close() -> void:
	if _busy:
		return
	_gate_mode = false
	if _online_busy:
		_online_busy = false
		duel_online_cancel.emit()
	_forge.visible = false
	_shrine.visible = false
	_storage.visible = false
	_bld.visible = false
	_jobs.visible = false
	_rack.visible = false
	_board.visible = false
	_shop.visible = false
	_yard.visible = false
	_duel.visible = false
	closed.emit()


## 들판·무덤의 내 체력 막대(17단계 → 2026-11-21 LifeBar): 글자 없이 막대만, 왼쪽 아래.
func set_hp(hp: float, max_hp: float) -> void:
	if _hp_bar == null:
		_hp_bar = LifeBar.new()
		add_child(_hp_bar)
	_hp_bar.set_hp(hp, max_hp)
	var sz: Vector2 = _hp_bar.custom_minimum_size
	_hp_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hp_bar.offset_left = 28
	_hp_bar.offset_right = 28 + sz.x
	_hp_bar.offset_top = -28 - sz.y
	_hp_bar.offset_bottom = -28


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
		UiKit.soft_shadow(_boss_name, 0.65)   # 테두리 대신 옅은 그림자(아래 어두운 띠가 받쳐 준다)
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


## 대사 글자가 아직 나오는 중이면 참(E는 먼저 다 보이게 한다).
func say_typing() -> bool:
	return _say.is_typing()


func say_finish() -> void:
	_say.finish_typing()


func say_end() -> void:
	_say.hide_box()


func area_title(t: String) -> void:
	_title.show_title(t)


# ---------------------------------------------------------------- 건물 안(2026-11-21)

var _fade: ColorRect = null


## 화면을 검게 덮거나(1) 걷는다(0). 끝나면 끝을 알리는 트윈을 돌려준다.
func fade_to(a: float, time: float) -> Tween:
	if _fade == null:
		_fade = ColorRect.new()
		_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade.color = Color(0, 0, 0, 0)
		add_child(_fade)
	move_child(_fade, get_child_count() - 1)
	var t := create_tween()
	t.tween_property(_fade, "color:a", a, time)
	return t


## 건물 안에서는 창을 화면 오른쪽에 두고 어둡게 덮지 않는다(안이 보이게, 아래에는 사람의 말).
func set_inside(on: bool) -> void:
	for layer in [_forge, _shrine, _storage, _bld, _jobs]:
		(layer as ColorRect).color = Color(0, 0, 0, 0.08 if on else 0.62)
		var c := (layer as Control).get_child(0) as Control
		if on:
			c.anchor_left = 0.56
			c.anchor_right = 0.98
			c.anchor_top = 0.04
			c.anchor_bottom = 0.74
		else:
			c.anchor_left = 0.0
			c.anchor_right = 1.0
			c.anchor_top = 0.0
			c.anchor_bottom = 1.0
		c.offset_left = 0
		c.offset_right = 0
		c.offset_top = 0
		c.offset_bottom = 0


func flash(c: Color, strength: float, time: float = 0.5) -> void:
	_flash.color = Color(c, strength)
	create_tween().tween_property(_flash, "color:a", 0.0, time)


func refresh_top() -> void:
	_shards.text = "조각  %s" % _num(meta.shards)
	if _mats and meta:
		_mats.refresh(meta, data)


## 주민이 늘었다(들판에서 풀어 줌): 사람 수 위에 +1.
func got_resident() -> void:
	refresh_top()
	_mats.pop(MatsBar.FOLK, 1)


## 재료를 얻었다: 숫자를 바꾸고 그 위에 +N을 잠깐 띄운다(들판에서 거둘 때).
func got_mat(id: StringName, n: int) -> void:
	refresh_top()
	_mats.pop(id, n)


# ---------------------------------------------------------------- 대장간

func open_forge() -> void:
	_forge.visible = true
	_forge_last = {}
	_render_forge("")


## 대장간 창(2026-11-24 사용자: "대장간 연출이랑 강화 보상이 직관적이지 않다"):
## 검집에 넣을 검과 그 카드 → 검집 강화 줄(ForgeTrack: 지금 단계, 각인 단계, 내려가는 단계) → 다음 단계에 무엇이 오르는지(피해·내구 숫자 앞뒤, 각인)
## → 성공 확률과 실패하면 어떻게 되는지 → 망치질 단추 → 결과(크게: 성공/그대로/내려감과 바뀐 숫자).
func _render_forge(msg: String) -> void:
	for c in _forge_box.get_children():
		c.queue_free()
	var md := data.meta
	UiKit.header(_forge_box, "대장간 · 검집 강화 +%d" % meta.sheath_lv, close)
	var cands := meta.sheath_candidates(data)
	var now := meta.sheath_sword(data)
	if cands.is_empty():
		_forge_box.add_child(_wrap(UiKit.label("검집에 넣을 검이 아직 없다. 전설 이상을 한 번 손에 넣으면 여기 놓인다(언덕에서 뽑거나 들판에서 얻기).\n강화는 미리 해 둘 수 있다. 나중에 넣는 검에 그 단계가 붙는다.", 15, UiKit.MUTED)))
	else:
		var pick := OptionButton.new()
		pick.focus_mode = Control.FOCUS_NONE
		for id in cands:
			var d := data.sword_by_id(id)
			pick.add_item("%s · %s (%s)" % [data.grades.names[d.grade], d.display_name, data.forms[d.form].display_name], id)
			if id == meta.sheath_id:
				pick.select(pick.item_count - 1)
		pick.disabled = _busy
		pick.item_selected.connect(func(i: int) -> void:
			meta.sheath_id = pick.get_item_id(i)
			meta.save()
			_forge_last = {}
			forge_changed.emit()
			_render_forge(""))
		_forge_box.add_child(pick)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiKit.style(data.grades.colors[now.grade] if now else Color.GRAY, 2))
		var r := UiKit.rich(15, 520)
		r.text = SwordCard.bbcode(now, data)
		card.add_child(r)
		_forge_box.add_child(card)
	_forge_box.add_child(UiKit.rule())
	_forge_box.add_child(UiKit.label("검집 강화", 17, UiKit.TITLE))
	_forge_box.add_child(UiKit.label("검이 아니라 검집이 단단해진다. 넣은 검을 바꿔도 단계와 각인은 남는다.", 13, UiKit.MUTED))
	var track := ForgeTrack.new()
	track.setup(meta.sheath_lv, meta.sheath_peak, md.sheath_max, md.sheath_drop_from, md.sheath_ins_levels)
	_forge_box.add_child(track)
	if meta.sheath_lv < md.sheath_max:
		var nx := UiKit.rich(16, 520)
		nx.text = _forge_next_bbcode(now, meta.sheath_lv + 1)
		_forge_box.add_child(nx)
		var odds := UiKit.rich(15, 520)
		var fail: String = ("[color=#%s]실패하면 +%d로 내려간다[/color]" % [FORGE_BAD.to_html(false), meta.sheath_lv - 1]) if meta.sheath_lv >= md.sheath_drop_from else "실패하면 그대로 +%d (조각만 든다)" % meta.sheath_lv
		odds.text = "성공 [b]%d%%[/b] · %s" % [roundi(meta.sheath_rate(md)), fail]
		_forge_box.add_child(odds)
		var cost: int = meta.sheath_cost(md)
		var b := UiKit.button("망치질 · 조각 %s%s" % [_num(cost), "  (모자람)" if meta.shards < cost else ""], _forge_sheath, 46)
		b.disabled = _busy
		_forge_box.add_child(b)
		if meta.has_recruit("smith"):
			_forge_box.add_child(UiKit.label("떠돌이 대장장이가 거든다: 망치질 값 -%d%%" % roundi((1.0 - FieldLayout.RECRUIT_FORGE) * 100.0), 13, UiKit.MUTED))
	else:
		_forge_box.add_child(UiKit.label("끝까지 벼렸다.", 16, UiKit.TITLE))
	# 결과(크게)
	if not _forge_last.is_empty():
		_forge_box.add_child(UiKit.rule())
		var big := UiKit.label(str(_forge_last.title), 24, _forge_last.col)
		_forge_box.add_child(big)
		if str(_forge_last.sub) != "":
			var sub := UiKit.rich(15, 520)
			sub.text = str(_forge_last.sub)
			_forge_box.add_child(sub)
		if bool(_forge_last.get("pop", false)):
			_forge_last.pop = false
			big.modulate = Color(2.2, 2.0, 1.6)
			create_tween().tween_property(big, "modulate", Color.WHITE, 0.6)
	_msg = UiKit.label(msg, 18, UiKit.TITLE)
	_forge_box.add_child(_msg)


const FORGE_GOLD := Color(0.95, 0.78, 0.4)
const FORGE_BAD := Color(0.86, 0.36, 0.28)


## 검집 단계 lv일 때 넣은 검의 모습(창의 앞뒤 숫자). 검이 없으면 null.
func _sheath_at(lv: int) -> Sword:
	var s := meta.sheath_sword(data)
	if s == null:
		return null
	var t := Sword.new(s.data, data)
	t.apply_sheath(lv, meta.sheath_ins, data)
	return t


## "피해 73 → 77 · 내구 246 → 264" (검이 없으면 % 앞뒤).
func _forge_diff(a_lv: int, b_lv: int) -> String:
	var md := data.meta
	var a := _sheath_at(a_lv)
	var b := _sheath_at(b_lv)
	var gold: String = FORGE_GOLD.to_html(false) if b_lv > a_lv else FORGE_BAD.to_html(false)
	if a == null:
		return "피해 +%d%% → [color=#%s]+%d%%[/color] · 내구 +%d%% → [color=#%s]+%d%%[/color]" % [roundi(md.sheath_damage * 100 * a_lv), gold, roundi(md.sheath_damage * 100 * b_lv), roundi(md.sheath_durability * 100 * a_lv), gold, roundi(md.sheath_durability * 100 * b_lv)]
	var t: String = "피해 %d → [color=#%s]%d[/color]" % [roundi(a.damage(data)), gold, roundi(b.damage(data))]
	if a.breakable():
		t += " · 내구 %d → [color=#%s]%d[/color]" % [roundi(a.max_durability), gold, roundi(b.max_durability)]
	return t


## 다음 단계에 오르는 것: "+4 → +5  피해 73 → 77 · 내구 …" 그리고 처음 닿는 각인 단계면 각인 줄.
func _forge_next_bbcode(_now: Sword, nxt: int) -> String:
	var md := data.meta
	var t: String = "[b][color=#%s]+%d → +%d[/color][/b]   %s" % [FORGE_GOLD.to_html(false), meta.sheath_lv, nxt, _forge_diff(meta.sheath_lv, nxt)]
	if md.sheath_ins_levels.has(nxt) and nxt > meta.sheath_peak:
		t += "\n[color=#%s]◆ +%d에 처음 닿으면 각인 하나가 붙는다[/color]" % [FORGE_GOLD.to_html(false), nxt]
	return t


# ---------------------------------------------------------------- 검 보관집(2026-11-21)

## 터(짓기 전)나 집(지은 뒤)에서 E. 지으면 창을 닫고 마을이 집을 한 조각씩 올린다. 집에서는 검집을 단계로 산다.
func open_storage() -> void:
	_storage.visible = true
	_render_storage("")


func _render_storage(msg: String) -> void:
	for c in _storage_box.get_children():
		c.queue_free()
	var md := data.meta
	var held: String = "지금 언덕 판 %d칸 · 들판 %d칸" % [meta.hill_slots(), meta.field_slots()]
	if not meta.storage_house:
		UiKit.header(_storage_box, "검 보관집 터", close)
		_storage_box.add_child(_wrap(UiKit.label("집을 지으면 그 안에서 검집을 살 수 있다. 검집이 늘면 언덕 판과 들판에서 한 번에 드는 검이 는다.", 15, UiKit.MUTED)))
		_storage_box.add_child(UiKit.label(held, 15, UiKit.TEXT))
		_storage_box.add_child(UiKit.button("검 보관집 짓기 · 조각 %s" % _num(meta.house_cost(md)), _build_house, 46))
	else:
		UiKit.header(_storage_box, "검 보관집 · 검집", close)
		_storage_box.add_child(UiKit.label(held, 15, UiKit.TEXT))
		for i in md.storage_costs.size():
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 14)
			var txt := UiKit.label("검집 %d단계\n언덕 판 %d칸 · 들판 %d칸" % [i + 1, 3 + i, 3 + i], 15)
			txt.custom_minimum_size = Vector2(360, 0)
			row.add_child(txt)
			if i < meta.storage_lv:
				row.add_child(UiKit.label("걸려 있다", 15, UiKit.MUTED))
			elif i == meta.storage_lv:
				var b := UiKit.button("조각 %s" % _num(md.storage_costs[i]), _buy_sheath)
				b.custom_minimum_size = Vector2(180, 40)
				row.add_child(b)
			else:
				row.add_child(UiKit.label("앞 단계를 먼저", 15, UiKit.MUTED))
			_storage_box.add_child(row)
	_msg = UiKit.label(msg, 18, UiKit.TITLE)
	_storage_box.add_child(_msg)


# ---------------------------------------------------------------- 바깥 터 건물(마을 키우기 2단계)

## 터(짓기 전)나 집(지은 뒤)에서 E. 짓기 전: 하는 일과 값(재료 그림 + 가진 수/드는 수), 짓기 단추.
## 지은 뒤: 하는 일 한 줄(판마다 모아 두는 양). 지으면 창을 닫고 마을이 집을 한 조각씩 올린다.
func open_building(b: BuildingData) -> void:
	if b == null:
		return
	_bld_data = b
	_bld.visible = true
	_render_building("")


func _render_building(msg: String) -> void:
	for c in _bld_box.get_children():
		c.queue_free()
	var b := _bld_data
	var done: bool = meta.has_built(b.id)
	UiKit.header(_bld_box, b.display_name if done else "%s 터" % b.display_name, close)
	_bld_box.add_child(_wrap(UiKit.label(b.desc, 15, UiKit.TEXT)))
	var made: Array[String] = []
	for id in Meta.MAT_IDS:
		if int(b.made()[id]) > 0:
			made.append("%s +%d" % [Meta.MAT_NAMES[id], int(b.made()[id])])
	if not made.is_empty():
		_bld_box.add_child(UiKit.label("판마다  " + " · ".join(made), 15, UiKit.MUTED))
	if not done:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		for id in b.cost():
			var need: int = int(b.cost()[id])
			var cell := HBoxContainer.new()
			cell.add_theme_constant_override("separation", 6)
			var icon := Control.new()
			icon.custom_minimum_size = Vector2(MatsBar.ICON, MatsBar.ICON)
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var kind: StringName = id
			icon.draw.connect(func() -> void: MatsBar.draw_icon(icon, kind))
			cell.add_child(icon)
			cell.add_child(UiKit.label("%d / %d" % [meta.mat(id), need], 17, UiKit.TEXT if meta.mat(id) >= need else UiKit.MUTED))
			row.add_child(cell)
		_bld_box.add_child(row)
		var go := UiKit.button("짓기", _build_building, 46)
		go.disabled = not meta.can_pay(b.cost()) or not meta.tier_allows(b, data)
		if not meta.tier_allows(b, data):   # 눌리지 않는 까닭(화면에 안 보이는 것)
			go.text = "%s이 되어야 지을 수 있다" % data.meta.tier_names[b.min_tier]
		_bld_box.add_child(go)
	_msg = UiKit.label(msg, 18, UiKit.TITLE)
	_bld_box.add_child(_msg)


# ---------------------------------------------------------------- 시작 구역(마을 키우기 5단계)

## 들판의 언덕길에서 E: 마을 단계가 연 구역 중 어디부터 오를지. 고르면 picked(구역)를 부른다.
func open_climb(starts: Array[int], current: int, picked: Callable) -> void:
	_jobs_i = -1
	_jobs.visible = true
	for c in _jobs_box.get_children():
		c.queue_free()
	UiKit.header(_jobs_box, "언덕으로 오른다", close)
	for z in starts:
		var zz: int = z
		var b := UiKit.button("%d구역부터" % z, func() -> void:
			close()
			picked.call(zz), 44)
		if z == current:
			b.text += "  ·  지난번"
		_jobs_box.add_child(b)


# ---------------------------------------------------------------- 주민의 일(마을 키우기 3단계)

## 주민에게 E: 쉰다 / 지은 일터(일꾼 수/자리, 일꾼 하나가 판마다 더 모으는 몫). 지금 하는 일은 눌리지 않는다.
func open_jobs(i: int) -> void:
	if i < 0 or i >= meta.residents.size():
		return
	_jobs_i = i
	_jobs.visible = true
	_render_jobs()


func _render_jobs() -> void:
	for c in _jobs_box.get_children():
		c.queue_free()
	var r: Dictionary = meta.residents[_jobs_i]
	UiKit.header(_jobs_box, r.name, close)
	var rest := UiKit.button("쉰다", func() -> void: _pick_job(&""), 40)
	rest.disabled = r.job == &""
	_jobs_box.add_child(rest)
	for b in data.buildings:
		if b.workers <= 0 or not meta.has_built(b.id):
			continue
		var gain: Array[String] = []
		for id in Meta.MAT_IDS:
			if int(b.made()[id]) > 0:
				gain.append("%s +%d" % [Meta.MAT_NAMES[id], b.per_worker])
		var id: StringName = b.id
		var btn := UiKit.button("%s  %d/%d  ·  판마다 %s" % [b.display_name, meta.workers_at(b.id), b.workers, " ".join(gain)], func() -> void: _pick_job(id), 40)
		btn.disabled = r.job == b.id or meta.workers_at(b.id) >= b.workers
		_jobs_box.add_child(btn)


func _pick_job(id: StringName) -> void:
	if meta.set_job(_jobs_i, id, data):
		meta.save()
		job_set.emit(_jobs_i)
	close()


func _build_building() -> void:
	var b := _bld_data
	if not meta.build(b, data):
		_render_building("재료가 모자라.")
		return
	meta.save()
	refresh_top()
	close()
	building_built.emit(b.id)


func _build_house() -> void:
	var c: int = meta.house_cost(data.meta)
	if not meta.build_house(data.meta):
		_render_storage("조각이 %s 모자라." % _num(maxi(0, c - meta.shards)))
		return
	meta.save()
	refresh_top()
	close()
	storage_built.emit()


func _buy_sheath() -> void:
	var c: int = meta.storage_cost(data.meta)
	if not meta.buy_sheath(data.meta):
		_render_storage("조각이 %s 모자라." % _num(maxi(0, c - meta.shards)))
		return
	meta.save()
	refresh_top()
	sheath_bought.emit(meta.storage_lv)
	_render_storage("검집 %d단계를 걸었다. 이제 언덕 판 %d칸, 들판 %d칸에 검을 든다." % [meta.storage_lv, meta.hill_slots(), meta.field_slots()])


func _forge_sheath() -> void:
	if _busy:
		return
	var cost: int = meta.sheath_cost(data.meta)
	if meta.shards < cost:
		_forge_last = {}
		_render_forge("조각이 %s 모자라." % _num(cost - meta.shards))
		return
	_busy = true
	_forge_last = {"title": "망치질", "sub": "", "col": UiKit.MUTED}
	_render_forge("")
	var beats: PackedStringArray = PackedStringArray()
	for i in 3:
		await get_tree().create_timer(forge_gap).timeout
		forge_hit.emit(i + 1)
		beats.append("땅!")
		_forge_last = {"title": "  ".join(beats), "sub": "", "col": UiKit.TITLE}
		_render_forge("")
	await get_tree().create_timer(result_delay).timeout
	var lv0: int = meta.sheath_lv
	var r := meta.forge_sheath(data)
	meta.save()
	_busy = false
	if r.ok:
		_forge_last = {"title": "성공 · 검집 +%d" % meta.sheath_lv, "col": FORGE_GOLD, "pop": true,
			"sub": _forge_diff(lv0, meta.sheath_lv) + ("\n[color=#%s]◆ 각인 「%s」이(가) 붙었다[/color]" % [FORGE_GOLD.to_html(false), r.ins] if r.ins != "" else "")}
	elif r.dropped:
		_forge_last = {"title": "실패 · +%d → +%d" % [lv0, meta.sheath_lv], "col": FORGE_BAD, "pop": true,
			"sub": "검집이 한 단계 내려갔다. " + _forge_diff(lv0, meta.sheath_lv)}
	else:
		_forge_last = {"title": "실패 · 그대로 +%d" % lv0, "col": UiKit.MUTED, "pop": true, "sub": "조각 %s만 들었다. 단계는 그대로다." % _num(cost)}
	forge_done.emit(r, r.ok and meta.sheath_lv >= 7 and meta.sheath_lv > lv0)
	refresh_top()
	_render_forge("")


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
	_render_heads()
	_msg = UiKit.label(msg, 18, UiKit.TITLE)
	_shrine_box.add_child(_msg)


## 머리(Heads, 2026-11-23): 가진 머리를 늘어놓고 하나를 쓴다(값 없음, 바꾸기 자유).
func _render_heads() -> void:
	_shrine_box.add_child(UiKit.label("머리", 18, UiKit.TITLE))
	if meta.heads.is_empty():
		_shrine_box.add_child(UiKit.label("아직 없다. 들판과 무덤의 우두머리를 쓰러뜨리면 가끔 떨어진다.", 13, UiKit.MUTED))
		return
	for id in meta.heads.keys():
		var i: Dictionary = Heads.info(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var sw := ColorRect.new()
		sw.color = i.glow
		sw.custom_minimum_size = Vector2(10, 34)
		row.add_child(sw)
		var txt := UiKit.label("%s\n%s" % [i.name, Heads.describe(i)], 14)
		txt.custom_minimum_size = Vector2(380, 0)
		row.add_child(txt)
		var on: bool = meta.head == id
		var b := UiKit.button("벗기" if on else "쓰기", func() -> void:
			meta.head = "" if on else id
			meta.save()
			ObjectHead.lord_info = Heads.info(meta.head) if meta.head != "" else {}
			_render_shrine("머리를 벗었다. 영주를 다시 세우면 보인다." if on else "%s를 썼다. 다음 장면부터 보인다." % i.name))
		b.custom_minimum_size = Vector2(110, 36)
		row.add_child(b)
		_shrine_box.add_child(row)


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
			var nxt: int = meta.memory_next(ids[i])
			var nl: String = ("  ·  다음 기억까지 %d" % nxt) if nxt > 0 else ""
			t += "  [color=#%s]%s[/color]%s  [color=#99917f]%s%s[/color]\n" % [col, meta.memory_title(sd), mark, meta.log_line(ids[i]), nl]
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
		_yard_box.add_child(_wrap(UiKit.label("고른 검은 마을에서만 쥔다.", 14, UiKit.MUTED)))
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
	if _gate_mode and meta.field_slots() > 1:
		# 검 보관집: 칸 2부터 더 들고 나간다(Q·숫자 키로 바꿔 쥔다)
		_gate_more.resize(meta.field_slots() - 1)
		for j in _gate_more.size():
			var more := OptionButton.new()
			more.focus_mode = Control.FOCUS_NONE
			more.custom_minimum_size = Vector2(520, 32)
			more.add_item("%d번 칸: 비움" % (j + 2), 0)
			for id in ids:
				var d := data.sword_by_id(id)
				more.add_item("%d번 칸: %s · %s (%s)" % [j + 2, data.grades.names[d.grade], d.display_name, data.forms[d.form].display_name], id)
				if id == _gate_more[j]:
					more.select(more.item_count - 1)
			var slot: int = j
			more.item_selected.connect(func(i: int) -> void:
				_gate_more[slot] = more.get_item_id(i))
			_yard_box.add_child(more)
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
		_yard_box.add_child(UiKit.button("나선다", func() -> void:
			Meta.carry_more = _gate_more.duplicate()
			field_go.emit(_gate_pick), 40.0))


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
		if data.duel.online_enabled:   # 내보내는 데모에서는 끈다(data/duel.tres, 실제 서버 확인 전)
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
