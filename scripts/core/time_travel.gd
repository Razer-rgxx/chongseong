class_name TimeTravel
extends RefCounted
## 시대 이동(docs/stranger.md 4단계)의 규칙: 싸움 중에는 못 간다. 노드에 기대지 않는다.

const COMBAT_RANGE: float = 14.0   ## 이 안에 살아 있는 적이 있으면 싸움 중(칸)
const ERA_NOW: StringName = &"now"
const ERA_FUTURE: StringName = &"future"
const ERA_PAST: StringName = &"past"
const NAMES: Dictionary = {&"now": "현재", &"future": "미래", &"past": "과거"}


## 싸움 중인가: 깨어난 보스, 덤비는 무리, 가까운 살아 있는 적(허수아비 빼고)이 있으면 참.
static func in_combat(r: Rules) -> bool:
	if r == null:
		return false
	if r.field_boss != null and r.field_boss_state == Rules.BOSS_AWAKE and not r.field_boss.dead:
		return true
	for e in r.enemies:
		if e.dead or e.data.still:
			continue
		if e.pack != &"" and r.packs.has(e.pack) and int(r.packs[e.pack].state) == Rules.PACK_ENGAGED:
			return true
		if e.pos.distance_to(r.lord.pos) <= COMBAT_RANGE:
			return true
	return false


## 이동 창이 열리는가: 타임트래블러가 있어야 한다.
static func why_not(m: Meta, r: Rules) -> String:
	if not m.time_traveller:
		return ""
	if in_combat(r):
		return "싸움 중에는 시간이 열리지 않는다."
	return "ok"
