extends RefCounted
## 30단계 걸어 다니는 점프 테스트(docs/field_life.md): 땅에서만 한 번, 포물선 높이와 내려앉는 때, 구르기·좌클릭 중 안 뜀,
## 공중 좌클릭 없음, 결정성, 낮은 막힘(Blockers)은 공중에서만 넘고 내려앉으면 밀어냄, 높은 막힘은 늘 막음, 결투 바이트 그대로.
## run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/jump_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_data_and_keys()
	_ground_only()
	_arc_and_landing()
	_not_while_busy()
	_no_attack_aloft()
	_walk_aloft()
	_still_hit()
	_replay()
	_blockers()
	_cross_fence()
	_duel_bytes()
	_pose()
	Grid.size = Vector2i(34, 22)


func _inp(move: Vector2 = Vector2.ZERO, jump: bool = false, attack: bool = false, dash: bool = false) -> LordInput:
	var i := LordInput.new()
	i.move = move
	i.jump = jump
	i.attack = attack
	i.dash = dash
	return i


## 들판 모드(늘 "밤"이라 좌클릭이 먹는다), 적 없음.
func _field(seed_value: int = 1) -> Rules:
	var r := Rules.new(d, seed_value)
	r.start_field()
	r.lord.pos = Vector2(10, 10)
	r.lord.prev_pos = r.lord.pos
	return r


## 땅에 닿을 때까지 돌리고 몇 틱 걸렸는지.
func _land(r: Rules, move: Vector2 = Vector2.ZERO) -> int:
	var n: int = 0
	while r.lord.airborne() and n < 200:
		r.step(_inp(move))
		n += 1
	return n


func _data_and_keys() -> void:
	var D := d.lord
	check.call(is_equal_approx(D.jump_time, 0.55) and is_equal_approx(D.jump_height, 1.1), "점프 수치: data/lord.tres jump_time 0.55초, jump_height 1.1m")
	check.call(D.jump_height > Blockers.JUMP_CLEAR and is_equal_approx(Blockers.JUMP_CLEAR, 1.0), "점프 높이(1.1m)가 낮은 막힘 기준(JUMP_CLEAR 1.0m)보다 높다")
	var cfg := ConfigFile.new()
	check.call(cfg.load("res://project.godot") == OK and cfg.has_section_key("input", "jump"), "입력: jump 행동이 있다")
	var space_jump: bool = false
	for e in InputMap.action_get_events("jump"):
		space_jump = space_jump or (e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_SPACE)
	var space_attack: bool = false
	for e in InputMap.action_get_events("attack"):
		space_attack = space_attack or (e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_SPACE)
	check.call(space_jump and not space_attack, "입력: Space는 점프, 베기의 예비 키에서는 빠졌다")
	var named: bool = false
	for a in GameSettings.ACTIONS:
		named = named or (a[0] == "jump" and a[1] == "점프")
	check.call(named, "설정 창: 점프 키를 바꿀 수 있다(GameSettings.ACTIONS)")


func _ground_only() -> void:
	var r := Rules.new(d, 3)   # 언덕 낮(걷기만)
	var jumps: Array = []
	var lands: Array = []
	r.lord_jumped.connect(func() -> void: jumps.append(1))
	r.lord_landed.connect(func(_at: Vector2) -> void: lands.append(1))
	check.call(not r.lord.airborne(), "점프: 처음에는 땅에 있다")
	r.step(_inp(Vector2.ZERO, true))
	check.call(r.lord.airborne() and is_equal_approx(r.lord.air, d.lord.jump_time) and jumps.size() == 1, "점프: 땅에서 누르면 뜬다(공중 시간 = jump_time)")
	r.step(_inp())
	var left: float = r.lord.air
	r.step(_inp(Vector2.ZERO, true))
	check.call(jumps.size() == 1 and r.lord.air < left, "점프: 공중에서 다시 눌러도 두 번 뛰지 않는다")
	_land(r)
	check.call(lands.size() == 1 and not r.lord.airborne(), "점프: 내려앉으면 lord_landed 한 번")
	r.step(_inp(Vector2.ZERO, true))
	check.call(jumps.size() == 2 and r.lord.airborne(), "점프: 내려앉은 뒤에는 다시 뛴다")
	# 뽑기와 같이 누르면 뛰지 않고 뽑는다(공중에서는 뽑기가 안 된다)
	var r2 := Rules.new(d, 3)
	var h: Hilt = r2.nearest_hilt(100.0)
	r2.lord.pos = h.pos + Vector2(0.3, 0.0)
	r2.step(_inp(Vector2.ZERO, true))
	var pull := LordInput.new()
	pull.pull = true
	r2.step(pull)
	check.call(r2.pull_hilt == null, "점프: 공중에서는 꽂힌 검을 뽑지 않는다")


