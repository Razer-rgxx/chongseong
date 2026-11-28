class_name Story
extends RefCounted
## 타임트래블러 이야기(docs/stranger.md 4단계)의 자리와 글. 미래 구역 안의 이야기는 띠(Band)·단말 글·낯선 사람 말로만 전한다.

const TIME_LOCK_COST: int = 60
const TIME_LOCK_AT: Vector2 = Vector2(23.0, 20.5)   ## 미래 구역: 시간 고정 단말
const VAULT_AT: Vector2 = Vector2(12.0, 57.0)      ## 봉인 금고 단말(남서쪽 가장자리)
const GUARDIAN_AT: Vector2 = Vector2(24.0, 54.0)
const GUARDIAN_ID: StringName = &"guardian"
const GUARDIAN_ZONE: int = 5
const FINAL_AT: Vector2 = Vector2(19.0, 55.5)      ## 마지막에 낯선 사람이 서는 자리
const ITEM_NAME: String = "타임트래블러"

## 자료 조각: {at, text}. 줍으면 글이 한 토막 뜬다.
const SHARDS: Array[Dictionary] = [
	{"at": Vector2(30.0, 40.5), "text": "[자료 1/3] 기록 7714. 추적 대상이 시간을 건넜다. 도착 좌표는 검이 꽂힌 언덕. 닻이 있었다."},
	{"at": Vector2(56.0, 32.0), "text": "[자료 2/3] 그 시대의 검은 시간에 박힌 못이다. 뽑힐 때마다 길이 헐거워진다. 문을 낸 쪽은 우리가 아니다."},
	{"at": Vector2(26.0, 16.0), "text": "[자료 3/3] 봉인 금고, 열쇠는 조각 셋. 안에 지키는 것이 있다. 이동 장치도 그 안에."},
]
const VAULT_SEALED: String = "봉인 단말. 자료 조각 %d/3. 열쇠가 모자라다."
const VAULT_OPEN: String = "조각 셋이 맞물린다. 봉인이 풀린다. 안에서 무언가 깨어난다."
const VAULT_DONE: String = "금고는 비었다."
const LOCK_ASK: String = "시간 고정 단말. 조각 %d개로 다음 언덕의 손잡이 하나를 조짐 3에 못 박는다."
const LOCK_DONE: String = "시간이 고정됐다. 다음 언덕, 첫 손잡이의 조짐은 3이다."
const LOCK_HELD: String = "이미 고정해 두었다. 다음 언덕에서 쓰인다."
const LOCK_POOR: String = "조각이 모자란다. (%d개 필요)"

## 금고지기를 쓰러뜨린 뒤 낯선 사람의 마지막 말.
const FINAL_LINES: Array[String] = [
	"...끝났군.",
	"내가 쫓던 건 이 시대의 것이 아니었어. 검 속에 숨어 있었다.",
	"닻이 많이 뽑히면 시간이 풀린다. 칼은 뽑되, 너무 많이는 뽑지 마라.",
	"뿌리는 더 오래전이다. 첫 검들이 벼려진 곳, 최초의 대장간. 길은 이미 열렸다.",
	"가져가. 두 시대를 오가는 장치다. 나는 더 깊이 들어간다.",
]
const GOT_LINE: String = "타임트래블러를 얻었다. T로 시대를 고른다. (과거: 최초의 대장간)"
