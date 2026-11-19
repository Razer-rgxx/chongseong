class_name EnemyArt
extends RefCounted
## 11단계 새 적 5종의 몸(아트팀, docs/content.md "11단계"). EnemyView가 몸 노드(_body) 아래에 짓고,
## 모션팀(EnemyMotion)과 이펙트팀(EnemyFx)이 돌려받은 부품(Dictionary)으로 움직이고 칠한다.
## 노드에 기대지 않는 정적 함수만 둔다. 어두운 사실풍: 해진 천, 낡은 가죽, 녹슨 쇠, 뼈빛 뿔. 꾸밈용 랜덤은 쓰지 않는다.
##
## 좌표: 미터. 모든 몸은 -Z를 보고(오른쪽 = +X, 왼쪽 = -X), 원점은 발밑이다. 크기(scale)는 root.scale에 넣었다.
## 관절(Node3D 피벗) 축: rotation.x > 0이면 팔·다리가 앞(-Z)으로 들린다(PI/2 = 곧게 앞). 머리는 rotation.x < 0이면 숙인다.
##   어깨 rotation.z는 왼팔 < 0, 오른팔 > 0이 바깥으로 벌어지는 쪽이다. 쉬는 자세 = 지었을 때의 rotation(움직이기 전에 저장해 둔다).
## 왼쪽·오른쪽 짝은 늘 [왼, 오] 순서다. 네발짐승의 다리는 [앞왼, 앞오, 뒤왼, 뒤오](늑대와 같다).
##
## build가 돌려주는 키(그 종류에 없는 키는 빠진다. parts.get(키)로 읽는다):
##   공통   kind(StringName), root(Node3D, 이 몸 전체. scale = 몸 크기), scale(float), height(m, 발밑에서 머리 끝)
##          eyes(Array[MeshInstance3D], 이름 Eye0/Eye1, 짝마다 재질 하나. EnemyView의 눈과 같은 unshaded 빛 구슬)
##          mats(Array[StandardMaterial3D], 상태 빛과 맞을 때 번쩍임. albedo_color를 바탕색으로 삼는다)
##          cloaks(Array[ShaderMaterial], wraith_cloak.gdshader: tint, flash, fade, rim)
##          glow(Array[StandardMaterial3D], 깜빡일 빛. emission_energy_multiplier에 곱한다. 바탕값은 meta "base_energy".
##               mats에는 넣지 않았다(정예의 emission 덮어쓰기에 빛이 지워지지 않게))
##   archer  torso, head, arms[2](어깨), forearms[2](팔꿈치), hands[2](손목), legs[2](엉덩이), knees[2],
##           bow(왼손의 활 노드, 원점 = 쥔 곳, 쏘는 쪽 -Z. 팔을 움직이면 bow.basis로 다시 세운다),
##           bowstring(시위 가운데 오늬 노드, 활 지역 좌표. set_draw로 당긴다), string_segments(시위 두 토막, set_draw가 쓴다),
##           arrow(오늬에 건 화살 MeshInstance3D, 깃 끝이 오늬. 처음에는 숨김), quiver(등의 화살통). cloaks[0] = 망토와 두건
##   shield  knight(LordCharacter, 모델이 없으면 null), skeleton(Skeleton3D 또는 null), shield(방패 노드, 왼 팔뚝 뼈에 붙었다.
##           shield_mesh 좌표: 앞 -Z), sword(SwordModel, 오른손). 모델이 없을 때의 도형 몸은
##           torso, head, arms[2], forearms[2], hands[2], legs[2], knees[2]도 준다(방패는 왼 팔꿈치 아래)
##   charger torso(몸통), head(낮게 든 머리), horns(머리의 뿔 노드), legs[4](엉덩이·어깨), knees[4], tail
##   bomber  torso(골반에서 굽은 등), head, belly(부푼 배 피벗: scale로 부풀린다), arms[2], forearms[2], hands[2],
##           legs[2], knees[2], light(OmniLight3D, 배 앞의 불빛, meta "base_energy"). glow = [배, 입]
##   caller  torso, head, arms[2], forearms[2], hands[2](오른손 = 지팡이), staff(지팡이 노드, 원점 = 쥔 곳),
##           lantern(등불이 매달린 진자 피벗: 쉬는 자세는 몸 기준으로 곧게 아래, rotation.x·z로 흔든다),
##           light(OmniLight3D, 등불, meta "base_energy"). glow = [불꽃, 유리], cloaks = [옷과 두건, 어깨 망토와 소매]
##
## 쉬는 자세(지었을 때의 rotation, 라디안):
##   archer  왼어깨 (0.15, 0, -0.08) 왼팔꿈치 (0.45, 0, 0) / 오른어깨 (0.05, 0, 0.06) 오른팔꿈치 (0.2, 0, 0). 나머지 0
##   bomber  어깨 (0.35, 0, ±0.42) 팔꿈치 (0.9, 0, ∓0.3)(왼, 오 순서의 부호). 나머지 0
##   caller  왼어깨 (0.12, 0, -0.06) 왼팔꿈치 (0.35, 0, 0) / 오른어깨 (0.3, 0, 0.12) 오른팔꿈치 (0.65, 0, 0). 나머지 0
##   charger 모두 0(뒷다리는 모양이 오금에서 꺾여 있다). shield 도형 몸만: 왼어깨 (0.35, 0, -0.15) 왼팔꿈치 (1.1, 0, 0) ...
##
## 기사 모델(방패병)은 트리에 들어간 뒤(ready) 옷을 입힌다. 부모가 트리 밖에서 지으면 mats·eyes·shield·sword·skeleton은
## 그때 같은 배열과 같은 Dictionary에 채워진다. EnemyView처럼 트리 안의 몸 노드에 지으면 build가 돌아올 때 다 차 있다.
## 기사의 눈은 이미 투구 앞에 맞춰 두었다(EnemyView._place_eyes가 필요 없다).

const CLOAK_SHADER: Shader = preload("res://scripts/enemies/wraith_cloak.gdshader")

const KINDS: Array[StringName] = [&"archer", &"shield", &"charger", &"bomber", &"caller"]

## 종류마다 눈 색. 정예는 EnemyView가 금빛으로 바꾼다.
const EYE_COLORS: Dictionary = {
	&"archer": Color(0.95, 0.9, 0.72),
	&"shield": Color(0.7, 0.85, 1.0),
	&"charger": Color(1.0, 0.2, 0.08),
	&"bomber": Color(1.0, 0.62, 0.2),
	&"caller": Color(0.7, 1.0, 0.78),
}

## 화살(arrow_mesh): 원점 = 화살촉 끝, 깃 쪽 끝이 +Z로 ARROW_LENGTH. 날아가는 쪽은 -Z.
const ARROW_LENGTH: float = 0.8
## 활(bow_mesh): 원점 = 쥔 곳, 위 끝 BOW_TIP(아래 끝은 y를 뒤집은 것). 시위는 +Z(쏘는 이 쪽), 쏘는 쪽은 -Z.
const BOW_TIP := Vector3(0.0, 0.68, 0.14)
## 다 당겼을 때 오늬(시위 가운데)의 자리. 활 지역 좌표.
const BOW_FULL_DRAW := Vector3(0.0, 0.0, 0.66)
## 지팡이(staff_mesh): 원점 = 아래 끝, +Y로 서고 꼭대기의 갈고리는 -Z로 굽는다. 쥔 곳과 등불을 다는 곳.
const STAFF_GRIP := Vector3(0.0, 1.3, 0.0)
const STAFF_HOOK := Vector3(0.0, 2.02, -0.245)
## 방패(shield_mesh): 앞면이 -Z, 위가 +Y. 원점 = 뒷면 가운데(팔이 지나는 자리). 너비와 높이(m).
const SHIELD_SIZE := Vector2(0.68, 1.06)
const SHIELD_TOP: float = 0.4
## 방패병 기사 모델의 크기(영주 = 1, 거인 = 1.85).
const SHIELD_KNIGHT_SCALE: float = 1.15

## 질감과 소품 재질은 한 번만 만든다.
static var _cache: Dictionary = {}


## kind의 몸을 parent 아래에 짓는다. scale = 적 반지름 / 표의 반지름, color = EnemyData.color(망토 가장자리·털에 조금 섞는다).
static func build(kind: StringName, parent: Node3D, scale: float, color: Color) -> Dictionary:
	match kind:
		&"archer":
			return build_archer(parent, scale, color)
		&"shield":
			return build_shield(parent, scale, color)
		&"charger":
			return build_charger(parent, scale, color)
		&"bomber":
			return build_bomber(parent, scale, color)
		&"caller":
			return build_caller(parent, scale, color)
	push_error("EnemyArt: 모르는 적 %s" % kind)
	return {}


# ---------------------------------------------------------------- 활잡이

