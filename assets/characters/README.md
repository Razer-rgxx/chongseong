# 캐릭터

Mixamo(Adobe)에서 받은 모델과 동작을 둔다. Mixamo 약관상 원본 파일을 그대로 나눠 주면 안 되어서 git에 올리지 않는다(.gitignore). PC에서 받아 이 자리에 넣는다.

| 자리 | 무엇 | Mixamo에서 받는 법 |
| --- | --- | --- |
| `lord/paladin.fbx` | 영주 모델 (Paladin J Nordstrom) | 캐릭터 고르고 아무 동작이나, With Skin |
| `lord/anims/*.fbx` | 영주 동작 | 같은 캐릭터로 동작 고르고 Without Skin, In Place 체크(With Skin도 되지만 파일이 크고 켜는 게 느려진다) |

| `enemies/<적 id>.fbx` | 적 모델(24단계, 고를 수 있음) | 캐릭터 고르고 아무 동작이나, With Skin. 동작은 영주의 것(`lord/anims/`)을 같이 쓴다 |

- 모델이 없으면 기본 도형 영주가 나온다.
- 동작은 파일 이름의 낱말로 고른다: idle, run, roll, impact/hit, death/dying, pull, slash/attack(이름에 great가 있으면 대검 베기). 베기는 여러 개 넣으면 번갈아 튼다. 없는 동작은 서 있기로 대신한다.
- 점프(30단계, Space): 이름에 `hop`이 있는 동작을 걸어 다니는 점프에 쓴다(Mixamo 검색어 jump · hop, Without Skin, In Place). `jump`는 도약 내려찍기 낱말이라 받은 파일 이름에서 빼고 `hop`을 넣는다(예: `Jump.fbx` → `Hop.fbx`). 없으면 뛰기 전 동작을 멈춰 두고 다리를 코드로 접는다.
- Godot이 FBX를 읽으면서 `paladin_0.png` 같은 텍스처를 옆에 뽑아 둔다. 이것도 올리지 않는다.

## 동작별로 받으면 좋은 것

좌클릭 동작 20가지(docs/attacks.md)는 지금 있는 동작만으로도 돈다. `MoveMotion`(scripts/lord/move_motion.gd)이 베기 두 개(Sword And Shield Slash, Slash2)의 알맞은 구간을 골라 틀거나 한 순간에 멈춰 세우고, 코드로 돌기·뛰기·기울기·웅크리기를 얹는다. 아래 동작을 받아 넣으면 그 동작을 먼저 쓴다.

- 검색어는 Mixamo 검색창에 넣을 낱말이다. 정확한 제목이 아니니 나온 것 중 한 손 칼에 맞는 것을 고른다. 받는 법은 위와 같다(같은 캐릭터, Without Skin, In Place).
- 파일 이름에 "파일 이름 낱말"을 넣는다. 이름에 `slash`나 `attack`이 있으면 베기로 먼저 읽히니 그 낱말은 빼고 바꾼다(예: `Great Sword Jump Attack.fbx` → `Great Sword Leap.fbx`).
- 칼이 맞는 때는 `MoveMotion.EXTRA`에 동작 길이의 비율로 적어 두었다. 받은 동작에서 칼이 늦거나 이르게 맞아 보이면 그 값을 고친다.

| 동작 | Mixamo 검색어 | 파일 이름 낱말 | 없으면 |
| --- | --- | --- | --- |
| 횡베기 `sweep` | (받을 것 없음) | | Slash2의 첫 베기(오른쪽→왼쪽)와 둘째 베기(왼쪽→오른쪽)를 연타마다 번갈아 |
| 찌르기 `thrust` | stab, sword thrust | `stab` 또는 `thrust` | Slash2에서 앞무릎을 굽혀 칼끝이 곧게 앞을 보는 순간에 멈추고 몸을 앞으로 내민다 |
| 올려베기 `rising` | (받을 것 없음) | | Slash(왼 어깨에서 오른쪽 위로) + 발끝으로 조금 솟기 |
| 연속 찌르기 `flurry` | stab | `stab` | 찌르기 자세에 멈추고 몸을 네 번 내밀었다 당긴다 |
| 반월 `crescent` | (받을 것 없음) | | Slash2 첫 베기 + 몸을 감았다 크게 푸는 비틀기 |
| 물러나 베기 `retreat` | dodge back, step back | `dodge` | 베기 + 코드로 뒤로 낮게 뛰기 |
| 끌어당기기 `pull` | (받을 것 없음) | | Slash2 되베기 + 앞으로 뻗었다 홱 당기기 |
| 내려찍기 `smash` | ground slam, downward slash | `slam` | Slash2 끝의 뛰어 내려찍기를 빠르게 |
| 회전베기 `spin` | spin attack | `spin` | 베기 + 코드로 제자리 한 바퀴 |
| 돌진베기 `lunge` | (받을 것 없음) | | 베기 + 낮게 숙여 미끄러지기 |
| 검기 `wave` | (받을 것 없음) | | 베기 + 몸을 앞으로 싣기 |
| 칼 던지기 `boomerang` | throw | `throw` | Slash2 되베기(원반 던지듯) |
| 도약 내려찍기 `leap` | jump attack, sword jump | `leap` 또는 `jump` | Slash2 끝의 뛰어 내려찍기 + 코드로 높이 뜨기, 내려앉기 |
| 발도 `iaido` | draw sword | `draw` | Slash의 칼을 감은 순간에 멈췄다가 빠르게 베기, 웅크리고 숙이기 |
| 십자 베기 `cross` | (받을 것 없음) | | Slash2의 두 베기를 빠르게 이어 X |
| 지진 `quake` | ground slam | `slam` | Slash2 내려찍기 끝의 웅크린 자세에 멈춰 버티기 |
| 소용돌이 `whirl` | (받을 것 없음) | | Slash2에서 칼을 옆으로 뻗은 순간에 멈추고 코드로 0.3초에 한 바퀴 |
| 순간 베기 `blink` | (받을 것 없음) | | 베기 + 지나온 쪽을 보던 몸을 홱 돌리기 |
| 갈고리 베기 `hook` | (받을 것 없음) | | 구르기(Stand To Roll)로 공중제비 + 닿으면 베기 |
| 반격 자세 `parry` | sword block, parry | `block` 또는 `parry` | Slash에서 칼을 세워 몸 앞에 든 순간에 멈춘다 |

