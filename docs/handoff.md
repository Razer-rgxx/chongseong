# 인계서 (2026-11-19 오후)

다음 Claude에게. 사용자는 한국어로 짧게 답받기를 원하는 1인 개발자(학생)다. 먼저 `CLAUDE.md`(규칙 전부)와 `docs/GDD.md`의 0·1·3절을 읽는다.

## 어디에 있나

- 저장소: https://github.com/Razer-rgxx/chongseong , 가지 **geom-hill** (PR #4). main이 아니다.
- 사용자 PC: `C:\Users\user\Documents\chongseong` (원격 없음). 받는 법(Godot 끄고 한 줄씩):
  ```
  cd C:\Users\user\Documents\chongseong
  git stash
  git pull https://github.com/Razer-rgxx/chongseong.git geom-hill
  ```
- 웹판(웨일북용): https://razer-rgxx.github.io/chongseong/ — `gh-pages` 가지. 다시 만들기: `python3 docs/web_build.py <godot> <폴더>` 후 그 폴더를 gh-pages로 강제 푸시.
- 확인: Godot 4.6.1 리눅스 실행 파일로 `--headless --path . -s tests/run_all.gd` (지금 **895 통과, 0 실패**). 화면은 Xvfb + `--rendering-driver opengl3 --rendering-method gl_compatibility`.

## 지금까지 (끝난 것)

1~4단계(표·규칙·화면·마을과 3인칭), 6~21단계가 끝났다. 5단계(손맛 맞추기)는 사용자가 PC에서 할 일로 남아 있다.

