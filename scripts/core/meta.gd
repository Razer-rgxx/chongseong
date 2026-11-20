class_name Meta
extends RefCounted
## 판과 판 사이에 남는 것: 조각, 검집, 축복, 도감, 기록. user://에 저장한다.
## 대장간·성소의 강화 확률은 판의 규칙(Rules.rng)과 따로 이 rng를 쓴다. 테스트는 시드를 넣어 돌린다.

const SAVE_PATH: String = "user://hill_save.json"

var shards: int = 0
## 검집에 넣은 검의 SwordData.id. -1이면 비었다.
var sheath_id: int = -1
## 들판·무덤에서 쓰러지면 쥔 검을 그 자리에 떨군다(소울류, 2026-11-20 사용자가 정함). {"id": 검 번호, "x", "y": 들판 칸}, 비면 없음.
## 무덤에서 쓰러지면 들판의 무덤 입구 앞에 떨어진다. 줍기 전에 또 쓰러지면 그 검은 lost로 간다.
var dropped: Dictionary = {}
## 잃은 검(번호 문자열 → 1). 검 걸이·북문·검집에서 빠진다. 언덕에서 다시 뽑으면(note_found) 되찾는다.
var lost: Dictionary = {}
## 검마다 쌓이는 기록(2026-11-20: "내 검"이 되게). 번호 문자열 → {"k": 벤 적, "b": 부러진 횟수, "p": 완벽한 뽑기, "r": 처음 뽑은 판 번호}.
var sword_log: Dictionary = {}
var sheath_lv: int = 0
## 가장 높이 올랐던 단계(각인은 처음 닿을 때만 붙는다).
var sheath_peak: int = 0
var sheath_ins: PackedStringArray = PackedStringArray()
## 축복 키 → 단계
var bless: Dictionary = {}
## 뽑아 본(들판에서 얻은 것도) 검: SwordData.id(문자열) → 횟수
var found: Dictionary = {}
## 가장 높이 오른 구역(1부터). 정상을 넘으면 구역 수 + 1.
var best: int = 0
var runs: int = 0
## 의뢰판(15단계): 붙은 의뢰(VillageData.quests의 번호) 3장, 맡은 장(-1 없음).
var quest_board: Array[int] = []
var quest_active: int = -1
## 떠돌이 상인의 좌판(물건 id)과 다음 판에 쓸 산 물건. 같은 물건은 한 판에 하나.
var stock: Array[StringName] = []
var pack: Array[StringName] = []
## 주민이 한 말: 주민 id → 들은 줄 번호들.
var heard: Dictionary = {}
## 수련장에서 마을을 떠나면 내려놓는 검(검 걸이에서 고른 SwordData.id, 저장하지 않는다).
var yard_sword: int = -1
## 들판(16단계): 연 유품 상자와 읽은 비석(id → 1), 비석 보상을 받았는지, 지금 떠 있는 흩어진 조각(후보 번호).
var field_found: Dictionary = {}
var lore_read: Dictionary = {}
var lore_paid: bool = false
var glints: Array[int] = []
var glints_ready: bool = false
## 들판 싸움(17단계): 이미 쓰러뜨린 무리 id(→ 1). 판이 끝날 때(record_run)와 들판에 날이 밝을 때(29단계, field.gd) 비운다.
var packs_cleared: Dictionary = {}
## 들판 시계(29단계, 초): 들판을 떠날 때 저장하고 다시 들어오면 이어 간다. 옛 저장은 0(아침). 들판 밖에서는 흐르지 않는다.
var field_clock: float = 0.0
## 들판 보스(18단계): 이번 판에 무덤 기사를 쓰러뜨렸는지(판이 끝날 때 record_run이 비운다, 쓰러뜨렸으면 들판에 다시 와도 안 선다)와 처음 보상을 받았는지(저장).
var boss_down: bool = false
var boss_first: bool = false
## 곳마다 우두머리(32단계): 처음 보상을 받은 우두머리 id(→ 1, 저장)와 이번 판에 쓰러뜨린 우두머리 id(→ 1, 저장, 판이 끝날 때 record_run이 비운다.
## 쓰러뜨렸으면 들판에 다시 와도 안 선다). 옛 저장은 빈 값으로 읽힌다.
var chiefs_first: Dictionary = {}
var chiefs_down: Dictionary = {}
## 떠도는 사람(34단계): 영입해 마을에 선 사람 id(FieldLayout.WANDERERS), 지금 들판에 선 사람 id(""이면 없음)와 그 자리(WANDERER_SPOTS 번호). 저장, 옛 저장은 비어 있다.
var recruits: Array[String] = []
var wanderer: String = ""
var wanderer_at: int = -1
## 들판 지도(38단계): 가 본 곳. FieldLayout.SEEN_SIZE 격자의 비트(한 칸 = 들판 SEEN_CELL칸, j * 너비 + i 번째 비트). 저장은 base64, 옛 저장은 아무것도 안 본 상태.
var field_seen: PackedByteArray = PackedByteArray()
## 지하 무덤(19단계): 이번 판에 쓰러뜨린 방 id(→ 1)와 연 관 id(→ 1). 판이 끝날 때(record_run) 비운다. 옛 저장은 빈 값으로 읽힌다.
var crypt_cleared: Dictionary = {}
var crypt_opened: Dictionary = {}
## 결투 기록(21단계, 저장): 같은 PC에서는 1P를 나로 센다. 비긴 결투는 세지 않는다. 옛 저장은 0으로 읽힌다.
var duel_wins: int = 0
var duel_losses: int = 0
## 마을 북문에서 고른 검(SwordData.id, 0은 맨손, -1은 안 골랐다)과 들판에서 쓰러져 북문 앞에서 깰 때의 표시.
## 장면을 넘어 이어지는 값이라 static이고 저장하지 않는다.
static var carry_sword: int = -1
## 결투(21단계)에서 1P와 2P가 든 검(SwordData.id, 0은 맨손). 마을 결투 말뚝에서 고르고 장면을 넘어 이어지는 값이라 static, 저장하지 않는다.
static var duel_picks: Array[int] = [0, 0]
static var wake_at_gate: bool = false
## 쓰러져서 마을·들판에서 깰 때 한 번 띄울 말(떨군 검·잃은 검). 띄우면 비운다.
static var wake_note: String = ""
## 지하 무덤에서 나왔거나 쓰러졌다: 들판의 무덤 입구 앞에서 깬다(장면을 넘어 이어지는 값이라 static, 저장하지 않는다).
static var wake_at_crypt: bool = false
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()
	field_seen = Meta.empty_seen()


