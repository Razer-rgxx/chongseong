# 검의 언덕(가제)

수천 자루 검이 꽂힌 언덕을 오르는 PC 액션 뽑기 게임. 낮에는 꽂힌 검을 뽑고(한 번에 체력이 든다), 밤에는 뽑은 검으로 몰려오는 괴물을 버틴다. 검은 벨수록 닳아 부러진다. 열 구역을 올라 정상의 언덕지기를 쓰러뜨리면 끝.

- 엔진: Godot 4.6 (GDScript). 실행하면 마을(`scenes/lobby/lobby.tscn`)에서 시작한다. 북쪽 길에서 E를 누르면 언덕에 오른다.
- 기획: [docs/GDD.md](docs/GDD.md)
- Claude Code 작업 지침: [CLAUDE.md](CLAUDE.md)
- HTML 시험판: [prototype/geom_hill.html](prototype/geom_hill.html) (브라우저로 열면 바로 플레이, ` 키로 관리 패널)
- 테스트: `godot --headless --path . -s tests/run_all.gd`

이 저장소는 「총성」, 「영지」에서 이어진다. 옛 기획은 git 기록에 남아 있다.
