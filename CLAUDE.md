# CLAUDE.md

이 저장소는 Godot 4.6 게임 「검의 언덕」(가제)이다. 이전 기획 「총성」과 「영지」는 접었고 git 기록에만 남아 있다. 기획은 [docs/GDD.md](docs/GDD.md)에 있고, 수치는 모두 HTML 시험판에서 옮긴 첫 값이라 테스트하며 바뀐다.

## 작업 방식

- docs/GDD.md "3. 앞으로의 계획"의 체크리스트를 위에서부터 한 번에 한 단계씩 진행한다. 단계를 마치면 그 줄을 `- [x]`로 바꾸고 "1. 지금까지 한 일"에 한 줄 적는다.
- 단계마다 커밋하고, 끝나면 무엇을 만들었는지와 사용자가 PC의 Godot에서 무엇을 확인하면 되는지 한국어로 짧게 정리한다.
- 사용자는 Godot 4.6과 GDScript를 쓰는 1인 개발자(학생)다. 답과 설명은 한국어로, 짧게 한다. 처음 여는 세션이면 docs/GDD.md의 "0. 인계 요약", "1. 지금까지 한 일", "3. 앞으로의 계획"부터 읽는다.
- 기획에 없는 시스템은 새로 만들지 않는다. 애매하면 가장 단순한 쪽으로 만들고 정리에 적는다. GDD "2.14 정하지 않은 것"의 항목은 사용자에게 묻기 전에는 바꾸지 않는다.
- 큰 일은 두 팀으로 나눠 이 순서로 한다: **모양팀**(아트·모션·이펙트: 모양, 아이콘, 움직임, 효과, 확인용 갤러리) → **기능팀**(규칙, 데이터, 테스트, 화면 연결). 2026-11-18까지는 네 팀(아트 → 모션 → 이펙트 → 기능)이었고, 사용자가 빠르게 하려고 합쳤다. 서로 겹치지 않는 단계의 모양팀은 동시에 돌려도 된다. 팀마다 Claude Code 대표 모델(Opus) 에이전트 하나가 맡고, 자기 파일만 고친다. 팀 사이의 약속(id, 신호, 자료 모양)은 시작 전에 `docs/`의 설계서에 쓴다(예: `docs/attacks.md`). 진행 상황은 팀 현황판 `docs/team_board.html`이고, `python3 docs/board.py` 한 줄로 git 기록(`모양팀: N단계`, `기능팀: N단계` 커밋)과 GDD 체크리스트에서 다시 채운다(손으로 고치지 않는다). 다시 올리는 것은 단계가 끝날 때만.
- `prototype/`의 HTML 시험판은 참고용이다. 규칙과 수치는 거기서 가져오되 코드는 GDScript로 새로 쓴다. 시험판 파일은 고치지 않는다. 규칙 코드는 `prototype/game_reference.js`에 있다.

## 기술 규칙

- Godot 4.6, GDScript만 쓴다. 타입을 붙인 GDScript로 쓴다.
- 1칸 = 2m. 싸움터는 34 × 22칸(`RunData.arena_size`)이다. 규칙의 위치는 칸 단위 실수(Vector2)이고, 월드 좌표 변환은 `Grid`의 함수(`cells_to_world`, `world_to_cells` 등)로만 한다. 시험판 수치는 칸 단위라 미터로는 2배다(영주 4.3칸/초 = 8.6m/초).
- 수치는 코드에 박지 않는다. 표 한 줄을 리소스 하나에 담는다.
  - `data/swords/001.tres` … `300.tres` (SwordData), `data/inscriptions/*.tres` (InscriptionData, 등급별 수치 6개)
  - `data/forms/*.tres` (FormData: 단검, 장검, 대검, 세검), `data/unarmed.tres` (맨손)
  - `data/grades.tres` (GradeTable), `data/enemies/*.tres` (EnemyData), `data/lord.tres` (LordData), `data/run.tres` (RunData: 구역, 낮의 뽑기와 제단, 밤의 적과 정예)
  - `data/meta.tres` (MetaData: 조각, 대장간 검집, 성소 축복), `data/powers.tres` (PowerTable: 각인 규칙과 고유 능력의 정해진 수치)
  - `data/attacks/moves/<id>.tres` (MoveData: 좌클릭 기본 동작 20개), `data/attacks/patterns/000.tres` … `150.tres` (PatternData: 공격 방식, 000은 맨손). 001~150과 검 표의 `attack`은 `scripts/debug/build_attacks.gd`가 만든다(손으로 고치지 않는다)
