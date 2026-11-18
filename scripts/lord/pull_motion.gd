class_name PullMotion
extends RefCounted
## 뽑는 동안 영주의 몸(14단계, 모양팀). docs/content.md 14단계 "버팀 타이밍".
## 뽑는 동안 무릎을 굽혀 엉덩이를 뒤로 빼고 상체를 젖혀 버티며, 두 팔은 손잡이 쪽으로 곧게 뻗고 몸이 떤다(버틸수록 더).
## 제대로 당김(pull_good)마다 한 번 크게 젖히며 팔을 당기고, 모두 제대로(pull_perfect)에서 마지막으로 가장 크게 젖힌다.
## 모두 코드 곡선(sin 떨림, 키 곡선)이고 랜덤은 쓰지 않는다.
##
## 기사 모델(LordCharacter)이 있으면 그 뼈대(Skeleton3D) 아래에 PullRig(SkeletonModifier3D) 하나를 스스로 붙여
## 동작(서기, "pull" 동작이 있으면 그것) 위에 뼈를 덮어쓴다(EnemyMotion의 ShieldRig와 같은 방식). 뽑기가 끝나면 무게가 0으로
## 줄어 원래 동작만 남는다. 기본 도형(character == null)이면 몸 전체를 발을 축으로 뒤로 젖히고 낮추는 것만 한다.
##
## LordView는 이렇게 쓴다:
##   1) 영주 하나에 한 번: var _pull := PullMotion.rest()
##   2) Rules.pull_good(hilt, step) → PullMotion.good(_pull, step)
##      Rules.pull_perfect(hilt)    → PullMotion.perfect(_pull)
##   3) draw()에서 매 프레임, MoveMotion.apply 바로 앞에서:
##        var add: Dictionary = PullMotion.pose(_pull, {"pulling": rules.pull_hilt != null, "steps": rules.pull_steps}, delta, character)
##        pose = PullMotion.add(pose, add)        # pose = MoveMotion.pose(…)의 결과
##        MoveMotion.apply(_model, pose, _yaw_now, _air)
##      state 열쇠(없으면 기본값):
##        pulling: bool   지금 손잡이를 잡고 있다(rules.pull_hilt != null). 꺼지면 버티기가 부드럽게 풀린다
##        steps: int      지금까지 버틴 단계(rules.pull_steps). 많을수록 더 떤다
##      돌려주는 것은 MoveMotion.pose와 같은 열쇠(yaw, y, pitch, crouch, push, scale_y)의 "더할 값"이다(scale_y는 곱할 값).
##      pulling이 꺼진 뒤에도 perfect의 젖힘이 끝날 때까지(PERFECT_TIME) 계속 부른다. active(_pull)가 거짓이면 0을 돌려준다.
##   4) 손잡이 쪽을 보게: 뽑는 동안 _yaw_now를 PullMotion.face_yaw(position, 손잡이 세계 좌표)로 돌린다(빠르게 lerp_angle).
##      팔이 손잡이 쪽으로 뻗으므로 몸이 손잡이를 봐야 맞는다.
##   5) 손의 칼: 두 손으로 손잡이를 잡는 자세라 쥔 칼이 손에서 삐져나와 보인다. 뽑는 동안 character.set_sword_visible(false),
##      끝나면 true로 되돌리길 권한다(칼 던지기의 숨김과 겹치지 않게 LordView가 정한다).
## 좌표: 뼈대 공간은 Mixamo의 것(앞 +Z, 왼쪽 +X, 위 +Y). 모델 노드의 앞은 -Z이고 pitch > 0이 앞으로 숙임(MoveMotion과 같다).

## 버티기로 들어가고 풀리는 빠르기(1/초).
const STRAIN_IN: float = 7.0
const STRAIN_OUT: float = 4.5
## 제대로 당김의 젖힘 곡선 [초, 값 …]과 길이. 모두 제대로는 더 길고 크다.
const GOOD_CURVE: Array[float] = [0.0, 0.0, 0.06, 1.0, 0.16, 0.85, 0.5, 0.0]
const GOOD_TIME: float = 0.5
const PERFECT_CURVE: Array[float] = [0.0, 0.0, 0.09, 1.0, 0.35, 0.95, 0.85, 0.0]
const PERFECT_TIME: float = 0.85
## 뼈 각도(라디안). 버티기(strain 1)일 때와 젖힘(heave 1)일 때 더하는 값. 모두 제대로는 heave에 PERFECT_MUL을 곱한다.
const KNEE: float = 0.55
const KNEE_HEAVE: float = 0.16
const LEAN: float = 0.5
const LEAN_HEAVE: float = 0.36
const HEAD_DOWN: float = 0.34
const HEAD_HEAVE: float = 0.3
const PERFECT_MUL: float = 1.5
## 떨림 폭(라디안, strain 1·0단계). 단계마다 TREMBLE_STEP씩 커진다.
const TREMBLE: float = 0.014
const TREMBLE_STEP: float = 0.45
## 기본 도형: 발을 축으로 뒤로 젖히는 각, 낮추는 높이(m), 젖힘에 뒤로 물러나는 거리(m).
const BOX_LEAN: float = 0.2
const BOX_LEAN_HEAVE: float = 0.14
const BOX_CROUCH: float = 0.12
const BOX_PUSH_HEAVE: float = 0.08


