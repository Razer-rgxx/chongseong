# 인계서 (2026-11-19 밤 늦게, 자세한 판 — 24·27단계 반영)

다음 Claude에게. **이 문서를 처음부터 끝까지 읽고 나서 움직여라.** 지난번 인계서가 짧아서 다음 세션이 헤맸다고 사용자가 말했다. 여기 적힌 순서대로 하면 된다.

---

## 0. 맨 처음 할 일 (순서대로, 사용자에게 묻지 말고)

1. **저장소 받기.** 사용자가 이 파일만 첨부했다면 저장소를 먼저 받는다.
   ```
   cd /home/claude && git clone -q -b geom-hill https://github.com/Razer-rgxx/chongseong.git && cd chongseong
   git log --oneline -1
   ```
   - 가지는 **geom-hill**이다(main 아님).
   - `git log` 맨 위가 이 인계서 커밋(27단계 `a68fe0e` 다음)보다 오래된 것(예: `7163afa 인계서`)이면, **사용자가 아직 bundle을 GitHub에 안 올린 것**이다. 사용자에게 "PC에서 bundle 받고 `git push https://github.com/Razer-rgxx/chongseong.git HEAD:geom-hill` 한 줄 쳐 주세요"라고 한 번 부탁하거나, 사용자가 `chongseong.bundle`을 첨부했으면 `git pull <첨부 경로> geom-hill`로 받는다.
   - 받은 뒤 이 인계서(`docs/handoff.md`)가 저장소에 있는 것과 같은지 본다.
2. **푸시가 되는지 본다.** `git push --dry-run origin geom-hill`.
   - 되면: 단계마다 커밋하고 푸시한다.
   - 안 되면(지난 세션이 그랬다: GitHub 연결 전에 세션이 시작됨): 커밋만 하고, 단계가 끝날 때마다 **bundle을 만들어 SendUserFile로 보낸다**(아래 5절). 사용자는 "번들 내가 받을 테니까 계속 업데이트"라고 했다.
   - `mcp__claude-code-remote__add_repo`가 "link your GitHub account"로 실패하면, 그 세션에서는 계속 안 된다. 사용자에게 연결을 다시 하라고 조르지 말고 bundle로 간다.
3. **Godot 받기와 테스트.** (약 1~2분)
   ```
   mkdir -p ~/godot && cd ~/godot && curl -sSL -o g.zip https://github.com/godotengine/godot/releases/download/4.6.1-stable/Godot_v4.6.1-stable_linux.x86_64.zip && unzip -qo g.zip
   cd /home/claude/chongseong
   ~/godot/Godot_v4.6.1-stable_linux.x86_64 --headless --path . --import >/dev/null 2>&1
   ~/godot/Godot_v4.6.1-stable_linux.x86_64 --headless --path . -s tests/run_all.gd 2>&1 | grep -E "통과|실패|SCRIPT ERROR"
   ```
   지금 기대값: **`통과 1240, 실패 0`**(약 2분 30초). 다르면 무엇이 깨졌는지부터 본다.
4. **읽기.** `CLAUDE.md`(규칙 전부, 기술 규칙이 매우 자세하다) → `docs/GDD.md`의 0절(인계 요약), 1절 표의 맨 위 몇 줄, 2.14(정하지 않은 것), 2.15(마을 밖·결투 결정), 3절(계획 체크리스트). 일할 단계의 설계서(`docs/outside.md`, `docs/duel.md` 등).
5. 사용자에게 **한두 줄로** "읽었고, 테스트 1240 통과, 다음은 N단계"라고 말하고 사용자가 시킨 일을 한다.

---

## 1. 사용자 (어떻게 대하나)

