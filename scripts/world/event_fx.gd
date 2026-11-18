class_name EventFx
extends NightFx
## 13단계 낮 사건의 효과(모양팀, docs/content.md "13단계"). NightFx의 도구(알갱이·땅 판·빛·소리 묶음)를 물려받는다.
## 밤 신호는 잇지 않는다(setup이 아무것도 잇지 않는다). 따로 하나 만들어 쓴다.
##   aura(node)        저주받은 손잡이의 검은 기운: 손잡이에서 검은 연기가 감기며 오르고, 둘레의 티끌이 안으로 끌려들고,
##                     땅에 검은 얼룩과 검붉은 점, 아주 어두운 붉은 빛. node를 따라간다.
##   aura_off(node)    기운이 걷힌다(burst면 검은 연기가 한 번 터져 흩어지고 낮은 울림)
##   used(P)           사건 형체가 쓰일 때(P = EventArt.build가 돌려준 것):
##                       대장장이 = 망치를 두 번 내리쳐 모루에서 불똥, 쇳소리, 짧은 불빛
##                       순례자 = 고개 숙여 절하고, 발밑에 먼지 고리와 따뜻한 티끌이 천천히 떠오른다
##                       점쟁이 = 등불을 들어 올리면 불이 커졌다 잦아들고, 등불에서 연기가 감겨 오른다
##   vanish(P)         형체가 사라진다: 해진 천이 흩어지고(망토 셰이더 fade), 몸이 옅어지며, 재와 먼지가 바람에 날린다.
##                     끝나면 root를 숨기고(free면 queue_free) vanished 신호를 낸다.
## 어두운 사실풍. 소리는 내려가거나 고른 음과 잡음만(종소리 없음: 모루 소리도 빨리 죽는 둔한 쇳소리다).
##
## main(기능팀)이 쓰는 법:
##   var efx := EventFx.new(); add_child(efx)
##   사건이 서면: var P := EventArt.build(kind, holder); _process에서 EventArt.breathe(P, 시간)
##   저주받은 손잡이: EventArt.curse_hilt(hilt_view); efx.aura(hilt_view)   → 뽑을 때 efx.aura_off(hilt_view)
##   E로 쓰면: efx.used(P)   → 그 뒤 사라지게: efx.vanish(P)   (used 연출은 약 1초. 바로 vanish를 불러도 된다: vanish가 used_time만큼 기다린다)
##   낮이 끝나면 efx.clear()

signal vanished(parts: Dictionary)

## used 다음에 vanish를 부르면 이만큼 기다렸다가 사라진다(초).
@export var used_time: float = 1.0
## 사라지는 데 걸리는 시간(초).
@export var vanish_time: float = 1.4

## 기운: 노드 instance id → job
var _auras: Dictionary = {}
## 형체 root instance id → used가 끝나는 시각(_clock)
var _busy: Dictionary = {}


func setup(_r: Rules) -> void:
	_build()


func clear() -> void:
	_auras.clear()
	_busy.clear()
	super.clear()


# ---------------------------------------------------------------- 저주받은 손잡이

