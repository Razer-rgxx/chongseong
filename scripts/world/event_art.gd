class_name EventArt
extends RefCounted
## 13단계 낮 사건의 모양(모양팀, docs/content.md "13단계"). 노드에 기대지 않는 정적 함수만 둔다.
##   smith   떠돌이 대장장이: 다부진 몸, 가죽 두건과 앞치마, 걷은 소매, 오른손에 망치. 곁에 그루터기 위의 모루.
##   pilgrim 순례자: 길고 해진 옷과 두건, 오른손에 긴 지팡이, 등에 등짐(꾸러미와 말아 묶은 깔개).
##   seer    점쟁이: 굽은 등, 깊은 두건과 어깨 숄, 왼손에 내민 등불(따뜻한 불빛).
##   cursed  저주받은 손잡이: 이미 있는 손잡이(SwordModel·HiltView)에 검은 쇠 재질을 입힌다(curse_hilt). 기운은 EventFx.aura.
## 어두운 사실풍: 해진 천, 낡은 가죽, 녹슨 쇠, 나무. 얼굴은 두건 안의 어둠이다(빛나는 눈 없음: 적이 아니다).
## 꾸밈용 랜덤은 쓰지 않는다(늘 같은 모양). 모션팀이 없어서 가볍게 숨 쉬는 움직임(breathe)을 여기에 둔다.
##
## 좌표: 미터. 몸은 -Z를 보고(오른쪽 = +X), 원점은 발밑이다. 기능팀은 parent를 땅 높이에 맞춘 자리에 두고
## parent.rotation.y로 영주 쪽을 보게 돌린다(VillageBuilder.facing_to(dir)처럼).
##   var P := EventArt.build(&"smith", holder)       # 또는 smith(holder), pilgrim(holder), seer(holder)
##   _process에서 EventArt.breathe(P, 시간)          # 시간 = 아무 초(누적). 몸마다 위상이 다르다
##   EventFx.used(P) / EventFx.vanish(P)             # 쓰일 때, 사라질 때
##   EventArt.curse_hilt(hilt_view)                  # 저주받은 손잡이(흙 둔덕은 건너뛴다). uncurse_hilt로 되돌린다
##
## build가 돌려주는 키:
##   kind(StringName), root(Node3D), height(m), radius(m, 다가갈 거리 어림), focus(Node3D: 쓰일 때 효과가 나는 곳 —
##   대장장이 = 모루 위, 순례자 = 가슴, 점쟁이 = 등불), torso, head, arms[2](어깨 피벗, [왼, 오]), forearms[2], hands[2],
##   mats(Array[StandardMaterial3D], 사라질 때 투명하게), cloaks(Array[ShaderMaterial], wraith_cloak.gdshader: fade로 흩어진다),
##   light(OmniLight3D 또는 없음, 점쟁이 등불, meta "base_energy"), glow(Array[StandardMaterial3D], 등불 불꽃),
##   rest(Dictionary: 피벗 → 지었을 때의 Transform3D, breathe와 EventFx가 기준으로 쓴다), phase(float)
##   smith  hammer(오른손의 망치 노드), anvil(모루 노드)
##   pilgrim staff(지팡이 노드), pack(등짐 노드)
##   seer   lantern(등불 진자 피벗)

const KINDS: Array[StringName] = [&"smith", &"pilgrim", &"seer"]
const CLOAK_SHADER: Shader = preload("res://scripts/enemies/wraith_cloak.gdshader")
const LANTERN_LIGHT := Color(1.0, 0.62, 0.3)

## 저주받은 손잡이: 검게 그을린 쇠, 결을 따라 검붉은 실금이 천천히 숨 쉰다. 오브젝트 좌표 잡음(모양마다 결이 다르다).
const CURSE_SHADER := """shader_type spatial;
uniform float energy = 0.8;
uniform float scale = 16.0;
varying vec3 op;
float h31(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float vn(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(h31(i), h31(i + vec3(1, 0, 0)), f.x), mix(h31(i + vec3(0, 1, 0)), h31(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(h31(i + vec3(0, 0, 1)), h31(i + vec3(1, 0, 1)), f.x), mix(h31(i + vec3(0, 1, 1)), h31(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}
void vertex() { op = VERTEX; }
void fragment() {
	vec3 p = op * scale;
	float n = vn(p) * 0.6 + vn(p * 2.3 + 7.0) * 0.4;
	float vein = 1.0 - smoothstep(0.0, 0.045, abs(vn(p * 0.8 + 3.0) - 0.5));
	float pulse = 0.55 + 0.45 * sin(TIME * 1.4 + n * 5.0);
	ALBEDO = vec3(0.016, 0.014, 0.015) + vec3(0.02, 0.016, 0.014) * n;
	METALLIC = 0.75;
	ROUGHNESS = 0.28 + 0.4 * n;
	RIM = 0.15;
	EMISSION = vec3(0.42, 0.035, 0.02) * vein * energy * pulse;
}
"""