- 게임 규칙(뽑기, 판정, 체력, 내구, 적, 구역)은 화면 코드와 섞지 않는다. `scripts/core/` 아래에 노드에 기대지 않는 RefCounted 클래스로 쓰고(`Rules`가 중심), 화면은 신호와 상태를 받아 그린다. 나중에 서버 판정으로 옮기기 쉽게 다음을 지킨다.
  - 규칙은 고정 틱(30Hz)으로 돈다. `_physics_process`에서 누적 시간을 틱으로 쪼갠다.
  - 랜덤은 전부 시드가 있는 `RandomNumberGenerator` 하나(`Rules.rng`)를 거친다. 전역 `randf()`, `randi()`는 쓰지 않는다. 같은 시드와 같은 입력이면 결과가 같아야 한다(`Rules.state_hash()`로 테스트한다). 화면 흔들림 같은 꾸밈용 랜덤은 화면 쪽에 따로 둔다.
  - 영주의 입력은 틱마다 `LordInput` 하나로 넘긴다. 밤 시작(`start_night`), 고르기(`choose`), 제단(`use_altar`)은 틱 사이에 부르는 함수다.
- 각인 36종과 고유 능력은 `Powers`(scripts/core/powers.gd)가 맡는다. Rules는 휘두르기·베기·쓰러뜨림·맞기·돌진·뽑기·부러짐 자리에서 부르고, 정해진 수치는 `data/powers.tres`(PowerTable)에 있다. 고유 능력은 검 이름으로 찾고, 넣은 것은 `Powers.READY`와 검 표의 `unique_ready`를 같이 켠다(테스트가 둘이 같은지 본다). 화면에 그릴 일은 `Rules.effect` 신호로 보내고 `PowerFx`가 그린다.
- 좌클릭은 `Moves`(scripts/core/moves.gd)가 맡는다: 쥔 검의 PatternData에서 다음 MoveData를 골라 판정·늦게 터지는 것·날아가는 것(`Rules.projectiles`)·반격 자세·속성·메아리를 돌리고, 맞힐 때마다 Powers의 자리를 예전 베기와 같은 순서로 부른다. 화면에는 `move_started`·`move_area`·`projectile_spawned`·`projectile_ended` 신호(docs/attacks.md 4절)로 알리고, `MoveFx`(scripts/world/move_fx.gd, 판정 모양·효과)와 `MoveMotion`(scripts/lord/move_motion.gd, 영주의 몸, LordView가 부른다)이 그린다. 우클릭 갈고리는 방식에 갈고리 베기가 든 검만.
- 새 적 5종(활잡이, 방패병, 돌격병, 자폭병, 부르는 자, docs/content.md 11단계)의 행동은 `Foes`(scripts/core/foes.gd)가 맡고 수치는 `EnemyData`의 행동 칸이다. 화면에는 `Rules.enemy_act(e, act, info)`와 `enemy_projectile_spawned/ended`(화살은 `Rules.enemy_projectiles`)로 알리고, 몸은 `EnemyArt`(짓기)·`EnemyMotion`(움직임, EnemyView가 부른다), 효과는 `EnemyFx`(main이 잇는다)가 그린다.
- 적이 영주를 때리려면 공격 표가 있어야 한다(`Tokens`, scripts/core/tokens.gd, docs/attack_tokens.md). 표 없는 적은 둘레를 돈다. 표 수와 표 값은 `RunData`(밤: 공격 표)와 `EnemyData.token_cost`.
- 밤마다 목표(`Rules.goal`: survive·defend·hunt·siege)와 구역 규칙(`Rules.rule`: 없음·fog·embers·graves)이 하나씩 붙는다(docs/content.md 12단계). 다음 밤 것은 낮에 `Rules.next_goal/next_rule`로 정하고 `set_next_night`로 바꾼다. 수치는 `RunData`(밤: 목표와 구역 규칙), 화면은 `NightArt`·`NightFx`(main이 잇는다)와 HUD의 위 가운데 진행 줄(`Hud.set_goal`).
- 새벽에는 갈림길(13단계): `Rules.path_open` 동안 시간이 멈추고, 지도 창(`PathMap`, `assets/ui/map/*.svg`)에서 고르면 `choose_path`가 다음 밤과 보상을 정하고 낮을 연다. 2구역부터 낮마다 사건 하나(`Rules.event`, `DayEvent`: 대장장이·저주받은 손잡이·순례자·점쟁이)가 서고 E로 한 번 쓴다. 수치는 `RunData`(갈림길과 낮 사건), 화면은 `EventArt`·`EventFx`(main이 잇는다).
- 뽑기 손맛(14단계): 버팀마다 창(`pull_window`, k × `pull_step` ± 0.08초)이 열리고 뽑는 동안의 E·좌클릭(`LordInput.pull_press`)을 버팀마다 한 번 판정한다(`pull_good`·`pull_perfect`·`pull_miss`). 손잡이 조짐은 `Hilt.omen`(운 배수)·`shown_omen`(75% 맞음), 점쟁이가 `revealed`. 수치는 `RunData`(낮: 뽑기 손맛), 화면은 `OmenArt`(HiltView)·`PullMotion`(LordView)·`PullTimingFx`(main)다.
- 마을 컨텐츠(15단계, docs/village.md): 의뢰판·상인·주민·수련장의 수치와 대사는 `data/village.tres`(VillageData), 의뢰·상인·말은 `Meta`(`quest_board`, `take_quest`, `buy`/`pack`, `talk`)가 맡고 `Rules.run_stats`를 판 동안 센다(`record_run`이 의뢰 보상). 허수아비는 `EnemyData.still`인 규칙의 적이고 `Rules.yard`가 켜진 마을에서만 낮에 좌클릭이 먹는다. 모양은 `VillageProps`, 창은 `LobbyHud`, 연결은 `lobby.gd`.
- 들판(16단계, docs/village.md, 크기 230×110칸: 20·28단계에서 동쪽으로 넓힘): 마을 북문 밖 `scenes/field/field.tscn`(싸움 없음). 동쪽 새 곳 다섯(20·28단계, docs/outside.md): 무너진 성채 `keep`(`FieldLayout.KEEP_WALLS`·`KEEP_TOWER`, 그린 성벽이 곧 막힘)와 안개 늪 `marsh`(들어서면 `field.gd`가 환경 안개만 `MARSH_FOG_*`로 짙게, 규칙과 무관), 버려진 채석장 `quarry`·불탄 마을 `hamlet`·까마귀 고개 `pass`(벽·벼랑·비계 기둥·울타리·우물 표는 `FieldLayout`, 그린 것이 곧 막힘, 구덩이·오르막은 `FieldBuilder.new_land`). 자리와 보상은 `FieldLayout`, 땅·꾸밈은 `FieldBuilder`(높이 `walk_height`), 짐승은 `FieldCreatures`, 장면은 `field.gd`(Rules로 걷고 `Grid.size`를 들판 크기로). 상자·조각·비석은 `Meta.field_open/take_glint/read_stone`.
- 들판 싸움(17단계, docs/outside.md): 마을 북문 E → 검 고르기(`LobbyHud.open_field_pick`, 걸이와 같은 목록) → `Meta.carry_sword`(static, 저장 안 함)가 들판으로 넘어가 `Meta.unbreakable_sword`로 칸 0에 쥔다. `Rules.field`(`start_field`)는 낮밤·구역 시간이 없고 영주가 늘 "밤"이며, 적은 `spawn_pack`/`spawn_packs`로 `FieldLayout.PACKS` 자리에 둔다(`Enemy.pack/home`, `Rules.packs`: 덤빔·돌아감 상태). 서성임·덤빔·돌아감·보상 수치는 `FieldLayout` 상수, 무리 상태는 `state_hash`에 든다. 보상은 `Meta.field_kill`(1)·`field_clear`(5~10, `Meta.rng`)와 `packs_cleared`(`record_run`이 비운다). 쓰러지면 `Meta.wake_at_gate`로 북문 앞에서 깬다. 화면은 `field.gd`가 EnemyView·MoveFx·EnemyFx·HitFx를 main처럼 잇고 높이는 `walk_height`.
- 들판 시계(29단계, docs/outside.md): `Rules.start_field(clock)`에 0 이상을 주면 `field_clock`(초)이 틱마다 `dt`씩 흘러(`FieldLayout.FIELD_DAY` 240 + `FIELD_NIGHT` 150초마다 0으로, 0은 아침) 낮 → 밤이면 `field_dusk`(밤 무리 `FieldLayout.NIGHT_PACKS`가 서고), 밤 → 낮이면 `field_dawn`(덤비는 중이 아닌 밤 무리가 사라지고 쓰러뜨린 낮 무리가 `spawn_packs`로 다시 선다)을 낸다. 밤에는 덤빔 `FIELD_NIGHT_AGGRO` 14칸, 무리가 덤빌 때 세기 구역 +`FIELD_NIGHT_ZONE`(구역 표 길이 안으로 자름). 시계는 `state_hash`에 들고 지하 무덤은 시계를 안 켠다. `field.gd`가 `Meta.field_clock`에서 이어 가고 떠날 때 저장하며(들판 밖에서는 안 흐름), `field_dawn`에서 `Meta.packs_cleared`를 비운다. 화면은 `FieldLayout.night_amount(시계)`로 해·하늘·환경광·안개·영주 횃불을 섞는다(수치는 `FieldLayout.FIELD_*`).
- 들판 보스(18단계, docs/outside.md): 옛 싸움터의 무덤 기사(`data/enemies/10_grave_knight.tres`, `FieldLayout.BOSS_*`)는 `Rules.spawn_field_boss`/`field_boss`·`field_boss_state`로 무리와 따로 센다(깨어남 8칸·돌아감 14칸, 신호 `field_boss_woke`·`field_boss_returned`·`field_boss_slain`). 행동(휘두르기·돌진·부르기·빨라짐)은 `Foes._knight`와 `EnemyData`의 무덤 기사 칸. 보상은 `Meta.boss_defeat`(조각 80/30, `charm`을 `Meta.pack`에), `Meta.boss_down`(`record_run`이 비운다)·`boss_first`(저장). 화면은 EnemyView(`model_scale`)·EnemyFx(`swing_wind` 부채꼴, `height_of`)·`LobbyHud.set_boss`.
- 지하 무덤(19단계, docs/outside.md): 들판 검은 숲 가장자리 입구(`FieldLayout.CRYPT_*`)에서 E → `scenes/crypt/crypt.tscn`. 방·문·관·무리 자리와 수치는 `CryptLayout`(static const) 한 곳, 규칙 쪽은 `CryptRun`(방에 들어서면 `Rules.spawn_pack`/`spawn_field_boss`로 세우고, 쓰러뜨린 방을 `Meta.crypt_clear`에 적는다. 문이 닫혔는지는 영주가 든 방과 `Rules.packs`·`field_boss_state`에서 읽고, 막힘은 `CryptLayout.push_in`). 마지막 방은 무덤 주인(`crypt_lord`, `Foes._knight` 공유). 보상은 `Meta.crypt_open`(관 10~25, 큰 관 60+운 부적), `crypt_cleared`·`crypt_opened`(저장, `record_run`이 비운다). 화면은 `CryptBuilder`(돌판 문, 낮은 벽, 횃불)와 `crypt.gd`, 나오거나 쓰러지면 `Meta.wake_at_crypt`로 입구 앞.
- 1대1 결투(21단계, docs/duel.md): `Rules.lords`(0 = `lord`, 비결투 모드는 하나)와 `start_duel`·`step_duel(입력1, 입력2)`. 영주마다 `DuelSeat`(검 칸·`Moves`·`Powers`·날아가는 것)를 틱마다 `Rules._seat`으로 갈아 끼워 돌리고, 상대 영주는 그림자 적(`Enemy.seat`)이라 `Moves`가 그대로 맞힌다(`Rules.hurt` → `_duel_hurt`). 각인과 고유 능력은 `Powers.off`로 끈다. 수치는 `data/duel.tres`(DuelData), 입력은 `LordInput.to_bytes/from_bytes`(22단계), 기록은 `Meta.duel_wins/duel_losses`. 화면은 마을 광장 결투 말뚝(`VillageProps.duel_post`, `LobbyHud.open_duel`) → `scenes/duel/duel.tscn`(`duel.gd`, `DuelHud`, `LordView.seat`). 1P는 키보드·마우스, 2P는 게임패드 0번.
- 온라인 결투(22단계, docs/duel.md, GD-Sync 무료판): 입력만 주고받는 락스텝. `Lockstep`(scripts/net/lockstep.gd, 노드 없음)이 `NetLink`(전송 인터페이스: `LoopLink` 시험용, `GdSyncLink` GD-Sync)만 알고, 내 입력을 tick + `DuelData.net_delay`에 넣고 겹쳐 보내며 두 입력이 다 있는 틱만 `Rules.step_duel`로 돌린다(없으면 멈춤, 몇 틱마다 `state_hash`를 맞춰 desync를 알림). 시작 정보(시드, 두 검)는 `DuelSetup`, 마을 창에서 결투 장면까지는 `OnlineDuel`. 온라인 규칙 코드는 한 줄도 `Rules`를 바꾸지 않는다. 플러그인은 `addons/GD-Sync`(소스 그대로)이고 autoload로 두지 않는다(`GdSyncLink`가 처음 쓸 때 `/root/GDSync`로 올림). 키는 git에 올리지 않고 `user://gdsync_keys.cfg`에서 읽으며 없으면 "GD-Sync 키가 없습니다"만 알린다.
- 판 사이에 남는 것(조각, 검집, 축복, 도감, 기록)은 `Meta`(scripts/core/meta.gd)가 `user://hill_save.json`에 저장한다. 대장간·성소의 강화 확률은 판의 규칙과 따로 `Meta.rng`를 쓴다. `Rules`는 시작할 때 Meta를 받아 축복과 검집의 검을 반영하고, 판이 끝나면 `Meta.record_run`이 조각을 센다.
- 시작 화면(27단계)은 `scenes/title/title.tscn`(시작 → 마을, 설정, 끝내기)이다. 설정은 `GameSettings`(static, `user://settings.cfg`: 소리 크기·마우스 감도 배수·키의 첫 입력)와 창 `SettingsPanel`(마을·언덕에서 F10, 트리를 멈춘다). 장면은 `GameSettings.ensure()`로 처음 한 번 적용하고(camera_rig·title), 감도는 `camera_rig`가 `GameSettings.mouse()`를 곱한다. Windows 내보내기 설정은 `export_presets.cfg`의 "Windows Desktop"(build/windows/geom_hill.exe).
- 그 다음 장면은 마을(`scenes/lobby/lobby.tscn`)이고 언덕은 `scenes/world/main.tscn`이다. 장면을 바꿀 때는 `change_scene_to_file`을 쓰고, 둘 다 저장 파일에서 Meta를 다시 읽는다(자동 로드 없음).
- 카메라(`camera_rig.gd`)는 3인칭이 기본이고 V로 쿼터뷰와 바꾼다. 3인칭에서는 이동 입력을 카메라 기준으로 돌려(`relative_move`) 넘기고, 카메라가 보는 쪽을 겨눈다. 모션 블러는 카메라에 붙은 화면 판(`motion_blur.gdshader`)이고, 가까운 것(`blur_mask_near` m 안)은 번지지 않는다. `motion_blur`를 0으로 하면 끈다.
- 영주와 적의 움직임과 부딪힘은 물리 엔진이 아니라 규칙이 계산한다. 화면 노드는 Node3D이고, 규칙의 위치(prev_pos → pos)를 틱 사이로 이어 그린다. 언덕 싸움터에는 장애물이 없어서 적은 영주에게 곧장 온다. 들판·무덤은 37단계부터 장면이 막힘 표를 `Rules.set_blockers`로 넘기고(`scripts/core/nav.gd`: 0.5칸 격자 두 장, 영주 쪽 흐름장 6틱마다 45칸), 곧은 선이 막혔을 때만 흐름장을 따라 돌아온다. 틱 끝에 적도 `Blockers.push_out`으로 막힘 밖으로 민다.
- 위치가 있는 소리(타격, 휘두름, 뽑기, 부러짐)는 AudioStreamPlayer3D(`Sfx`)로 낸다. 종소리, 올라가는 삐 소리, 위로 쓸어 올리는 소리는 쓰지 않는다(사용자가 싫어한다).
- 규칙 단위 테스트를 `tests/`에 둔다. 애드온 없이 `extends SceneTree` 스크립트로 쓰고 `godot --headless --path . -s tests/run_all.gd`로 돌린다. 규칙을 바꾸면 테스트도 같이 고친다.
- GDScript 람다는 바깥 지역 변수를 값으로 가져간다. 신호를 세는 테스트는 `Array`에 넣어 센다.

