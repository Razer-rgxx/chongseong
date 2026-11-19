# 마을 컨텐츠와 들판 (15·16단계 설계서)

2026-11-19 사용자가 정함: 마을에 **의뢰판, 수련장, 주민과 이야기, 떠돌이 상인**을 넣고, 마을 밖에 **싸움 없는 들판 탐험**(살짝 오픈월드)을 넣는다. GDD 2.14의 "마을에 더 들를 곳"은 이것으로 정해졌다.

팀은 **모양팀 → 기능팀** 순서다(CLAUDE.md). 모양팀 둘(마을 A, 들판 B)은 파일이 겹치지 않아 동시에 돈다. 기능팀은 15 → 16 차례로(meta.gd, lobby.gd가 겹친다). 이 문서가 팀 사이의 약속이다. 바꿀 일이 생기면 여기를 먼저 고친다.

공통: 어두운 사실풍, AI 에셋 없음, 우주·수묵 느낌 없음, 세계에 글자를 띄우지 않는다(수련장 피해 숫자만 예외). 말은 아래 띠(`Band`), 곳 이름은 `AreaTitle`, 창은 `UiKit`. 종소리·올라가는 삐 소리·위로 쓸어 올리는 소리 없음. 판의 랜덤은 `Rules.rng`, 판 밖(마을·들판)의 랜덤은 `Meta.rng`, 꾸밈 랜덤은 화면 쪽.

---

## 15단계: 마을

마을은 지금처럼 34 × 22칸이다(`lobby.gd`의 `forge_at` 등). 새로 들를 곳은 비어 있는 자리에 둔다(모양팀 A가 `VillageBuilder`의 집·소품 자리를 보고 정해 `lobby.gd`의 `@export`로 적을 값을 보고에 쓴다).

### 15.1 의뢰판 (`board`)

- 광장 가장자리의 나무 게시판. E로 열면 의뢰 카드 3장이 있는 창. 하나를 골라 **맡는다**(한 번에 하나). 맡은 의뢰는 다음 판에서 센다.
- 판이 끝나면(`Meta.record_run`) 맡은 의뢰를 이루었는지 보고, 이루면 조각을 주고 그 자리에 새 의뢰가 붙는다. 못 이루면 그대로 남는다. 의뢰판은 판이 끝날 때마다 안 맡은 것 하나를 바꾼다.
- 의뢰 종류(`QuestData`, `data/village.tres`의 표):

| id | 말 (예) | 셈 | 보상 |
| --- | --- | --- | --- |
| kill | 한 판에 적 60마리 | 쓰러뜨린 적 수 | 25 |
| kill_kind | 활잡이 12마리 | 그 종류 수 | 30 |
| zones | 5구역 넘기 | 넘은 구역 수 | 30 |
| elites | 정예 3 쓰러뜨리기 | 정예 수 | 35 |
| pull_grade | 영웅 이상 2자루 뽑기 | 그 등급 이상 뽑은 수 | 30 |
| perfect | 모두 제대로 당기기 3번 | `pull_perfect` 수 | 25 |
| goal | 사냥 목표 2번 이루기 | 그 밤 목표를 이룬 수 | 35 |
| events | 낮 사건 3번 쓰기 | 쓴 사건 수 | 20 |

  수치(n, 보상)는 표에 여러 줄로 둔다(쉬운 것·어려운 것). 고를 때 `Meta.rng`.
- Rules는 판 동안 `run_stats: Dictionary`를 센다: `kills`, `kills_by_kind`, `zones`, `elites`, `pulled_by_grade`, `perfect`, `goals_done`(목표 id → 수), `events_used`. `state_hash`에 넣는다.
- 신호/함수: `Meta.quest_board: Array`(3장), `Meta.quest_active: int`(-1 없음), `Meta.take_quest(i)`, `Meta.record_run`이 결과 `{quest_done: bool, quest_reward: int}`를 돌려준다(정산 창에 한 줄).

### 15.2 수련장 (`yard`)

