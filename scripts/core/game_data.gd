class_name GameData
extends RefCounted
## data/ 아래의 리소스를 한데 모은다. 규칙은 이것만 보고 수치를 읽는다.

const DIR: String = "res://data/"

var run: RunData
var lord: LordData
var grades: GradeTable
var unarmed: FormData
var meta: MetaData
## 각인과 고유 능력의 정해진 수치.
var powers: PowerTable
## 파일 이름 순서(0 단검, 1 장검, 2 대검, 3 세검).
var forms: Array[FormData] = []
## 파일 이름 순서(001 … 300).
var swords: Array[SwordData] = []
## 등급마다 그 등급 검의 swords 번호.
var swords_by_grade: Array[PackedInt32Array] = []
## 각인 이름 → InscriptionData
var inscriptions: Dictionary = {}
## id → EnemyData
var enemies: Dictionary = {}
## 좌클릭 기본 동작: id(StringName) → MoveData
var moves: Dictionary = {}
## 공격 방식. 번호가 곧 자리다(0 맨손, 1 … 150).
var patterns: Array[PatternData] = []


static func load_default() -> GameData:
	var d := GameData.new()
	d.run = load(DIR + "run.tres") as RunData
	d.lord = load(DIR + "lord.tres") as LordData
	d.grades = load(DIR + "grades.tres") as GradeTable
	d.unarmed = load(DIR + "unarmed.tres") as FormData
	d.meta = load(DIR + "meta.tres") as MetaData
	d.powers = load(DIR + "powers.tres") as PowerTable if ResourceLoader.exists(DIR + "powers.tres") else PowerTable.new()
	for path in _tres_in(DIR + "forms/"):
		d.forms.append(load(path) as FormData)
	for path in _tres_in(DIR + "inscriptions/"):
		var ins := load(path) as InscriptionData
		d.inscriptions[ins.key] = ins
	for path in _tres_in(DIR + "enemies/"):
		var e := load(path) as EnemyData
		d.enemies[e.id] = e
	for path in _tres_in(DIR + "attacks/moves/"):
		var m := load(path) as MoveData
		d.moves[m.id] = m
	for path in _tres_in(DIR + "attacks/patterns/"):
		var pat := load(path) as PatternData
		while d.patterns.size() <= pat.id:
			d.patterns.append(null)
		d.patterns[pat.id] = pat
	for g in d.grades.names.size():
		d.swords_by_grade.append(PackedInt32Array())
	for path in _tres_in(DIR + "swords/"):
		var s := load(path) as SwordData
		d.swords_by_grade[s.grade].append(d.swords.size())
		d.swords.append(s)
	return d


## SwordData.id는 1부터 300까지이고 swords 순서와 같다.
func sword_by_id(id: int) -> SwordData:
	if id >= 1 and id <= swords.size() and swords[id - 1].id == id:
		return swords[id - 1]
	for s in swords:
		if s.id == id:
			return s
	return null


## 그 검의 공격 방식. 표에 없으면 맨손(0번).
func pattern_for(s: SwordData) -> PatternData:
	if s != null and s.attack > 0 and s.attack < patterns.size() and patterns[s.attack] != null:
		return patterns[s.attack]
	return unarmed_pattern()


func unarmed_pattern() -> PatternData:
	return patterns[0] if not patterns.is_empty() else null


func pattern_by_name(n: String) -> PatternData:
	for p in patterns:
		if p and p.display_name == n:
			return p
	return null


func move(id: StringName) -> MoveData:
	return moves.get(id) as MoveData


func sword_by_name(n: String) -> SwordData:
	for s in swords:
		if s.display_name == n:
			return s
	return null


## 내보낸 게임에서도 되도록 ResourceLoader로 목록을 읽는다.
static func _tres_in(dir: String) -> PackedStringArray:
	var names: Array[String] = []
	for f in ResourceLoader.list_directory(dir):
		if f.ends_with(".tres"):
			names.append(f)
	names.sort()
	var out := PackedStringArray()
	for f in names:
		out.append(dir + f)
	return out
