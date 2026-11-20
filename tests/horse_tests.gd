extends RefCounted
## 39단계 말 테스트(docs/open_world2.md): 수치·키, 부르기 조건(들판만·덤비는 적·이미 탐), 달려와 곁에 섬, 타기(곁에서만)·내리기,
## 탄 채 빠르기(×2.2)와 느린 방향 바꾸기, 도약(낮은 막힘을 넘는 높이), 맞으면 떨어짐(밀리고 휘청), 말 위 베기(넓게, 맨손이면 없음),
## 결정성(state_hash), 결투 바이트 그대로, 말 화면(HorseView) 만들기.
## run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/horse_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_data_and_keys()
	_call_rules()
	_arrive()
	_mount_dismount()
	_ride_speed()
	_leap()
	_fall()
	_ride_attack()
	_replay()
	_duel_bytes()
	_view()
	Grid.size = Vector2i(34, 22)


func _inp(move: Vector2 = Vector2.ZERO, jump: bool = false, attack: bool = false) -> LordInput:
	var i := LordInput.new()
	i.move = move
	i.jump = jump
	i.attack = attack
	return i


## 들판(늘 밤이라 좌클릭이 먹는다), 적 없음, 말을 부를 수 있다.
func _field(seed_value: int = 1) -> Rules:
	var r := Rules.new(d, seed_value)
	r.start_field()
	Grid.size = FieldLayout.SIZE   # Rules.new가 언덕 크기로 되돌린다: 들판 크기로
	r.allow_horse = true
	r.lord.pos = Vector2(40, 40)
	r.lord.prev_pos = r.lord.pos
	return r


## 부르고 다 올 때까지 돌린다(틱 수).
func _summon(r: Rules) -> int:
	r.call_horse()
	var n: int = 0
	while r.horse.state == Horse.COMING and n < 400:
		r.step(_inp())
		n += 1
	return n


func _ride(r: Rules) -> void:
	_summon(r)
	r.lord.pos = r.horse.pos + Vector2(0.5, 0)
	r.mount()


func _data_and_keys() -> void:
	var H := d.horse
	check.call(H != null and is_equal_approx(H.speed_mult, 2.2), "말 수치: data/horse.tres, 탄 채 빠르기 ×2.2")
	check.call(LordState.arc(H.leap_time * 0.5, H.leap_time, H.leap_height) > Blockers.JUMP_CLEAR, "말 도약의 가장 높은 곳이 낮은 막힘 기준(1m)보다 높다")
	var h_key: bool = false
	for e in InputMap.action_get_events("horse"):
		h_key = h_key or (e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_H)
	check.call(h_key, "입력: horse 행동이 H")


func _call_rules() -> void:
	var r := _field()
	r.allow_horse = false
	check.call(r.call_horse() == &"not_here" and not r.horse.present(), "부르기: 들판이 아니면(allow_horse 꺼짐) 안 온다")
	r = _field()
	r.spawn_field_boss(r.lord.pos + Vector2(4, 0))
	r.field_boss_state = Rules.BOSS_AWAKE
	check.call(r.horse_fight() and r.call_horse() == &"fight", "부르기: 깨어 덤비는 적이 있으면 못 부른다")
	r = _field()
	check.call(r.call_horse() == &"" and r.horse.state == Horse.COMING, "부르기: 들판에서 부르면 달려오기 시작한다")
	check.call(r.horse.pos.distance_to(r.lord.pos) > d.horse.call_from - 0.5, "부르기: 말은 call_from칸 떨어진 곳에서 나타난다")


func _arrive() -> void:
	var r := _field()
	var n: int = _summon(r)
	check.call(r.horse.state == Horse.STANDING and n < int(d.horse.come_max / r.dt) + 2, "부르면 come_max초 안에 곁에 와서 선다 (%d틱)" % n)
	check.call(r.horse.pos.distance_to(r.lord.pos) < d.horse.call_side + 0.5, "말은 영주 곁(call_side칸)에 선다")
	check.call(r.horse_near(), "곁에 온 말은 탈 수 있는 거리다")


func _mount_dismount() -> void:
	var r := _field()
	_summon(r)
	r.lord.pos = r.horse.pos + Vector2(d.horse.mount_reach + 1.0, 0)
	check.call(not r.mount() and not r.lord.riding, "타기: 말이 멀면 못 탄다")
	r.lord.pos = r.horse.pos + Vector2(0.5, 0)
	check.call(r.mount() and r.lord.riding and r.horse.state == Horse.RIDDEN, "타기: 곁에서 E로 탄다")
	check.call(r.lord.pos == r.horse.pos, "타면 영주가 말 자리에 앉는다")
	check.call(r.call_horse() == &"riding", "탄 채로는 다시 부르지 않는다")
	check.call(r.dismount() and not r.lord.riding and r.horse.state == Horse.STANDING, "내리기: 말은 그 자리에 선다")
	check.call(absf(r.lord.pos.distance_to(r.horse.pos) - d.horse.dismount_side) < 0.05, "내리면 말 옆(dismount_side칸)에 선다")


