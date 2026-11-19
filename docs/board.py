#!/usr/bin/env python3
"""팀 현황판(docs/team_board.html)의 STATE를 git 기록과 GDD 체크리스트로 다시 채운다.

쓰는 법(저장소 맨 위에서):  python3 docs/board.py
- 단계 진행: docs/GDD.md "3. 앞으로의 계획"의 `- [x] N단계` / `- [ ] N단계`
- 팀 진행: 커밋 제목 `모양팀: N단계 …`(예전 이름 아트팀·모션팀·이펙트팀도 센다), `기능팀: N단계 …`
- 기록: 최근 커밋 제목(현황판 커밋은 뺀다)
손으로 STATE를 고치지 않는다.
"""
import json
import os
import re
import subprocess
from datetime import datetime, timedelta, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BOARD = os.path.join(ROOT, "docs", "team_board.html")
GDD = os.path.join(ROOT, "docs", "GDD.md")
STEPS = [15, 16]  # 지금 팀으로 돌리는 단계(11~14는 끝)
NAMES = {11: "적 행동", 12: "밤 목표·구역 규칙", 13: "낮 사건·갈림길", 14: "뽑기 손맛", 15: "마을 컨텐츠", 16: "마을 밖 들판"}


def git_log(n: int = 60) -> list:
    env = dict(os.environ, TZ="Asia/Seoul")
    out = subprocess.run(
        ["git", "log", f"-{n}", "--pretty=%h\t%ad\t%s", "--date=format-local:%m-%d %H:%M"],
        cwd=ROOT, env=env, capture_output=True, text=True, check=True).stdout
    return [line.split("\t", 2) for line in out.splitlines() if line.count("\t") >= 2]


def checked_steps() -> set:
    done = set()
    for line in open(GDD, encoding="utf-8"):
        m = re.match(r"- \[(x| )\] (\d+)단계", line)
        if m and m.group(1) == "x":
            done.add(int(m.group(2)))
    return done


def team_done(log: list, prefixes: tuple) -> dict:
    done = {}
    for h, _, subject in log:
        for n in STEPS:
            if re.match(rf"^({'|'.join(prefixes)}): {n}단계", subject):
                done.setdefault(n, h)
    return done


def team_note(done: dict, checked: set, is_func: bool) -> tuple:
    finished = [n for n in STEPS if n in done or (is_func and n in checked)]
    left = [n for n in STEPS if n not in finished]
    if not left:
        return "done", "끝: " + ", ".join(f"{n}단계" for n in finished)
    parts = []
    if finished:
        parts.append("끝: " + ", ".join(f"{n}단계({done.get(n, '')})".replace("()", "") for n in finished))
    if is_func:  # 기능팀은 규칙 파일이 겹쳐서 하나씩 차례로
        parts.append(f"하는 중: {left[0]}단계 {NAMES[left[0]]}")
        if left[1:]:
            parts.append("남음: " + ", ".join(f"{n}단계" for n in left[1:]))
    else:  # 모양팀은 겹치지 않는 단계를 동시에
        parts.append("하는 중: " + ", ".join(f"{n}단계" for n in left))
    return "doing", " · ".join(parts)


def js(s: str) -> str:
    return json.dumps(s, ensure_ascii=False)


def set_field(block: str, field: str, value: str) -> str:
    return re.sub(rf'({field}: )"(?:[^"\\]|\\.)*"', lambda m: m.group(1) + js(value), block, count=1)


def main() -> None:
    log = git_log()
    checked = checked_steps()
    look = team_done(log, ("모양팀", "이펙트팀"))
    func = team_done(log, ("기능팀",))
    look_status, look_note = team_note(look, checked, False)
    func_status, func_note = team_note(func, checked, True)
    left = [n for n in STEPS if n not in checked]
    now = datetime.now(timezone(timedelta(hours=9))).strftime("%Y-%m-%d %H:%M")
    stage = (f"지금 {left[0]}단계: {NAMES[left[0]]}" if left else f"{STEPS[0]}~{STEPS[-1]}단계 끝") + \
        " · " + " / ".join(f"{n} {'끝' if n in checked else NAMES[n]}" for n in STEPS) + \
        " (설계서 docs/village.md)"
    lead_note = "모양팀이 먼저(겹치지 않는 단계는 동시에), 기능팀이 차례로 잇는다. 단계가 끝나면 테스트·화면 확인·푸시."
    entries = [[d, s] for h, d, s in log if "현황판" not in s][:25]

    html = open(BOARD, encoding="utf-8").read()
    a = html.index("const STATE = {")
    b = html.index("\n};", a)
    state = html[a:b]
    state = set_field(state, "stage", stage)
    state = set_field(state, "updated", now)
    lead_a = state.index("lead: {")
    lead_b = state.index("},", lead_a)
    lead = state[lead_a:lead_b]
    lead = set_field(set_field(lead, "status", "done" if not left else "doing"), "note", lead_note)
    state = state[:lead_a] + lead + state[lead_b:]
    for key, status, note in (("look", look_status, look_note), ("func", func_status, func_note)):
        ta = state.index(f'{{ key: "{key}"')
        tb = state.find("{ key:", ta + 5)
        tb = state.index("\n  ],", ta) if tb < 0 else tb
        block = set_field(set_field(state[ta:tb], "status", status), "note", note)
        state = state[:ta] + block + state[tb:]
    la = state.index("  log: [")
    lb = state.index("\n  ]", la)
    rows = ",\n".join(f"    [{js(d)}, {js(s)}]" for d, s in entries)
    state = state[:la] + "  log: [\n" + rows + state[lb:]
    open(BOARD, "w", encoding="utf-8").write(html[:a] + state + html[b:])
    print(f"현황판: {stage}\n  모양팀 {look_status}: {look_note}\n  기능팀 {func_status}: {func_note}")


if __name__ == "__main__":
    main()
