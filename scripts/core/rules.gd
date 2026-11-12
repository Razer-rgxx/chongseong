class_name Rules
extends RefCounted
## 게임 규칙. 노드에 기대지 않고 step() 한 번에 한 틱(1/30초)씩만 돈다.
## 랜덤은 전부 rng 하나를 거친다. 같은 시드와 같은 입력이면 결과가 같다.
## 화면은 신호를 받아 그린다. 지금(1단계)은 낮과 밤의 시계와 자원, 등급 굴리기만 있다.

signal day_started(day: int)
signal night_started(day: int)
signal run_ended(won: bool)

enum Phase { DAY, NIGHT, OVER }

var data: GameData
var rng := RandomNumberGenerator.new()
var seed_value: int
## 한 틱의 길이(초).
var dt: float
var tick: int = 0
var day: int = 1
var phase: Phase = Phase.DAY
## 밤까지 남은 시간(초).
var day_left: float
var wood: int
var stone: int
var gold: int


func _init(game_data: GameData, p_seed: int) -> void:
	data = game_data
	seed_value = p_seed
	rng.seed = p_seed
	dt = 1.0 / float(data.run.tick_rate)
	Grid.size = data.run.map_size
	wood = data.run.start_wood
	stone = data.run.start_stone
	gold = data.run.start_gold
	day_left = data.run.day_length


func step() -> void:
	if phase == Phase.OVER:
		return
	tick += 1
	if phase == Phase.DAY:
		day_left -= dt
		if day_left <= 0.0:
			start_night()
	# 밤의 습격은 4단계에서 넣는다. 그전까지는 end_night()를 불러 넘긴다.


func start_night() -> void:
	if phase != Phase.DAY:
		return
	day_left = 0.0
	phase = Phase.NIGHT
	night_started.emit(day)


func end_night() -> void:
	if phase != Phase.NIGHT:
		return
	day += 1
	if day > data.run.days:
		phase = Phase.OVER
		run_ended.emit(true)
		return
	phase = Phase.DAY
	day_left = data.run.day_length
	day_started.emit(day)


## 1/N 표에서 높은 등급부터 차례로 굴린다. 설계함 등급과 사람 등급이 같이 쓴다.
func roll_tier(odds: PackedFloat64Array, luck: float) -> int:
	for i in range(odds.size() - 1, 0, -1):
		if rng.randf() < luck / odds[i]:
			return i
	return 0
