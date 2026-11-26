class_name FallenShare
extends RefCounted
## 다른 영주들의 쓰러진 검(docs/sword_hill.md 2번, 2026-11-21 사용자: "검의 주인은 다른 사람들 것도 가끔 뜨게").
## GD-Sync 클라우드 순위표 BOARD에 내 마지막 쓰러진 검(Meta.fallen의 끝)을 올리고(계정 하나에 한 줄, 점수 = 올린 때라 새것이 위),
## 다른 사람들 것을 받아 Meta.others에 둔다(저장, 인터넷이 없어도 다음 판에 쓴다). 마을에 들어올 때 마을이 sync를 부른다.
## 계정은 처음 한 번 저절로 만든다(이름 lordxxxxxx, 비밀번호는 user://share_account.cfg). GD-Sync 쪽에서 할 일:
## 대시보드에 순위표 BOARD를 만들고, 계정 이메일 인증을 끈다(인증이 켜져 있으면 로그인이 안 되어 조용히 넘어간다).
## 키는 결투와 같은 user://gdsync_keys.cfg(GdSyncLink.load_keys). 실패는 모두 조용히(글 한 줄만 돌려준다).
## 올리는 꼴(pack)은 2048바이트 안: 몸놀림은 틱마다 6바이트(x·y × 100은 u16, 얼굴 u8, 휘두름 u8)를 base64로.

const BOARD: String = "fallen_swords"
const ACCOUNT_PATH: String = "user://share_account.cfg"
const OTHERS_MAX: int = 20
const NAME_CHARS: String = "abcdefghjkmnpqrstuvwxyz23456789"
## 한 번에 기다리는 최대 시간(초).
const WAIT: float = 8.0

## 마지막 sync의 결과 한 줄(설정·마을에서 보일 수 있다).
static var status: String = ""
static var _busy: bool = false


## 순위표에 올려도 되나: 관리자 계정은 어떤 순위에도 오르지 않는다(docs/account.md).
static func may_submit() -> bool:
	return not Account.is_admin()


## 올릴 꼴(2048바이트 안).
static func pack(rec: Dictionary) -> Dictionary:
	var g: Array = rec.get("ghost", [])
	var n: int = g.size() / 4
	var b := PackedByteArray()
	b.resize(n * 6)
	for t in n:
		var x: int = clampi(roundi(float(g[t * 4]) * 100.0), 0, 65535)
		var y: int = clampi(roundi(float(g[t * 4 + 1]) * 100.0), 0, 65535)
		var f: int = posmod(roundi(fposmod(float(g[t * 4 + 2]), TAU) / TAU * 256.0), 256)
		b.encode_u16(t * 6, x)
		b.encode_u16(t * 6 + 2, y)
		b[t * 6 + 4] = f
		b[t * 6 + 5] = clampi(roundi(float(g[t * 4 + 3])), 0, 2)
	return {"i": int(rec.get("id", 0)), "z": int(rec.get("zone", 0)), "k": int(rec.get("kills", 0)), "g": Marshalls.raw_to_base64(b)}


## 받은 꼴을 Meta.fallen과 같은 기록으로(name = 올린 사람). 이상하면 빈 사전.
static func unpack(d: Dictionary, username: String) -> Dictionary:
	if not d.has("i") or int(d.get("i", 0)) <= 0:
		return {}
	var b: PackedByteArray = Marshalls.base64_to_raw(str(d.get("g", "")))
	var g: Array = []
	for t in b.size() / 6:
		g.append_array([b.decode_u16(t * 6) / 100.0, b.decode_u16(t * 6 + 2) / 100.0, b[t * 6 + 4] / 256.0 * TAU, float(b[t * 6 + 5])])
	return {"id": int(d.i), "run": 0, "zone": int(d.get("z", 0)), "kills": int(d.get("k", 0)), "ghost": g, "name": username}


## 올리고 받는다. 마을이 들어올 때 부른다(await하지 않아도 된다). 결과 한 줄을 돌려준다.
static func sync(tree: SceneTree, meta: Meta) -> String:
	if _busy:
		return status
	if not GdSyncLink.plugin_present() or not GdSyncLink.has_keys():
		status = "다른 영주의 검: GD-Sync 키가 없다"
		return status
	_busy = true
	status = await _sync(tree, meta)
	_busy = false
	return status


