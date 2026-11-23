class_name NpcModel
extends Node3D
## 마을 사람 모델(Mixamo 농부 남녀). assets/characters/npc/에 있으면 VillageProps.villager가 기본 도형 대신 이것을 세운다.
## 동작은 npc/anims/*.fbx에서 파일 이름으로 읽는다(idle, talk, walk, sit, kneel, pray). 두 모델 모두 Mixamo 뼈대라 같이 쓴다.
## 받는 법은 assets/characters/README.md "마을 사람".

const DIR: String = "res://assets/characters/npc/"
const ANIM_DIR: String = "res://assets/characters/npc/anims/"
const NAMES: Array[String] = ["idle", "talk", "walk", "sit", "kneel", "pray"]
const LOOPING: Array[String] = ["idle", "talk", "walk", "sit", "kneel", "pray"]

## 2026-11-22: Quaternius 농부·순찰자(CC0, assets/characters_cc0/folk/)가 있으면 그것을 먼저 쓴다. 동작은 Universal Animation Library.
const FOLK: String = "res://assets/characters_cc0/folk/"
const FOLK_ANIMS: Dictionary = {"idle": "Idle", "talk": "Idle_Talking", "walk": "Walk", "sit": "Sitting_Idle", "kneel": "Crouch_Idle", "pray": "Fixing_Kneeling"}
const FOLK_MODELS: Dictionary = {"man": "Male_Peasant", "girl": "Female_Peasant", "ranger": "Male_Ranger", "ranger_girl": "Female_Ranger"}

static var _lib: AnimationLibrary = null

## "man" 또는 "girl".
var model: String = "man"
## 옷 빛을 이 색 쪽으로 조금 물들인다(사람마다 다르게). 흰색이면 그대로.
var tint: Color = Color.WHITE
## 동작 시작을 사람마다 어긋나게(초).
var phase: float = 0.0
## 오브젝트 헤드: 사람 종류(ObjectHead.FOR_KIND). 비면 그대로.
var head: StringName = &""
var _body: Node3D
var _player: AnimationPlayer
var _state: String = ""
var _started: bool = false


static func available() -> bool:
	return folk() or ResourceLoader.exists(DIR + "man.fbx")


static func folk() -> bool:
	return ResourceLoader.exists(FOLK + "Male_Peasant.gltf")


static func path_for(m: String) -> String:
	if folk():
		return FOLK + str(FOLK_MODELS.get(m, "Male_Peasant")) + ".gltf"
	if m.begins_with("ranger"):
		m = "girl" if m == "ranger_girl" else "man"
	var p: String = DIR + m + ".fbx"
	return p if ResourceLoader.exists(p) else DIR + "man.fbx"


func _ready() -> void:
	if COSTUME.has(head):
		tint = COSTUME[head][0]
	_body = (load(path_for(model)) as PackedScene).instantiate()
	_body.rotation.y = PI   # Mixamo 캐릭터는 +Z를 본다. 마을 사람의 앞은 -Z다
	add_child(_body)
	_player = _body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player == null:
		_player = AnimationPlayer.new()
		_body.add_child(_player)
		_player.root_node = NodePath("..")
	_player.add_animation_library("npc", _library())
	if folk():
		_add_skin()
	if head != &"":
		ObjectHead.attach(_body.find_child("Skeleton3D", true, false) as Skeleton3D, head)
		_dress()
	_dye(_body)
	play(_state if _state != "" else "idle")


## 옷 모델에는 머리와 맨살이 없다: 동작 팩의 마네킹 몸을 같은 뼈대에 붙이고 살빛을 입힌다(옷 아래로는 가려진다).
func _add_skin() -> void:
	var skel := _body.find_child("Skeleton3D", true, false) as Skeleton3D
	var src := (load(FOLK + "anims.glb") as PackedScene).instantiate()
	var man := src.find_child("Mannequin", true, false) as MeshInstance3D
	if skel and man:
		man.get_parent().remove_child(man)
		skel.add_child(man)
		man.skeleton = NodePath("..")
		man.scale = Vector3(0.985, 0.985, 0.985)   # 옷 안으로 조금 들인다
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.46, 0.34, 0.27).lerp(Color(0.36, 0.27, 0.22), fmod(phase * 0.37, 1.0))
		m.roughness = 0.8
		man.material_override = m
	src.free()


## 머리 물건에 맞춘 옷(사진 속 등불머리의 연미복처럼): 옷감 색, 장식 색, 덧옷 한 벌.
## 덧옷: apron(앞치마), tails(연미복 꼬리), cloak(망토), sash(띠), vest(조끼)
const COSTUME: Dictionary = {
	&"smith": [Color(0.26, 0.2, 0.15), Color(0.55, 0.4, 0.2), &"apron"],
	&"apprentice": [Color(0.3, 0.24, 0.18), Color(0.5, 0.36, 0.2), &"apron"],
	&"elder": [Color(0.12, 0.13, 0.22), Color(0.7, 0.55, 0.25), &"tails"],
	&"merchant": [Color(0.34, 0.14, 0.12), Color(0.72, 0.58, 0.28), &"sash"],
	&"pilgrim": [Color(0.5, 0.47, 0.42), Color(0.75, 0.68, 0.5), &"cloak"],
	&"herbalist": [Color(0.2, 0.28, 0.18), Color(0.5, 0.44, 0.28), &"apron"],
	&"gatherer": [Color(0.28, 0.3, 0.2), Color(0.45, 0.38, 0.24), &"vest"],
	&"hunter": [Color(0.24, 0.22, 0.16), Color(0.4, 0.3, 0.2), &"cloak"],
	&"knight": [Color(0.3, 0.32, 0.36), Color(0.55, 0.5, 0.4), &"tails"],
	&"gatekeeper": [Color(0.22, 0.24, 0.3), Color(0.5, 0.42, 0.3), &"sash"],
	&"drunk": [Color(0.35, 0.18, 0.2), Color(0.5, 0.4, 0.3), &"vest"],
	&"peasant": [Color(0.36, 0.3, 0.22), Color(0.42, 0.34, 0.24), &"apron"],
	&"peasant2": [Color(0.4, 0.34, 0.2), Color(0.5, 0.4, 0.22), &"vest"],
	&"peasant3": [Color(0.3, 0.28, 0.26), Color(0.4, 0.36, 0.3), &"apron"],
	&"peasant4": [Color(0.42, 0.36, 0.22), Color(0.55, 0.45, 0.22), &"sash"],
}

