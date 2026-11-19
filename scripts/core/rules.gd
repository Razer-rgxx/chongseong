class_name Rules
extends RefCounted
## 게임 규칙. 노드에 기대지 않고 step() 한 번에 한 틱(1/30초)씩만 돈다.
## 랜덤은 전부 rng 하나를 거친다. 같은 시드와 같은 입력이면 결과가 같다.
## 화면은 신호와 상태를 받아 그린다.
## 지금(1단계): 낮에 꽂힌 검 뽑기, 두 칸과 바꿔 쥐기, 밤의 적, 형태별 베기, 내구와 부러짐, 구역 오르기, 언덕지기.
## 좌클릭은 검마다 다른 공격 방식(PatternData, 동작 2~4개)이고 Moves(moves.gd)가 돌린다(docs/attacks.md).
## 판 사이 성장(Meta): 축복(체력, 운, 뽑기 값, 새벽 회복)과 검집의 검을 들고 시작한다. 정예와 숫돌 제단.
## 각인 36종과 고유 능력은 Powers(powers.gd)가 맡고, 이 파일은 정해진 자리에서 부른다.
## 11단계 새 적 5종(활잡이, 방패병, 돌격병, 자폭병, 부르는 자)의 행동은 Foes(foes.gd)가 맡는다.
## 12단계 밤마다 목표 하나(버티기·지키기·사냥·포위)와 구역 규칙 하나(없음·짙은 안개·불씨 땅·무덤). docs/content.md "12단계".
## 13단계 갈림길(새벽에 다음 구역의 길 두 개 중 고른다, choose_path)과 낮 사건(대장장이·저주받은 손잡이·순례자·점쟁이).
## 14단계 뽑기 손맛: 버팀 타이밍(pull_window·pull_good·pull_perfect·pull_miss, LordInput.pull_press)과 손잡이 조짐(Hilt.omen, 운 배수).

signal day_started(zone: int)
signal night_started(zone: int)
signal run_ended(won: bool)
signal pull_started(hilt: Hilt, grade: int)
signal pull_step(hilt: Hilt, step: int)
signal pull_refused(reason: String)
signal sword_pulled(sword: Sword)
## 버팀 타이밍(14단계). step번째 버팀의 창이 열린다(open_at ~ close_at, 시각은 pull_t의 시계).
## 창의 가운데가 그 버팀이 저절로 끝나는 때다. 창은 앞 버팀이 판정된 뒤(뽑기 시작이면 바로) 하나씩 보낸다.
signal pull_window(hilt: Hilt, open_at: float, close_at: float)
## 창 안에서 눌렀다(제대로 당김) / 버팀을 모두 제대로 당겼다(pull_perfect_min번 이상) / 그 버팀을 놓쳤다(일찍 눌렀거나 창이 닫혔다).
signal pull_good(hilt: Hilt, step: int)
signal pull_perfect(hilt: Hilt)
signal pull_miss(hilt: Hilt, step: int)
## 점쟁이(14단계): 오늘 손잡이의 참된 조짐이 드러났다(Hilt.revealed, seen_omen()).
signal omens_revealed()
signal choice_needed(sword: Sword)
signal slots_changed()
signal sword_broke(slot: int, sword: Sword)
signal lord_swung(big: bool)
signal lord_dashed()
## 갈고리를 걸었다(날아가기 시작).
signal lord_hooked(target: Enemy)
signal lord_hurt(damage: float)
signal enemy_spawned(enemy: Enemy)
signal enemy_hit(enemy: Enemy, damage: float, big: bool)
signal enemy_died(enemy: Enemy)
## 들판(17단계): 무리가 덤볐다, 제자리로 돌아간다, 무리를 다 쓰러뜨렸다(id).
signal pack_engaged(id: StringName)
signal pack_returned(id: StringName)
signal pack_cleared(id: StringName)
signal boss_spawned(enemy: Enemy)
signal elite_spawned(enemy: Enemy)
signal altar_opened()
signal altar_used(kind: String, text: String)
## 각인·고유 능력이 낸 일(번개, 고리, 떨어진 검, 멈춤, 살아남음 …). 화면이 그린다. info는 종류마다 다르다.
signal effect(kind: StringName, at: Vector2, info: Dictionary)
## 좌클릭 동작 하나가 시작됐다(docs/attacks.md 4절의 info). 모션팀(MoveMotion)과 이펙트팀(MoveFx)이 이것으로 그린다.
signal move_started(move: StringName, info: Dictionary)
## 늦게 터지는 판정(내려찍기·도약 착지, 지진 고리, 발도의 띠, 반격, 소용돌이의 한 바퀴, 연속 찌르기의 한 번, 갈고리 도착, 메아리).
signal move_area(move: StringName, info: Dictionary)
## 날아가는 것(검기, 던진 칼)이 생겼다 / 사라졌다. 위치는 projectiles에서 틱마다 읽는다.
signal projectile_spawned(p: Projectile)
signal projectile_ended(p: Projectile)
## 적이 무엇을 시작했다(docs/content.md 11단계의 act와 info). 이펙트(EnemyFx)와 적 화면이 이것으로 그린다.
signal enemy_act(e: Enemy, act: StringName, info: Dictionary)
## 적의 화살이 났다 / 끝났다(hit = 영주에게 맞았다. 부러졌으면 p.cut). 위치는 enemy_projectiles에서 틱마다 읽는다.
signal enemy_projectile_spawned(p: Projectile)
signal enemy_projectile_ended(p: Projectile, hit: bool)
## 이 밤의 목표(survive, defend, hunt, siege)와 구역 규칙(&"", fog, embers, graves). 밤이 시작될 때(night_started 앞).
signal night_goal_changed(goal: StringName, rule: StringName)
## 봉화가 맞았다 / 꺼졌다(지키기). 봉화 자리는 beacon_pos.
signal beacon_hit(hp: float, max_hp: float)
signal beacon_out()
## 불씨 땅: 그 자리(칸)가 time초 뒤 불붙는다 / 지금부터 time초 동안 탄다.
signal ember_warn(at: Vector2, radius: float, time: float)
signal ember_burn(at: Vector2, radius: float, time: float)
## 무덤: 쓰러졌던 망령이 그 자리에서 다시 일어났다(enemy_spawned 뒤).
signal grave_rise(at: Vector2)
## 포위: 적이 나오는 변(0 북 y = 0, 1 남, 2 서 x = 0, 3 동). -1이면 포위가 끝났다.
signal siege_side(side: int)
## 갈림길(13단계): 새벽에 다음 구역의 길 두 개를 보인다. 카드는 {goal, rule, reward}. choose_path(i)를 부르기 전에는 낮이 시작되지 않는다.
signal path_offered(cards: Array)
signal path_chosen(i: int, card: Dictionary)
## 낮 사건(13단계): 섰다(day_started 뒤) / 썼다(result는 종류마다 다르다) / 사라졌다(쓴 뒤, 또는 쓰지 않고 밤이 왔을 때).
## 못 쓰면(체력이 모자람, 검이 없음) pull_refused로 까닭을 보낸다.
signal event_placed(ev: DayEvent)
signal event_used(ev: DayEvent, result: Dictionary)
signal event_gone(ev: DayEvent)

enum Phase { DAY, NIGHT, OVER }

## 밤의 목표와 구역 규칙(RunData.night_goals, zone_rules의 값).
const GOALS: Array[StringName] = [&"survive", &"defend", &"hunt", &"siege"]
const ZONE_RULES: Array[StringName] = [&"", &"fog", &"embers", &"graves"]

