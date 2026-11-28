extends RefCounted
## 22단계 온라인 락스텝 테스트(docs/duel.md). run_all.gd가 부른다: run(데이터, check).
## LoopLink(지연·뒤섞임·빠짐)로 두 Lockstep과 두 Rules를 한 프로세스에서 돌린다. GD-Sync에는 접속하지 않는다.

var d: GameData
var check: Callable
var _saved_timeout: float = 0.0


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/net_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_saved_timeout = d.duel.net_timeout
	_data()
	_setup_bytes()
	_swords_rebuilt()
	_bad_bytes()
	_loop_link()
	_handshake()
	_ideal()
	_jitter()
	_lossy()
	_matches_plain_run()
	_stall()
	_timeout()
	_left()
	_desync()
	_version()
	_keys()
	_bandwidth()
	d.duel.net_timeout = _saved_timeout
	Grid.size = Vector2i(34, 22)


func _data() -> void:
	var D := d.duel
	check.call(D.net_delay == 4 and D.net_timeout > 0.0 and D.net_hash_every == 30 and D.net_resend_min >= 1 and D.net_resend_max >= D.net_resend_min and D.net_version >= 1, "온라인 수치(duel.tres): 입력 지연 4틱, 시간 한계, hash 30틱마다, 겹쳐 보내는 수")


func _spec(id: int) -> Dictionary:
	var s: Dictionary = DuelSetup.bare()
	s.id = id
	return s


func _setup_bytes() -> void:
	var s := DuelSetup.new()
	s.seed_value = 123456
	var sheath := Meta.new()
	sheath.sheath_id = d.sword_by_name("늙은 사자").id
	sheath.sheath_lv = 4
	sheath.sheath_ins = PackedStringArray(["연격"])
	s.picks = [DuelSetup.spec_of(sheath, sheath.sheath_id), _spec(d.sword_by_name("녹슨 장검").id)]
	var back := DuelSetup.from_bytes(s.to_bytes(), d)
	check.call(back != null and back.seed_value == 123456 and back.version == s.version, "시작 정보가 바이트를 거쳐도 같다(시드, 버전)")
	check.call(back != null and back.picks[0].id == s.picks[0].id and back.picks[0].lv == 4 and back.picks[0].sheath and back.picks[0].ins == PackedStringArray(["연격"]) and back.picks[1].id == s.picks[1].id and not back.picks[1].sheath, "두 검의 번호·검집 단계·각인이 같다")


func _swords_rebuilt() -> void:
	var m := Meta.new()
	m.sheath_id = d.sword_by_name("늙은 사자").id
	m.sheath_lv = 3
	m.sheath_ins = PackedStringArray(["연격"])
	var local: Sword = m.unbreakable_sword(d, m.sheath_id)
	var s := DuelSetup.new()
	s.picks = [DuelSetup.spec_of(m, m.sheath_id), DuelSetup.bare()]
	var back := DuelSetup.from_bytes(s.to_bytes(), d)
	var made: Array[Sword] = back.make_swords(d)
	var a: Sword = made[0]
	check.call(a != null and a.data.id == local.data.id and a.grade == local.grade and is_equal_approx(a.bonus, local.bonus) and a.ins == local.ins and a.sheath_lv == 3, "받은 정보로 검집의 검을 다시 만든다(내가 만든 것과 같은 등급·강화·각인)")
	check.call(a.max_durability < 0.0 and made[1] == null, "결투의 검은 부러지지 않고, 맨손은 null")


