class_name EnemyFx
extends Node3D
## 11단계 새 적 5종의 효과(이펙트팀, docs/content.md "11단계: 적 행동"). Rules의 enemy_act와 enemy_projectile_* 신호를 받아 그린다.
##   활잡이   겨눈 선(땅의 가는 검붉은 줄, 겨누는 동안 짙어진다), 날아가는 화살과 옅은 꼬리, 꽂힘·맞음·부러짐
##   방패병   막을 때 불똥·쇠 번쩍임·흙먼지와 둔한 쇳소리, 깨질 때 더 큰 불똥·나뭇조각·먼지와 낮게 갈라지는 소리
##   돌격병   발굽 긁는 먼지, 돌진할 길(땅의 검붉은 띠가 머리 낮추는 동안 찬다), 달리는 먼지 꼬리와 땅 금, 멈춤 먼지, 비틀거림 티끌
##   자폭병   위험 원(심지가 타는 동안 찬다), 배의 틈에서 튀는 불똥과 쉬익 소리, 폭발(불덩이, 충격파, 파편, 그을음, 짧은 빛, 낮은 울림)
##   부르는 자 둘레의 재와 불씨 고리(점점 짙어진다), 부를 자리마다 땅이 갈라지고 검은 안개, 지팡이 끝의 충격 고리
## 어두운 사실풍: 땅·쇠·불·먼지에서 나오는 것만. 글자, 문양, 별 모양, 형광빛은 쓰지 않는다.
## 꾸밈용 랜덤은 이 노드의 것(_rng)이다. Rules.rng는 건드리지 않는다.
##
## main(기능팀)이 쓰는 법:
##   var efx := EnemyFx.new(); add_child(efx)
##   efx.setup(rules, body_of)          # Rules에 있는 신호만 이름으로 잇는다(아직 없어도 죽지 않는다):
##                                       #   enemy_act → on_act, enemy_projectile_spawned → on_projectile_spawned,
##                                       #   enemy_projectile_ended → on_projectile_ended
##       body_of(e: Enemy) -> Dictionary  (없어도 된다) 그 적의 EnemyArt 부품(EnemyView가 지은 parts). 있으면 방패·배·지팡이 끝·
##                                       발굽·머리의 실제 자리에서 터지고, 없으면 적 위치·face·크기로 어림한다.
##   _process에서 efx.draw(alpha)        # 화살과 적을 따라가는 효과를 틱 사이로 이어 그린다(MoveFx.draw와 같이, main이 부모라 먼저 돈다)
##   efx.exploded.connect(...)           # 폭발: 세계 자리와 세기(반지름 2.2칸 = 1). 카메라 흔들림·FOV 차기는 main이 한다
##   판이 끝나거나 낮이 되면 efx.clear()
## 갤러리(scripts/debug/enemy_gallery.gd)는 on_* 함수를 가짜 Enemy·Projectile·info로 바로 부른다(Rules 없이).
##
## 읽는 것
##   Enemy: pos, prev_pos, face, radius, data.radius, dead, act(있으면: 행동이 바뀌거나 끊기면 미리 보기를 일찍 거둔다)
##   Projectile: pos, prev_pos, dir, id, kind(arrow), cut(있으면: 영주의 좌클릭에 부러짐)
##   info(docs/content.md 표): aim{from, dir, time, length?} shoot{from, dir} block{at, dir} guard_break{at, time}
##     wind{from, dir, length, time, width?} charge{from, to, time?} charge_end{at, hit, time, stun?} fuse{at, radius, time}
##     explode{at, radius} call_wind{at, radius, time} call{at, count, spots?}
##     ?가 붙은 열쇠는 없으면 표의 첫 값이나 적 크기로 어림한다. call의 spots(부를 자리, 칸 Vector2 배열)가 없으면 둘레에 고르게 놓는다.
## 화살이 끝날 때: hit = true면 영주에게 맞아 작은 불똥과 함께 사라지고, 아니면 p.cut(또는 셋째 인자)이 true면 두 동강 나 튕기고,
##   둘 다 아니면 사거리 끝에서 땅에 꽂혀 떨다가 arrow_stuck초 뒤 가라앉는다.
## 빛: 자폭병·부르는 자의 glow는 모션팀(EnemyMotion.animate)이 매 프레임 쓴다. 여기서는 건드리지 않는다.
## 소리: 위치가 있는 AudioStreamPlayer3D. assets/sound/<이름>/에 파일이 있으면 그것을, 없으면 여기서 만든 짧은 소리를 튼다(SOUNDS).
##   종소리, 올라가는 삐 소리, 위로 쓸어 올리는 소리는 없다(모두 내려가거나 고른 음과 잡음).
## 가볍게: 알갱이 노드·땅 판·조각·화살·빛·소리는 모두 미리 만든 것을 돌려 쓴다(MAX_*). 넘치면 그 효과의 일부만 거른다.
## 이 노드는 top_level이고 원점에 있어서 자식의 위치가 곧 세계 좌표다.

## 폭발했다. pos_world = 세계 자리, strength = 반지름 / 2.2칸(0.4~2).
signal exploded(pos_world: Vector3, strength: float)

const SIGNALS: Dictionary = {
	&"enemy_act": "on_act",
	&"enemy_projectile_spawned": "on_projectile_spawned",
	&"enemy_projectile_ended": "on_projectile_ended",
}
## info에 없을 때 쓰는 규칙의 첫 값(칸, 초). docs/content.md 11단계 표.
const ARROW_RANGE: float = 12.0
const CHARGE_SPEED: float = 13.0
const CALL_RADIUS: float = 1.6
const BLAST_RADIUS: float = 2.2
## 한도: 한꺼번에 쓰는 알갱이 노드, 땅 판, 조각(파편·부러진 화살), 날아가는 화살, 빛, 소리.
const MAX_EMITTERS: int = 28
const MAX_DECALS: int = 24
const MAX_CHUNKS: int = 36
const MAX_ARROWS: int = 16
const LIGHTS: int = 3
const VOICES: int = 10
## 화살이 끝 신호 없이 이만큼(초) 날면 사거리 끝으로 본다.
const ARROW_MAX_AGE: float = 3.0
## 부러지는 자리(촉에서 m).
const ARROW_CUT: float = 0.42

const RED := Color(0.34, 0.035, 0.025)
const RED_HOT := Color(0.6, 0.09, 0.045)
## 먼지·재·연기·안개(빛을 받는 바탕색).
const DUST := Color(0.45, 0.4, 0.34)
const EMBER := Color(1.0, 0.42, 0.12)
const SPARK := Color(1.0, 0.6, 0.26)
const STEEL := Color(0.86, 0.9, 0.97)
const ASH := Color(0.46, 0.44, 0.41)
const MIST := Color(0.075, 0.08, 0.085)
const CHAR := Color(0.07, 0.058, 0.05)
## 부르는 자리의 갈라진 틈에서 새는 흐린 찬빛(등불과 같은 결, 훨씬 어둡게).
const CRACK_COLD := Color(0.4, 0.52, 0.46)

## 땅 판 셰이더. 모양(mode): 0 위험 띠(돌진 길), 1 위험 원(심지), 2 겨눈 줄, 3 충격 고리(먼지), 4 그을음, 5 재·불씨 고리.
## 1 × 1 PlaneMesh를 노드 크기로 늘린다. 섞어 그리고 땅처럼 빛을 받는다(낮에는 밝고 밤에는 어둡다).
## 빛나는 곳(위험 표시의 검붉은 빛, 불씨)만 EMISSION으로 스스로 빛나서 밤에도 보인다(emit = 그 세기).
## fill: 띠·원은 찬 정도(0~1), 겨눈 줄은 짙기, 충격 고리는 퍼진 정도, 재 고리는 세기. ew·hw: 테·머리 폭(판 크기에 대한 비율).
const DECAL_SHADER := """shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, specular_disabled;
uniform int mode = 0;
uniform float emit = 0.0;
uniform vec4 color : source_color = vec4(0.42, 0.045, 0.03, 1.0);
uniform vec4 hot : source_color = vec4(0.74, 0.12, 0.055, 1.0);
uniform float fill = 0.0;
uniform float fade = 1.0;
uniform float energy = 0.0;
uniform float ew = 0.08;
uniform float hw = 0.02;
uniform float seed = 0.0;
varying vec2 lp;
varying vec2 wxz;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	lp = VERTEX.xz + 0.5;
	wxz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	float n = vn(wxz * 1.6 + seed);
	float n2 = vn(wxz * 5.1 + seed * 1.7 + 11.0);
	float a = 0.0;
	float heat = 0.0;
	if (mode == 0 || mode == 2) {
		float along = 1.0 - lp.y;
		float across = abs(lp.x - 0.5) * 2.0;
		if (mode == 0) {
			float cap = smoothstep(0.0, hw * 1.5, along) * (1.0 - smoothstep(1.0 - hw * 1.5, 1.0, along));
			float edge = smoothstep(1.0 - ew * 2.2, 1.0 - ew, across) * (1.0 - smoothstep(1.0 - ew * 0.35, 1.0, across));
			float inside = 1.0 - smoothstep(1.0 - ew, 1.0, across);
			float filled = 1.0 - smoothstep(fill - hw, fill, along);
			float head = exp(-pow((along - fill) / hw, 2.0)) * step(0.002, fill) * (1.0 - step(0.998, fill));
			float tip = exp(-pow((along - 1.0 + hw * 2.5) / hw, 2.0));
			float grain = 0.62 + 0.38 * n;
			a = (0.14 * inside * grain + 0.5 * edge * (0.75 + 0.25 * n2) + 0.3 * filled * inside * grain + 0.5 * head * inside + 0.35 * tip * inside) * cap;
			heat = clamp(edge * 0.7 + head + 0.2 * filled + 0.5 * tip, 0.0, 1.0);
		} else {
			float core = pow(clamp(1.0 - across, 0.0, 1.0), 1.6);
			float taper = smoothstep(0.0, 0.015, along) * pow(clamp(1.0 - along, 0.0, 1.0), 0.8);
			float shimmer = 0.86 + 0.14 * sin(along * 90.0 - TIME * 14.0);
			a = core * taper * shimmer * (0.1 + 0.62 * fill);
			heat = core * clamp(fill, 0.0, 1.0) * 0.8;
		}
	} else {
		vec2 q = lp - 0.5;
		float r = length(q) * 2.0;
		if (r > 1.0) { discard; }
		if (mode == 1) {
			float edge = smoothstep(1.0 - ew * 2.2, 1.0 - ew, r) * (1.0 - smoothstep(1.0 - ew * 0.3, 1.0, r));
			float inside = 1.0 - smoothstep(1.0 - ew, 1.0, r);
			float filled = 1.0 - smoothstep(fill - hw, fill, r);
			float head = exp(-pow((r - fill) / hw, 2.0)) * step(0.002, fill) * (1.0 - step(0.998, fill));
			float grain = 0.62 + 0.38 * n;
			a = 0.12 * inside * grain + 0.5 * edge * (0.75 + 0.25 * n2) + 0.26 * filled * inside * grain + 0.3 * head * inside;
			heat = clamp(edge * 0.7 + head + 0.3 * filled * energy, 0.0, 1.0);
		} else if (mode == 3) {
			float band = smoothstep(fill - 0.2, fill, r) * (1.0 - smoothstep(fill, fill + 0.04, r));
			a = band * pow(clamp(1.0 - fill, 0.0, 1.0), 1.2) * 0.6 * (0.55 + 0.45 * n2) * smoothstep(0.1, 0.2, fill);
		} else if (mode == 4) {
			float rr = r + (n - 0.5) * 0.42 + (n2 - 0.5) * 0.12;
			a = (1.0 - smoothstep(0.45, 0.95, rr)) * (0.7 + 0.3 * n2) * 0.85;
			heat = smoothstep(0.74, 0.92, vn(wxz * 11.0 + seed * 2.3)) * (1.0 - smoothstep(0.1, 0.6, rr)) * energy;
		} else {
			float rr = r + (n2 - 0.5) * 0.05;
			float ring = exp(-pow((rr - 0.9) / max(ew, 0.01), 2.0));
			float sp = vn(wxz * 7.0 + vec2(TIME * 0.35, -TIME * 0.25) + seed);
			float flick = 0.65 + 0.35 * sin(TIME * 9.0 + n2 * 31.0);
			float inner = (1.0 - smoothstep(0.78, 0.9, r)) * 0.08;
			a = (ring * (0.45 + 0.3 * n) + inner * n) * clamp(fill, 0.0, 1.0);
			heat = ring * smoothstep(0.66, 0.86, sp) * flick * energy;
		}
	}
	float h = clamp(heat, 0.0, 1.0);
	ALBEDO = mix(color.rgb, hot.rgb, h);
	ROUGHNESS = 1.0;
	if (mode <= 2) {
		EMISSION = mix(color.rgb, hot.rgb, h) * emit;
	} else {
		EMISSION = hot.rgb * h * emit;
	}
	ALPHA = clamp(a * fade, 0.0, 1.0);
}
"""