## 영주 하나의 움직임 상태. LordView가 들고 있다가 good·perfect·pose에 넘긴다.
static func rest() -> Dictionary:
	return {"strain": 0.0, "good_t": -1.0, "good_step": 0, "perfect_t": -1.0, "t": 0.0, "rig": null}


## 제대로 당김(pull_good). step: 몇 번째 버팀인지(클수록 조금 더 세게).
static func good(m: Dictionary, step: int) -> void:
	m["good_t"] = 0.0
	m["good_step"] = step


## 모두 제대로(pull_perfect). 마지막으로 가장 크게 젖힌다.
static func perfect(m: Dictionary) -> void:
	m["perfect_t"] = 0.0


## 버티기나 젖힘이 보이는 중인지.
static func active(m: Dictionary) -> bool:
	return float(m.strain) > 0.001 or _running(m, "good_t", GOOD_TIME) or _running(m, "perfect_t", PERFECT_TIME)


## 매 프레임. 상태를 delta만큼 진행하고, 기사 모델이면 뼈를 덮어쓰고, 모델 노드에 더할 값을 돌려준다(머리말 3).
static func pose(m: Dictionary, state: Dictionary, delta: float, character: LordCharacter) -> Dictionary:
	var out: Dictionary = {"yaw": 0.0, "y": 0.0, "pitch": 0.0, "crouch": 0.0, "push": 0.0, "scale_y": 1.0}
	var pulling: bool = bool(state.get("pulling", false))
	var steps: int = int(state.get("steps", 0))
	var s: float = float(m.strain)
	var target: float = 1.0 if pulling else 0.0
	s = lerpf(s, target, 1.0 - exp(-(STRAIN_IN if pulling else STRAIN_OUT) * delta))
	if not pulling and s < 0.002:
		s = 0.0
	m["strain"] = s
	m["t"] = float(m.t) + delta
	var heave: float = 0.0
	var gt: float = float(m.good_t)
	if gt >= 0.0:
		var k: float = 1.0 + 0.12 * clampf(float(int(m.good_step) - 1), 0.0, 4.0)
		heave = maxf(heave, _curve(GOOD_CURVE, gt) * k)
		m["good_t"] = gt + delta if gt + delta < GOOD_TIME else -1.0
	var pt: float = float(m.perfect_t)
	var final: float = 0.0
	if pt >= 0.0:
		final = _curve(PERFECT_CURVE, pt)
		m["perfect_t"] = pt + delta if pt + delta < PERFECT_TIME else -1.0
	var h: float = maxf(heave, final * PERFECT_MUL)
	var t: float = float(m.t)
	var amp: float = TREMBLE * s * (1.0 + TREMBLE_STEP * float(steps)) * (1.0 - 0.6 * clampf(h, 0.0, 1.0))
	var tr := Vector3(
		sin(t * 37.0) + 0.7 * sin(t * 53.0 + 1.3),
		sin(t * 29.0 + 0.4) + 0.6 * sin(t * 47.0),
		sin(t * 41.0 + 2.1) + 0.5 * sin(t * 61.0)) * 0.5 * amp
	var rig: PullRig = _rig(m, character)
	if rig:
		rig.strain = s
		rig.heave = h
		rig.lift = clampf(heave * 0.8 + final, 0.0, 1.0)
		rig.tremble = tr
		rig.fresh = true
		rig.poke()
		# 몸 전체는 아주 조금만(뼈가 대부분을 한다)
		out["pitch"] = -0.035 * h + tr.x * 0.3
		out["yaw"] = tr.y * 0.4
		return out
	if s <= 0.0 and h <= 0.0:
		return out
	out["pitch"] = -(BOX_LEAN * s + BOX_LEAN_HEAVE * h) + tr.x
	out["crouch"] = BOX_CROUCH * s + 0.04 * h
	out["push"] = -BOX_PUSH_HEAVE * h
	out["yaw"] = tr.y
	out["scale_y"] = 1.0 - 0.04 * s
	return out


