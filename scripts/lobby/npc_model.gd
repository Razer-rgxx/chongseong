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


## 어둡고 바랜 빛에 맞게 조금 낮추고 tint 쪽으로 물들인다.
func _dye(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if m is BaseMaterial3D:
				var d := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
				d.albedo_color = d.albedo_color * Color(0.78, 0.74, 0.7).lerp(tint, 0.35)
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
	var first: bool = not _started
	_started = true
	_state = name
	_player.play("npc/" + name, 0.0 if first else 0.3)
	if first:
		_player.seek(fmod(phase, _player.current_animation_length), true)