- 마을 한쪽의 울타리 친 마당. 허수아비 3개, 검 걸이(E).
- 검 걸이에서 E: 창에서 **검집의 검 + 도감에서 찾은 검**(찾은 검의 맨 낮은 등급 판) 중 하나를 고른다. 영주가 마을에서 그 검을 쥐고 좌클릭으로 공격 방식을 시험한다. 마을을 떠나면 내려놓는다(판에 들고 가지 않는다).
- 허수아비는 규칙의 적이다(`EnemyData` `dummy`: 체력 아주 큼, 움직이지 않음, 때리지 않음, 공격 표 0, 3초 안 맞으면 체력이 다 찬다). 피해 숫자를 띄운다(언덕과 같은 피해 숫자). 띠에 "5초 피해 N"을 보인다.
- 마을의 Rules는 지금처럼 이동만 하던 것에서, 수련장 안에서만 좌클릭을 받는다(마당 밖에서는 휘두르지 않는다).

### 15.3 주민과 이야기 (`villager`)

- 주민 5명. 서서 숨 쉬고, 영주가 다가가면 고개를 돌린다. E로 말을 건다: 띠에 한 줄(누르면 다음 줄, 2~4줄). 대사는 `data/village.tres`.

| id | 누구 | 자리 |
| --- | --- | --- |
| gatekeeper | 문지기 | 북문 옆 |
| elder | 마을 어른 | 우물가 |
| drunk | 술꾼 | 광장 의자 |
| herbalist | 약초꾼 | 집 사이 |
| apprentice | 대장장이 도제 | 대장간 앞 |

- 대사에는 조건을 붙일 수 있다: 판 수 ≥ n, 가장 높이 오른 구역 ≥ n, 전설 이상을 찾음, 정상에 오름, 의뢰를 맡음. 조건이 맞는 줄 중 아직 안 들은 것부터.
- 이야기는 언덕과 검에 얽힌 짧은 사연(누가 왜 검을 꽂았나, 언덕지기는 무엇인가, 마을은 왜 남았나). 짧고 어둡게. 대사 안에 게임 조작 설명은 문지기·도제만.

### 15.4 떠돌이 상인 (`merchant`)

- 장터 좌판 옆 짐수레와 상인. E로 연다. 물건 3개(아래 5개 중 `Meta.rng`로, 판이 끝날 때마다 바뀐다). 조각으로 산다. 산 것은 **다음 판 하나에만** 쓰이고 판이 시작될 때 쓴다(`Meta.pack: Array[StringName]`, `Rules`가 시작할 때 읽고 비운다).

| id | 이름 | 다음 판에 | 값 |
| --- | --- | --- | --- |
| ticket | 뽑기 표 | 공짜 뽑기 +1 | 25 |
| whetstone | 숫돌 | 처음 쥔 검 최대 내구 +20% | 20 |
| charm | 운 부적 | 1~2구역 낮 뽑기 운 ×1.2 | 30 |
| note | 점쟁이 쪽지 | 1구역 낮 손잡이 조짐이 참으로 보인다 | 20 |
| bread | 말린 빵 | 최대 체력 +15 | 20 |

  같은 물건은 한 판에 하나. 값과 효과는 `data/village.tres`.

### 15.5 신호와 파일 (15단계)

- 모양팀 A(마을)의 파일만:
  - `scripts/lobby/village_props.gd` (`VillageProps`, static): `board(parent)`, `yard(parent)`(울타리·허수아비 3·검 걸이, 허수아비 노드 돌려줌), `merchant_cart(parent)`, `villager(kind, parent)`(형체: `EventArt`처럼 몸 부위 사전 돌려줌), 각 부위·크기·막는 자리(칸 단위 Rect2 / 원)를 돌려준다.
  - `scripts/lobby/villager_motion.gd` (`VillagerMotion`, static): `rest(P)`, `idle(P, rest, t)`, `look_at(P, rest, target_world, k)`, `talk(P, rest, t)`(말할 때 손짓), 허수아비 `dummy_hit(P, dir, k)`(맞으면 흔들림).
  - `scripts/lobby/village_fx.gd` (`VillageFx`): 허수아비 맞음(지푸라기·먼지), 의뢰를 맡을 때(종이 펄럭), 물건 살 때(동전 소리 아님: 낮은 나무·천 소리), 의뢰 보상 때.
  - `assets/ui/village/*.svg`: 의뢰 종류 8개, 물건 5개(놋쇠빛, `assets/ui/map/`과 같은 결). 만드는 스크립트는 `scripts/debug/build_village_icons.gd`.
  - `scripts/debug/village_gallery.gd` + `scenes/debug/village_gallery.tscn`.
