class_name SwordModel
extends Node3D
## 칼 한 자루의 모양을 코드로 만든다(모델 에셋 없이). 칼날은 형태(단검·장검·대검·세검)를 따르고,
## 코등이·손잡이·자루끝은 칼 번호로 고른다(같은 칼은 늘 같은 모양). 등급이 오를수록 재질이 좋아지고 빛이 붙는다.
## 지역 좌표: 코등이가 원점, 칼날은 +Y, 손잡이는 -Y. 날이 선 쪽은 ±X, 칼등의 두께는 Z.
##
## 등급별 모습: 흔함 녹슨 쇠 / 귀함 닦은 강철과 놋쇠 / 전설 금빛 코등이와 피홈의 빛 /
## 신화 검은 강철에 빛나는 무늬 / 초월 칼날 전체가 빛나고 빛 알갱이 / 무한 검은 칼날에 날만 타오르고 알갱이가 많다.

const KINDS: Dictionary = {"단검": "dagger", "장검": "longsword", "대검": "greatsword", "세검": "rapier"}

## 칼날 길이(m)와 손잡이 길이(m). 궤적과 손에 쥐는 자리에 쓴다.
var blade_length: float = 1.0
var grip_length: float = 0.2
var grade: int = 0
var glow_color: Color = Color.WHITE
## 칼끝의 x(m). 곧은 칼은 0, 휜 사이버 카타나(Blender)는 칼등 쪽으로 조금 비켜난다. 베기 궤적이 칼끝을 따라가게.
var tip_x: float = 0.0


## form: FormData(칼날 길이·너비), grade: 0~5, seed: 칼 번호, col: 등급 색. form이 null이면 그냥 장검.
static func make(form: FormData, p_grade: int, seed: int, col: Color) -> SwordModel:
	var s := SwordModel.new()
	s._build(form, p_grade, seed, col)
	return s


static func for_sword(sw: Sword, grades: GradeTable) -> SwordModel:
	return make(sw.form, sw.grade, sw.data.id if sw.data else 0, grades.colors[sw.grade])


## 칼날의 손잡이 쪽 끝과 칼끝(세계 좌표).
func blade_points() -> Array[Vector3]:
	return [global_transform * Vector3(0, 0.05, 0), global_transform * Vector3(tip_x, blade_length, 0)]


func _build(form: FormData, p_grade: int, seed: int, col: Color) -> void:
	grade = p_grade
	glow_color = col
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7919 + 13
	var kind: String = KINDS.get(form.display_name, "longsword") if form else "longsword"
	blade_length = form.blade_length if form else 1.1
	var width: float = form.blade_width if form else 0.08
	grip_length = {"dagger": 0.11, "longsword": 0.2, "greatsword": 0.36, "rapier": 0.14}.get(kind, 0.2)
	# Blender로 지은 칼(tools/blender/make_swords.py → assets/swords/<번호>.glb)이 있으면 그것(최고 등급 몇 자루, 사이버 카타나)
	var glb: String = "res://assets/swords/%d.glb" % seed
	if ResourceLoader.exists(glb):
		var g := (load(glb) as PackedScene).instantiate() as Node3D
		add_child(g)
		if seed == KATANA_SEED:   # 사이버 카타나: 등급 색 대신 제 청록빛, 빛 알갱이 없음, 두 손 손잡이
			glow_color = KATANA_BLUE
			grip_length = KATANA_GRIP
			tip_x = KATANA_TIP_X
			_katana_glow(g)
			return
		_tint_glow(g, col)
		if grade >= 4:
			_aura(col, grade)
		return
	if seed == KATANA_SEED:
		_katana(blade_length)
		return
	var mats := _materials(grade, col)
	add_child(_blade(kind, blade_length, width, mats[0]))
	if grade >= 2:
		add_child(_fuller(kind, blade_length, width, mats[3]))
	grip_length = {"dagger": 0.11, "longsword": 0.2, "greatsword": 0.36, "rapier": 0.14}.get(kind, 0.2)
	var guard_w: float = {"dagger": 0.16, "longsword": 0.26, "greatsword": 0.42, "rapier": 0.2}.get(kind, 0.26)
	_guard(rng.randi() % 4, guard_w, mats[1], mats[3])
	_grip(grip_length, mats[2])
	_pommel(rng.randi() % 3, guard_w, mats[1], mats[3])
	if grade >= 4:
		_aura(col, grade)


