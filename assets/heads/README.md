# 머리 모델(Heads)

`tools/blender/make_heads.py`가 만든다. PC의 chongseong 폴더에서 한 번:

```
set PATH=%PATH%;C:\Program Files\Blender Foundation\Blender 5.3
blender -b -P tools\blender\make_heads.py
blender -b -P tools\blender\make_heads.py -- tomb        (하나만 다시)
```

모양 11개(hill, wolf, tower, boulder, shield, marsh, pick, burnt, raven, grave_helm, tomb)가 `<모양>.glb`로 생긴다.
있으면 `ObjectHead.build`가 그것을 쓰고, 없으면 예전 기본 도형으로 그린다. 재질 이름 앞머리 `metal_`·`glow_`로 게임이 바탕색과 빛 색을 바꾼다.
직접 다듬어도 된다: 같은 이름, 바닥 가운데 원점, 얼굴은 Blender의 -Y, 높이 0.35~0.55m.

2026-11-23: Blender 5.3으로 만들었다. 무덤(tomb)은 처음에 묘비가 빠져(겹친 몸을 join한 뒤 불리언) 스크립트를 `merge`(합집합)로 고쳐 다시 만들었다.
Blender 5.x가 JPEG에 붙이는 ICC 색 프로필은 Godot 4.6이 못 읽어서 `tools/blender/glb_icc.py`가 뺀다(내보낼 때 스스로).