var data: GameData
## 판 사이에 남는 것. null이면 축복도 검집도 없다(테스트).
var meta: Meta
var rng := RandomNumberGenerator.new()
var seed_value: int
## 한 틱의 길이(초).
var dt: float
var tick: int = 0
var phase: Phase = Phase.DAY
## 0부터 센다. 마지막 구역은 zone_count() - 1.
var zone: int = 0
## 새벽까지 남은 시간(초). 0 아래로 내려가도 마지막 구역에서는 언덕지기를 쓰러뜨릴 때까지 밤이다.
var night_left: float = 0.0
## 이 밤의 길이(초). 포위는 짧다.
var night_total: float = 0.0
var lord := LordState.new()
## 두 칸. 빈 칸은 null.
var slots: Array[Sword] = [null, null]
var active: int = 0
var hilts: Array[Hilt] = []
var enemies: Array[Enemy] = []
## 뽑는 중인 검. 뽑는 동안 영주는 움직이지 않는다.
var pull_hilt: Hilt = null
var pull_grade: int = 0
var pull_t: float = 0.0
var pull_steps: int = 0
## 버팀 타이밍(14단계): 판정이 끝난 버팀 수, 그중 제대로 당긴 수, 창을 보낸 버팀 번호(0이면 아직 없음)와 그 창,
## 모두 제대로 당겼는지(pull_perfect를 보냈다).
var pull_judged: int = 0
var pull_goods: int = 0
var pull_win_step: int = 0
var pull_win_open: float = 0.0
var pull_win_close: float = 0.0
var pull_all_good: bool = false
## 다음 창을 보내도 되는 때(pull_t). 제대로 당기면 바로, 일찍 눌러 놓치면 그 창이 닫힌 뒤.
var _next_win_at: float = 0.0
## 두 칸이 다 차서 어디에 들지 기다리는 검. 고르기 전에는 시간이 멈춘다.
var pending: Sword = null
var won: bool = false
var boss_out: bool = false
var kills: int = 0
var pulls: int = 0
var best_grade: int = -1
## 판이 끝나면 조각으로 바꾸는 기록.
var broken_by_grade: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
var melted_by_grade: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
var elites_killed: int = 0
## 체력을 쓰지 않는 뽑기(정예가 준다).
var free_pulls: int = 0
var elite_out: bool = false
var altar: Altar = null
## 제단 창이 열려 있으면 시간이 멈춘다.
var altar_open: bool = false
var _pull_free: bool = false
## 남은 히트스톱 틱. 0보다 크면 그 틱은 시간이 멈춘다.
var freeze: int = 0
## 날아가는 것(검기, 던진 칼).
var projectiles: Array[Projectile] = []
## 적의 화살(활잡이). 영주 쪽 날아가는 것과 따로 둔다.
var enemy_projectiles: Array[Projectile] = []
## 이 밤에 나온 부르는 자의 수(RunData.caller_max까지).
var callers_out: int = 0
## 관리용: 영주가 다치지 않는다 / 다음 뽑기 등급을 고정한다(-1이면 굴린다).
var debug_god: bool = false
## 마을 수련장(15단계): 켜면 낮에도 좌클릭이 먹고, 허수아비(still)가 규칙의 적으로 선다.
var yard: bool = false
## 들판 모드(17단계, docs/outside.md): 낮밤과 구역 시간이 흐르지 않고 밤 나오기가 없다. 적은 spawn_pack으로 자리에 둔다.
## 영주는 늘 "밤"(맞고 휘두른다)이고, 무리가 쓰러지거나 돌아가는 일은 _step_field가 맡는다.
var field: bool = false
## 들판 무리: id → {home, wander, zone(0부터), state, spawned, cleared}. state는 PACK_*.
var packs: Dictionary = {}
const PACK_IDLE: int = 0
const PACK_ENGAGED: int = 1
const PACK_RETURNING: int = 2
## 이번 판에 센 것(의뢰판이 본다, docs/village.md 15.1).
var run_stats: Dictionary = {"kills": 0, "kills_by_kind": {}, "zones": 0, "elites": 0, "pulled_by_grade": [0, 0, 0, 0, 0, 0], "perfect": 0, "goals_done": {}, "events_used": 0}
## 떠돌이 상인에게서 산 것 중 아직 안 쓴 것(Meta.pack을 시작할 때 읽고 비운다).
var pack: Array[StringName] = []
var _whetstone: bool = false
var debug_grade: int = -1
var _spawn_t: float = 0.0
var _next_id: int = 1
## 각인과 고유 능력.
var powers: Powers
## 좌클릭 동작.
var moves: Moves
## 공격 표: 표를 가진 적만 영주를 때린다(docs/attack_tokens.md).
var tokens: Tokens
## 새 적 5종의 행동.
var foes: Foes

# ---- 밤의 목표와 구역 규칙(12단계). 화면은 읽기만 한다.
## 이 밤(또는 지난 밤)의 목표와 구역 규칙.
var goal: StringName = &"survive"
var rule: StringName = &""
## 다음 밤의 목표와 구역 규칙. 1구역은 버티기, 그 뒤는 새벽의 갈림길(choose_path)이 set_next_night로 정한다.
var next_goal: StringName = &"survive"
var next_rule: StringName = &""
## 지키기: 봉화 자리(칸)와 체력. beacon_max가 0이면 봉화가 없는 밤이다.
var beacon_pos: Vector2 = Vector2.ZERO
var beacon_hp: float = 0.0
var beacon_max: float = 0.0
var beacon_lost: bool = false
## 사냥: 우두머리가 나왔는지, 그 적, 쓰러뜨렸는지(그러면 다음 틱에 새벽).
var hunt_out: bool = false
var hunt_boss: Enemy = null
var hunt_killed: bool = false
## 포위: 적이 나오는 변(-1이면 네 변 아무 데나)과 다른 변으로 바뀔 때까지 남은 시간(초).
var siege: int = -1
var siege_left: float = 0.0
## 불씨 땅: 자리마다 {at, warn(미리 보임 남은 초), burn(타는 남은 초)}.
var embers: Array[Dictionary] = []
var _ember_t: float = 0.0
var _burn_acc: float = 0.0
## 무덤: 다시 일어날 망령 {at, t(남은 초), kind, hp}.
var graves: Array[Dictionary] = []
## 목표를 이뤄 판이 끝날 때 더하는 조각(사냥).
var goal_shards: int = 0
## 지난 밤의 결과: goal, rule, ok(이뤘는지), free(받은 공짜 뽑기), shards, heal(되찾은 체력), fled(우두머리가 달아났는지).
var last_night: Dictionary = {}

# ---- 갈림길과 낮 사건(13단계). 화면은 읽기만 한다.
## 새벽에 길을 고르는 중이면 시간이 멈추고 낮이 시작되지 않는다(손잡이도 없다).
var path_open: bool = false
## 고를 길 두 개: {goal, rule, reward}.
var path_cards: Array[Dictionary] = []
## 지나온 구역: {zone, goal, rule, reward}. 1구역은 고르지 않았으니 reward가 &"". 지도 창이 그린다.
var path_log: Array[Dictionary] = []
## 이 낮에 받은 갈림길 보상(&""이면 없음).
var path_reward: StringName = &""
## 이 낮의 뽑기 운 배수(갈림길의 운 보상).
var day_luck: float = 1.0
## 갈림길의 조각 보상. 판이 끝날 때 Meta.run_shards가 센다.
var path_shards: int = 0
## 이 낮의 사건(없으면 null). 쓰면 used가 켜지고 밤이 오면 null.
var event: DayEvent = null
## 점쟁이를 썼다: 오늘 손잡이의 참된 조짐이 보인다(손잡이마다 Hilt.revealed, omens_revealed).
var seer_used_today: bool = false
## 저주받은 손잡이를 뽑았다: 이번 밤 새로 나오는 적의 체력과 피해 ×cursed_enemies.
var cursed_night: bool = false
var _pull_cursed: bool = false


func _init(game_data: GameData, p_seed: int, p_meta: Meta = null) -> void:
	data = game_data
	meta = p_meta
	seed_value = p_seed
	rng.seed = p_seed
	dt = 1.0 / float(data.run.tick_rate)
	Grid.size = data.run.arena_size
	powers = Powers.new(self)
	moves = Moves.new(self)
	tokens = Tokens.new(self)
	foes = Foes.new(self)
	night_total = data.run.night_length
	lord.hp = max_hp()
	path_log.append({"zone": 0, "goal": &"survive", "rule": &"", "reward": &""})
	_new_day()
	if meta:
		var s := meta.sheath_sword(data)
		if s:
			slots[0] = s
			active = 0
		_apply_pack()


## 산 물건을 쓴다(처음 한 번). 물건 값은 data/village.tres.
func _apply_pack() -> void:
	pack.clear()
	for id in meta.pack:
		pack.append(StringName(id))
	meta.pack.clear()
	var V := data.village
	for id in pack:
		var g := V.goods_by_id(id)
		if g == null:
			continue
		match id:
			&"ticket":
				free_pulls = mini(data.run.max_free_pulls, free_pulls + int(g.value))
			&"whetstone":
				_whetstone = true
			&"bread":
				lord.hp = max_hp()
			&"note":
				for h in hilts:
					h.revealed = true
	if _whetstone and slots[active] != null:
		_whet(slots[active])


func _whet(s: Sword) -> void:
	_whetstone = false
	if s.breakable():
		s.max_durability = roundf(s.max_durability * (1.0 + data.village.goods_by_id(&"whetstone").value))
		s.durability = s.max_durability


func has_pack(id: StringName) -> bool:
	return pack.has(id)


func _bless(key: String) -> float:
	return meta.bless_value(data.meta, key) if meta else 0.0


func max_hp() -> float:
	return data.lord.hp + _bless("hp") + (data.village.goods_by_id(&"bread").value if pack.has(&"bread") else 0.0)


func pull_cost() -> float:
	return maxf(1.0, data.run.pull_cost - _bless("cost") - (powers.pull_discount() if powers else 0.0))


func heal_at_dawn() -> float:
	return data.run.heal_per_dawn + _bless("heal")


func zone_count() -> int:
	return data.run.zone_names.size()


func last_zone() -> bool:
	return zone == zone_count() - 1


func current() -> Sword:
	return slots[active]


## 쥔 검(없으면 맨손)의 좌클릭 공격 방식.
func pattern() -> PatternData:
	return moves.pattern()


func luck() -> float:
	return data.run.zone_luck[mini(zone, data.run.zone_luck.size() - 1)] * (1.0 + _bless("luck")) * powers.luck_mult() * day_luck * _charm()


func step(input: LordInput = null) -> void:
	if phase == Phase.OVER:
		return
	tick += 1
	lord.prev_pos = lord.pos
	for e in enemies:
		e.prev_pos = e.pos
	for p in projectiles:
		p.prev_pos = p.pos
	for p in enemy_projectiles:
		p.prev_pos = p.pos
	if freeze > 0:
		freeze -= 1
		return
	if pending != null or altar_open or path_open:
		return
	if pull_hilt != null:
		_step_pull(input)
		return
	moves.advance(dt)
	powers.tick(dt)
	if phase == Phase.OVER:
		return
	_step_lord(input)
	moves.tick(dt)
	if yard:
		_step_yard()
	if field:
		_step_field()
		if phase == Phase.NIGHT:
			_step_enemies()
		if phase == Phase.NIGHT:
			foes.step_arrows(dt)
		return
	if phase == Phase.NIGHT:
		_step_night()
		if phase == Phase.NIGHT:
			_step_enemies()
		if phase == Phase.NIGHT:
			foes.step_arrows(dt)


# ---------------------------------------------------------------- 낮과 밤

