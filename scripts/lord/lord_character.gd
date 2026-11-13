class_name LordCharacter
extends Node3D
## 영주 모델(Mixamo 기사). assets/characters/lord/paladin.fbx가 있으면 lord_view가 기본 도형 대신 이것을 쓴다.
## 동작은 assets/characters/lord/anims/*.fbx(Mixamo, Without Skin)에서 읽는다. 파일 이름의 낱말로 어떤 동작인지 고른다.
## 같은 Mixamo 뼈대라 동작을 그대로 옮겨 붙일 수 있다. 제자리 동작이 되게 엉덩이의 앞뒤·좌우 이동은 지운다.

const CHAR_PATH: String = "res://assets/characters/lord/paladin.fbx"
const ANIM_DIR: String = "res://assets/characters/lord/anims/"
const HAND_BONE: String = "mixamorig_RightHand"
## 파일 이름에 이 낱말이 있으면 그 동작으로 쓴다(앞의 것부터 본다). 베기는 _key_for에서 따로 고른다.
const KEYWORDS: Array = [
	["idle", "idle"], ["run", "run"], ["roll", "roll"], ["impact", "hit"], ["hit", "hit"],
	["death", "death"], ["dying", "death"], ["pull", "pull"],
]
const LOOPING: Array[String] = ["idle", "run", "pull"]

## 칼을 쥔 자리. T자세에서 손바닥 가운데, 칼날은 몸 앞쪽(엄지 쪽)으로 뻗게 스스로 맞춘다.
## 동작을 넣고 칼이 손에서 어긋나 보이면 이 두 값으로 더 맞춘다(쥔 자리 기준, 미터와 도).
@export var grip_offset: Vector3 = Vector3.ZERO
@export var grip_rotation_deg: Vector3 = Vector3.ZERO
@export var blend: float = 0.12

var anims: Dictionary = {}
var _body: Node3D
var _skel: Skeleton3D
var _player: AnimationPlayer
var _hand := BoneAttachment3D.new()
var _blade := MeshInstance3D.new()
var _guard := MeshInstance3D.new()
var _guard_mat := StandardMaterial3D.new()
var _state: String = ""
var _slash_i: int = 0


static func available() -> bool:
	return ResourceLoader.exists(CHAR_PATH)


func _ready() -> void:
	_body = (load(CHAR_PATH) as PackedScene).instantiate()
	_body.rotation.y = PI   # Mixamo 캐릭터는 +Z를 본다. 이 게임의 모델 앞은 -Z다
	add_child(_body)
	_skel = _body.find_child("Skeleton3D", true, false) as Skeleton3D
	_player = _body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_load_anims()
	_hand.bone_name = HAND_BONE
	_skel.add_child(_hand)
	var grip := Node3D.new()
	grip.transform = _grip_transform()
	_hand.add_child(grip)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.08, 1.2, 0.03)
	_blade.mesh = bm
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.85, 0.88, 0.93)
	steel.metallic = 0.85
	steel.roughness = 0.25
	_blade.material_override = steel
	grip.add_child(_blade)
	var gm := BoxMesh.new()
	gm.size = Vector3(0.26, 0.05, 0.06)
	_guard.mesh = gm
	_guard_mat.emission_enabled = true
	_guard_mat.emission_energy_multiplier = 0.6
	_guard.material_override = _guard_mat
	grip.add_child(_guard)
	play("idle")


## 손 뼈 기준으로 칼을 쥔 자리와 방향. 쥔 자리의 Y가 칼날, X가 날이 선 쪽이다.
func _grip_transform() -> Transform3D:
	var b: int = _skel.find_bone(HAND_BONE)
	var inv: Basis = _skel.get_bone_global_rest(b).basis.orthonormalized().inverse()
	var y: Vector3 = (inv * Vector3(0, 0, 1)).normalized()   # T자세에서 몸 앞쪽
	var x: Vector3 = (inv * Vector3(0, 1, 0)).normalized()   # 위아래
	var z: Vector3 = x.cross(y).normalized()
	x = y.cross(z).normalized()
	var at: Vector3 = Vector3(0, 0.08, 0) + inv * Vector3(0, -0.025, 0)   # 손가락 쪽으로 조금, 손바닥 아래로 조금
	var t := Transform3D(Basis(x, y, z), at)
	return t * Transform3D(Basis.from_euler(grip_rotation_deg * PI / 180.0), grip_offset)