## MoveMotion.pose의 결과에 pose의 결과를 더한다(scale_y는 곱한다). 새 Dictionary를 돌려준다.
static func add(a: Dictionary, b: Dictionary) -> Dictionary:
	var out: Dictionary = a.duplicate()
	for k in ["yaw", "y", "pitch", "crouch", "push"]:
		out[k] = float(a.get(k, 0.0)) + float(b.get(k, 0.0))
	out["scale_y"] = float(a.get("scale_y", 1.0)) * float(b.get("scale_y", 1.0))
	return out


## 모델(앞 -Z)이 from에서 to를 보게 하는 돌기(LordView._yaw_now와 같은 뜻). 세계 좌표.
static func face_yaw(from: Vector3, to: Vector3) -> float:
	var d: Vector3 = to - from
	return atan2(-d.x, -d.z)


# ---------------------------------------------------------------- 안쪽

static func _running(m: Dictionary, key: String, _time: float) -> bool:
	return float(m.get(key, -1.0)) >= 0.0


## 키 곡선 [초, 값, …] 사이를 부드럽게(smoothstep) 잇는다.
static func _curve(keys: Array[float], t: float) -> float:
	if keys.size() < 2:
		return 0.0
	if t <= keys[0]:
		return keys[1]
	for i in range(2, keys.size(), 2):
		if t <= keys[i]:
			var t0: float = keys[i - 2]
			var u: float = (t - t0) / maxf(0.0001, keys[i] - t0)
			return lerpf(keys[i - 1], keys[i + 1], smoothstep(0.0, 1.0, u))
	return keys[keys.size() - 1]


static func _rig(m: Dictionary, c: LordCharacter) -> PullRig:
	if c == null:
		return null
	var o: Variant = m.get("rig")
	if o != null and is_instance_valid(o):
		return o as PullRig
	var sk := c.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null or not sk.is_inside_tree():
		return null
	var rig := PullRig.new()
	rig.name = "PullRig"
	sk.add_child(rig)
	m["rig"] = rig
	return rig


