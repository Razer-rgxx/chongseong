extends SceneTree
## 사이버 검 200자루(312~511)를 data/swords/312.tres … 511.tres로 쓰고, 사이버 카타나(311)에 능력을 붙인다. docs/cyber_swords.md.
##   godot --headless --path . -s scripts/debug/build_cyber_swords.gd
## 시드가 정해져 있어 다시 돌려도 같은 파일이 나온다. 등급은 종류마다 고르게 나눈다(무한은 종류마다 둘).

const SWORD_DIR: String = "res://data/swords/"
const PATTERN_DIR: String = "res://data/attacks/patterns/"
const SEED: int = 20261125

## 등급별 수: 흔함 34, 귀함 40, 전설 44, 신화 38, 초월 32, 무한 12 (언덕 표보다 조금 위쪽).
const GRADE_COUNTS: Array[int] = [34, 40, 44, 38, 32, 12]
## 종류마다 어울리는 능력(순서대로 돌려 쓴다).
const AFFINITY: Dictionary = {
	"단검": ["연사", "탄창", "오버클럭", "조준"],
	"카타나": ["글리치 순간베기", "레일", "플라즈마 칼날", "오버클럭"],
	"오니마루": ["플라즈마 칼날", "산탄", "과열", "해킹"],
	"환도": ["관통탄", "탄창", "조준", "해킹"],
	"중장도": ["산탄", "과열", "EMP", "방벽"],
	"대검": ["반동 돌진", "관통탄", "레일", "방벽"],
}
const DESIGN: Dictionary = {
	"단검": ["CZ-%02d", "Type-%02d", "Mk.%s"],
	"카타나": ["Mk.%s", "KT-%02d", "Rev.%02d"],
	"오니마루": ["Mk.%s", "Type-%02d", "ON-%02d"],
	"환도": ["-%02d", "-%02d", "-%02d"],
	"중장도": ["HV-%02d", "Mk.%s", "Type-%02d"],
	"대검": ["Mk.%s", "GR-%02d", "Type-%02d"],
}
const ADJ: Array[String] = ["네온", "강철", "폐허", "심야", "과열", "무음", "유리", "균열", "방전", "회로", "안개", "사막", "해무", "빗속", "역광", "잔광", "영하", "붉은", "푸른", "검은", "차가운", "끊어진", "녹슨", "투명한", "떠도는", "마지막", "불량", "탈옥한", "잠긴", "깨진"]
const NOUN: Array[String] = ["까마귀", "늑대", "적귀", "전류", "유령", "도시", "불꽃", "심장", "신호", "파편", "사냥꾼", "문지기", "뱀", "기억", "새벽", "잔상", "궤도", "낙인", "송곳니", "거미", "나침반", "그림자", "등대", "폭죽", "국경", "비명", "암호", "혜성", "철새", "배달부"]
## 무한 12자루(종류마다 둘): [종류, 이름, 능력 둘, 이야기]
const INFINITE: Array[Array] = [
	["단검", "단검 Ω-01 「무음의 송곳니」", ["연사", "글리치 순간베기"], "소리 없이 열 발을 쏘고 등 뒤에 선다."],
	["단검", "단검 Ω-02 「잔광」", ["탄창", "과열"], "쏜 자리에 열이 남아 한참 식지 않는다."],
	["카타나", "카타나 Mk.X 「절단선」", ["레일", "글리치 순간베기"], "베기 전에 선이 먼저 그어진다."],
	["카타나", "카타나 Mk.XI 「새벽의 방전」", ["오버클럭", "플라즈마 칼날"], "해 뜨기 전에 가장 빨리 달린다."],
	["오니마루", "오니마루 Mk.IX 「적귀」", ["산탄", "플라즈마 칼날"], "붉은 눈 하나가 총구를 겸한다."],
	["오니마루", "오니마루 Mk.XII 「백귀야행」", ["해킹", "EMP"], "쓰러진 기계들이 줄지어 주인을 따른다."],
	["환도", "환도-00 「전류」", ["관통탄", "오버클럭"], "한 줄로 선 것은 한 발로 끝난다."],
	["환도", "환도-13 「유리 왕관」", ["조준", "방벽"], "쓰는 자의 머리 위에 보이지 않는 관이 선다."],
	["중장도", "중장도 「폐허의 왕」", ["산탄", "과열"], "무너진 도시를 한 칼로 다시 무너뜨린다."],
	["중장도", "중장도 「철의 장례」", ["EMP", "방벽"], "기계의 마지막 날을 알리는 종도 없이."],
	["대검", "대검 Tyrant 「도시를 가르는 자」", ["관통탄", "반동 돌진"], "한 발에 한 구역이 갈라지고 쏜 자도 물러난다."],
	["대검", "대검 Juggernaut 「심야 열차」", ["레일", "반동 돌진"], "선로 위의 것은 모두 치인다."],
]
const ROMAN: Array[String] = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX"]

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = SEED
	var existing: Dictionary = {}
	for f in ResourceLoader.list_directory(SWORD_DIR):
		if f.ends_with(".tres"):
			var sd := load(SWORD_DIR + f) as SwordData
			if sd.id < CyberSwords.FIRST:
				existing[sd.display_name] = true
	# 등급 나누기: 종류마다 칸 수가 정해져 있고, 등급마다 종류를 돌아가며 채운다(무한은 종류마다 둘)
	var ids_of: Array = [[], [], [], [], [], []]
	for id in range(CyberSwords.FIRST, CyberSwords.LAST + 1):
		ids_of[(id - CyberSwords.FIRST) % 6].append(id)
	var room: Array[int] = []
	for k in 6:
		room.append(ids_of[k].size())
	var grade_of: Dictionary = {}   # id -> 등급
	var pools: Array = [[], [], [], [], [], []]   # 종류마다 등급 목록
	var cursor: int = 0
	for g in [5, 4, 3, 2, 1, 0]:
		for i in GRADE_COUNTS[g]:
			var tries: int = 0
			while room[cursor % 6] == 0 and tries < 6:
				cursor += 1
				tries += 1
			pools[cursor % 6].append(g)
			room[cursor % 6] -= 1
			cursor += 1
	for k in 6:
		var pool: Array = pools[k]
		var ids: Array = ids_of[k].duplicate()
		_shuffle(ids)
		for i in ids.size():
			grade_of[ids[i]] = pool[i]
	# 이름 가운데 「」 부분은 겹치지 않게 뽑는다
	var epithets: Array[String] = []
	for a in ADJ:
		for n in NOUN:
			epithets.append("%s %s" % [a, n])
	_shuffle(epithets)
	var inf_left: Array = INFINITE.duplicate()
	var used_names: Dictionary = {}
	var used_sets: Dictionary = {}
	for row in INFINITE:
		used_names[row[1]] = true
		var s: Array = (row[2] as Array).duplicate()
		s.sort()
		used_sets[",".join(PackedStringArray(s))] = true
	# 공격 방식: 등급마다 그 등급의 방식 번호들
	var pats: Array = [[], [], [], [], [], []]
	for f in ResourceLoader.list_directory(PATTERN_DIR):
		if f.ends_with(".tres"):
			var pd := load(PATTERN_DIR + f) as PatternData
			if pd.id > 0:
				pats[pd.grade].append(pd.id)
	var seen_in_grade: Array[int] = [0, 0, 0, 0, 0, 0]
	var kind_n: Array[int] = [0, 0, 0, 0, 0, 0]
	var ins_keys: Array = []
	for f in ResourceLoader.list_directory("res://data/inscriptions/"):
		if f.ends_with(".tres"):
			ins_keys.append((load("res://data/inscriptions/" + f) as InscriptionData).key)
	ins_keys.sort()
	var ep_i: int = 0
	var out: Array[Dictionary] = []
	for id in range(CyberSwords.FIRST, CyberSwords.LAST + 1):
		var k: int = (id - CyberSwords.FIRST) % 6
		var sub: String = CyberSwords.SUBS[k]
		var g: int = grade_of[id]
		var d: Dictionary = {"id": id, "grade": g, "sub": sub, "form": CyberSwords.FORM_OF[sub], "story": ""}
		var n: int = kind_n[k]
		kind_n[k] += 1
		if g == 5:
			var row: Array = []
			for r in inf_left:
				if r[0] == sub:
					row = r
					break
			inf_left.erase(row)
			d["name"] = row[1]
			d["powers"] = row[2]
			d["story"] = row[3]
		else:
			var aff: Array = AFFINITY[sub]
			var p1: String = aff[n % 4]
			var powers: Array = [p1]
			if g >= 2:
				powers.append(aff[(n + 1 + n / 4) % 4])
			var key: Array = powers.duplicate()
			key.sort()
			if g >= 2:
				var shift: int = 2
				while shift < 8 and (used_sets.has(_set_key(powers)) or powers[0] == powers[1]):
					powers[1] = aff[(n + shift + n / 4) % 4]   # 무한의 짝과 같으면 바꾼다
					shift += 1
			d["powers"] = powers
			var nm: String = ""
			while nm == "" or used_names.has(nm) or existing.has(nm):
				var ep: String = epithets[ep_i]
				ep_i += 1
				var fmts: Array = DESIGN[sub]
				var fmt: String = fmts[n % 3]
				var tag: String = fmt % (ROMAN[n % ROMAN.size()] if fmt.contains("%s") else 1 + (n * 7 + id) % 99)
				nm = "%s%s%s 「%s」" % [sub, "" if tag.begins_with("-") else " ", tag, ep]
			used_names[nm] = true
			d["name"] = nm
		# 능력의 짝이 둘 다 같은 능력이면 하나만
		var uniq: Array = []
		for p in d["powers"]:
			if not uniq.has(p):
				uniq.append(p)
		d["powers"] = uniq
		var plist: Array = pats[g]
		d["attack"] = plist[(seen_in_grade[g] * 7 + seen_in_grade[g] / 3) % plist.size()]
		seen_in_grade[g] += 1
		# 각인: 흔함~전설 1개, 신화 이상 2개
		var want: int = 1 if g <= 2 else 2
		var ins: Array = []
		while ins.size() < want:
			var key2: String = ins_keys[_rng.randi_range(0, ins_keys.size() - 1)]
			if not ins.has(key2) and key2 != "투박함":
				ins.append(key2)
		d["ins"] = ins
		out.append(d)
	for d in out:
		_write(d)
	# 사이버 카타나(311): 글리치 순간베기
	var kat := load(SWORD_DIR + "311.tres") as SwordData
	_patch_katana(kat)
	var by_grade: Array[int] = [0, 0, 0, 0, 0, 0]
	for d in out:
		by_grade[d.grade] += 1
	print("사이버 검 %d자루 등급별 %s" % [out.size(), by_grade])
	quit(0)


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func _write(d: Dictionary) -> void:
	var powers: PackedStringArray = PackedStringArray(d["powers"])
	var lines: PackedStringArray = [
		"[gd_resource type=\"Resource\" script_class=\"SwordData\" format=3]", "",
		"[ext_resource type=\"Script\" path=\"res://scripts/core/data/sword_data.gd\" id=\"1_s\"]", "",
		"[resource]", "script = ExtResource(\"1_s\")",
		"id = %d" % d.id,
		"display_name = %s" % _q(d.name),
		"grade = %d" % d.grade,
		"form = %d" % d.form,
		"attack = %d" % d.attack,
		"inscriptions = PackedStringArray(%s)" % ", ".join(PackedStringArray((d.ins as Array).map(func(s): return _q(s)))),
		"unique_text = %s" % _q(CyberSwords.text_for(powers)),
		"unique_ready = true",
		"unbreakable = false",
		"story = %s" % _q(d.story),
		"field_only = false",
		"cyber = true",
		"sub_type = %s" % _q(d.sub),
		"cyber_powers = PackedStringArray(%s)" % ", ".join(PackedStringArray((d.powers as Array).map(func(s): return _q(s)))),
	]
	var f := FileAccess.open(SWORD_DIR + "%d.tres" % d.id, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()


func _patch_katana(kat: SwordData) -> void:
	var path: String = SWORD_DIR + "311.tres"
	var text: String = FileAccess.get_file_as_string(path)
	var keep: PackedStringArray = []
	for line in text.split("\n"):
		if line.begins_with("unique_text = ") or line.begins_with("unique_ready = ") or line.begins_with("cyber = ") or line.begins_with("sub_type = ") or line.begins_with("cyber_powers = "):
			continue
		keep.append(line)
	var out: PackedStringArray = []
	for line in keep:
		out.append(line)
		if line.begins_with("inscriptions = "):
			out.append("unique_text = %s" % _q(CyberSwords.text_for(PackedStringArray(["글리치 순간베기"]))))
			out.append("unique_ready = true")
	var s: String = "\n".join(out).strip_edges() + "\n"
	s += "cyber = true\nsub_type = \"카타나\"\ncyber_powers = PackedStringArray(\"글리치 순간베기\")\n"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(s)
	f.close()


static func _set_key(a: Array) -> String:
	var k: Array = a.duplicate()
	k.sort()
	return ",".join(PackedStringArray(k))


static func _q(s: String) -> String:
	return "\"%s\"" % s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n")