- 기능팀의 파일: `scripts/core/`(Rules `run_stats`, Meta 의뢰·상인·`pack`), `scripts/core/data/`(VillageData 등), `data/village.tres`, `data/enemies/9_dummy.tres`, `scripts/lobby/lobby.gd`, `scripts/ui/`(창: 의뢰판·상인·검 걸이, `LobbyHud`), 테스트, 문서.

---

## 16단계: 들판 (마을 밖)

- 마을 북문에서 E → **들판**(`scenes/field/field.tscn`). 들판 북쪽 끝 언덕 발치의 길에서 E → 판 시작(`scenes/world/main.tscn`). 들판 남쪽 끝 마을 문에서 E → 마을. 판이 끝나면(R) 지금처럼 마을로.
- 크기 110 × 110칸(220m). 남쪽 가장자리에 마을 목책과 문, 북쪽에 언덕(큰 비탈과 그 위의 싸움터 둘레가 멀리 보인다), 가운데로 흙길이 휘어 언덕 발치까지 간다. 둘레는 숲·벼랑으로 막힌다(보이지 않는 벽 대신 나무와 바위가 막는 것처럼).
- 하늘과 빛은 마을과 같은 해 질 녘. 땅·풀·나무·바위는 `HillBuilder`의 것을 같이 쓴다.
- **싸움 없음.** 영주는 걷고 구르기만 한다(좌클릭 없음).

### 16.1 곳 (`area`)

들어서면 이름을 크게 한 번(`AreaTitle`, 들판에 올 때마다 곳마다 한 번).

| id | 이름 | 무엇 |
| --- | --- | --- |
| road | 언덕길 | 마을 문에서 언덕 발치까지 흙길, 수레바퀴 자국, 길가 이정표 |
| old_field | 옛 싸움터 | 녹슨 검과 부서진 방패가 꽂힌 풀밭, 무너진 수레 |
| watchtower | 무너진 망루 | 반쯤 무너진 돌 망루(멀리서도 보이는 표지), 까마귀 |
| brook | 개울가 | 얕은 개울(물 판), 돌다리, 갈대 |
| grove | 검은 숲 가장자리 | 마른 나무와 짙은 그늘, 쓰러진 거목 |
| foot | 언덕 발치 | 언덕으로 오르는 길머리, 돌 계단, 꺼진 화톳불 |

### 16.2 찾을 것

- **유품 상자** (`cache_1` … `cache_8`): 곳곳에 숨은 상자·자루·무덤 앞 꾸러미. E로 열면 조각(10~40). **한 번 찾으면 끝**(`Meta.field_found`에 남는다).
- **흩어진 조각** (`glint`): 풀숲에 희미하게 반짝이는 쇳조각. 자리 후보 16곳 중 판이 끝날 때마다 4곳이 새로 생긴다(`Meta.rng`). 다가가 E로 줍는다(2~5).
- **이야기 비석** (`stone_1` … `stone_6`): E로 읽는다(띠에 2~3줄). 읽은 것은 `Meta.lore_read`. 6개를 다 읽으면 조각 30 한 번.
- **짐승**(규칙 없음, 화면만): 까마귀(망루·옛 싸움터, 다가가면 날아오른다), 사슴 두세 마리(개울·숲가, 다가가면 달아난다). 꾸밈 랜덤.

### 16.3 신호와 파일 (16단계)

- 모양팀 B(들판)의 파일만:
  - `scripts/field/field_layout.gd` (`FieldLayout`, static const): 크기(칸), 곳(id → 칸 단위 Rect2 또는 다각형), 길의 점들, 마을 문·언덕 길머리 자리, 유품 상자 8곳·흩어진 조각 후보 16곳·비석 6곳(id → 칸 자리), 영주가 처음 서는 자리. **자리는 여기 하나에만** 둔다(기능팀은 읽기만).
  - `scripts/field/field_builder.gd` (`FieldBuilder`, static): `setup()`, `height(x, z)`(m), `build(parent, env) -> Dictionary` — 땅·길·개울·숲·망루·옛 싸움터·언덕 실루엣·소품을 짓고 `{"rects": Array[Rect2], "circles": Array}`(칸 단위, 영주가 못 들어가는 곳)를 돌려준다. 상자·비석·흩어진 조각의 모양은 `cache(parent, id)`, `stone(parent, id)`, `glint(parent)`(노드 돌려줌, 열림·사라짐 함수 포함).
  - `scripts/field/field_creatures.gd` (`FieldCreatures`, Node3D): 까마귀 떼·사슴을 짓고 `step(delta, lord_world)`로 혼자 움직인다(다가가면 날아오름·달아남, 소리 포함).
  - `scripts/field/field_fx.gd` (`FieldFx`): 상자 열 때(먼지, 낡은 천), 조각 주울 때(작은 반짝임 꺼짐), 비석 읽을 때(이끼 먼지, 희미한 빛), 개울 물결·날벌레·떠도는 꽃가루 같은 바람 꾸밈.
  - `scripts/debug/field_gallery.gd` + `scenes/debug/field_gallery.tscn`: 들판을 돌아다니며 보는 확인용(규칙 없이 WASD).
