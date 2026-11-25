# 총 든 낯선 사람 (2026-11-25)

들판에 총을 든 낯선 사람이 가끔 선다. 이 시대에 없는 물건을 든 사람이 「검의 언덕」 이야기 위에 다른 시간을 얹는다. 1~3단계를 만들었고 나머지는 뒤에 한다.

## 약속
- 규칙(`Stranger`, scripts/core/stranger.gd)은 `Rules.rng`만 쓴다. 나타남은 들판에 들어올 때와 새벽·해질녘에 한 번씩 굴린다. 한 번 들판에 있는 동안 하나만 나타난다. 폭풍에는 안 나타난다.
- 자리는 `FieldLayout.STRANGER_SPOTS`. 영주에게서 24칸 이상 먼 자리만 뽑는다.
- 저장은 `Meta.stranger_seen`(만난 횟수), `Meta.stranger_done`(다섯 번째 만남을 마침), `Meta.stranger_drop`(떨군 물건의 자리 번호, -1이면 없음).
- 화면은 `StrangerView`(몸, 총, 번쩍임, 흩어져 사라짐), `SwordGlitch`·`GlitchOverlay`(검이 바뀌는 글리치), 연결은 `field.gd`. 세계에 글자는 띄우지 않고 대사는 Band(`LobbyHud.say`)로.
- 관리 명령 `낯선이 N`은 만난 횟수를 N으로 맞추고 바로 한 명을 세운다(0이면 모두 처음으로).

## 계획
1. [만듦] 목격. 긴 외투와 후드, 총 모양의 긴 그림자. 10칸 안에 가면 짧은 말("...?" 등), 돌아서서 지지직거리며 사라진다. 싸울 수 없고 길을 막지 않는다. 만날 때마다 `stranger_seen` +1.
2. [만듦] 다섯 번째 만남. `stranger_seen >= 4`에서 또 나타나면 한 줄을 말하고 총을 쏜다(번쩍임, 날카로운 총성, 작은 피해. 죽지는 않는다: 체력 1은 남긴다). 사라지고 차가운 푸른빛의 낯선 물건을 떨군다. E로 줍으면 쥔 검이 글리치로 흔들리다 「사이버 카타나」(311)로 바뀐다. 한 번만(`stranger_done`).
3. [만듦] 작은 녹슨 미래 구역. 아래 "3단계" 절.
4. [만듦] 이야기와 타임트래블러. 아래 "4단계" 절.
5. [뒤에] 과거·판타지 시대.

## 정한 것
- 같은 검은 같은 자료를 두고, 미래 모습과 능력 변형은 나중에 얹는다. 새 검 300자루를 만들지 않는다.
- 사이버 카타나는 오픈월드 한정 검(`field_only`) 311. 고유 능력은 없다.

## 3단계: 녹슨 미래 구역 (2026-11-25)
- **가는 길:** `Meta.rift_open()`(= `stranger_done`)이면 들판의 `FutureLayout.RIFT_FIELD`(낯선 사람이 처음 서던 자리 곁)에 흐릿한 틈(`FutureRift`)이 선다. E → `GlitchOverlay`가 0.9초 오르고 `scenes/future/future.tscn`으로(`SceneLoader`). 미래 안 `EXIT_AT`의 같은 틈에서 E → 글리치 → 들판 틈 앞에서 깬다(`Meta.wake_at_rift`). 쓰러지면 쥔 검을 들판 틈 앞에 떨군다(무덤과 같다).
- **모양:** 80×60칸 폐허 도시 한 블록. 창틀 격자 질감(코드로 그린 작은 이미지, 삼면 투영)의 탑 일곱(셋은 윗부분이 무너진 모양), 서 있는 고가와 무너져 누운 상판, 녹슨 자동차 14대(MultiMesh), 웅덩이, 글자 없는 네온 8장(깜빡임, 곁에 작은 빛 셋만), 쉬지 않는 비(`WeatherFx` rain 재사용). 가라앉은 차가운 파랑에 보라 조금. 작은 소품은 보이는 거리를 걸고 `WebQuality.apply`를 부른다. 막힘은 `FutureLayout.blockers()`(탑·기둥은 키 큼, 자동차·누운 상판은 낮아서 뛰어넘음)를 `Rules.set_blockers`에 넘긴다.
- **규칙:** 들판 모드(`Rules.start_field`) + `Grid.size = FutureLayout.SIZE`. 무리 셋(`FutureLayout.PACKS`: 드론 4 / 사수 2 + 드론 2 / 사수 3 + 드론 2)은 `spawn_pack(id, def)`. 새 적 `data/enemies/20_drone.tres`(늑대 행동, 빠름), `21_husk.tres`(활잡이 행동)는 `EnemyData.future = true`라 `EnemyView`가 `FutureEnemyArt`의 도형 몸(무딘 쇠, 차가운 눈 하나)으로 짓는다.
- **미래의 능력(`Rules.era == &"future"`):** 쥔 검이 무엇이든 사거리 ×`FutureLayout.REACH_MULT`(1.15, `Powers.stats`), 마무리 베기 뒤에 이미 있는 메아리(`Moves`의 `echo_next`, `LordData.echo_delay`·`echo_damage`)가 한 번 더 친다. 메아리 지연은 새로 만들지 않고 기존 값을 쓴다(정한 것: 0.2초 대신 기존 값). 베기 빛(`LordView.set_slash_override`)과 동작 빛(`MoveFx.tint`)은 차가운 푸른빛(`FutureLayout.TRAIL`). `era`는 `state_hash`에 든다.
- **여기서만:** 단말(E, `Meta.future_terminal`)은 다음 언덕 판 시작에 조짐 쪽지(`Meta.pack`의 `note`, 마을 물건 쪽지와 같은 것)를 건넨다(이미 있으면 겹치지 않는다. 간단하게 판마다 다시 받을 수 있다). 녹슨 함(`Meta.future_cache`, `field_found["future_cache"]`)은 조각 90개를 한 번만 준다.
- **관리 명령:** `미래`는 낯선 사람 이야기를 마친 것으로 하고(사이버 카타나 도감) 들판이면 바로 미래 구역으로 간다.
- **정한 것:** 새 검을 만들지 않는다. 시대 능력은 규칙 한 곳(`era`)만 본다. 밤·시계·날씨 규칙은 안 켠다(비는 보기만).

