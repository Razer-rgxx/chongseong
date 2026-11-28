class_name League
extends RefCounted
## 결투 리그 규칙(docs/duel_league.md). 노드에 기대지 않는 정적 함수와 Meta의 저장 칸만 쓴다. 랜덤이 없다.
## 랭크는 온라인 랭크 결투만 센다: 같은 PC 결투와 보통 온라인 결투는 Meta.record_duel만 부르고 여기는 건드리지 않는다.
## 상태는 Meta.league(사전): season, step, rr, mmr, games, shield, peak, wins, losses, pending.

const MAX_STEP: int = 23   ## 불멸 3
const SWORD_STEP: int = 24 ## 언덕의 검(표시와 칭호에서만)
static var _data: LeagueData = null


static func data() -> LeagueData:
	if _data == null:
		_data = load("res://data/league.tres") as LeagueData if ResourceLoader.exists("res://data/league.tres") else LeagueData.new()
	return _data


## 처음 상태.
static func fresh(d: LeagueData = null) -> Dictionary:
	var ld: LeagueData = d if d != null else data()
	return {"season": 0, "step": 0, "rr": 0, "mmr": ld.mmr_start, "games": 0, "shield": true, "peak": 0, "wins": 0, "losses": 0, "pending": false}


## Meta.league를 빠진 칸 없이 채워 돌려준다(옛 저장은 빈 사전이었다).
static func state(meta: Meta) -> Dictionary:
	var f: Dictionary = fresh()
	for k in f:
		if not meta.league.has(k):
			meta.league[k] = f[k]
	return meta.league


static func placing(meta: Meta, d: LeagueData = null) -> bool:
	var ld: LeagueData = d if d != null else data()
	return int(state(meta).games) < ld.placement_games


# ---------------------------------------------------------------- 이름과 표시

static func tier_of(step: int) -> int:
	return clampi(step, 0, MAX_STEP) / 3


static func div_of(step: int) -> int:
	return clampi(step, 0, MAX_STEP) % 3 + 1


## "은 2", "불멸 3", 24는 "언덕의 검".
static func step_name(step: int, d: LeagueData = null) -> String:
	var ld: LeagueData = d if d != null else data()
	if step >= SWORD_STEP:
		return ld.top_name
	return "%s %d" % [ld.tier_names[tier_of(step)], div_of(step)]


## 이모티콘 그림 번호: 0~7 티어, 8 = 언덕의 검.
static func emblem_of(step: int) -> int:
	return 8 if step >= SWORD_STEP else tier_of(step)


## 지금 보일 걸음(언덕의 검 표가 있으면 24).
static func shown_step(meta: Meta) -> int:
	return SWORD_STEP if meta.league_sword and int(state(meta).step) >= MAX_STEP else int(state(meta).step)


## 화면 한 줄: "은 2 · RR 45" 또는 "배치 2/5".
static func line(meta: Meta, d: LeagueData = null) -> String:
	var ld: LeagueData = d if d != null else data()
	if placing(meta, ld):
		return "배치 %d/%d" % [int(state(meta).games), ld.placement_games]
	return "%s · RR %d" % [step_name(shown_step(meta), ld), int(state(meta).rr)]


# ---------------------------------------------------------------- 시즌

## 날짜(유닉스 초)와 관리자가 넘긴 수로 시즌 번호(1부터).
static func season_of(unix: float, offset: int = 0, d: LeagueData = null) -> int:
	var ld: LeagueData = d if d != null else data()
	var day: int = floori(unix / 86400.0)
	return maxi(1, floori(float(day - ld.season_anchor_day) / float(ld.season_days)) + 1 + offset)


static func season_now(meta: Meta) -> int:
	return season_of(Time.get_unix_time_from_system(), meta.league_offset)


## 이 시즌이 끝나기까지 남은 날(올림).
static func days_left(unix: float, d: LeagueData = null) -> int:
	var ld: LeagueData = d if d != null else data()
	var day: int = floori(unix / 86400.0)
	var into: int = posmod(day - ld.season_anchor_day, ld.season_days)
	return ld.season_days - into


