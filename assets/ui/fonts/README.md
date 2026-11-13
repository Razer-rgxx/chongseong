# 글꼴

`NotoSerifKR-subset.ttf`는 Noto Serif KR(가변 굵기, SIL OFL 1.1, `OFL.txt`)에서 자주 쓰는 한글 2350자(KS X 1001), 영문·숫자·기호, 그리고 저장소의 표와 코드에 나오는 글자만 남긴 것이다(2.5MB).

- 테마는 `assets/ui/theme.tres`다(프로젝트 설정 gui/theme/custom). 본문 굵기 600, 굵은 글씨 800. `godot --headless --path . -s scripts/debug/build_theme.gd`로 다시 만든다.
- 굵기는 FontVariation의 `variation_opentype`에 숫자 태그 `2003265652`(wght)로 준다. 문자열 "wght"는 먹지 않는다.
- 없는 글자가 나오면 Godot이 시스템 글꼴로 대신 그린다. 그럴 땐 원본(https://github.com/google/fonts/tree/main/ofl/notoserifkr)으로 다시 만든다:

```
pip install fonttools
python -m fontTools.subset "NotoSerifKR[wght].ttf" --text-file=chars.txt --layout-features=* --notdef-outline --output-file=NotoSerifKR-subset.ttf
```

`chars.txt`에는 위의 글자들을 넣는다(2350자는 `len(c.encode('euc-kr')) == 2`인 한글 음절).
