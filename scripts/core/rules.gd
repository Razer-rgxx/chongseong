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
## 21단계 1대1 결투(start_duel, step_duel, docs/duel.md): lords 둘, 영주마다 DuelSeat(검 칸·좌클릭 동작·날아가는 것)를 갈아 끼워 돌린다.
## 14단계 뽑기 손맛: 버팀 타이밍(pull_window·pull_good·pull_perfect·pull_miss, LordInput.pull_press)과 손잡이 조짐(Hilt.omen, 운 배수).

signal day_started(zone: int)
## 언덕 재설계(docs/hill_events.md): 검의 사건이 시작됐다(kind = HillZone.Event), 거래가 걸렸다, 사건이 끝났다.
signal hz_event(zi: int, kind: int)
signal hz_offer_made(zi: int, ask: StringName)
signal hz_done(zi: int, won: bool)
signal hz_woke(zi: int)
signal night_started(zone: int)
signal run_ended(won: bool)
signal pull_started(hilt: Hilt, grade: int)
signal pull_step(hilt: Hilt, step: int)
signal pull_refused(reason: String)
signal sword_pulled(sword: Sword)
## 밤의 발검(docs/sword_hill.md 1번): 꽂힌 검(hilt)에서 sword를 뽑았다. planted는 쥐고 있던 검을 꽂은 새 손잡이(맨손이었으면 null).
signal sword_drawn(sword: Sword, hilt: Hilt, planted: Hilt)
## 발검 반격이 됐다(뽑는 순간 맞으려 했다): 피해 없이 둘레를 크게 베고 뽑기 값을 돌려받았다.
signal draw_countered(at: Vector2)
## 검 주인의 잔영(docs/sword_hill.md 2번): 나타남, 휘두름(큰 베기면 big), 사라짐.
signal ghost_spawned(g: Ghost)
signal ghost_swung(g: Ghost, big: bool)
signal ghost_gone(g: Ghost)
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
## 걸어 다니는 점프(30단계): 뛰었다 / 내려앉았다(at은 내려앉은 자리, 칸). 화면이 몸을 띄우고 흙먼지와 발소리를 낸다.
signal lord_jumped()
signal lord_landed(at: Vector2)
## 갈고리를 걸었다(날아가기 시작).
signal lord_hooked(target: Enemy)
## 39단계 말: 불렀다(달려오기 시작), 곁에 다 왔다, 탔다, 내렸다(fell: 맞아서 떨어졌다).
signal horse_called()
signal horse_arrived()
signal horse_mounted()
signal horse_dismounted(fell: bool)
signal lord_hurt(damage: float)
signal enemy_spawned(enemy: Enemy)
signal enemy_hit(enemy: Enemy, damage: float, big: bool)
signal enemy_died(enemy: Enemy)
## 들판(17단계): 무리가 덤볐다, 제자리로 돌아간다, 무리를 다 쓰러뜨렸다(id).
signal pack_engaged(id: StringName)
signal pack_returned(id: StringName)
signal pack_cleared(id: StringName)
## 들판 보스(18단계): 깨어났다, 제자리로 돌아갔다(체력이 다 찼다), 쓰러졌다.
## 들판 낮밤(29단계): 해가 졌다(밤 무리가 선다) / 날이 밝았다(쓰러뜨린 낮 무리가 다시 서고 밤 무리가 사라진다).
signal field_dusk
signal field_dawn
signal field_boss_woke(e: Enemy)
signal field_boss_returned(e: Enemy)
signal field_boss_slain(e: Enemy)
## 곳마다 우두머리(32단계): 깨어남, 돌아가 다시 잠, 쓰러뜨림(id는 FieldLayout.CHIEFS).
signal chief_woke(id: StringName, e: Enemy)
signal chief_returned(id: StringName, e: Enemy)
signal chief_slain(id: StringName, e: Enemy)
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
## 결투(21단계): 판이 시작됐다(n은 1부터) / 판이 끝났다(winner: 0, 1, 비김은 -1) / 결투가 끝났다(winner 같음) / 영주가 맞았다(seat, 피해, 큰 베기인지).
signal duel_round_started(n: int)
signal duel_round_ended(winner: int)
signal duel_over(winner: int)
signal duelist_hurt(seat: int, damage: float, big: bool)

enum Phase { DAY, NIGHT, OVER }

## ---- 언덕 재설계(docs/hill_events.md, 2026-11-22). 첫 구역에서만 켠다(시험) ----
## 시험이라 기본은 끈다. main.gd가 언덕 판을 만들기 전에 events_default를 켠다(옛 테스트는 예전 첫 구역).
static var events_default: bool = false
var use_hill_events: bool = events_default
var hz: HillZone = null
## 적 id → 검 번호, 검 번호 → 남은 적 수, 검 번호 → 이기면 받을 검.
var hz_foes: Dictionary = {}
var hz_left: Dictionary = {}
var hz_prize: Dictionary = {}
## 걸린 거래 {zi, ask}. 비어 있으면 없음. ask: &"sword" | &"max_hp" | &"durability"
var hz_offer: Dictionary = {}
var hz_max_hp_cut: float = 0.0
## 쓴 머리(Heads.info). 비면 없음. 결투에서는 꺼진다. save는 판마다 한 번.
var head: Dictionary = {}
var head_saved: bool = false
## 지도(HillZone 칸) → 싸움터 칸 배율.
var hz_scale: Vector2 = Vector2.ONE
## 플레이 기록용: 뽑은 순서(검 번호), 사건별 승, 정산 때 온 주인 수, 거래 받음/거절.
var hz_log: Dictionary = {"order": [], "won": {}, "reckoned": 0, "trade_yes": 0, "trade_no": 0}

## 결투의 한 판 단계: 시작 전 서 있기 → 싸움 → 판 사이 쉼 → 끝.
const DUEL_READY: int = 0
const DUEL_FIGHT: int = 1
const DUEL_BETWEEN: int = 2
const DUEL_DONE: int = 3
## duel_winner가 아직 정해지지 않았다 / 비겼다.
const DUEL_NONE: int = -2
const DUEL_DRAW: int = -1

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
## 판을 시작한 구역(0부터, 마을 키우기 5단계). 1구역부터 오르면 0.
var start_zone: int = 0
## 풀무간이 벼린 검이 든 칸(없으면 -1).
var forged: int = -1
## 새벽까지 남은 시간(초). 0 아래로 내려가도 마지막 구역에서는 언덕지기를 쓰러뜨릴 때까지 밤이다.
var night_left: float = 0.0
## 이 밤의 길이(초). 포위는 짧다.
var night_total: float = 0.0
var lord := LordState.new()
## 영주들(21단계). 0은 lord와 같다. 결투가 아니면 하나뿐이다.
var lords: Array[LordState] = []
## 두 칸. 빈 칸은 null.
var slots: Array[Sword] = [null, null]
## swap(k)의 "다음 칸"(Q). 칸 번호(0~)와 겹치지 않게 큰 수(LordInput에는 swap_to + 1로 실린다).
const SWAP_NEXT: int = 9
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
## 39단계 말(docs/open_world2.md): 들판 장면만 allow_horse를 켠다(마을·언덕·무덤·결투에는 말이 없다). 말의 상태는 horse, 탄 상태는 lord.riding.
var allow_horse: bool = false
var horse := Horse.new()
## 1대1 결투(21단계, docs/duel.md). 켜면 낮밤·뽑기·적이 없고 영주 둘이 서로 벤다. 각인과 고유 능력은 듣지 않는다(Powers.off).
var duel: bool = false
var duel_phase: int = DUEL_READY
## 이 단계에 남은 시간(시작 전, 판 사이)과 이 판에 남은 시간(초).
var duel_timer: float = 0.0
var duel_left: float = 0.0
## 지금 몇 번째 판(1부터)과 영주마다 이긴 판 수, 판마다의 승자(0, 1, 비김 -1), 결투의 승자(DUEL_NONE이면 아직).
var duel_round: int = 0
var duel_wins: Array[int] = [0, 0]
var duel_results: Array[int] = []
var duel_winner: int = DUEL_NONE
## 지금 틱을 돌리는 영주(규칙의 lord·slots·moves·powers·projectiles·enemies가 이 자리의 것이다). 화면은 신호를 받을 때 이것으로 누구인지 안다.
var cur_seat: int = 0
var _seats: Array[DuelSeat] = []
## 상대 영주를 대신하는 그림자 적(영주 i의 몸). 이것을 맞히면 영주 i가 맞는다.
var _proxies: Array[Enemy] = []
var _proxy_at: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
## 마을 수련장(15단계): 켜면 낮에도 좌클릭이 먹고, 허수아비(still)가 규칙의 적으로 선다.
var yard: bool = false
## 들판 모드(17단계, docs/outside.md): 낮밤과 구역 시간이 흐르지 않고 밤 나오기가 없다. 적은 spawn_pack으로 자리에 둔다.
## 영주는 늘 "밤"(맞고 휘두른다)이고, 무리가 쓰러지거나 돌아가는 일은 _step_field가 맡는다.
var field: bool = false
## 들판 무리: id → {home, wander, zone(0부터), state, spawned, cleared, night}. state는 PACK_*. night는 밤에만 서는 무리(29단계).
var packs: Dictionary = {}
## 들판 시계(29단계): 켜져 있으면 틱마다 dt초씩 세고(FIELD_DAY + FIELD_NIGHT초마다 0으로 돌아감, 0은 아침) field_night(밤)이 바뀔 때 신호를 낸다.
## 지하 무덤은 켜지 않는다(시계 없음 = 늘 낮 규칙).
var field_clock_on: bool = false
var field_clock: float = 0.0
var field_night: bool = false
## 마지막으로 영주를 때린 적의 종류(플레이 기록용, state_hash에 넣지 않는다).
var last_hit_by: StringName = &""
## 들판 보스(18단계): 무덤 기사 한 마리. 상태는 BOSS_*(자는 중, 깨어남, 돌아가는 중, 쓰러뜨림).
var field_boss: Enemy = null
var field_boss_state: int = BOSS_SLEEP
var field_boss_home: Vector2 = Vector2.ZERO
## 불려 오는 적의 세기 구역(1부터). 들판은 FieldLayout.BOSS_ZONE, 지하 무덤은 방이 정한다.
var field_boss_zone: int = FieldLayout.BOSS_ZONE
## 곳마다 우두머리(32단계): FieldLayout.CHIEFS의 id → {e: Enemy, state: BOSS_*, home: 제자리, zone: 불려 오는 적의 세기 구역(1부터)}.
## 들판 보스(field_boss)와 같은 틀(깨어남 CHIEF_WAKE, 놓아줌 CHIEF_LEASH, 돌아가면 체력이 참)을 여럿으로. 무리(packs)와 따로 센다.
var chiefs: Dictionary = {}
## 적 길찾기(37단계, docs/open_world2.md): 장면이 쓰는 막힘 표(set_blockers)를 구운 격자와 흐름장. null이면 막힘이 없다
## (언덕 싸움터·결투·수련장: 적은 예전처럼 곧장 온다). 있으면 적은 막힘을 돌아서 오고, 틱 끝에 막힘 밖으로 밀린다.
var nav: Nav = null
const BOSS_SLEEP: int = 0
const BOSS_AWAKE: int = 1
const BOSS_RETURNING: int = 2
const BOSS_DOWN: int = 3
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
## 떠돌이 약초꾼을 영입했으면(34단계, Meta.recruit_hp) 최대 체력에 더한다. 판은 Meta에서 받고, 들판은 장면이 넣는다.
var bonus_hp: float = 0.0
## 검의 기억(Meta.memory_table): 검 번호 → 그 검으로 벨 때 피해 배수. 시작할 때 Meta에서 받는다.
var memory: Dictionary = {}