static func load_or_new(path: String = SAVE_PATH) -> Meta:
	var m := Meta.new()
	if not FileAccess.file_exists(path):
		return m
	var f := FileAccess.open(path, FileAccess.READ)
	var d: Variant = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		m.from_dict(d)
	return m


func save(path: String = SAVE_PATH) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict(), "\t"))


func to_dict() -> Dictionary:
	return {"shards": shards, "sheath_id": sheath_id, "sheath_lv": sheath_lv, "sheath_peak": sheath_peak, "sheath_ins": Array(sheath_ins), "bless": bless, "found": found, "best": best, "runs": runs, "quest_board": quest_board, "quest_active": quest_active, "stock": Array(stock), "pack": Array(pack), "heard": heard, "field_found": field_found, "lore_read": lore_read, "lore_paid": lore_paid, "glints": glints, "glints_ready": glints_ready, "packs_cleared": packs_cleared, "field_clock": field_clock, "boss_down": boss_down, "boss_first": boss_first, "chiefs_first": chiefs_first, "chiefs_down": chiefs_down, "recruits": recruits, "wanderer": wanderer, "wanderer_at": wanderer_at, "crypt_cleared": crypt_cleared, "crypt_opened": crypt_opened, "duel_wins": duel_wins, "duel_losses": duel_losses, "dropped": dropped, "lost": lost, "sword_log": sword_log, "field_seen": Marshalls.raw_to_base64(field_seen)}


func from_dict(d: Dictionary) -> void:
	shards = int(d.get("shards", 0))
	sheath_id = int(d.get("sheath_id", -1))
	var dr: Variant = d.get("dropped", {})
	dropped = {}
	if dr is Dictionary and (dr as Dictionary).has("id"):
		dropped = {"id": int(dr["id"]), "x": float(dr.get("x", 0.0)), "y": float(dr.get("y", 0.0))}
	sword_log = {}
	var sl: Variant = d.get("sword_log", {})
	if sl is Dictionary:
		for k in sl:
			var e: Variant = sl[k]
			if e is Dictionary:
				sword_log[str(k)] = {"k": int(e.get("k", 0)), "b": int(e.get("b", 0)), "p": int(e.get("p", 0)), "r": int(e.get("r", 0))}
	lost = {}
	var lo: Variant = d.get("lost", {})
	if lo is Dictionary:
		for k in lo:
			lost[str(k)] = 1
	sheath_lv = int(d.get("sheath_lv", 0))
	sheath_peak = int(d.get("sheath_peak", 0))
	sheath_ins = PackedStringArray(d.get("sheath_ins", []))
	bless = {}
	var b: Dictionary = d.get("bless", {})
	for k in b:
		bless[k] = int(b[k])
	found = {}
	var f: Dictionary = d.get("found", {})
	for k in f:
		found[str(k)] = int(f[k])
	best = int(d.get("best", 0))
	runs = int(d.get("runs", 0))
	quest_board = []
	for q in d.get("quest_board", []):
		quest_board.append(int(q))
	quest_active = int(d.get("quest_active", -1))
	stock = []
	for g in d.get("stock", []):
		stock.append(StringName(g))
	pack = []
	for g in d.get("pack", []):
		pack.append(StringName(g))
	heard = {}
	var hd: Dictionary = d.get("heard", {})
	for k in hd:
		var arr: Array = []
		for v in hd[k]:
			arr.append(int(v))
		heard[str(k)] = arr
	field_found = {}
	for k in d.get("field_found", {}):
		field_found[str(k)] = 1
	lore_read = {}
	for k in d.get("lore_read", {}):
		lore_read[str(k)] = 1
	lore_paid = bool(d.get("lore_paid", false))
	glints = []
	for g in d.get("glints", []):
		glints.append(int(g))
	glints_ready = bool(d.get("glints_ready", false))
	packs_cleared = {}
	for k in d.get("packs_cleared", {}):
		packs_cleared[str(k)] = 1
	field_clock = clampf(float(d.get("field_clock", 0.0)), 0.0, FieldLayout.FIELD_DAY + FieldLayout.FIELD_NIGHT)
	boss_down = bool(d.get("boss_down", false))
	boss_first = bool(d.get("boss_first", false))
	chiefs_first = {}
	for k in d.get("chiefs_first", {}):
		chiefs_first[str(k)] = 1
	chiefs_down = {}
	for k in d.get("chiefs_down", {}):
		chiefs_down[str(k)] = 1
	recruits = []
	for k in d.get("recruits", []):
		if FieldLayout.WANDERERS.has(str(k)) and not recruits.has(str(k)):
			recruits.append(str(k))
	wanderer = str(d.get("wanderer", ""))
	wanderer_at = int(d.get("wanderer_at", -1))
	if not FieldLayout.WANDERERS.has(wanderer) or recruits.has(wanderer) or wanderer_at < 0 or wanderer_at >= FieldLayout.WANDERER_SPOTS.size():
		wanderer = ""
		wanderer_at = -1
	crypt_cleared = {}
	for k in d.get("crypt_cleared", {}):
		crypt_cleared[str(k)] = 1
	crypt_opened = {}
	for k in d.get("crypt_opened", {}):
		crypt_opened[str(k)] = 1
	duel_wins = int(d.get("duel_wins", 0))
	duel_losses = int(d.get("duel_losses", 0))
	field_seen = Meta.empty_seen()
	var fs: Variant = d.get("field_seen", "")
	if fs is String and fs != "":
		var raw: PackedByteArray = Marshalls.base64_to_raw(fs)
		if raw.size() == field_seen.size():   # 격자 크기가 다르면(모르는 모양) 안 본 것으로
			field_seen = raw


