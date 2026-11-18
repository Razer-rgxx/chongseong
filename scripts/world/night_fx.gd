class_name NightFx
extends Node3D
## 12단계 밤의 효과(모양팀, docs/content.md "12단계"). Rules의 밤 신호를 받아 그린다.
##   봉화      맞으면 바구니에서 불똥과 불씨가 튀고 불이 움찔한다(체력이 줄수록 불이 작아진다). 꺼지면 불이 잦아들고
##             짙은 연기가 오르고 숯이 천천히 식는다. watch_beacon으로 넘긴 봉화(NightArt.beacon)의 불빛을 늘 일렁인다.
##   불씨 땅   미리 보임: 땅에 금이 가고 가운데에서 바깥으로 검붉게 달아오른다(반지름 끝에 옅은 테).
##             탐: 낮은 불길(땅에 붙은 불꽃 판 여럿), 불똥, 옅은 연기, 일렁이는 불빛, 아지랑이. 끝나면 그을음이 식어 사라진다.
##   무덤      흙더미(NightArt.grave_mound)가 땅을 가르며 솟고 흙덩이·먼지·검은 안개가 터진다. 잠시 남았다가 가라앉는다.
##   포위      그 변을 따라 짓밟힌 검은 땅 띠와 안쪽으로 밀려드는 먼지, 먼 쿵 소리. 다른 변이 되면 앞의 것은 옅어진다.
##   안개      fog(env, true) → 환경의 안개를 3배로 천천히, fog(env, false) → 처음 값으로.
##   우두머리  ring_follow(node) → 발밑에 검붉은 고리(NightArt.boss_ring)가 그 노드를 따라다닌다.
## 어두운 사실풍: 땅·쇠·불·흙·연기에서 나오는 것만. 글자, 문양, 형광빛은 쓰지 않는다.
## 꾸밈용 랜덤은 이 노드의 것(_rng)이다. Rules.rng는 건드리지 않는다.
##
## main(기능팀)이 쓰는 법:
##   var nfx := NightFx.new(); add_child(nfx)
##   nfx.setup(rules)                      # Rules에 있는 신호만 이름으로 잇는다(아직 없어도 죽지 않는다):
##                                          #   beacon_hit(hp, max) → on_beacon_hit, beacon_out() → on_beacon_out,
##                                          #   ember_warn(at, radius, time) → on_ember_warn, ember_burn(at, radius, time) → on_ember_burn,
##                                          #   grave_rise(at) → on_grave_rise, siege_side(side) → on_siege_side
##   봉화: var b := NightArt.beacon(holder); nfx.watch_beacon(b)     # 맞음·꺼짐 효과가 이 봉화에서 난다. 다음 밤에 새로 지으면 다시 부른다
##   우두머리: boss_spawned(e)에서 nfx.ring_follow(그 적의 EnemyView, 반지름 m)   # 노드가 사라지거나 숨으면 고리도 옅어져 사라진다
##   안개: 밤이 시작될 때 구역 규칙이 fog면 nfx.fog(env, true), 새벽에 nfx.fog(env, false)   # env = WorldEnvironment.environment
##   판이 끝나거나 낮이 되면 nfx.clear()(포위 띠, 불, 무덤, 고리, 봉화 지켜보기를 거둔다. 안개는 fog(env, false)로 따로 되돌린다)
## 갤러리(scripts/debug/night_gallery.gd)는 on_* 함수를 바로 부른다(Rules 없이).
##
## 자리: at은 칸(Vector2), radius는 칸, time은 초. 포위 side는 Rules._spawn의 변 번호:
##   0 = 북(y = 0), 1 = 남(y = 끝), 2 = 서(x = 0), 3 = 동(x = 끝), -1(또는 null) = 없음. &"north"·&"south"·&"west"·&"east"도 받는다.
## 소리: 위치가 있는 AudioStreamPlayer3D. assets/sound/<이름>/에 파일이 있으면 그것을, 없으면 여기서 만든 짧은 소리(SOUNDS).
##   종소리, 올라가는 삐 소리, 위로 쓸어 올리는 소리는 없다(모두 내려가거나 고른 음과 잡음).
## 이 노드는 top_level이고 원점에 있어서 자식의 위치가 곧 세계 좌표다. EventFx가 이 도구(알갱이·땅 판·빛·소리)를 물려받는다.

const SIGNALS: Dictionary = {
	&"beacon_hit": "on_beacon_hit",
	&"beacon_out": "on_beacon_out",
	&"ember_warn": "on_ember_warn",
	&"ember_burn": "on_ember_burn",
	&"grave_rise": "on_grave_rise",
	&"siege_side": "on_siege_side",
}
## 포위 띠의 깊이(칸).
const SIEGE_DEPTH: float = 3.0
## 한도: 한꺼번에 쓰는 알갱이 노드, 땅 판, 짧은 빛, 소리.
const MAX_EMITTERS: int = 30
const MAX_DECALS: int = 16
const LIGHTS: int = 3
const VOICES: int = 8

const DUST := Color(0.45, 0.4, 0.34)
const EARTH := Color(0.16, 0.13, 0.1)
const EMBER := Color(1.0, 0.42, 0.12)
const SPARK := Color(1.0, 0.6, 0.26)
const CHAR := Color(0.045, 0.038, 0.033)
const SMOKE := Color(0.13, 0.125, 0.12)
const MIST := Color(0.05, 0.05, 0.055)
const RED := Color(0.34, 0.035, 0.025)
const RED_HOT := Color(0.6, 0.09, 0.045)

## 땅 판 셰이더(1 × 1 PlaneMesh를 노드 크기로 늘린다). 땅처럼 빛을 받고, 빛나는 곳만 EMISSION.
##   mode 0 불씨 땅: fill = 미리 보임이 찬 정도(가운데 → 테), burn = 타는 세기, scorch = 그을음 짙기
##   mode 1 포위 띠: lp.y 0 = 변(바깥), 1 = 안쪽. fill = 나타남
##   mode 2 얼룩: 가운데가 짙은 들쭉날쭉한 얼룩(검은 기운의 땅, 젖은 흙). fill = 짙기, energy = 붉은 점
##   mode 3 먼지 고리: fill = 퍼진 정도(0 → 1)
const DECAL_SHADER := """shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, specular_disabled, shadows_disabled;
uniform int mode = 0;
uniform vec4 color : source_color = vec4(0.045, 0.038, 0.033, 1.0);
uniform vec4 hot : source_color = vec4(1.0, 0.42, 0.12, 1.0);
uniform float emit = 2.0;
uniform float fill = 0.0;
uniform float burn = 0.0;
uniform float scorch = 0.0;
uniform float energy = 0.0;
uniform float fade = 1.0;
uniform float seed = 0.0;
uniform float cell = 1.1;
varying vec2 lp;
varying vec2 wxz;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
float cracks(vec2 p) {
	p += (vec2(vn(p * 0.7), vn(p * 0.7 + 9.3)) - 0.5) * 1.1;
	vec2 ip = floor(p);
	vec2 fp = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = vec2(h21(ip + g), h21(ip + g + 31.7));
			vec2 d = g + o - fp;
			float dd = dot(d, d);
			if (dd < f1) { f2 = f1; f1 = dd; } else if (dd < f2) { f2 = dd; }
		}
	}
	float e = sqrt(f2) - sqrt(f1);
	float c = 1.0 - smoothstep(0.015, 0.075, e);
	float hair = 1.0 - smoothstep(0.0, 0.035, abs(vn(p * 2.6 + 4.0) - 0.5));
	return max(c, hair * 0.45 * step(0.5, vn(p * 1.3)));
}
void vertex() {
	lp = VERTEX.xz + 0.5;
	wxz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	float n = vn(wxz * 0.9 + seed);
	float n2 = vn(wxz * 4.3 + seed * 1.7 + 11.0);
	float a = 0.0;
	float h = 0.0;
	if (mode == 0) {
		vec2 q = lp - 0.5;
		float r = length(q) * 2.0;
		if (r > 1.0) { discard; }
		float inside = 1.0 - smoothstep(0.78, 1.0, r + (n - 0.5) * 0.22);
		float c = cracks(wxz / cell + seed);
		float front = 1.0 - smoothstep(fill - 0.18, fill, r);
		float warn = c * front * inside * (0.3 + 0.7 * fill) * (1.0 - burn);
		float ring = exp(-pow((r - 0.93) / 0.03, 2.0)) * (0.45 + 0.55 * n2) * step(0.001, fill) * (1.0 - burn) * (1.0 - scorch * 0.7);
		float flick = 0.7 + 0.3 * sin(TIME * 8.0 + n2 * 23.0) * sin(TIME * 5.3 + n * 17.0);
		float spots = smoothstep(0.62, 0.86, vn(wxz * 3.1 + vec2(TIME * 0.3, -TIME * 0.2) + seed)) * 0.7;
		float fire = burn * inside * (c * (0.75 + 0.45 * flick) + spots * flick);
		float sc = scorch * inside * (0.72 + 0.28 * n);
		a = max(max(sc * 0.86, warn * 0.95), max(fire, ring * 0.5));
		h = clamp(max(warn * 0.85 + ring * 0.35, fire), 0.0, 1.0);
	} else if (mode == 1) {
		float along = lp.x;
		float across = lp.y;
		float body = pow(1.0 - smoothstep(0.0, 1.0, across + (n - 0.5) * 0.4), 1.3);
		float ends = smoothstep(0.0, 0.05, along) * (1.0 - smoothstep(0.95, 1.0, along));
		float scuff = 0.6 + 0.4 * n2;
		a = body * ends * scuff * 0.8 * fill;
		h = (1.0 - smoothstep(0.0, 0.1, across + (n2 - 0.5) * 0.05)) * ends * fill * (0.55 + 0.45 * n);
	} else if (mode == 2) {
		vec2 q = lp - 0.5;
		float r = length(q) * 2.0;
		if (r > 1.0) { discard; }
		float rr = r + (n - 0.5) * 0.5 + (n2 - 0.5) * 0.15;
		a = (1.0 - smoothstep(0.35, 0.92, rr)) * (0.65 + 0.35 * n2) * fill;
		h = smoothstep(0.72, 0.9, vn(wxz * 9.0 + seed * 2.3 + vec2(0.0, TIME * 0.2))) * (1.0 - smoothstep(0.2, 0.7, rr)) * energy;
	} else {
		vec2 q = lp - 0.5;
		float r = length(q) * 2.0;
		if (r > 1.0) { discard; }
		float band = smoothstep(fill - 0.22, fill, r) * (1.0 - smoothstep(fill, fill + 0.04, r));
		a = band * pow(clamp(1.0 - fill, 0.0, 1.0), 1.2) * 0.55 * (0.55 + 0.45 * n2) * smoothstep(0.08, 0.2, fill);
	}
	ALBEDO = mix(color.rgb, hot.rgb, h);
	EMISSION = hot.rgb * h * emit;
	ROUGHNESS = 1.0;
	ALPHA = clamp(a * fade, 0.0, 1.0);
}
"""