## 손잡이(node)에 검은 기운을 두른다. height = 손잡이 끝 높이(m, 땅에서). 이미 있으면 그대로 둔다.
func aura(node: Node3D, height: float = 1.1) -> void:
	_build()
	if node == null:
		return
	var key: int = node.get_instance_id()
	if _auras.has(key):
		return
	var emits: Array = []
	# 검은 연기: 손잡이를 따라 감기며 오른다(빛을 받지 않는 검은 조각이라 낮에 또렷하고 밤에는 붉은 점과 빛으로 읽힌다)
	var wisp := _emitter(true)
	if wisp != null:
		wisp.amount = 16
		wisp.lifetime = 2.2
		wisp.explosiveness = 0.0
		wisp.randomness = 0.5
		wisp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		wisp.emission_sphere_radius = 0.18
		wisp.direction = Vector3.UP
		wisp.spread = 12.0
		wisp.initial_velocity_min = 0.35
		wisp.initial_velocity_max = 0.7
		wisp.gravity = Vector3(0.0, 0.25, 0.0)
		wisp.damping_min = 0.1
		wisp.damping_max = 0.3
		wisp.tangential_accel_min = 0.6
		wisp.tangential_accel_max = 1.2
		wisp.radial_accel_min = -0.4
		wisp.radial_accel_max = -0.1
		wisp.angle_min = -180.0
		wisp.angle_max = 180.0
		wisp.angular_velocity_min = -60.0
		wisp.angular_velocity_max = 60.0
		_curve3(wisp, 0.3, 0.8, 1.3)
		_ramp(wisp, [Color(0.01, 0.008, 0.008, 0.0), Color(0.012, 0.009, 0.009, 0.7), Color(0.02, 0.012, 0.012, 0.45), Color(0.02, 0.015, 0.015, 0.0)], [0.0, 0.15, 0.6, 1.0])
		wisp.mesh = _quad(0.55, Q_FIRE)
		wisp.emitting = true
		emits.append(wisp)
	# 안으로 끌려드는 티끌(땅에서 손잡이 쪽으로)
	var pull := _emitter(true)
	if pull != null:
		pull.amount = 14
		pull.lifetime = 1.6
		pull.explosiveness = 0.0
		pull.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		pull.emission_ring_axis = Vector3.UP
		pull.emission_ring_radius = 1.4
		pull.emission_ring_inner_radius = 1.0
		pull.emission_ring_height = 0.1
		pull.direction = Vector3.UP
		pull.spread = 10.0
		pull.initial_velocity_min = 0.1
		pull.initial_velocity_max = 0.3
		pull.gravity = Vector3(0.0, 0.3, 0.0)
		pull.radial_accel_min = -2.2
		pull.radial_accel_max = -1.4
		pull.angle_min = -180.0
		pull.angle_max = 180.0
		_curve(pull, 1.0, 0.3)
		_ramp(pull, [Color(0.03, 0.025, 0.022, 0.0), Color(0.03, 0.025, 0.022, 0.55), Color(0.03, 0.025, 0.022, 0.0)], [0.0, 0.3, 1.0])
		pull.mesh = _quad(0.22, Q_LIT)
		pull.emitting = true
		emits.append(pull)
	# 검붉은 점(불씨가 아니라 식은 피 같은 빛): 손잡이 둘레에서 천천히 오르다 꺼진다
	var motes := _emitter(true)
	if motes != null:
		motes.amount = 6
		motes.lifetime = 2.0
		motes.explosiveness = 0.0
		motes.randomness = 0.7
		motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		motes.emission_sphere_radius = 0.35
		motes.direction = Vector3.UP
		motes.spread = 20.0
		motes.initial_velocity_min = 0.15
		motes.initial_velocity_max = 0.4
		motes.gravity = Vector3(0.0, 0.1, 0.0)
		motes.tangential_accel_min = -0.5
		motes.tangential_accel_max = 0.5
		_ramp(motes, [Color(0.5, 0.04, 0.02, 0.0), Color(0.75, 0.06, 0.03, 0.9), Color(0.3, 0.02, 0.01, 0.0)], [0.0, 0.3, 1.0])
		motes.mesh = _quad(0.04, Q_ADD)
		motes.emitting = true
		emits.append(motes)
	var stain := _decal(2)
	if not stain.is_empty():
		_put(stain, {"fill": 0.0, "color": Color(0.012, 0.01, 0.01), "hot": Color(0.5, 0.04, 0.02), "energy": 0.8, "emit": 1.2})
	var l := OmniLight3D.new()
	l.light_color = Color(0.6, 0.06, 0.03)
	l.light_energy = 0.0
	l.omni_range = 2.6
	l.omni_attenuation = 1.6
	l.shadow_enabled = false
	_layer.add_child(l)
	var j := _job(_run_aura, {"node_ref": weakref(node), "key": key, "emit": emits, "decal": stain, "nodes": [l], "light": l,
		"height": height, "out": -1.0, "burst": false, "yaw": _rng.randf() * TAU})
	_auras[key] = j
	_run_aura(j, 0.0)