func _bad_bytes() -> void:
	check.call(DuelSetup.from_bytes(PackedByteArray([1, 2, 3]), d) == null and DuelSetup.from_bytes(var_to_bytes("글"), d) == null and DuelSetup.from_bytes(var_to_bytes([1, 2]), d) == null, "깨진 시작 정보는 null")
	var odd := PackedByteArray()
	odd.append_array(var_to_bytes([1, 5, {"id": 99999, "lv": 99, "ins": ["없는 각인"], "sheath": true}, {"id": "글", "sheath": 7}]))
	var s := DuelSetup.from_bytes(odd, d)
	check.call(s != null and s.picks[0].id == 0 and s.picks[1].id == 0, "모르는 검 번호나 모양이 틀린 검은 맨손으로 다듬는다")
	var lion: int = d.sword_by_name("늙은 사자").id
	var wild := DuelSetup.from_bytes(var_to_bytes([1, 5, {"id": lion, "lv": 99, "ins": ["없는 각인", "연격", "연격"], "sheath": true}, {}]), d)
	check.call(wild.picks[0].lv == d.meta.sheath_max and wild.picks[0].ins == PackedStringArray(["연격"]), "검집 단계는 한계로, 각인은 아는 것만 한 번씩")
	# 락스텝 쪽: 짧거나 맞지 않는 묶음, 모르는 종류는 버린다
	var p := LoopLink.pair(1)
	var ls := Lockstep.new(d, p[0])
	for junk in [PackedByteArray(), PackedByteArray([1]), PackedByteArray([1, 0, 0, 0, 0, 0, 0, 0, 0, 5]), PackedByteArray([99, 1, 2])]:
		ls._on_received(junk)
	check.call(not ls.lost and not ls.desynced, "깨진 묶음은 버리고 아무 일도 없다")


func _loop_link() -> void:
	var p := LoopLink.pair(5, 0, 0, 0.0)
	var got: Array = []
	p[1].received.connect(func(b: PackedByteArray) -> void: got.append(b))
	check.call(not p[0].peer_present(), "LoopLink: 찾기 전에는 상대가 없다")
	p[0].find_match()
	check.call(p[0].status == NetLink.Status.WAITING and p[0].is_host and not p[1].is_host, "LoopLink: 먼저 찾은 쪽은 기다리고 방장")
	p[1].find_match()
	check.call(p[0].status == NetLink.Status.MATCHED and p[1].status == NetLink.Status.MATCHED and p[0].peer_present(), "LoopLink: 둘이 찾으면 맺어진다")
	p[0].send(PackedByteArray([7, 8]), true)
	check.call(got.is_empty(), "LoopLink: poll 전에는 도착하지 않는다")
	p[1].poll(0.0)
	check.call(got.size() == 1 and got[0] == PackedByteArray([7, 8]), "LoopLink: poll하면 도착한다")
	var q := LoopLink.pair(9, 3, 3, 1.0)
	q[0].find_match()
	q[1].find_match()
	var n: Array = [0]
	q[1].received.connect(func(_b: PackedByteArray) -> void: n[0] += 1)
	q[0].send(PackedByteArray([1]), false)
	q[0].send(PackedByteArray([2]), true)
	for i in 6:
		q[1].poll(0.0)
	check.call(n[0] == 1, "LoopLink: 빠짐 100%여도 믿는 전송(reliable)은 늦게라도 온다")


## 맺어진 링크 둘로 OnlineDuel 흐름(HELLO·START)을 돌려 Lockstep 둘과 Rules 둘을 만든다.
func _rig(seed_value: int, dmin: int, dmax: int, lossp: float, id_a: int = -1, id_b: int = -1) -> Dictionary:
	var links: Array[LoopLink] = LoopLink.pair(seed_value, dmin, dmax, lossp)
	var ids: Array[int] = [id_a if id_a >= 0 else d.sword_by_name("녹슨 장검").id, id_b if id_b >= 0 else d.sword_by_name("녹슨 단검").id]
	var ods: Array[OnlineDuel] = []
	for i in 2:
		var od := OnlineDuel.new(d, Meta.new())
		od.start(ids[i], links[i])
		ods.append(od)
	for k in 400:
		if ods[0].done and ods[1].done:
			break
		links[0].poll(1.0 / 30.0)
		links[1].poll(1.0 / 30.0)
	var rules: Array[Rules] = []
	for i in 2:
		var ls: Lockstep = ods[i].lockstep
		var r := Rules.new(d, ls.setup.seed_value if ls.setup != null else 1)
		if ls.setup != null:
			var sw: Array[Sword] = ls.setup.make_swords(d)
			r.start_duel(sw[0], sw[1])
		ls.bind(r)
		rules.append(r)
	return {"links": links, "ods": ods, "ls": [ods[0].lockstep, ods[1].lockstep], "rules": rules}