## 아지랑이: 세로축 빌보드 판 뒤의 화면을 잡음으로 흔든다(아래가 세고 위로 옅어진다).
const SHIMMER_SHADER := """shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.008;
uniform float fade = 1.0;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	float v = 1.0 - UV.y;
	float mask = smoothstep(0.0, 0.12, v) * (1.0 - smoothstep(0.35, 1.0, v)) * (1.0 - smoothstep(0.25, 0.5, abs(UV.x - 0.5)));
	vec2 w = vec2(vn(vec2(UV.x * 9.0, v * 7.0 - TIME * 3.2)), vn(vec2(UV.x * 9.0 + 5.2, v * 7.0 - TIME * 2.7))) - 0.5;
	vec2 suv = SCREEN_UV + w * strength * mask * fade;
	ALBEDO = texture(screen, suv).rgb;
	ALPHA = clamp(mask * fade, 0.0, 1.0);
}
"""

## 파일이 없을 때 만드는 소리. 열쇠: dur(초), f0→f1(내려가는 음, Hz), tone, tdecay(1/초), partials([Hz, 세기, 1/초], 빨리 죽는 쇠 울림),
## noise, lp·hp(Hz), ndecay(1/초), attack(초), crackle(튀는 잡음 확률), swell(잡음이 점점 커진다: 음높이는 그대로), clicks(초 목록), level.
const SOUNDS: Dictionary = {
	&"beacon_hit": {"dur": 0.3, "f0": 104.0, "f1": 68.0, "tone": 0.5, "tdecay": 16.0, "partials": [[262.0, 0.24, 28.0], [583.0, 0.13, 40.0], [1127.0, 0.05, 60.0]], "noise": 0.45, "lp": 2600.0, "ndecay": 26.0, "crackle": 0.02, "level": 0.8},
	&"beacon_out": {"dur": 1.8, "f0": 66.0, "f1": 34.0, "tone": 0.45, "tdecay": 4.0, "noise": 0.6, "lp": 2800.0, "hp": 450.0, "ndecay": 1.9, "crackle": 0.012, "attack": 0.01, "level": 0.7},
	&"ember_warn": {"dur": 1.0, "noise": 0.32, "lp": 1600.0, "hp": 180.0, "swell": true, "crackle": 0.03, "attack": 0.06, "level": 0.4},
	&"ember_burn": {"dur": 4.2, "noise": 0.5, "lp": 850.0, "hp": 60.0, "ndecay": 0.2, "crackle": 0.035, "attack": 0.08, "level": 0.55},
	&"grave_rise": {"dur": 0.95, "f0": 58.0, "f1": 29.0, "tone": 0.6, "tdecay": 4.5, "noise": 0.7, "lp": 620.0, "ndecay": 3.4, "crackle": 0.02, "clicks": [0.0, 0.05, 0.12], "level": 0.85},
	&"siege_side": {"dur": 1.3, "f0": 50.0, "f1": 33.0, "tone": 0.8, "tdecay": 2.8, "noise": 0.4, "lp": 320.0, "ndecay": 2.4, "attack": 0.01, "level": 0.7},
	&"smith_use": {"dur": 0.36, "f0": 176.0, "f1": 118.0, "tone": 0.4, "tdecay": 22.0, "partials": [[421.0, 0.28, 32.0], [933.0, 0.16, 44.0], [1577.0, 0.07, 64.0]], "noise": 0.4, "lp": 4000.0, "ndecay": 40.0, "clicks": [0.0], "level": 0.85},
	&"pilgrim_use": {"dur": 0.65, "f0": 112.0, "f1": 80.0, "tone": 0.22, "tdecay": 5.0, "noise": 0.4, "lp": 1200.0, "hp": 150.0, "ndecay": 5.0, "attack": 0.06, "level": 0.5},
	&"seer_use": {"dur": 0.75, "f0": 92.0, "f1": 58.0, "tone": 0.2, "tdecay": 6.0, "noise": 0.5, "lp": 2000.0, "hp": 300.0, "ndecay": 4.5, "attack": 0.03, "crackle": 0.02, "level": 0.55},
	&"event_vanish": {"dur": 1.4, "noise": 0.45, "lp": 700.0, "hp": 120.0, "ndecay": 1.9, "attack": 0.15, "level": 0.5},
	&"curse_off": {"dur": 0.85, "f0": 62.0, "f1": 34.0, "tone": 0.5, "tdecay": 4.0, "noise": 0.5, "lp": 520.0, "ndecay": 4.0, "level": 0.7},
}
const RATE: int = 22050
const Q_ADD: int = 0
const Q_FIRE: int = 1
const Q_LIT: int = 2

## 무덤 흙더미가 남는 시간(초).
@export var grave_time: float = 7.0
## 봉화가 가장 작을 때(체력 0 바로 앞) 불 크기.
@export var beacon_low: float = 0.35
## 불씨 땅 그을음이 식어 사라질 때까지(초).
@export var scorch_time: float = 3.0
## 아지랑이 세기(화면 UV). 0이면 끈다.
@export var shimmer: float = 0.008
## 모든 소리에 더하는 크기(dB).
@export var volume_db: float = 0.0

var rules: Rules = null

static var _cache: Dictionary = {}

