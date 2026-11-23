class_name Heads
extends RefCounted
## 머리(2026-11-23, 40단계 "우두머리 잔영"을 대신한다): 갑옷 칸. 하나를 쓰면 받는 피해가 줄고 고유 효과가 하나 붙는다.
## 머리 셋 갈래:
##   - 우두머리 머리: 우두머리를 쓰러뜨릴 때마다 DROP 확률로(곳마다 여덟 + 들판 보스 + 무덤 주인).
##     id = "우두머리id|씨앗". 틀·효과는 우두머리가, 빛·장식·바탕(쇠·놋쇠·뼈)·색은 씨앗이 정해서 같은 우두머리 머리도 하나하나 다르다(사용자 2026-11-23: 내 머리는 없앤다)
##   - 남의 머리 "p:이름": 그 사람 이름을 씨앗으로 같은 방식. 다른 영주의 주인 있는 검을 뽑거나 결투에서 이기면 사본을 얻는다
## 효과 키: arrow(쏜 것) front(앞) low(체력 30% 아래) wraith(망령) maxhp(+20) heal(처치 회복) charge(돌진) save(한 번 버팀) steady(밀리지 않음)

const CHIEF: Dictionary = {
	"chief_tower": {"name": "망루 궁수장의 머리", "shape": &"tower", "cut": 0.10, "fx": &"arrow"},
	"chief_grove": {"name": "늑대왕의 머리", "shape": &"wolf", "cut": 0.10, "fx": &"heal"},
	"chief_foot": {"name": "발치 거인의 머리", "shape": &"boulder", "cut": 0.15, "fx": &"maxhp"},
	"chief_keep": {"name": "방패대장의 머리", "shape": &"shield", "cut": 0.12, "fx": &"front"},
	"chief_marsh": {"name": "늪의 부르는 자의 머리", "shape": &"marsh", "cut": 0.10, "fx": &"heal"},
	"chief_quarry": {"name": "채석장 감독의 머리", "shape": &"pick", "cut": 0.12, "fx": &"charge"},
	"chief_hamlet": {"name": "불탄 거인의 머리", "shape": &"burnt", "cut": 0.15, "fx": &"steady"},
	"chief_pass": {"name": "까마귀 기사의 머리", "shape": &"raven", "cut": 0.12, "fx": &"low"},
	"boss": {"name": "무덤 기사의 머리", "shape": &"grave_helm", "cut": 0.15, "fx": &"save"},
	"crypt": {"name": "무덤 주인의 머리", "shape": &"tomb", "cut": 0.18, "fx": &"wraith"},
}

## 씨앗 머리의 틀(내 머리·남의 머리).
## 우두머리를 쓰러뜨릴 때 머리가 떨어질 확률.
const DROP: float = 0.25
const FRAMES: Array[StringName] = [&"iron", &"brass", &"bone", &"rust"]

const SEED_SHAPES: Array[StringName] = [&"hill", &"helm", &"lantern", &"candle", &"shield", &"tomb", &"boulder", &"raven", &"pot", &"sword"]
const SEED_FX: Array[StringName] = [&"arrow", &"front", &"low", &"wraith", &"maxhp", &"heal", &"charge", &"steady"]

const FX_TEXT: Dictionary = {
	&"arrow": "쏜 것에 맞는 피해 -50%", &"front": "앞에서 오는 피해 -30%", &"low": "체력 30% 아래일 때 받는 피해 -25% 더",
	&"wraith": "망령에게 받는 피해 -40%", &"maxhp": "최대 체력 +20", &"heal": "적을 쓰러뜨리면 체력 2 회복",
	&"charge": "돌진에 맞는 피해 -40%", &"steady": "밀려나지 않는다", &"save": "판마다 한 번, 쓰러질 피해를 체력 1로 버틴다",
}


static func seed_of(text: String) -> int:
	return absi(hash(text))


## 머리 하나의 모든 것: {id, name, shape, cut, fx, tint, glow, horns, cracks, chain}
static func info(id: String, _meta: Meta = null) -> Dictionary:
	var base: String = id.get_slice("|", 0)
	var sd: String = id.get_slice("|", 1) if id.contains("|") else base
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_of(sd if CHIEF.has(base) else base.substr(2))
	var hue: float = rng.randf()
	var out := {
		"id": id,
		"shape": SEED_SHAPES[rng.randi_range(0, SEED_SHAPES.size() - 1)],
		"fx": SEED_FX[rng.randi_range(0, SEED_FX.size() - 1)],
		"cut": 0.06,
		"tint": Color.from_hsv(hue, rng.randf_range(0.1, 0.4), rng.randf_range(0.55, 0.95)),
		"glow": Color.from_hsv(fmod(hue + rng.randf_range(0.3, 0.7), 1.0), 0.8, 1.0),
		"frame": FRAMES[rng.randi_range(0, FRAMES.size() - 1)],
		"horns": rng.randf() < 0.35,
		"cracks": rng.randf() < 0.45,
		"chain": rng.randf() < 0.3,
	}
	if CHIEF.has(base):
		var c: Dictionary = CHIEF[base]
		out.name = c.name
		out.shape = c.shape
		out.cut = c.cut
		out.fx = c.fx
	else:
		out.name = base.substr(2) + "의 머리"
	return out


## 우두머리 머리 하나를 굴린다(떨어지지 않으면 ""). rng는 Meta.rng.
static func roll(chief: String, rng: RandomNumberGenerator) -> String:
	if not CHIEF.has(chief) or rng.randf() >= DROP:
		return ""
	return "%s|%08x" % [chief, rng.randi()]


static func describe(i: Dictionary) -> String:
	return "받는 피해 -%d%% · %s" % [roundi(float(i.cut) * 100.0), FX_TEXT.get(i.fx, "")]
