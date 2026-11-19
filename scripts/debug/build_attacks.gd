extends SceneTree
## 공격 방식 150가지를 만들어 data/attacks/patterns/001.tres … 150.tres에 쓰고, 검 표(data/swords/*.tres)의 attack을 채운다.
## docs/attacks.md 3절의 규칙을 따른다. 랜덤은 등급대마다 정해진 시드의 RandomNumberGenerator라서 다시 돌려도 같은 파일이 나온다.
##   godot --headless --path . -s scripts/debug/build_attacks.gd
## 검 파일은 attack 줄만 고친다(없으면 form 줄 뒤에 넣는다). 동작 이름(이음·마무리 꼴)은 data/attacks/moves/<id>.tres에서 읽는다.
## 000.tres(맨손)는 손으로 쓴 것이라 건드리지 않는다.

const MOVES_DIR: String = "res://data/attacks/moves/"
const PATTERN_DIR: String = "res://data/attacks/patterns/"
const SWORD_DIR: String = "res://data/swords/"
const SEED: int = 20261117

## 등급대: 방식 수, 이음 수(최소~최대), 이음 후보, 마무리 후보, 속성, 메아리, 갈고리 자리, 반격 자리.
## 갈고리·반격 자리: 등급대 안의 번호 → "open"(첫 동작), "mid"(가운데), "end"(마무리).
const LINK_BASIC: Array[String] = ["sweep", "thrust", "rising", "crescent", "pull"]
const LINK_ALL: Array[String] = ["sweep", "thrust", "rising", "flurry", "crescent", "retreat", "pull"]
const FIN_BASIC: Array[String] = ["smash", "spin", "lunge", "cross", "wave", "boomerang"]
const FIN_MORE: Array[String] = ["smash", "spin", "lunge", "cross", "wave", "boomerang", "leap", "iaido"]
const FIN_ALL: Array[String] = ["smash", "spin", "lunge", "wave", "boomerang", "leap", "iaido", "cross", "quake", "whirl", "blink"]
const ELEMENTS: Array[String] = ["fire", "ice", "bolt", "blood"]
const PREFIX: Dictionary = {"fire": "불꽃", "ice": "서리", "bolt": "벼락", "blood": "피의"}
## 연달아 두 번 오면 어색한 동작(물러나고 물러나고, 당기고 당기고 …). 베기·찌르기·올려치기는 연달아 와도 된다.
const NO_TWICE: Array[String] = ["flurry", "crescent", "retreat", "pull"]

const BANDS: Array[Dictionary] = [
	{"grade": 0, "count": 41, "links": [1, 2], "link_from": LINK_BASIC, "fin_from": FIN_BASIC, "element": false, "echo": false, "hook": {}, "parry": {}},
	{"grade": 1, "count": 35, "links": [2, 2], "link_from": LINK_ALL, "fin_from": FIN_MORE, "element": false, "echo": false, "hook": {}, "parry": {}},
	{"grade": 2, "count": 28, "links": [2, 2], "link_from": LINK_ALL, "fin_from": FIN_ALL, "element": true, "echo": false,
		"hook": {3: "open", 10: "end", 17: "open", 24: "end"}, "parry": {}},
	{"grade": 3, "count": 20, "links": [2, 3], "link_from": LINK_ALL, "fin_from": FIN_ALL, "element": true, "echo": false,
		"hook": {2: "open", 7: "end", 12: "mid", 17: "open"}, "parry": {4: "open", 9: "mid", 14: "end", 19: "mid"}},
	{"grade": 4, "count": 20, "links": [3, 3], "link_from": LINK_ALL, "fin_from": FIN_ALL, "element": true, "echo": true,
		"hook": {4: "open", 11: "open", 18: "open"}, "parry": {}},
]

## 무한: 마무리 두 개를 잇는다. 이름은 따로 짓는다.
const INFINITE: Array[Dictionary] = [
	{"moves": ["thrust", "spin", "wave"], "element": "fire", "name": "타오르는 수레바퀴"},
	{"moves": ["hook", "lunge", "iaido"], "element": "bolt", "name": "벼락 사냥"},
	{"moves": ["crescent", "leap", "quake"], "element": "ice", "name": "얼어붙은 대지"},
	{"moves": ["flurry", "blink", "cross"], "element": "blood", "name": "핏빛 십자가"},
	{"moves": ["rising", "smash", "whirl"], "element": "fire", "name": "재의 회오리"},
	{"moves": ["retreat", "wave", "boomerang"], "element": "ice", "name": "서리 폭풍"},
]

var _moves: Dictionary = {}
var _used_keys: Dictionary = {}
var _used_names: Dictionary = {}


func _init() -> void:
	for f in ResourceLoader.list_directory(MOVES_DIR):
		if f.ends_with(".tres"):
			var m := load(MOVES_DIR + f) as MoveData
			_moves[String(m.id)] = m
	var out: Array[Dictionary] = []
	for band in BANDS:
		out.append_array(_band(band))
	for inf in INFINITE:
		out.append(_add({"grade": 5, "moves": inf.moves, "element": inf.element, "echo": true, "name": inf.name}))
	var bad: Array[String] = []
	for p in out:
		if p.is_empty():
			bad.append("빈 방식")
	if out.size() != 150 or not bad.is_empty():
		push_error("방식이 150개가 아니다(%d) %s" % [out.size(), bad])
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATTERN_DIR))
	var first: Array[int] = [0, 0, 0, 0, 0, 0]
	var count: Array[int] = [0, 0, 0, 0, 0, 0]
	for i in out.size():
		var p: Dictionary = out[i]
		p["id"] = i + 1
		_write_pattern(p)
		var g: int = p.grade
		if count[g] == 0:
			first[g] = i + 1
		count[g] += 1
	var hooks: int = out.filter(func(p: Dictionary) -> bool: return (p.moves as Array).has("hook")).size()
	_assign(first, count)
	print("방식 %d개 (등급대 %s, 갈고리 %d), 검 300자루에 배정" % [out.size(), count, hooks])
	quit(0)