## 낮에만. 뽑는 중이거나 고르는 중이면 못 한다.
func start_night() -> void:
	if phase != Phase.DAY or pull_hilt != null or pending != null or altar_open or path_open:
		return
	var R := data.run
	phase = Phase.NIGHT
	goal = next_goal
	rule = next_rule
	if zone == 0 or last_zone():
		goal = &"survive"
		rule = &""
	night_total = R.siege_night if goal == &"siege" else R.night_length
	night_left = night_total
	_spawn_t = R.spawn_first
	boss_out = false
	# 사냥하는 밤에는 우두머리가 정예를 대신한다
	elite_out = goal == &"hunt"
	callers_out = 0
	enemy_projectiles.clear()
	hilts.clear()
	altar = null
	# 쓰지 않은 낮 사건은 밤이 오면 떠난다
	if event:
		var ev := event
		event = null
		if not ev.used:
			event_gone.emit(ev)
	moves.clear()
	tokens.reset()
	powers.on_night_start()
	_start_goal()
	night_goal_changed.emit(goal, rule)
	night_started.emit(zone)
	if siege >= 0:
		siege_side.emit(siege)


## 관리용: 지금 밤을 바로 끝낸다(마지막 구역이면 이긴 것으로 친다).
func skip_night() -> void:
	if phase == Phase.NIGHT:
		_end_night()


## 낮을 연다. reward는 고른 길의 보상(13단계 갈림길, 1구역은 &"").
func _new_day(reward: StringName = &"") -> void:
	var R := data.run
	phase = Phase.DAY
	path_open = false
	day_luck = 1.0
	seer_used_today = false
	cursed_night = false
	hilts.clear()
	lord.pos = Grid.middle()
	lord.prev_pos = lord.pos
	for i in R.hilts_per_day:
		var p := Vector2.ZERO
		for tries in 40:
			p = Vector2(rng.randf_range(2.0, R.arena_size.x - 2.0), rng.randf_range(2.0, R.arena_size.y - 2.0))
			if _hilt_spot_ok(p):
				break
		var h := Hilt.new()
		h.id = _new_id()
		h.pos = p
		h.tilt = rng.randf_range(-0.25, 0.25)
		_roll_omen(h)
		hilts.append(h)
	altar = null
	if zone >= R.altar_from_zone:
		var a := Altar.new()
		for tries in 60:
			a.pos = Vector2(rng.randf_range(3.0, R.arena_size.x - 3.0), rng.randf_range(3.0, R.arena_size.y - 3.0))
			if a.pos.distance_to(lord.pos) >= 3.0 and hilts.all(func(h: Hilt) -> bool: return h.pos.distance_to(a.pos) >= 1.8):
				break
		altar = a
	_place_event()
	_apply_path_reward(reward)
	day_started.emit(zone)
	if event:
		event_placed.emit(event)


func _hilt_spot_ok(p: Vector2) -> bool:
	if p.distance_to(lord.pos) < data.run.hilt_clear:
		return false
	for h in hilts:
		if h.pos.distance_to(p) < data.run.hilt_spacing:
			return false
	return true


func _end_night() -> void:
	var reward := _goal_reward()
	enemies.clear()
	enemy_projectiles.clear()
	_end_hook()
	moves.clear()
	embers.clear()
	graves.clear()
	hunt_boss = null
	if siege >= 0:
		siege = -1
		siege_side.emit(-1)
	if reward.ok and goal != &"survive":
		run_stats.goals_done[goal] = int(run_stats.goals_done.get(goal, 0)) + 1
	if last_zone():
		run_stats.zones = zone_count()
		phase = Phase.OVER
		won = true
		run_ended.emit(true)
		return
	for s in slots:
		if s:
			s.night_bonus = 1.0
	free_pulls = mini(data.run.max_free_pulls, free_pulls + int(reward.free))
	goal_shards += int(reward.shards)
	zone += 1
	run_stats.zones = zone
	var before: float = lord.hp
	lord.hp = minf(max_hp(), lord.hp + heal_at_dawn() * float(reward.heal_k))
	reward["heal"] = lord.hp - before
	reward.erase("heal_k")
	last_night = reward
	_offer_path()


# ---------------------------------------------------------------- 뽑기

## 1/N 표에서 높은 등급부터 차례로 굴린다. 보장은 없다.
func roll_grade(p_luck: float) -> int:
	var odds := data.grades.odds
	for g in range(odds.size() - 1, 0, -1):
		if rng.randf() < p_luck / odds[g]:
			return g
	return 0


## 운 부적: 1~charm_zones구역 낮의 운.
func _charm() -> float:
	if pack.has(&"charm") and zone < data.village.charm_zones:
		return data.village.goods_by_id(&"charm").value
	return 1.0


func nearest_hilt(reach: float) -> Hilt:
	var best: Hilt = null
	var bd: float = reach
	for h in hilts:
		if h.gone:
			continue
		var d: float = h.pos.distance_to(lord.pos)
		if d < bd:
			bd = d
			best = h
	return best


## 그 손잡이를 뽑을 때의 운: 운 × 숨은 조짐의 배수(14단계) × (저주받은 손잡이면 cursed_luck).
func pull_luck(h: Hilt) -> float:
	if h == null:
		return luck()
	return luck() * omen_luck(h.omen) * (data.run.cursed_luck if h.cursed else 1.0)


## 조짐(0~3)의 운 배수.
func omen_luck(o: int) -> float:
	var t := data.run.omen_luck
	return t[clampi(o, 0, t.size() - 1)] if not t.is_empty() else 1.0


## 손잡이가 꽂힐 때 숨은 조짐(omen_weights)과 겉 조짐(omen_shown_true만큼 맞고, 아니면 한 단계 위나 아래)을 정한다.
func _roll_omen(h: Hilt) -> void:
	var R := data.run
	var total: float = 0.0
	for w in R.omen_weights:
		total += w
	var x: float = rng.randf() * total
	h.omen = R.omen_weights.size() - 1
	for i in R.omen_weights.size():
		x -= R.omen_weights[i]
		if x < 0.0:
			h.omen = i
			break
	h.shown_omen = h.omen
	if rng.randf() >= R.omen_shown_true:
		var top: int = maxi(0, R.omen_weights.size() - 1)
		h.shown_omen = clampi(h.omen + (1 if rng.randf() < 0.5 else -1), 0, top)
	h.revealed = false


func pull_duration() -> float:
	return data.run.pull_time + data.run.pull_step * pull_grade


func _try_pull() -> void:
	if phase != Phase.DAY or pending != null or pull_hilt != null or altar_open:
		return
	if near_altar():
		altar_open = true
		altar_opened.emit()
		return
	var ev := near_event()
	if ev:
		_use_event(ev)
		return
	var h := nearest_hilt(data.run.pull_reach)
	if h == null:
		return
	# 저주받은 손잡이는 체력도 공짜 뽑기도 쓰지 않는다
	_pull_cursed = h.cursed
	_pull_free = not _pull_cursed and free_pulls > 0
	if not _pull_free and not _pull_cursed and lord.hp <= pull_cost():
		pull_refused.emit("체력이 모자라. 더 뽑으면 쓰러진다.")
		return
	pull_hilt = h
	pull_grade = debug_grade if debug_grade >= 0 else roll_grade(pull_luck(h))
	pull_t = 0.0
	pull_steps = 0
	pull_judged = 0
	pull_goods = 0
	pull_win_step = 0
	pull_win_open = 0.0
	pull_win_close = 0.0
	pull_all_good = false
	_next_win_at = 0.0
	pull_started.emit(h, pull_grade)
	_open_window()


## k번째 버팀이 저절로 끝나는 때(pull_t의 시계).
func pull_step_at(k: int) -> float:
	return float(k) * data.run.pull_step


## 등급이 높을수록 오래 버틴다. 한 단계 버틸 때마다 pull_step 신호가 온다.
## 버팀 타이밍(14단계): 버팀마다 창(그 버팀이 끝나는 때 ± pull_window)이 하나 열린다. 눌린 때는 이 틱 사이의 가운데로 친다.
## 창 안에서 누르면 제대로 당김: 일찍이면 그 버팀이 바로 끝나고(pull_t를 끝나는 때로 당긴다), 늦어도(이미 끝났어도) 친다.
## 버팀마다 한 번만 판정한다: 창이 열리기 전에 누르면 그 버팀은 놓친 것(손해는 없다).
func _step_pull(input: LordInput = null) -> void:
	var R := data.run
	var press_at: float = pull_t + dt * 0.5
	pull_t += dt
	if input and input.pull_press:
		_judge_press(press_at)
	while pull_steps < pull_grade and pull_t >= pull_step_at(pull_steps + 1) - 0.0001:
		pull_steps += 1
		pull_step.emit(pull_hilt, pull_steps)
	# 누르지 않고 창이 닫혔다
	if pull_win_step > pull_judged and pull_t > pull_win_close:
		pull_judged = pull_win_step
		_next_win_at = pull_win_close
		pull_miss.emit(pull_hilt, pull_judged)
	_open_window()
	if pull_t < pull_duration():
		return
	var h := pull_hilt
	pull_hilt = null
	h.gone = true
	if _pull_cursed:
		pass
	elif _pull_free:
		free_pulls -= 1
	else:
		lord.hp -= pull_cost()
	# 제대로 당긴 만큼 돌려받는다(뽑기 값과 함께 셈해서 가득 찬 체력에서도 버리지 않는다)
	if pull_goods > 0:
		lord.hp = minf(max_hp(), lord.hp + R.pull_good_refund * pull_goods)
	pulls += 1
	run_stats.pulled_by_grade[pull_grade] += 1
	best_grade = maxi(best_grade, pull_grade)
	var list: PackedInt32Array = data.swords_by_grade[pull_grade]
	var s := Sword.new(data.swords[list[rng.randi_range(0, list.size() - 1)]], data)
	powers.on_pulled(s)
	# 모두 제대로 당겼다: 최대 내구 +10%(반올림, 적어도 1). 언덕의 첫 검 뒤, 저주의 절반 앞
	if pull_all_good and s.breakable():
		s.max_durability = maxf(s.max_durability + 1.0, roundf(s.max_durability * (1.0 + R.pull_perfect_durability)))
		s.durability = s.max_durability
	if _pull_cursed:
		_pull_cursed = false
		_cursed_pulled(h, s)
	sword_pulled.emit(s)
	_receive(s)


