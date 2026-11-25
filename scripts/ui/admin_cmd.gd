class_name AdminCmd
extends RefCounted
## 관리자 창의 낱말 명령(docs/account.md): "날씨 비", "재료 쇠 50", "머리 망루". 검 콘솔(SwordConsole)이 해석해 command 신호로 보내고
## 장면이 apply로 돌린다. 규칙에 걸리는 일은 Rules의 함수로만 한다. 돌려주는 글은 알림에 띄운다.

const WEATHER_NAMES: Dictionary = {&"clear": "맑음", &"rain": "비", &"fog": "안개", &"storm": "폭풍", &"ash": "잿바람"}
const MAT_ALIAS: Dictionary = {"나무": &"wood", "돌": &"stone", "쇠": &"iron"}
const HEAD_ALIAS: Dictionary = {
	"망루": "chief_tower", "늑대": "chief_grove", "발치": "chief_foot", "방패": "chief_keep", "늪": "chief_marsh",
	"채석": "chief_quarry", "불탄": "chief_hamlet", "까마귀": "chief_pass", "무덤기사": "boss", "무덤주인": "crypt",
}
const NAMES: PackedStringArray = ["날씨", "재료", "머리", "낯선이", "미래", "시대", "이야기"]


## 입력 글이 명령이면 {name, args}, 아니면 빈 사전.
static func parse(text: String) -> Dictionary:
	var w: PackedStringArray = text.strip_edges().split(" ", false)
	if w.is_empty() or not NAMES.has(w[0]):
		return {}
	return {"name": w[0], "args": w.slice(1)}


static func weather_of(word: String) -> StringName:
	for k in WEATHER_NAMES:
		if word == String(k) or word == WEATHER_NAMES[k]:
			return k
	return &""


## 줄 아래에 띄울 설명.
static func describe(cmd: Dictionary) -> String:
	var a: PackedStringArray = cmd.args
	match cmd.name:
		"날씨":
			if a.size() >= 1 and weather_of(a[0]) != &"":
				return "Enter: 날씨를 %s(으)로 (들판에서만)" % WEATHER_NAMES[weather_of(a[0])]
			return "날씨 맑음 · 비 · 안개 · 폭풍 · 잿바람 (들판에서만)"
		"재료":
			if a.size() >= 1 and MAT_ALIAS.has(a[0]):
				return "Enter: %s %+d" % [a[0], int(a[1]) if a.size() > 1 and a[1].is_valid_int() else 50]
			return "재료 나무 · 돌 · 쇠 [수, 기본 50]"
		"낯선이":
			return "낯선이 횟수 (4면 다음이 다섯 번째, 0이면 처음부터, 들판에서만 바로 선다)"
		"미래":
			return "미래 (낯선이 이야기를 마친 것으로 하고 다음 들판 방문부터 틈이 선다. 들판에서 바로 든다)"
		"시대":
			return "시대 현재 · 미래 · 과거 (타임트래블러 없이도 건넌다. 들판과 미래·과거 구역에서)"
		"이야기":
			return "이야기 0~4 (0 처음, 1 조각 하나, 2 조각 셋, 3 금고 엶, 4 장치를 받음)"
		"머리":
			if a.size() >= 1 and HEAD_ALIAS.has(a[0]):
				return "Enter: %s의 머리 하나" % a[0]
			return "머리 " + " · ".join(HEAD_ALIAS.keys())
	return ""


## 명령을 돌린다. rules는 없을 수 있다(마을). 결과 글을 돌려준다.
static func apply(cmd: Dictionary, rules: Rules, meta: Meta) -> String:
	var a: PackedStringArray = cmd.args
	match cmd.name:
		"날씨":
			var k: StringName = weather_of(a[0]) if a.size() >= 1 else &""
			if k == &"":
				return "날씨 이름을 확인하세요."
			if rules == null or not rules.set_weather(k):
				return "날씨는 들판에서만 바꿀 수 있습니다."
			return "관리: 날씨 %s" % WEATHER_NAMES[k]
		"재료":
			if a.is_empty() or not MAT_ALIAS.has(a[0]) or meta == null:
				return "재료 이름을 확인하세요."
			var n: int = int(a[1]) if a.size() > 1 and a[1].is_valid_int() else 50
			meta.add_mat(MAT_ALIAS[a[0]], n)
			meta.save()
			return "관리: %s %+d" % [a[0], n]
		"낯선이":
			if meta == null or a.is_empty() or not a[0].is_valid_int():
				return "낯선이 횟수(0~)를 적으세요."
			meta.stranger_seen = maxi(0, int(a[0]))
			if meta.stranger_seen == 0:
				meta.stranger_done = false
				meta.stranger_drop = -1
			meta.save()
			Stranger.force = rules != null and rules.field and not meta.stranger_done
			return "관리: 낯선이 만난 횟수 %d%s" % [meta.stranger_seen, " (들판이면 바로 선다)" if Stranger.force else ""]
		"미래":
			if meta == null:
				return "저장 자료가 없습니다."
			meta.stranger_done = true
			meta.stranger_drop = -1
			meta.note_found(Stranger.SWORD)
			meta.save()
			if rules != null and rules.field:
				Meta.go_future = true
			return "관리: 녹슨 미래로 간다" if Meta.go_future else "관리: 낯선이 이야기를 마쳤다(사이버 카타나 도감). 들판에 가면 틈이 선다."
		"시대":
			if a.is_empty() or not ["현재", "미래", "과거"].has(a[0]):
				return "시대 현재, 미래, 과거 중 하나를 적으세요."
			if rules == null or not rules.field:
				return "시대는 들판과 미래·과거 구역에서만 건널 수 있습니다."
			if a[0] == "미래":
				if meta != null and not meta.rift_open():
					meta.stranger_done = true
					meta.stranger_drop = -1
					meta.note_found(Stranger.SWORD)
					meta.save()
				if rules.era == Rules.ERA_FUTURE:
					return "이미 미래입니다."
				Meta.go_future = true
				return "관리: 미래로 건넌다"
			if a[0] == "과거":
				if rules.era == Rules.ERA_PAST:
					return "이미 과거입니다."
				Meta.go_past = true
				return "관리: 과거로 건넌다 (최초의 대장간)"
			if rules.era == &"":
				return "이미 현재입니다."
			Meta.go_present = true
			return "관리: 현재로 돌아간다"
		"이야기":
			if meta == null or a.is_empty() or not a[0].is_valid_int():
				return "이야기 0~4를 적으세요."
			meta.set_story(int(a[0]))
			meta.save()
			return "관리: 이야기 %d (조각 %d/3%s%s)" % [meta.story(), meta.story_shards.size(), ", 금고 열림" if meta.vault_open else "", ", 타임트래블러" if meta.time_traveller else ""]
		"머리":
			if a.is_empty() or not HEAD_ALIAS.has(a[0]) or meta == null:
				return "머리 이름을 확인하세요."
			var id: String = "%s|%08x" % [HEAD_ALIAS[a[0]], randi()]   # 관리용이라 규칙 난수와 무관하다
			meta.add_head(id)
			meta.save()
			return "관리: %s의 머리를 받았다." % a[0]
	return ""