## 결투가 끝났다(winner: 0은 1P가 이김, 1은 2P가 이김, 그 밖은 비김). 1P를 나로 센다.
func record_duel(winner: int) -> void:
	if winner == 0:
		duel_wins += 1
	elif winner == 1:
		duel_losses += 1


func note_found(id: int) -> void:
	found[str(id)] = int(found.get(str(id), 0)) + 1
	lost.erase(str(id))   # 잃었던 검을 다시 뽑으면 되찾는다


# ---------------------------------------------------------------- 검의 기록 (2026-11-20)

func _log(id: int) -> Dictionary:
	var k: String = str(id)
	if not sword_log.has(k):
		sword_log[k] = {"k": 0, "b": 0, "p": 0, "r": runs + 1}
	return sword_log[k]


## 뽑았다(처음이면 몇 번째 판에 뽑았는지 남는다). perfect: 완벽한 뽑기였다.
func log_pull(id: int, perfect: bool) -> void:
	if id <= 0:
		return
	var e := _log(id)
	if perfect:
		e["p"] = int(e["p"]) + 1


## 이 검으로 적을 쓰러뜨렸다(언덕·들판·무덤).
## 벤 적을 세고, 이번에 새 기억 단계(MEMORY)를 넘었으면 그 단계 번호(1~)를 돌려준다(아니면 0).
func log_kill(id: int) -> int:
	if id <= 0:
		return 0
	var e := _log(id)
	var before: int = memory_tier(id)
	e["k"] = int(e["k"]) + 1
	var after: int = memory_tier(id)
	return after if after > before else 0


# ---------------------------------------------------------------- 검의 기억 (2026-11-20 사용자: "1000~10000마리 잡으면 ○○와의 추억이 담긴 검, ○○의 검의 사념")

## 한 검으로 벤 적 수에 따라 검이 이름을 얻는다. [벤 적, 이름 꼴({n} = 검 이름, {과} 등은 조사), 그 검으로 벨 때 피해 배수].
## 피해 배수는 그 검을 쥐고 나갈 때(판·들판·무덤 시작) Rules.memory로 넘어간다(판 도중에 넘으면 다음부터).
const MEMORY: Array = [
	[1000, "손에 익은 {n}", 1.02],
	[2500, "{n}{과}의 추억이 담긴 검", 1.04],
	[5000, "{n}의 검의 사념", 1.06],
	[7500, "이름을 부르면 대답하는 {n}", 1.08],
	[10000, "{n}, 영주의 반쪽", 1.10],
]


## 지금 기억 단계(0 = 아직 없음, 1~5).
func memory_tier(id: int) -> int:
	var k: int = kills_of(id)
	var t: int = 0
	for i in MEMORY.size():
		if k >= int(MEMORY[i][0]):
			t = i + 1
	return t


## 기억 단계가 있으면 그 이름, 없으면 검 이름 그대로.
func memory_title(d: SwordData, id: int = -1) -> String:
	if d == null:
		return "?"
	var t: int = memory_tier(id if id > 0 else d.id)
	if t == 0:
		return d.display_name
	var n: String = d.display_name
	return String(MEMORY[t - 1][1]).replace("{n}", n).replace("{과}", josa(n, "과", "와"))


## 다음 단계까지 남은 적 수(마지막 단계면 0).
func memory_next(id: int) -> int:
	var t: int = memory_tier(id)
	return 0 if t >= MEMORY.size() else int(MEMORY[t][0]) - kills_of(id)


## 검 번호 → 피해 배수(기억이 있는 검만). Rules.memory에 넣는다.
func memory_table() -> Dictionary:
	var out: Dictionary = {}
	for k in sword_log:
		var t: int = memory_tier(int(k))
		if t > 0:
			out[int(k)] = float(MEMORY[t - 1][2])
	return out


## 받침이 있으면 with_final, 없으면 without(예: josa("검", "과", "와") = "과"). 한글이 아니면 without.
static func josa(word: String, with_final: String, without: String) -> String:
	if word.is_empty():
		return without
	var c: int = word.unicode_at(word.length() - 1)
	if c < 0xAC00 or c > 0xD7A3:
		return without
	return with_final if (c - 0xAC00) % 28 != 0 else without


func log_break(id: int) -> void:
	if id > 0:
		var e := _log(id)
		e["b"] = int(e["b"]) + 1


func kills_of(id: int) -> int:
	return int(sword_log.get(str(id), {}).get("k", 0))


## 기록 한 줄("벤 적 120 · 부러짐 3 · 완벽한 뽑기 2 · 7번째 판에 처음 뽑음"). 기록이 없으면 "".
func log_line(id: int) -> String:
	if not sword_log.has(str(id)):
		return ""
	var e: Dictionary = sword_log[str(id)]
	var parts: Array[String] = ["벤 적 %d" % int(e["k"])]
	if int(e["b"]) > 0:
		parts.append("부러짐 %d" % int(e["b"]))
	if int(e["p"]) > 0:
		parts.append("완벽한 뽑기 %d" % int(e["p"]))
	if int(e["r"]) > 0:
		parts.append("%d번째 판에 처음 뽑음" % int(e["r"]))
	return " · ".join(parts)


# ---------------------------------------------------------------- 떨군 검 (2026-11-20)

## 쓰러졌다: 먼저 떨군 검이 있으면 그것은 잃고(lost), 쥔 검(id > 0)을 at에 떨군다. 잃은 검 번호를 돌려준다(없으면 -1).
## 검집의 검을 잃으면 검집이 비고 fix_sheath가 다음 좋은 검을 넣는다(검집 강화·각인은 검집에 남는다).
func drop_sword(game: GameData, id: int, at: Vector2) -> int:
	var gone: int = -1
	if not dropped.is_empty():
		gone = int(dropped["id"])
		lost[str(gone)] = 1
		dropped = {}
		if sheath_id == gone:
			sheath_id = -1
			fix_sheath(game)
	if id > 0:
		dropped = {"id": id, "x": at.x, "y": at.y}
	return gone