- 한국인 1인 개발자, **학생**. Godot 4.6 + GDScript. 주로 **폰으로** 말한다(화면이 작다).
- **한국어로, 짧게.** 긴 설명·표 남발 싫어한다. 결과 → PC에서 볼 것 → 남은 구멍 → 다음, 이 순서로 짧게.
- 말이 아주 짧다("됨?", "링크 + 2", "함", "관리 패널은 뭐야?"). 앞 대화 맥락으로 뜻을 읽는다. 예: "링크 + 2"는 "링크 주고, 선택지 2번으로 해".
- **"링크 달라"고 하면 진짜 주소를 준다.** 설명만 하지 말 것. 모르면 검색해서 찾는다.
- **"자세히 설명"이라고 하면 단계별로 진짜 자세히.** 대충 쓰면 다시 묻는다.
- **알아서 하라고 했으면 묻지 말고 한다.** 사용자가 학원 등으로 자리를 비울 때 "다음 단계 알아서 해"라고 한다. 그때는 가장 단순한 쪽으로 정하고 설계서 "정한 것"에 적은 뒤 진행, 단계마다 bundle+인계서를 SendUserFile(status proactive)로 보낸다.
- **주간 사용 한도가 빠듯하다.** 큰 단계는 sonnet 에이전트 하나에게 맡기는 게 싸다(아래 4절). 쓸데없는 탐색·되풀이 하지 말 것.
- 이미 있는 것을 다시 만들자고 하면 싫어한다. 예: 23단계 관리 패널 — "이미 다 있는데 조각 주기만 추가"라고 했다. 일 시작 전에 이미 있는지 `grep`으로 본다.
- 사용자 이메일을 커밋·문서·밖에 쓰지 않는다.

## 2. 사용자 PC

- 저장소 위치: `C:\Users\user\Documents\chongseong` (원격 등록 없음, 그때그때 URL로 pull/push).
- **GitHub에서 받기**(Godot 끄고 한 줄씩):
  ```
  cd C:\Users\user\Documents\chongseong
  git stash
  git pull https://github.com/Razer-rgxx/chongseong.git geom-hill
  ```
- **bundle로 받기**(다운로드 폴더에 둔 경우):
  ```
  git pull C:\Users\user\Downloads\chongseong.bundle geom-hill
  ```
  bundle은 **PC의 지금 커밋..geom-hill**로 만든다(2026-11-19 23시: PC는 `3e913be`, 그 전에는 `75be671`). 2026-11-19 밤에 PC를 직접 열어 보니 PC의 geom-hill은 `75be671`(검 받기 창)에서 멈춰 있었다. GitHub의 7163afa도, 그 뒤 bundle도 PC에 들어간 적이 없다(7163afa 기준 bundle은 "필요한 커밋 없음"으로 실패했다). PC가 따라잡으면(사용자가 pull에 성공하면) 그 커밋을 새 기준으로 삼는다. 매번 그때까지 전부 들어 있어서 최신 것 하나만 받으면 된다.
- PC가 이 세션에 연결돼 있으면(`mcp__remote-devices__*`) `device_commit_files`로 bundle을 저장소 맨 위에 `update.bundle`로 바로 써 준다(`.git` 안은 쓰기가 막힌다, `*.bundle`은 .gitignore). 사용자는 `git pull .\update.bundle geom-hill` 한 줄만 친다. PC의 git 상태는 `.git/logs/HEAD`·`refs/heads/geom-hill`을 stage해서 본다(device_bash 없음).
- 사용자의 터미널은 **PowerShell**이다(`&&`가 안 된다, `;`로 잇는다). Godot 폴더(바탕화면)에서 연 PowerShell에 붙여 넣는다.
- 사용자에게는 **명령 한 줄**로 준다(파일을 풀거나 복사하게 하지 않는다). 사용자는 "왜 내가 푸냐, 전 클로드는 한 줄이면 됐다"고 했다:
  ```
  cd C:\Users\user\Documents\chongseong; git stash; git pull .\update.bundle geom-hill
  ```
