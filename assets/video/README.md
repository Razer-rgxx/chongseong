# 뽑기 연출 영상

전설 이상을 뽑으면 등급에 맞는 영상이 있으면 화면 가득 튼다(`Hud.play_video`). 없으면 땅에서 나오는 연출(`PullFx`)만 나온다.

| 파일 | 등급 |
| --- | --- |
| `grade_2.ogv` | 전설 |
| `grade_3.ogv` | 신화 |
| `grade_4.ogv` | 초월 |
| `grade_5.ogv` | 무한 |

- 형식은 Ogg Theora(.ogv). 다른 형식은 Godot가 못 튼다. 바꾸는 법: `ffmpeg -i 녹화.mp4 -c:v libtheora -q:v 7 -c:a libvorbis -q:a 5 grade_2.ogv`
- 연출 중에는 글자를 띄우지 않는다. 영상이 끝나면 칼 이름을 알리고, 두 칸이 차 있으면 그때 고르기 창이 열린다.