func _arc_and_landing() -> void:
	var D := d.lord
	var T: float = D.jump_time
	check.call(LordState.air_height(T, D) == 0.0 and LordState.air_height(0.0, D) == 0.0, "포물선: 뜬 순간과 내려앉은 순간의 높이는 0")
	check.call(is_equal_approx(LordState.air_height(T * 0.5, D), D.jump_height), "포물선: 가운데가 가장 높다(jump_height)")
	check.call(absf(LordState.air_height(T * 0.75, D) - D.jump_height * 0.75) < 0.001 and absf(LordState.air_height(T * 0.25, D) - D.jump_height * 0.75) < 0.001, "포물선: 1/4·3/4 때 높이는 jump_height의 3/4(4h·u(1-u))")
	var r := _field()
	r.step(_inp(Vector2.ZERO, true))
	var peak: float = 0.0
	var prev: float = 0.0
	var up_then_down: bool = true
	var falling: bool = false
	var ticks: int = 0
	while r.lord.airborne() and ticks < 100:
		r.step(_inp())
		ticks += 1
		var h: float = LordState.air_height(r.lord.air, D)
		peak = maxf(peak, h)
		if h < prev:
			falling = true
		elif falling and h > prev + 0.0001:
			up_then_down = false
		prev = h
	check.call(up_then_down and peak > D.jump_height * 0.97, "포물선: 오르다 내려온다(가장 높은 곳 %.2fm)" % peak)
	var want: int = ceili(T / r.dt - 0.001)
	check.call(absi(ticks - want) <= 1, "내려앉는 때: 뜬 시간 %.2f초 ≈ %d틱(30Hz, 기대 %d)" % [ticks * r.dt, ticks, want])


func _not_while_busy() -> void:
	# 구르기 중
	var r := _field()
	r.step(_inp(Vector2.RIGHT, false, false, true))
	check.call(r.lord.dash > 0.0, "구르기 시작")
	r.step(_inp(Vector2.RIGHT, true))
	check.call(not r.lord.airborne(), "점프: 구르는 중에는 뛰지 않는다")
	# 공중에서는 구르기도 안 나간다
	var r2 := _field()
	r2.step(_inp(Vector2.ZERO, true))
	r2.step(_inp(Vector2.RIGHT, false, false, true))
	check.call(r2.lord.dash <= 0.0 and r2.lord.airborne(), "점프: 공중에서는 구르지 않는다")
	# 좌클릭 동작 중
	var r3 := _field()
	r3.step(_inp(Vector2.ZERO, false, true))
	check.call(r3.lord.move != &"" or r3.lord.swing > 0.0, "좌클릭 동작 시작")
	r3.step(_inp(Vector2.ZERO, true))
	check.call(not r3.lord.airborne(), "점프: 좌클릭 동작 중에는 뛰지 않는다")
	for i in 60:
		r3.step(_inp())
	r3.step(_inp(Vector2.ZERO, true))
	check.call(r3.lord.airborne(), "점프: 동작이 끝나면 뛴다")
	# 결투는 점프를 쓰지 않는다
	var r4 := Rules.new(d, 1)
	r4.start_duel(null, null)
	for t in roundi(d.duel.ready_time / r4.dt) + 2:
		r4.step_duel()
	r4.step_duel(_inp(Vector2.ZERO, true), _inp(Vector2.ZERO, true))
	check.call(not r4.lords[0].airborne() and not r4.lords[1].airborne(), "점프: 결투에서는 jump를 눌러도 뛰지 않는다")


