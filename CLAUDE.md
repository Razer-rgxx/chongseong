# CLAUDE.md

이 저장소는 Godot 4.6 게임 「총성(銃城)」이다. 기획은 [docs/GDD.md](docs/GDD.md)에 있고, 수치는 모두 첫 값이라 테스트하며 바뀐다.

## 작업 방식

- docs/GDD.md "3. 앞으로의 계획"의 체크리스트를 위에서부터 한 번에 한 단계씩 진행한다. 단계를 마치면 그 줄을 `- [x]`로 바꾼다.
- 단계마다 커밋하고, 끝나면 무엇을 만들었는지와 사용자가 PC의 Godot에서 무엇을 확인하면 되는지 한국어로 짧게 정리한다.
- 사용자는 Godot 4.6과 GDScript를 쓰는 1인 개발자다. 답과 설명은 한국어로, 짧게 한다. 처음 여는 세션이면 docs/GDD.md의 "1. 지금까지 한 일"과 "3. 앞으로의 계획"부터 읽는다.
- 기획에 없는 시스템은 새로 만들지 않는다. 애매하면 가장 단순한 쪽으로 만들고 정리에 적는다.

## 기술 규칙

- Godot 4.6, GDScript만 쓴다. 타입을 붙인 GDScript로 쓴다.
- 1칸 = 2m, 결투장은 13 × 17칸이다. 칸 좌표(Vector2i)와 월드 좌표 변환은 함수 하나로 통일한다.
- 수치는 코드에 박지 않는다. 총은 `data/guns/*.tres`, 설계도는 `data/blueprints/*.tres`로 표 한 줄을 리소스 하나에 담는다(GunData, BlueprintData 같은 Resource 스크립트).
- 게임 규칙(판정, 체력, 석재, 설계함)은 화면 표시 코드와 섞지 않는다. 나중에 서버 판정으로 옮기기 쉽게 입력, 규칙, 표시를 나눈다.
- 위치가 있는 소리(짓기, 총, 발소리)는 AudioStreamPlayer3D로 낸다. 재질과 총마다 다른 소리를 리소스에 붙인다.
- 봇 길찾기는 AStarGrid2D를 쓴다. 온라인은 마지막 단계이고, 그전까지는 로컬에서 봇과 대전한다.

### 충돌 레이어

프로젝트 설정에 이름을 붙여 등록한다.

| 번호 | 이름 | 무엇 |
| --- | --- | --- |
| 1 | world | 바닥, 결투장 경계 |
| 2 | south_body | 남쪽 축성술사 |
| 3 | north_body | 북쪽 축성술사 |
| 4 | structure | 벽, 망루 같은 구조물. 몸과 총알을 모두 막는다 |
| 5 | moat | 해자. 몸만 막는다 |
| 6 | south_gate | 남쪽 쇠살문. 북쪽 몸과 총알을 막는다 |
| 7 | north_gate | 북쪽 쇠살문. 남쪽 몸과 총알을 막는다 |
| 8 | heart | 심장석 |

- 남쪽 몸의 마스크: world, structure, moat, north_gate, heart
- 북쪽 몸의 마스크: world, structure, moat, south_gate, heart
- 총알 레이캐스트의 마스크: world, structure, south_gate, north_gate, heart, 상대 몸 (moat는 넣지 않는다)

## 에셋

- 에셋은 `assets/` 아래에 둔다. AI 생성 에셋은 쓰지 않는다.
- 쓸 에셋은 docs/GDD.md의 에셋 표에 있다. 에셋 파일은 사용자가 PC에서 받아 넣는다. 아직 없으면 기본 도형으로 자리를 채우고, 나중에 바꿔 끼우기 쉽게 씬 하나로 감싼다.
- 에셋을 넣으면 `CREDITS.md`에 이름, 작가, 라이선스, 링크를 적는다.

## 확인

- 클라우드에서는 Godot 에디터로 직접 플레이할 수 없다. Godot 실행 파일을 받을 수 있으면 헤드리스로 프로젝트를 열어 스크립트 오류를 확인하고, 받을 수 없으면 그 사실을 정리에 적는다.
- 손맛(이동 속도, 반동, 낙차)은 사용자가 PC에서 맞춘다. 수치를 리소스로 빼 두는 이유다.

## 폴더 구조

```
project.godot
scenes/   arena/, player/, structures/, ui/
scripts/  core/ (규칙), player/, structures/, bot/, ui/
data/     guns/, blueprints/
assets/   characters/, structures/, guns/, territory/
```