## 뽑는 동안 누른 것을 판정한다(at: 눌린 때, pull_t의 시계). 지금 창의 버팀을 한 번만 판정한다.
func _judge_press(at: float) -> void:
	var k: int = pull_win_step
	if k == 0 or k <= pull_judged:
		return
	pull_judged = k
	if at < pull_win_open or at > pull_win_close:
		# 창 밖: 그 버팀은 놓쳤다. 다음 창은 이 창이 닫힌 뒤
		_next_win_at = pull_win_close
		pull_miss.emit(pull_hilt, k)
		return
	pull_goods += 1
	# 일찍 눌렀으면 그 버팀이 바로 끝난다
	pull_t = maxf(pull_t, pull_step_at(k))
	_next_win_at = pull_t
	pull_good.emit(pull_hilt, k)
	if pull_goods == pull_grade and pull_grade >= data.run.pull_perfect_min:
		pull_all_good = true
		run_stats.perfect += 1
		pull_perfect.emit(pull_hilt)


## 앞 버팀이 판정됐고 다음 버팀이 남았으면 그 창을 연다(pull_window).
func _open_window() -> void:
	if pull_hilt == null or pull_win_step > pull_judged or pull_judged >= pull_grade or pull_t < _next_win_at:
		return
	pull_win_step = pull_judged + 1
	var c: float = pull_step_at(pull_win_step)
	pull_win_open = c - data.run.pull_window
	pull_win_close = c + data.run.pull_window
	_next_win_at = INF
	pull_window.emit(pull_hilt, pull_win_open, pull_win_close)


func _receive(s: Sword) -> void:
	if _whetstone:
		_whet(s)
	for k in 2:
		if slots[k] == null:
			slots[k] = s
			if slots[active] == null:
				active = k
			slots_changed.emit()
			return
	pending = s
	choice_needed.emit(s)


## 두 칸이 다 찼을 때 새 검을 둘 칸(0, 1). -1이면 두고 간다.
func choose(k: int) -> void:
	if pending == null:
		return
	if k == 0 or k == 1:
		slots[k] = pending
	pending = null
	slots_changed.emit()


## 관리·테스트용: 그 칸에 검을 바로 쥐여 준다.
func give(d: SwordData, k: int) -> Sword:
	var s := Sword.new(d, data)
	slots[k] = s
	if slots[active] == null:
		active = k
	slots_changed.emit()
	return s


## 다른 칸의 검으로 바꿔 쥔다. 2는 "다른 칸".
func swap(k: int) -> void:
	if k == 2:
		k = 1 - active
	if k < 0 or k > 1 or k == active or slots[k] == null:
		return
	active = k
	lord.combo = 0
	powers.swapped = true
	slots_changed.emit()


# ---------------------------------------------------------------- 영주

func _step_lord(input: LordInput) -> void:
	var L := lord
	var D := data.lord
	L.cooldown -= dt
	L.swing -= dt
	L.invuln -= dt
	L.dash_cooldown -= dt
	L.hook_cooldown -= dt
	L.combo_timer -= dt
	L.move_lock -= dt
	# 돌격병에 받혀 밀려나는 중
	if L.push.length_squared() > 0.0001:
		L.pos = (L.pos + L.push * dt).clamp(Vector2(0.5, 0.5), Vector2(Grid.size) - Vector2(0.5, 0.5))
		L.push *= pow(D.knock_keep, dt)
	else:
		L.push = Vector2.ZERO
	if input and input.swap_to >= 0:
		swap(input.swap_to)
	if input and input.pull:
		_try_pull()
		if pull_hilt != null:
			L.moving = false
			return
	var mv: Vector2 = input.move if input else Vector2.ZERO
	if mv.length() > 1.0:
		mv = mv.normalized()
	L.moving = mv.length() > 0.1
	if L.moving:
		L.move_dir = mv.normalized()
	# 발도·지진·반격 자세처럼 멈추는 동작과 영주를 옮기는 동작(돌진베기, 도약 …) 동안은 걷지도, 돌진·갈고리도 못 한다
	var busy: bool = L.move_lock > 0.0 or moves.steering()
	if input and input.dash and not busy and powers.dash_charges > 0 and L.dash <= 0.0:
		powers.dash_charges -= 1
		if powers.dash_recharge <= 0.0:
			powers.dash_recharge = powers.dash_cooldown()
		L.dash = D.dash_time
		L.dash_cooldown = powers.dash_recharge
		L.invuln = maxf(L.invuln, D.dash_time + 0.05)
		L.dash_dir = L.move_dir if L.moving else Vector2.from_angle(L.face)
		powers.on_dash()
		lord_dashed.emit()
	if input and input.hook and not busy and phase == Phase.NIGHT and L.hook <= 0.0 and L.dash <= 0.0 and L.hook_cooldown <= 0.0:
		_try_hook(input)
	if L.hook > 0.0:
		_step_hook()
		return
	var v: Vector2
	if L.dash > 0.0:
		L.dash -= dt
		v = L.dash_dir * D.dash_speed
		powers.dash_tick()
	elif busy:
		v = Vector2.ZERO
		L.moving = false
	else:
		var walk: float = moves.walk_mult()
		if walk < 0.0:
			walk = D.swing_move_mult if L.swing > 0.0 else 1.0
		v = mv * D.speed * walk
	var lim := Vector2(Grid.size) - Vector2(0.5, 0.5)
	L.pos = (L.pos + v * dt).clamp(Vector2(0.5, 0.5), lim)
	if not busy:
		if input and input.aim_valid and L.pos.distance_to(input.aim) > 0.05:
			L.face = (input.aim - L.pos).angle()
		elif L.moving:
			L.face = mv.angle()
	if input and input.attack and (phase == Phase.NIGHT or yard) and L.cooldown <= 0.0 and L.dash <= 0.0 and not busy:
		moves.attack(input)


## 겨눈 쪽 부채꼴(hook_cone) 안, hook_range 안의 적 중 겨눈 선에 가장 가까운 적. 없으면 null.
func find_hook_target(face: float) -> Enemy:
	var L := lord
	var D := data.lord
	var best: Enemy = null
	var best_a: float = INF
	for e in enemies:
		if e.dead:
			continue
		var to: Vector2 = e.pos - L.pos
		var d: float = to.length()
		if d > D.hook_range + e.radius or d < 0.001:
			continue
		var a: float = absf(angle_difference(face, to.angle()))
		if a > D.hook_cone / 2.0:
			continue
		if a < best_a - 0.0001 or (absf(a - best_a) <= 0.0001 and best and d < L.pos.distance_to(best.pos)):
			best = e
			best_a = a
	return best


## 우클릭(F) 갈고리: 갈고리 검(방식에 갈고리 베기가 든 검)을 쥐었을 때만. 걸 적이 없으면 아무 일도 없다.
func _try_hook(input: LordInput) -> void:
	if not moves.has_hook():
		return
	var L := lord
	var face: float = L.face
	if input.aim_valid and L.pos.distance_to(input.aim) > 0.05:
		face = (input.aim - L.pos).angle()
	var best := find_hook_target(face)
	if best == null:
		return
	L.hook_cooldown = data.lord.hook_cooldown
	start_hook(best, null)


## 그 적에게 줄을 걸고 날아가기 시작한다. run이 있으면 좌클릭의 갈고리 베기, null이면 우클릭.
func start_hook(target: Enemy, run: MoveRun) -> void:
	var L := lord
	var D := data.lord
	L.hook = D.hook_max_time
	L.hook_target = target
	L.hook_from = L.pos
	L.invuln = maxf(L.invuln, D.hook_max_time + 0.1)
	L.face = (target.pos - L.pos).angle()
	if run:
		run.face = L.face
		run.from = L.pos
	moves.hook_started(target, run)
	lord_hooked.emit(target)


## 날아가는 중: 적에게 곧장 간다. 닿으면 큰 베기, 적이 죽거나 시간이 다 되면 멈춘다.
func _step_hook() -> void:
	var L := lord
	var D := data.lord
	var e: Enemy = L.hook_target
	L.hook -= dt
	if e == null or e.dead:
		_end_hook()
		return
	var to: Vector2 = e.pos - L.pos
	var stop: float = e.radius + D.hook_gap
	var step: float = D.hook_speed * dt
	L.face = to.angle()
	L.moving = true
	L.move_dir = to.normalized()
	if to.length() - stop <= step:
		var lim := Vector2(Grid.size) - Vector2(0.5, 0.5)
		L.pos = (e.pos - to.normalized() * stop).clamp(Vector2(0.5, 0.5), lim)
		lord.hook = 0.0
		lord.hook_target = null
		L.cooldown = 0.0
		moves.hook_arrived()
		return
	var lim2 := Vector2(Grid.size) - Vector2(0.5, 0.5)
	L.pos = (L.pos + to.normalized() * step).clamp(Vector2(0.5, 0.5), lim2)
	if L.hook <= 0.0:
		_end_hook()


func _end_hook() -> void:
	lord.hook = 0.0
	lord.hook_target = null
	moves.hook_ended()


## 그 칸의 검을 부러뜨린다(충신이 대신 부러질 때도).
func break_slot(k: int) -> void:
	if slots[k] != null:
		_break(k)


func _break(k: int) -> void:
	var s := slots[k]
	slots[k] = null
	broken_by_grade[s.grade] += 1
	powers.on_break(s)
	if k == active and slots[1 - k] != null:
		active = 1 - k
	lord.combo = 0
	sword_broke.emit(k, s)
	slots_changed.emit()


