class_name PowerFx
extends Node3D
## 각인과 고유 능력이 낸 일(Rules.effect)을 그린다: 번개, 퍼지는 고리, 땅에서 솟는 검, 하늘에서 떨어지는 거대한 검,
## 떨어질 자리 표시, 그리고 땅에 남는 자리(늪, 불길, 피 웅덩이). 규칙과 상관없는 꾸밈이라 랜덤은 이 노드의 것.

var rules: Rules
var _rng := RandomNumberGenerator.new()
var _zone_views: Array[MeshInstance3D] = []
var _bolt_mat := StandardMaterial3D.new()


func setup(r: Rules) -> void:
	rules = r
	r.effect.connect(_on_effect)


func _ready() -> void:
	_rng.randomize()
	_bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bolt_mat.albedo_color = Color(0.8, 0.9, 1.0)
	_bolt_mat.emission_enabled = true
	_bolt_mat.emission = Color(0.7, 0.85, 1.0)
	_bolt_mat.emission_energy_multiplier = 4.0


func _on_effect(kind: StringName, at: Vector2, info: Dictionary) -> void:
	var p := Grid.cells_to_world(at)
	match kind:
		&"zap":
			var to := Grid.cells_to_world(info.to)
			if at.distance_to(info.to) < 0.05:
				_bolt(to + Vector3(0, 14, 0), to + Vector3(0, 0.5, 0), 0.12)
			else:
				_bolt(p + Vector3(0, 1.2, 0), to + Vector3(0, 1.0, 0), 0.06)
		&"ring":
			_ring(p, Grid.cells_to_meters(info.radius), info.get("color", Color.WHITE), 0.45)
		&"spike":
			_spike(p)
		&"fall_warn":
			_ring(p, Grid.cells_to_meters(info.radius), Color(1.0, 0.25, 0.2), 0.45, true)
		&"fall":
			_fall(p, Grid.cells_to_meters(info.radius))


## 지그재그 번개 한 줄기(짧게 남는다).
func _bolt(a: Vector3, b: Vector3, width: float) -> void:
	var n: int = 7
	var pts: Array[Vector3] = [a]
	for i in range(1, n):
		var t: float = float(i) / n
		var j: float = a.distance_to(b) * 0.06
		pts.append(a.lerp(b, t) + Vector3(_rng.randf_range(-j, j), _rng.randf_range(-j, j), _rng.randf_range(-j, j)))
	pts.append(b)
	var root := Node3D.new()
	add_child(root)
	for i in pts.size() - 1:
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(width, width, pts[i].distance_to(pts[i + 1]))
		seg.mesh = bm
		seg.material_override = _bolt_mat
		root.add_child(seg)
		seg.look_at_from_position((pts[i] + pts[i + 1]) / 2.0, pts[i + 1], Vector3.UP if absf((pts[i + 1] - pts[i]).normalized().y) < 0.99 else Vector3.RIGHT)
	var light := OmniLight3D.new()
	light.light_color = Color(0.7, 0.85, 1.0)
	light.light_energy = 1.0
	light.omni_range = 5.0
	light.position = b
	root.add_child(light)
	var tw := create_tween()
	tw.tween_interval(0.12)
	tw.tween_callback(root.queue_free)


