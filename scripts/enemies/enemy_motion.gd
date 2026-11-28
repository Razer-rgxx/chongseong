class_name EnemyMotion
extends RefCounted
## 11단계 새 적 5종의 몸 움직임(모션팀, docs/content.md "11단계: 적 행동"). EnemyArt가 지은 부품(parts)을 매 프레임 움직인다.
## 정적 함수뿐이다(방패병 기사 모델의 뼈를 동작 위에 덮어쓰는 작은 노드 ShieldRig 하나만 뼈대 아래에 붙인다).
## 꾸밈용 흔들림은 sin 곡선과 state.id의 위상으로 만들고 랜덤은 쓰지 않는다.
##
## EnemyView는 이렇게 쓴다:
##   1) _ready에서 몸을 트리 안(_body 아래)에 지은 직후 한 번: parts = EnemyArt.build(…), motion = EnemyMotion.rest(parts)
##      motion은 이 몸의 쉬는 자세와 걸음 위상 같은 움직임 상태를 담는다. 적 하나에 하나씩 둔다.
##   2) draw()에서 매 프레임(죽는 중이 아닐 때): EnemyMotion.animate(parts, motion, kind, state, delta)
##      state 열쇠(없으면 기본값):
##        act: StringName   enemy.act (&"" = 걷기·서기, &"wait" = 표를 기다리며 영주를 본 채 게걸음)
##        act_t, act_time   enemy.act_t, enemy.act_time(0이면 TIME의 값)
##        speed: float      땅 위 빠르기(m/초, EnemyView._speed_m). 뒤로 걸으면 backing = true(활잡이가 물러날 때)
##        side: float       옆 빠르기(m/초, + = 몸의 오른쪽). wait일 때 어느 쪽으로 게걸음 하는지(없으면 speed로 오른쪽)
##        t: float          누적 시간(EnemyView._t)             id: int  enemy.id(흔들림 위상)
##        guard: bool       방패를 든다(방패병: 깨지지 않았고 guard_down <= 0)
##        stunned: bool     기절 중                              recoil: float  EnemyView._recoil(맞으면 1, 크게 1.6, 0으로 준다)
##        attack: float     근접 공격을 시작하고 지난 초(EnemyView._attack, 없으면 -1). 방패병의 베기
##        hit: float        크게 맞고 지난 초(EnemyView._hit_anim, 없으면 -1). 방패병 기사의 맞는 동작
##   3) 맞을 때 뒤로 젖혀지기는 state.recoil로 여기서 한다(parts.root를 발을 축으로 돌린다). 이 다섯 종은 EnemyView가
##      _body를 따로 젖히거나 눌러 찌그러뜨리지 않는다. 위치·돌기(EnemyView 노드)와 _body는 여기서 건드리지 않는다.
##   4) 방패병 기사 모델(parts.knight가 있을 때): animate가 knight_plan을 보고 knight.play를 스스로 부른다(바뀔 때만).
##      EnemyView는 die()의 knight.play("death")만 부른다. 뼈 덮어쓰기(방패 들기, 내던지기, 움찔, 비틀거림, 게걸음 허리)는
##      animate가 처음 불릴 때 parts.skeleton 아래에 붙이는 ShieldRig(SkeletonModifier3D)가 한다. 이것은 AnimationPlayer가
##      동작을 적용한 뒤 뼈대가 갱신될 때(프레임 끝) 돌므로 animate를 부르는 순서와 때는 상관없다. 뼈에 붙은 방패·칼·눈도 따라간다.
##      animate가 불리지 않으면(죽는 중) 덮어쓰기는 스스로 0으로 줄어 동작만 남는다.
##   5) 빛: 자폭병과 부르는 자의 glow 재질 emission_energy_multiplier와 light.light_energy를 매 프레임 쓴다(바탕값 meta
##      "base_energy" × 배수). 다른 곳에서 바꾸려면 이 뒤에 곱한다. 활잡이의 화살(parts.arrow)은 겨누는 동안만 보인다.
##
## 좌표 약속은 EnemyArt와 같다: 몸은 -Z를 보고 원점은 발밑, 짝은 [왼, 오], rotation.x > 0 = 팔다리를 앞으로(머리는 < 0이 숙임).

## act_time이 0일 때 쓰는 행동 길이(초). docs/content.md 11단계 표의 첫 값.
const TIME: Dictionary = {
	&"aim": 0.6, &"shoot": 0.3, &"block": 0.3, &"guard_break": 1.2, &"wind": 0.7, &"charge": 0.7,
	&"charge_end": 1.0, &"fuse": 0.9, &"explode": 0.2, &"call_wind": 1.0, &"call": 0.6,
}
## 맞을 때 뒤로 젖혀지는 각도(라디안, recoil 1당).
const RECOIL: float = 0.28
## 방패병 기사 모델: 달리기 동작을 이동 1m/초당 이만큼 빠르게 튼다(걷기 동작이 있으면 WALK_PER_MPS).
const RUN_PER_MPS: float = 0.155
const WALK_PER_MPS: float = 0.28
## 기사 베기를 이 시간(초) 동안 둔다(state.attack 기준). 그 뒤 서기·걷기로 돌아간다.
const SLASH_HOLD: float = 1.1
## 쉬는 자세를 잡아 두는 부품.
const NODE_KEYS: Array[String] = ["root", "torso", "head", "bow", "staff", "lantern", "belly", "tail", "horns", "shield", "quiver"]
const ARRAY_KEYS: Array[String] = ["arms", "forearms", "hands", "legs", "knees"]


# ---------------------------------------------------------------- 바깥에서 부르는 것

## 지은 직후의 자세(위치·돌기·크기)를 잡아 두고, 이 몸의 움직임 상태를 담을 Dictionary를 돌려준다.
static func rest(parts: Dictionary) -> Dictionary:
	var xf: Dictionary = {}
	for k in NODE_KEYS:
		var n := parts.get(k) as Node3D
		if n != null:
			xf[k] = n.transform
	for k in ARRAY_KEYS:
		var a: Array = parts.get(k, [])
		var out: Array[Transform3D] = []
		for n in a:
			out.append((n as Node3D).transform)
		xf[k] = out
	var r: Dictionary = {"xf": xf, "since": {}, "act": &"", "act_t": 0.0, "init": false}
	var legs: Array = parts.get("legs", [])
	r["leg_len"] = (legs[0] as Node3D).position.y if not legs.is_empty() else 0.0
	return r


## 매 프레임 부른다. kind = EnemyData.id(archer, shield, charger, bomber, caller). state는 위 머리말의 열쇠.
static func animate(parts: Dictionary, rest: Dictionary, kind: StringName, state: Dictionary, delta: float) -> void:
	if parts.is_empty() or rest.is_empty():
		return
	var S: Dictionary = _state(state)
	if not bool(rest["init"]):
		rest["init"] = true
		rest["ph"] = fposmod(float(S.id) * 1.37, TAU)
		rest["sph"] = fposmod(float(S.id) * 2.11, TAU)
	_track(rest, S)
	_reset(parts, rest)
	match kind:
		&"archer":
			_archer(parts, rest, S, delta)
		&"shield":
			if parts.get("knight") != null:
				_shield_knight(parts, rest, S, delta)
			else:
				_shield_box(parts, rest, S, delta)
		&"charger":
			_charger(parts, rest, S, delta)
		&"bomber":
			_bomber(parts, rest, S, delta)
		&"caller":
			_caller(parts, rest, S, delta)


## 방패병 기사 모델이 지금 틀 동작. anim = LordCharacter.play의 이름(idle, run 또는 walk, slash, hit),
## speed·from은 play의 인자, once = 한 번 트는 동작(바뀔 때만 튼다). animate가 이것으로 knight.play를 부른다.
static func knight_plan(state: Dictionary) -> Dictionary:
	var S: Dictionary = _state(state)
	var attack: float = S.attack
	if attack >= 0.0 and attack < SLASH_HOLD:
		return {"anim": "slash", "speed": 0.85, "from": -0.12, "once": true}
	if S.act == &"guard_break" and float(S.act_t) < 0.5:
		return {"anim": "hit", "speed": 0.8, "from": 0.0, "once": true}
	var hit: float = S.hit
	if hit >= 0.0 and hit < 0.45:
		return {"anim": "hit", "speed": 1.2, "from": 0.0, "once": true}
	if S.act == &"guard_break" or bool(S.stunned):
		return {"anim": "idle", "speed": 0.5, "from": 0.0, "once": false}
	var spd: float = maxf(float(S.speed), absf(float(S.side)) if S.act == &"wait" else 0.0)
	if spd > 0.25:
		return {"anim": "run", "speed": clampf(spd * RUN_PER_MPS, 0.3, 1.2), "from": 0.0, "once": false, "walk": clampf(spd * WALK_PER_MPS, 0.3, 1.2)}
	return {"anim": "idle", "speed": 0.8, "from": 0.0, "once": false}


