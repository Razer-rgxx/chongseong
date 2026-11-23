# 칼 모델(최고 등급 몇 자루)

`tools/blender/make_swords.py`가 만든다(도구는 make_heads.py를 빌린다). PC의 chongseong 폴더에서 한 번:

```
"C:\Program Files\Blender Foundation\Blender 4.2\blender.exe" -b -P tools\blender\make_swords.py
```

`<칼 번호>.glb`가 생기고, `SwordModel`은 그 번호의 파일이 있으면 코드 모양 대신 그것을 쓴다(없으면 예전 모양).
지금: 292 환도, 296 카타나, 290 레이피어, 294 몰락한 왕의 부러진 대검, 291 플랑베르주, 289 그림자 왕의 단검.
약속: 코등이가 원점, 칼날 +Z(Godot +Y), 날 ±X. glow_·ghost_ 재질은 게임이 등급 빛깔로 바꾼다.
