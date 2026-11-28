class_name CosSecrets
extends RefCounted
## 꾸미기 비밀(docs/cosmetics.md): 세계 곳곳의 구체적인 행동으로만 열리는 꾸밀 것. 노드에 기대지 않는 정적 표와 함수.
## 한 줄 = 한 장면의 한 자리 + 때(날씨·밤낮) + 하는 일(touch: E로 만진다 / talk: 숨은 인물에게 말을 건다).
## 어디서도 조건 문구를 보이지 않는다: 자리는 때가 맞을 때만 서고(때가 틀리면 아무것도 없다), 띠는 하는 일 이름만 말한다.
## 찾으면 Meta.cos_secrets에 적히고(저장), 그 열쇠(key)를 가진 꾸미기 항목이 열린다(Cosmetics.met).

## scene: field·future·past·crypt. at: 칸 좌표(막힘 밖: tests/cosmetic_tests.gd). look: 모양(SecretProps).
## when: 들판 {weather: [..], night: 0 낮 / 1 밤 / -1 상관없음}, need: Meta의 값(boss_first). 비면 늘 선다.
## prompt: 띠(E 안내), name: talk일 때 말하는 이("???"), line: 말·알림(은근한 암시만).
const TABLE: Array[Dictionary] = [
	{"id": "well_rain", "scene": "field", "at": Vector2(192.0, 55.2), "kind": "touch", "look": "cairn",
		"when": {"weather": ["rain", "storm"]}, "prompt": "우물 속을 들여다본다",
		"line": "두레박줄 끝에 젖은 천 두 장이 걸려 올라왔다. 비가 오는 날에만 떠오르는 모양이다."},
	{"id": "marsh_hermit", "scene": "field", "at": Vector2(138.0, 88.0), "kind": "talk", "look": "figure",
		"when": {"weather": ["fog"]}, "name": "???", "prompt": "안개 속의 그림자에게 말을 건다",
		"line": "안개가 걷히면 나도 없소. 줄무늬 천은 늘 물가에서 마르지.\n(그림자가 낡은 천 한 필을 밀어 준다)"},
	{"id": "ash_ruin", "scene": "field", "at": Vector2(177.5, 47.6), "kind": "touch", "look": "cairn",
		"when": {"weather": ["ash"]}, "prompt": "식은 잿더미를 헤친다",
		"line": "재 속에서 아직 따뜻한 불씨 한 줌이 손에 남았다."},
	{"id": "quarry_storm", "scene": "field", "at": Vector2(175.5, 24.0), "kind": "touch", "look": "cairn",
		"when": {"weather": ["storm"]}, "prompt": "벼락 맞은 모루를 만진다",
		"line": "번개가 칠 때마다 쇠뿔 모양 그림자가 모루에 비친다. 손바닥이 찌릿하다."},
	{"id": "pass_night", "scene": "field", "at": Vector2(200.0, 95.0), "kind": "touch", "look": "cairn",
		"when": {"night": 1}, "prompt": "까마귀 둥지를 뒤진다",
		"line": "붉은 구슬들이 둥지에 가득하다. 어둠에 젖어 아직 마르지 않았다."},
	{"id": "keep_clear", "scene": "field", "at": Vector2(151.0, 22.6), "kind": "touch", "look": "cairn",
		"when": {"weather": ["clear"], "night": 0}, "prompt": "탑 그늘의 돌 밑을 본다",
		"line": "맑은 낮의 짧은 그림자 끝에서 넓은 챙의 쇠모자가 나왔다."},
	{"id": "knight_relic", "scene": "field", "at": Vector2(84.0, 98.4), "kind": "touch", "look": "cairn",
		"when": {"need": "boss_first"}, "prompt": "쓰러진 자리를 살핀다",
		"line": "기사가 서 있던 자리에 낡은 망토와 투구, 푸른 불씨가 남아 있다."},
	{"id": "neon_door", "scene": "future", "at": Vector2(41.5, 99.0), "kind": "talk", "look": "figure",
		"name": "???", "prompt": "문 앞의 그림자에게 말을 건다",
		"line": "이 문은 안 열려. 안에 아무도 없으니까. 대신 이걸 가져가.\n(그림자가 체크무늬 천과 투구를 내민다)"},
	{"id": "neon_billboard", "scene": "future", "at": Vector2(83.0, 76.0), "kind": "touch", "look": "cairn",
		"prompt": "꺼진 광고판 밑을 만진다",
		"line": "광고판 뒤에서 초록 불빛이 한 번 깜박이고 손에 스며들었다."},
	{"id": "rib_hollow", "scene": "past", "at": Vector2(118.0, 22.0), "kind": "touch", "look": "cairn",
		"prompt": "갈비뼈 사이 틈을 더듬는다",
		"line": "뼈 사이에 박혀 있던 천 조각을 뽑았다. 칼 모양의 문장이 수놓여 있다."},
	{"id": "crystal_echo", "scene": "past", "at": Vector2(157.4, 70.0), "kind": "touch", "look": "cairn",
		"prompt": "수정에 귀를 댄다",
		"line": "수정 안에서 쇠 부딪히는 소리가 난다. 손을 떼니 손바닥에 철관이 놓여 있다."},
]

## 관(돌 관) 비밀: 지하 무덤 r3의 관을 목숨이 간당할 때(체력 35% 이하) 연다. 자리가 따로 없다(crypt.gd가 관 열 때 부른다).
const CRYPT_ID: String = "crypt_low"
const CRYPT_COFFIN: StringName = &"r3"
const CRYPT_HP: float = 0.35
const CRYPT_LINE: String = "관 속 수의가 피 묻은 손에 감겨 올라온다. 뼈로 된 관과 하얀 빛도 함께였다."


static func find(id: String) -> Dictionary:
	for s in TABLE:
		if s.id == id:
			return s
	return {}


static func ids() -> Array[String]:
	var out: Array[String] = []
	for s in TABLE:
		out.append(String(s.id))
	out.append(CRYPT_ID)
	return out


static func known(id: String) -> bool:
	return ids().has(id)


## 이 장면의 비밀 자리들.
static func in_scene(scene: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in TABLE:
		if s.scene == scene:
			out.append(s)
	return out


## 지금 이 비밀이 서 있나(때가 맞고 아직 못 찾았다). ctx: {weather: String, night: bool}.
static func active(s: Dictionary, meta: Meta, ctx: Dictionary = {}) -> bool:
	if meta.cos_secrets.has(String(s.id)):
		return false
	var w: Dictionary = s.get("when", {})
	if w.has("weather") and not (w.weather as Array).has(String(ctx.get("weather", ""))):
		return false
	if w.has("night"):
		var want: int = int(w.night)
		if want >= 0 and (1 if bool(ctx.get("night", false)) else 0) != want:
			return false
	if w.has("need") and not bool(meta.get(String(w.need))):
		return false
	return true