# ---------------------------------------------------------------- 활잡이

static func _archer(P: Dictionary, r: Dictionary, S: Dictionary, delta: float) -> void:
	var root: Node3D = P.root
	var torso: Node3D = P.torso
	var head: Node3D = P.head
	var arms: Array = P.arms
	var fore: Array = P.forearms
	var hands: Array = P.hands
	var act: StringName = S.act
	var shot: float = _since(r, S, &"shoot")
	var p: float = _progress(S)
	# 겨눔 무게: 겨누는 동안 1, 쏘고 조금 뒤에 내린다
	var aim_on: bool = act == &"aim" or act == &"shoot" or shot < 0.32
	var w: float = _ease_to(r, "aim_w", 1.0 if aim_on else 0.0, 10.0 if aim_on else 5.0, delta)
	var e: float = smoothstep(0.0, 1.0, w)
	var g: Dictionary = _legs(P, r, S, delta, 1.7, 2.0, 0.5, 2.8, e)
	var ph: float = g.ph
	var run: float = g.run
	var rr: Vector3 = g.rr
	var rp: Vector3 = g.rp
	# 쏜 뒤의 반동(0~1~0)
	var kick: float = smoothstep(0.0, 0.05, shot) * (1.0 - smoothstep(0.08, 0.4, shot)) if shot < 0.5 else 0.0
	# 걷기: 조금 숙이고(물러날 때는 젖히고) 어깨가 다리와 반대로 돈다. 오른팔은 다리와 반대로, 활 든 왼팔은 조금
	var lean: float = (0.05 if bool(S.backing) else -0.07) * run
	_turn(torso, Vector3(lean, 0.08 * run * sin(ph), 0.0))
	_turn(head, Vector3(-lean * 0.6, -0.06 * run * sin(ph), 0.0))
	_turn(arms[1], Vector3(0.38 * run * sin(ph), 0.0, 0.0))
	_turn(fore[1], Vector3(0.25 * run * maxf(0.0, sin(ph)), 0.0, 0.0))
	_turn(arms[0], Vector3(-0.14 * run * sin(ph), 0.0, 0.0))
	if e > 0.001:
		# 겨누기: 왼어깨를 앞으로 틀어 옆으로 서고 조금 젖힌다. 고개는 앞(영주)을 본다. 앞발(왼)을 내딛고 뒷발을 뺀다
		_turn(torso, Vector3(0.07 + 0.05 * kick, -0.55, 0.0) * e)
		_turn(head, Vector3(-0.08, 0.52, 0.08) * e)
		_turn(P.legs[0], Vector3(0.2, 0.0, -0.06) * e)
		_turn(P.knees[0], Vector3(-0.14, 0.0, 0.0) * e)
		_turn(P.legs[1], Vector3(-0.24, 0.0, 0.08) * e)
		_turn(P.knees[1], Vector3(-0.1, 0.0, 0.0) * e)
		rp.y -= 0.025 * e
		var inv: Transform3D = torso.transform.affine_inverse()
		# 활 든 손: 어깨 높이로 곧게 앞(쏘면 앞아래로 조금 튄다). 팔꿈치는 바깥 아래
		var bow_at := Vector3(-0.06, 1.43, -0.64) + Vector3(0.0, -0.035, -0.04) * kick
		_ik(arms[0], fore[0], hands[0], inv * bow_at, inv.basis * Vector3(-1.0, -0.7, 0.15), e)
		# 활을 몸 기준으로 곧게 세운다(쏘는 쪽 = 몸의 앞)
		var bow: Node3D = P.bow
		var want: Basis = EnemyArt._basis_to(hands[0], root).inverse() * Basis.from_euler(Vector3(0.0, 0.0, -0.1))
		bow.basis = bow.basis.slerp(want.orthonormalized(), e)
	# 시위: 겨누는 동안 당기고(0.2~0.9), 쏘면 바로 놓는다
	var draw: float = 0.0
	if act == &"aim":
		draw = smoothstep(0.22, 0.92, p)
	elif act == &"shoot" or shot < 0.3:
		draw = 1.0 - smoothstep(0.0, 0.05, shot)
	EnemyArt.set_draw(P, draw * e)
	var arrow := P.get("arrow") as Node3D
	if arrow:
		arrow.visible = act == &"aim" and p > 0.12
	if e > 0.001:
		# 당기는 손: 오늬 바로 뒤. 놓으면 뒤로 빠진다. 팔꿈치는 어깨 높이로 뒤·바깥
		var inv: Transform3D = torso.transform.affine_inverse()
		var nock: Vector3 = _xf(P.bowstring, root).origin
		var follow: float = smoothstep(0.0, 0.07, shot) * (1.0 - smoothstep(0.2, 0.5, shot)) if shot < 0.6 else 0.0
		var hand_at: Vector3 = nock + Vector3(0.02, 0.0, 0.06) + Vector3(0.09, 0.03, 0.13) * follow
		_ik(arms[1], fore[1], hands[1], inv * hand_at, inv.basis * Vector3(1.0, 0.3, 0.7), e)
	rr += _daze(S, head)
	if bool(S.stunned):
		_turn(torso, Vector3(-0.1, 0.0, 0.0))
	rr.x += RECOIL * float(S.recoil)
	_place_root(root, r, rr, rp)


# ---------------------------------------------------------------- 방패병(기사 모델)

static func _shield_knight(P: Dictionary, r: Dictionary, S: Dictionary, delta: float) -> void:
	var k := P.knight as LordCharacter
	if k == null or not k.is_inside_tree():
		return
	# 동작
	var plan: Dictionary = knight_plan(S)
	var anim: String = plan.anim
	if anim == "run" and k.has("walk"):
		anim = "walk"
		plan["speed"] = plan.get("walk", plan.speed)
	var prev: String = r.get("kanim", "")
	var restart: bool = false
	if anim == "slash":
		restart = float(S.attack) < float(r.get("katt", 1e9))
	elif anim == "hit" and S.act != &"guard_break":
		restart = float(S.hit) < float(r.get("khit", 1e9))
	if anim != prev or restart:
		k.play(anim, plan.speed, plan.from)
	elif not bool(plan.once):
		k.play(anim, plan.speed)
	r["kanim"] = anim
	r["katt"] = float(S.attack) if float(S.attack) >= 0.0 else 1e9
	r["khit"] = float(S.hit) if float(S.hit) >= 0.0 else 1e9
	# 뼈 덮어쓰기의 무게
	var rig: ShieldRig = _rig(P, r)
	var root: Node3D = P.root
	var rr := Vector3.ZERO
	var rp := Vector3.ZERO
	var t: float = S.t
	var act: StringName = S.act
	var slashing: bool = float(S.attack) >= 0.0 and float(S.attack) < SLASH_HOLD
	var breaking: bool = act == &"guard_break"
	var up: bool = bool(S.guard) and not slashing and not breaking and not bool(S.stunned)
	var guard: float = _ease_to(r, "guard", 1.0 if up else 0.0, 9.0 if up else 7.0, delta)
	# 깨짐: 방패 팔을 바깥으로 내던지고(0.12초), 기절 동안 비틀거리다 끝에 추스른다
	var T: float = _time(S)
	var at: float = S.act_t
	var fl: float = smoothstep(0.0, 0.12, at) * (1.0 - smoothstep(T - 0.35, T, at)) if breaking else 0.0
	var fling: float = _ease_to(r, "fling", fl, 25.0 if fl > float(r.get("fling", 0.0)) else 6.0, delta)
	# 막기: 짧게 움찔(밀려 뒤로)
	var bs: float = _since(r, S, &"block")
	var flinch: float = smoothstep(0.0, 0.04, bs) * (1.0 - smoothstep(0.08, 0.34, bs)) if bs < 0.4 else 0.0
	# 게걸음: 엉덩이를 가는 쪽으로 돌리고(달리기 동작이 옆으로 간다) 가슴은 영주를 본다
	var ws: float = _ease_to(r, "wait_w", 1.0 if act == &"wait" else 0.0, 6.0, delta)
	var side: float = S.side
	var dir: float = signf(side) if absf(side) > 0.05 else 1.0
	var lean := Vector3.ZERO
	var head := Vector3.ZERO
	# 방패 뒤에 웅크려 조금 숙인다
	lean.x += 0.1 * guard
	head.x -= 0.08 * guard
	lean.x -= 0.32 * flinch
	head.x -= 0.22 * flinch
	rp.z += 0.09 * flinch
	if breaking or bool(S.stunned):
		var env: float = (smoothstep(0.0, 0.2, at) * (1.0 - smoothstep(T - 0.3, T, at))) if breaking else 1.0
		lean += Vector3(-0.12 + 0.07 * sin(t * 3.7), 0.1 * sin(t * 2.3), 0.13 * sin(t * 2.9 + 0.6)) * env
		head += Vector3(0.28 + 0.08 * sin(t * 4.1), 0.15 * sin(t * 1.9), -0.22 * sin(t * 2.9 + 1.2)) * env
		rr.z += 0.04 * sin(t * 2.9) * env
	if rig:
		rig.guard = guard
		rig.fling = fling
		rig.flinch = flinch
		rig.lean = lean
		rig.head = head
		rig.hips_yaw = -0.95 * dir * ws
		rig.fresh = true
		rig.poke()
	rr.x += RECOIL * 0.6 * float(S.recoil)
	_place_root(root, r, rr, rp)