## 기운을 걷는다. burst면 검은 연기가 터져 흩어지고 낮은 울림(뽑았을 때).
func aura_off(node: Node3D, burst: bool = true) -> void:
	if node == null:
		return
	var key: int = node.get_instance_id()
	if not _auras.has(key):
		return
	var j: Dictionary = _auras[key]
	_auras.erase(key)
	if float(j["out"]) >= 0.0:
		return
	j["out"] = float(j["t"])
	for e: Variant in j.get("emit", []):
		if e is CPUParticles3D:
			_release(e)
	j["emit"] = []
	if burst:
		var at: Vector3 = j.get("at", Vector3.ZERO)
		var p := _emitter()
		if p != null:
			p.amount = 16
			p.lifetime = 1.4
			p.explosiveness = 0.95
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = 0.3
			p.direction = Vector3(1.0, 0.4, 0.0)
			p.spread = 180.0
			p.flatness = 0.4
			p.initial_velocity_min = 1.5
			p.initial_velocity_max = 3.5
			p.damping_min = 2.0
			p.damping_max = 3.5
			p.gravity = Vector3(0.0, 0.5, 0.0)
			p.angle_min = -180.0
			p.angle_max = 180.0
			_curve(p, 0.6, 1.8)
			_ramp(p, [Color(0.012, 0.01, 0.01, 0.8), Color(0.02, 0.015, 0.015, 0.0)], [0.0, 1.0])
			p.mesh = _quad(0.9, Q_FIRE)
			_fire(p, at + Vector3(0.0, 0.7, 0.0))
		_dust(at, 14, 3.0, 0.5, 1.0)
		_play(&"curse_off", at + Vector3(0.0, 0.8, 0.0), -3.0)


func _run_aura(j: Dictionary, dt: float) -> bool:
	var n: Variant = (j["node_ref"] as WeakRef).get_ref()
	var at: Vector3 = j.get("at", Vector3.ZERO)
	if n is Node3D and (n as Node3D).is_inside_tree():
		var p: Vector3 = (n as Node3D).global_position
		at = Vector3(p.x, HillBuilder.height(p.x, p.z), p.z)
		j["at"] = at
	elif float(j["out"]) < 0.0:
		_auras.erase(j["key"])
		j["out"] = float(j["t"])
		for e: Variant in j.get("emit", []):
			if e is CPUParticles3D:
				_release(e)
		j["emit"] = []
	var h: float = j["height"]
	for e: Variant in j.get("emit", []):
		if e is CPUParticles3D:
			var c: CPUParticles3D = e
			c.position = at + Vector3(0.0, h * (0.45 if c.emission_shape == CPUParticles3D.EMISSION_SHAPE_SPHERE else 0.02), 0.0)
	var t: float = j["t"]
	var out: float = j["out"]
	var k: float = clampf(t / 0.8, 0.0, 1.0)
	if out >= 0.0:
		k *= 1.0 - clampf((t - out) / 0.7, 0.0, 1.0)
	var d: Dictionary = j["decal"]
	if not d.is_empty():
		(d["mi"] as MeshInstance3D).transform = Transform3D(Basis(Vector3.UP, float(j["yaw"])).scaled(Vector3(2.6, 1.0, 2.6)), at + Vector3(0.0, 0.028, 0.0))
		_put(d, {"fill": 0.85 * k})
	var l: OmniLight3D = j["light"]
	if is_instance_valid(l):
		l.position = at + Vector3(0.0, h * 0.6, 0.0)
		l.light_energy = 0.45 * k * (0.75 + 0.25 * sin(t * 1.4))
	return out < 0.0 or t - out < 0.75


# ---------------------------------------------------------------- 쓰일 때