- **GitHub로 올리기**(사용자 PC에서): `git push https://github.com/Razer-rgxx/chongseong.git HEAD:geom-hill`
- PC에만 있고 git에 없는 것: Mixamo 기사 모델·동작(`assets/characters/`), 사운드 팩(`assets/sound/`), 뽑기 영상(`assets/video/`). 클라우드에서는 기본 도형·코드 소리로 돈다(정상).
- 웹판(웨일북용, https://razer-rgxx.github.io/chongseong/, `gh-pages` 가지)은 15단계 무렵 것이다. 사용자가 **결투는 웹판 안 한다**고 했다. 웹판을 다시 만들라는 말이 없으면 건드리지 않는다.

## 3. 지금 상태 (2026-11-19 밤)

### 2026-11-20 아침까지 더한 것
- 시작 화면 3D(해 질 녘 언덕, 금빛 검), 대사 창 `DialogueBox`, 30 점프(`Blockers`, `LegFold`), 31 어려운 무덤, 32 곳마다 우두머리(`Rules.chiefs`), 33 오픈월드 한정 검(301~310), 34 떠도는 사람·영입, 35 죽으면 검 떨굼(`Meta.dropped`·`lost`, 소울류), 36 들판 화면(`FieldHud` 나침반). 설계서 docs/field_life.md.
- 큰 단계는 git 워크트리 두 개(`git worktree add /home/claude/wt-a -b <가지>`)에 opus 에이전트를 하나씩 붙여 동시에 만들고 합쳤다(Agent의 isolation 옵션은 막혀 있다). 에이전트에게 GDD·handoff·CLAUDE.md는 고치지 말라고 하고 합칠 때 직접 고친다. 사용자 5시간 한도에 걸리면 에이전트가 멈춘다: 풀린 뒤 SendMessage로 이어 가게 한다.
- PC 연결(`mcp__remote-devices__*`)은 데스크톱 앱이 켜져 있을 때만 된다. 연결돼 있으면 `device_commit_files`로 `update.bundle`을 게임 폴더에 넣는다.

### 끝난 단계
1~4, 6~24, 27~29단계. 5단계(손맛 맞추기)는 사용자가 PC에서 할 일이라 비어 있다. 25(소리)는 미룸, 26(균형)은 사람이 해 본 기록이 있어야 한다.

| 단계 | 무엇 | 어디 |
| --- | --- | --- |
| 9 | 좌클릭 150가지(기본 동작 20개 조합) | `Moves`, docs/attacks.md |
| 10 | 적 공격 표 | `Tokens`, docs/attack_tokens.md |
| 11~14 | 새 적 5종, 밤 목표·구역 규칙, 새벽 갈림길·낮 사건, 뽑기 타이밍·조짐 | docs/content.md |
| 15 | 마을: 의뢰판, 수련장, 주민 5명, 떠돌이 상인 | docs/village.md, `data/village.tres` |
| 16 | 마을 북문 밖 들판(탐험) | `scenes/field/`, `FieldLayout` |
| 17 | 들판 싸움: 북문 검 고르기, 무리, `Rules.field` 모드 | docs/outside.md |
| 18 | 들판 보스 무덤 기사 | `Foes._knight`, `FieldLayout.BOSS_*` |
| 19 | 지하 무덤: 방 6개, 돌판 문, 관, 무덤 주인 | `scripts/crypt/`, `scenes/crypt/` |
| 20 | 새 지역: 들판 170×110칸, 무너진 성채, 안개 늪 | `FieldLayout.KEEP_*`, `MARSH_FOG_*` |
| 21 | 1대1 결투 규칙(같은 PC: 1P 키보드·마우스, 2P 패드) | `Rules.lords`, `start_duel`, `step_duel`, `DuelSeat`, docs/duel.md |
| 22 | 온라인 결투(GD-Sync, 입력만 주고받는 락스텝) | `scripts/net/`, `addons/GD-Sync` |
| 23 | 관리 패널: 나머지는 이미 있었고 **조각 주기만** 더함 | 검 콘솔(` 또는 F6, 언덕에서)에 `조각 500` + Enter |
| 24 | 적 모델: 적은 **이미 다 모양이 있다**(망령 망토, 늑대, 새 적 5종 EnemyArt, 큰 적·방패병은 Mixamo 기사). 바꿔 끼울 자리만 만듦: `assets/characters/enemies/<적 id>.fbx`가 있으면 그것(`LordCharacter.enemy_path`·`char_path`) | assets/characters/README.md "적 모델" |
| 27 | 시작 화면(해 질 녘 언덕 3D 배경, 금빛 검·불씨·재, "아무 키나 누르세요" → 시작·설정·끝내기, `scripts/title/title.gd`, 찍기 `scripts/debug/shots/shot_title.gd`), 설정 창(소리 크기·마우스 감도·키 11개, `user://settings.cfg`), 마을·언덕에서 F10, Windows 내보내기 설정 "Windows Desktop" | `scenes/title/`, `GameSettings`, `SettingsPanel` |
| 28 | 새 지역 더: 들판 230×110칸, 버려진 채석장·불탄 마을·까마귀 고개(그린 곳 = 막힌 곳 표, 틈 셋), 무리 5·상자 4·비석 2·조각 후보 3 | `FieldLayout.QUARRY_*`·`HAMLET_*`·`PASS_*`, `FieldBuilder._quarry/_hamlet/_pass/new_land` |
| 29 | 들판 낮밤과 다시 생기는 적: 시계(낮 240초·밤 150초, `Meta.field_clock`), 밤엔 덤빔 14칸·세기 구역 +1·무리 적 피해 ×1.25(`FIELD_NIGHT_DAMAGE`), 밤에만 서는 무리 4곳, 새벽마다 낮 무리 되살림(영주 14칸 안의 무리는 그 새벽 건너뜀, `FIELD_DAWN_SAFE`), 밤 화면과 영주 횃불 | `Rules._step_field_clock`, `FieldLayout.NIGHT_PACKS`·`night_amount`, `field.gd._light`, docs/outside.md |

커밋, 오래된 것부터: `dc94b8e` 계획 → `4db1432` 17 → `9a52bff` 18 → `9a44328` 인계서 → `a626e62` 19 → `fb87c71` 20 → `7344955` 결투 설계서 → `f3f4616` 21 → `a4000f6` 락스텝 결정 → `d82bf00` 22 → `a5399b4` 23 → (다음 세션) `ff9d1f3` 24 → `a68fe0e` 27 → 인계서 → (다음 세션) 28·29(아래 `git log`로 확인). 이 커밋들은 아직 GitHub에 없다(bundle로만 줬다).

### 진행 중인 일: GD-Sync 키 (22단계 확인 대기)
- 사용자가 gd-sync.com에 가입했다. **API Keys 페이지(https://www.gd-sync.com/app/a...)에 "Your API keys 0/1"만 있고 키도, 만드는 버튼도 안 보였다**(폰 화면). 메일 인증, 로그아웃 후 다시 로그인(바뀐 것은 최대 5분 걸린다고 페이지에 적힘), PC에서 열기, MENU의 다른 항목 확인을 권했다. 그 뒤 결과는 아직 모른다.
- 키를 넣는 곳(둘 중 하나, 둘 다 git에 안 올라간다):
  - Godot 에디터 **Project > Tools > GD-Sync** 창에 공개키·비밀키 붙여 넣기 → `addons/GD-Sync/keys.cfg`. 이게 더 쉽다.
  - 또는 `%APPDATA%\Godot\app_userdata\검의 언덕\gdsync_keys.cfg`:
    ```
    [keys]
    public="공개키"
    private="비밀키"
    ```
- 키가 생기면 사용자가 확인할 것: Debug > Customize Run Instances로 창 2개 → 두 창 모두 마을 광장 결투 말뚝 E → "모르는 사람과 겨루기" → 만나는지, 3판 끝까지 가는지, "어긋남(desync)" 창이 안 뜨는지. 안 되면 `user://GD-Sync/Logs` 로그를 받아 본다.
- 비밀키를 채팅에 붙이지 말라고 했다. 붙여 오면 쓰지 말고 "그 키는 다시 만드세요"라고 한다.
- GD-Sync 문서: https://www.gd-sync.com/docs/getting-started , 로비 https://www.gd-sync.com/docs/lobbies , 요금 https://www.gd-sync.com/plans (무료 하루 200MB, 우리 한 판 둘이 합쳐 약 1.4MB). WebFetch는 gd-sync.com을 막을 수 있다: WebSearch(allowed_domains gd-sync.com)로 찾으면 내용이 나온다.
- **라이선스 주의:** `addons/GD-Sync/LICENSE`는 "All rights reserved" + 소스 재배포만 허락하는 BSD 비슷한 글이다. 실행 파일 배포 조항이 없다. GD-Sync 안내서에는 API 키를 넣으면 게임을 내보내 친구에게 보내도 된다고 적혀 있다(https://www.gd-sync.com/guides/godot-multiplayer-tutorial). 약관 본문(https://www.gd-sync.com/terms)은 아직 못 읽었다. 남에게 exe를 나눠 주기 전에 확인할 것이라고 사용자에게 말했다.

### 다음 단계
- 계획표는 25·26만 남았다.
- **25 소리 에셋(미룸):** 코드로 만든 소리가 23개 남았다(`EnemyFx.SOUNDS` 11, `NightFx.SOUNDS` 11, `Sfx`의 night). 클라우드에서는 itch.io·OpenGameArt·Freesound에 접속이 안 된다(github.com과 godot 릴리스만 됨). 사용자가 팩 원본 zip(Gravity Sound Medieval Melee Weapon SFX, Hove Audio Sword Combat Free)을 다시 받아 올리면 고르고 다듬어 넣는다. 사용자는 "귀찮다"고 했다: 다시 조르지 말고, 사용자가 올리면 한다.
- **26 균형:** 사용자가 해 본 기록이 있어야 한다.
- 그 밖에는 사용자가 시키는 것을 한다. 17~23단계를 PC에서 해 본 말이 오면 그걸 먼저 고친다.
- 사용자가 다른 걸 시키면 그걸 한다(계획은 사용자가 자주 바꾼다: 17~22단계도 이번에 끼워 넣었다).

## 4. 일하는 방식 (지난 세션에서 잘 된 방법)

### 단계 하나를 끝내는 흐름
1. 설계서가 없으면 먼저 짧게 쓴다(`docs/<이름>.md`). 사용자가 정한 것과 "가장 단순하게 정한 것"을 나눠 적고 커밋.
2. **sonnet 에이전트 하나**(`Agent`, `subagent_type: general-purpose`, `model: sonnet`, `run_in_background: true`)에게 모양+기능을 다 맡긴다. 프롬프트 틀은 아래.
3. 에이전트가 끝나면 **직접 확인**: `git status`(깨끗한지), `git log -1`, 테스트 다시 돌리기, 찍은 화면 `Read`로 보기. 이상하면(예: 결투 화면에서 두 영주가 다 맞음) 찍기 스크립트를 열어 원인이 무엇인지 본다. 지난번엔 찍기 스크립트가 2P도 공격하게 해서였고 버그가 아니었다.
4. bundle 다시 만들고 인계서 복사해 SendUserFile:
   ```
   cd /home/claude/chongseong && mkdir -p /home/claude/out
   git bundle create /home/claude/out/chongseong.bundle <PC의 커밋>..geom-hill   # PC의 .git/logs/HEAD 마지막 줄에서 본다
   cp docs/handoff.md /home/claude/out/handoff.md
   ```
   (푸시가 되면 bundle 대신 `git push origin geom-hill`.)
5. 사용자에게 짧게: 만든 것 / PC에서 볼 것 3~5줄 / 남은 구멍 / 다음.

### 에이전트 프롬프트 틀 (이대로 써서 잘 됐다)
```
너는 Godot 4.6 게임 「검의 언덕」의 N단계(이름)를 모양과 기능 모두 혼자 끝까지 만든다. 절약판이다: 모양은 기본 도형과 이미 있는 것을 빌리고, 갤러리·아이콘은 만들지 않는다.
저장소: /home/claude/chongseong (가지 geom-hill). 푸시하지 않는다. 커밋만 한다.
Godot: ~/godot/Godot_v4.6.1-stable_linux.x86_64. 새 장면·리소스를 만들면 `--headless --path . --import` 한 번. 테스트: (명령) — 지금 "통과 947, 실패 0". 끝날 때도 실패 0.
먼저 읽기: CLAUDE.md, 설계서의 N단계 절, 앞 단계 커밋(git show --stat <해시>), 관련 파일(이름을 콕 집어 준다).
할 일: (설계서를 번호 목록으로 풀어 쓴다. 수치는 어디에 두는지, 저장은 Meta 어디에, 옛 저장은 기본값으로 읽히게.)
테스트: tests/<이름>_tests.gd 새로 만들고 run_all에 등록. 결정성(state_hash), 옛 저장 읽기는 늘 넣는다.
헤드리스로 장면 몇 백 프레임 돌려 오류 확인. Xvfb + `--rendering-driver opengl3 --rendering-method gl_compatibility`로 화면 한 장 /home/claude/shots/<이름>.png. (찍기 예: scripts/debug/shots/shot_duel.gd)
문서: 설계서 "정한 것", GDD 3절 `- [x]`, GDD 1절 표 맨 위에 날짜 한 줄, CLAUDE.md 기술 규칙 한 줄, docs/handoff.md 고침, `python3 docs/board.py`.
커밋 메시지 "기능팀: N단계 이름(...)", 끝에 정확히 이 두 줄(이메일 넣지 말 것):
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: <이 세션 주소>
author는 `git -c user.name=Claude -c user.email=noreply@anthropic.com commit ...`.
지킬 것: 타입 붙인 GDScript, 수치 코드에 박지 않기, 규칙과 화면 분리, 전역 randf/randi 금지, 세계(3D)에 글자 없음, AI 에셋 없음, 기획에 없는 시스템 만들지 않기. 애매하면 가장 단순하게 하고 "정한 것"에 적는다.
끝나면 한국어로 짧게 보고: 만든 것, 바꾼 파일, 테스트 수, 화면 확인 여부, 사용자가 PC에서 확인할 것 3~5줄, 남은 구멍.
```
- 커밋 꼬리의 두 줄은 그 세션의 시스템 안내(attribution)에 나오는 것을 쓴다. 세션 주소는 세션마다 다르다.
- 작은 일(예: 23단계 조각 주기, 20줄)은 에이전트 없이 직접 고친다. 더 싸다.

### 화면 찍기
- 들판: `scripts/debug/shots/shot_field.gd`. Xvfb로 돌리면 새 곳·틈·해질녘·밤·새벽을 찍고(한 장에 1분쯤, 다 합쳐 10분: 백그라운드로 돌리고 기다린다), `--headless`로 돌리면 START에서 상자·비석·무리·조각·곳마다 걸어서 닿는지 BFS만 본다(몇 분).
- 앞 단계가 쓴 찍기·연기 스크립트: `scripts/debug/shots/shot_duel.gd`(결투 장면을 띄워 245틱 뒤 PNG 저장, 1P·2P 자동 입력), `scripts/debug/shots/lobby_smoke.gd`(마을에서 결투 말뚝 상호작용까지). 다른 장면은 이것을 고쳐 쓴다.
- 돌리는 법: `xvfb-run -a ~/godot/Godot_v4.6.1-stable_linux.x86_64 --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s scripts/debug/shots/shot_duel.gd` (Xvfb가 없으면 `apt-get install -y xvfb`).

## 5. 사용자가 정한 것 (반드시 지킬 것)

- 화풍: **어두운 사실풍.** AI 생성 에셋 금지. 우주/Sol's RNG 느낌, 수묵화, 양산형 금지.
- 소리: 종소리, 올라가는 삐 소리, 위로 쓸어 올리는 소리 금지.
- 확률 보장(천장) 대신 다른 비용을 낮춘다.
- 화면 글자는 엘든 링식. 세계(3D)에 글자를 띄우지 않는다(피해 숫자만 예외). 안내는 `Band`, 곳 이름은 `AreaTitle`, 창은 `UiKit`.
- 갈고리(입체기동)는 갈고리 베기가 든 검만.
- 저주받은 손잡이의 밤: 적이 강해진다(체력·피해 ×1.25).
- 마을 밖 큰 것(들판 싸움, 들판 보스, 지하 무덤, 새 지역)은 사용자가 고른 것이고 순서도 사용자가 정했다(들판부터, 결투는 마지막).
- 결투: 모르는 사람과 매칭(GD-Sync 무료판), **웹판 없음**, 서로 베기, 곳은 언덕 싸움터, **각자 검집의 검**을 들고 간다, 방식은 **입력만 주고받는 락스텝**.
- 사용자가 없을 때 Claude가 "가장 단순하게" 정한 것(사용자가 바꿀 수 있음): 들판에서 쓰러져도 잃는 것 없음, 결투에서 각인·고유 능력 끔, 결투 체력 300·90초·3판 2선승, 결투 보상 없음(기록만), 같은 PC 결투는 쿼터뷰 하나. 자세한 것은 docs/outside.md·docs/duel.md "정한 것".
- 커밋 메시지에 사용자 이메일을 넣지 않는다.

## 6. 코드 지도 (어디를 고치나)

자세한 규칙은 CLAUDE.md "기술 규칙"에 다 있다. 처음 찾을 때 쓰는 요약:

- **규칙(노드 없음):** `scripts/core/rules.gd`가 중심. 30Hz 틱(`step`, 들판 `start_field`, 결투 `step_duel`), 랜덤은 `Rules.rng` 하나, `state_hash()`로 결정성. 적 행동 `foes.gd`, 공격 표 `tokens.gd`, 좌클릭 `moves.gd`, 각인·고유 능력 `powers.gd`, 영주 입력 `lord_input.gd`(`to_bytes`).
- **판 밖 저장:** `scripts/core/meta.gd` → `user://hill_save.json`. 판 밖 랜덤은 `Meta.rng`. 새 칸을 더하면 옛 저장이 기본값으로 읽혀야 한다(테스트 필수). 판이 끝날 때 `record_run`이 조각 세고 들판·무덤·보스를 비운다.
- **수치:** `data/*.tres`(표 한 줄 = 리소스 하나). 들판·무덤 수치는 예외로 `FieldLayout`·`CryptLayout` 상수에 있다.
- **장면:** 마을 `scenes/lobby/lobby.tscn`(시작 장면, `scripts/lobby/lobby.gd`, 창 `scripts/ui/lobby_hud.gd`), 언덕 `scenes/world/main.tscn`(`main.gd`), 들판 `scenes/field/field.tscn`, 무덤 `scenes/crypt/crypt.tscn`, 결투 `scenes/duel/duel.tscn`. 장면을 바꿀 때 `change_scene_to_file`, 각 장면이 Meta를 다시 읽는다(autoload 없음). 장면 사이로 넘기는 값은 `Meta`의 static 변수(`carry_sword`, `wake_at_gate`, `wake_at_crypt`, `duel_picks` 등).
- **온라인:** `scripts/net/` — `lockstep.gd`(지연 `DuelData.net_delay` 4틱, 겹쳐 보내기, 30틱마다 hash 비교), `net_link.gd`(인터페이스), `loop_link.gd`(시험용), `gdsync_link.gd`(실제, 처음 쓸 때 `/root/GDSync`를 올림, autoload 아님), `duel_setup.gd`(시드·두 검), `online_duel.gd`(마을 창 → 결투 장면).
- **관리 기능:** 검 콘솔 `scripts/ui/sword_console.gd`(언덕 `main.gd`에서만 열림: 검 받기, `조각 N`). 언덕(`main.gd` `_unhandled_input`)의 관리 키: F1 도움말, F2 무적, F3 밤 넘기기, F4 다음 뽑기 등급 고정(돌려 가며), ` 또는 F6 검 콘솔(검 받기·`조각 N`), V 카메라. 마을·들판·무덤·결투에는 관리 키가 없다.
- **테스트:** `tests/run_all.gd`가 파일을 하나씩 등록한다. 새 테스트 파일은 거기에 넣어야 돈다.
- **현황판:** `python3 docs/board.py`가 `docs/team_board.html`을 다시 만든다(손으로 고치지 않는다). 15~29단계를 GDD 체크리스트에서 읽는다.

## 7. 알려진 구멍 (사용자가 PC에서 아직 안 본 것 포함)

- **하나도 사람이 직접 해 보지 않았다(17~23).** 헤드리스와 화면 한 장씩만 봤다. 사용자가 PC에서 해 보고 말해 주는 것이 먼저다. 사용자가 "이상하다"고 하면 그 말이 맞다고 보고 고친다.
- 들판·무덤의 적과 보스는 나무·바위·벽을 뚫고 걷는다(길찾기 없음). 무덤은 그래서 방에 들어설 때 무리를 세운다.
- 이동·타격 효과 일부는 땅 높이를 평지로 그려 언덕진 곳에서 뜨거나 묻힐 수 있다(보스 단계에서 `EnemyFx.height_of`로 일부 고침).
- 보스 체력 1800, 돌진 확률 0.6, 결투 체력 300 등은 첫 값. 보스 이름 글자가 작고 흐리다.
- 무덤: 기둥 없음, 서쪽 끝 방(r5)은 막다른 선택 방, 적 하나당 조각 없음(관이 보물). 돌판 문 움직임·카메라와 낮은 벽(1.5m)·횃불 밝기는 확인 전.
- 28·29: 채석장 구덩이·고개 길·새 곳의 상자·비석·무리는 걸어 보지 못했다(화면은 불탄 마을 한 장). 그을린 벽이 조명 아래서 갈색으로 보인다. 29: 낮밤이 실제로 넘어가는 몇 분, 해질녘 색, 밤 세기의 손맛(구역 +1은 공격 표 수와 부른 적만 바꾼다), 새벽에 영주 곁에서 무리가 되살아나는 순간은 확인 전. 게임 창을 그냥 닫으면 시계는 마지막 저장 때 값으로 돌아간다. 들판 낮의 영주 횃불을 1.2에서 0으로 끈 것이 사용자 눈에 어떤지 모른다.
- 새 지역: 성채는 돌 상자를 쌓은 수준. 들판을 넓히면서 나무·바위를 다시 뿌려 원래 들판의 나무·바위 자리가 조금 바뀌었다(상자·비석·무리 자리는 그대로).
- 결투: 같은 틱에 서로 베면 둘 다 맞는다. 도중에 Esc로 나가면 기록 안 함. 회오리 같은 따라가는 효과는 늘 1P 쪽에 그려진다. 결투 소리 4가지뿐.
- 온라인: 실제 서버 접속 확인 전. Windows와 Linux끼리는 부동소수 차이로 desync 가능. 재접속 없음. 같은 저장 파일을 쓰는 두 창은 한쪽 기록만 남을 수 있다.
- 옛 구멍: "메아리 계곡"은 호를 다시 그리고, "바람의 왕"+회전은 싸움터 전체를 맞힌다. 3인칭에서 앞에 적이 없으면 도약이 3칸 고정. `FormData.combo`는 안 쓴다.
- 들판 수치(보상·비석 글·곳 이름)는 `data/field.tres`가 아니라 `FieldLayout` 상수에 있다.
- 24: 적 제 모델(`enemies/<id>.fbx`)은 실제 파일로 돌려 보지 못했다(영주 동작이 붙는지, 크기, 눈 자리). 넣지 않으면 아무것도 안 바뀐다.
- 27: 키 바꾸기는 행동마다 첫 입력만 바꾼다(예비 키는 남음). 도움말·안내 글의 키 이름은 바꾼 키를 따라가지 않는다. 들판·무덤·결투에는 F10이 없다(시작 화면에서 바꾸면 된다). Windows exe는 PC에서 만든다(Mixamo·소리가 PC에만 있어서).

## 8. 하지 말 것 (지난 세션에서 배운 것)

- 사용자에게 같은 걸 두 번 묻지 않는다. 이 문서에 답이 있으면 그걸 쓴다.
- 링크를 달라는데 메뉴 이름만 말하지 않는다. 모르면 "확인 못 했다"고 솔직히 말하고 아는 주소(로그인 주소 등)를 준다.
- GitHub 연결이 안 된다고 대화 내내 붙잡지 않는다. 한 번 시도해서 안 되면 bundle로 간다.
- 설계서에 없는 시스템을 만들지 않는다. 사용자가 이미 있다고 한 것을 다시 만들지 않는다.
- 커밋을 안 하고 끝내지 않는다. 작업 공간은 세션이 끝나면 사라질 수 있다. 단계마다 커밋 + bundle(또는 푸시).
- **사용자에게 에셋을 받아 오라고 떠넘기지 않는다.** 이미 있는 것(모델·소리)을 먼저 `grep`으로 찾고, 있으면 그대로 쓴다. 24단계에서 "Mixamo에서 받아 넣으라"고 했다가 "전 클로드들은 알아서 다 했다", "이미 모델 있었다"는 말을 들었다. 활잡이 등을 기사 모델로 덮어썼다가 되돌렸다.
- zip을 풀게 하지 않는다. bundle + 명령 한 줄.
