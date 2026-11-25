class_name StoryPast
extends RefCounted
## 과거 3막 「첫 닻」(2026-11-26 사용자: "과거 판타지 월드도"). 넓힌 과거(거인의 뼈 들·수정 호수·잿불 능선)의 이야기 자리와 글.
## 흐름: 기억의 돌 셋(Meta.past_memories) → 첫 대장간 곁의 첫 대장장이 벼리(혼)의 말이 바뀐다 → 미래 2막(대수확자)을 마쳤으면
## 잿불 능선 아홉 돌 고리의 봉인 제단에서 시간을 먹는 짐승의 남은 몸(27_devourer)이 깬다 → 쓰러뜨리면 벼리의 마지막 말과
## 축복 「닻의 손」(Meta.anchor_hand: 언덕 판마다 처음 부러질 검을 한 번 붙잡는다, Rules._break)과 조각 REWARD_SHARDS.
## 이야기는 띠·말로만(세계에 글자 없음).

const MEMORIES: Array[Dictionary] = [
	{"at": Vector2(140.0, 40.0), "text": "[기억 1/3 · 거인의 뼈 들] 하늘을 먹는 짐승이 낮과 밤을 삼켰다. 거인이 맞섰고, 거인은 여기 누웠다. 그 갈비뼈 사이로 아직 바람이 운다."},
	{"at": Vector2(166.0, 78.0), "text": "[기억 2/3 · 수정 호수] 첫 대장장이는 별에서 떨어진 쇠로 칼을 벼려 시간 위에 꽂았다. 칼이 꽂힌 곳마다 시간이 흩어지지 않았다. 사람들은 그것을 닻이라 불렀다."},
	{"at": Vector2(20.0, 80.0), "text": "[기억 3/3 · 잿불 능선] 짐승은 죽지 않았다. 아홉 돌 고리 아래 묶였을 뿐. 닻이 뽑힐수록 사슬이 느슨해진다."},
]

const SMITH_AT: Vector2 = Vector2(45.0, 31.0)   ## 첫 대장간 제단 곁, 첫 대장장이의 혼
const SMITH_NAME: String = "벼리"
const SEAL_AT: Vector2 = PastLayout.SEAL_AT     ## 봉인 제단(고리 한가운데)
const BEAST_AT: Vector2 = Vector2(38.0, 85.0)
const BEAST_ID: StringName = &"devourer"
const BEAST_ZONE: int = 8
const REWARD_SHARDS: int = 150
## 닻의 손: 부러질 검을 붙잡을 때 남기는 내구 몫.
const ANCHOR_KEEP: float = 0.3


static func smith_line(memories: int, harvest_down: bool, done: bool) -> String:
	if done:
		return "닻은 뽑는 손과 박는 손이 같아야 하지. 이제 너는 둘 다다. 네 칼이 처음 부러지려 할 때, 한 번은 내가 붙잡아 주마."
	if memories == 0:
		return "...시간 밖에서 온 손님이군. 이 칼들이 왜 땅에 꽂혀 있는지 아는가? 들에 남은 기억의 돌 셋을 읽어 보게. 뼈의 들, 수정 호수, 잿불 능선."
	if memories < MEMORIES.size():
		return "기억 %d/%d. 셋을 다 읽으면 말해 주지." % [memories, MEMORIES.size()]
	if not harvest_down:
		return "먼 뒤의 사람들이 닻을 캐어 빛을 만든다지. 그 손부터 멈추게. 사슬을 당기는 손이 남아 있으면 내가 묶어도 소용없다."
	return "봉인이 풀리고 있다. 잿불 능선의 아홉 돌 고리로 가게. 짐승의 남은 몸이 깨어나려 한다. 내가 벼린 칼이 아니라, 네 칼로 끝내야 한다."

const SEAL_LOOSE: String = "아홉 돌 고리. 돌에 새긴 사슬이 느슨하다. (기억 %d/%d)"
const SEAL_PULLED: String = "먼 뒤에서 누군가 사슬을 당기고 있다. 지금 깨우면 다시 묶을 수 없다. (미래의 수확을 먼저 멈춘다)"
const SEAL_WAKE: String = "고리 가운데 땅이 갈라진다. 시간을 먹는 짐승의 남은 몸이 일어선다."
const SEAL_DONE: String = "고리는 조용하다."
const SEAL_BUSY: String = "짐승이 아직 움직인다."

const FINAL_LINES: Array[String] = [
	"...끝났군. 짐승은 다시 잠들었다.",
	"나는 첫 칼을 벼렸고, 그 칼을 시간에 박았다. 그게 시작이었다.",
	"먼 뒤의 사람들은 그 칼을 뽑아 빛을 캤지. 칼은 원래 사슬이었다.",
	"언덕으로 돌아가라. 칼을 뽑되, 무엇을 묶고 있었는지 잊지 말게.",
]
const GOT_LINE: String = "첫 대장장이의 축복 「닻의 손」: 언덕 판마다 처음 부러질 검을 한 번 붙잡는다. 조각 +%d"
const ANCHOR_SAVED: String = "닻의 손이 부러지려던 칼을 붙잡았다."
