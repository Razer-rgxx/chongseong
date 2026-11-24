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
4. [뒤에] 이야기와 시간 여행자. 낯선 사람의 정체와 두 시대를 오가는 길.
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