## 사건 형체가 쓰였다. P = EventArt.build가 돌려준 것.
func used(P: Dictionary) -> void:
	_build()
	if P.is_empty() or not is_instance_valid(P.get("root")):
		return
	var root: Node3D = P.root
	_busy[root.get_instance_id()] = _clock + used_time
	var feet: Vector3 = root.global_position
	match StringName(P.get("kind", &"")):
		&"smith":
			_job(_run_smith, {"P": P, "hits": 0})
		&"pilgrim":
			_job(_run_pilgrim, {"P": P})
			_dust(feet, 16, 2.2, 0.5, 1.2)
			_ring(feet, 2.4, 0.6)
			var p := _emitter()
			if p != null:
				p.amount = 14
				p.lifetime = 2.2
				p.explosiveness = 0.6
				p.randomness = 0.5
				p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
				p.emission_ring_axis = Vector3.UP
				p.emission_ring_radius = 0.9
				p.emission_ring_inner_radius = 0.3
				p.emission_ring_height = 0.2
				p.direction = Vector3.UP
				p.spread = 15.0
				p.initial_velocity_min = 0.3
				p.initial_velocity_max = 0.7
				p.gravity = Vector3(0.0, 0.15, 0.0)
				p.tangential_accel_min = -0.4
				p.tangential_accel_max = 0.4
				_ramp(p, [Color(1.2, 0.8, 0.45, 0.0), Color(1.1, 0.72, 0.4, 0.7), Color(0.6, 0.35, 0.15, 0.0)], [0.0, 0.3, 1.0])
				p.mesh = _quad(0.035, Q_ADD)
				_fire(p, feet + Vector3(0.0, 0.2, 0.0))
			_light(feet + Vector3(0.0, 1.2, 0.0), Color(1.0, 0.7, 0.42), 1.4, 4.5, 1.2)
			_play(&"pilgrim_use", feet + Vector3(0.0, 1.0, 0.0), -4.0)
		&"seer":
			_job(_run_seer, {"P": P})
			_play(&"seer_use", _focus(P), -4.0)
		_:
			_dust(feet, 14, 2.0, 0.5, 1.0)


func _run_smith(j: Dictionary, _dt: float) -> bool:
	var P: Dictionary = j["P"]
	if not is_instance_valid(P.get("root")):
		return false
	var t: float = j["t"]
	var arm: Node3D = (P.get("arms", []) as Array)[1] if (P.get("arms", []) as Array).size() > 1 else null
	var fore: Node3D = (P.get("forearms", []) as Array)[1] if (P.get("forearms", []) as Array).size() > 1 else null
	var rest: Dictionary = P.get("rest", {})
	# 두 번 내리친다: 0.0~0.45, 0.45~0.9(들어 올렸다가 빠르게 내리친다). 내리친 순간에 불똥
	var beat: float = 0.45
	var k: float = fmod(t, beat) / beat
	var lift: float = 0.0
	if t < beat * 2.0:
		lift = sin(clampf(k / 0.7, 0.0, 1.0) * PI * 0.5) if k < 0.7 else 1.0 - pow((k - 0.7) / 0.3, 2.0)
		lift = clampf(lift, 0.0, 1.0)
	if arm and rest.has(arm):
		arm.transform = Transform3D((rest[arm] as Transform3D).basis * Basis.from_euler(Vector3(1.6 * lift, 0.0, -0.25 * lift)), (rest[arm] as Transform3D).origin)
	if fore and rest.has(fore):
		fore.transform = Transform3D((rest[fore] as Transform3D).basis * Basis.from_euler(Vector3(0.4 * lift, 0.0, 0.0)), (rest[fore] as Transform3D).origin)
	var hits: int = j["hits"]
	if hits < 2 and t >= beat * (float(hits) + 0.98):
		j["hits"] = hits + 1
		var at: Vector3 = _focus(P)
		var side: Vector3 = ((P.root as Node3D).global_basis * Vector3(1.0, 0.0, 0.0)).normalized()
		_sparks(at, 16, Vector3.UP + side * 0.3, 70.0, 2.5, 6.0, SPARK, 0.6)
		_sparks(at, 8, side + Vector3(0.0, 0.3, 0.0), 40.0, 3.0, 7.0, SPARK, 0.4)
		_light(at + Vector3(0.0, 0.25, 0.0), Color(1.0, 0.6, 0.3), 2.6, 4.0, 0.3)
		_play(&"smith_use", at, -2.0, 1.0 if hits == 0 else 0.94)
	if t >= beat * 2.0 + 0.2:
		if arm and rest.has(arm):
			arm.transform = rest[arm]
		if fore and rest.has(fore):
			fore.transform = rest[fore]
		return false
	return true


