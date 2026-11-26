class_name RuneTable
extends Resource
## 검의 기억 수치(docs/sword_memory.md): 룬 자리가 열리는 벤 적 수, 룬 8종, 보석 6종(단계 3), 보석 값, 이름 규칙.
## data/runes.tres 한 장. 값은 여기 기본값이고 .tres가 덮는다. 규칙(Meta)은 이 표만 읽는다.

## 룬 자리가 열리는 벤 적 수(그 검으로 벤 수, Meta.kills_of). 1번째 룬 100, 2번째 400, 3번째 1000.
@export var slot_kills: PackedInt32Array = PackedInt32Array([100, 400, 1000])
## 룬 키 → {name, counter(쓰임 세는 이름), stat(붙는 수치 이름), value, text}.
## 새 룬은 그 검의 쓰임(counter)이 가장 많은 것부터 하나씩 고른다(같으면 표 순서). 아무 쓰임도 없으면 표 순서.
@export var runes: Dictionary = {
	"keen": {"name": "예리의 룬", "counter": "big", "stat": "crit", "value": 0.04, "text": "치명타 확률 +4%"},
	"night": {"name": "밤의 룬", "counter": "night", "stat": "night", "value": 0.05, "text": "밤에 피해 +5%"},
	"day": {"name": "낮의 룬", "counter": "day", "stat": "tough", "value": 0.06, "text": "내구 +6%"},
	"hunt": {"name": "사냥의 룬", "counter": "boss", "stat": "boss", "value": 0.08, "text": "우두머리에게 피해 +8%"},
	"wind": {"name": "바람의 룬", "counter": "dash", "stat": "speed", "value": 0.04, "text": "휘두르는 속도 +4%"},
	"grit": {"name": "불굴의 룬", "counter": "hurt", "stat": "guard", "value": 0.04, "text": "받는 피해 -4%"},
	"chain": {"name": "연쇄의 룬", "counter": "chain", "stat": "shard", "value": 0.05, "text": "벨 때마다 조각 +0.05"},
	"elite": {"name": "정예의 룬", "counter": "elite", "stat": "knock", "value": 0.08, "text": "밀어내기 +8%"},
}
## 룬 키 차례(표 순서를 고정한다).
@export var rune_order: PackedStringArray = PackedStringArray(["keen", "night", "day", "hunt", "wind", "grit", "chain", "elite"])
## 룬 개수 → 보석 자리 수(룬이 하나 이상이면 1, 둘 이상이면 2).
@export var sockets: PackedInt32Array = PackedInt32Array([0, 1, 2, 2])
## 보석 키 → {name, stat, values(단계 1~3), color, text}.
@export var gems: Dictionary = {
	"ruby": {"name": "홍옥", "stat": "dmg", "values": [0.03, 0.06, 0.10], "color": Color(0.9, 0.12, 0.2), "text": "피해"},
	"amethyst": {"name": "자수정", "stat": "tough", "values": [0.08, 0.16, 0.30], "color": Color(0.62, 0.3, 0.92), "text": "내구"},
	"lapis": {"name": "청금석", "stat": "crit", "values": [0.03, 0.06, 0.10], "color": Color(0.2, 0.35, 0.95), "text": "치명타 확률"},
	"amber": {"name": "호박", "stat": "shard", "values": [0.05, 0.10, 0.20], "color": Color(1.0, 0.62, 0.1), "text": "벨 때마다 조각"},
	"obsidian": {"name": "흑요석", "stat": "knock", "values": [0.10, 0.20, 0.35], "color": Color(0.38, 0.16, 0.5), "text": "밀어내기"},
	"moonstone": {"name": "월장석", "stat": "power", "values": [0.05, 0.10, 0.18], "color": Color(0.7, 0.85, 1.0), "text": "각인 세기"},
}
@export var gem_order: PackedStringArray = PackedStringArray(["ruby", "amethyst", "lapis", "amber", "obsidian", "moonstone"])
@export var tier_names: PackedStringArray = PackedStringArray(["거친", "고운", "흠 없는"])
## 보석을 상점처럼 조각으로 사는 값(단계 1~3).
@export var buy_cost: PackedInt32Array = PackedInt32Array([60, 180, 500])
## 보석을 빼는 값(조각, 단계 1~3). 보석은 사라지지 않고 주머니로 돌아온다.
@export var remove_fee: PackedInt32Array = PackedInt32Array([10, 30, 80])
## 드롭: 보스(들판 보스·우두머리·무덤 주인·대수확자·흑룡), 상자(무덤 관·미래 함·과거 함·유품 상자).
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


func stat_of_rune(key: String) -> String:
	return String((runes.get(key, {}) as Dictionary).get("stat", ""))


func rune_name(key: String) -> String:
	return String((runes.get(key, {}) as Dictionary).get("name", key))


func gem_name(key: String) -> String:
	## key는 "종류:단계"(예: "ruby:2")
	var p: PackedStringArray = key.split(":")
	var g: Dictionary = gems.get(p[0], {})
	var t: int = clampi(int(p[1]) if p.size() > 1 else 1, 1, 3)
	return "%s %s" % [tier_names[t - 1], String(g.get("name", p[0]))]


func gem_value(key: String) -> float:
	var p: PackedStringArray = key.split(":")
	var g: Dictionary = gems.get(p[0], {})
	var t: int = clampi(int(p[1]) if p.size() > 1 else 1, 1, 3)
	return float((g.get("values", [0.0, 0.0, 0.0]) as Array)[t - 1])


func gem_stat(key: String) -> String:
	return String((gems.get(key.split(":")[0], {}) as Dictionary).get("stat", ""))


func gem_color(key: String) -> Color:
	return (gems.get(key.split(":")[0], {}) as Dictionary).get("color", Color.WHITE)


func valid_gem(key: String) -> bool:
	var p: PackedStringArray = key.split(":")
	return p.size() == 2 and gems.has(p[0]) and p[1].is_valid_int() and int(p[1]) >= 1 and int(p[1]) <= 3
