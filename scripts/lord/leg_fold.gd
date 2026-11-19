class_name LegFold
extends SkeletonModifier3D
## 걸어 다니는 점프(30단계): Mixamo 기사(LordCharacter)의 다리를 코드로 굽힌다. hop 동작 파일이 없을 때만 쓴다.
## 동작(AnimationPlayer)이 정한 자세 위에 얹는다(SkeletonModifier3D는 동작 뒤에 돈다).
## 뼈대 공간은 Mixamo 그대로 +Y가 위, +Z가 몸 앞이다(LordCharacter._grip_transform과 같은 뜻). 그래서 뼈대 X축으로 돌리면
## 다리가 앞뒤로 굽는다: 허벅지를 -각(무릎이 앞으로), 정강이를 +각(발이 뒤로). 뼈마다 쉬는 자세의 축과 상관없다.
##   bend: 선 채로 무릎 굽힘. 허벅지 BEND_THIGH, 정강이 그 두 배라 발이 엉덩이 밑에 남는다(몸은 LordView가 LordCharacter.bend_drop만큼 내린다).
##   tuck: 공중에서 다리 접기. 허벅지를 TUCK_THIGH 올리고 정강이를 TUCK_SHIN 접는다.

const LEGS: Array = [
	["mixamorig_LeftUpLeg", "mixamorig_LeftLeg", "mixamorig_LeftFoot"],
	["mixamorig_RightUpLeg", "mixamorig_RightLeg", "mixamorig_RightFoot"],
]
## 라디안. 무릎 굽힘의 허벅지(정강이는 두 배), 공중에서 접을 때 허벅지와 정강이.
const BEND_THIGH: float = 0.62
const TUCK_THIGH: float = 1.15
const TUCK_SHIN: float = 1.75
## 공중에서 발끝을 아래로 두는 정도(1이면 발바닥이 땅과 나란하게 되돌린다).
const TUCK_FOOT_KEEP: float = 0.5

var bend: float = 0.0
var tuck: float = 0.0


func _process_modification_with_delta(_delta: float) -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk != null:
		LegFold.fold(sk, tuck, bend)


## 허벅지·정강이·발을 돌리는 각(뼈대 X축, 라디안).
static func angles(p_tuck: float, p_bend: float) -> Vector3:
	var thigh: float = -(BEND_THIGH * p_bend + TUCK_THIGH * p_tuck)
	var shin: float = 2.0 * BEND_THIGH * p_bend + TUCK_SHIN * p_tuck
	var foot: float = -(BEND_THIGH * p_bend) - TUCK_FOOT_KEEP * (TUCK_SHIN - TUCK_THIGH) * p_tuck
	return Vector3(thigh, shin, foot)


## 지금 자세(동작이 정한 것) 위에 다리를 굽힌다. 테스트는 만든 뼈대로 바로 부른다.
static func fold(sk: Skeleton3D, p_tuck: float, p_bend: float) -> void:
	if p_tuck <= 0.001 and p_bend <= 0.001:
		return
	var a: Vector3 = angles(p_tuck, p_bend)
	for leg in LEGS:
		var up: int = sk.find_bone(leg[0])
		var lo: int = sk.find_bone(leg[1])
		if up < 0 or lo < 0:
			continue
		_turn(sk, up, a.x)
		_turn(sk, lo, a.y)
		var ft: int = sk.find_bone(leg[2])
		if ft >= 0:
			_turn(sk, ft, a.z)


## 뼈 하나를 뼈대 X축으로 ang만큼 더 돌린다(부모의 지금 자세로 축을 뼈의 자리로 옮긴다).
static func _turn(sk: Skeleton3D, b: int, ang: float) -> void:
	var parent: int = sk.get_bone_parent(b)
	var pg: Basis = sk.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	var axis: Vector3 = (pg.inverse() * Vector3.RIGHT).normalized()
	sk.set_bone_pose_rotation(b, (Quaternion(axis, ang) * sk.get_bone_pose_rotation(b)).normalized())