## 땅처럼 빛을 받는 알갱이(먼지, 연기, 안개, 재). 판은 카메라를 보지만 법선은 위를 봐서 땅과 같은 빛을 받는다.
## 꺼진 빛 그대로(unshaded) 칠하면 낮의 톤매핑에서 땅보다 어둡게 뭉치고 밤에는 떠 보여서 이렇게 한다.
const LIT_SHADER := """shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, specular_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap, hint_default_white;
void vertex() {
	mat4 mw = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	mw = mw * mat4(vec4(cos(INSTANCE_CUSTOM.x), -sin(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(sin(INSTANCE_CUSTOM.x), cos(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * mw;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
void fragment() {
	vec4 t = texture(tex, UV);
	ALBEDO = COLOR.rgb * t.rgb;
	ALPHA = clamp(COLOR.a * t.a, 0.0, 1.0);
	ROUGHNESS = 1.0;
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}
"""

## 화살 꼬리: UV.x 0(화살 깃) → 1(꼬리 끝)으로 옅어지는 가는 줄(더해 그린다, 아주 옅게).
const TRAIL_SHADER := """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(0.62, 0.6, 0.56, 1.0);
uniform float fade = 1.0;
void fragment() {
	float u = UV.x;
	float across = abs(UV.y - 0.5) * 2.0;
	float a = pow(clamp(1.0 - u, 0.0, 1.0), 1.8) * (1.0 - smoothstep(0.0, 1.0, across)) * smoothstep(0.0, 0.04, u);
	ALBEDO = color.rgb;
	ALPHA = clamp(a * fade * 0.5, 0.0, 1.0);
}
"""

## 파일이 없을 때 만드는 소리. 열쇠: dur(초), f0→f1(내려가는 음, Hz), tone(세기), tdecay(1/초),
## partials([Hz, 세기, 1/초] 빨리 죽는 쇠 울림: 종처럼 남지 않는다), noise(세기), lp·hp(Hz), ndecay(1/초),
## attack(초), crackle(튀는 잡음 확률), swell(잡음이 점점 커진다: 음높이는 그대로), clicks(초 목록, 짧은 딱 소리), level(최고 크기).
const SOUNDS: Dictionary = {
	&"enemy_bow": {"dur": 0.16, "f0": 130.0, "f1": 95.0, "tone": 0.25, "tdecay": 28.0, "noise": 0.4, "lp": 3200.0, "hp": 900.0, "ndecay": 26.0, "level": 0.6},
	&"enemy_arrow_hit": {"dur": 0.13, "f0": 170.0, "f1": 95.0, "tone": 0.5, "tdecay": 34.0, "noise": 0.3, "lp": 2000.0, "ndecay": 45.0, "partials": [[640.0, 0.12, 60.0]], "level": 0.7},
	&"enemy_arrow_ground": {"dur": 0.12, "f0": 120.0, "f1": 70.0, "tone": 0.45, "tdecay": 30.0, "noise": 0.35, "lp": 1200.0, "ndecay": 40.0, "level": 0.6},
	&"enemy_arrow_cut": {"dur": 0.09, "noise": 0.6, "lp": 5200.0, "hp": 1400.0, "ndecay": 60.0, "clicks": [0.0, 0.012], "level": 0.6},
	&"enemy_block": {"dur": 0.24, "f0": 112.0, "f1": 68.0, "tone": 0.55, "tdecay": 17.0, "partials": [[236.0, 0.3, 30.0], [517.0, 0.2, 42.0], [866.0, 0.08, 60.0]], "noise": 0.35, "lp": 2400.0, "ndecay": 34.0, "level": 0.85},
	&"enemy_break": {"dur": 0.42, "f0": 92.0, "f1": 42.0, "tone": 0.6, "tdecay": 9.0, "partials": [[188.0, 0.22, 24.0], [341.0, 0.16, 30.0]], "noise": 0.7, "lp": 3600.0, "hp": 250.0, "ndecay": 13.0, "clicks": [0.0, 0.014, 0.037], "level": 0.9},
	&"enemy_hoof": {"dur": 0.26, "noise": 0.45, "lp": 950.0, "hp": 120.0, "ndecay": 8.0, "attack": 0.025, "crackle": 0.01, "level": 0.5},
	&"enemy_skid": {"dur": 0.5, "f0": 78.0, "f1": 34.0, "tone": 0.7, "tdecay": 7.0, "noise": 0.5, "lp": 700.0, "ndecay": 6.0, "level": 0.85},
	&"enemy_fuse": {"dur": 1.0, "noise": 0.35, "lp": 7200.0, "hp": 2600.0, "swell": true, "crackle": 0.02, "attack": 0.04, "level": 0.45},
	&"enemy_boom": {"dur": 1.3, "f0": 64.0, "f1": 26.0, "tone": 0.8, "tdecay": 3.0, "noise": 0.85, "lp": 520.0, "ndecay": 3.4, "attack": 0.003, "clicks": [0.0], "level": 0.95},
	&"enemy_call": {"dur": 0.9, "f0": 72.0, "f1": 32.0, "tone": 0.6, "tdecay": 5.0, "noise": 0.5, "lp": 420.0, "ndecay": 4.0, "crackle": 0.004, "level": 0.8},
}
const RATE: int = 22050
const Q_ADD: int = 0
const Q_FIRE: int = 1
const Q_LIT: int = 2

## 화살이 나는 높이(m). 활 높이(1.43m)와 영주 가슴 사이.
@export var arrow_height: float = 1.4
## 화살 꼬리의 가장 긴 길이(m).
@export var arrow_trail: float = 2.4
## 땅에 꽂힌 화살이 남는 시간(초).
@export var arrow_stuck: float = 3.0
## 겨눈 줄의 폭(m).
@export var aim_width: float = 0.18
## 폭발 그을음이 사라질 때까지(초).
@export var scorch_time: float = 4.0
## 폭발의 짧은 빛 세기.
@export var boom_light: float = 7.0
## 모든 소리에 더하는 크기(dB).
@export var volume_db: float = 0.0

var rules: Rules = null
## 적의 EnemyArt 부품을 돌려주는 함수(e: Enemy) -> Dictionary. 비어 있으면 어림한다.
var body_of: Callable = Callable()

static var _cache: Dictionary = {}

var _built: bool = false
var _rng := RandomNumberGenerator.new()
var _clock: float = 0.0
var _alpha: float = 1.0
var _layer: Node3D
var _jobs: Array[Dictionary] = []
## 적 id와 효과 이름 → 살아 있는 효과(겨눔, 돌진 길, 심지, 부르기 …). 다음 행동이 앞의 것을 거둘 때 쓴다.
var _by_enemy: Dictionary = {}
## 부르는 자 id → 마지막 불러내기의 반지름(칸). call에 spots가 없을 때 쓴다.
var _call_r: Dictionary = {}
var _emitters: Array[CPUParticles3D] = []
var _decals: Array[Dictionary] = []
var _chunks: Array[Dictionary] = []
var _lights: Array[OmniLight3D] = []
var _voices: Array[AudioStreamPlayer3D] = []
var _next_voice: int = 0
var _streams: Dictionary = {}
## 날아가는 화살: Projectile 인스턴스 id → {p, mi, trail, mat, start, age}
var _arrows: Dictionary = {}
var _arrow_free: Array[Dictionary] = []
var _serial: int = 0
var _plane := PlaneMesh.new()
var _decal_shader := Shader.new()
var _mix_mat: StandardMaterial3D
var _add_mat: StandardMaterial3D
var _lit_mat: ShaderMaterial
var _spark_mat: StandardMaterial3D
var _quads: Dictionary = {}
var _spark_mesh := BoxMesh.new()
var _spark_small := BoxMesh.new()
var _chip_mesh := BoxMesh.new()
var _rock_mesh := SphereMesh.new()


func _ready() -> void:
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	top_level = true
	transform = Transform3D.IDENTITY
	_rng.randomize()
	_layer = Node3D.new()
	_layer.name = "EnemyFxLayer"
	add_child(_layer)
	_plane.size = Vector2.ONE
	_decal_shader.code = DECAL_SHADER
	_mix_mat = _particle_mat(false, _puff())
	_add_mat = _particle_mat(true, HitFx._soft_dot())
	_lit_mat = ShaderMaterial.new()
	_lit_mat.shader = _shader("lit", LIT_SHADER)
	_lit_mat.set_shader_parameter("tex", _puff())
	_spark_mat = StandardMaterial3D.new()
	_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spark_mat.vertex_color_use_as_albedo = true
	_spark_mat.disable_receive_shadows = true
	_spark_mesh.size = Vector3(0.014, 0.16, 0.014)
	_spark_mesh.material = _spark_mat
	_spark_small.size = Vector3(0.009, 0.07, 0.009)
	_spark_small.material = _spark_mat
	var chip_mat := StandardMaterial3D.new()
	chip_mat.vertex_color_use_as_albedo = true
	chip_mat.roughness = 0.9
	_chip_mesh.size = Vector3(0.05, 0.025, 0.08)
	_chip_mesh.material = chip_mat
	_rock_mesh.radius = 0.5
	_rock_mesh.height = 0.8
	_rock_mesh.radial_segments = 6
	_rock_mesh.rings = 3
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
func setup(r: Rules, parts_of: Callable = Callable()) -> void:
	_build()
	rules = r
	body_of = parts_of
	if r == null:
		return
	for s: StringName in SIGNALS:
		var c := Callable(self, SIGNALS[s])
		if r.has_signal(s) and not r.is_connected(s, c):
			r.connect(s, c)