func _init(game_data: GameData, p_seed: int, p_meta: Meta = null) -> void:
	data = game_data
	meta = p_meta
	if meta:
		bonus_hp = meta.recruit_hp()
		memory = meta.memory_table()
	seed_value = p_seed
	rng.seed = p_seed
	dt = 1.0 / float(data.run.tick_rate)
	Grid.size = data.run.arena_size
	lords.append(lord)
	powers = Powers.new(self)
	moves = Moves.new(self)
	tokens = Tokens.new(self)
	foes = Foes.new(self)
	night_total = data.run.night_length
	lord.hp = max_hp()
	if meta and meta.start_zone > 1 and meta.start_zones(data).has(meta.start_zone):   # 마을 단계가 연 깊은 구역부터(마을 키우기 5단계)
		zone = clampi(meta.start_zone - 1, 0, zone_count() - 2)
		start_zone = zone
	path_log.append({"zone": zone, "goal": &"survive", "rule": &"", "reward": &""})
	_new_day()
	if meta:
		set_slot_count(meta.hill_slots())   # 검 보관집(2026-11-21)
		var s := meta.sheath_sword(data)
		if s:
			slots[0] = s
			active = 0
		if use_hill_events and meta.runs < 3 and slots.all(func(x): return x == null):
			slots[0] = starter_sword()   # 처음 세 판: 빈손으로 시작하지 않게(튜토리얼)
			active = 0
		var fg: int = meta.forge_grade(data)
		if fg >= 0:   # 풀무간(마을 키우기 5단계): 벼린 검 한 자루를 빈 칸에
			var at: int = slots.find(null)
			if at >= 0:
				slots[at] = Sword.new(pick_sword(fg), data)
				forged = at
		_apply_pack()
		if meta.head != "":
			head = Heads.info(meta.head, meta)
			lord.hp = max_hp()


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
	return _max_hp_base() - hz_max_hp_cut + (20.0 if _head_fx(&"maxhp") else 0.0)


func _head_fx(k: StringName) -> bool:
	return not head.is_empty() and not duel and head.get("fx") == k


func _max_hp_base() -> float:
	if duel:
		return data.duel.hp
	return data.lord.hp + _bless("hp") + bonus_hp + (data.village.goods_by_id(&"bread").value if pack.has(&"bread") else 0.0)


## 이번 발검에 쓴 체력(발검 반격이 되면 돌려준다).
var _draw_cost: float = 0.0
## 검 주인의 잔영들(밤에만 움직인다)과, 낮에 주인 있는 검을 뽑아 밤에 나올 잔영({"rec", "at"}).
var ghosts: Array[Ghost] = []
var _ghost_queue: Array[Dictionary] = []
## 이 판에서 이미 꽂은 주인 기록(같은 검이 두 번 나오지 않게).
var _owners_used: Array = []
## 언덕의 밤에 영주의 몸놀림을 적는 고리(틱마다 [x, y, 얼굴, 휘두름]). 쓰러지면 Meta.fallen으로.
var _rec := PackedFloat32Array()
var _rec_head: int = 0
var _rec_len: int = 0


func pull_cost() -> float:
	return maxf(1.0, data.run.pull_cost - _bless("cost") - (powers.pull_discount() if powers else 0.0))


func heal_at_dawn() -> float:
	return data.run.heal_per_dawn + _bless("heal")


func zone_count() -> int:
	return data.run.zone_names.size()


func last_zone() -> bool:
	return zone == zone_count() - 1


## 검의 기억에 따른 피해 배수(없으면 1).
func memory_mult(s: Sword) -> float:
	return float(memory.get(s.data.id, 1.0)) if s and s.data else 1.0


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
	lord.prev_air = lord.air
	horse.prev_pos = horse.pos
	for e in enemies:
		e.prev_pos = e.pos
	for p in projectiles:
		p.prev_pos = p.pos
	for p in enemy_projectiles:
		p.prev_pos = p.pos
	for g in ghosts:
		g.prev_pos = g.pos
	if freeze > 0:
		freeze -= 1
		return
	if pending != null or altar_open or path_open or not hz_offer.is_empty():
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
		_step_horse()
		_step_field()
		if phase == Phase.NIGHT:
			_step_enemies()
		if phase == Phase.NIGHT:
			foes.step_arrows(dt)
		return
	if phase == Phase.DAY and hz:
		_step_hz()
		return
	if phase == Phase.NIGHT:
		if not duel and not yard:
			_record_frame()
		_step_night()
		if phase == Phase.NIGHT:
			_step_enemies()
		if phase == Phase.NIGHT:
			_step_ghosts()
		if phase == Phase.NIGHT:
			foes.step_arrows(dt)


# ---------------------------------------------------------------- 낮과 밤

## 낮에만. 뽑는 중이거나 고르는 중이면 못 한다.
func start_night() -> void:
	if phase != Phase.DAY or pull_hilt != null or pending != null or altar_open or path_open:
		return
	var R := data.run
	phase = Phase.NIGHT
	_hz_reckon()
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
	# 낮에 뽑지 않은 검은 밤에도 꽂혀 있다(발검 자리, docs/sword_hill.md 1번)
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
	# 낮에 뽑은 주인 있는 검의 잔영은 밤이 오는 순간 영주 곁에 나온다
	var q := _ghost_queue
	_ghost_queue = []
	for k in q.size():
		_spawn_ghost(q[k].rec, _clamp_cells(lord.pos + Vector2.from_angle(lord.face + PI * 0.5 + k) * 1.2))
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
	# 꽂아 둔(아는) 검은 새벽에도 남는다. 나머지 손잡이는 새로 꽂힌다.
	var planted: Array[Hilt] = []
	for h in hilts:
		if not h.gone and h.sword != null:
			planted.append(h)
	hilts.clear()
	hilts.append_array(planted)
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
	_hz_setup()
	altar = null
	if zone >= R.altar_from_zone:
		var a := Altar.new()
		for tries in 60:
			a.pos = Vector2(rng.randf_range(3.0, R.arena_size.x - 3.0), rng.randf_range(3.0, R.arena_size.y - 3.0))
			if a.pos.distance_to(lord.pos) >= 3.0 and hilts.all(func(h: Hilt) -> bool: return h.pos.distance_to(a.pos) >= 1.8):
				break
		altar = a
	_place_event()
	_place_owner()
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
	for g in ghosts:
		ghost_gone.emit(g)
	ghosts.clear()
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
	# 꽂아 둔 검: 무엇인지 아니 버티지 않고 값 없이 바로 뽑는다
	if h.sword != null:
		h.gone = true
		var known: Sword = h.sword
		sword_pulled.emit(known)
		_receive(known)
		return
	# 주인 있는 검: 무엇인지 보이니 버티지 않고 바로 뽑는다(값은 보통 뽑기와 같다). 잔영은 밤이 오면 나온다
	if not h.owner.is_empty():
		var owner_free: bool = free_pulls > 0
		if not owner_free and lord.hp <= pull_cost():
			pull_refused.emit("체력이 모자라. 더 뽑으면 쓰러진다.")
			return
		if owner_free:
			free_pulls -= 1
		else:
			lord.hp -= pull_cost()
		h.gone = true
		var os := _owner_sword(h)
		pulls += 1
		run_stats.pulled_by_grade[os.grade] += 1
		best_grade = maxi(best_grade, os.grade)
		powers.on_pulled(os)
		sword_pulled.emit(os)
		_receive(os)
		_owner_pulled(h)
		return
	# 저주받은 손잡이는 체력도 공짜 뽑기도 쓰지 않는다
	_pull_cursed = h.cursed
	_pull_free = not _pull_cursed and free_pulls > 0
	if not _pull_free and not _pull_cursed and lord.hp <= pull_cost():
		pull_refused.emit("체력이 모자라. 더 뽑으면 쓰러진다.")
		return
	pull_hilt = h
	pull_grade = debug_grade if debug_grade >= 0 else roll_grade(pull_luck(h))
	if h.zi >= 0 and hz:
		pull_grade = hz.blades[h.zi].final_grade(data.grades.names.size() - 1)
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


## 밤의 발검(docs/sword_hill.md 1번): 꽂힌 검 앞에서 E. 쥔 검을 그 자리에 꽂고(아는 검이 된다) 새 검을 뽑으며 벤다.
## 뽑는 순간부터 draw 동작의 시간 동안 맞으면 발검 반격(Moves.parried): 피해 없이 둘레를 크게 베고 뽑기 값을 돌려받는다.
## 값: 모르는 검은 낮처럼 체력(공짜 뽑기가 있으면 그것), 꽂아 둔 검은 공짜. 저주받은 손잡이는 체력 없이(밤이라 저주는 걸리지 않는다).
## 굴림은 낮 뽑기와 같다(운, 조짐). 버팀 타이밍은 없다. 두 칸 고르기 창도 없다: 쥔 칸이 바뀐다.
func _try_draw() -> void:
	var L := lord
	if L.move_lock > 0.0 or L.parry > 0.0 or L.dash > 0.0 or L.hook > 0.0 or moves.steering() or L.riding:
		return
	var h := nearest_hilt(data.run.pull_reach)
	if h == null:
		return
	var cost: float = 0.0
	var s: Sword = h.sword
	var free_pull: bool = false
	if s == null:
		free_pull = free_pulls > 0 and not h.cursed
		if not free_pull and not h.cursed:
			cost = pull_cost()
			if L.hp <= cost:
				pull_refused.emit("체력이 모자라. 더 뽑으면 쓰러진다.")
				return
		if not h.owner.is_empty():
			s = _owner_sword(h)
		else:
			s = Sword.new(pick_sword(debug_grade if debug_grade >= 0 else roll_grade(pull_luck(h))), data)
		if free_pull:
			free_pulls -= 1
		L.hp -= cost
		pulls += 1
		run_stats.pulled_by_grade[s.grade] += 1
		best_grade = maxi(best_grade, s.grade)
		powers.on_pulled(s)
	h.gone = true
	var old: Sword = slots[active]
	var planted: Hilt = null
	if old != null:
		planted = Hilt.new()
		planted.id = _new_id()
		planted.pos = h.pos
		planted.tilt = rng.randf_range(-0.25, 0.25)
		planted.sword = old
		hilts.append(planted)
	slots[active] = s
	_draw_cost = cost
	slots_changed.emit()
	sword_drawn.emit(s, h, planted)
	if not h.owner.is_empty():
		_owner_pulled(h)
	moves.draw_strike()


# ---------------------------------------------------------------- 검의 주인과 잔영 (docs/sword_hill.md 2번)

