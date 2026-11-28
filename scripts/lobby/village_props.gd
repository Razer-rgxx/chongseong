class_name VillageProps
extends RefCounted
## 마을의 새 들를 곳과 주민의 모양(15단계, docs/village.md). 기본 도형, 규칙 없음. VillageBuilder·EventArt의 도구를 쓴다.
## 앞은 +Z(VillageBuilder.place와 같다). 주민의 몸은 EventArt처럼 -Z를 본다(lobby가 PI를 더해 돌린다).

## 주민 한 사람의 옷과 소품: [옷 색, 두건/머리 색, 소품].
const LOOKS: Dictionary = {
	&"gatekeeper": [Color(0.16, 0.17, 0.2), Color(0.3, 0.3, 0.33), "spear"],
	&"elder": [Color(0.26, 0.22, 0.17), Color(0.62, 0.6, 0.56), "staff"],
	&"drunk": [Color(0.3, 0.14, 0.1), Color(0.34, 0.26, 0.2), "jug"],
	&"herbalist": [Color(0.12, 0.2, 0.13), Color(0.2, 0.24, 0.14), "basket"],
	&"apprentice": [Color(0.22, 0.18, 0.15), Color(0.16, 0.11, 0.08), "apron"],
	&"merchant": [Color(0.2, 0.1, 0.22), Color(0.28, 0.12, 0.3), "pack"],
	# 34단계 떠도는 사람(FieldLayout.WANDERERS): 같은 몸, 옷 색과 소품만 다르다. 들판에 서고, 영입하면 마을에 선다.
	&"gatherer": [Color(0.17, 0.19, 0.11), Color(0.32, 0.27, 0.18), "basket"],
	&"smith": [Color(0.19, 0.13, 0.09), Color(0.1, 0.08, 0.06), "apron"],
	&"hunter": [Color(0.25, 0.2, 0.13), Color(0.5, 0.48, 0.45), "spear"],
	&"pilgrim": [Color(0.4, 0.36, 0.3), Color(0.36, 0.32, 0.26), "staff"],
	&"knight": [Color(0.13, 0.14, 0.17), Color(0.2, 0.18, 0.17), "blade"],
	# 마을 키우기 3단계 주민(들판에서 풀어 준 사람): 바랜 삼베·무명 빛, 소품은 돌려 가며
	&"peasant": [Color(0.33, 0.28, 0.21), Color(0.24, 0.19, 0.14), "basket"],
	&"peasant2": [Color(0.24, 0.22, 0.2), Color(0.42, 0.38, 0.32), "apron"],
	&"peasant3": [Color(0.29, 0.21, 0.16), Color(0.18, 0.14, 0.11), "pack"],
	&"peasant4": [Color(0.2, 0.23, 0.22), Color(0.3, 0.26, 0.2), ""],
}


## 의뢰판: 기둥 둘, 널빤지, 붙은 종이 카드들.
static func board(parent: Node3D, at: Vector3, facing: float, rng: RandomNumberGenerator) -> void:
	var b := VillageBuilder.place(parent, at, facing)
	if VillageModels.available("board"):
		VillageBuilder._burn(rng, 20)
		VillageModels.put(b, "board", Vector3.ZERO)
		return
	for x in [-1.3, 1.3]:
		VillageBuilder.box(b, Vector3(0.18, 2.5, 0.18), Vector3(x, 1.25, 0), VillageBuilder.timber())
	VillageBuilder.box(b, Vector3(2.9, 1.5, 0.1), Vector3(0, 1.55, 0.05), VillageBuilder.planks())
	VillageBuilder.box(b, Vector3(3.2, 0.1, 0.5), Vector3(0, 2.55, 0.1), VillageBuilder.roof(), Vector3(0.25, 0, 0))
	var paper := VillageBuilder.plain(Color(0.62, 0.55, 0.4), 1.0)
	for i in 5:
		var s := Vector3(rng.randf_range(0.4, 0.6), rng.randf_range(0.5, 0.7), 0.01)
		var p := Vector3(-1.05 + i * 0.52, 1.55 + rng.randf_range(-0.2, 0.2), 0.13)
		VillageBuilder.box(b, s, p, paper, Vector3(0, 0, rng.randf_range(-0.12, 0.12)))
	VillageBuilder.box(b, Vector3(0.1, 0.1, 0.05), Vector3(0, 1.9, 0.14), VillageBuilder.plain(Color(0.15, 0.15, 0.16), 0.5, 0.7))


