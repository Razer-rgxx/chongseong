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
}


## 의뢰판: 기둥 둘, 널빤지, 붙은 종이 카드들.
static func board(parent: Node3D, at: Vector3, facing: float, rng: RandomNumberGenerator) -> void:
	var b := VillageBuilder.place(parent, at, facing)
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
	for i in 4:
		var a: Vector2 = corners[i]
		var c: Vector2 = corners[(i + 1) % 4]
		var len: float = a.distance_to(c)
		var n: int = int(len / 0.6)
		for k in n + 1:
			var p: Vector2 = a.lerp(c, float(k) / float(n))
			# 서쪽(마당 들머리)의 틈
			if i == 3 and p.y > gap.x and p.y < gap.y:
				continue
			VillageBuilder.box(parent, Vector3(0.12, 1.2, 0.12), Grid.cells_to_world(p) + Vector3(0, 0.6, 0), wood)
		for h in [0.45, 0.9]:
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
		VillageBuilder.box(piv, Vector3(0.12, 1.7, 0.12), Vector3(0, 0.85, 0), wood)
		VillageBuilder.box(piv, Vector3(1.1, 0.1, 0.1), Vector3(0, 1.25, 0), wood)
		VillageBuilder.cyl(piv, 0.25, 0.32, 0.8, Vector3(0, 1.0, 0.0), straw, 8)
		VillageBuilder.ball(piv, 0.2, Vector3(0, 1.7, 0), sack)
		for s in [-1.0, 1.0]:
			VillageBuilder.cyl(piv, 0.05, 0.08, 0.3, Vector3(s * 0.6, 1.2, 0), straw, 6).rotation.z = PI / 2.0
		out.append(piv)
	# 검 걸이: 두 기둥 사이 가로대에 칼 몇 자루
	var r := VillageBuilder.place(parent, Grid.cells_to_world(rack_at), 0.0)
	for x in [-0.9, 0.9]:
		VillageBuilder.box(r, Vector3(0.12, 1.5, 0.12), Vector3(x, 0.75, 0), wood)
	VillageBuilder.box(r, Vector3(2.0, 0.08, 0.1), Vector3(0, 1.3, 0), wood)
	VillageBuilder.box(r, Vector3(2.0, 0.08, 0.1), Vector3(0, 0.8, 0), wood)
	var steel := VillageBuilder.plain(Color(0.55, 0.57, 0.6), 0.45, 0.8)
	for i in 4:
		VillageBuilder.box(r, Vector3(0.07, 1.0, 0.03), Vector3(-0.6 + i * 0.4, 1.0, 0.07), steel, Vector3(0, 0, rng.randf_range(-0.08, 0.08)))
	return out


## 떠돌이 상인의 짐수레: 짐칸, 바퀴 둘, 천 덮개, 자루와 통, 끌채.
static func cart(parent: Node3D, at: Vector3, facing: float) -> void:
	var c := VillageBuilder.place(parent, at, facing)
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
	EventArt._rest(P)
	return P


## 주민이 영주 쪽을 본다(머리를 몸 기준 yaw로 k만큼 돌린다, -0.9~0.9 제한). target은 월드 위치.
static func look_at(P: Dictionary, root: Node3D, target: Vector3, k: float) -> void:
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
	var forearms: Array = P.get("forearms", [])
	if forearms.size() < 2:
		return
	var f: Node3D = forearms[1]
	f.rotation.x = 0.9 + 0.35 * sin(t * 6.0)


## 허수아비 맞음: dir(월드 XZ, 영주에서 허수아비로)쪽으로 기울고 돌아온다(k 1→0).
static func dummy_wobble(piv: Node3D, dir: Vector3, k: float) -> void:
	var axis := Vector3(dir.z, 0.0, -dir.x)
	piv.transform.basis = Basis(axis.normalized(), 0.28 * k * cos((1.0 - k) * 14.0)) if k > 0.001 else Basis.IDENTITY
