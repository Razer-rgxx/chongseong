# 소리

itch.io의 무료 팩에서 골라 다듬은 소리(모노 44.1kHz, 앞의 빈 곳 자름, 크기 맞춤)를 이름별 폴더에 둔다. 폴더 안의 파일 중 하나를 골라 높낮이를 조금 흔들어 튼다(`Sfx`). 폴더가 없으면 코드로 만든 소리로 대신한다.

공개 저장소에는 올리지 않는다(.gitignore). 팩에 약관 문구가 없어서다. 출처는 CREDITS.md에 있다.

| 폴더 | 언제 | 원본 |
| --- | --- | --- |
| swish | 휘두르기 | Gravity Sound, Sword_* |
| swish_big | 크게 휘두르기(마지막 타, 대검) | Gravity Sound, Heavy_Swing_Weapon_* |
| grunt | 크게 휘두를 때 기합 | Hove Audio, Action Grunts |
| dash | 구르기 | Hove Audio, Whooshes |
| hit | 적을 벰 | Hove Audio, Sword Stabs |
| hit_big | 크게 벰 | Hove Audio, Sword Stabs w/ Gore |
| hit_flesh | 베기에 겹치는 살 소리(늑대, 정예 등). 맨손은 이것만 | Gravity Sound, Axe_* |
| hit_heavy | 거인·언덕지기와 크게 벨 때 겹치는 묵직한 소리 | Gravity Sound, Shield_Bash_* |
| hurt | 영주가 맞음 | Hove Audio, Damage Grunts |
| thump | 뽑을 때 땅이 울림, 대장간 실패 | Gravity Sound, Staff_Bash_* |
| anvil | 망치질, 숫돌 제단 | Gravity Sound, Weapon_Clash_* |
| draw | 검을 뽑아 듦 | Gravity Sound, Equip_* |
| break | 검이 부러짐 | Gravity Sound, Drop_Weapon_* |
| enemy_block | 적이 칼로 막음 | Gravity Sound, Weapon_Clash_7·8·9 |
| enemy_break | 적의 자세가 무너짐 | Gravity Sound, Flail_1·2·3 |
| enemy_arrow_cut | 날아오는 화살을 벰 | Gravity Sound, Light_Swing_Weapon_3·4·8 |
| smith_use | 대장장이를 씀(망치질) | Hove Audio, Sword Collisions/Base Metal 03·06 |

새 넷(enemy_*, smith_use)은 앞의 빈 곳을 자르고 뒤를 빨리 줄여 쇠 울림이 종소리처럼 남지 않게 했다(모노 44.1kHz).

나머지(night, land, enemy_bow·arrow_hit·arrow_ground·hoof·skid·fuse·boom·call, 밤 사건 소리들)는 아직 코드로 만든 소리다.

주의: 파일은 `assets/sound/<이름>/` 바로 아래에 있어야 한다. `assets/sound/sound/<이름>/`처럼 한 단계 더 들어가면 못 찾고 코드 소리를 낸다(2026-11-20에 그래서 옮겼다).
