class_name LeagueResult
extends VBoxContainer
## 랭크 결투 뒤의 RR 변화(docs/duel_league.md 7): 이긴 쪽은 막대가 오르며 숫자가 세어 오르고, 진 쪽은 내려간다.
## 승급은 금빛, 강등은 붉은 번쩍임. 배치 중에는 배치 줄만, 배치가 끝나는 판에는 정해진 티어를 보인다.
## 한 숫자 P = 걸음 × 100 + RR을 처음 값에서 나중 값까지 움직이며 매 프레임 티어·단계·RR을 다시 읽는다.

var _res: Dictionary = {}
var _emblem: TextureRect
var _name: Label
var _bar: ProgressBar
var _rr: Label
var _delta: Label
var _flash: ColorRect
var _shown_step: int = -1
## 시험이 들여다본다: 마지막으로 보인 P.
var shown_p: float = 0.0


func setup(res: Dictionary) -> void:
	_res = res


func _ready() -> void:
	build()
	play()


## 화면 조각을 짓는다(시험은 트리 밖에서 이것만 부른다).
func build() -> void:
	add_theme_constant_override("separation", 6)
	var ld: LeagueData = League.data()
	var win: bool = bool(_res.get("win", false))
	var head := UiKit.label("랭크 결과", 15, UiKit.MUTED)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(head)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(340, 96)
	add_child(holder)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(cc)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(row)
	holder.add_child(_flash)
	_emblem = LeagueUi.emblem(0, 84.0)
	row.add_child(_emblem)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)
	_name = UiKit.label("", 22, UiKit.TITLE)
	col.add_child(_name)
	_bar = LeagueUi.rr_bar(UiKit.LINE, 200.0)
	col.add_child(_bar)
	_rr = UiKit.label("", 14, UiKit.TEXT)
	col.add_child(_rr)
	_delta = UiKit.label("", 26, Color(0.95, 0.82, 0.4) if win else Color(0.85, 0.35, 0.35))
	_delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_delta)
	if bool(_res.get("placing", false)):
		_show_placement(ld)
		return
	_apply(float(int(_res.step_before) * 100 + int(_res.rr_before)))


## 숫자가 오르내리고 승급·강등이면 번쩍인다.
func play() -> void:
	if bool(_res.get("placing", false)):
		return
	var ld: LeagueData = League.data()
	var win: bool = bool(_res.get("win", false))
	var p0: float = float(int(_res.step_before) * 100 + int(_res.rr_before))
	var p1: float = float(int(_res.step_after) * 100 + int(_res.rr_after))
	var d: int = int(_res.get("delta", 0))
	_delta.text = ("%+d RR" % d) if not bool(_res.get("shielded", false)) else "강등 보호 (RR 0)"
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_method(_apply, p0, p1, ld.anim_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if bool(_res.get("promoted", false)) or bool(_res.get("demoted", false)):
		var up: bool = bool(_res.get("promoted", false))
		tw.tween_callback(func() -> void:
			_delta.text = ("승급  %s" if up else "강등  %s") % League.step_name(int(_res.step_after), ld)
			_flash.color = Color(1.0, 0.86, 0.45, 0.55) if up else Color(0.8, 0.12, 0.14, 0.5)
			var fl := create_tween()
			fl.tween_property(_flash, "color:a", 0.0, ld.flash_time))


## 배치 중: 판 수 줄. 마지막 배치 판이면 정해진 티어까지.
func _show_placement(ld: LeagueData) -> void:
	_emblem.visible = true
	if bool(_res.get("placed_now", false)):
		_set_step(int(_res.step_after))
		_name.text = "배치 완료  %s" % League.step_name(int(_res.step_after), ld)
		_bar.value = 0.0
		_rr.text = "RR 0 / %d" % ld.rr_max
		_delta.text = "시작 티어가 정해졌다"
		_flash.color = Color(1.0, 0.86, 0.45, 0.5)
		if is_inside_tree():
			create_tween().tween_property(_flash, "color:a", 0.0, ld.flash_time + 0.4)
	else:
		_set_step(0)
		_name.text = "배치 중"
		_bar.max_value = float(ld.placement_games)
		_bar.value = float(int(_res.get("games", 0)))
		_rr.text = "배치 %d/%d" % [int(_res.get("games", 0)), ld.placement_games]
		_delta.text = "이겼다" if bool(_res.get("win", false)) else "졌다"


func _set_step(step: int) -> void:
	if step == _shown_step:
		return
	_shown_step = step
	var path: String = LeagueUi.EMBLEM_DIR % League.emblem_of(step)
	if ResourceLoader.exists(path):
		_emblem.texture = load(path) as Texture2D
	var col: Color = LeagueUi.color_of(step)
	_bar.add_theme_stylebox_override("fill", _fill(col))


func _fill(col: Color) -> StyleBoxFlat:
	var f := UiKit.style(col, 0, col)
	f.set_content_margin_all(0)
	return f


## P(걸음 × 100 + RR)를 화면에 그린다.
func _apply(p: float) -> void:
	shown_p = p
	var ld: LeagueData = League.data()
	var step: int = clampi(floori(p / float(ld.rr_max)), 0, League.MAX_STEP)
	var rr: float = p - float(step * ld.rr_max)
	_set_step(step)
	_name.text = League.step_name(step, ld)
	_bar.value = minf(rr, float(ld.rr_max))
	_rr.text = "RR %d / %d" % [roundi(rr), ld.rr_max]