## 떨군 검을 주웠다. 주운 검 번호(없으면 -1).
func pick_dropped() -> int:
	var id: int = dropped_id()
	dropped = {}
	return id


func dropped_id() -> int:
	return int(dropped["id"]) if not dropped.is_empty() else -1


func dropped_at() -> Vector2:
	return Vector2(float(dropped.get("x", 0.0)), float(dropped.get("y", 0.0)))


## 지금 쥐고 나갈 수 있는 검인가(잃지도, 떨구지도 않았다).
func usable(id: int) -> bool:
	return id > 0 and not lost.has(str(id)) and id != dropped_id()


func has_found(id: int) -> bool:
	return found.has(str(id))


func bless_level(key: String) -> int:
	return int(bless.get(key, 0))


## 축복이 판에 주는 값.
func bless_value(md: MetaData, key: String) -> float:
	var i: int = md.bless_keys.find(key)
	return 0.0 if i < 0 else md.bless_step[i] * bless_level(key)


# ---------------------------------------------------------------- 검집

## 검집에 넣을 수 있는 검(찾아 본 전설 이상, 오픈월드 한정 검도), 높은 등급부터.
func sheath_candidates(game: GameData) -> Array[int]:
	var out: Array[int] = []
	for s in game.swords:
		if s.grade >= game.meta.sheath_min_grade and has_found(s.id) and not lost.has(str(s.id)):
			out.append(s.id)
	out.sort_custom(func(a: int, b: int) -> bool:
		var ga: int = game.sword_by_id(a).grade
		var gb: int = game.sword_by_id(b).grade
		return ga > gb or (ga == gb and a < b))
	return out


## 검집에 든 검이 자격을 잃었으면 비우고, 비었으면 가장 좋은 것을 넣는다.
func fix_sheath(game: GameData) -> void:
	var c := sheath_candidates(game)
	if sheath_id >= 0 and not c.has(sheath_id):
		sheath_id = -1
	if sheath_id < 0 and not c.is_empty():
		sheath_id = c[0]


## 망치질 값. 떠돌이 대장장이를 영입했으면(34단계) RECRUIT_FORGE배.
func sheath_cost(md: MetaData) -> int:
	return roundi(md.sheath_cost * (sheath_lv + 1) * (FieldLayout.RECRUIT_FORGE if has_recruit("smith") else 1.0))


func sheath_rate(md: MetaData) -> float:
	return md.sheath_rates[mini(sheath_lv, md.sheath_rates.size() - 1)]


## 망치를 내리친 결과. ok, dropped, ins(새로 붙은 각인, 없으면 "").
func forge_sheath(game: GameData) -> Dictionary:
	var md := game.meta
	var r := {"ok": false, "dropped": false, "ins": "", "paid": false}
	if sheath_lv >= md.sheath_max or shards < sheath_cost(md):
		return r
	shards -= sheath_cost(md)
	r.paid = true
	var before: int = sheath_lv
	if rng.randf() * 100.0 < sheath_rate(md):
		sheath_lv += 1
		r.ok = true
		if md.sheath_ins_levels.has(sheath_lv) and sheath_lv > sheath_peak:
			var keys: Array = game.inscriptions.keys().filter(func(k: String) -> bool: return not sheath_ins.has(k))
			keys.sort()
			if not keys.is_empty():
				r.ins = keys[rng.randi_range(0, keys.size() - 1)]
				sheath_ins.append(r.ins)
		sheath_peak = maxi(sheath_peak, sheath_lv)
	elif before >= md.sheath_drop_from:
		sheath_lv -= 1
		r.dropped = true
	return r


## 검집에 든 검을 판에 들고 갈 모습으로 만든다. 없으면 null.
func sheath_sword(game: GameData) -> Sword:
	if sheath_id < 0:
		return null
	var d := game.sword_by_id(sheath_id)
	if d == null or d.grade < game.meta.sheath_min_grade or not has_found(sheath_id):
		return null
	var s := Sword.new(d, game)
	s.apply_sheath(sheath_lv, sheath_ins, game)
	return s


# ---------------------------------------------------------------- 축복

## 축복 값. 길 잃은 순례자를 영입했으면(34단계) RECRUIT_BLESS배.
func bless_cost(md: MetaData, key: String) -> int:
	return roundi(md.bless_cost * (bless_level(key) + 1) * (FieldLayout.RECRUIT_BLESS if has_recruit("pilgrim") else 1.0))


func bless_rate(md: MetaData, key: String) -> float:
	return md.bless_rates[mini(bless_level(key), md.bless_rates.size() - 1)]


func bless_full(md: MetaData, key: String) -> bool:
	var i: int = md.bless_keys.find(key)
	return i < 0 or bless_level(key) >= md.bless_max[i]


## 축복은 실패해도 내려가지 않는다.
func forge_bless(md: MetaData, key: String) -> Dictionary:
	var r := {"ok": false, "paid": false}
	if bless_full(md, key) or shards < bless_cost(md, key):
		return r
	shards -= bless_cost(md, key)
	r.paid = true
	if rng.randf() * 100.0 < bless_rate(md, key):
		bless[key] = bless_level(key) + 1
		r.ok = true
	return r


# ---------------------------------------------------------------- 판이 끝나면

## 판에서 얻은 조각을 항목별로 센다.
static func run_shards(rules: Rules, md: MetaData) -> Dictionary:
	var broken: int = 0
	var melted: int = 0
	for g in rules.broken_by_grade.size():
		broken += rules.broken_by_grade[g] * md.broken[g]
		melted += rules.melted_by_grade[g] * md.melt[g]
	var r := {
		"kills": floori(float(rules.kills) / md.kills_per_shard),
		"zone": rules.zone * md.per_zone + (md.win_bonus if rules.won else 0),
		"broken": broken,
		"elite": rules.elites_killed * md.elite,
		"melt": melted,
		"goal": rules.goal_shards,
		"path": rules.path_shards,
	}
	r["total"] = r.kills + r.zone + r.broken + r.elite + r.melt + r.goal + r.path
	return r


