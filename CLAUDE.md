# CLAUDE.md

이 저장소는 Godot 4.6 게임 「검의 언덕」(가제)이다. 이전 기획 「총성」과 「영지」는 접었고 git 기록에만 남아 있다. 기획은 [docs/GDD.md](docs/GDD.md)에 있고, 수치는 모두 HTML 시험판에서 옮긴 첫 값이라 테스트하며 바뀐다.

## 작업 방식

- docs/GDD.md "3. 앞으로의 계획"의 체크리스트를 위에서부터 한 번에 한 단계씩 진행한다. 단계를 마치면 그 줄을 `- [x]`로 바꾸고 "1. 지금까지 한 일"에 한 줄 적는다.
- 단계마다 커밋하고, 끝나면 무엇을 만들었는지와 사용자가 PC의 Godot에서 무엇을 확인하면 되는지 한국어로 짧게 정리한다.
- 사용자는 Godot 4.6과 GDScript를 쓰는 1인 개발자(학생)다. 답과 설명은 한국어로, 짧게 한다. 처음 여는 세션이면 docs/GDD.md의 "0. 인계 요약", "1. 지금까지 한 일", "3. 앞으로의 계획"부터 읽는다.
- 기획에 없는 시스템은 새로 만들지 않는다. 애매하면 가장 단순한 쪽으로 만들고 정리에 적는다. GDD "2.14 정하지 않은 것"의 항목은 사용자에게 묻기 전에는 바꾸지 않는다.
- `prototype/`의 HTML 시험판은 참고용이다. 규칙과 수치는 거기서 가져오되 코드는 GDScript로 새로 쓴다. 시험판 파일은 고치지 않는다. 규칙 코드는 `prototype/game_reference.js`에 있다.

## 기술 규칙

- Godot 4.6, GDScript만 쓴다. 타입을 붙인 GDScript로 쓴다.
- 1칸 = 2m. 싸움터는 34 × 22칸(`RunData.arena_size`)이다. 규칙의 위치는 칸 단위 실수(Vector2)이고, 월드 좌표 변환은 `Grid`의 함수(`cells_to_world`, `world_to_cells` 등)로만 한다. 시험판 수치는 칸 단위라 미터로는 2배다(영주 4.3칸/초 = 8.6m/초).
- 수치는 코드에 박지 않는다. 표 한 줄을 리소스 하나에 담는다.
  - `data/swords/001.tres` … `300.tres` (SwordData), `data/inscriptions/*.tres` (InscriptionData, 등급별 수치 6개)
  - `data/forms/*.tres` (FormData: 단검, 장검, 대검, 세검), `data/unarmed.tres` (맨손)
  - `data/grades.tres` (GradeTable), `data/enemies/*.tres` (EnemyData), `data/lord.tres` (LordData), `data/run.tres` (RunData: 구역, 낮의 뽑기와 제단, 밤의 적과 정예)
  - `data/meta.tres` (MetaData: 조각, 대장간 검집, 성소 축복)
- 게임 규칙(뽑기, 판정, 체력, 내구, 적, 구역)은 화면 코드와 섞지 않는다. `scripts/core/` 아래에 노드에 기대지 않는 RefCounted 클래스로 쓰고(`Rules`가 중심), 화면은 신호와 상태를 받아 그린다. 나중에 서버 판정으로 옮기기 쉽게 다음을 지킨다.
  - 규칙은 고정 틱(30Hz)으로 돈다. `_physics_process`에서 누적 시간을 틱으로 쪼갠다.
  - 랜덤은 전부 시드가 있는 `RandomNumberGenerator` 하나(`Rules.rng`)를 거친다. 전역 `randf()`, `randi()`는 쓰지 않는다. 같은 시드와 같은 입력이면 결과가 같아야 한다(`Rules.state_hash()`로 테스트한다). 화면 흔들림 같은 꾸밈용 랜덤은 화면 쪽에 따로 둔다.
  - 영주의 입력은 틱마다 `LordInput` 하나로 넘긴다. 밤 시작(`start_night`), 고르기(`choose`), 제단(`use_altar`)은 틱 사이에 부르는 함수다.
