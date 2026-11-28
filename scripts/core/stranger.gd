class_name Stranger
extends RefCounted
## 총 든 낯선 사람(docs/stranger.md)의 규칙. 노드에 기대지 않고 난수는 넘겨 받은 Rules.rng만 쓴다.

const CHANCE: float = 0.3          ## 들판에 들어올 때·새벽·해질녘마다 나타날 확률
const CHANCE_FINAL: float = 0.6    ## 다섯 번째 만남 차례일 때
const NEED: int = 4                ## 이만큼 만났으면 다음 만남이 다섯 번째
const NEAR: float = 10.0           ## 영주가 이 안으로 오면 반응한다(칸)
const MIN_START: float = 24.0      ## 영주에게서 이만큼 먼 자리에만 선다(칸)
const SWORD: int = 311             ## 사이버 카타나(오픈월드 한정 검)
const SHOT_DAMAGE: float = 12.0
## 짧은 말. 만날 때마다 난수로 하나.
const LINES: Array[String] = ["...?", "......", "...여기가 아니군.", "...이 하늘이 아니야.", "...쇳소리뿐이군."]
const FINAL_LINE: String = "...찾았다. 이번엔 놓치지 않아."
const FOUND_LINE: String = "어딘가 다른 시간의 것이다…"
const OBJECT_PROMPT: String = "낯선 물건을 줍는다"

## 관리 명령용: 참이면 다음 굴림이 확률을 건너뛴다(field.gd가 읽고 끈다).
static var force: bool = false


static func is_final(seen: int, done: bool) -> bool:
	return not done and seen >= NEED


## 한 번 굴린다. 안 나타나면 빈 값, 나타나면 {spot, line, final}. 이미 마쳤거나 물건이 놓여 있거나 폭풍이면 나타나지 않는다.
## 굴림 수는 늘 같다(난수 한 번) 거기에 나타날 때만 두 번 더.
static func roll(rng: RandomNumberGenerator, seen: int, done: bool, drop: int, weather: StringName, lord_pos: Vector2, forced: bool = false) -> Dictionary:
	var r: float = rng.randf()
	if done or drop >= 0 or weather == &"storm":
		return {}
	var fin: bool = is_final(seen, done)
	if not forced and r >= (CHANCE_FINAL if fin else CHANCE):
		return {}
	var ok: Array[int] = []
	for i in FieldLayout.STRANGER_SPOTS.size():
		if FieldLayout.STRANGER_SPOTS[i].distance_to(lord_pos) >= MIN_START:
			ok.append(i)
	if ok.is_empty():
		return {}
	var spot: int = ok[rng.randi_range(0, ok.size() - 1)]
	var line: String = FINAL_LINE if fin else LINES[rng.randi_range(0, LINES.size() - 1)]
	return {"spot": spot, "line": line, "final": fin}


## 총에 맞아도 죽지 않는다: 체력 1은 남긴다.
static func shot_damage(hp: float) -> float:
	return clampf(hp - 1.0, 0.0, SHOT_DAMAGE)