## 4단계: 이야기와 타임트래블러 (2026-11-25)
- **이야기(띠·단말 글·낯선 사람 말로만):** 낯선 사람은 이 시대로 숨어든 무언가를 쫓는 미래의 병사고, 언덕의 검은 시간에 박힌 닻이다(`Story`의 글). 진행 `Meta.story()`: 0 처음, 1 조각 있음, 2 조각 셋, 3 금고를 엶, 4 장치를 받음.
  - (a) 미래 구역에 자료 조각 셋(`Story.SHARDS`, 도는 푸른 결정, E로 줍기, `Meta.story_shards` 저장). 줍을 때마다 띠에 글 한 토막.
  - (b) 남서쪽 봉인 금고 단말(`Story.VAULT_AT`, E): 조각이 셋이 아니면 "n/3" 알림, 셋이면 `Meta.open_vault`로 열리고 금고지기가 깨어난다(`vault_open` 저장).
  - (c) 금고지기(`data/enemies/22_guardian.tres`): `kind = grave_knight`라 `Foes._knight`를 그대로 쓰고 `future = true`라 `FutureEnemyArt`의 사수 몸을 2.4배로 키운 모양(정한 것: 새 몸을 만들지 않았다). `Rules.spawn_field_boss`로 서서 쓰러지면 낯선 사람이 `Story.FINAL_AT`에 서서 말하고 `Meta.guardian_slain`이 `time_traveller`를 한 번만 준다(미래에서 쓰러졌다 되살아나도 금고는 열린 채, 장치를 받기 전이면 금고지기가 다시 선다).
- **시대 고르기:** `TimeUi`(scripts/ui/time_ui.gd). 장치가 있으면 오른쪽 아래에 놋쇠빛 "시대 · 현재/미래" 작은 글자. 들판과 미래 구역에서 T → 작은 창. 건너는 길은 틈과 같은 글리치(들판 `_enter_rift`, 미래 `_leave`)라 틈이 없어도 된다. `TimeTravel.in_combat`(깨어난 보스, 덤비는 무리, 14칸 안의 산 적. 허수아비 빼고)이면 창이 안 열리고 고른 뒤에도 다시 본다. 정한 것: 시대는 장면(들판=현재, 미래 구역=미래)이 곧 시대고 따로 저장하지 않는다.
- **미래에서만 하는 일 둘째, 시간 고정:** `Story.TIME_LOCK_AT` 단말(E)에서 조각 `Story.TIME_LOCK_COST`(60)로 `Meta.time_lock`을 사면 다음 언덕 판 시작(`Rules._apply_pack`)에 첫 손잡이의 조짐(`omen`·`shown_omen`)이 3이 되고 곧 꺼진다. 이미 사 두었으면 또 못 산다(조각을 안 받는다). 정한 것: 어느 손잡이인지는 가장 단순하게 첫 번째.
- **관리 명령:** `시대 현재|미래`(들판·미래 구역에서만, 장치 없이도 건넌다. `시대 미래`는 낯선 사람 이야기를 마친 것으로 한다), `이야기 n`(0~4, 0은 처음부터, 2는 조각 셋, 3은 금고 열림, 4는 장치까지. 1 이상이면 낯선 사람 이야기도 마친 것).
- **테스트:** `tests/story_tests.gd`(조각 저장, 조각 셋이어야 금고, 금고지기가 장치를 한 번만, 싸움 중 시대 막힘, 시간 고정이 한 번만 쓰임, 관리 명령).