## 두건 쓴 활잡이(키 1.88m). 무릎까지 오는 해진 망토 아래로 다리와 장화가 보이고, 왼손에 굽은 활, 등에 화살통.
## 쉬는 자세: 왼팔을 조금 앞으로 내려 활을 몸 옆에 곧게 세운다. 오른팔은 내린다.
static func build_archer(parent: Node3D, scale: float, color: Color) -> Dictionary:
	var P := _begin(&"archer", parent, scale)
	var root: Node3D = P.root
	P.height = 1.88 * scale
	var cloth := _std(P, Color(0.075, 0.07, 0.064), 0.95)
	var leather := _std(P, Color(0.1, 0.07, 0.048), 0.7)
	# 다리: 바지와 무릎 아래 장화(발끝이 앞)
	var legs: Array[Node3D] = []
	var knees: Array[Node3D] = []
	for i in 2:
		var side: float = -1.0 if i == 0 else 1.0
		var hip := _pivot(root, Vector3(0.1 * side, 0.88, 0.0), "Hip")
		_add(hip, CreatureMesh.loft([
			[Vector3(0, 0.08, 0), 0.09, 0.095], [Vector3(0, -0.2, 0), 0.078, 0.082], [Vector3(0, -0.43, 0), 0.056, 0.06],
		], 10, 0.0), cloth)
		var knee := _pivot(hip, Vector3(0, -0.43, 0), "Knee")
		_add(knee, CreatureMesh.loft([
			[Vector3(0, 0.03, 0), 0.056, 0.06], [Vector3(0, -0.18, 0.01), 0.05, 0.055],
		], 10, 0.0), cloth)
		_add(knee, CreatureMesh.loft([
			[Vector3(0, -0.12, 0.0), 0.062, 0.066], [Vector3(0, -0.34, 0.012), 0.058, 0.062],
			[Vector3(0, -0.41, -0.02), 0.062, 0.05], [Vector3(0, -0.425, -0.12), 0.052, 0.034], [Vector3(0, -0.43, -0.18), 0.03, 0.02],
		], 10, 0.0), leather)
		legs.append(hip)
		knees.append(knee)
	P.legs = legs
	P.knees = knees
	# 몸통(망토 안. 팔을 들면 보인다)
	var torso := _pivot(root, Vector3(0, 0.9, 0), "Torso")
	P.torso = torso
	_add(torso, CreatureMesh.loft([
		[Vector3(0, -0.06, 0), 0.15, 0.11], [Vector3(0, 0.2, 0), 0.17, 0.12], [Vector3(0, 0.45, 0), 0.19, 0.12], [Vector3(0, 0.6, 0), 0.08, 0.07],
	], 12, 0.0), cloth)
	# 망토: 무릎에서 어깨까지. 망령보다 짙고 덜 빛나며, 끝단만 조금 해졌다
	var rim: Color = Color(0.5, 0.48, 0.44).lerp(color, 0.25)
	var mantle := _cloak(P, Color(0.058, 0.05, 0.042), rim, 0.45, 0.16, 0.035)
	_add(torso, CreatureMesh.lathe([
		[-0.38, 0.33, 0.29, 0.05], [-0.15, 0.29, 0.25, 0.04], [0.1, 0.26, 0.2, 0.02], [0.35, 0.27, 0.19, 0.01],
		[0.5, 0.275, 0.18, 0.0], [0.58, 0.2, 0.15, 0.0], [0.645, 0.11, 0.1, 0.01],
	], 20), mantle).name = "Mantle"
	# 머리: 두건과 그 안의 어둠
	var head := _pivot(torso, Vector3(0, 0.62, 0), "Head")
	P.head = head
	_add(head, CreatureMesh.lathe([
		[-0.1, 0.17, 0.17, 0.02], [0.0, 0.155, 0.155, 0.02], [0.12, 0.155, 0.16, 0.03], [0.23, 0.13, 0.145, 0.06],
		[0.31, 0.075, 0.085, 0.1], [0.35, 0.01, 0.01, 0.14],
	], 18), mantle).name = "Hood"
	_void(head, Vector3(0, 0.13, -0.07), 0.12, 0.2)
	_eyes(P, head, Vector3(0, 0.14, -0.18), 0.045, 0.024, EYE_COLORS[&"archer"])
	# 팔: 소매와 가죽 팔뚝, 장갑
	var arms := _arms(P, torso, Vector3(0.22, 0.5, 0.0), 0.3, 0.28, cloth, leather, 0.07)
	var sh: Array[Node3D] = arms[0]
	var el: Array[Node3D] = arms[1]
	var hands: Array[Node3D] = arms[2]
	sh[0].rotation = Vector3(0.15, 0.0, -0.08)
	el[0].rotation = Vector3(0.45, 0.0, 0.0)
	sh[1].rotation = Vector3(0.05, 0.0, 0.06)
	el[1].rotation = Vector3(0.2, 0.0, 0.0)
	# 활: 왼손에 곧게 세운다(활 노드의 원점 = 쥔 곳)
	var bow := Node3D.new()
	bow.name = "Bow"
	hands[0].add_child(bow)
	bow.position = Vector3(0, -0.065, -0.012)
	bow.basis = _basis_to(hands[0], root).inverse() * Basis.from_euler(Vector3(0.0, 0.0, -0.06))
	P.bow = bow
	var bow_mi := _add(bow, bow_mesh(false), null)
	bow_mi.name = "BowMesh"
	_own_materials(P, bow_mi)
	# 시위: 두 토막이 활 끝에서 오늬로 모인다(set_draw로 당긴다)
	var nock := _pivot(bow, Vector3(0, 0, BOW_TIP.z), "Nock")
	P.bowstring = nock
	var cord := CylinderMesh.new()
	cord.top_radius = 0.004
	cord.bottom_radius = 0.004
	cord.height = 1.0
	cord.radial_segments = 4
	cord.rings = 0
	var cord_m := _std(P, Color(0.62, 0.58, 0.5), 0.8)
	var segs: Array[MeshInstance3D] = []
	for i in 2:
		var seg := _add(bow, cord, cord_m)
		seg.name = "String%d" % i
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		segs.append(seg)
	P.string_segments = segs
	# 오늬에 건 화살(겨눌 때 보인다): 깃 끝이 오늬에, 촉이 앞
	var arrow := MeshInstance3D.new()
	arrow.name = "Arrow"
	arrow.mesh = arrow_mesh()
	arrow.position = Vector3(0, 0, -ARROW_LENGTH)
	arrow.visible = false
	nock.add_child(arrow)
	P.arrow = arrow
	set_draw(P, 0.0)
	# 화살통: 등 오른쪽 어깨 뒤로 기울고, 깃이 어깨 위로 보인다
	var quiver := _pivot(torso, Vector3(0.11, 0.3, 0.26), "Quiver")
	quiver.rotation = Vector3(0.18, 0.0, -0.32)
	P.quiver = quiver
	_add(quiver, CreatureMesh.loft([
		[Vector3(0, -0.38, 0), 0.05, 0.045], [Vector3(0, -0.34, 0), 0.06, 0.055], [Vector3(0, 0.12, 0), 0.068, 0.06], [Vector3(0, 0.16, 0), 0.07, 0.062],
	], 10, 0.0), leather)
	var shaft := arrow_mesh()
	for k in 4:
		var a := MeshInstance3D.new()
		a.mesh = shaft
		a.position = Vector3(-0.025 + 0.018 * k, -0.36, 0.012 * float((k % 2) * 2 - 1))
		a.rotation = Vector3(-PI / 2.0 + 0.04 * float(k - 1), 0.4 * k, 0.05 * float(k - 2))
		quiver.add_child(a)
	return P


## 활을 당긴다. k: 0 = 쉬는 시위, 1 = 다 당김(오늬가 BOW_FULL_DRAW). 시위 두 토막을 오늬에 다시 잇는다.
## 모션팀이 매 프레임 부른다. 오른손을 오늬 자리에 맞추려면 bowstring.global_position을 쓴다.
static func set_draw(parts: Dictionary, k: float) -> void:
	var nock: Node3D = parts.get("bowstring")
	if nock == null:
		return
	nock.position = Vector3(0.0, 0.0, BOW_TIP.z).lerp(BOW_FULL_DRAW, clampf(k, 0.0, 1.0))
	var segs: Array = parts.get("string_segments", [])
	var tips: Array[Vector3] = [BOW_TIP, Vector3(BOW_TIP.x, -BOW_TIP.y, BOW_TIP.z)]
	for i in mini(segs.size(), 2):
		_span(segs[i], tips[i], nock.position)


# ---------------------------------------------------------------- 방패병

## 쇳빛으로 칠한 기사(영주 모델 ×1.15). 왼 팔뚝에 큰 연 모양 방패, 오른손에 짧은 칼.
## 기사 모델이 없으면 같은 차림의 도형 몸(방패를 몸 앞에 든 자세).
static func build_shield(parent: Node3D, scale: float, color: Color) -> Dictionary:
	var P := _begin(&"shield", parent, scale)
	P.height = 1.8 * SHIELD_KNIGHT_SCALE * scale
	P.knight = null
	P.skeleton = null
	var own: String = LordCharacter.enemy_path(&"shield")   # 24단계: 방패병 제 모델이 있으면 그것
	if own == "" and not LordCharacter.available():
		_shield_dummy(P, color)
		return P
	var k := LordCharacter.new()
	if own != "":
		k.char_path = own
	k.name = "Knight"
	k.scale = Vector3.ONE * SHIELD_KNIGHT_SCALE
	P.knight = k
	(P.root as Node3D).add_child(k)
	if k.is_node_ready():
		_dress_knight(P, k, color)
	else:
		k.ready.connect(func() -> void: _dress_knight(P, k, color), CONNECT_ONE_SHOT)
	return P


