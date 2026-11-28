class_name RiftRaid
extends RefCounted
## 시대 균열(2026-11-26, docs/rift_raid.md): 3막(흑룡)을 마친 뒤 판이 끝날 때마다 들판에 균열이 열린다.
## 제때 닫지 못하면 터지고, 터지면 마을 방어전(RiftRaid.Defense)이 선다. 영주가 지켜 내면 아무 일 없고, 쓰러지면 건물이 망가진다. 노드에 기대지 않는다. 상태는 Meta(rr_*)에 저장하고 난수는 Meta.rng만 쓴다.
## 싸움(물결과 우두머리)은 RiftRaid.Fight, 화면은 field.gd(RiftTear)와 lobby.gd(BuildingPlot의 망가진 모습).

## 물결에 섞이는 세 시대의 적. 물결마다 이 중 두 시대를 굴려 섞고, 마지막은 시대 우두머리 하나.
const ERA_FOES: Dictionary = {
	&"now": [&"wraith", &"wolf"],
	&"future": [&"drone", &"husk"],
	&"past": [&"stag", &"stone"],
}
const ERAS: Array[StringName] = [&"now", &"future", &"past"]
## 마지막 우두머리(시대마다 하나): 현재 무덤 기사, 미래 대수확자, 과거 시간을 먹는 흑룡.
const BOSSES: Array[StringName] = [&"grave_knight", &"harvester", &"devourer"]
## 망가질 수 있는 건물 종류가 아닌 것(돌담은 목책 줄이라 따로 안 망가진다).
const SAFE_KINDS: Array[StringName] = [&"wall"]
## 마을 방어전(2026-11-26): 물결 수, 적 수 배율, 세기 구역을 균열 싸움보다 낮춘 수, 이겼을 때 조각 배율(균열 닫기 보상 대비).
const DEF_WAVES: int = 2
const DEF_SCALE: float = 0.55
const DEF_ZONE_CUT: int = 2
const DEF_REWARD: float = 0.5
## 마을의 적이 나오는 자리(칸): 북문 앞, 목책 가장자리(서쪽·남서·동쪽 바깥 터). 물결마다 북문 하나와 가장자리 하나가 선다.
const DEF_GATE: Vector2 = Vector2(17.0, 4.6)
const DEF_EDGES: Array[Vector2] = [Vector2(2.5, 19.0), Vector2(47.0, 11.2), Vector2(2.5, 6.0)]


## 3막을 마쳤나(흑룡을 쓰러뜨렸다). 그 전에는 균열에 관한 것이 어디에도 안 나온다(길라잡이 포함).
static func unlocked(m: Meta) -> bool:
	return m.anchor_hand


static func from_dict(m: Meta, d: Dictionary) -> void:
	m.rr_open = bool(d.get("rr_open", false))
	m.rr_spot = clampi(int(d.get("rr_spot", 0)), 0, FieldLayout.RIFT_RAID_SPOTS.size() - 1)
	m.rr_left = maxi(0, int(d.get("rr_left", 0)))
	if m.rr_open and m.rr_left <= 0:
		m.rr_left = 1
	m.rr_since = maxi(0, int(d.get("rr_since", 0)))
	m.rr_streak = maxi(0, int(d.get("rr_streak", 0)))
	m.rr_ruined = {}
	for k in d.get("rr_ruined", []):
		m.rr_ruined[StringName(str(k))] = 1
	m.rr_fled = {}
	var fl: Variant = d.get("rr_fled", {})
	if fl is Dictionary:
		for k in fl:
			m.rr_fled[str(k)] = maxi(1, int(fl[k]))
	m.rr_news = str(d.get("rr_news", ""))
	m.rr_closed = maxi(0, int(d.get("rr_closed", 0)))
	m.rr_cut = clampi(int(d.get("rr_cut", 0)), 0, 1)
	m.rr_breach_pending = bool(d.get("rr_breach_pending", false))


## 균열이 열릴 확률(마지막 균열 뒤 지난 판이 길수록 조금씩 오른다).
static func chance(m: Meta, md: MetaData) -> float:
	return minf(md.rift_chance_cap, md.rift_chance_base + md.rift_chance_step * float(maxi(0, m.rr_since - 1)))


## 판이 하나 끝났다(Meta.record_run이 부른다). 열려 있으면 한 판 줄고(0이면 터진다), 없으면 확률로 연다.
## "" 아무 일 없음, "opened" 열림, "ticking" 아직 열려 있음, "breached" 터짐.
static func after_run(m: Meta, d: GameData) -> String:
	_fled_tick(m)
	if not unlocked(m):
		return ""
	if m.rr_open:
		m.rr_left -= 1
		if m.rr_left <= 0:
			breach(m)
			return "breached"
		return "ticking"
	if m.rr_breach_pending:   # 아직 방어전을 안 치렀으면 또 열리지 않는다
		return ""
	m.rr_since += 1
	if m.rng.randf() < chance(m, d.meta):
		open(m, d.meta)
		return "opened"
	return ""