## 적 모델 (24단계)

받을 것은 없다. 적은 모두 이미 모양이 있다(망령 망토, 늑대, 새 적 5종의 EnemyArt, 거인·언덕지기·무덤 기사·무덤 주인·방패병은 영주 기사). 

다른 사람 모델로 바꾸고 싶을 때만(고를 수 있음) 적마다 Mixamo 캐릭터 하나를 `enemies/<적 id>.fbx`로 넣으면 그 적은 그 모델로 서고, 영주의 동작(서기·걷기/달리기·베기·맞기·쓰러짐)을 같이 쓴다. 눈은 머리 뼈에 붙어 빛나고, 정예는 금빛이 돈다. 파일이 없는 적은 지금 모양 그대로다.

- 받는 법: Mixamo에서 캐릭터를 고르고 아무 동작이나 골라 Download → Format FBX, **With Skin**. 받은 파일 이름을 아래 id로 바꿔 `assets/characters/enemies/`에 넣는다. 같은 모델을 두 적에 쓰려면 파일을 복사해 이름만 바꾼다.
- 캐릭터 이름은 Mixamo Characters 탭에서 찾을 이름이다. 없으면 비슷한 어두운 것을 고른다(어두운 사실풍, 만화풍은 피한다).
- 늑대(`wolf`)와 허수아비(`dummy`)는 사람형이 아니라 바꾸지 않는다.

| id | 적 | 추천 캐릭터 | 크기 |
| --- | --- | --- | --- |
| `wraith` | 망령 | Skeletonzombie T Avelange | 사람 크기 |
| `archer` | 활잡이 | Erika Archer | 사람 크기 |
| `shield` | 방패병 | Knight D Pelegrini | 지금 방패병 크기, 방패는 그대로 왼팔에 |
| `charger` | 돌격병 | Warzombie F Pedroso | 사람 크기 |
| `bomber` | 자폭병 | Parasite L Starkie | 사람 크기 |
| `caller` | 부르는 자 | Nightshade J Friedrich | 사람 크기 |
| `giant` | 거인 | Mutant | ×1.85 |
| `boss` | 언덕지기 | Maw J Laygo | ×2.5 |
| `grave_knight` | 무덤 기사(들판 보스) | Knight D Pelegrini 또는 Paladin | 표의 `model_scale` |
| `crypt_lord` | 무덤 주인 | Vampire A Lusth | 표의 `model_scale` |

알아 둘 것
- 활잡이·돌격병·자폭병·부르는 자는 제 모델을 넣으면 EnemyArt의 전용 모양과 자세(겨누기, 머리 낮추기, 심지)가 빠지고 걷기·베기·맞기·쓰러짐으로 움직인다(활잡이는 왼손에 활, 부르는 자는 오른손에 지팡이). 효과는 그대로다. 어색하면 그 파일만 빼면 된다.
- 모델마다 뼈 이름이 `mixamorig:`로 시작해야 영주 동작이 붙는다(Mixamo 캐릭터는 다 그렇다). 동작이 안 붙고 T자로 서면 그 모델은 빼고 알려 준다.
- 너무 밝거나 어두우면 `EnemyView._build_knight`의 `mul`(제 모델용 줄)을 고친다.

## 마을 사람 (2026-11-21)

`npc/`에 넣으면 마을 사람·주민·걷는 사람·포로·건물 안 사람이 기본 도형 대신 이 모델로 선다(`NpcModel`). 없으면 지금 모양 그대로다.

| 자리 | 무엇 | Mixamo |
| --- | --- | --- |
| `npc/man.fbx` | 남자 모델 | Peasant Man, With Skin |
| `npc/girl.fbx` | 여자 모델(약초꾼·상인·채집꾼·주민 일부) | Peasant Girl, 아무 동작이나 With Skin |
| `npc/anims/idle.fbx` | 서 있기 | Idle |
| `npc/anims/talk.fbx` | 말하기 | Talking |
| `npc/anims/walk.fbx` | 걷기(제자리) | Walking, In Place |
| `npc/anims/kneel.fbx` | 무릎 꿇기(들판의 포로) | Kneeling Idle |
| `npc/anims/pray.fbx` | 빌기(성소지기) | Praying |
| `npc/anims/sit.fbx` | 앉아 있기(아직 안 씀) | Sitting Idle |
