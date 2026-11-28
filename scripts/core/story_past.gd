class_name StoryPast
extends RefCounted
## 과거 3막 「첫 닻」(2026-11-26 사용자: "과거 판타지 월드도", "용의 세계도 있고 닻의 선장 같은 것도"). 넓힌 과거의 이야기 자리와 글.
## 이야기: 흑룡이 하늘을 물어뜯어 낮과 밤을 삼키던 때, 첫 대장장이 벼리가 별쇠로 칼을 벼리고 하늘배 「첫 닻호」의 선장이
## 그 칼을 닻으로 내려 시간 위에 박았다(그 뒤로 「닻의 선장」). 흑룡은 용의 산맥 꼭대기 아홉 돌 고리 아래 묶였고, 닻이 뽑힐수록 사슬이 느슨해진다(미래의 수확).
## 흐름: 기억의 돌 넷(Meta.past_memories) → 첫 대장간 곁 벼리(혼)의 말 → 미래 2막(대수확자)을 마쳤으면 호숫가 선착장의 닻의 선장이
## 맹세를 받는다(Meta.captain_oath) → 용의 산맥 봉인 제단에서 시간을 먹는 흑룡(27_devourer)이 깬다 → 쓰러뜨리면 벼리·닻의 선장의 마지막 말과
## 흑룡이 쓰러지면 선장이 봉인의 첫 닻이 되어 떠난다(Meta.captain_gone, 2026-11-26 사용자 요청). 축복 「선장이 남긴 손」(Meta.anchor_hand: 언덕 판마다 처음 부러질 검을 한 번 붙잡는다, Rules._break)과 조각 REWARD_SHARDS.
## 이야기는 띠·말로만(세계에 글자 없음).

const MEMORIES: Array[Dictionary] = [
	{"at": Vector2(140.0, 40.0), "text": "[기억 1/4 · 거인의 뼈 들] 흑룡이 하늘을 물어뜯어 낮과 밤을 삼켰다. 거인이 맞섰고, 거인은 여기 누웠다. 그 갈비뼈 사이로 아직 바람이 운다."},
	{"at": Vector2(166.0, 78.0), "text": "[기억 2/4 · 수정 호수] 첫 대장장이는 별에서 떨어진 쇠로 칼을 벼렸다. 하늘배 「첫 닻호」가 그 칼을 닻으로 내려 시간 위에 박았다. 그날부터 시간이 흩어지지 않았다."},
	{"at": Vector2(20.0, 80.0), "text": "[기억 3/4 · 잿불 능선] 흑룡의 불이 떨어진 자리. 땅은 아직 식지 않았다. 닻이 하나 뽑힐 때마다 금이 다시 붉어진다."},
	{"at": Vector2(204.0, 58.0), "text": "[기억 4/4 · 용의 산맥] 흑룡은 산맥 꼭대기, 아홉 돌 고리 아래 묶였다. 그 자식들이 둥지를 지키며 사슬이 끊어질 날을 기다린다."},
]

const SMITH_AT: Vector2 = Vector2(45.0, 31.0)   ## 첫 대장간 제단 곁, 첫 대장장이의 혼
const SMITH_NAME: String = "벼리"
const CAPTAIN_AT: Vector2 = PastLayout.CAPTAIN_AT   ## 호숫가 선착장, 하늘배 「첫 닻호」의 선장
const CAPTAIN_NAME: String = "닻의 선장"
const SEAL_AT: Vector2 = PastLayout.SEAL_AT     ## 봉인 제단(용의 산맥 꼭대기, 고리 한가운데)
const BEAST_AT: Vector2 = Vector2(232.0, 43.0)
const BEAST_ID: StringName = &"devourer"
const BEAST_ZONE: int = 8
const REWARD_SHARDS: int = 150
## 닻의 손: 부러질 검을 붙잡을 때 남기는 내구 몫.
const ANCHOR_KEEP: float = 0.3


static func smith_line(memories: int, harvest_down: bool, oath: bool, done: bool) -> String:
	if done:
		return "선장이 닻이 되었다. 박는 손은 그가 했고, 뽑는 손은 네가 한다. 그가 남긴 손이 네 칼을 한 번은 붙잡아 줄 게다."
	if memories == 0:
		return "...시간 밖에서 온 손님이군. 이 칼들이 왜 땅에 꽂혀 있는지 아는가? 들에 남은 기억의 돌 넷을 읽어 보게. 뼈의 들, 수정 호수, 잿불 능선, 그리고 용의 산맥."
	if memories < MEMORIES.size():
		return "기억 %d/%d. 다 읽거든 호숫가의 선장을 찾아가게. 내 칼을 하늘에서 내린 사람이다." % [memories, MEMORIES.size()]
	if not harvest_down:
		return "먼 뒤의 사람들이 닻을 캐어 빛을 만든다지. 그 손부터 멈추게. 사슬을 당기는 손이 남아 있으면 흑룡을 다시 묶을 수 없다."
	if not oath:
		return "닻의 선장에게 가게. 첫 닻호의 맹세 없이는 고리에 손을 얹을 수 없다."
	return "흑룡이 깨어나려 한다. 용의 산맥 꼭대기, 아홉 돌 고리로 가게. 내가 벼린 칼이 아니라, 네 칼로 끝내야 한다."