### 충돌 레이어

프로젝트 설정에 이름이 붙어 있다. 지금은 쓰지 않는다(규칙이 판정한다). 화면 쪽에서 마우스로 고르기나 시각 효과에 쓸 때 이 뜻을 지킨다.

| 번호 | 이름 | 무엇 |
| --- | --- | --- |
| 1 | world | 바닥, 언덕 |
| 2 | lord | 영주 |
| 3 | enemy | 적 |
| 4 | structure | (비어 있음) |
| 5 | nature | 나무, 바위 |
| 6 | pick | 마우스로 땅을 고를 때 쓰는 판 |

- 투사체가 생기면 물리로 맞히지 않고 규칙이 목표를 따라가 맞힌다.

## 에셋

- 에셋은 `assets/` 아래에 둔다. AI 생성 에셋은 쓰지 않는다.
- 에셋 파일은 사용자가 PC에서 받아 넣는다. 화풍은 어두운 사실풍이다(GDD 2.14). 모델이 아직 없는 자리는 기본 도형으로 자리를 채우고, 바꿔 끼우기 쉽게 한 곳에 모은다(`HiltView._build`, `EnemyView._build_*`, `AltarView`, `scenes/lord/lord_model.tscn`과 `LordCharacter`, `HillBuilder`, `lobby._build_*`와 `VillageBuilder`). 마을의 집·소품은 VillageBuilder가 기본 도형과 질감으로 짓는다. 언덕의 땅·하늘·바위·꽂힌 검·먼 숲은 `HillBuilder`가 짓고(땅 셰이더 `terrain.gdshader`, 하늘 `hill_sky.gdshader`), Poly Haven(CC0) 질감·모델·HDRI를 저장소에 넣어 쓴다(`assets/hill/`, `assets/nature/`, `assets/sky/`). 나무와 돌은 마을도 HillBuilder의 것을 같이 쓴다. 적: 망령은 해진 망토 셰이더(`wraith_cloak.gdshader`), 늑대는 `CreatureMesh`로 짓고 다리를 코드로 움직인다. 거인과 언덕지기는 기사 모델(`LordCharacter`)을 어둡게 칠해 키우고, 없으면 도형이다. 24단계부터 적마다 제 Mixamo 모델(`assets/characters/enemies/<적 id>.fbx`, `LordCharacter.enemy_path`·`char_path`)이 있으면 그것을 먼저 쓰고 영주 동작을 같이 쓴다(늑대·허수아비 빼고, 방패병은 `EnemyArt.build_shield`에서). 칼은 모두 `SwordModel`(형태·등급·칼 번호로 모양이 정해진다)로 그리고, 베기 궤적과 베기 빛은 `SlashFx`다.
- 글꼴은 Noto Serif KR을 쓰는 글자만 남겨 넣었다(`assets/ui/fonts/`). 테마 `assets/ui/theme.tres`는 손으로 고치지 않고 `scripts/debug/build_theme.gd`를 고쳐 다시 만든다. 굵기는 FontVariation에 숫자 태그(2003265652 = wght)로 준다.
- 화면 글자는 엘든 링식이다. 세계(3D)에 글자를 띄우지 않는다(피해 숫자만 예외). 다가갔을 때 안내와 알림은 `Band`, 새 곳의 이름은 `AreaTitle`, 창은 `UiKit`(모서리 없는 검은 판, 놋쇠빛 줄, 따뜻한 글자색). 표에 드문 글자가 새로 생기면 `assets/ui/fonts/README.md`대로 다시 만든다.
- 에셋을 넣으면 `CREDITS.md`에 이름, 작가, 라이선스, 링크를 적는다.
- 소리(`assets/sound/<이름>/*.wav`)도 약관 문구가 없는 팩이라 git에 올리지 않는다(`assets/sound/README.md`). 파일이 없으면 `Sfx`가 코드로 만든 소리로 대신한다.
- Mixamo 캐릭터와 동작(`assets/characters/`)은 원본을 다시 나눠 주면 안 되어 git에 올리지 않는다(.gitignore). 무엇을 어디에 두는지는 `assets/characters/README.md`에 적는다. 파일이 없으면 기본 도형으로 돌아가야 한다(`LordCharacter.available()`).
- 뽑기 연출은 `PullFx`다: 당기는 동안 땅이 갈라지고, 뽑히면 등급만큼 먼지·불똥·불씨·빛·충격파가 커지고 뽑힌 칼이 땅에서 솟아 떠 있다. 전설 이상은 사용자가 녹화한 영상(`assets/video/grade_<등급>.ogv`, Ogg Theora)이 있으면 화면 가득 튼다(`assets/video/README.md`). 연출 중에는 글자를 띄우지 않고, 끝난 뒤 이름 알림과 고르기 창을 연다.

