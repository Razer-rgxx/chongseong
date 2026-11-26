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
const FOLK_ANIMS: Dictionary = {"idle": "Idle", "talk": "Idle_Talking", "walk": "Walk", "sit": "Sitting_Idle", "kneel": "Crouch_Idle", "pray": "Fixing_Kneeling", "strike": "Sword_Attack"}
## 한 번만 하는 동작(대장장이의 망치질, Interior.hammer).
const ONCE: Array[String] = ["strike"]
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
## 덧옷: apron(앞치마), tails(연미복 꼬리), cloak(망토), sash(띠), vest(조끼), coat(선장 외투: 앞판·금 단추·견장·꼬리)
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
	&"captain": [Color(0.07, 0.08, 0.14), Color(0.8, 0.62, 0.26), &"coat"],   # 2026-11-26 닻의 선장(과거): 검남색 연미복, 금빛 단
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
		&"coat":   # 선장 연미복(2026-11-26, 사용자 "더 멋있게" + 등불머리 사진 "이런 느낌" + "옷에서 코드로 만든 티가 좀 덜나게").
			# 몸통·팔은 몸 메시를 한 겹 부풀린 껍데기(_shell_coat, 칠은 captain_coat.gdshader)라 몸과 같이 움직이고,
			# 둥근 흰 주름 목장식, 둥근 금 견장과 술, 높은 깃, 휘어 내려오는 뒤 꼬리(_tails), 허리 칼만 따로 단다.
			var lace := _mat(Color(0.9, 0.88, 0.82))
			var coat_m := _coat_material(c[0] as Color, c[1] as Color)
			_shell_coat(coat_m)
			_tails(coat_m)
			for k in 5:   # 흰 주름 목장식(자보): 아래로 갈수록 좁아지는 둥근 주름
				_pball(Vector3(0.075 - k * 0.009, 0.026, 0.03), Vector3(0, h * 0.815 - k * 0.03, -0.15 - k * 0.006), lace)
			for sx in [-1.0, 1.0]:
				var ep := _pcyl(0.085, 0.075, 0.03, Vector3(sx * 0.2, h * 0.822, 0.0), trim)   # 둥근 금 견장
				ep.scale = Vector3(1.0, 1.0, 0.85)
				for k in 7:   # 견장 술
					var a: float = PI * (0.15 + 0.7 * k / 6.0)
					_pcyl(0.006, 0.006, 0.075, Vector3(sx * (0.2 + cos(a) * 0.08 * sx), h * 0.822 - 0.045, -sin(a) * 0.07 + 0.0), trim)
			var col := _pcyl(0.12, 0.135, 0.11, Vector3(0, h * 0.865, 0.03), coat_m)   # 높은 깃(둥글게 목 뒤를 감쌈)
			col.rotation = Vector3(-0.3, 0, 0)
			_pbox(Vector3(0.045, 0.7, 0.03), Vector3(-0.22, h * 0.36, -0.02), _mat(Color(0.08, 0.06, 0.05)), Vector3(0.35, 0, -0.18))   # 허리 칼(칼집)
			_pbox(Vector3(0.12, 0.03, 0.05), Vector3(-0.17, h * 0.55, -0.1), trim, Vector3(0.35, 0, -0.18))
		&"vest":
			for sx in [-1.0, 1.0]:
				_pbox(Vector3(0.15, 0.36, 0.02), Vector3(sx * 0.09, h * 0.63, -0.13), cloth)
			_pbox(Vector3(0.02, 0.34, 0.025), Vector3(0, h * 0.63, -0.14), trim)


const COAT_SHADER: String = "res://assets/past/captain_coat.gdshader"


func _coat_material(cloth: Color, gold: Color) -> Material:
	if not ResourceLoader.exists(COAT_SHADER):
		return _mat(cloth)
	var m := ShaderMaterial.new()
	m.shader = load(COAT_SHADER) as Shader
	m.set_shader_parameter("coat", cloth)
	m.set_shader_parameter("gold", gold)
	return m