func record_run(rules: Rules, md: MetaData) -> Dictionary:
	var r := run_shards(rules, md)
	shards += r.total
	# 의뢰: 맡은 것을 이루었으면 조각을 주고, 판이 끝날 때마다 안 맡은 것 하나를 바꾼다
	r["quest_done"] = false
	r["quest_reward"] = 0
	r["quest_text"] = ""
	var V := rules.data.village
	if quest_active >= 0 and quest_active < quest_board.size():
		var q: QuestData = V.quests[quest_board[quest_active]]
		r.quest_text = quest_text(q)
		if quest_count(q, rules.run_stats) >= q.n:
			r.quest_done = true
			r.quest_reward = q.reward
			shards += q.reward
			r.total += q.reward
			quest_board[quest_active] = _pick_quest(V, rules.data, true)
			quest_active = -1
	refresh_board(rules.data)
	refresh_stock(rules.data)
	roll_glints()
	packs_cleared = {}
	boss_down = false
	chiefs_down = {}
	crypt_cleared = {}
	crypt_opened = {}
	best = maxi(best, rules.zone_count() + 1 if rules.won else rules.zone + 1)
	runs += 1
	return r


# ---------------------------------------------------------------- 들판 (docs/village.md 16.2)

## 유품 상자를 연다. 처음이면 조각을 받고 그 수를, 이미 열었으면 0을 돌려준다.
func field_open(id: String, amount: int) -> int:
	if field_found.has(id):
		return 0
	field_found[id] = 1
	shards += amount
	return amount


## 들판 싸움(17단계): 적 하나를 쓰러뜨렸다. 받은 조각 수를 돌려준다.
func field_kill() -> int:
	shards += FieldLayout.PACK_KILL_SHARDS
	return FieldLayout.PACK_KILL_SHARDS


## 무리를 다 쓰러뜨렸다. 처음이면 조각(PACK_CLEAR_MIN~MAX, Meta.rng, 늙은 사냥꾼을 영입했으면 RECRUIT_HUNT배)을 받고 그 수를, 이미 쓰러뜨린 무리면 0을 돌려준다.
func field_clear(id: String) -> int:
	if packs_cleared.has(id):
		return 0
	packs_cleared[id] = 1
	var n: int = rng.randi_range(FieldLayout.PACK_CLEAR_MIN, FieldLayout.PACK_CLEAR_MAX)
	if has_recruit("hunter"):   # 34단계: 늙은 사냥꾼이 거둔다
		n = roundi(n * FieldLayout.RECRUIT_HUNT)
	shards += n
	return n


## 들판 보스(18단계): 무덤 기사를 쓰러뜨렸다. 처음이면 조각 BOSS_FIRST_SHARDS, 다음부터 BOSS_SHARDS를 받고, 운 부적이 pack에 든다(이미 있으면 그대로).
## {shards, first, charm}을 돌려준다(charm은 새로 들었는지).
func boss_defeat() -> Dictionary:
	var first: bool = not boss_first
	var n: int = FieldLayout.BOSS_FIRST_SHARDS if first else FieldLayout.BOSS_SHARDS
	shards += n
	boss_first = true
	boss_down = true
	var charm: bool = not pack.has(FieldLayout.BOSS_CHARM)
	if charm:
		pack.append(FieldLayout.BOSS_CHARM)
	return {"shards": n, "first": first, "charm": charm}


## 곳마다 우두머리(32단계)를 쓰러뜨렸다. 처음이면 조각 CHIEF_FIRST_SHARDS와 그 곳의 오픈월드 한정 검(도감에 든다),
## 다음부터 CHIEF_SHARDS. {shards, first, sword(새로 얻은 검 id, 없으면 0)}을 돌려준다. 모르는 id면 shards 0.
func chief_defeat(id: String) -> Dictionary:
	var r := {"shards": 0, "first": false, "sword": 0}
	if not FieldLayout.CHIEFS.has(id):
		return r
	r.first = not chiefs_first.has(id)
	r.shards = FieldLayout.CHIEF_FIRST_SHARDS if r.first else FieldLayout.CHIEF_SHARDS
	shards += r.shards
	chiefs_first[id] = 1
	chiefs_down[id] = 1
	if r.first:
		r.sword = int(FieldLayout.CHIEFS[id].sword)
		note_found(r.sword)
	return r


# ---------------------------------------------------------------- 들판 지도 (38단계)

## 아무것도 안 본 밝힘 격자(비트 SEEN_SIZE.x × SEEN_SIZE.y개, 모두 0).
static func empty_seen() -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(ceili(FieldLayout.SEEN_SIZE.x * FieldLayout.SEEN_SIZE.y / 8.0))
	b.fill(0)
	return b


## 밝힘 격자 칸 (i, j)를 봤는가. 격자 밖은 false.
func seen_cell(i: int, j: int) -> bool:
	if i < 0 or j < 0 or i >= FieldLayout.SEEN_SIZE.x or j >= FieldLayout.SEEN_SIZE.y:
		return false
	var k: int = j * FieldLayout.SEEN_SIZE.x + i
	return field_seen[k >> 3] & (1 << (k & 7)) != 0


## 들판 칸 c가 든 밝힘 칸을 봤는가.
func seen_at(c: Vector2) -> bool:
	return seen_cell(floori(c.x / FieldLayout.SEEN_CELL), floori(c.y / FieldLayout.SEEN_CELL))


## 영주가 at(들판 칸)에 있다: 둘레 radius칸 원에 닿는 밝힘 칸을 모두 밝힌다. 새로 밝힌 칸 수를 돌려준다(0이면 바뀐 것 없음).
func see_field(at: Vector2, radius: float = FieldLayout.SEEN_RADIUS) -> int:
	var C: float = float(FieldLayout.SEEN_CELL)
	var i0: int = maxi(0, floori((at.x - radius) / C))
	var i1: int = mini(FieldLayout.SEEN_SIZE.x - 1, floori((at.x + radius) / C))
	var j0: int = maxi(0, floori((at.y - radius) / C))
	var j1: int = mini(FieldLayout.SEEN_SIZE.y - 1, floori((at.y + radius) / C))
	var n: int = 0
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var near := Vector2(clampf(at.x, i * C, (i + 1) * C), clampf(at.y, j * C, (j + 1) * C))   # 칸에서 영주에게 가장 가까운 점
			if near.distance_to(at) > radius:
				continue
			var k: int = j * FieldLayout.SEEN_SIZE.x + i
			var bit: int = 1 << (k & 7)
			if field_seen[k >> 3] & bit == 0:
				field_seen[k >> 3] |= bit
				n += 1
	return n


