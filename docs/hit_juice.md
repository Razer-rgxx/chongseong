# 손맛 꾸밈 (2026-11-28)

화면 연출만이다. `Rules`·규칙 상태·`state_hash`는 안 바뀌고, 랜덤은 화면 쪽 것을 쓴다. **조절 상수와 색 역할은 모두 `scripts/world/juice.gd`(`Juice`) 한 곳.** 웹판(`WebQuality.on()`)은 점광원을 아예 만들지 않고 알갱이를 `WEB_KEEP`(50%)로 줄이며 가장자리 안개를 안 만든다.

| # | 무엇 | 어디 |
| --- | --- | --- |
| 1 | 맞은 자리 점광원(0.1초, 풀 `HIT_LIGHT_POOL`개 돌려 씀) | `HitFx.hit_light`(blood/wisp/sparks가 부름) |
| 2 | 멈춤 프레임(`HOLD_TIME`) 동안 피·조각을 `HOLD_SPEED`로 붙잡았다 풂 | `HitFx._hold` |
| 3 | 꾸밈 통·상자·항아리·작은 돌이 베기(`move_started`/`move_area`) 근처에서 튀고 넘어짐. "kickable" 모임에 넣은 것만(막힘 표의 것은 안 넣음) | `PropKick`, 무덤 `CryptBuilder._props`·들판 불탄 마을 `FieldBuilder`·작은 돌 `_scatter` |
| 4 | 큰 베기·쓰러뜨림 때 화각을 좁혔다 돌아옴(흔들기·`fov_kick`과 따로) | `camera_rig.pinch`, `HitFx.struck`가 부름 |
| 5 | 갑옷 적(방패·우두머리·보스·무덤 기사·금고지기)과 발검 반격(칼 부딪힘)에 주황 불꽃과 쇳조각 | `HitFx.sparks`, `Juice.armored` |
| 6 | 체력이 깎일수록 몸이 아주 약하게 어둡고 붉게(`WOUND_MAX` 0.22) | `EnemyView._paint` |
| 7 | 환경광을 더 어둡게(`AMBIENT_*_MUL`), 불빛은 따뜻하고 둥글게(`TORCH_ATTEN`·`TORCH_ENERGY_MUL`) | main `_set_light`, field `_blend`, crypt, `LordView.torch`, 무덤 횃불 |
| 8 | 언덕 싸움터 가장자리 낮은 안개 | `EdgeFog`(main `_build_world`) |
| 9 | 색 역할: 영주 놋쇠·흰빛, 적 눈 차가운 파랑(정예·보스만 금빛), 때리기 직전 눈이 붉게, 위험 자국 붉은색 | `Juice` 색 상수, `EnemyArt.EYE_COLORS`·`EnemyView`·`EnemyFx.RED` |
| 10 | 쿼터뷰(V)일 때만 영주 발밑 옅은 고리 | `QuarterRing`(main·field·crypt) |

그림: `scripts/debug/shots/shot_juice.gd -- before|after [hill crypt quarter field]`(`--fixed-fps 30`, 한 장면에 몇 분) → `/home/claude/shots/juice_*.png`.