## dot: 출혈·불처럼 틱마다 조금씩 들어가는 피해(화면에 맞음 신호를 보내지 않는다).
## src: 때린 자리(방패병이 막는 쪽). 없으면(INF) 영주의 자리.
func hurt(e: Enemy, damage: float, knock: Vector2, big: bool, dot: bool = false, src: Vector2 = Vector2.INF) -> void:
	if e.dead:
		return
	if field and e.pack != &"" and int(packs[e.pack].state) != PACK_ENGAGED:
		_engage_pack(e.pack)
	var res: Array = foes.taken(e, damage, knock, big, dot, lord.pos if src == Vector2.INF else src)
	damage = res[0]
	knock = res[1]
	powers.on_damage(e, damage)
	e.hp -= damage
	e.idle_t = 0.0
	if e.data.refill_after > 0.0:
		e.hp = maxf(e.hp, 1.0)
	e.push += knock * e.data.knockback_mult * data.lord.knock_speed
	if not dot:
		enemy_hit.emit(e, damage, big)
	if e.hp <= 0.0:
		e.dead = true
		tokens.release(e, true)
		if not e.data.still:
			kills += 1
			run_stats.kills += 1
			run_stats.kills_by_kind[e.data.id] = int(run_stats.kills_by_kind.get(e.data.id, 0)) + 1
		if e.elite:
			elites_killed += 1
			run_stats.elites += 1
			free_pulls = mini(data.run.max_free_pulls, free_pulls + 1)
		if e.hunt:
			hunt_killed = true
		_note_grave(e)
		powers.on_kill(e)
		enemy_died.emit(e)
		# 심지가 타는 동안 쓰러진 자폭병은 바로 터진다
		if e.act == &"fuse":
			foes.explode(e)


func _hurt_lord(d: float, attacker: Enemy = null) -> void:
	var L := lord
	if L.invuln > 0.0 or L.dash > 0.0 or phase != Phase.NIGHT:
		return
	# 반격 자세: 피해 없이 둘레를 반격한다(관리용 무적이어도)
	if moves.parried(attacker):
		return
	if debug_god:
		return
	d = powers.lord_damage(d, attacker)
	L.hp -= d
	L.invuln = data.lord.hurt_invuln
	lord_hurt.emit(d)
	if L.hp <= 0.0 and not powers.save_from_death():
		lord_died()


func lord_died() -> void:
	lord.hp = 0.0
	phase = Phase.OVER
	won = false
	run_ended.emit(false)


# ---------------------------------------------------------------- 적

func _step_night() -> void:
	var R := data.run
	# 사냥: 우두머리를 쓰러뜨리면 그 자리에서 새벽이 온다
	if hunt_killed:
		_end_night()
		return
	night_left -= dt
	var prog: float = 1.0 - maxf(0.0, night_left) / night_total
	if last_zone() and not boss_out and night_left <= night_total * R.boss_at:
		boss_out = true
		boss_spawned.emit(_spawn(&"boss"))
	if goal == &"hunt" and not hunt_out and prog >= R.hunt_at:
		hunt_out = true
		boss_spawned.emit(_spawn_hunt())
	if not elite_out and prog > R.elite_at:
		elite_out = true
		elite_spawned.emit(_spawn_elite())
	_step_siege()
	_step_graves()
	_step_embers()
	if phase != Phase.NIGHT:
		return
	_spawn_t -= dt
	if _spawn_t <= 0.0 and enemies.size() < R.max_enemies and (night_left > 0.0 or last_zone()):
		_spawn_t = (R.spawn_start - R.spawn_drop * minf(1.0, prog)) / (1.0 + R.spawn_zone * zone)
		if goal == &"siege":
			_spawn_t /= maxf(0.01, R.siege_spawn)
		var r: float = rng.randf()
		# 새 적(구역마다 RunData의 확률). 나머지 몫 안에서 망령·늑대·거인을 예전 비율로 나눈다
		var extra: float = _extra_total()
		var kind: StringName = _pick_extra(r)
		if kind == &"":
			r = (r - extra) / maxf(0.0001, 1.0 - extra)
			var giant_p: float = minf(R.giant_chance.z, R.giant_chance.x + R.giant_chance.y * zone)
			var wolf_p: float = minf(R.wolf_chance.z, R.wolf_chance.x + R.wolf_chance.y * zone)
			kind = &"wraith"
			if zone >= 1 and prog > R.giant_after and r < giant_p:
				kind = &"giant"
			elif r < wolf_p:
				kind = &"wolf"
		elif kind == &"caller":
			if callers_out >= R.caller_max:
				kind = &"wraith"
			else:
				callers_out += 1
		_mark_beacon(_spawn(kind))
	if night_left <= 0.0 and (not last_zone() or (boss_out and not boss_alive())):
		_end_night()


## 이 구역에서 새 적이 나올 확률의 합.
func _extra_total() -> float:
	var t: float = 0.0
	for k in RunData.EXTRA_KINDS:
		if data.enemies.has(k):
			t += data.run.extra_chance(k, zone)
	return minf(t, 1.0)


## 0~1의 값 r로 새 적을 하나 고른다. 새 적의 몫(_extra_total) 밖이면 &"".
func _pick_extra(r: float) -> StringName:
	var acc: float = 0.0
	for k in RunData.EXTRA_KINDS:
		if not data.enemies.has(k):
			continue
		acc += data.run.extra_chance(k, zone)
		if r < acc:
			return k
	return &""


func boss_alive() -> bool:
	for e in enemies:
		if e.data.boss and not e.dead:
			return true
	return false


## 싸움터 네 변 바깥 한 칸에서 나온다.
func _spawn(kind: StringName) -> Enemy:
	var size := Vector2(Grid.size)
	# 포위하는 밤에는 정해진 변에서만
	var side: int = siege if siege >= 0 else rng.randi_range(0, 3)
	var p := Vector2.ZERO
	match side:
		0:
			p = Vector2(rng.randf() * size.x, -1.0)
		1:
			p = Vector2(rng.randf() * size.x, size.y + 1.0)
		2:
			p = Vector2(-1.0, rng.randf() * size.y)
		_:
			p = Vector2(size.x + 1.0, rng.randf() * size.y)
	return spawn_at(kind, p)


func spawn_at(kind: StringName, p: Vector2) -> Enemy:
	var D: EnemyData = data.enemies[kind]
	var e := Enemy.new()
	e.id = _new_id()
	e.data = D
	e.pos = p
	e.prev_pos = p
	var zi: int = mini(zone, data.run.zone_hp.size() - 1)
	e.max_hp = D.hp * (1.0 if D.boss else data.run.zone_hp[zi])
	e.hp = e.max_hp
	e.damage = D.damage * (1.0 if D.boss else data.run.zone_damage[zi])
	# 저주받은 손잡이를 뽑은 밤에는 새로 나오는 적(정예·우두머리·불려 온 적·다시 일어난 망령도)이 강하다
	if cursed_night:
		e.max_hp *= data.run.cursed_enemies
		e.hp = e.max_hp
		e.damage *= data.run.cursed_enemies
	e.radius = D.radius
	e.cooldown = rng.randf() * 0.5
	foes.on_spawn(e)
	enemies.append(e)
	enemy_spawned.emit(e)
	return e


## 표를 가진 적(Tokens)과 언덕지기는 영주에게 곧장 다가가 닿으면 때린다. 표 없는 적은 기다림 거리 둘레를 돈다.
## 서로 겹치지 않게 밀어내고, 틱 끝에 표를 나눠 준다.
func _step_enemies() -> void:
	var keep: float = pow(data.lord.knock_keep, dt)
	var reach: float = data.run.enemy_reach
	for e in enemies.duplicate():
		if e.dead:
			continue
		e.pos += e.push * dt
		e.push *= keep
		var k: float = powers.enemy_tick(e, dt)
		if e.dead or phase != Phase.NIGHT:
			continue
		# 묶였거나(기절·얼음) 망각이면 표를 내려놓는다
		tokens.check_state(e)
		# 새 적의 행동 시간(겨눔, 돌진, 심지 …). 심지가 다 타면 여기서 터진다
		foes.tick(e, k, dt)
		if e.dead or phase != Phase.NIGHT:
			continue
		if k <= 0.0:
			continue
		# 들판: 덤비지 않은 무리는 제자리를 서성이거나 돌아간다
		if field and e.pack != &"" and int(packs[e.pack].state) != PACK_ENGAGED:
			_step_pack_idle(e, k)
			continue
		# 망각에 걸린 적은 가장 가까운 다른 적을 친다
		var foe: Enemy = null
		if e.confused > 0.0:
			var best: float = 1e9
			for o in enemies:
				if o != e and not o.dead and o.pos.distance_squared_to(e.pos) < best:
					best = o.pos.distance_squared_to(e.pos)
					foe = o
		# 봉화를 노리는 적은 봉화가 타는 동안 표 없이 봉화를 친다
		var burn_it: bool = foe == null and at_beacon(e)
		var target: Vector2 = foe.pos if foe else (beacon_pos if burn_it else lord.pos)
		var to: Vector2 = target - e.pos
		var d: float = to.length()
		if d > 0.001:
			foes.turn(e, to / d, dt)
		e.cooldown -= dt
		# 망각으로 다른 적을 치거나 표가 들지 않는 적(언덕지기)은 표 없이 덤빈다
		var free_hand: bool = foe != null or burn_it or tokens.cost(e) <= 0
		if not free_hand:
			tokens.hold(e, d, dt)
		# 새 적의 걸음과 행동(활잡이, 돌격병, 자폭병의 심지, 부르는 자). 맡았으면 아래를 건너뛴다
		if foes.step(e, foe, to, d, k, dt):
			continue
		if not free_hand and e.token <= 0:
			tokens.wait_move(e, to, d, e.data.speed * k, dt)
		elif d > e.radius + reach + (foe.radius if foe else (data.run.beacon_radius if burn_it else 0.0)):
			e.pos += e.face * e.data.speed * k * dt
		elif e.cooldown <= 0.0 and e.windup <= 0.0:
			e.cooldown = e.data.cooldown
			if foe:
				hurt(foe, e.damage, Vector2.ZERO, false)
			elif burn_it:
				hit_beacon(e.damage)
			else:
				_hurt_lord(e.damage, e)
				# 한 번 때리면(피해를 줬든 막혔든) 표를 돌려놓는다
				tokens.release(e, true)
	var n: int = enemies.size()
	for i in n:
		var a := enemies[i]
		for j in range(i + 1, n):
			var b := enemies[j]
			var dv: Vector2 = b.pos - a.pos
			var d: float = dv.length()
			var m: float = a.radius + b.radius
			if d < m and d > 0.0001:
				var p: Vector2 = dv * ((m - d) / 2.0 / d)
				a.pos -= p
				b.pos += p
	_keep_off_beacon()
	var alive: Array[Enemy] = []
	for e in enemies:
		if not e.dead:
			alive.append(e)
	enemies = alive
	tokens.deal(dt)