## 사이버 카타나(311, docs/stranger.md). 보통은 Blender 모델(assets/swords/311.glb, tools/blender/make_swords.py의
## sword_cyber_katana)을 쓰고, 그 파일이 없을 때만 아래 _katana가 코드로 짓는다.
## 칼날은 +Y로 길이 L, 날 쪽은 +X. 손잡이는 -Y.
const KATANA_SEED: int = 311
const KATANA_BLUE: Color = Color(0.35, 0.85, 0.95)
## Blender 카타나의 손잡이 길이(코등이 아래 ~ 끝마개, 칼날 1.42m의 1/4)와 칼끝 x. make_swords.py의 KAT_GRIP·KAT_TIP_X와 같다.
const KATANA_GRIP: float = 0.355
const KATANA_TIP_X: float = -0.064
## Blender 카타나의 빛 세기: 날 끝은 은은하게, 덮개의 네온관(파랑)과 코등이·끝마개의 네온 고리(청록)는 네온사인처럼.
## 빛 색에 빨강이 없어서 세게 켜도 하얗게 날지 않고 번짐(glow)만 생긴다.
const KATANA_GLOW: Dictionary = {"glow_kat_edge": 1.3, "glow_kat_line": 3.2, "glow_kat_rim": 2.8}
const KATANA_SORI: float = 0.08    ## 휨(칼날 길이에 대한 비율)
const KATANA_N: int = 12           ## 칼날 마디 수


## 휜 칼날의 가운데선 x(칼뿌리 0, 칼끝은 살짝 +X). t = 0~1.
static func _kx(t: float, L: float) -> float:
	return KATANA_SORI * L * (t * t - 0.5 * t) * 1.6