## 수련장: 울타리(칸 rect 둘레, 서쪽 gap에 틈), 허수아비 pivots(쓰러지지 않고 맞으면 흔들린다), 검 걸이.
## 돌려주는 값: 허수아비 피벗 배열(각 피벗의 meta "base"는 땅 위치).
static func yard(parent: Node3D, area: Rect2, gap: Vector2, dummies: Array[Vector2], rack_at: Vector2, rng: RandomNumberGenerator) -> Array[Node3D]:
	var wood := VillageBuilder.timber()
	var corners := [area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]
	var modelled: bool = VillageModels.available("fence_unit")
	for i in 4:
		var a: Vector2 = corners[i]
		var c: Vector2 = corners[(i + 1) % 4]
		var len: float = a.distance_to(c)
		var n: int = int(len / 0.6)
		if modelled:
			_fence_side(parent, a, c, n, i == 3, gap)
			continue
		for k in n + 1:
			var p: Vector2 = a.lerp(c, float(k) / float(n))
			# 서쪽(마당 들머리)의 틈
			if i == 3 and p.y > gap.x and p.y < gap.y:
				continue
			VillageBuilder.box(parent, Vector3(0.12, 1.0, 0.12), Grid.cells_to_world(p) + Vector3(0, 0.5, 0), wood)   # 1m: 점프로 넘는다(30단계)
		for h in [0.4, 0.82]:
			var from := Grid.cells_to_world(a)
			var to := Grid.cells_to_world(c)
			var mid := (from + to) / 2.0
			var rail := VillageBuilder.box(parent, Vector3(0.07, 0.07, from.distance_to(to)), mid + Vector3(0, h, 0), wood)
			rail.look_at_from_position(mid + Vector3(0, h, 0), to + Vector3(0, h, 0), Vector3.UP)
	# 허수아비: 말뚝, 가로대, 짚 몸통, 자루 머리
	var straw := VillageBuilder.plain(Color(0.62, 0.5, 0.28), 1.0)
	var sack := VillageBuilder.plain(Color(0.45, 0.38, 0.27), 1.0)
	var out: Array[Node3D] = []
	for d in dummies:
		var piv := Node3D.new()
		piv.position = Grid.cells_to_world(d)
		piv.set_meta("base", piv.position)
		parent.add_child(piv)
		if VillageModels.available("scarecrow"):
			VillageModels.put(piv, "scarecrow", Vector3.ZERO)
			out.append(piv)
			continue
		VillageBuilder.box(piv, Vector3(0.12, 1.7, 0.12), Vector3(0, 0.85, 0), wood)
		VillageBuilder.box(piv, Vector3(1.1, 0.1, 0.1), Vector3(0, 1.25, 0), wood)
		VillageBuilder.cyl(piv, 0.25, 0.32, 0.8, Vector3(0, 1.0, 0.0), straw, 8)
		VillageBuilder.ball(piv, 0.2, Vector3(0, 1.7, 0), sack)
		for s in [-1.0, 1.0]:
			VillageBuilder.cyl(piv, 0.05, 0.08, 0.3, Vector3(s * 0.6, 1.2, 0), straw, 6).rotation.z = PI / 2.0
		out.append(piv)
	# 검 걸이: 두 기둥 사이 가로대에 칼 몇 자루
	var r := VillageBuilder.place(parent, Grid.cells_to_world(rack_at), 0.0)
	if VillageModels.available("sword_rack"):
		VillageBuilder._burn(rng, 4)
		VillageModels.put(r, "sword_rack", Vector3.ZERO)
		return out
	for x in [-0.9, 0.9]:
		VillageBuilder.box(r, Vector3(0.12, 1.5, 0.12), Vector3(x, 0.75, 0), wood)
	VillageBuilder.box(r, Vector3(2.0, 0.08, 0.1), Vector3(0, 1.3, 0), wood)
	VillageBuilder.box(r, Vector3(2.0, 0.08, 0.1), Vector3(0, 0.8, 0), wood)
	var steel := VillageBuilder.plain(Color(0.55, 0.57, 0.6), 0.45, 0.8)
	for i in 4:
		VillageBuilder.box(r, Vector3(0.07, 1.0, 0.03), Vector3(-0.6 + i * 0.4, 1.0, 0.07), steel, Vector3(0, 0, rng.randf_range(-0.08, 0.08)))
	return out