static func _dress_knight(P: Dictionary, k: LordCharacter, color: Color) -> void:
	var mats: Array = P.mats
	for m in k.recolor(Color(0.56, 0.58, 0.62).lerp(color, 0.1)):
		mats.append(m)
	var sword := SwordModel.make(_short_form(), 0, 7001 + int(k.get_instance_id() % 97), Color.WHITE)
	k.hold(sword)
	P.sword = sword
	var sk := k.find_child("Skeleton3D", true, false) as Skeleton3D
	P.skeleton = sk
	# 방패: 왼 팔뚝 위(T자세에서 손등 쪽 = 위)에 붙인다. 방패 위쪽은 T자세의 앞을 조금 팔꿈치 쪽으로 돌린 것이라
	# 칼과 방패 대기 동작에서 방패가 거의 곧게 몸 앞-왼쪽을 본다.
	var fa_b: int = sk.find_bone("mixamorig_LeftForeArm")
	var hd_b: int = sk.find_bone("mixamorig_LeftHand")
	if fa_b >= 0 and hd_b >= 0:
		var fa: Vector3 = sk.get_bone_global_rest(fa_b).origin
		var hd: Vector3 = sk.get_bone_global_rest(hd_b).origin
		var along: Vector3 = (hd - fa).normalized()
		var front := Vector3.UP
		var top: Vector3 = (Vector3.BACK * cos(0.35) - along * sin(0.35))
		top = (top - front * top.dot(front)).normalized()
		var frame := Transform3D(Basis(front.cross(top), top, -front), fa.lerp(hd, 0.5) + front * 0.065)
		var holder := Node3D.new()
		holder.name = "Shield"
		k.attach("mixamorig_LeftForeArm", holder)
		holder.transform = sk.get_bone_global_rest(fa_b).affine_inverse() * frame
		_shield_on(P, holder)
	# 눈: 투구 앞(머리 뼈에서 앞 0.11, 위 0.07)
	var head_b: int = sk.find_bone("mixamorig_Head")
	if head_b >= 0:
		var eh := Node3D.new()
		eh.name = "EyeHolder"
		k.attach("mixamorig_Head", eh)
		var at: Vector3 = sk.get_bone_global_rest(head_b).origin + Vector3(0.0, 0.07, 0.11)
		eh.transform = sk.get_bone_global_rest(head_b).affine_inverse() * Transform3D(Basis.IDENTITY, at)
		_eyes(P, eh, Vector3.ZERO, 0.035, 0.022, EYE_COLORS[&"shield"])


## 기사 모델이 없을 때: 쇳빛 도형 몸(2.07m). 방패는 왼 팔뚝 앞에 몸 정면을 보게, 칼은 오른손에 앞으로.
static func _shield_dummy(P: Dictionary, color: Color) -> void:
	var root: Node3D = P.root
	var s: float = SHIELD_KNIGHT_SCALE
	var iron := _std(P, Color(0.27, 0.28, 0.3).lerp(color, 0.1), 0.55, 0.6)
	var dark := _std(P, Color(0.1, 0.095, 0.09), 0.85)
	var legs: Array[Node3D] = []
	var knees: Array[Node3D] = []
	for i in 2:
		var side: float = -1.0 if i == 0 else 1.0
		var hip := _pivot(root, Vector3(0.12 * side, 0.9, 0.0) * s, "Hip")
		_add(hip, _capsule(0.08 * s, 0.48 * s), dark, Vector3(0, -0.22, 0) * s)
		var knee := _pivot(hip, Vector3(0, -0.45, 0) * s, "Knee")
		_add(knee, _capsule(0.07 * s, 0.46 * s), iron, Vector3(0, -0.2, 0) * s)
		_add(knee, _box(Vector3(0.12, 0.06, 0.22) * s), dark, Vector3(0, -0.42, -0.04) * s)
		legs.append(hip)
		knees.append(knee)
	P.legs = legs
	P.knees = knees
	var torso := _pivot(root, Vector3(0, 0.92, 0) * s, "Torso")
	P.torso = torso
	_add(torso, CreatureMesh.loft([
		[Vector3(0, 0.0, 0), 0.17 * s, 0.13 * s], [Vector3(0, 0.25, 0) * s, 0.2 * s, 0.14 * s],
		[Vector3(0, 0.5, 0) * s, 0.23 * s, 0.15 * s], [Vector3(0, 0.6, 0) * s, 0.1 * s, 0.08 * s],
	], 12, 0.0), iron)
	var head := _pivot(torso, Vector3(0, 0.62, 0) * s, "Head")
	P.head = head
	var helm := CylinderMesh.new()
	helm.top_radius = 0.11 * s
	helm.bottom_radius = 0.12 * s
	helm.height = 0.24 * s
	_add(head, helm, iron, Vector3(0, 0.12, 0) * s)
	var crown := SphereMesh.new()
	crown.radius = 0.11 * s
	crown.height = 0.12 * s
	_add(head, crown, iron, Vector3(0, 0.24, 0) * s)
	_void(head, Vector3(0, 0.15, -0.06) * s, 0.07 * s, 0.05 * s)
	_eyes(P, head, Vector3(0, 0.15, -0.12) * s, 0.035 * s, 0.022 * s, EYE_COLORS[&"shield"])
	var arms := _arms(P, torso, Vector3(0.27, 0.5, 0.0) * s, 0.3 * s, 0.27 * s, iron, dark, 0.075 * s)
	var sh: Array[Node3D] = arms[0]
	var el: Array[Node3D] = arms[1]
	var hands: Array[Node3D] = arms[2]
	sh[0].rotation = Vector3(0.35, 0.0, -0.15)
	el[0].rotation = Vector3(1.1, 0.0, 0.0)
	sh[1].rotation = Vector3(0.3, 0.0, 0.1)
	el[1].rotation = Vector3(0.6, 0.0, 0.0)
	var holder := _pivot(el[0], Vector3(0, -0.15, -0.07) * s, "Shield")
	holder.basis = _basis_to(el[0], root).inverse() * Basis.from_euler(Vector3(0.0, 0.25, 0.0))
	holder.scale = Vector3.ONE * s
	_shield_on(P, holder)
	var sword := SwordModel.make(_short_form(), 0, 7001, Color.WHITE)
	hands[1].add_child(sword)
	sword.position = Vector3(0, -0.06, 0) * s
	sword.basis = _basis_to(hands[1], root).inverse() * Basis.from_euler(Vector3(-1.1, 0.0, 0.0))
	P.sword = sword


static func _shield_on(P: Dictionary, holder: Node3D) -> void:
	var mi := _add(holder, shield_mesh(), null)
	mi.name = "ShieldMesh"
	_own_materials(P, mi)
	P.shield = holder


static func _short_form() -> FormData:
	var f := FormData.new()
	f.display_name = "장검"
	f.blade_length = 0.72
	f.blade_width = 0.07
	return f


# ---------------------------------------------------------------- 돌격병