## 수련장: 허수아비는 서 있기만 한다. 넉백은 받지 않고, refill_after초 안 맞으면 체력이 찬다.
func _step_yard() -> void:
	for e in enemies:
		if e.dead:
			continue
		e.push = Vector2.ZERO
		e.idle_t += dt
		if e.data.refill_after > 0.0 and e.idle_t >= e.data.refill_after:
			e.hp = e.max_hp


## 허수아비를 세운다(수련장).
func spawn_dummy(p: Vector2) -> Enemy:
	return spawn_at(&"dummy", p)


# ---------------------------------------------------------------- 들판 무리 (17단계)

## 들판 모드를 켠다: 영주는 체력이 가득한 채 "밤"에 서고, 시간은 흐르지 않는다.
func start_field() -> void:
	field = true
	phase = Phase.NIGHT
	night_left = night_total
	hilts.clear()
	altar = null
	event = null
	lord.hp = max_hp()


## FieldLayout.PACKS의 무리를 자리에 둔다. def를 주면 그 무리(테스트용)를 둔다: {at, wander, zone, foes}.
## 세기는 zone(1부터)의 RunData 구역 배수다. 적은 제자리 둘레에 퍼져 선다(랜덤은 rng).
func spawn_pack(id: StringName, def: Dictionary = {}) -> Array[Enemy]:
	var out: Array[Enemy] = []
	var P: Dictionary = def if not def.is_empty() else FieldLayout.PACKS.get(String(id), {})
	if P.is_empty() or packs.has(id):
		return out
	var home: Vector2 = P.at
	var wander: float = float(P.wander)
	var pz: int = clampi(int(P.zone) - 1, 0, data.run.zone_hp.size() - 1)
	var kinds: Array[StringName] = []
	for f in P.foes:
		for _i in int(f[1]):
			kinds.append(StringName(f[0]))
	var a0: float = rng.randf() * TAU
	var keep_zone: int = zone
	zone = pz
	for i in kinds.size():
		var at: Vector2 = home + Vector2.from_angle(a0 + TAU * i / kinds.size()) * wander * (0.35 + 0.35 * rng.randf())
		var e := spawn_at(kinds[i], at)
		e.pack = id
		e.home = at
		e.wander_to = at
		e.wander_t = rng.randf_range(FieldLayout.PACK_WANDER_WAIT.x, FieldLayout.PACK_WANDER_WAIT.y)
		out.append(e)
	zone = keep_zone
	packs[id] = {"home": home, "wander": wander, "zone": pz, "state": PACK_IDLE, "spawned": out.size(), "cleared": false}
	return out


## 안 쓰러뜨린 무리를 모두 둔다(skip: 이미 쓰러뜨린 무리 id → 아무 값).
func spawn_packs(skip: Dictionary = {}) -> void:
	for id in FieldLayout.PACKS:
		if not skip.has(id):
			spawn_pack(StringName(id))


func pack_alive(id: StringName) -> int:
	var n: int = 0
	for e in enemies:
		if e.pack == id and not e.dead:
			n += 1
	return n


func _engage_pack(id: StringName) -> void:
	var p: Dictionary = packs[id]
	if int(p.state) == PACK_ENGAGED:
		return
	p.state = PACK_ENGAGED
	zone = int(p.zone)   # 공격 표 수와 불려 오는 적의 세기가 이 무리를 따른다
	pack_engaged.emit(id)


func _recall_pack(id: StringName) -> void:
	packs[id].state = PACK_RETURNING
	for e in enemies:
		if e.pack != id or e.dead:
			continue
		tokens.release(e, false)
		e.waiting = false
		e.act = &""
		e.act_t = 0.0
		e.windup = 0.0
		e.attack_soon = false
		e.wander_t = 0.0


## 무리마다: 영주가 가까우면 덤비고, 너무 멀어지면 돌아가고, 다 쓰러졌으면 알린다.
func _step_field() -> void:
	if phase == Phase.DAY:
		phase = Phase.NIGHT
	for id in packs:
		var p: Dictionary = packs[id]
		if p.cleared:
			continue
		if pack_alive(id) == 0:
			p.cleared = true
			pack_cleared.emit(id)
			continue
		var d: float = lord.pos.distance_to(p.home)
		match int(p.state):
			PACK_IDLE:
				if d <= FieldLayout.PACK_AGGRO:
					_engage_pack(id)
			PACK_ENGAGED:
				if d > FieldLayout.PACK_LEASH:
					_recall_pack(id)
			_:
				if d <= FieldLayout.PACK_AGGRO:
					_engage_pack(id)
				else:
					var home_all: bool = true
					for e in enemies:
						if e.pack == id and not e.dead and e.pos.distance_to(e.home) > 0.5:
							home_all = false
							break
					if home_all:
						p.state = PACK_IDLE
						pack_returned.emit(id)


## 덤비지 않은 무리의 적 하나: 제자리 반지름 안을 서성이거나(idle) 제자리로 돌아가며 체력이 찬다(returning).
func _step_pack_idle(e: Enemy, k: float) -> void:
	var p: Dictionary = packs[e.pack]
	var sp: float = e.data.speed * k
	if int(p.state) == PACK_RETURNING:
		e.hp = minf(e.max_hp, e.hp + e.max_hp * dt / maxf(dt, FieldLayout.PACK_HEAL_TIME))
		var to: Vector2 = e.home - e.pos
		var step_len: float = sp * FieldLayout.PACK_RETURN_SPEED * dt
		if to.length() <= maxf(step_len, 0.05):
			e.pos = e.home
			e.hp = e.max_hp
		else:
			e.face = to.normalized()
			e.pos += e.face * step_len
		return
	e.wander_t -= dt
	if e.wander_t <= 0.0:
		var home: Vector2 = p.home
		e.wander_to = home + Vector2.from_angle(rng.randf() * TAU) * float(p.wander) * rng.randf()
		e.wander_t = rng.randf_range(FieldLayout.PACK_WANDER_WAIT.x, FieldLayout.PACK_WANDER_WAIT.y)
	var w: Vector2 = e.wander_to - e.pos
	var len_w: float = w.length()
	if len_w > 0.1:
		e.face = w / len_w
		e.pos += e.face * minf(len_w, sp * FieldLayout.PACK_WANDER_SPEED * dt)


## 정예: 체력과 피해가 몇 배, 몸이 크다. 쓰러뜨리면 공짜 뽑기.
func _spawn_elite() -> Enemy:
	var R := data.run
	var kind: StringName = &"wraith"
	# 새 적이 나오는 구역이면 그 확률로 새 적이 정예가 된다(부르는 자는 빼고)
	var extra: StringName = _pick_extra(rng.randf()) if _extra_total() > 0.0 else &""
	if extra != &"" and extra != &"caller":
		kind = extra
	elif zone >= R.elite_giant_from and rng.randf() < R.elite_giant_chance:
		kind = &"giant"
	elif rng.randf() < 0.5:
		kind = &"wolf"
	var e := _spawn(kind)
	e.elite = true
	e.max_hp *= R.elite_hp
	e.hp = e.max_hp
	e.damage *= R.elite_damage
	e.radius *= R.elite_size
	return e


# ---------------------------------------------------------------- 밤의 목표와 구역 규칙(12단계)

## 다음 밤의 목표와 구역 규칙을 바꾼다(13단계 갈림길이 부른다. 관리, 테스트). 모르는 값이면 그대로 둔다.
## 1구역과 마지막 구역의 밤은 이것과 상관없이 버티기다.
func set_next_night(g: StringName, z: StringName) -> void:
	if not GOALS.has(g) or not ZONE_RULES.has(z):
		return
	next_goal = g
	next_rule = z


## 밤이 시작될 때 목표와 구역 규칙의 상태를 새로 둔다.
func _start_goal() -> void:
	var R := data.run
	beacon_max = 0.0
	beacon_hp = 0.0
	beacon_lost = false
	if goal == &"defend":
		beacon_pos = (Grid.middle() + R.beacon_offset).clamp(Vector2(1.0, 1.0), Vector2(Grid.size) - Vector2(1.0, 1.0))
		beacon_max = R.beacon_hp * R.zone_hp[mini(zone, R.zone_hp.size() - 1)]
		beacon_hp = beacon_max
	hunt_out = false
	hunt_boss = null
	hunt_killed = false
	siege = -1
	siege_left = 0.0
	if goal == &"siege":
		siege = rng.randi_range(0, 3)
		siege_left = R.siege_switch
	embers.clear()
	graves.clear()
	_ember_t = R.ember_every
	_burn_acc = 0.0


