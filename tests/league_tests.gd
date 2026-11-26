extends RefCounted
## 결투 리그 테스트(docs/duel_league.md). run_all.gd가 부른다: run(데이터, check). 네트워크와 실제 저장 파일은 쓰지 않는다.

const TMP: String = "user://테스트_league.json"

var check: Callable
var ld: LeagueData


static func run(_game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/league_tests.gd") as GDScript).new()
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	ld = League.data()
	_data()
	_amounts()
	_placement()
	_promote_demote()
	_protection()
	_top()
	_season()
	_eligibility()
	_local_duel()
	_save()
	_pending()
	_board()
	_admin()
	_ui()


## 배치를 마친 상태의 Meta: 걸음과 RR을 정한다.
func _at(step: int, rr: int, mmr: float = -1.0) -> Meta:
	var m := Meta.new()
	var st: Dictionary = League.state(m)
	st.games = ld.placement_games
	st.step = step
	st.rr = rr
	st.peak = step
	st.mmr = League.nominal(step, ld) if mmr < 0.0 else mmr
	return m


func _data() -> void:
	check.call(ld.tier_names.size() == 8 and ld.tier_names[0] == "녹쇠" and ld.tier_names[7] == "불멸" and ld.top_name == "언덕의 검", "리그: 티어 여덟과 언덕의 검 이름이 data/league.tres에 있다")
	check.call(League.step_name(0, ld) == "녹쇠 1" and League.step_name(8, ld) == "은 3" and League.step_name(23, ld) == "불멸 3" and League.step_name(24, ld) == "언덕의 검", "리그: 걸음 → 이름(티어 + 단계, 24는 언덕의 검)")
	var all_art: bool = true
	for t in 9:
		all_art = all_art and FileAccess.file_exists("res://assets/ui/league/tier_%d.svg" % t)
	check.call(all_art, "리그: 티어 문장 아홉이 assets/ui/league에 있다")
	var shapes: Dictionary = {}
	for t in 9:
		var f := FileAccess.open("res://assets/ui/league/tier_%d.svg" % t, FileAccess.READ)
		shapes[f.get_as_text()] = true
	check.call(shapes.size() == 9, "리그: 문장 아홉이 모두 다르다")


func _amounts() -> void:
	var ok: bool = true
	for step in [0, 6, 12, 23]:
		for dm in [-400.0, -100.0, 0.0, 100.0, 400.0]:
			var mmr: float = League.nominal(step, ld) + dm
			var w: int = League.win_gain(mmr, step, ld)
			var l: int = League.loss_cost(mmr, step, ld)
			ok = ok and w >= 18 and w <= 28 and l >= 12 and l <= 22
	check.call(ok, "리그: 이기면 +18~28, 지면 -12~22 안에 든다")
	check.call(League.win_gain(League.nominal(6, ld), 6, ld) == ld.win_base and League.loss_cost(League.nominal(6, ld), 6, ld) == ld.loss_base, "리그: MMR이 기준과 같으면 기본값(+23, -17)")
	check.call(League.win_gain(League.nominal(6, ld) + 100.0, 6, ld) > League.win_gain(League.nominal(6, ld) - 100.0, 6, ld), "리그: MMR이 높으면 이길 때 더 받는다")
	check.call(League.loss_cost(League.nominal(6, ld) + 100.0, 6, ld) < League.loss_cost(League.nominal(6, ld) - 100.0, 6, ld), "리그: MMR이 높으면 질 때 덜 깎인다")
	var m: Meta = _at(6, 40)
	var r: Dictionary = League.record(m, true, ld)
	check.call(r.delta == 23 and int(League.state(m).rr) == 63 and float(League.state(m).mmr) > League.nominal(6, ld), "리그: 이기면 RR이 오르고 MMR도 오른다")
	var m2: Meta = _at(6, 40)
	var r2: Dictionary = League.record(m2, false, ld)
	check.call(r2.delta == -17 and int(League.state(m2).rr) == 23 and float(League.state(m2).mmr) < League.nominal(6, ld), "리그: 지면 RR이 깎이고 MMR도 내린다")


func _placement() -> void:
	var m := Meta.new()
	check.call(League.placing(m, ld), "리그: 새 계정은 배치 중")
	var sh: Array = []
	for i in 4:
		var r: Dictionary = League.record(m, true, ld)
		sh.append(int(r.delta) == 0 and bool(r.placing) and not bool(r.placed_now))
	check.call(not sh.has(false) and int(League.state(m).step) == 0 and int(League.state(m).rr) == 0, "리그: 배치 4판까지는 RR·티어가 안 움직인다")
	var r5: Dictionary = League.record(m, true, ld)
	var want: int = League.placement_step(float(League.state(m).mmr), ld)
	check.call(bool(r5.placed_now) and int(League.state(m).step) == want and want > 0 and not League.placing(m, ld), "리그: 5판째에 MMR로 시작 티어가 정해진다(5연승 → %s)" % League.step_name(want, ld))
	var lost := Meta.new()
	for i in 5:
		League.record(lost, false, ld)
	check.call(int(League.state(lost).step) == 0, "리그: 5연패는 녹쇠 1에서 시작")
	var cap := Meta.new()
	League.state(cap).mmr = 3000.0
	League.state(cap).games = 4
	League.record(cap, true, ld)
	check.call(int(League.state(cap).step) == ld.placement_cap_step and League.step_name(int(League.state(cap).step), ld) == "금 1", "리그: 배치는 아무리 MMR이 높아도 금 1까지")
	check.call(int(League.state(m).peak) == int(League.state(m).step), "리그: 배치가 끝나면 이번 시즌 최고가 시작 티어")


func _promote_demote() -> void:
	var m: Meta = _at(6, 90)
	var r: Dictionary = League.record(m, true, ld)
	check.call(bool(r.promoted) and int(League.state(m).step) == 7 and int(League.state(m).rr) == 90 + 23 - 100, "리그: RR 100에 닿으면 승급하고 넘친 만큼 남는다")
	check.call(int(League.state(m).peak) == 7, "리그: 최고 티어가 올라간다")
	var d: Meta = _at(7, 5)
	League.state(d).shield = false
	var r2: Dictionary = League.record(d, false, ld)
	check.call(bool(r2.demoted) and int(League.state(d).step) == 6 and int(League.state(d).rr) == 100 + (5 - 17) and int(League.state(d).peak) == 7, "리그: 0 밑으로 내려가면 강등(앞 단계 RR %d), 최고는 그대로" % int(League.state(d).rr))
	var z: Meta = _at(0, 5)
	League.state(z).shield = false
	League.record(z, false, ld)
	check.call(int(League.state(z).step) == 0 and int(League.state(z).rr) == 0, "리그: 녹쇠 1은 더 내려가지 않는다")
	var big: Meta = _at(5, 99)
	League.record(big, true, ld)
	check.call(int(League.state(big).step) == 6 and int(League.state(big).rr) < ld.rr_max, "리그: 티어를 넘어 단계에서 티어로도 오른다(청동 3 → 은 1)")


func _protection() -> void:
	var m: Meta = _at(7, 0)
	var r: Dictionary = League.record(m, false, ld)
	check.call(bool(r.shielded) and int(League.state(m).step) == 7 and int(League.state(m).rr) == 0 and not bool(League.state(m).shield), "리그: RR 0에서 한 번 져도 강등되지 않는다(보호)")
	var r2: Dictionary = League.record(m, false, ld)
	check.call(bool(r2.demoted) and int(League.state(m).step) == 6, "리그: 보호는 한 번뿐, 또 지면 강등")
	var m3: Meta = _at(7, 0)
	League.record(m3, false, ld)
	League.record(m3, true, ld)
	check.call(bool(League.state(m3).shield), "리그: 이기면 보호가 다시 찬다")


func _top() -> void:
	var m: Meta = _at(League.MAX_STEP, 95)
	League.record(m, true, ld)
	check.call(int(League.state(m).step) == League.MAX_STEP and int(League.state(m).rr) > 100, "리그: 불멸 3에서는 RR이 100을 넘어 쌓인다(승급 없음)")
	check.call(League.is_top(0, 23, ld) and League.is_top(99, 23, ld) and not League.is_top(100, 23, ld) and not League.is_top(5, 22, ld) and not League.is_top(-1, 23, ld), "리그: 언덕의 검은 불멸 3인 위쪽 100명")
	m.league_sword = true
	check.call(League.shown_step(m) == 24 and League.step_name(League.shown_step(m), ld) == "언덕의 검", "리그: 언덕의 검 표가 있으면 24로 보인다")
	var lo: Meta = _at(10, 50)
	lo.league_sword = true
	check.call(League.shown_step(lo) == 10, "리그: 불멸 3이 아니면 표가 있어도 안 보인다")
	check.call(League.score_of(_at(23, 130)) > League.score_of(_at(22, 99)) and League.split_score(League.score_of(_at(12, 44))) == Vector2i(12, 44), "리그: 순위표 점수는 걸음이 먼저, 같으면 RR")


func _season() -> void:
	var day0: float = float(ld.season_anchor_day) * 86400.0
	check.call(League.season_of(day0, 0, ld) == 1 and League.season_of(day0 + 41.0 * 86400.0, 0, ld) == 1 and League.season_of(day0 + 42.0 * 86400.0, 0, ld) == 2, "리그: 시즌은 6주(42일)마다 바뀐다")
	check.call(League.season_of(day0, 2, ld) == 3 and League.days_left(day0, ld) == 42 and League.days_left(day0 + 41.0 * 86400.0, ld) == 1, "리그: 관리자 시즌 수와 남은 날")
	var m: Meta = _at(10, 60)   # 금 2
	League.state(m).peak = 13   # 백금 2까지 갔다
	League.state(m).season = 1
	League.state(m).mmr = League.nominal(10, ld)
	var r: Dictionary = League.sync_season(m, 2, ld)
	check.call(bool(r.changed) and int(League.state(m).step) == 7 and int(League.state(m).rr) == 0 and int(League.state(m).season) == 2, "리그: 시즌이 바뀌면 3단계 내려간다(금 2 → 청동... %s)" % League.step_name(int(League.state(m).step), ld))
	check.call(int(m.league_titles.get("1", -1)) == 13 and League.title_text(m, ld) == "S1 백금 2" and League.with_title(m, "검성") == "「S1 백금 2」 검성", "리그: 지난 시즌 최고 티어가 칭호로 남는다")
	check.call(int(League.state(m).peak) == 7, "리그: 새 시즌의 최고는 내려온 자리에서 다시 센다")
	League.state(m).step = 2
	League.sync_season(m, 3, ld)
	check.call(int(League.state(m).step) == 0 and int(m.league_titles.get("2", -1)) == 7, "리그: 녹쇠 1 밑으로는 안 내려간다, 칭호는 시즌마다")
	check.call(League.title_text(m, ld) == "S1 백금 2", "리그: 칭호는 가장 높은 것을 보인다")
	var same: Dictionary = League.sync_season(m, 3, ld)
	check.call(not bool(same.changed), "리그: 같은 시즌이면 아무 일도 없다")
	var fresh := Meta.new()
	League.state(fresh).games = 2
	League.sync_season(fresh, 1, ld)
	League.sync_season(fresh, 2, ld)
	check.call(fresh.league_titles.is_empty() and League.title_text(fresh, ld) == "", "리그: 배치도 못 마친 사람은 칭호가 없다")
	var sw: Meta = _at(League.MAX_STEP, 40)
	sw.league_sword = true
	League.state(sw).season = 4
	League.sync_season(sw, 5, ld)
	check.call(League.title_text(sw, ld) == "S4 언덕의 검" and not sw.league_sword and int(League.state(sw).step) == 20, "리그: 언덕의 검이었으면 그 칭호가 남고 표는 꺼진다")


func _eligibility() -> void:
	check.call(League.eligibility(false, true) != "" and League.eligibility(false, false) != "" and League.eligibility(true, true) != "" and League.eligibility(true, false) == "", "리그: 게스트와 로그인 안 한 사람은 랭크를 못 한다")
	var keep: Array = [Account.logged_in, Account.guest, Account.admin]
	Account.logged_in = true
	Account.guest = false
	Account.admin = false
	check.call(League.may_submit() and League.can_play() == "", "리그: 로그인한 일반 계정은 순위표에 올린다")
	Account.admin = true
	check.call(not League.may_submit() and League.can_play() == "", "리그: 관리자는 순위표에 올리지 않는다(랭크는 해 볼 수 있다)")
	Account.admin = false
	Account.guest = true
	check.call(not League.may_submit() and League.can_play() != "", "리그: 게스트는 올리지도 못 한다")
	Account.logged_in = keep[0]
	Account.guest = keep[1]
	Account.admin = keep[2]


func _local_duel() -> void:
	var m: Meta = _at(9, 33)
	var before: Dictionary = League.state(m).duplicate()
	m.record_duel(0)
	m.record_duel(1)
	m.record_duel(-1)
	check.call(m.duel_wins == 1 and m.duel_losses == 1 and League.state(m) == before and m.league_last.is_empty(), "리그: 같은 PC·보통 온라인 결투(record_duel)는 랭크에 안 센다")
	var src: String = FileAccess.get_file_as_string("res://scripts/duel/duel.gd")
	check.call(src.contains("_ranked = online.ranked") and not src.contains("_ranked = true"), "리그: 랭크는 온라인 결투 장면에서 랭크로 찾았을 때만")


func _save() -> void:
	var m: Meta = _at(14, 57, 1337.5)
	League.state(m).season = 3
	League.state(m).shield = false
	m.league_titles["2"] = 11
	m.league_offset = 2
	m.league_sword = true
	League.record(m, true, ld)
	m.save(TMP)
	var back: Meta = Meta.load_or_new(TMP)
	var a: Dictionary = League.state(m)
	var b: Dictionary = League.state(back)
	var same: bool = true
	for k in a:
		same = same and (absf(float(a[k]) - float(b[k])) < 0.001 if k != "shield" and k != "pending" else bool(a[k]) == bool(b[k]))
	check.call(same and back.league_titles == {"2": 11} and back.league_offset == 2 and back.league_sword and int(back.league_last.get("delta", 0)) == int(m.league_last.delta), "리그: 저장 → 읽기가 그대로 돌아온다")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	var old := Meta.new()
	old.from_dict({"shards": 5, "duel_wins": 2})
	check.call(League.state(old).step == 0 and League.placing(old, ld) and old.league_titles.is_empty() and old.duel_wins == 2, "리그: 옛 저장(리그 칸 없음)은 처음 상태로 읽힌다")


func _pending() -> void:
	var m: Meta = _at(9, 50)
	League.begin_match(m, TMP)
	check.call(bool(League.state(m).pending), "리그: 랭크 결투를 시작하면 표가 선다")
	var left: Dictionary = League.settle_pending(m, ld, TMP)
	check.call(not left.is_empty() and int(League.state(m).rr) == 50 - 17 and int(League.state(m).losses) == 1 and not bool(League.state(m).pending), "리그: 끝나기 전에 꺼졌다면 다음에 진 것으로 센다")
	check.call(League.settle_pending(m, ld, TMP).is_empty(), "리그: 표는 한 번만 센다")
	League.begin_match(m, TMP)
	League.void_match(m, TMP)
	check.call(League.settle_pending(m, ld, TMP).is_empty() and int(League.state(m).rr) == 33, "리그: 무효(어긋남·시간 초과·비김)는 RR이 그대로")
	var r: Dictionary = League.record(m, true, ld)
	check.call(not bool(League.state(m).pending) and r.win, "리그: 결과를 세면 표가 선다 지워진다")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	var duel_src: String = FileAccess.get_file_as_string("res://scripts/duel/duel.gd")
	check.call(duel_src.contains("League.void_match(meta)") and duel_src.contains("_ranked_result(false)"), "리그: 어긋남은 무효, 도중에 나가면 패배로 센다(장면 코드)")


func _board() -> void:
	check.call(League.board_name(3, ld) == "league_s3", "리그: 순위표 이름은 league_s<시즌>")
	var rows: Array[Dictionary] = LeagueBoard.rows_from([
		{"Username": "lordabc", "Score": 23 * 100000 + 140, "Data": {"n": "검성", "t": "S1 금 1"}},
		{"Username": "lordxyz", "Score": 12 * 100000 + 30, "Data": {}},
	])
	check.call(rows.size() == 2 and rows[0].name == "검성" and rows[0].step == 23 and rows[0].rr == 140 and rows[0].title == "S1 금 1" and rows[1].name == "lordxyz" and rows[1].rank == 1, "리그: 순위표 줄 읽기")
	var m: Meta = _at(12, 44)
	var keep: String = Account.nickname
	Account.nickname = "검성"
	var p: Dictionary = LeagueBoard.pack(m)
	check.call(p.n == "검성" and p.s == 12 and p.r == 44, "리그: 올릴 꼴")
	Account.nickname = keep


func _admin() -> void:
	var m := Meta.new()
	check.call(AdminCmd.parse("리그 불멸 3 40").name == "리그" and AdminCmd.parse("시즌 다음").name == "시즌", "관리: 리그·시즌 명령이 인식된다")
	var out: String = AdminCmd.league_cmd(PackedStringArray(["백금", "2", "40"]), m)
	check.call(int(League.state(m).step) == 13 and int(League.state(m).rr) == 40 and not League.placing(m, ld) and out.contains("백금 2"), "관리: 리그 백금 2 40")
	AdminCmd.league_cmd(PackedStringArray(["불멸", "3", "130"]), m)
	check.call(int(League.state(m).step) == 23 and int(League.state(m).rr) == 130, "관리: 불멸 3은 RR 100을 넘길 수 있다")
	AdminCmd.league_cmd(PackedStringArray(["은", "9", "500"]), m)
	check.call(int(League.state(m).step) == 8 and int(League.state(m).rr) == 100, "관리: 단계·RR은 한계로 자른다")
	check.call(AdminCmd.league_cmd(PackedStringArray(["없는티어"]), m).contains("티어는"), "관리: 모르는 티어는 안내")
	AdminCmd.league_cmd(PackedStringArray(["언덕의검"]), m)
	check.call(m.league_sword and League.shown_step(m) == 24, "관리: 리그 언덕의검")
	AdminCmd.league_cmd(PackedStringArray(["금", "2", "10"]), m)
	var season_before: int = League.season_now(m)
	var s: String = AdminCmd.season_cmd(PackedStringArray(["다음"]), m)
	check.call(League.season_now(m) == season_before + 1 and int(League.state(m).step) == 7 and League.title_text(m, ld) != "" and s.contains("시즌"), "관리: 시즌 다음 → 3단계 내려가고 칭호가 남는다 (%s)" % s)
	AdminCmd.league_cmd(PackedStringArray(["처음"]), m)
	check.call(League.placing(m, ld), "관리: 리그 처음")


func _ui() -> void:
	var res := {"win": true, "placing": false, "placed_now": false, "delta": 23, "step_before": 5, "rr_before": 90, "step_after": 6, "rr_after": 13, "promoted": true, "demoted": false, "shielded": false, "games": 9}
	var p: Control = LeagueUi.result_panel(res)
	var lr: LeagueResult = p as LeagueResult
	lr.build()   # 트리 밖에서 짓기만 한다(움직임은 play)
	lr._apply(float(5 * 100 + 95))
	check.call(lr._name.text == "청동 3" and int(lr._bar.value) == 95, "리그 화면: RR 막대 값에 따라 티어·RR 글이 바뀐다")
	lr._apply(float(6 * 100 + 13))
	check.call(lr._name.text == "은 1" and lr._rr.text == "RR 13 / 100", "리그 화면: 승급 뒤 티어가 바뀐다")
	p.free()
	var m: Meta = _at(7, 30)
	var card: Control = LeagueUi.card(m)
	check.call(card != null and card.get_child_count() == 2, "리그 화면: 티어 카드")
	card.free()