## 남은 효과를 모두 거둔다(판이 끝날 때, 낮이 될 때, 갤러리에서).
func clear() -> void:
	_build()
	for j in _jobs:
		_end_job(j)
	_jobs.clear()
	_by_enemy.clear()
	_call_r.clear()
	for key in _arrows.keys():
		_free_arrow(_arrows[key])
	_arrows.clear()
	for c in _chunks:
		c["busy"] = false
		(c["mi"] as MeshInstance3D).visible = false
	for p in _emitters:
		p.emitting = false
		p.set_meta("free_at", 0.0)
	for l in _lights:
		l.visible = false
		l.set_meta("until", 0.0)
	for v in _voices:
		v.stop()


# ---------------------------------------------------------------- 신호

## 적이 무엇을 시작했다(Rules.enemy_act).
func on_act(e: Enemy, act: StringName, info: Dictionary) -> void:
	_build()
	match act:
		&"aim":
			_aim(e, info)
		&"shoot":
			_shoot(e, info)
		&"block":
			_block(e, info)
		&"guard_break":
			_guard_break(e, info)
		&"wind":
			_wind(e, info)
		&"charge":
			_charge(e, info)
		&"charge_end":
			_charge_end(e, info)
		&"fuse":
			_fuse(e, info)
		&"explode":
			_explode(e, info)
		&"call_wind":
			_call_wind(e, info)
		&"call":
			_call(e, info)


## 화살이 났다(Rules.enemy_projectile_spawned). 활잡이의 걸어 둔 화살은 shoot에서 숨고 이 화살이 그 자리에서 난다.
func on_projectile_spawned(p: Projectile) -> void:
	_build()
	if p == null:
		return
	var key: int = p.get_instance_id()
	if _arrows.has(key):
		return
	var a: Dictionary = _take_arrow()
	if a.is_empty():
		return
	a["p"] = p
	a["start"] = p.prev_pos
	a["age"] = 0.0
	(a["mat"] as ShaderMaterial).set_shader_parameter("fade", 1.0)
	(a["mi"] as MeshInstance3D).visible = true
	(a["trail"] as MeshInstance3D).visible = true
	_arrows[key] = a
	_place_arrow(a, _alpha)


## 화살이 끝났다(Rules.enemy_projectile_ended). cut은 갤러리처럼 p.cut이 없을 때 쓰는 대신 값.
func on_projectile_ended(p: Projectile, hit: bool, cut: bool = false) -> void:
	_build()
	if p == null:
		return
	var key: int = p.get_instance_id()
	if not _arrows.has(key):
		on_projectile_spawned(p)
		if not _arrows.has(key):
			return
	var a: Dictionary = _arrows[key]
	_arrows.erase(key)
	var broke: bool = cut or bool(p.get("cut") if p.get("cut") != null else false)
	var mi: MeshInstance3D = a["mi"]
	var d3: Vector3 = _dir3(p.dir if p.dir.length_squared() > 1e-6 else p.pos - p.prev_pos)
	var tip: Vector3 = _ground(p.pos, arrow_height)
	mi.transform = Transform3D(Basis.looking_at(d3, Vector3.UP), tip)
	(a["trail"] as MeshInstance3D).visible = false
	if hit:
		# 영주에게 맞았다: 작은 불똥과 나뭇조각, 화살은 사라진다
		_sparks(tip, 7, -d3 + Vector3(0.0, 0.6, 0.0), 60.0, 1.5, 3.5, SPARK, 0.3, true)
		_chips(tip, 3, Color(0.36, 0.27, 0.18), 2.0, 0.5)
		_play(&"enemy_arrow_hit", tip, -6.0)
		_free_arrow(a)
	elif broke:
		# 칼에 맞아 두 동강: 앞뒤 토막이 갈라져 튕기고 땅에 눕는다
		var xf: Transform3D = mi.transform
		_free_arrow(a)
		var halves: Array = _arrow_halves()
		var side: Vector3 = d3.cross(Vector3.UP).normalized()
		var s: float = 1.0 if _rng.randf() < 0.5 else -1.0
		var front_c: Vector3 = xf * Vector3(0.0, 0.0, ARROW_CUT * 0.5)
		var back_c: Vector3 = xf * Vector3(0.0, 0.0, (ARROW_CUT + EnemyArt.ARROW_LENGTH) * 0.5)
		_toss(halves[0], null, Transform3D(xf.basis, front_c), d3 * 2.2 + side * s * 1.4 + Vector3(0, 2.2, 0), Vector3(_rng.randf_range(-1, 1), 1.0, _rng.randf_range(-1, 1)).normalized() * 14.0, 0.012, true, 1.6)
		_toss(halves[1], null, Transform3D(xf.basis, back_c), d3 * 0.6 - side * s * 1.2 + Vector3(0, 2.8, 0), Vector3(_rng.randf_range(-1, 1), 1.0, _rng.randf_range(-1, 1)).normalized() * -11.0, 0.012, true, 1.6)
		var at: Vector3 = xf * Vector3(0.0, 0.0, ARROW_CUT)
		_sparks(at, 6, Vector3.UP, 80.0, 1.5, 3.0, STEEL.lerp(SPARK, 0.4), 0.25, true)
		_chips(at, 4, Color(0.36, 0.27, 0.18), 2.4, 0.6)
		_play(&"enemy_arrow_cut", at, -4.0)
	else:
		# 사거리 끝: 앞으로 조금 더 날아 비스듬히 땅에 꽂혀 떨고, 남았다가 가라앉는다
		var land: Vector3 = tip + d3 * 0.9
		land.y = _hy(land)
		var f: Vector3 = (d3 * cos(0.6) + Vector3.DOWN * sin(0.6)).normalized()
		var stuck := Transform3D(Basis.looking_at(f, Vector3.UP), land + f * 0.16)
		_job(_run_stuck, {"arrow": a, "from": mi.transform, "to": stuck, "dir": f, "landed": false})


## main이 매 화면 부른다. alpha는 지난 틱과 이번 틱 사이(0~1).
func draw(alpha: float) -> void:
	_alpha = alpha
	for key in _arrows.keys():
		_place_arrow(_arrows[key], alpha)


func _process(delta: float) -> void:
	if not _built:
		return
	_clock += delta
	for key in _arrows.keys():
		var a: Dictionary = _arrows[key]
		a["age"] = float(a["age"]) + delta
		if float(a["age"]) > ARROW_MAX_AGE:
			on_projectile_ended(a["p"], false)
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
	_step_chunks(delta)


# ---------------------------------------------------------------- 활잡이

## 겨눔: 활잡이 앞에서 겨눈 쪽으로 땅에 가는 검붉은 줄. 겨누는 동안 짙어지고, 쏘면 한 번 짙어졌다가 바로 사라진다.
func _aim(e: Enemy, info: Dictionary) -> void:
	_drop(e, "aim")
	var d := _decal(2)
	if d.is_empty():
		return
	var T: float = maxf(0.05, float(info.get("time", 0.6)))
	var j := _job(_run_aim, {"e": e, "decal": d, "time": T, "dir": _v2(info.get("dir", _face(e))),
		"from": _v2(info.get("from", _epos(e))), "length": Grid.cells_to_meters(float(info.get("length", ARROW_RANGE))), "out": -1.0, "shot": false})
	_put(d, {"fill": 0.0, "fade": 1.0, "color": RED, "hot": RED_HOT})
	_by_enemy[_key(e, "aim")] = j
	_run_aim(j, 0.0)


func _run_aim(j: Dictionary, _dt: float) -> bool:
	var e: Enemy = j["e"]
	var d: Dictionary = j["decal"]
	var T: float = j["time"]
	var t: float = j["t"]
	var from: Vector2 = _epos(e) if e != null else j["from"]
	var length: float = float(j["length"]) - 0.6
	_lane(d, from, j["dir"], 0.6, length, aim_width, 0.035)
	if float(j["out"]) < 0.0 and (t > T + 0.08 or not _still(e, &"aim") or bool(j["shot"])):
		j["out"] = t
	var out: float = j["out"]
	if out < 0.0:
		var k: float = clampf(t / T, 0.0, 1.0)
		_put(d, {"fill": k * k * (3.0 - 2.0 * k), "fade": 1.0})
		return true
	var o: float = (t - out) / 0.16
	if o >= 1.0:
		return false
	_put(d, {"fill": 1.0 + (0.5 if bool(j["shot"]) else 0.0) * (1.0 - o), "fade": 1.0 - o * o})
	return true


## 쏘기: 시위 소리. 겨눈 줄은 한 번 짙어졌다가 사라진다. 화살은 enemy_projectile_spawned가 그린다.
func _shoot(e: Enemy, info: Dictionary) -> void:
	var j: Dictionary = _by_enemy.get(_key(e, "aim"), {})
	if not j.is_empty():
		j["shot"] = true
	var from: Vector2 = _v2(info.get("from", _epos(e)))
	_play(&"enemy_bow", _ground(from, 1.4), -6.0)


# ---------------------------------------------------------------- 방패병

## 막기: 방패에서 불똥이 막은 쪽으로 튀고, 쇠가 짧게 번쩍이고, 발밑에서 흙먼지. 둔한 쇳소리.
func _block(e: Enemy, info: Dictionary) -> void:
	var dir: Vector3 = _dir3(_v2(info.get("dir", _face(e))))
	var at: Vector3 = _shield_point(e, info, dir)
	var g: float = _grow(e)
	_sparks(at, 12, dir + Vector3(0.0, 0.45, 0.0), 55.0, 2.5, 5.5, SPARK, 0.4)
	_sparks(at, 5, dir + Vector3(0.0, 0.2, 0.0), 30.0, 4.0, 7.0, STEEL.lerp(SPARK, 0.3), 0.22, true)
	_glint(at + dir * 0.05, 0.55, STEEL, 0.8, 0.15)
	var feet: Vector3 = _ground(_v2(info.get("at", _epos(e))), 0.0)
	if e != null:
		feet = _ground(_epos(e), 0.0)
	_dust(feet - dir * 0.25 * g, 6, 1.4, 0.32, 0.9, -dir)
	_play(&"enemy_block", at, -2.0)


## 방패가 깨졌다: 크게 튀는 불똥, 쪼개진 나뭇조각과 쇳조각, 발밑 먼지, 큰 번쩍임. 짧고 낮게 갈라지는 소리.
## 방패가 열리며 비틀거리는 것은 모션팀(EnemyMotion)이 한다.
func _guard_break(e: Enemy, info: Dictionary) -> void:
	var dir: Vector3 = _dir3(_face(e))
	var at: Vector3 = _shield_point(e, info, dir)
	var g: float = _grow(e)
	_sparks(at, 22, Vector3(0.0, 1.0, 0.0) + dir * 0.6, 85.0, 3.0, 7.5, SPARK, 0.55)
	_sparks(at, 8, dir, 40.0, 5.0, 9.0, STEEL.lerp(SPARK, 0.35), 0.25, true)
	_chips(at, 9, Color(0.3, 0.2, 0.13), 4.0, 0.9)
	_chips(at, 4, Color(0.32, 0.32, 0.33), 4.5, 0.8)
	_glint(at + dir * 0.05, 0.8, STEEL, 0.7, 0.2)
	var feet: Vector3 = _ground(_epos(e) if e != null else _v2(info.get("at", Vector2.ZERO)), 0.0)
	_dust(feet, 14, 2.2, 0.45 * g, 1.1)
	_play(&"enemy_break", at, 0.0)


