# CLAUDE.md

이 저장소는 Godot 4.6 게임 「영지」(가제)다. 이전 기획 「총성」은 접었고 git 기록에만 남아 있다. 기획은 [docs/GDD.md](docs/GDD.md)에 있고, 수치는 모두 HTML 시연판에서 옮긴 첫 값이라 테스트하며 바뀐다.

## 작업 방식

- docs/GDD.md "3. 앞으로의 계획"의 체크리스트를 위에서부터 한 번에 한 단계씩 진행한다. 단계를 마치면 그 줄을 `- [x]`로 바꾸고 "1. 지금까지 한 일"에 한 줄 적는다.
- 단계마다 커밋하고, 끝나면 무엇을 만들었는지와 사용자가 PC의 Godot에서 무엇을 확인하면 되는지 한국어로 짧게 정리한다.
- 사용자는 Godot 4.6과 GDScript를 쓰는 1인 개발자(학생)다. 답과 설명은 한국어로, 짧게 한다. 처음 여는 세션이면 docs/GDD.md의 "0. 인계 요약", "1. 지금까지 한 일", "3. 앞으로의 계획"부터 읽는다.
- 기획에 없는 시스템은 새로 만들지 않는다. 애매하면 가장 단순한 쪽으로 만들고 정리에 적는다. GDD "2.14 정하지 않은 것"의 항목은 사용자에게 묻기 전에는 바꾸지 않는다.
- `prototype/`의 HTML 시연판은 참고용이다. 규칙과 수치는 거기서 가져오되 코드는 GDScript로 새로 쓴다. 시연판 파일은 고치지 않는다.

## 기술 규칙

- Godot 4.6, GDScript만 쓴다. 타입을 붙인 GDScript로 쓴다.
- 1칸 = 2m, 영지는 33 × 33칸, 영주관은 가운데 칸 (16, 16)이다. 칸 좌표(Vector2i)와 월드 좌표 변환은 `Grid.cell_to_world()`, `Grid.world_to_cell()` 두 함수로 통일한다. 시연판 수치는 칸 단위라 미터로는 2배다(영주 4.3칸/초 = 8.6m/초).
- 수치는 코드에 박지 않는다. 표 한 줄을 리소스 하나에 담는다.
  - `data/buildings/*.tres` (BuildingData), `data/people/classes/*.tres` (ClassData), `data/people/grades.tres` (GradeTable)
  - `data/enemies/*.tres` (EnemyData), `data/lord.tres` (LordData), `data/run.tres` (RunData: 일수, 낮 길이, 설계함 값, 시작 자원 등), `data/box_tiers.tres` (TierTable)
- 게임 규칙(판정, 체력, 자원, 뽑기, 길찾기, 습격)은 화면 코드와 섞지 않는다. `scripts/core/` 아래에 노드에 기대지 않는 RefCounted 클래스로 쓰고, 화면은 신호로 받는다. 나중에 서버 판정으로 옮기기 쉽게 다음을 지킨다.
  - 규칙은 고정 틱(30Hz)으로 돈다. `_physics_process`에서 누적 시간을 틱으로 쪼갠다.
  - 랜덤은 전부 시드가 있는 `RandomNumberGenerator` 하나(`Rules.rng`)를 거친다. 전역 `randf()`, `randi()`는 쓰지 않는다. 같은 시드와 같은 입력이면 결과가 같아야 한다.
- 적 길찾기는 영주관에서 거꾸로 퍼지는 거리 표(flow field, 다익스트라)를 칸이 바뀔 때만 다시 계산하고, 모든 적이 그 표 하나를 같이 쓴다. 칸 비용은 GDD 2.9에 있다. AStarGrid2D는 한 개체의 경로가 따로 필요할 때만 쓴다.
- 위치가 있는 소리(타격, 화살, 짓기, 발소리)는 AudioStreamPlayer3D로 낸다. 종소리, 올라가는 삐 소리, 위로 쓸어 올리는 소리는 쓰지 않는다(사용자가 싫어한다).
- 규칙 단위 테스트를 `tests/`에 둔다. 애드온 없이 `extends SceneTree` 스크립트로 쓰고 `godot --headless -s tests/run_all.gd`로 돌린다. 규칙을 바꾸면 테스트도 같이 고친다.

### 충돌 레이어

프로젝트 설정에 이름을 붙여 등록한다.

| 번호 | 이름 | 무엇 |
| --- | --- | --- |
| 1 | world | 바닥, 영지 경계 |
| 2 | lord | 영주 |
| 3 | enemy | 적 |
| 4 | structure | 성벽, 건물, 영주관. 적을 막는다 |
| 5 | nature | 나무, 바위. 영주와 적을 모두 막는다 |
| 6 | pick | 마우스로 칸을 고를 때 쓰는 바닥 판 |

- 영주의 마스크: world, nature, enemy. 시연판처럼 자기 성벽과 건물은 지나간다(GDD 2.14에서 다시 정한다).
- 적의 마스크: world, structure, nature, lord
- 화살, 돌, 마법 같은 투사체는 물리로 맞히지 않고 규칙이 목표를 따라가 맞힌다(시연판과 같다).

## 에셋

- 에셋은 `assets/` 아래에 둔다. AI 생성 에셋은 쓰지 않는다.
- 에셋 파일은 사용자가 PC에서 받아 넣는다. KayKit(CC0)을 먼저 쓴다. 아직 없으면 기본 도형으로 자리를 채우고, 나중에 바꿔 끼우기 쉽게 씬 하나로 감싼다.
- 에셋을 넣으면 `CREDITS.md`에 이름, 작가, 라이선스, 링크를 적는다.
- 설계함 연출은 `prototype/yeongji_pc.html`의 연출을 사용자가 녹화한 영상(.ogv, Ogg Theora)을 등급마다 하나씩 `assets/video/`에 넣어 VideoStreamPlayer로 튼다. 영상이 없으면 0.5초 번쩍임으로 대신한다.

## 확인

- 클라우드에서는 Godot 에디터로 직접 플레이할 수 없다. Godot 실행 파일을 받을 수 있으면 헤드리스로 프로젝트를 열어 스크립트 오류와 `tests/`를 확인하고, 받을 수 없으면 그 사실을 정리에 적는다.
- 손맛(이동, 타격, 넉백, 돌진, 히트스톱)은 사용자가 PC에서 맞춘다. 수치를 리소스로 빼 두는 이유다.
- 규칙이 시연판과 같게 도는지 헷갈리면 `prototype/yeongji_pc.html`을 브라우저로 열어 본다. ` 키로 관리 패널이 열린다.

## 폴더 구조

```
project.godot
scenes/   world/, lord/, enemies/, buildings/, people/, inn/, ui/, debug/
scripts/  core/ (규칙), world/, lord/, enemies/, buildings/, people/, inn/, ui/, debug/
data/     buildings/, people/, enemies/, lord.tres, run.tres, box_tiers.tres
assets/   characters/, buildings/, nature/, ui/, video/, sound/
tests/
prototype/  HTML 시연판 (고치지 않는다)
```