## 수련장 울타리 한 변(모델판): 칸 a→c, 말뚝 n+1개, 틈(gap은 y 범위, 서쪽 변만)에는 말뚝도 가로대도 없다.
static func _fence_side(parent: Node3D, a: Vector2, c: Vector2, n: int, west: bool, gap: Vector2) -> void:
	var wa: Vector3 = Grid.cells_to_world(a)
	var wc: Vector3 = Grid.cells_to_world(c)
	var dir: Vector3 = (wc - wa).normalized()
	var yaw: float = atan2(dir.x, dir.z)
	var step: float = wa.distance_to(wc) / float(n)
	var in_gap := func(k: int) -> bool:
		var p: Vector2 = a.lerp(c, float(k) / float(n))
		return west and p.y > gap.x and p.y < gap.y
	for k in n + 1:
		if in_gap.call(k):
			continue
		var at: Vector3 = wa.lerp(wc, float(k) / float(n))
		if k == n or in_gap.call(k + 1):
			VillageModels.put(parent, "fence_end", at, yaw + float(k) * 1.7)
		else:
			var u := VillageModels.put(parent, "fence_unit", at, yaw)
			u.scale = Vector3(1, 1, step / 0.6)


## 결투 말뚝(21단계): 밟아 다진 둥근 마당, 굵은 말뚝에 엇갈려 꽂힌 칼 둘, 양쪽에 걸린 천(1P 금빛, 2P 검붉음). 기본 도형.
static func duel_post(parent: Node3D, at: Vector3) -> void:
	var d := VillageBuilder.place(parent, at, 0.0)
	if VillageModels.available("duel_post"):
		VillageModels.put(d, "duel_post", Vector3.ZERO)
		return
	VillageBuilder.cyl(d, 2.0, 2.1, 0.05, Vector3(0, 0.025, 0), VillageBuilder.dirt(), 24)
	var stone := VillageBuilder.plain(Color(0.36, 0.35, 0.34), 0.95)
	for i in 10:
		var a: float = TAU * i / 10.0
		VillageBuilder.box(d, Vector3(0.34, 0.2, 0.26), Vector3(cos(a) * 1.95, 0.1, sin(a) * 1.95), stone, Vector3(0, -a, 0))
	var wood := VillageBuilder.timber()
	VillageBuilder.box(d, Vector3(0.3, 2.5, 0.3), Vector3(0, 1.25, 0), wood)
	VillageBuilder.box(d, Vector3(1.5, 0.12, 0.14), Vector3(0, 2.1, 0), wood)
	var steel := VillageBuilder.plain(Color(0.62, 0.64, 0.68), 0.4, 0.85)
	for k in [-1.0, 1.0]:
		VillageBuilder.box(d, Vector3(0.09, 1.5, 0.03), Vector3(0, 1.55, 0.18), steel, Vector3(0, 0, k * 0.7))
	VillageBuilder.box(d, Vector3(0.3, 0.1, 0.12), Vector3(0, 1.55, 0.18), VillageBuilder.plain(Color(0.2, 0.17, 0.14), 0.6, 0.5))
	for pair in [[-0.6, Color(0.66, 0.54, 0.2)], [0.6, Color(0.46, 0.12, 0.14)]]:
		VillageBuilder.box(d, Vector3(0.36, 0.7, 0.03), Vector3(pair[0], 1.7, 0.02), VillageBuilder.plain(pair[1], 1.0))


