class_name Juice
extends RefCounted
## 손맛 꾸밈(docs/hit_juice.md)의 조절 상수와 색 역할 한 곳. 규칙과 무관한 화면 값이라 마음대로 맞춰도 규칙은 안 바뀐다.
## 웹판(WebQuality.on())에서는 점광원을 끄고 알갱이를 WEB_KEEP 비율로 줄인다.

# ---- 색 역할: 영주 쪽은 놋쇠빛·흰빛, 적의 눈은 차가운 파랑, 위험 예고는 붉은색 ----
const LORD_LIGHT := Color(1.0, 0.72, 0.45)     ## 영주 둘레의 따뜻한 놋쇠빛(횃불)
const LORD_WHITE := Color(1.0, 0.95, 0.86)
const EYE_COLD := Color(0.7, 0.85, 1.0)        ## 보통 적의 눈
const EYE_ELITE := Color(1.0, 0.8, 0.35)       ## 정예·우두머리·보스의 눈(격을 보이는 예외)
const DANGER_DARK := Color(0.34, 0.035, 0.025) ## 위험 예고 땅 자국
const DANGER_HOT := Color(0.6, 0.09, 0.045)
const DANGER_EYE := Color(1.0, 0.16, 0.1)      ## 때리기 직전 눈이 기우는 붉은색
const DANGER_EYE_MIX: float = 0.6              ## 그 기울기(0~1)
const FIRE_WARM := Color(1.0, 0.6, 0.28)       ## 점광원·불똥의 주황

# ---- 1. 맞은 자리 점광원 ----
const HIT_LIGHT_POOL: int = 4                  ## 동시에 켤 수 있는 수(웹은 0)
const HIT_LIGHT_TIME: float = 0.1              ## 켜졌다 꺼지는 데 걸리는 초
const HIT_LIGHT_ENERGY: float = 2.2
const HIT_LIGHT_ENERGY_BIG: float = 3.6
const HIT_LIGHT_RANGE: float = 4.5

# ---- 2. 멈춤 프레임 동안 붙잡는 조각 ----
const HOLD_TIME: float = 0.066                 ## 작은 타격(LordData.hitstop과 같게)
const HOLD_TIME_BIG: float = 0.133             ## 큰 타격(hitstop_big)
const HOLD_SPEED: float = 0.04                 ## 붙잡는 동안 알갱이 시간 배수(0이면 아예 안 나온다)
const HOLD_RELEASE: float = 0.12               ## 놓은 뒤 속도가 0에서 1로 돌아오는 초(흩어지는 느낌)
const WEB_KEEP: float = 0.5                    ## 웹판 알갱이 비율

# ---- 3. 꾸밈 물건 튀기 ----
const KICK_REACH_PAD: float = 1.0              ## 베기 닿는 거리(m)에 더하는 여유
const KICK_SPEED: float = 5.0                  ## 튀는 세기(m/초)
const KICK_LIFE: float = 1.1                   ## 날다 가라앉는 초
const KICK_MAX_MOVING: int = 8                 ## 한꺼번에 움직이는 물건 수

# ---- 4. 카메라 화각 조임(흔들기와 따로) ----
const FOV_PINCH_BIG: float = 4.0               ## 큰 베기(도)
const FOV_PINCH_FINISH: float = 7.0            ## 마무리·쓰러뜨림(도)
const FOV_PINCH_DECAY: float = 22.0            ## 돌아오는 속도(도/초)

# ---- 5. 갑옷 불꽃 ----
const SPARK_COUNT: int = 10
const SPARK_COUNT_BIG: int = 18
const SHARD_COUNT: int = 3                     ## 작은 쇳조각
const SPARK_LIFE: float = 0.35
const SPARK_COLOR := Color(1.0, 0.55, 0.16)

# ---- 6. 체력이 깎인 몸 ----
const WOUND_MAX: float = 0.22                  ## 체력 0일 때 몸이 젖는 정도(0~1). 아주 약하게
const WOUND_COLOR := Color(0.16, 0.025, 0.025)

# ---- 7. 빛 웅덩이 대비(환경광은 어둡게, 불빛은 따뜻하고 둥글게) ----
const AMBIENT_NIGHT_MUL: float = 0.72          ## 언덕·들판 밤 환경광 배수
const AMBIENT_CRYPT_MUL: float = 0.8           ## 무덤 환경광 배수
const TORCH_ATTEN: float = 1.5                 ## 점광원 감쇠(클수록 가운데에 모이고 둥글다)
const TORCH_ENERGY_MUL: float = 1.15           ## 영주 횃불 세기 배수

# ---- 8. 언덕 싸움터 가장자리 안개 ----
const EDGE_FOG_HEIGHT: float = 5.0             ## 높이(m)
const EDGE_FOG_COLOR := Color(0.03, 0.04, 0.06)
const EDGE_FOG_ALPHA: float = 0.85             ## 바닥에서의 진하기

# ---- 10. 쿼터뷰 발밑 고리 ----
const RING_RADIUS: float = 0.95
const RING_WIDTH: float = 0.07
const RING_ALPHA: float = 0.32


static func web() -> bool:
	return WebQuality.on()


## 갑옷 입은 적인가: 방패, 우두머리, 보스, 무덤 기사·무덤 주인.
static func armored(e: Enemy) -> bool:
	if e == null or e.data == null:
		return false
	var D: EnemyData = e.data
	return D.guard_arc > 0.0 or D.boss or e.chief != &"" or D.id in [&"grave_knight", &"crypt_lord", &"guardian"]