var _built: bool = false
var _rng := RandomNumberGenerator.new()
var _clock: float = 0.0
var _layer: Node3D
var _jobs: Array[Dictionary] = []
var _emitters: Array[CPUParticles3D] = []
var _decals: Array[Dictionary] = []
var _lights: Array[OmniLight3D] = []
var _voices: Array[AudioStreamPlayer3D] = []
var _next_voice: int = 0
var _streams: Dictionary = {}
var _serial: int = 0
var _plane := PlaneMesh.new()
var _decal_shader := Shader.new()
var _mix_mat: StandardMaterial3D
var _add_mat: StandardMaterial3D
var _lit_mat: ShaderMaterial
var _spark_mat: StandardMaterial3D
var _quads: Dictionary = {}
var _spark_mesh := BoxMesh.new()
var _chip_mesh := BoxMesh.new()
var _clod_mesh := SphereMesh.new()
var _flicker := FastNoiseLite.new()
## 봉화(NightArt.beacon의 parts)와 그 상태.
var _beacon: Dictionary = {}
var _beacon_dip: float = 0.0
var _beacon_last_hit: float = -1.0
var _beacon_level: float = 1.0
## 불씨 땅: 자리 → job(미리 보임에서 탐으로 같은 판을 이어 쓴다).
var _embers: Array[Dictionary] = []
var _siege: Dictionary = {}
## 우두머리 고리: 노드 instance id → job
var _rings: Dictionary = {}
var _fog_tween: Tween


func _ready() -> void:
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	top_level = true
	transform = Transform3D.IDENTITY
	_rng.randomize()
	_flicker.frequency = 2.2
	_flicker.seed = 3
	_layer = Node3D.new()
	_layer.name = "FxLayer"
	add_child(_layer)
	_plane.size = Vector2.ONE
	_decal_shader.code = DECAL_SHADER
	_mix_mat = _particle_mat(false, NightArt.puff())
	_add_mat = _particle_mat(true, NightArt.dot())
	_lit_mat = ShaderMaterial.new()
	_lit_mat.shader = NightArt._shader("lit", NightArt.LIT_SHADER)
	_lit_mat.set_shader_parameter("tex", NightArt.puff())
	_spark_mat = StandardMaterial3D.new()
	_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spark_mat.vertex_color_use_as_albedo = true
	_spark_mat.disable_receive_shadows = true
	_spark_mesh.size = Vector3(0.014, 0.15, 0.014)
	_spark_mesh.material = _spark_mat
	var chip_mat := StandardMaterial3D.new()
	chip_mat.vertex_color_use_as_albedo = true
	chip_mat.roughness = 0.95
	_chip_mesh.size = Vector3(0.05, 0.025, 0.08)
	_chip_mesh.material = chip_mat
	_clod_mesh.radius = 0.07
	_clod_mesh.height = 0.11
	_clod_mesh.radial_segments = 6
	_clod_mesh.rings = 3
	_clod_mesh.material = chip_mat
	for i in LIGHTS:
		var l := OmniLight3D.new()
		l.shadow_enabled = false
		l.visible = false
		l.set_meta("until", 0.0)
		_layer.add_child(l)
		_lights.append(l)
	for i in VOICES:
		var v := AudioStreamPlayer3D.new()
		v.unit_size = 10.0
		add_child(v)
		_voices.append(v)
	for key: StringName in SOUNDS:
		var files: Array[AudioStream] = Sfx._load_dir(str(key))
		if files.is_empty():
			files.append(_sound(key))
		_streams[key] = files


## Rules의 신호 중 있는 것만 잇는다. 이름으로 이어서 신호가 아직 없어도 이 스크립트는 읽힌다.
func setup(r: Rules) -> void:
	_build()
	rules = r
	if r == null:
		return
	for s: StringName in SIGNALS:
		var c := Callable(self, SIGNALS[s])
		if r.has_signal(s) and not r.is_connected(s, c):
			r.connect(s, c)


## 남은 효과를 모두 거둔다(판이 끝날 때, 낮이 될 때, 갤러리에서). 봉화 노드는 지은 쪽이 거둔다(여기서는 지켜보기만 멈춘다).
func clear() -> void:
	_build()
	for j in _jobs:
		_end_job(j)
	_jobs.clear()
	_embers.clear()
	_siege = {}
	_rings.clear()
	_beacon = {}
	for p in _emitters:
		p.emitting = false
		p.set_meta("free_at", 0.0)
	for d in _decals:
		_free_decal(d)
	for l in _lights:
		l.visible = false
		l.set_meta("until", 0.0)
	for v in _voices:
		v.stop()


func _process(delta: float) -> void:
	if not _built:
		return
	_clock += delta
	var jobs: Array[Dictionary] = _jobs
	_jobs = []
	var live: Array[Dictionary] = []
	for j in jobs:
		j["t"] = float(j["t"]) + delta
		if not bool(j.get("dead", false)) and (j["fn"] as Callable).call(j, delta):
			live.append(j)
		else:
			_end_job(j)
	live.append_array(_jobs)
	_jobs = live
	_step_beacon(delta)


# ---------------------------------------------------------------- 봉화

## 이 봉화(NightArt.beacon이 돌려준 것)를 지켜본다: 불빛을 일렁이고, 맞음·꺼짐 효과를 여기서 낸다. 빈 Dictionary면 그만 본다.
func watch_beacon(parts: Dictionary) -> void:
	_build()
	_beacon = parts
	_beacon_dip = 0.0
	_beacon_level = float(parts.get("fire", 1.0)) if not parts.is_empty() else 1.0


## 봉화가 맞았다(Rules.beacon_hit). 체력이 줄수록 불이 작아진다(beacon_low까지). 아주 잦은 맞음은 효과를 줄인다.
func on_beacon_hit(hp: float, max_hp: float) -> void:
	_build()
	if _beacon.is_empty():
		return
	var ratio: float = clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
	if ratio <= 0.0:
		return
	_beacon_level = lerpf(beacon_low, 1.0, ratio)
	_beacon_dip = 1.0
	var root: Node3D = _beacon.root
	if not is_instance_valid(root):
		return
	var rim: Vector3 = root.global_transform * Vector3(0.0, float(_beacon.get("rim", 1.86)), 0.0)
	var fire: Vector3 = root.global_transform * (_beacon.get("fire_at", NightArt.FIRE_AT) as Vector3)
	var busy: bool = _clock - _beacon_last_hit < 0.12
	_beacon_last_hit = _clock
	# 맞은 쪽은 모르니 바구니 테의 아무 데서나: 불똥이 옆으로 튀어 떨어지고, 불씨가 한 줌 오른다
	var a: float = _rng.randf() * TAU
	var side := Vector3(cos(a), 0.0, sin(a))
	_sparks(rim + side * 0.4, 5 if busy else 12, side + Vector3(0.0, 0.5, 0.0), 55.0, 2.0, 5.0, SPARK, 0.55)
	if not busy:
		_embers_up(fire + Vector3(0.0, 0.3, 0.0), 10, 0.35, 1.2)
		_ash(fire + Vector3(0.0, 0.5, 0.0), 4, 0.6)
		_play(&"beacon_hit", rim, -4.0, _rng.randf_range(0.92, 1.08))


## 봉화가 꺼졌다(Rules.beacon_out). 불이 1초에 잦아들고, 짙은 연기가 오르며, 숯이 6초에 걸쳐 식는다.
func on_beacon_out() -> void:
	_build()
	if _beacon.is_empty():
		return
	var root: Node3D = _beacon.root
	if not is_instance_valid(root):
		return
	var fire: Vector3 = root.global_transform * (_beacon.get("fire_at", NightArt.FIRE_AT) as Vector3)
	_beacon_level = 0.0
	var smoke := _emitter(true)
	if smoke != null:
		smoke.amount = 22
		smoke.lifetime = 3.6
		smoke.explosiveness = 0.0
		smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		smoke.emission_sphere_radius = 0.22
		smoke.direction = Vector3.UP
		smoke.spread = 14.0
		smoke.initial_velocity_min = 0.9
		smoke.initial_velocity_max = 1.6
		smoke.gravity = Vector3(0.3, 0.3, 0.15)
		smoke.damping_min = 0.1
		smoke.damping_max = 0.3
		smoke.angle_min = -180.0
		smoke.angle_max = 180.0
		smoke.angular_velocity_min = -25.0
		smoke.angular_velocity_max = 25.0
		_curve(smoke, 0.5, 2.6)
		_ramp(smoke, [Color(SMOKE, 0.0), Color(SMOKE, 0.55), Color(SMOKE.lightened(0.05), 0.0)], [0.0, 0.15, 1.0])
		smoke.mesh = _quad(1.3, Q_LIT)
		smoke.position = fire + Vector3(0.0, 0.25, 0.0)
		smoke.emitting = true
	# 불이 꺼지는 순간: 불씨가 바구니 사이로 흘러 떨어지고, 재가 한 번 일어난다
	_sparks(fire, 14, Vector3.DOWN, 70.0, 0.4, 1.6, EMBER, 1.1, true)
	_embers_up(fire + Vector3(0.0, 0.2, 0.0), 8, 0.3, 1.6)
	_ash(fire + Vector3(0.0, 0.3, 0.0), 6, 0.9)
	_play(&"beacon_out", fire, -3.0)
	_job(_run_beacon_out, {"emit": smoke, "parts": _beacon, "from": float(_beacon.get("fire", 1.0)), "c0": float(_beacon.get("coals", 1.0))})