func _handshake() -> void:
	var rig := _rig(3, 1, 3, 0.0, d.sword_by_name("늙은 사자").id, d.sword_by_name("녹슨 단검").id)
	var ods: Array = rig.ods
	var ls: Array = rig.ls
	check.call(ods[0].done and ods[1].done and OnlineDuel.current != null, "OnlineDuel: 둘이 맺어지면 시작 정보를 주고받아 둘 다 준비된다")
	check.call(ls[0].seat == 0 and ls[1].seat == 1 and ls[0].setup != null and ls[1].setup != null, "방장이 0번 자리, 손님이 1번 자리")
	check.call(ls[0].setup.seed_value == ls[1].setup.seed_value and ls[0].setup.picks[0].id == d.sword_by_name("늙은 사자").id and ls[1].setup.picks[1].id == d.sword_by_name("녹슨 단검").id, "방장이 정한 시드와 두 검(방장 검 · 손님 검)을 둘이 같이 안다")
	var r: Array = rig.rules
	check.call(r[0].seat_sword(0).data.id == r[1].seat_sword(0).data.id and r[0].seat_sword(1).data.id == r[1].seat_sword(1).data.id and r[0].state_hash() == r[1].state_hash(), "두 쪽 Rules가 같은 검·같은 시작 상태")
	OnlineDuel.current = null


## 두 쪽을 n틱 돌린다. 입력은 자리마다 자체 RNG로 만든 공격적인 입력(상대 쪽으로 걸어가 휘두름). 틱 번호별 hash를 모아 돌려준다.
func _play(rig: Dictionary, n: int, input_seed: int = 11) -> Dictionary:
	var links: Array = rig.links
	var ls: Array = rig.ls
	var rules: Array = rig.rules
	var rngs: Array[RandomNumberGenerator] = []
	var made: Array = [[], []]
	var hashes: Array = [{}, {}]
	for i in 2:
		var g := RandomNumberGenerator.new()
		g.seed = input_seed + i * 101
		rngs.append(g)
	var steps: int = 0
	for k in n:
		for i in 2:
			links[i].poll(1.0 / 30.0)
		for i in 2:
			var inp := LordInput.new()
			var me: Rules = rules[i]
			var foe: Vector2 = me.lords[1 - i].pos
			var mine: Vector2 = me.lords[i].pos
			var to: Vector2 = (foe - mine)
			inp.move = to.normalized() * (1.0 if rngs[i].randf() < 0.8 else -1.0) if to.length() > 1.2 else Vector2(rngs[i].randf_range(-1, 1), rngs[i].randf_range(-1, 1)).limit_length(1.0)
			inp.aim_valid = true
			inp.aim = foe
			inp.attack = rngs[i].randf() < 0.5
			inp.dash = rngs[i].randf() < 0.03
			inp.hook = rngs[i].randf() < 0.02
			var before: int = ls[i].sched
			var ran: int = ls[i].update(inp)
			if ls[i].sched > before:
				made[i].append(inp)
			if ran == 1:
				hashes[i][ls[i].exec_tick] = rules[i].state_hash()
				steps += 1
	return {"hashes": hashes, "made": made, "steps": steps}


func _same_hashes(res: Dictionary) -> Array:
	var h: Array = res.hashes
	var common: int = 0
	var bad: int = 0
	for t in h[0]:
		if h[1].has(t):
			common += 1
			if h[0][t] != h[1][t]:
				bad += 1
	return [common, bad]