## 새벽의 보상. heal_k는 새벽 회복에 곱한다(봉화가 꺼지면 절반).
func _goal_reward() -> Dictionary:
	var R := data.run
	var out := {"goal": goal, "rule": rule, "ok": false, "free": 0, "shards": 0, "heal_k": 1.0, "fled": false}
	match goal:
		&"defend":
			out.ok = not beacon_lost
			out.free = R.defend_free if out.ok else 0
			out.heal_k = 1.0 if out.ok else R.beacon_out_heal
		&"hunt":
			out.ok = hunt_killed
			out.fled = hunt_out and not hunt_killed
			if out.ok:
				out.free = R.hunt_free
				out.shards = R.hunt_shards
		&"siege":
			out.ok = true
			out.free = R.siege_free
	return out


## 그 적이 지금 봉화를 노리는지(봉화가 타는 동안만).
func at_beacon(e: Enemy) -> bool:
	return e.beacon and beacon_hp > 0.0


## 봉화를 친다. 0이 되면 꺼진다(밤은 이어진다).
func hit_beacon(damage: float) -> void:
	if beacon_hp <= 0.0:
		return
	beacon_hp = maxf(0.0, beacon_hp - damage)
	beacon_hit.emit(beacon_hp, beacon_max)
	if beacon_hp <= 0.0:
		beacon_lost = true
		beacon_out.emit()


## 지키는 밤에 새로 나온 적의 몫(beacon_share)은 봉화를 노린다(beacon_kinds만).
func _mark_beacon(e: Enemy) -> void:
	var R := data.run
	if beacon_hp > 0.0 and R.beacon_kinds.has(String(e.data.id)) and rng.randf() < R.beacon_share:
		e.beacon = true


## 봉화(돌 받침) 안으로는 영주도 적도 들어오지 못한다.
func _keep_off_beacon() -> void:
	if beacon_max <= 0.0:
		return
	var br: float = data.run.beacon_radius
	for e in enemies:
		e.pos = _push_out(e.pos, br + e.radius)
	lord.pos = _push_out(lord.pos, br)


func _push_out(p: Vector2, r: float) -> Vector2:
	var v: Vector2 = p - beacon_pos
	var d: float = v.length()
	if d >= r:
		return p
	return beacon_pos + (v / d if d > 0.0001 else Vector2.DOWN) * r


## 사냥의 우두머리: 이 구역에서 나올 수 있는 적(hunt_kinds) 하나를 정예로, 체력은 hunt_hp배.
func _spawn_hunt() -> Enemy:
	var R := data.run
	var kinds: Array[StringName] = []
	for k in R.hunt_kinds:
		var id := StringName(k)
		if data.enemies.has(id) and _can_appear(id):
			kinds.append(id)
	var kind: StringName = kinds[rng.randi_range(0, kinds.size() - 1)] if not kinds.is_empty() else &"wraith"
	var e := _spawn(kind)
	e.elite = true
	e.hunt = true
	e.max_hp *= R.hunt_hp
	e.hp = e.max_hp
	e.damage *= R.elite_damage
	e.radius *= R.elite_size
	hunt_boss = e
	return e


## 그 종류가 지금 구역의 밤에 나올 수 있는지.
func _can_appear(kind: StringName) -> bool:
	match kind:
		&"wraith", &"wolf":
			return true
		&"giant":
			return zone >= 1
	return RunData.EXTRA_KINDS.has(kind) and data.run.extra_chance(kind, zone) > 0.0


## 포위: siege_switch초마다 다른 변으로.
func _step_siege() -> void:
	if siege < 0:
		return
	siege_left -= dt
	if siege_left > 0.0:
		return
	siege_left += data.run.siege_switch
	var n: int = rng.randi_range(0, 2)
	siege = n if n < siege else n + 1
	siege_side.emit(siege)


## 무덤: 쓰러진 망령(우두머리·언덕지기·이미 일어난 것은 빼고)이 grave_chance로 grave_delay초 뒤 다시 일어난다.
func _note_grave(e: Enemy) -> void:
	var R := data.run
	if rule != &"graves" or phase != Phase.NIGHT or not e.data.wraith or e.risen or e.hunt or e.data.boss:
		return
	if rng.randf() < R.grave_chance:
		graves.append({"at": e.pos, "t": R.grave_delay, "kind": e.data.id, "hp": e.max_hp * R.grave_hp})


func _step_graves() -> void:
	if graves.is_empty():
		return
	var keep: Array[Dictionary] = []
	var rise: Array[Dictionary] = []
	for g in graves:
		g.t -= dt
		if g.t > 0.0:
			keep.append(g)
		else:
			rise.append(g)
	graves = keep
	for g in rise:
		var e := spawn_at(g.kind, g.at)
		e.risen = true
		e.max_hp = g.hp
		e.hp = g.hp
		grave_rise.emit(g.at)


## 불씨 땅: ember_every초마다 ember_count곳이 ember_warn초 미리 보이고 ember_burn초 동안 탄다.
## 안에 있으면 영주는 초당 ember_lord(겹쳐도 한 번), 적은 초당 ember_enemy.
func _step_embers() -> void:
	if rule != &"embers":
		return
	var R := data.run
	_ember_t -= dt
	if _ember_t <= 0.0:
		_ember_t += R.ember_every
		if night_left > 0.0:
			var size := Vector2(Grid.size)
			for i in R.ember_count:
				var at := Vector2(rng.randf_range(2.0, size.x - 2.0), rng.randf_range(2.0, size.y - 2.0))
				embers.append({"at": at, "warn": R.ember_warn, "burn": R.ember_burn})
				ember_warn.emit(at, R.ember_radius, R.ember_warn)
	var lit: Array[Vector2] = []
	var keep: Array[Dictionary] = []
	for f in embers:
		if f.warn > 0.0:
			f.warn -= dt
			if f.warn <= 0.0:
				ember_burn.emit(f.at, R.ember_radius, R.ember_burn)
			keep.append(f)
			continue
		f.burn -= dt
		if f.burn > 0.0:
			keep.append(f)
			lit.append(f.at)
	embers = keep
	if lit.is_empty():
		return
	for e in enemies.duplicate():
		if e.dead:
			continue
		for at in lit:
			if e.pos.distance_to(at) <= R.ember_radius:
				hurt(e, R.ember_enemy * dt, Vector2.ZERO, false, true)
				break
	for at in lit:
		if lord.pos.distance_to(at) <= R.ember_radius:
			_burn_lord(R.ember_lord * dt)
			break


## 불에 타는 영주: 무적·돌진과 상관없이 조금씩 닳는다. 맞음 신호는 1초 몫이 쌓일 때마다 한 번.
func _burn_lord(d: float) -> void:
	if debug_god or phase != Phase.NIGHT:
		return
	lord.hp -= d
	_burn_acc += d
	if _burn_acc >= maxf(1.0, data.run.ember_lord):
		lord_hurt.emit(_burn_acc)
		_burn_acc = 0.0
	if lord.hp <= 0.0 and not powers.save_from_death():
		lord_died()


# ---------------------------------------------------------------- 갈림길(13단계)

## 새벽: 다음 구역의 길 두 개를 보이고 고를 때까지 기다린다(시간이 멈추고 손잡이도 없다).
func _offer_path() -> void:
	phase = Phase.DAY
	hilts.clear()
	altar = null
	event = null
	path_cards = make_path_cards()
	path_open = true
	path_offered.emit(path_cards)


## 길 두 개: {goal, rule, reward}. 2~9구역은 목표와 구역 규칙을 RunData 목록에서 고르고(두 길이 같지 않게),
## 마지막 구역은 둘 다 언덕지기(버티기, 규칙 없음)이고 보상만 다르다. 어려운 길일수록 좋은 보상이 잘 붙는다.
func make_path_cards() -> Array[Dictionary]:
	var R := data.run
	var out: Array[Dictionary] = []
	for k in 2:
		var g: StringName = &"survive"
		var z: StringName = &""
		if zone > 0 and not last_zone() and not R.night_goals.is_empty():
			for tries in 12:
				g = StringName(R.night_goals[rng.randi_range(0, R.night_goals.size() - 1)])
				z = StringName(R.zone_rules[rng.randi_range(0, R.zone_rules.size() - 1)]) if not R.zone_rules.is_empty() else &""
				if k == 0 or g != out[0].goal or z != out[0].rule:
					break
		var avoid: StringName = out[0].reward if k == 1 else &""
		out.append({"goal": g, "rule": z, "reward": roll_path_reward(R.path_hardness(g, z), avoid)})
	return out


## 그 어려움(0~2)의 길에 붙을 보상 하나. avoid는 뺀다(두 길의 보상이 겹치지 않게).
func roll_path_reward(hard: int, avoid: StringName = &"") -> StringName:
	var R := data.run
	var w := R.path_weights(hard)
	var total: float = 0.0
	for i in w.size():
		if StringName(R.path_rewards[i]) == avoid:
			w[i] = 0.0
		total += w[i]
	if total <= 0.0:
		return &""
	var x: float = rng.randf() * total
	for i in w.size():
		x -= w[i]
		if x < 0.0:
			return StringName(R.path_rewards[i])
	return StringName(R.path_rewards[w.size() - 1])


## 길을 고른다(0, 1). 틱 사이에 부른다. 다음 밤의 목표·규칙을 정하고 보상을 받아 낮을 연다.
func choose_path(i: int) -> void:
	if not path_open or i < 0 or i >= path_cards.size():
		return
	var c: Dictionary = path_cards[i]
	path_open = false
	set_next_night(c.goal, c.rule)
	path_log.append({"zone": zone, "goal": c.goal, "rule": c.rule, "reward": c.reward})
	path_cards = []
	path_chosen.emit(i, c)
	_new_day(c.reward)


