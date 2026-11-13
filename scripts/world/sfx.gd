class_name Sfx
extends Node3D
## 에셋이 없는 동안 쓰는 소리. 코드로 짧은 쿵 소리와 잡음을 만든다. 음이 올라가는 소리는 만들지 않는다.

const RATE: int = 22050

@export var voices: int = 10
@export var unit_size: float = 10.0

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer3D] = []
var _next: int = 0


func _ready() -> void:
	# 이름: [시작 음, 끝 음(내려간다), 길이, 음 세기, 잡음 세기, 잡음 밝기]
	_streams[&"hit"] = _make(140.0, 50.0, 0.14, 0.55, 0.5, 2600.0)
	_streams[&"hit_big"] = _make(110.0, 38.0, 0.24, 0.75, 0.6, 2000.0)
	_streams[&"swish"] = _make(0.0, 0.0, 0.1, 0.0, 0.22, 1800.0)
	_streams[&"dash"] = _make(0.0, 0.0, 0.16, 0.0, 0.25, 900.0)
	_streams[&"thump"] = _make(92.0, 36.0, 0.4, 0.6, 0.25, 700.0)
	_streams[&"draw"] = _make(150.0, 80.0, 0.16, 0.3, 0.35, 2600.0)
	_streams[&"break"] = _make(220.0, 60.0, 0.28, 0.3, 0.6, 3200.0)
	_streams[&"hurt"] = _make(150.0, 70.0, 0.15, 0.5, 0.2, 1200.0)
	_streams[&"night"] = _make(70.0, 40.0, 1.2, 0.5, 0.15, 600.0)
	for i in voices:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = unit_size
		add_child(p)
		_pool.append(p)


func play(name: StringName, at: Vector3, volume_db: float = 0.0) -> void:
	if not _streams.has(name):
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _streams[name]
	p.global_position = at
	p.volume_db = volume_db
	p.play()


static func _make(f0: float, f1: float, dur: float, tone_vol: float, noise_vol: float, bright: float) -> AudioStreamWAV:
	var n: int = int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var phase: float = 0.0
	var lp: float = 0.0
	var a: float = 1.0 - exp(-TAU * bright / RATE)
	for i in n:
		var k: float = float(i) / n
		var env: float = pow(1.0 - k, 2.0)
		if f0 > 0.0:
			phase += TAU * f0 * pow(f1 / f0, k) / RATE
		lp += a * (rng.randf_range(-1.0, 1.0) - lp)
		var s: float = (sin(phase) * tone_vol + lp * noise_vol * 2.0) * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
