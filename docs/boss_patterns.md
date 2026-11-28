# 보스 패턴 (2026-11-23)

사용자: "보스들 패턴 좀 추가". 언덕지기·무덤 기사·무덤 주인이 기사형 행동(`Foes._knight`: 휘두르기·돌진·부르기·빨라짐) 위에 새 패턴을 얹는다.
수치는 모두 `EnemyData`의 "보스 패턴" 칸이고 0이면 그 패턴이 없다. 곳마다 우두머리(32단계)는 그대로다.

## 무엇을 하나

| 패턴 | 언제 고르나 | 예고 | 터짐 | 피하는 법 |
| --- | --- | --- | --- | --- |
| 연속 베기 | 휘두르기 뒤 `combo`번 더(빨라지면 `combo_rage` 더) | 다시 영주 쪽 부채꼴 `combo_wind`초 | 부채꼴 안이면 피해 | 뒤로 돌아 들어가기, 구르기 |
| 내려찍기 | 휘두를 거리 안에서 `slam_chance` | 발밑 위험 원 `slam_time`초, 충격파 끝 고리(옅게) | 둘레 `slam_radius`칸 피해 × `slam_mult`, `slam_knock`칸 밀림. 그 뒤 `slam_rest`초 틈 | 원 밖으로 나가기 |
| 충격파 | 내려찍기 가장자리에서 | — | 고리가 `quake_speed`칸/초로 `quake_range`칸까지 퍼진다. 지나가면 피해 × `quake_mult` 한 번 | 고리가 올 때 구르기 |
| 칼비 (언덕지기) | `rain_min`칸보다 멀면 `rain_chance` | 칼을 하늘로 세움 `rain_time`초, 자리마다 위험 원 | 영주 자리 하나 + 둘레 `rain_spread`칸 안 `rain_count`곳(빨라지면 + `rain_rage`)에 `rain_delay`초 뒤부터 `rain_step`초 간격으로 칼이 꽂힌다(피해 × `rain_mult`) | 원 밖으로 비키기 |
| 무덤 손 (무덤 주인) | 칼비와 같음(`rain_line`, `rain_look` hand) | 발밑이 갈라짐, 자리마다 위험 원 | 보스에서 영주를 지나 `rain_spread`칸 더 가는 줄로 가까운 곳부터 뼈 가시가 솟는다 | 옆으로 비키기 |
| 땅 가르기 (무덤 기사) | `swing_range`보다 멀고 `cleave_range` 안에서 `cleave_chance` | 앞길 띠 `cleave_time`초 | 참격파가 `cleave_speed`칸/초로 곧게(폭 `cleave_width`, 벽에서 멈춤), 피해 × `cleave_mult` | 옆으로 비키기, 구르기 |
| 그림자 걸음 (무덤 주인) | `blink_min`칸보다 멀면 `blink_chance` | 땅으로 꺼지며 나올 자리(영주 너머 `blink_dist`칸)에 위험 원 `blink_time`초 | 그 자리에서 솟아 곧바로 `blink_swing`초 알린 휘두르기(연속 베기도 이어짐) | 나올 자리에서 멀어지기 |

멀리 있을 때 고르는 차례: 그림자 걸음 → 칼비·무덤 손 → 땅 가르기 → 돌진. 하나도 안 고르면 `charge_retry`초 다가가다 다시 고른다.
고리·떨어지는 자리·참격파는 `Rules.enemy_projectiles`(kind `ring`, `fall`, `shock`)이고 화살과 달리 칼로 부러지지 않는다. 구르는 중(`dash`)·갈고리로 나는 중에는 지나간다.
예고는 모두 기절·얼음에 끊긴다(쉬고 연속 베기도 그친다).

## 보스마다

- **언덕지기**(마지막 구역의 밤): 연속 베기 2번(빨라지면 3번), 내려찍기 + 충격파(10칸), 칼비 5곳(빨라지면 8곳), 돌진. 50% 밑 ×1.25. 부르기는 없다(밤에 적이 이미 많다).
- **무덤 기사**(들판 옛 싸움터): 전과 같고 땅 가르기를 더했다. 빨라지면 두 번 벤다.
- **무덤 주인**(지하 무덤 마지막 방): 연속 베기 2번(빨라지면 3번), 그림자 걸음, 무덤 손 5곳(빨라지면 7곳), 돌진, 망령 부르기 두 번.

## 신호와 화면

- `Rules.enemy_act(e, act, info)`: `slam_wind{at, radius, range, time}` `slam{at, radius, range, hit}` `rain_wind{at, time, look}` `rain{at, count, look}`
  `cleave_wind{from, dir, length, time, width}` `cleave{at, dir}` `blink_wind{from, to, time}` `blink{from, at, dir}`, `swing_wind`에 `combo`(남은 수), `swing`에 `more`.
- `enemy_projectile_spawned/ended`: `ring`(pos 가운데, travelled 지금 반지름, distance 끝), `fall`(pos 자리, max_time 터지는 때, look sword·hand), `shock`(화살처럼 곧게). `landed`는 영주를 맞혔는지.
- `EnemyFx`가 그린다(땅 판 셰이더 mode 7 = 위험 고리). 땅이 울리면 `EnemyFx.quaked`를 내고 언덕·들판·무덤 장면이 카메라를 흔든다.
- `EnemyView._rust_pose`가 몸을 기울이고(내려찍기·칼비·땅 가르기) 그림자 걸음에는 몸을 땅으로 꺼뜨렸다가 솟게 한다.
- 확인용 그림: `scripts/debug/shots/shot_boss.gd`(들판 보스에게 패턴 하나씩만 남겨 찍는다). 테스트: `tests/boss_pattern_tests.gd`.