func _katana(L: float) -> void:
	glow_color = KATANA_BLUE
	grip_length = 0.28
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.17, 0.19, 0.23)
	steel.metallic = 0.85
	steel.roughness = 0.3
	var plate := steel.duplicate() as StandardMaterial3D   # 덮개의 밝은 판
	plate.albedo_color = Color(0.27, 0.3, 0.35)
	plate.roughness = 0.38
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.03, 0.035, 0.045)
	dark.metallic = 0.6
	dark.roughness = 0.5
	var wrap := StandardMaterial3D.new()
	wrap.albedo_color = Color(0.13, 0.145, 0.17)
	wrap.roughness = 0.7
	wrap.cull_mode = BaseMaterial3D.CULL_DISABLED
	var pale := StandardMaterial3D.new()
	pale.albedo_color = Color(0.72, 0.78, 0.82)
	pale.metallic = 0.9
	pale.roughness = 0.3
	var glow := StandardMaterial3D.new()
	glow.albedo_color = KATANA_BLUE
	glow.emission_enabled = true
	glow.emission = KATANA_BLUE
	glow.emission_energy_multiplier = 1.5
	glow.albedo_color = KATANA_BLUE.darkened(0.3)
	var faint := glow.duplicate() as StandardMaterial3D
	faint.emission_energy_multiplier = 0.9
	faint.albedo_color = KATANA_BLUE.darkened(0.4)
	# 칼날과 날·등의 빛 줄
	var y0: float = 0.02
	var y1: float = L + 0.03
	var rings: Array = []   # 마디마다 [중심 x, y, 날쪽 반너비, 등쪽 반너비, 반두께, 뾰족함 0~1]
	for i in KATANA_N + 1:
		var t: float = float(i) / KATANA_N
		var base_w: float = 0.046 - 0.016 * t      # 칼뿌리로 갈수록 넓다
		var u: float = smoothstep(0.0, 1.0, clampf((t - 0.78) / 0.22, 0.0, 1.0))   # 칼끝(키사키)
		var we: float = base_w * (1.0 - 0.55 * u)
		var ws: float = base_w * (1.0 - u)
		var h: float = 0.0055 * (1.0 - 0.3 * t) * (1.0 - u * u)
		var cx: float = _kx(t, L)
		if i == KATANA_N:
			we = 0.0
			ws = 0.0
			h = 0.0
		rings.append([cx, y0 + t * (y1 - y0), we, ws, h])
	var bs := SurfaceTool.new()
	bs.begin(Mesh.PRIMITIVE_TRIANGLES)
	bs.set_smooth_group(-1)
	var edge_pts: Array[Vector3] = []
	var spine_pts: Array[Vector3] = []
	for i in KATANA_N + 1:
		var r: Array = rings[i]
		edge_pts.append(Vector3(r[0] + r[2], r[1], 0))
		spine_pts.append(Vector3(r[0] - r[3], r[1], r[4]))
	for i in KATANA_N:
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		var pa := _katana_ring(a)
		var pb := _katana_ring(b)
		for k in 5:
			var k2: int = (k + 1) % 5
			_tri_quad(bs, pa[k], pa[k2], pb[k2], pb[k])
	# 칼뿌리 마개(등 쪽 단면)
	var p0 := _katana_ring(rings[0])
	_tri_quad(bs, p0[0], p0[4], p0[3], p0[2])
	_tri_quad(bs, p0[0], p0[2], p0[1], p0[0])
	bs.generate_normals()
	_mesh_node(bs, steel)
	_mesh_node(_tube(edge_pts, 0.0042, 2, KATANA_N), glow)    # 날과 칼끝을 따라 도는 줄
	var sp: Array[Vector3] = []
	for i in range(2, KATANA_N - 1):
		sp.append(spine_pts[i] + Vector3(0, 0, 0.0008))
	_mesh_node(_tube(sp, 0.0022, 0, sp.size() - 1), faint)    # 칼등의 가는 줄
	# 칼뿌리 덮개: 겹친 네모 판, 홈의 선, 작은 네모
	var H: float = L * 0.2
	var hs := SurfaceTool.new()      # 밝은 판
	var ds := SurfaceTool.new()      # 어두운 판·홈
	var gs := SurfaceTool.new()      # 홈 속 빛
	for s in [hs, ds, gs]:
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
		s.set_smooth_group(-1)
	var yb: float = 0.008
	_sbox(hs, Vector3(0, yb + H * 0.5, 0), Vector3(0.09, H, 0.03))               # 몸통
	_sbox(ds, Vector3(0, yb + 0.006, 0), Vector3(0.1, 0.012, 0.038))             # 아래 받침
	_sbox(ds, Vector3(0, yb + H + 0.005, 0), Vector3(0.098, 0.012, 0.036))          # 위 테두리
	_sbox(hs, Vector3(0, yb + H + 0.016, 0), Vector3(0.07, 0.01, 0.025))           # 위로 좁아지는 층
	_sbox(hs, Vector3(0, yb + H + 0.024, 0), Vector3(0.055, 0.006, 0.019))
	for z in [-1.0, 1.0]:
		var fz: float = z * 0.0165
		_sbox(ds, Vector3(0, yb + H * 0.5, fz), Vector3(0.074, H * 0.82, 0.004))     # 앞뒤 어두운 판
		_sbox(hs, Vector3(-0.016, yb + H * 0.72, fz + z * 0.002), Vector3(0.03, H * 0.3, 0.003))   # 겹친 작은 판
		_sbox(ds, Vector3(0.0, yb + H * 0.2, fz + z * 0.002), Vector3(0.066, H * 0.1, 0.003))
		var gz: float = z * 0.0186
		_sbox(gs, Vector3(-0.032, yb + H * 0.5, gz), Vector3(0.0022, H * 0.7, 0.0016))   # 세로 홈 빛
		_sbox(gs, Vector3(0.032, yb + H * 0.5, gz), Vector3(0.0022, H * 0.7, 0.0016))
		_sbox(gs, Vector3(0, yb + H * 0.88, gz), Vector3(0.066, 0.0022, 0.0016))          # 가로 홈 빛
		_sbox(gs, Vector3(0, yb + H * 0.1, gz), Vector3(0.066, 0.0022, 0.0016))
		_sbox(ds, Vector3(0.016, yb + H * 0.44, gz + z * 0.0005), Vector3(0.016, 0.016, 0.0014))   # 작은 네모
		_sbox(gs, Vector3(0.016, yb + H * 0.44, gz + z * 0.0016), Vector3(0.007, 0.007, 0.0012))
	for s in [hs, ds, gs]:
		s.generate_normals()
	_mesh_node(hs, plate)
	_mesh_node(ds, dark)
	_mesh_node(gs, glow)
	# 코등이: 둥글고 약간 두껍게, 얇은 청록 테
	_cyl_n(0.056, 0.056, 0.014, Vector3(0, 0, 0), dark, 18)
	_cyl_n(0.0585, 0.0585, 0.0036, Vector3(0, 0, 0), glow, 18)
	# 손잡이: 검은 심, 비스듬한 감김, 옅은 쇠고리, 네모진 자루끝
	_cyl_n(0.0155, 0.0155, grip_length, Vector3(0, -grip_length / 2.0 - 0.012, 0), dark, 10)
	_cyl_n(0.0215, 0.0215, 0.016, Vector3(0, -0.02, 0), pale, 12)
	var ws := SurfaceTool.new()
	ws.begin(Mesh.PRIMITIVE_TRIANGLES)
	ws.set_smooth_group(-1)
	var rows: int = 8
	for r in rows:
		var yy: float = -0.052 - r * 0.0245
		for c in 6:
			var ang: float = TAU * (float(c) + 0.5 * (r % 2)) / 6.0
			_wrap_quad(ws, ang, yy, 0.0165, 1.0 if (c + r) % 2 == 0 else -1.0)
	ws.generate_normals()
	_mesh_node(ws, wrap)
	var cap_y: float = -grip_length - 0.012 - 0.013
	_cyl_n(0.0195, 0.0195, 0.008, Vector3(0, -grip_length - 0.004, 0), pale, 12)
	var cs := SurfaceTool.new()
	cs.begin(Mesh.PRIMITIVE_TRIANGLES)
	cs.set_smooth_group(-1)
	_sbox(cs, Vector3(0, cap_y, 0), Vector3(0.036, 0.026, 0.036))
	cs.generate_normals()
	_mesh_node(cs, plate)
	var cg := SurfaceTool.new()
	cg.begin(Mesh.PRIMITIVE_TRIANGLES)
	cg.set_smooth_group(-1)
	_sbox(cg, Vector3(0, cap_y, 0), Vector3(0.039, 0.0028, 0.039))
	cg.generate_normals()
	_mesh_node(cg, glow)


