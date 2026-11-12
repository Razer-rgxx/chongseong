class_name GameData
extends RefCounted
## data/ 아래의 리소스를 한데 모은다. 규칙은 이것만 보고 수치를 읽는다.

const DIR: String = "res://data/"

var run: RunData
var lord: LordData
var tiers: TierTable
var grades: GradeTable
## 파일 이름 순서(0_창병, 1_궁수, …)대로 담는다.
var classes: Array[ClassData] = []
## id → EnemyData
var enemies: Dictionary = {}
## 파일 이름 순서(등급_순번_id)대로 담는다.
var buildings: Array[BuildingData] = []


static func load_default() -> GameData:
	var d := GameData.new()
	d.run = load(DIR + "run.tres") as RunData
	d.lord = load(DIR + "lord.tres") as LordData
	d.tiers = load(DIR + "box_tiers.tres") as TierTable
	d.grades = load(DIR + "people/grades.tres") as GradeTable
	for path in _tres_in(DIR + "people/classes/"):
		d.classes.append(load(path) as ClassData)
	for path in _tres_in(DIR + "enemies/"):
		var e := load(path) as EnemyData
		d.enemies[e.id] = e
	for path in _tres_in(DIR + "buildings/"):
		d.buildings.append(load(path) as BuildingData)
	return d


func buildings_of_tier(tier: int) -> Array[BuildingData]:
	var out: Array[BuildingData] = []
	for b in buildings:
		if b.tier == tier:
			out.append(b)
	return out


func building(id: StringName) -> BuildingData:
	for b in buildings:
		if b.id == id:
			return b
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
