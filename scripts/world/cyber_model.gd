class_name CyberModel
extends RefCounted
## 사이버 검(312~511, docs/cyber_swords.md)의 코드 모양. SwordModel._build가 번호로 알아보고 부른다.
## 좌표는 SwordModel과 같다(코등이가 원점, 칼날 +Y, 손잡이 -Y, 날은 ±X, 칼 두께는 Z).
## 종류(단검·카타나·오니마루·환도·중장도·대검)마다 칼날 너비·휘어짐·코등이·손잡이 길이가 다르고, 모두 총검이다:
## 칼날 밑에 총열과 총구 고리, 코등이 뒤의 탄창 덩이, 날을 따라 청록 빛 줄. 무한은 칼날에 방열창과 레일이 더 붙는다.
## 무한 12자루는 Blender 모델(assets/swords/<번호>.glb, tools/blender/make_cyber_swords.py)이 있으면 그것을 쓴다.

const TEAL: Color = Color(0.35, 0.85, 0.95)

## 종류별 모양 값: 휘어짐(sori, 칼날 길이 비율), 칼날 폭 배수, 칼끝 길이, 끝이 넓어지는 정도, 양날, 손잡이 길이(m).
const SHAPE: Dictionary = {
	"단검":    {"sori": 0.02, "w": 1.0, "tip": 0.30, "flare": 0.0, "double": false, "grip": 0.12},
	"카타나":  {"sori": 0.05, "w": 1.0, "tip": 0.16, "flare": 0.0, "double": false, "grip": 0.30},
	"오니마루": {"sori": 0.085, "w": 1.15, "tip": 0.2, "flare": 0.1, "double": false, "grip": 0.32},
	"환도":    {"sori": 0.035, "w": 1.1, "tip": 0.14, "flare": 0.35, "double": false, "grip": 0.24},
	"중장도":  {"sori": 0.015, "w": 1.85, "tip": 0.12, "flare": 0.1, "double": false, "grip": 0.36},
	"대검":    {"sori": 0.0, "w": 1.5, "tip": 0.14, "flare": 0.0, "double": true, "grip": 0.40},
}


