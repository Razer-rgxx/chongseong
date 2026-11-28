class_name LeagueUi
extends RefCounted
## 결투 리그 화면 조각(docs/duel_league.md): 티어 문장, 티어와 RR 막대 카드. 그림이 먼저고 글은 짧게.
## 문장은 assets/ui/league/tier_<n>.svg(scripts/debug/build_league_emblems.gd가 만든다).

const EMBLEM_DIR: String = "res://assets/ui/league/tier_%d.svg"
## 티어 색(문장과 같은 결): 막대와 글에 쓴다.
const TIER_COLORS: Array[Color] = [
	Color("#8a5a3c"), Color("#b0713a"), Color("#b9c0c8"), Color("#d4b04a"), Color("#5fc7bb"),
	Color("#6f9bff"), Color("#58c78d"), Color("#c0394d"), Color("#f0e2a8"),
]


static func emblem(step: int, size: float = 64.0) -> TextureRect:
	var t := TextureRect.new()
	var path: String = EMBLEM_DIR % League.emblem_of(step)
	if ResourceLoader.exists(path):
		t.texture = load(path) as Texture2D
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func color_of(step: int) -> Color:
	return TIER_COLORS[League.emblem_of(step)]


static func rr_bar(col: Color, width: float = 220.0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = float(League.data().rr_max)
	bar.custom_minimum_size = Vector2(width, 12)
	var bg := UiKit.style(Color(UiKit.LINE, 0.5), 1, Color(0.02, 0.018, 0.015, 0.8))
	var fill := UiKit.style(col, 0, col)
	for sb in [bg, fill]:
		sb.set_content_margin_all(0)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


## 내 티어 카드: 문장, 티어 이름과 단계, RR 막대(배치 중이면 배치 줄), 칭호.
static func card(meta: Meta, size: float = 72.0, bar_width: float = 220.0) -> Control:
	var ld: LeagueData = League.data()
	var st: Dictionary = League.state(meta)
	var step: int = League.shown_step(meta)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(emblem(step if not League.placing(meta) else 0, size))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	if League.placing(meta):
		col.add_child(UiKit.label("배치 중", 22, UiKit.TITLE))
		var bar := rr_bar(UiKit.LINE, bar_width)
		bar.max_value = float(ld.placement_games)
		bar.value = float(int(st.games))
		col.add_child(bar)
		col.add_child(UiKit.label("랭크 결투 %d/%d판 (시작 티어는 금 1까지)" % [int(st.games), ld.placement_games], 13, UiKit.MUTED))
	else:
		col.add_child(UiKit.label(League.step_name(step, ld), 22, color_of(step).lerp(UiKit.TITLE, 0.35)))
		var bar2 := rr_bar(color_of(step), bar_width)
		bar2.value = float(mini(int(st.rr), ld.rr_max))
		col.add_child(bar2)
		col.add_child(UiKit.label("RR %d / %d" % [int(st.rr), ld.rr_max], 13, UiKit.MUTED))
	var t: String = League.title_text(meta, ld)
	if t != "":
		col.add_child(UiKit.label("칭호  「%s」" % t, 13, UiKit.LINE))
	return row


## 랭크 결투가 끝난 뒤의 RR 변화 판(문장이 바뀌고 막대가 세어 올라가거나 내려간다).
static func result_panel(res: Dictionary) -> Control:
	var p := LeagueResult.new()
	p.setup(res)
	return p
