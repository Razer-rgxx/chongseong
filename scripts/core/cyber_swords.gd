class_name CyberSwords
extends RefCounted
## 사이버 검(docs/cyber_swords.md)의 이름표: 번호 범위, 종류, 능력 이름과 글. 규칙과 모양과 만들기 도구가 같이 읽는다.
## 사이버 카타나(311)도 사이버 검이다. 312~511은 (번호 - 312) % 6으로 종류가 정해진다.

const KATANA: int = 311
const FIRST: int = 312
const LAST: int = 511
const COUNT: int = 200

## 종류(순서가 곧 번호 % 6). 형태는 기존 4가지에 맞춘다: 단검, 장검(오니마루·환도), 대검(중장도·대검), 세검(카타나).
const SUBS: Array[String] = ["단검", "카타나", "오니마루", "환도", "중장도", "대검"]
const FORM_OF: Dictionary = {"단검": 0, "카타나": 3, "오니마루": 1, "환도": 1, "중장도": 2, "대검": 2}

## 사이버 능력 14가지(PowerTable.cyber에 수치, CyberPowers가 규칙).
const SHOTGUN: String = "산탄"
const PIERCE: String = "관통탄"
const HEAT: String = "과열"
const EMP: String = "EMP"
const HACK: String = "해킹"
const BLINK: String = "글리치 순간베기"
const PLASMA: String = "플라즈마 칼날"
const MAGAZINE: String = "탄창"
const RECOIL: String = "반동 돌진"
const RAIL: String = "레일"
const BURST: String = "연사"
const OVERCLOCK: String = "오버클럭"
const BARRIER: String = "방벽"
const AIM: String = "조준"

const POWERS: Array[String] = [SHOTGUN, PIERCE, HEAT, EMP, HACK, BLINK, PLASMA, MAGAZINE, RECOIL, RAIL, BURST, OVERCLOCK, BARRIER, AIM]

## 카드에 보이는 글.
const TEXT: Dictionary = {
	"산탄": "큰 베기 끝에 앞으로 산탄이 퍼진다(부채꼴, 멀수록 약하지 않다).",
	"관통탄": "큰 베기마다 적을 모두 꿰뚫는 탄이 곧게 날아간다.",
	"과열": "같은 적을 4번 맞히면 과열해 터진다(둘레에 피해와 불).",
	"EMP": "큰 베기가 전자기 파동을 낸다. 드론·기계는 기절하고 나머지는 느려진다.",
	"해킹": "4번 맞힐 때마다 그 적이 잠깐 아군이 되어 가까운 적을 친다.",
	"글리치 순간베기": "큰 베기에 가까운 적 뒤로 순간 이동해 벤다(재사용 대기 있음).",
	"플라즈마 칼날": "휘두르는 길에 플라즈마가 남아 닿은 적이 탄다.",
	"탄창": "4번 휘두를 때마다 탄이 한 발 나간다.",
	"반동 돌진": "큰 베기에 탄을 쏘고 반동으로 뒤로 밀려난다.",
	"레일": "큰 베기에 화면 가로지르는 긴 선을 맞힌다.",
	"연사": "작은 베기마다 약한 탄이 연달아 나간다.",
	"오버클럭": "쓰러뜨릴수록 공격이 빨라진다(잠시).",
	"방벽": "6명 쓰러뜨릴 때마다 방어막이 생긴다.",
	"조준": "체력이 거의 가득한 적에게 첫 타 피해가 크다.",
}


static func is_cyber(id: int) -> bool:
	return id == KATANA or (id >= FIRST and id <= LAST)


static func sub_of(id: int) -> String:
	if id == KATANA:
		return "카타나"
	if id < FIRST or id > LAST:
		return ""
	return SUBS[(id - FIRST) % SUBS.size()]


## 칼 한 자루에 붙은 능력의 글(줄바꿈으로 이은 것).
static func text_for(powers: PackedStringArray) -> String:
	var lines: Array[String] = []
	for p in powers:
		lines.append("%s: %s" % [p, TEXT.get(p, "")])
	return "\n".join(PackedStringArray(lines))


## 미래 구역의 꽂힌 낯선 검(docs/cyber_swords.md): 한 번 들를 때마다 이만큼 서고, 사이버 검만 나온다. 뽑으면 도감에 오르고(Meta.note_found) 마을 걸이·검집에서 쓴다.
const FUTURE_HILTS: int = 3
## 등급을 굴리는 운(언덕 첫 구역의 뽑기 운과 비슷하게). 뽑기 체력은 들지 않는다.
const FUTURE_LUCK: float = 4.0
## 대수확자를 쓰러뜨린 뒤(Meta.harvest_down)의 운(2026-11-26 미래 2막 보상).
const FUTURE_LUCK_FREED: float = 9.0


## 미래 구역에 설 사이버 검 번호 FUTURE_HILTS개(서로 다르다). rules.rng만 쓴다. luck을 안 주면 FUTURE_LUCK.
## 2026-11-26 밸런스: 들를 때마다 새로 서던 것을 언덕 판 하나 마칠 때마다 새로 서게 바꿨다(Meta.future_set, 드나들며 공짜로 도감 채우기 막음).
static func roll_future(rules: Rules, luck: float = FUTURE_LUCK) -> Array[int]:
	var out: Array[int] = []
	var tries: int = 0
	while out.size() < FUTURE_HILTS and tries < 100:
		tries += 1
		var g: int = rules.roll_grade(luck)
		var list: PackedInt32Array = rules.data.cyber_by_grade[g]
		if list.is_empty():
			continue
		var id: int = rules.data.swords[list[rules.rng.randi_range(0, list.size() - 1)]].id
		if not out.has(id):
			out.append(id)
	return out