## 옷 껍데기: 몸통·팔 메시(손 빼고)를 법선 쪽으로 한 겹 부풀린 스킨 메시. 같은 스킨·뼈대를 써서 몸과 같이 움직인다.
## 칠할 자리를 위해 묶을 때 자세 위치를 UV2(x, y)·UV.x(z)에 담는다(captain_coat.gdshader).
func _shell_coat(mat: Material) -> void:
	for src in _body.find_children("*", "MeshInstance3D", true, false):
		var mi := src as MeshInstance3D
		var nm: String = String(mi.name)
		if mi.skin == null or not (nm.ends_with("_Body") or nm.ends_with("_Arms")):
			continue
		var am := ArrayMesh.new()
		for si in mi.mesh.get_surface_count():
			var a: Array = mi.mesh.surface_get_arrays(si)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
			if v.is_empty() or idx.is_empty() or bones.is_empty():
				continue
			var per: int = bones.size() / v.size()
			var remap := PackedInt32Array()
			remap.resize(v.size())
			var ov := PackedVector3Array()
			var on := PackedVector3Array()
			var uv := PackedVector2Array()
			var uv2 := PackedVector2Array()
			var ob := PackedInt32Array()
			var ow := PackedFloat32Array()
			var off: float = 0.012 if nm.ends_with("_Body") else 0.009
			for k in v.size():
				remap[k] = -1
				if absf(v[k].x) > 0.655:   # 손은 빼고
					continue
				remap[k] = ov.size()
				ov.append(v[k] + n[k] * off)
				on.append(n[k])
				uv.append(Vector2(v[k].z, 0.0))
				uv2.append(Vector2(v[k].x, v[k].y))
				for b in per:
					ob.append(bones[k * per + b])
					ow.append(weights[k * per + b])
			var oi := PackedInt32Array()
			for t in range(0, idx.size(), 3):
				var p0: int = remap[idx[t]]
				var p1: int = remap[idx[t + 1]]
				var p2: int = remap[idx[t + 2]]
				if p0 >= 0 and p1 >= 0 and p2 >= 0:
					oi.append_array([p0, p1, p2])
			if oi.is_empty():
				continue
			var arr: Array = []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = ov
			arr[Mesh.ARRAY_NORMAL] = on
			arr[Mesh.ARRAY_TEX_UV] = uv
			arr[Mesh.ARRAY_TEX_UV2] = uv2
			arr[Mesh.ARRAY_BONES] = ob
			arr[Mesh.ARRAY_WEIGHTS] = ow
			arr[Mesh.ARRAY_INDEX] = oi
			var flags: int = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
			am.surface_set_material(am.get_surface_count() - 1, mat)
		if am.get_surface_count() == 0:
			continue
		var shell := MeshInstance3D.new()
		shell.name = nm + "_Coat"
		shell.mesh = am
		mi.get_parent().add_child(shell)
		shell.transform = mi.transform
		shell.skin = mi.skin
		shell.skeleton = shell.get_path_to(mi.get_node(mi.skeleton))


## 연미복 뒤 꼬리: 허리 뒤에서 종아리까지 휘어 내려오며 퍼지는 두 자락(곡면, 앞뒤 면, 같은 껍데기 칠: 밑단 금띠).
func _tails(mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: int = 8
	var cols: int = 6
	for flap in [-1.0, 1.0]:
		var grid: Array = []
		for r in rows + 1:
			var t: float = r / float(rows)
			var y: float = lerpf(0.98, 0.36, t)
			var rad: float = lerpf(0.175, 0.26, t * t)
			var row: Array = []
			for cc in cols + 1:
				var a: float = lerpf(0.06, 1.25, cc / float(cols)) * flap   # 등 가운데(0)에서 옆으로
				# NpcModel 공간: 앞이 -Z, 등은 +Z
				row.append(Vector3(sin(a) * rad * 1.05, y, cos(a) * rad * 0.85 + 0.02))
			grid.append(row)
		for r in rows:
			for cc in cols:
				var q: Array = [grid[r][cc], grid[r][cc + 1], grid[r + 1][cc + 1], grid[r + 1][cc]]
				for tri in [[0, 1, 2], [0, 2, 3], [0, 2, 1], [0, 3, 2]]:
					for k in tri:
						var p: Vector3 = q[k]
						st.set_uv(Vector2(-p.z, 0.0))   # 칠 공간은 모델 앞 +Z라 뒤집는다
						st.set_uv2(Vector2(-p.x, p.y))
						st.add_vertex(p)
	st.generate_normals()
	st.set_material(mat)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	_piece.add_child(mi)


func _pball(scale: Vector3, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.scale = scale
	mi.position = at
	mi.material_override = m
	_piece.add_child(mi)
	return mi


func _pcyl(rt: float, rb: float, hh: float, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = rt
	cm.bottom_radius = rb
	cm.height = hh
	cm.radial_segments = 14
	mi.mesh = cm
	mi.position = at
	mi.material_override = m
	_piece.add_child(mi)
	return mi


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
				a.loop_mode = Animation.LOOP_NONE if ONCE.has(key) else Animation.LOOP_LINEAR
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


## 망치를 한 번 내리친다(from초부터 다시: 칼 휘두르기 동작의 치켜든 데부터 쓰면 내리치기가 된다). 동작이 없으면 아무것도 안 한다.
func strike(from: float = 0.0) -> void:
	if _player == null or not has("strike"):
		return
	_started = true
	_state = "strike"
	_player.play("npc/strike", 0.08)
	_player.seek(from, true)


## 오른손에 물건을 쥐여 준다(대장장이의 망치). 손뼈가 없으면 버린다.
func hold(item: Node3D, bone: String = "hand_r") -> void:
	var skel := _body.find_child("Skeleton3D", true, false) as Skeleton3D if _body else null
	if skel == null or skel.find_bone(bone) < 0:
		item.queue_free()
		return
	var at := BoneAttachment3D.new()
	at.bone_name = bone
	skel.add_child(at)
	at.add_child(item)


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