static func _sync(tree: SceneTree, meta: Meta) -> String:
	var gd: Node = await _boot(tree)
	if gd == null:
		return "다른 영주의 검: 접속하지 못했다"
	if not await _login(gd):
		return "다른 영주의 검: 계정에 들어가지 못했다(대시보드의 이메일 인증을 꺼야 한다)"
	var me: String = _account().get("name", "")
	# 올린 적 없는 내 마지막 쓰러진 검(관리자는 순위에 올리지 않는다)
	if not meta.fallen.is_empty() and may_submit():
		var last: Dictionary = meta.fallen[meta.fallen.size() - 1]
		var key: String = "%d:%d:%d" % [int(last.id), int(last.run), int(last.kills)]
		if key != meta.shared_key:
			var code: int = int(await gd.call("leaderboard_submit_score", BOARD, int(Time.get_unix_time_from_system()), pack(last)))
			if code == 0:
				meta.shared_key = key
	var res: Variant = await gd.call("leaderboard_browse_scores", BOARD, 60, 1)
	if not (res is Dictionary) or int((res as Dictionary).get("Code", 1)) != 0:
		meta.save()
		return "다른 영주의 검: 순위표를 받지 못했다(대시보드에 %s를 만들어야 한다)" % BOARD
	var got: Array = []
	for row in (res as Dictionary).get("Result", []):
		if not (row is Dictionary):
			continue
		var who: String = str(row.get("Username", ""))
		if who == "" or who == me:
			continue
		var rec: Dictionary = unpack(row.get("Data", {}), who)
		if not rec.is_empty():
			got.append(rec)
		if got.size() >= OTHERS_MAX:
			break
	meta.others = got
	meta.save()
	return "다른 영주의 검 %d자루를 받았다" % got.size()


## GD-Sync 노드를 올리고 접속한다(결투의 GdSyncLink와 같은 노드를 쓴다). 실패하면 null.
## http_only: 계정·순위표 같은 HTTPS 요청만 할 거면 플러그인이 "켜짐"(서버 고르기까지)이면 되고,
## 게임 서버와의 연결(client id)까지 기다리지 않는다(계정 로그인이 오래 걸리던 것, 2026-11-24).
static var _pending: Node = null


static func _boot(tree: SceneTree, http_only: bool = false) -> Node:
	var gd: Node = tree.root.get_node_or_null(GdSyncLink.NODE_NAME)
	if gd == null and _pending != null and is_instance_valid(_pending):
		gd = _pending   # 다른 곳이 막 올리는 중(같은 노드를 두 번 올리지 않는다)
	if gd == null:
		gd = (load(GdSyncLink.PLUGIN_SCRIPT) as GDScript).new() as Node
		gd.name = GdSyncLink.NODE_NAME
		_pending = gd
		tree.root.add_child.call_deferred(gd)
	while not gd.is_inside_tree():
		await tree.process_frame
	await tree.process_frame
	var keys: Dictionary = GdSyncLink.load_keys()
	var cc: Variant = gd.get("_connection_controller")
	if cc != null and (str(cc.get("_PUBLIC_KEY")) == "" or str(cc.get("_PRIVATE_KEY")) == ""):
		cc.set("_PUBLIC_KEY", keys.public)
		cc.set("_PRIVATE_KEY", keys.private)
	var ok_now := func() -> bool:
		return bool(gd.call("is_active")) and (http_only or int(gd.call("get_client_id")) >= 0)
	if ok_now.call():
		return gd
	if int(gd.get("_connection_controller").get("status")) == ENUMS.CONNECTION_STATUS.DISABLED:
		gd.call("start_multiplayer")
	var t: float = 0.0
	while t < WAIT:
		await tree.create_timer(0.1).timeout
		t += 0.1
		if ok_now.call():
			return gd
	return null


## 저절로 만든 계정으로 들어간다(없으면 만든다).
static func _login(gd: Node) -> bool:
	if bool(gd.call("account_is_logged_in")):
		return true
	var acc: Dictionary = _account()
	if acc.is_empty():
		acc = _new_account()
		var made: int = int(await gd.call("account_create", acc.email, acc.name, acc.password))
		if made != 0:
			return false
		_save_account(acc)
	var res: Variant = await gd.call("account_login", acc.email, acc.password, 7.0 * 86400.0)
	return res is Dictionary and int((res as Dictionary).get("Code", 1)) == 0


static func _account() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(ACCOUNT_PATH) != OK:
		return {}
	var a := {"email": str(cfg.get_value("a", "email", "")), "name": str(cfg.get_value("a", "name", "")), "password": str(cfg.get_value("a", "password", ""))}
	return a if a.email != "" and a.name != "" and a.password != "" else {}


static func _new_account() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var tag: String = ""
	for i in 6:
		tag += NAME_CHARS[rng.randi_range(0, NAME_CHARS.length() - 1)]
	var pw: String = ""
	for i in 16:
		pw += NAME_CHARS[rng.randi_range(0, NAME_CHARS.length() - 1)]
	# 이름은 영문·숫자만(GD-Sync 데이터베이스의 이름 규칙에 걸리지 않게, 3~20자), 메일은 받는 곳이 없는 예약 주소
	return {"email": "lord%s@example.com" % tag, "name": "lord%s" % tag, "password": pw}


static func _save_account(a: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for k in ["email", "name", "password"]:
		cfg.set_value("a", k, a[k])
	cfg.save(ACCOUNT_PATH)
