class_name FutureRift
extends Node3D
## 갈라진 시간의 틈(docs/stranger.md 3단계). 가는 세로 틈이 어긋나며 깜빡인다. 들판과 미래 구역 양쪽에 서고, 꾸밈이라 화면 쪽 난수를 쓴다. 글자 없음.

var _bars: Array[MeshInstance3D] = []
var _mats: Array[StandardMaterial3D] = []
var _light: OmniLight3D
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _bright: float = 1.0


## faint가 참이면 들판용: 더 흐리고 작다.
static func make(parent: Node3D, at: Vector3, faint: bool = false) -> FutureRift:
	var r := FutureRift.new()
	parent.add_child(r)
	r.position = at
	r._build(faint)
	return r


func _build(faint: bool) -> void:
	_rng.seed = int(position.x * 31.0 + position.z * 17.0)
	_bright = 0.55 if faint else 1.0
	var s: float = 0.8 if faint else 1.0
	var cols: Array[Color] = [Color(0.45, 0.8, 1.0), Color(0.6, 0.4, 1.0), Color(0.3, 0.55, 0.9), Color(0.7, 0.9, 1.0)]
	for i in 4:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05 + 0.03 * (i % 2), (2.6 - 0.35 * i) * s, 0.04)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = cols[i]
		m.emission_enabled = true
		m.emission = cols[i]
		m.emission_energy_multiplier = 1.6
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		mi.material_override = m
		mi.position = Vector3((i - 1.5) * 0.09, 1.4 * s, 0)
		add_child(mi)
		_bars.append(mi)
		_mats.append(m)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.45, 0.65, 1.0)
	_light.omni_range = 5.0
	_light.light_energy = 0.9 * _bright
	_light.position.y = 1.4
	_light.shadow_enabled = false
	add_child(_light)


func _process(delta: float) -> void:
	_t += delta
	for i in _bars.size():
		var flick: float = 0.35 + 0.65 * absf(sin(_t * (5.0 + 3.0 * i) + i * 1.7))
		if _rng.randf() < 0.04:
			flick = 0.0
		_mats[i].albedo_color.a = flick * _bright
		_mats[i].emission_energy_multiplier = 2.2 * flick
		if _rng.randf() < 0.08:
			_bars[i].position.x = (i - 1.5) * 0.09 + _rng.randf_range(-0.12, 0.12)
	_light.light_energy = (0.5 + 0.8 * absf(sin(_t * 9.0))) * _bright
