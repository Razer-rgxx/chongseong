class_name LandmarkView
extends Node3D
## 들판 구조물(2026-11-24, docs/landmarks.md)의 움직이는 부분: 풍차 날개, 물레방아 바퀴, 흔들다리, 상인 행렬(수레 넷·호위 셋).
## 규칙과 상관없는 화면이다. 위치는 들판 시계(Caravan)에서만 나오고, 꾸밈 흔들림만 자기 시간(_t)을 쓴다.

var wind_hub: Node3D
var mill_wheel: Node3D
var bridge: Node3D
var _t: float = 0.0
var _carts: Array[Node3D] = []
var _escorts: Array[Node3D] = []
var _lamp: OmniLight3D
var _creak: AudioStreamPlayer3D
var _trade: Variant = null
static var _creak_stream_cache: AudioStreamWAV


func _ready() -> void:
	_build_caravan()
	_creak = AudioStreamPlayer3D.new()
	_creak.stream = _creak_stream()
	_creak.volume_db = -8.0
	_creak.unit_size = 7.0
	_creak.max_distance = 60.0
	add_child(_creak)
	_creak.play()
	_creak.stream_paused = true


## 맨 뒤 수레의 자리(칸). 길 위에 없으면 null. E로 물건을 사는 자리다.
func trade_cell() -> Variant:
	return _trade


func update(clock: float, weather: StringName, delta: float) -> void:
	_t += delta
	if wind_hub:
		wind_hub.rotation.x += delta * FieldLayout.WINDMILL_SPEED * float(FieldLayout.WINDMILL_WIND.get(weather, 1.0))
	if mill_wheel:
		mill_wheel.rotation.z -= delta * FieldLayout.WATERMILL_SPEED
	if bridge:
		bridge.rotation.x = 0.03 * sin(_t * 1.1) + 0.012 * sin(_t * 2.7)
	var mid := Vector2.ZERO
	var movers: int = 0
	_trade = null
	for i in _carts.size():
		var p: Dictionary = Caravan.place(clock, float(i))
		_carts[i].visible = bool(p.on)
		if not bool(p.on):
			continue
		_pose(_carts[i], p, 0.0)
		for wh in _carts[i].get_meta("wheels"):
			(wh as Node3D).rotation.x = -float(p.roll) / 0.55
		var swing: float = sin(float(p.roll) * 1.6) * 0.4 if bool(p.moving) else 0.0
		var legs: Array = _carts[i].get_meta("legs")
		for k in legs.size():
			(legs[k] as Node3D).rotation.x = swing * (1.0 if k % 2 == 0 else -1.0)
		if bool(p.moving):
			mid += p.pos
			movers += 1
		if i == _carts.size() - 1:
			_trade = (p.pos as Vector2) / Grid.CELL
	for e in _escorts.size():
		var spec: Vector2 = FieldLayout.CARAVAN_ESCORTS[e]
		var p: Dictionary = Caravan.place(clock, spec.x, spec.y * 1.9)
		_escorts[e].visible = bool(p.on)
		if bool(p.on):
			_pose(_escorts[e], p, 0.0)
			if bool(p.moving):
				_escorts[e].position.y += absf(sin(float(p.roll) * 1.9)) * 0.08
	if _lamp:
		_lamp.light_energy = lerpf(0.4, 1.3, FieldLayout.night_amount(clock))
	if movers > 0:
		mid /= movers
		_creak.position = Vector3(mid.x, FieldBuilder.walk_height(mid.x, mid.y) + 1.0, mid.y)
		_creak.stream_paused = false
	else:
		_creak.stream_paused = true


func _pose(n: Node3D, p: Dictionary, lift: float) -> void:
	var at: Vector2 = p.pos
	var yaw: float = p.yaw
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var f: Vector2 = at + fwd * 1.5
	var b: Vector2 = at - fwd * 1.5
	var hf: float = FieldBuilder.walk_height(f.x, f.y)
	var hb: float = FieldBuilder.walk_height(b.x, b.y)
	n.position = Vector3(at.x, (hf + hb) / 2.0 + lift, at.y)
	n.rotation = Vector3(atan2(hf - hb, 3.0), yaw, 0.0)


func _build_caravan() -> void:
	for i in FieldLayout.CARAVAN_CARTS:
		var cart := _cart(i)
		add_child(cart)
		cart.visible = false
		_carts.append(cart)
	for e in FieldLayout.CARAVAN_ESCORTS.size():
		var g := _guard(e == 0)
		add_child(g)
		g.visible = false
		_escorts.append(g)