func _band(band: Dictionary) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + int(band.grade) * 7919
	var out: Array[Dictionary] = []
	var links_from: Array = band.link_from
	var fins: Array = band.fin_from
	var lo: int = band.links[0]
	var hi: int = band.links[1]
	for i in int(band.count):
		var element: String = ELEMENTS[(i + int(band.grade)) % ELEMENTS.size()] if band.element else ""
		var made: Dictionary = {}
		for tries in 200:
			var n_links: int = lo + (i % (hi - lo + 1))
			var moves: Array = []
			for k in n_links:
				var pick: String = links_from[rng.randi_range(0, links_from.size() - 1)]
				while k > 0 and pick == moves[k - 1] and NO_TWICE.has(pick):
					pick = links_from[rng.randi_range(0, links_from.size() - 1)]
				moves.append(pick)
			moves.append(fins[(i + tries) % fins.size()])
			_special(moves, "hook", (band.hook as Dictionary).get(i, ""))
			_special(moves, "parry", (band.parry as Dictionary).get(i, ""))
			made = _add({"grade": band.grade, "moves": moves, "element": element, "echo": band.echo, "name": ""})
			if not made.is_empty():
				break
		out.append(made)
	return out


## 특수 동작을 그 자리에 넣는다: open = 첫 동작, mid = 가운데(마무리 바로 앞), end = 마무리.
static func _special(moves: Array, id: String, where: String) -> void:
	match where:
		"open":
			moves[0] = id
		"mid":
			moves[moves.size() - 2] = id
		"end":
			moves[moves.size() - 1] = id


## 겹치지 않으면 방식을 만들어 돌려준다. 겹치면 빈 Dictionary.
func _add(p: Dictionary) -> Dictionary:
	var moves: Array = p.moves
	var key: String = ",".join(PackedStringArray(moves)) + "|" + String(p.element) + "|" + str(p.echo)
	var name: String = p.name if p.name != "" else _name(moves, p.element)
	if _used_keys.has(key) or _used_names.has(name):
		return {}
	_used_keys[key] = true
	_used_names[name] = true
	return {"grade": p.grade, "moves": moves.duplicate(), "element": p.element, "echo": p.echo, "name": name}


## "찌르고 내려찍기", "베고 베고 회전". 속성이 있으면 앞에 "불꽃", "서리", "벼락", "피의".
func _name(moves: Array, element: String) -> String:
	var words: Array[String] = []
	if element != "":
		words.append(PREFIX[element])
	for k in moves.size():
		var m: MoveData = _moves[moves[k]]
		words.append(m.end_name if k == moves.size() - 1 else m.link_name)
	return " ".join(PackedStringArray(words))


func _write_pattern(p: Dictionary) -> void:
	var quoted: Array[String] = []
	for m in p.moves:
		quoted.append("\"%s\"" % m)
	var lines: Array[String] = [
		"[gd_resource type=\"Resource\" script_class=\"PatternData\" format=3]",
		"",
		"[ext_resource type=\"Script\" path=\"res://scripts/core/data/pattern_data.gd\" id=\"1_s\"]",
		"",
		"[resource]",
		"script = ExtResource(\"1_s\")",
		"id = %d" % p.id,
		"display_name = \"%s\"" % p.name,
		"grade = %d" % p.grade,
		"moves = PackedStringArray(%s)" % ", ".join(PackedStringArray(quoted)),
		"element = &\"%s\"" % p.element,
		"echo = %s" % ("true" if p.echo else "false"),
	]
	var f := FileAccess.open(PATTERN_DIR + "%03d.tres" % p.id, FileAccess.WRITE)
	f.store_string("\n".join(PackedStringArray(lines)) + "\n")
	f.close()


## 같은 등급 안에서 검 번호 순서대로 나눈다: k번째 검(0부터) → 그 등급대의 floor(k × 방식 수 / 검 수)번째 방식.
func _assign(first: Array[int], count: Array[int]) -> void:
	var by_grade: Array = [[], [], [], [], [], []]
	var files: Array[String] = []
	for f in ResourceLoader.list_directory(SWORD_DIR):
		if f.ends_with(".tres"):
			files.append(f)
	files.sort()
	var info: Dictionary = {}
	for f in files:
		var text := FileAccess.get_file_as_string(SWORD_DIR + f)
		var id: int = _field(text, "id")
		var grade: int = _field(text, "grade")
		by_grade[grade].append(id)
		info[id] = f
	for g in 6:
		var ids: Array = by_grade[g]
		ids.sort()
		for k in ids.size():
			var attack: int = first[g] + int(floor(float(k * count[g]) / float(ids.size())))
			_set_attack(SWORD_DIR + String(info[ids[k]]), attack)


static func _field(text: String, key: String) -> int:
	for line in text.split("\n"):
		if line.begins_with(key + " = "):
			return int(line.substr(key.length() + 3))
	return -1


static func _set_attack(path: String, attack: int) -> void:
	var text := FileAccess.get_file_as_string(path)
	var lines := text.split("\n")
	var out := PackedStringArray()
	var done: bool = false
	for line in lines:
		if line.begins_with("attack = "):
			out.append("attack = %d" % attack)
			done = true
		else:
			out.append(line)
	if not done:
		var at: int = -1
		for i in out.size():
			if out[i].begins_with("form = "):
				at = i
		out.insert(at + 1, "attack = %d" % attack)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(out))
	f.close()