## 거울(영주 꾸미기, docs/cosmetics.md): 나무 틀에 선 키 큰 거울, 옆 걸대에 걸린 망토와 쇠모자. 기본 도형. 앞이 +Z.
static func mirror(parent: Node3D, at: Vector3, facing: float) -> void:
	var m := VillageBuilder.place(parent, at, facing)
	if VillageModels.available("mirror"):
		VillageModels.put(m, "mirror", Vector3.ZERO)
		return
	var wood := VillageBuilder.timber()
	VillageBuilder.cyl(m, 0.8, 0.85, 0.06, Vector3(0, 0.03, 0), VillageBuilder.dirt(), 18)
	for k in [-1.0, 1.0]:
		VillageBuilder.box(m, Vector3(0.1, 2.3, 0.12), Vector3(k * 0.58, 1.18, 0), wood)
		VillageBuilder.box(m, Vector3(0.12, 0.08, 0.7), Vector3(k * 0.58, 0.04, -0.1), wood)
	VillageBuilder.box(m, Vector3(1.26, 0.12, 0.12), Vector3(0, 2.3, 0), wood)
	VillageBuilder.box(m, Vector3(1.26, 0.1, 0.12), Vector3(0, 0.18, 0), wood)
	var glass := VillageBuilder.plain(Color(0.25, 0.29, 0.33), 0.5, 0.1)   # 거울면: 흐린 쇳빛(반사는 없다)
	VillageBuilder.box(m, Vector3(1.06, 2.0, 0.03), Vector3(0, 1.24, 0.02), glass)
	var brass := VillageBuilder.plain(Color(0.5, 0.4, 0.22), 0.5, 0.6)
	VillageBuilder.box(m, Vector3(0.3, 0.1, 0.14), Vector3(0, 2.4, 0), brass)
	# 옆 걸대: 기둥, 가로대에 걸린 망토, 꼭대기에 올린 쇠모자
	VillageBuilder.box(m, Vector3(0.09, 1.9, 0.09), Vector3(1.25, 0.95, 0.1), wood)
	VillageBuilder.box(m, Vector3(0.7, 0.07, 0.07), Vector3(1.25, 1.75, 0.1), wood)
	VillageBuilder.box(m, Vector3(0.5, 0.95, 0.04), Vector3(1.25, 1.25, 0.16), VillageBuilder.plain(Color(0.34, 0.1, 0.13), 1.0), Vector3(0.06, 0, 0.03))
	VillageBuilder.cyl(m, 0.12, 0.17, 0.22, Vector3(1.25, 2.0, 0.1), VillageBuilder.plain(Color(0.4, 0.4, 0.43), 0.45, 0.8), 12)


## 떠돌이 상인의 짐수레: 짐칸, 바퀴 둘, 천 덮개, 자루와 통, 끌채.
static func cart(parent: Node3D, at: Vector3, facing: float) -> void:
	var c := VillageBuilder.place(parent, at, facing)
	if VillageModels.available("cart"):
		VillageModels.put(c, "cart", Vector3.ZERO, 0.0, 1.0, {"cloth": Color(0.3, 0.14, 0.32)})
		return
	VillageBuilder.box(c, Vector3(2.2, 0.15, 1.3), Vector3(0, 0.75, 0), VillageBuilder.planks())
	VillageBuilder.box(c, Vector3(2.2, 0.45, 0.08), Vector3(0, 1.0, 0.62), VillageBuilder.planks())
	VillageBuilder.box(c, Vector3(2.2, 0.45, 0.08), Vector3(0, 1.0, -0.62), VillageBuilder.planks())
	for z in [-0.72, 0.72]:
		var w := VillageBuilder.cyl(c, 0.5, 0.5, 0.08, Vector3(0.1, 0.5, z), VillageBuilder.timber(), 14)
		w.rotation.x = PI / 2.0
	for z in [-0.4, 0.4]:
		VillageBuilder.box(c, Vector3(1.9, 0.07, 0.07), Vector3(-2.0, 0.55, z), VillageBuilder.timber(), Vector3(0, 0, 0.08))
	VillageBuilder.box(c, Vector3(1.7, 0.05, 1.5), Vector3(0.1, 1.95, 0), VillageBuilder.plain(Color(0.22, 0.1, 0.24), 0.95), Vector3(0, 0, 0.0))
	for x in [-0.8, 0.9]:
		for z in [-0.6, 0.6]:
			VillageBuilder.box(c, Vector3(0.07, 1.2, 0.07), Vector3(x, 1.35, z), VillageBuilder.timber())
	var sack := VillageBuilder.plain(Color(0.4, 0.34, 0.25), 1.0)
	for i in 3:
		VillageBuilder.cyl(c, 0.14, 0.24, 0.5, Vector3(-0.6 + i * 0.5, 1.07, 0.1 * (i - 1)), sack, 8)
	VillageBuilder.cyl(c, 0.22, 0.24, 0.45, Vector3(0.75, 1.05, -0.2), VillageBuilder.planks(), 10)