static var _cache: Dictionary = {}


## kind의 사건 형체를 parent 아래에 짓는다. 모르는 kind면 빈 Dictionary.
static func build(kind: StringName, parent: Node3D) -> Dictionary:
	match kind:
		&"smith":
			return smith(parent)
		&"pilgrim":
			return pilgrim(parent)
		&"seer":
			return seer(parent)
	push_error("EventArt: 모르는 사건 %s" % kind)
	return {}


# ---------------------------------------------------------------- 대장장이

static func smith(parent: Node3D) -> Dictionary:
	var P := _begin(&"smith", parent)
	var root: Node3D = P.root
	P.height = 1.82
	P.radius = 1.2
	var cloth := _mat(P, Color(0.13, 0.115, 0.1), 0.95)
	var shirt := _mat(P, Color(0.2, 0.18, 0.15), 0.95)
	var leather := _mat(P, Color(0.085, 0.055, 0.035), 0.6)
	var skin := _mat(P, Color(0.3, 0.2, 0.15), 0.7)
	var hood := _mat(P, Color(0.1, 0.07, 0.05), 0.7)
	_legs(P, 0.12, 0.92, cloth, leather, 0.1)
	var torso := _pivot(root, Vector3(0, 0.92, 0), "Torso")
	P.torso = torso
	_add(torso, CreatureMesh.loft([
		[Vector3(0, -0.05, 0), 0.19, 0.14], [Vector3(0, 0.2, 0.0), 0.21, 0.15], [Vector3(0, 0.45, 0.0), 0.25, 0.16], [Vector3(0, 0.56, 0.0), 0.2, 0.13], [Vector3(0, 0.64, 0), 0.08, 0.07],
	], 14, 0.0), shirt)
	# 앞치마: 가슴에서 무릎까지 늘어진 두꺼운 가죽, 허리끈
	_add(torso, CreatureMesh.loft([
		[Vector3(0, 0.4, -0.158), 0.12, 0.01], [Vector3(0, 0.2, -0.162), 0.15, 0.012], [Vector3(0, -0.05, -0.152), 0.17, 0.012],
		[Vector3(0, -0.3, -0.155), 0.17, 0.012], [Vector3(0, -0.5, -0.145), 0.16, 0.01],
	], 10, 0.0), leather).name = "Apron"
	_add(torso, CreatureMesh.lathe([[0.02, 0.2, 0.15, 0.0], [0.06, 0.2, 0.15, 0.0]], 14), leather)
	# 머리: 짧은 가죽 두건(어깨까지 덮는 깃), 안의 어둠
	var head := _pivot(torso, Vector3(0, 0.66, 0), "Head")
	P.head = head
	_add(head, CreatureMesh.lathe([
		[-0.12, 0.2, 0.18, 0.02], [-0.04, 0.15, 0.15, 0.02], [0.05, 0.13, 0.14, 0.02], [0.16, 0.125, 0.135, 0.03], [0.25, 0.09, 0.1, 0.04], [0.3, 0.02, 0.02, 0.05],
	], 16), hood).name = "Hood"
	_void(P, head, Vector3(0, 0.1, -0.08), 0.1, 0.17)
	# 굵은 팔: 걷은 소매, 맨 팔뚝
	var arms := _arms(P, torso, Vector3(0.27, 0.5, 0.0), 0.3, 0.28, shirt, skin, 0.085)
	var sh: Array[Node3D] = arms[0]
	var el: Array[Node3D] = arms[1]
	var hands: Array[Node3D] = arms[2]
	sh[0].rotation = Vector3(0.08, 0.0, -0.12)
	el[0].rotation = Vector3(0.25, 0.0, 0.0)
	sh[1].rotation = Vector3(0.2, 0.0, 0.1)
	el[1].rotation = Vector3(0.55, 0.0, 0.0)
	# 망치: 오른손에 쥐고 머리가 아래(쉬는 자세). 자루 0.42m, 쇠 머리
	var iron := _mat(P, Color(0.11, 0.105, 0.1), 0.45, 0.75)
	var wood := _mat(P, Color(0.24, 0.17, 0.11), 0.85)
	var hammer := _pivot(hands[1], Vector3(0, -0.07, -0.01), "Hammer")
	hammer.rotation = Vector3(-0.55, 0.0, 0.0)
	_add(hammer, _cyl(0.016, 0.019, 0.42, 6), wood, Vector3(0, -0.13, 0))
	var head_m := BoxMesh.new()
	head_m.size = Vector3(0.07, 0.07, 0.16)
	_add(hammer, head_m, iron, Vector3(0, -0.33, -0.015))
	_add(hammer, _cyl(0.032, 0.036, 0.03, 8), iron, Vector3(0, -0.33, -0.1), Vector3(PI / 2.0, 0, 0))
	P.hammer = hammer
	# 모루: 오른쪽 앞 그루터기 위(뿔이 바깥으로)
	var anvil := _pivot(root, Vector3(0.78, 0.0, -0.32), "Anvil")
	anvil.rotation.y = -0.35
	P.anvil = anvil
	var bark := HillBuilder.bark()
	var stump := _add(anvil, _cyl(0.24, 0.29, 0.5, 12), bark, Vector3(0, 0.25, 0))
	stump.name = "Stump"
	var cut := _mat(P, Color(0.3, 0.24, 0.17), 0.9)
	_add(anvil, _cyl(0.235, 0.235, 0.012, 12), cut, Vector3(0, 0.5, 0))
	var anvil_iron := _mat(P, Color(0.075, 0.072, 0.07), 0.35, 0.85)
	_add(anvil, anvil_mesh(), anvil_iron, Vector3(0, 0.5, 0))
	var top := _pivot(anvil, Vector3(0, 0.5 + 0.3, 0), "AnvilTop")
	P.focus = top
	# 모루 곁: 기대 세운 집게
	var tongs := _pivot(anvil, Vector3(-0.26, 0.0, 0.12), "Tongs")
	tongs.rotation = Vector3(0.0, 0.4, 0.22)
	for s in [-1.0, 1.0]:
		_add(tongs, _cyl(0.008, 0.008, 0.55, 5), iron, Vector3(0.012 * s, 0.28, 0), Vector3(0, 0, 0.03 * s))
	_rest(P)
	return P


