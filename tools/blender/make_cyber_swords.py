# 사이버 검 무한 열두 자루(312~511 중 grade 5, docs/cyber_swords.md)를 Blender로 짓고 .glb로 내보낸다. (2026-11-25)
#
# 한 번(chongseong 폴더에서): Blender가 있으면
#   blender -b -P tools/blender/make_cyber_swords.py [-- 칼번호 ...]
# 없으면 pip로 bpy 모듈을 깔아(python 3.13, `pip install bpy`) 같은 파일을 그냥 돌려도 된다:
#   python tools/blender/make_cyber_swords.py [칼번호 ...]
# 결과: assets/swords/<칼 번호>.glb (질감 512). 게임(SwordModel → CyberModel)은 그 번호의 파일이 있으면 코드 모양 대신 그것을 쓴다.
# 사이버 카타나(311)의 재질과 도구(make_swords.py)를 빌린다: 짙은 건메탈, 청록 네온(glow_kat_*), 베벨 노멀.
#
# 약속(SwordModel과): 코등이가 원점, 칼날은 +Z(Godot +Y), 손잡이는 -Z, 날은 ±X. 칼 두께는 Y이고 총열과 탄창은 +Y쪽(Godot -Z)이다.
# 칼날 길이는 형태 표를 따른다: 단검 0.55, 장검 1.10, 대검 1.61, 세검 1.42(m). 손잡이 길이는 CyberModel.SHAPE의 grip과 같다.
# 모든 무한이 총검이다: 칼날 밑 총열(끝에 청록 총구 고리), 코등이 뒤 탄창 덩이, 날을 따라 청록 빛 줄, 방열창, 등의 레일.

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_swords as MS   # noqa: E402  (도구와 재질을 빌린다. 이 파일은 make_swords를 돌리지 않는다)
import make_heads as K     # noqa: E402

bpy = MS.bpy
OUT = MS.OUT
SIZE = 512