## 본 밝힘 칸 수(지도 머리에 "가 본 곳 n%").
func seen_count() -> int:
	var n: int = 0
	for k in FieldLayout.SEEN_SIZE.x * FieldLayout.SEEN_SIZE.y:
		if field_seen[k >> 3] & (1 << (k & 7)) != 0:
			n += 1
	return n


# ---------------------------------------------------------------- 떠도는 사람과 영입 (34단계)

func has_recruit(id: String) -> bool:
	return recruits.has(id)


## 떠돌이 약초꾼을 영입했으면 판 시작·들판의 최대 체력에 더하는 값(Rules.bonus_hp).
func recruit_hp() -> float:
	return FieldLayout.RECRUIT_HP if has_recruit("gatherer") else 0.0


## 들판에 설 사람을 새로 정한다(들판 새벽마다): 아직 영입하지 않은 사람 중 하나와 후보 자리 하나(Meta.rng). 다 영입했으면 아무도 없다.
func place_wanderer() -> void:
	var pool: Array[String] = []
	for id in FieldLayout.WANDERERS:
		if not recruits.has(id):
			pool.append(id)
	if pool.is_empty():
		wanderer = ""
		wanderer_at = -1
		return
	wanderer = pool[rng.randi_range(0, pool.size() - 1)]
	wanderer_at = rng.randi_range(0, FieldLayout.WANDERER_SPOTS.size() - 1)


## 들판에 들어올 때: 서 있는 사람이 없으면 세운다.
func ensure_wanderer() -> void:
	if wanderer == "":
		place_wanderer()


## 지금 선 사람의 조건이 몇까지 찼는지 [지금, 필요]. 없으면 [0, 1].
func wanderer_count(game: GameData) -> Array[int]:
	if wanderer == "":
		return [0, 1]
	var W: Dictionary = FieldLayout.WANDERERS[wanderer]
	var need: int = int(W.n)
	var have: int = 0
	match String(W.cond):
		"shards":
			have = shards
		"field_sword":
			for i in game.field_swords:
				have += 1 if has_found(game.swords[i].id) else 0
		"pack":
			have = 1 if wanderer_at >= 0 and packs_cleared.has(String(FieldLayout.WANDERER_SPOTS[wanderer_at].pack)) else 0
		"stones":
			for k in FieldLayout.STONES:
				have += 1 if lore_read.has(k) else 0
		"chiefs":
			have = chiefs_first.size()
	return [have, need]


## 지금 선 사람을 데려갈 수 있는지(조건이 맞음).
func wanderer_ready(game: GameData) -> bool:
	var c: Array[int] = wanderer_count(game)
	return wanderer != "" and c[0] >= c[1]


## 조건의 진행을 띠에 붙일 한 줄(예: "읽은 비석 3 / 5").
func wanderer_progress(game: GameData) -> String:
	if wanderer == "":
		return ""
	var c: Array[int] = wanderer_count(game)
	match String(FieldLayout.WANDERERS[wanderer].cond):
		"shards":
			return "가진 조각 %d / %d" % [c[0], c[1]]
		"field_sword":
			return "들판의 검 %d / %d" % [mini(c[0], c[1]), c[1]]
		"pack":
			var at: Vector2 = FieldLayout.PACKS[String(FieldLayout.WANDERER_SPOTS[wanderer_at].pack)].at
			return "%s의 무리 %d / %d" % [FieldLayout.AREA_NAMES[FieldLayout.area_at(at)], c[0], c[1]]
		"stones":
			return "읽은 비석 %d / %d" % [c[0], c[1]]
		"chiefs":
			return "쓰러뜨린 우두머리 %d / %d" % [mini(c[0], c[1]), c[1]]
	return ""


## 지금 선 사람을 데려간다(조건이 맞을 때만). 약초꾼은 조각을 내고, 기사는 오픈월드 한정 검(RECRUIT_SWORD)을 준다.
## {ok, id, paid(낸 조각), sword(받은 검 id, 없으면 0)}을 돌려준다. 데려가면 들판에는 아무도 없다(다음 새벽에 다른 사람).
func recruit(game: GameData) -> Dictionary:
	var r := {"ok": false, "id": wanderer, "paid": 0, "sword": 0}
	if not wanderer_ready(game):
		return r
	var W: Dictionary = FieldLayout.WANDERERS[wanderer]
	if String(W.cond) == "shards":
		r.paid = int(W.n)
		shards -= r.paid
	if wanderer == "knight":
		r.sword = FieldLayout.RECRUIT_SWORD
		note_found(r.sword)
	recruits.append(wanderer)
	r.ok = true
	wanderer = ""
	wanderer_at = -1
	return r


## 지하 무덤(19단계): 방을 쓰러뜨렸다(저장된다. 쓰러져도 남는다).
func crypt_clear(id: String) -> void:
	crypt_cleared[id] = 1


