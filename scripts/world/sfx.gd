class_name Sfx
extends Node3D
## 위치가 있는 소리. assets/sound/<이름>/*.wav가 있으면 그중 하나를 골라 조금씩 높낮이를 바꿔 튼다.
## 없으면 코드로 짧은 쿵 소리와 잡음을 만들어 대신한다(39단계 말발굽·휘파람도). 음이 올라가는 소리, 종소리는 쓰지 않는다.
## 고르기와 높낮이의 랜덤은 꾸밈용이라 규칙의 rng가 아닌 이 노드의 것을 쓴다.

const RATE: int = 22050
## 39단계 말 부르는 휘파람(코드 소리)의 음: [시작(초), 길이(초), 시작 음(Hz), 끝 음(Hz)]. 음마다 내려가고 다음 음은 앞 음의 끝보다 낮다(올라가는 소리 없음).
const WHISTLE_NOTES: Array = [[0.0, 0.15, 1680.0, 1560.0], [0.2, 0.36, 1460.0, 1180.0]]
const SOUND_DIR: String = "res://assets/sound/"

@export var voices: int = 12
@export var unit_size: float = 10.0
## 같은 소리를 여러 번 들어도 덜 지겹게 높낮이를 이만큼(비율) 흔든다. 이름마다 따로 줄 수 있다.
@export var pitch_jitter: float = 0.06
@export var jitters: Dictionary = {&"hit": 0.12, &"hit_flesh": 0.1, &"hit_heavy": 0.08, &"swish": 0.08, &"chain": 0.0}
## 이름마다 더하는 크기(dB). 부르는 쪽의 volume_db에 더해진다.
@export var gains: Dictionary = {
	&"swish": -2.0, &"swish_big": 0.0, &"dash": -4.0, &"hit": 0.0, &"hit_big": 2.0,
	&"hit_flesh": -3.0, &"hit_heavy": -4.0, &"thump": -2.0, &"anvil": 0.0, &"draw": -2.0, &"break": 0.0, &"hurt": -2.0, &"grunt": -6.0,
	&"land": -3.0, &"hoof": -4.0, &"whistle": -3.0, &"chain": -6.0, &"crack": 2.0, &"glitch": -4.0,
}

var _streams: Dictionary = {}   # 이름 -> Array[AudioStream]
var _pool: Array[AudioStreamPlayer3D] = []
var _next: int = 0
var _rng := RandomNumberGenerator.new()
var _last: Dictionary = {}   # 이름 -> 지난번에 튼 번호(같은 파일을 연달아 틀지 않는다)


func _ready() -> void:
	_rng.randomize()
	# 파일이 없을 때 대신하는 소리. 이름: [시작 음, 끝 음(내려간다), 길이, 음 세기, 잡음 세기, 잡음 밝기]
	var made := {
		&"hit": [140.0, 50.0, 0.14, 0.55, 0.5, 2600.0], &"hit_big": [110.0, 38.0, 0.24, 0.75, 0.6, 2000.0],
		&"swish": [0.0, 0.0, 0.1, 0.0, 0.22, 1800.0], &"swish_big": [0.0, 0.0, 0.16, 0.0, 0.3, 1200.0],
		&"dash": [0.0, 0.0, 0.16, 0.0, 0.25, 900.0], &"thump": [92.0, 36.0, 0.4, 0.6, 0.25, 700.0],
		&"anvil": [92.0, 36.0, 0.4, 0.6, 0.25, 700.0], &"draw": [150.0, 80.0, 0.16, 0.3, 0.35, 2600.0],
		&"break": [220.0, 60.0, 0.28, 0.3, 0.6, 3200.0], &"hurt": [150.0, 70.0, 0.15, 0.5, 0.2, 1200.0],
		&"night": [70.0, 40.0, 1.2, 0.5, 0.15, 600.0],
		&"land": [85.0, 42.0, 0.11, 0.35, 0.4, 900.0],   # 점프하고 내려앉는 발소리(30단계): 짧게 내려가는 쿵과 흙 잡음
		&"hoof": [175.0, 72.0, 0.075, 0.42, 0.62, 1500.0],   # 39단계 말발굽: 짧게 내려가는 딱 소리와 흙 잡음
		&"crack": [1800.0, 260.0, 0.09, 0.3, 0.95, 5200.0],   # 낯선 사람의 총성(docs/stranger.md): 짧고 날카로운 딱
		&"chain": [520.0, 260.0, 0.09, 0.45, 0.45, 3400.0],   # 처치 연쇄(2026-11-24): 짧은 쇳소리. 부르는 쪽이 연쇄만큼 높인다
	}
	for name in made:
		var files := _load_dir(str(name))
		if files.is_empty():
			var m: Array = made[name]
			files.append(_make(m[0], m[1], m[2], m[3], m[4], m[5]))
		_streams[name] = files
	var wh := _load_dir("whistle")   # 39단계 말 부르는 휘파람(파일이 없으면 코드로: 내려가는 두 음)
	if wh.is_empty():
		wh.append(_make_whistle())
	_streams[&"whistle"] = wh
	_streams[&"glitch"] = [_make_glitch()]   # 지지지지직: 낯선 물건이 검을 바꿀 때
	for extra in ["grunt", "hit_flesh", "hit_heavy"]:
		var files := _load_dir(extra)
		if not files.is_empty():
			_streams[StringName(extra)] = files
	for i in voices:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = unit_size
		add_child(p)
		_pool.append(p)