## 방패 앞면의 자리. 부품이 있으면 방패 노드, 없으면 적 앞 가슴 높이.
func _shield_point(e: Enemy, info: Dictionary, dir: Vector3) -> Vector3:
	var sh := _node(e, "shield")
	if sh != null:
		var front: Vector3 = -sh.global_basis.z.normalized()
		return sh.global_position + front * 0.06 + Vector3(0.0, -0.1, 0.0)
	var g: float = _grow(e)
	var at: Vector2 = _v2(info.get("at", _epos(e)))
	if e != null:
		at = _epos(e)
	return _ground(at, 1.15 * g) + dir * 0.42 * g


# ---------------------------------------------------------------- 돌격병

## 돌진 준비: 앞오른발로 땅을 긁는 먼지 두 번, 돌진할 길이 땅에 검붉은 띠로 보이고 머리 낮추는 동안 찬다.
func _wind(e: Enemy, info: Dictionary) -> void:
	_drop(e, "wind")
	var T: float = maxf(0.05, float(info.get("time", 0.7)))
	var dir: Vector2 = _v2(info.get("dir", _face(e)))
	var r: float = e.radius if e != null else 0.4
	var length: float = float(info.get("length", 9.0))
	var width: float = Grid.cells_to_meters(float(info.get("width", r * 2.0)))
	var d := _decal(0)
	var j := _job(_run_wind, {"e": e, "decal": d, "time": T, "dir": dir, "from": _v2(info.get("from", _epos(e))),
		"start": Grid.cells_to_meters(r * 0.5), "length": Grid.cells_to_meters(length + r * 0.5), "width": width,
		"puffs": [0.2 * T / 0.7, 0.54 * T / 0.7], "out": -1.0, "out_time": 0.3})
	if not d.is_empty():
		var L: float = float(j["length"])
		_put(d, {"fill": 0.0, "fade": 1.0, "color": RED, "hot": RED_HOT, "ew": clampf(0.07 / (width * 0.5), 0.02, 0.3), "hw": clampf(0.2 / L, 0.004, 0.1)})
	_by_enemy[_key(e, "wind")] = j
	_run_wind(j, 0.0)


func _run_wind(j: Dictionary, _dt: float) -> bool:
	var e: Enemy = j["e"]
	var T: float = j["time"]
	var t: float = j["t"]
	var d: Dictionary = j["decal"]
	var from: Vector2 = j["from"]
	if not d.is_empty():
		_lane(d, from, j["dir"], float(j["start"]), float(j["length"]), float(j["width"]), 0.03)
	# 발굽 긁기(모션팀의 긁는 때와 맞춘다: 뒤로 긁어 내리는 순간)
	var puffs: Array = j["puffs"]
	while not puffs.is_empty() and t >= float(puffs[0]) and float(j["out"]) < 0.0:
		puffs.pop_front()
		var hoof: Vector3 = _hoof(e)
		var back: Vector3 = -_dir3(j["dir"])
		_dust(hoof, 7, 1.8, 0.3, 0.8, back + Vector3(0.0, 0.35, 0.0))
		_chips(hoof, 3, Color(0.2, 0.16, 0.12), 1.8, 0.5, back)
		_play(&"enemy_hoof", hoof, -10.0)
	if float(j["out"]) < 0.0 and (t > T + 0.12 or not _still(e, &"wind")):
		j["out"] = t
	var out: float = j["out"]
	if d.is_empty():
		return out < 0.0
	if out < 0.0:
		var k: float = clampf(t / T, 0.0, 1.0)
		_put(d, {"fill": 1.0 - pow(1.0 - k, 1.6), "fade": 1.0})
		return true
	var o: float = (t - out) / float(j["out_time"])
	if o >= 1.0:
		return false
	_put(d, {"fill": 1.0, "fade": 1.0 - o})
	return true


## 돌진: 뒷발 박차는 먼지, 달리는 동안 몸 뒤로 먼지 꼬리, 지나간 땅에 금. 돌진 길 띠는 빠르게 식는다.
func _charge(e: Enemy, info: Dictionary) -> void:
	var w: Dictionary = _by_enemy.get(_key(e, "wind"), {})
	if not w.is_empty() and float(w["out"]) < 0.0:
		w["out"] = float(w["t"])
		w["out_time"] = 0.35
	_drop(e, "charge")
	var from: Vector2 = _v2(info.get("from", _epos(e)))
	var to: Vector2 = _v2(info.get("to", from + _face(e) * 9.0))
	var T: float = float(info.get("time", from.distance_to(to) / CHARGE_SPEED))
	var g: float = _grow(e)
	var go: Vector3 = _dir3(to - from)
	var rear: Vector3 = _ground(from, 0.0) - go * 0.9 * g
	_dust(rear, 12, 2.6, 0.45 * g, 1.0, -go + Vector3(0.0, 0.3, 0.0))
	_chips(rear, 5, Color(0.2, 0.16, 0.12), 2.5, 0.6, -go)
	var trail := _emitter(true)
	if trail != null:
		trail.amount = 44
		trail.lifetime = 1.1
		trail.explosiveness = 0.0
		trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		trail.emission_sphere_radius = 0.8 * g
		trail.direction = Vector3.UP
		trail.spread = 70.0
		trail.initial_velocity_min = 0.4
		trail.initial_velocity_max = 1.5
		trail.damping_min = 1.0
		trail.damping_max = 2.0
		trail.gravity = Vector3(0.0, 0.12, 0.0)
		trail.angle_min = -180.0
		trail.angle_max = 180.0
		_curve(trail, 0.6, 2.1)
		_ramp(trail, [Color(DUST, 0.0), Color(DUST, 0.32), Color(DUST.darkened(0.1), 0.0)], [0.0, 0.12, 1.0])
		trail.mesh = _quad(1.3 * g, Q_LIT)
		trail.position = rear + Vector3(0.0, 0.2, 0.0)
		trail.restart()
	var j := _job(_run_charge, {"e": e, "emit": trail, "time": maxf(0.1, T), "from": from, "to": to, "last": _ground(from, 0.0), "cracks": 0})
	_by_enemy[_key(e, "charge")] = j


func _run_charge(j: Dictionary, _dt: float) -> bool:
	var e: Enemy = j["e"]
	var t: float = j["t"]
	var T: float = j["time"]
	var from: Vector2 = j["from"]
	var to: Vector2 = j["to"]
	var cells: Vector2 = _epos(e) if e != null else from.lerp(to, clampf(t / T, 0.0, 1.0))
	var g: float = _grow(e)
	var go: Vector3 = _dir3(to - from)
	var at: Vector3 = _ground(cells, 0.0)
	var trail: CPUParticles3D = j["emit"]
	if trail != null:
		trail.position = at - go * 0.8 * g + Vector3(0.0, 0.2, 0.0)
	# 지나간 땅에 금(1.7m마다, 몸 밑에서 생겨 지나가면 드러난다)
	var last: Vector3 = j["last"]
	if at.distance_to(last) >= 1.7 and int(j["cracks"]) < 12:
		j["last"] = at
		j["cracks"] = int(j["cracks"]) + 1
		_crack(at - go * 0.4 * g, 0.6 * g, Color(1.0, 0.45, 0.15), 0.0, 1.4, 0.5, go)
	var done: bool = t > T + 0.12 or (t > 0.1 and not _still(e, &"charge"))
	return not done


## 돌진이 끝났다: 미끄러져 멈춘 자리에 큰 먼지, 앞으로 튀는 흙. 비틀거리는 동안(time) 머리 둘레를 도는 흐린 티끌 몇 개.
func _charge_end(e: Enemy, info: Dictionary) -> void:
	_drop(e, "charge")
	var at2: Vector2 = _v2(info.get("at", _epos(e)))
	var at: Vector3 = _ground(at2, 0.0)
	var g: float = _grow(e)
	var go: Vector3 = _dir3(_face(e))
	_dust(at + go * 0.6 * g, 18, 3.2, 0.55 * g, 1.2)
	_dust(at + go * 0.9 * g, 8, 3.0, 0.4 * g, 0.9, go + Vector3(0.0, 0.25, 0.0))
	_chips(at + go * 0.8 * g, 7, Color(0.2, 0.16, 0.12), 3.0, 0.7, go)
	_play(&"enemy_skid", at, -2.0 if bool(info.get("hit", false)) else -4.0)
	if bool(info.get("hit", false)) and rules != null:
		_dust(_ground(rules.lord.pos, 0.0), 8, 2.0, 0.4, 0.9)
	var T: float = float(info.get("time", 1.0))
	if not bool(info.get("stun", T > 0.0)) or T <= 0.0 or e == null:
		return
	_drop(e, "daze")
	var root := Node3D.new()
	_layer.add_child(root)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = HitFx._soft_dot()
	m.albedo_color = Color(0.72, 0.66, 0.55, 0.0)
	m.disable_receive_shadows = true
	var q := QuadMesh.new()
	q.size = Vector2(0.11, 0.11)
	for i in 4:
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	_by_enemy[_key(e, "daze")] = _job(_run_daze, {"e": e, "node": root, "mat": m, "time": T, "phase": _rng.randf() * TAU})


func _run_daze(j: Dictionary, _dt: float) -> bool:
	var e: Enemy = j["e"]
	var t: float = j["t"]
	var T: float = j["time"]
	if t > T + 0.3 or e == null or e.dead:
		return false
	var root: Node3D = j["node"]
	var g: float = _grow(e)
	root.position = _head(e) + Vector3(0.0, 0.42 * g, 0.0)
	var a0: float = float(j["phase"]) + t * 2.6
	var kids: Array[Node] = root.get_children()
	for i in kids.size():
		var a: float = a0 + TAU * i / kids.size()
		(kids[i] as Node3D).position = Vector3(cos(a) * 0.36 * g, 0.06 * sin(a * 2.0 + i) * g, sin(a) * 0.36 * g)
	var k: float = smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(T - 0.1, T + 0.3, t))
	var m: StandardMaterial3D = j["mat"]
	m.albedo_color = Color(m.albedo_color, 0.42 * k)
	return true


# ---------------------------------------------------------------- 자폭병

## 심지: 발밑에 위험 원(반지름 radius칸)이 테부터 보이고 가운데에서 밖으로 찬다(다 차면 터진다). 자폭병을 따라간다.
## 배의 갈라진 틈에서 불똥이 쉬익 튀고 점점 빨라진다.
func _fuse(e: Enemy, info: Dictionary) -> void:
	_drop(e, "fuse")
	var T: float = maxf(0.05, float(info.get("time", 0.9)))
	var R: float = Grid.cells_to_meters(float(info.get("radius", BLAST_RADIUS)))
	var d := _decal(1)
	if not d.is_empty():
		_put(d, {"fill": 0.0, "fade": 1.0, "energy": 0.0, "color": RED, "hot": RED_HOT, "ew": clampf(0.07 / R, 0.01, 0.2), "hw": clampf(0.18 / R, 0.01, 0.2)})
	var sp := _emitter(true)
	if sp != null:
		sp.amount = 26
		sp.lifetime = 0.32
		sp.explosiveness = 0.0
		sp.randomness = 0.6
		sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		sp.emission_sphere_radius = 0.07
		sp.spread = 55.0
		sp.initial_velocity_min = 1.0
		sp.initial_velocity_max = 2.6
		sp.gravity = Vector3(0.0, -9.0, 0.0)
		sp.particle_flag_align_y = true
		sp.scale_amount_min = 0.6
		sp.scale_amount_max = 1.2
		_ramp(sp, [Color(SPARK.r * 3.0, SPARK.g * 2.6, SPARK.b * 2.0, 1.0), Color(EMBER.r, EMBER.g * 0.5, EMBER.b * 0.3, 0.0)], [0.0, 1.0])
		sp.mesh = _spark_small
		sp.speed_scale = 0.6
		sp.restart()
	var at: Vector3 = _belly(e)
	var voice := _play(&"enemy_fuse", at, -8.0)
	var j := _job(_run_fuse, {"e": e, "decal": d, "emit": sp, "voice": voice, "voice_serial": int(voice.get_meta("serial", -1)) if voice else -1,
		"time": T, "radius": R, "at": _v2(info.get("at", _epos(e))), "out": -1.0})
	_by_enemy[_key(e, "fuse")] = j
	_run_fuse(j, 0.0)