func _m(parent: Node3D, mesh: Mesh, m: Material, at: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return Landmarks._put(parent, mesh, m, at, rot, 220.0)


func _cart(i: int) -> Node3D:
	var wood: Material = FieldBuilder._wood()
	var iron: Material = FieldBuilder._mat("iron", Color(0.14, 0.14, 0.15), 0.6, 0.6)
	var hide: Material = FieldBuilder._mat("ox", Color(0.2, 0.15, 0.11))
	var cloth: Material = FieldBuilder._mat("cloth", Color(0.36, 0.3, 0.2))
	var n := Node3D.new()
	_m(n, Landmarks._bm(Vector3(1.8, 0.25, 3.2)), wood, Vector3(0, 0.95, 0))
	for s in [-1.0, 1.0]:
		_m(n, Landmarks._bm(Vector3(0.1, 0.5, 3.2)), wood, Vector3(0.85 * s, 1.3, 0))
	_m(n, Landmarks._bm(Vector3(1.8, 0.5, 0.1)), wood, Vector3(0, 1.3, 1.55))
	if i % 2 == 0:
		_m(n, Landmarks._bm(Vector3(1.7, 1.1, 2.9)), cloth, Vector3(0, 1.95, 0))
		_m(n, Landmarks._bm(Vector3(1.2, 0.3, 2.7)), cloth, Vector3(0, 2.6, 0))
	else:
		_m(n, Landmarks._bm(Vector3(0.9, 0.7, 0.9)), wood, Vector3(-0.4, 1.55, -0.7))
		_m(n, Landmarks._bm(Vector3(0.8, 0.6, 0.8)), wood, Vector3(0.4, 1.5, 0.6))
		var bar := CylinderMesh.new()
		bar.top_radius = 0.38
		bar.bottom_radius = 0.38
		bar.height = 0.9
		bar.radial_segments = 8
		_m(n, bar, wood, Vector3(0.35, 1.6, -0.8))
	var wheels: Array = []
	var rim := CylinderMesh.new()
	rim.top_radius = 0.55
	rim.bottom_radius = 0.55
	rim.height = 0.12
	rim.radial_segments = 12
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var w := Node3D.new()
			w.position = Vector3(1.0 * sx, 0.55, 1.0 * sz)
			n.add_child(w)
			_m(w, rim, wood, Vector3.ZERO, Vector3(0, 0, PI / 2.0))
			_m(w, Landmarks._bm(Vector3(0.14, 1.0, 0.09)), iron, Vector3.ZERO)
			_m(w, Landmarks._bm(Vector3(0.14, 0.09, 1.0)), iron, Vector3.ZERO)
			wheels.append(w)
	n.set_meta("wheels", wheels)
	# 소(수레 앞): 몸, 머리, 뿔, 다리 넷
	_m(n, Landmarks._bm(Vector3(0.08, 0.1, 2.2)), wood, Vector3(0, 0.9, -2.6))
	var ox := Node3D.new()
	ox.position = Vector3(0, 0, -3.9)
	n.add_child(ox)
	_m(ox, Landmarks._bm(Vector3(0.9, 0.85, 1.9)), hide, Vector3(0, 1.25, 0))
	_m(ox, Landmarks._bm(Vector3(0.5, 0.5, 0.7)), hide, Vector3(0, 1.35, -1.2))
	for s in [-1.0, 1.0]:
		_m(ox, Landmarks._bm(Vector3(0.5, 0.07, 0.07)), FieldBuilder._mat("horn", Color(0.7, 0.66, 0.55)), Vector3(0.35 * s, 1.65, -1.2))
	var legs: Array = []
	var k: int = 0
	for sz in [-0.65, 0.65]:
		for sx in [-0.3, 0.3]:
			var leg := Node3D.new()
			leg.position = Vector3(sx, 0.85, sz)
			ox.add_child(leg)
			_m(leg, Landmarks._bm(Vector3(0.18, 0.85, 0.18)), hide, Vector3(0, -0.42, 0))
			legs.append(leg)
			k += 1
	n.set_meta("legs", legs)
	if i == FieldLayout.CARAVAN_CARTS - 1:   # 맨 뒤 수레의 등불
		_m(n, Landmarks._bm(Vector3(0.05, 0.05, 0.9)), wood, Vector3(0.0, 2.4, 1.9))
		_m(n, Landmarks._bm(Vector3(0.28, 0.36, 0.28)), FieldBuilder._mat("lantern", Color(1.0, 0.7, 0.35), 0.5, 0.0, 2.2), Vector3(0.0, 2.1, 2.3))
		_lamp = OmniLight3D.new()
		_lamp.position = Vector3(0.0, 2.1, 2.3)
		_lamp.light_color = Color(1.0, 0.72, 0.42)
		_lamp.omni_range = 7.0
		_lamp.shadow_enabled = false
		n.add_child(_lamp)
	return n


func _guard(lantern: bool) -> Node3D:
	var n := Node3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.28
	cap.height = 1.5
	cap.radial_segments = 8
	cap.rings = 3
	_m(n, cap, FieldBuilder._mat("guard", Color(0.16, 0.15, 0.14)), Vector3(0, 0.85, 0))
	var head := SphereMesh.new()
	head.radius = 0.2
	head.height = 0.4
	head.radial_segments = 8
	head.rings = 4
	_m(n, head, FieldBuilder._mat("skin", Color(0.4, 0.3, 0.24)), Vector3(0, 1.8, 0))
	_m(n, Landmarks._bm(Vector3(0.05, 2.3, 0.05)), FieldBuilder._wood(), Vector3(0.4, 1.2, -0.1))
	if lantern:
		_m(n, Landmarks._bm(Vector3(0.18, 0.24, 0.18)), FieldBuilder._mat("lantern", Color(1.0, 0.7, 0.35), 0.5, 0.0, 2.2), Vector3(-0.4, 1.0, -0.2))
	return n


## 바퀴 소리와 낮은 울림: 낮게 깔린 소음에 삐걱 소리 셋(내려가는 높이). 한 번 만들어 이어 돌린다.
static func _creak_stream() -> AudioStreamWAV:
	if _creak_stream_cache:
		return _creak_stream_cache
	var rate: int = 22050
	var n: int = int(rate * 1.8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var data := PackedByteArray()
	data.resize(n * 2)
	var low: float = 0.0
	for k in n:
		var t: float = float(k) / rate
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.02
		var v: float = low * 2.2 + 0.18 * sin(TAU * 52.0 * t) * (0.6 + 0.4 * sin(TAU * 1.1 * t))
		for c in 3:
			var u: float = t - (0.2 + 0.6 * c)
			if u >= 0.0 and u < 0.28:
				var f: float = 260.0 - 90.0 * u / 0.28 + 20.0 * c
				v += 0.16 * sin(TAU * f * u) * sin(PI * u / 0.28)
		data.encode_s16(k * 2, int(clampf(v, -1.0, 1.0) * 14000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	_creak_stream_cache = w
	return w