func _no_attack_aloft() -> void:
	var r := _field()
	var swings: Array = []
	r.lord_swung.connect(func(_b: bool) -> void: swings.append(1))
	r.step(_inp(Vector2.ZERO, true))
	for i in 5:
		r.step(_inp(Vector2.ZERO, false, true))
	check.call(swings.is_empty() and r.lord.move == &"", "점프: 공중에서는 좌클릭이 나가지 않는다")
	_land(r)
	r.step(_inp(Vector2.ZERO, false, true))
	check.call(swings.size() == 1, "점프: 내려앉으면 좌클릭이 나간다")


func _walk_aloft() -> void:
	var a := _field()
	var b := _field()
	b.step(_inp(Vector2.RIGHT, true))
	a.step(_inp(Vector2.RIGHT))
	for i in 10:
		a.step(_inp(Vector2.RIGHT))
		b.step(_inp(Vector2.RIGHT))
	check.call(b.lord.airborne() and a.lord.pos.distance_to(b.lord.pos) < 0.0001, "점프: 공중에서도 걷던 대로 움직인다(같은 거리)")
	var c := _field()
	c.step(_inp(Vector2.RIGHT, true))
	for i in 6:
		c.step(_inp(Vector2.DOWN))
	check.call(c.lord.pos.y > 10.5, "점프: 공중에서 방향을 바꿀 수 있다")


func _still_hit() -> void:
	var r := _field()
	r.step(_inp(Vector2.ZERO, true))
	for i in 4:
		r.step(_inp())
	var hp: float = r.lord.hp
	r._hurt_lord(10.0)
	check.call(r.lord.airborne() and r.lord.hp < hp, "점프: 공중이어도 맞는다(피하는 효과 없음)")


func _replay() -> void:
	var hashes: Array[int] = []
	for k in 2:
		var r := _field(9)
		for t in 90:
			var mv := Vector2.from_angle(t * 0.21)
			r.step(_inp(mv, t % 23 == 0, t % 31 == 5))
		hashes.append(r.state_hash())
	check.call(hashes[0] == hashes[1], "결정성: 같은 시드·같은 입력(점프 포함)이면 state_hash가 같다")
	var a := _field(9)
	var b := _field(9)
	a.step(_inp(Vector2.ZERO, true))
	b.step(_inp())
	check.call(a.state_hash() != b.state_hash(), "결정성: 공중 상태가 state_hash에 든다")


func _blockers() -> void:
	var fence: Array = [Rect2(10, 5, 0.4, 10)]
	var wall: Array = [Rect2(20, 5, 1.0, 10)]
	var log_c: Array = [[Vector2(30, 10), 0.5]]
	var p := Vector2(10.2, 10)   # 울타리 한가운데
	check.call(Blockers.push_out(p, [], [], fence, [], true) == p, "낮은 막힘: 공중이면 지나간다")
	var q: Vector2 = Blockers.push_out(p, [], [], fence, [], false)
	check.call(q.x <= 10.0 - Blockers.BODY + 0.0001 or q.x >= 10.4 + Blockers.BODY - 0.0001, "낮은 막힘: 땅에 있으면(내려앉은 틱) 가까운 변 밖으로 밀어낸다")
	var w := Vector2(20.4, 10)
	check.call(Blockers.push_out(w, wall, [], [], [], true) != w and Blockers.push_out(w, wall, [], [], [], false) != w, "높은 막힘: 공중이어도 막는다")
	var c := Vector2(30.1, 10)
	check.call(Blockers.push_out(c, [], [], [], log_c, true) == c and Blockers.push_out(c, [], [], [], log_c, false).distance_to(Vector2(30, 10)) >= 0.8 - 0.0001, "낮은 둥근 막힘(쓰러진 통나무): 공중이면 지나가고 땅이면 밀어낸다")
	check.call(Blockers.inside(p, [], [], fence) and not Blockers.inside(p, [], [], fence, [], true), "Blockers.inside: 낮은 막힘은 땅에서만")
	# 둥근 막힘 줄(겹친 원) 사이에 내려앉아도 모두 밖으로
	var chain: Array = []
	for k in 5:
		chain.append([Vector2(40 + k * 1.0, 10), 0.45])
	var out: Vector2 = Blockers.push_out(Vector2(41.5, 10.05), [], [], [], chain, false)
	var clear: bool = true
	for cc in chain:
		clear = clear and out.distance_to(cc[0]) >= float(cc[1]) + Blockers.BODY - 0.001
	check.call(clear, "낮은 막힘: 겹친 둥근 막힘 줄 안에 내려앉아도 밖으로 밀려난다")
	check.call(Blockers.is_low(0.9) and Blockers.is_low(1.0) and not Blockers.is_low(1.1), "낮은 막힘: 그린 높이 1m 이하")


