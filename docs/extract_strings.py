"""화면 글자 뽑기(2026-11-20 리뷰: 번역 구조). python3 docs/extract_strings.py
scripts/ 아래 .gd와 data/ 아래 .tres에서 한글이 든 문자열을 모아 locale/strings.csv를 만든다(이미 있는 번역 칸은 지킨다).
첫 칸 keys = 한국어 원문 그대로(Godot가 Label·Button 글자를 이 열쇠로 자동 번역한다), ko = 원문, en = 영어(비어 있으면 원문이 나온다).
값을 끼우는 글(%d, %s)은 원문 틀이 열쇠다: 코드에서 tr("…%d…") % 값 으로 쓰면 번역된다(아직 tr로 감싸지 않은 곳은 한국어로 남는다).
"""
import csv, os, re, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "locale", "strings.csv")
HANGUL = re.compile(r"[가-힣]")
LIT = re.compile(r'"((?:[^"\\\n]|\\.)*)"')

def strings():
    seen = []
    for base, exts in (("scripts", (".gd",)), ("data", (".tres",)), ("scenes", (".tscn",))):
        for dp, _, fs in os.walk(os.path.join(ROOT, base)):
            if "/debug" in dp.replace("\\", "/"):
                continue
            for f in sorted(fs):
                if not f.endswith(exts):
                    continue
                for line in open(os.path.join(dp, f), encoding="utf-8"):
                    s = line.strip()
                    if s.startswith("#"):
                        continue
                    code = line.split("##")[0] if f.endswith(".gd") else line
                    for m in LIT.finditer(code):
                        t = m.group(1)
                        if HANGUL.search(t) and t not in seen:
                            seen.append(t)
    return seen

def main():
    old = {}
    if os.path.exists(OUT):
        for row in csv.DictReader(open(OUT, encoding="utf-8")):
            old[row["keys"]] = row
    rows = strings()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="") as fp:
        w = csv.writer(fp)
        w.writerow(["keys", "ko", "en"])
        for t in rows:
            key = t.replace("\\n", "\n").replace('\\"', '"')
            w.writerow([key, key, old.get(key, {}).get("en", "")])
    done = sum(1 for t in rows if old.get(t.replace("\\n", "\n"), {}).get("en"))
    print(f"글 {len(rows)}개 · 영어 {done}개 → {OUT}")

if __name__ == "__main__":
    main()
