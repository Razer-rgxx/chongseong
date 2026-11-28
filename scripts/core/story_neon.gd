class_name StoryNeon
extends RefCounted
## 미래 2막 「닻 공사」(2026-11-26 사용자: "미래 스토리 구체화"). 네온 시가의 이야기 자리와 글.
## 흐름: 거리의 기록 단말 다섯(Meta.neon_logs) → 시장 광장 정보상 렌의 말이 바뀐다 → 1막(금고지기, 타임트래블러)을 마쳤으면
## 가운데 광장 정지 단말에서 대수확자(26_harvester)가 깬다 → 쓰러뜨리면 낯선 사람(7714)이 정체를 밝히고 과거(최초의 대장간)를 가리킨다.
## 보상: 조각 REWARD_SHARDS, 그 뒤 미래의 꽂힌 검이 더 좋아진다(CyberSwords.roll_future, Meta.harvest_down).
## 이야기는 띠(Band)·단말 글·말로만 전한다(세계에 글자 없음). 자리는 모두 네온 시가의 길·광장(막힘 밖, tests/neon_tests.gd).

const LOGS: Array[Dictionary] = [
	{"at": Vector2(83.0, 30.0), "text": "[기록 1/5 · 닻 공사 광고] 밤이 없는 도시. 꺼지지 않는 빛. 닻 공사는 지나간 시간에서 내일의 전력을 캡니다."},
	{"at": Vector2(128.0, 21.0), "text": "[기록 2/5 · 수확 보고 4471] 닻(옛 검) 하나를 뽑으면 그 자리에 고여 있던 시간이 흘러나온다. 회수한 칼은 다시 벼려 경비에게 지급. 사이버 날은 전부 옛 칼이었다."},
	{"at": Vector2(150.0, 88.0), "text": "[기록 3/5 · 내부 메모] 동쪽 외곽 녹 번짐 보고. 너무 많이 뽑힌 시대는 녹슨다. 그 블록은 포기한다. 외부에 알리지 말 것."},
	{"at": Vector2(61.0, 88.0), "text": "[기록 4/5 · 명령서] 사냥꾼 7714: 수확 구역을 벗어난 닻을 회수하라. ...추기: 7714 응답 없음. 이탈로 처리. 이동 장치 하나 분실."},
	{"at": Vector2(171.0, 41.0), "text": "[기록 5/5 · 설비 대장] 대수확자. 가운데 광장 홀로그램 아래. 정지 단말은 이동 장치의 서명만 받는다."},
]
const LOG_READ: String = "단말은 같은 기록을 다시 띄운다."

const FIXER_AT: Vector2 = Vector2(134.5, 70.5)    ## 시장 광장 모퉁이의 정보상 렌
const FIXER_NAME: String = "렌"
const STOP_AT: Vector2 = Vector2(117.0, 56.0)     ## 가운데 광장 정지 단말
const HARVESTER_AT: Vector2 = Vector2(117.0, 49.0)
const HARVESTER_ID: StringName = &"harvester"
const HARVESTER_ZONE: int = 8
const FINAL_AT: Vector2 = Vector2(113.0, 55.0)
const REWARD_SHARDS: int = 200

## 정보상 렌의 말: 단계(Meta.neon_step)마다.
static func fixer_line(logs: int, traveller: bool, down: bool) -> String:
	if down:
		return "불빛이 흔들리네. 고맙다고 해야 하나. 이제 이 도시는 제 시간으로 산다. ...미래의 꽂힌 검도 이젠 덜 녹슬었을 거야."
	if logs == 0:
		return "어서 와, 시간 밖 손님. 여긴 다들 빛을 사고판다. 그 빛이 어디서 오는지 궁금하면 거리의 기록 단말을 읽어 봐. 다섯 개다."
	if logs < LOGS.size():
		return "기록 %d/%d. 계속 읽어. 닻 공사가 감춘 게 다 거기 있다." % [logs, LOGS.size()]
	if not traveller:
		return "다 읽었군. 정지 단말은 가운데 광장 홀로그램 아래야. 그런데 이동 장치의 서명이 있어야 받아 준다. 폐허 쪽 봉인 금고에 하나 잠들어 있다던데."
	return "준비됐어? 가운데 광장 정지 단말을 건드리면 대수확자가 깬다. 그놈이 멈추면 이 도시의 빛도... 뭐, 원래 우리 것이 아니었지."

const STOP_LOGS: String = "정지 단말. 기록 %d/%d. 무엇을 멈추는지 모르고는 누를 수 없다."
const STOP_SIGN: String = "단말이 이동 장치의 서명을 찾는다. 없다."
const STOP_WAKE: String = "수확 정지 명령. 홀로그램이 꺼지고, 광장 아래에서 대수확자가 일어선다."
const STOP_DONE: String = "수확기는 멈췄다. 단말은 조용하다."
const STOP_BUSY: String = "대수확자가 아직 움직인다."

## 대수확자를 쓰러뜨린 뒤 낯선 사람(7714)의 말.
const FINAL_LINES: Array[String] = [
	"...또 만났군. 이번엔 내가 늦었다.",
	"나는 7714. 닻 공사의 사냥꾼이었다. 시대를 돌며 닻을 뽑아 왔지.",
	"그 빛이 다 누군가의 시간이었다는 걸 알고, 총구를 돌렸다.",
	"수확은 멈췄다. 하지만 닻을 처음 만든 손은 아직 과거에 있다.",
	"최초의 대장간. 첫 검을 벼린 자를 찾아라. 거기서 닻이 시작됐다.",
]
const GOT_LINE: String = "대수확자를 멈췄다. 조각 +%d · 이제 미래의 꽂힌 검이 더 좋은 등급으로 선다."