## 규칙으로 걷고 장면처럼 Blockers로 미는 것을 틱마다 되풀이해, 울타리는 뛰어야만 넘고 높은 벽은 못 넘는지 본다.
func _walk_into(low: Array, high: Array, jump_at: int) -> Vector2:
	var r := _field(2)
	r.lord.pos = Vector2(8, 10)
	r.lord.prev_pos = r.lord.pos
	for t in 60:
		r.step(_inp(Vector2.RIGHT, t == jump_at))
		r.lord.pos = Blockers.push_out(r.lord.pos, high, [], low, [], r.lord.airborne())
	return r.lord.pos


func _cross_fence() -> void:
	var fence: Array = [Rect2(10, 5, 0.4, 10)]
	var stay: Vector2 = _walk_into(fence, [], -1)
	check.call(stay.x < 10.0, "울타리: 뛰지 않으면 넘지 못한다")
	var over: Vector2 = _walk_into(fence, [], 6)
	check.call(over.x > 10.4 + Blockers.BODY, "울타리: 앞에서 뛰면 넘는다")
	var wall: Array = [Rect2(10, 5, 0.4, 10)]
	var blocked: Vector2 = _walk_into([], wall, 6)
	check.call(blocked.x < 10.0, "높은 벽: 뛰어도 넘지 못한다")
	# 막힘 위에 내려앉으면 밖으로(불탄 마을 우물처럼 넓은 낮은 막힘)
	var well: Array = [Rect2(10, 5, 4, 10)]
	var r := _field(2)
	r.lord.pos = Vector2(9.6, 10)
	r.step(_inp(Vector2.RIGHT, true))
	r.lord.pos = Blockers.push_out(r.lord.pos, [], [], well, [], r.lord.airborne())
	var mid_air: bool = false
	for t in 40:
		r.step(_inp(Vector2.RIGHT if r.lord.airborne() else Vector2.ZERO))
		r.lord.pos = Blockers.push_out(r.lord.pos, [], [], well, [], r.lord.airborne())
		mid_air = mid_air or ((well[0] as Rect2).has_point(r.lord.pos) and r.lord.airborne())
	check.call(mid_air and not Blockers.inside(r.lord.pos, [], [], well), "넓은 낮은 막힘: 공중에서는 위를 지나고 그 안에 내려앉으면 밀려난다")


func _duel_bytes() -> void:
	var i := LordInput.new()
	i.jump = true
	i.attack = true
	i.move = Vector2(0.5, -0.25)
	var b: PackedByteArray = i.to_bytes()
	check.call(LordInput.BYTES == 18 and b.size() == 18, "결투 바이트: 길이 18 그대로(점프는 넣지 않는다)")
	var back := LordInput.from_bytes(b)
	check.call(not back.jump and back.attack and back.move == i.move, "결투 바이트: 되돌리면 jump는 늘 false, 나머지는 그대로")
	var j := LordInput.new()
	j.attack = true
	j.move = i.move
	check.call(j.to_bytes() == b, "결투 바이트: jump가 있어도 없어도 바이트가 같다")


