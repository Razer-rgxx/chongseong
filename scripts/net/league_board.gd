class_name LeagueBoard
extends RefCounted
## 결투 리그 순위표(docs/duel_league.md 6): GD-Sync 순위표 "league_s<시즌>"에 내 점수(League.score_of)를 올리고 위쪽을 받는다.
## FallenShare와 같은 방법(FallenShare._boot로 노드를 올림, 로그인은 Account가 이미 했다). 관리자·게스트는 올리지 않는다(League.may_submit).
## 실패는 모두 조용히 글 한 줄로. 대시보드에서 해 줄 일: 순위표 league_s<시즌>(점수 큰 것이 위)를 만든다.

static var status: String = ""


## 올릴 꼴: 이름과 걸음·RR(점수에서 다시 읽을 수 있지만 보기 쉽게 같이 둔다).
static func pack(meta: Meta) -> Dictionary:
	var st: Dictionary = League.state(meta)
	return {"n": Account.nickname, "s": int(st.step), "r": int(st.rr), "t": League.title_text(meta)}


## 받은 줄 목록(Username, Score, Data)을 화면 줄로 바꾼다: [{rank, name, step, rr, title}].
static func rows_from(result: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in result.size():
		var row: Variant = result[i]
		if not (row is Dictionary):
			continue
		var sc: Vector2i = League.split_score(int((row as Dictionary).get("Score", 0)))
		var data: Variant = (row as Dictionary).get("Data", {})
		var nm: String = str((data as Dictionary).get("n", "")) if data is Dictionary else ""
		out.append({"rank": i, "name": nm if nm != "" else str((row as Dictionary).get("Username", "?")), "step": sc.x, "rr": sc.y, "title": str((data as Dictionary).get("t", "")) if data is Dictionary else ""})
	return out


## 올린다. 올리지 않아야 하면(관리자·게스트·키 없음) 글만 돌려준다.
static func submit(tree: SceneTree, meta: Meta) -> String:
	if not League.may_submit():
		status = "순위표에는 올리지 않는다(관리자·게스트)"
		return status
	if not GdSyncLink.plugin_present() or not GdSyncLink.has_keys():
		status = "순위표: GD-Sync 키가 없다"
		return status
	var gd: Node = await FallenShare._boot(tree, true)
	if gd == null:
		status = "순위표: 접속하지 못했다"
		return status
	if not bool(gd.call("account_is_logged_in")):
		status = "순위표: 로그인이 풀렸다"
		return status
	var code: int = int(await gd.call("leaderboard_submit_score", League.board_name(int(League.state(meta).season)), League.score_of(meta), pack(meta)))
	status = "순위표에 올렸다" if code == 0 else "순위표에 올리지 못했다(대시보드에 %s가 있어야 한다)" % League.board_name(int(League.state(meta).season))
	return status


## 위쪽 top_n을 받는다. {ok, rows, text}. 받았고 내가 불멸 3이며 top_n 안이면 meta.league_sword를 켠다(저장은 부른 쪽).
static func top(tree: SceneTree, meta: Meta) -> Dictionary:
	var ld: LeagueData = League.data()
	var res := {"ok": false, "rows": [], "text": ""}
	if not GdSyncLink.plugin_present() or not GdSyncLink.has_keys():
		res.text = "온라인 순위표를 쓰려면 GD-Sync 키가 필요하다"
		return res
	var gd: Node = await FallenShare._boot(tree, true)
	if gd == null:
		res.text = "순위표에 접속하지 못했다"
		return res
	var board: String = League.board_name(int(League.state(meta).season), ld)
	var got: Variant = await gd.call("leaderboard_browse_scores", board, ld.top_n, 1)
	if not (got is Dictionary) or int((got as Dictionary).get("Code", 1)) != 0:
		res.text = "순위표를 받지 못했다(대시보드에 %s가 있어야 한다)" % board
		return res
	res.rows = rows_from((got as Dictionary).get("Result", []))
	res.ok = true
	if League.may_submit():
		var mine: int = League.score_of(meta)
		for r in res.rows:
			if r.name == Account.nickname and League.split_score(mine) == Vector2i(r.step, r.rr):
				meta.league_sword = League.is_top(r.rank, r.step, ld)
				break
	return res