## 확인

- 클라우드에서는 Godot 에디터로 직접 플레이할 수 없다. Godot 실행 파일을 받을 수 있으면 헤드리스로 프로젝트를 열어 스크립트 오류와 `tests/`를 확인하고, Xvfb와 gl_compatibility로 화면을 찍어 본다. 받을 수 없으면 그 사실을 정리에 적는다.
- 손맛(이동, 베기, 넉백, 돌진, 히트스톱)은 사용자가 PC에서 맞춘다. 수치를 리소스로 빼 두는 이유다.
- 웹판: `python3 docs/web_build.py <godot> <폴더>`가 `export_presets.cfg`의 "Web"(스레드 없음)으로 내보내고, 100MB가 넘는 index.pck를 90MB 조각으로 잘라 index.html이 이어 붙이게 고친다. 그 폴더를 `gh-pages` 가지로 올리면 https://razer-rgxx.github.io/chongseong/ 에서 돈다(웨일북용). 사운드 팩은 공개 웹판에서도 뺀다. 웹판에서만 `WebQuality`(scripts/world/web_quality.gd, 마을·언덕 _ready 끝)가 그래픽을 가볍게 한다(3D 해상도 0.6, 해 그림자 한 겹, 작은 빛 그림자·번짐 판·빛 번짐 끔, 풀 30%).
- 규칙이 시험판과 같게 도는지 헷갈리면 `prototype/geom_hill.html`을 브라우저로 열어 본다. ` 키로 관리 패널이 열린다.

## 폴더 구조

```
project.godot
scenes/   lobby/ (마을, 시작 장면), world/ (언덕), field/ (들판), crypt/ (지하 무덤), duel/ (결투), lord/, debug/
scripts/  core/ (규칙, Meta), core/data/ (표의 Resource 클래스), lobby/, world/, field/, crypt/, duel/, net/ (온라인 락스텝·전송), lord/, enemies/, ui/, debug/
data/     swords/, inscriptions/, forms/, enemies/, attacks/ (moves/, patterns/), grades.tres, lord.tres, run.tres, unarmed.tres, meta.tres, powers.tres, duel.tres
assets/   characters/, nature/, ui/, video/, sound/
addons/   GD-Sync/ (온라인 플러그인, 소스 그대로)
tests/
prototype/  HTML 시험판 (고치지 않는다)
```