func _run_beacon_out(j: Dictionary, _dt: float) -> bool:
	var t: float = j["t"]
	var P: Dictionary = j["parts"]
	if not is_instance_valid(P.get("root")):
		return false
	var k: float = clampf(t / 1.0, 0.0, 1.0)
	NightArt.set_fire(P, float(j["from"]) * (1.0 - k) * (1.0 - k))
	NightArt.set_coals(P, float(j["c0"]) * (1.0 - smoothstep(0.3, 6.5, t)))
	var smoke: CPUParticles3D = j["emit"]
	if smoke and t > 2.0:
		smoke.speed_scale = maxf(0.4, 1.0 - (t - 2.0) * 0.12)
	if t > 4.5 and smoke and smoke.emitting:
		smoke.emitting = false
	return t < 6.5


## 다시 불을 붙인다(갤러리, 다음 밤에 같은 봉화를 쓸 때).
func relight_beacon() -> void:
	if _beacon.is_empty():
		return
	for j in _jobs:
		if (j["fn"] as Callable) == Callable(self, "_run_beacon_out"):
			j["dead"] = true
	_beacon_level = 1.0
	NightArt.set_coals(_beacon, 1.0)
	NightArt.set_fire(_beacon, 1.0)


## 봉화의 불: 맞으면 잠깐 움찔(작아졌다가 돌아온다), 늘 일렁이는 불빛.
func _step_beacon(delta: float) -> void:
	if _beacon.is_empty():
		return
	if not is_instance_valid(_beacon.get("root")):
		_beacon = {}
		return
	var l: OmniLight3D = _beacon.get("light")
	_beacon_dip = maxf(0.0, _beacon_dip - delta * 4.0)
	var now: float = float(_beacon.get("fire", 1.0))
	if _beacon_level > 0.0:
		var want: float = _beacon_level * (1.0 - 0.35 * _beacon_dip * _beacon_dip)
		now = move_toward(now, want, delta * 3.0)
	# set_fire가 불빛을 바탕값으로 다시 맞추고, 그 위에 일렁임을 곱한다
	NightArt.set_fire(_beacon, now)
	if l and l.visible:
		var f: float = 0.86 + 0.14 * _flicker.get_noise_1d(_clock * 10.0) + 0.05 * sin(_clock * 23.0)
		l.light_energy *= f + 0.25 * _beacon_dip


# ---------------------------------------------------------------- 불씨 땅

## 불붙을 자리가 미리 보인다(Rules.ember_warn): time초 동안 금이 가운데에서 테까지 달아오른다.
func on_ember_warn(at: Vector2, radius: float, time: float) -> void:
	_build()
	var job := _ember_at(at, radius)
	var T: float = maxf(0.1, time)
	job["warn"] = T
	job["t"] = 0.0
	job["phase"] = 0
	var g: Vector3 = _ground(at, 0.0)
	_play(&"ember_warn", g, -8.0)


## 그 자리가 탄다(Rules.ember_burn): time초 동안 낮은 불길. 미리 보임 판이 있으면 이어 쓴다.
func on_ember_burn(at: Vector2, radius: float, time: float) -> void:
	_build()
	var j := _ember_at(at, radius)
	if int(j.get("phase", 0)) >= 1:
		return
	j["phase"] = 1
	j["burn_t"] = float(j["t"])
	j["burn"] = maxf(0.2, time)
	var R: float = Grid.cells_to_meters(radius)
	var g: Vector3 = _ground(at, 0.0)
	var mats: Array[ShaderMaterial] = []
	var nodes: Array[Node3D] = []
	# 불꽃 판: 반지름 안에 흩어 세운다(가운데가 조금 더 높다)
	var count: int = clampi(roundi(R * R * 1.1), 5, 14)
	var holder := Node3D.new()
	holder.position = g
	_layer.add_child(holder)
	for i in count:
		var rr: float = sqrt(_rng.randf()) * R * 0.8
		var a: float = _rng.randf() * TAU
		var hgt: float = lerpf(0.85, 0.45, rr / R) * _rng.randf_range(0.8, 1.15)
		var q := QuadMesh.new()
		q.size = Vector2(hgt * 0.9, hgt)
		q.center_offset = Vector3(0.0, hgt * 0.5, 0.0)
		var m := ShaderMaterial.new()
		m.shader = NightArt._shader("flame", NightArt.FLAME_SHADER)
		m.set_shader_parameter("seed", _rng.randf() * 40.0)
		m.set_shader_parameter("speed", _rng.randf_range(1.1, 1.5))
		m.set_shader_parameter("energy", 1.3)
		m.set_shader_parameter("power", 0.0)
		var f := MeshInstance3D.new()
		f.mesh = q
		f.material_override = m
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.position = Vector3(cos(a) * rr, -0.04, sin(a) * rr)
		holder.add_child(f)
		mats.append(m)
	j["flames"] = mats
	j["node"] = holder
	# 아지랑이
	if shimmer > 0.0:
		var sh := MeshInstance3D.new()
		var sq := QuadMesh.new()
		sq.size = Vector2(R * 2.0, 2.4)
		sq.center_offset = Vector3(0.0, 1.2, 0.0)
		sh.mesh = sq
		var sm := ShaderMaterial.new()
		sm.shader = NightArt._shader("shimmer", SHIMMER_SHADER)
		sm.set_shader_parameter("strength", shimmer)
		sm.set_shader_parameter("fade", 0.0)
		sh.material_override = sm
		sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sh.sorting_offset = 1.0
		holder.add_child(sh)
		j["shimmer"] = sm
	# 낮은 불 조각, 튀는 불똥, 옅은 연기(타는 동안 늘)
	var emits: Array = []
	var fire := _emitter(true)
	if fire != null:
		fire.amount = clampi(roundi(R * 8.0), 10, 26)
		fire.lifetime = 0.7
		fire.explosiveness = 0.0
		fire.randomness = 0.5
		fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		fire.emission_ring_axis = Vector3.UP
		fire.emission_ring_radius = R * 0.75
		fire.emission_ring_inner_radius = 0.0
		fire.emission_ring_height = 0.05
		fire.direction = Vector3.UP
		fire.spread = 12.0
		fire.initial_velocity_min = 0.6
		fire.initial_velocity_max = 1.4
		fire.gravity = Vector3(0.0, 0.8, 0.0)
		fire.angle_min = -180.0
		fire.angle_max = 180.0
		fire.scale_amount_min = 0.5
		fire.scale_amount_max = 1.0
		_curve3(fire, 0.6, 1.0, 0.2)
		_ramp(fire, [Color(1.3, 0.62, 0.22, 0.0), Color(1.25, 0.5, 0.15, 0.8), Color(0.7, 0.16, 0.04, 0.5), Color(0.1, 0.07, 0.05, 0.0)], [0.0, 0.15, 0.5, 1.0])
		fire.mesh = _quad(0.55, Q_FIRE)
		fire.position = g + Vector3(0.0, 0.05, 0.0)
		fire.emitting = true
		emits.append(fire)
	var sp := _emitter(true)
	if sp != null:
		sp.amount = 10
		sp.lifetime = 0.9
		sp.explosiveness = 0.0
		sp.randomness = 0.6
		sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		sp.emission_box_extents = Vector3(R * 0.7, 0.05, R * 0.7)
		sp.direction = Vector3.UP
		sp.spread = 25.0
		sp.initial_velocity_min = 1.0
		sp.initial_velocity_max = 2.8
		sp.gravity = Vector3(0.0, 0.5, 0.0)
		sp.tangential_accel_min = -1.0
		sp.tangential_accel_max = 1.0
		sp.scale_amount_min = 0.5
		sp.scale_amount_max = 1.0
		_ramp(sp, [Color(1.6, 0.8, 0.35, 1.0), Color(1.2, 0.4, 0.1, 0.8), Color(0.5, 0.1, 0.03, 0.0)], [0.0, 0.5, 1.0])
		sp.mesh = _quad(0.045, Q_ADD)
		sp.position = g + Vector3(0.0, 0.3, 0.0)
		sp.emitting = true
		emits.append(sp)
	var sm2 := _emitter(true)
	if sm2 != null:
		sm2.amount = 10
		sm2.lifetime = 2.6
		sm2.explosiveness = 0.0
		sm2.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		sm2.emission_box_extents = Vector3(R * 0.6, 0.05, R * 0.6)
		sm2.direction = Vector3.UP
		sm2.spread = 15.0
		sm2.initial_velocity_min = 0.6
		sm2.initial_velocity_max = 1.1
		sm2.gravity = Vector3(0.2, 0.2, 0.1)
		sm2.angle_min = -180.0
		sm2.angle_max = 180.0
		_curve(sm2, 0.5, 2.0)
		_ramp(sm2, [Color(SMOKE, 0.0), Color(SMOKE, 0.28), Color(SMOKE, 0.0)], [0.0, 0.2, 1.0])
		sm2.mesh = _quad(1.4, Q_LIT)
		sm2.position = g + Vector3(0.0, 0.8, 0.0)
		sm2.emitting = true
		emits.append(sm2)
	j["emit"] = emits
	# 일렁이는 불빛(이 자리 것)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.5, 0.2)
	l.omni_range = R * 2.6
	l.omni_attenuation = 1.3
	l.light_energy = 0.0
	l.shadow_enabled = false
	l.position = g + Vector3(0.0, 0.8, 0.0)
	_layer.add_child(l)
	j["light"] = l
	nodes.append(l)
	j["nodes"] = nodes
	var v := _play(&"ember_burn", g, -7.0)
	if v:
		j["voice"] = v
		j["voice_serial"] = v.get_meta("serial", -1)
	_dust(g, 10, 2.0, 0.5 * R, 0.9)