## 화면 쪽(정적 함수): 점프 자세와 Mixamo 동작 낱말, 다리 굽힘 방향.
func _pose() -> void:
	var a: Dictionary = MoveMotion.hop_pose(0.0, -1.0)
	var mid: Dictionary = MoveMotion.hop_pose(0.5, -1.0)
	var land: Dictionary = MoveMotion.hop_pose(-1.0, MoveMotion.HOP_LAND * MoveMotion.HOP_LAND_PEAK)
	var rest: Dictionary = MoveMotion.hop_pose(-1.0, -1.0)
	check.call(float(a.bend) > 0.4 and float(a.tuck) < 0.05, "점프 자세: 뜰 때 웅크렸다 편다")
	check.call(float(mid.tuck) > 0.9 and float(mid.bend) < 0.01, "점프 자세: 공중 가운데에서 다리를 접는다")
	check.call(float(land.bend) > 0.9 and float(land.pitch) > 0.0, "점프 자세: 내려앉으며 무릎을 굽힌다")
	check.call(float(rest.bend) == 0.0 and float(rest.tuck) == 0.0, "점프 자세: 땅에서 가만히 있으면 아무것도 안 얹는다")
	check.call(float(mid.gather) > 0.99 and float(a.gather) < 0.01 and float(rest.gather) == 0.0 and float(MoveMotion.hop_pose(1.0, -1.0).gather) < 0.01,
		"점프 자세: 공중에서는 두 다리를 몸 밑에 모으고, 뜰 때와 내려앉을 때는 동작의 다리 그대로")
	_gather()
	check.call(LordCharacter._key_for("hop") == "hop" and LordCharacter._key_for("jump hop") == "hop" and LordCharacter._key_for("great sword jump") == "leap", "Mixamo 낱말: hop은 점프, jump는 그대로 도약 내려찍기")
	# 다리 굽힘(LegFold): 뼈대 X축으로 허벅지를 -각(무릎이 앞 +Z), 정강이를 +각. 무릎 굽힘이면 발이 엉덩이 밑에 남고 발바닥이 평평하다.
	var g: Vector3 = LegFold.angles(0.0, 1.0)
	var thigh: Vector3 = Basis(Vector3.RIGHT, g.x) * Vector3(0, -0.45, 0)
	var shin: Vector3 = Basis(Vector3.RIGHT, g.x + g.y) * Vector3(0, -0.45, 0)
	check.call(thigh.z > 0.1 and absf((thigh + shin).z) < 0.001 and absf(g.x + g.y + g.z) < 0.001, "다리 굽힘: 무릎은 앞으로, 발은 엉덩이 밑에, 발바닥은 평평하게")
	var t: Vector3 = LegFold.angles(1.0, 0.0)
	var knee: Vector3 = Basis(Vector3.RIGHT, t.x) * Vector3(0, -0.45, 0)
	var foot: Vector3 = knee + Basis(Vector3.RIGHT, t.x + t.y) * Vector3(0, -0.45, 0)
	check.call(knee.z > 0.3 and foot.y > -0.6, "다리 접기: 공중에서 무릎이 앞으로 들리고 발이 올라온다")


## 다리 모으기(LegFold gather): 동작이 벌려 놓은 다리를 쉬는 자세 쪽으로 옮긴다(공중에서 걸음 중간에 굳은 다리가 따로 놀지 않게).
func _gather() -> void:
	var sk := Skeleton3D.new()
	var names: Array[String] = ["mixamorig_Hips"]
	for leg in LegFold.LEGS:
		for n in leg:
			names.append(n)
	for n in names:
		sk.add_bone(n)
	for i in range(1, names.size()):
		sk.set_bone_parent(i, 0 if (i == 1 or i == 4) else i - 1)
	var spread := Quaternion(Vector3.FORWARD, 0.5)
	var up: int = sk.find_bone("mixamorig_LeftUpLeg")
	sk.set_bone_pose_rotation(up, spread)
	LegFold.fold(sk, 0.0, 0.0, 0.0, 1.0)
	check.call(sk.get_bone_pose_rotation(up).is_equal_approx(Quaternion.IDENTITY), "다리 모으기: 다 모으면 쉬는 자세(곧게 내린 다리)가 된다")
	sk.set_bone_pose_rotation(up, spread)
	LegFold.fold(sk, 0.0, 0.0, 0.0, 0.0)
	check.call(sk.get_bone_pose_rotation(up).is_equal_approx(spread), "다리 모으기: 0이면 동작의 다리를 건드리지 않는다")
	sk.free()