## 닻의 선장의 말. 맹세를 받을 차례면(기억 넷 + 미래 2막, 아직 맹세 전) OATH_LINE을 부른 쪽이 고른다(Meta.swear_oath).
static func captain_line(memories: int, harvest_down: bool, oath: bool, done: bool) -> String:
	if done:
		return "닻이 다시 단단히 물렸다. 첫 닻호는 이 하늘에 남는다. 언젠가 네 시대의 하늘에서 돛을 보거든, 나인 줄 알아라."
	if memories < MEMORIES.size():
		return "첫 닻호의 선장이다. 다들 닻의 선장이라 부르지. 저 사슬 끝의 칼이 보이나? 벼리가 벼리고 내가 내렸다. 이 시대를 붙잡아 두는 닻이야. 기억의 돌을 다 읽고 오게. (기억 %d/%d)" % [memories, MEMORIES.size()]
	if not harvest_down:
		return "사슬이 떨린다. 먼 뒤에서 누가 닻을 뽑고 있어. 그 손부터 멈춰야 흑룡과 싸울 수 있다."
	if oath:
		return "산맥 꼭대기다. 흑룡의 불은 피하고, 날개를 칠 때 파고들어라. 내 배가 위에서 지켜보마."
	return OATH_LINE

const OATH_LINE: String = "좋다. 첫 닻호의 이름으로 맹세를 받지. 용의 산맥 꼭대기, 아홉 돌 고리에 흑룡이 묶여 있다. 고리 가운데 제단에 손을 얹으면 깨어난다."
const OATH_GOT: String = "첫 닻호의 맹세를 받았다. 용의 산맥 꼭대기로."

const SEAL_LOOSE: String = "아홉 돌 고리. 돌에 새긴 사슬이 느슨하다. (기억 %d/%d)"
const SEAL_PULLED: String = "먼 뒤에서 누군가 사슬을 당기고 있다. 지금 깨우면 다시 묶을 수 없다. (미래의 수확을 먼저 멈춘다)"
const SEAL_OATH: String = "고리가 손을 밀어낸다. 첫 닻호의 맹세가 있어야 한다. (호숫가의 선장)"
const SEAL_WAKE: String = "고리 가운데 땅이 갈라진다. 사슬을 끊고 시간을 먹는 흑룡이 일어선다."
const SEAL_DONE: String = "고리는 조용하다."
const SEAL_BUSY: String = "흑룡이 아직 움직인다."
const HOARD_GOT: String = "용의 보물 더미에서 조각 %d개를 얻었다"

## 선장의 마지막 말(흑룡을 쓰러뜨린 뒤 봉인 제단에서, 띠로 차례로): [누가, 말]. 막을 수 없다.
const FINAL_LINES: Array = [
	["닻의 선장", "...끝났군. 그런데 사슬이 아직 헐겁다."],
	["닻의 선장", "닻 없이는 봉인이 버티지 못한다. 내가 첫 닻이 되겠다고 맹세했다."],
	["닻의 선장", "배는 두고 간다. 닻은 여기 남는다."],
	["닻의 선장", "언덕에 전해라. 검을 놓지 말라고."],
]
## 선장이 떠난 뒤(Meta.captain_gone)의 한 줄씩.
const COAT_LINE: String = "선착장 말뚝에 남색 외투가 걸려 있다. 소매에 아직 바닷바람이 배어 있다."
const ANCHOR_PLANTED_LINE: String = "봉인 제단에 박힌 닻. 손을 얹자 차갑고, 속이 금빛으로 고요하다."
const SHIP_EMPTY_PROMPT: String = "선착장 말뚝의 외투를 본다"
const ANCHOR_PROMPT: String = "박힌 닻을 만진다"
const SEAL_ANCHOR_AT: Vector2 = Vector2(2.2, 0.0)   ## 박힌 닻 자리(봉인 제단 한가운데에서 칸 단위로 비낀 곳)
const COAT_AT: Vector2 = PastLayout.CAPTAIN_AT      ## 외투 말뚝(선장이 서 있던 자리)
const CAPTAIN_WALK_FROM: Vector2 = Vector2(-9.0, 0.0)   ## 선장이 걸어 들어오는 시작(제단에서 칸 단위)
const CAPTAIN_STAND: Vector2 = Vector2(1.2, 0.0)   ## 말하는 자리(닻 곁)
const GOT_LINE: String = "첫 닻의 축복 「선장이 남긴 손」: 언덕 판마다 처음 부러질 검을 한 번 붙잡는다. 조각 +%d"
const ANCHOR_SAVED: String = "선장이 남긴 손이 부러지려던 칼을 붙잡았다."