## 자리(칸)의 불씨 판을 찾거나 새로 만든다.
func _ember_at(at: Vector2, radius: float) -> Dictionary:
	for j in _embers:
		if (j["at"] as Vector2).distance_to(at) < 0.3 and not bool(j.get("dead", false)):
			return j
	var R: float = Grid.cells_to_meters(radius)
	var d := _decal(0)
	var g: Vector3 = _ground(at, 0.0)
	if not d.is_empty():
		_put(d, {"fill": 0.0, "burn": 0.0, "scorch": 0.0, "fade": 1.0, "color": CHAR, "hot": Color(0.95, 0.3, 0.07), "emit": 2.4, "cell": 1.0 + R * 0.12})
		(d["mi"] as MeshInstance3D).transform = Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(R * 2.0, 1.0, R * 2.0)), g + Vector3(0.0, 0.03, 0.0))
	var j := _job(_run_ember, {"at": at, "R": R, "decal": d, "warn": 0.0, "phase": 0})
	_embers.append(j)
	return j


func _run_ember(j: Dictionary, _dt: float) -> bool:
	var t: float = j["t"]
	var d: Dictionary = j["decal"]
	var phase: int = j["phase"]
	if phase == 0:
		var T: float = j["warn"]
		if T <= 0.0:
			return true
		var k: float = clampf(t / T, 0.0, 1.0)
		_put(d, {"fill": k * (2.0 - k), "scorch": 0.25 * k})
		# 신호 없이 너무 오래 미리 보이면 거둔다
		if t > T + 3.0:
			_embers.erase(j)
			return false
		return true
	var bt: float = t - float(j["burn_t"])
	var B: float = j["burn"]
	var on: float = clampf(bt / 0.25, 0.0, 1.0)
	var off: float = clampf((bt - B) / 0.7, 0.0, 1.0)
	var level: float = on * (1.0 - off)
	var flick: float = 0.8 + 0.2 * _flicker.get_noise_2d(_clock * 9.0, float(j["R"]) * 7.0)
	for m: ShaderMaterial in j.get("flames", []):
		m.set_shader_parameter("power", level * flick)
	var sh: Variant = j.get("shimmer")
	if sh is ShaderMaterial:
		(sh as ShaderMaterial).set_shader_parameter("fade", level)
	var l: Variant = j.get("light")
	if l is OmniLight3D and is_instance_valid(l):
		(l as OmniLight3D).light_energy = 2.2 * level * flick
	# 그을음: 타는 동안 검고, 꺼지면 틈의 빛이 식다가 scorch_time에 사라진다
	var cool: float = clampf((bt - B) / maxf(0.1, scorch_time * 0.5), 0.0, 1.0)
	_put(d, {"fill": 1.0, "burn": on * (1.0 - cool), "scorch": 1.0, "fade": 1.0 - clampf((bt - B - scorch_time * 0.4) / (scorch_time * 0.6), 0.0, 1.0)})
	if off >= 1.0 and not bool(j.get("stopped", false)):
		j["stopped"] = true
		for e: Variant in j.get("emit", []):
			if e is CPUParticles3D:
				_release(e)
		j["emit"] = []
		var v: Variant = j.get("voice")
		if v is AudioStreamPlayer3D and int((v as AudioStreamPlayer3D).get_meta("serial", -1)) == int(j.get("voice_serial", -2)):
			(v as AudioStreamPlayer3D).stop()
	if bt > B + scorch_time:
		_embers.erase(j)
		return false
	return true


# ---------------------------------------------------------------- 무덤

## 쓰러진 망령이 무덤에서 일어난다(Rules.grave_rise). 땅이 갈라지고 흙더미가 솟으며 흙덩이·먼지·검은 안개가 터진다.
## 흙더미는 grave_time초 남았다가 가라앉는다.
func on_grave_rise(at: Vector2) -> void:
	_build()
	var g: Vector3 = _ground(at, 0.0)
	var holder := Node3D.new()
	holder.position = g
	holder.rotation.y = _rng.randf() * TAU
	_layer.add_child(holder)
	var P: Dictionary = NightArt.grave_mound(holder, _rng.randi() % 4)
	var root: Node3D = P.root
	root.position.y = -0.5
	root.scale = Vector3(0.7, 0.4, 0.7)
	_crack(g, 1.5, 0.9)
	_crack(g, 0.9, 0.7)
	var stain := _decal(2)
	if not stain.is_empty():
		_put(stain, {"fill": 0.0, "color": Color(0.03, 0.025, 0.022), "hot": RED, "energy": 0.0, "emit": 0.0})
		(stain["mi"] as MeshInstance3D).transform = Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(3.6, 1.0, 3.6)), g + Vector3(0.0, 0.025, 0.0))
	# 흙덩이가 사방으로, 흙먼지, 땅에서 피어오르는 검은 안개
	_clods(g + Vector3(0.0, 0.2, 0.0), 14, 4.5, 1.3)
	_chips(g + Vector3(0.0, 0.1, 0.0), 10, EARTH, 3.5, 0.9)
	_dust(g, 22, 3.6, 0.7, 1.5)
	var mist := _emitter()
	if mist != null:
		mist.amount = 12
		mist.lifetime = 2.2
		mist.explosiveness = 0.85
		mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		mist.emission_sphere_radius = 0.5
		mist.direction = Vector3.UP
		mist.spread = 35.0
		mist.initial_velocity_min = 0.6
		mist.initial_velocity_max = 1.8
		mist.damping_min = 0.6
		mist.damping_max = 1.2
		mist.gravity = Vector3(0.0, 0.35, 0.0)
		mist.angle_min = -180.0
		mist.angle_max = 180.0
		mist.angular_velocity_min = -40.0
		mist.angular_velocity_max = 40.0
		_curve(mist, 0.6, 2.2)
		_ramp(mist, [Color(MIST, 0.0), Color(MIST, 0.75), Color(MIST, 0.0)], [0.0, 0.15, 1.0])
		mist.mesh = _quad(1.3, Q_LIT)
		_fire(mist, g + Vector3(0.0, 0.3, 0.0))
	_play(&"grave_rise", g, -1.0)
	_job(_run_grave, {"node": holder, "root": root, "decal": stain})


func _run_grave(j: Dictionary, _dt: float) -> bool:
	var t: float = j["t"]
	var root: Node3D = j["root"]
	if not is_instance_valid(root):
		return false
	# 0.22초에 솟으며 조금 넘쳤다가 자리 잡고, 끝에 1.5초 동안 가라앉는다
	var k: float = clampf(t / 0.22, 0.0, 1.0)
	var over: float = sin(k * PI) * 0.12 * (1.0 - k * 0.5)
	var up: float = 1.0 - pow(1.0 - k, 3.0)
	var sink: float = clampf((t - grave_time) / 1.5, 0.0, 1.0)
	root.position.y = lerpf(-0.5, 0.0, up) + over - sink * 0.42
	var s: float = lerpf(0.7, 1.0, up)
	root.scale = Vector3(s, lerpf(0.4, 1.0, up) * (1.0 - sink * 0.4), s)
	_put(j["decal"], {"fill": clampf(t / 0.3, 0.0, 1.0) * 0.8 * (1.0 - sink)})
	return sink < 1.0