## 낮마다 owner_chance로 손잡이 하나를 주인 있는 검으로(이 판에서 아직 안 나온 Meta.fallen 기록 하나).
func _place_owner() -> void:
	var R := data.run
	if meta == null or (meta.fallen.is_empty() and meta.others.is_empty()) or zone < R.owner_from_zone or field or yard or duel:
		return
	if rng.randf() >= R.owner_chance:
		return
	var pool: Array = []
	# 다른 영주의 검(받아 둔 것이 있을 때 other_chance), 아니면 내 지난 판의 검
	var src: Array = meta.fallen
	if not meta.others.is_empty() and (meta.fallen.is_empty() or rng.randf() < R.other_chance):
		src = meta.others
	for rec in src:
		if not _owners_used.has(rec) and data.sword_by_id(int(rec.get("id", 0))) != null:
			pool.append(rec)
	var cands: Array[Hilt] = []
	for h in hilts:
		if h.sword == null and not h.cursed and not h.gone:
			cands.append(h)
	if pool.is_empty() or cands.is_empty():
		return
	var rec: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	_owners_used.append(rec)
	cands[rng.randi_range(0, cands.size() - 1)].owner = rec


## 주인 있는 검에서 나오는 검(굴리지 않는다).
func _owner_sword(h: Hilt) -> Sword:
	var sd := data.sword_by_id(int(h.owner.get("id", 0)))
	return Sword.new(sd if sd else pick_sword(0), data)


## 주인 있는 검을 뽑았다: 밤이면 그 자리에 잔영이 바로, 낮이면 밤이 오는 순간.
func _owner_pulled(h: Hilt) -> void:
	if h.owner.has("name") and str(h.owner.name) != "":
		head_found.emit("p:" + str(h.owner.name))   # 다른 영주의 검: 그 사람 머리의 사본
	if phase == Phase.NIGHT:
		_spawn_ghost(h.owner, h.pos)
	else:
		_ghost_queue.append({"rec": h.owner, "at": h.pos})


func _spawn_ghost(rec: Dictionary, at: Vector2) -> void:
	var f := PackedFloat32Array()
	for v in rec.get("ghost", []):
		f.append(float(v))
	if f.size() < 8:
		return
	var g := Ghost.new()
	g.id = _new_id()
	g.sword_id = int(rec.get("id", 0))
	g.frames = f
	g.offset = at - Vector2(f[0], f[1])
	g.pos = at
	g.prev_pos = at
	g.face = f[2]
	ghosts.append(g)
	ghost_spawned.emit(g)


## 잔영마다 한 틱: 기록을 읽어 옮기고, 휘두름이 적힌 틱이면 앞을 벤다. 다 움직였으면 사라진다.
func _step_ghosts() -> void:
	var k: int = 0
	while k < ghosts.size():
		var g := ghosts[k]
		if g.done():
			ghosts.remove_at(k)
			ghost_gone.emit(g)
			continue
		var j: int = g.i * 4
		g.pos = _clamp_cells(Vector2(g.frames[j], g.frames[j + 1]) + g.offset)
		g.face = g.frames[j + 2]
		var act: int = roundi(g.frames[j + 3])
		g.i += 1
		if act > 0:
			_ghost_swing(g, act == 2)
		k += 1


## 잔영의 한 칼: 주인 검의 등급·형태로 앞 부채꼴(ghost_reach × 형태 사거리, ghost_arc)을 벤다. 아주 가까운 적도.
func _ghost_swing(g: Ghost, big: bool) -> void:
	var R := data.run
	var sd := data.sword_by_id(g.sword_id)
	if sd == null:
		return
	var F: FormData = data.forms[sd.form]
	var dmg: float = data.lord.damage * data.grades.damage_mult[sd.grade] * F.damage * R.ghost_damage * (data.lord.big_damage_mult if big else 1.0)
	var reach: float = R.ghost_reach * F.reach
	for e in enemies.duplicate():
		if e.dead:
			continue
		var to: Vector2 = e.pos - g.pos
		var d: float = to.length()
		if d > reach + e.radius:
			continue
		if d > e.radius + 0.35 and absf(angle_difference(g.face, to.angle())) > R.ghost_arc * 0.5:
			continue
		hurt(e, dmg, (to / maxf(d, 0.001)) * data.lord.knockback * F.knockback * 0.6, big, false, g.pos)
	ghost_swung.emit(g, big)


## 언덕의 밤에 영주의 한 틱을 적는다(ghost_ticks만큼 돌아가며). 휘두름: 이 틱에 좌클릭이 시작됐으면 1, 큰 베기면 2.
func _record_frame() -> void:
	var n: int = maxi(2, data.run.ghost_ticks)
	if _rec.size() != n * 4:
		_rec.resize(n * 4)
		_rec_head = 0
		_rec_len = 0
	var L := lord
	var act: int = 0
	if L.swing > data.lord.swing_time - dt * 0.5:
		act = 2 if L.big else 1
	var j: int = _rec_head * 4
	_rec[j] = L.pos.x
	_rec[j + 1] = L.pos.y
	_rec[j + 2] = L.face
	_rec[j + 3] = act
	_rec_head = (_rec_head + 1) % n
	_rec_len = mini(n, _rec_len + 1)


## 적어 둔 몸놀림을 오래된 것부터(쓰러진 순간이 끝).
func recorded() -> Array:
	var out: Array = []
	var n: int = _rec.size() / 4
	if n == 0:
		return out
	var start: int = (_rec_head - _rec_len + n) % n
	for k in _rec_len:
		var j: int = ((start + k) % n) * 4
		out.append_array([snappedf(_rec[j], 0.01), snappedf(_rec[j + 1], 0.01), snappedf(_rec[j + 2], 0.01), _rec[j + 3]])
	return out


## 언덕에서 쓰러졌다: 쥐고 있던 검과 이 판의 기록, 마지막 몇 초를 Meta.fallen에 남긴다(맨손이면 남길 검이 없다).
func _leave_fallen() -> void:
	if meta == null or field or duel or yard:
		return
	var s := current()
	if s == null or s.data == null:
		return
	meta.add_fallen({"id": s.data.id, "run": meta.runs, "zone": zone, "kills": kills, "ghost": recorded()})


## Moves.parried가 발검 반격 때 부른다: 뽑기 값을 돌려받는다.
func _draw_countered() -> void:
	lord.hp = minf(max_hp(), lord.hp + _draw_cost)
	_draw_cost = 0.0
	draw_countered.emit(lord.pos)


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
	var s := Sword.new(pick_sword(pull_grade), data)
	powers.on_pulled(s)
	# 모두 제대로 당겼다: 최대 내구 +10%(반올림, 적어도 1). 언덕의 첫 검 뒤, 저주의 절반 앞
	if pull_all_good and s.breakable():
		s.max_durability = maxf(s.max_durability + 1.0, roundf(s.max_durability * (1.0 + R.pull_perfect_durability)))
		s.durability = s.max_durability
	if _pull_cursed:
		_pull_cursed = false
		_cursed_pulled(h, s)
	if h.zi >= 0 and hz:
		_hz_begin(h.zi, s)
		return
	sword_pulled.emit(s)
	_receive(s)


## 운명 베기: 낮에 뽑은 검을 다시 뽑는다(Uniques.fate_reroll). 된 일이면 true.
func fate_reroll() -> bool:
	return powers.U.fate_reroll()


## 그 등급에서 뽑힐 검 하나(rng). 후보는 GameData.swords_by_grade라 오픈월드 한정 검(33단계, field_only)은 나오지 않는다.
## 초보자의 검(2026-11-23): 가장 흔한 검을 바탕으로, 이름을 바꾸고 내구를 두 배로. 처음 세 판에만 쥐고 시작한다.
func starter_sword() -> Sword:
	var d: SwordData = pick_sword(0).duplicate()
	d.display_name = "초보자의 검"
	var s := Sword.new(d, data)
	s.max_durability *= 2.0
	s.durability = s.max_durability
	return s


func pick_sword(grade: int) -> SwordData:
	var list: PackedInt32Array = data.swords_by_grade[grade]
	return data.swords[list[rng.randi_range(0, list.size() - 1)]]


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
	for k in slots.size():
		if slots[k] == null:
			slots[k] = s
			if slots[active] == null:
				active = k
			slots_changed.emit()
			return
	pending = s
	choice_needed.emit(s)


## 칸이 다 찼을 때 새 검을 둘 칸(0부터). -1이면 두고 간다.
func choose(k: int) -> void:
	if pending == null:
		return
	if k >= 0 and k < slots.size():
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
## 검 칸 수(언덕 판 기본 2, 들판 1, 마을의 검 보관집으로 3~4). 줄이면 뒤 칸의 검은 버린다.
func set_slot_count(n: int) -> void:
	n = maxi(1, n)
	slots.resize(n)
	if active >= n:
		active = 0
	slots_changed.emit()


## 쥔 칸 다음으로(돌아가며) 검이 든 칸. 없으면 -1. 두 칸일 때는 "다른 칸"과 같다.
func other_slot() -> int:
	var n: int = slots.size()
	for d in range(1, n):
		var k: int = (active + d) % n
		if slots[k] != null:
			return k
	return -1


## 다른 칸의 검으로 바꿔 쥔다. SWAP_NEXT(Q)는 다음 칸(검이 든).
func swap(k: int) -> void:
	if k == SWAP_NEXT:
		k = other_slot()
	if k < 0 or k >= slots.size() or k == active or slots[k] == null:
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
	# 걸어 다니는 점프(30단계): 공중 시간이 다 되면 내려앉는다(장면이 이 틱 뒤 낮은 막힘 안이면 밀어낸다)
	if L.air > 0.0:
		L.air -= dt
		if L.air <= 0.0:
			L.air = 0.0
			lord_landed.emit(L.pos)
	# 돌격병에 받혀 밀려나는 중
	if _head_fx(&"steady"):
		L.push = Vector2.ZERO   # 머리: 밀려나지 않는다
	if L.push.length_squared() > 0.0001:
		L.pos = (L.pos + L.push * dt).clamp(Vector2(0.5, 0.5), Vector2(Grid.size) - Vector2(0.5, 0.5))
		L.push *= pow(D.knock_keep, dt)
	else:
		L.push = Vector2.ZERO
	if input and input.swap_to >= 0:
		swap(input.swap_to)
	if L.riding:   # 39단계: 말을 탄 채(걷기·구르기·갈고리·뽑기 대신 말)
		_step_ride(input)
		return
	if input and input.pull and L.air <= 0.0:
		if phase == Phase.NIGHT and not field and not duel:
			_try_draw()
		else:
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
	# 점프: 땅에서만(두 번 뛰기 없음), 구르기·갈고리·좌클릭 동작 중에는 안 뛴다. 결투는 점프를 쓰지 않는다.
	if input and input.jump and not duel and L.air <= 0.0 and not busy and L.dash <= 0.0 and L.hook <= 0.0 and L.move == &"" and L.swing <= 0.0:
		L.air = D.jump_time
		lord_jumped.emit()
	var aloft: bool = L.air > 0.0
	if input and input.dash and not busy and not aloft and powers.dash_charges > 0 and L.dash <= 0.0:
		powers.dash_charges -= 1
		if powers.dash_recharge <= 0.0:
			powers.dash_recharge = powers.dash_cooldown()
		L.dash = D.dash_time
		L.dash_cooldown = powers.dash_recharge
		L.invuln = maxf(L.invuln, D.dash_time + 0.05)
		L.dash_dir = L.move_dir if L.moving else Vector2.from_angle(L.face)
		powers.on_dash()
		lord_dashed.emit()
	if input and input.hook and not busy and not aloft and phase == Phase.NIGHT and L.hook <= 0.0 and L.dash <= 0.0 and L.hook_cooldown <= 0.0:
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
	if input and input.attack and (phase == Phase.NIGHT or yard) and L.cooldown <= 0.0 and L.dash <= 0.0 and not busy and not aloft:
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
	if k == active and other_slot() >= 0:
		active = other_slot()
	lord.combo = 0
	sword_broke.emit(k, s)
	slots_changed.emit()