## 기사 모델의 뼈를 동작 위에 덮어쓴다(Skeleton3D의 자식). 무게(strain, heave)가 모두 0이면 아무것도 바꾸지 않는다.
## fresh가 꺼진 채 갱신되면(pose가 안 불림) 무게를 스스로 0으로 줄인다.
class PullRig extends SkeletonModifier3D:
	## 버티기(0~1), 젖힘(0~1.5), 팔을 당겨 올림(0~1), 떨림(라디안, x = 앞뒤, y = 돌기, z = 옆).
	var strain: float = 0.0
	var heave: float = 0.0
	var lift: float = 0.0
	var tremble: Vector3 = Vector3.ZERO
	var fresh: bool = false
	var _ok: bool = false
	var _b: Dictionary = {}
	var _thigh: float = 0.4
	var _shin: float = 0.4

	## 팔을 뻗는 쪽(뼈대 공간, 왼팔 기준. 오른팔은 x를 뒤집는다): 앞 아래로, 두 손이 가운데에서 만나게.
	const REACH := Vector3(-0.22, -0.74, 0.64)
	## 당길 때 팔꿈치를 몸 뒤로 끌고, 아래팔은 허리 앞으로(밧줄을 허리로 당기듯).
	const HAUL_UA := Vector3(0.12, -0.92, -0.3)
	const HAUL_FA := Vector3(-0.38, -0.12, 0.92)

	func poke() -> void:
		var sk := get_skeleton()
		if sk and _ok:
			var h: int = _b["hips"]
			sk.set_bone_pose_rotation(h, sk.get_bone_pose_rotation(h))

	func _bind(sk: Skeleton3D) -> void:
		for pair in [["hips", "Hips"], ["spine", "Spine"], ["spine1", "Spine1"], ["spine2", "Spine2"], ["head", "Head"],
				["l_ua", "LeftArm"], ["l_fa", "LeftForeArm"], ["l_hand", "LeftHand"],
				["r_ua", "RightArm"], ["r_fa", "RightForeArm"], ["r_hand", "RightHand"],
				["l_up", "LeftUpLeg"], ["l_leg", "LeftLeg"], ["l_foot", "LeftFoot"],
				["r_up", "RightUpLeg"], ["r_leg", "RightLeg"], ["r_foot", "RightFoot"]]:
			var b: int = sk.find_bone("mixamorig_" + str(pair[1]))
			if b < 0:
				return
			_b[pair[0]] = b
		var up: Vector3 = sk.get_bone_global_rest(_b["l_up"]).origin
		var knee: Vector3 = sk.get_bone_global_rest(_b["l_leg"]).origin
		var foot: Vector3 = sk.get_bone_global_rest(_b["l_foot"]).origin
		_thigh = up.distance_to(knee)
		_shin = knee.distance_to(foot)
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
			strain *= k
			heave *= k
			lift *= k
			tremble *= k
		fresh = false
		var w: float = clampf(strain + heave, 0.0, 1.0)
		if w < 0.001:
			return
		# 다리: 허벅지를 앞으로, 정강이를 뒤로 굽혀 엉덩이를 낮추고 뒤로 뺀다(발은 거의 제자리)
		var a: float = PullMotion.KNEE * strain + PullMotion.KNEE_HEAVE * heave
		var b: float = a * 0.7
		for side in [["l_up", "l_leg"], ["r_up", "r_leg"]]:
			_turn_global(sk, _b[side[0]], Quaternion(Vector3.RIGHT, -a))
			_turn_global(sk, _b[side[1]], Quaternion(Vector3.RIGHT, a + b))
		var drop: float = _thigh * (1.0 - cos(a)) + _shin * (1.0 - cos(b))
		var back: float = (_thigh * sin(a) - _shin * sin(b)) * 0.8
		var h: int = _b["hips"]
		sk.set_bone_pose_position(h, sk.get_bone_pose_position(h) + Vector3(0.0, -drop, -back))
		# 척추: 뒤로 젖힌다(세 마디에 나눈다). 떨림은 앞뒤와 옆으로
		var lean: float = -(PullMotion.LEAN * strain + PullMotion.LEAN_HEAVE * heave) + tremble.x
		var spine_turn := Quaternion.from_euler(Vector3(lean, tremble.y, tremble.z) / 3.0)
		for key in ["spine", "spine1", "spine2"]:
			_turn_global(sk, _b[key], spine_turn)
		# 머리: 손잡이를 내려다보다가 젖힐 때 뒤로 넘어간다
		var hd: float = PullMotion.HEAD_DOWN * strain - PullMotion.HEAD_HEAVE * heave + tremble.x * 1.5
		_turn_global(sk, _b["head"], Quaternion.from_euler(Vector3(hd, tremble.y * 1.5, 0.0)))
		# 팔: 손잡이 쪽으로 곧게 뻗고, 당길 때 몸 쪽으로 접어 올린다
		for side in [["l_ua", "l_fa", "l_hand", 1.0], ["r_ua", "r_fa", "r_hand", -1.0]]:
			var sx: float = side[3]
			var reach := Vector3(REACH.x * sx, REACH.y, REACH.z)
			reach += Vector3(tremble.z, tremble.x, 0.0) * 2.0
			var ua_dir: Vector3 = reach.lerp(Vector3(HAUL_UA.x * sx, HAUL_UA.y, HAUL_UA.z), lift).normalized()
			var fa_dir: Vector3 = reach.lerp(Vector3(HAUL_FA.x * sx, HAUL_FA.y, HAUL_FA.z), lift).normalized()
			_aim(sk, _b[side[0]], _b[side[1]], ua_dir, w)
			_aim(sk, _b[side[1]], _b[side[2]], fa_dir, w)

	## 뼈 b가 자식 뼈 child 쪽으로 뻗은 방향을 dir(뼈대 공간)로 weight만큼 돌린다(가장 짧게 도는 쪽으로).
	func _aim(sk: Skeleton3D, b: int, child: int, dir: Vector3, weight: float) -> void:
		var from: Vector3 = sk.get_bone_global_pose(child).origin - sk.get_bone_global_pose(b).origin
		if from.length() < 0.0001:
			return
		var q := Quaternion(from.normalized(), dir)
		_turn_global(sk, b, Quaternion.IDENTITY.slerp(q, clampf(weight, 0.0, 1.0)))

	## 뼈 b를 뼈대 공간의 돌기 q만큼 더 돌린다(뼈의 자리를 축으로).
	func _turn_global(sk: Skeleton3D, b: int, q: Quaternion) -> void:
		var parent: int = sk.get_bone_parent(b)
		var pg := Quaternion.IDENTITY
		if parent >= 0:
			pg = sk.get_bone_global_pose(parent).basis.get_rotation_quaternion()
		var lq: Quaternion = sk.get_bone_pose_rotation(b)
		sk.set_bone_pose_rotation(b, (pg.inverse() * q * pg * lq).normalized())