## 주민 한 사람(EventArt처럼 몸 부위 사전을 돌려준다: root, torso, head, rest, phase …). 발밑이 원점, -Z를 본다.
static func villager(kind: StringName, parent: Node3D) -> Dictionary:
	var look: Array = LOOKS.get(kind, LOOKS[&"elder"])
	var P := EventArt._begin(kind, parent)
	P.phase = float(LOOKS.keys().find(kind)) * 1.7 + 0.3
	if NpcModel.available():
		return _modelled(P, kind, look)
	var root: Node3D = P.root
	P.height = 1.75
	P.radius = 0.9
	var cloth := EventArt._mat(P, look[0], 0.95)
	var hood := EventArt._mat(P, look[1], 0.95)
	var skin := EventArt._mat(P, Color(0.5, 0.38, 0.3), 0.8)
	var torso := EventArt._pivot(root, Vector3(0, 0.95, 0), "Torso")
	P.torso = torso
	EventArt._add(torso, CreatureMesh.lathe([
		[-0.95, 0.3, 0.26, 0.0], [-0.55, 0.26, 0.22, 0.0], [-0.1, 0.22, 0.17, 0.0], [0.3, 0.24, 0.16, 0.0], [0.5, 0.2, 0.14, 0.0], [0.58, 0.1, 0.09, 0.0],
	], 16), cloth)
	var head := EventArt._pivot(torso, Vector3(0, 0.68, 0.0), "Head")
	P.head = head
	EventArt._add(head, CreatureMesh.lathe([
		[-0.1, 0.07, 0.07, 0.0], [0.0, 0.11, 0.1, 0.0], [0.12, 0.12, 0.11, 0.0], [0.22, 0.09, 0.09, 0.0], [0.27, 0.03, 0.03, 0.0],
	], 14), skin)
	# 두건 또는 머리카락(뒤통수와 정수리만)
	var cap := EventArt._add(head, CreatureMesh.lathe([
		[0.0, 0.125, 0.115, 0.02], [0.12, 0.135, 0.125, 0.02], [0.22, 0.1, 0.1, 0.01], [0.28, 0.03, 0.03, 0.0],
	], 14), hood)
	cap.position = Vector3(0, 0.0, 0.01)
	var arms := EventArt._arms(P, torso, Vector3(0.24, 0.45, 0.0), 0.28, 0.26, cloth, skin, 0.06)
	var sh: Array[Node3D] = arms[0]
	var el: Array[Node3D] = arms[1]
	sh[0].rotation = Vector3(0.1, 0.0, -0.12)
	sh[1].rotation = Vector3(0.1, 0.0, 0.12)
	el[0].rotation = Vector3(0.35, 0.0, 0.0)
	el[1].rotation = Vector3(0.35, 0.0, 0.0)
	var wood := VillageBuilder.timber()
	match String(look[2]):
		"spear":
			sh[1].rotation = Vector3(0.0, 0.0, 0.08)
			EventArt._add(arms[2][1], EventArt._box_mesh(Vector3(0.04, 2.1, 0.04)), wood, Vector3(0, 0.0, -0.05))
			EventArt._add(arms[2][1], EventArt._box_mesh(Vector3(0.07, 0.25, 0.02)), VillageBuilder.plain(Color(0.6, 0.62, 0.66), 0.4, 0.8), Vector3(0, 1.1, -0.05))
		"staff":
			EventArt._add(arms[2][1], EventArt._box_mesh(Vector3(0.05, 1.6, 0.05)), wood, Vector3(0, 0.1, -0.05))
			torso.rotation.x = -0.12
		"jug":
			el[1].rotation = Vector3(1.4, 0.0, 0.0)
			EventArt._add(arms[2][1], EventArt._cyl(0.07, 0.09, 0.2, 8), VillageBuilder.plain(Color(0.32, 0.22, 0.14), 0.7), Vector3(0, -0.1, -0.05))
			torso.rotation.z = 0.08
		"basket":
			EventArt._add(torso, EventArt._cyl(0.2, 0.15, 0.22, 10), VillageBuilder.plain(Color(0.42, 0.32, 0.18), 1.0), Vector3(0.0, -0.4, 0.3))
		"apron":
			EventArt._add(torso, EventArt._box_mesh(Vector3(0.34, 0.75, 0.04)), VillageBuilder.plain(Color(0.14, 0.1, 0.07), 0.9), Vector3(0, -0.45, 0.2))
		"pack":
			EventArt._add(torso, EventArt._box_mesh(Vector3(0.4, 0.5, 0.25)), VillageBuilder.plain(Color(0.36, 0.28, 0.2), 1.0), Vector3(0, 0.1, -0.27))
		"blade":
			# 몰락한 기사: 앞에 바랜 붉은 겉옷 자락, 허리에 찬 칼집과 쇠 칼자루, 등에 해진 망토
			var red := VillageBuilder.plain(Color(0.21, 0.05, 0.045), 1.0)
			EventArt._add(torso, EventArt._box_mesh(Vector3(0.24, 1.1, 0.03)), red, Vector3(0, -0.3, -0.23)).rotation = Vector3(0.08, 0.0, 0.0)
			EventArt._add(torso, EventArt._box_mesh(Vector3(0.5, 0.95, 0.04)), red, Vector3(0, -0.1, 0.24)).rotation = Vector3(-0.12, 0.0, 0.0)
			var leather := VillageBuilder.plain(Color(0.24, 0.16, 0.1), 0.8)
			var steel := VillageBuilder.plain(Color(0.58, 0.58, 0.6), 0.45, 0.8)
			EventArt._add(torso, EventArt._box_mesh(Vector3(0.06, 0.95, 0.05)), leather, Vector3(0.31, -0.72, 0.0)).rotation = Vector3(0.0, 0.0, 0.2)
			EventArt._add(torso, EventArt._box_mesh(Vector3(0.04, 0.24, 0.04)), steel, Vector3(0.22, -0.15, 0.0)).rotation = Vector3(0.0, 0.0, 0.2)
			EventArt._add(torso, EventArt._box_mesh(Vector3(0.2, 0.035, 0.05)), steel, Vector3(0.245, -0.27, 0.0)).rotation = Vector3(0.0, 0.0, 0.2)
	EventArt._rest(P)
	return P