## 균열을 연다(관리자도 쓴다). 자리는 Meta.rng로 고른다. 이미 열려 있으면 그대로.
static func open(m: Meta, md: MetaData, spot: int = -1) -> bool:
	if m.rr_open:
		return false
	m.rr_open = true
	m.rr_spot = spot if spot >= 0 and spot < FieldLayout.RIFT_RAID_SPOTS.size() else m.rng.randi() % FieldLayout.RIFT_RAID_SPOTS.size()
	m.rr_left = md.rift_runs
	m.rr_since = 0
	return true


## 균열이 터졌다(2026-11-26 방어전): 건물은 그대로이고, 다음에 마을에 들어서면 방어전이 선다(rr_breach_pending, 저장).
## 이미 방어전을 기다리는 중이면 그대로 둔다.
static func breach(m: Meta) -> void:
	m.rr_open = false
	m.rr_left = 0
	m.rr_since = 0
	m.rr_breach_pending = true


## 방어전을 지켜 냈다: 대기를 지우고 보상을 한 번만 준다. {shards, rune}을 돌려주고, 대기 중이 아니었으면 빈 사전.
static func defense_win(m: Meta, d: GameData) -> Dictionary:
	if not m.rr_breach_pending:
		return {}
	var md: MetaData = d.meta
	m.rr_breach_pending = false
	m.rr_news = ""
	var shards: int = maxi(1, roundi(float(md.rift_reward_shards) * DEF_REWARD))
	m.shards += shards
	var out := {"shards": shards, "rune": ""}
	if m.rng.randf() < md.rift_rune_chance:
		var T: RuneTable = Meta.rt()
		var type: String = String(T.rune_order[m.rng.randi() % T.rune_order.size()])
		var key: String = "%s:%d" % [type, 1 + (m.rng.randi() % 2)]   # 1~2단계
		if m.rune_add(key):
			out.rune = key
	return out


## 방어전에서 영주가 쓰러졌다: 건물이 1~2채 망가지고 주민이 하나 도망치며, 안 고치고 연달아 잃으면 마을 단계가 내려간다.
## 지은 건물이 하나도 없으면 망가질 것이 없다(소식만). 세이브와 검집의 검은 건드리지 않는다. 대기 중이 아니면 빈 사전.
static func defense_lose(m: Meta, d: GameData) -> Dictionary:
	if not m.rr_breach_pending:
		return {}
	m.rr_breach_pending = false
	var md: MetaData = d.meta
	m.rr_streak += 1
	var pool: Array[StringName] = []
	for b in d.buildings:
		if m.has_built(b.id) and not m.rr_ruined.has(b.id) and not SAFE_KINDS.has(b.kind):
			pool.append(b.id)
	var hit: Array[StringName] = []
	var n: int = mini(m.rng.randi_range(md.rift_damage_min, md.rift_damage_max), pool.size())
	for _i in n:
		var j: int = m.rng.randi() % pool.size()
		hit.append(pool[j])
		m.rr_ruined[pool[j]] = 1
		pool.remove_at(j)
	var fled: String = ""
	var avail: Array = m.residents.filter(func(r: Dictionary) -> bool: return not m.rr_fled.has(r.name))
	if not avail.is_empty() and not hit.is_empty():
		fled = str(avail[m.rng.randi() % avail.size()].name)
		m.rr_fled[fled] = md.rift_flee_runs
	var dropped: bool = false
	if m.rr_streak >= md.rift_drop_after and m.rr_cut == 0 and not m.rr_ruined.is_empty():
		m.rr_cut = 1
		dropped = true
	m.rr_news = "dropped" if dropped else "breach"
	return {"hit": hit, "fled": fled, "dropped": dropped}


## 도망친 주민이 판이 하나 끝날 때마다 돌아올 날에 가까워진다.
static func _fled_tick(m: Meta) -> void:
	for k in m.rr_fled.keys():
		m.rr_fled[k] = int(m.rr_fled[k]) - 1
		if int(m.rr_fled[k]) <= 0:
			m.rr_fled.erase(k)


## 마을에 들어서서 알릴 소식 글(없으면 ""). 알린 뒤 clear_news.
static func news_text(m: Meta, d: GameData) -> String:
	if m.rr_news == "":
		return ""
	var names: Array[String] = []
	for b in d.buildings:
		if m.rr_ruined.has(b.id):
			names.append(b.display_name)
	var t: String = "균열이 마을을 할퀴고 지나갔다"
	if m.rr_news == "dropped":
		t = "균열이 마을을 할퀴고 지나갔다. 마을이 한 단계 내려앉았다"
	return t + (" (%s)" % ", ".join(names) if not names.is_empty() else "")