## 마디 하나의 단면 5점: 날, 윗 시노기, 윗 등, 아랫 등, 아랫 시노기.
static func _katana_ring(r: Array) -> Array[Vector3]:
	var cx: float = r[0]
	var y: float = r[1]
	var we: float = r[2]
	var ws: float = r[3]
	var h: float = r[4]
	return [
		Vector3(cx + we, y, 0),
		Vector3(cx + we * 0.15, y, h),
		Vector3(cx - ws, y, h * 0.85),
		Vector3(cx - ws, y, -h * 0.85),
		Vector3(cx + we * 0.15, y, -h),
	]


## 앞에서 봤을 때 반시계인 네 점(a,b,c,d)을 Godot의 시계 방향 앞면으로 쓴다.
static func _tri_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)


static func _sbox(st: SurfaceTool, c: Vector3, s: Vector3) -> void:
	var h: Vector3 = s * 0.5
	var p: Array[Vector3] = []
	for k in 8:
		p.append(c + Vector3(h.x if k & 1 else -h.x, h.y if k & 2 else -h.y, h.z if k & 4 else -h.z))
	# 면마다 바깥에서 보아 반시계 순서
	_tri_quad(st, p[1], p[3], p[7], p[5])   # +X
	_tri_quad(st, p[4], p[6], p[2], p[0])   # -X
	_tri_quad(st, p[2], p[6], p[7], p[3])   # +Y
	_tri_quad(st, p[0], p[1], p[5], p[4])   # -Y
	_tri_quad(st, p[5], p[7], p[6], p[4])   # +Z
	_tri_quad(st, p[0], p[2], p[3], p[1])   # -Z