## 모루(밑동, 잘록한 허리, 넓은 몸, 앞으로 뻗은 뿔). 원점 = 밑바닥, 뿔은 +X.
static func anvil_mesh() -> ArrayMesh:
	if _cache.has("anvil"):
		return _cache["anvil"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(_box_mesh(Vector3(0.32, 0.06, 0.24)), 0, Transform3D(Basis.IDENTITY, Vector3(0, 0.03, 0)))
	st.append_from(_box_mesh(Vector3(0.18, 0.1, 0.14)), 0, Transform3D(Basis.IDENTITY, Vector3(0, 0.11, 0)))
	st.append_from(_box_mesh(Vector3(0.4, 0.12, 0.17)), 0, Transform3D(Basis.IDENTITY, Vector3(-0.02, 0.22, 0)))
	var horn := CreatureMesh.loft([
		[Vector3(0.17, 0.23, 0), 0.075, 0.055], [Vector3(0.26, 0.24, 0), 0.05, 0.04], [Vector3(0.34, 0.255, 0), 0.025, 0.022], [Vector3(0.39, 0.265, 0), 0.006, 0.006],
	], 10, 0.0)
	st.append_from(horn, 0, Transform3D.IDENTITY)
	var mesh := st.commit()
	_cache["anvil"] = mesh
	return mesh


# ---------------------------------------------------------------- 순례자

static func pilgrim(parent: Node3D) -> Dictionary:
	var P := _begin(&"pilgrim", parent)
	var root: Node3D = P.root
	P.height = 1.9
	P.radius = 1.0
	var leather := _mat(P, Color(0.12, 0.085, 0.06), 0.7)
	var robe := _cloak(P, Color(0.16, 0.14, 0.115), Color(0.5, 0.46, 0.4), 0.22, 0.14, 0.025)
	var rag := _cloak(P, Color(0.12, 0.105, 0.09), Color(0.5, 0.46, 0.4), 0.2, 0.3, 0.04)
	var skin := _mat(P, Color(0.3, 0.23, 0.19), 0.75)
	# 긴 옷(발목까지), 아래로 장화 끝이 보인다
	for s in [-1.0, 1.0]:
		_add(root, CreatureMesh.loft([
			[Vector3(0.1 * s, 0.12, 0.0), 0.06, 0.065], [Vector3(0.1 * s, 0.03, -0.02), 0.06, 0.05], [Vector3(0.1 * s, 0.015, -0.13), 0.05, 0.03], [Vector3(0.1 * s, 0.01, -0.17), 0.03, 0.015],
		], 10, 0.0), leather)
	var torso := _pivot(root, Vector3(0, 0.98, 0), "Torso")
	torso.rotation.x = -0.12
	P.torso = torso
	_add(torso, CreatureMesh.lathe([
		[-0.98, 0.3, 0.27, 0.02], [-0.7, 0.27, 0.24, 0.02], [-0.35, 0.22, 0.19, 0.01], [0.0, 0.19, 0.15, 0.0],
		[0.3, 0.2, 0.15, 0.0], [0.5, 0.22, 0.155, 0.0], [0.6, 0.17, 0.13, 0.0], [0.67, 0.09, 0.08, 0.01],
	], 20), robe).name = "Robe"
	# 허리끈(꼰 줄)
	_add(torso, CreatureMesh.lathe([[-0.02, 0.2, 0.16, 0.0], [0.02, 0.2, 0.16, 0.0]], 16), leather)
	# 두건과 어깨 덮개
	_add(torso, CreatureMesh.lathe([
		[0.28, 0.3, 0.24, 0.02], [0.45, 0.28, 0.21, 0.01], [0.56, 0.24, 0.18, 0.0], [0.64, 0.14, 0.12, 0.01],
	], 20), rag).name = "Cape"
	var head := _pivot(torso, Vector3(0, 0.68, 0), "Head")
	head.rotation.x = 0.1
	P.head = head
	_add(head, CreatureMesh.lathe([
		[-0.1, 0.16, 0.16, 0.02], [0.0, 0.15, 0.15, 0.02], [0.12, 0.145, 0.155, 0.04], [0.24, 0.115, 0.13, 0.07],
		[0.32, 0.06, 0.07, 0.11], [0.36, 0.01, 0.01, 0.14],
	], 18), robe).name = "Hood"
	_void(P, head, Vector3(0, 0.11, -0.07), 0.11, 0.19)
	# 팔: 넓은 소매, 마른 손
	var arms := _arms(P, torso, Vector3(0.22, 0.5, 0.0), 0.3, 0.27, rag, skin, 0.07)
	var sh: Array[Node3D] = arms[0]
	var el: Array[Node3D] = arms[1]
	var hands: Array[Node3D] = arms[2]
	sh[0].rotation = Vector3(0.1, 0.0, -0.06)
	el[0].rotation = Vector3(0.3, 0.0, 0.0)
	sh[1].rotation = Vector3(0.45, 0.0, 0.14)
	el[1].rotation = Vector3(0.75, 0.0, 0.0)
	# 지팡이: 오른손, 곧게 땅까지(몸 기준으로 세운다)
	var staff := Node3D.new()
	staff.name = "Staff"
	hands[1].add_child(staff)
	staff.position = Vector3(0, -0.06, -0.01)
	staff.basis = _basis_to(hands[1], root).inverse() * Basis.from_euler(Vector3(0.05, 0.0, -0.05))
	P.staff = staff
	var wood := _mat(P, Color(0.2, 0.15, 0.1), 0.9)
	_add(staff, CreatureMesh.loft([
		[Vector3(0, -1.32, 0), 0.016, 0.016], [Vector3(0.006, -0.8, 0.004), 0.021, 0.021], [Vector3(-0.004, -0.1, 0.0), 0.022, 0.022],
		[Vector3(0.0, 0.3, 0.004), 0.023, 0.023], [Vector3(0.006, 0.48, 0.0), 0.034, 0.03], [Vector3(0.0, 0.56, 0.0), 0.028, 0.028], [Vector3(-0.006, 0.6, 0.0), 0.012, 0.012],
	], 8, 0.0), wood)
	# 지팡이 끝에 매단 천 조각
	var strip := _cloak(P, Color(0.22, 0.17, 0.12), Color(0.5, 0.46, 0.4), 0.15, 0.5, 0.06)
	_add(staff, CreatureMesh.lathe([[0.22, 0.03, 0.02, 0.0], [0.4, 0.03, 0.02, 0.0], [0.47, 0.026, 0.026, 0.0]], 8), strip)
	# 등짐: 가죽 꾸러미, 그 위에 말아 묶은 깔개, 어깨끈
	var pack := _pivot(torso, Vector3(0, 0.3, 0.22), "Pack")
	pack.rotation.x = 0.12
	P.pack = pack
	var canvas := _mat(P, Color(0.2, 0.17, 0.13), 0.95)
	_add(pack, CreatureMesh.loft([
		[Vector3(0, -0.24, 0), 0.17, 0.09], [Vector3(0, -0.2, 0), 0.2, 0.12], [Vector3(0, 0.1, 0.01), 0.21, 0.12], [Vector3(0, 0.2, 0.0), 0.19, 0.1], [Vector3(0, 0.24, 0), 0.12, 0.06],
	], 12, 0.0), leather)
	_add(pack, _cyl(0.085, 0.085, 0.5, 12), canvas, Vector3(0, 0.33, 0.0), Vector3(0, 0, PI / 2.0))
	for s in [-1.0, 1.0]:
		_add(pack, _cyl(0.088, 0.088, 0.02, 12), leather, Vector3(0.14 * s, 0.33, 0.0), Vector3(0, 0, PI / 2.0))
		_add(pack, CreatureMesh.loft([
			[Vector3(0.12 * s, 0.22, -0.08), 0.02, 0.006], [Vector3(0.14 * s, 0.32, -0.22), 0.02, 0.006], [Vector3(0.13 * s, 0.1, -0.38), 0.02, 0.006],
		], 6, 0.0), leather)
	# 꾸러미에 매단 작은 냄비
	var iron := _mat(P, Color(0.1, 0.095, 0.09), 0.5, 0.6)
	_add(pack, _cyl(0.06, 0.05, 0.08, 10), iron, Vector3(0.2, -0.1, 0.06), Vector3(0, 0, 0.3))
	P.focus = _pivot(torso, Vector3(0, 0.35, -0.2), "Chest")
	_rest(P)
	return P


# ---------------------------------------------------------------- 점쟁이

static func seer(parent: Node3D) -> Dictionary:
	var P := _begin(&"seer", parent)
	var root: Node3D = P.root
	P.height = 1.7
	P.radius = 1.0
	var robe := _cloak(P, Color(0.085, 0.075, 0.07), Color(0.55, 0.45, 0.35), 0.25, 0.12, 0.03)
	var shawl := _cloak(P, Color(0.14, 0.09, 0.07), Color(0.55, 0.45, 0.35), 0.22, 0.35, 0.05)
	var skin := _mat(P, Color(0.32, 0.27, 0.23), 0.8)
	var torso := _pivot(root, Vector3(0, 0.92, 0), "Torso")
	torso.rotation.x = -0.22
	P.torso = torso
	_add(torso, CreatureMesh.lathe([
		[-0.92, 0.33, 0.3, 0.04], [-0.6, 0.28, 0.25, 0.03], [-0.25, 0.22, 0.19, 0.02], [0.1, 0.19, 0.16, 0.02],
		[0.35, 0.21, 0.17, 0.03], [0.5, 0.2, 0.16, 0.04], [0.58, 0.12, 0.11, 0.05],
	], 20), robe).name = "Robe"
	# 숄: 어깨에서 가슴 아래까지, 끝이 많이 해졌다
	_add(torso, CreatureMesh.lathe([
		[0.0, 0.3, 0.26, 0.04], [0.2, 0.28, 0.23, 0.04], [0.38, 0.27, 0.21, 0.04], [0.5, 0.22, 0.18, 0.05], [0.57, 0.13, 0.12, 0.06],
	], 20), shawl).name = "Shawl"
	# 깊은 두건(앞으로 길게 나왔다)
	var head := _pivot(torso, Vector3(0, 0.58, -0.03), "Head")
	head.rotation.x = 0.28
	P.head = head
	_add(head, CreatureMesh.lathe([
		[-0.12, 0.17, 0.19, 0.0], [0.0, 0.16, 0.18, -0.01], [0.13, 0.15, 0.17, 0.0], [0.24, 0.12, 0.14, 0.04],
		[0.32, 0.07, 0.085, 0.09], [0.37, 0.02, 0.02, 0.13],
	], 18), robe).name = "Hood"
	_void(P, head, Vector3(0, 0.08, -0.1), 0.115, 0.2)
	var arms := _arms(P, torso, Vector3(0.21, 0.45, 0.0), 0.28, 0.26, shawl, skin, 0.065)
	var sh: Array[Node3D] = arms[0]
	var el: Array[Node3D] = arms[1]
	var hands: Array[Node3D] = arms[2]
	# 왼팔을 앞으로 내밀어 등불을 든다, 오른손은 가슴께에
	sh[0].rotation = Vector3(0.95, 0.0, -0.12)
	el[0].rotation = Vector3(0.35, 0.0, 0.0)
	sh[1].rotation = Vector3(0.35, 0.0, 0.18)
	el[1].rotation = Vector3(1.35, 0.0, -0.2)
	# 등불: 왼손에서 짧은 사슬로 늘어진 진자(쉬는 자세는 몸 기준으로 곧게 아래)
	var lantern := _pivot(hands[0], Vector3(0, -0.09, 0), "Lantern")
	lantern.basis = _basis_to(hands[0], root).inverse()
	P.lantern = lantern
	_lantern(P, lantern)
	P.focus = lantern
	_rest(P)
	return P


static func _lantern(P: Dictionary, at: Node3D) -> void:
	var iron := _mat(P, Color(0.11, 0.1, 0.09), 0.5, 0.7)
	_add(at, _cyl(0.005, 0.005, 0.12, 4), iron, Vector3(0, -0.06, 0))
	_add(at, _cyl(0.02, 0.08, 0.07, 8), iron, Vector3(0, -0.15, 0))
	for k in 4:
		var a: float = TAU * k / 4.0 + PI / 4.0
		_add(at, _cyl(0.006, 0.006, 0.18, 4), iron, Vector3(cos(a) * 0.07, -0.27, sin(a) * 0.07))
	_add(at, _cyl(0.08, 0.065, 0.025, 8), iron, Vector3(0, -0.37, 0))
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.6, 0.5, 0.35, 0.16)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.roughness = 0.25
	gm.emission_enabled = true
	gm.emission = Color(1.0, 0.6, 0.28)
	gm.emission_energy_multiplier = 0.35
	gm.set_meta("base_energy", 0.35)
	(P.glow as Array).append(gm)
	_add(at, _cyl(0.062, 0.062, 0.18, 10), gm, Vector3(0, -0.27, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var flame := SphereMesh.new()
	flame.radius = 0.024
	flame.height = 0.075
	flame.radial_segments = 8
	flame.rings = 4
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.4, 0.25, 0.1)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.66, 0.3)
	fm.emission_energy_multiplier = 3.0
	fm.set_meta("base_energy", 3.0)
	(P.glow as Array).insert(0, fm)
	_add(at, flame, fm, Vector3(0, -0.29, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.name = "LanternLight"
	light.light_color = LANTERN_LIGHT
	light.light_energy = 1.2
	light.omni_range = 4.5
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	light.position = Vector3(0, -0.27, 0)
	light.set_meta("base_energy", 1.2)
	at.add_child(light)
	P.light = light


# ---------------------------------------------------------------- 숨 쉬기

## 가볍게 숨 쉬는 움직임. 매 화면 부른다(time = 누적 초). 몸통이 조금 부풀고 오르내리며, 머리가 따라 끄덕이고,
## 등불은 천천히 흔들리고 불빛이 일렁인다. 쉬는 자세(rest)를 기준으로 쓰므로 다른 곳에서 피벗을 돌려도 rest로 돌아온다.
static func breathe(parts: Dictionary, time: float) -> void:
	if parts.is_empty():
		return
	var rest: Dictionary = parts.get("rest", {})
	var t: float = time + float(parts.get("phase", 0.0))
	var b: float = sin(t * 1.55)
	var torso: Node3D = parts.get("torso")
	if torso and rest.has(torso):
		var r: Transform3D = rest[torso]
		torso.transform = Transform3D(r.basis * Basis.from_euler(Vector3(0.012 * b, 0.0, 0.006 * sin(t * 0.7))).scaled(Vector3(1.0 + 0.012 * b, 1.0 + 0.006 * b, 1.0 + 0.016 * b)), r.origin + Vector3(0.0, 0.006 * b, 0.0))
	var head: Node3D = parts.get("head")
	if head and rest.has(head):
		var r: Transform3D = rest[head]
		head.transform = Transform3D(r.basis * Basis.from_euler(Vector3(-0.025 * sin(t * 1.55 - 0.6), 0.05 * sin(t * 0.31), 0.0)), r.origin)
	var lantern: Node3D = parts.get("lantern")
	if lantern and rest.has(lantern):
		var r: Transform3D = rest[lantern]
		lantern.transform = Transform3D(r.basis * Basis.from_euler(Vector3(0.06 * sin(t * 1.1), 0.0, 0.05 * sin(t * 0.83 + 1.0))), r.origin)
	var light: OmniLight3D = parts.get("light")
	if light:
		var f: float = 0.9 + 0.06 * sin(t * 13.0) + 0.04 * sin(t * 29.0 + 1.3)
		light.light_energy = float(light.get_meta("base_energy", 1.2)) * f * float(parts.get("light_k", 1.0))


# ---------------------------------------------------------------- 저주받은 손잡이

## 검은 쇠 재질(하나를 같이 쓴다).
static func cursed_material() -> ShaderMaterial:
	if _cache.has("curse"):
		return _cache["curse"]
	var m := ShaderMaterial.new()
	var s := Shader.new()
	s.code = CURSE_SHADER
	m.shader = s
	_cache["curse"] = m
	return m


## node 아래 모든 MeshInstance3D에 검은 재질을 입힌다(원래 material_override는 meta "pre_curse"에 둔다).
## node가 HiltView면 바로 아래의 MeshInstance3D(칼이 박힌 흙 둔덕)는 건너뛰고 칼만 칠한다.
static func curse_hilt(node: Node3D) -> void:
	if node == null:
		return
	var skip_direct: bool = node is HiltView
	for mi: MeshInstance3D in _meshes(node, skip_direct):
		if not mi.has_meta("pre_curse"):
			mi.set_meta("pre_curse", mi.material_override)
		mi.material_override = cursed_material()


static func uncurse_hilt(node: Node3D) -> void:
	if node == null:
		return
	for mi: MeshInstance3D in _meshes(node, false):
		if mi.has_meta("pre_curse"):
			mi.material_override = mi.get_meta("pre_curse")
			mi.remove_meta("pre_curse")


static func _meshes(node: Node, skip_direct: bool) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c in node.get_children():
		if c is MeshInstance3D:
			if not skip_direct:
				out.append(c)
		if c.get_child_count() > 0:
			out.append_array(_meshes(c, false))
	return out


# ---------------------------------------------------------------- 공통 부품

static func _begin(kind: StringName, parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = String(kind).capitalize()
	parent.add_child(root)
	var mats: Array[StandardMaterial3D] = []
	var cloaks: Array[ShaderMaterial] = []
	var glow: Array[StandardMaterial3D] = []
	return {"kind": kind, "root": root, "height": 1.8, "radius": 1.0, "mats": mats, "cloaks": cloaks, "glow": glow,
		"phase": float(KINDS.find(kind)) * 2.1 + 0.4}


## 지었을 때의 피벗 자세를 rest에 적는다.
static func _rest(P: Dictionary) -> void:
	var rest: Dictionary = {}
	for key in ["torso", "head", "lantern", "hammer", "staff"]:
		var n: Variant = P.get(key)
		if n is Node3D:
			rest[n] = (n as Node3D).transform
	for key in ["arms", "forearms", "hands"]:
		for n: Node3D in P.get(key, []):
			rest[n] = n.transform
	P.rest = rest


## 다리 둘(엉덩이·무릎 피벗, 바지와 장화).
static func _legs(P: Dictionary, gap: float, hip_y: float, cloth: Material, boot: Material, r: float) -> void:
	var legs: Array[Node3D] = []
	var knees: Array[Node3D] = []
	var upper: float = hip_y * 0.5
	for i in 2:
		var side: float = -1.0 if i == 0 else 1.0
		var hip := _pivot(P.root, Vector3(gap * side, hip_y, 0.0), "Hip")
		_add(hip, CreatureMesh.loft([
			[Vector3(0, 0.08, 0), r, r * 1.05], [Vector3(0, -upper * 0.45, 0), r * 0.88, r * 0.92], [Vector3(0, -upper, 0), r * 0.64, r * 0.68],
		], 10, 0.0), cloth)
		var knee := _pivot(hip, Vector3(0, -upper, 0), "Knee")
		_add(knee, CreatureMesh.loft([
			[Vector3(0, 0.03, 0), r * 0.64, r * 0.68], [Vector3(0, -upper * 0.3, 0.01), r * 0.6, r * 0.62],
		], 10, 0.0), cloth)
		_add(knee, CreatureMesh.loft([
			[Vector3(0, -upper * 0.3, 0.0), r * 0.7, r * 0.74], [Vector3(0, -upper * 0.82, 0.012), r * 0.66, r * 0.7],
			[Vector3(0, -upper * 0.96, -0.02), r * 0.7, r * 0.56], [Vector3(0, -upper * 0.99, -0.12), r * 0.6, r * 0.38], [Vector3(0, -upper, -0.19), r * 0.34, r * 0.22],
		], 10, 0.0), boot)
		legs.append(hip)
		knees.append(knee)
	P.legs = legs
	P.knees = knees


## 어깨·팔꿈치·손목 피벗을 좌우로 짓는다. at은 오른쪽 어깨(왼쪽은 x를 뒤집는다). [어깨들, 팔꿈치들, 손들].
static func _arms(P: Dictionary, torso: Node3D, at: Vector3, upper: float, lower: float, sleeve: Material, glove: Material, r: float) -> Array:
	var shoulders: Array[Node3D] = []
	var elbows: Array[Node3D] = []
	var hands: Array[Node3D] = []
	for i in 2:
		var side: float = -1.0 if i == 0 else 1.0
		var sh := _pivot(torso, Vector3(at.x * side, at.y, at.z), "Shoulder")
		_add(sh, CreatureMesh.loft([
			[Vector3(0, r * 0.7, 0), r, r], [Vector3(0, -upper * 0.5, 0), r * 0.95, r * 0.95], [Vector3(0, -upper, 0), r * 0.82, r * 0.82],
		], 10, 0.0), sleeve)
		var el := _pivot(sh, Vector3(0, -upper, 0), "Elbow")
		_add(el, CreatureMesh.loft([
			[Vector3(0, r * 0.3, 0), r * 0.74, r * 0.74], [Vector3(0, -lower * 0.5, 0), r * 0.68, r * 0.68], [Vector3(0, -lower, 0), r * 0.52, r * 0.48],
		], 10, 0.0), glove)
		var hand := _pivot(el, Vector3(0, -lower, 0), "Hand")
		_add(hand, CreatureMesh.loft([
			[Vector3(0, r * 0.2, 0), r * 0.5, r * 0.42], [Vector3(0, -r * 0.8, -r * 0.15), r * 0.6, r * 0.36], [Vector3(0, -r * 1.5, -r * 0.2), r * 0.38, r * 0.26],
		], 8, 0.0), glove)
		shoulders.append(sh)
		elbows.append(el)
		hands.append(hand)
	P.arms = shoulders
	P.forearms = elbows
	P.hands = hands
	return [shoulders, elbows, hands]


static func _pivot(parent: Node3D, at: Vector3, name: String) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = at
	parent.add_child(n)
	return n


static func _add(parent: Node3D, mesh: Mesh, m: Material, at: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if m:
		mi.material_override = m
	mi.position = at
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## 이 형체만의 보통 재질(mats에 넣는다: 사라질 때 투명하게 한다). 윤곽이 보이게 가장자리를 조금 밝힌다.
static func _mat(P: Dictionary, c: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	m.rim_enabled = true
	m.rim = 0.2
	m.rim_tint = 0.5
	(P.mats as Array).append(m)
	return m


static func _cloak(P: Dictionary, cloth: Color, rim: Color, rim_energy: float, tear: float, flutter: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CLOAK_SHADER
	m.set_shader_parameter("tatter", _tatter())
	m.set_shader_parameter("cloth", cloth)
	m.set_shader_parameter("rim", rim)
	m.set_shader_parameter("rim_energy", rim_energy)
	m.set_shader_parameter("tear", tear)
	m.set_shader_parameter("flutter", flutter)
	m.set_shader_parameter("phase", float(P.phase) * 1.7 + float((P.cloaks as Array).size()) * 0.9)
	m.set_shader_parameter("fade", 1.0)
	(P.cloaks as Array).append(m)
	return m


## 두건 안의 어둠(빛을 받지 않는 검은 타원). 이 형체의 mats에 넣어 같이 사라진다.
static func _void(P: Dictionary, parent: Node3D, at: Vector3, r: float, h: float) -> void:
	var face := SphereMesh.new()
	face.radius = r
	face.height = h
	face.radial_segments = 12
	face.rings = 6
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.BLACK
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	(P.mats as Array).append(m)
	_add(parent, face, m, at).name = "Void"


static func _cyl(top: float, bottom: float, h: float, sides: int) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	return c


static func _box_mesh(size: Vector3) -> ArrayMesh:
	var b := BoxMesh.new()
	b.size = size
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, b.get_mesh_arrays())
	return am


## node의 기저를 top 기준으로(사이의 회전을 모두 곱한 것).
static func _basis_to(node: Node3D, top: Node3D) -> Basis:
	var b := Basis.IDENTITY
	var n: Node = node
	while n != null and n != top:
		if n is Node3D:
			b = (n as Node3D).basis * b
		n = n.get_parent()
	return b


static func _tatter() -> NoiseTexture2D:
	if _cache.has("tatter"):
		return _cache["tatter"]
	var nz := FastNoiseLite.new()
	nz.frequency = 0.035
	nz.fractal_octaves = 3
	var t := NoiseTexture2D.new()
	t.noise = nz
	t.seamless = true
	t.width = 128
	t.height = 128
	_cache["tatter"] = t
	return t