static func _rig(P: Dictionary, r: Dictionary) -> ShieldRig:
	var o: Variant = r.get("rig")
	if o != null and is_instance_valid(o):
		return o as ShieldRig
	var sk := P.get("skeleton") as Skeleton3D
	if sk == null or not sk.is_inside_tree():
		return null
	var rig := ShieldRig.new()
	rig.name = "ShieldRig"
	sk.add_child(rig)
	r["rig"] = rig
	return rig


## 방패병 기사 모델의 뼈를 동작 위에 덮어쓴다(Skeleton3D의 자식). 뼈대 공간은 Mixamo의 것(앞 +Z, 왼쪽 +X, T자세).
## 무게가 모두 0이면 아무것도 바꾸지 않는다. fresh가 꺼진 채 갱신되면(animate가 안 불림) 무게를 스스로 0으로 줄인다.
class ShieldRig extends SkeletonModifier3D:
	## 방패를 가슴·얼굴 앞에 든다(0~1).
	var guard: float = 0.0
	## 방패 팔을 바깥으로 내던진다(0~1). guard보다 앞선다.
	var fling: float = 0.0
	## 막을 때 방패 팔이 몸 쪽으로 밀린다(0~1).
	var flinch: float = 0.0
	## 척추에 더하는 돌기(라디안, 세 마디에 나눈다): x = 앞으로 숙임, y = 왼쪽으로 돎, z = 오른쪽으로 기욺.
	var lean: Vector3 = Vector3.ZERO
	## 머리에 더하는 돌기(같은 뜻).
	var head: Vector3 = Vector3.ZERO
	## 엉덩이를 이만큼 돌리고(+ = 왼쪽) 척추에서 되돌려 가슴은 그대로 앞을 본다.
	var hips_yaw: float = 0.0
	var fresh: bool = false
	var _ok: bool = false
	var _b: Dictionary = {}
	var _ua_axis := Vector3.ZERO
	var _ua_hinge := Vector3.ZERO
	var _fa_axis := Vector3.ZERO
	var _fa_normal := Vector3.ZERO
	var _chest_rest := Quaternion.IDENTITY

	## 방패를 든 자세: 위팔 방향, 아래팔 방향(가슴 앞을 가로질러 오른쪽으로), 방패 앞면이 볼 쪽. T자세 뼈대 공간.
	const GUARD_UA := Vector3(0.1, -0.76, 0.64)
	const GUARD_FA := Vector3(-0.93, -0.1, 0.34)
	const GUARD_N := Vector3(0.12, 0.22, 1.0)
	## 막을 때 밀리는 쪽(위팔에 더한다)과 방패 윗머리가 뒤로 젖혀지는 쪽(앞면에 더한다).
	const FLINCH_UA := Vector3(0.05, 0.3, -0.55)
	const FLINCH_N := Vector3(0.0, 0.6, 0.0)
	## 내던진 자세: 위팔은 바깥 뒤로 벌어지고 아래팔은 앞으로 늘어져, 방패가 문짝처럼 바깥으로 열린다(가슴이 드러난다).
	const FLING_UA := Vector3(0.87, -0.15, -0.46)
	const FLING_FA := Vector3(0.1, -0.35, 0.93)
	const FLING_N := Vector3(0.95, 0.0, 0.3)

	## 무게가 바뀐 것을 뼈대에 알린다(동작이 멈춰 있어도 다음 갱신에 이 노드가 돈다).
	func poke() -> void:
		var sk := get_skeleton()
		if sk and _ok:
			var h: int = _b["hips"]
			sk.set_bone_pose_rotation(h, sk.get_bone_pose_rotation(h))

	func _bind(sk: Skeleton3D) -> void:
		for pair in [["hips", "Hips"], ["spine", "Spine"], ["spine1", "Spine1"], ["spine2", "Spine2"], ["neck", "Neck"], ["head", "Head"],
				["sh", "LeftShoulder"], ["ua", "LeftArm"], ["fa", "LeftForeArm"], ["hand", "LeftHand"]]:
			var b: int = sk.find_bone("mixamorig_" + str(pair[1]))
			if b < 0:
				return
			_b[pair[0]] = b
		var gua: Transform3D = sk.get_bone_global_rest(_b["ua"])
		var gfa: Transform3D = sk.get_bone_global_rest(_b["fa"])
		var ghd: Transform3D = sk.get_bone_global_rest(_b["hand"])
		var iua: Basis = gua.basis.orthonormalized().inverse()
		var ifa: Basis = gfa.basis.orthonormalized().inverse()
		_ua_axis = (iua * (gfa.origin - gua.origin)).normalized()
		_ua_hinge = (iua * Vector3.DOWN).normalized()   # T자세에서 팔꿈치를 굽히면 손이 앞(+Z)으로: 축 = -Y
		_fa_axis = (ifa * (ghd.origin - gfa.origin)).normalized()
		_fa_normal = (ifa * Vector3.UP).normalized()     # T자세에서 방패 앞면은 위를 본다(EnemyArt._dress_knight)
		_chest_rest = sk.get_bone_global_rest(_b["spine2"]).basis.get_rotation_quaternion()
		_ok = true

	func _process_modification_with_delta(delta: float) -> void:
		var sk := get_skeleton()
		if sk == null:
			return
		if not _ok:
			_bind(sk)
			if not _ok:
				return
		if not fresh:
			var k: float = exp(-8.0 * delta)
			guard *= k
			fling *= k
			flinch *= k
			lean *= k
			head *= k
			hips_yaw *= k
		fresh = false
		if absf(hips_yaw) > 0.001:
			var h: int = _b["hips"]
			sk.set_bone_pose_rotation(h, Quaternion(Vector3.UP, hips_yaw) * sk.get_bone_pose_rotation(h))
		var spine_turn := Quaternion.from_euler(Vector3(lean.x, lean.y - hips_yaw, -lean.z) / 3.0)
		if not spine_turn.is_equal_approx(Quaternion.IDENTITY):
			for key in ["spine", "spine1", "spine2"]:
				_turn_global(sk, _b[key], spine_turn)
		if head.length() > 0.001:
			_turn_global(sk, _b["head"], Quaternion.from_euler(Vector3(head.x, head.y, -head.z)))
		if guard + fling > 0.001:
			_arm(sk)

	## 뼈 b를 뼈대 공간의 돌기 q만큼 더 돌린다(뼈의 자리를 축으로).
	func _turn_global(sk: Skeleton3D, b: int, q: Quaternion) -> void:
		var parent: int = sk.get_bone_parent(b)
		var pg := Quaternion.IDENTITY
		if parent >= 0:
			pg = sk.get_bone_global_pose(parent).basis.get_rotation_quaternion()
		var lq: Quaternion = sk.get_bone_pose_rotation(b)
		sk.set_bone_pose_rotation(b, (pg.inverse() * q * pg * lq).normalized())

	## 왼팔 두 마디를 방패 자세(guard)와 내던진 자세(fling)로 돌린다. 가슴의 돌기를 반쯤 따라가 몸 앞을 지킨다.
	func _arm(sk: Skeleton3D) -> void:
		var chest: Quaternion = sk.get_bone_global_pose(_b["spine2"]).basis.get_rotation_quaternion() * _chest_rest.inverse()
		var c: Quaternion = Quaternion.IDENTITY.slerp(chest, 0.5)
		var psh: Quaternion = sk.get_bone_global_pose(_b["sh"]).basis.get_rotation_quaternion()
		var ua0: Quaternion = sk.get_bone_pose_rotation(_b["ua"])
		var fa0: Quaternion = sk.get_bone_pose_rotation(_b["fa"])
		var g: Array[Quaternion] = _solve(psh, c, GUARD_UA + FLINCH_UA * flinch, GUARD_FA, GUARD_N + FLINCH_N * flinch)
		var f: Array[Quaternion] = _solve(psh, c, FLING_UA, FLING_FA, FLING_N)
		var ua: Quaternion = ua0.slerp(g[0], clampf(guard, 0.0, 1.0)).slerp(f[0], clampf(fling, 0.0, 1.0))
		var fa: Quaternion = fa0.slerp(g[1], clampf(guard, 0.0, 1.0)).slerp(f[1], clampf(fling, 0.0, 1.0))
		sk.set_bone_pose_rotation(_b["ua"], ua.normalized())
		sk.set_bone_pose_rotation(_b["fa"], fa.normalized())

	## 위팔이 u, 아래팔이 d를 향하고 방패 앞면이 n을 보게 하는 두 뼈의 지역 돌기 [위팔, 아래팔].
	## 위팔의 비틀기는 팔꿈치 경첩이 u × d가 되게 잡는다(팔꿈치가 자연스럽게 굽는다).
	func _solve(psh: Quaternion, c: Quaternion, u_dir: Vector3, d_dir: Vector3, n_dir: Vector3) -> Array[Quaternion]:
		var u: Vector3 = (c * u_dir).normalized()
		var d: Vector3 = (c * d_dir).normalized()
		var n: Vector3 = c * n_dir
		var hinge: Vector3 = u.cross(d)
		if hinge.length() < 0.001:
			hinge = u.cross(Vector3.UP)
		var gua: Quaternion = EnemyMotion._frame(_ua_axis, _ua_hinge, u, hinge)
		var gfa: Quaternion = EnemyMotion._frame(_fa_axis, _fa_normal, d, n)
		return [psh.inverse() * gua, gua.inverse() * gfa]