## 점들을 따라가는 가는 마름모 관. from~to 마디(포함). 칼끝에서 뾰족하게 닫힌다.
static func _tube(pts: Array[Vector3], r: float, from: int, to: int) -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var offs: Array[Vector3] = [Vector3(r, 0, 0), Vector3(0, 0, r), Vector3(-r, 0, 0), Vector3(0, 0, -r)]
	for i in range(from, to):
		for k in 4:
			var k2: int = (k + 1) % 4
			_tri_quad(st, pts[i] + offs[k], pts[i] + offs[k2], pts[i + 1] + offs[k2], pts[i + 1] + offs[k])
	st.generate_normals()
	return st


## 손잡이 둘레에 비스듬히 놓이는 작은 판 하나(방향 s로 기울기가 번갈아 바뀐다).
static func _wrap_quad(st: SurfaceTool, ang: float, y: float, rad: float, s: float) -> void:
	var b := Basis(Vector3.UP, ang)
	var tang: Vector3 = b * Vector3(1, 0, 0)
	var rad_dir: Vector3 = b * Vector3(0, 0, 1)
	var along: Vector3 = (Vector3(0, 1, 0) * 0.8 + tang * 0.6 * s).normalized()
	var across: Vector3 = (tang * 0.8 - Vector3(0, 1, 0) * 0.6 * s).normalized()
	var c: Vector3 = rad_dir * (rad + 0.0012) + Vector3(0, y, 0)
	var la: float = 0.0105
	var lb: float = 0.0055
	_tri_quad(st, c - along * la - across * lb, c - along * la + across * lb,
		c + along * la + across * lb, c + along * la - across * lb)