## 돌 관을 연다. 그 방을 쓰러뜨렸고 아직 안 열었을 때만 받는다. 일반 관은 조각 CRYPT_COFFIN_MIN~MAX(Meta.rng),
## 마지막 방의 큰 관은 조각 CRYPT_BIG_SHARDS와 운 부적(Meta.pack, 이미 있으면 겹치지 않는다).
## 31단계: 큰 관을 처음 열면(도감에 아직 없으면) 오픈월드 한정 검 CryptLayout.BIG_COFFIN_SWORD를 도감(found, note_found)에 넣는다.
## 그 검 파일이 없으면 조용히 건너뛴다(33단계 전).
## {shards, charm, sword(얻은 검 번호, 없으면 -1)}을 돌려준다(못 열면 shards 0).
func crypt_open(id: String) -> Dictionary:
	var r := {"shards": 0, "charm": false, "sword": -1}
	if not crypt_cleared.has(id) or crypt_opened.has(id) or not CryptLayout.ROOMS.has(StringName(id)):
		return r
	crypt_opened[id] = 1
	var n: int
	if bool(CryptLayout.ROOMS[StringName(id)].get("big", false)):
		n = CryptLayout.BIG_SHARDS
		if not pack.has(CryptLayout.BIG_CHARM):
			pack.append(CryptLayout.BIG_CHARM)
			r.charm = true
		if not has_found(CryptLayout.BIG_COFFIN_SWORD) and CryptLayout.big_coffin_sword_path() != "":
			note_found(CryptLayout.BIG_COFFIN_SWORD)
			r.sword = CryptLayout.BIG_COFFIN_SWORD
	else:
		n = rng.randi_range(CryptLayout.COFFIN_MIN, CryptLayout.COFFIN_MAX)
	shards += n
	r.shards = n
	return r


## 흩어진 조각 자리를 새로 뽑는다(판이 끝날 때마다).
func roll_glints() -> void:
	var pool: Array[int] = []
	for i in FieldLayout.GLINTS.size():
		pool.append(i)
	glints = []
	for _k in mini(FieldLayout.GLINT_ACTIVE, pool.size()):
		var j: int = rng.randi() % pool.size()
		glints.append(pool[j])
		pool.remove_at(j)
	glints.sort()
	glints_ready = true


func ensure_glints() -> void:
	if not glints_ready:
		roll_glints()


## 흩어진 조각을 줍는다. 줍은 수(2~5)를 돌려주고 없는 자리면 0.
func take_glint(i: int) -> int:
	var at: int = glints.find(i)
	if at < 0:
		return 0
	glints.remove_at(at)
	var n: int = rng.randi_range(FieldLayout.GLINT_MIN, FieldLayout.GLINT_MAX)
	shards += n
	return n


## 비석을 읽는다. 모든 비석(FieldLayout.STONES 전부, 20단계에서 7개)을 다 읽은 그 순간에만 보상 조각 수를, 아니면 0을 돌려준다(한 번뿐:
## 옛 저장에서 여섯 개를 읽고 이미 받은 사람(lore_paid)은 일곱 번째를 읽어도 다시 받지 않는다).
func read_stone(id: String) -> int:
	lore_read[id] = 1
	var all: bool = true
	for k in FieldLayout.STONES:
		all = all and lore_read.has(k)
	if not lore_paid and all:
		lore_paid = true
		shards += FieldLayout.LORE_REWARD
		return FieldLayout.LORE_REWARD
	return 0


# ---------------------------------------------------------------- 의뢰판 (docs/village.md 15.1)

## 이번 판의 stats에서 그 의뢰가 센 값.
static func quest_count(q: QuestData, st: Dictionary) -> int:
	match q.kind:
		&"kill":
			return int(st.get("kills", 0))
		&"kill_kind":
			return int(st.get("kills_by_kind", {}).get(q.target, 0))
		&"zones":
			return int(st.get("zones", 0))
		&"elites":
			return int(st.get("elites", 0))
		&"pull_grade":
			var n: int = 0
			var arr: Array = st.get("pulled_by_grade", [])
			for g in range(q.grade, arr.size()):
				n += int(arr[g])
			return n
		&"perfect":
			return int(st.get("perfect", 0))
		&"goal":
			return int(st.get("goals_done", {}).get(q.target, 0))
		&"events":
			return int(st.get("events_used", 0))
	return 0


## 의뢰 한 줄의 말.
static func quest_text(q: QuestData) -> String:
	match q.kind:
		&"kill":
			return "한 판에 적 %d마리 쓰러뜨리기" % q.n
		&"kill_kind":
			return "한 판에 %s %d마리 쓰러뜨리기" % [KIND_NAMES.get(q.target, str(q.target)), q.n]
		&"zones":
			return "한 판에 %d구역 넘기" % q.n
		&"elites":
			return "한 판에 정예 %d 쓰러뜨리기" % q.n
		&"pull_grade":
			return "한 판에 %s 이상 %d자루 뽑기" % [GRADE_NAMES[clampi(q.grade, 0, 5)], q.n]
		&"perfect":
			return "한 판에 모두 제대로 당기기 %d번" % q.n
		&"goal":
			return "한 판에 %s 목표 %d번 이루기" % [GOAL_NAMES.get(q.target, str(q.target)), q.n]
		&"events":
			return "한 판에 낮 사건 %d번 쓰기" % q.n
	return ""


const KIND_NAMES: Dictionary = {&"wraith": "망령", &"wolf": "늑대", &"giant": "거인", &"archer": "활잡이", &"shield": "방패병", &"charger": "돌격병", &"bomber": "자폭병", &"caller": "부르는 자"}
const GOAL_NAMES: Dictionary = {&"hunt": "사냥", &"defend": "봉화 지키기", &"siege": "포위"}
const GRADE_NAMES: PackedStringArray = ["흔함", "귀함", "전설", "신화", "초월", "무한"]


## 붙일 수 있는 의뢰(가장 높이 오른 구역이 모자라지 않고, 판에 안 붙은 종류).
func _pick_quest(V: VillageData, game: GameData, replacing: bool = false) -> int:
	var used_kinds: Array = []
	for i in quest_board:
		if i >= 0:
			used_kinds.append(_kind_key(V.quests[i]))
	var open: Array[int] = []
	var open_any: Array[int] = []
	for i in V.quests.size():
		var q := V.quests[i]
		if best < q.min_best or quest_board.has(i):
			continue
		open_any.append(i)
		if not used_kinds.has(_kind_key(q)):
			open.append(i)
	var pool: Array[int] = open if not open.is_empty() else open_any
	if pool.is_empty():
		return 0
	return pool[rng.randi_range(0, pool.size() - 1)]