# ---------------------------------------------------------------- 포위

## 적이 이 변에서만 나온다(Rules.siege_side). 그 변을 따라 짓밟힌 검은 띠가 깔리고 먼지가 안쪽으로 밀려든다.
func on_siege_side(side: Variant) -> void:
	_build()
	var s: int = _side_index(side)
	if not _siege.is_empty():
		_siege["out"] = float(_siege["t"])
		_siege = {}
	if s < 0:
		return
	var size := Vector2(Grid.size)
	var length: float = Grid.cells_to_meters(size.x if s < 2 else size.y)
	var depth: float = Grid.cells_to_meters(SIEGE_DEPTH)
	var yaw: float = [0.0, PI, PI * 0.5, -PI * 0.5][s]
	var edge_c: Vector2 = [Vector2(size.x * 0.5, 0.0), Vector2(size.x * 0.5, size.y), Vector2(0.0, size.y * 0.5), Vector2(size.x, size.y * 0.5)][s]
	var inward: Vector2 = [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)][s]
	var b := Basis(Vector3.UP, yaw)
	var center: Vector3 = _ground(edge_c + inward * SIEGE_DEPTH * 0.5, 0.03)
	var d := _decal(1)
	if not d.is_empty():
		_put(d, {"fill": 0.0, "color": Color(0.03, 0.025, 0.022), "hot": Color(0.3, 0.04, 0.025), "emit": 0.9})
		(d["mi"] as MeshInstance3D).transform = Transform3D(b * Basis.from_scale(Vector3(length, 1.0, depth)), center)
	var dust := _emitter(true)
	if dust != null:
		dust.amount = 28
		dust.lifetime = 2.6
		dust.explosiveness = 0.0
		dust.randomness = 0.5
		dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		dust.emission_box_extents = Vector3(length * 0.48, 0.15, 0.6)
		dust.direction = Vector3(0.0, 0.25, 1.0)
		dust.spread = 25.0
		dust.initial_velocity_min = 1.2
		dust.initial_velocity_max = 2.8
		dust.damping_min = 0.4
		dust.damping_max = 0.8
		dust.gravity = Vector3(0.0, 0.1, 0.0)
		dust.angle_min = -180.0
		dust.angle_max = 180.0
		_curve(dust, 0.6, 1.8)
		_ramp(dust, [Color(DUST, 0.0), Color(DUST, 0.32), Color(DUST.darkened(0.1), 0.0)], [0.0, 0.2, 1.0])
		dust.mesh = _quad(1.6, Q_LIT)
		dust.transform = Transform3D(b, _ground(edge_c - inward * 0.2, 0.25))
		dust.emitting = true
	var job := _job(_run_siege, {"decal": d, "emit": dust, "out": -1.0})
	_siege = job
	_play(&"siege_side", _ground(edge_c, 1.0), 0.0)


func _run_siege(j: Dictionary, _dt: float) -> bool:
	var t: float = j["t"]
	var out: float = j["out"]
	var k: float = clampf(t / 0.9, 0.0, 1.0)
	if out < 0.0:
		_put(j["decal"], {"fill": k * k * (3.0 - 2.0 * k)})
		return true
	var e: Variant = j.get("emit")
	if e is CPUParticles3D and (e as CPUParticles3D).emitting:
		_release(e)
	var o: float = clampf((t - out) / 0.8, 0.0, 1.0)
	_put(j["decal"], {"fill": k * (1.0 - o)})
	return o < 1.0


func _side_index(side: Variant) -> int:
	if side == null:
		return -1
	if side is int or side is float:
		return clampi(int(side), -1, 3)
	match StringName(str(side)):
		&"north", &"top":
			return 0
		&"south", &"bottom":
			return 1
		&"west", &"left":
			return 2
		&"east", &"right":
			return 3
	return -1


# ---------------------------------------------------------------- 안개

## 짙은 안개(구역 규칙 fog): on이면 환경 안개 짙기를 mult배로, 아니면 처음 값으로 time초에 바꾼다.
## 처음 값은 처음 부를 때 env의 meta "fog_base"에 적어 둔다(두 번 불러도 겹쳐 곱하지 않는다).
func fog(env: Environment, on: bool, time: float = 2.5, mult: float = 3.0) -> Tween:
	_build()
	if env == null:
		return null
	if not env.has_meta("fog_base"):
		env.set_meta("fog_base", Vector2(env.fog_density, env.fog_height_density))
	var base: Vector2 = env.get_meta("fog_base")
	var k: float = mult if on else 1.0
	if _fog_tween and _fog_tween.is_valid():
		_fog_tween.kill()
	_fog_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fog_tween.tween_property(env, "fog_density", base.x * k, maxf(0.01, time))
	_fog_tween.tween_property(env, "fog_height_density", base.y * k, maxf(0.01, time))
	return _fog_tween


# ---------------------------------------------------------------- 우두머리 고리

## 이 노드의 발밑에 검붉은 고리를 둔다(radius_m 미터). 노드를 따라다니고, 노드가 사라지거나 숨으면 옅어져 사라진다.
func ring_follow(node: Node3D, radius_m: float = 1.3) -> void:
	_build()
	if node == null:
		return
	var key: int = node.get_instance_id()
	if _rings.has(key):
		var old: Dictionary = _rings[key]
		(old["mi"] as MeshInstance3D).scale = Vector3(radius_m * 2.0, 1.0, radius_m * 2.0)
		old["out"] = -1.0
		return
	var mi := NightArt.boss_ring(_layer, radius_m, _rng.randf() * 20.0)
	(mi.material_override as ShaderMaterial).set_shader_parameter("fade", 0.0)
	var j := _job(_run_ring, {"node_ref": weakref(node), "mi": mi, "node": mi, "key": key, "out": -1.0, "k": 0.0})
	_rings[key] = j
	_run_ring(j, 0.0)
	if node.is_inside_tree():
		_dust(_ground(Grid.world_to_cells(node.global_position), 0.0), 12, 2.5, radius_m * 0.5, 0.9)


## 고리를 거둔다(옅어져 사라진다).
func ring_drop(node: Node3D) -> void:
	if node == null:
		return
	var key: int = node.get_instance_id()
	if _rings.has(key):
		var j: Dictionary = _rings[key]
		if float(j["out"]) < 0.0:
			j["out"] = float(j["t"])


func _run_ring(j: Dictionary, dt: float) -> bool:
	var n: Variant = (j["node_ref"] as WeakRef).get_ref()
	var mi: MeshInstance3D = j["mi"]
	var alive: bool = n is Node3D and (n as Node3D).is_inside_tree() and (n as Node3D).is_visible_in_tree()
	if alive:
		var p: Vector3 = (n as Node3D).global_position
		mi.position = Vector3(p.x, HillBuilder.height(p.x, p.z) + 0.035, p.z)
	elif float(j["out"]) < 0.0:
		j["out"] = float(j["t"])
	var k: float = j["k"]
	if float(j["out"]) < 0.0:
		k = minf(1.0, k + dt / 0.5)
	else:
		k = maxf(0.0, k - dt / 0.4)
	j["k"] = k
	(mi.material_override as ShaderMaterial).set_shader_parameter("fade", k)
	if float(j["out"]) >= 0.0 and k <= 0.0:
		_rings.erase(j["key"])
		return false
	return true


# ---------------------------------------------------------------- 일(job)

func _job(fn: Callable, j: Dictionary) -> Dictionary:
	j["t"] = 0.0
	j["fn"] = fn
	_jobs.append(j)
	return j


func _end_job(j: Dictionary) -> void:
	for key in ["decal", "emit"]:
		var v: Variant = j.get(key)
		var list: Array = v if v is Array else [v]
		for x: Variant in list:
			if x is Dictionary:
				_free_decal(x)
			elif x is CPUParticles3D:
				_release(x)
	for key in ["node", "nodes"]:
		var v: Variant = j.get(key)
		var list: Array = v if v is Array else [v]
		for x: Variant in list:
			if x is Node and is_instance_valid(x):
				(x as Node).queue_free()
	var vo: Variant = j.get("voice")
	if vo is AudioStreamPlayer3D:
		var p: AudioStreamPlayer3D = vo
		if p.playing and int(p.get_meta("serial", -1)) == int(j.get("voice_serial", -2)):
			p.stop()


