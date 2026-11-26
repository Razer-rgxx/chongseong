class_name Guide
extends RefCounted
## 길라잡이(2026-11-26, docs/guide.md): 새 영주에게 "다음에 무엇을 할지"를 늘 알려 주는 단계 표.
## 노드에 기대지 않는다. 단계 표(STEPS)와 끝났는지 보는 법, 보상 지급만 맡고 규칙은 새로 만들지 않는다.
## 끝났는지는 Meta의 상태나, 장면이 세어 둔 일(Meta.guide_note)로 본다. 화면은 GuideHud.
## 단계는 순서대로 안내하지만 끝나는 것은 순서와 무관하다(먼저 해낸 것은 조건이 차는 때 바로 끝난다).

const CHAPTERS: Array[String] = ["마을", "언덕", "들판", "이야기"]

## id, ch(장), title, goal, need(세는 수), reward{shards, mats}, hint{장면: 자리}, hidden(틈이 열리기 전에는 목록에 아예 넣지 않는다: 이름도 ???도 보이지 않는다).
## 세는 법은 count()의 match. hint 자리 이름은 장면이 풀어 준다(lobby.guide_spot, field.guide_spot, GuideHud의 hill).
const STEPS: Array[Dictionary] = [
	{"id": "talk_gate", "ch": 0, "title": "문지기와 이야기하기", "goal": "마을 문 곁의 문지기에게 가서 E로 말을 건다", "need": 1, "reward": {"shards": 5}, "hint": {"lobby": "v_gatekeeper"}},
	{"id": "rack", "ch": 0, "title": "검 진열대 보기", "goal": "진열대에서 E를 눌러 도감을 본다", "need": 1, "reward": {"shards": 5}, "hint": {"lobby": "rack"}},
	{"id": "hill_gate", "ch": 1, "title": "언덕 길에서 판 시작", "goal": "북문 밖 들판 끝의 언덕 길에서 E를 눌러 오른다", "need": 1, "reward": {"shards": 5}, "hint": {"lobby": "gate", "field": "trail"}},
	{"id": "first_pull", "ch": 1, "title": "첫 검 뽑기", "goal": "땅에 꽂힌 손잡이에 다가가 E를 누르고 있어 검을 뽑는다", "need": 1, "reward": {"shards": 5}, "hint": {"hill": "hilt"}},
	{"id": "good_pull", "ch": 1, "title": "박자 맞춰 뽑기", "goal": "뽑는 동안 버팀마다 박자에 맞게 E나 클릭을 한 번 더 누른다", "need": 1, "reward": {"shards": 5}, "hint": {"hill": "hilt"}},
	{"id": "first_night", "ch": 1, "title": "첫 밤 넘기기", "goal": "N으로 밤을 부르고 쓰러지지 않고 새벽을 맞는다", "need": 1, "reward": {"shards": 10}},
	{"id": "path", "ch": 1, "title": "새벽 갈림길 고르기", "goal": "새벽에 지도 창에서 다음 길 하나를 고른다", "need": 1, "reward": {"shards": 5}},
	{"id": "day_event", "ch": 1, "title": "낮 사건 쓰기", "goal": "2구역부터 서는 낮 사건 곁에서 E를 한 번 쓴다", "need": 1, "reward": {"shards": 5}, "hint": {"hill": "event"}},
	{"id": "finish_run", "ch": 1, "title": "판 마치고 조각 보기", "goal": "판을 끝까지 가거나 쓰러져서 끝 화면의 조각을 본다", "need": 1, "reward": {"shards": 10}},
	{"id": "spend", "ch": 0, "title": "조각 쓰기", "goal": "대장간이나 성소에서 조각을 내고 강화를 한 번 해 본다", "need": 1, "reward": {"shards": 5}, "hint": {"lobby": "forge"}},
	{"id": "quest", "ch": 0, "title": "의뢰 맡기", "goal": "의뢰판에서 의뢰 하나를 맡는다", "need": 1, "reward": {"shards": 5}, "hint": {"lobby": "board"}},
	{"id": "yard", "ch": 0, "title": "수련장에서 검 시험", "goal": "수련장의 허수아비를 세 번 벤다", "need": 3, "reward": {"shards": 5}, "hint": {"lobby": "yard"}},
	{"id": "field", "ch": 2, "title": "들판으로 나가기", "goal": "마을 북문에서 E를 눌러 검을 골라 들판으로 나간다", "need": 1, "reward": {"shards": 5, "mats": {"wood": 2}}, "hint": {"lobby": "gate"}},
	{"id": "cache", "ch": 2, "title": "유품 상자 열기", "goal": "들판 곳곳의 유품 상자 곁에서 E를 눌러 연다", "need": 1, "reward": {"shards": 10, "mats": {"stone": 2}}, "hint": {"field": "cache"}},
	{"id": "pack", "ch": 2, "title": "무리 하나 쓰러뜨리기", "goal": "들판에 서성이는 적 무리를 모두 쓰러뜨린다", "need": 1, "reward": {"shards": 10, "mats": {"iron": 2}}, "hint": {"field": "pack"}},
	{"id": "stable_horse", "ch": 2, "title": "검 받침터와 탈 검", "goal": "마을 바깥 터에 검 받침터를 짓고, 들판에서 H로 탈 검을 부른다", "need": 2, "reward": {"shards": 15}, "hint": {"lobby": "stable"}},
	{"id": "stranger", "ch": 2, "title": "낯선 사람 만나기", "goal": "들판을 거닐다 마주치는 총 든 낯선 사람을 만난다", "need": 1, "reward": {"shards": 10}, "hint": {"field": "stranger"}},
	{"id": "first_rune", "ch": 2, "title": "검에 첫 룬 새기기", "goal": "한 검으로 적을 100마리 벤다(어디서든). 룬이 저절로 새겨진다", "need": 1, "reward": {"shards": 15}},
	{"id": "gem_socket", "ch": 0, "title": "보석 박기", "goal": "대장간 E의 보석 탭에서 룬이 새겨진 검에 보석을 박는다(보석은 우두머리·상자에서 가끔 나오고 조각으로도 산다)", "need": 1, "reward": {"shards": 20}, "hint": {"lobby": "forge"}},
	{"id": "future", "ch": 3, "title": "녹슨 미래로", "goal": "들판에 열린 갈라진 틈에서 E를 눌러 건너간다", "need": 1, "reward": {"shards": 20}, "hint": {"field": "rift"}, "hidden": true},
	{"id": "traveller", "ch": 3, "title": "시간을 건너는 사람", "goal": "미래의 이야기를 따라가 타임트래블러를 만난다", "need": 1, "reward": {"shards": 30}, "hidden": true},
	## 시대 균열(docs/rift_raid.md): 3막(흑룡)을 마친 뒤에만 목록에 든다(raid). 열려 있는 동안은 맨 앞 단계가 된다(urgent).
	{"id": "rift_close", "ch": 3, "title": "균열 닫기", "goal": "들판에 열린 시대의 균열에서 E를 눌러 물결을 이겨 내고 우두머리를 쓰러뜨린다. 못 닫으면 터져 마을이 상한다", "need": 1, "reward": {"shards": 40}, "hint": {"field": "raid", "lobby": "raid"}, "raid": true},
	## 건물 수리: 건물이 망가져 있는 동안에만 나오는 안내(끝나는 단계가 아니라 쪽수에도 안 센다, transient).
	{"id": "repair", "ch": 0, "title": "무너진 건물 고치기", "goal": "무너진 건물 앞에서 E를 눌러 재료를 내고 수리한다(고치기 전에는 그 건물의 기능을 못 쓴다)", "need": 1, "reward": {}, "hint": {"lobby": "repair"}, "transient": true},
]


