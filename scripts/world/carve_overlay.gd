class_name CarveOverlay
extends RefCounted
## 검의 기억(docs/sword_memory.md)을 칼 모델 위에 얹는다: 룬은 칼날을 따라 새긴 차가운 푸른 각진 무늬(마름모 테두리, V 표시),
## 보석은 없다(룬 박기로 바뀜).
## SwordModel의 블레이드 길이·너비·칼끝 x·손잡이 길이만 읽어서 절차 모양과 Blender 모델 어느 쪽에나 같게 붙는다.
## 좌표는 SwordModel과 같다(코등이가 원점, 칼날 +Y, 날 ±X, 두께 ±Z).

const RUNE_BLUE: Color = Color(0.35, 0.72, 1.0)
const NAME: String = "CarveOverlay"


## 룬 키 목록(Meta.sword_runes[id], "종류:단계")으로 m에 얹는다. 이미 얹은 것은 먼저 걷어 낸다.
## 단계가 높을수록 무늬가 조금 크고 더 밝게 빛난다.
static func apply(m: SwordModel, runes: Array) -> void:
	var old := m.get_node_or_null(NAME)
	if old:
		m.remove_child(old)
		old.free()
	if runes.is_empty():
		return
	var root := Node3D.new()
	root.name = NAME
	m.add_child(root)
	var T: RuneTable = Meta.rt()
	var W: float = m.form_width if m.form_width > 0.0 else 0.07
	var glyph: float = clampf(W * 0.7, 0.032, 0.056)
	for i in runes.size():
		var key: String = T.norm(String(runes[i]))
		var tier: int = T.tier_of(key)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = RUNE_BLUE
		mat.emission_enabled = true
		mat.emission = RUNE_BLUE
		mat.emission_energy_multiplier = 2.2 + 0.9 * float(tier)
		var pos: Array = slot_positions(m, i)
		var scene: PackedScene = model_of(T.type_of(key))
		for k in pos.size():
			var sz: float = glyph * (0.9 + 0.1 * float(tier))
			if scene != null:   # Blender 룬 모델(assets/runes/<종류>.glb)이 있으면 그것을, 없으면 납작한 무늬
				var n := scene.instantiate() as Node3D
				n.position = pos[k]
				n.scale = Vector3.ONE * (sz * 1.2)   # 모델은 가장 긴 변이 1.0, 무늬 면이 +Z(앞)
				if k == 1:
					n.rotation.y = PI   # 뒷면 짝은 반대쪽을 본다
				show_tier(n, tier)
				root.add_child(n)
			else:
				_glyph(root, T.glyph_of(key), pos[k], sz, mat)


## Blender 룬 모델(docs/sword_memory.md "룬 모델 약속"). 없으면 null(납작한 무늬로 돌아간다).
static func model_of(type: String) -> PackedScene:
	var path: String = "res://assets/runes/%s.glb" % type
	return load(path) as PackedScene if ResourceLoader.exists(path) else null


## 룬 모델의 단계 장식 노드(make_runes.py: glow_rune_t2 = 2단계부터 빛 상감 점, rune_inlay_t3·glow_rune_t3 = 3단계 은 테두리와 점)를
## 단계에 맞춰 켜고 끄고, 홈의 빛(glow_rune*)은 단계가 높을수록 조금 밝게. 대장간 그림(ForgeThumbs)은 1단계로 그린다.
static func show_tier(n: Node, tier: int) -> void:
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var nm: String = String(mi.name)
		if nm.ends_with("_t2"):
			mi.visible = tier >= 2
		elif nm.ends_with("_t3"):
			mi.visible = tier >= 3
		for si in mi.mesh.get_surface_count():
			var mt := mi.mesh.surface_get_material(si) as StandardMaterial3D
			if mt and mt.resource_name.begins_with("glow_rune"):
				var d := mt.duplicate() as StandardMaterial3D
				d.emission_enabled = true
				d.emission_energy_multiplier = 0.7 + 0.12 * float(tier)
				mi.set_surface_override_material(si, d)


## 룬 자리 i(0~2)가 칼에서 놓이는 곳(앞뒤 둘). 빈 자리 고리(ForgePreview)도 같은 곳에 띄운다.
static func slot_positions(m: SwordModel, i: int) -> Array:
	var L: float = m.blade_length
	var W: float = m.form_width if m.form_width > 0.0 else 0.07
	var t: float = 0.34 + 0.2 * float(i)
	var cx: float = m.tip_x * t * t
	var y: float = 0.1 + t * (L - 0.1) * 0.9
	var z: float = 0.017 if W >= 0.05 else 0.014
	return [Vector3(cx, y, z), Vector3(cx, y, -z)]


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