## 시즌이 바뀌었으면 옛 시즌의 최고 티어를 칭호로 남기고 부드럽게 내린다(soft_drop 단계). 돌려주는 사전: changed, title(칭호 걸음, -1 없음), from, to.
static func sync_season(meta: Meta, season: int, d: LeagueData = null) -> Dictionary:
	var ld: LeagueData = d if d != null else data()
	var st: Dictionary = state(meta)
	var res := {"changed": false, "title": -1, "from": int(st.step), "to": int(st.step)}
	if int(st.season) == 0:
		st.season = season
		return res
	if season <= int(st.season):
		return res
	res.changed = true
	if int(st.games) >= ld.placement_games:   # 배치를 마친 사람만 칭호와 내려앉음이 있다
		var peak: int = SWORD_STEP if meta.league_sword else int(st.peak)
		meta.league_titles[str(int(st.season))] = maxi(int(meta.league_titles.get(str(int(st.season)), 0)), peak)
		res.title = peak
		var drop: int = mini(ld.soft_drop, int(st.step))
		st.step = int(st.step) - drop
		st.rr = 0
		st.mmr = maxf(ld.mmr_base, float(st.mmr) - drop * ld.mmr_per_step)
		st.shield = true
	st.peak = int(st.step)
	meta.league_sword = false
	st.season = season
	res.to = int(st.step)
	return res


## 가장 높은 칭호의 글("S1 금 2")과 그 걸음. 없으면 "".
static func title_text(meta: Meta, d: LeagueData = null) -> String:
	var best_s: int = -1
	var best_step: int = -1
	for k in meta.league_titles:
		var step: int = int(meta.league_titles[k])
		if step > best_step or (step == best_step and int(k) > best_s):
			best_step = step
			best_s = int(k)
	if best_s < 0:
		return ""
	return "S%d %s" % [best_s, step_name(best_step, d)]


## 이름 옆에 붙는 칭호: "「S1 금 2」 닉네임".
static func with_title(meta: Meta, nick: String) -> String:
	var t: String = title_text(meta)
	return nick if t == "" else "「%s」 %s" % [t, nick]


# ---------------------------------------------------------------- RR 계산

static func nominal(step: int, d: LeagueData = null) -> float:
	var ld: LeagueData = d if d != null else data()
	return ld.mmr_base + float(step) * ld.mmr_per_step


## 이겼을 때 RR(양수). MMR이 걸음의 기준보다 높을수록 늘어난다.
static func win_gain(mmr: float, step: int, d: LeagueData = null) -> int:
	var ld: LeagueData = d if d != null else data()
	return clampi(roundi(ld.win_base + (mmr - nominal(step, ld)) * ld.mmr_gain_k), ld.win_min, ld.win_max)


## 졌을 때 깎이는 RR(양수). MMR이 기준보다 높을수록 줄어든다.
static func loss_cost(mmr: float, step: int, d: LeagueData = null) -> int:
	var ld: LeagueData = d if d != null else data()
	return clampi(roundi(ld.loss_base - (mmr - nominal(step, ld)) * ld.mmr_gain_k), ld.loss_min, ld.loss_max)


## MMR로 배치 걸음(금 1을 넘지 않는다).
static func placement_step(mmr: float, d: LeagueData = null) -> int:
	var ld: LeagueData = d if d != null else data()
	return clampi(floori((mmr - ld.mmr_base) / ld.mmr_per_step), 0, ld.placement_cap_step)