# ---------------------------------------------------------------- 방패병(기사 모델이 없을 때의 도형 몸)

static func _shield_box(P: Dictionary, r: Dictionary, S: Dictionary, delta: float) -> void:
	var root: Node3D = P.root
	var torso: Node3D = P.torso
	var head: Node3D = P.head
	var arms: Array = P.arms
	var fore: Array = P.forearms
	var t: float = S.t
	var act: StringName = S.act
	var g: Dictionary = _legs(P, r, S, delta, 1.8, 1.9, 0.45, 2.4, 0.0)
	var ph: float = g.ph
	var run: float = g.run
	var rr: Vector3 = g.rr
	var rp: Vector3 = g.rp
	var attack: float = S.attack
	var slashing: bool = attack >= 0.0 and attack < 0.7
	var breaking: bool = act == &"guard_break"
	var up: bool = bool(S.guard) and not slashing and not breaking and not bool(S.stunned)
	var guard: float = _ease_to(r, "guard", 1.0 if up else 0.0, 9.0 if up else 7.0, delta)
	var T: float = _time(S)
	var at: float = S.act_t
	var fling: float = smoothstep(0.0, 0.12, at) * (1.0 - smoothstep(T - 0.35, T, at)) if breaking else 0.0
	var bs: float = _since(r, S, &"block")
	var flinch: float = smoothstep(0.0, 0.04, bs) * (1.0 - smoothstep(0.08, 0.34, bs)) if bs < 0.4 else 0.0
	_turn(torso, Vector3(-0.06 * run - 0.08 * guard + 0.18 * flinch, 0.07 * run * sin(ph), 0.0))
	# 방패 팔: 들면 팔뚝을 가슴 앞으로 올리고 방패를 몸 기준으로 곧게 앞을 보게 세운다
	_turn(arms[0], Vector3(0.75 * guard - 0.3 * flinch, -0.4 * guard, -0.05 * guard) + Vector3(-0.4, 0.0, -1.1) * fling)
	_turn(fore[0], Vector3(0.35 * guard, 0.0, 0.0) + Vector3(-0.8, 0.0, 0.0) * fling)
	var holder := P.get("shield") as Node3D
	if holder:
		var sc: Vector3 = holder.scale
		var want: Basis = EnemyArt._basis_to(fore[0], root).inverse() * Basis.from_euler(Vector3(-0.05, 0.12, 0.0))
		var b: Basis = holder.basis.orthonormalized().slerp(want.orthonormalized(), guard * (1.0 - fling))
		holder.basis = b.scaled(sc)
	# 칼 팔: 들어 올렸다(0~0.18초) 비스듬히 내려 벤다(0.18~0.32초), 0.7초에 돌아온다
	_turn(arms[1], Vector3(-0.2 * run * sin(ph), 0.0, 0.0))
	if slashing:
		var up_k: float = smoothstep(0.0, 0.18, attack) * (1.0 - smoothstep(0.18, 0.32, attack))
		var down_k: float = smoothstep(0.18, 0.32, attack) * (1.0 - smoothstep(0.45, 0.7, attack))
		_turn(arms[1], Vector3(2.2, 0.0, 0.5) * up_k + Vector3(0.6, 0.0, -0.5) * down_k)
		_turn(fore[1], Vector3(0.6, 0.0, 0.0) * up_k + Vector3(-0.4, 0.0, 0.0) * down_k)
		_turn(torso, Vector3(0.0, -0.3 * up_k + 0.35 * down_k, 0.0))
	if breaking or bool(S.stunned):
		var env: float = (smoothstep(0.0, 0.2, at) * (1.0 - smoothstep(T - 0.3, T, at))) if breaking else 1.0
		_turn(torso, Vector3(-0.12 + 0.07 * sin(t * 3.7), 0.1 * sin(t * 2.3), -0.12 * sin(t * 2.9 + 0.6)) * env)
		_turn(head, Vector3(-0.25 - 0.08 * sin(t * 4.1), 0.15 * sin(t * 1.9), 0.2 * sin(t * 2.9 + 1.2)) * env)
		rr.z += 0.05 * sin(t * 2.9) * env
	rr.x += RECOIL * float(S.recoil)
	_place_root(root, r, rr, rp)


# ---------------------------------------------------------------- 돌격병

## 다리 순서 [앞왼, 앞오, 뒤왼, 뒤오]마다 위상(한 주기에 대한 비율). 걷기는 4박(뒤왼 → 앞왼 → 뒤오 → 앞오), 뛰기는 돌며 뛰기.
const CHARGER_WALK: Array[float] = [0.25, 0.75, 0.0, 0.5]
const CHARGER_GALLOP: Array[float] = [0.55, 0.67, 0.0, 0.12]

