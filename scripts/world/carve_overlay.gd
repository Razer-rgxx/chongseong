class_name CarveOverlay
extends RefCounted
## 검의 기억(docs/sword_memory.md)을 칼 모델 위에 얹는다: 룬은 칼날을 따라 새긴 차가운 푸른 각진 무늬(마름모 테두리, V 표시),
## 보석은 코등이와 칼날 밑동에 박힌 깎은 돌(작은 팔면체, 종류마다 붉은·보랏빛 등 제 색).
## SwordModel의 블레이드 길이·너비·칼끝 x·손잡이 길이만 읽어서 절차 모양과 Blender 모델 어느 쪽에나 같게 붙는다.
## 좌표는 SwordModel과 같다(코등이가 원점, 칼날 +Y, 날 ±X, 두께 ±Z).

const RUNE_BLUE: Color = Color(0.35, 0.72, 1.0)
const NAME: String = "CarveOverlay"


## 룬 키 목록(Meta.sword_runes[id])과 보석 키 목록("종류:단계")으로 m에 얹는다. 이미 얹은 것은 먼저 걷어 낸다.
static func apply(m: SwordModel, runes: Array, gems: Array) -> void:
	var old := m.get_node_or_null(NAME)
	if old:
		m.remove_child(old)
		old.free()
	if runes.is_empty() and gems.is_empty():
		return
	var root := Node3D.new()
	root.name = NAME
	m.add_child(root)
	var T: RuneTable = Meta.rt()
	var L: float = m.blade_length
	var W: float = m.form_width if m.form_width > 0.0 else 0.07
	var glyph: float = clampf(W * 0.7, 0.032, 0.056)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = RUNE_BLUE
	mat.emission_enabled = true
	mat.emission = RUNE_BLUE
	mat.emission_energy_multiplier = 3.0
	for i in runes.size():
		var idx: int = maxi(0, T.rune_order.find(String(runes[i])))
		var t: float = 0.34 + 0.2 * float(i)
		var cx: float = m.tip_x * t * t
		var y: float = 0.1 + t * (L - 0.1) * 0.9
		for side in [-1.0, 1.0]:
			_glyph(root, idx % 4, Vector3(cx, y, side * (0.017 if W >= 0.05 else 0.014)), glyph, mat)
	for i in mini(gems.size(), 2):
		var col: Color = T.gem_color(String(gems[i]))
		var gm := _gem_mat(col, int(String(gems[i]).split(":")[1]))
		var sz: float = 0.018 + 0.004 * float(int(String(gems[i]).split(":")[1]))
		if i == 0:   # 칼날 밑동, 앞뒤
			for side in [-1.0, 1.0]:
				_gem(root, Vector3(0.0, 0.085, side * 0.022), sz, gm)
		else:        # 코등이 양 끝
			for sx in [-1.0, 1.0]:
				_gem(root, Vector3(sx * 0.06, 0.0, 0.03), sz, gm)


static func _gem_mat(col: Color, tier: int) -> StandardMaterial3D:
	var gm := StandardMaterial3D.new()
	gm.albedo_color = col
	gm.metallic = 0.3
	gm.roughness = 0.12
	gm.emission_enabled = true
	gm.emission = col
	gm.emission_energy_multiplier = 1.4 + 0.6 * float(tier)
	return gm


static func _gem(root: Node3D, at: Vector3, size: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()   # 낮은 분할의 구 = 깎은 돌(팔면체에 가깝다)
	s.radial_segments = 4
	s.rings = 2
	s.radius = size
	s.height = size * 2.4
	mi.mesh = s
	mi.material_override = mat
	mi.position = at
	mi.rotation.y = PI / 4.0
	root.add_child(mi)


## 얇은 막대 하나(길이 len, 각도 ang(rad, z축)).
static func _bar(root: Node3D, at: Vector3, len: float, ang: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(len, 0.0048, 0.0022)
	mi.mesh = b
	mi.material_override = mat
	mi.position = at
	mi.rotation.z = ang
	root.add_child(mi)


## 무늬 하나: 0 마름모 테두리, 1 V, 2 마름모 + V, 3 겹친 V 둘.
static func _glyph(root: Node3D, kind: int, at: Vector3, g: float, mat: Material) -> void:
	var s: float = g * 0.5   # 마름모 반대각 길이의 절반
	var edge: float = s * 1.4142
	match kind:
		0, 2:
			var c: float = s * 0.5
			for sgn in [[1.0, 1.0, -PI / 4.0], [-1.0, 1.0, PI / 4.0], [1.0, -1.0, PI / 4.0], [-1.0, -1.0, -PI / 4.0]]:
				_bar(root, at + Vector3(sgn[0] * c, sgn[1] * c, 0.0), edge, sgn[2], mat)
			if kind == 2:
				_v(root, at + Vector3(0.0, -s * 1.5, 0.0), s * 0.8, mat)
		1:
			_v(root, at, s * 1.2, mat)
		3:
			_v(root, at + Vector3(0.0, s * 0.5, 0.0), s, mat)
			_v(root, at + Vector3(0.0, -s * 0.6, 0.0), s, mat)


## V 모양(아래가 뾰족): 막대 둘.
static func _v(root: Node3D, at: Vector3, s: float, mat: Material) -> void:
	var l: float = s * 1.3
	_bar(root, at + Vector3(-s * 0.5, s * 0.5, 0.0), l, -PI / 3.0, mat)
	_bar(root, at + Vector3(s * 0.5, s * 0.5, 0.0), l, PI / 3.0, mat)