## 뿔 달린 큰 짐승(어깨 혹 2.05m, 길이 2.3m). 들소와 멧돼지를 섞은 몸에 굵은 뼈빛 뿔, 이마에 녹슨 쇠 덮개.
## 머리를 늘 낮게 들고 있어서 돌진 전에 더 숙이면(head.rotation.x < 0) 뿔이 앞을 겨눈다.
## 기사 모델과 달리 에셋이 없어도 같은 모습이다.
static func build_charger(parent: Node3D, scale: float, color: Color) -> Dictionary:
	var P := _begin(&"charger", parent, scale)
	var root: Node3D = P.root
	P.height = 2.05 * scale
	var coat: Color = Color(0.13, 0.105, 0.085).lerp(color, 0.1)
	var fur := _fur(P, coat, coat.darkened(0.65), Vector3(3, 6, 1))
	var mane := _fur(P, coat.darkened(0.35), Color(0.02, 0.018, 0.015), Vector3(5, 9, 1))
	var horn := _std(P, Color(0.46, 0.41, 0.33), 0.55)
	var hoof := _std(P, Color(0.06, 0.05, 0.045), 0.6)
	var iron := _std(P, Color(0.24, 0.21, 0.19), 0.6, 0.7)
	var torso := _pivot(root, Vector3(0, 1.05, 0), "Torso")
	P.torso = torso
	# 몸통: 어깨 위가 크게 솟은 혹, 엉덩이는 낮다
	_add(torso, CreatureMesh.loft(_smooth([
		[Vector3(0, 0.14, 0.98), 0.1, 0.1], [Vector3(0, 0.13, 0.9), 0.3, 0.3], [Vector3(0, 0.1, 0.66), 0.4, 0.42],
		[Vector3(0, 0.09, 0.36), 0.42, 0.46], [Vector3(0, 0.16, 0.06), 0.47, 0.57], [Vector3(0, 0.3, -0.26), 0.52, 0.7],
		[Vector3(0, 0.32, -0.52), 0.5, 0.68], [Vector3(0, 0.17, -0.77), 0.41, 0.55], [Vector3(0, -0.02, -0.92), 0.27, 0.33],
		[Vector3(0, -0.1, -1.0), 0.12, 0.14],
	]), 18, 0.08), fur)
	# 머리: 몸 앞 아래에 낮게. 넓은 이마와 뭉툭한 주둥이
	var head := _pivot(torso, Vector3(0, -0.05, -0.98), "Head")
	P.head = head
	_add(head, CreatureMesh.loft(_smooth([
		[Vector3(0, 0.06, 0.14), 0.12, 0.13], [Vector3(0, 0.06, 0.08), 0.2, 0.21], [Vector3(0, 0.04, -0.06), 0.26, 0.26],
		[Vector3(0, -0.06, -0.24), 0.23, 0.22], [Vector3(0, -0.18, -0.4), 0.2, 0.17], [Vector3(0, -0.27, -0.5), 0.18, 0.14],
		[Vector3(0, -0.31, -0.56), 0.14, 0.1], [Vector3(0, -0.32, -0.59), 0.06, 0.04],
	]), 16, 0.15), fur)
	# 이마의 쇠 덮개(콧등까지)와 뿔을 가로지르는 띠
	_add(head, CreatureMesh.loft([
		[Vector3(0, 0.3, -0.06), 0.1, 0.02], [Vector3(0, 0.29, -0.09), 0.13, 0.024], [Vector3(0, 0.16, -0.27), 0.11, 0.022],
		[Vector3(0, -0.045, -0.44), 0.08, 0.02], [Vector3(0, -0.09, -0.48), 0.05, 0.012],
	], 10, 0.0), iron)
	_add(head, CreatureMesh.loft([
		[Vector3(-0.27, 0.17, -0.06), 0.03, 0.03], [Vector3(-0.14, 0.29, -0.1), 0.05, 0.025], [Vector3(0, 0.32, -0.11), 0.05, 0.025],
		[Vector3(0.14, 0.29, -0.1), 0.05, 0.025], [Vector3(0.27, 0.17, -0.06), 0.03, 0.03],
	], 8, 0.0), iron)
	var horns := _pivot(head, Vector3.ZERO, "Horns")
	P.horns = horns
	for side in [-1.0, 1.0]:
		_add(horns, CreatureMesh.loft([
			[Vector3(0.18 * side, 0.12, -0.06), 0.09, 0.09], [Vector3(0.33 * side, 0.14, -0.09), 0.075, 0.075],
			[Vector3(0.47 * side, 0.2, -0.17), 0.058, 0.058], [Vector3(0.54 * side, 0.3, -0.31), 0.043, 0.043],
			[Vector3(0.52 * side, 0.39, -0.46), 0.028, 0.028], [Vector3(0.46 * side, 0.44, -0.57), 0.012, 0.012],
		], 10, 0.25), horn)
	_eyes(P, head, Vector3(0, -0.02, -0.28), 0.205, 0.03, EYE_COLORS[&"charger"])
	# 꼬리
	var tail := _pivot(torso, Vector3(0, 0.15, 0.97), "Tail")
	P.tail = tail
	_add(tail, CreatureMesh.loft([
		[Vector3(0, 0, 0), 0.05, 0.05], [Vector3(0, -0.2, 0.06), 0.04, 0.04], [Vector3(0, -0.48, 0.08), 0.03, 0.03],
		[Vector3(0, -0.54, 0.08), 0.06, 0.06], [Vector3(0, -0.7, 0.07), 0.05, 0.05], [Vector3(0, -0.78, 0.06), 0.01, 0.01],
	], 8, 0.0), mane)
	# 다리: [앞왼, 앞오, 뒤왼, 뒤오]. 쉬는 자세의 회전은 모두 0이고 뒷다리는 모양이 오금으로 꺾여 있다.
	var legs: Array[Node3D] = []
	var knees: Array[Node3D] = []
	for i in 4:
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var front: bool = i < 2
		var hip := _pivot(torso, Vector3(0.27 * side, -0.2, -0.55) if front else Vector3(0.26 * side, -0.05, 0.62), "Hip")
		var knee: Node3D
		if front:
			_add(hip, CreatureMesh.loft([
				[Vector3(0, 0.14, 0), 0.17, 0.2], [Vector3(0, -0.15, 0), 0.13, 0.15], [Vector3(0, -0.4, 0), 0.085, 0.09],
			], 12, 0.0), fur)
			knee = _pivot(hip, Vector3(0, -0.4, 0), "Knee")
			_add(knee, CreatureMesh.loft([
				[Vector3(0, 0.03, 0), 0.08, 0.085], [Vector3(0, -0.28, 0), 0.058, 0.062], [Vector3(0, -0.35, 0), 0.075, 0.07],
			], 12, 0.0), fur)
			_hoof(knee, Vector3(0, -0.36, -0.01), hoof)
		else:
			_add(hip, CreatureMesh.loft([
				[Vector3(0, 0.16, -0.02), 0.2, 0.25], [Vector3(0, -0.15, 0.06), 0.15, 0.17], [Vector3(0, -0.45, 0.14), 0.08, 0.09],
			], 12, 0.0), fur)
			knee = _pivot(hip, Vector3(0, -0.45, 0.14), "Knee")
			_add(knee, CreatureMesh.loft([
				[Vector3(0, 0.03, 0.0), 0.075, 0.08], [Vector3(0, -0.25, -0.06), 0.055, 0.06], [Vector3(0, -0.43, -0.1), 0.068, 0.066],
			], 12, 0.0), fur)
			_hoof(knee, Vector3(0, -0.44, -0.11), hoof)
		legs.append(hip)
		knees.append(knee)
	P.legs = legs
	P.knees = knees
	return P


static func _hoof(parent: Node3D, at: Vector3, m: Material) -> void:
	_add(parent, CreatureMesh.loft([
		[at + Vector3(0, 0.02, 0.0), 0.07, 0.068], [at + Vector3(0, -0.04, -0.01), 0.09, 0.088], [at + Vector3(0, -0.085, -0.015), 0.095, 0.09],
	], 10, 0.0), m)


# ---------------------------------------------------------------- 자폭병

