# 캐릭터

Mixamo(Adobe)에서 받은 모델과 동작을 둔다. Mixamo 약관상 원본 파일을 그대로 나눠 주면 안 되어서 git에 올리지 않는다(.gitignore). PC에서 받아 이 자리에 넣는다.

| 자리 | 무엇 | Mixamo에서 받는 법 |
| --- | --- | --- |
| `lord/paladin.fbx` | 영주 모델 (Paladin J Nordstrom) | 캐릭터 고르고 아무 동작이나, With Skin |
| `lord/anims/*.fbx` | 영주 동작 | 같은 캐릭터로 동작 고르고 Without Skin, In Place 체크(With Skin도 되지만 파일이 크고 켜는 게 느려진다) |

- 모델이 없으면 기본 도형 영주가 나온다.
- 동작은 파일 이름의 낱말로 고른다: idle, run, roll, impact/hit, death/dying, pull, slash/attack(이름에 great가 있으면 대검 베기). 베기는 여러 개 넣으면 번갈아 튼다. 없는 동작은 서 있기로 대신한다.
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