static func _load_dir(name: String) -> Array[AudioStream]:
	var out: Array[AudioStream] = []
	var dir: String = SOUND_DIR + name + "/"
	if not DirAccess.dir_exists_absolute(dir):
		return out
	var names: Array[String] = []
	for f in ResourceLoader.list_directory(dir):
		if f.get_extension().to_lower() in ["wav", "ogg"]:
			names.append(f)
	names.sort()
	for f in names:
		var s := load(dir + f) as AudioStream
		if s:
			out.append(s)
	return out


func has(name: StringName) -> bool:
	return _streams.has(name)


## pitch는 기본 높낮이(1 = 그대로). 여기에 흔들림이 더해진다.
func play(name: StringName, at: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(name):
		return
	var list: Array = _streams[name]
	var i: int = _rng.randi() % list.size()
	if list.size() > 1 and i == int(_last.get(name, -1)):
		i = (i + 1 + _rng.randi() % (list.size() - 1)) % list.size()
	_last[name] = i
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = list[i]
	p.global_position = at
	p.volume_db = volume_db + float(gains.get(name, 0.0))
	var j: float = float(jitters.get(name, pitch_jitter))
	p.pitch_scale = pitch * (1.0 + _rng.randf_range(-j, j))
	p.play()


## 지지지지직(docs/stranger.md): 짧게 끊기는 잡음 덩이와 낮은 네모 소리를 1.5초. 덩이 길이와 음이 제멋대로 바뀌고 오르거나 내려가는 흐름이 없다. 끝에서 조금 잦아든다.
static func _make_glitch() -> AudioStreamWAV:
	var dur: float = 1.5
	var n: int = int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 311
	var left: int = 0
	var on: bool = true
	var freq: float = 110.0
	var phase: float = 0.0
	var held: float = 0.0
	for i in n:
		if left <= 0:
			left = int(rng.randf_range(0.012, 0.055) * RATE)
			on = rng.randf() < 0.78
			freq = rng.randf_range(70.0, 190.0)
		left -= 1
		var env: float = 1.0 - smoothstep(0.75, 1.0, float(i) / n)
		var s: float = 0.0
		if on:
			phase += TAU * freq / RATE
			if i % 6 == 0:   # 거칠게 듬성듬성 고른 잡음
				held = rng.randf_range(-1.0, 1.0)
			s = ((0.45 if sin(phase) >= 0.0 else -0.45) + held * 0.5) * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 24000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## 말 부르는 휘파람(39단계): 짧은 높은 음 하나와 조금 낮은 긴 음 하나. 두 음 다 조금씩 내려가기만 한다(올라가는 소리는 쓰지 않는다).
## 부드럽게 들어가고 나오며 입김 같은 잡음을 얕게 섞는다.
static func _make_whistle() -> AudioStreamWAV:
	var notes: Array = WHISTLE_NOTES
	var dur: float = 0.6
	var n: int = int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var phase: float = 0.0
	var lp: float = 0.0
	var hp_prev: float = 0.0
	var a: float = 1.0 - exp(-TAU * 5000.0 / RATE)
	for i in n:
		var t: float = float(i) / RATE
		var s: float = 0.0
		for nt in notes:
			var k: float = (t - float(nt[0])) / float(nt[1])
			if k < 0.0 or k > 1.0:
				continue
			var env: float = smoothstep(0.0, 0.12, k) * (1.0 - smoothstep(0.7, 1.0, k))
			phase += TAU * float(nt[2]) * pow(float(nt[3]) / float(nt[2]), k) / RATE
			lp += a * (rng.randf_range(-1.0, 1.0) - lp)
			var breath: float = lp - hp_prev
			hp_prev = lp
			s += (sin(phase) * 0.42 + breath * 0.25) * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


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