## 랭크 결투 한 판의 결과를 센다(win: 내가 이겼나). 비긴 판·끊긴 판은 부르지 않는다(무효).
## 돌려주는 사전: win, placing(이 판이 배치였나), placed_now, delta, step_before, rr_before, step_after, rr_after,
## promoted, demoted, shielded, games(배치 판 수), mmr.
static func record(meta: Meta, win: bool, d: LeagueData = null) -> Dictionary:
	var ld: LeagueData = d if d != null else data()
	var st: Dictionary = state(meta)
	var step0: int = int(st.step)
	var rr0: int = int(st.rr)
	var mmr0: float = float(st.mmr)
	var was_placing: bool = int(st.games) < ld.placement_games
	var res := {"win": win, "placing": was_placing, "placed_now": false, "delta": 0, "step_before": step0, "rr_before": rr0, "promoted": false, "demoted": false, "shielded": false}
	# 숨은 MMR: 상대를 내 걸음의 기준값으로 어림해 Elo 한 번(배치 중에는 시작값, 큰 K)
	var opp: float = ld.mmr_start if was_placing else nominal(step0, ld)
	var expect: float = 1.0 / (1.0 + pow(10.0, (opp - mmr0) / 400.0))
	var k: float = ld.k_placement if was_placing else ld.k_factor
	st.mmr = mmr0 + k * ((1.0 if win else 0.0) - expect)
	st.games = int(st.games) + 1
	if win:
		st.wins = int(st.wins) + 1
	else:
		st.losses = int(st.losses) + 1
	if was_placing:
		if int(st.games) >= ld.placement_games:
			st.step = placement_step(float(st.mmr), ld)
			st.rr = 0
			st.peak = int(st.step)
			st.shield = true
			res.placed_now = true
	else:
		var delta: int = win_gain(mmr0, step0, ld) if win else -loss_cost(mmr0, step0, ld)
		res.delta = delta
		var rr: int = rr0 + delta
		var step: int = step0
		if win:
			st.shield = true
		while rr >= ld.rr_max and step < MAX_STEP:
			rr -= ld.rr_max
			step += 1
			res.promoted = true
		if rr < 0:
			if step == 0:
				rr = 0
			elif bool(st.shield):
				rr = 0
				st.shield = false
				res.shielded = true
			else:
				step -= 1
				rr = maxi(0, ld.rr_max + rr)
				res.demoted = true
				st.shield = true
		st.step = step
		st.rr = rr
		st.peak = maxi(int(st.peak), step)
	st.pending = false
	res.step_after = int(st.step)
	res.rr_after = int(st.rr)
	res.games = int(st.games)
	res.mmr = float(st.mmr)
	meta.league_last = res.duplicate()
	return res


# ---------------------------------------------------------------- 자격과 순위표

## 랭크를 할 수 없는 까닭(없으면 ""). 게스트와 로그인 안 한 사람은 못 한다.
static func eligibility(logged_in: bool, guest: bool) -> String:
	if guest or not logged_in:
		return "랭크 결투는 로그인한 계정으로만 할 수 있다(게스트는 안 된다)."
	return ""


static func can_play() -> String:
	return eligibility(Account.logged_in, Account.guest)


## 순위표에 올려도 되나: 로그인한 일반 계정만(관리자와 게스트는 올리지 않는다).
static func may_submit() -> bool:
	return can_play() == "" and not Account.is_admin()


## 순위표 점수: 걸음이 먼저, 같으면 RR(불멸 3에서는 RR이 100을 넘는다).
static func score_of(meta: Meta) -> int:
	var st: Dictionary = state(meta)
	return int(st.step) * 100000 + clampi(int(st.rr), 0, 99999)


static func board_name(season: int, d: LeagueData = null) -> String:
	var ld: LeagueData = d if d != null else data()
	return "%s%d" % [ld.board_prefix, season]


## 점수 → 걸음과 RR.
static func split_score(score: int) -> Vector2i:
	return Vector2i(score / 100000, score % 100000)


## 순위표 위쪽 top_n 안(0부터 센 순위)이고 불멸 3이면 "언덕의 검".
static func is_top(rank: int, step: int, d: LeagueData = null) -> bool:
	var ld: LeagueData = d if d != null else data()
	return rank >= 0 and rank < ld.top_n and step >= MAX_STEP


# ---------------------------------------------------------------- 도중에 나감

## 랭크 결투를 시작한다: 끝나기 전에 게임이 꺼지면 다음에 지는 것으로 센다.
static func begin_match(meta: Meta, path: String = Meta.SAVE_PATH) -> void:
	state(meta).pending = true
	meta.save(path)


## 끝났거나 무효가 되어 표를 지운다(RR은 그대로).
static func void_match(meta: Meta, path: String = Meta.SAVE_PATH) -> void:
	state(meta).pending = false
	meta.save(path)


## 끝나지 않은 랭크 결투가 남아 있으면 진 것으로 센다(돌려주는 값: 결과 사전, 없으면 빈 사전).
static func settle_pending(meta: Meta, d: LeagueData = null, path: String = Meta.SAVE_PATH) -> Dictionary:
	if not bool(state(meta).pending):
		return {}
	var r: Dictionary = record(meta, false, d)
	r["left"] = true
	meta.league_last = r.duplicate()
	meta.save(path)
	return r
