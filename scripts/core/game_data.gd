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
var runes: RuneTable
## 마을 컨텐츠(15단계): 의뢰, 상인, 주민.
var village: VillageData
## 1대1 결투(21단계)의 수치.
var duel: DuelData
## 언덕 재설계(docs/hill_events.md): 한 구역의 검 지도 수치.
var hill_zone: HillZoneData
## 39단계 말의 수치(들판에서만).
var horse: HorseData
## 파일 이름 순서(0 단검, 1 장검, 2 대검, 3 세검).
var forms: Array[FormData] = []
## 파일 이름 순서(001 … 511).
var swords: Array[SwordData] = []
## 등급마다 그 등급 검의 swords 번호. 언덕에서 뽑히는 후보라 오픈월드 한정 검(field_only)은 들지 않는다.
var swords_by_grade: Array[PackedInt32Array] = []
## 사이버 검(312~511)의 등급별 swords 번호. 언덕 뽑기에는 Meta.rift_open 뒤에만 일부 섞인다(Rules.pick_pull_sword).
var cyber_by_grade: Array[PackedInt32Array] = []
## 오픈월드 한정 검(33단계)의 swords 번호(id 순서).
var field_swords: PackedInt32Array = PackedInt32Array()
## 각인 이름 → InscriptionData
var inscriptions: Dictionary = {}
## id → EnemyData
var enemies: Dictionary = {}
## 마을 건물(2026-11-21 마을 키우기 2단계, 파일 이름 순서).
var buildings: Array[BuildingData] = []
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
	d.runes = load(DIR + "runes.tres") as RuneTable if ResourceLoader.exists(DIR + "runes.tres") else RuneTable.new()
	d.powers = load(DIR + "powers.tres") as PowerTable if ResourceLoader.exists(DIR + "powers.tres") else PowerTable.new()
	d.village = load(DIR + "village.tres") as VillageData
	d.hill_zone = load(DIR + "hill_zone.tres") as HillZoneData if ResourceLoader.exists(DIR + "hill_zone.tres") else null
	d.duel = load(DIR + "duel.tres") as DuelData if ResourceLoader.exists(DIR + "duel.tres") else DuelData.new()
	d.horse = load(DIR + "horse.tres") as HorseData if ResourceLoader.exists(DIR + "horse.tres") else HorseData.new()
	for path in _tres_in(DIR + "forms/"):
		d.forms.append(load(path) as FormData)
	for path in _tres_in(DIR + "buildings/"):
		d.buildings.append(load(path) as BuildingData)
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
		d.cyber_by_grade.append(PackedInt32Array())
	for path in _tres_in(DIR + "swords/"):
		var s := load(path) as SwordData
		if s.field_only:
			d.field_swords.append(d.swords.size())
		elif s.cyber:
			d.cyber_by_grade[s.grade].append(d.swords.size())
		else:
			d.swords_by_grade[s.grade].append(d.swords.size())
		d.swords.append(s)
	return d


func building(id: StringName) -> BuildingData:
	for b in buildings:
		if b.id == id:
			return b
	return null


## SwordData.id는 1부터 511까지이고 swords 순서와 같다.
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


## 오픈월드 한정 검인지(모르는 id면 false).
func is_field_sword(id: int) -> bool:
	var s := sword_by_id(id)
	return s != null and s.field_only


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