## 칼 한 자루를 m에 붙인다. 칼날 길이(m.blade_length)는 형태 표가 정한 것을 쓴다.
static func build(m: SwordModel, grade: int, seed: int, col: Color) -> void:
	var sub: String = CyberSwords.sub_of(seed)
	var S: Dictionary = SHAPE[sub]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 6151 + 29
	var L: float = m.blade_length
	var base_w: float = (m.form_width if m.form_width > 0.0 else 0.06) * float(S.w)
	m.grip_length = float(S.grip)
	m.glow_color = TEAL
	m.tip_x = -float(S.sori) * L
	var mats: Dictionary = _materials(grade, col)
	var h: float = clampf(base_w * 0.16, 0.005, 0.014)   # 반두께
	# 칼날과 날의 빛 줄
	m.add_child(_blade_mesh(L, base_w, h, S, mats.steel))
	m.add_child(_edge_glow(L, base_w, h, S, mats.glow))
	# 방열창(전설부터 하나씩 늘고 무한은 가득)과 등의 레일(대검·중장도·무한)
	var vents: int = 0 if grade < 2 else clampi(grade - 1 + (2 if sub == "중장도" or sub == "대검" else 0), 0, 6)
	for i in vents:
		var t: float = 0.22 + 0.5 * float(i) / maxf(1.0, vents - 1.0 if vents > 1 else 1.0)
		var cx: float = _cx(t, L, S)
		for side in [-1.0, 1.0]:
			m._box(Vector3(base_w * 0.42, 0.018, 0.003), Vector3(cx - base_w * 0.05, 0.02 + t * (L - 0.02), side * (h + 0.0008)), mats.glow)
	if grade >= 5 or sub == "대검" or sub == "중장도":
		m._box(Vector3(0.016, L * 0.34, 0.012), Vector3(_cx(0.2, L, S) - base_w * 0.2, 0.1 + L * 0.17, h + 0.006), mats.dark)
		m._box(Vector3(0.006, L * 0.3, 0.004), Vector3(_cx(0.2, L, S) - base_w * 0.2, 0.1 + L * 0.17, h + 0.013), mats.glow)
	# 총열: 칼날 밑(Z 뒤쪽)에 나란히. 끝에 청록 총구 고리. 대검은 둘.
	var barrels: int = 2 if sub == "대검" else 1
	for b in barrels:
		var bz: float = -(h + 0.016 + 0.026 * b)
		var bx: float = -base_w * (0.35 if barrels == 1 else (0.1 + 0.5 * b))
		var blen: float = L * (0.58 if sub != "단검" else 0.7)
		var barrel := m._cyl(0.011, 0.013, blen, Vector3(bx, 0.05 + blen / 2.0, bz), mats.dark)
		barrel.rotation = Vector3.ZERO
		var ring := m._cyl(0.016, 0.016, 0.012, Vector3(bx, 0.05 + blen, bz), mats.glow)
		ring.rotation = Vector3.ZERO
		m._cyl(0.009, 0.009, 0.014, Vector3(bx, 0.056 + blen, bz), mats.dark)
	# 코등이
	_guard(m, sub, base_w, mats, rng)
	# 탄창 덩이: 코등이 뒤쪽에 청록 줄이 든 상자
	var mag: Vector3 = Vector3(0.05, 0.11, 0.032) * (1.0 + (0.5 if sub == "중장도" or sub == "대검" else 0.0))
	var mx: float = (-1.0 if rng.randi() % 2 == 0 else 1.0) * 0.012
	m._box(mag, Vector3(mx, -0.06 - mag.y * 0.25, -(h + 0.03)), mats.plate)
	m._box(Vector3(mag.x * 0.5, mag.y * 0.7, 0.004), Vector3(mx, -0.06 - mag.y * 0.25, -(h + 0.03 + mag.z / 2.0 + 0.001)), mats.glow)
	# 손잡이와 자루끝
	m._grip(m.grip_length, mats.grip)
	var py: float = -m.grip_length - 0.02
	m._box(Vector3(0.05, 0.036, 0.05), Vector3(0, py, 0), mats.plate)
	m._box(Vector3(0.03, 0.01, 0.052), Vector3(0, py - 0.022, 0), mats.glow)
	if grade >= 3:
		m._ball(0.012, Vector3(0, py - 0.036, 0), mats.accent)
	if grade >= 4:
		m._aura(col.lerp(TEAL, 0.6), grade)


## 칼날 가운데선의 x. t는 0(코등이)~1(칼끝). 칼끝이 칼등(-X) 쪽으로 휜다.
static func _cx(t: float, L: float, S: Dictionary) -> float:
	return -float(S.sori) * L * t * t