static func size() -> int:
	return STEPS.size()


static func index_of(id: String) -> int:
	for i in STEPS.size():
		if STEPS[i].id == id:
			return i
	return -1


static func _ev(m: Meta, name: String) -> int:
	return int(m.guide_ev.get(name, 0))


static func _any_key(d: Dictionary, prefix: String) -> bool:
	for k in d:
		if str(k).begins_with(prefix):
			return true
	return false


## 단계 i의 지금 진행(0~need). 규칙이 아니라 Meta의 상태와 장면이 센 일만 읽는다.
static func count(i: int, m: Meta) -> int:
	var s: Dictionary = STEPS[i]
	var n: int = 0
	match String(s.id):
		"talk_gate": n = 1 if m.heard.has("gatekeeper") else 0
		"rack": n = _ev(m, "rack")
		"hill_gate": n = _ev(m, "run_start")
		"first_pull": n = _ev(m, "pull")
		"good_pull": n = _ev(m, "pull_good")
		"first_night": n = _ev(m, "night")
		"path": n = _ev(m, "path")
		"day_event": n = _ev(m, "event")
		"finish_run": n = 1 if m.runs >= 1 else 0
		"spend": n = _ev(m, "spend")
		"quest": n = _ev(m, "quest")
		"yard": n = _ev(m, "yard")
		"field": n = _ev(m, "field_enter")
		"cache": n = 1 if _any_key(m.field_found, "cache") else 0
		"pack": n = _ev(m, "pack")
		"stable_horse": n = (1 if m.has_built(&"stable") else 0) + (1 if _ev(m, "horse") > 0 else 0)
		"stranger": n = 1 if m.stranger_seen >= 1 else 0
		"future": n = _ev(m, "future_enter")
		"rift_close": n = m.rr_closed
		"repair": n = 0   # 끝나는 단계가 아니다(건물을 다 고치면 목록에서 사라진다)
		"traveller": n = 1 if m.time_traveller else 0
		"first_rune": n = 1 if m.sword_runes.values().any(func(v): return not (v as Array).is_empty()) else 0
		"gem_socket": n = 1 if m.sword_gems.values().any(func(v): return not (v as Array).is_empty()) else 0
	return mini(n, int(s.need))