static func clear_news(m: Meta) -> void:
	m.rr_news = ""


# ---------------------------------------------------------------- 수리

## 수리 값: 건물 짓는 값의 일부(재료마다 올림, 최소 1).
static func repair_cost(b: BuildingData, md: MetaData) -> Dictionary:
	var out := {}
	var c: Dictionary = b.cost()
	for id in c:
		out[id] = maxi(1, ceili(float(c[id]) * md.rift_repair_ratio))
	return out


## 고친다(재료를 낸다). 된 일이면 true. 고치면 연달아 터진 수가 0이 되고, 다 고치면 마을 단계도 돌아온다.
static func repair(m: Meta, b: BuildingData, md: MetaData) -> bool:
	if b == null or not m.rr_ruined.has(b.id) or not m.pay(repair_cost(b, md)):
		return false
	m.rr_ruined.erase(b.id)
	m.rr_streak = 0
	if m.rr_ruined.is_empty():
		m.rr_cut = 0
	m.guide_note("repair")
	return true


# ---------------------------------------------------------------- 닫기

## 균열을 닫는다: 열려 있을 때 한 번만 보상을 준다. {shards, rune, sword}를 돌려주고, 열려 있지 않았으면 빈 사전.
static func close(m: Meta, d: GameData) -> Dictionary:
	if not m.rr_open:
		return {}
	var md: MetaData = d.meta
	m.rr_open = false
	m.rr_left = 0
	m.rr_since = 0
	m.rr_closed += 1
	m.shards += md.rift_reward_shards
	var out := {"shards": md.rift_reward_shards, "rune": "", "sword": 0}
	if m.rng.randf() < md.rift_rune_chance:
		var T: RuneTable = Meta.rt()
		var type: String = String(T.rune_order[m.rng.randi() % T.rune_order.size()])
		var tier: int = 2 + (m.rng.randi() % 2)   # 2~3단계
		var key: String = "%s:%d" % [type, mini(tier, T.buy_cost.size())]
		if m.rune_add(key):
			out.rune = key
	if m.rng.randf() < md.rift_sword_chance:
		out.sword = _reward_sword(m, d)
		if int(out.sword) > 0:
			m.note_found(int(out.sword))
	return out


## 보상 검: 사이버 검(틈을 연 뒤라면 절반) 아니면 높은 등급(초월·무한) 중에서.
static func _reward_sword(m: Meta, d: GameData) -> int:
	var top: int = d.grades.names.size() - 1
	var pool: Array[int] = []
	if m.rift_open() and m.rng.randf() < 0.5:
		for g in [top - 1, top]:
			for i in d.cyber_by_grade[g]:
				pool.append(d.swords[i].id)
	if pool.is_empty():
		for g in [top - 1, top]:
			for i in d.swords_by_grade[g]:
				pool.append(d.swords[i].id)
	return pool[m.rng.randi() % pool.size()] if not pool.is_empty() else 0


# ---------------------------------------------------------------- 물결 싸움 (규칙, 노드 없음)

## 물결 n(1부터)의 무리 정의(Rules.spawn_pack의 def). 두 시대를 rng로 골라 섞는다. 마지막(n == 물결 수 + 1)은 우두머리 하나.
static func wave_def(rules: Rules, md: MetaData, n: int, at: Vector2) -> Dictionary:
	var foes: Array = []
	if n > md.rift_waves:
		foes.append([BOSSES[rules.rng.randi() % BOSSES.size()], 1])
	else:
		var skip: int = rules.rng.randi() % ERAS.size()
		for i in ERAS.size():
			if i == skip:
				continue
			var kinds: Array = ERA_FOES[ERAS[i]]
			var kind: StringName = kinds[rules.rng.randi() % kinds.size()]
			foes.append([kind, 1 + n + (rules.rng.randi() % 2)])
	return {"at": at, "wander": 3.0, "zone": md.rift_zone, "foes": foes}