## 동작 파일을 읽어 이 캐릭터의 AnimationPlayer에 붙인다.
func _load_anims() -> void:
	var lib := AnimationLibrary.new()
	if DirAccess.dir_exists_absolute(ANIM_DIR):
		var files: Array[String] = []
		for f in ResourceLoader.list_directory(ANIM_DIR):
			if f.to_lower().ends_with(".fbx"):
				files.append(f)
		files.sort()
		for f in files:
			var key: String = _key_for(f.get_basename().to_lower())
			if key == "":
				continue
			var a := _first_animation(load(ANIM_DIR + f) as PackedScene)
			if a == null:
				continue
			a = a.duplicate(true)
			_in_place(a)
			a.loop_mode = Animation.LOOP_LINEAR if LOOPING.has(key) else Animation.LOOP_NONE
			if key == "slash":
				var n: int = 1
				while lib.has_animation("slash%d" % n):
					n += 1
				key = "slash%d" % n
			if not lib.has_animation(key):
				lib.add_animation(key, a)
				anims[key] = a.length
	_player.add_animation_library("lord", lib)


static func _key_for(name: String) -> String:
	if name.contains("slash") or name.contains("attack"):
		return "big" if name.contains("great") else "slash"
	for kw in KEYWORDS:
		if name.contains(kw[0]):
			return kw[1]
	return ""


static func _first_animation(ps: PackedScene) -> Animation:
	if ps == null:
		return null
	var n := ps.instantiate()
	var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var a: Animation = null
	if ap and not ap.get_animation_list().is_empty():
		a = ap.get_animation(ap.get_animation_list()[0])
	n.free()
	return a


## 엉덩이가 앞뒤·좌우로 움직이는 것을 지워 제자리 동작으로 만든다(위아래는 둔다).
static func _in_place(a: Animation) -> void:
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_POSITION_3D or not str(a.track_get_path(t)).ends_with("mixamorig_Hips"):
			continue
		var first: Vector3 = a.track_get_key_value(t, 0)
		for k in a.track_get_key_count(t):
			var v: Vector3 = a.track_get_key_value(t, k)
			a.track_set_key_value(t, k, Vector3(first.x, v.y, first.z))


func has(state: String) -> bool:
	return anims.has(state)


## 상태를 바꾼다. 없는 동작이면 비슷한 것으로, 그것도 없으면 팔을 내린 서 있는 자세.
## 실제로 튼 동작의 이름을 돌려준다(없으면 "").
func play(state: String, speed: float = 1.0) -> String:
	var name: String = state
	if state == "slash" or state == "big":
		var slashes: Array[String] = []
		for k in anims:
			if str(k).begins_with("slash"):
				slashes.append(k)
		slashes.sort()
		if state == "big" and has("big"):
			name = "big"
		elif not slashes.is_empty():
			name = slashes[_slash_i % slashes.size()]
			_slash_i += 1
		else:
			name = "idle"
	elif not has(state):
		name = "run" if state == "roll" and has("run") else "idle"
	if not has(name):
		_stand()
		return ""
	if name == _state and _player.is_playing() and LOOPING.has(name):
		_player.speed_scale = speed
		return name
	_state = name
	_player.speed_scale = speed
	_player.play("lord/" + name, blend)
	if not LOOPING.has(name):
		_player.seek(0.0, true)
	return name


func length(state: String) -> float:
	return anims.get(state, 0.0)


## 동작 파일이 아직 없을 때: T자세 대신 팔을 내린 자세로 세운다.
func _stand() -> void:
	if _state == "_stand":
		return
	_state = "_stand"
	_player.stop()
	_skel.reset_bone_poses()
	# 어깨 아래에서 몸 앞쪽 축(Z)으로 팔을 돌려 내린다. 뼈대 공간에서 돌린 뒤 뼈의 자리로 옮긴다
	for side in [["mixamorig_LeftArm", -1.0], ["mixamorig_RightArm", 1.0]]:
		var b: int = _skel.find_bone(side[0])
		if b < 0:
			continue
		var pg: Basis = _skel.get_bone_global_rest(_skel.get_bone_parent(b)).basis.orthonormalized()
		var turn := Basis(Vector3(0, 0, 1), side[1] * deg_to_rad(72.0))
		var rest: Basis = _skel.get_bone_rest(b).basis.orthonormalized()
		_skel.set_bone_pose_rotation(b, (pg.inverse() * turn * pg * rest).get_rotation_quaternion())


func set_sword(s: Sword, grades: GradeTable) -> void:
	_blade.visible = s != null
	_guard.visible = s != null
	if s == null:
		return
	var m := _blade.mesh as BoxMesh
	m.size = Vector3(maxf(s.form.blade_width, 0.04), s.form.blade_length, 0.025)
	_blade.position = Vector3(0, 0.07 + s.form.blade_length / 2.0, 0)
	_guard.position = Vector3(0, 0.05, 0)
	var c: Color = grades.colors[s.grade]
	_guard_mat.albedo_color = c
	_guard_mat.emission = c