static func _kind_key(q: QuestData) -> String:
	return "%s:%s" % [q.kind, q.target if q.kind == &"kill_kind" or q.kind == &"goal" else ""]


## 의뢰판을 채운다(처음, 또는 저장에 없을 때).
func fill_board(game: GameData) -> void:
	var V := game.village
	quest_board = quest_board.filter(func(i: int) -> bool: return i >= 0 and i < V.quests.size())
	if quest_active >= quest_board.size():
		quest_active = -1
	while quest_board.size() < V.board_size:
		quest_board.append(_pick_quest(V, game))


## 판이 끝날 때마다 안 맡은 것 하나를 바꾼다.
func refresh_board(game: GameData) -> void:
	fill_board(game)
	var free: Array[int] = []
	for i in quest_board.size():
		if i != quest_active:
			free.append(i)
	if free.is_empty():
		return
	var k: int = free[rng.randi_range(0, free.size() - 1)]
	var old: int = quest_board[k]
	quest_board[k] = -1
	var n: int = _pick_quest(game.village, game)
	quest_board[k] = n if n != old or game.village.quests.size() < 4 else old


func take_quest(i: int) -> bool:
	if quest_active >= 0 or i < 0 or i >= quest_board.size():
		return false
	quest_active = i
	return true


## 의뢰를 내려놓는다(맡은 것만).
func drop_quest() -> void:
	quest_active = -1


# ---------------------------------------------------------------- 떠돌이 상인 (15.4)

func refresh_stock(game: GameData) -> void:
	var V := game.village
	var ids: Array[StringName] = []
	for g in V.goods:
		ids.append(g.id)
	stock = []
	while stock.size() < mini(V.stock_size, ids.size()):
		var k: int = rng.randi_range(0, ids.size() - 1)
		stock.append(ids[k])
		ids.remove_at(k)


func fill_stock(game: GameData) -> void:
	stock = stock.filter(func(g: StringName) -> bool: return game.village.goods_by_id(g) != null)
	if stock.is_empty():
		refresh_stock(game)


## 물건을 산다. 같은 물건은 한 판에 하나, 조각이 모자라면 못 산다. 이유("" 이면 샀다).
func buy(game: GameData, id: StringName) -> String:
	var g := game.village.goods_by_id(id)
	if g == null or not stock.has(id):
		return "그런 물건은 없다"
	if pack.has(id):
		return "이미 샀다"
	if shards < g.price:
		return "조각이 모자란다"
	shards -= g.price
	pack.append(id)
	return ""


# ---------------------------------------------------------------- 주민 (15.3)

func cond_ok(cond: String, n: int, game: GameData) -> bool:
	match cond:
		"":
			return true
		"runs":
			return runs >= n
		"best":
			return best >= n
		"legend":
			for s in game.swords:
				if s.grade >= 2 and has_found(s.id):
					return true
			return false
		"top":
			return best > game.run.zone_names.size()
		"quest":
			return quest_active >= 0
	return false


## 그 주민의 다음 말: 조건이 맞는 줄 중 아직 안 들은 것부터, 다 들었으면 처음부터 다시. 줄 번호를 돌려준다(-1이면 말이 없다).
func next_line(game: GameData, id: StringName) -> int:
	var v := game.village.villager(id)
	if v == null:
		return -1
	var ok: Array[int] = []
	for i in v.lines.size():
		if cond_ok(v.cond[i], v.cond_n[i], game):
			ok.append(i)
	if ok.is_empty():
		return -1
	var heard_i: Array = heard.get(str(id), [])
	for i in ok:
		if not heard_i.has(i):
			return i
	return ok[0]


## 말을 건다: 오늘 할 말 한 줄들(안 들은 줄이면 그 줄 하나 + 이어지는 안 들은 줄이 없으면 끝). 듣는다고 기록한다.
func talk(game: GameData, id: StringName) -> Array[String]:
	var v := game.village.villager(id)
	var out: Array[String] = []
	var i: int = next_line(game, id)
	if i < 0:
		return out
	out.append(v.lines[i])
	var h: Array = heard.get(str(id), [])
	if not h.has(i):
		h.append(i)
	heard[str(id)] = h
	# 다음 줄이 안 들은 줄이면 이어서 한 번 더(2~4줄 이야기)
	var j: int = next_line(game, id)
	while j >= 0 and not h.has(j) and out.size() < 3:
		out.append(v.lines[j])
		h.append(j)
		j = next_line(game, id)
	return out


# ---------------------------------------------------------------- 수련장 검 걸이 (15.2)

## 걸이에서 고를 수 있는 검: 검집의 검과 도감에서 찾은 검(찾은 것 중 낮은 등급 판).
func yard_swords(game: GameData) -> Array[int]:
	var out: Array[int] = []
	if sheath_id >= 0:
		out.append(sheath_id)
	var ids: Array[int] = []
	for s in game.swords:
		if has_found(s.id) and not out.has(s.id):
			ids.append(s.id)
	ids.sort_custom(func(a: int, b: int) -> bool:
		var ga: int = game.sword_by_id(a).grade
		var gb: int = game.sword_by_id(b).grade
		return ga > gb or (ga == gb and a < b))
	out.append_array(ids)
	var ok: Array[int] = []
	for i in out:
		if usable(i):   # 잃은 검·떨군 검은 걸 수 없다
			ok.append(i)
	return ok


## 수련장에서 쥘 검(검집의 검이면 검집 강화를 입는다). 없으면 null(맨손). 부러지지 않는다.
func yard_sword_made(game: GameData) -> Sword:
	return unbreakable_sword(game, yard_sword)


## id의 검(검집의 검이면 검집 강화를 입는다). 0 이하나 모르는 id면 null(맨손). 부러지지 않는다. 수련장과 들판이 쓴다.
func unbreakable_sword(game: GameData, id: int) -> Sword:
	if id <= 0:
		return null
	var d := game.sword_by_id(id)
	if d == null:
		return null
	var s := Sword.new(d, game)
	if id == sheath_id:
		s.apply_sheath(sheath_lv, sheath_ins, game)
	s.max_durability = -1.0
	s.durability = -1.0
	return s