static func _charger(P: Dictionary, r: Dictionary, S: Dictionary, delta: float) -> void:
	var root: Node3D = P.root
	var torso: Node3D = P.torso
	var head: Node3D = P.head
	var tail := P.get("tail") as Node3D
	var legs: Array = P.legs
	var knees: Array = P.knees
	var act: StringName = S.act
	var t: float = S.t
	var id: float = float(S.id)
	var p: float = _progress(S)
	var spd: float = S.speed
	var charging: bool = act == &"charge"
	var gal: float = _ease_to(r, "gallop", 1.0 if charging else 0.0, 12.0, delta)
	var wind: float = _ease_to(r, "wind_w", 1.0 if act == &"wind" else 0.0, 12.0, delta)
	var ws: float = _ease_to(r, "wait_w", 1.0 if act == &"wait" else 0.0, 6.0, delta)
	var es: float = _since(r, S, &"charge_end")
	var end_on: bool = act == &"charge_end" or bool(S.stunned)
	var T: float = _time(S) if act == &"charge_end" else 1.0
	# 걸음 위상: 걷기는 한 주기 1.6m, 뛰기는 5m에 초당 3.3번까지
	var stride: float = lerpf(1.6, 5.0, gal)
	var ph: float = _advance(r, "ph", maxf(spd, 9.0 * gal), stride, lerpf(2.0, 3.3, gal), delta, bool(S.backing))
	var side: float = S.side
	var lateral: float = absf(side) if absf(side) > 0.05 else spd
	var sph: float = _advance(r, "sph", lateral, 1.2, 1.8, delta, side < 0.0)
	var walk: float = clampf(spd / 3.0, 0.0, 1.0) * (1.0 - gal) * (1.0 - ws) * (1.0 - wind)
	var sidew: float = clampf(lateral / 2.0, 0.0, 1.0) * ws * (1.0 - gal)
	var tr := Vector3.ZERO
	var tp := Vector3.ZERO
	var hd := Vector3.ZERO
	var rr := Vector3.ZERO
	var rp := Vector3.ZERO
	for i in 4:
		var front: bool = i < 2
		var sgn: float = -1.0 if i % 2 == 0 else 1.0
		var qw: float = ph + TAU * CHARGER_WALK[i]
		var qg: float = ph + TAU * CHARGER_GALLOP[i]
		var hip := Vector3.ZERO
		var knee := 0.0
		# 걷기: 무겁게 내딛고, 드는 동안 앞다리는 무릎을 뒤로, 뒷다리는 오금을 앞으로 접는다
		var bw: float = maxf(0.0, sin(qw + 1.87))
		hip.x += 0.42 * walk * sin(qw)
		knee += (-1.0 if front else 0.75) * bw * walk
		# 뛰기: 크게 뻗고 크게 접는다
		var bg: float = maxf(0.0, sin(qg + 1.7))
		hip.x += (0.7 if front else 0.6) * gal * sin(qg)
		knee += (-1.5 if front else 1.1) * bg * gal
		# 게걸음: 대각선 짝(앞왼·뒤오, 앞오·뒤왼)이 같이 옆으로 내딛고 엇갈린다
		var qs: float = sph + (0.0 if i == 0 or i == 3 else PI)
		hip.z += 0.2 * sidew * sin(qs)
		hip.x += -sgn * 0.08 * sidew * sin(qs) * (1.0 if front else -1.0)
		knee += (-0.5 if front else 0.4) * sidew * maxf(0.0, cos(qs))
		legs[i].rotation += hip
		knees[i].rotation.x += knee
	# 걷기: 몸이 좌우로 구르고 걸음마다 가라앉으며 머리가 끄덕인다
	tr.z += 0.05 * walk * sin(ph)
	tp.y += -0.03 * walk * (0.5 - 0.5 * cos(2.0 * ph))
	tr.x += 0.02 * walk * sin(2.0 * ph)
	hd.x += -0.07 * walk * sin(2.0 * ph + 0.6)
	rr.z += -0.04 * signf(side if absf(side) > 0.05 else 1.0) * sidew
	# 뛰기: 몸을 앞으로 기울여 흔들고 솟았다 내려앉는다. 머리는 낮게 뿔로 앞을 겨눈다
	tr.x += gal * (-0.07 + 0.09 * sin(ph + 0.6))
	tp.y += gal * (0.06 * cos(ph - 1.0) - 0.04)
	hd.x += gal * (-0.42 + 0.05 * sin(ph))
	# 돌진 전: 머리를 낮추고 몸을 낮춰 굳히며, 앞오른발로 땅을 두 번 긁는다. 몸이 가늘게 떤다
	if wind > 0.001:
		var we: float = smoothstep(0.0, 1.0, wind)
		hd.x += -0.4 * we + 0.04 * sin(t * 13.0 + id)
		hd.z += 0.03 * sin(t * 9.0)
		tr.x += -0.05 * we
		tp.y += -0.06 * we
		tp.x += 0.006 * sin(t * 53.0 + id) * we
		tp.z += 0.005 * sin(t * 61.0) * we
		# 뒷다리를 몸 밑으로 모으고 앞다리는 버틴다
		for i in [2, 3]:
			legs[i].rotation.x += 0.22 * we
			knees[i].rotation.x += 0.18 * we
		legs[0].rotation.x += 0.1 * we
		# 긁기: 앞오른발을 앞으로 들었다가 뒤로 긁는다(0.7초에 두 번), 끝에는 딛는다
		if act == &"wind":
			var scrape: float = 1.0 - smoothstep(0.8, 0.95, p)
			var q: float = p * _time(S) * TAU * 2.9
			legs[1].rotation.x += (0.12 + 0.32 * sin(q)) * scrape
			knees[1].rotation.x += -0.75 * maxf(0.0, sin(q + 1.3)) * scrape
	# 돌진이 끝나면: 앞발로 버텨 미끄러지며 멈추고, 머리를 흔들며 비틀거린다
	if end_on and es < T + 0.5:
		var skid: float = smoothstep(0.0, 0.06, es) * (1.0 - smoothstep(0.22, 0.45, es))
		for i in [0, 1]:
			legs[i].rotation.x += 0.45 * skid
			knees[i].rotation.x += 0.1 * skid
		for i in [2, 3]:
			legs[i].rotation.x += 0.3 * skid
			knees[i].rotation.x += 0.12 * skid
		tr.x += 0.07 * skid
		tp.y += -0.08 * skid
		hd.x += 0.25 * skid
		var dz: float = smoothstep(0.15, 0.35, es) * (1.0 - smoothstep(T - 0.25, T, es))
		if bool(S.stunned) and act != &"charge_end":
			dz = 1.0
		if dz > 0.0:
			hd += Vector3(-0.18 + 0.06 * sin(t * 3.0), 0.28 * sin(t * 4.6 + id), 0.32 * sin(t * 9.0 + id)) * dz
			tr.z += 0.07 * sin(t * 3.1 + id) * dz
			tr.y += 0.05 * sin(t * 2.2) * dz
			rp.x += 0.06 * sin(t * 3.1 + id + 0.5) * dz
			# 다리를 벌리고 무릎이 꺾였다 펴진다. 한 발씩 헛디딘다
			for i in 4:
				var sgn: float = -1.0 if i % 2 == 0 else 1.0
				legs[i].rotation.z += 0.12 * sgn * dz
			for i in [0, 1]:
				knees[i].rotation.x += -0.18 * (0.5 + 0.5 * sin(t * 5.3 + i * 2.0)) * dz
			legs[1].rotation.x += 0.25 * maxf(0.0, sin(t * 3.1 + id)) * dz
			knees[1].rotation.x += -0.4 * maxf(0.0, sin(t * 3.1 + id)) * dz
	# 꼬리: 걸을 때 흔들리고, 굳히면 들고, 달리면 뒤로 날린다
	if tail:
		tail.rotation.x += -0.15 * walk - 0.55 * wind - 1.15 * gal + 0.12 * gal * sin(ph * 2.0) + 0.06 * sin(t * 1.7 + id)
		tail.rotation.z += 0.2 * sin(t * 2.3 + id) * (1.0 - gal) + 0.25 * walk * sin(ph)
	# 맞으면 앞이 들리고 머리를 쳐든다
	var rc: float = S.recoil
	tr.x += 0.12 * rc
	hd.x += 0.2 * rc
	_turn(torso, tr)
	torso.position += tp
	_turn(head, hd)
	_place_root(root, r, rr, rp)


# ---------------------------------------------------------------- 자폭병