- 기능팀의 파일: `scenes/field/field.tscn`, `scripts/field/field.gd`(장면: Rules로 걷기, 막힘, 높이 따라 그리기, E, 곳 이름, 장면 바꾸기, `WebQuality.apply`), `scripts/core/`(Meta `field_found`, `lore_read`, `glints`), `data/field.tres`(보상·비석 글·곳 이름), `scripts/lobby/lobby.gd`(북문 → 들판), 테스트, 문서.

## 기능팀이 정한 것

15단계(2026-11-19):
- 자리(`lobby.gd`의 `@export`): 의뢰판 (21.5, 5.2), 수련장 마당 Rect2(24, 14.5, 5, 3.5)(서쪽 y 15.5~17에 틈, 허수아비 x=28, 검 걸이 (25.4, 14.9)), 상인 수레 (13.4, 9.7)와 상인 (14.7, 10.4). 마당 자리에 있던 죽은 나무와 건초 둘은 치웠다. 주민 자리는 `Lobby.VILLAGERS`.
- 모양은 기본 도형이다(`scripts/lobby/village_props.gd` 한 파일: 의뢰판·마당·수레·`villager`·고개 돌림·손짓·허수아비 흔들림). `EventArt`의 몸 짓기 도구를 빌렸고 아이콘 SVG와 갤러리 장면은 만들지 않았다(창은 글과 `UiKit`).
- 규칙: `Rules.yard`가 켜지면 낮에도 좌클릭이 먹고 `_step_yard`가 허수아비를 맡는다(`EnemyData.still`, `refill_after`: 안 맞으면 체력이 차고, 체력이 1 밑으로 안 내려가며, 넉백 없음, 처치·`run_stats`로 세지 않는다). 마을 Rules는 `yard = true`, 언덕은 꺼져 있다.
- `Rules.run_stats`는 `state_hash`에 들어간다. 이루었는지는 `Meta.record_run`이 `quest_count`로 보고 `{quest_done, quest_reward, quest_text}`를 돌려준다. 이루면 그 자리에 새 의뢰, 판이 끝날 때마다 안 맡은 것 하나를 `Meta.rng`로 바꾼다. 의뢰는 `min_best`(가장 높이 오른 구역)가 모자라면 안 붙고 종류(`kill_kind`, `goal`은 대상까지)가 겹치지 않게 붙는다.
- 상인: 좌판 3개는 판이 끝날 때 바뀌고(`refresh_stock`), 산 것은 `Meta.pack`에 있다가 `Rules`가 시작할 때 읽고 비운다(`_apply_pack`: 뽑기 표 +1, 숫돌은 처음 받는 검, 말린 빵은 최대 체력 +15와 가득 채움, 점쟁이 쪽지는 1구역 낮 조짐 참, 운 부적은 `luck()` ×1.2). 언덕 장면이 판을 만들면 바로 저장한다.
- 주민: `Meta.talk`은 조건이 맞는 줄 중 안 들은 것부터 최대 3줄을 한 번에 돌려주고(`heard`에 저장), 다 들었으면 처음 줄부터 다시 한다. 띠에서 E로 한 줄씩 넘기고, 멀어지면 끝난다.
- 검 걸이: 걸이 목록은 검집의 검 + 도감에서 찾은 모든 검(높은 등급부터)이고 맨손도 고른다. 고른 검(`Meta.yard_sword`, 저장 안 함)은 부러지지 않는 검으로 마을 Rules 칸 0에 쥔다.
- 저장: `quest_board`, `quest_active`, `stock`, `pack`, `heard`가 `hill_save.json`에 더해졌다. 없으면 기본값이라 옛 저장도 읽는다.
