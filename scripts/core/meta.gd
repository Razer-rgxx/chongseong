class_name Meta
extends RefCounted
## 판과 판 사이에 남는 것: 조각, 검집, 축복, 도감, 기록. user://에 저장한다.
## 대장간·성소의 강화 확률은 판의 규칙(Rules.rng)과 따로 이 rng를 쓴다. 테스트는 시드를 넣어 돌린다.

const SAVE_PATH: String = "user://hill_save.json"

var shards: int = 0
## 검집에 넣은 검의 SwordData.id. -1이면 비었다.
var sheath_id: int = -1
var sheath_lv: int = 0
## 가장 높이 올랐던 단계(각인은 처음 닿을 때만 붙는다).
var sheath_peak: int = 0
var sheath_ins: PackedStringArray = PackedStringArray()
## 축복 키 → 단계
var bless: Dictionary = {}
## 뽑아 본 검: SwordData.id(문자열) → 횟수
var found: Dictionary = {}
## 가장 높이 오른 구역(1부터). 정상을 넘으면 구역 수 + 1.
var best: int = 0
var runs: int = 0
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


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
	return {"shards": shards, "sheath_id": sheath_id, "sheath_lv": sheath_lv, "sheath_peak": sheath_peak, "sheath_ins": Array(sheath_ins), "bless": bless, "found": found, "best": best, "runs": runs}


func from_dict(d: Dictionary) -> void:
	shards = int(d.get("shards", 0))
	sheath_id = int(d.get("sheath_id", -1))
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


func note_found(id: int) -> void:
	found[str(id)] = int(found.get(str(id), 0)) + 1


func has_found(id: int) -> bool:
	return found.has(str(id))


func bless_level(key: String) -> int:
	return int(bless.get(key, 0))


## 축복이 판에 주는 값.
func bless_value(md: MetaData, key: String) -> float:
	var i: int = md.bless_keys.find(key)
	return 0.0 if i < 0 else md.bless_step[i] * bless_level(key)


# ---------------------------------------------------------------- 검집

## 검집에 넣을 수 있는 검(뽑아 본 전설 이상), 높은 등급부터.
func sheath_candidates(game: GameData) -> Array[int]:
	var out: Array[int] = []
	for s in game.swords:
		if s.grade >= game.meta.sheath_min_grade and has_found(s.id):
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


func sheath_cost(md: MetaData) -> int:
	return md.sheath_cost * (sheath_lv + 1)


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

func bless_cost(md: MetaData, key: String) -> int:
	return md.bless_cost * (bless_level(key) + 1)


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
	}
	r["total"] = r.kills + r.zone + r.broken + r.elite + r.melt
	return r


func record_run(rules: Rules, md: MetaData) -> Dictionary:
	var r := run_shards(rules, md)
	shards += r.total
	best = maxi(best, rules.zone_count() + 1 if rules.won else rules.zone + 1)
	runs += 1
	return r
