class_name GameData
extends RefCounted
## data/ 아래의 리소스를 한데 모은다. 규칙은 이것만 보고 수치를 읽는다.

const DIR: String = "res://data/"

var run: RunData
var lord: LordData
var grades: GradeTable
var unarmed: FormData
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


static func load_default() -> GameData:
	var d := GameData.new()
	d.run = load(DIR + "run.tres") as RunData
	d.lord = load(DIR + "lord.tres") as LordData
	d.grades = load(DIR + "grades.tres") as GradeTable
	d.unarmed = load(DIR + "unarmed.tres") as FormData
	for path in _tres_in(DIR + "forms/"):
		d.forms.append(load(path) as FormData)
	for path in _tres_in(DIR + "inscriptions/"):
		var ins := load(path) as InscriptionData
		d.inscriptions[ins.key] = ins
	for path in _tres_in(DIR + "enemies/"):
		var e := load(path) as EnemyData
		d.enemies[e.id] = e
	for g in d.grades.names.size():
		d.swords_by_grade.append(PackedInt32Array())
	for path in _tres_in(DIR + "swords/"):
		var s := load(path) as SwordData
		d.swords_by_grade[s.grade].append(d.swords.size())
		d.swords.append(s)
	return d


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