func _run_pilgrim(j: Dictionary, _dt: float) -> bool:
	var P: Dictionary = j["P"]
	if not is_instance_valid(P.get("root")):
		return false
	var t: float = j["t"]
	var torso: Node3D = P.get("torso")
	var rest: Dictionary = P.get("rest", {})
	# 천천히 고개 숙여 절한다(0.35초 숙이고 0.3초 머물고 0.35초 편다). breathe가 다시 rest에서 시작한다
	var k: float = 0.0
	if t < 0.35:
		k = smoothstep(0.0, 0.35, t)
	elif t < 0.65:
		k = 1.0
	else:
		k = 1.0 - smoothstep(0.65, 1.0, t)
	if torso and rest.has(torso):
		var r: Transform3D = rest[torso]
		torso.transform = Transform3D(r.basis * Basis.from_euler(Vector3(-0.38 * k, 0.0, 0.0)), r.origin)
		P["bow"] = k
	return t < 1.0


func _run_seer(j: Dictionary, _dt: float) -> bool:
	var P: Dictionary = j["P"]
	if not is_instance_valid(P.get("root")):
		return false
	var t: float = j["t"]
	var arm: Node3D = (P.get("arms", []) as Array)[0] if (P.get("arms", []) as Array).size() > 0 else null
	var rest: Dictionary = P.get("rest", {})
	# 등불을 들어 올리고(0.3초) 불이 커졌다가 잦아든다. 등불에서 연기가 감겨 오른다
	var k: float = smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.75, 1.1, t))
	if arm and rest.has(arm):
		var r: Transform3D = rest[arm]
		arm.transform = Transform3D(r.basis * Basis.from_euler(Vector3(0.45 * k, 0.0, 0.0)), r.origin)
	P["light_k"] = 1.0 + 2.2 * k
	for g: StandardMaterial3D in P.get("glow", []):
		g.emission_energy_multiplier = float(g.get_meta("base_energy", 1.0)) * (1.0 + 1.5 * k)
	if not bool(j.get("smoke", false)) and t > 0.25:
		j["smoke"] = true
		var at: Vector3 = _focus(P)
		var p := _emitter()
		if p != null:
			p.amount = 10
			p.lifetime = 2.0
			p.explosiveness = 0.5
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = 0.05
			p.direction = Vector3.UP
			p.spread = 15.0
			p.initial_velocity_min = 0.4
			p.initial_velocity_max = 0.8
			p.gravity = Vector3(0.0, 0.2, 0.0)
			p.tangential_accel_min = 0.8
			p.tangential_accel_max = 1.5
			p.angle_min = -180.0
			p.angle_max = 180.0
			_curve(p, 0.3, 1.6)
			_ramp(p, [Color(SMOKE, 0.0), Color(SMOKE.lightened(0.1), 0.45), Color(SMOKE, 0.0)], [0.0, 0.2, 1.0])
			p.mesh = _quad(0.5, Q_LIT)
			_fire(p, at + Vector3(0.0, -0.08, 0.0))
		_embers_up(at + Vector3(0.0, -0.2, 0.0), 6, 0.06, 1.2)
	if t >= 1.2:
		P["light_k"] = 1.0
		for g: StandardMaterial3D in P.get("glow", []):
			g.emission_energy_multiplier = float(g.get_meta("base_energy", 1.0))
		if arm and rest.has(arm):
			arm.transform = rest[arm]
		return false
	return true


# ---------------------------------------------------------------- 사라질 때

## 형체가 사라진다(time초). used가 아직 도는 중이면 끝날 때까지 기다린다. free면 끝에 root를 queue_free한다.
func vanish(P: Dictionary, free: bool = true) -> void:
	_build()
	if P.is_empty() or not is_instance_valid(P.get("root")):
		return
	var root: Node3D = P.root
	var wait: float = maxf(0.0, float(_busy.get(root.get_instance_id(), 0.0)) - _clock)
	_job(_run_vanish, {"P": P, "wait": wait, "free": free, "started": false})