func _mesh_node(st: SurfaceTool, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	st.index()
	mi.mesh = st.commit()
	mi.material_override = m
	add_child(mi)
	return mi


func _cyl_n(top: float, bottom: float, h: float, at: Vector3, m: Material, segs: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	mi.mesh = c
	mi.material_override = m
	mi.position = at
	add_child(mi)
	return mi


## Blender 사이버 카타나의 빛 재질(glow_kat_*): 색은 모델의 청록 그대로 두고 세기만 KATANA_GLOW로.
static func _katana_glow(n: Node) -> void:
	for node in n.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for si in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(si) as StandardMaterial3D
			if m and KATANA_GLOW.has(m.resource_name):
				var d := m.duplicate() as StandardMaterial3D
				d.emission_enabled = true
				d.emission_energy_multiplier = KATANA_GLOW[m.resource_name]
				mi.set_surface_override_material(si, d)


## Blender 칼의 glow_·ghost_ 재질을 등급 빛깔로.
static func _tint_glow(n: Node, col: Color) -> void:
	for node in n.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for si in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(si) as StandardMaterial3D
			if m and (m.resource_name.begins_with("glow") or m.resource_name.begins_with("ghost")):
				var d := m.duplicate() as StandardMaterial3D
				d.emission_enabled = true
				d.emission = col
				d.albedo_color = Color(col.lerp(Color.WHITE, 0.3), d.albedo_color.a)
				mi.set_surface_override_material(si, d)


# ---------------------------------------------------------------- 재질

## [칼날, 코등이와 자루끝, 손잡이, 빛]
static func _materials(g: int, col: Color) -> Array[StandardMaterial3D]:
	var blade := StandardMaterial3D.new()
	var guard := StandardMaterial3D.new()
	var grip := StandardMaterial3D.new()
	var glow := StandardMaterial3D.new()
	blade.metallic = 0.9
	guard.metallic = 0.9
	grip.roughness = 0.8
	glow.emission_enabled = true
	glow.albedo_color = col
	glow.emission = col
	glow.emission_energy_multiplier = 2.0 + g * 0.6
	match g:
		0:   # 녹슨 쇠: 얼룩진 잡음
			blade.albedo_texture = _stain(Color(0.36, 0.31, 0.27), Color(0.54, 0.54, 0.56))
			blade.roughness = 0.6
			guard.albedo_color = Color(0.3, 0.28, 0.26)
			guard.roughness = 0.7
			grip.albedo_color = Color(0.22, 0.15, 0.1)
		1:
			blade.albedo_color = Color(0.82, 0.84, 0.88)
			blade.roughness = 0.22
			guard.albedo_color = Color(0.66, 0.5, 0.26)
			guard.roughness = 0.35
			grip.albedo_color = Color(0.18, 0.1, 0.07)
		2:
			blade.albedo_color = Color(0.86, 0.87, 0.9)
			blade.roughness = 0.15
			guard.albedo_color = Color(0.9, 0.68, 0.28)
			guard.roughness = 0.25
			grip.albedo_color = Color(0.3, 0.06, 0.05)
		3:
			blade.albedo_color = Color(0.22, 0.24, 0.28)
			blade.roughness = 0.18
			blade.emission_enabled = true
			blade.emission = col
			blade.emission_energy_multiplier = 1.0
			blade.emission_texture = _runes()
			guard.albedo_color = Color(0.15, 0.15, 0.17)
			guard.roughness = 0.3
			grip.albedo_color = Color(0.08, 0.07, 0.08)
		4:
			blade.albedo_color = col.lightened(0.5)
			blade.roughness = 0.1
			blade.emission_enabled = true
			blade.emission = col
			blade.emission_energy_multiplier = 1.6
			guard.albedo_color = Color(0.92, 0.88, 0.8)
			guard.roughness = 0.2
			grip.albedo_color = Color(0.85, 0.82, 0.75)
		_:
			blade.albedo_color = Color(0.03, 0.03, 0.04)
			blade.roughness = 0.08
			blade.emission_enabled = true
			blade.emission = col
			blade.emission_energy_multiplier = 3.0
			blade.emission_texture = _edges()
			guard.albedo_color = Color(0.05, 0.05, 0.06)
			guard.roughness = 0.15
			guard.emission_enabled = true
			guard.emission = col
			guard.emission_energy_multiplier = 0.4
			grip.albedo_color = Color(0.04, 0.04, 0.05)
	blade.uv1_triplanar = g == 0
	if g == 0:
		blade.uv1_scale = Vector3.ONE * 3.0
	return [blade, guard, grip, glow]


static func _stain(a: Color, b: Color) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.frequency = 0.03
	n.fractal_octaves = 4
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.2, 0.75])
	g.colors = PackedColorArray([a, b])
	var t := NoiseTexture2D.new()
	t.noise = n
	t.color_ramp = g
	t.seamless = true
	t.width = 256
	t.height = 256
	return t


## 신화: 칼날 위의 빛나는 무늬(잡음의 가는 띠만 남긴다).
static func _runes() -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	n.frequency = 0.05
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.08, 0.16])
	g.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color.BLACK])
	var t := NoiseTexture2D.new()
	t.noise = n
	t.color_ramp = g
	t.width = 128
	t.height = 512
	return t


## 무한: 날(UV 가장자리)만 밝게.
static func _edges() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.12, 0.3, 1.0])
	g.colors = PackedColorArray([Color.WHITE, Color(0.35, 0.35, 0.35), Color.BLACK, Color.BLACK])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 4
	return t


# ---------------------------------------------------------------- 칼날