## dot: 출혈·불처럼 틱마다 조금씩 들어가는 피해(화면에 맞음 신호를 보내지 않는다).
## src: 때린 자리(방패병이 막는 쪽). 없으면(INF) 영주의 자리.
func hurt(e: Enemy, damage: float, knock: Vector2, big: bool, dot: bool = false, src: Vector2 = Vector2.INF) -> void:
	if e.dead:
		return
	if e.seat >= 0:
		_duel_hurt(e.seat, damage, knock, big)
		return
	if field and e.pack != &"" and int(packs[e.pack].state) != PACK_ENGAGED:
		_engage_pack(e.pack)
	if field and e == field_boss and field_boss_state != BOSS_AWAKE and field_boss_state != BOSS_DOWN:
		_wake_boss()
	if field and e.chief != &"" and chiefs.has(e.chief) and int(chiefs[e.chief].state) != BOSS_AWAKE and int(chiefs[e.chief].state) != BOSS_DOWN:
		_wake_chief(e.chief)
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
		_hz_killed(e)
		if _head_fx(&"heal") and lord.hp > 0.0:
			lord.hp = minf(max_hp(), lord.hp + 2.0)
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
	if field_night and attacker != null and (attacker.pack != &"" or attacker.chief != &""):
		d *= FieldLayout.FIELD_NIGHT_DAMAGE   # 29단계: 들판의 밤에는 무리 적과 곳마다 우두머리(32단계)가 더 아프게 때린다(옛 싸움터의 무덤 기사는 그대로)
	d = powers.lord_damage(d, attacker)
	d = _head_cut(d, attacker)
	if attacker != null and attacker.data != null:
		last_hit_by = attacker.data.id
	L.hp -= d
	L.invuln = data.lord.hurt_invuln
	if not duel:
		freeze = maxi(freeze, roundi(data.lord.hitstop_hurt / dt))   # 맞은 순간 짧게 멈춘다(2026-11-20 히트스톱)
	lord_hurt.emit(d)
	if L.riding:   # 39단계: 탄 채 맞으면 떨어진다(때린 쪽 반대로 밀리고 짧게 휘청)
		dismount(true, attacker.pos if attacker != null else Vector2.INF)
	if L.hp <= 0.0 and _head_fx(&"save") and not head_saved:
		head_saved = true
		L.hp = 1.0
	if L.hp <= 0.0 and not powers.save_from_death():
		lord_died()


func lord_died() -> void:
	lord.hp = 0.0
	_leave_fallen()
	phase = Phase.OVER
	won = false
	run_ended.emit(false)


# ---------------------------------------------------------------- 적

func _step_night() -> void:
	var R := data.run
	# 첫 구역(재설계): 밤은 정산뿐. 몰려온 주인을 다 쓰러뜨리면 새벽
	if hz:
		if hz_left.is_empty():
			_end_night()
		return
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
## 막힘이 있으면(nav, 37단계) 영주와의 곧은 선이 막힌 적은 흐름장을 따라 돌아오고(_detour), 틱 끝에 모든 적을 막힘 밖으로 민다.
func _step_enemies() -> void:
	var keep: float = pow(data.lord.knock_keep, dt)
	var reach: float = data.run.enemy_reach
	if nav != null:
		_plan_paths()
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
		# 들판 보스: 깨어나기 전에는 가만히 서 있고, 돌아가는 중에는 제자리로 걸으며 체력이 찬다
		if field and e == field_boss and field_boss_state != BOSS_AWAKE:
			_step_boss_idle(e, k)
			continue
		# 곳마다 우두머리(32단계): 들판 보스와 같다
		if field and e.chief != &"" and chiefs.has(e.chief) and int(chiefs[e.chief].state) != BOSS_AWAKE:
			_step_chief_idle(e, k)
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
		# 37단계: 영주와의 곧은 선이 막혔으면(_plan_paths) 흐름장을 따라 돌아온다. 흐름장이 닿지 않았으면 곧장(막힘은 틱 끝에 밀어낸다)
		if e.detour:
			var way: Vector2 = nav.flow_step(Nav.class_of(e.radius), e.pos) if foe == null and not burn_it else Vector2.INF
			if way != Vector2.INF:
				_detour(e, way, d, k)
				continue
			e.detour = false
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
	for e in enemies:
		if not e.dead:
			powers.U.push(e)   # 쇠말뚝·언덕을 쌓은 검의 벽
	if nav != null:
		for e in enemies:
			if not e.dead:
				e.pos = nav.push(e.pos, e.radius)   # 37단계: 낮은 막힘도 적에게는 막힘(적은 뛰지 않는다)
	var alive: Array[Enemy] = []
	for e in enemies:
		if not e.dead:
			alive.append(e)
	enemies = alive
	tokens.deal(dt)


# ---------------------------------------------------------------- 적 길찾기 (37단계)

## 장면이 쓰는 막힘 표를 준다(칸 단위). 들판은 FieldBuilder.build의 표, 무덤은 CryptRun이 방(walk)·문(gates: id → 열렸을 때 걷는 곳)·관을 준다.
## area는 판의 칸 수(안 주면 지금 Grid.size). 장면과 규칙이 같은 표를 쓰므로 결정성은 그대로다. 빈 표면 막힘이 없는 것과 같다.
func set_blockers(rects: Array, circles: Array, low_rects: Array = [], low_circles: Array = [], walk: Array = [], gates: Dictionary = {}, area: Vector2 = Vector2.ZERO) -> void:
	nav = Nav.new(area if area != Vector2.ZERO else Vector2(Grid.size), rects, circles, low_rects, low_circles, walk, gates)


## 무덤의 문(set_blockers의 gates)을 연다/닫는다(open: id → 아무 값). CryptRun이 틱마다 부른다(바뀔 때만 다시 굽는다).
func set_open_gates(open: Dictionary) -> void:
	if nav != null:
		nav.set_open(open)


## 영주에게 덤비는 중인 적인가(_step_enemies에서 서성임·잠·돌아감·망각으로 빠지지 않는 적).
func _chasing(e: Enemy) -> bool:
	if e.dead or e.confused > 0.0 or e.data.still:
		return false
	if field and e.pack != &"" and int(packs[e.pack].state) != PACK_ENGAGED:
		return false
	if field and e == field_boss and field_boss_state != BOSS_AWAKE:
		return false
	if field and e.chief != &"" and chiefs.has(e.chief) and int(chiefs[e.chief].state) != BOSS_AWAKE:
		return false
	return not at_beacon(e)


## 틱 처음: 덤비는 적마다 영주와의 곧은 선(몸만큼 넓힌 격자, 영주 앞 닿는 거리는 빼고)을 보고, 막힌 적은 detour를 켠다.
## 막힌 적이 있으면 몸 크기별 영주 쪽 흐름장을 (때가 됐으면) 다시 채운다.
func _plan_paths() -> void:
	var want: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
	var reach: float = data.run.enemy_reach
	for e in enemies:
		e.detour = false
		if not _chasing(e):
			continue
		var cls: int = Nav.class_of(e.radius)
		var to: Vector2 = lord.pos - e.pos
		var dd: float = to.length()
		var stop: float = e.radius + reach
		if dd <= stop or nav.clear(e.pos, e.pos + to * ((dd - stop) / dd), cls):
			continue
		e.detour = true
		var c: int = nav.free_cell(e.pos, cls)
		if c >= 0:
			want[cls].append(c)
	for cls in want.size():
		if not want[cls].is_empty():
			nav.update_flow(cls, lord.pos, tick, want[cls])


## 막힘을 돌아오는 적의 한 틱: way(흐름장이 고른 다음 자리) 쪽으로 몸을 돌려 걷는다. 표는 그대로 들되(멀어지면 Tokens가 내려놓는다)
## 새로 받지 않고(Foes.can_take_token), 하던 돌진·멈춘 일·부르기는 Foes.detour가 맡는다. 겨누기·돌진·휘두르기·심지는 곧게 보일 때만 시작한다.
func _detour(e: Enemy, way: Vector2, d: float, k: float) -> void:
	var to_w: Vector2 = way - e.pos
	var dw: float = to_w.length()
	if dw > 0.001:
		foes.turn(e, to_w / dw, dt)
	e.cooldown -= dt
	if tokens.cost(e) > 0:
		tokens.hold(e, d, dt)
	if foes.detour(e, k, dt):
		return
	if dw > 0.001:
		e.pos += to_w / dw * minf(e.data.speed * k * foes.pace(e) * dt, dw)


## 제자리로 돌아가는 적이 이번 틱에 걸어갈 자리: goal(제자리)까지 곧게 보이면 goal, 아니면 flow_home(무리·우두머리의 제자리) 쪽 흐름장의 다음 자리.
func _home_way(e: Enemy, goal: Vector2, flow_home: Vector2) -> Vector2:
	var cls: int = Nav.class_of(e.radius)
	if nav.clear(e.pos, goal, cls):
		return goal
	var w: Vector2 = nav.home_step(cls, flow_home, e.pos, tick)
	return goal if w == Vector2.INF else w


## 돌아가는 적이 step_len칸 걷는다(막혔으면 흐름장을 따라, _home_way). 다음 자리를 넘어가지 않는다.
func _walk_home(e: Enemy, goal: Vector2, flow_home: Vector2, step_len: float) -> void:
	var way: Vector2 = _home_way(e, goal, flow_home)
	var to: Vector2 = way - e.pos
	if way == goal:   # 곧게 보인다: 막힘이 없을 때와 똑같이 걷는다
		e.face = to.normalized()
		e.pos += e.face * step_len
		return
	var len_to: float = to.length()
	if len_to <= 0.0001:
		return
	e.face = to / len_to
	e.pos += e.face * minf(step_len, len_to)


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
## clock가 0 이상이면 들판 시계를 그 값(초)에서 켠다(밤이면 밤 무리도 선다). 안 주면 시계 없음.
func start_field(clock: float = -1.0) -> void:
	field = true
	phase = Phase.NIGHT
	night_left = night_total
	hilts.clear()
	altar = null
	event = null
	lord.hp = max_hp()
	if clock >= 0.0:
		field_clock_on = true
		field_clock = fposmod(clock, FieldLayout.FIELD_DAY + FieldLayout.FIELD_NIGHT)
		field_night = field_clock >= FieldLayout.FIELD_DAY
		if field_night:
			spawn_night_packs()