def _sm(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


# 칼 번호 → 모양(name은 게임 안의 이름). L 칼날 길이, W 반너비, T 반두께, curve 휨(m), single 외날, tip 칼끝 구간, flare 끝이 넓어짐, grip 손잡이 길이,
# guard 코등이 종류, 나머지는 덧붙이는 부품.
SPECS = {
    "384": dict(name="무음의 송곳니", L=0.55, W=0.020, T=0.0036, curve=0.012, single=True, tip=0.24, flare=0.0, grip=0.12, guard="bar",
                barrels=1, barrel_len=0.46, barrel_r=0.0105, suppressor=True, mag=(0.036, 0.075, 0.026), vents=2),
    "486": dict(name="잔광", L=0.55, W=0.022, T=0.0045, curve=0.0, single=False, tip=0.3, flare=0.0, grip=0.12, guard="bar",
                barrels=1, barrel_len=0.36, barrel_r=0.0095, heat_rings=3, mag=(0.04, 0.08, 0.028), vents=3),
    "349": dict(name="절단선", L=1.42, W=0.024, T=0.0042, curve=0.07, single=True, tip=0.1, flare=0.0, grip=0.30, guard="disc",
                barrels=1, barrel_len=0.86, barrel_r=0.0085, rail=True, mag=(0.04, 0.09, 0.03), vents=0),
    "487": dict(name="새벽의 방전", L=1.42, W=0.025, T=0.0042, curve=0.062, single=True, tip=0.11, flare=0.0, grip=0.30, guard="disc",
                barrels=1, barrel_len=0.7, barrel_r=0.009, coils=4, mag=(0.04, 0.09, 0.03), vents=2),
    "470": dict(name="적귀", L=1.10, W=0.030, T=0.0050, curve=0.10, single=True, tip=0.15, flare=0.08, grip=0.32, guard="horns",
                barrels=1, barrel_len=0.66, barrel_r=0.012, red_eye=True, mag=(0.045, 0.1, 0.034), vents=3),
    "482": dict(name="백귀야행", L=1.10, W=0.029, T=0.0048, curve=0.094, single=True, tip=0.15, flare=0.08, grip=0.32, guard="horns",
                barrels=3, barrel_len=0.58, barrel_r=0.008, drum=True, mag=(0.04, 0.09, 0.03), vents=2),
    "423": dict(name="전류", L=1.10, W=0.027, T=0.0042, curve=0.05, single=True, tip=0.13, flare=0.35, grip=0.24, guard="petals",
                barrels=2, barrel_len=0.7, barrel_r=0.0085, coils=5, mag=(0.04, 0.085, 0.03), vents=2),
    "453": dict(name="유리 왕관", L=1.10, W=0.027, T=0.0040, curve=0.046, single=True, tip=0.13, flare=0.35, grip=0.24, guard="petals",
                barrels=1, barrel_len=0.62, barrel_r=0.009, halo=True, crown=True, mag=(0.04, 0.085, 0.03), vents=3),
    "352": dict(name="폐허의 왕", L=1.61, W=0.058, T=0.0075, curve=0.03, single=True, tip=0.1, flare=0.08, grip=0.36, guard="block",
                barrels=2, barrel_len=0.95, barrel_r=0.016, crown=True, mag=(0.07, 0.15, 0.05), vents=5),
    "490": dict(name="철의 장례", L=1.61, W=0.060, T=0.0078, curve=0.026, single=True, tip=0.1, flare=0.05, grip=0.36, guard="block",
                barrels=1, barrel_len=0.9, barrel_r=0.017, dish=True, mag=(0.075, 0.16, 0.05), vents=6),
    "329": dict(name="도시를 가르는 자", L=1.61, W=0.066, T=0.0075, curve=0.0, single=False, tip=0.13, flare=0.0, grip=0.40, guard="wings",
                barrels=2, barrel_len=1.0, barrel_r=0.017, rail=True, brake=True, mag=(0.075, 0.16, 0.05), vents=5),
    "377": dict(name="심야 열차", L=1.61, W=0.068, T=0.0078, curve=0.0, single=False, tip=0.13, flare=0.0, grip=0.40, guard="wings",
                barrels=2, barrel_len=0.9, barrel_r=0.018, rail=True, headlight=True, mag=(0.08, 0.17, 0.052), vents=6),
}


def _edge_line(L, hw, curve, tip, side, flare, single):
    """날을 따라 가는 청록 빛 줄(날 쪽 비탈에 얹는다)."""
    def prof(w, th, k):
        x = side * w * k
        return [(x + side * 0.0016, 0.0), (x - side * 0.0042, 0.0016), (x - side * 0.0042, -0.0016)]
    return MS.blade("edge%d" % side, L, hw, 0.002, "glow_kat_edge", curve, False, 0.0, 0, tip, 60, 0.0, prof)


def _cx(t, L, curve):
    return -curve * (t ** 1.7)


def build(spec):
    MS._kat_materials()
    L, W, T = spec["L"], spec["W"], spec["T"]
    curve, single, tip, flare = spec["curve"], spec["single"], spec["tip"], spec["flare"]
    def hw(t):
        return W * (1 - 0.18 * t) * (1 + flare * _sm(0.5, 0.9, t))
    MS.blade("blade", L, hw, T, "kat_blade", curve, single, 0.0, 0, tip, 60, 0.0)
    if single:
        _edge_line(L, hw, curve, tip, 1, flare, True)
    else:
        _edge_line(L, hw, curve, tip, 1, flare, False)
        _edge_line(L, hw, curve, tip, -1, flare, False)
    # 방열창(칼날 양면의 청록 홈)
    n = spec.get("vents", 0)
    for i in range(n):
        t = 0.2 + 0.5 * i / max(1, n - 1) if n > 1 else 0.3
        z = t * L
        cx = _cx(t, L, curve)
        for s in (-1, 1):
            K.box((hw(t) * 0.45, 0.0016, 0.02), (cx - hw(t) * 0.05, s * (T * 0.62 + 0.0012), z), "glow_kat_line", bev=0.0)
    # 등의 레일(검은 레일 위에 가는 청록 줄)
    if spec.get("rail"):
        cx = _cx(0.3, L, curve)
        K.box((0.016, 0.0125, L * 0.36), (cx - hw(0.3) * 0.25, T + 0.0055, 0.1 + L * 0.18), "kat_dark", bev=0.0015)
        K.box((0.005, 0.0045, L * 0.32), (cx - hw(0.3) * 0.25, T + 0.0125, 0.1 + L * 0.18), "glow_kat_rim", bev=0.0)
    # 총열: 칼날 밑(+Y쪽)에 나란히, 끝에 청록 총구 고리
    nb = spec["barrels"]
    r = spec["barrel_r"]
    bl = spec["barrel_len"]
    for b in range(nb):
        x = -hw(0.2) * (0.35 if nb == 1 else (0.1 + 0.6 * b / max(1, nb - 1) - 0.25))
        y = T + r + 0.004
        K.cyl(r * 0.9, r, bl, (x, y, 0.05 + bl / 2), "kat_dark", 24)
        K.ring(r * 1.3, 0.0022, (x, y, 0.05 + bl), "glow_kat_rim")
        K.cyl(r * 0.7, r * 0.7, 0.014, (x, y, 0.06 + bl), "kat_plate", 24)
        if spec.get("suppressor"):
            K.cyl(r * 1.35, r * 1.35, bl * 0.4, (x, y, 0.05 + bl * 0.8), "kat_plate", 24)
        for k in range(spec.get("heat_rings", 0)):
            K.ring(r * 1.25, 0.0018, (x, y, 0.08 + bl * (k + 1) / (spec["heat_rings"] + 1)), "glow_kat_rim")
        for k in range(spec.get("coils", 0)):
            K.ring(r * 1.5, 0.0022, (x, y, 0.1 + (bl - 0.1) * (k + 0.5) / spec["coils"]), "glow_kat_line")
    if spec.get("brake"):   # 대검 밑동의 큰 총구 제동기
        K.box((0.1, 0.05, 0.05), (0.0, T + 0.04, 0.09), "kat_plate")
        K.box((0.1, 0.01, 0.012), (0.0, T + 0.068, 0.09), "glow_kat_rim", bev=0.0)
    # 코등이
    _guard(spec)
    # 탄창: 코등이 뒤쪽(+Y쪽)의 상자나 드럼과 청록 줄
    mx, my, mz = spec["mag"]
    if spec.get("drum"):
        K.cyl(0.05, 0.05, 0.05, (0.0, T + 0.045, -0.06), "kat_plate", 32, (math.pi / 2, 0, 0))
        K.ring(0.043, 0.003, (0.0, T + 0.072, -0.06), "glow_kat_rim", (math.pi / 2, 0, 0))
    else:
        K.box((mx, mz, my), (0.012, T + mz / 2 + 0.012, -0.06 - my * 0.25), "kat_plate")
        K.box((mx * 0.5, 0.004, my * 0.7), (0.012, T + mz + 0.013, -0.06 - my * 0.25), "glow_kat_rim", bev=0.0)
    # 손잡이와 자루끝
    g = spec["grip"]
    K.cyl(0.0185, 0.0170, g, (0, 0, -g / 2 - 0.01), "kat_wrap", 24)
    for k in range(int(g / 0.06)):
        K.ring(0.0198, 0.0022, (0, 0, -0.03 - k * 0.06), "kat_pale")
    pz = -g - 0.03
    K.box((0.05, 0.05, 0.036), (0, 0, pz), "kat_plate")
    K.box((0.03, 0.052, 0.01), (0, 0, pz - 0.022), "glow_kat_rim", bev=0.0)
    if spec.get("crown"):
        for k in range(5):
            a = (k - 2) * 0.5
            K.cyl(0.0, 0.01, 0.07, (math.sin(a) * 0.05, 0, pz - 0.05 + math.cos(a) * 0.0), "kat_plate", 12, (math.pi, 0, 0))
    if spec.get("halo"):
        K.ring(0.085, 0.0028, (0, 0, 0.13), "glow_kat_rim", (0, 0, 0))
    if spec.get("red_eye"):
        K.ball(0.014, (0.0, T + 0.03, 0.005), "glow_fire", (1, 1, 1), 3)
    if spec.get("headlight"):
        K.ball(0.026, (0.0, T + 0.03, 0.022), "glow_kat_rim", (1, 1, 0.8), 3)
    if spec.get("dish"):
        K.cyl(0.06, 0.012, 0.03, (0.0, T + 0.03, 0.04), "kat_plate", 32, (math.pi / 2, 0, 0))
        K.ring(0.05, 0.003, (0.0, T + 0.046, 0.04), "glow_kat_line", (math.pi / 2, 0, 0))


def _guard(spec):
    T = spec["T"]
    kind = spec["guard"]
    if kind == "bar":
        K.box((0.12, 0.04, 0.03), (0, 0, 0), "kat_plate")
        K.ball(0.012, (0, T + 0.02, 0.0), "glow_kat_rim", (1, 1, 1), 3)
    elif kind == "disc":
        K.cyl(0.054, 0.054, 0.014, (0, 0, 0), "kat_dark", 48)
        K.ring(0.05, 0.0026, (0, 0, 0.0078), "glow_kat_rim")
    elif kind == "horns":
        K.box((0.2, 0.05, 0.03), (0, 0, 0), "kat_plate")
        for s in (-1, 1):
            K.cyl(0.0, 0.024, 0.11, (s * 0.105, 0, 0.055), "kat_plate", 16, (0, s * 0.5, 0))
            K.ball(0.011, (s * 0.115, T + 0.026, 0.0), "glow_kat_rim", (1, 1, 1), 3)
    elif kind == "petals":
        K.cyl(0.058, 0.058, 0.016, (0, 0, 0), "kat_dark", 48)
        for k in range(8):
            a = k / 8 * math.tau
            K.ball(0.017, (math.cos(a) * 0.062, math.sin(a) * 0.062, 0.0), "glow_kat_rim" if k % 2 == 0 else "kat_plate", (1, 1, 0.5), 3)
    elif kind == "block":
        K.box((0.22, 0.075, 0.05), (0, 0, 0), "kat_plate")
        for s in (-1, 1):
            K.box((0.05, 0.078, 0.012), (s * 0.07, 0, 0), "glow_kat_rim", bev=0.0)
    else:   # wings
        K.box((0.36, 0.06, 0.04), (0, 0, 0), "kat_plate")
        for s in (-1, 1):
            K.box((0.1, 0.06, 0.03), (s * 0.19, 0, -0.03), "kat_plate", (0, s * 0.5, 0))
        K.box((0.05, 0.064, 0.02), (0, 0, 0), "glow_kat_rim", bev=0.0)


def _register():
    table = {}
    for sid, spec in SPECS.items():
        table[sid] = (lambda s=spec: build(s))
    return table


if __name__ == "__main__":
    want = [a for a in (sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]) if a in SPECS]
    table = {k: v for k, v in _register().items() if not want or k in want}
    K.run_all(table, OUT, SIZE, "사이버 검")