static func _bomber(P: Dictionary, r: Dictionary, S: Dictionary, delta: float) -> void:
	var root: Node3D = P.root
	var torso: Node3D = P.torso
	var head: Node3D = P.head
	var belly := P.get("belly") as Node3D
	var arms: Array = P.arms
	var fore: Array = P.forearms
	var act: StringName = S.act
	var t: float = S.t
	var id: float = float(S.id)
	var fuse: bool = act == &"fuse" or act == &"explode"
	var p: float = _progress(S) if act == &"fuse" else (1.0 if act == &"explode" else 0.0)
	var fw: float = _ease_to(r, "fuse_w", 1.0 if fuse else 0.0, 14.0, delta)
	var g: Dictionary = _legs(P, r, S, delta, 0.95, 4.6, 0.6, 4.5, fw)
	var ph: float = g.ph
	var run: float = g.run
	var rr: Vector3 = g.rr
	var rp: Vector3 = g.rp
	# 종종걸음: 걸음마다 통통 튀고 뒤뚱거리며 더 웅크린다. 머리는 앞을 보려 들고 이리저리 홱홱 돌린다
	rp.y += 0.035 * run * absf(cos(ph))
	rr.z += 0.1 * run * sin(ph)
	rr.y += 0.07 * run * sin(ph)
	var tr := Vector3(-0.14 * run + 0.05 * run * sin(2.0 * ph), 0.0, 0.0)
	var hd := Vector3(0.14 * run - 0.04 * run * sin(2.0 * ph), 0.14 * sin(t * 2.3 + id) + 0.06 * sin(t * 7.9 + id * 2.0), 0.0)
	for i in 2:
		var sgn: float = -1.0 if i == 0 else 1.0
		_turn(arms[i], Vector3(0.22 * run * sin(ph + (PI if i == 0 else 0.0)), 0.0, 0.1 * run * sgn * absf(sin(ph))))
		_turn(fore[i], Vector3(0.2 * run * maxf(0.0, sin(ph + (PI if i == 0 else 0.0))), 0.0, 0.0))
	# 심지: 배가 1.5배로 부풀며 점점 빠르게 떨고, 몸을 젖혀 배를 내밀고 머리를 뒤로 젖혀 울부짖는다. 팔은 배에 밀려 벌어진다
	var pulse: float = 0.5
	if fw > 0.001:
		var e: float = smoothstep(0.0, 1.0, fw)
		var hz: float = 3.0 + 13.0 * p * p
		var fph: float = fposmod(float(r.get("fuse_ph", 0.0)) + TAU * hz * delta, TAU)
		r["fuse_ph"] = fph
		pulse = 0.5 + 0.5 * sin(fph)
		var swell: float = 0.5 * pow(p, 1.2)
		if belly:
			belly.scale *= Vector3.ONE * (1.0 + swell + 0.04 * p * (pulse - 0.5))
		var amp: float = (0.005 + 0.022 * p * p) * e
		var f: float = 1.0 + p
		rp += Vector3(amp * sin(t * 41.0 * f + id), amp * 0.5 * sin(t * 59.0 * f), amp * sin(t * 67.0 * f + 1.3))
		rr.z += amp * 2.0 * sin(t * 47.0 * f + id)
		tr += Vector3(0.12 + 0.2 * p, 0.0, 0.0) * e
		hd += Vector3(0.2 + 0.35 * p + 6.0 * amp * sin(t * 53.0 * f), 0.0, 0.0) * e
		for i in 2:
			var sgn: float = -1.0 if i == 0 else 1.0
			_turn(arms[i], Vector3(-0.15 - 0.15 * p, 0.0, sgn * (0.35 + 0.45 * swell * 2.0)) * e)
			_turn(fore[i], Vector3(-0.35 - 0.2 * p, 0.0, 0.0) * e)
			_turn(P.legs[i], Vector3(0.05, 0.0, 0.17 * sgn) * e)
			_turn(P.knees[i], Vector3(-0.3, 0.0, 0.0) * e)
		rp.y -= 0.045 * e
	# 배의 불빛: 평소에는 숨 쉬듯 일렁이고, 심지가 타면 점점 빠르고 밝게 깜빡인다
	var k_idle: float = 1.0 + 0.12 * sin(t * 3.3 + id) + 0.06 * sin(t * 8.9 + id * 0.7)
	var k_fuse: float = (1.0 + 2.2 * p) * (0.7 + 0.6 * pulse)
	var k: float = lerpf(k_idle, k_fuse, smoothstep(0.0, 1.0, fw))
	_glow(P, k, k * (1.0 + 0.5 * fw))
	if bool(S.stunned):
		tr.x -= 0.15
	rr.x += RECOIL * float(S.recoil)
	_turn(torso, tr)
	_turn(head, hd)
	rr += _daze(S, head)
	_place_root(root, r, rr, rp)


# ---------------------------------------------------------------- 부르는 자

static func _caller(P: Dictionary, r: Dictionary, S: Dictionary, delta: float) -> void:
	var root: Node3D = P.root
	var torso: Node3D = P.torso
	var head: Node3D = P.head
	var arms: Array = P.arms
	var fore: Array = P.forearms
	var hands: Array = P.hands
	var staff := P.get("staff") as Node3D
	var act: StringName = S.act
	var t: float = S.t
	var id: float = float(S.id)
	var p: float = _progress(S)
	var spd: float = S.speed
	var side: float = S.side
	var ws: float = _ease_to(r, "wait_w", 1.0 if act == &"wait" else 0.0, 6.0, delta)
	var lateral: float = absf(side) if absf(side) > 0.05 else spd
	# 옷자락 아래로 걷는다: 걸음마다 좌우로 흔들리고 조금 오르내린다. 옆으로 가면 그쪽으로 기운다
	var ph: float = _advance(r, "ph", maxf(spd, lateral * ws), 1.5, 1.6, delta, bool(S.backing))
	var run: float = clampf(maxf(spd, lateral * ws) / 2.6, 0.0, 1.0)
	var rr := Vector3(0.0, 0.0, -0.05 * ws * signf(side if absf(side) > 0.05 else 1.0))
	var rp := Vector3(0.0, 0.02 * run * cos(2.0 * ph) + 0.015 * sin(t * 1.3 + id), 0.0)
	var tr := Vector3(-0.06 * run * (1.0 - ws), 0.05 * run * sin(ph), 0.035 * run * sin(ph))
	var hd := Vector3(0.04 * run, -0.04 * run * sin(ph), -0.02 * run * sin(ph))
	_turn(arms[0], Vector3(0.14 * run * sin(ph), 0.0, 0.0))
	_turn(fore[0], Vector3(0.1 * run * maxf(0.0, sin(ph)), 0.0, 0.0))
	_turn(arms[1], Vector3(-0.07 * run * sin(ph), 0.0, 0.0))
	# 불러내기(call_wind): 지팡이를 쥔 팔과 빈 팔을 머리 위로 들고(0.45초) 고개를 젖힌다. 들고 있는 동안 떤다.
	# 내려치기(call): 0.1초에 지팡이 끝을 땅에 내리꽂으며 몸을 숙이고, 0.55초부터 돌아온다.
	# arm_w = 팔을 IK로 잡는 무게, mix = 든 자세(0)에서 내려친 자세(1)로
	var cs: float = _since(r, S, &"call")
	var raised: bool = float(r.get("raised", 0.0)) > 0.5
	var arm_w: float = 0.0
	var mix: float = 0.0
	var settle: float = 0.0
	if act == &"call_wind":
		arm_w = smoothstep(0.0, 0.45, p * _time(S))
		r["raised"] = 1.0
	elif cs < 1.0:
		var down: float = clampf(cs / 0.1, 0.0, 1.0)
		mix = down * down if raised else 1.0
		arm_w = (1.0 - smoothstep(0.55, 0.95, cs)) * (1.0 if raised else smoothstep(0.0, 0.1, cs))
		settle = exp(-cs * 9.0) * minf(1.0, cs / 0.1)
	else:
		r["raised"] = 0.0
	# 끊기면(불러내다 맞아 멈춤 등) 팔을 툭 떨어뜨리지 않고 내린다
	arm_w = _ease_to(r, "arm_w", arm_w, 40.0 if arm_w > float(r.get("arm_w", 0.0)) else 8.0, delta)
	var raise: float = arm_w * (1.0 - mix)
	var strike: float = arm_w * mix
	var shake: float = 0.012 * raise * sin(t * 37.0 + id)
	tr += Vector3(0.1 * raise - 0.28 * strike, 0.0, 0.0)
	hd += Vector3(0.32 * raise - 0.15 * strike, 0.0, 0.0)
	rp.y += 0.08 * raise - 0.04 * strike
	_turn(torso, tr)
	_turn(head, hd)
	if arm_w > 0.001:
		var inv: Transform3D = torso.transform.affine_inverse()
		var r_hand: Vector3 = Vector3(0.3, 2.3, -0.12).lerp(Vector3(0.3, 1.3, -0.46), mix) + Vector3(shake, shake, 0.0)
		var r_pole: Vector3 = Vector3(1.0, 0.0, 0.4).lerp(Vector3(1.0, 0.3, 0.8), mix)
		_ik(arms[1], fore[1], hands[1], inv * r_hand, inv.basis * r_pole, arm_w)
		var l_hand: Vector3 = Vector3(-0.44, 2.22, -0.22).lerp(Vector3(-0.3, 1.45, -0.42), mix) - Vector3(shake, 0.0, shake)
		var l_pole: Vector3 = Vector3(-1.0, -0.2, 0.3).lerp(Vector3(-1.0, -0.4, 0.5), mix)
		_ik(arms[0], fore[0], hands[0], inv * l_hand, inv.basis * l_pole, arm_w)
	# 지팡이: 걸을 때는 손을 따르고, 들거나 내려칠 때는 몸 기준으로 곧게 세운다(내려친 뒤 조금 떤다)
	if staff:
		var lean_x: float = -0.12 * raise + 0.05 * settle * sin(cs * 70.0)
		var want: Basis = EnemyArt._basis_to(hands[1], root).inverse() * Basis.from_euler(Vector3(lean_x, -0.5, -0.04 + 0.04 * settle * sin(cs * 55.0)))
		staff.basis = staff.basis.slerp(want.orthonormalized(), clampf(arm_w * 3.0, 0.0, 1.0))
	# 등불의 빛: 촛불처럼 일렁이고, 불러내는 동안 밝아지며, 내려칠 때 확 번쩍인 뒤 잦아든다
	var k: float = 1.0 + 0.08 * sin(t * 9.1 + id) + 0.05 * sin(t * 23.3 + id * 1.3)
	if act == &"call_wind":
		k += 2.0 * smoothstep(0.05, 0.9, p) * (1.0 + 0.12 * sin(t * 31.0))
	elif cs < 1.0:
		k += 3.4 * exp(-maxf(0.0, cs - 0.1) * 5.0) * smoothstep(0.0, 0.1, cs) + (2.0 * (1.0 - smoothstep(0.0, 0.1, cs)) if raised else 0.0)
	_glow(P, k, k)
	rr += _daze(S, head)
	if bool(S.stunned):
		_turn(torso, Vector3(-0.08, 0.0, 0.0))
	rr.x += RECOIL * float(S.recoil)
	_place_root(root, r, rr, rp)
	_lantern(P, r, S, delta, run, ph)