## 여자 모델로 서는 사람.
const GIRLS: Array[StringName] = [&"herbalist", &"merchant", &"gatherer", &"peasant2", &"peasant4"]


## Mixamo 농부 모델로 선 사람(NpcModel). 몸 부위 대신 P.npc가 있다.
static func _modelled(P: Dictionary, kind: StringName, look: Array) -> Dictionary:
	var m := NpcModel.new()
	m.model = "girl" if GIRLS.has(kind) else "man"
	if kind in [&"gatekeeper", &"hunter", &"knight"]:
		m.model = "ranger"
	elif kind in [&"herbalist", &"gatherer"]:
		m.model = "ranger_girl"
	m.tint = look[0]
	m.head = kind
	m.phase = float(P.phase)
	(P.root as Node3D).add_child(m)
	P.npc = m
	P.rest = {}
	P.height = 1.75
	P.radius = 0.9
	return P


## 모델로 선 사람의 동작(idle, talk, walk, sit, kneel, pray). 기본 도형이면 아무것도 안 한다.
static func pose(P: Dictionary, state: String) -> void:
	var m: NpcModel = P.get("npc")
	if m:
		m.play(state)


## 말을 마치고 손을 내린다.
static func still(P: Dictionary) -> void:
	pose(P, "idle")
	for f: Node3D in P.get("forearms", []):
		if P.rest.has(f):
			f.transform = P.rest[f]


## 주민이 영주 쪽을 본다(머리를 몸 기준 yaw로 k만큼 돌린다, -0.9~0.9 제한). target은 월드 위치.
static func look_at(P: Dictionary, root: Node3D, target: Vector3, k: float) -> void:
	var m: NpcModel = P.get("npc")
	if m:
		# 모델: 몸을 살짝 영주 쪽으로 돌린다
		var dm: Vector3 = root.to_local(target)
		var ym: float = clampf(atan2(-dm.x, -dm.z), -0.7, 0.7) * k
		m.rotation.y = lerpf(m.rotation.y, ym, 0.06)
		return
	var head: Node3D = P.get("head")
	if head == null or not P.rest.has(head):
		return
	var d: Vector3 = root.to_local(target)
	var yaw: float = clampf(atan2(-d.x, -d.z), -0.9, 0.9)
	var r: Transform3D = P.rest[head]
	var cur: float = float(head.get_meta("yaw", 0.0))
	cur = lerpf(cur, yaw * k, 0.15)
	head.set_meta("yaw", cur)
	head.transform = Transform3D(r.basis * Basis.from_euler(Vector3(0, cur, 0)), r.origin)


## 말할 때 손짓(t: 누적 초).
static func talk(P: Dictionary, t: float) -> void:
	pose(P, "talk")
	var forearms: Array = P.get("forearms", [])
	if forearms.size() < 2:
		return
	var f: Node3D = forearms[1]
	f.rotation.x = 0.9 + 0.35 * sin(t * 6.0)


## 허수아비 맞음: dir(월드 XZ, 영주에서 허수아비로)쪽으로 기울고 돌아온다(k 1→0).
static func dummy_wobble(piv: Node3D, dir: Vector3, k: float) -> void:
	var axis := Vector3(dir.z, 0.0, -dir.x)
	piv.transform.basis = Basis(axis.normalized(), 0.28 * k * cos((1.0 - k) * 14.0)) if k > 0.001 else Basis.IDENTITY