static func _blade_mesh(L: float, W: float, h: float, S: Dictionary, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var n: int = 16
	var rings: Array = []
	var dbl: bool = bool(S.double)
	for i in n + 1:
		var t: float = float(i) / n
		var w: float = W / 2.0 * (1.0 - 0.18 * t) * (1.0 + float(S.flare) * smoothstep(0.5, 0.9, t))
		var u: float = clampf((t - (1.0 - float(S.tip))) / float(S.tip), 0.0, 1.0)
		var tipf: float = sqrt(maxf(0.0, 1.0 - u * u)) if not dbl else 1.0 - u
		var hh: float = h * (1.0 - 0.35 * t) * (1.0 if u <= 0.0 else maxf(0.1, 1.0 - u * u))
		var we: float = w * (tipf if i < n else 0.0)
		var cx: float = _cx(t, L, S)
		var y: float = 0.02 + t * (L - 0.02)
		if dbl:
			rings.append([Vector3(cx - we, y, 0), Vector3(cx - we * 0.55, y, hh), Vector3(cx + we * 0.55, y, hh), Vector3(cx + we, y, 0), Vector3(cx + we * 0.55, y, -hh), Vector3(cx - we * 0.55, y, -hh)])
		else:
			var ws: float = w * 0.6 * (1.0 if i < n else 0.0) * (1.0 if u <= 0.0 else maxf(0.0, 1.0 - u * 0.7))
			rings.append([Vector3(cx + we, y, 0), Vector3(cx + we * 0.3, y, hh), Vector3(cx - ws, y, hh), Vector3(cx - ws, y, -hh), Vector3(cx + we * 0.3, y, -hh)])
	var k: int = (rings[0] as Array).size()
	for i in n:
		for j in k:
			var j2: int = (j + 1) % k
			SwordModel._quad(st, rings[i][j], rings[i][j2], rings[i + 1][j2], rings[i + 1][j], Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	# 밑동 막기
	var r0: Array = rings[0]
	for j in range(1, k - 1):
		st.add_vertex(r0[0])
		st.add_vertex(r0[j + 1])
		st.add_vertex(r0[j])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	return mi


## 날을 따라 가는 청록 빛 줄(날 쪽 비탈에 얹는다. 양날이면 두 날).
static func _edge_glow(L: float, W: float, h: float, S: Dictionary, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var n: int = 16
	var dbl: bool = bool(S.double)
	var sides: Array = [1.0, -1.0] if dbl else [1.0]
	for sx in sides:
		for zs in [-1.0, 1.0]:
			var prev: Array = []
			for i in range(1, n):
				var t: float = float(i) / n
				var w: float = W / 2.0 * (1.0 - 0.18 * t) * (1.0 + float(S.flare) * smoothstep(0.5, 0.9, t))
				var u: float = clampf((t - (1.0 - float(S.tip))) / float(S.tip), 0.0, 1.0)
				var tipf: float = sqrt(maxf(0.0, 1.0 - u * u)) if not dbl else 1.0 - u
				var we: float = w * tipf
				var hh: float = h * (1.0 - 0.35 * t) * (1.0 if u <= 0.0 else maxf(0.1, 1.0 - u * u))
				var cx: float = _cx(t, L, S)
				var y: float = 0.02 + t * (L - 0.02)
				var a: Vector3 = Vector3(cx + sx * we * 0.62, y, zs * hh * 0.62 + zs * 0.0012)
				var b: Vector3 = Vector3(cx + sx * we * 0.97, y, zs * hh * 0.06 + zs * 0.0012)
				if not prev.is_empty():
					SwordModel._quad(st, prev[0], prev[1], b, a, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
				prev = [a, b]
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	return mi


static func _guard(m: SwordModel, sub: String, W: float, mats: Dictionary, rng: RandomNumberGenerator) -> void:
	match sub:
		"단검":
			m._box(Vector3(0.12, 0.03, 0.05), Vector3.ZERO, mats.plate)
			m._ball(0.012, Vector3(0, 0, 0.03), mats.glow)
		"카타나":
			var disc := m._cyl(0.052, 0.052, 0.014, Vector3.ZERO, mats.plate)
			disc.rotation.x = 0.0
			var rim := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.046
			tm.outer_radius = 0.054
			tm.rings = 24
			tm.ring_segments = 6
			rim.mesh = tm
			rim.material_override = mats.glow
			rim.rotation.x = 0.0
			m.add_child(rim)
		"오니마루":
			m._box(Vector3(0.2, 0.03, 0.05), Vector3.ZERO, mats.plate)
			for sx in [-1.0, 1.0]:
				var horn := m._cyl(0.0, 0.022, 0.1, Vector3(sx * 0.1, 0.05, 0), mats.plate)
				horn.rotation.z = sx * -0.5
				m._ball(0.012, Vector3(sx * 0.11, 0.0, 0.028), mats.glow)
		"환도":
			m._cyl(0.056, 0.056, 0.016, Vector3.ZERO, mats.plate)
			for k in 6:
				var a: float = TAU * k / 6.0
				var petal := m._ball(0.016, Vector3(cos(a) * 0.06, 0.0, sin(a) * 0.06), mats.glow if k % 2 == 0 else mats.plate)
				petal.scale = Vector3(1, 0.5, 1)
		"중장도":
			m._box(Vector3(0.22, 0.05, 0.075), Vector3.ZERO, mats.plate)
			for sx in [-1.0, 1.0]:
				m._box(Vector3(0.05, 0.012, 0.078), Vector3(sx * 0.07, 0.0, 0), mats.glow)
		_:
			m._box(Vector3(0.36, 0.04, 0.06), Vector3.ZERO, mats.plate)
			for sx in [-1.0, 1.0]:
				var wing := m._box(Vector3(0.1, 0.03, 0.06), Vector3(sx * 0.19, -0.03, 0), mats.plate)
				wing.rotation.z = sx * -0.5
			m._box(Vector3(0.05, 0.02, 0.064), Vector3.ZERO, mats.glow)


## 재질: 등급이 오를수록 총기처럼 검고 매끈해지고 빛이 세진다. 빛은 늘 청록이고 등급 빛은 장식(accent)에만 쓴다.
static func _materials(g: int, col: Color) -> Dictionary:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.58, 0.62, 0.68).lerp(Color(0.27, 0.31, 0.38), clampf(g / 5.0, 0.0, 1.0))
	steel.metallic = 0.6
	steel.roughness = lerpf(0.55, 0.3, clampf(g / 5.0, 0.0, 1.0))
	var plate := steel.duplicate() as StandardMaterial3D
	plate.albedo_color = steel.albedo_color.lightened(0.18)
	plate.roughness = steel.roughness + 0.08
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.04, 0.045, 0.055)
	dark.metallic = 0.6
	dark.roughness = 0.45
	var grip := StandardMaterial3D.new()
	grip.albedo_color = Color(0.06, 0.07, 0.09)
	grip.roughness = 0.85
	var glow := StandardMaterial3D.new()
	glow.albedo_color = TEAL.darkened(0.35)
	glow.emission_enabled = true
	glow.emission = TEAL
	glow.emission_energy_multiplier = 1.2 + g * 0.45
	var accent := StandardMaterial3D.new()
	accent.albedo_color = col
	accent.emission_enabled = true
	accent.emission = col
	accent.emission_energy_multiplier = 2.0
	return {"steel": steel, "plate": plate, "dark": dark, "grip": grip, "glow": glow, "accent": accent}


## Blender 무한 모델(glow_kat_* 재질)의 빛 세기: 날 끝은 사이버 카타나(311)처럼 은은하게, 홈·총구 고리는 네온처럼. 색은 모델 그대로.
## 2026-11-26부터 칼마다 빛 색이 달라 재질 이름 뒤에 _<빛>이 붙는다(glow_kat_edge_red 등): 앞부분으로 세기를 고른다.
const GLOW: Dictionary = {"glow_kat_edge": 1.3, "glow_kat_line": 3.0, "glow_kat_rim": 2.8, "glow_fire": 3.0}


static func glow_boost(n: Node) -> void:
	for node in n.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for si in mi.mesh.get_surface_count():
			var mt := mi.mesh.surface_get_material(si) as StandardMaterial3D
			var key: String = _glow_key(mt.resource_name) if mt else ""
			if key != "":
				var d := mt.duplicate() as StandardMaterial3D
				d.emission_enabled = true
				d.emission_energy_multiplier = GLOW[key]
				mi.set_surface_override_material(si, d)


## 재질 이름 → GLOW의 열쇠(glow_kat_edge_red → glow_kat_edge). 없으면 "".
static func _glow_key(nm: String) -> String:
	if GLOW.has(nm):
		return nm
	for k in GLOW:
		if nm.begins_with(String(k) + "_"):
			return k
	return ""