func _run_vanish(j: Dictionary, _dt: float) -> bool:
	var P: Dictionary = j["P"]
	var root: Variant = P.get("root")
	if not is_instance_valid(root):
		return false
	var t: float = float(j["t"]) - float(j["wait"])
	if t < 0.0:
		return true
	var T: float = maxf(0.2, vanish_time)
	var r3: Node3D = root
	if not bool(j["started"]):
		j["started"] = true
		for m: StandardMaterial3D in P.get("mats", []):
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		for m: StandardMaterial3D in P.get("glow", []):
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var feet: Vector3 = r3.global_position
		var h: float = float(P.get("height", 1.8))
		var p := _emitter()
		if p != null:
			p.amount = 26
			p.lifetime = 1.8
			p.explosiveness = 0.25
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			p.emission_box_extents = Vector3(0.3, h * 0.45, 0.25)
			p.direction = Vector3(0.6, 1.0, 0.2)
			p.spread = 30.0
			p.initial_velocity_min = 0.5
			p.initial_velocity_max = 1.3
			p.gravity = Vector3(0.6, 0.3, 0.15)
			p.angle_min = -180.0
			p.angle_max = 180.0
			p.angular_velocity_min = -50.0
			p.angular_velocity_max = 50.0
			_curve(p, 0.4, 1.5)
			_ramp(p, [Color(ASH_C, 0.0), Color(ASH_C, 0.55), Color(ASH_C, 0.0)], [0.0, 0.25, 1.0])
			p.mesh = _quad(0.45, Q_LIT)
			_fire(p, feet + Vector3(0.0, h * 0.5, 0.0))
		_dust(feet, 14, 2.4, 0.5, 1.2)
		_play(&"event_vanish", feet + Vector3(0.0, 1.0, 0.0), -5.0)
	var k: float = clampf(t / T, 0.0, 1.0)
	var a: float = 1.0 - k * k * (3.0 - 2.0 * k)
	for m: StandardMaterial3D in P.get("mats", []):
		m.albedo_color.a = a
	for m: StandardMaterial3D in P.get("glow", []):
		m.albedo_color.a = minf(m.albedo_color.a, a)
		m.emission_energy_multiplier = float(m.get_meta("base_energy", 1.0)) * a
	for m: ShaderMaterial in P.get("cloaks", []):
		m.set_shader_parameter("fade", a)
	P["light_k"] = a
	var l: Variant = P.get("light")
	if l is OmniLight3D:
		(l as OmniLight3D).light_energy = float((l as OmniLight3D).get_meta("base_energy", 1.0)) * a
	# 형체가 조금 가라앉으며 흩어진다
	r3.position.y = -0.08 * k
	if k >= 1.0:
		r3.visible = false
		_busy.erase(r3.get_instance_id())
		vanished.emit(P)
		if bool(j["free"]):
			r3.queue_free()
		return false
	return true


# ---------------------------------------------------------------- 도움

const ASH_C := Color(0.3, 0.28, 0.26)


## 쓰일 때 효과가 나는 곳(세계 좌표). focus가 없으면 가슴 높이.
func _focus(P: Dictionary) -> Vector3:
	var f: Variant = P.get("focus")
	if f is Node3D and (f as Node3D).is_inside_tree():
		return (f as Node3D).global_position
	var r: Node3D = P.get("root")
	return r.global_position + Vector3(0.0, 1.2, 0.0)


## 땅의 먼지 고리 한 번(radius m까지 퍼진다).
func _ring(at: Vector3, radius: float, time: float) -> void:
	var d := _decal(3)
	if d.is_empty():
		return
	_put(d, {"fill": 0.05, "color": DUST, "emit": 0.0})
	(d["mi"] as MeshInstance3D).transform = Transform3D(Basis.from_scale(Vector3.ONE * radius * 2.0), at + Vector3(0.0, 0.04, 0.0))
	_job(_run_dust_ring, {"decal": d, "time": time})


func _run_dust_ring(j: Dictionary, _dt: float) -> bool:
	var k: float = float(j["t"]) / float(j["time"])
	if k >= 1.0:
		return false
	_put(j["decal"], {"fill": 0.05 + 0.95 * (1.0 - pow(1.0 - k, 2.0))})
	return true
