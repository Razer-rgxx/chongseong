# 일감: 네온 시가 건물을 Blender로 짓기 (PC의 Claude Code에게, 2026-11-25)

사용자: "시간 좀 걸려도 도시는 블렌더로", "클로드코드한테 맡겨서". 클라우드 세션은 Blender를 못 돌려서(망 막힘, bpy 없음) 이 PC에서 한다.
참고 그림: 사이버펑크 2077 같은 밤 도시(빽빽한 고층, 켜진 창 벽, 네온 줄, 큰 광고 화면, 젖은 길, 하늘을 나는 차). **분위기만** 따른다(그 게임의 간판·상표·글자는 넣지 않는다).

## 지금 상태 (먼저 읽을 것)
- `docs/neon_city.md`: 네온 시가가 무엇인지. 구역 180×110칸, 옛 폐허(`FutureLayout.OLD`) 동쪽·남쪽의 블록 격자.
- `scripts/future/future_layout.gd`: `X_SPANS`·`Y_SPANS`·`PLAZAS`·`neon_blocks()`(블록 = 키 큰 막힘 하나). **자리와 막힘은 바꾸지 않는다**(테스트 `tests/neon_tests.gd`가 본다).
- `scripts/future/neon_district.gd`: 지금은 블록을 9~15m 조각(`_cuts`)으로 나눠 **Kenney City Kit 건물**(`FutureBuilder.BLD_MODELS`)을 늘려 세운다(`_building`). 늘린 Kenney는 창이 늘어나 보여서 셰이더 격자 창(`kit_building.gdshader`의 `grid_lit`)으로 덮었다. 네온 줄·광고판·지붕 등·하늘길 차·광장 홀로그램은 셰이더(`assets/future/neon_*.gdshader`)로 따로 붙인다 — 이것들은 그대로 둔다.
- 비슷한 일을 한 Blender 스크립트: `tools/blender/make_cyber_swords.py`, `make_heads.py`(재질 `mat`, 굽기, `finish`가 glb로 내고 `glb_icc.strip_glb`로 ICC 프로필을 뺀다 — Blender 5.x JPEG를 Godot 4.6이 못 읽는 문제).
- Blender: `C:\Program Files\Blender Foundation\Blender 5.3\blender.exe`.

## 할 일
1. `tools/blender/make_city.py`를 새로 쓴다(bmesh로 직접, 코드로만 짓는다. AI 생성 에셋 금지, 바깥 모델 안 씀).
   - 고층 건물 **18~24종**을 실제 크기(m)로: 발자국 10·12·14m(가로·세로 섞어서), 높이 20~120m 여러 단.
   - 모양 다양하게: 받침층(가게층) + 몸통 + 층층이 들어간 윗부분(setback), 모서리 깎기, 팔각·둥근 탑 몇, 쌍둥이 탑, 다리로 이은 것 하나쯤.
   - 붙는 것: 층 띠·처마, 발코니 줄, 실외기·물탱크·안테나(꼭대기 붉은 등은 빛 재질), 헬기장 하나쯤, 바깥 배관, 가게층 유리(따뜻한 빛)와 차양, 건물 모서리·층 띠의 네온 줄(청록·자홍·호박·보라·연두, 빛 재질).
   - 창: 벽 질감에 창 격자(창 한 칸 가로 2.4m × 세로 3.4m를 UV에서 m 단위로 맞춰 반복) + 빛 질감(켜진 창 30%쯤, 따뜻한·차가운·분홍 섞어서, 층 무리마다 켜짐 다르게). 질감 1K, 2~3벌 돌려 쓰기. 늘리지 않아도 되게 실제 크기로 지으니 창이 늘어나지 않는다.
   - **세계에 글자 없음**(간판·광고에 글자 금지). 큰 광고 화면 자리는 비워 둔다(게임의 `neon_board.gdshader`가 움직이는 도형을 그린다) — 각 건물의 광고판 붙일 자리(면, 높이, 크기)를 glb 노드 이름이나 별도 json으로 남기면 좋다.
   - 가볍게: 한 채 정점 2만 아래, 재질은 몇 개로 묶기(벽·쇠·유리·빛 색들). 원점은 발자국 가운데 바닥, +Y 위(Godot 기준).
   - 결과: `assets/future/models/neon_city/<이름>.glb` + `index.json`(이름 → 발자국 w·d, 높이 h, 광고판 자리들).
   - 한 줄로 돈다: `blender -b -P tools\blender\make_city.py [-- 이름 ...]`
2. `NeonDistrict._building`이 `index.json`을 읽어 **발자국·높이가 가장 가까운 Blender 건물**을 고르고(늘리기는 ±15% 안), 없으면 지금처럼 Kenney로 돌아간다. 블록을 꽉 채우는 것은 지켜야 한다(블록 전체가 막힘이라 빈틈이 보이면 안 된다: 조각 크기를 건물 발자국에 맞춰 자르거나 받침층을 블록 둘레로 이어 붙인다). Blender 건물이 제 재질을 쓰면 `grid_lit` 덮기는 끈다. 광고판·네온 줄은 index.json의 자리를 쓰고, 없으면 지금 방식.
3. 둘레 먼 건물(`FutureBuilder._skyline`)도 Blender 건물 낮은 단계(또는 같은 것)로.
4. 확인: `godot --headless --path . -s tests/run_all.gd`(다 통과), 미래 구역에 들어가 네온 시가를 돌아보고(관리 콘솔 ` → `미래`·`시대 미래`) 길·광장·위에서 본 그림을 `scripts/debug/shots/`에 확인용 스크립트로 남긴다. 프레임이 너무 떨어지면 줄인다(웹판도 돈다: `WebQuality`).
5. `CREDITS.md`(직접 지은 것이라 "코드로 지음"), `docs/neon_city.md`, `CLAUDE.md`의 네온 시가 줄, `docs/GDD.md` "1. 지금까지 한 일"에 한 줄.
6. 커밋하고 `geom-hill`에 올린다. 그다음 웹판: `python docs/web_build.py <godot 실행 파일> <폴더>` → 그 폴더를 `gh-pages` 가지에 올린다(https://razer-rgxx.github.io/chongseong/). 올리기 전에 pck 안에 사용자 키 파일(`user://gdsync_keys.cfg`의 내용)이 없는지 본다(`addons/GD-Sync/keys.cfg`는 플러그인이 넣는 것으로, 정식 출시 때 사용자가 정하기로 함).

## 지킬 것 (CLAUDE.md에도 있다)
- 커밋 메시지 끝에 사용자 이메일을 넣지 않는다. 비밀 키를 화면·채팅·커밋에 내지 않는다.
- 세계(3D)에 글자를 띄우지 않는다(피해 숫자만). 종소리·올라가는 삐 소리·위로 쓸어 올리는 소리는 넣지 않는다.
- 규칙(막힘·무리 자리)은 건드리지 않는다. 화면 쪽만 바꾼다.
- 사용자에게는 한국어로 짧게 정리한다.