## 들판 시계를 한 틱 센다. 낮 → 밤이면 해가 지고(밤 무리가 선다), 밤 → 낮(한 바퀴)이면 날이 밝는다(쓰러뜨린 낮 무리가 다시 선다).
func _step_field_clock() -> void:
	if not field_clock_on:
		return
	field_clock += dt
	var cycle: float = FieldLayout.FIELD_DAY + FieldLayout.FIELD_NIGHT
	if field_clock >= cycle:
		field_clock -= cycle
	var night: bool = field_clock >= FieldLayout.FIELD_DAY
	if night == field_night:
		return
	field_night = night
	if night:
		spawn_night_packs()
		field_dusk.emit()
	else:
		_field_dawn()
		field_dawn.emit()


## 날이 밝았다: 쓰러뜨린 낮 무리의 기록을 지우고 빈 자리의 무리를 다시 세운다(안 쓰러뜨린 무리는 그대로).
## 영주가 제자리에서 FIELD_DAWN_SAFE칸 안에 있는 무리는 곁에서 솟지 않게 이번 새벽은 건너뛴다(쓰러뜨린 채로, 다음 새벽에).
## 밤 무리는 _step_field가 덤비는 중이 아닌 것부터 거둔다.
func _field_dawn() -> void:
	var skip: Dictionary = {}
	for id in FieldLayout.PACKS:
		var sid := StringName(id)
		var near: bool = lord.pos.distance_to(FieldLayout.PACKS[id].at) <= FieldLayout.FIELD_DAWN_SAFE
		if packs.has(sid):
			if packs[sid].cleared and not near:
				packs.erase(sid)
		elif near:
			skip[id] = 1
	spawn_packs(skip)


## 쓰러뜨린 채로 있는(또는 아직 안 선) 낮 무리 id. 장면이 새벽에 Meta.packs_cleared를 이것으로 맞춘다.
func field_cleared_ids() -> Dictionary:
	var out: Dictionary = {}
	for id in FieldLayout.PACKS:
		var sid := StringName(id)
		if not packs.has(sid) or bool(packs[sid].cleared):
			out[id] = 1
	return out


## 밤 무리(FieldLayout.NIGHT_PACKS)를 모두 세운다(이미 서 있는 것은 그대로).
func spawn_night_packs() -> void:
	for id in FieldLayout.NIGHT_PACKS:
		spawn_pack(StringName(id))


## 밤 무리 하나를 거둔다: 쓰러뜨린 것으로 치지 않고(보상 없음, 신호 없음) 무리 기록을 지운다.
func _vanish_pack(id: StringName) -> void:
	for e in enemies:
		if e.pack == id and not e.dead:
			e.dead = true
			tokens.release(e, true)
	packs.erase(id)


## FieldLayout.PACKS의 무리를 자리에 둔다. def를 주면 그 무리(테스트용)를 둔다: {at, wander, zone, foes}.
## 세기는 zone(1부터)의 RunData 구역 배수다. 적은 제자리 둘레에 퍼져 선다(랜덤은 rng).
func spawn_pack(id: StringName, def: Dictionary = {}) -> Array[Enemy]:
	var out: Array[Enemy] = []
	var P: Dictionary = def if not def.is_empty() else FieldLayout.PACKS.get(String(id), FieldLayout.NIGHT_PACKS.get(String(id), {}))
	if P.is_empty() or packs.has(id):
		return out
	var night_pack: bool = bool(P.get("night", false)) or (def.is_empty() and FieldLayout.NIGHT_PACKS.has(String(id)))
	var home: Vector2 = P.at
	var wander: float = float(P.wander)
	var pz: int = clampi(int(P.zone) - 1, 0, data.run.zone_hp.size() - 1)
	var spawn_z: int = clampi(pz + (FieldLayout.FIELD_NIGHT_ZONE if night_pack else 0), 0, data.run.zone_hp.size() - 1)   # 밤에 서는 무리는 한 구역 더 세다
	var kinds: Array[StringName] = []
	for f in P.foes:
		for _i in int(f[1]):
			kinds.append(StringName(f[0]))
	var a0: float = rng.randf() * TAU
	var keep_zone: int = zone
	zone = spawn_z
	var elite_kind: StringName = StringName(P.get("elite", &""))   # 지하 무덤(31단계): 그 종류의 첫 적이 정예
	for i in kinds.size():
		var at: Vector2 = home + Vector2.from_angle(a0 + TAU * i / kinds.size()) * wander * (0.35 + 0.35 * rng.randf())
		var e := spawn_at(kinds[i], at)
		e.pack = id
		e.home = at
		e.wander_to = at
		e.wander_t = rng.randf_range(FieldLayout.PACK_WANDER_WAIT.x, FieldLayout.PACK_WANDER_WAIT.y)
		if elite_kind != &"" and kinds[i] == elite_kind:
			make_elite(e)
			elite_kind = &""
		out.append(e)
	zone = keep_zone
	packs[id] = {"home": home, "wander": wander, "zone": pz, "state": PACK_IDLE, "spawned": out.size(), "cleared": false, "night": night_pack}
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
	# 공격 표 수와 불려 오는 적의 세기가 이 무리를 따른다. 밤에는 한 구역 더 세다(구역 표 길이를 넘지 않게 자른다)
	zone = clampi(int(p.zone) + (FieldLayout.FIELD_NIGHT_ZONE if field_night else 0), 0, data.run.zone_hp.size() - 1)
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
	_step_field_clock()
	_step_boss()
	_step_chiefs()
	var aggro: float = FieldLayout.FIELD_NIGHT_AGGRO if field_night else FieldLayout.PACK_AGGRO
	for id in packs.keys():
		var p: Dictionary = packs[id]
		if bool(p.night) and not field_night and (int(p.state) != PACK_ENGAGED or p.cleared):
			_vanish_pack(id)   # 날이 밝았다: 덤비는 중이 아닌 밤 무리(이미 쓰러뜨린 것의 기록도)는 사라진다
			continue
		if p.cleared:
			continue
		if pack_alive(id) == 0:
			p.cleared = true
			pack_cleared.emit(id)
			continue
		var d: float = lord.pos.distance_to(p.home)
		match int(p.state):
			PACK_IDLE:
				if d <= aggro:
					_engage_pack(id)
			PACK_ENGAGED:
				if d > FieldLayout.PACK_LEASH:
					_recall_pack(id)
			_:
				if d <= aggro:
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
		elif nav != null:
			_walk_home(e, e.home, p.home, step_len)   # 37단계: 막혔으면 무리 제자리 쪽 흐름장으로 돌아간다
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


# ---------------------------------------------------------------- 말 (39단계, docs/open_world2.md)

## 덤비는 무리·깨어 있는 우두머리·깨어 있는 무덤 기사가 있는가(그동안은 말을 못 부른다).
func horse_fight() -> bool:
	for id in packs:
		var p: Dictionary = packs[id]
		if int(p.state) == PACK_ENGAGED and not bool(p.cleared) and pack_alive(id) > 0:
			return true
	if field_boss != null and field_boss_state == BOSS_AWAKE and not field_boss.dead:
		return true
	for id in chiefs:
		if int(chiefs[id].state) == BOSS_AWAKE and not (chiefs[id].e as Enemy).dead:
			return true
	return false


## 말을 부른다(H, 틱 사이에 부른다). 되면 &"", 아니면 까닭: &"not_here"(들판 밖·결투), &"fight"(덤비는 적), &"riding"(이미 탔다).
## from: 말이 나타날 자리(칸, 장면이 막힘을 피해 고른다). INF면 영주 뒤 call_from칸. 말이 이미 곁(call_from칸 안)에 있으면 거기서 달려온다.
func call_horse(from: Vector2 = Vector2.INF) -> StringName:
	var H := data.horse
	if not allow_horse or duel or not field or phase == Phase.OVER:
		return &"not_here"
	if lord.riding:
		return &"riding"
	if horse_fight():
		return &"fight"
	if horse.state == Horse.AWAY or horse.pos.distance_to(lord.pos) > H.call_from:
		var at: Vector2 = from
		if at == Vector2.INF:
			at = lord.pos - Vector2.from_angle(lord.face) * H.call_from
		horse.pos = _clamp_cells(at)
		horse.prev_pos = horse.pos
		horse.speed = 0.0
		horse.face = (lord.pos - horse.pos).angle()
	horse.state = Horse.COMING
	horse.come_t = 0.0
	horse_called.emit()
	return &""


## 말 곁(mount_reach칸 안)이고 말이 서 있거나 다가오는 중인가.
func horse_near() -> bool:
	return horse.waiting() and lord.pos.distance_to(horse.pos) <= data.horse.mount_reach


## 말에 탄다(E, 틱 사이에). 말 곁이고 땅에서 다른 동작 중이 아닐 때만. 영주는 말 자리로, 보는 쪽은 말이 보는 쪽.
func mount() -> bool:
	var L := lord
	if L.riding or not horse_near() or L.airborne() or L.dash > 0.0 or L.hook > 0.0 or L.move != &"" or L.move_lock > 0.0 or phase == Phase.OVER or pull_hilt != null:
		return false
	L.riding = true
	L.pos = horse.pos
	L.ride_vel = Vector2.ZERO
	L.face = horse.face
	L.move_dir = Vector2.from_angle(horse.face)
	L.push = Vector2.ZERO
	L.combo = 0
	horse.state = Horse.RIDDEN
	horse.speed = 0.0
	horse_mounted.emit()
	return true


## 내린다(H·E, 틱 사이에). 말은 그 자리에 서고(달리던 빠르기에서 coast_time에 걸쳐 선다), 영주는 말의 왼쪽(dismount_side칸)에 선다.
## fell: 맞아서 떨어졌다. 그러면 from(때린 자리, INF면 말이 달리던 반대쪽) 반대로 fall_push만큼 밀리고 fall_stagger초 휘청인다(걷지도 베지도 못한다).
func dismount(fell: bool = false, from: Vector2 = Vector2.INF) -> bool:
	var L := lord
	var H := data.horse
	if not L.riding:
		return false
	L.riding = false
	horse.state = Horse.STANDING
	horse.pos = L.pos
	horse.speed = L.ride_vel.length()
	L.ride_vel = Vector2.ZERO
	L.air = 0.0   # 도약 중에 떨어지면 바로 땅
	L.pos = _clamp_cells(L.pos + Vector2.from_angle(horse.face - PI / 2.0) * H.dismount_side)
	if fell:
		var away: Vector2 = L.pos - from if from != Vector2.INF else -Vector2.from_angle(horse.face)
		away = away.normalized() if away.length() > 0.001 else -Vector2.from_angle(horse.face)
		L.push = away * H.fall_push
		L.move_lock = maxf(L.move_lock, H.fall_stagger)
	horse_dismounted.emit(fell)
	return true