func _run_fuse(j: Dictionary, _dt: float) -> bool:
	var e: Enemy = j["e"]
	var t: float = j["t"]
	var T: float = j["time"]
	var R: float = j["radius"]
	var cells: Vector2 = _epos(e) if e != null else j["at"]
	var d: Dictionary = j["decal"]
	if not d.is_empty():
		var c: Vector3 = _ground(cells, 0.04)
		(d["mi"] as MeshInstance3D).transform = Transform3D(Basis.from_scale(Vector3(R * 2.0, 1.0, R * 2.0)), c)
	var k: float = clampf(t / T, 0.0, 1.0)
	var sp: CPUParticles3D = j["emit"]
	if sp != null:
		var fwd: Vector3 = _dir3(_face(e))
		sp.position = _belly(e)
		sp.direction = (fwd + Vector3(0.0, 0.8, 0.0)).normalized()
		sp.speed_scale = 0.6 + 1.6 * k
		sp.initial_velocity_max = 2.6 + 2.0 * k
	if float(j["out"]) < 0.0 and (t > T + 0.25 or (e != null and not _still(e, &"fuse") and not e.dead)):
		j["out"] = t
	var out: float = j["out"]
	if out < 0.0:
		if not d.is_empty():
			_put(d, {"fill": pow(k, 0.85), "energy": k, "fade": smoothstep(0.0, 0.08, t)})
		return true
	var o: float = (t - out) / 0.2
	if not d.is_empty():
		_put(d, {"fade": 1.0 - o})
	return o < 1.0


## 폭발: 짧은 흰불 번쩍임 뒤 어두워지는 불덩이와 검은 연기, 땅을 쓰는 먼지 충격파, 튀는 불똥과 흙·돌 파편(땅에 떨어져 눕는다),
## 4초 동안 식는 그을음, 짧은 주황 빛, 낮은 울림. exploded 신호를 낸다(카메라는 main).
func _explode(e: Enemy, info: Dictionary) -> void:
	_drop(e, "fuse")
	var R: float = Grid.cells_to_meters(float(info.get("radius", BLAST_RADIUS)))
	var k: float = clampf(R / Grid.cells_to_meters(BLAST_RADIUS), 0.4, 2.0)
	var at2: Vector2 = _v2(info.get("at", _epos(e)))
	var g0: Vector3 = _ground(at2, 0.0)
	var c: Vector3 = g0 + Vector3(0.0, 0.7 * k, 0.0)
	# 번쩍임(아주 짧게)
	var flash := MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(1.4, 1.4) * k
	flash.mesh = fq
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.albedo_texture = _puff()
	fm.albedo_color = Color(1.0, 0.72, 0.42, 0.7)
	fm.disable_receive_shadows = true
	flash.material_override = fm
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.position = c
	_layer.add_child(flash)
	_job(_run_flash, {"node": flash, "mat": fm})
	# 불덩이: 가운데에 뭉친 큰 불과 밖으로 터지는 불. 밝게 터져 금방 검붉고 검게 식는다
	var fire_ramp: Array = [Color(1.25, 0.9, 0.5, 1.0), Color(1.15, 0.45, 0.12, 1.0), Color(0.6, 0.14, 0.04, 0.95), Color(0.12, 0.085, 0.065, 0.8), Color(0.06, 0.05, 0.045, 0.0)]
	var fire_offs: Array = [0.0, 0.1, 0.25, 0.5, 1.0]
	var core := _emitter()
	if core != null:
		core.amount = 9
		core.lifetime = 0.85
		core.explosiveness = 1.0
		core.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		core.emission_sphere_radius = 0.45 * k
		core.direction = Vector3.UP
		core.spread = 80.0
		core.initial_velocity_min = 0.4 * k
		core.initial_velocity_max = 2.2 * k
		core.damping_min = 2.0 * k
		core.damping_max = 3.0 * k
		core.gravity = Vector3(0.0, 1.8, 0.0)
		core.angle_min = -180.0
		core.angle_max = 180.0
		core.scale_amount_min = 0.8
		core.scale_amount_max = 1.2
		_curve3(core, 0.5, 1.0, 1.35)
		_ramp(core, fire_ramp, fire_offs)
		core.color_initial_ramp = _fire_vary()
		core.mesh = _quad(2.0 * k, Q_FIRE)
		_fire(core, c)
	var fire := _emitter()
	if fire != null:
		fire.amount = 12
		fire.lifetime = 0.6
		fire.explosiveness = 1.0
		fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		fire.emission_sphere_radius = 0.3 * k
		fire.direction = Vector3.UP
		fire.spread = 180.0
		fire.flatness = 0.35
		fire.initial_velocity_min = 3.0 * k
		fire.initial_velocity_max = 7.0 * k
		fire.damping_min = 8.0 * k
		fire.damping_max = 11.0 * k
		fire.gravity = Vector3(0.0, 1.0, 0.0)
		fire.angle_min = -180.0
		fire.angle_max = 180.0
		fire.scale_amount_min = 0.6
		fire.scale_amount_max = 1.1
		_curve3(fire, 0.4, 1.0, 1.3)
		_ramp(fire, fire_ramp, fire_offs)
		fire.color_initial_ramp = _fire_vary()
		fire.mesh = _quad(1.3 * k, Q_FIRE)
		_fire(fire, c)
	# 연기: 불이 식을 무렵 짙어져 천천히 오르며 흩어진다(빛을 받는 짙은 잿빛)
	var smoke := _emitter()
	if smoke != null:
		smoke.amount = 9
		smoke.lifetime = 2.6
		smoke.explosiveness = 0.95
		smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		smoke.emission_sphere_radius = 0.7 * k
		smoke.direction = Vector3.UP
		smoke.spread = 50.0
		smoke.initial_velocity_min = 0.7
		smoke.initial_velocity_max = 1.8
		smoke.damping_min = 0.4
		smoke.damping_max = 0.8
		smoke.gravity = Vector3(0.0, 0.45, 0.0)
		smoke.angle_min = -180.0
		smoke.angle_max = 180.0
		smoke.angular_velocity_min = -25.0
		smoke.angular_velocity_max = 25.0
		_curve(smoke, 0.6, 2.2)
		_ramp(smoke, [Color(0.2, 0.19, 0.17, 0.0), Color(0.2, 0.19, 0.17, 0.0), Color(0.18, 0.17, 0.16, 0.5), Color(0.16, 0.15, 0.14, 0.0)], [0.0, 0.1, 0.3, 1.0])
		smoke.mesh = _quad(2.2 * k, Q_LIT)
		_fire(smoke, c + Vector3(0.0, 0.3, 0.0))
	_sparks(c, 18, Vector3.UP, 75.0, 5.0 * k, 11.0 * k, EMBER, 0.75)
	# 땅: 먼지 충격파, 고리 자국, 그을음
	_dust(g0, 26, 5.0 * k, 0.6 * k, 1.3)
	var ring := _decal(3)
	if not ring.is_empty():
		_put(ring, {"fill": 0.05, "fade": 1.0, "color": DUST})
		(ring["mi"] as MeshInstance3D).transform = Transform3D(Basis.from_scale(Vector3.ONE * R * 2.5), g0 + Vector3(0.0, 0.05, 0.0))
		_job(_run_ring, {"decal": ring, "time": 0.42})
	var scorch := _decal(4)
	if not scorch.is_empty():
		_put(scorch, {"fade": 1.0, "energy": 1.0, "color": CHAR, "hot": EMBER, "seed": _rng.randf() * 50.0})
		(scorch["mi"] as MeshInstance3D).transform = Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(R * 1.7, 1.0, R * 1.7)), g0 + Vector3(0.0, 0.032, 0.0))
		_job(_run_scorch, {"decal": scorch, "time": scorch_time})
	# 파편: 흙덩이와 돌, 몇 개는 달궈져 식는다
	for i in 9:
		var a: float = _rng.randf() * TAU
		var v := Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(2.5, 6.0) * k + Vector3(0.0, _rng.randf_range(3.0, 7.0) * k, 0.0)
		var s: float = _rng.randf_range(0.06, 0.15) * k
		var hot: bool = i < 3
		var col: Color = Color(0.13, 0.11, 0.09).lerp(Color(0.2, 0.18, 0.16), _rng.randf())
		_toss(_rock_mesh, col, Transform3D(Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, 0.0)).scaled(Vector3(s * 1.3, s, s * 1.1)), g0 + Vector3(0.0, 0.4, 0.0)),
			v, Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized() * _rng.randf_range(6.0, 14.0), s * 0.4, false, _rng.randf_range(1.0, 1.8), 1.6 if hot else 0.0)
	_light(c + Vector3(0.0, 0.5, 0.0), Color(1.0, 0.5, 0.18), boom_light * k, R * 3.2, 0.45)
	_play(&"enemy_boom", c, 2.0)
	exploded.emit(c, k)


func _run_flash(j: Dictionary, _dt: float) -> bool:
	var t: float = j["t"]
	var k: float = t / 0.13
	if k >= 1.0:
		return false
	var n: Node3D = j["node"]
	n.scale = Vector3.ONE * (0.6 + 0.8 * k)
	var m: StandardMaterial3D = j["mat"]
	m.albedo_color = Color(m.albedo_color, 0.7 * (1.0 - k) * (1.0 - k))
	return true


func _run_ring(j: Dictionary, _dt: float) -> bool:
	var k: float = float(j["t"]) / float(j["time"])
	if k >= 1.0:
		return false
	_put(j["decal"], {"fill": 0.05 + 0.95 * (1.0 - pow(1.0 - k, 2.0))})
	return true


func _run_scorch(j: Dictionary, _dt: float) -> bool:
	var t: float = j["t"]
	var T: float = j["time"]
	if t >= T:
		return false
	_put(j["decal"], {"energy": exp(-t * 2.4), "fade": 1.0 - smoothstep(T * 0.55, T, t)})
	return true


# ---------------------------------------------------------------- 부르는 자

