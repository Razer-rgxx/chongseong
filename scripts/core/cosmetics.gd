class_name Cosmetics
extends RefCounted
## 영주 꾸미기 규칙(docs/cosmetics.md). 노드에 기대지 않는 정적 함수. 랜덤이 없고 Rules는 건드리지 않는다.
## 표는 data/cosmetics.tres(CosmeticTable), 가진 것과 입은 것은 Meta.cos_owned·cos_worn(저장).
## 해금 조건은 이미 있는 Meta 값에서 읽는다: 리그 최고 티어, 우두머리, 이야기 막, 검의 기억 룬 자리.

static var _table: CosmeticTable = null


static func table() -> CosmeticTable:
	if _table == null:
		_table = load("res://data/cosmetics.tres") as CosmeticTable if ResourceLoader.exists("res://data/cosmetics.tres") else CosmeticTable.new()
	return _table


## 리그에서 이룬 가장 높은 티어(0~7). 배치를 마치기 전에는 지난 시즌 칭호만 센다. 한 번도 못 이뤘으면 -1.
static func league_tier(meta: Meta) -> int:
	var best: int = -1
	for k in meta.league_titles:
		best = maxi(best, League.tier_of(int(meta.league_titles[k])))
	if not League.placing(meta):
		best = maxi(best, League.tier_of(int(League.state(meta).peak)))
	return best


## 가장 많이 열린 룬 자리(검 하나 기준).
static func rune_slots_best(meta: Meta) -> int:
	var best: int = 0
	for k in meta.sword_log:
		best = maxi(best, meta.rune_slots(int(k)))
	return best


## 이 항목의 조건(조각으로 사는 것 말고)이 차 있나. free는 늘 참, shards는 사야 하니 거짓.
static func met(it: CosmeticItem, meta: Meta) -> bool:
	match String(it.unlock):
		"free":
			return true
		"league":
			return league_tier(meta) >= it.need
		"rune":
			return rune_slots_best(meta) >= it.need
		"boss":
			match String(it.key):
				"grave_knight": return meta.boss_first
				"crypt_lord": return meta.crypt_cleared.has("boss")
		"story":
			match String(it.key):
				"act1": return meta.time_traveller
				"act2": return meta.harvest_down
				"act3": return meta.anchor_hand
	return false


## 목록에 보일 항목인가. 이야기 항목은 틈이 열리기 전(Meta.rift_open)에는 이름도 안 보인다(길라잡이와 같은 규칙). 가진 것은 늘 보인다.
static func shown(it: CosmeticItem, meta: Meta) -> bool:
	if meta.cos_owned.has(String(it.id)):
		return true
	return it.unlock != &"story" or meta.rift_open()


## 잠긴 항목의 조건 한 줄.
static func condition_text(it: CosmeticItem) -> String:
	match String(it.unlock):
		"free":
			return "처음부터"
		"shards":
			return "조각 %d" % it.need
		"league":
			return "랭크 결투 %s 이상" % League.data().tier_names[clampi(it.need, 0, League.data().tier_names.size() - 1)]
		"rune":
			return "검 하나의 룬 자리 %d개 열기" % it.need
		"boss":
			return "무덤 기사를 쓰러뜨린다" if it.key == &"grave_knight" else "무덤 주인을 쓰러뜨린다"
		"story":
			match String(it.key):
				"act1": return "타임트래블러 이야기를 마친다"
				"act2": return "닻 공사를 마친다"
				"act3": return "첫 닻 이야기를 마친다"
	return ""


## 입은 베기 빛 색. 안 입었거나 검 본래의 빛이면 알파 0(쥔 검의 등급 색을 쓴다).
static func slash_color(worn: Dictionary) -> Color:
	var t: CosmeticTable = table()
	var it: CosmeticItem = t.item(StringName(worn.get("slash", t.default_of(&"slash"))))
	return it.color if it != null and it.slot == &"slash" else Color(0, 0, 0, 0)


## 상대가 보낸 것을 다듬는다(온라인 결투): 표에 있고 그 자리의 것인 항목만 남긴다. 모양이 틀리면 빈 사전.
static func clean(v: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (v is Dictionary):
		return out
	var t: CosmeticTable = table()
	for slot in CosmeticTable.SLOTS:
		var raw: Variant = (v as Dictionary).get(String(slot), (v as Dictionary).get(slot, ""))
		if raw is String or raw is StringName:
			var it: CosmeticItem = t.item(StringName(raw))
			if it != null and it.slot == slot:
				out[String(slot)] = String(it.id)
	return out