var _piece: Node3D


func _dress() -> void:
	var c: Array = COSTUME.get(head, [])
	if c.is_empty():
		return
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = (c[0] as Color) * 0.85
	cloth.roughness = 0.95
	var trim := StandardMaterial3D.new()
	trim.albedo_color = c[1]
	trim.metallic = 0.4
	trim.roughness = 0.5
	_piece = Node3D.new()
	add_child(_piece)
	var h: float = 1.75   # 사람 키
	match c[2]:
		&"apron":
			_pbox(Vector3(0.36, 0.62, 0.02), Vector3(0, h * 0.42, -0.15), _mat(Color(0.2, 0.15, 0.1)), Vector3(-0.12, 0, 0))
			_pbox(Vector3(0.38, 0.03, 0.025), Vector3(0, h * 0.58, -0.13), trim)
		&"tails":
			for sx in [-1.0, 1.0]:
				_pbox(Vector3(0.16, 0.6, 0.02), Vector3(sx * 0.09, h * 0.36, 0.15), cloth, Vector3(0.12, 0, sx * 0.08))
				_pbox(Vector3(0.02, 0.58, 0.022), Vector3(sx * 0.17, h * 0.36, 0.16), trim, Vector3(0.12, 0, sx * 0.08))
		&"cloak":
			_pbox(Vector3(0.52, 1.0, 0.03), Vector3(0, h * 0.5, 0.17), cloth, Vector3(0.08, 0, 0))
			_pbox(Vector3(0.5, 0.06, 0.24), Vector3(0, h * 0.8, 0.04), cloth)
		&"sash":
			_pbox(Vector3(0.08, 0.7, 0.3), Vector3(0, h * 0.62, 0), trim, Vector3(0, 0, 0.75))
		&"vest":
			for sx in [-1.0, 1.0]:
				_pbox(Vector3(0.15, 0.36, 0.02), Vector3(sx * 0.09, h * 0.63, -0.13), cloth)
			_pbox(Vector3(0.02, 0.34, 0.025), Vector3(0, h * 0.63, -0.14), trim)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _pbox(size: Vector3, at: Vector3, m: Material, rot: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = at
	mi.rotation = rot
	mi.material_override = m
	_piece.add_child(mi)


## 어둡고 바랜 빛에 맞게 조금 낮추고 tint 쪽으로 물들인다.
func _dye(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if m is BaseMaterial3D:
				var d := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
				d.albedo_color = d.albedo_color * Color(0.78, 0.74, 0.7).lerp(tint * 2.2, 0.6 if COSTUME.has(head) else 0.35)
				d.roughness = maxf(d.roughness, 0.85)
				d.metallic = 0.0
				mi.set_surface_override_material(s, d)
	for c in n.get_children():
		_dye(c)


static func _library() -> AnimationLibrary:
	if _lib:
		return _lib
	_lib = AnimationLibrary.new()
	if folk():
		var root := (load(FOLK + "anims.glb") as PackedScene).instantiate()
		var ap := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
		for key in FOLK_ANIMS:
			if ap and ap.has_animation(FOLK_ANIMS[key]):
				var a := ap.get_animation(FOLK_ANIMS[key]).duplicate(true) as Animation
				a.loop_mode = Animation.LOOP_LINEAR
				_lib.add_animation(key, a)
		root.free()
		return _lib
	if not DirAccess.dir_exists_absolute(ANIM_DIR):
		return _lib
	for f in ResourceLoader.list_directory(ANIM_DIR):
		if not f.to_lower().ends_with(".fbx"):
			continue
		var key: String = f.get_basename().to_lower()
		if not NAMES.has(key):
			continue
		var a := LordCharacter._first_animation(load(ANIM_DIR + f) as PackedScene)
		if a == null:
			continue
		a = a.duplicate(true)
		LordCharacter._in_place(a)
		a.loop_mode = Animation.LOOP_LINEAR if LOOPING.has(key) else Animation.LOOP_NONE
		_lib.add_animation(key, a)
	return _lib


func has(state: String) -> bool:
	return _lib != null and _lib.has_animation(state)


## 동작을 바꾼다. 없으면 서 있기, 그것도 없으면 그대로 둔다.
func play(state: String) -> void:
	var name: String = state if has(state) else "idle"
	if _player == null:
		_state = name
		return
	if name == _state and _player.is_playing():
		return
	if not has(name):
		return
	if _piece:
		_piece.visible = not name in ["kneel", "sit", "pray"]
	var first: bool = not _started
	_started = true
	_state = name
	_player.play("npc/" + name, 0.0 if first else 0.3)
	if first:
		_player.seek(fmod(phase, _player.current_animation_length), true)