## 불러내기: 둘레 radius칸에 그을린 고리가 생기고 고리를 따라 불씨가 일렁인다. 안쪽에 옅은 고리 하나 더.
## 재 조각이 고리에서 맴돌며 떠오르고 불씨 몇 개가 오른다. 1초 동안 점점 짙어진다. 부르는 자를 따라간다.
func _call_wind(e: Enemy, info: Dictionary) -> void:
	_drop(e, "call_wind")
	var T: float = maxf(0.05, float(info.get("time", 1.0)))
	var R: float = Grid.cells_to_meters(float(info.get("radius", CALL_RADIUS)))
	var outer := _decal(5)
	var inner := _decal(5)
	_put(outer, {"fill": 0.0, "fade": 1.0, "energy": 0.0, "color": CHAR, "hot": EMBER, "seed": _rng.randf() * 40.0, "ew": 0.035})
	_put(inner, {"fill": 0.0, "fade": 1.0, "energy": 0.0, "color": CHAR, "hot": EMBER, "seed": _rng.randf() * 40.0, "ew": 0.05})
	var ash := _emitter(true)
	if ash != null:
		ash.amount = 26
		ash.lifetime = 1.7
		ash.explosiveness = 0.0
		ash.randomness = 0.5
		ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		ash.emission_ring_axis = Vector3.UP
		ash.emission_ring_height = 0.15
		ash.emission_ring_radius = R * 1.05
		ash.emission_ring_inner_radius = R * 0.75
		ash.direction = Vector3.UP
		ash.spread = 25.0
		ash.initial_velocity_min = 0.35
		ash.initial_velocity_max = 0.9
		ash.gravity = Vector3(0.0, 0.12, 0.0)
		ash.damping_min = 0.2
		ash.damping_max = 0.4
		ash.tangential_accel_min = 0.5
		ash.tangential_accel_max = 1.2
		ash.angle_min = -180.0
		ash.angle_max = 180.0
		ash.angular_velocity_min = -90.0
		ash.angular_velocity_max = 90.0
		_curve(ash, 0.6, 1.1)
		_ramp(ash, [Color(ASH, 0.0), Color(ASH, 0.75), Color(ASH.darkened(0.3), 0.0)], [0.0, 0.15, 1.0])
		ash.mesh = _quad(0.13, Q_LIT)
		ash.speed_scale = 0.6
		ash.restart()
	var emb := _emitter(true)
	if emb != null:
		emb.amount = 12
		emb.lifetime = 1.2
		emb.explosiveness = 0.0
		emb.randomness = 0.6
		emb.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		emb.emission_ring_axis = Vector3.UP
		emb.emission_ring_height = 0.05
		emb.emission_ring_radius = R * 0.95
		emb.emission_ring_inner_radius = R * 0.85
		emb.direction = Vector3.UP
		emb.spread = 20.0
		emb.initial_velocity_min = 0.5
		emb.initial_velocity_max = 1.4
		emb.gravity = Vector3(0.0, 0.3, 0.0)
		emb.tangential_accel_min = 0.6
		emb.tangential_accel_max = 1.4
		emb.scale_amount_min = 0.5
		emb.scale_amount_max = 1.0
		_ramp(emb, [Color(EMBER.r * 2.2, EMBER.g * 1.8, EMBER.b * 1.4, 0.0), Color(EMBER.r * 2.2, EMBER.g * 1.8, EMBER.b * 1.4, 0.9), Color(0.5, 0.1, 0.02, 0.0)], [0.0, 0.2, 1.0])
		emb.mesh = _quad(0.06, Q_ADD)
		emb.speed_scale = 0.5
		emb.restart()
	var j := _job(_run_call_wind, {"e": e, "decal": [outer, inner], "emit": [ash, emb], "time": T, "radius": R,
		"at": _v2(info.get("at", _epos(e))), "out": -1.0, "called": false})
	_by_enemy[_key(e, "call_wind")] = j
	_call_r[e.id if e != null else -1] = float(info.get("radius", CALL_RADIUS))
	_run_call_wind(j, 0.0)


func _run_call_wind(j: Dictionary, _dt: float) -> bool:
	var e: Enemy = j["e"]
	var t: float = j["t"]
	var T: float = j["time"]
	var R: float = j["radius"]
	var cells: Vector2 = _epos(e) if e != null else j["at"]
	var c: Vector3 = _ground(cells, 0.0)
	var ds: Array = j["decal"]
	for i in ds.size():
		var d: Dictionary = ds[i]
		if d.is_empty():
			continue
		var r: float = R if i == 0 else R * 0.55
		(d["mi"] as MeshInstance3D).transform = Transform3D(Basis(Vector3.UP, t * (0.25 if i == 0 else -0.4)).scaled(Vector3(r * 2.2, 1.0, r * 2.2)), c + Vector3(0.0, 0.036 + 0.003 * i, 0.0))
	var es: Array = j["emit"]
	var k: float = smoothstep(0.0, 1.0, clampf(t / T, 0.0, 1.0))
	for p: CPUParticles3D in es:
		if p != null:
			p.position = c + Vector3(0.0, 0.08, 0.0)
			p.speed_scale = 0.5 + 1.0 * k
	if float(j["out"]) < 0.0 and (t > T + 0.1 or bool(j["called"]) or not _still(e, &"call_wind")):
		j["out"] = t
		for p: CPUParticles3D in es:
			if p != null:
				p.emitting = false
	var out: float = j["out"]
	if out < 0.0:
		for i in ds.size():
			var d: Dictionary = ds[i]
			if not d.is_empty():
				_put(d, {"fill": k * (1.0 if i == 0 else 0.55), "energy": 0.3 + 0.9 * k, "fade": 1.0})
		return true
	var span: float = 0.45 if bool(j["called"]) else 0.3
	var o: float = (t - out) / span
	if o >= 1.0:
		return false
	for i in ds.size():
		var d: Dictionary = ds[i]
		if not d.is_empty():
			var flare: float = (1.0 - o) * 0.8 if bool(j["called"]) else 0.0
			_put(d, {"energy": 1.2 * (1.0 - o) + flare, "fade": 1.0 - o * o})
	return true


## 부르기: 0.1초에 지팡이 끝이 땅을 쳐 충격 고리가 퍼지고, 곧이어 부를 자리마다 땅이 갈라지며(틈에 흐린 찬빛) 검은 안개가 오른다.
## 부를 자리는 info.spots(칸 배열). 없으면 count(3)개를 둘레(불러내기의 radius)에 고르게 놓는다.
func _call(e: Enemy, info: Dictionary) -> void:
	var cw: Dictionary = _by_enemy.get(_key(e, "call_wind"), {})
	if not cw.is_empty():
		cw["called"] = true
	var at: Vector2 = _v2(info.get("at", _epos(e)))
	var spots: Array[Vector2] = []
	for s: Variant in info.get("spots", []):
		spots.append(_v2(s))
	if spots.is_empty():
		var n: int = maxi(1, int(info.get("count", 3)))
		var r: float = float(_call_r.get(e.id if e != null else -1, CALL_RADIUS))
		var a0: float = _face(e).angle() + PI / n
		for i in n:
			var a: float = a0 + TAU * i / n
			spots.append(at + Vector2(cos(a), sin(a)) * r)
	_job(_run_call, {"e": e, "at": at, "spots": spots, "struck": false, "done": 0})


func _run_call(j: Dictionary, _dt: float) -> bool:
	var t: float = j["t"]
	var e: Enemy = j["e"]
	if not bool(j["struck"]) and t >= 0.1:
		j["struck"] = true
		var tip: Vector3 = _staff_tip(e, j["at"])
		var ring := _decal(3)
		if not ring.is_empty():
			_put(ring, {"fill": 0.05, "fade": 1.0, "color": DUST.lerp(Color(0.4, 0.42, 0.4), 0.3)})
			(ring["mi"] as MeshInstance3D).transform = Transform3D(Basis.from_scale(Vector3.ONE * 4.6), tip + Vector3(0.0, 0.05, 0.0))
			_job(_run_ring, {"decal": ring, "time": 0.36})
		_dust(tip, 10, 2.2, 0.32, 0.9)
		_play(&"enemy_call", tip, -2.0)
	var spots: Array[Vector2] = j["spots"]
	var done: int = j["done"]
	while done < spots.size() and t >= 0.13 + 0.06 * done:
		_rise(spots[done])
		done += 1
	j["done"] = done
	return done < spots.size() or not bool(j["struck"])


## 부를 자리 하나: 땅이 갈라지고(틈에 흐린 찬빛이 잠깐) 흙이 튀고 검은 안개가 오른다.
func _rise(cells: Vector2) -> void:
	var at: Vector3 = _ground(cells, 0.0)
	_crack(at, 0.9, CRACK_COLD, 0.9, 1.6, 0.6)
	_chips(at, 4, Color(0.16, 0.13, 0.1), 2.2, 0.6)
	var p := _emitter()
	if p != null:
		p.amount = 14
		p.lifetime = 1.7
		p.explosiveness = 0.55
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.35
		p.direction = Vector3.UP
		p.spread = 12.0
		p.initial_velocity_min = 0.7
		p.initial_velocity_max = 1.8
		p.damping_min = 0.3
		p.damping_max = 0.6
		p.gravity = Vector3(0.0, 0.3, 0.0)
		p.angle_min = -180.0
		p.angle_max = 180.0
		p.angular_velocity_min = -40.0
		p.angular_velocity_max = 40.0
		_curve(p, 0.5, 2.0)
		_ramp(p, [Color(MIST, 0.0), Color(MIST, 0.5), Color(MIST.lightened(0.05), 0.0)], [0.0, 0.2, 1.0])
		p.mesh = _quad(0.75, Q_LIT)
		_fire(p, at + Vector3(0.0, 0.15, 0.0))
	_dust(at, 6, 1.2, 0.3, 0.8)


# ---------------------------------------------------------------- 몸의 자리(부품이 있으면 그것, 없으면 어림)

func _hoof(e: Enemy) -> Vector3:
	var knees: Array = _parts(e).get("knees", [])
	if knees.size() > 1 and is_instance_valid(knees[1]) and (knees[1] as Node3D).is_inside_tree():
		var p: Vector3 = (knees[1] as Node3D).global_transform * Vector3(0.0, -0.44, -0.01)
		p.y = _hy(p)
		return p
	var g: float = _grow(e)
	var f: Vector3 = _dir3(_face(e))
	var p2: Vector3 = _ground(_epos(e), 0.0) + f * 0.6 * g + _right(f) * 0.27 * g
	p2.y = _hy(p2)
	return p2


func _head(e: Enemy) -> Vector3:
	var h := _node(e, "head")
	if h != null:
		return h.global_position
	var g: float = _grow(e)
	return _ground(_epos(e), 1.05 * g) + _dir3(_face(e)) * 1.0 * g


func _belly(e: Enemy) -> Vector3:
	var b := _node(e, "belly")
	var f: Vector3 = _dir3(_face(e))
	var g: float = _grow(e)
	if b != null:
		return b.global_position + f * 0.2 * g * b.scale.x + Vector3(0.0, -0.02, 0.0)
	return _ground(_epos(e), 0.55 * g) + f * 0.25 * g


## 지팡이 아래 끝이 땅에 닿은 자리(땅 위).
func _staff_tip(e: Enemy, at: Vector2) -> Vector3:
	var s := _node(e, "staff")
	var p: Vector3
	if s != null:
		p = s.global_transform * (-EnemyArt.STAFF_GRIP)
	else:
		var g: float = _grow(e)
		var f: Vector3 = _dir3(_face(e))
		p = _ground(_epos(e) if e != null else at, 0.0) + f * 0.46 * g + _right(f) * 0.3 * g
	p.y = _hy(p)
	return p


# ---------------------------------------------------------------- 효과 묶음(job)

## 살아 있는 효과 하나. fn(j, dt)가 false를 돌려주면 끝나고, 쥔 것(decal, emit, node, voice)을 돌려놓는다.
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
	var n: Variant = j.get("node")
	if n is Node and is_instance_valid(n):
		(n as Node).queue_free()
	var a: Variant = j.get("arrow")
	if a is Dictionary:
		_free_arrow(a)
	for key in _by_enemy.keys():
		if is_same(_by_enemy[key], j):
			_by_enemy.erase(key)
	# 쥔 소리(심지의 쉬익)는 그 재생기가 아직 이 소리를 틀고 있을 때만 멈춘다(다른 소리에 넘어갔으면 둔다)
	var vo: Variant = j.get("voice")
	if vo is AudioStreamPlayer3D:
		var p: AudioStreamPlayer3D = vo
		if p.playing and int(p.get_meta("serial", -1)) == int(j.get("voice_serial", -2)):
			p.stop()


