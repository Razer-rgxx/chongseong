# 「검의 언덕」 미래 구역 네온 시가의 고층 건물(docs/neon_city_blender.md)을 Blender로 짓고 .glb로 내보낸다. (2026-11-25)
#
# 한 번(chongseong 폴더에서): blender -b -P tools/blender/make_city.py [-- 이름 ...]
# 결과: assets/future/models/neon_city/<이름>.glb, index.json, textures/(벽 질감 1K: fa_a·fa_b·fa_c·shop의 색과 법선).
# 바깥 모델·AI 생성 에셋 없이 bmesh로 코드로만 짓는다. 세계에 글자 없음(간판·광고판에 글자 금지, 광고 화면 자리는 비워 둔다).
#
# 약속(NeonDistrict와):
#   - 실제 크기(m). 원점은 발자국 가운데 바닥. Blender Z 위(Godot +Y), 앞(가게·큰 광고판)은 Blender -Y(Godot +Z).
#   - 건물 한 채 = glb 하나 = 메시 하나(재질 여러 칸). 재질은 이름만 쓴다(MATS): 게임이 이름으로 공유 재질을 끼운다.
#     fa_a(콘크리트 벽에 뚫린 창)·fa_b(유리 커튼월)·fa_c(금속 판과 띠창)는 창 셰이더(assets/future/neon_tower.gdshader),
#     shop(가게층 유리, 따뜻한 빛), roof·trim(콘크리트), metal, glass(어두운 유리), neon_c·m·a·v·l(청록·자홍·호박·보라·연두), beacon(붉은 등).
#   - 벽(fa_*)의 UV는 m 단위: u = 가로 / (2.4 × 4), v = (높이 − 받침층 위) / (3.4 × 4). 질감 한 장 = 창 4 × 4칸.
#     glTF는 v를 뒤집으므로 Godot에서 UV.y는 위로 갈수록 줄고, 질감 그림은 위가 층의 위다.
#   - index.json: 이름 → {w, d(발자국 m, Godot x·z), h(지붕 높이), top(안테나 끝), boards: [{p, n, s}]} (Godot 좌표).
#     boards는 광고 화면을 붙일 자리(가운데, 바깥 법선, 가로·세로). 화면 판은 게임(neon_board.gdshader)이 그린다.
#   - 한 채 정점 2만 아래(실제로는 수천).

import bmesh
import bpy
import json
import math
import os
import random
import sys

import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "future", "models", "neon_city")
TEX = os.path.join(OUT, "textures")
WIN_W, WIN_H, CELLS = 2.4, 3.4, 4
SHOP_W = 4.0
TEX_SIZE = 1024

MATS = ["fa_a", "fa_b", "fa_c", "shop", "roof", "trim", "metal", "glass", "neon_c", "neon_m", "neon_a", "neon_v", "neon_l", "beacon"]
FACADES = ("fa_a", "fa_b", "fa_c")
NEONS = ("neon_c", "neon_m", "neon_a", "neon_v", "neon_l")
PREVIEW = {   # Blender 안에서 볼 색(게임은 이름으로 바꿔 끼운다)
    "fa_a": (0.3, 0.31, 0.34), "fa_b": (0.05, 0.07, 0.1), "fa_c": (0.2, 0.21, 0.24), "shop": (0.6, 0.45, 0.3),
    "roof": (0.2, 0.2, 0.22), "trim": (0.38, 0.39, 0.42), "metal": (0.1, 0.1, 0.12), "glass": (0.03, 0.04, 0.06),
    "neon_c": (0.15, 0.95, 1.0), "neon_m": (1.0, 0.2, 0.75), "neon_a": (1.0, 0.62, 0.18), "neon_v": (0.55, 0.35, 1.0),
    "neon_l": (0.35, 1.0, 0.45), "beacon": (1.0, 0.12, 0.1),
}