- 판 사이에 남는 것(조각, 검집, 축복, 도감, 기록)은 `Meta`(scripts/core/meta.gd)가 `user://hill_save.json`에 저장한다. 대장간·성소의 강화 확률은 판의 규칙과 따로 `Meta.rng`를 쓴다. `Rules`는 시작할 때 Meta를 받아 축복과 검집의 검을 반영하고, 판이 끝나면 `Meta.record_run`이 조각을 센다.
- 시작 장면은 마을(`scenes/lobby/lobby.tscn`)이고 언덕은 `scenes/world/main.tscn`이다. 장면을 바꿀 때는 `change_scene_to_file`을 쓰고, 둘 다 저장 파일에서 Meta를 다시 읽는다(자동 로드 없음).
- 카메라(`camera_rig.gd`)는 3인칭이 기본이고 V로 쿼터뷰와 바꾼다. 3인칭에서는 이동 입력을 카메라 기준으로 돌려(`relative_move`) 넘기고, 카메라가 보는 쪽을 겨눈다.
- 영주와 적의 움직임과 부딪힘은 물리 엔진이 아니라 규칙이 계산한다. 화면 노드는 Node3D이고, 규칙의 위치(prev_pos → pos)를 틱 사이로 이어 그린다. 싸움터에는 장애물이 없어서 적은 영주에게 곧장 온다(길찾기가 필요해지면 그때 넣는다).
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
- 에셋 파일은 사용자가 PC에서 받아 넣는다. 화풍은 어두운 사실풍이다(GDD 2.14). 모델이 아직 없는 자리는 기본 도형으로 자리를 채우고, 바꿔 끼우기 쉽게 한 곳에 모은다(`HiltView._build`, `EnemyView._build_*`, `AltarView`, `scenes/lord/lord_model.tscn`과 `LordCharacter`, `main._build_world`, `lobby._build_*`).
- 글꼴은 Noto Serif KR을 쓰는 글자만 남겨 넣었다(`assets/ui/fonts/`). 테마 `assets/ui/theme.tres`는 손으로 고치지 않고 `scripts/debug/build_theme.gd`를 고쳐 다시 만든다. 굵기는 FontVariation에 숫자 태그(2003265652 = wght)로 준다.
- 화면 글자는 엘든 링식이다. 세계(3D)에 글자를 띄우지 않는다(피해 숫자만 예외). 다가갔을 때 안내와 알림은 `Band`, 새 곳의 이름은 `AreaTitle`, 창은 `UiKit`(모서리 없는 검은 판, 놋쇠빛 줄, 따뜻한 글자색). 표에 드문 글자가 새로 생기면 `assets/ui/fonts/README.md`대로 다시 만든다.
- 에셋을 넣으면 `CREDITS.md`에 이름, 작가, 라이선스, 링크를 적는다.
- 소리(`assets/sound/<이름>/*.wav`)도 약관 문구가 없는 팩이라 git에 올리지 않는다(`assets/sound/README.md`). 파일이 없으면 `Sfx`가 코드로 만든 소리로 대신한다.
- Mixamo 캐릭터와 동작(`assets/characters/`)은 원본을 다시 나눠 주면 안 되어 git에 올리지 않는다(.gitignore). 무엇을 어디에 두는지는 `assets/characters/README.md`에 적는다. 파일이 없으면 기본 도형으로 돌아가야 한다(`LordCharacter.available()`).
- 뽑기 연출은 뽑기 데모의 연출을 사용자가 녹화한 영상(.ogv, Ogg Theora)을 등급마다 하나씩 `assets/video/`에 넣어 VideoStreamPlayer로 튼다. 영상이 없으면 0.5초 번쩍임으로 대신한다.

## 확인

- 클라우드에서는 Godot 에디터로 직접 플레이할 수 없다. Godot 실행 파일을 받을 수 있으면 헤드리스로 프로젝트를 열어 스크립트 오류와 `tests/`를 확인하고, Xvfb와 gl_compatibility로 화면을 찍어 본다. 받을 수 없으면 그 사실을 정리에 적는다.
- 손맛(이동, 베기, 넉백, 돌진, 히트스톱)은 사용자가 PC에서 맞춘다. 수치를 리소스로 빼 두는 이유다.
- 규칙이 시험판과 같게 도는지 헷갈리면 `prototype/geom_hill.html`을 브라우저로 열어 본다. ` 키로 관리 패널이 열린다.

## 폴더 구조

```
project.godot
scenes/   lobby/ (마을, 시작 장면), world/ (언덕), lord/, debug/
scripts/  core/ (규칙, Meta), core/data/ (표의 Resource 클래스), lobby/, world/, lord/, enemies/, ui/, debug/
data/     swords/, inscriptions/, forms/, enemies/, grades.tres, lord.tres, run.tres, unarmed.tres, meta.tres
assets/   characters/, nature/, ui/, video/, sound/
tests/
prototype/  HTML 시험판 (고치지 않는다)
```