# ---------------------------------------------------------------- 땅 판(돌려 쓴다)

func _decal(mode: int) -> Dictionary:
	var d: Dictionary = {}
	for x in _decals:
		if not bool(x["busy"]):
			d = x
			break
	if d.is_empty():
		if _decals.size() >= MAX_DECALS:
			return {}
		var mi := MeshInstance3D.new()
		mi.mesh = _plane
		var mat := ShaderMaterial.new()
		mat.shader = _decal_shader
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_layer.add_child(mi)
		d = {"mi": mi, "mat": mat}
		_decals.append(d)
	d["busy"] = true
	_serial += 1
	var m: ShaderMaterial = d["mat"]
	m.set_shader_parameter("mode", mode)
	for k: String in ["fill", "burn", "scorch", "energy"]:
		m.set_shader_parameter(k, 0.0)
	m.set_shader_parameter("fade", 1.0)
	m.set_shader_parameter("emit", 2.0)
	m.set_shader_parameter("cell", 1.1)
	m.set_shader_parameter("seed", float(_serial % 37) * 3.7)
	m.set_shader_parameter("color", CHAR)
	m.set_shader_parameter("hot", EMBER)
	(d["mi"] as MeshInstance3D).visible = true
	(d["mi"] as MeshInstance3D).sorting_offset = float(_serial % 8) * 0.01
	return d


func _free_decal(d: Dictionary) -> void:
	if d.is_empty():
		return
	d["busy"] = false
	(d["mi"] as MeshInstance3D).visible = false


func _put(d: Dictionary, values: Dictionary) -> void:
	if d.is_empty():
		return
	var m: ShaderMaterial = d["mat"]
	for k: String in values:
		m.set_shader_parameter(k, values[k])


## 갈라진 틈(MoveArt의 금 모양): 빠르게 자라 어두운 금으로 남았다가 hold초에 사라진다.
func _crack(at: Vector3, r: float, hold: float) -> void:
	var key: String = "crack%d_%d" % [roundi(r * 10.0), _rng.randi() % 4]
	if not _cache.has(key):
		_cache[key] = MoveArt.crack_mesh(_rng.randi(), r)
	var m := MeshInstance3D.new()
	m.mesh = _cache[key]
	var mat := MoveArt.crack_material(Color(0.5, 0.2, 0.1))
	mat.set_shader_parameter("grow", 0.0)
	mat.set_shader_parameter("energy", 0.0)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = Vector3(at.x, _hy(at) + 0.034, at.z)
	m.rotation.y = _rng.randf() * TAU
	_layer.add_child(m)
	_job(_run_crack, {"node": m, "mat": mat, "hold": hold})


func _run_crack(j: Dictionary, _dt: float) -> bool:
	var t: float = j["t"]
	var mat: ShaderMaterial = j["mat"]
	mat.set_shader_parameter("grow", clampf(1.0 - pow(1.0 - t / 0.15, 2.0), 0.0, 1.0))
	var k: float = (t - float(j["hold"])) / 0.8
	if k >= 1.0:
		return false
	mat.set_shader_parameter("fade", 1.0 - clampf(k, 0.0, 1.0))
	return true


## 짧은 빛(돌려 쓴다). time초에 걸쳐 꺼진다.
func _light(at: Vector3, c: Color, energy: float, range_m: float, time: float) -> void:
	var l: OmniLight3D = null
	for x in _lights:
		if float(x.get_meta("until", 0.0)) <= _clock:
			l = x
			break
	if l == null:
		return
	l.set_meta("until", _clock + time)
	l.position = at
	l.light_color = c
	l.light_energy = energy
	l.omni_range = range_m
	l.omni_attenuation = 1.3
	l.visible = true
	_job(_run_light, {"light": l, "energy": energy, "time": time})


func _run_light(j: Dictionary, _dt: float) -> bool:
	var l: OmniLight3D = j["light"]
	var k: float = float(j["t"]) / float(j["time"])
	if k >= 1.0:
		l.visible = false
		return false
	l.light_energy = float(j["energy"]) * pow(1.0 - k, 2.0)
	return true


# ---------------------------------------------------------------- 알갱이(돌려 쓴다)

## 쉬는 알갱이 노드 하나를 처음 값으로 돌려준다(없으면 null). hold면 놓을 때까지(_release) 다른 데 쓰지 않는다.
func _emitter(hold: bool = false) -> CPUParticles3D:
	var p: CPUParticles3D = null
	for x in _emitters:
		if float(x.get_meta("free_at", 0.0)) <= _clock:
			p = x
			break
	if p == null:
		if _emitters.size() >= MAX_EMITTERS:
			return null
		p = CPUParticles3D.new()
		_layer.add_child(p)
		_emitters.append(p)
	_reset(p)
	p.set_meta("free_at", 1e12 if hold else _clock + 0.05)
	if hold:
		p.one_shot = false
	return p


func _fire(p: CPUParticles3D, at: Vector3) -> void:
	p.one_shot = true
	p.position = at
	p.set_meta("free_at", _clock + p.lifetime + 0.15)
	p.restart()


func _release(p: CPUParticles3D) -> void:
	if p == null or not is_instance_valid(p):
		return
	p.emitting = false
	p.set_meta("free_at", _clock + p.lifetime + 0.15)


func _reset(p: CPUParticles3D) -> void:
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.one_shot = true
	p.amount = 8
	p.lifetime = 1.0
	p.explosiveness = 0.9
	p.randomness = 0.0
	p.local_coords = false
	p.speed_scale = 1.0
	p.transform = Transform3D.IDENTITY
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINT
	p.emission_sphere_radius = 0.1
	p.emission_box_extents = Vector3.ONE
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_height = 0.0
	p.emission_ring_radius = 1.0
	p.emission_ring_inner_radius = 0.0
	p.direction = Vector3(1.0, 0.0, 0.0)
	p.spread = 45.0
	p.flatness = 0.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	p.gravity = Vector3(0.0, -9.8, 0.0)
	p.damping_min = 0.0
	p.damping_max = 0.0
	p.angular_velocity_min = 0.0
	p.angular_velocity_max = 0.0
	p.tangential_accel_min = 0.0
	p.tangential_accel_max = 0.0
	p.radial_accel_min = 0.0
	p.radial_accel_max = 0.0
	p.angle_min = 0.0
	p.angle_max = 0.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.0
	p.scale_amount_curve = null
	p.color = Color.WHITE
	p.color_ramp = null
	p.color_initial_ramp = null
	p.particle_flag_align_y = false
	p.mesh = null


## 흙먼지: 땅을 따라 둥글게 퍼진다.
func _dust(at: Vector3, amount: int, speed: float, size: float, life: float) -> void:
	var p := _emitter()
	if p == null:
		return
	p.amount = maxi(1, amount)
	p.lifetime = life
	p.explosiveness = 0.92
	p.direction = Vector3(1.0, 0.25, 0.0)
	p.spread = 180.0
	p.flatness = 0.85
	p.initial_velocity_min = speed * 0.45
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.8
	p.damping_max = speed * 1.2
	p.gravity = Vector3(0.0, 0.15, 0.0)
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	_curve(p, 0.4, 1.6)
	_ramp(p, [Color(DUST, 0.45), Color(DUST.darkened(0.1), 0.0)], [0.0, 1.0])
	p.mesh = _quad(size * 2.0, Q_LIT)
	_fire(p, at + Vector3(0.0, 0.1, 0.0))


## 불똥: 가는 빛줄이 날아가는 쪽으로 늘어서 튄다.
func _sparks(at: Vector3, amount: int, dir: Vector3, spread: float, vmin: float, vmax: float, c: Color, life: float, slow: bool = false) -> void:
	var p := _emitter()
	if p == null:
		return
	p.amount = maxi(1, amount)
	p.lifetime = life
	p.explosiveness = 0.96
	p.randomness = 0.4
	p.direction = dir.normalized() if dir.length_squared() > 0.001 else Vector3.UP
	p.spread = spread
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = Vector3(0.0, -4.0 if slow else -11.0, 0.0)
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.particle_flag_align_y = true
	p.scale_amount_min = 0.4 if slow else 0.5
	p.scale_amount_max = 0.8 if slow else 1.1
	_ramp(p, [Color(c.r * 3.0, c.g * 2.6, c.b * 2.2, 1.0), Color(c.r * 1.2, c.g * 0.6, c.b * 0.4, 0.6), Color(c.r * 0.6, c.g * 0.25, c.b * 0.1, 0.0)], [0.0, 0.5, 1.0])
	p.mesh = _spark_mesh
	_fire(p, at)