## 등불을 진자로 흔든다. 갈고리가 움직인 가속도(팔·지팡이)와 몸의 빠르기 변화를 받고, 걸음마다 조금씩 민다.
static func _lantern(P: Dictionary, r: Dictionary, S: Dictionary, delta: float, run: float, ph: float) -> void:
	var lantern := P.get("lantern") as Node3D
	var staff := P.get("staff") as Node3D
	var root: Node3D = P.root
	if lantern == null or staff == null:
		return
	var s: float = float(P.get("scale", 1.0))
	var dt: float = maxf(delta, 0.0001)
	var hook: Vector3 = _xf(lantern, root).origin
	var v := Vector3.ZERO
	if r.has("hook_p"):
		v = (hook - (r["hook_p"] as Vector3)) * s / dt
	var acc: Vector3 = (v - (r.get("hook_v", v) as Vector3)) / dt
	r["hook_p"] = hook
	r["hook_v"] = v
	# 몸이 빨라지면(앞 = -Z) 등불은 뒤로 처진다. 옆도 같다
	var fwd: float = float(S.speed) * (-1.0 if bool(S.backing) else 1.0)
	acc.z -= (fwd - float(r.get("lan_fwd", fwd))) / dt
	acc.x += (float(S.side) - float(r.get("lan_side", float(S.side)))) / dt
	r["lan_fwd"] = fwd
	r["lan_side"] = float(S.side)
	acc = acc.limit_length(30.0)
	var th: Vector2 = r.get("lan_th", Vector2.ZERO)
	var om: Vector2 = r.get("lan_om", Vector2.ZERO)
	var L: float = 0.26 * s
	var grav: float = maxf(2.0, 9.8 + acc.y)
	var steps: int = clampi(ceili(dt * 120.0), 1, 12)
	var h: float = dt / steps
	for i in steps:
		var ax: float = -(grav / L) * sin(th.x) - 1.4 * om.x + (acc.z / L) * cos(th.x) + 4.0 * run * sin(ph)
		var az: float = -(grav / L) * sin(th.y) - 1.4 * om.y - (acc.x / L) * cos(th.y) + 3.0 * run * cos(ph)
		om += Vector2(ax, az) * h
		th += om * h
	th = th.clamp(Vector2(-1.1, -1.1), Vector2(1.1, 1.1))
	r["lan_th"] = th
	r["lan_om"] = om
	lantern.basis = EnemyArt._basis_to(staff, root).inverse() * Basis.from_euler(Vector3(th.x, 0.0, th.y))


# ---------------------------------------------------------------- 걷기(두 다리)

## 두 다리(legs·knees)의 걸음. 앞뒤 걷기(뒤로 걸으면 거꾸로 돈다)와 게걸음(wait: 옆으로, 두 다리가 엇갈린다)을 섞는다.
## stride = 한 주기(두 걸음)에 나아가는 거리(m), max_hz = 다리를 놀리는 가장 빠른 횟수, amp = 엉덩이 흔들림(라디안),
## full = 이 빠르기(m/초)에서 다 흔든다, plant = 1이면 발을 딛고 선다(겨누기, 심지).
## 돌려주는 것: ph(위상), run(0~1), rp(뿌리 위치에 더할 것: 다리가 기운 만큼 내려앉기), rr(뿌리 돌기에 더할 것: 옆으로 기울기)
static func _legs(P: Dictionary, r: Dictionary, S: Dictionary, delta: float, stride: float, max_hz: float, amp: float, full: float, plant: float) -> Dictionary:
	var legs: Array = P.get("legs", [])
	var knees: Array = P.get("knees", [])
	var ws: float = _ease_to(r, "wait_w", 1.0 if S.act == &"wait" else 0.0, 6.0, delta)
	var side: float = S.side
	var spd: float = S.speed
	var back: bool = S.backing
	var lateral: float = absf(side) if absf(side) > 0.05 else spd
	var run_f: float = clampf(spd / full, 0.0, 1.15) * (1.0 - plant) * (1.0 - ws)
	var run_s: float = clampf(lateral / (full * 0.6), 0.0, 1.0) * (1.0 - plant) * ws
	var ph: float = _advance(r, "ph", spd, stride, max_hz, delta, back)
	var sph: float = _advance(r, "sph", lateral, stride * 0.55, max_hz, delta, side < 0.0)
	var ss: float = sin(sph)
	var cs: float = cos(sph)
	for i in mini(legs.size(), 2):
		var sgn: float = -1.0 if i == 0 else 1.0
		var q: float = ph + (0.0 if i == 0 else PI)
		var hip := Vector3(amp * run_f * sin(q), 0.0, 0.0)
		# 드는 동안 무릎을 굽힌다(뒤로 걸을 때는 거꾸로 돈 위상에 맞춘다)
		var bend: float = maxf(0.0, sin((-q if back else q) + 1.87)) * run_f
		# 게걸음: 왼다리는 앞으로, 오른다리는 뒤로 지나가며 엇갈렸다 벌어진다. 옮기는 다리의 무릎을 굽힌다
		hip.z += -sgn * 0.24 * run_s * ss
		hip.x += -sgn * 0.12 * run_s * ss
		bend += 0.55 * run_s * maxf(0.0, -sgn * cs)
		(legs[i] as Node3D).rotation += hip
		if i < knees.size():
			(knees[i] as Node3D).rotation.x -= bend
	var tilt: float = maxf(amp * run_f * absf(sin(ph)), 0.24 * run_s * absf(ss))
	var leg_len: float = r.get("leg_len", 0.0)
	var rp := Vector3(0.0, -leg_len * (1.0 - cos(tilt)) + 0.012 * run_f * cos(2.0 * ph), 0.0)
	var rr := Vector3(0.0, 0.0, -0.05 * run_s * (signf(side) if absf(side) > 0.05 else 1.0))
	return {"ph": ph, "run": run_f, "side": run_s, "sph": sph, "rp": rp, "rr": rr}