# ================================================================== 벽 질감(창 4 × 4칸, 위가 층의 위)
def _noise(rng, n, low):
    """부드러운 잡음 0~1(낮은 해상도를 키우고 흐린다)."""
    a = rng.random((low, low))
    a = np.kron(a, np.ones((n // low, n // low)))
    for _ in range(2):
        a = (a + np.roll(a, n // low // 2, 0) + np.roll(a, -n // low // 2, 0) + np.roll(a, n // low // 2, 1) + np.roll(a, -n // low // 2, 1)) / 5.0
    return (a - a.min()) / max(1e-6, a.max() - a.min())


def _rect(img, h, x0, y0, x1, y1, col, hv):
    img[y0:y1, x0:x1] = col
    h[y0:y1, x0:x1] = hv


def _facade(kind, seed):
    """(색 HxWx3, 높이 HxW) 0~1. 한 칸 = 256 화소. 칸 안 좌표 f(0~1, 위가 0)."""
    N = TEX_SIZE
    c = N // CELLS
    rng = np.random.default_rng(seed)
    big = _noise(rng, N, 16)
    fine = rng.random((N, N)) * 0.06
    img = np.zeros((N, N, 3))
    h = np.full((N, N), 0.5)
    if kind == "fa_a":     # 콘크리트에 뚫린 창, 창틀, 창턱, 가운데 창살, 바닥 줄
        base = np.array([0.30, 0.31, 0.345])
        img[:] = base * (0.82 + 0.3 * big[..., None]) + fine[..., None]
        for i in range(CELLS):
            for j in range(CELLS):
                x0, y0 = j * c, i * c
                wx0, wx1, wy0, wy1 = x0 + int(0.16 * c), x0 + int(0.84 * c), y0 + int(0.2 * c), y0 + int(0.8 * c)
                _rect(img, h, wx0 - 6, wy0 - 6, wx1 + 6, wy1 + 6, (0.13, 0.135, 0.15), 0.62)
                g = np.linspace(0.05, 0.025, wy1 - wy0)[:, None, None]
                img[wy0:wy1, wx0:wx1] = np.concatenate([g * 0.8, g * 0.95, g * 1.4], axis=2) + fine[wy0:wy1, wx0:wx1, None] * 0.2
                h[wy0:wy1, wx0:wx1] = 0.2
                m = (wx0 + wx1) // 2
                _rect(img, h, m - 2, wy0, m + 2, wy1, (0.13, 0.135, 0.15), 0.55)
                _rect(img, h, wx0 - 10, wy1 + 6, wx1 + 10, wy1 + 14, (0.46, 0.47, 0.5), 0.75)
                streak = rng.random() < 0.45
                if streak:   # 창턱 아래 물때
                    sx = rng.integers(wx0, wx1 - 20)
                    img[wy1 + 14:y0 + c - 10, sx:sx + 18] *= 0.8
                _rect(img, h, x0, y0 + c - 7, x0 + c, y0 + c, (0.17, 0.175, 0.19), 0.35)
    elif kind == "fa_b":   # 유리 커튼월: 세로 멀리언, 층마다 어두운 스팬드럴 판
        for i in range(CELLS):
            for j in range(CELLS):
                x0, y0 = j * c, i * c
                g = np.linspace(0.07, 0.035, c)[:, None, None]
                img[y0:y0 + c, x0:x0 + c] = np.concatenate([g * 0.75, g * 1.0, g * 1.45], axis=2) + big[y0:y0 + c, x0:x0 + c, None] * 0.02
                h[y0:y0 + c, x0:x0 + c] = 0.3
                _rect(img, h, x0, y0 + int(0.87 * c), x0 + c, y0 + c, (0.09, 0.1, 0.12), 0.45)
                _rect(img, h, x0, y0, x0 + 5, y0 + c, (0.36, 0.38, 0.42), 0.7)
                _rect(img, h, x0 + c - 5, y0, x0 + c, y0 + c, (0.36, 0.38, 0.42), 0.7)
                _rect(img, h, x0, y0 + int(0.87 * c) - 3, x0 + c, y0 + int(0.87 * c) + 3, (0.36, 0.38, 0.42), 0.7)
                _rect(img, h, x0, y0, x0 + c, y0 + 5, (0.36, 0.38, 0.42), 0.7)
        img += fine[..., None] * 0.25
    elif kind == "fa_c":   # 금속 판(가로 이음줄)과 띠창(반 칸마다 창살)
        base = np.array([0.2, 0.21, 0.24])
        img[:] = base * (0.85 + 0.25 * big[..., None]) + fine[..., None] * 0.5
        for y in range(0, N, c // 8):
            _rect(img, h, 0, y, N, y + 2, (0.1, 0.105, 0.12), 0.42)
        for i in range(CELLS):
            y0 = i * c
            wy0, wy1 = y0 + int(0.3 * c), y0 + int(0.76 * c)
            g = np.linspace(0.06, 0.03, wy1 - wy0)[:, None, None]
            img[wy0:wy1, :] = np.concatenate([g * 0.8, g * 1.0, g * 1.35], axis=2)
            h[wy0:wy1, :] = 0.2
            _rect(img, h, 0, wy0 - 5, N, wy0, (0.32, 0.33, 0.36), 0.7)
            _rect(img, h, 0, wy1, N, wy1 + 7, (0.38, 0.39, 0.42), 0.75)
            for x in range(0, N, c // 2):
                _rect(img, h, x, wy0, x + 4, wy1, (0.3, 0.31, 0.34), 0.65)
    else:                  # shop: 가게 앞 유리(한 칸 = 가로 4m × 받침층 높이), 위 간판 띠, 아래 받침
        img[:] = (0.07, 0.07, 0.08)
        h[:] = 0.6
        x0, x1, y0, y1 = int(0.04 * N), int(0.96 * N), int(0.08 * N), int(0.82 * N)
        g = np.linspace(0.16, 0.1, y1 - y0)[:, None, None]
        img[y0:y1, x0:x1] = np.concatenate([g * 1.3, g * 1.0, g * 0.75], axis=2)
        h[y0:y1, x0:x1] = 0.25
        for k in range(3):   # 안쪽 선반 그림자
            yy = y0 + int((0.35 + 0.17 * k) * (y1 - y0))
            img[yy:yy + 10, x0 + 40:x1 - 40] *= 0.45
        _rect(img, h, N // 2 - 4, y0, N // 2 + 4, y1, (0.12, 0.12, 0.13), 0.6)
        _rect(img, h, 0, y1, N, y1 + 8, (0.25, 0.25, 0.27), 0.7)
        img += fine[..., None] * 0.2
    return np.clip(img, 0.0, 1.0), h


def _normal(h, strength=6.0):
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    n = np.dstack([-gx, gy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * 0.5 + 0.5


def _save(arr, path, srgb=True):
    """위가 0번 줄인 배열을 그림 파일로(Blender 화소는 아래부터라 뒤집는다). JPEG의 ICC 프로필은 뺀다(Godot이 못 읽는다)."""
    N = arr.shape[0]
    img = bpy.data.images.new(os.path.basename(path), N, N, alpha=False)
    if not srgb:
        img.colorspace_settings.name = "Non-Color"
    rgba = np.ones((N, N, 4), dtype=np.float32)
    rgba[..., :3] = arr[::-1]
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = path
    img.file_format = "JPEG"
    sc = bpy.context.scene
    sc.render.image_settings.quality = 90
    img.save()
    bpy.data.images.remove(img)
    try:
        sys.path.insert(0, HERE)
        import glb_icc
        with open(path, "rb") as f:
            data = f.read()
        out = glb_icc.strip_jpeg(data)
        if out != data:
            with open(path, "wb") as f:
                f.write(out)
    except Exception as e:   # noqa: BLE001
        print("ICC 빼기 실패:", path, e)


def make_textures():
    os.makedirs(TEX, exist_ok=True)
    for i, kind in enumerate(("fa_a", "fa_b", "fa_c", "shop")):
        img, h = _facade(kind, 31 + i)
        _save(img, os.path.join(TEX, kind + "_alb.jpg"))
        _save(_normal(h), os.path.join(TEX, kind + "_nrm.jpg"), False)
    print("벽 질감 4벌을", TEX, "에 만들었다")


# ================================================================== 모양 도구
class G:
    """bmesh 하나에 면을 쌓는다. 면마다 꼭짓점을 따로(각진 면), 둥근 탑만 꼭짓점을 나눠 매끈하게."""

    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def face(self, pts, mat, uvs=None, smooth=False, verts=None):
        vs = verts or [self.bm.verts.new(p) for p in pts]
        f = self.bm.faces.new(vs)
        f.material_index = MATS.index(mat)
        f.smooth = smooth
        if uvs:
            for lp, u in zip(f.loops, uvs):
                lp[self.uv].uv = u
        return f


def _uv(mat, s, z, L, zb, z0, z1):
    if mat in FACADES:
        return ((s - (L % WIN_W) / 2.0) / (WIN_W * CELLS), (z - zb) / (WIN_H * CELLS))
    if mat == "shop":
        return ((s - (L % SHOP_W) / 2.0) / SHOP_W, (z - z0) / max(0.01, z1 - z0))
    return (s / 4.0, z / 4.0)


def prism(g, poly, z0, z1, side, top=None, bottom=None, zb=0.0, smooth=False):
    """다각형(위에서 보아 반시계)을 z0~z1로 세운다. 옆면 UV는 둘레를 따라 m 단위."""
    n = len(poly)
    if smooth:   # 둥근 탑: 옆면 꼭짓점을 나눈다(둘레 이음매는 UV만 다르다)
        lo = [g.bm.verts.new((x, y, z0)) for x, y in poly]
        hi = [g.bm.verts.new((x, y, z1)) for x, y in poly]
        per = sum((Vector(poly[(i + 1) % n]) - Vector(poly[i])).length for i in range(n))
        s = 0.0
        for i in range(n):
            j = (i + 1) % n
            L = (Vector(poly[j]) - Vector(poly[i])).length
            uvs = [_uv(side, s, z0, per, zb, z0, z1), _uv(side, s + L, z0, per, zb, z0, z1), _uv(side, s + L, z1, per, zb, z0, z1), _uv(side, s, z1, per, zb, z0, z1)]
            g.face(None, side, uvs, True, [lo[i], lo[j], hi[j], hi[i]])
            s += L
    else:
        for i in range(n):
            a, b = Vector(poly[i]), Vector(poly[(i + 1) % n])
            L = (b - a).length
            if L < 1e-4:
                continue
            uvs = [_uv(side, 0.0, z0, L, zb, z0, z1), _uv(side, L, z0, L, zb, z0, z1), _uv(side, L, z1, L, zb, z0, z1), _uv(side, 0.0, z1, L, zb, z0, z1)]
            g.face([(a.x, a.y, z0), (b.x, b.y, z0), (b.x, b.y, z1), (a.x, a.y, z1)], side, uvs)
    if top:
        g.face([(x, y, z1) for x, y in poly], top, [(x / 4.0, y / 4.0) for x, y in poly])
    if bottom:
        g.face([(x, y, z0) for x, y in reversed(poly)], bottom, [(x / 4.0, y / 4.0) for x, y in reversed(poly)])


def box(g, c, s, mat, top=True):
    x, y, z = c
    w, d, h = s
    prism(g, rect(w, d, x, y), z - h / 2.0, z + h / 2.0, mat, mat if top else None, mat)


def cyl(g, c, r, z0, z1, mat, n=10, r1=None):
    """원기둥(r1이면 위가 좁아지는 뿔대)."""
    r1 = r if r1 is None else r1
    lo = [g.bm.verts.new((c[0] + math.cos(k / n * math.tau) * r, c[1] + math.sin(k / n * math.tau) * r, z0)) for k in range(n)]
    hi = [g.bm.verts.new((c[0] + math.cos(k / n * math.tau) * r1, c[1] + math.sin(k / n * math.tau) * r1, z1)) for k in range(n)]
    for k in range(n):
        g.face(None, mat, [(k / n, 0), ((k + 1) / n, 0), ((k + 1) / n, 1), (k / n, 1)], True, [lo[k], lo[(k + 1) % n], hi[(k + 1) % n], hi[k]])
    if r1 > 0.0:
        g.face([(c[0] + math.cos(k / n * math.tau) * r1, c[1] + math.sin(k / n * math.tau) * r1, z1) for k in range(n)], mat)


def rect(w, d, cx=0.0, cy=0.0):
    return [(cx - w / 2, cy - d / 2), (cx + w / 2, cy - d / 2), (cx + w / 2, cy + d / 2), (cx - w / 2, cy + d / 2)]


def cham(w, d, c, cx=0.0, cy=0.0):
    x0, x1, y0, y1 = cx - w / 2, cx + w / 2, cy - d / 2, cy + d / 2
    return [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c), (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)]


def ellipse(w, d, n=20, cx=0.0, cy=0.0):
    return [(cx + math.cos(-math.pi / 2 + k / n * math.tau) * w / 2, cy + math.sin(-math.pi / 2 + k / n * math.tau) * d / 2) for k in range(n)]


def grow(poly, c):
    """볼록한 다각형을 c만큼 넓힌다(c<0이면 줄인다)."""
    n = len(poly)
    cx = sum(p[0] for p in poly) / n
    cy = sum(p[1] for p in poly) / n
    out = []
    for i in range(n):
        p = Vector(poly[i])
        a, b = Vector(poly[i - 1]), Vector(poly[(i + 1) % n])
        d1, d2 = (p - a).normalized(), (b - p).normalized()
        n1, n2 = Vector((d1.y, -d1.x)), Vector((d2.y, -d2.x))
        m = (n1 + n2)
        if m.length < 1e-6:
            m = n1
        m.normalize()
        k = c / max(0.3, m.dot(n1))
        out.append((p.x + m.x * k, p.y + m.y * k))
    return out


def shape(t):
    """층(tier)의 발자국 다각형."""
    w, d, dx, dy = t["w"], t["d"], t.get("dx", 0.0), t.get("dy", 0.0)
    k = t.get("shape", "box")
    if k == "cham":
        return cham(w, d, t.get("c", min(w, d) * 0.12), dx, dy)
    if k == "oct":
        return cham(w, d, min(w, d) * 0.29, dx, dy)
    if k == "round":
        return ellipse(w, d, 20, dx, dy)
    return rect(w, d, dx, dy)


# ================================================================== 건물 한 채
def tower(sp):
    """sp: 짓는 법(아래 SPECS). 돌려주는 값: (G, index 항목)."""
    rnd = random.Random(sp["seed"])
    g = G()
    fw, fd = sp["fw"], sp["fd"]
    ph = sp.get("ph", 7.0)
    neon = sp["neon"]
    boards = []
    # 받침층(가게층): 발자국을 꽉 채운다. 유리 가게 앞, 위 간판 띠, 앞 차양과 그 밑 네온
    prism(g, rect(fw, fd), 0.0, ph - 1.0, "shop", None, None)
    prism(g, rect(fw + 0.3, fd + 0.3), ph - 1.0, ph, "trim", "roof", "trim")
    for side in sp.get("awn", ["f"]):
        if side == "f":
            box(g, (0.0, -fd / 2 - 0.65, 3.9), (fw * 0.86, 1.3, 0.22), "metal")
            box(g, (0.0, -fd / 2 - 1.3, 3.72), (fw * 0.86, 0.12, 0.12), neon[0])
        else:
            sx = 1.0 if side == "r" else -1.0
            box(g, (sx * (fw / 2 + 0.55), 0.0, 3.9), (1.1, fd * 0.7, 0.2), "metal")
            box(g, (sx * (fw / 2 + 1.1), 0.0, 3.72), (0.12, fd * 0.7, 0.12), neon[-1])
    tops = []
    for si, stack in enumerate(sp["stacks"]):
        z = ph
        last = None
        for ti, t in enumerate(stack):
            poly = shape(t)
            z1 = t["top"]
            prism(g, poly, z, z1, t["fa"], "roof", None, ph, t.get("shape") == "round")
            # 처마(층 끝)와 층 띠
            prism(g, grow(poly, 0.28), z1, z1 + 0.5, "trim", "roof", "trim")
            band = t.get("band", 0)
            if band:
                zz = z + band * WIN_H
                k = 0
                while zz < z1 - 2.0:
                    lit = t.get("neon_band") and k % 2 == 1
                    if lit:
                        prism(g, grow(poly, 0.16), zz - 0.1, zz + 0.1, neon[(si + k) % len(neon)])
                    else:
                        prism(g, grow(poly, 0.14), zz - 0.16, zz + 0.16, "trim", "trim", "trim")
                    zz += band * WIN_H
                    k += 1
            # 앞 모서리 세로 네온
            if t.get("corners") and t.get("shape", "box") != "round":
                xs = [p[0] for p in poly]
                ys = [p[1] for p in poly]
                fy = min(ys)
                for cx in (min(xs) + 0.15, max(xs) - 0.15):
                    box(g, (cx, fy - 0.12, (z + 1.5 + z1 - 1.0) / 2.0), (0.2, 0.2, z1 - z - 2.5), neon[ti % len(neon)])
            # 발코니 줄(앞면)
            if t.get("balc"):
                xs = [p[0] for p in poly]
                fy = min(p[1] for p in poly)
                bw = (max(xs) - min(xs)) * 0.72
                zz = z + WIN_H
                k = 0
                while zz < z1 - 2.0:
                    if k % t["balc"] == 0:
                        box(g, ((min(xs) + max(xs)) / 2, fy - 0.55, zz), (bw, 1.1, 0.18), "trim")
                        box(g, ((min(xs) + max(xs)) / 2, fy - 1.07, zz + 0.55), (bw, 0.05, 0.95), "glass")
                    zz += WIN_H
                    k += 1
            # 옆 배관
            for p in range(t.get("pipes", 0)):
                xs = [q[0] for q in poly]
                ys = [q[1] for q in poly]
                y = min(ys) + (max(ys) - min(ys)) * (0.25 + 0.5 * p / max(1, t["pipes"] - 1) if t["pipes"] > 1 else 0.5)
                cyl(g, (max(xs) + 0.3, y), 0.2, z, z1 - 0.5, "metal", 8)
                for zz in range(int(z) + 4, int(z1), 6):
                    box(g, (max(xs) + 0.15, y, zz), (0.35, 0.5, 0.15), "metal")
            # 광고판 자리(앞면): 어두운 판과 틀만 짓고 자리를 적는다(화면은 게임이 그린다)
            for bd in t.get("boards", []):
                xs = [p[0] for p in poly]
                ys = [p[1] for p in poly]
                if bd.get("side") == "r":
                    face_x = max(xs)
                    bw, bh = bd["w"], bd["h"]
                    cz = bd["z"]
                    cyy = (min(ys) + max(ys)) / 2 + bd.get("off", 0.0)
                    box(g, (face_x + 0.12, cyy, cz), (0.24, bw + 0.5, bh + 0.5), "metal")
                    boards.append({"p": [face_x + 0.3, cz, -cyy], "n": [1, 0, 0], "s": [bw, bh]})
                else:
                    fy = min(ys)
                    bw, bh = bd["w"], bd["h"]
                    cz = bd["z"]
                    cx = (min(xs) + max(xs)) / 2 + bd.get("off", 0.0)
                    box(g, (cx, fy - 0.12, cz), (bw + 0.5, 0.24, bh + 0.5), "metal")
                    for dz in (-1, 1):
                        box(g, (cx, fy - 0.3, cz + dz * (bh / 2 + 0.2)), (bw + 0.6, 0.14, 0.14), "trim")
                    boards.append({"p": [cx, cz, -(fy - 0.3)], "n": [0, 0, 1], "s": [bw, bh]})
            z = z1 + 0.5
            last = (poly, z)
        tops.append(last)
    # 하늘 다리
    for br in sp.get("bridges", []):
        z0, x0, x1, y = br
        box(g, ((x0 + x1) / 2, y, z0), (x1 - x0, 3.0, 3.4), "glass")
        box(g, ((x0 + x1) / 2, y, z0 - 1.85), (x1 - x0, 3.4, 0.3), "trim")
        box(g, ((x0 + x1) / 2, y - 1.6, z0 - 1.6), (x1 - x0, 0.12, 0.12), neon[1 % len(neon)])
        box(g, ((x0 + x1) / 2, y + 1.6, z0 - 1.6), (x1 - x0, 0.12, 0.12), neon[1 % len(neon)])
    # 지붕 위
    top_z = 0.0
    peak = 0.0
    for si, (poly, z) in enumerate(tops):
        xs = [p[0] for p in poly]
        ys = [p[1] for p in poly]
        cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
        hw, hd = (max(xs) - min(xs)) / 2 - 1.2, (max(ys) - min(ys)) / 2 - 1.2
        top_z = max(top_z, z)
        peak = max(peak, z)
        feats = sp.get("roof", ["ac"]) if si == 0 else sp.get("roof2", ["ac"])
        for f in feats:
            if f == "ac":
                for k in range(rnd.randint(2, 4)):
                    box(g, (cx + rnd.uniform(-hw, hw) * 0.8, cy + rnd.uniform(-hd, hd) * 0.8, z + 0.6), (1.4, 1.0, 1.2), "metal")
            elif f == "tank":
                tx, ty = cx + hw * 0.5, cy - hd * 0.4
                for lx in (-0.8, 0.8):
                    for ly in (-0.8, 0.8):
                        box(g, (tx + lx, ty + ly, z + 0.9), (0.18, 0.18, 1.8), "metal")
                cyl(g, (tx, ty), 1.3, z + 1.8, z + 4.4, "metal", 12)
            elif f == "antenna":
                hh = rnd.uniform(8.0, 15.0)
                ax, ay = cx - hw * 0.4, cy + hd * 0.3
                cyl(g, (ax, ay), 0.16, z, z + hh, "metal", 6, 0.08)
                for k in range(3):
                    box(g, (ax, ay, z + hh * (0.35 + 0.2 * k)), (1.6 - k * 0.4, 0.08, 0.08), "metal")
                box(g, (ax, ay, z + hh + 0.3), (0.5, 0.5, 0.5), "beacon")
                peak = max(peak, z + hh + 0.6)
            elif f == "heli":   # 헬기장: 둥근 판, 둘레 네온, 가운데 둥근 표지(글자 없음)
                r = min(hw, hd) + 0.6
                prism(g, ellipse(r * 2, r * 2, 16, cx, cy), z, z + 0.3, "metal", "metal")
                for k in range(16):
                    a = k / 16 * math.tau
                    box(g, (cx + math.cos(a) * (r - 0.4), cy + math.sin(a) * (r - 0.4), z + 0.36), (0.9, 0.9, 0.08), neon[0] if k % 2 == 0 else "trim")
                prism(g, ellipse(r * 0.8, r * 0.8, 16, cx, cy), z + 0.3, z + 0.34, "trim", "trim")
            elif f == "spire":
                hh = rnd.uniform(10.0, 18.0)
                cyl(g, (cx, cy), min(hw, hd) * 0.5, z, z + hh, "metal", 8, 0.12)
                box(g, (cx, cy, z + hh + 0.3), (0.45, 0.45, 0.45), "beacon")
                peak = max(peak, z + hh + 0.5)
            elif f == "fins":   # 꼭대기 둘레 세로 지느러미와 그 끝 네온
                for k in range(4):
                    for s in (-1.0, 1.0):
                        x = cx - hw + (2 * hw) * (k + 0.5) / 4
                        box(g, (x, cy + s * (hd + 1.2), z + 3.0), (0.35, 0.35, 6.0), "trim")
                        box(g, (x, cy + s * (hd + 1.4), z + 3.0), (0.12, 0.12, 5.6), neon[k % len(neon)])
                peak = max(peak, z + 6.0)
            elif f == "ring":   # 꼭대기 네온 띠
                prism(g, grow(poly, 0.4), z - 2.4, z - 2.1, neon[-1])
                prism(g, grow(poly, 0.4), z - 1.4, z - 1.1, neon[0])
            elif f == "crown":  # 층층이 줄어드는 왕관 꼭대기
                p2 = grow(poly, -1.2)
                prism(g, p2, z, z + 3.4, "glass", "roof")
                prism(g, grow(p2, 0.2), z + 3.4, z + 3.8, neon[0])
                p3 = grow(p2, -1.0)
                prism(g, p3, z + 3.8, z + 6.0, "trim", "roof")
                peak = max(peak, z + 6.0)
    info = {"w": round(fw, 3), "d": round(fd, 3), "h": round(top_z, 2), "top": round(max(peak, top_z), 2), "boards": boards}
    return g, info


# ================================================================== 열여덟~스물넷 종
def _t(shape, w, d, top, fa, **kw):
    t = {"shape": shape, "w": w, "d": d, "top": top, "fa": fa}
    t.update(kw)
    return t


def specs():
    """이름 → 짓는 법. 발자국 10·12·14m(가로·세로 섞음), 높이 18~120m."""
    C, M, A, V, L = NEONS
    S = {}
    # --- 10 × 10
    S["s10_shop"] = dict(fw=10, fd=10, ph=7.0, neon=[A, M], awn=["f", "r"], stacks=[[_t("box", 9.6, 9.6, 19.0, "fa_c", band=2, boards=[{"z": 12.0, "w": 6.0, "h": 3.4}])]], roof=["ac", "tank"])
    S["s10_round"] = dict(fw=10, fd=10, ph=7.0, neon=[C, V], stacks=[[_t("round", 9.4, 9.4, 38.0, "fa_a", band=3, neon_band=True)]], roof=["ac", "antenna"])
    S["s10_pencil"] = dict(fw=10, fd=10, ph=7.0, neon=[M, C], stacks=[[_t("cham", 9.0, 9.0, 40.0, "fa_b", band=4, corners=True, boards=[{"z": 18.0, "w": 2.4, "h": 10.0, "side": "r"}]),
                                                                      _t("cham", 7.4, 7.4, 64.0, "fa_b", band=4)]], roof=["spire"])
    S["s10_slim"] = dict(fw=10, fd=10, ph=7.0, neon=[C, A], stacks=[[_t("box", 9.4, 9.4, 70.0, "fa_c", band=5, pipes=1, boards=[{"z": 20.0, "w": 6.5, "h": 4.0}]),
                                                                    _t("cham", 8.0, 8.0, 100.0, "fa_c", band=5, corners=True)]], roof=["antenna", "ac"])
    # --- 10 × 12 (가로 10, 깊이 12)
    S["r1012_balc"] = dict(fw=10, fd=12, ph=4.6, neon=[L, M], stacks=[[_t("box", 9.6, 11.6, 26.0, "fa_a", balc=1, band=0)]], roof=["ac", "tank"])
    S["r1012_glass"] = dict(fw=10, fd=12, ph=7.0, neon=[C, V], stacks=[[_t("box", 9.6, 11.6, 30.0, "fa_b", band=3, corners=True, boards=[{"z": 15.0, "w": 6.5, "h": 4.0}]),
                                                                      _t("box", 8.0, 9.6, 44.0, "fa_b", band=3)]], roof=["ac"])
    S["r1012_oct"] = dict(fw=10, fd=12, ph=7.0, neon=[V, C], stacks=[[_t("oct", 9.4, 11.4, 76.0, "fa_c", band=4, neon_band=True, boards=[{"z": 16.0, "w": 2.4, "h": 9.0, "side": "r"}])]], roof=["antenna", "ac"])
    S["r1012_step"] = dict(fw=10, fd=12, ph=7.0, neon=[M, A], stacks=[[_t("box", 9.6, 11.6, 52.0, "fa_b", band=4, corners=True, boards=[{"z": 22.0, "w": 6.0, "h": 3.6}]),
                                                                     _t("box", 8.4, 10.0, 84.0, "fa_b", band=4), _t("box", 6.8, 8.0, 112.0, "fa_b", band=4, corners=True)]], roof=["spire"])
    # --- 12 × 12
    S["s12_shophouse"] = dict(fw=12, fd=12, ph=4.6, neon=[A, L], awn=["f", "l"], stacks=[[_t("box", 11.6, 11.6, 18.0, "fa_a", balc=2, boards=[{"z": 11.0, "w": 7.0, "h": 3.4}])]], roof=["tank", "ac"])
    S["s12_oct"] = dict(fw=12, fd=12, ph=7.0, neon=[C, M], stacks=[[_t("oct", 11.0, 11.0, 48.0, "fa_b", band=3, neon_band=True)]], roof=["ring", "ac"])
    S["s12_round"] = dict(fw=12, fd=12, ph=7.0, neon=[V, C], stacks=[[_t("box", 11.6, 11.6, 16.0, "fa_c", band=2, boards=[{"z": 11.5, "w": 8.0, "h": 4.0}]),
                                                                    _t("round", 10.6, 10.6, 88.0, "fa_b", band=5)]], roof=["ring", "antenna"])
    S["s12_twin"] = dict(fw=12, fd=12, ph=7.0, neon=[M, C], stacks=[[_t("box", 4.8, 10.0, 116.0, "fa_b", dx=-3.3, band=5, corners=True)],
                                                                   [_t("box", 4.8, 10.0, 100.0, "fa_b", dx=3.3, band=5, corners=True)]],
                         bridges=[(60.0, -0.9, 0.9, 0.0), (86.0, -0.9, 0.9, 0.0)], roof=["antenna"], roof2=["heli"])
    # --- 12 × 14
    S["r1214_cham"] = dict(fw=12, fd=14, ph=7.0, neon=[A, C], stacks=[[_t("cham", 11.6, 13.6, 32.0, "fa_a", band=3, pipes=2, boards=[{"z": 15.0, "w": 7.5, "h": 4.2}])]], roof=["ac", "tank"])
    S["r1214_canti"] = dict(fw=12, fd=14, ph=7.0, neon=[C, M], stacks=[[_t("box", 11.6, 13.6, 30.0, "fa_c", band=3, boards=[{"z": 17.0, "w": 7.0, "h": 4.0}]),
                                                                      _t("box", 10.0, 11.0, 56.0, "fa_b", dy=-0.8, band=3, corners=True)]], roof=["ac", "fins"])
    S["r1214_twin"] = dict(fw=12, fd=14, ph=7.0, neon=[V, A], stacks=[[_t("cham", 5.0, 12.0, 94.0, "fa_a", dx=-3.2, band=4, neon_band=True)],
                                                                     [_t("cham", 5.0, 12.0, 80.0, "fa_a", dx=3.2, band=4, neon_band=True)]],
                           bridges=[(48.0, -0.8, 0.8, 0.0)], roof=["antenna"], roof2=["ac"])
    S["r1214_crown"] = dict(fw=12, fd=14, ph=7.0, neon=[C, V], stacks=[[_t("box", 11.6, 13.6, 64.0, "fa_b", band=5, corners=True, boards=[{"z": 24.0, "w": 8.0, "h": 4.5}]),
                                                                      _t("cham", 9.6, 11.0, 114.0, "fa_b", band=5)]], roof=["crown", "antenna"])
    # --- 14 × 14
    S["s14_zig"] = dict(fw=14, fd=14, ph=4.6, neon=[L, A], awn=["f", "r", "l"], stacks=[[_t("box", 13.6, 13.6, 14.0, "fa_c", band=0, boards=[{"z": 10.0, "w": 9.0, "h": 3.4}]),
                                                                                       _t("box", 11.6, 11.6, 20.0, "fa_c"), _t("box", 9.0, 9.0, 24.0, "fa_a")]], roof=["tank", "ac"])
    S["s14_setback"] = dict(fw=14, fd=14, ph=7.0, neon=[M, C], stacks=[[_t("box", 13.6, 13.6, 36.0, "fa_a", band=3, pipes=2, boards=[{"z": 16.0, "w": 9.0, "h": 4.8}]),
                                                                       _t("box", 11.6, 11.6, 60.0, "fa_a", band=3, corners=True)]], roof=["ac", "antenna"])
    S["s14_heli"] = dict(fw=14, fd=14, ph=7.0, neon=[C, A], stacks=[[_t("cham", 13.6, 13.6, 58.0, "fa_c", band=4, neon_band=True, boards=[{"z": 20.0, "w": 9.0, "h": 5.0}]),
                                                                    _t("cham", 12.0, 12.0, 106.0, "fa_c", band=4)]], roof=["heli"])
    S["s14_mega"] = dict(fw=14, fd=14, ph=7.0, neon=[V, M, C], stacks=[[_t("box", 13.6, 13.6, 40.0, "fa_a", band=3, boards=[{"z": 20.0, "w": 10.0, "h": 5.4}, {"z": 30.0, "w": 2.6, "h": 12.0, "side": "r"}]),
                                                                       _t("cham", 12.0, 12.0, 80.0, "fa_b", band=4, corners=True),
                                                                       _t("oct", 9.4, 9.4, 120.0, "fa_b", band=4, neon_band=True)]], roof=["spire", "ring"])
    # --- 10 × 14
    S["r1014_long"] = dict(fw=10, fd=14, ph=4.6, neon=[A, C], awn=["f", "r"], stacks=[[_t("box", 9.6, 13.6, 22.0, "fa_a", balc=1, pipes=1)]], roof=["ac", "tank"])
    S["r1014_twin"] = dict(fw=10, fd=14, ph=7.0, neon=[M, L], stacks=[[_t("box", 9.0, 5.6, 52.0, "fa_c", dy=-3.6, band=3, corners=True, boards=[{"z": 20.0, "w": 6.0, "h": 3.6}])],
                                                                     [_t("box", 9.0, 5.6, 44.0, "fa_c", dy=3.6, band=3)]],
                           bridges=[], roof=["ac"], roof2=["tank"])
    S["r1014_slab"] = dict(fw=10, fd=14, ph=7.0, neon=[C, M], stacks=[[_t("box", 9.6, 13.6, 82.0, "fa_c", band=4, neon_band=True, pipes=2, boards=[{"z": 18.0, "w": 2.4, "h": 10.0, "side": "r"}])]], roof=["ac", "antenna"])
    S["r1014_fins"] = dict(fw=10, fd=14, ph=7.0, neon=[V, C], stacks=[[_t("cham", 9.6, 13.6, 100.0, "fa_b", band=5, corners=True, boards=[{"z": 24.0, "w": 6.5, "h": 4.0}])]], roof=["fins", "ac"])
    return S


# ================================================================== 내보내기
def _materials():
    for name in MATS:
        if bpy.data.materials.get(name):
            continue
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        p = m.node_tree.nodes.get("Principled BSDF")
        p.inputs["Base Color"].default_value = (*PREVIEW[name], 1.0)
        if name in NEONS or name == "beacon" or name == "shop":
            for key in ("Emission Color", "Emission"):
                if key in p.inputs:
                    p.inputs[key].default_value = (*PREVIEW[name], 1.0)
                    break
            p.inputs["Emission Strength"].default_value = 2.0


def export(name, g):
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)
    _materials()
    me = bpy.data.meshes.new(name)
    g.bm.to_mesh(me)
    g.bm.free()
    for mn in MATS:
        me.materials.append(bpy.data.materials[mn])
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    try:
        bpy.ops.object.material_slot_remove_unused()
    except Exception:   # noqa: BLE001
        pass
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True)
    nv = len(me.vertices)
    print("만듦 %s (정점 %d)" % (path, nv))
    return nv


def main():
    os.makedirs(OUT, exist_ok=True)
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    S = specs()
    want = [a for a in args if a in S] or list(S)
    if not args or "textures" in args:
        make_textures()
    ipath = os.path.join(OUT, "index.json")
    index = {}
    if os.path.exists(ipath):
        index = json.load(open(ipath, encoding="utf-8"))
    for i, name in enumerate(S):
        if name not in want:
            continue
        sp = dict(S[name])
        sp["seed"] = 100 + i
        g, info = tower(sp)
        export(name, g)
        index[name] = info
    index = {k: index[k] for k in S if k in index}
    with open(ipath, "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, indent=1)
    print("건물 %d종, index.json" % len(index))


if __name__ == "__main__":
    main()