func _run_case(label: String, seed_value: int, dmin: int, dmax: int, lossp: float, n: int) -> Dictionary:
	var rig := _rig(seed_value, dmin, dmax, lossp)
	var res := _play(rig, n)
	var cmp := _same_hashes(res)
	var ls: Array = rig.ls
	check.call(cmp[0] > n / 3 and cmp[1] == 0, "%s: 틱마다 두 쪽 state_hash가 같다(%d틱 비교, 다른 것 %d)" % [label, cmp[0], cmp[1]])
	check.call(not ls[0].desynced and not ls[1].desynced and not ls[0].lost and not ls[1].lost, "%s: desync도 끊김도 없다" % label)
	var r: Array = rig.rules
	check.call(r[0].lords[0].hp < d.duel.hp or r[0].lords[1].hp < d.duel.hp, "%s: 실제로 싸움이 일어났다(체력 %d, %d)" % [label, int(r[0].lords[0].hp), int(r[0].lords[1].hp)])
	rig.merge({"res": res})
	return rig


func _ideal() -> void:
	_run_case("지연 없음", 21, 0, 0, 0.0, 600)


func _jitter() -> void:
	_run_case("지연 1~4틱(뒤섞임)", 22, 1, 4, 0.0, 700)


func _lossy() -> void:
	_run_case("지연 1~3틱 + 빠짐 35%", 23, 1, 3, 0.35, 800)
	_run_case("지연 0~5틱 + 빠짐 60%", 24, 0, 5, 0.6, 1500)   # 2026-11-25 조작감: 걷기 램프로 무작위 입력의 궤적이 달라져 900틱에는 안 맞을 수 있어 늘림


## 락스텝 결과가 "입력 지연 D만큼 밀린 입력으로 한 Rules를 그냥 돌린 것"과 같다(규칙은 한 줄도 안 바뀐다).
func _matches_plain_run() -> void:
	var rig := _rig(31, 1, 3, 0.2)
	var res := _play(rig, 500, 17)
	var ls: Array = rig.ls
	var made: Array = res.made
	var delay: int = d.duel.net_delay
	var plain := Rules.new(d, ls[0].setup.seed_value)
	var sw: Array[Sword] = ls[0].setup.make_swords(d)
	plain.start_duel(sw[0], sw[1])
	var empty := LordInput.new()
	var k: int = mini(ls[0].exec_tick, ls[1].exec_tick)
	for t in k:
		var a: LordInput = empty if t < delay else made[0][t - delay]
		var b: LordInput = empty if t < delay else made[1][t - delay]
		plain.step_duel(a, b)
	check.call(k > 200, "비교할 만큼 돌았다(%d틱)" % k)
	# 두 쪽이 서로 다른 틱까지 갔을 수 있어서, 같은 틱까지만 비교한다
	var common: int = mini(ls[0].exec_tick, ls[1].exec_tick)
	var h1: Rules = Rules.new(d, ls[0].setup.seed_value)
	h1.start_duel(sw[0], sw[1])
	for t in common:
		h1.step_duel(empty if t < delay else made[0][t - delay], empty if t < delay else made[1][t - delay])
	var ref: int = h1.state_hash()
	var ok0: bool = ls[0].exec_tick != common or (rig.rules[0] as Rules).state_hash() == ref
	var ok1: bool = ls[1].exec_tick != common or (rig.rules[1] as Rules).state_hash() == ref
	check.call(ok0 and ok1, "락스텝 = 입력을 %d틱 미뤄 한 Rules로 그냥 돌린 것(%d틱까지 비교)" % [delay, common])


func _stall() -> void:
	var rig := _rig(41, 0, 1, 0.0)
	var ls: Array = rig.ls
	var links: Array = rig.links
	_play(rig, 120)
	var t0: int = ls[0].exec_tick
	check.call(t0 > 60, "멈춤 시험 전에 틱이 나아갔다(%d)" % t0)
	# 손님이 입력을 못 보내게 막는다(방장은 기다려야 한다)
	d.duel.net_timeout = 9999.0
	links[1].loss = 1.0
	var inp := LordInput.new()
	var ran: int = 0
	var seen_stall: Array[bool] = [false]
	ls[0].stalled_changed.connect(func(s: bool) -> void: seen_stall[0] = seen_stall[0] or s)
	for k in 90:
		links[0].poll(1.0 / 30.0)
		links[1].poll(1.0 / 30.0)
		ran += ls[0].update(inp)
		ls[1].update(inp)
	check.call(ls[0].stalled and ran <= d.duel.net_delay + 2 and seen_stall[0], "상대 입력이 안 오면 기다린다(멈춤): 멈추기 전 %d틱만 나아감" % ran)
	check.call(not ls[0].lost and not ls[0].desynced, "기다리는 동안은 끊김도 desync도 아니다")
	var frozen: int = ls[0].exec_tick
	links[1].loss = 0.0
	for k in 60:
		links[0].poll(1.0 / 30.0)
		links[1].poll(1.0 / 30.0)
		ls[0].update(inp)
		ls[1].update(inp)
	check.call(ls[0].exec_tick > frozen + 20 and not ls[0].stalled, "입력이 다시 오면 이어서 돈다")
	d.duel.net_timeout = _saved_timeout