## 옛 저장(길라잡이가 없던 때)에서 이미 이뤘다고 볼 만한 것. 처음 읽을 때 한 번만 쓴다(보상 없이 끝낸다).
static func legacy_ok(i: int, m: Meta) -> bool:
	var ran: bool = m.runs > 0
	var deep: bool = m.best >= 2
	var vet: bool = m.runs >= 3
	match String(STEPS[i].id):
		"rack", "hill_gate", "first_pull", "good_pull", "finish_run": return ran
		"first_night", "path", "day_event": return deep
		"spend": return m.sheath_peak > 0 or m.sheath_lv > 0 or m.bless.values().any(func(v): return int(v) > 0) or vet
		"quest": return m.quest_active >= 0 or vet
		"yard": return vet
		"field": return m.seen_count() > 0 or not m.field_found.is_empty() or not m.packs_cleared.is_empty() or m.boss_first
		"pack": return not m.packs_cleared.is_empty() or m.boss_first or not m.chiefs_first.is_empty() or not m.crypt_cleared.is_empty() or not m.crypt_opened.is_empty()
		"stable_horse": return m.has_built(&"stable")
		"rift_close": return m.rr_closed > 0
		"future": return not m.neon_logs.is_empty() or not m.story_shards.is_empty() or not m.future_hilts.is_empty() or m.time_traveller or m.vault_open
	return false


static func met(i: int, m: Meta, with_legacy: bool = false) -> bool:
	return count(i, m) >= int(STEPS[i].need) or (with_legacy and legacy_ok(i, m))


static func is_done(i: int, m: Meta) -> bool:
	return m.guide_done.has(String(STEPS[i].id))


static func done_count(m: Meta) -> int:
	var n: int = 0
	for i in STEPS.size():
		n += 1 if is_done(i, m) and shown(i, m) and not _transient(i) else 0
	return n


