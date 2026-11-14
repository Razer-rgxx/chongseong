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
	["idle", "idle"], ["walk", "walk"], ["run", "run"], ["roll", "roll"], ["impact", "hit"], ["hit", "hit"],
	["death", "death"], ["dying", "death"], ["pull", "pull"],
]
const LOOPING: Array[String] = ["idle", "walk", "run", "pull"]

## 칼을 쥔 자리. T자세에서 손바닥 가운데, 칼날은 몸 앞쪽(엄지 쪽)으로 뻗게 스스로 맞춘다.
## 동작을 넣고 칼이 손에서 어긋나 보이면 이 두 값으로 더 맞춘다(쥔 자리 기준, 미터와 도).
@export var grip_offset: Vector3 = Vector3.ZERO
@export var grip_rotation_deg: Vector3 = Vector3.ZERO
@export var blend: float = 0.12

var anims: Dictionary = {}
## 동작 파일은 한 번만 읽어 모든 캐릭터(영주, 거인 적)가 같이 쓴다.
static var _lib_cache: AnimationLibrary = null
static var _anims_cache: Dictionary = {}
static var _roll_cache: Vector2 = Vector2(-1.0, -1.0)
## 베기 동작마다 칼이 실제로 지나가는 때(초). 손이 가장 빨리 움직이는 때로 찾는다.
static var _contact_cache: Dictionary = {}
## 마지막으로 튼 한 번짜리 동작을 몇 초째부터 틀었는지.
var last_from: float = 0.0
## 구르기 동작에서 실제로 몸이 굴러가는 구간(초). 엉덩이 높이로 찾는다. 못 찾으면 (-1, -1).
var roll_window: Vector2 = Vector2(-1.0, -1.0)
var _body: Node3D
var _skel: Skeleton3D
var _player: AnimationPlayer
var _hand := BoneAttachment3D.new()
var _grip := Node3D.new()
var _sword: SwordModel = null
var _speed: float = 1.0
var _frozen: bool = false
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
	_grip.transform = _grip_transform()
	_hand.add_child(_grip)
	if _contact_cache.is_empty():
		_find_contacts()
	play("idle")


## 베기 동작마다 손이 가장 빠른 때(= 칼이 맞는 때)를 찾아 둔다. 규칙은 누르는 순간 베므로
## 화면은 그 순간에 맞춰 동작의 중간부터 튼다(play의 from이 음수일 때).
func _find_contacts() -> void:
	var b: int = _skel.find_bone(HAND_BONE)
	for k in anims:
		var name: String = k
		if not (name.begins_with("slash") or name == "big"):
			continue
		_player.play("lord/" + name, 0.0)
		var L: float = anims[k]
		var prev := Vector3.ZERO
		var best: float = -1.0
		var at: float = 0.0
		var t: float = 0.0
		# 앞쪽 3/4 안에서 찾는다(끝의 되돌아오는 동작은 뺀다)
		while t <= L * 0.75:
			_player.seek(t, true)
			var p: Vector3 = _skel.get_bone_global_pose(b).origin
			if t > 0.0:
				var v: float = (p - prev).length()
				if v > best:
					best = v
					at = t
			prev = p
			t += 1.0 / 30.0
		_contact_cache[name] = at
	_player.stop()


func contact(name: String) -> float:
	return _contact_cache.get(name, 0.0)


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
	if _lib_cache:
		anims = _anims_cache
		roll_window = _roll_cache
		_player.add_animation_library("lord", _lib_cache)
		return
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
			if key == "roll":
				roll_window = _low_window(a)
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
	_lib_cache = lib
	_anims_cache = anims
	_roll_cache = roll_window


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


## 엉덩이가 선 높이의 75%보다 낮은 구간(앞뒤로 조금 넉넉히). 구르기의 도움닫기와 일어서기를 잘라 낸다.
static func _low_window(a: Animation) -> Vector2:
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_POSITION_3D or not str(a.track_get_path(t)).ends_with("mixamorig_Hips"):
			continue
		var stand: float = (a.track_get_key_value(t, 0) as Vector3).y
		var first: float = -1.0
		var last: float = -1.0
		for k in a.track_get_key_count(t):
			if (a.track_get_key_value(t, k) as Vector3).y < stand * 0.75:
				var time: float = a.track_get_key_time(t, k)
				if first < 0.0:
					first = time
				last = time
		if first >= 0.0:
			return Vector2(maxf(0.0, first - 0.15), minf(a.length, last + 0.1))
	return Vector2(-1.0, -1.0)


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
## 실제로 튼 동작의 이름을 돌려준다(없으면 ""). from은 한 번 트는 동작을 몇 초째부터 틀지.
## from이 음수면 베기 동작에서 칼이 맞는 때보다 그만큼(초) 앞에서부터 튼다.
func play(state: String, speed: float = 1.0, from: float = 0.0) -> String:
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
	_speed = speed
	if name == _state and _player.is_playing() and LOOPING.has(name):
		_player.speed_scale = 0.0 if _frozen else speed
		return name
	_state = name
	_player.speed_scale = 0.0 if _frozen else speed
	_player.play("lord/" + name, blend)
	if not LOOPING.has(name):
		var start: float = from
		if from < 0.0:
			start = maxf(0.0, contact(name) + from)
		last_from = minf(start, length(name) * 0.9)
		_player.seek(last_from, true)
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


## 칼날의 손잡이 쪽 끝과 끝(세계 좌표). 칼을 들고 있지 않으면 빈 배열.
func blade_points() -> Array[Vector3]:
	return _sword.blade_points() if _sword else ([] as Array[Vector3])


## 손에 쥔 칼을 바꾼다(SwordModel: 형태·등급·번호로 모양이 정해진다). 손잡이 가운데쯤을 쥔다.
func set_sword(s: Sword, grades: GradeTable) -> void:
	if _sword:
		_sword.queue_free()
		_sword = null
	if s == null:
		return
	_sword = SwordModel.for_sword(s, grades)
	_sword.position = Vector3(0, _sword.grip_length * 0.4, 0)
	_grip.add_child(_sword)


## 손에 아무 모델이나 쥐게 한다(적 거인의 칼). 손잡이 가운데쯤을 쥔다.
func hold(model: SwordModel) -> void:
	model.position = Vector3(0, model.grip_length * 0.4, 0)
	_grip.add_child(model)


## 뼈에 붙인다(적의 빛나는 눈 같은 것). 뼈 이름은 mixamorig_Head처럼.
func attach(bone: String, node: Node3D) -> void:
	var at := BoneAttachment3D.new()
	at.bone_name = bone
	_skel.add_child(at)
	at.add_child(node)


## 적으로 쓸 때: 갑옷 색에 mul을 곱하고 glow로 은은하게 빛나게 한다. 바꾼 재질들을 돌려준다(맞을 때 번쩍임에 쓴다).
func recolor(mul: Color, glow: Color = Color.BLACK, glow_energy: float = 0.0) -> Array[StandardMaterial3D]:
	var out: Array[StandardMaterial3D] = []
	for node in _body.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i) as StandardMaterial3D
			if src == null:
				continue
			var m := src.duplicate() as StandardMaterial3D
			m.albedo_color = src.albedo_color * mul
			if glow_energy > 0.0:
				m.emission_enabled = true
				m.emission = glow
				m.emission_energy_multiplier = glow_energy
			mi.set_surface_override_material(i, m)
			out.append(m)
	return out


## 히트스톱 동안 동작을 멈춘다.
func set_frozen(on: bool) -> void:
	if on == _frozen:
		return
	_frozen = on
	_player.speed_scale = 0.0 if on else _speed