func _timeout() -> void:
	var rig := _rig(42, 0, 0, 0.0)
	var ls: Array = rig.ls
	var links: Array = rig.links
	d.duel.net_timeout = 1.0
	var reasons: Array[String] = []
	ls[0].peer_lost.connect(func(r: String) -> void: reasons.append(r))
	links[1].loss = 1.0
	var inp := LordInput.new()
	for k in 200:
		links[0].poll(1.0 / 30.0)
		links[1].poll(1.0 / 30.0)
		ls[0].update(inp)
	check.call(reasons == ["timeout"] and ls[0].lost, "상대 입력이 net_timeout초 넘게 안 오면 끊김(timeout) 신호 한 번")
	d.duel.net_timeout = _saved_timeout


func _left() -> void:
	var rig := _rig(43, 0, 0, 0.0)
	var ls: Array = rig.ls
	var reasons: Array[String] = []
	ls[1].peer_lost.connect(func(r: String) -> void: reasons.append(r))
	(rig.links[0] as LoopLink).close()
	check.call(reasons == ["left"] and ls[1].lost, "상대가 방을 나가면 끊김(left) 신호")
	check.call(ls[1].update(LordInput.new()) == 0, "끊긴 뒤에는 더 돌리지 않는다")


func _desync() -> void:
	var rig := _rig(44, 1, 2, 0.1)
	var ls: Array = rig.ls
	var rules: Array = rig.rules
	var got: Array[int] = []
	ls[0].desync.connect(func(t: int) -> void: got.append(t))
	ls[1].desync.connect(func(t: int) -> void: got.append(t))
	_play(rig, 100)
	check.call(got.is_empty(), "규칙이 같으면 desync가 없다(100틱 동안 hash %d번 맞춤)" % (mini(ls[0].exec_tick, ls[1].exec_tick) / d.duel.net_hash_every))
	# 한쪽 규칙을 일부러 바꾼다: 손님 쪽 영주 체력을 몰래 깎는다
	(rules[1] as Rules).lords[0].hp -= 5.0
	_play(rig, 200)
	check.call(got.size() >= 1 and (ls[0].desynced or ls[1].desynced), "한쪽 규칙이 어긋나면 hash 비교로 desync를 알린다(틱 %s)" % [got])
	var frozen: int = ls[0].exec_tick
	ls[0].update(LordInput.new())
	check.call(ls[0].desynced == false or ls[0].exec_tick == frozen, "desync 뒤에는 더 돌리지 않는다")


func _version() -> void:
	var links: Array[LoopLink] = LoopLink.pair(51)
	var a := Lockstep.new(d, links[0])
	var b := Lockstep.new(d, links[1])
	var lost: Array[String] = []
	a.peer_lost.connect(func(r: String) -> void: lost.append(r))
	var bad_version: int = d.duel.net_version + 1
	links[0].find_match()
	links[1].find_match()
	b.begin(_spec(0))
	a.begin(_spec(0))
	var saved: int = d.duel.net_version
	# 상대(b)가 다른 버전의 HELLO를 보낸 것처럼 직접 보낸다
	links[1].send(PackedByteArray([Lockstep.Pkt.HELLO]) + var_to_bytes([bad_version, _spec(0)]), true)
	for i in 5:
		links[0].poll(0.03)
	d.duel.net_version = saved
	check.call(lost.has("version"), "프로토콜 번호가 다르면 겨루지 않는다(version)")