## 오르는 불씨(둥근 빛 점, 천천히 흔들리며 오르다 꺼진다).
func _embers_up(at: Vector3, amount: int, r: float, life: float) -> void:
	var p := _emitter()
	if p == null:
		return
	p.amount = maxi(1, amount)
	p.lifetime = life
	p.explosiveness = 0.8
	p.randomness = 0.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = r
	p.direction = Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.6
	p.gravity = Vector3(0.0, 0.4, 0.0)
	p.damping_min = 0.6
	p.damping_max = 1.2
	p.tangential_accel_min = -1.2
	p.tangential_accel_max = 1.2
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.1
	_ramp(p, [Color(1.7, 0.85, 0.38, 1.0), Color(1.2, 0.4, 0.1, 0.85), Color(0.4, 0.08, 0.02, 0.0)], [0.0, 0.55, 1.0])
	p.mesh = _quad(0.045, Q_ADD)
	_fire(p, at)


## 재: 잿빛 조각이 흩날린다.
func _ash(at: Vector3, amount: int, size: float) -> void:
	var p := _emitter()
	if p == null:
		return
	p.amount = maxi(1, amount)
	p.lifetime = 1.6
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.2
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.5
	p.damping_min = 0.5
	p.damping_max = 1.0
	p.gravity = Vector3(0.0, 0.25, 0.0)
	p.angle_min = -180.0
	p.angle_max = 180.0
	_curve(p, 0.5, 1.8)
	_ramp(p, [Color(SMOKE, 0.5), Color(SMOKE, 0.0)], [0.0, 1.0])
	p.mesh = _quad(size, Q_LIT)
	_fire(p, at)


## 작은 조각(흙, 나뭇조각): 튀어 올라 돌며 떨어진다.
func _chips(at: Vector3, amount: int, c: Color, speed: float, life: float) -> void:
	var p := _emitter()
	if p == null:
		return
	p.amount = maxi(1, amount)
	p.lifetime = life
	p.explosiveness = 0.95
	p.randomness = 0.5
	p.direction = Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0.0, -12.0, 0.0)
	p.angular_velocity_min = -480.0
	p.angular_velocity_max = 480.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.color = c
	p.mesh = _chip_mesh
	_fire(p, at)


## 흙덩이: 둥근 덩이가 솟구쳐 흩어져 떨어진다.
func _clods(at: Vector3, amount: int, speed: float, life: float) -> void:
	var p := _emitter()
	if p == null:
		return
	p.amount = maxi(1, amount)
	p.lifetime = life
	p.explosiveness = 0.97
	p.randomness = 0.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.35
	p.direction = Vector3.UP
	p.spread = 50.0
	p.initial_velocity_min = speed * 0.45
	p.initial_velocity_max = speed
	p.gravity = Vector3(0.0, -12.0, 0.0)
	p.angular_velocity_min = -300.0
	p.angular_velocity_max = 300.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.5
	p.color = EARTH
	p.mesh = _clod_mesh
	_fire(p, at)


func _ramp(p: CPUParticles3D, cols: Array, offs: Array) -> void:
	p.color_ramp = NightArt._gradient(cols, offs)


func _curve(p: CPUParticles3D, a: float, b: float) -> void:
	p.scale_amount_curve = NightArt._curve(a, b)


func _curve3(p: CPUParticles3D, a: float, b: float, c3: float) -> void:
	var c := Curve.new()
	c.max_value = maxf(a, maxf(b, c3))
	c.add_point(Vector2(0.0, a))
	c.add_point(Vector2(0.25, b))
	c.add_point(Vector2(1.0, c3))
	p.scale_amount_curve = c


## 알갱이 판(종류·크기별로 한 번만). Q_ADD = 더해 그리는 둥근 빛(불씨), Q_FIRE = 스스로 빛나는 들쭉날쭉한 불 조각,
## Q_LIT = 땅처럼 빛을 받는 들쭉날쭉한 조각(먼지, 연기, 안개, 재).
func _quad(size: float, kind: int) -> QuadMesh:
	var key: String = "%d_%.3f" % [kind, size]
	if _quads.has(key):
		return _quads[key]
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = [_add_mat, _mix_mat, _lit_mat][kind]
	_quads[key] = q
	return q


func _particle_mat(add: bool, tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.disable_receive_shadows = true
	return m


# ---------------------------------------------------------------- 소리

## 이름의 소리를 at에서 튼다(높낮이를 조금 흔든다). 튼 재생기를 돌려준다.
func _play(name: StringName, at: Vector3, db: float, pitch: float = 1.0) -> AudioStreamPlayer3D:
	if not _streams.has(name) or _voices.is_empty():
		return null
	var list: Array = _streams[name]
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	p.stream = list[_rng.randi() % list.size()]
	p.position = at
	p.volume_db = db + volume_db
	p.pitch_scale = pitch * (1.0 + _rng.randf_range(-0.04, 0.04))
	_serial += 1
	p.set_meta("serial", _serial)
	p.play()
	return p


## SOUNDS의 값으로 짧은 소리를 만든다(한 번만, 같은 시드라 늘 같다).
static func _sound(key: StringName) -> AudioStreamWAV:
	var ck: String = "snd_" + str(key)
	if _cache.has(ck):
		return _cache[ck]
	var s: Dictionary = SOUNDS[key]
	var dur: float = float(s.get("dur", 0.3))
	var n: int = int(dur * RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var f0: float = float(s.get("f0", 0.0))
	var f1: float = float(s.get("f1", f0))
	var tone: float = float(s.get("tone", 0.0))
	var tdec: float = float(s.get("tdecay", 8.0))
	var partials: Array = s.get("partials", [])
	var noise: float = float(s.get("noise", 0.0))
	var ndec: float = float(s.get("ndecay", 10.0))
	var lp_a: float = 1.0 - exp(-TAU * float(s.get("lp", 4000.0)) / RATE)
	var hp_f: float = float(s.get("hp", 0.0))
	var hp_a: float = 1.0 - exp(-TAU * hp_f / RATE)
	var attack: float = maxf(0.0005, float(s.get("attack", 0.002)))
	var crackle: float = float(s.get("crackle", 0.0))
	var swell: bool = bool(s.get("swell", false))
	var clicks: Array = s.get("clicks", [])
	var phase: float = 0.0
	var pph: Array[float] = []
	pph.resize(partials.size())
	pph.fill(0.0)
	var lp: float = 0.0
	var hp: float = 0.0
	var buf := PackedFloat32Array()
	buf.resize(n)
	var peak: float = 0.0001
	for i in n:
		var t: float = float(i) / RATE
		var k: float = t / dur
		var v: float = 0.0
		if tone > 0.0 and f0 > 0.0:
			phase += TAU * f0 * pow(f1 / f0, k) / RATE
			v += sin(phase) * tone * exp(-t * tdec)
		for q in partials.size():
			var pr: Array = partials[q]
			pph[q] += TAU * float(pr[0]) / RATE
			v += sin(pph[q]) * float(pr[1]) * exp(-t * float(pr[2]))
		if noise > 0.0:
			var w: float = rng.randf_range(-1.0, 1.0)
			if crackle > 0.0 and rng.randf() < crackle:
				w *= 5.0
			lp += lp_a * (w - lp)
			var x: float = lp
			if hp_f > 0.0:
				hp += hp_a * (x - hp)
				x -= hp
			var ne: float = (0.3 + 0.7 * k) if swell else exp(-t * ndec)
			v += x * noise * 3.0 * ne
		for c: float in clicks:
			if t >= c and t < c + 0.004:
				v += rng.randf_range(-1.0, 1.0) * (1.0 - (t - c) / 0.004)
		v *= (1.0 - exp(-t / attack)) * (1.0 - smoothstep(0.85, 1.0, k))
		buf[i] = v
		peak = maxf(peak, absf(v))
	var level: float = float(s.get("level", 0.8)) / peak
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i] * level, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	_cache[ck] = wav
	return wav


# ---------------------------------------------------------------- 도움

## 칸 위치의 땅 위 lift m(세계 좌표).
func _ground(cells: Vector2, lift: float) -> Vector3:
	var w: Vector3 = Grid.cells_to_world(cells)
	w.y = HillBuilder.height(w.x, w.z) + lift
	return w


func _hy(p: Vector3) -> float:
	return HillBuilder.height(p.x, p.z)