static func _transient(i: int) -> bool:
	return bool(STEPS[i].get("transient", false))


## 목록에 들어 있나. 숨은 단계(미래·이야기)는 틈이 열린 뒤(Meta.rift_open)에야, 균열 단계(raid)는 3막을 마친 뒤에야,
## 수리 안내(transient)는 건물이 망가져 있는 동안에만 들어간다. 그 전에는 이름도 ???도 안 보인다.
static func shown(i: int, m: Meta) -> bool:
	var s: Dictionary = STEPS[i]
	if bool(s.get("hidden", false)) and not m.rift_open():
		return false
	if bool(s.get("raid", false)) and not RiftRaid.unlocked(m):
		return false
	if bool(s.get("transient", false)) and m.rr_ruined.is_empty():
		return false
	return true


## 쪽수(n/전체)에 세는 단계 수(수리 안내는 안 센다).
static func shown_count(m: Meta) -> int:
	var n: int = 0
	for i in STEPS.size():
		n += 1 if shown(i, m) and not _transient(i) else 0
	return n


## 급한 단계: 건물이 망가져 있으면 수리, 균열이 열려 있으면 균열 닫기가 맨 앞에 선다.
static func _urgent(i: int, m: Meta) -> bool:
	match String(STEPS[i].id):
		"repair": return not m.rr_ruined.is_empty()
		"rift_close": return m.rr_open and RiftRaid.unlocked(m)
	return false


## 지금 안내할 단계(급한 것, 아니면 끝나지 않은 첫 단계). 모두 끝났으면 -1.
static func current(m: Meta) -> int:
	for i in STEPS.size():
		if shown(i, m) and not is_done(i, m) and _urgent(i, m):
			return i
	for i in STEPS.size():
		if shown(i, m) and not is_done(i, m):
			return i
	return -1


static func title_of(i: int) -> String:
	return String(STEPS[i].title)


static func goal_of(i: int) -> String:
	return String(STEPS[i].goal)


## 보상을 한 줄로("조각 10 · 나무 2").
static func reward_text(i: int) -> String:
	var r: Dictionary = STEPS[i].reward
	var parts: PackedStringArray = []
	if int(r.get("shards", 0)) > 0:
		parts.append("조각 %d" % int(r.shards))
	var mats: Dictionary = r.get("mats", {})
	for id in Meta.MAT_IDS:
		if mats.has(String(id)):
			parts.append("%s %d" % [Meta.MAT_NAMES[id], int(mats[String(id)])])
	return " · ".join(parts)


## 보상을 준다(조각, 재료).
static func pay(i: int, m: Meta) -> void:
	var r: Dictionary = STEPS[i].reward
	m.shards += int(r.get("shards", 0))
	var mats: Dictionary = r.get("mats", {})
	for id in Meta.MAT_IDS:
		if mats.has(String(id)):
			m.add_mat(id, int(mats[String(id)]))


## 끝난 단계를 걷어 간다. 새로 끝난 단계 번호들을 돌려준다(보상은 이 안에서 한 번만 준다).
## 처음 읽는 저장(guide_init이 false)이면 옛 기록으로 이미 이룬 것을 보상 없이 끝낸다.
static func sync(m: Meta) -> Array[int]:
	var silent: bool = not m.guide_init
	var out: Array[int] = []
	for i in STEPS.size():
		if is_done(i, m) or not shown(i, m):
			continue
		if met(i, m, silent):
			m.guide_done[String(STEPS[i].id)] = 1
			if not silent:
				pay(i, m)
				out.append(i)
	m.guide_init = true
	m.guide_step = maxi(current(m), 0)
	return out


## 지금 단계의 자리 힌트(장면 이름으로). 없으면 "".
static func hint_for(i: int, scene: String, m: Meta) -> String:
	if i < 0 or not shown(i, m):
		return ""
	return String((STEPS[i].get("hint", {}) as Dictionary).get(scene, ""))