func _keys() -> void:
	var saved_path: String = GdSyncLink.keys_path
	GdSyncLink.keys_path = "user://테스트용_없는_키_파일.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GdSyncLink.keys_path))
	var env_free: bool = OS.get_environment("GDSYNC_PUBLIC_KEY") == "" and OS.get_environment("GDSYNC_PRIVATE_KEY") == ""
	if env_free:
		check.call(not GdSyncLink.has_keys(), "키 파일이 없으면 has_keys가 false")
		var link := GdSyncLink.new(d)
		var seen: Array[int] = []
		link.status_changed.connect(func(s: int) -> void: seen.append(s))
		link.find_match()
		check.call(link.status == NetLink.Status.NO_KEYS and seen == [NetLink.Status.NO_KEYS] and not link.peer_present(), "키가 없으면 GdSyncLink는 오류 없이 '키 없음' 상태로 멈춘다")
		check.call(link.error_text == "GD-Sync 키가 없습니다" and (_tree_has_no_gdsync()), "접속을 시도하지 않고(GDSync 노드도 안 올림) 한 줄만 낸다")
		link.send(PackedByteArray([1]), true)
		link.close()
		check.call(true, "키 없음 상태에서 send·close도 조용하다")
		var od := OnlineDuel.new(d, Meta.new())
		var texts: Array[String] = []
		od.failed.connect(func(t: String) -> void: texts.append(t))
		od.start(0, GdSyncLink.new(d))
		check.call(texts.size() == 1 and texts[0].begins_with("GD-Sync 키가 없습니다") and texts[0].contains(GdSyncLink.keys_os_path()) and texts[0].contains("public"), "OnlineDuel은 키 없음을 안내 글(파일 위치, public·private)로 알린다")
	var cfg := ConfigFile.new()
	cfg.set_value("keys", "public", " pub123 ")
	cfg.set_value("keys", "private", "pri456")
	GdSyncLink.keys_path = "user://테스트용_키_파일.cfg"
	cfg.save(GdSyncLink.keys_path)
	var k: Dictionary = GdSyncLink.load_keys()
	check.call(k.public == "pub123" and k.private == "pri456" and GdSyncLink.has_keys(), "키 파일([keys] public, private)을 읽는다(앞뒤 공백은 뗀다)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GdSyncLink.keys_path))
	GdSyncLink.keys_path = saved_path


func _tree_has_no_gdsync() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	return tree == null or (tree.root.get_node_or_null("GDSync") == null and tree.root.get_node_or_null("GdSyncRelay") == null)


## 대역폭: 지연 2틱·빠짐 5%에서 한 쪽이 보내는 양을 재서 90초 3판(시작 2초·쉼 3초 포함 약 290초)으로 늘린다.
func _bandwidth() -> void:
	var rig := _rig(61, 1, 3, 0.05)
	var res := _play(rig, 900, 23)
	var ls: Array = rig.ls
	var secs: float = float(ls[0].exec_tick) / 30.0
	var bps: float = float(ls[0].sent_bytes) / secs
	var total_kb: float = bps * d.duel.net_estimate_seconds / 1024.0
	print("대역폭(어림): 한 쪽이 초당 %.0f B 보냄(묶음 평균 %.0f B), 90초 3판(약 %.0f초)이면 %.0f KB, 둘이 합쳐 %.0f KB. 무료판 하루 200MB면 한 판 %.0f번쯤(플러그인 겉치레 ×2로 쳐도 %.0f번)." % [bps, float(ls[0].sent_bytes) / maxf(1.0, ls[0].sent_packets), d.duel.net_estimate_seconds, total_kb, total_kb * 2.0, 200.0 * 1024.0 / (total_kb * 2.0), 200.0 * 1024.0 / (total_kb * 4.0)])
	check.call(bps > 0.0 and total_kb < 2000.0, "대역폭: 한 쪽 한 판(3판) 보내는 양이 2MB 아래(%.0f KB)" % total_kb)
	check.call(res.steps > 0, "대역폭 시험이 실제로 돌았다")