## 땅에 퍼지는 고리. warn이면 퍼지지 않고 깜빡이며 자리만 보인다.
func _ring(at: Vector3, radius: float, col: Color, time: float, warn: bool = false) -> void:
	var m := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.92
	tm.outer_radius = 1.0
	tm.rings = 32
	m.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(col, 0.9)
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 2.0
	m.material_override = mat
	m.position = at + Vector3(0, 0.08, 0)
	m.scale = Vector3(radius, 0.4, radius) * (1.0 if warn else 0.2)
	add_child(m)
	var tw := create_tween()
	if not warn:
		tw.set_parallel(true)
		tw.tween_property(m, "scale", Vector3(radius, 0.4, radius), time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(mat, "albedo_color:a", 0.0, time)
		tw.chain().tween_callback(m.queue_free)
	else:
		tw.tween_property(mat, "albedo_color:a", 0.2, time / 3.0)
		tw.tween_property(mat, "albedo_color:a", 0.9, time / 3.0)
		tw.tween_property(mat, "albedo_color:a", 0.0, time / 3.0)
		tw.tween_callback(m.queue_free)


## 언덕의 심장: 땅에서 검이 솟았다가 들어간다.
func _spike(at: Vector3) -> void:
	var s := SwordModel.make(rules.data.forms[_rng.randi() % rules.data.forms.size()], 0, _rng.randi(), Color.WHITE)
	s.position = at + Vector3(0, -1.6, 0)
	s.rotation = Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf() * TAU, 0)
	add_child(s)
	var tw := create_tween()
	tw.tween_property(s, "position:y", 0.3, 0.08).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.2)
	tw.tween_property(s, "position:y", -1.8, 0.2)
	tw.tween_callback(s.queue_free)


## 떨어진 검: 하늘에서 거대한 검이 꽂히고 고리가 퍼진다. 잠시 꽂혀 있다가 가라앉는다.
func _fall(at: Vector3, radius: float) -> void:
	var s := SwordModel.make(rules.data.forms[2], 4, _rng.randi(), Color(0.85, 0.95, 1.0))
	s.scale = Vector3.ONE * 4.0
	s.rotation.x = PI
	s.position = at + Vector3(0, 30, 0)
	add_child(s)
	var tw := create_tween()
	tw.tween_property(s, "position:y", 3.0, 0.12).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: _ring(at, radius, Color(0.9, 0.95, 1.0), 0.5))
	tw.tween_interval(1.2)
	tw.tween_property(s, "position:y", -6.0, 0.6)
	tw.tween_callback(s.queue_free)


## 땅에 남는 자리를 규칙의 zones와 맞춘다(매 화면).
func _process(_delta: float) -> void:
	if rules == null:
		return
	var zones: Array[Dictionary] = rules.powers.zones
	while _zone_views.size() < zones.size():
		var m := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 1.0
		c.bottom_radius = 1.0
		c.height = 0.03
		c.radial_segments = 24
		m.mesh = c
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.2
		m.material_override = mat
		m.add_child(_flames())
		add_child(m)
		_zone_views.append(m)
	for i in _zone_views.size():
		var m := _zone_views[i]
		m.visible = i < zones.size()
		if not m.visible:
			continue
		var z: Dictionary = zones[i]
		var r: float = Grid.cells_to_meters(z.radius)
		m.position = Grid.cells_to_world(z.pos, 0.04 + 0.002 * i)
		m.scale = Vector3(r, 1, r)
		var mat := m.material_override as StandardMaterial3D
		var a: float = clampf(z.t / maxf(0.01, z.time) * 2.0, 0.0, 1.0)
		(m.get_child(0) as CPUParticles3D).emitting = z.kind == &"fire"
		match z.kind:
			&"swamp":
				mat.albedo_color = Color(0.12, 0.16, 0.08, 0.75 * a)
				mat.emission_enabled = false
			&"fire":
				mat.albedo_color = Color(0.35, 0.08, 0.02, 0.55 * a)
				mat.emission_enabled = true
				mat.emission = Color(0.9, 0.28, 0.05)
				mat.emission_energy_multiplier = (0.6 + sin(Time.get_ticks_msec() * 0.02 + i) * 0.2) * a
			_:
				mat.albedo_color = Color(0.3, 0.01, 0.02, 0.8 * a)
				mat.emission_enabled = false


## 불길 자리 위로 오르는 불꽃(지름 1인 판 기준, 판의 크기를 따라 커진다).
func _flames() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 24
	p.lifetime = 0.6
	p.emitting = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.8
	p.direction = Vector3.UP
	p.spread = 15.0
	p.gravity = Vector3(0, 2.0, 0)
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.35, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = HitFx._soft_dot()
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1.0, 0.75, 0.3, 0.0), Color(1.0, 0.5, 0.12, 0.9), Color(0.6, 0.12, 0.02, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	p.color_ramp = g
	return p