- 9: 좌클릭 150가지(기본 동작 20개 조합, `Moves`, docs/attacks.md)
- 10: 적 공격 표(`Tokens`, docs/attack_tokens.md)
- 11~14: 새 적 5종, 밤 목표·구역 규칙, 새벽 갈림길·낮 사건, 뽑기 타이밍·손잡이 조짐 (docs/content.md)
- 15: 마을 — 의뢰판, 수련장(허수아비), 주민 5명 대사, 떠돌이 상인 (docs/village.md, `data/village.tres`)
- 16: 마을 북문 밖 들판(싸움 없는 탐험, `scenes/field/`, `FieldLayout`)
- 17: 들판 싸움 — 북문에서 검 고르기, 무리 8곳, `Rules` 들판 모드(`start_field`, `spawn_pack`), 조각 보상 (docs/outside.md)
- 18: 들판 보스 무덤 기사(`Foes._knight`, `FieldLayout.BOSS_*`, `Meta.boss_defeat`), 화면 아래 체력 막대 (docs/outside.md)
- 19: 지하 무덤 — 들판 입구 → 방 6개(문이 닫히고 무리를 쓰러뜨리면 열림), 돌 관, 무덤 주인 (`CryptLayout`·`CryptRun`·`CryptBuilder`, `Meta.crypt_*`, docs/outside.md)
- 20: 새 지역 — 들판을 170×110칸으로 동쪽에 넓힘, 무너진 성채(`keep`)와 안개 늪(`marsh`), 무리 넷·상자 둘·비석 하나·조각 후보 4곳, 늪 안개는 화면만 (`FieldLayout.KEEP_*`·`MARSH_FOG_*`, `field.gd._marsh_fog`, docs/outside.md)
- 21: 1대1 결투 규칙(같은 PC) — `Rules.lords`·`start_duel`·`step_duel`(영주마다 `DuelSeat`를 갈아 끼움, 상대는 그림자 적), `Powers.off`, `data/duel.tres`, `LordInput.to_bytes/from_bytes`, `Meta.duel_wins/duel_losses`, 마을 광장 결투 말뚝 → `scenes/duel/duel.tscn`(1P 키보드·마우스, 2P 게임패드 0번) (docs/duel.md "정한 것")
- 그 밖: 원하는 검 얻는 콘솔(` 또는 F6, `SwordConsole`), 웹판 전용 그래픽 낮춤(`WebQuality`), 현황판 자동 채우기(`python3 docs/board.py`)

## 사용자가 정한 것 (지킬 것)

- 화풍: 어두운 사실풍. AI 생성 에셋 금지. 우주/Sol's RNG 느낌, 수묵화, 양산형 금지.
- 소리: 종소리, 올라가는 삐 소리, 위로 쓸어 올리는 소리 금지.
- 확률 보장(천장) 대신 다른 비용을 낮춘다.
- 화면 글자는 엘든 링식. 세계(3D)에 글자를 띄우지 않는다(피해 숫자만 예외).
- 갈고리(입체기동)는 갈고리 베기가 든 검만.
- 저주받은 손잡이의 밤: 적이 강해진다(체력·피해 ×1.25).
- 커밋 메시지 끝에 사용자 이메일을 넣지 않는다. 사용자 이메일은 밖에 공유하지 않는다.

## 일하는 방식

- GDD "3. 앞으로의 계획"을 위에서부터. 끝나면 `[x]`, "1. 지금까지 한 일"에 한 줄, 커밋·푸시, 사용자가 PC에서 볼 것을 짧게.
- 규칙은 `scripts/core/`의 노드 없는 RefCounted(`Rules` 중심), 30Hz 고정 틱, 랜덤은 `Rules.rng` 하나(판 밖은 `Meta.rng`), `state_hash`로 결정성 테스트. 수치는 `.tres`. 화면은 신호를 받아 그린다.
- 큰 일은 모양팀 → 기능팀 에이전트(CLAUDE.md). **사용자 주간 한도가 빠듯하니** 작은 모델로 한 에이전트가 끝까지 하는 쪽이 낫다(15·16단계는 그렇게 했다).
- 15·16단계는 절약판이라 모양이 기본 도형이고, 갤러리·아이콘·들판 효과가 없다. 들판은 직접 걸어 보지 못했다(E 상호작용, 장면 바꾸기, 다리, 짐승 도망은 확인 전).

## 사용자가 정한 것 (2026-11-19 오후, GDD 2.15)

- 마을 밖 큰 것: 들판 싸움(17) → 들판 보스(18) → 지하 무덤(19) → 새 지역(20), 모두 끝. 설계서 docs/outside.md.
- 1대1 결투: 모르는 사람과 매칭, **GD-Sync 무료판**(사용자가 가입·키 받기 필요), 웹판 없음, 서로 베기, 언덕 싸움터, **검집의 검**을 들고 감. 21 규칙(같은 PC 두 입력으로 먼저) → 22 온라인. 설계서 docs/duel.md는 21단계에서 쓴다.

## 다음

22단계 온라인 매칭(GD-Sync). **먼저 사용자가 GD-Sync에 가입해 키를 받아야 한다**(키는 git에 올리지 않는다). 방식(방장이 규칙을 돌리고 상대는 입력만 보냄 / 입력만 주고받는 락스텝)은 시작할 때 사용자에게 묻는다. 21단계가 이미 준비해 둔 것: 규칙이 결정적이고(`state_hash` 테스트), `LordInput.to_bytes/from_bytes`(18바이트), `duel.gd`의 `p1_source`·`p2_source`(입력을 대신 주는 Callable), `Rules.step_duel(입력1, 입력2)`. 설계서 docs/duel.md 22단계 절.

## 남은 계획 (GDD 3절)

22 온라인 매칭 → 23 관리 패널 → 24 화풍과 모델 → 25 소리 에셋 → 26 난이도와 강화 균형 → 27 시작 화면·설정·Windows 내보내기.

## 알려진 구멍

- 결투(21단계)는 직접 해 보지 못했다(게임패드 2P, 쿼터뷰 겨눔, 손맛, 마을 말뚝 자리). `MoveFx`의 따라가는 효과(회오리 띠)는 늘 1P를 따라간다. 영주 0이 한 틱에 먼저 돌아서 같은 틱에 서로 베면 둘 다 맞는다.
- "메아리 계곡"은 호를 다시 그리고, "바람의 왕"+회전은 싸움터 전체를 맞힌다. 3인칭에서 앞에 적이 없으면 도약이 3칸 고정이다. `FormData.combo`는 안 쓴다.
- 들판 수치(보상·비석 글·곳 이름)는 `data/field.tres`가 아니라 `FieldLayout` 상수에 있다.
- Mixamo 캐릭터와 사운드 팩은 git에 없다(PC에만). 없으면 기본 도형·코드 소리로 돈다.
- 들판의 적과 보스는 나무·바위를 뚫고 걷는다(길찾기 없음). 보스 체력 1800, 돌진 확률 0.6은 첫 값. 보스 이름 글자가 작고 흐리다.
- 지하 무덤은 직접 걸어 보지 못했다(문 돌판 움직임, 횃불 밝기, 카메라와 낮은 벽, 무덤 주인 싸움 손맛). 적은 무덤 벽도 뚫고 걷는다. 서쪽 끝 방(r5)은 선택 방이다.
- 이 세션은 GitHub 연결 전에 시작돼 푸시를 못 했다. 17~19단계 커밋은 사용자에게 git bundle로 줬다. 새 세션에서 원격에 없으면 사용자 PC에서 푸시하게 하거나 다시 받는다.