## 탄 채 한 틱(_step_lord가 부른다): 걷기 대신 말의 빠르기(speed_mult배)로 달리고 방향은 turn_rate만큼만 돈다(서 있으면 turn_still).
## 크게 돌면 늦추고, 다 달리기까지 accel_time, 서기까지 stop_time. 점프 키는 말 도약(공중 leap_time, 낮은 막힘을 넘는다), 좌클릭은 말 위 베기(맨손이면 없음).
## 구르기·갈고리·뽑기는 없다. 휘청이는 동안(move_lock)은 입력을 안 받는다.
func _step_ride(input: LordInput) -> void:
	var L := lord
	var D := data.lord
	var H := data.horse
	var mv: Vector2 = input.move if input else Vector2.ZERO
	if mv.length() > 1.0:
		mv = mv.normalized()
	var top: float = D.speed * H.speed_mult
	var cur: float = L.ride_vel.length()
	var dir: Vector2 = L.ride_vel / cur if cur > 0.001 else Vector2.from_angle(horse.face)
	var want: float = 0.0
	if mv.length() > 0.1 and L.move_lock <= 0.0:
		var rate: float = lerpf(H.turn_still, H.turn_rate, clampf(cur / maxf(top, 0.01), 0.0, 1.0))
		var a: float = dir.angle()
		dir = Vector2.from_angle(a + clampf(angle_difference(a, mv.angle()), -rate * dt, rate * dt))
		var off: float = absf(angle_difference(dir.angle(), mv.angle()))
		want = top * mv.length() * lerpf(1.0, H.turn_slow, smoothstep(0.3, 2.0, off))
	var acc: float = top / maxf(H.accel_time if want > cur else H.stop_time, 0.01)
	cur = move_toward(cur, want, acc * dt)
	L.ride_vel = dir * cur
	L.pos = _clamp_cells(L.pos + L.ride_vel * dt)
	L.moving = cur > 0.3
	L.move_dir = dir
	horse.face = dir.angle()
	horse.speed = cur
	if input and input.attack and input.aim_valid and L.pos.distance_to(input.aim) > 0.05:
		L.face = (input.aim - L.pos).angle()
	elif L.moving:
		L.face = horse.face
	var aloft: bool = L.air > 0.0
	if input and input.jump and not aloft and L.move_lock <= 0.0:
		L.air = H.leap_time
		lord_jumped.emit()
		aloft = true
	if input and input.attack and phase == Phase.NIGHT and L.cooldown <= 0.0 and not aloft and L.move_lock <= 0.0 and current() != null:
		moves.ride_attack(input)


## 말 한 틱(들판에서, _step_lord 뒤): 탔으면 영주를 따르고, 오는 중이면 영주 곁(다가온 쪽 call_side칸)으로 달려와 늦추며 서고,
## 서 있으면 남은 빠르기로 몇 걸음 더 가다 선다. come_max초 안에 못 오면 곁에 바로 선다.
func _step_horse() -> void:
	var h := horse
	var H := data.horse
	var top: float = data.lord.speed * H.speed_mult
	match h.state:
		Horse.RIDDEN:
			h.pos = lord.pos
		Horse.COMING:
			h.come_t += dt
			var from_me: Vector2 = h.pos - lord.pos
			var side: Vector2 = from_me.normalized() if from_me.length() > 0.001 else Vector2.from_angle(lord.face + PI / 2.0)
			var target: Vector2 = _clamp_cells(lord.pos + side * H.call_side)
			var to: Vector2 = target - h.pos
			var dist: float = to.length()
			if dist <= H.arrive_eps or h.come_t >= H.come_max:
				if dist > H.arrive_eps:
					h.pos = target
				h.state = Horse.STANDING
				h.speed = 0.0
				horse_arrived.emit()
				return
			var want: float = minf(top, dist * H.arrive_brake)
			h.speed = move_toward(h.speed, want, top / maxf(H.accel_time, 0.01) * dt)
			var a: float = h.face
			h.face = a + clampf(angle_difference(a, to.angle()), -H.turn_still * dt, H.turn_still * dt)
			h.pos = _clamp_cells(h.pos + Vector2.from_angle(h.face) * minf(h.speed * dt, dist))
		Horse.STANDING:
			if h.speed > 0.0:
				h.speed = move_toward(h.speed, 0.0, top / maxf(H.coast_time, 0.01) * dt)
				h.pos = _clamp_cells(h.pos + Vector2.from_angle(h.face) * h.speed * dt)


# ---------------------------------------------------------------- 들판 보스 (18단계)

## 무덤 기사를 자리에 세운다. 이미 있으면 새로 세우지 않는다. at을 주면 그 자리(테스트용)에 선다.
## kind·boss_zone은 지하 무덤(19단계)의 무덤 주인이 쓴다(같은 행동, 다른 적 표).
func spawn_field_boss(at: Vector2 = FieldLayout.BOSS_AT, kind: StringName = FieldLayout.BOSS_ID, boss_zone: int = FieldLayout.BOSS_ZONE) -> Enemy:
	if field_boss != null:
		return null
	field_boss_zone = boss_zone
	var keep_zone: int = zone
	zone = clampi(boss_zone - 1, 0, data.run.zone_hp.size() - 1)
	var e := spawn_at(kind, at)
	zone = keep_zone
	e.home = at
	e.face = Vector2.DOWN
	field_boss = e
	field_boss_home = at
	field_boss_state = BOSS_SLEEP
	return e


func _wake_boss() -> void:
	if field_boss == null or field_boss.dead:
		return
	field_boss_state = BOSS_AWAKE
	zone = clampi(field_boss_zone - 1, 0, data.run.zone_hp.size() - 1)   # 불려 오는 망령의 세기
	field_boss.cooldown = maxf(field_boss.cooldown, field_boss.data.cooldown)
	field_boss_woke.emit(field_boss)


## 너무 멀어졌다: 하던 일을 멈추고 불러낸 것을 거두고 제자리로 돌아간다(체력이 차면 부르기도 다시 쓴다).
func _recall_boss() -> void:
	var b: Enemy = field_boss
	field_boss_state = BOSS_RETURNING
	b.act = &""
	b.act_t = 0.0
	b.windup = 0.0
	b.summoned = 0
	_dismiss_minions()


## 불려 온 적을 쓰러뜨린 것으로 치지 않고 거둔다(신호 없이).
func _dismiss_minions() -> void:
	if field_boss == null:
		return
	for e in enemies:
		if e.caller == field_boss.id and not e.dead:
			e.dead = true
			tokens.release(e, true)


func _step_boss() -> void:
	var b: Enemy = field_boss
	if b == null or field_boss_state == BOSS_DOWN:
		return
	if b.dead:
		field_boss_state = BOSS_DOWN
		_dismiss_minions()
		field_boss_slain.emit(b)
		return
	var d: float = lord.pos.distance_to(field_boss_home)
	match field_boss_state:
		BOSS_SLEEP:
			if d <= FieldLayout.BOSS_WAKE:
				_wake_boss()
		BOSS_AWAKE:
			if d > FieldLayout.BOSS_LEASH:
				_recall_boss()
		_:
			if d <= FieldLayout.BOSS_WAKE:
				_wake_boss()
			elif b.pos.distance_to(field_boss_home) <= 0.05 and b.hp >= b.max_hp:
				field_boss_state = BOSS_SLEEP
				field_boss_returned.emit(b)


func _step_boss_idle(e: Enemy, k: float) -> void:
	if field_boss_state != BOSS_RETURNING:
		e.push = Vector2.ZERO
		return
	var sp: float = e.data.speed * k * FieldLayout.PACK_RETURN_SPEED
	e.hp = minf(e.max_hp, e.hp + e.max_hp * dt / maxf(dt, FieldLayout.PACK_HEAL_TIME))
	var to: Vector2 = field_boss_home - e.pos
	var step_len: float = sp * dt
	if to.length() <= maxf(step_len, 0.05):
		e.pos = field_boss_home
	elif nav != null:
		_walk_home(e, field_boss_home, field_boss_home, step_len)
	else:
		e.face = to.normalized()
		e.pos += e.face * step_len


# ---------------------------------------------------------------- 곳마다 우두머리 (32단계)

## 우두머리 하나를 제자리(FieldLayout.CHIEFS)에 세운다. 이미 있거나 모르는 id면 null. at을 주면 그 자리(테스트용).
## 세기는 적 표 그대로(boss라 구역 배수를 받지 않는다). 불려 오는 적의 세기는 그 곳의 zone.
func spawn_chief(id: StringName, at: Vector2 = Vector2.INF) -> Enemy:
	if chiefs.has(id) or not FieldLayout.CHIEFS.has(String(id)):
		return null
	var C: Dictionary = FieldLayout.CHIEFS[String(id)]
	var home: Vector2 = C.at if at == Vector2.INF else at
	var keep_zone: int = zone
	zone = clampi(int(C.zone) - 1, 0, data.run.zone_hp.size() - 1)
	var e := spawn_at(C.kind, home)
	zone = keep_zone
	e.home = home
	e.face = Vector2.DOWN
	e.chief = id
	chiefs[id] = {"e": e, "state": BOSS_SLEEP, "home": home, "zone": int(C.zone)}
	return e


## 안 쓰러뜨린 우두머리를 모두 세운다(skip: 이번 판에 쓰러뜨린 우두머리 id → 아무 값, Meta.chiefs_down).
func spawn_chiefs(skip: Dictionary = {}) -> void:
	for id in FieldLayout.CHIEFS:
		if not skip.has(id):
			spawn_chief(StringName(id))


## 깨어 있는 우두머리 중 영주에게 가장 가까운 것(화면 아래 체력 막대). 없으면 null.
func awake_chief() -> Enemy:
	var best: Enemy = null
	var bd: float = INF
	for id in chiefs:
		var c: Dictionary = chiefs[id]
		var b: Enemy = c.e
		if int(c.state) == BOSS_AWAKE and not b.dead and b.pos.distance_to(lord.pos) < bd:
			bd = b.pos.distance_to(lord.pos)
			best = b
	return best


func _wake_chief(id: StringName) -> void:
	var c: Dictionary = chiefs[id]
	var b: Enemy = c.e
	if b.dead:
		return
	c.state = BOSS_AWAKE
	zone = clampi(int(c.zone) - 1, 0, data.run.zone_hp.size() - 1)   # 공격 표 수와 불려 오는 적의 세기
	b.cooldown = maxf(b.cooldown, b.data.cooldown)
	chief_woke.emit(id, b)


## 너무 멀어졌다: 하던 일을 멈추고 불러낸 것을 거두고 제자리로 돌아간다(체력이 차면 부르기도 다시 쓴다).
func _recall_chief(id: StringName) -> void:
	var c: Dictionary = chiefs[id]
	var b: Enemy = c.e
	c.state = BOSS_RETURNING
	b.act = &""
	b.act_t = 0.0
	b.windup = 0.0
	b.summoned = 0
	tokens.release(b, false)
	_dismiss_called(b)


## b가 불러낸 적을 쓰러뜨린 것으로 치지 않고 거둔다(신호 없이).
func _dismiss_called(b: Enemy) -> void:
	for e in enemies:
		if e.caller == b.id and not e.dead:
			e.dead = true
			tokens.release(e, true)


