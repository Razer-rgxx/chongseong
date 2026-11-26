class_name RuneTable
extends Resource
## 검의 기억 수치(docs/sword_memory.md): 룬 자리가 열리는 벤 적 수, 룬 8종(단계 3), 룬 값, 이름 규칙. 보석은 없다(2026-11-26 룬 박기로 바뀜).
## data/runes.tres 한 장. 값은 여기 기본값이고 .tres가 덮는다. 규칙(Meta)은 이 표만 읽는다.

## 룬 자리가 열리는 벤 적 수(그 검으로 벤 수, Meta.kills_of). 1번째 룬 100, 2번째 400, 3번째 1000.
@export var slot_kills: PackedInt32Array = PackedInt32Array([100, 400, 1000])
## 룬 키 → {name, counter(쓰임 세는 이름), stat(붙는 수치 이름), value, text}.
## 새 룬은 그 검의 쓰임(counter)이 가장 많은 것부터 하나씩 고른다(같으면 표 순서). 아무 쓰임도 없으면 표 순서.
@export var runes: Dictionary = {
	"keen": {"name": "예리의 룬", "counter": "big", "stat": "crit", "value": 0.04, "text": "치명타 확률 +%s"},
	"night": {"name": "밤의 룬", "counter": "night", "stat": "night", "value": 0.05, "text": "밤에 피해 +%s"},
	"day": {"name": "낮의 룬", "counter": "day", "stat": "tough", "value": 0.06, "text": "내구 +%s"},
	"hunt": {"name": "사냥의 룬", "counter": "boss", "stat": "boss", "value": 0.08, "text": "우두머리에게 피해 +%s"},
	"wind": {"name": "바람의 룬", "counter": "dash", "stat": "speed", "value": 0.04, "text": "휘두르는 속도 +%s"},
	"grit": {"name": "불굴의 룬", "counter": "hurt", "stat": "guard", "value": 0.04, "text": "받는 피해 -%s"},
	"chain": {"name": "연쇄의 룬", "counter": "chain", "stat": "shard", "value": 0.05, "text": "벨 때마다 조각 +%s"},
	"elite": {"name": "정예의 룬", "counter": "elite", "stat": "knock", "value": 0.08, "text": "밀어내기 +%s"},
}
## 룬 키 차례(표 순서를 고정한다).
@export var rune_order: PackedStringArray = PackedStringArray(["keen", "night", "day", "hunt", "wind", "grit", "chain", "elite"])
## 룬 단계 배수(1~3단계). 단계 n의 값 = 룬의 value × tier_mult[n-1]. 룬의 value가 1단계 값이다.
@export var tier_mult: PackedFloat32Array = PackedFloat32Array([1.0, 2.0, 3.0])
@export var tier_names: PackedStringArray = PackedStringArray(["거친", "고운", "또렷한"])
## 룬을 대장간에서 조각으로 사는 값(단계 1~3).
@export var buy_cost: PackedInt32Array = PackedInt32Array([60, 180, 500])
## 룬을 빼는 값(조각, 단계 1~3). 룬은 사라지지 않고 주머니로 돌아온다.
@export var remove_fee: PackedInt32Array = PackedInt32Array([10, 30, 80])
## 옛 보석을 조각으로 바꿀 때도 buy_cost를 쓴다. 드롭: 보스(들판 보스·우두머리·무덤 주인·대수확자·흑룡), 상자(무덤 관·미래 함·과거 함·유품 상자).
@export var drop_boss: float = 0.35
@export var drop_cache: float = 0.12
## 드롭 단계 가중치(1, 2, 3). 보스는 높은 단계가 더 나온다.
@export var tier_weights_cache: PackedFloat32Array = PackedFloat32Array([0.7, 0.27, 0.03])
@export var tier_weights_boss: PackedFloat32Array = PackedFloat32Array([0.5, 0.38, 0.12])
## 치명타 때 피해 배수.
@export var crit_mult: float = 1.5
## 이름: 최대 글자 수와 이름을 지을 수 있는 룬 수(무한 등급은 룬 없이도).
@export var name_max: int = 12
@export var name_runes: int = 3


## 룬 키는 "종류:단계"(예: "keen:2"). 옛 저장의 "keen"은 1단계로 읽는다(norm).
func norm(key: String) -> String:
	var p: PackedStringArray = key.split(":")
	if p.size() == 1 and runes.has(p[0]):
		return p[0] + ":1"
	return key


func valid_rune(key: String) -> bool:
	var p: PackedStringArray = key.split(":")
	return p.size() == 2 and runes.has(p[0]) and p[1].is_valid_int() and int(p[1]) >= 1 and int(p[1]) <= tier_mult.size()


func tier_of(key: String) -> int:
	var p: PackedStringArray = key.split(":")
	return clampi(int(p[1]) if p.size() > 1 else 1, 1, tier_mult.size())


func type_of(key: String) -> String:
	return key.split(":")[0]


func stat_of_rune(key: String) -> String:
	return String((runes.get(type_of(key), {}) as Dictionary).get("stat", ""))


## 이름: "룬 종류" + 단계("거친 예리의 룬").
func rune_name(key: String) -> String:
	var nm: String = String((runes.get(type_of(key), {}) as Dictionary).get("name", type_of(key)))
	if key.find(":") < 0:
		return nm
	return "%s %s" % [tier_names[tier_of(key) - 1], nm]


func rune_value(key: String) -> float:
	return float((runes.get(type_of(key), {}) as Dictionary).get("value", 0.0)) * tier_mult[tier_of(key) - 1]


## 효과 글(예: "치명타 확률 +8%"). 조각 값(chain)은 소수로.
func rune_text(key: String) -> String:
	var r: Dictionary = runes.get(type_of(key), {})
	var v: float = rune_value(key)
	var num: String = ("%.2f" % v) if String(r.get("stat", "")) == "shard" else ("%d%%" % roundi(v * 100.0))
	return String(r.get("text", "%s")) % num


## 칼에 그리는 무늬 번호(0~3): 종류 차례 % 4.
func glyph_of(key: String) -> int:
	return maxi(0, rune_order.find(type_of(key))) % 4