## 고른 길의 보상(낮이 열릴 때): 공짜 뽑기, 체력, 두 칸 검 내구, 이 낮의 운, 판이 끝날 때의 조각.
func _apply_path_reward(reward: StringName) -> void:
	var R := data.run
	path_reward = reward
	match reward:
		&"pulls":
			free_pulls = mini(R.max_free_pulls, free_pulls + R.reward_pulls)
		&"heal":
			lord.hp = minf(max_hp(), lord.hp + R.reward_heal)
		&"whet":
			for s in slots:
				if s and s.breakable():
					s.durability = s.max_durability
			slots_changed.emit()
		&"luck":
			day_luck = R.reward_luck
		&"shards":
			path_shards += R.reward_shards


# ---------------------------------------------------------------- 낮 사건(13단계)

## 이 구역부터 낮마다 사건 하나. 저주받은 손잡이는 낮의 손잡이 하나에 붙고, 나머지는 손잡이·제단·영주와 떨어진 자리에 선다.
func _place_event() -> void:
	var R := data.run
	event = null
	if zone < R.event_from_zone or R.event_kinds.is_empty():
		return
	var ev := DayEvent.new()
	ev.id = _new_id()
	ev.kind = StringName(R.event_kinds[rng.randi_range(0, R.event_kinds.size() - 1)])
	if ev.kind == &"cursed":
		if hilts.is_empty():
			return
		var h := hilts[rng.randi_range(0, hilts.size() - 1)]
		h.cursed = true
		ev.hilt = h
		ev.pos = h.pos
	else:
		var clear: float = R.event_reach + R.pull_reach
		for tries in 60:
			ev.pos = Vector2(rng.randf_range(3.0, R.arena_size.x - 3.0), rng.randf_range(3.0, R.arena_size.y - 3.0))
			if ev.pos.distance_to(lord.pos) >= 3.0 and hilts.all(func(h: Hilt) -> bool: return h.pos.distance_to(ev.pos) >= clear) and (altar == null or altar.pos.distance_to(ev.pos) >= R.altar_reach + R.event_reach):
				break
	event = ev


## E로 쓸 수 있는 가까운 사건(저주받은 손잡이는 뽑기로 쓴다). 없으면 null.
func near_event() -> DayEvent:
	if event == null or event.used or event.kind == &"cursed" or phase != Phase.DAY:
		return null
	return event if event.pos.distance_to(lord.pos) < data.run.event_reach else null


## 지금 그 사건을 쓸 수 있는지. 못 쓰면 까닭(화면의 알림), 쓸 수 있으면 "".
func event_block(ev: DayEvent) -> String:
	var R := data.run
	match ev.kind:
		&"smith":
			if current() == null:
				return "벼릴 검을 쥐고 있지 않다."
			if lord.hp <= R.smith_cost:
				return "체력이 모자라. 대장장이에게 낼 체력이 없다."
		&"pilgrim":
			if pilgrim_slot() < 0:
				return "바칠 검이 없다."
		&"seer":
			if lord.hp <= R.seer_cost:
				return "체력이 모자라. 점쟁이에게 낼 체력이 없다."
	return ""


## 순례자에게 바칠 칸: 쥐지 않은 칸, 그 칸이 비면 쥔 칸. 둘 다 비면 -1.
func pilgrim_slot() -> int:
	if slots[1 - active] != null:
		return 1 - active
	return active if slots[active] != null else -1


func _use_event(ev: DayEvent) -> void:
	var R := data.run
	var why := event_block(ev)
	if why != "":
		pull_refused.emit(why)
		return
	var result := {}
	match ev.kind:
		&"smith":
			var s := current()
			lord.hp -= R.smith_cost
			if s.breakable():
				s.durability = s.max_durability
			s.night_bonus = 1.0 + R.smith_damage
			result = {"sword": s, "cost": R.smith_cost, "damage": R.smith_damage}
		&"pilgrim":
			var k := pilgrim_slot()
			var s := slots[k]
			slots[k] = null
			if k == active and slots[1 - k] != null:
				active = 1 - k
			lord.combo = 0
			var before: float = lord.hp
			lord.hp = minf(max_hp(), lord.hp + max_hp() * R.pilgrim_heal)
			free_pulls = mini(R.max_free_pulls, free_pulls + R.pilgrim_free)
			result = {"sword": s, "slot": k, "heal": lord.hp - before, "free": R.pilgrim_free}
		&"seer":
			lord.hp -= R.seer_cost
			seer_used_today = true
			# 오늘 손잡이의 겉 조짐이 참된 조짐이 된다(14단계)
			for h in hilts:
				h.revealed = true
			result = {"cost": R.seer_cost}
	ev.used = true
	run_stats.events_used += 1
	event_used.emit(ev, result)
	event_gone.emit(ev)
	if ev.kind == &"seer":
		omens_revealed.emit()
	if ev.kind == &"pilgrim" or ev.kind == &"smith":
		slots_changed.emit()


## 저주받은 손잡이를 다 뽑았다: 뽑은 검의 최대 내구가 절반, 이번 밤 적이 강해진다(spawn_at).
func _cursed_pulled(h: Hilt, s: Sword) -> void:
	var R := data.run
	if s.breakable():
		s.max_durability = maxf(1.0, roundf(s.max_durability * R.cursed_durability))
		s.durability = s.max_durability
	cursed_night = true
	var ev := event if event and event.hilt == h else null
	if ev == null:
		return
	ev.used = true
	event_used.emit(ev, {"sword": s, "max_durability": s.max_durability})
	event_gone.emit(ev)


# ---------------------------------------------------------------- 제단

func near_altar() -> bool:
	return altar != null and not altar.used and phase == Phase.DAY and altar.pos.distance_to(lord.pos) < data.run.altar_reach


## 지금 할 수 있는 일. kind: melt(그 칸의 검을 조각으로), repair(다른 칸을 바쳐 쥔 검 내구를 채움), transfer(다른 칸을 바쳐 그 각인 하나를 쥔 검에).
func altar_options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k in 2:
		if slots[k]:
			out.append({"kind": "melt", "slot": k})
	var s := current()
	var o := slots[1 - active]
	if s and o:
		if s.breakable() and s.durability < s.max_durability:
			out.append({"kind": "repair"})
		var n: int = 0
		for key in o.ins:
			if not s.ins.has(key) and n < 2:
				out.append({"kind": "transfer", "key": key})
				n += 1
	return out


## 고른 일을 한다. -1이면 그냥 닫는다(제단은 남는다).
func use_altar(i: int) -> void:
	if not altar_open:
		return
	altar_open = false
	var opts := altar_options()
	if i < 0 or i >= opts.size():
		return
	var o: Dictionary = opts[i]
	var s := current()
	var other_k: int = 1 - active
	var text: String = ""
	match o.kind:
		"melt":
			var k: int = o.slot
			var w := slots[k]
			slots[k] = null
			melted_by_grade[w.grade] += 1
			if k == active and slots[1 - k] != null:
				active = 1 - k
			text = w.label()
		"repair":
			slots[other_k] = null
			s.durability = s.max_durability
			text = s.label()
		"transfer":
			slots[other_k] = null
			s.add_ins(o.key, data)
			text = o.key
	altar.used = true
	lord.combo = 0
	altar_used.emit(o.kind, text)
	slots_changed.emit()


func _new_id() -> int:
	_next_id += 1
	return _next_id


## 같은 시드·같은 입력이면 같은 값이 나와야 한다(테스트용).
func state_hash() -> int:
	var parts: Array = [tick, zone, phase, lord.pos, lord.hp, kills, pulls, active, enemies.size(), hilts.size(), rng.state, free_pulls, elites_killed, altar.used if altar else null, lord.combo, lord.move, moves.events.size()]
	for p in projectiles:
		parts.append(p.pos)
	for p in enemy_projectiles:
		parts.append(p.pos)
	parts.append(tokens.cooling)
	parts.append(lord.push)
	parts.append(callers_out)
	parts.append_array([goal, rule, next_goal, next_rule, night_total, beacon_hp, beacon_lost, hunt_out, hunt_killed, siege, siege_left, _ember_t, goal_shards])
	for f in embers:
		parts.append_array([f.at, f.warn, f.burn])
	for g in graves:
		parts.append_array([g.at, g.t, g.kind, g.hp])
	for e in enemies:
		parts.append(e.pos)
		parts.append(e.hp)
		parts.append(e.token)
		parts.append(e.act)
		parts.append(e.act_t)
		parts.append(e.guard_down)
		parts.append(e.summoned)
		parts.append_array([e.beacon, e.hunt, e.risen])
	for s in slots:
		parts.append(s.data.id if s else -1)
		parts.append(s.durability if s else -1.0)
		parts.append(s.max_durability if s else -1.0)
		parts.append(s.night_bonus if s else -1.0)
	parts.append_array([path_open, path_shards, day_luck, path_reward, path_log.size(), seer_used_today, cursed_night])
	for c in path_cards:
		parts.append_array([c.goal, c.rule, c.reward])
	if event:
		parts.append_array([event.kind, event.pos, event.used])
	for h in hilts:
		if h.cursed:
			parts.append_array([h.id, h.gone])
		parts.append_array([h.omen, h.shown_omen, h.revealed])
	parts.append_array([run_stats.kills, run_stats.zones, run_stats.elites, run_stats.perfect, run_stats.events_used, str(run_stats.kills_by_kind), str(run_stats.goals_done), str(run_stats.pulled_by_grade), pack.size()])
	if field:
		parts.append(str(packs))
		for e in enemies:
			parts.append_array([e.pack, e.home, e.wander_to, e.wander_t])
	parts.append_array([pull_t, pull_steps, pull_judged, pull_goods, pull_win_step, pull_all_good])
	return hash(str(parts))
