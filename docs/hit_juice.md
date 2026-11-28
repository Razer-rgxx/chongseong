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

## 2026-11-28 보강
- 화각 조임: 목표로 빠르게 들어가고(`FOV_PINCH_ATTACK`) 0.05초 머문 뒤 `FOV_PINCH_DECAY`로 돌아온다. 큰 베기 5도, 마무리 6.5도. 미래·과거·마을 방어전도 `HitFx.struck`를 부른다.
- 피 붙잡기: 멈춤 프레임이 없어도 최소 `HOLD_MIN`(0.06초).
- 물건 튀기: `PropKick.setup`이 한 프레임 뒤 장면을 훑어(`_scan`) 작은 꾸밈(발자국 `SCAN_XZ`, 높이 `SCAN_Y_MIN~MAX`)을 모은다. 스크립트·빛·입자·뼈대·막힘 표 위의 것과 큰 것은 뺀다. 언덕·들판·무덤·미래·과거에 붙는다(마을 아님). 8m 칸 공간 해시로 근처만 검사, 튄 뒤 `height_of`로 비탈에 내려앉는다.
- 체력 젖음: 재질을 바꾸지 않고 몸 메시마다 `material_overlay`(어두운 핏빛, 체력 90% 아래부터, 0이면 `WOUND_ALPHA`)를 얹어 Mixamo·셰이더·도형을 모두 덮는다.
- 빛: 환경광 `AMBIENT_*_MUL` 더 낮게, 횃불 반경 `TORCH_RANGE_MUL`·세기 `TORCH_ENERGY_MUL` 키움. 가장자리 안개는 장막 둘(안쪽 `EDGE_FOG_INSET`), 높이 7m.