## 우두머리마다: 영주가 제자리에서 CHIEF_WAKE칸 안에 오면 깨어나고, CHIEF_LEASH칸 넘게 멀어지면 돌아간다. 쓰러지면 한 번 알린다.
func _step_chiefs() -> void:
	for id in chiefs:
		var c: Dictionary = chiefs[id]
		var b: Enemy = c.e
		if int(c.state) == BOSS_DOWN:
			continue
		if b.dead:
			c.state = BOSS_DOWN
			_dismiss_called(b)
			chief_slain.emit(id, b)
			continue
		var d: float = lord.pos.distance_to(c.home)
		match int(c.state):
			BOSS_SLEEP:
				if d <= FieldLayout.CHIEF_WAKE:
					_wake_chief(id)
			BOSS_AWAKE:
				if d > FieldLayout.CHIEF_LEASH:
					_recall_chief(id)
			_:
				if d <= FieldLayout.CHIEF_WAKE:
					_wake_chief(id)
				elif b.pos.distance_to(c.home) <= 0.05 and b.hp >= b.max_hp:
					c.state = BOSS_SLEEP
					chief_returned.emit(id, b)


## 깨지 않은 우두머리: 자는 동안은 가만히 서 있고, 돌아가는 중에는 제자리로 걸으며 체력이 찬다.
func _step_chief_idle(e: Enemy, k: float) -> void:
	var c: Dictionary = chiefs[e.chief]
	if int(c.state) != BOSS_RETURNING:
		e.push = Vector2.ZERO
		return
	var home: Vector2 = c.home
	var step_len: float = e.data.speed * k * FieldLayout.PACK_RETURN_SPEED * dt
	e.hp = minf(e.max_hp, e.hp + e.max_hp * dt / maxf(dt, FieldLayout.PACK_HEAL_TIME))
	var to: Vector2 = home - e.pos
	if to.length() <= maxf(step_len, 0.05):
		e.pos = home
	elif nav != null:
		_walk_home(e, home, home, step_len)
	else:
		e.face = to.normalized()
		e.pos += e.face * step_len


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
	make_elite(e)
	return e


## 정예로 만든다: 체력 elite_hp배(다 찬다), 피해 elite_damage배, 몸 elite_size배(data/run.tres). 화면(EnemyView)은 금빛 몸·빛·발밑 고리.
## 쓰러뜨리면 elites_killed를 세고 공짜 뽑기(언덕). 언덕 밤의 정예와 지하 무덤 방마다의 정예(31단계)가 같이 쓴다.
func make_elite(e: Enemy) -> void:
	var R := data.run
	e.elite = true
	e.max_hp *= R.elite_hp
	e.hp = e.max_hp
	e.damage *= R.elite_damage
	e.radius *= R.elite_size


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
	# 꽂아 둔(아는) 검은 남긴다(_new_day가 다시 세운다). 나머지 손잡이는 걷는다
	var planted: Array[Hilt] = []
	for h in hilts:
		if not h.gone and h.sword != null:
			planted.append(h)
	hilts.clear()
	hilts.append_array(planted)
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
	if other_slot() >= 0:
		return other_slot()
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
			if k == active and other_slot() >= 0:
				active = other_slot()
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
	for k in slots.size():
		if slots[k]:
			out.append({"kind": "melt", "slot": k})
	var s := current()
	var o: Sword = slots[other_slot()] if other_slot() >= 0 else null
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
	var other_k: int = other_slot()
	var text: String = ""
	match o.kind:
		"melt":
			var k: int = o.slot
			var w := slots[k]
			slots[k] = null
			melted_by_grade[w.grade] += 1
			if k == active and other_slot() >= 0:
				active = other_slot()
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
	parts.append(lord.air)
	parts.append_array([lord.riding, lord.ride_vel, horse.state, horse.pos, horse.face, horse.speed, horse.come_t])
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
	for g in ghosts:
		parts.append_array([g.id, g.i, g.pos, g.face])
	parts.append(_ghost_queue.size())
	for h in hilts:
		if h.cursed or h.sword or not h.owner.is_empty():
			parts.append_array([h.id, h.gone, h.pos, h.sword.data.id if h.sword else -1, h.sword.durability if h.sword else -1.0, str(h.owner)])
		parts.append_array([h.omen, h.shown_omen, h.revealed])
	parts.append_array([run_stats.kills, run_stats.zones, run_stats.elites, run_stats.perfect, run_stats.events_used, str(run_stats.kills_by_kind), str(run_stats.goals_done), str(run_stats.pulled_by_grade), pack.size()])
	if field:
		parts.append_array([field_clock_on, field_clock, field_night])
		parts.append(str(packs))
		parts.append_array([field_boss_state, field_boss_home, field_boss.id if field_boss else -1])
		for id in chiefs:
			parts.append_array([id, chiefs[id].state, chiefs[id].home, (chiefs[id].e as Enemy).id])
		for e in enemies:
			parts.append_array([e.pack, e.home, e.wander_to, e.wander_t])
	parts.append_array(powers.U.hash_parts())
	parts.append_array([pull_t, pull_steps, pull_judged, pull_goods, pull_win_step, pull_all_good])
	if duel:
		parts.append_array([duel_phase, duel_timer, duel_left, duel_round, duel_wins[0], duel_wins[1], duel_winner, cur_seat])
		for st in _seats:
			var q: LordState = st.lord
			parts.append_array([q.pos, q.hp, q.face, q.cooldown, q.invuln, q.push, q.dash, q.hook, q.move, q.combo, q.parry, q.move_lock, q.swing, q.dash_cooldown, q.hook_cooldown, st.slots[0].data.id if st.slots[0] else -1, st.moves.events.size(), st.powers.dash_charges])
			for p in st.projectiles:
				parts.append(p.pos)
	return hash(str(parts))


# ---------------------------------------------------------------- 1대1 결투 (21단계, docs/duel.md)

## 결투를 연다: 영주 둘이 각자 검(null이면 맨손)을 들고 마주 선다. 결투의 검은 부러지지 않는다.
## 낮밤·뽑기·적은 없고, 좌클릭은 상대 영주를 맞힌다. 각인과 고유 능력은 듣지 않는다. 틱은 step_duel로 돌린다.
func start_duel(sword_a: Sword, sword_b: Sword) -> void:
	duel = true
	allow_horse = false   # 39단계: 결투에는 말이 없다
	phase = Phase.NIGHT
	hilts.clear()
	altar = null
	event = null
	enemies.clear()
	projectiles.clear()
	enemy_projectiles.clear()
	powers.off = true
	var s0 := DuelSeat.new()
	s0.lord = lord
	s0.slots = slots
	s0.moves = moves
	s0.powers = powers
	s0.projectiles = projectiles
	var s1 := DuelSeat.new()
	s1.lord = LordState.new()
	s1.moves = Moves.new(self)
	s1.powers = Powers.new(self)
	s1.powers.off = true
	_seats.clear()
	_seats.append(s0)
	_seats.append(s1)
	lords.clear()
	lords.append(s0.lord)
	lords.append(s1.lord)
	var swords: Array[Sword] = [sword_a, sword_b]
	for i in 2:
		var w: Sword = swords[i]
		if w != null:
			w.max_durability = -1.0
			w.durability = -1.0
		_seats[i].slots[0] = w
		_seats[i].slots[1] = null
		var p := Enemy.new()
		p.id = _new_id()
		p.seat = i
		p.data = EnemyData.new()
		p.radius = data.duel.body_radius
		p.max_hp = data.duel.hp
		p.hp = p.max_hp
		_proxies.append(p)
	s0.foes.append(_proxies[1])
	s1.foes.append(_proxies[0])
	cur_seat = 0
	enemies = s0.foes
	duel_wins = [0, 0]
	duel_results.clear()
	duel_round = 0
	duel_winner = DUEL_NONE
	_begin_round()


## 한 영주의 몫(lord, 검 칸, 좌클릭 동작, 날아가는 것, 맞힐 것)을 규칙의 자리에 끼운다.
func _seat(i: int) -> void:
	if i == cur_seat:
		return
	_seats[cur_seat].active = active
	var s: DuelSeat = _seats[i]
	cur_seat = i
	lord = s.lord
	slots = s.slots
	active = s.active
	moves = s.moves
	powers = s.powers
	projectiles = s.projectiles
	enemies = s.foes


## 영주 i의 쥔 검(없으면 null). 화면이 읽는다.
func seat_sword(i: int) -> Sword:
	if not duel:
		return current()
	if i == cur_seat:
		return slots[active]
	var s: DuelSeat = _seats[i]
	return s.slots[s.active]


## 영주 i의 날아가는 것.
func seat_projectiles(i: int) -> Array[Projectile]:
	return projectiles if i == cur_seat or not duel else _seats[i].projectiles


## 그림자 적을 영주의 몸에 맞춘다.
func _sync_proxy(j: int) -> void:
	var p: Enemy = _proxies[j]
	var L: LordState = lords[j]
	p.pos = L.pos
	p.prev_pos = L.prev_pos
	p.hp = L.hp
	p.dead = L.hp <= 0.0
	p.face = Vector2.from_angle(L.face)
	_proxy_at[j] = L.pos


func _begin_round() -> void:
	var D := data.duel
	duel_round += 1
	duel_phase = DUEL_READY
	duel_timer = D.ready_time
	duel_left = D.round_time
	for i in 2:
		_seat(i)
		var L := lord
		L.hp = D.hp
		L.pos = Grid.middle() + Vector2(-D.start_gap if i == 0 else D.start_gap, 0.0)
		L.prev_pos = L.pos
		L.face = 0.0 if i == 0 else PI
		L.move_dir = Vector2.RIGHT if i == 0 else Vector2.LEFT
		L.moving = false
		L.cooldown = 0.0
		L.combo = 0
		L.combo_timer = 0.0
		L.swing = 0.0
		L.big = false
		L.dash = 0.0
		L.dash_cooldown = 0.0
		L.invuln = 0.0
		L.push = Vector2.ZERO
		L.hook = 0.0
		L.hook_target = null
		L.hook_cooldown = 0.0
		L.air = 0.0
		L.prev_air = 0.0
		moves.clear()
		powers.dash_charges = 1
		powers.dash_recharge = 0.0
	_seat(0)
	for j in 2:
		_sync_proxy(j)
	duel_round_started.emit(duel_round)


## 결투 한 틱. 영주마다 입력 하나(null이면 가만히). 시작 전과 판 사이에는 입력이 먹지 않는다.
func step_duel(input_a: LordInput = null, input_b: LordInput = null) -> void:
	if not duel or phase == Phase.OVER:
		return
	tick += 1
	for st in _seats:
		st.lord.prev_pos = st.lord.pos
		for p in st.projectiles:
			p.prev_pos = p.pos
	if freeze > 0:
		freeze -= 1
		return
	var inputs: Array = [input_a, input_b] if duel_phase == DUEL_FIGHT else [null, null]
	for i in 2:
		_seat(i)
		var o: int = 1 - i
		_sync_proxy(o)
		moves.advance(dt)
		powers.tick(dt)
		_step_lord(inputs[i])
		moves.tick(dt)
		# 끌어당기기(pull)가 그림자 적의 자리를 옮겼으면 상대 영주도 옮긴다
		if _proxies[o].pos != _proxy_at[o]:
			lords[o].pos = _clamp_cells(_proxies[o].pos)
	_seat(0)
	_separate()
	match duel_phase:
		DUEL_READY:
			duel_timer -= dt
			if duel_timer <= 0.0:
				duel_phase = DUEL_FIGHT
		DUEL_FIGHT:
			duel_left -= dt
			_check_round_end()
		DUEL_BETWEEN:
			duel_timer -= dt
			if duel_timer <= 0.0:
				_begin_round()