## 길이를 따라 단면(날이 깎인 육각형)을 이어 붙인다. 너비와 두께는 형태마다 다른 선을 따른다.
## UV: u는 날에서 0, 가운데 등에서 0.5. v는 0(코등이)~1(칼끝).
static func _blade(kind: String, L: float, W: float, m: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var n: int = 14
	var tip: float = {"dagger": 0.32, "longsword": 0.16, "greatsword": 0.12, "rapier": 0.3}.get(kind, 0.16)
	var thick: float = {"dagger": 0.16, "longsword": 0.13, "greatsword": 0.1, "rapier": 0.42}.get(kind, 0.13)
	var rings: Array = []
	for i in n + 1:
		var t: float = float(i) / n
		var w: float = _width(kind, t, tip) * W / 2.0
		var h: float = maxf(0.004, W * thick * (1.0 - t * 0.5)) * (1.0 if t < 1.0 - tip else (1.0 - t) / tip)
		var y: float = 0.02 + t * (L - 0.02)
		rings.append([
			Vector3(-w, y, 0), Vector3(-w * 0.55, y, h), Vector3(w * 0.55, y, h),
			Vector3(w, y, 0), Vector3(w * 0.55, y, -h), Vector3(-w * 0.55, y, -h),
		])
	var us := [0.0, 0.5, 0.5, 0.0, 0.5, 0.5]   # 0 = 날, 0.5 = 등(가운데)
	for i in n:
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		var va: float = float(i) / n
		var vb: float = float(i + 1) / n
		for k in 6:
			var k2: int = (k + 1) % 6
			var u0: float = us[k]
			var u1: float = us[k2]
			_quad(st, a[k], a[k2], b[k2], b[k], Vector2(u0, va), Vector2(u1, va), Vector2(u1, vb), Vector2(u0, vb))
	# 밑동 막기
	var r0: Array = rings[0]
	for k in range(1, 5):
		st.set_uv(Vector2(0.5, 0))
		st.add_vertex(r0[0])
		st.add_vertex(r0[k + 1])
		st.add_vertex(r0[k])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	return mi


## 형태마다 칼날 너비(0~1)를 길이(t)에 따라.
static func _width(kind: String, t: float, tip: float) -> float:
	var body: float
	match kind:
		"dagger":    # 나뭇잎꼴: 가운데가 조금 불룩
			body = 1.0 + 0.3 * sin(PI * minf(1.0, t / (1.0 - tip)) * 0.9)
		"greatsword":   # 넓고 곧게, 밑동은 날을 세우지 않은 좁은 부분
			body = 0.78 if t < 0.1 else 1.0 - t * 0.12
		"rapier":    # 바늘처럼 가늘어진다
			body = 1.0 - t * 0.55
		_:
			body = 1.0 - t * 0.28
	if t > 1.0 - tip:
		var k: float = (t - (1.0 - tip)) / tip
		body *= sqrt(maxf(0.0, 1.0 - k * k)) if kind != "rapier" else (1.0 - k)
	return maxf(0.0, body)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_uv(uc)
	st.add_vertex(c)
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(uc)
	st.add_vertex(c)
	st.set_uv(ud)
	st.add_vertex(d)


## 피홈: 칼날 가운데의 가는 빛줄(전설 이상).
static func _fuller(kind: String, L: float, W: float, m: Material) -> Node3D:
	var n := Node3D.new()
	var len: float = L * (0.55 if kind != "rapier" else 0.4)
	for side in [-1.0, 1.0]:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(maxf(0.006, W * 0.12), len, 0.004)
		b.mesh = bm
		b.material_override = m
		b.position = Vector3(0, 0.06 + len / 2.0, side * W * 0.13 * (2.5 if kind == "rapier" else 1.0))
		n.add_child(b)
	return n


# ---------------------------------------------------------------- 코등이, 손잡이, 자루끝

## 0 곧은 막대, 1 아래로 휜 막대, 2 막대와 가운데 원반, 3 끝이 넓어지는 날개꼴.
func _guard(style: int, w: float, m: Material, glow: Material) -> void:
	match style:
		0:
			_box(Vector3(w, 0.035, 0.045), Vector3(0, 0, 0), m)
			for sx in [-1.0, 1.0]:
				_ball(0.025, Vector3(sx * w / 2.0, 0, 0), m)
		1:   # 가운데 막대와 아래로 꺾인 두 끝
			_box(Vector3(w * 0.62, 0.032, 0.042), Vector3.ZERO, m)
			for sx in [-1.0, 1.0]:
				var tip := _box(Vector3(w * 0.26, 0.03, 0.04), Vector3(sx * w * 0.4, -0.022, 0), m)
				tip.rotation.z = sx * -0.55
		2:
			_box(Vector3(w, 0.03, 0.04), Vector3.ZERO, m)
			var disc := _cyl(0.045, 0.045, 0.03, Vector3.ZERO, m)
			disc.rotation.x = PI / 2.0
		_:
			for sx in [-1.0, 1.0]:
				var wing := _box(Vector3(w * 0.5, 0.03, 0.05), Vector3(sx * w * 0.25, 0.012, 0), m)
				wing.rotation.z = sx * 0.18
				_box(Vector3(0.03, 0.07, 0.06), Vector3(sx * w * 0.5, 0.035, 0), m)
	if grade >= 2:
		var gem := _ball(0.018, Vector3(0, 0, 0.03), glow)
		gem.scale = Vector3(1, 1.3, 0.6)
		var gem2 := _ball(0.018, Vector3(0, 0, -0.03), glow)
		gem2.scale = Vector3(1, 1.3, 0.6)


func _grip(len: float, m: Material) -> void:
	_cyl(0.017, 0.019, len, Vector3(0, -len / 2.0, 0), m)
	var rings: int = int(len / 0.035)
	for i in rings:
		_cyl(0.021, 0.021, 0.008, Vector3(0, -0.02 - i * (len - 0.03) / maxf(1, rings - 1), 0), m)


## 0 공, 1 원반, 2 각진 덩이.
func _pommel(style: int, guard_w: float, m: Material, glow: Material) -> void:
	var y: float = -grip_length - 0.025
	match style:
		0:
			_ball(0.032 + guard_w * 0.03, Vector3(0, y, 0), m)
		1:
			var d := _cyl(0.04, 0.04, 0.025, Vector3(0, y, 0), m)
			d.rotation.x = PI / 2.0
		_:
			var b := _box(Vector3(0.045, 0.05, 0.045), Vector3(0, y, 0), m)
			b.rotation.y = PI / 4.0
	if grade >= 3:
		_ball(0.014, Vector3(0, y - 0.03, 0), glow)


## 초월 이상: 칼날을 따라 피어오르는 빛 알갱이.
func _aura(col: Color, g: int) -> void:
	var p := CPUParticles3D.new()
	p.amount = 18 if g == 4 else 36
	p.lifetime = 0.9
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.02, blade_length * 0.45, 0.01)
	p.position = Vector3(0, blade_length * 0.5, 0)
	p.direction = Vector3(0, 1, 0)
	p.spread = 60.0
	p.gravity = Vector3(0, 0.6, 0)
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.25
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = HitFx._soft_dot()
	q.material = m
	p.mesh = q
	var gr := Gradient.new()
	gr.colors = PackedColorArray([Color(col, 0.0), Color(col.lightened(0.3), 1.0), Color(col, 0.0)])
	gr.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	p.color_ramp = gr
	add_child(p)


func _box(size: Vector3, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = at
	add_child(mi)
	return mi


func _cyl(top: float, bottom: float, h: float, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 10
	c.rings = 1
	mi.mesh = c
	mi.material_override = m
	mi.position = at
	add_child(mi)
	return mi


func _ball(r: float, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 10
	s.rings = 6
	mi.mesh = s
	mi.material_override = m
	mi.position = at
	add_child(mi)
	return mi
