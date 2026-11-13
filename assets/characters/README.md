# 캐릭터

Mixamo(Adobe)에서 받은 모델과 동작을 둔다. Mixamo 약관상 원본 파일을 그대로 나눠 주면 안 되어서 git에 올리지 않는다(.gitignore). PC에서 받아 이 자리에 넣는다.

| 자리 | 무엇 | Mixamo에서 받는 법 |
| --- | --- | --- |
| `lord/paladin.fbx` | 영주 모델 (Paladin J Nordstrom) | 캐릭터 고르고 아무 동작이나, With Skin |
| `lord/anims/*.fbx` | 영주 동작 | 같은 캐릭터로 동작 고르고 Without Skin, In Place 체크(With Skin도 되지만 파일이 크고 켜는 게 느려진다) |

- 모델이 없으면 기본 도형 영주가 나온다.
- 동작은 파일 이름의 낱말로 고른다: idle, run, roll, impact/hit, death/dying, pull, slash/attack(이름에 great가 있으면 대검 베기). 베기는 여러 개 넣으면 번갈아 튼다. 없는 동작은 서 있기로 대신한다.
- Godot이 FBX를 읽으면서 `paladin_0.png` 같은 텍스처를 옆에 뽑아 둔다. 이것도 올리지 않는다.