func _clamp_cells(p: Vector2) -> Vector2:
	return p.clamp(Vector2(0.5, 0.5), Vector2(Grid.size) - Vector2(0.5, 0.5))


## 두 영주의 몸이 겹치면 반씩 서로 밀어낸다.
func _separate() -> void:
	var a: LordState = lords[0]
	var b: LordState = lords[1]
	var min_d: float = data.duel.body_radius * 2.0
	var d: float = a.pos.distance_to(b.pos)
	if d >= min_d:
		return
	var n: Vector2 = (b.pos - a.pos) / d if d > 0.001 else Vector2.RIGHT
	var half: float = (min_d - d) / 2.0
	a.pos = _clamp_cells(a.pos - n * half)
	b.pos = _clamp_cells(b.pos + n * half)


## 상대 영주의 몸(그림자 적)이 맞았다. Moves._deal이 Rules.hurt로 부른다. 맞는 쪽의 구르기·맞은 뒤 무적은 그대로이고,
## 반격 자세면 피해 없이 반격한다. 상태 효과(불·얼음·출혈)는 영주에게 걸리지 않는다(속성은 피해만).
func _duel_hurt(j: int, damage: float, knock: Vector2, big: bool) -> void:
	if duel_phase != DUEL_FIGHT:
		return
	var L: LordState = lords[j]
	if L.hp <= 0.0 or L.invuln > 0.0 or L.dash > 0.0:
		return
	var from: int = cur_seat
	_seat(j)
	var parried: bool = moves.parried(_proxies[from])
	_seat(from)
	if parried:
		return
	L.hp = maxf(0.0, L.hp - damage)
	L.invuln = data.duel.hurt_invuln
	L.push += knock * data.duel.knockback_mult * data.lord.knock_speed
	duelist_hurt.emit(j, damage, big)


## 싸움 중 매 틱: 쓰러진 쪽이 있거나 시간이 다 되면 판이 끝난다.
func _check_round_end() -> void:
	var D := data.duel
	var dead_a: bool = lords[0].hp <= 0.0
	var dead_b: bool = lords[1].hp <= 0.0
	var w: int = DUEL_NONE
	if dead_a or dead_b:
		w = DUEL_DRAW if dead_a and dead_b else (1 if dead_a else 0)
	elif duel_left <= 0.0:
		var ra: float = lords[0].hp / D.hp
		var rb: float = lords[1].hp / D.hp
		if absf(ra - rb) < D.tie_eps:
			w = DUEL_DRAW
		else:
			w = 0 if ra > rb else 1
	if w == DUEL_NONE:
		return
	duel_results.append(w)
	if w >= 0:
		duel_wins[w] += 1
	duel_round_ended.emit(w)
	var need: int = D.rounds_to_win
	if duel_wins[0] >= need or duel_wins[1] >= need or duel_round >= need * 2 - 1:
		duel_winner = DUEL_DRAW if duel_wins[0] == duel_wins[1] else (0 if duel_wins[0] > duel_wins[1] else 1)
		duel_phase = DUEL_DONE
		phase = Phase.OVER
		duel_over.emit(duel_winner)
	else:
		duel_phase = DUEL_BETWEEN
		duel_timer = D.break_time


# ---------------------------------------------------------------- 언덕 재설계(docs/hill_events.md)

func _hz_on() -> bool:
	return use_hill_events and data.hill_zone != null and zone == 0 and not field and not yard and not duel


## 첫 구역의 낮: 손잡이를 HillZone의 검 지도로 바꾼다. 조짐은 등급에서(75% 맞음).
func _hz_setup() -> void:
	hz = null
	hz_foes.clear()
	hz_left.clear()
	hz_prize.clear()
	hz_offer = {}
	if not _hz_on():
		return
	var R := data.run
	hz = HillZone.new(data.hill_zone, rng.randi(), data.grades.names.size() - 1)
	hilts.clear()
	var mid := Grid.middle()
	var sx: float = (float(R.arena_size.x) / 2.0 - 2.0) / data.hill_zone.radius
	var sy: float = (float(R.arena_size.y) / 2.0 - 2.0) / data.hill_zone.radius
	hz_scale = Vector2(sx, sy)
	for i in hz.blades.size():
		var b := hz.blades[i]
		var h := Hilt.new()
		h.id = _new_id()
		h.zi = i
		h.pos = mid + Vector2(b.at.x * sx, b.at.y * sy)
		h.tilt = rng.randf_range(-0.25, 0.25)
		h.omen = [0, 1, 1, 2, 2, 3][clampi(b.grade, 0, 5)]
		h.shown_omen = h.omen if rng.randf() < 0.75 else clampi(h.omen + (1 if rng.randf() < 0.5 else -1), 0, 3)
		hilts.append(h)


func hilt_of(zi: int) -> Hilt:
	for h in hilts:
		if h.zi == zi:
			return h
	return null


## 이 손잡이를 뽑으면 깨어날 수 있는 이웃 손잡이들(지도·땅에 미리 보인다).
func hz_wake_preview(h: Hilt) -> Array[Hilt]:
	var out: Array[Hilt] = []
	if hz == null or h == null or h.zi < 0:
		return out
	for j in hz.wake_candidates(h.zi):
		var o := hilt_of(j)
		if o:
			out.append(o)
	return out


## 뽑기가 끝났다: 검은 사건을 이겨야 받는다. 이웃이 깨어난다.
func _hz_begin(zi: int, s: Sword) -> void:
	var before: Array[int] = []
	for i in hz.blades.size():
		if hz.blades[i].state == HillZone.State.AWAKE:
			before.append(i)
	hz.pull(zi)
	hz.started.erase(zi)
	hz_log.order.append(zi)
	for i in hz.blades.size():
		if hz.blades[i].state == HillZone.State.AWAKE and not before.has(i):
			hz_woke.emit(i)
	var h := hilt_of(zi)
	if h:
		h.gone = true
	hz_prize[zi] = s
	_hz_event(zi, hz.blades[zi].event)


func _hz_event(zi: int, kind: int) -> void:
	var h := hilt_of(zi)
	var at: Vector2 = h.pos if h else lord.pos
	if not hz_prize.has(zi):
		hz_prize[zi] = Sword.new(pick_sword(hz.blades[zi].final_grade(data.grades.names.size() - 1)), data)
	hz_event.emit(zi, kind)
	match kind:
		HillZone.Event.TRADE:
			var asks: Array[StringName] = [&"max_hp", &"durability"]
			if current() != null and not current().from_sheath:
				asks.append(&"sword")
			hz_offer = {"zi": zi, "ask": asks[rng.randi_range(0, asks.size() - 1)]}
			hz_offer_made.emit(zi, hz_offer.ask)
		HillZone.Event.CHASE:
			var n: int = rng.randi_range(hz.d.chase_min, hz.d.chase_max)
			hz_left[zi] = n
			for k in n:
				var a: float = rng.randf() * TAU
				var e := spawn_at(&"wolf" if k % 2 == 0 else &"wraith", at + Vector2(cos(a), sin(a)) * 2.0)
				hz_foes[e.id] = zi
		_:
			var e := spawn_at(&"wraith", at)
			var m: float = hz.duel_hp_mult(zi) * 3.0
			e.max_hp *= m
			e.hp = e.max_hp
			hz_foes[e.id] = zi
			hz_left[zi] = 1


## 거래에 답한다. 받으면 값을 내고 검(+각인 하나), 거절하면 결투.
func hz_answer(accept: bool) -> void:
	if hz_offer.is_empty():
		return
	var zi: int = hz_offer.zi
	var ask: StringName = hz_offer.ask
	hz_offer = {}
	hz_log["trade_yes" if accept else "trade_no"] += 1
	if not accept:
		_hz_event(zi, HillZone.Event.DUEL)
		return
	match ask:
		&"max_hp":
			hz_max_hp_cut += hz.d.trade_max_hp
			lord.hp = minf(lord.hp, max_hp())
		&"durability":
			for k in slots.size():
				if slots[k] and slots[k].breakable():
					slots[k].durability *= hz.d.trade_durability
		&"sword":
			for k in slots.size():
				if slots[k] == current():
					slots[k] = null
					break
			slots_changed.emit()
	var s: Sword = hz_prize[zi]
	var keys: Array = data.inscriptions.keys()
	if not keys.is_empty():
		s.extra_ins.append(str(keys[rng.randi_range(0, keys.size() - 1)]))
	_hz_win(zi)


func _hz_killed(e: Enemy) -> void:
	if not hz_foes.has(e.id):
		return
	var zi: int = hz_foes[e.id]
	hz_foes.erase(e.id)
	hz_left[zi] = int(hz_left.get(zi, 1)) - 1
	if int(hz_left[zi]) <= 0:
		hz_left.erase(zi)
		_hz_win(zi)


func _hz_win(zi: int) -> void:
	hz.finish(zi, true)
	var ek: String = str(hz.blades[zi].event)
	hz_log.won[ek] = int(hz_log.won.get(ek, 0)) + 1
	var s: Sword = hz_prize.get(zi)
	hz_prize.erase(zi)
	hz_done.emit(zi, true)
	if s and phase != Phase.OVER:
		sword_pulled.emit(s)
		_receive(s)


## 낮(첫 구역): 주인이 다가오고, 닿으면 그 검의 결투. 사건의 적이 움직인다.
func _step_hz() -> void:
	hz.step(dt, (lord.pos - Grid.middle()) / hz_scale)
	for zi in hz.started:
		_hz_event(zi, HillZone.Event.DUEL)
	hz.started.clear()
	if not enemies.is_empty():
		_step_enemies()
		foes.step_arrows(dt)


## 첫 구역의 밤 = 정산: 깨어나고 안 뽑은 검의 주인이 모두 온다.
func _hz_reckon() -> void:
	if hz == null:
		return
	var come := hz.begin_reckoning()
	hz_log.reckoned = come.size()
	for zi in come:
		_hz_event(zi, HillZone.Event.DUEL)


# ---------------------------------------------------------------- 머리(Heads, 2026-11-23)
signal head_found(id: String)


## 쓴 머리만큼 받는 피해를 줄인다(결투에서는 없음).
func _head_cut(d: float, attacker: Enemy) -> float:
	if head.is_empty() or duel:
		return d
	d *= 1.0 - float(head.get("cut", 0.0))
	var a: EnemyData = attacker.data if attacker != null else null
	match head.get("fx"):
		&"arrow":
			if a and a.aim_time > 0.0:
				d *= 0.5
		&"wraith":
			if a and a.wraith:
				d *= 0.6
		&"charge":
			if a and a.charge_min > 0.0:
				d *= 0.6
		&"low":
			if lord.hp < max_hp() * 0.3:
				d *= 0.75
		&"front":
			if attacker != null:
				var to: Vector2 = attacker.pos - lord.pos
				if to.length() > 0.01 and absf(Vector2.from_angle(lord.face).angle_to(to)) < deg_to_rad(60.0):
					d *= 0.7
	return d
