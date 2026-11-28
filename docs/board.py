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
FIRST_STEP = 15  # 현황판이 보는 첫 단계(11~14는 끝). 마지막 단계는 GDD 체크리스트에서 읽는다


def git_log(n: int = 60) -> list:
    env = dict(os.environ, TZ="Asia/Seoul")
    out = subprocess.run(
        ["git", "log", f"-{n}", "--pretty=%h\t%ad\t%s", "--date=format-local:%m-%d %H:%M"],
        cwd=ROOT, env=env, capture_output=True, text=True, check=True).stdout
    return [line.split("\t", 2) for line in out.splitlines() if line.count("\t") >= 2]


def read_steps() -> tuple:
    """GDD 체크리스트의 `- [x] N단계: 이름…`에서 (단계 번호 목록, 끝난 단계 집합, 단계 → 짧은 이름)을 읽는다."""
    steps, done, names = [], set(), {}
    for line in open(GDD, encoding="utf-8"):
        m = re.match(r"- \[(x| )\] (\d+)단계:?\s*(.*)", line)
        if not m or int(m.group(2)) < FIRST_STEP:
            continue
        n = int(m.group(2))
        steps.append(n)
        names[n] = re.split(r"[(.:,]", m.group(3), maxsplit=1)[0].strip() or f"{n}단계"
        if m.group(1) == "x":
            done.add(n)
    return steps, done, names


def team_done(log: list, prefixes: tuple, steps: list) -> dict:
    done = {}
    for h, _, subject in log:
        for n in steps:
            if re.match(rf"^({'|'.join(prefixes)}): {n}단계", subject):
                done.setdefault(n, h)
    return done


def fmt(ns: list) -> str:
    """단계 번호 목록을 짧게: 셋 이하면 나열, 더 많으면 `19~27단계`."""
    return ", ".join(f"{n}단계" for n in ns) if len(ns) <= 3 else f"{ns[0]}~{ns[-1]}단계"


def team_note(done: dict, checked: set, is_func: bool, steps: list, names: dict) -> tuple:
    finished = [n for n in steps if n in done or n in checked]  # 모양을 기능팀이 같이 맡은 절약판 단계도 끝으로 센다
    left = [n for n in steps if n not in finished]
    if not left:
        return "done", "끝: " + fmt(finished)
    parts = []
    if finished:
        parts.append("끝: " + (fmt(finished) if len(finished) > 3 else ", ".join(f"{n}단계({done.get(n, '')})".replace("()", "") for n in finished)))
    if is_func:  # 기능팀은 규칙 파일이 겹쳐서 하나씩 차례로
        parts.append(f"하는 중: {left[0]}단계 {names[left[0]]}")
        if left[1:]:
            parts.append("남음: " + fmt(left[1:]))
    else:  # 모양팀은 겹치지 않는 단계를 동시에
        parts.append("하는 중: " + fmt(left[:2]))
    return "doing", " · ".join(parts)


def js(s: str) -> str:
    return json.dumps(s, ensure_ascii=False)


def set_field(block: str, field: str, value: str) -> str:
    return re.sub(rf'({field}: )"(?:[^"\\]|\\.)*"', lambda m: m.group(1) + js(value), block, count=1)


def main() -> None:
    log = git_log()
    steps, checked, names = read_steps()
    look = team_done(log, ("모양팀", "이펙트팀"), steps)
    func = team_done(log, ("기능팀",), steps)
    look_status, look_note = team_note(look, checked, False, steps, names)
    func_status, func_note = team_note(func, checked, True, steps, names)
    left = [n for n in steps if n not in checked]
    now = datetime.now(timezone(timedelta(hours=9))).strftime("%Y-%m-%d %H:%M")
    ended = [n for n in steps if n in checked]
    stage = (f"지금 {left[0]}단계: {names[left[0]]}" if left else f"{steps[0]}~{steps[-1]}단계 끝") + \
        (f" · {ended[0]}~{ended[-1]}단계 끝" if ended else "") + \
        " (단계 목록은 GDD 3절, 설계서는 docs/)"
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