func _ride_speed() -> void:
	var r := _field()
	_ride(r)
	var start: Vector2 = r.lord.pos
	for i in 90:
		r.step(_inp(Vector2.RIGHT))
	var top: float = d.lord.speed * d.horse.speed_mult
	check.call(r.lord.ride_vel.length() > top * 0.95, "탄 채 다 달리면 걷기의 ×2.2 (%.2f칸/초)" % r.lord.ride_vel.length())
	check.call(r.lord.pos.x - start.x > d.lord.speed * 3.0 * 1.6, "3초 달린 거리가 걸은 거리보다 한참 길다")
	r.step(_inp(Vector2.LEFT))
	check.call(r.lord.ride_vel.x > 0.0, "다 달리다 뒤로 돌면 한 틱에 확 돌지 않는다(방향 바꾸기가 느리다)")
	check.call(r.horse.pos == r.lord.pos, "탄 말은 영주를 따라간다")


func _leap() -> void:
	var r := _field()
	_ride(r)
	r.step(_inp(Vector2.ZERO, true))
	check.call(r.lord.airborne() and r.lord.riding, "탄 채 점프 키 = 말 도약(공중)")
	var n: int = 0
	while r.lord.airborne() and n < 100:
		r.step(_inp())
		n += 1
	check.call(absf(n * r.dt - d.horse.leap_time) < 0.1, "말 도약은 leap_time초 뒤 내려앉는다 (%.2f초)" % (n * r.dt))


func _fall() -> void:
	var r := _field()
	_ride(r)
	for i in 40:
		r.step(_inp(Vector2.RIGHT))
	r._hurt_lord(5.0)
	check.call(not r.lord.riding and r.horse.state == Horse.STANDING, "탄 채 맞으면 떨어진다")
	check.call(r.lord.move_lock > 0.0 and r.lord.push.length() > 1.0, "떨어지면 밀리고 짧게 휘청인다(걷지 못한다)")
	var hp: float = r.lord.hp
	check.call(hp < d.lord.hp, "떨어져도 피해는 그대로 받는다")


func _ride_attack() -> void:
	var r := _field()
	r.give(d.swords[0], 0)
	_ride(r)
	var e := r.spawn_at(&"dummy", r.lord.pos + Vector2(1.5, 0))
	var hp0: float = e.hp
	var i := _inp(Vector2.ZERO, false, true)
	i.aim_valid = true
	i.aim = e.pos
	r.step(i)
	for k in 12:
		r.step(_inp())
	check.call(e.hp < hp0, "말 위 베기: 좌클릭으로 곁의 적을 벤다")
	check.call(r.lord.riding, "말 위에서 베어도 내리지 않는다")
	var bare := _field()
	_ride(bare)
	var e2 := bare.spawn_at(&"dummy", bare.lord.pos + Vector2(1.5, 0))
	var hp2: float = e2.hp
	bare.step(_inp(Vector2.ZERO, false, true))
	for k in 12:
		bare.step(_inp())
	check.call(is_equal_approx(e2.hp, hp2), "맨손이면 말 위에서 못 벤다")


func _replay() -> void:
	var hashes: Array[int] = []
	for k in 2:
		var r := _field(7)
		r.give(d.swords[0], 0)
		_ride(r)
		for t in 120:
			r.step(_inp(Vector2.from_angle(t * 0.13), t % 41 == 0, t % 29 == 3))
		hashes.append(r.state_hash())
	check.call(hashes[0] == hashes[1], "결정성: 같은 시드·같은 입력(말 탄 채)이면 state_hash가 같다")
	var a := _field(7)
	var b := _field(7)
	_ride(a)
	_summon(b)
	check.call(a.state_hash() != b.state_hash(), "결정성: 탄 상태가 state_hash에 든다")


func _duel_bytes() -> void:
	var r := Rules.new(d, 3)
	check.call(not r.allow_horse and r.call_horse() == &"not_here", "결투·언덕 판(기본 Rules)에는 말이 없다")


func _view() -> void:
	var r := _field()
	var v := HorseView.new()
	v.setup(r)
	v.draw(1.0, 0.016)
	check.call(not v.visible, "말 화면: 부르기 전에는 안 보인다")
	_summon(r)
	v.draw(1.0, 0.016)
	check.call(v.visible and v.seat_height() > 1.3 and v.seat_height() < 1.8, "말 화면: 부르면 보이고 안장 높이가 사람 허리 위다 (%.2fm)" % v.seat_height())
	v.free()