## 균열 싸움 하나(들판 한 번 방문 동안). 물결이 다 쓰러지면 다음 물결, 우두머리까지 쓰러지면 cleared.
## field.gd가 틱마다 step()을 부르고, 닫는 일(RiftRaid.close)은 부른 쪽이 한다.
class Fight extends RefCounted:
	var rules: Rules
	var md: MetaData
	var at: Vector2
	var wave: int = 0          ## 0 시작 전, 1~waves 물결, waves+1 우두머리
	var wait: float = 0.0
	var cleared: bool = false
	var boss_kind: StringName = &""
	var pack_id: StringName = &""
	signal wave_started(n: int, boss: bool)
	signal done()

	func _init(p_rules: Rules, p_md: MetaData, p_at: Vector2) -> void:
		rules = p_rules
		md = p_md
		at = p_at

	func active() -> bool:
		return wave > 0 and not cleared

	func start() -> void:
		if wave == 0:
			_spawn(1)

	func _spawn(n: int) -> void:
		wave = n
		pack_id = StringName("rift_w%d" % n)
		var def: Dictionary = RiftRaid.wave_def(rules, md, n, at)
		var es: Array[Enemy] = rules.spawn_pack(pack_id, def)
		if n > md.rift_waves:
			boss_kind = def.foes[0][0]
			for e in es:   # 우두머리는 구역으로 세지지 않으니 체력만 줄인다
				e.max_hp *= md.rift_boss_hp
				e.hp = e.max_hp
		wave_started.emit(n, n > md.rift_waves)

	## 틱마다(dt초). 지금 무리가 모두 쓰러졌으면 쉬었다가 다음 물결.
	func step(dt: float) -> void:
		if not active():
			return
		if wait > 0.0:
			wait -= dt
			if wait <= 0.0:
				_spawn(wave + 1)
			return
		if rules.packs.has(pack_id) and bool(rules.packs[pack_id].cleared):
			if wave > md.rift_waves:
				cleared = true
				done.emit()
			else:
				wait = md.rift_wave_gap


# ---------------------------------------------------------------- 마을 방어전 (규칙, 노드 없음)

## 방어전 물결 n(1부터)의 무리 정의: 균열 싸움의 물결(wave_def)과 같은 구성인데 적 수를 DEF_SCALE로, 세기 구역을 DEF_ZONE_CUT만큼 줄였다. 우두머리는 없다.
static func defense_def(rules: Rules, md: MetaData, n: int, at: Vector2) -> Dictionary:
	var def: Dictionary = wave_def(rules, md, mini(n, md.rift_waves), at)
	var foes: Array = []
	for f in def.foes:
		foes.append([f[0], maxi(1, roundi(float(f[1]) * DEF_SCALE))])
	def.foes = foes
	def.zone = maxi(1, md.rift_zone - DEF_ZONE_CUT)
	def.wander = 2.0
	return def


## 마을 방어전 하나(마을 한 번 방문 동안). 물결마다 북문과 목책 가장자리에 무리가 서서 영주에게 곧장 덤비고, 다 쓰러지면 쉬었다가 다음 물결.
## 마지막 물결까지 쓰러지면 cleared. 지는 일(영주가 쓰러짐)은 Rules.run_ended를 받은 쪽이 한다. lobby.gd가 틱마다 step()을 부른다.
class Defense extends RefCounted:
	var rules: Rules
	var md: MetaData
	var wave: int = 0
	var wait: float = 0.0
	var cleared: bool = false
	var ids: Array[StringName] = []
	signal wave_started(n: int, last: bool)
	signal done()

	func _init(p_rules: Rules, p_md: MetaData) -> void:
		rules = p_rules
		md = p_md

	func active() -> bool:
		return wave > 0 and not cleared

	func start() -> void:
		if wave == 0:
			_spawn(1)

	func _spawn(n: int) -> void:
		wave = n
		ids.clear()
		var edge: Vector2 = RiftRaid.DEF_EDGES[rules.rng.randi() % RiftRaid.DEF_EDGES.size()]
		var k: int = 0
		for at in [RiftRaid.DEF_GATE, edge]:
			var id := StringName("def_w%d_%d" % [n, k])
			rules.spawn_pack(id, RiftRaid.defense_def(rules, md, n, at))
			if rules.packs.has(id):
				ids.append(id)
			k += 1
		_chase()
		wave_started.emit(n, n >= RiftRaid.DEF_WAVES)

	## 무리를 늘 덤비는 상태로 두고, 무리의 제자리를 영주 곁으로 옮겨 멀어져도 돌아가지 않게 한다(마을은 들판 무리 규칙의 끈이 안 맞는다).
	func _chase() -> void:
		for id in ids:
			var p: Dictionary = rules.packs[id]
			p.home = rules.lord.pos
			if int(p.state) != Rules.PACK_ENGAGED and not bool(p.cleared):
				rules._engage_pack(id)

	func step(dt: float) -> void:
		if not active():
			return
		if wait > 0.0:
			wait -= dt
			if wait <= 0.0:
				_spawn(wave + 1)
			return
		_chase()
		for id in ids:
			if not bool(rules.packs[id].cleared):
				return
		if wave >= RiftRaid.DEF_WAVES:
			cleared = true
			done.emit()
		else:
			wait = md.rift_wave_gap