## 이 적의 같은 이름 효과가 아직 있으면 거둔다(다음 _process에서 쥔 것을 돌려놓는다).
func _drop(e: Enemy, what: String) -> void:
	var key: String = _key(e, what)
	if not _by_enemy.has(key):
		return
	var j: Dictionary = _by_enemy[key]
	_by_enemy.erase(key)
	j["dead"] = true


func _key(e: Enemy, what: String) -> String:
	return "%d:%s" % [e.id if e != null else -1, what]


## 이 적이 아직 그 행동 중인지. Enemy.act가 없으면(갤러리, 기능팀 전) 늘 그렇다고 본다(시간으로만 끝낸다).
func _still(e: Enemy, act: StringName) -> bool:
	if e == null:
		return true
	if e.dead:
		return false
	var a: Variant = e.get("act")
	if a == null:
		return true
	return StringName(a) == act


# ---------------------------------------------------------------- 화살

func _take_arrow() -> Dictionary:
	if not _arrow_free.is_empty():
		return _arrow_free.pop_back()
	var live: int = _arrows.size()
	for j in _jobs:
		if j.has("arrow"):
			live += 1
	if live >= MAX_ARROWS:
		# 땅에 꽂힌 것 중 가장 오래된 것을 거둔다
		for j in _jobs:
			if j.has("arrow"):
				var a: Dictionary = j["arrow"]
				j.erase("arrow")
				j["dead"] = true
				(a["mi"] as MeshInstance3D).visible = false
				return a
		return {}
	var mi := MeshInstance3D.new()
	mi.mesh = EnemyArt.arrow_mesh()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_layer.add_child(mi)
	var tr := MeshInstance3D.new()
	tr.mesh = _trail_mesh()
	var mat := ShaderMaterial.new()
	mat.shader = _shader("trail_shader", TRAIL_SHADER)
	tr.material_override = mat
	tr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_layer.add_child(tr)
	return {"mi": mi, "trail": tr, "mat": mat}


func _free_arrow(a: Dictionary) -> void:
	if a.is_empty():
		return
	(a["mi"] as MeshInstance3D).visible = false
	(a["trail"] as MeshInstance3D).visible = false
	a.erase("p")
	if not _arrow_free.has(a):
		_arrow_free.append(a)


func _place_arrow(a: Dictionary, alpha: float) -> void:
	var p: Projectile = a.get("p")
	if p == null:
		return
	var cells: Vector2 = p.prev_pos.lerp(p.pos, alpha)
	var d: Vector2 = p.dir if p.dir.length_squared() > 1e-6 else p.pos - p.prev_pos
	var d3: Vector3 = _dir3(d)
	var tip: Vector3 = _ground(cells, arrow_height)
	var b := Basis.looking_at(d3, Vector3.UP)
	(a["mi"] as MeshInstance3D).transform = Transform3D(b, tip)
	# 꼬리: 깃 뒤에서 지나온 만큼(arrow_trail까지)
	var gone: float = Grid.cells_to_meters(cells.distance_to(a["start"])) - EnemyArt.ARROW_LENGTH
	var L: float = clampf(gone, 0.02, arrow_trail)
	var tail: Vector3 = tip - d3 * EnemyArt.ARROW_LENGTH * 0.92
	(a["trail"] as MeshInstance3D).transform = Transform3D(b * Basis.from_scale(Vector3(0.07, 0.07, L)), tail)


## 꽂힌 화살: 0.08초에 땅으로 파고들고, 잠깐 떨고, arrow_stuck초 뒤 0.5초 동안 가라앉는다.
func _run_stuck(j: Dictionary, _dt: float) -> bool:
	var a: Dictionary = j["arrow"]
	var mi: MeshInstance3D = a["mi"]
	var t: float = j["t"]
	var from: Transform3D = j["from"]
	var to: Transform3D = j["to"]
	if t < 0.08:
		var k: float = t / 0.08
		mi.transform = Transform3D(from.basis.slerp(to.basis, k), from.origin.lerp(to.origin, k * k))
		return true
	if not bool(j["landed"]):
		j["landed"] = true
		_dust(to.origin, 4, 0.9, 0.2, 0.6)
		_chips(to.origin, 2, Color(0.2, 0.16, 0.12), 1.4, 0.4)
		_play(&"enemy_arrow_ground", to.origin, -10.0)
	var s: float = t - 0.08
	var side: Vector3 = (j["dir"] as Vector3).cross(Vector3.UP).normalized()
	var wob: float = 0.1 * exp(-s * 9.0) * sin(s * 55.0)
	var b: Basis = Basis(side, wob) * to.basis
	var sink: float = maxf(0.0, s - arrow_stuck) / 0.5
	if sink >= 1.0:
		return false
	mi.transform = Transform3D(b, to.origin + (j["dir"] as Vector3) * 0.6 * sink * sink)
	return true


