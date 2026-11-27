# 마을 소품 모델 (2026-11-27)

사용자 요청: "마을 오브젝트들 좀 코드로 만든 티 안나게". 기본 도형(상자·원통)이던 소품을 Blender 스크립트 모델로 바꿨다. 집(KitHouse, Quaternius)은 이미 모델이라 그대로다.

## 만드는 법
- `blender -b -P tools/blender/make_village.py [-- 이름 ...]` → `assets/village/models/<이름>.glb` (26개, 합 4.4MB, 삼각형 100~10000).
- 모든 모양은 Godot 좌표(Y 위, 앞 +Z)로 짓고 마지막에 Blender 좌표로 바꾼다. 모서리는 깎고(Bevel), 길이 방향으로 휘고 비틀며(잡음 변형), 돌은 잡음으로 민 공, 통은 휜 널 열여섯 장, 지붕은 겹쳐 올린 널, 천은 처진 격자.
- 질감은 굽지 않는다. 재질은 이름만 싣는다(wood·plank·log·logend·stone·stone_dark·roof·iron·steel·brass·rope·sack·straw·cloth·cloth_gold·cloth_red·paper·leather·wicker·dirt·burnt·water·mirror·glow·ember). UV는 1 = 1m. 꼭짓점 색(COLOR_0)에 땅 쪽 어둡기와 얼룩이 들어 있다.
- 게임의 `VillageModels`(scripts/lobby/village_models.gd)가 이름마다 `assets/village/`·`assets/hill/`의 Poly Haven(CC0) 질감을 입힌다(표 `TABLE`). 새 질감은 없다. `put(parent, 이름, 자리, 방향, 크기, {재질: 색})`.

## 바꾼 곳
| 모델 | 쓰는 곳 |
| --- | --- |
| barrel, crate, hay, firewood, bench, well, stall, lantern, torch | `VillageBuilder.barrel/crate/hay/firewood/bench/well/stall/lantern/torch` |
| palisade_a·b·c, palisade_rail | `VillageBuilder.palisade`(MultiMesh 셋 + 가로대 토막) |
| board, fence_unit, fence_end, scarecrow, sword_rack, duel_post, mirror, cart | `VillageProps.board/yard/duel_post/mirror/cart` |
| forge_shed, forge_furnace, anvil, grindstone, blades | `lobby._build_forge` |

## 약속
- glb가 없으면 예전 기본 도형으로 돌아간다(`VillageModels.available`).
- 막힘 표·자리·크기·발자국은 그대로다. 꾸밈용 rng의 부름 수도 같게 맞췄다(`VillageBuilder._burn`).
- 수련장 울타리는 서쪽 틈에서 가로대도 끊긴다(예전엔 가로대가 틈을 가로질렀다).
- 못 바꾼 것: 마을 문(`_build_gate`)·성소(`_build_shrine`)·검 진열대 지붕(`_build_rack`)·돌담(`stone_wall`)의 돌 상자, 집 안 가구(Interior), 주민 몸.
- 확인: `scripts/debug/shots/shot_village2.gd -- before|after`(마을 아홉 자리), `shot_village2_models.gd -- 이름 ...`(모델 하나씩).