# ---------------------------------------------------------------- 안쪽

static func _state(state: Dictionary) -> Dictionary:
	return {
		"act": StringName(state.get("act", &"")),
		"act_t": float(state.get("act_t", 0.0)),
		"act_time": float(state.get("act_time", 0.0)),
		"speed": float(state.get("speed", 0.0)),
		"side": float(state.get("side", 0.0)),
		"backing": bool(state.get("backing", false)),
		"t": float(state.get("t", 0.0)),
		"guard": bool(state.get("guard", true)),
		"stunned": bool(state.get("stunned", false)),
		"id": int(state.get("id", 0)),
		"recoil": float(state.get("recoil", 0.0)),
		"attack": float(state.get("attack", -1.0)),
		"hit": float(state.get("hit", -1.0)),
	}


## 행동이 바뀌거나(같은 행동이라도 act_t가 줄면) 시작한 때를 적어 둔다. 행동이 금방 끝나도 뒤따르는 움직임을 이어 그린다.
static func _track(r: Dictionary, S: Dictionary) -> void:
	var act: StringName = S.act
	var at: float = S.act_t
	if act != (r["act"] as StringName) or at < float(r["act_t"]) - 0.0001:
		if act != &"":
			(r["since"] as Dictionary)[act] = float(S.t) - at
	r["act"] = act
	r["act_t"] = at


## act가 마지막으로 시작하고 지난 초(없으면 아주 큰 값).
static func _since(r: Dictionary, S: Dictionary, act: StringName) -> float:
	var since: Dictionary = r["since"]
	return float(S.t) - float(since[act]) if since.has(act) else 1e9


static func _time(S: Dictionary) -> float:
	var T: float = S.act_time
	return T if T > 0.0 else float(TIME.get(S.act, 0.5))


## 지금 행동의 진행(0~1).
static func _progress(S: Dictionary) -> float:
	return clampf(float(S.act_t) / _time(S), 0.0, 1.0)


## r[key]를 target 쪽으로 부드럽게 옮긴다(처음에는 바로 target).
static func _ease_to(r: Dictionary, key: String, target: float, rate: float, delta: float) -> float:
	var v: float = lerpf(float(r.get(key, target)), target, 1.0 - exp(-rate * delta))
	r[key] = v
	return v


## 걸음 위상을 나아간 거리만큼 돌린다(뒤로면 거꾸로).
static func _advance(r: Dictionary, key: String, speed: float, stride: float, max_hz: float, delta: float, back: bool) -> float:
	var hz: float = minf(absf(speed) / stride, max_hz)
	var ph: float = fposmod(float(r.get(key, 0.0)) + TAU * hz * delta * (-1.0 if back else 1.0), TAU)
	r[key] = ph
	return ph


## 잡아 둔 부품을 모두 쉬는 자세로 되돌린다. 그 위에 이번 프레임의 움직임을 더한다.
static func _reset(P: Dictionary, r: Dictionary) -> void:
	var xf: Dictionary = r["xf"]
	for k in xf:
		var v: Variant = xf[k]
		if v is Transform3D:
			var n := P.get(k) as Node3D
			if n:
				n.transform = v
		else:
			var a: Array = P.get(k, [])
			var rest_a: Array = v
			for i in mini(a.size(), rest_a.size()):
				(a[i] as Node3D).transform = rest_a[i]


static func _turn(n: Node3D, add: Vector3) -> void:
	if n:
		n.rotation += add


## 몸 전체(parts.root)를 발밑을 축으로 돌리고(rr: x = 뒤로 젖힘, y, z = 왼쪽으로 기욺) 옮긴다(rp).
static func _place_root(root: Node3D, r: Dictionary, rr: Vector3, rp: Vector3) -> void:
	var x: Transform3D = (r["xf"] as Dictionary)["root"]
	root.transform = Transform3D(Basis.from_euler(rr) * x.basis, x.origin + rp)


## 기절: 몸이 천천히 흔들리고 고개가 떨어진다. 뿌리 돌기에 더할 것을 돌려준다(기절이 아니면 0).
static func _daze(S: Dictionary, head: Node3D) -> Vector3:
	if not bool(S.stunned):
		return Vector3.ZERO
	var t: float = S.t
	var id: float = float(S.id)
	_turn(head, Vector3(-0.3 + 0.08 * sin(t * 3.3), 0.15 * sin(t * 2.1 + id), 0.18 * sin(t * 2.8 + id + 1.0)))
	return Vector3(0.03 * sin(t * 1.9 + id), 0.0, 0.07 * sin(t * 2.8 + id))


## 빛 재질과 불빛에 바탕값의 k배(불빛은 light_k배)를 준다.
static func _glow(P: Dictionary, k: float, light_k: float) -> void:
	for m in P.get("glow", []):
		var sm := m as StandardMaterial3D
		if sm:
			sm.emission_energy_multiplier = float(sm.get_meta("base_energy", 1.0)) * maxf(0.0, k)
	var l := P.get("light") as Light3D
	if l:
		l.light_energy = float(l.get_meta("base_energy", 1.0)) * maxf(0.0, light_k)


## node의 변환을 top 기준으로(top 자신은 빼고) 모은다. 트리 밖에서도 된다.
static func _xf(node: Node3D, top: Node3D) -> Transform3D:
	var x := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != top and n is Node3D:
		x = (n as Node3D).transform * x
		n = n.get_parent()
	return x


## 두 마디 팔(어깨 → 팔꿈치 → 손 피벗, -Y로 곧게 지은 것)의 손 피벗을 target(어깨 부모의 공간)에 닿게 한다.
## pole = 팔꿈치가 향할 쪽(같은 공간의 방향). w(0~1)로 지금 자세에서 섞는다. 닿지 않으면 그쪽으로 곧게 뻗는다.
static func _ik(sh: Node3D, el: Node3D, hand: Node3D, target: Vector3, pole: Vector3, w: float) -> void:
	if w <= 0.0005:
		return
	var a: float = el.position.length()
	var b: float = hand.position.length()
	var s0: Vector3 = sh.position
	var to: Vector3 = target - s0
	var n: Vector3 = to.normalized() if to.length() > 0.0001 else Vector3.DOWN
	var d: float = clampf(to.length(), absf(a - b) + 0.01, a + b - 0.002)
	var pp: Vector3 = pole - n * pole.dot(n)
	if pp.length() < 0.0001:
		pp = n.cross(Vector3.RIGHT if absf(n.x) < 0.9 else Vector3.UP)
	pp = pp.normalized()
	var ca: float = clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var u: Vector3 = n * ca + pp * sqrt(1.0 - ca * ca)
	var f: Vector3 = (n * d - u * a).normalized()
	var flex: float = acos(clampf(u.dot(f), -1.0, 1.0))
	var wv: Vector3 = f - u * f.dot(u)
	if wv.length() < 0.0001:
		wv = -(pp - u * pp.dot(u))
	var y: Vector3 = -u
	var z: Vector3 = -wv.normalized()
	var x: Vector3 = y.cross(z).normalized()
	var want := Basis(x, y, z)
	sh.basis = sh.basis.orthonormalized().slerp(want.orthonormalized(), w)
	el.rotation = el.rotation.lerp(Vector3(flex, 0.0, 0.0), w)


## al → aw, bl → bw(각각 al·aw에 수직인 성분)로 보내는 돌기.
static func _frame(al: Vector3, bl: Vector3, aw: Vector3, bw: Vector3) -> Quaternion:
	var a1: Vector3 = al.normalized()
	var b1: Vector3 = (bl - a1 * bl.dot(a1)).normalized()
	var a2: Vector3 = aw.normalized()
	var b2: Vector3 = (bw - a2 * bw.dot(a2)).normalized()
	var m1 := Basis(a1, b1, a1.cross(b1))
	var m2 := Basis(a2, b2, a2.cross(b2))
	return (m2 * m1.inverse()).get_rotation_quaternion()