## 등이 굽은 작은 것(0.92m). 잿빛 마른 팔다리, 앞으로 불룩 튀어나온 배는 그을려 갈라졌고 틈에서 불씨가 빛난다.
## 심지가 타는 동안 glow[0](배)의 emission_energy_multiplier와 light.light_energy를 올리고 belly.scale로 부풀린다.
static func build_bomber(parent: Node3D, scale: float, color: Color) -> Dictionary:
	var P := _begin(&"bomber", parent, scale)
	var root: Node3D = P.root
	P.height = 0.92 * scale
	var skin := _fur(P, Color(0.2, 0.19, 0.18).lerp(color, 0.04), Color(0.11, 0.1, 0.095), Vector3(3, 6, 1))
	var claw := _std(P, Color(0.1, 0.085, 0.07), 0.5)
	# 다리: 짧고 휘었다
	var legs: Array[Node3D] = []
	var knees: Array[Node3D] = []
	for i in 2:
		var side: float = -1.0 if i == 0 else 1.0
		var hip := _pivot(root, Vector3(0.11 * side, 0.43, 0.06), "Hip")
		_add(hip, CreatureMesh.loft([
			[Vector3(0, 0.04, 0), 0.065, 0.07], [Vector3(0.03 * side, -0.12, -0.08), 0.052, 0.056], [Vector3(0.04 * side, -0.22, -0.1), 0.04, 0.045],
		], 8, 0.0), skin)
		var knee := _pivot(hip, Vector3(0.04 * side, -0.22, -0.1), "Knee")
		_add(knee, CreatureMesh.loft([
			[Vector3(0, 0.02, 0), 0.04, 0.045], [Vector3(0, -0.1, 0.04), 0.032, 0.034], [Vector3(0, -0.18, 0.06), 0.028, 0.03],
		], 8, 0.0), skin)
		_add(knee, CreatureMesh.loft([
			[Vector3(0, -0.17, 0.08), 0.035, 0.026], [Vector3(0, -0.195, 0.0), 0.045, 0.022], [Vector3(0, -0.2, -0.08), 0.032, 0.014],
			[Vector3(0, -0.205, -0.11), 0.012, 0.008],
		], 8, 0.0), skin)
		legs.append(hip)
		knees.append(knee)
	P.legs = legs
	P.knees = knees
	# 몸: 골반에서 둥글게 굽은 등, 앞으로 내민 목
	var torso := _pivot(root, Vector3(0, 0.43, 0.06), "Torso")
	P.torso = torso
	_add(torso, CreatureMesh.loft(_smooth([
		[Vector3(0, -0.05, 0.04), 0.1, 0.08], [Vector3(0, -0.02, 0.05), 0.13, 0.1], [Vector3(0, 0.1, 0.08), 0.16, 0.14],
		[Vector3(0, 0.23, 0.06), 0.18, 0.16], [Vector3(0, 0.33, -0.02), 0.17, 0.15], [Vector3(0, 0.39, -0.12), 0.14, 0.12],
		[Vector3(0, 0.4, -0.21), 0.085, 0.075], [Vector3(0, 0.38, -0.27), 0.05, 0.05],
	]), 14, 0.1), skin)
	# 등뼈 마디
	var knob := SphereMesh.new()
	knob.radius = 0.03
	knob.height = 0.05
	knob.radial_segments = 8
	knob.rings = 4
	for b in [Vector3(0, 0.1, 0.21), Vector3(0, 0.2, 0.215), Vector3(0, 0.29, 0.17), Vector3(0, 0.36, 0.08), Vector3(0, 0.4, -0.02)]:
		_add(torso, knob, skin, b)
	# 부푼 배: 갈라진 틈에서 불씨 빛
	var belly := _pivot(torso, Vector3(0, 0.14, -0.08), "Belly")
	P.belly = belly
	var ember := StandardMaterial3D.new()
	ember.albedo_color = Color(0.16, 0.1, 0.08)
	ember.albedo_texture = _noise_tex("char", 0.06, Color(0.25, 0.2, 0.17), Color(0.05, 0.03, 0.025))
	ember.roughness = 0.9
	ember.emission_enabled = true
	ember.emission = Color(1.0, 0.36, 0.07)
	ember.emission_texture = _cracks()
	ember.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	ember.emission_energy_multiplier = 2.0
	ember.uv1_scale = Vector3(2.0, 1.5, 1.0)
	ember.set_meta("base_energy", 2.0)
	(P.glow as Array).append(ember)
	_add(belly, CreatureMesh.loft(_smooth([
		[Vector3(0, -0.17, 0.0), 0.04, 0.04], [Vector3(0, -0.13, -0.01), 0.15, 0.14], [Vector3(0, -0.02, -0.04), 0.215, 0.21],
		[Vector3(0, 0.1, -0.03), 0.19, 0.18], [Vector3(0, 0.19, 0.0), 0.11, 0.1], [Vector3(0, 0.22, 0.01), 0.03, 0.03],
	]), 16, 0.0), ember)
	var light := OmniLight3D.new()
	light.name = "Ember"
	light.light_color = Color(1.0, 0.45, 0.15)
	light.light_energy = 0.45
	light.omni_range = 1.6 * scale
	light.omni_attenuation = 1.6
	light.shadow_enabled = false
	light.position = Vector3(0, -0.12, -0.5)
	belly.add_child(light)
	light.set_meta("base_energy", 0.45)
	P.light = light
	# 머리: 굽은 등 끝에서 앞으로 내밀었다
	var head := _pivot(torso, Vector3(0, 0.38, -0.27), "Head")
	P.head = head
	_add(head, CreatureMesh.loft(_smooth([
		[Vector3(0, 0.03, 0.05), 0.05, 0.05], [Vector3(0, 0.035, 0.0), 0.075, 0.075], [Vector3(0, 0.03, -0.06), 0.085, 0.08],
		[Vector3(0, 0.0, -0.11), 0.07, 0.06], [Vector3(0, -0.03, -0.145), 0.045, 0.038], [Vector3(0, -0.04, -0.16), 0.02, 0.018],
	]), 12, 0.1), skin)
	# 눈 위로 튀어나온 이마뼈
	_add(head, CreatureMesh.loft([
		[Vector3(-0.065, 0.055, -0.07), 0.012, 0.012], [Vector3(-0.03, 0.07, -0.1), 0.018, 0.016], [Vector3(0.0, 0.072, -0.105), 0.016, 0.014],
		[Vector3(0.03, 0.07, -0.1), 0.018, 0.016], [Vector3(0.065, 0.055, -0.07), 0.012, 0.012],
	], 8, 0.0), skin)
	_eyes(P, head, Vector3(0, 0.028, -0.128), 0.036, 0.018, EYE_COLORS[&"bomber"])
	# 벌어진 입 안에도 불씨(배와 같이 깜빡인다: glow[1])
	var maw_m := StandardMaterial3D.new()
	maw_m.albedo_color = Color(0.05, 0.02, 0.01)
	maw_m.emission_enabled = true
	maw_m.emission = Color(1.0, 0.36, 0.07)
	maw_m.emission_energy_multiplier = 1.2
	maw_m.set_meta("base_energy", 1.2)
	(P.glow as Array).append(maw_m)
	var maw := SphereMesh.new()
	maw.radius = 0.03
	maw.height = 0.02
	maw.radial_segments = 10
	maw.rings = 4
	_add(head, maw, maw_m, Vector3(0, -0.035, -0.135), Vector3(0.35, 0, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 팔: 길고 마른 팔이 배를 감싸듯 앞으로
	var arms := _arms(P, torso, Vector3(0.15, 0.34, -0.14), 0.24, 0.24, skin, skin, 0.04)
	var sh: Array[Node3D] = arms[0]
	var el: Array[Node3D] = arms[1]
	var hands: Array[Node3D] = arms[2]
	for i in 2:
		var side: float = -1.0 if i == 0 else 1.0
		sh[i].rotation = Vector3(0.35, 0.0, 0.42 * side)
		el[i].rotation = Vector3(0.9, 0.0, -0.3 * side)
		# 발톱 셋
		for f in 3:
			var fx: float = (float(f) - 1.0) * 0.018
			_add(hands[i], CreatureMesh.loft([
				[Vector3(fx, -0.04, -0.01), 0.008, 0.008], [Vector3(fx * 1.4, -0.09, -0.02), 0.006, 0.006], [Vector3(fx * 1.6, -0.12, -0.0), 0.002, 0.002],
			], 6, 0.0), claw)
	return P


# ---------------------------------------------------------------- 부르는 자

## 키 큰 사제(2.45m). 땅에 끌리는 긴 옷, 뾰족하고 높은 두건, 해진 어깨 망토, 넓은 소매.
## 오른손의 지팡이 꼭대기 갈고리에 등불이 매달려 흐린 푸른 흰빛을 낸다(형광빛이 아니다).
static func build_caller(parent: Node3D, scale: float, color: Color) -> Dictionary:
	var P := _begin(&"caller", parent, scale)
	var root: Node3D = P.root
	P.height = 2.45 * scale
	var rim: Color = Color(0.45, 0.55, 0.48).lerp(color, 0.2)
	var robe := _cloak(P, Color(0.056, 0.058, 0.052), rim, 0.5, 0.06, 0.03)
	var rag := _cloak(P, Color(0.044, 0.046, 0.041), rim, 0.45, 0.4, 0.05)
	var bone := _std(P, Color(0.42, 0.39, 0.35), 0.8)
	var torso := _pivot(root, Vector3(0, 1.0, 0), "Torso")
	P.torso = torso
	_add(torso, CreatureMesh.lathe([
		[-1.0, 0.34, 0.3, 0.05], [-0.7, 0.3, 0.26, 0.04], [-0.3, 0.25, 0.21, 0.02], [0.1, 0.21, 0.17, 0.01],
		[0.5, 0.23, 0.16, 0.0], [0.8, 0.27, 0.17, 0.0], [0.9, 0.2, 0.14, 0.0], [0.96, 0.1, 0.09, 0.01],
	], 20), robe).name = "Robe"
	# 해진 어깨 망토(가슴까지)
	_add(torso, CreatureMesh.lathe([
		[0.38, 0.33, 0.26, 0.02], [0.6, 0.31, 0.22, 0.01], [0.78, 0.29, 0.19, 0.0], [0.88, 0.22, 0.16, 0.0], [0.95, 0.12, 0.1, 0.01],
	], 20), rag).name = "Mantle"
	# 높은 두건
	var head := _pivot(torso, Vector3(0, 0.95, 0), "Head")
	P.head = head
	_add(head, CreatureMesh.lathe([
		[-0.12, 0.16, 0.16, 0.02], [0.0, 0.15, 0.15, 0.02], [0.13, 0.145, 0.155, 0.04], [0.26, 0.115, 0.13, 0.08],
		[0.37, 0.07, 0.08, 0.13], [0.45, 0.03, 0.035, 0.18], [0.5, 0.005, 0.005, 0.22],
	], 18), robe).name = "Hood"
	_void(head, Vector3(0, 0.11, -0.065), 0.115, 0.2)
	_eyes(P, head, Vector3(0, 0.12, -0.172), 0.04, 0.022, EYE_COLORS[&"caller"])
	# 넓은 소매(손목 쪽이 해졌다)와 마른 손
	var shoulders: Array[Node3D] = []
	var elbows: Array[Node3D] = []
	var hands: Array[Node3D] = []
	for i in 2:
		var side: float = -1.0 if i == 0 else 1.0
		var sh := _pivot(torso, Vector3(0.25 * side, 0.8, 0.0), "Shoulder")
		_add(sh, CreatureMesh.loft([
			[Vector3(0, -0.34, 0), 0.085, 0.085], [Vector3(0, -0.15, 0), 0.08, 0.08], [Vector3(0, 0.05, 0), 0.075, 0.075],
		], 10, 0.0, false), rag)
		var el := _pivot(sh, Vector3(0, -0.32, 0), "Elbow")
		_add(el, CreatureMesh.loft([
			[Vector3(0, -0.31, 0.01), 0.14, 0.13], [Vector3(0, -0.18, 0.0), 0.11, 0.1], [Vector3(0, 0.02, 0), 0.085, 0.085],
		], 12, 0.0, false), rag)
		var hand := _pivot(el, Vector3(0, -0.28, 0), "Hand")
		_add(hand, CreatureMesh.loft([
			[Vector3(0, 0.03, 0), 0.03, 0.025], [Vector3(0, -0.04, -0.01), 0.038, 0.02], [Vector3(0, -0.11, -0.02), 0.022, 0.012],
		], 8, 0.0), bone)
		shoulders.append(sh)
		elbows.append(el)
		hands.append(hand)
	P.arms = shoulders
	P.forearms = elbows
	P.hands = hands
	shoulders[0].rotation = Vector3(0.12, 0.0, -0.06)
	elbows[0].rotation = Vector3(0.35, 0.0, 0.0)
	shoulders[1].rotation = Vector3(0.3, 0.0, 0.12)
	elbows[1].rotation = Vector3(0.65, 0.0, 0.0)
	# 지팡이: 오른손에 곧게 세우고, 갈고리는 앞-바깥을 본다
	var staff := Node3D.new()
	staff.name = "Staff"
	hands[1].add_child(staff)
	staff.position = Vector3(0, -0.05, -0.01)
	staff.basis = _basis_to(hands[1], root).inverse() * Basis.from_euler(Vector3(0.0, -0.5, -0.04))
	P.staff = staff
	var staff_mi := _add(staff, staff_mesh(), null, -STAFF_GRIP)
	staff_mi.name = "StaffMesh"
	_own_materials(P, staff_mi)
	# 등불: 갈고리에 매달린 진자. 피벗의 쉬는 자세는 지팡이 기울기를 되돌려 곧게 아래로 늘어진다
	var lantern := _pivot(staff, STAFF_HOOK - STAFF_GRIP, "Lantern")
	lantern.basis = _basis_to(staff, root).inverse()
	P.lantern = lantern
	_lantern(P, lantern)
	return P


static func _lantern(P: Dictionary, at: Node3D) -> void:
	var iron := _std(P, Color(0.12, 0.11, 0.1), 0.55, 0.7)
	var chain := CylinderMesh.new()
	chain.top_radius = 0.006
	chain.bottom_radius = 0.006
	chain.height = 0.1
	chain.radial_segments = 4
	chain.rings = 0
	_add(at, chain, iron, Vector3(0, -0.05, 0))
	var cap := CylinderMesh.new()
	cap.top_radius = 0.018
	cap.bottom_radius = 0.075
	cap.height = 0.06
	cap.radial_segments = 8
	_add(at, cap, iron, Vector3(0, -0.13, 0))
	var bar := CylinderMesh.new()
	bar.top_radius = 0.006
	bar.bottom_radius = 0.006
	bar.height = 0.17
	bar.radial_segments = 4
	bar.rings = 0
	for k in 4:
		var a: float = TAU * k / 4.0 + PI / 4.0
		_add(at, bar, iron, Vector3(cos(a) * 0.065, -0.245, sin(a) * 0.065))
	var base := CylinderMesh.new()
	base.top_radius = 0.075
	base.bottom_radius = 0.06
	base.height = 0.025
	base.radial_segments = 8
	_add(at, base, iron, Vector3(0, -0.34, 0))
	# 흐린 유리와 그 안의 불
	var glass := CylinderMesh.new()
	glass.top_radius = 0.058
	glass.bottom_radius = 0.058
	glass.height = 0.17
	glass.radial_segments = 10
	glass.rings = 0
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.45, 0.6, 0.48, 0.18)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.roughness = 0.3
	gm.emission_enabled = true
	gm.emission = Color(0.4, 0.75, 0.5)
	gm.emission_energy_multiplier = 0.2
	gm.set_meta("base_energy", 0.2)
	(P.glow as Array).append(gm)
	_add(at, glass, gm, Vector3(0, -0.245, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var flame := SphereMesh.new()
	flame.radius = 0.034
	flame.height = 0.1
	flame.radial_segments = 8
	flame.rings = 4
	var fm := StandardMaterial3D.new()
	var c := Color(0.55, 1.0, 0.66)
	fm.albedo_color = c * 0.3
	fm.emission_enabled = true
	fm.emission = c
	fm.emission_energy_multiplier = 1.2
	fm.set_meta("base_energy", 1.2)
	(P.glow as Array).insert(0, fm)
	_add(at, flame, fm, Vector3(0, -0.25, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.name = "LanternLight"
	light.light_color = Color(0.55, 0.9, 0.62)
	light.light_energy = 1.1
	light.omni_range = 3.6 * float(P.scale)
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	light.position = Vector3(0, -0.25, 0)
	light.set_meta("base_energy", 1.1)
	at.add_child(light)
	P.light = light


# ---------------------------------------------------------------- 소품 메시(이펙트팀·기능팀도 쓴다)

## 화살(0.8m). 원점 = 촉 끝, 깃 쪽이 +Z. 쇠 촉(두 날을 엇갈린 넓은 촉), 나무 살, 잿빛 깃 셋.
## 정점 색 한 겹에 재질이 붙어 있다(그대로 MeshInstance3D에 넣으면 된다). 부를 때마다 같은 메시를 돌려준다.
static func arrow_mesh() -> ArrayMesh:
	if _cache.has("arrow"):
		return _cache["arrow"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood := Color(0.36, 0.27, 0.18)
	var iron := Color(0.27, 0.28, 0.3)
	var feather := Color(0.56, 0.53, 0.48)
	var dark := Color(0.08, 0.07, 0.06)
	_tube(st, Vector3(0, 0, 0.1), Vector3(0, 0, 0.78), 0.0075, 0.0075, 6, wood)
	_tube(st, Vector3(0, 0, 0.065), Vector3(0, 0, 0.115), 0.0055, 0.0095, 6, iron)
	_tube(st, Vector3(0, 0, 0.775), Vector3(0, 0, ARROW_LENGTH), 0.0085, 0.0065, 6, dark)
	# 촉: 십자로 엇갈린 두 날
	for k in 2:
		var w: Vector3 = Vector3(0.022, 0, 0) if k == 0 else Vector3(0, 0.022, 0)
		_quad(st, Vector3.ZERO, w + Vector3(0, 0, 0.055), Vector3(0, 0, 0.09), -w + Vector3(0, 0, 0.055), iron)
	# 깃: 120°마다
	for k in 3:
		var a: float = TAU * k / 3.0 + PI / 2.0
		var d := Vector3(cos(a), sin(a), 0.0)
		_quad(st, d * 0.007 + Vector3(0, 0, 0.6), d * 0.032 + Vector3(0, 0, 0.66), d * 0.03 + Vector3(0, 0, 0.765), d * 0.007 + Vector3(0, 0, 0.77), feather)
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.75
	mesh.surface_set_material(0, m)
	_cache["arrow"] = mesh
	return mesh


## 큰 연 모양 방패(SHIELD_SIZE: 너비 0.68m, 높이 1.06m). 앞면 -Z가 볼록하고, 위 +Y. 원점 = 뒷면 가운데(팔이 지나는 자리),
## 위 끝은 y = SHIELD_TOP, 아래 뾰족한 끝은 y = SHIELD_TOP - 높이. 겹: 0 = 판(가죽 씌운 나무에 바랜 검붉은 띠), 1 = 쇠 테.
static func shield_mesh() -> ArrayMesh:
	if _cache.has("shield"):
		return _cache["shield"]
	var hw: float = SHIELD_SIZE.x * 0.5
	var top: float = SHIELD_TOP
	var bottom: float = SHIELD_TOP - SHIELD_SIZE.y
	var th: float = 0.03
	var bend: float = 0.09
	# 테두리(앞에서 볼 때 시계 반대 방향): 위 둥근 변 → 왼쪽 변 → 아래 끝 → 오른쪽 변
	var outline: Array[Vector2] = []
	var n_top: int = 10
	var n_side: int = 16
	for i in n_top + 1:
		var x: float = hw - 2.0 * hw * float(i) / n_top
		outline.append(Vector2(x, top - 0.08 + 0.08 * (1.0 - pow(x / hw, 2.0))))
	for i in range(1, n_side + 1):
		var t: float = float(i) / n_side
		var y: float = lerpf(top - 0.08, bottom, t)
		outline.append(Vector2(-hw * sqrt(maxf(0.0, 1.0 - pow(t, 2.2))), y))
	for i in range(n_side - 1, 0, -1):
		var t: float = float(i) / n_side
		var y: float = lerpf(top - 0.08, bottom, t)
		outline.append(Vector2(hw * sqrt(maxf(0.0, 1.0 - pow(t, 2.2))), y))
	var zf := func(x: float) -> float: return bend * pow(x / hw, 2.0) - th
	var zb := func(x: float) -> float: return bend * pow(x / hw, 2.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector2(0.0, (top + bottom) * 0.45)
	var n: int = outline.size()
	# 앞면은 가운데에서 부채꼴로(Godot의 앞면은 시계 방향이다). 칠은 질감(_shield_paint)이고 뒷면은 정점 색으로 어둡게
	for i in n:
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % n]
		for p in [center, a, b]:
			var q: Vector2 = p
			st.set_color(Color.WHITE)
			st.set_normal(Vector3(2.0 * bend * q.x / (hw * hw), 0.0, -1.0).normalized())
			st.set_uv(Vector2(q.x / SHIELD_SIZE.x + 0.5, (top - q.y) / SHIELD_SIZE.y))
			st.add_vertex(Vector3(q.x, q.y, zf.call(q.x)))
		for p in [center, b, a]:
			var q: Vector2 = p
			st.set_color(Color(0.5, 0.5, 0.5))
			st.set_normal(Vector3(-2.0 * bend * q.x / (hw * hw), 0.0, 1.0).normalized())
			st.set_uv(Vector2(q.x / SHIELD_SIZE.x + 0.5, (top - q.y) / SHIELD_SIZE.y))
			st.add_vertex(Vector3(q.x, q.y, zb.call(q.x)))
	st.generate_tangents()
	var mesh := st.commit()
	var face := StandardMaterial3D.new()
	face.vertex_color_use_as_albedo = true
	face.albedo_texture = _shield_paint()
	face.roughness = 0.85
	face.rim_enabled = true
	face.rim = 0.3
	face.rim_tint = 0.4
	mesh.surface_set_material(0, face)
	# 쇠 테: 테두리를 따라 도는 관
	var ring: Array = []
	for i in n + 1:
		var q: Vector2 = outline[i % n]
		ring.append([Vector3(q.x, q.y, zf.call(q.x) + th * 0.5), 0.02, 0.022])
	var rim_mesh := CreatureMesh.loft(ring, 6, 0.0, false)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, rim_mesh.surface_get_arrays(0))
	var rim := StandardMaterial3D.new()
	rim.albedo_color = Color(0.33, 0.32, 0.31)
	rim.metallic = 0.8
	rim.roughness = 0.45
	rim.rim_enabled = true
	rim.rim = 0.35
	rim.rim_tint = 0.3
	mesh.surface_set_material(1, rim)
	# 가운데 쇠 돌기(팔이 지나는 자리 앞)
	var boss := CreatureMesh.loft([
		[Vector3(0, 0, -th - 0.002), 0.07, 0.07], [Vector3(0, 0, -th - 0.025), 0.05, 0.05], [Vector3(0, 0, -th - 0.04), 0.02, 0.02],
	], 10, 0.0)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, boss.surface_get_arrays(0))
	mesh.surface_set_material(2, rim)
	_cache["shield"] = mesh
	return mesh


## 굽은 활(높이 1.36m). 원점 = 쥔 곳, 두 끝은 BOW_TIP과 그 위아래 뒤집은 자리, 시위는 +Z, 쏘는 쪽 -Z.
## 겹: 0 = 활대(어두운 나무), 1 = 쥔 곳의 가죽, 2 = 시위(with_string일 때만, 곧게 쉬는 시위).
static func bow_mesh(with_string: bool = true) -> ArrayMesh:
	var key: String = "bow_s" if with_string else "bow"
	if _cache.has(key):
		return _cache[key]
	var limb := CreatureMesh.loft([
		[Vector3(0, 0.06, 0.0), 0.02, 0.02], [Vector3(0, 0.12, 0.01), 0.019, 0.014], [Vector3(0, 0.3, 0.085), 0.017, 0.012],
		[Vector3(0, 0.47, 0.165), 0.014, 0.01], [Vector3(0, 0.58, 0.195), 0.011, 0.009], [Vector3(0, 0.645, 0.17), 0.009, 0.008],
		[Vector3(0, BOW_TIP.y, BOW_TIP.z), 0.007, 0.006],
	], 8, 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(limb, 0, Transform3D.IDENTITY)
	# 아래 활대: 위 활대를 Z축으로 반 바퀴(시위 쪽은 그대로 +Z)
	st.append_from(limb, 0, Transform3D(Basis(Vector3(0, 0, 1), PI), Vector3.ZERO))
	var mesh := st.commit()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.22, 0.15, 0.1)
	wood.vertex_color_use_as_albedo = false
	wood.roughness = 0.55
	mesh.surface_set_material(0, wood)
	var grip := CreatureMesh.loft([
		[Vector3(0, -0.1, 0.0), 0.017, 0.017], [Vector3(0, -0.07, 0.0), 0.024, 0.027], [Vector3(0, 0.0, -0.004), 0.026, 0.031],
		[Vector3(0, 0.07, 0.0), 0.024, 0.027], [Vector3(0, 0.1, 0.0), 0.017, 0.017],
	], 8, 0.0)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, grip.surface_get_arrays(0))
	var wrap := StandardMaterial3D.new()
	wrap.albedo_color = Color(0.11, 0.075, 0.055)
	wrap.roughness = 0.85
	mesh.surface_set_material(1, wrap)
	if with_string:
		var cs := SurfaceTool.new()
		cs.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tube(cs, Vector3(0, -BOW_TIP.y, BOW_TIP.z), BOW_TIP, 0.004, 0.004, 4, Color(0.62, 0.58, 0.5))
		cs.commit(mesh)
		var sm := StandardMaterial3D.new()
		sm.vertex_color_use_as_albedo = true
		sm.roughness = 0.8
		mesh.surface_set_material(2, sm)
	_cache[key] = mesh
	return mesh


## 옹이 진 지팡이(2.2m). 원점 = 아래 끝, +Y로 서고 꼭대기에서 -Z로 갈고리처럼 굽는다(STAFF_HOOK에 등불을 단다, STAFF_GRIP을 쥔다).
static func staff_mesh() -> ArrayMesh:
	if _cache.has("staff"):
		return _cache["staff"]
	var mesh := CreatureMesh.loft([
		[Vector3(0, 0.0, 0), 0.016, 0.016], [Vector3(0, 0.02, 0), 0.021, 0.021], [Vector3(0.005, 0.5, 0.004), 0.024, 0.024],
		[Vector3(-0.006, 0.95, -0.003), 0.026, 0.026], [Vector3(-0.004, 1.02, -0.002), 0.034, 0.032], [Vector3(0.0, 1.08, 0.0), 0.027, 0.027],
		[Vector3(0.006, 1.55, 0.005), 0.028, 0.028], [Vector3(0.004, 1.84, 0.0), 0.03, 0.03], [Vector3(0.0, 1.9, 0.0), 0.037, 0.035],
		[Vector3(0, 2.0, 0.005), 0.03, 0.03], [Vector3(0, 2.1, -0.02), 0.027, 0.027], [Vector3(0, 2.16, -0.08), 0.025, 0.025],
		[Vector3(0, 2.16, -0.16), 0.023, 0.023], [Vector3(0, 2.11, -0.225), 0.02, 0.02], [Vector3(0, 2.05, -0.245), 0.018, 0.018],
		[Vector3(0, 2.03, -0.245), 0.01, 0.01],
	], 8, 0.0)
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = _noise_tex("bark", 0.12, Color(0.26, 0.2, 0.15), Color(0.08, 0.06, 0.05))
	wood.uv1_scale = Vector3(2, 12, 1)
	wood.roughness = 0.9
	mesh.surface_set_material(0, wood)
	_cache["staff"] = mesh
	return mesh


# ---------------------------------------------------------------- 공통 부품

static func _begin(kind: StringName, parent: Node3D, s: float) -> Dictionary:
	var root := Node3D.new()
	root.name = String(kind).capitalize()
	root.scale = Vector3.ONE * s
	parent.add_child(root)
	var mats: Array[StandardMaterial3D] = []
	var cloaks: Array[ShaderMaterial] = []
	var glow: Array[StandardMaterial3D] = []
	var eyes: Array[MeshInstance3D] = []
	return {"kind": kind, "root": root, "scale": s, "height": 2.0 * s, "eyes": eyes, "mats": mats, "cloaks": cloaks, "glow": glow}


## 어깨·팔꿈치·손목 피벗을 좌우로 짓는다. at은 오른쪽 어깨(왼쪽은 x를 뒤집는다). [어깨들, 팔꿈치들, 손들]을 돌려주고 P에도 넣는다.
static func _arms(P: Dictionary, torso: Node3D, at: Vector3, upper: float, lower: float, sleeve: Material, glove: Material, r: float) -> Array:
	var shoulders: Array[Node3D] = []
	var elbows: Array[Node3D] = []
	var hands: Array[Node3D] = []
	for i in 2:
		var side: float = -1.0 if i == 0 else 1.0
		var sh := _pivot(torso, Vector3(at.x * side, at.y, at.z), "Shoulder")
		_add(sh, CreatureMesh.loft([
			[Vector3(0, r * 0.7, 0), r, r], [Vector3(0, -upper * 0.5, 0), r * 0.92, r * 0.92], [Vector3(0, -upper, 0), r * 0.72, r * 0.72],
		], 10, 0.0), sleeve)
		var el := _pivot(sh, Vector3(0, -upper, 0), "Elbow")
		_add(el, CreatureMesh.loft([
			[Vector3(0, r * 0.3, 0), r * 0.72, r * 0.72], [Vector3(0, -lower * 0.5, 0), r * 0.66, r * 0.66], [Vector3(0, -lower, 0), r * 0.55, r * 0.5],
		], 10, 0.0), glove)
		var hand := _pivot(el, Vector3(0, -lower, 0), "Hand")
		_add(hand, CreatureMesh.loft([
			[Vector3(0, r * 0.2, 0), r * 0.5, r * 0.42], [Vector3(0, -r * 0.8, -r * 0.15), r * 0.58, r * 0.36], [Vector3(0, -r * 1.5, -r * 0.2), r * 0.36, r * 0.25],
		], 8, 0.0), glove)
		shoulders.append(sh)
		elbows.append(el)
		hands.append(hand)
	P.arms = shoulders
	P.forearms = elbows
	P.hands = hands
	return [shoulders, elbows, hands]


## 단면 사이에 Catmull-Rom으로 steps개씩 단면을 끼워 넣어 큰 몸의 굴곡을 매끈하게 한다(CreatureMesh.loft에 넘긴다).
static func _smooth(sections: Array, steps: int = 2) -> Array:
	var out: Array = []
	var n: int = sections.size()
	for i in n - 1:
		var p0: Array = sections[maxi(i - 1, 0)]
		var p1: Array = sections[i]
		var p2: Array = sections[i + 1]
		var p3: Array = sections[mini(i + 2, n - 1)]
		out.append(p1)
		for k in range(1, steps + 1):
			var t: float = float(k) / float(steps + 1)
			out.append([
				(p1[0] as Vector3).cubic_interpolate(p2[0], p0[0], p3[0], t),
				maxf(0.001, cubic_interpolate(p1[1], p2[1], p0[1], p3[1], t)),
				maxf(0.001, cubic_interpolate(p1[2], p2[2], p0[2], p3[2], t)),
			])
	out.append(sections[n - 1])
	return out


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


## 칠할 수 있는 보통 재질(mats에 넣는다). 밤에 윤곽이 보이게 가장자리를 조금 밝힌다.
static func _std(P: Dictionary, c: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.5
	(P.mats as Array).append(m)
	return m


static func _fur(P: Dictionary, c: Color, dark: Color, uv: Vector3) -> StandardMaterial3D:
	var m := CreatureMesh.fur(c, dark)
	m.uv1_scale = uv
	(P.mats as Array).append(m)
	return m


## 소품 메시의 겹 재질을 이 몸만의 것으로 복사해 mats에 넣는다(맞을 때 같이 번쩍인다).
static func _own_materials(P: Dictionary, mi: MeshInstance3D) -> void:
	for i in mi.mesh.get_surface_count():
		var src := mi.mesh.surface_get_material(i) as StandardMaterial3D
		if src == null:
			continue
		var m := src.duplicate() as StandardMaterial3D
		mi.set_surface_override_material(i, m)
		(P.mats as Array).append(m)


static func _cloak(P: Dictionary, cloth: Color, rim: Color, rim_energy: float, tear: float, flutter: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CLOAK_SHADER
	m.set_shader_parameter("tatter", _tatter())
	m.set_shader_parameter("cloth", cloth)
	m.set_shader_parameter("rim", rim)
	m.set_shader_parameter("rim_energy", rim_energy)
	m.set_shader_parameter("tear", tear)
	m.set_shader_parameter("flutter", flutter)
	m.set_shader_parameter("phase", float((P.root as Node3D).get_instance_id() % 17) * 0.37)
	m.set_shader_parameter("fade", 1.0)
	(P.cloaks as Array).append(m)
	return m


## 두건 안의 어둠(빛을 받지 않는 검은 타원).
static func _void(parent: Node3D, at: Vector3, r: float, h: float) -> void:
	var face := SphereMesh.new()
	face.radius = r
	face.height = h
	face.radial_segments = 12
	face.rings = 6
	if not _cache.has("void"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color.BLACK
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_cache["void"] = m
	_add(parent, face, _cache["void"], at).name = "Void"


## 스스로 빛나는 눈 한 쌍(EnemyView._eyes_at과 같은 모양과 재질).
static func _eyes(P: Dictionary, parent: Node3D, at: Vector3, gap: float, size: float, c: Color) -> void:
	var s := SphereMesh.new()
	s.radius = size
	s.height = size * 1.4
	s.radial_segments = 8
	s.rings = 4
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 4.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 2:
		var side: float = -1.0 if i == 0 else 1.0
		var e := _add(parent, s, m, at + Vector3(gap * side, 0, 0))
		e.name = "Eye%d" % i
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(P.eyes as Array).append(e)


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 10
	c.rings = 4
	return c


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


## node의 회전·크기를 top 기준으로(top 자신은 빼고) 모은다. 손에 쥔 것을 몸 기준으로 곧게 세울 때 쓴다.
static func _basis_to(node: Node3D, top: Node3D) -> Basis:
	var b := Basis.IDENTITY
	var n: Node = node
	while n != null and n != top and n is Node3D:
		b = (n as Node3D).basis * b
		n = n.get_parent()
	return b


## 높이 1의 원기둥(CylinderMesh)을 a에서 b까지 잇는다.
static func _span(mi: Node3D, a: Vector3, b: Vector3) -> void:
	var y: Vector3 = b - a
	var l: float = maxf(y.length(), 0.0001)
	var dir: Vector3 = y / l
	var x: Vector3 = dir.cross(Vector3.BACK if absf(dir.z) < 0.9 else Vector3.RIGHT).normalized()
	var z: Vector3 = x.cross(dir).normalized()
	mi.transform = Transform3D(Basis(x, dir * l, z), (a + b) * 0.5)


## 정점 색을 단 관(뚜껑 없음). 메시 소품용.
static func _tube(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, sides: int, c: Color) -> void:
	var d: Vector3 = (b - a).normalized()
	var u: Vector3 = d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	var v: Vector3 = d.cross(u)
	for k in sides:
		var a0: float = TAU * k / sides
		var a1: float = TAU * (k + 1) / sides
		var n0: Vector3 = u * cos(a0) + v * sin(a0)
		var n1: Vector3 = u * cos(a1) + v * sin(a1)
		var p: Array[Vector3] = [a + n0 * ra, b + n0 * rb, b + n1 * rb, a + n1 * ra]
		var nn: Array[Vector3] = [n0, n0, n1, n1]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_color(c)
			st.set_normal(nn[idx])
			st.set_uv(Vector2(float(k) / sides, 0.0))
			st.add_vertex(p[idx])


## 정점 색을 단 납작한 사각형(앞뒤 같은 법선, 재질은 양면).
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	var n: Vector3 = (b - a).cross(c - a).normalized()
	for p in [a, b, c, a, c, d]:
		st.set_color(col)
		st.set_normal(n)
		st.set_uv(Vector2.ZERO)
		st.add_vertex(p)


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


static func _noise_tex(key: String, freq: float, light: Color, dark: Color) -> NoiseTexture2D:
	if _cache.has(key):
		return _cache[key]
	var nz := FastNoiseLite.new()
	nz.frequency = freq
	nz.fractal_octaves = 4
	var g := Gradient.new()
	g.colors = PackedColorArray([dark, light])
	var t := NoiseTexture2D.new()
	t.noise = nz
	t.color_ramp = g
	t.seamless = true
	t.width = 128
	t.height = 128
	_cache[key] = t
	return t


## 방패 앞면의 칠: 낡은 가죽 바탕에 바랜 검붉은 세로 띠, 칠이 벗겨진 자국. UV.x가 가로(0.5 = 가운데).
static func _shield_paint() -> ImageTexture:
	if _cache.has("shield_paint"):
		return _cache["shield_paint"]
	var w: int = 64
	var h: int = 128
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var nz := FastNoiseLite.new()
	nz.seed = 11
	nz.frequency = 0.09
	nz.fractal_octaves = 4
	var fine := FastNoiseLite.new()
	fine.seed = 5
	fine.frequency = 0.35
	for y in h:
		for x in w:
			var u: float = (float(x) + 0.5) / w
			var n: float = clampf(nz.get_noise_2d(x, y * 0.6) * 0.6 + 0.5, 0.0, 1.0)
			var g: float = fine.get_noise_2d(x, y) * 0.04
			var c: Color = Color(0.31, 0.26, 0.21).lerp(Color(0.13, 0.105, 0.085), n)
			if absf(u - 0.5) < 0.085:
				# 띠의 칠은 밝은 얼룩에서 벗겨져 바탕이 보인다
				c = Color(0.3, 0.075, 0.05).lerp(c, smoothstep(0.62, 0.8, 1.0 - n) * 0.85)
			img.set_pixel(x, y, Color(c.r + g, c.g + g, c.b + g))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache["shield_paint"] = t
	return t


## 갈라진 틈(세포 잡음의 경계): 틈이 흰빛, 나머지는 검다. 배의 emission_texture.
static func _cracks() -> NoiseTexture2D:
	if _cache.has("cracks"):
		return _cache["cracks"]
	var nz := FastNoiseLite.new()
	nz.noise_type = FastNoiseLite.TYPE_CELLULAR
	nz.frequency = 0.03
	nz.fractal_type = FastNoiseLite.FRACTAL_NONE
	nz.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	nz.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	nz.domain_warp_enabled = true
	nz.domain_warp_amplitude = 14.0
	nz.domain_warp_frequency = 0.03
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.05, 0.14])
	g.colors = PackedColorArray([Color(1, 1, 1), Color(0.5, 0.5, 0.5), Color(0, 0, 0)])
	var t := NoiseTexture2D.new()
	t.noise = nz
	t.color_ramp = g
	t.normalize = true
	t.seamless = true
	t.width = 256
	t.height = 256
	_cache["cracks"] = t
	return t