static func _trail_mesh() -> ArrayMesh:
	if _cache.has("trail"):
		return _cache["trail"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for plane in 2:
		var w: Vector3 = Vector3(0.5, 0, 0) if plane == 0 else Vector3(0, 0.5, 0)
		var v: Array[Vector3] = [-w, w, w + Vector3(0, 0, 1), -w + Vector3(0, 0, 1)]
		var uv: Array[Vector2] = [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uv[i])
			st.set_normal(Vector3.UP)
			st.add_vertex(v[i])
	var m := st.commit()
	_cache["trail"] = m
	return m


## 화살 메시를 ARROW_CUT에서 잘라 [앞(촉), 뒤(깃)] 두 토막. 토막마다 원점을 제 가운데로 옮겼다.
static func _arrow_halves() -> Array:
	if _cache.has("halves"):
		return _cache["halves"]
	var src: ArrayMesh = EnemyArt.arrow_mesh()
	var arr: Array = src.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if idx.is_empty():
		for i in verts.size():
			idx.append(i)
	var out: Array = []
	for half in 2:
		var center: float = ARROW_CUT * 0.5 if half == 0 else (ARROW_CUT + EnemyArt.ARROW_LENGTH) * 0.5
		var sgn: float = 1.0 if half == 0 else -1.0   # 남길 쪽: sgn * (ARROW_CUT - z) >= 0
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for t in range(0, idx.size() - 2, 3):
			var poly: Array = []
			for k in 3:
				var i: int = idx[t + k]
				poly.append([verts[i], norms[i], cols[i] if i < cols.size() else Color.WHITE])
			var clipped: Array = _clip(poly, sgn)
			for k in range(1, clipped.size() - 1):
				for q: Array in [clipped[0], clipped[k], clipped[k + 1]]:
					st.set_color(q[2])
					st.set_normal(q[1])
					st.add_vertex((q[0] as Vector3) - Vector3(0.0, 0.0, center))
		var m := st.commit()
		m.surface_set_material(0, src.surface_get_material(0))
		out.append(m)
	_cache["halves"] = out
	return out


## 다각형([위치, 법선, 색] 목록)을 평면 z = ARROW_CUT로 잘라 sgn * (ARROW_CUT - z) >= 0 쪽만 남긴다.
static func _clip(poly: Array, sgn: float) -> Array:
	var out: Array = []
	var n: int = poly.size()
	for i in n:
		var a: Array = poly[i]
		var b: Array = poly[(i + 1) % n]
		var da: float = sgn * (ARROW_CUT - (a[0] as Vector3).z)
		var db: float = sgn * (ARROW_CUT - (b[0] as Vector3).z)
		if da >= 0.0:
			out.append(a)
		if (da >= 0.0) != (db >= 0.0):
			var k: float = da / (da - db)
			out.append([(a[0] as Vector3).lerp(b[0], k), ((a[1] as Vector3).lerp(b[1], k)).normalized(), (a[2] as Color).lerp(b[2], k)])
	return out


# ---------------------------------------------------------------- 조각(파편, 부러진 화살): 땅에 떨어져 눕고 가라앉는다

## mesh를 xf에서 던진다. col이 null이면 메시의 재질 그대로(부러진 화살), 아니면 이 조각의 재질 색(hot > 0이면 달궈져 식는다).
## spin = 돌기 축 × 빠르기(라디안/초). rest = 땅 위에 남는 높이, flat이면 긴 쪽(Z)을 땅에 눕힌다. hold = 누운 뒤 가라앉기 전까지(초).
func _toss(mesh: Mesh, col: Variant, xf: Transform3D, vel: Vector3, spin: Vector3, rest: float, flat: bool, hold: float, hot: float = 0.0) -> void:
	var c: Dictionary = {}
	for x in _chunks:
		if not bool(x["busy"]):
			c = x
			break
	if c.is_empty():
		if _chunks.size() >= MAX_CHUNKS:
			return
		var mi := MeshInstance3D.new()
		var m := StandardMaterial3D.new()
		m.roughness = 0.95
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_layer.add_child(mi)
		c = {"mi": mi, "mat": m}
		_chunks.append(c)
	var mi2: MeshInstance3D = c["mi"]
	var mat: StandardMaterial3D = c["mat"]
	mi2.mesh = mesh
	if col == null:
		mi2.material_override = null
	else:
		mat.albedo_color = col
		mat.emission_enabled = hot > 0.0
		mat.emission = EMBER
		mat.emission_energy_multiplier = hot
		mi2.material_override = mat
	mi2.transform = xf
	mi2.visible = true
	c["busy"] = true
	c["vel"] = vel
	c["spin"] = spin
	c["rest"] = rest
	c["flat"] = flat
	c["hold"] = hold
	c["hot"] = hot
	c["t"] = 0.0
	c["down"] = -1.0
	c["bounced"] = false
	c["scale"] = xf.basis.get_scale()


func _step_chunks(dt: float) -> void:
	for c in _chunks:
		if not bool(c["busy"]):
			continue
		var mi: MeshInstance3D = c["mi"]
		c["t"] = float(c["t"]) + dt
		var hot: float = c["hot"]
		if hot > 0.0:
			(c["mat"] as StandardMaterial3D).emission_energy_multiplier = hot * exp(-float(c["t"]) * 2.2)
		var down: float = c["down"]
		var xf: Transform3D = mi.transform
		if down < 0.0:
			var v: Vector3 = c["vel"]
			v.y -= 9.8 * dt
			var p: Vector3 = xf.origin + v * dt
			var spin: Vector3 = c["spin"]
			var b: Basis = xf.basis
			if spin.length() > 0.001:
				b = Basis(spin.normalized(), spin.length() * dt) * b
			var floor_y: float = _hy(p) + float(c["rest"])
			if p.y <= floor_y and v.y < 0.0:
				p.y = floor_y
				if not bool(c["bounced"]) and absf(v.y) > 1.5:
					c["bounced"] = true
					v = Vector3(v.x * 0.45, -v.y * 0.28, v.z * 0.45)
					c["spin"] = spin * 0.5
				else:
					c["down"] = float(c["t"])
					var sc: Vector3 = c["scale"]
					if bool(c["flat"]):
						var z: Vector3 = b.z
						var fz := Vector3(z.x, 0.0, z.z)
						if fz.length() < 0.01:
							fz = Vector3.FORWARD
						b = Basis.looking_at(-fz.normalized(), Vector3.UP).scaled(sc)
					v = Vector3.ZERO
			c["vel"] = v
			mi.transform = Transform3D(b, p)
		else:
			var s: float = float(c["t"]) - down - float(c["hold"])
			if s > 0.0:
				var k: float = s / 0.6
				if k >= 1.0:
					c["busy"] = false
					mi.visible = false
					continue
				mi.transform = Transform3D(xf.basis, Vector3(xf.origin.x, xf.origin.y - dt * 0.35, xf.origin.z))


# ---------------------------------------------------------------- 땅 판

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
	m.set_shader_parameter("fill", 0.0)
	m.set_shader_parameter("fade", 1.0)
	m.set_shader_parameter("energy", 0.0)
	m.set_shader_parameter("ew", 0.08)
	m.set_shader_parameter("hw", 0.02)
	m.set_shader_parameter("seed", float(_serial % 37) * 3.7)
	m.set_shader_parameter("color", RED)
	m.set_shader_parameter("hot", RED_HOT)
	m.set_shader_parameter("emit", [0.5, 0.5, 0.8, 0.0, 1.6, 2.0][clampi(mode, 0, 5)])
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


## 띠 판을 from(칸)에서 dir 쪽으로 start m 떨어진 곳부터 length m, 폭 width m로 눕힌다.
func _lane(d: Dictionary, from: Vector2, dir: Vector2, start: float, length: float, width: float, lift: float) -> void:
	if d.is_empty():
		return
	var d3: Vector3 = _dir3(dir)
	var c: Vector3 = _ground(from, 0.0) + d3 * (start + length * 0.5)
	c.y = _hy(c) + lift
	(d["mi"] as MeshInstance3D).transform = Transform3D(Basis.looking_at(d3, Vector3.UP) * Basis.from_scale(Vector3(width, 1.0, maxf(0.05, length))), c)


## 갈라진 틈(MoveArt의 금 모양): 빠르게 자라고, energy면 잠깐 틈에서 빛이 났다가 어두운 금으로 남은 뒤 hold초에 사라진다.
## k = 진하기(0~1). along이 있으면 그 쪽(세계 방향)으로 늘이고 옆으로 줄여 발굽에 파인 자국처럼 한다.
func _crack(at: Vector3, r: float, c: Color, energy: float, hold: float, k: float = 1.0, along: Vector3 = Vector3.ZERO) -> void:
	var key: String = "crack%d_%d" % [roundi(r * 10.0), _rng.randi() % 4]
	if not _cache.has(key):
		_cache[key] = MoveArt.crack_mesh(_rng.randi(), r)
	var m := MeshInstance3D.new()
	m.mesh = _cache[key]
	var mat := MoveArt.crack_material(c)
	mat.set_shader_parameter("grow", 0.0)
	mat.set_shader_parameter("energy", energy)
	mat.set_shader_parameter("fade", k)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = Vector3(at.x, _hy(at) + 0.034, at.z)
	if along.length_squared() > 0.001:
		m.basis = Basis.looking_at(along, Vector3.UP) * Basis.from_scale(Vector3(0.45, 1.0, 1.3))
	else:
		m.rotation.y = _rng.randf() * TAU
	_layer.add_child(m)
	_job(_run_crack, {"node": m, "mat": mat, "energy": energy, "hold": hold, "k": k})


func _run_crack(j: Dictionary, _dt: float) -> bool:
	var t: float = j["t"]
	var mat: ShaderMaterial = j["mat"]
	var hold: float = j["hold"]
	mat.set_shader_parameter("grow", clampf(1.0 - pow(1.0 - t / 0.12, 2.0), 0.0, 1.0))
	mat.set_shader_parameter("energy", float(j["energy"]) * exp(-t * 3.5))
	var k: float = (t - hold) / 0.6
	if k >= 1.0:
		return false
	mat.set_shader_parameter("fade", float(j["k"]) * (1.0 - clampf(k, 0.0, 1.0)))
	return true


## 쇠의 번쩍임(MoveArt의 빌보드 별). 깊이 검사를 받으니 카메라 쪽으로 조금 당긴다.
func _glint(p: Vector3, size: float, c: Color, k: float, life: float) -> void:
	var key: String = "glint%.2f" % size
	if not _cache.has(key):
		_cache[key] = MoveArt.glint_mesh(size)
	var m := MeshInstance3D.new()
	m.mesh = _cache[key]
	var mat := MoveArt.glint_material(c)
	mat.set_shader_parameter("fade", k)
	mat.set_shader_parameter("spin", _rng.randf_range(-0.3, 0.3))
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = _toward_cam(p, 0.5)
	m.scale = Vector3.ONE * 0.35
	_layer.add_child(m)
	_job(_run_glint, {"node": m, "mat": mat, "k": k, "life": life})


func _run_glint(j: Dictionary, _dt: float) -> bool:
	var t: float = j["t"]
	var life: float = j["life"]
	if t >= life:
		return false
	var n: Node3D = j["node"]
	n.scale = Vector3.ONE * (0.35 + 0.65 * minf(1.0, t / 0.05))
	var k: float = 1.0 - t / life
	(j["mat"] as ShaderMaterial).set_shader_parameter("fade", float(j["k"]) * k * k)
	return true


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


func _toward_cam(p: Vector3, d: float) -> Vector3:
	var vp := get_viewport()
	var cam: Camera3D = vp.get_camera_3d() if vp else null
	if cam == null:
		return p
	return p + (cam.global_position - p).normalized() * d


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


## 한 번 터지는 알갱이를 at에서 터뜨린다(lifetime이 지나면 다시 쓴다).
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
	p.position = Vector3.ZERO
	p.rotation = Vector3.ZERO
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINT
	p.emission_sphere_radius = 0.1
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_height = 0.0
	p.emission_ring_radius = 1.0
	p.emission_ring_inner_radius = 0.0
	p.emission_box_extents = Vector3.ONE
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
	p.particle_flag_align_y = false
	p.mesh = null


## 흙먼지: 땅을 따라 둥글게 퍼진다(kick이 있으면 그쪽으로 튄다).
func _dust(at: Vector3, amount: int, speed: float, size: float, life: float, kick: Vector3 = Vector3.ZERO) -> void:
	var p := _emitter()
	if p == null:
		return
	p.amount = maxi(1, amount)
	p.lifetime = life
	p.explosiveness = 0.92
	if kick.length_squared() > 0.001:
		p.direction = kick.normalized()
		p.spread = 35.0
	else:
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
func _sparks(at: Vector3, amount: int, dir: Vector3, spread: float, vmin: float, vmax: float, c: Color, life: float, small: bool = false) -> void:
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
	p.gravity = Vector3(0.0, -11.0, 0.0)
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.particle_flag_align_y = true
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.1
	_ramp(p, [Color(c.r * 3.0, c.g * 2.6, c.b * 2.2, 1.0), Color(c.r * 1.2, c.g * 0.6, c.b * 0.4, 0.6), Color(c.r * 0.6, c.g * 0.25, c.b * 0.1, 0.0)], [0.0, 0.5, 1.0])
	p.mesh = _spark_small if small else _spark_mesh
	_fire(p, at)


## 작은 조각(나뭇조각, 쇳조각, 흙): 튀어 올라 돌며 떨어진다.
func _chips(at: Vector3, amount: int, c: Color, speed: float, life: float, dir: Vector3 = Vector3.UP) -> void:
	var p := _emitter()
	if p == null:
		return
	p.amount = maxi(1, amount)
	p.lifetime = life
	p.explosiveness = 0.95
	p.randomness = 0.5
	p.direction = (dir.normalized() + Vector3(0.0, 1.0, 0.0)).normalized()
	p.spread = 50.0
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


func _ramp(p: CPUParticles3D, cols: Array, offs: Array) -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offs)
	g.colors = PackedColorArray(cols)
	p.color_ramp = g


## 불 조각마다 조금씩 다른 밝기·붉기(한 덩이로 뭉쳐 보이지 않게).
func _fire_vary() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1.0, 1.0, 1.0), Color(0.62, 0.42, 0.34)])
	return g


func _curve(p: CPUParticles3D, a: float, b: float) -> void:
	var c := Curve.new()
	c.max_value = maxf(a, b)
	c.add_point(Vector2(0.0, a))
	c.add_point(Vector2(1.0, b))
	p.scale_amount_curve = c


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
	var key: String = "%d_%.2f" % [kind, size]
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


## 가장자리가 들쭉날쭉한 연기·먼지 조각(가운데가 진하고 잡음으로 찢긴다). 한 번만 만든다.
static func _puff() -> ImageTexture:
	if _cache.has("puff"):
		return _cache["puff"]
	var s: int = 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var nz := FastNoiseLite.new()
	nz.seed = 3
	nz.frequency = 0.08
	nz.fractal_octaves = 3
	for y in s:
		for x in s:
			var d: float = Vector2(x + 0.5 - s * 0.5, y + 0.5 - s * 0.5).length() / (s * 0.5)
			var n: float = nz.get_noise_2d(x, y) * 0.5 + 0.5
			var a: float = (1.0 - smoothstep(0.15, 1.0, d + (n - 0.5) * 0.8)) * (0.35 + 0.9 * n)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache["puff"] = t
	return t


static func _shader(key: String, code: String) -> Shader:
	if _cache.has(key):
		return _cache[key]
	var s := Shader.new()
	s.code = code
	_cache[key] = s
	return s


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
	p.pitch_scale = pitch * (1.0 + _rng.randf_range(-0.05, 0.05))
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
	rng.seed = 11
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

## 칸 위치의 땅 위 lift m(세계 좌표). 싸움터 밖이면 비탈 높이.
func _ground(cells: Vector2, lift: float) -> Vector3:
	var w: Vector3 = Grid.cells_to_world(cells)
	w.y = HillBuilder.height(w.x, w.z) + lift
	return w


func _hy(p: Vector3) -> float:
	return HillBuilder.height(p.x, p.z)


func _dir3(d: Vector2) -> Vector3:
	var v := Vector3(d.x, 0.0, d.y)
	return v.normalized() if v.length_squared() > 1e-8 else Vector3.FORWARD


## 몸의 앞(-Z)이 face일 때 오른쪽(+X)이 가리키는 세계 방향(EnemyView의 돌기와 같다).
func _right(f: Vector3) -> Vector3:
	return Vector3(-f.z, 0.0, f.x)


func _v2(v: Variant) -> Vector2:
	if v is Vector2:
		return v
	if v is Vector2i:
		return Vector2(v)
	return Vector2.ZERO


func _epos(e: Enemy) -> Vector2:
	if e == null:
		return Vector2.ZERO
	return e.prev_pos.lerp(e.pos, _alpha)


func _face(e: Enemy) -> Vector2:
	if e == null or e.face.length_squared() < 1e-6:
		return Vector2.UP
	return e.face.normalized()


## 적의 크기 배수(정예는 1보다 크다). EnemyArt의 scale과 같다.
func _grow(e: Enemy) -> float:
	if e == null or e.data == null or e.data.radius <= 0.0:
		return 1.0
	return e.radius / e.data.radius


func _parts(e: Enemy) -> Dictionary:
	if e == null or not body_of.is_valid():
		return {}
	var v: Variant = body_of.call(e)
	return v if v is Dictionary else {}


func _node(e: Enemy, key: String) -> Node3D:
	var n: Variant = _parts(e).get(key)
	if n is Node3D and is_instance_valid(n) and (n as Node3D).is_inside_tree():
		return n
	return null
