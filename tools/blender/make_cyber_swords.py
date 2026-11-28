# 사이버 검 무한 열두 자루(docs/cyber_swords.md)를 Blender로 짓고 .glb로 내보낸다. (2026-11-25, 사이버 카타나 311과 같은 방식)
#
# 한 번(chongseong 폴더에서):
#   blender -b -P tools/blender/make_cyber_swords.py [-- 칼번호 ...]
# Blender가 없으면 pip의 bpy 모듈(python 3.13, `pip install bpy`)로 `python tools/blender/make_cyber_swords.py [칼번호 ...]`.
# 결과: assets/swords/<칼 번호>.glb (질감 1K). 게임(SwordModel)은 그 번호의 파일이 있으면 코드 모양(CyberModel) 대신 그것을 쓴다.
#
# 짓는 법은 make_swords.py의 사이버 카타나(311)와 같다: bmesh로 직접 지어 정점 3천 개 아래, 재질은 311의 kat_*(짙은 건메탈,
# 검은 끈 마름모 감김 등)을 Cycles로 1K에 굽고, 빛은 glow_kat_edge(날 끝, 청록)·glow_kat_line(홈과 네온관, 파랑)·glow_kat_rim
# (총구·고리, 청록)뿐이다(빨강 없음). 게임은 CyberModel.glow_boost가 빛 세기만 맞춘다.
#
# 약속(SwordModel과): 코등이 가운데가 원점, 칼날은 +Z(Godot +Y), 손잡이는 -Z, 날은 +X(양날은 ±X), 칼 두께는 Y.
# 총몸·탄창·총열은 +Y쪽(Godot -Z, "칼날 아래")이고 -Y쪽 면에는 판과 네온이 있다.
# 길이·손잡이·칼끝은 게임 값을 그대로 읽는다: 칼날 길이는 data/forms(형태), 손잡이 길이와 휨은 scripts/world/cyber_model.gd의
# SHAPE(grip, sori). 칼끝은 (−sori × 칼날 길이, 0, 칼날 길이)에 정확히 놓는다(SwordModel.tip_x와 같아 베기 궤적이 맞는다).
# 손잡이는 코등이 아래부터 자루끝까지가 grip이다(영주는 그 40% 자리를 쥔다).
#
# 열두 자루(종류, 능력 → 포인트):
#   384 단검 「무음의 송곳니」 연사·글리치 순간베기 → 송곳니 같은 외날, 두 줄 총열 위 긴 소음기와 네온 고리, 칼날의 어긋난 네온 토막
#   486 단검 「잔광」          탄창·과열          → 두꺼운 양날 단검과 빛 홈, 탄알이 보이는 큰 탄창, 방열 지느러미, 총열의 열 고리
#   349 카타나 「절단선」       레일·글리치 순간베기 → 칼등을 따라 휘어 가는 긴 레일 두 줄과 사이의 빛, 팔각 코등이, 어긋난 네온 토막
#   487 카타나 「새벽의 방전」  오버클럭·플라즈마 칼날 → 칼날 속 넓은 빛 코어(홈), 총열의 축전 코일, 네모 코등이
#   470 오니마루 「적귀」       산탄·플라즈마 칼날  → 크게 휜 넓은 태도, 납작하게 벌어진 넓은 총구, 날 속 빛 코어, 오니 뿔 코등이와 청록 눈
#   482 오니마루 「백귀야행」   해킹·EMP           → 칼날 위 회로 네온, 덮개 둘레 EMP 코일, 드럼 탄창, 작은 뿔이 둥글게 돋은 코등이
#   423 환도 「전류」          관통탄·오버클럭     → 곧은 외날, 칼등을 따라 가는 긴 총열과 송곳 탄두, 칼날의 번개 네온, 꽃잎 코등이, 고리 자루끝
#   453 환도 「유리 왕관」      조준·방벽          → 곧은 외날, 칼등 위 조준경(빛 렌즈), 육각 방패 코등이, 빛 결정 왕관 자루끝
#   352 중장도 「폐허의 왕」    산탄·과열          → 넓고 긴 외날(칼끝을 잘라 낸 꼴), 부서진 등 톱니, 세 구멍 넓은 총구, 방열 지느러미와 빛 틈
#   490 중장도 「철의 장례」    EMP·방벽           → 넓은 외날에 덧댄 갑판, EMP 접시와 빛 고리, 관 꼴 방패 코등이
#   329 대검 「도시를 가르는 자」 관통탄·반동 돌진  → 아주 두꺼운 양날과 가운데 빛 홈, 굵은 총열과 송곳 탄두·제동기, 코등이 아래 분사구 둘
#   377 대검 「심야 열차」      레일·반동 돌진      → 아주 두꺼운 양날 위 긴 레일 두 줄과 코일, 앞등(빛 렌즈), 열차 완충기 꼴 코등이, 분사구

import bmesh
import math
import os
import re
import sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_swords as MS   # noqa: E402  (재질·네온관·면 도구를 빌린다. 이 파일은 make_swords의 칼을 짓지 않는다)
import make_heads as K     # noqa: E402

bpy = MS.bpy
OUT = MS.OUT
SIZE = int(os.environ.get("CYBER_TEX", "1024"))   # 질감 크기(시험할 때만 줄인다)
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
IDS = ["384", "486", "349", "487", "470", "482", "423", "453", "352", "490", "329", "377"]

# 재질 번호(_obj에 넘기는 목록의 순서)
MATS = ["glow_kat_edge", "kat_blade", "kat_shin", "glow_kat_line", "kat_plate", "kat_dark", "kat_pale", "kat_wrap", "glow_kat_rim"]
EDGE, BLADE, SHIN, LINE, PLATE, DARK, PALE, WRAP, RIM = range(9)


# ================================================================== 게임 값 읽기
def _shapes():
    """scripts/world/cyber_model.gd의 SHAPE(종류 → sori, grip …)."""
    src = open(os.path.join(ROOT, "scripts", "world", "cyber_model.gd"), encoding="utf-8").read()
    out = {}
    for name, body in re.findall(r'"([^"]+)":\s*\{([^}]*)\}', src):
        vals = dict(re.findall(r'"(\w+)":\s*([^,]+)', body))
        if "sori" in vals and "grip" in vals:
            out[name] = {"sori": float(vals["sori"]), "grip": float(vals["grip"])}
    return out


def _forms():
    """data/forms/<n>_*.tres의 칼날 길이(형태 번호 → m)."""
    d = os.path.join(ROOT, "data", "forms")
    out = {}
    for f in os.listdir(d):
        m = re.match(r"(\d+)_.*\.tres$", f)
        if m:
            txt = open(os.path.join(d, f), encoding="utf-8").read()
            out[int(m.group(1))] = float(re.search(r"blade_length = ([\d.]+)", txt).group(1))
    return out


class Ctx:
    """칼 한 자루의 게임 값."""
    def __init__(self, sid):
        txt = open(os.path.join(ROOT, "data", "swords", "%s.tres" % sid), encoding="utf-8").read()
        self.id = sid
        self.name = re.search(r'display_name = "([^"]*)"', txt).group(1)
        self.sub = re.search(r'sub_type = "([^"]*)"', txt).group(1)
        self.powers = re.findall(r'"([^"]+)"', re.search(r"cyber_powers = PackedStringArray\(([^)]*)\)", txt).group(1))
        self.L = _forms()[int(re.search(r"\nform = (\d+)", txt).group(1))]
        s = _shapes()[self.sub]
        self.grip = s["grip"]
        self.tip_x = -s["sori"] * self.L


# ================================================================== 기본 도구
def _face(bm, vs, mi, inside):
    return MS._kat_face(bm, vs, mi, inside)


def _obj(name, bm, round_all=False):
    """재질 목록은 늘 MATS 전체(쓰지 않은 칸은 내보낼 때 빠진다). 50도보다 꺾인 모서리만 각지게(가는 8각 관은 매끈,
    깎은 판의 모서리는 60도가 넘어 각지다). 칼날의 날·시노기·요코테 같은 선은 bmesh에서 직접 각지게 표시해 둔다."""
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    for mn in MATS:
        me.materials.append(K.mat(mn))
    if round_all:
        me.shade_smooth()
    else:
        K.only(o)
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(50))
    return o


def _rev(bm, prof, segs, mats, origin=(0, 0, 0), axis="Z", sx=1.0, sy=1.0, sharp=(), phase=0.0, seams=False):
    """옆모습 [(반지름, 높이)]을 축 둘레로 돌린다. axis: "Z"·"Y"·"X". 반지름 0인 끝은 한 점으로 닫는다.
    앞면은 옆모습 다각형의 방향으로 정한다(움푹한 총구 구멍도 맞게)."""
    o = Vector(origin)
    if axis == "Z":
        U, V, A = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
    elif axis == "Y":
        U, V, A = Vector((0, 0, 1)), Vector((1, 0, 0)), Vector((0, 1, 0))
    else:
        U, V, A = Vector((0, 1, 0)), Vector((0, 0, 1)), Vector((1, 0, 0))
    poly = list(prof)
    if poly[0][0] > 0:
        poly = [(0.0, poly[0][1])] + poly
    if poly[-1][0] > 0:
        poly = poly + [(0.0, poly[-1][1])]
    area = sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))
    ccw = area > 0
    angs = [phase + k / segs * math.tau for k in range(segs)]
    rings = []
    for r, z in prof:
        if r <= 0.0:
            rings.append([bm.verts.new(o + A * z)])
        else:
            rings.append([bm.verts.new(o + A * z + U * (math.cos(a) * r * sx) + V * (math.sin(a) * r * sy)) for a in angs])
    for i in range(len(prof) - 1):
        (r0, z0), (r1, z1) = prof[i], prof[i + 1]
        dr, dz = r1 - r0, z1 - z0
        if abs(dr) + abs(dz) < 1e-9:
            continue
        nr, nz = (dz, -dr) if ccw else (-dz, dr)
        a, b = rings[i], rings[i + 1]
        for k in range(segs):
            k2 = (k + 1) % segs
            if len(a) == 1:
                vs = [a[0], b[k], b[k2]]
            elif len(b) == 1:
                vs = [a[k], a[k2], b[0]]
            else:
                vs = [a[k], a[k2], b[k2], b[k]]
            am = angs[k] + math.pi / segs
            radial = (U * math.cos(am) * sx + V * math.sin(am) * sy).normalized()
            out = (radial * nr + A * nz).normalized()
            cen = sum((v.co for v in vs), Vector()) / len(vs)
            _face(bm, vs, mats[i] if isinstance(mats, (list, tuple)) else mats, cen - out * 0.001)
    for i in sharp:
        ring = rings[i]
        for k in range(len(ring)):
            e = bm.edges.get((ring[k], ring[(k + 1) % len(ring)]))
            if e:
                e.smooth = False
    if seams:   # 각진 것(팔각 코등이 등): 둘레의 모서리도 각지게
        for i in range(len(rings) - 1):
            if len(rings[i]) > 1 and len(rings[i + 1]) > 1:
                for k in range(segs):
                    e = bm.edges.get((rings[i][k], rings[i + 1][k]))
                    if e:
                        e.smooth = False
    return rings


def _plate(bm, pts, o, U, V, N, t, c, mi, bottom=False):
    """평면 다각형(U·V 좌표)을 N 쪽으로 t만큼 세운 판. 윗면은 c만큼 줄여 옆면이 비스듬하다(깎은 모서리)."""
    o, U, V, N = Vector(o), Vector(U), Vector(V), Vector(N)
    top = MS._kat_inset(pts, c) if c > 0 else pts
    inner = [bm.verts.new(o + U * u + V * v) for u, v in pts]
    outer = [bm.verts.new(o + U * u + V * v + N * t) for u, v in top]
    cen = sum((v.co for v in inner + outer), Vector()) / (2 * len(pts))
    _face(bm, outer, mi, cen)
    if bottom:
        _face(bm, inner, mi, cen)
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        _face(bm, [inner[i], inner[j], outer[j], outer[i]], mi, cen)


def _slab(bm, pts, o, U, V, N, t, c, mi):
    """가운데 면에서 양쪽으로 t/2씩, 양쪽 모서리를 다 깎은 판(코등이, 탄창 등)."""
    N = Vector(N)
    _plate(bm, pts, o, U, V, N, t / 2.0, c, mi)
    _plate(bm, pts, o, U, V, -N, t / 2.0, c, mi)


def _box(bm, center, size, mi, c=0.0):
    hx, hy, hz = size[0] / 2.0, size[1] / 2.0, size[2] / 2.0
    _slab(bm, [(-hx, -hy), (hx, -hy), (hx, hy), (-hx, hy)], center, (1, 0, 0), (0, 1, 0), (0, 0, 1), size[2], c, mi)


def _tube(bm, pts, radii, mi, segs=8, closed=False):
    """점마다 굵기가 다른 관(뿔, 레일, 관). 끝은 막는다."""
    P = [Vector(p) for p in pts]
    n = len(P)
    rings = []
    nrm = None
    for i in range(n):
        t = (P[(i + 1) % n] - P[i - 1]).normalized() if closed else (P[min(i + 1, n - 1)] - P[max(i - 1, 0)]).normalized()
        ref = nrm if nrm is not None else (Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0)))
        nrm = (ref - t * ref.dot(t)).normalized()
        bi = t.cross(nrm)
        r = radii[i]
        if r <= 0.0:
            rings.append([bm.verts.new(P[i])])
        else:
            rings.append([bm.verts.new(P[i] + (nrm * math.cos(k / segs * math.tau + math.pi / segs) + bi * math.sin(k / segs * math.tau + math.pi / segs)) * r) for k in range(segs)])
    for i in range(n if closed else n - 1):
        a, b = rings[i], rings[(i + 1) % n]
        mid = (P[i] + P[(i + 1) % n]) / 2.0
        for k in range(segs):
            k2 = (k + 1) % segs
            if len(a) == 1:
                vs = [a[0], b[k], b[k2]]
            elif len(b) == 1:
                vs = [a[k], a[k2], b[0]]
            else:
                vs = [a[k], a[k2], b[k2], b[k]]
            _face(bm, vs, mi, mid)
    if not closed:
        if len(rings[0]) > 2:
            _face(bm, rings[0], mi, P[0] + (P[1] - P[0]).normalized() * 0.001)
        if len(rings[-1]) > 2:
            _face(bm, rings[-1], mi, P[-1] + (P[-2] - P[-1]).normalized() * 0.001)


def _neon(gl, pts, r=0.0012, closed=False, segs=5, mi=LINE):
    """네온관(기본 파랑 LINE, 고리·총구는 청록 RIM)."""
    MS._kat_tube(gl, pts, r, mi, segs, closed)


def _loop(cx, cy, z, rx, ry, n, axis="Z"):
    """닫힌 고리 점들(네온 고리용)."""
    out = []
    for k in range(n):
        a = k / n * math.tau
        if axis == "Z":
            out.append((cx + math.cos(a) * rx, cy + math.sin(a) * ry, z))
        else:   # Y축 둘레: (x, y=cy, z)
            out.append((cx + math.cos(a) * rx, cy, z + math.sin(a) * ry))
    return out


# ================================================================== 칼날
class Blade:
    """칼날 한 장. 외날(single)은 날·빛 경계·지·(홈)·시노기·(홈)·칼등 어깨·칼등 마루, 양날은 날·빛 경계·지·마루(또는 가운데 홈)·지·빛 경계·날.
    날 끝의 좁은 면만 glow_kat_edge. 홈(groove)은 바닥이 빛(LINE)이고 끝에서 얕아진다. 칼끝은 c.tip_x에 정확히 닿는다."""

    def __init__(self, c, W0, Wy, T0, Ty, K, zc, single=True, M0=None, sp=0.3, pk=0.3, mt=0.68, kp=1.4,
                 groove=None, n_main=8, g=(0.0046, 0.0036), tg=0.0009, bulge=0.06, dark_kiss=True):
        self.c, self.L, self.zc, self.K = c, c.L, zc, K
        self.zy = c.L - K
        self.W0, self.Wy, self.T0, self.Ty = W0, Wy, T0, Ty
        self.single, self.sp, self.pk, self.mt, self.kp = single, sp, pk, mt, kp
        self.groove, self.g, self.tg, self.bulge, self.dark_kiss = groove, g, tg, bulge, dark_kiss
        self.n_main = n_main
        xt = c.tip_x
        if single:
            self.M0 = -W0 / 2.0 if M0 is None else M0
            if self.M0 - xt >= 0.0:      # 칼끝이 칼등 쪽: 칼등 선이 휜다(소리)
                self.S, self.clip = self.M0 - xt, 0.0
            else:                        # 칼끝이 날 쪽: 곧은 칼등, 킷사키에서 칼끝을 안으로 깎는다
                self.S, self.clip = 0.0, xt - self.M0
        else:
            self.M0 = 0.0
            self.S, self.clip = 0.0, 0.0

    # --- 줄기 값
    def s(self, z):
        return max(0.0, (z - self.zc) / (self.L - self.zc))

    def M(self, z):
        """외날: 칼등 x. 양날: 가운데 x(칼끝 x로 곧게 기운다)."""
        if self.single:
            return self.M0 - self.S * self.s(z) ** 2
        return self.c.tip_x * max(0.0, z) / self.L

    def lin(self, a, b, z):
        k = min(1.0, max(0.0, (z - self.zc) / (self.zy - self.zc)))
        return a + (b - a) * k

    def W(self, z):
        return self.lin(self.W0, self.Wy, z)

    def T(self, z):
        return self.lin(self.T0, self.Ty, z)

    def x_at(self, z, f):
        """칼등(외날) 또는 가운데에서 너비 비율 f인 자리의 x(양날은 -1~1)."""
        return self.M(z) + f * self.W(z) if self.single else self.M(z) + f * self.W(z) / 2.0

    def surf(self, z, x):
        """칼날 +Y면의 높이(z에서 x 자리, 단면 그대로). 칼날 위에 얹는 것들이 쓴다. 킷사키 안은 요코테 단면으로."""
        z = min(z, self.zy)
        m, w, t = self.M(z), self.W(z), self.T(z)
        k = min(1.0, max(0.0, (z - self.zc) / (self.zy - self.zc)))
        g = self.g[0] + (self.g[1] - self.g[0]) * k
        top = self.section(m, w if self.single else w / 2.0, t, g, self.tg, self.bulge, self.gdepth(z), False)[0]
        pts = sorted(top, key=lambda p: p[0])
        if x <= pts[0][0]:
            return pts[0][1]
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            if x <= x1:
                return y0 + (y1 - y0) * (x - x0) / max(1e-9, x1 - x0)
        return pts[-1][1]

    def sy(self, z, f):
        return self.surf(z, self.x_at(z, f))

    # --- 홈 깊이(끝에서 얕아진다)
    def gdepth(self, z):
        gr = self.groove
        if not gr:
            return 0.0
        a, b = gr["z"][0] * self.L, gr["z"][1] * self.L
        if z <= a or z >= b:
            return 0.0
        ramp = min(1.0, (z - a) / 0.04, (b - z) / 0.06)
        return gr["d"] * max(0.0, ramp)

    # --- 단면
    def _gq(self, A, B, fa, fb, d):
        def at(f):
            return (A[0] + (B[0] - A[0]) * f, A[1] + (B[1] - A[1]) * f)
        q1, q4 = at(fa), at(fb)
        q2, q3 = at(fa + 0.12 * (fb - fa)), at(fb - 0.12 * (fb - fa))
        return [q1, (q2[0], q2[1] - d), (q3[0], q3[1] - d), q4]

    def section(self, m, w, t, g, tg, bulge, d, kiss):
        """윗면 점들(날 → 칼등 또는 반대 날)과 띠마다의 재질, 각지게 할 점, 홈 바닥 띠 번호."""
        gr = self.groove
        ji = SHIN if (kiss and self.dark_kiss and self.single) else BLADE
        if self.single:
            E, G, S = (m + w, 0.0), (m + w - g, tg), (m + self.sp * w, t)
            xj = m + 0.62 * w if not kiss else (G[0] + S[0]) / 2.0
            k = (G[0] - xj) / max(1e-6, G[0] - S[0])
            J = (xj, G[1] + (S[1] - G[1]) * k + bulge * t)
            top, tm, sharp = [E, G, J], [EDGE, ji], [0]
            gb = -1
            if gr and gr["at"] == "ji":
                q = self._gq(J, S, gr["f"][0], gr["f"][1], d)
                top += q
                tm += [ji, SHIN, LINE, SHIN]
                gb = len(tm) - 2
                sharp += [len(top) - 4, len(top) - 3, len(top) - 2, len(top) - 1]
                tm += [ji]
            else:
                tm += [ji]
            top.append(S)
            sharp.append(len(top) - 1)
            Mt = (m, self.mt * t)
            if gr and gr["at"] == "shin":
                q = self._gq(S, Mt, gr["f"][0], gr["f"][1], d)
                top += q
                tm += [SHIN, SHIN, LINE, SHIN]
                gb = len(tm) - 2
                sharp += [len(top) - 4, len(top) - 3, len(top) - 2, len(top) - 1]
            top.append(Mt)
            tm.append(SHIN)
            sharp.append(len(top) - 1)
            return top, tm, sharp, gb
        # 양날
        E, G = (m + w, 0.0), (m + w - g, tg)
        R = (m, t)
        xj = m + 0.5 * w if not kiss else (G[0] + m) / 2.0
        k = (G[0] - xj) / max(1e-6, G[0] - m)
        J = (xj, G[1] + (R[1] - G[1]) * k + bulge * t)
        top, tm, sharp = [E, G, J], [EDGE, BLADE], [0]
        gb = -1
        if gr:
            gw = gr["w"] * w
            yq = t * 0.97
            top += [(m + gw, yq), (m + gw * 0.72, yq - d), (m - gw * 0.72, yq - d), (m - gw, yq)]
            tm += [BLADE, SHIN, LINE, SHIN]
            gb = len(tm) - 2
            sharp += [3, 4, 5, 6]
        else:
            top.append(R)
            tm.append(BLADE)
            sharp.append(3)
        top += [(2 * m - J[0], J[1]), (2 * m - G[0], G[1]), (2 * m - E[0], 0.0)]
        tm += [BLADE, BLADE, EDGE]
        sharp.append(len(top) - 1)
        return top, tm, sharp, gb

    def ring_at(self, z, u=None):
        """z의 단면 고리(점, 띠 재질, 각진 점, 홈 바닥 띠). u는 킷사키 안의 비율(없으면 몸통)."""
        if u is None:
            m, w, t = self.M(z), self.W(z), self.T(z)
            k = min(1.0, max(0.0, (z - self.zc) / (self.zy - self.zc)))
            g = self.g[0] + (self.g[1] - self.g[0]) * k
            top, tm, sharp, gb = self.section(m, w if self.single else w / 2.0, t, g, self.tg, self.bulge, self.gdepth(z), False)
        else:
            if self.single:
                sp = self.M(z) + self.clip * u * u
                w = self.Wy * (1.0 - u ** self.kp)
                m = sp
            else:
                m = self.M(z)
                w = self.Wy / 2.0 * (1.0 - u ** self.kp)
            t = self.Ty * (1.0 - u) ** 0.9
            g = min(self.g[1] * (1.0 - 0.6 * u), 0.3 * w)
            top, tm, sharp, gb = self.section(m, w, t, g, self.tg * (1.0 - u), 0.0, 0.0, True)
        if self.single:
            P = (top[-1][0] - self.pk * top[-1][1] / self.mt, 0.0)
            ring = top + [P] + [(x, -y) for x, y in reversed(top[1:])]
            seg = tm + [SHIN, SHIN] + tm[::-1]
            n = len(top)
            sh = set(sharp) | {n} | {2 * n - i for i in sharp if i > 0}
            gbs = {gb, 2 * n - 1 - gb} if gb >= 0 else set()
        else:
            ring = top + [(x, -y) for x, y in reversed(top[1:-1])]
            seg = tm + tm[::-1]
            n = len(top)
            sh = set(sharp) | {2 * (n - 1) - i for i in sharp if 0 < i < n - 1}
            gbs = {gb, 2 * (n - 1) - 1 - gb} if gb >= 0 else set()
        return ring, seg, sh, gbs

    def build(self, bm):
        zs0 = self.zc - 0.03
        zs = [zs0, self.zc] + [self.zc + (self.zy - self.zc) * k / self.n_main for k in range(1, self.n_main + 1)]
        # 홈의 시작·끝 자리에 마디를 더해 홈 끝이 또렷하게
        if self.groove:
            for f in self.groove["z"]:
                for dz in (0.0, 0.04 if f == self.groove["z"][0] else -0.06):
                    z = f * self.L + dz
                    if self.zc + 0.01 < z < self.zy - 0.01 and all(abs(z - q) > 0.015 for q in zs):
                        zs.append(z)
        zs.sort()
        kus = (0.14, 0.28, 0.42, 0.56, 0.69, 0.8, 0.89, 0.96)
        secs = [(z, None) for z in zs] + [(self.zy + u * self.K, u) for u in kus]
        yokote = len(zs) - 1
        rings, segs, sharps, gbss, depth = [], [], [], [], []
        for z, u in secs:
            ring, seg, sh, gbs = self.ring_at(z, u)
            rings.append([bm.verts.new((x, y, z)) for x, y in ring])
            segs.append(seg)
            sharps.append(sh)
            gbss.append(gbs)
            depth.append(self.gdepth(z) if u is None else 0.0)
        tip = bm.verts.new((self.c.tip_x, 0.0, self.L))
        n = len(rings[0])
        # 단면 방향(바깥쪽 법선을 정하려고)
        pts = [(v.co.x, v.co.y) for v in rings[1]]
        area = sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1] for i in range(n))
        for i in range(len(rings) - 1):
            a, b = rings[i], rings[i + 1]
            for k in range(n):
                k2 = (k + 1) % n
                mi = segs[i][k]
                if mi == LINE and not (depth[i] > 1e-5 and depth[i + 1] > 1e-5):
                    mi = SHIN if self.single else BLADE
                if i >= yokote and mi == BLADE and self.single and self.dark_kiss:
                    mi = SHIN
                dx, dy = a[k2].co.x - a[k].co.x, a[k2].co.y - a[k].co.y
                out = Vector((dy, -dx, 0.0)) if area > 0 else Vector((-dy, dx, 0.0))
                if out.length < 1e-9:
                    out = Vector(((a[k].co.x - self.M(a[k].co.z)), a[k].co.y, 0.0))
                out.normalize()
                vs = [a[k], a[k2], b[k2], b[k]]
                cen = sum((v.co for v in vs), Vector()) / 4.0
                _face(bm, vs, mi, cen - out * 0.0005)
        last = rings[-1]
        mid = (sum((v.co for v in last), Vector()) + tip.co) / (n + 1)
        for k in range(n):
            mi = segs[-1][k]
            if mi == LINE:
                mi = SHIN
            _face(bm, [last[k], last[(k + 1) % n], tip], mi, mid)
        for i in range(len(rings) - 1):
            for k in sharps[i]:
                e = bm.edges.get((rings[i][k], rings[i + 1][k]))
                if e:
                    e.smooth = False
        for k in range(n):
            e = bm.edges.get((rings[yokote][k], rings[yokote][(k + 1) % n]))
            if e:
                e.smooth = False


# ================================================================== 칼뿌리 기계 덮개와 총몸
def cover(bm, gl, bl, H, gz, nb=3, slant=1.0, plus_plates=False):
    """칼뿌리 덮개(코등이 위 gz ~ H). -Y면에는 바닥 판 위에 판 nb장과 판 사이·칼등 쪽 네온관,
    +Y면은 총몸이 붙는 자리(plus_plates면 거기도 판). 위는 칼날을 감싸며 좁아지는 칼코. 돌려주는 값: (xs, xe, ty)."""
    W0, T0 = bl.W0, bl.T0
    if bl.single:
        xs, xe = bl.M0 - 0.011, bl.M0 + W0 + 0.011
    else:
        xs, xe = -W0 / 2.0 - 0.011, W0 / 2.0 + 0.011
    ty = T0 + 0.0095
    if bl.single:
        sec = [(xe, 0.0), (xe - 0.013, ty), (xs + 0.006, ty), (xs, ty * 0.4), (xs, -ty * 0.4), (xs + 0.006, -ty), (xe - 0.013, -ty)]
    else:
        sec = [(xe, 0.0), (xe - 0.015, ty), (xs + 0.015, ty), (xs, 0.0), (xs + 0.015, -ty), (xe - 0.015, -ty)]
    cx = (xs + xe) / 2.0
    hw = (xe - xs) / 2.0
    z1 = H - 0.035
    kx = (W0 / 2.0 + 0.006) / hw
    ky = (T0 + 0.0028) / ty
    rings = []
    for z, sx, sy in ((gz - 0.001, 1.0, 1.0), (z1, 1.0, 1.0), (H, kx, ky)):
        rings.append([bm.verts.new((cx + (x - cx) * sx, y * sy, z)) for x, y in sec])
    n = len(sec)
    for i in range(2):
        cz = (rings[i][0].co.z + rings[i + 1][0].co.z) / 2.0
        for k in range(n):
            _face(bm, [rings[i][k], rings[i][(k + 1) % n], rings[i + 1][(k + 1) % n], rings[i + 1][k]], DARK if i == 0 else PLATE, (cx, 0.0, cz))
    _face(bm, rings[2], PLATE, (cx, 0.0, H - 0.01))
    for k in range(n):
        e = bm.edges.get((rings[1][k], rings[1][(k + 1) % n]))
        if e:
            e.smooth = False
    # 판: 바닥 판(어둡게) 위에 판 nb장, 비스듬한 틈마다 네온관
    za, zb = gz + 0.012, z1 - 0.01
    xa, xb = xs + 0.008, xe - 0.018
    sides = (-1.0, 1.0) if plus_plates else (-1.0,)
    for sy in sides:
        o = (0.0, sy * ty, 0.0)
        U, V, N = (1, 0, 0), (0, 0, 1), (0, sy, 0)
        _plate(bm, [(xa, za), (xb, za), (xb, zb - 0.025), (xb - 0.015, zb), (xa, zb)], o, U, V, N, 0.0022, 0.0012, DARK)
        oy = ty + 0.0022
        bx0, bx1 = xa + 0.006, xb - 0.004
        span = (zb - 0.006) - (za + 0.006)
        gap = 0.009
        h = (span - gap * (nb - 1)) / nb
        sl = 0.012 * slant
        cuts = [za + 0.006 + k * (h + gap) for k in range(nb + 1)]
        for k in range(nb):
            lo, hi = cuts[k], cuts[k] + h
            lo_l = lo + (sl if k > 0 else 0.0)
            hi_l = hi + (sl if k < nb - 1 else 0.0)
            poly = [(bx0, lo_l), (bx1, lo), (bx1, hi), (bx0, hi_l)]
            _plate(bm, poly, (0.0, sy * oy, 0.0), U, V, N, 0.0026, 0.0014, PLATE)
            if k < nb - 1:
                zm = hi + gap / 2.0
                _neon(gl, [(bx0 - 0.0002, sy * (oy + 0.0006), zm + sl), (bx1 + 0.0002, sy * (oy + 0.0006), zm)], 0.0012)
        _neon(gl, [((xa + bx0) / 2.0 - 0.0005, sy * (oy + 0.0004), za + 0.01), ((xa + bx0) / 2.0 - 0.0005, sy * (oy + 0.0004), zb - 0.01)], 0.001)
    # 칼등(또는 한쪽 날 쪽) 끝면을 따라 가는 네온
    _neon(gl, [(xs + 0.0004, 0.0, gz + 0.02), (xs + 0.0004, 0.0, z1 - 0.01)], 0.0013)
    return xs, xe, ty


def receiver(bm, gl, x0, x1, z0, z1, ty, depth, mag=None):
    """+Y면의 총몸(깎은 상자)과 옆 네온 줄. mag: (x0, x1, z0, z1, 깊이) 탄창이 총몸 밖으로 더 나온다."""
    U, V, N = (1, 0, 0), (0, 0, 1), (0, 1, 0)
    _plate(bm, [(x0, z0), (x1, z0), (x1, z1 - 0.012), (x1 - 0.012, z1), (x0, z1)], (0, ty, 0), U, V, N, depth, 0.003, PLATE)
    _neon(gl, [(x1 - 0.004, ty + depth + 0.0004, z0 + 0.012), (x1 - 0.004, ty + depth + 0.0004, z1 - 0.02)], 0.0011)
    if mag:
        mx0, mx1, mz0, mz1, md = mag
        y0 = ty + depth
        _plate(bm, [(mx0, mz0 + 0.008), (mx1, mz0), (mx1, mz1), (mx0, mz1)], (0, y0, 0), U, V, N, md, 0.0025, DARK)
        _neon(gl, [((mx0 + mx1) / 2.0, y0 + md + 0.0004, mz0 + 0.014), ((mx0 + mx1) / 2.0, y0 + md + 0.0004, mz1 - 0.01)], 0.0013)
    return ty + depth


def barrel(bm, gl, x, y, z0, z1, r, style="plain", rings=0, coils=0, sx=1.0, spike=False, brake=False, segs=12):
    """칼날 아래(+Y)의 총열. 끝에 청록 총구 고리. style: plain·bell(넓은 산탄 총구)·suppressor. spike: 관통 송곳 탄두, brake: 옆구멍 제동기."""
    if style == "bell":
        prof = [(0.0, z0), (r, z0), (r, z1 - 0.07), (r * 1.12, z1 - 0.05), (r * 1.75, z1 - 0.008), (r * 1.75, z1), (r * 1.3, z1), (r * 1.2, z1 - 0.014), (0.0, z1 - 0.014)]
        _rev(bm, prof, 14, [DARK, DARK, PLATE, PLATE, PLATE, PLATE, DARK, DARK], (x, y, 0), "Z", sx, 1.0, sharp=(2, 4, 5, 6))
        _neon(gl, _loop(x, y, z1 - 0.003, r * 1.78 * sx, r * 1.78, 16), 0.0014, True, mi=RIM)
    elif style == "suppressor":
        zsu = z0 + (z1 - z0) * 0.42
        prof = [(0.0, z0), (r, z0), (r, zsu), (r * 1.5, zsu + 0.008), (r * 1.5, z1 - 0.008), (r * 1.3, z1), (r * 0.55, z1), (r * 0.55, z1 - 0.006), (0.0, z1 - 0.006)]
        _rev(bm, prof, 12, [DARK, DARK, PLATE, PLATE, PLATE, PLATE, DARK, DARK], (x, y, 0), "Z", sharp=(2, 3, 4, 5))
        for k in range(3):
            zz = zsu + 0.03 + k * (z1 - zsu - 0.06) / 2.0
            _neon(gl, _loop(x, y, zz, r * 1.52, r * 1.52, 12), 0.0009, True, 4)
        _neon(gl, _loop(x, y, z1 - 0.002, r * 1.32, r * 1.32, 12), 0.0011, True, mi=RIM)
    else:
        prof = [(0.0, z0), (r, z0), (r, z1 - 0.016), (r * 1.2, z1 - 0.012), (r * 1.2, z1), (r * 0.62, z1), (r * 0.62, z1 - 0.007), (0.0, z1 - 0.007)]
        _rev(bm, prof, segs, [DARK, DARK, PLATE, PLATE, PLATE, DARK, DARK], (x, y, 0), "Z", sx, 1.0, sharp=(2, 3, 4, 5))
        _neon(gl, _loop(x, y, z1 - 0.006, r * 1.22 * sx, r * 1.22, segs), 0.0012, True, mi=RIM)
    if spike:   # 관통탄: 총구 밖으로 나온 송곳 탄두
        _rev(bm, [(0.0, z1 - 0.006), (r * 0.5, z1 - 0.006), (r * 0.5, z1 + 0.01), (0.0, z1 + 0.06)], 10, [PALE, PALE, PALE], (x, y, 0), "Z", sharp=(1, 2))
    if brake:   # 반동 돌진: 총구 앞 옆구멍 난 제동기
        _box(bm, (x, y, z1 - 0.045), (r * 3.0, r * 2.2, 0.05), PLATE, 0.004)
        for k in range(3):
            zz = z1 - 0.06 + k * 0.014
            for s in (-1.0, 1.0):
                _neon(gl, [(x + s * r * 1.52, y - r * 0.7, zz), (x + s * r * 1.52, y + r * 0.7, zz)], 0.0016)
    for k in range(rings):   # 열 고리(과열)
        zz = z0 + 0.03 + (z1 - z0 - 0.08) * (k + 0.5) / rings
        _neon(gl, _loop(x, y, zz, r * 1.18 * sx, r * 1.18, 12), 0.0012, True, 4)
    for k in range(coils):   # 축전 코일(오버클럭·EMP): 어두운 띠 위 네온
        zz = z0 + 0.04 + (z1 - z0 - 0.1) * (k + 0.5) / coils
        _rev(bm, [(r * 1.0, zz - 0.007), (r * 1.4, zz - 0.005), (r * 1.4, zz + 0.005), (r * 1.0, zz + 0.007)], 12, [DARK, DARK, DARK], (x, y, 0), "Z", sx, 1.0)
        _neon(gl, _loop(x, y, zz, r * 1.42 * sx, r * 1.42, 12), 0.0011, True, 4)


def bracket(bm, bl, x, y_top, z, w=0.016, h=0.014):
    """총열을 칼날 면에 잇는 받침."""
    y0 = bl.surf(z, x) - 0.001
    _box(bm, (x, (y0 + y_top) / 2.0, z), (w, y_top - y0, h), DARK, 0.0015)


# ================================================================== 코등이, 손잡이
def guard_round(bm, gl, R, th, segs=28, sides=0, rot=0.0, sx=1.0, sy=1.0, ring2=True):
    """둥근(sides=0) 또는 각진(sides>0) 코등이. 둘레 가운데 얕은 홈에 청록 네온 고리, 칼 쪽 면에 가는 네온 고리."""
    h = th / 2.0
    prof = [(0.0, h), (R - 0.006, h), (R, h - 0.003), (R, 0.0025), (R - 0.001, 0.0019),
            (R - 0.001, -0.0019), (R, -0.0025), (R, -h + 0.003), (R - 0.006, -h), (0.0, -h)]
    n = sides if sides else segs
    _rev(bm, prof, n, DARK, sx=sx, sy=sy, sharp=(1, 3, 4, 5, 6, 8) if sides else (3, 4, 5, 6), phase=rot, seams=bool(sides))
    if sides:
        pts = []
        for k in range(sides):
            a0, a1 = rot + k / sides * math.tau, rot + (k + 1) / sides * math.tau
            for f in (0.0, 0.5):
                a = a0 + (a1 - a0) * f
                rr = (R - 0.0004) * (1.0 if f == 0.0 else math.cos(math.pi / sides))
                pts.append((math.cos(a) * rr * sx, math.sin(a) * rr * sy, 0.0))
        _neon(gl, pts, 0.0015, True, mi=RIM)
    else:
        _neon(gl, _loop(0, 0, 0.0, (R - 0.0004) * sx, (R - 0.0004) * sy, 28), 0.0015, True, mi=RIM)
    if ring2:
        _neon(gl, _loop(0, 0, h + 0.0005, (R - 0.014) * sx, (R - 0.014) * sy, 20), 0.001, True, 4, mi=RIM)


def hilt(bm, gl, c, gz, r=0.0185, ry=0.82, wrap=True, pommel="cap", ribs=0):
    """손잡이: 코등이 아래 gz부터 자루끝까지 c.grip. 옅은 고리 둘(위아래), 감김(wrap) 또는 홈 판 고무(ribs), 자루끝."""
    g = c.grip
    zt, zb = -gz, -gz - g
    pom = {"cap": 0.026, "spike": 0.04, "ring": 0.034, "hex": 0.028, "block": 0.04, "crown": 0.03}[pommel]
    pom = min(pom, g * 0.28)
    zk = zb + pom                      # 자루끝 위
    ring_h = min(0.018, g * 0.12)
    zf = zt - ring_h                   # 위 고리 아래
    zk2 = zk + 0.008                   # 아래 고리 위
    if wrap:
        prof = [(r, zf - 0.004)] + [(r * (1.0 - 0.05 * math.sin(math.pi * k / 4.0)), zf - (zf - zk2) * k / 4.0) for k in range(1, 4)] + [(r * 0.99, zk2 + 0.004)]
        _rev(bm, prof, 18, WRAP, sx=1.0, sy=ry)
    else:   # 홈 판 손잡이
        prof = []
        nrib = max(3, ribs)
        for k in range(nrib):
            za = zf - (zf - zk2) * k / nrib
            zb2 = zf - (zf - zk2) * (k + 1) / nrib
            prof += [(r, za - 0.001), (r * 1.07, za - 0.004), (r * 1.07, zb2 + 0.004), (r, zb2 + 0.001)]
        _rev(bm, prof, 16, DARK, sx=1.0, sy=ry)
    for top, bot, rr in ((zt, zf, r + 0.0022), (zk2, zk, r + 0.0012)):
        h = top - bot
        e = min(0.0016, h * 0.25)
        prof = [(0.0, top), (rr - e, top), (rr, top - e), (rr, bot + e), (rr - e, bot), (0.0, bot)]
        _rev(bm, prof, 16, PALE, sx=1.0, sy=ry + 0.02)
    # 자루끝
    if pommel == "cap":
        hx, hy = r + 0.003, (r + 0.003) * 0.88
        _slab(bm, [(-hx, -hy), (hx, -hy), (hx, hy), (-hx, hy)], (0, 0, (zk + zb) / 2.0), (1, 0, 0), (0, 1, 0), (0, 0, 1), zk - zb, 0.0026, PLATE)
        c2 = 0.0026
        _neon(gl, [(hx, -hy + c2, zb + 0.008), (hx, hy - c2, zb + 0.008), (hx - c2, hy, zb + 0.008), (-hx + c2, hy, zb + 0.008),
                   (-hx, hy - c2, zb + 0.008), (-hx, -hy + c2, zb + 0.008), (-hx + c2, -hy, zb + 0.008), (hx - c2, -hy, zb + 0.008)], 0.0012, True, mi=RIM)
    elif pommel == "spike":   # 깨뜨리는 송곳
        _rev(bm, [(0.0, zk), (r + 0.002, zk), (r + 0.002, zk - 0.01), (r * 0.6, zk - 0.016), (0.0, zb)], 8, [PLATE, PLATE, PLATE, PALE], sharp=(1, 2, 3))
        _neon(gl, _loop(0, 0, zk - 0.005, r + 0.0025, r + 0.0025, 16), 0.0011, True, mi=RIM)
    elif pommel == "ring":    # 환도의 고리 자루끝: 쇠 고리와 네온
        _rev(bm, [(0.0, zk), (r, zk), (r * 0.8, zk - 0.008), (0.0, zk - 0.01)], 16, PLATE)
        ring_r = (pom - 0.012) / 2.0 + 0.002
        _tube(bm, _loop(0, 0, zk - 0.01 - ring_r, ring_r, ring_r, 16, "Y"), [0.0035] * 16, PLATE, 6, True)
        _neon(gl, _loop(0, 0.0036, zk - 0.01 - ring_r, ring_r, ring_r, 16, "Y"), 0.0009, True, 5, mi=RIM)
    elif pommel == "hex":
        _rev(bm, [(0.0, zk), (r + 0.004, zk), (r + 0.004, zb + 0.004), (r, zb), (0.0, zb)], 6, PLATE, sharp=(1, 2, 3), phase=math.pi / 6)
        rh = r + 0.0044
        _neon(gl, [(math.cos(math.pi / 6 + k * math.pi / 3) * rh, math.sin(math.pi / 6 + k * math.pi / 3) * rh, (zk + zb) / 2.0) for k in range(6)], 0.0012, True, mi=RIM)
    elif pommel == "block":
        hx, hy = r + 0.008, r + 0.006
        _slab(bm, [(-hx, -hy), (hx, -hy), (hx, hy), (-hx, hy)], (0, 0, (zk + zb) / 2.0), (1, 0, 0), (0, 1, 0), (0, 0, 1), zk - zb, 0.004, PLATE)
        for s in (-1.0, 1.0):
            _neon(gl, [(-hx + 0.006, s * (hy + 0.0003), (zk + zb) / 2.0), (hx - 0.006, s * (hy + 0.0003), (zk + zb) / 2.0)], 0.0014, mi=RIM)
    else:   # crown: 빛 결정 왕관
        _rev(bm, [(0.0, zk), (r + 0.004, zk), (r + 0.006, zb + 0.008), (r * 0.5, zb), (0.0, zb)], 12, PLATE, sharp=(1, 2))
        for k in range(6):   # 빛 결정(청록으로 빛나는 뾰족한 결정 여섯)
            a = k / 6 * math.tau
            p0 = Vector((math.cos(a) * (r + 0.003), math.sin(a) * (r + 0.003) * ry, zb + 0.014))
            p1 = p0 + Vector((math.cos(a) * 0.012, math.sin(a) * 0.012 * ry, -0.028))
            _tube(gl, [tuple(p0), tuple(p1)], [0.0036, 0.0], RIM, 4)
    return zb


# ================================================================== 덧붙이는 포인트
def glitch_dashes(gl, bl, z0, z1, n=6, side=-1.0, f0=0.34, f1=0.52):
    """글리치 순간베기: 칼날 면 위 어긋난 네온 토막(계단처럼 엇갈린다)."""
    for k in range(n):
        z = z0 + (z1 - z0) * k / max(1, n - 1)
        f = f0 if k % 2 == 0 else f1
        ln = 0.035 + 0.02 * (k % 3)
        y = side * (bl.sy(z, f) + 0.0007)
        _neon(gl, [(bl.x_at(z, f), y, z), (bl.x_at(z + ln, f), side * (bl.sy(z + ln, f) + 0.0007), z + ln)], 0.0011)


def rails(bm, gl, bl, z0, z1, f0, f1, side=1.0, n=10, clamps=4, coil=False):
    """레일 두 줄: 칼날 면(+Y) 위를 칼날을 따라(휘면 같이 휘며) 가는 검은 레일과 사이의 빛, 죔쇠."""
    zs = [z0 + (z1 - z0) * k / n for k in range(n + 1)]
    for f in (f0, f1):
        pts = [(bl.x_at(z, f), side * (bl.sy(z, f) + 0.0026), z) for z in zs]
        _tube(bm, pts, [0.0032] * len(pts), DARK, 4)
    fm = (f0 + f1) / 2.0
    hi = [max(bl.sy(z, f0), bl.sy(z, f1), bl.sy(z, fm)) for z in zs]
    _neon(gl, [(bl.x_at(z, fm), side * (h + 0.0016), z) for z, h in zip(zs, hi)], 0.0015)
    for k in range(clamps):
        z = z0 + 0.03 + (z1 - z0 - 0.06) * k / max(1, clamps - 1)
        xa, xb = bl.x_at(z, f0), bl.x_at(z, f1)
        h = max(bl.sy(z, f0), bl.sy(z, f1))
        _box(bm, ((xa + xb) / 2.0, side * (h + 0.0045), z), (abs(xb - xa) + 0.012, 0.007, 0.012), PLATE, 0.0015)
        if coil:
            _neon(gl, [((xa + xb) / 2.0 - (abs(xb - xa) / 2.0 + 0.0062), side * (h + 0.0082), z),
                       ((xa + xb) / 2.0 + (abs(xb - xa) / 2.0 + 0.0062), side * (h + 0.0082), z)], 0.0012, mi=RIM)


def trace(gl, bl, path, side=-1.0, pad=True):
    """해킹: 칼날 면 위 회로 네온. path는 (z, 너비 비율) 점들, 꺾인 자리는 둥글게, 끝에 작은 고리."""
    pts = [(bl.x_at(z, f), side * (bl.sy(z, f) + 0.0007), z) for z, f in path]
    _neon(gl, [tuple(p) for p in MS._kat_round(pts, 0.006)], 0.001)
    if pad:
        z, f = path[-1]
        x = bl.x_at(z, f)
        y = side * (bl.sy(z, f) + 0.0007)
        _neon(gl, [(x + math.cos(a) * 0.0035, y, z + 0.0045 + math.sin(a) * 0.0035) for a in [k / 8 * math.tau for k in range(8)]], 0.0008, True, 5)


def zigzag(gl, bl, z0, z1, n, f0, f1, side=-1.0):
    """전류: 칼날 면 위 번개 꼴 네온."""
    pts = []
    for k in range(n + 1):
        z = z0 + (z1 - z0) * k / n
        f = f0 if k % 2 == 0 else f1
        pts.append((bl.x_at(z, f), side * (bl.sy(z, f) + 0.0007), z))
    _neon(gl, pts, 0.0012)


def fins(bm, gl, x0, x1, y0, z0, z1, n, depth, axis_y=1.0):
    """방열 지느러미(과열): +Y쪽으로 나온 얇은 판 여러 장, 사이마다 빛 틈."""
    for k in range(n):
        z = z0 + (z1 - z0) * k / max(1, n - 1)
        _box(bm, ((x0 + x1) / 2.0, axis_y * (y0 + depth / 2.0), z), (x1 - x0, depth, 0.0035), PLATE, 0.0008)
        if k < n - 1:
            zm = z + (z1 - z0) / max(1, n - 1) / 2.0
            _neon(gl, [(x0 + 0.004, axis_y * (y0 + 0.0012), zm), (x1 - 0.004, axis_y * (y0 + 0.0012), zm)], 0.0012)


def vent_slits(gl, bl, z0, n, f0, f1, side=-1.0, step=0.022):
    """칼날 밑동의 빛 틈(과열): 짧은 가로 네온."""
    for k in range(n):
        z = z0 + k * step
        _neon(gl, [(bl.x_at(z, f0), side * (bl.sy(z, f0) + 0.0007), z), (bl.x_at(z, f1), side * (bl.sy(z, f1) + 0.0007), z)], 0.0011)


def horn(bm, base, d1, d2, length, r0):
    """휘어 오르는 뿔(굵기가 줄어드는 관)."""
    b = Vector(base)
    pts, rr = [], []
    for k in range(5):
        t = k / 4.0
        p = b + Vector(d1) * (length * t) + Vector(d2) * (length * 0.35 * t * t)
        pts.append(tuple(p))
        rr.append(r0 * (1.0 - t) ** 0.8 + 0.0006)
    rr[-1] = 0.0
    _tube(bm, pts, rr, PLATE, 7)


def dish(bm, gl, x, y, z, R, depth=0.016):
    """EMP 접시: +Y로 향한 얕은 접시와 동심 네온 고리 둘."""
    _rev(bm, [(0.0, 0.0), (R * 0.35, 0.0), (R, depth * 0.7), (R * 1.02, depth), (R * 0.9, depth * 0.9), (R * 0.25, depth * 0.35), (0.0, depth * 0.35)],
         24, [DARK, PLATE, PLATE, PLATE, DARK, DARK], (x, y, z), "Y", sharp=(2, 3))
    _neon(gl, _loop(x, y + depth * 0.95, z, R * 0.92, R * 0.92, 24, "Y"), 0.0013, True)
    _neon(gl, _loop(x, y + depth * 0.55, z, R * 0.55, R * 0.55, 18, "Y"), 0.0011, True, 5)
    _rev(gl, [(0.0, depth * 0.4), (R * 0.12, depth * 0.4), (R * 0.12, depth * 1.1), (0.0, depth * 1.15)], 8, RIM, (x, y, z), "Y")


def lamp(bm, gl, x, y, z, R, segs=16):
    """앞등: +Y로 향한 둥근 등과 빛 렌즈."""
    _rev(bm, [(0.0, 0.0), (R * 1.15, 0.0), (R * 1.15, 0.014), (R * 0.85, 0.016), (0.0, 0.012)], segs, [PLATE, PLATE, PLATE, DARK], (x, y, z), "Y", sharp=(1, 2))
    _rev(gl, [(0.0, 0.0165), (R * 0.82, 0.0128), (0.0, 0.0127)], segs, RIM, (x, y, z), "Y")


def thruster(bm, gl, x, z0, z1, r, y=0.0, segs=10):
    """반동 분사구: 아래로 벌어진 통과 안쪽 빛."""
    prof = [(0.0, z0), (r * 0.8, z0), (r, z0 - 0.006), (r * 1.35, z1), (r * 1.1, z1), (r * 0.7, z1 + 0.008), (0.0, z1 + 0.008)]
    _rev(bm, prof, segs, [PLATE, PLATE, PLATE, PLATE, DARK, DARK], (x, y, 0), "Z", sharp=(2, 3, 4))
    _rev(gl, [(0.0, z1 + 0.0085), (r * 0.68, z1 + 0.0085), (0.0, z1 + 0.0084)], segs, RIM, (x, y, 0), "Z")
    _neon(gl, _loop(x, y, z1 + 0.0015, r * 1.36, r * 1.36, segs), 0.0011, True, mi=RIM)


def scope(bm, gl, x, y, z0, z1, r):
    """조준경: 통과 양끝 빛 렌즈."""
    prof = [(0.0, z0), (r * 1.25, z0), (r * 1.25, z0 + 0.02), (r, z0 + 0.03), (r, z1 - 0.03), (r * 1.3, z1 - 0.018), (r * 1.3, z1), (0.0, z1)]
    _rev(bm, prof, 14, [PLATE, PLATE, PLATE, DARK, PLATE, PLATE, PLATE], (x, y, 0), "Z", sharp=(1, 2, 5, 6))
    for zz, s in ((z0 - 0.0006, -1.0), (z1 + 0.0006, 1.0)):
        _rev(gl, [(0.0, zz), (r * (1.1 if s > 0 else 0.95), zz), (0.0, zz + s * 0.0002)], 14, RIM, (x, y, 0), "Z")
    _neon(gl, _loop(x, y, (z0 + z1) / 2.0, r * 1.02, r * 1.02, 14), 0.0009, True, 5)
    for zz in (z0 + 0.04, z1 - 0.045):
        _box(bm, (x, y - r - 0.006, zz), (r * 1.2, 0.012, 0.014), DARK, 0.0015)


def teeth(bm, bl, z0, z1, n, h, side_x=-1.0):
    """부서진 등 톱니(폐허의 왕): 칼등 위 삼각 이빨."""
    for k in range(n):
        za = z0 + (z1 - z0) * k / n
        zb = za + (z1 - z0) / n * 0.8
        hh = h * (0.6 + 0.4 * ((k * 7) % 3) / 2.0)
        xa = bl.M(za)
        pts = [(za, 0.0), (zb, 0.0), (za + (zb - za) * 0.3, hh)]
        T = bl.surf(za, xa - 0.001) * 0.9
        o = (xa, -T, 0.0)
        _plate(bm, [(z, -x) for z, x in pts], o, (0, 0, 1), (1, 0, 0), (0, 1, 0), 2 * T, 0.0, DARK, bottom=True)


# ================================================================== 열두 자루
def sw_384(c, bm, gl):
    """단검 「무음의 송곳니」(연사·글리치 순간베기)."""
    bl = Blade(c, 0.034, 0.028, 0.0046, 0.0036, 0.085, 0.13, M0=-0.017, kp=1.05, n_main=5, g=(0.0036, 0.003))
    bl.build(bm)
    gz = 0.009
    xs, xe, ty = cover(bm, gl, bl, 0.13, gz, nb=2, slant=-1.0)
    top = receiver(bm, gl, xs + 0.004, xe - 0.012, gz + 0.006, 0.122, ty, 0.012, (xs + 0.008, xe - 0.02, gz + 0.012, 0.07, 0.022))
    for k, bx in enumerate((-0.008, 0.005)):   # 연사: 두 줄 총열
        barrel(bm, gl, bx, top + 0.0055, 0.11, 0.2, 0.0055)
    barrel(bm, gl, -0.0015, top + 0.011, 0.19, 0.43, 0.0085, "suppressor")
    bracket(bm, bl, -0.0015, top + 0.004, 0.3)
    glitch_dashes(gl, bl, 0.17, 0.4, 5, -1.0, 0.4, 0.62)
    _slab(bm, [(-0.04, -0.016), (0.03, -0.022), (0.045, 0.0), (0.03, 0.022), (-0.04, 0.016), (-0.05, 0.0)], (0, 0, 0), (1, 0, 0), (0, 1, 0), (0, 0, 1), 2 * gz, 0.003, DARK)
    _neon(gl, [(-0.04, 0.0165, 0.0), (0.03, 0.0225, 0.0), (0.0455, 0.0, 0.0), (0.03, -0.0225, 0.0), (-0.04, -0.0165, 0.0), (-0.0505, 0.0, 0.0)], 0.0011, True)
    hilt(bm, gl, c, gz, 0.0165, 0.8, wrap=False, pommel="spike", ribs=4)


def sw_486(c, bm, gl):
    """단검 「잔광」(탄창·과열)."""
    bl = Blade(c, 0.046, 0.034, 0.0062, 0.0046, 0.11, 0.12, single=False, kp=1.0, n_main=5, bulge=0.04,
               groove={"at": "mid", "z": (0.27, 0.78), "w": 0.2, "d": 0.0016}, g=(0.0034, 0.0028))
    bl.build(bm)
    gz = 0.009
    xs, xe, ty = cover(bm, gl, bl, 0.12, gz, nb=2, slant=1.0)
    top = receiver(bm, gl, xs + 0.006, xe - 0.006, gz + 0.006, 0.112, ty, 0.01)
    # 탄창: 크고 길게 나온 상자와 탄알 창(빛 점 다섯)
    _slab(bm, [(-0.018, 0.014), (0.018, 0.014), (0.018, 0.092), (-0.018, 0.092)], (0, top + 0.016, 0.0), (1, 0, 0), (0, 0, 1), (0, 1, 0), 0.032, 0.003, DARK)
    for k in range(5):   # 탄알 창: 빛나는 탄 다섯
        z = 0.026 + k * 0.014
        _neon(gl, [(-0.008, top + 0.0322, z), (0.008, top + 0.0322, z)], 0.0016, mi=RIM)
    barrel(bm, gl, 0.0, top + 0.0075, 0.1, 0.32, 0.0075, rings=3)
    bracket(bm, bl, 0.0, top + 0.001, 0.2)
    _slab(bm, [(-0.05, -0.014), (0.05, -0.014), (0.056, 0.0), (0.05, 0.014), (-0.05, 0.014), (-0.056, 0.0)], (0, 0, 0), (1, 0, 0), (0, 1, 0), (0, 0, 1), 2 * gz, 0.003, DARK)
    for k in range(4):   # 코등이 양 끝 방열 지느러미
        for s in (-1.0, 1.0):
            _box(bm, (s * (0.06 + k * 0.006), 0.0, 0.0), (0.0025, 0.03 - k * 0.004, 0.024), PLATE, 0.0006)
    _neon(gl, [(-0.05, 0.0145, 0.0), (0.05, 0.0145, 0.0)], 0.0011)
    _neon(gl, [(-0.05, -0.0145, 0.0), (0.05, -0.0145, 0.0)], 0.0011)
    hilt(bm, gl, c, gz, 0.017, 0.85, wrap=False, pommel="hex", ribs=4)


def sw_349(c, bm, gl):
    """카타나 「절단선」(레일·글리치 순간베기)."""
    bl = Blade(c, 0.054, 0.038, 0.006, 0.0043, 0.085, 0.27, groove={"at": "shin", "z": (0.2, 0.45), "f": (0.25, 0.85), "d": 0.0012})
    bl.build(bm)
    gz = 0.009
    xs, xe, ty = cover(bm, gl, bl, 0.27, gz, nb=3, slant=1.0)
    top = receiver(bm, gl, xs + 0.004, xe - 0.016, gz + 0.008, 0.25, ty, 0.012, (xs + 0.012, xs + 0.045, gz + 0.02, 0.12, 0.022))
    barrel(bm, gl, bl.M0 + 0.022, top + 0.007, 0.24, 0.62, 0.0068)
    bracket(bm, bl, bl.M0 + 0.022, top + 0.001, 0.44)
    rails(bm, gl, bl, 0.68, 1.22, 0.1, 0.32, 1.0, n=10, clamps=4)
    glitch_dashes(gl, bl, 0.5, 1.15, 6, -1.0, 0.42, 0.62)
    guard_round(bm, gl, 0.06, 0.017, sides=8, rot=math.pi / 8)
    hilt(bm, gl, c, gz, pommel="cap")


def sw_487(c, bm, gl):
    """카타나 「새벽의 방전」(오버클럭·플라즈마 칼날)."""
    bl = Blade(c, 0.06, 0.042, 0.0064, 0.0046, 0.09, 0.25, groove={"at": "ji", "z": (0.2, 0.86), "f": (0.12, 0.88), "d": 0.0018})
    bl.build(bm)
    gz = 0.01
    xs, xe, ty = cover(bm, gl, bl, 0.25, gz, nb=2, slant=-1.0)
    top = receiver(bm, gl, xs + 0.004, xe - 0.016, gz + 0.008, 0.23, ty, 0.016)
    barrel(bm, gl, bl.M0 + 0.026, top + 0.002, 0.2, 0.56, 0.0105, coils=4)
    bracket(bm, bl, bl.M0 + 0.026, top - 0.007, 0.5)
    for k in range(5):   # 오버클럭 표시 막대(총몸 위)
        _box(gl, (xe - 0.03, top + 0.0005, 0.04 + k * 0.03), (0.012, 0.0012, 0.008 + k * 0.003), LINE)
    guard_round(bm, gl, 0.058, 0.018, sides=4, rot=math.pi / 4, sx=1.05, sy=0.95)
    hilt(bm, gl, c, gz, pommel="cap")


def sw_470(c, bm, gl):
    """오니마루 「적귀」(산탄·플라즈마 칼날): 크게 휜 넓은 태도."""
    bl = Blade(c, 0.07, 0.05, 0.0068, 0.005, 0.1, 0.2, groove={"at": "ji", "z": (0.22, 0.8), "f": (0.2, 0.75), "d": 0.0016})
    bl.build(bm)
    gz = 0.011
    xs, xe, ty = cover(bm, gl, bl, 0.2, gz, nb=2, slant=1.0)
    top = receiver(bm, gl, xs + 0.004, xe - 0.018, gz + 0.008, 0.19, ty, 0.014, (xs + 0.03, xe - 0.03, gz + 0.012, 0.09, 0.02))
    barrel(bm, gl, bl.M0 + 0.035, top + 0.01, 0.16, 0.46, 0.011, "bell", sx=1.5)
    bracket(bm, bl, bl.M0 + 0.033, top + 0.002, 0.33, 0.02)
    # 오니 뿔 코등이: 가로 막대 양끝에서 휘어 오르는 두 뿔, 가운데 청록 눈
    _slab(bm, [(-0.085, -0.02), (0.085, -0.02), (0.1, 0.0), (0.085, 0.02), (-0.085, 0.02), (-0.1, 0.0)], (0, 0, 0), (1, 0, 0), (0, 1, 0), (0, 0, 1), 2 * gz, 0.004, DARK)
    for s in (-1.0, 1.0):
        horn(bm, (s * 0.088, 0.0, 0.004), (s * 0.25, 0.0, 1.0), (s * 0.5, 0.0, -0.2), 0.12, 0.013)
        _neon(gl, [(s * 0.02, 0.0205, 0.0), (s * 0.08, 0.0205, 0.0)], 0.0011)
        _neon(gl, [(s * 0.02, -0.0205, 0.0), (s * 0.08, -0.0205, 0.0)], 0.0011)
    for sy in (-1.0, 1.0):   # 청록 눈
        _rev(gl, [(0.0, 0.0), (0.0075, 0.0), (0.0, sy * 0.003)], 12, RIM, (0, sy * 0.0205, 0), "Y")
    hilt(bm, gl, c, gz, pommel="cap")


def sw_482(c, bm, gl):
    """오니마루 「백귀야행」(해킹·EMP)."""
    bl = Blade(c, 0.066, 0.047, 0.0066, 0.0048, 0.1, 0.22)
    bl.build(bm)
    gz = 0.011
    xs, xe, ty = cover(bm, gl, bl, 0.22, gz, nb=2, slant=-1.0, plus_plates=False)
    top = receiver(bm, gl, xs + 0.004, xe - 0.018, gz + 0.008, 0.21, ty, 0.012)
    # 드럼 탄창(Y축 둘레 원통)과 네온 고리
    cxm = (xs + xe) / 2.0
    _rev(bm, [(0.0, 0.0), (0.036, 0.0), (0.036, 0.027), (0.032, 0.03), (0.0, 0.03)], 20, [PLATE, PLATE, PLATE, DARK], (cxm, top, 0.085), "Y", sharp=(1, 2, 3))
    _neon(gl, _loop(cxm, top + 0.0302, 0.085, 0.025, 0.025, 16, "Y"), 0.0013, True)
    _neon(gl, _loop(cxm, top + 0.0302, 0.085, 0.012, 0.012, 10, "Y"), 0.001, True, 4)
    barrel(bm, gl, bl.M0 + 0.03, top + 0.0075, 0.2, 0.52, 0.0075)
    bracket(bm, bl, bl.M0 + 0.03, top + 0.0005, 0.4)
    # EMP 코일: 덮개 둘레 세 고리
    for k in range(3):
        z = 0.05 + k * 0.055
        _neon(gl, _loop(cxm, 0.0, z, (xe - xs) / 2.0 + 0.004, ty + 0.017, 18), 0.0016, True, 4)
    # 해킹 회로(칼날 -Y면)
    trace(gl, bl, [(0.24, 0.2), (0.36, 0.2), (0.4, 0.45), (0.55, 0.45)], -1.0)
    trace(gl, bl, [(0.3, 0.6), (0.48, 0.6), (0.52, 0.35), (0.7, 0.35), (0.74, 0.55), (0.86, 0.55)], -1.0)
    trace(gl, bl, [(0.62, 0.22), (0.78, 0.22)], -1.0)
    # 작은 뿔이 둥글게 돋은 코등이
    guard_round(bm, gl, 0.056, 0.018, segs=24, ring2=False)
    for k in range(6):
        a = (k + 0.5) / 6 * math.tau
        p = (math.cos(a) * 0.054, math.sin(a) * 0.054, 0.004)
        horn(bm, p, (math.cos(a) * 0.5, math.sin(a) * 0.5, 0.85), (0, 0, 0.0), 0.03, 0.0055)
    hilt(bm, gl, c, gz, pommel="cap")


def sw_423(c, bm, gl):
    """환도 「전류」(관통탄·오버클럭): 곧은 외날, 칼등을 따라 긴 총열."""
    bl = Blade(c, 0.05, 0.042, 0.0058, 0.0046, 0.08, 0.2, M0=c.tip_x)
    bl.build(bm)
    gz = 0.01
    xs, xe, ty = cover(bm, gl, bl, 0.2, gz, nb=3, slant=1.0, plus_plates=True)
    # 칼등을 따라 가는 총열(곧은 칼이라 끝까지 붙는다)과 송곳 탄두, 오버클럭 코일
    bx = bl.M0 - 0.009
    barrel(bm, gl, bx, 0.0, 0.18, 0.82, 0.0075, coils=2, spike=True)
    for z in (0.4, 0.7):
        _box(bm, (bl.M0 - 0.003, 0.0, z), (0.01, 0.009, 0.014), DARK, 0.0012)
    zigzag(gl, bl, 0.24, 0.92, 9, 0.38, 0.66, -1.0)
    zigzag(gl, bl, 0.3, 0.8, 6, 0.4, 0.62, 1.0)
    # 꽃잎 코등이(여섯 잎)와 네온 고리
    prof_r = 0.056
    guard_round(bm, gl, prof_r, 0.016, segs=24, ring2=False)
    for k in range(6):
        a = k / 6 * math.tau
        _slab(bm, [(-0.012, 0.0), (0.0, -0.009), (0.012, 0.0), (0.0, 0.009)], (math.cos(a) * 0.056, math.sin(a) * 0.056, 0.0),
              (math.cos(a), math.sin(a), 0), (-math.sin(a), math.cos(a), 0), (0, 0, 1), 0.012, 0.002, DARK)
    _neon(gl, _loop(0, 0, 0.0085, 0.044, 0.044, 20), 0.001, True, 4, mi=RIM)
    hilt(bm, gl, c, gz, pommel="ring")


def sw_453(c, bm, gl):
    """환도 「유리 왕관」(조준·방벽): 곧은 외날, 칼등 위 조준경, 육각 방패 코등이, 빛 결정 왕관 자루끝."""
    bl = Blade(c, 0.054, 0.044, 0.006, 0.0047, 0.08, 0.2, M0=c.tip_x, groove={"at": "shin", "z": (0.22, 0.7), "f": (0.2, 0.8), "d": 0.0011})
    bl.build(bm)
    gz = 0.011
    xs, xe, ty = cover(bm, gl, bl, 0.2, gz, nb=3, slant=-1.0)
    top = receiver(bm, gl, xs + 0.004, xe - 0.016, gz + 0.008, 0.19, ty, 0.012, (xs + 0.03, xe - 0.026, gz + 0.012, 0.1, 0.02))
    barrel(bm, gl, bl.M0 + 0.03, top + 0.0075, 0.18, 0.5, 0.0075)
    bracket(bm, bl, bl.M0 + 0.03, top + 0.001, 0.38)
    scope(bm, gl, xs - 0.016, 0.0, 0.06, 0.24, 0.0105)
    for z in (0.09, 0.21):
        _box(bm, (xs - 0.006, 0.0, z), (0.012, 0.01, 0.012), DARK, 0.0012)
    # 육각 방패 코등이
    R = 0.07
    hexp = [(math.cos(k / 6 * math.tau) * R, math.sin(k / 6 * math.tau) * R * 0.72) for k in range(6)]
    _slab(bm, hexp, (0, 0, 0), (1, 0, 0), (0, 1, 0), (0, 0, 1), 2 * gz, 0.004, DARK)
    _neon(gl, [(x * 0.84, y * 0.84, gz + 0.0004) for x, y in hexp], 0.0012, True)
    _neon(gl, [(x * 1.005, y * 1.005, 0.0) for x, y in hexp], 0.0014, True, mi=RIM)
    hilt(bm, gl, c, gz, pommel="crown")


def sw_352(c, bm, gl):
    """중장도 「폐허의 왕」(산탄·과열): 넓고 긴 외날, 칼끝을 잘라 낸 꼴, 부서진 등 톱니, 세 구멍 넓은 총구."""
    bl = Blade(c, 0.15, 0.13, 0.0085, 0.0065, 0.17, 0.26, kp=1.0, sp=0.24, mt=0.72, pk=0.0, g=(0.006, 0.005),
               groove={"at": "ji", "z": (0.18, 0.7), "f": (0.3, 0.42), "d": 0.0015}, dark_kiss=False)
    bl.build(bm)
    gz = 0.013
    xs, xe, ty = cover(bm, gl, bl, 0.26, gz, nb=3, slant=1.0)
    top = receiver(bm, gl, xs + 0.006, xe - 0.03, gz + 0.008, 0.245, ty, 0.016, (xs + 0.03, xs + 0.07, gz + 0.016, 0.13, 0.026))
    # 세 구멍 넓은 총구(가로로 나란한 짧은 총열 셋을 한 덩이로)
    for k in range(3):
        barrel(bm, gl, bl.M0 + 0.05 + k * 0.024, top + 0.011, 0.23, 0.6, 0.0105, segs=10)
    _box(bm, (bl.M0 + 0.074, top + 0.011, 0.585), (0.08, 0.026, 0.03), PLATE, 0.003)
    _neon(gl, [(bl.M0 + 0.036, top + 0.0245, 0.585), (bl.M0 + 0.112, top + 0.0245, 0.585)], 0.0016)
    bracket(bm, bl, bl.M0 + 0.074, top + 0.001, 0.42, 0.05)
    fins(bm, gl, xs + 0.08, xe - 0.04, top, 0.05, 0.2, 5, 0.012)
    vent_slits(gl, bl, 0.3, 5, 0.55, 0.78, -1.0, 0.026)
    teeth(bm, bl, 0.75, 1.3, 6, 0.018)
    # 넓은 덩이 코등이와 이빨 꼴 테
    _slab(bm, [(-0.11, -0.03), (0.13, -0.03), (0.15, 0.0), (0.13, 0.03), (-0.11, 0.03), (-0.13, 0.0)], (0, 0, 0), (1, 0, 0), (0, 1, 0), (0, 0, 1), 2 * gz, 0.005, DARK)
    for k in range(5):
        x = -0.09 + k * 0.05
        _slab(bm, [(-0.009, 0.0), (0.009, 0.0), (0.0, 0.024)], (x, 0.0, gz - 0.002), (1, 0, 0), (0, 0, 1), (0, 1, 0), 0.03, 0.002, DARK)
    for s in (-1.0, 1.0):
        _neon(gl, [(-0.11, s * 0.0305, 0.0), (0.13, s * 0.0305, 0.0)], 0.0013, mi=RIM)
    hilt(bm, gl, c, gz, r=0.02, ry=0.85, wrap=True, pommel="block")


def sw_490(c, bm, gl):
    """중장도 「철의 장례」(EMP·방벽): 넓은 외날, 끌처럼 각진 칼끝, 양면에 덧댄 갑판, EMP 접시, 관 꼴 방패 코등이."""
    bl = Blade(c, 0.14, 0.12, 0.0088, 0.0068, 0.1, 0.24, sp=0.28, mt=0.75, pk=0.0, g=(0.006, 0.005), kp=0.55, dark_kiss=False)
    bl.build(bm)
    gz = 0.015
    xs, xe, ty = cover(bm, gl, bl, 0.24, gz, nb=2, slant=-1.0)
    top = receiver(bm, gl, xs + 0.006, xe - 0.03, gz + 0.008, 0.23, ty, 0.014)
    dish(bm, gl, (xs + xe) / 2.0 - 0.01, top, 0.12, 0.042)
    barrel(bm, gl, bl.M0 + 0.025, top + 0.0105, 0.22, 0.62, 0.0105)
    bracket(bm, bl, bl.M0 + 0.025, top + 0.001, 0.45)
    # 갑판: 칼날 -Y면에 판 셋, +Y면에는 총열 위로 판 셋(빛 틈)
    for side, f0, f1, zz in ((-1.0, 0.08, 0.5, ((0.3, 0.46), (0.5, 0.66), (0.7, 0.84))),
                             (1.0, 0.3, 0.72, ((0.7, 0.86), (0.9, 1.06), (1.1, 1.26)))):
        for za, zb in zz:
            xa, xb = bl.x_at(za, f0), bl.x_at(za, f1)
            y0 = max(bl.sy(za, f0), bl.sy(za, f1), bl.sy(za, (f0 + f1) / 2.0))
            _plate(bm, [(xa, za), (xb, za + 0.02), (xb, zb), (xa, zb - 0.02)], (0, side * y0, 0), (1, 0, 0), (0, 0, 1), (0, side, 0), 0.003, 0.0016, PLATE)
            _neon(gl, [(xb + 0.004, side * (y0 + 0.0006), za + 0.025), (xb + 0.004, side * (y0 + 0.0006), zb - 0.006)], 0.0011)
    # 관 꼴 방패 코등이(길쭉한 육각)
    cof = [(-0.12, 0.0), (-0.07, -0.042), (0.11, -0.036), (0.14, 0.0), (0.11, 0.036), (-0.07, 0.042)]
    _slab(bm, cof, (0, 0, 0), (1, 0, 0), (0, 1, 0), (0, 0, 1), 2 * gz, 0.005, DARK)
    _neon(gl, [(x * 0.9, y * 0.86, gz + 0.0004) for x, y in cof], 0.0012, True)
    _neon(gl, [(x * 1.004, y * 1.004, 0.0) for x, y in cof], 0.0014, True, mi=RIM)
    hilt(bm, gl, c, gz, r=0.02, ry=0.85, wrap=True, pommel="block")


def sw_329(c, bm, gl):
    """대검 「도시를 가르는 자」(관통탄·반동 돌진): 아주 두꺼운 양날, 가운데 빛 홈, 굵은 총열과 송곳 탄두·제동기, 분사구 둘."""
    bl = Blade(c, 0.12, 0.1, 0.0135, 0.01, 0.18, 0.25, single=False, kp=1.0, bulge=0.03, g=(0.0065, 0.0055), tg=0.0016,
               groove={"at": "mid", "z": (0.2, 0.84), "w": 0.16, "d": 0.0028})
    bl.build(bm)
    gz = 0.015
    xs, xe, ty = cover(bm, gl, bl, 0.25, gz, nb=3, slant=1.0)
    top = receiver(bm, gl, xs + 0.01, xe - 0.01, gz + 0.008, 0.235, ty, 0.014, (-0.025, 0.025, gz + 0.012, 0.12, 0.028))
    barrel(bm, gl, 0.0, top + 0.012, 0.22, 0.86, 0.016, spike=True, brake=True)
    for z in (0.42, 0.64):
        bracket(bm, bl, 0.0, top + 0.002, z, 0.03, 0.018)
    # 날개 코등이
    _slab(bm, [(-0.07, -0.016), (0.07, -0.016), (0.07, 0.03), (-0.07, 0.03)], (0, 0, 0), (1, 0, 0), (0, 0, 1), (0, 1, 0), 0.05, 0.005, DARK)
    for s in (-1.0, 1.0):   # 아래로 꺾인 날개 둘
        _slab(bm, [(s * 0.062, 0.028), (s * 0.062, -0.01), (s * 0.2, -0.04), (s * 0.212, -0.016)], (0, 0, 0), (1, 0, 0), (0, 0, 1), (0, 1, 0), 0.044, 0.005, DARK)
    for s in (-1.0, 1.0):
        _neon(gl, [(s * 0.065, 0.0255, 0.026), (s * 0.19, 0.0255, -0.008)], 0.0014)
        _neon(gl, [(s * 0.065, -0.0255, 0.026), (s * 0.19, -0.0255, -0.008)], 0.0014)
        thruster(bm, gl, s * 0.1, -0.02, -0.07, 0.013)
    hilt(bm, gl, c, 0.03, r=0.021, ry=0.86, wrap=False, pommel="block", ribs=6)


def sw_377(c, bm, gl):
    """대검 「심야 열차」(레일·반동 돌진): 아주 두꺼운 양날 위 긴 레일 두 줄과 코일, 앞등, 열차 완충기 꼴 코등이, 분사구."""
    bl = Blade(c, 0.13, 0.11, 0.0135, 0.0105, 0.16, 0.24, single=False, kp=1.0, bulge=0.03, g=(0.0065, 0.0055), tg=0.0016)
    bl.build(bm)
    gz = 0.02
    xs, xe, ty = cover(bm, gl, bl, 0.24, gz, nb=2, slant=-1.0)
    top = receiver(bm, gl, xs + 0.01, xe - 0.01, gz + 0.006, 0.23, ty, 0.012)
    rails(bm, gl, bl, 0.25, 1.36, -0.45, 0.45, 1.0, n=6, clamps=4, coil=True)
    lamp(bm, gl, 0.0, top, 0.12, 0.024)
    for s in (-1.0, 1.0):
        lamp(bm, gl, s * 0.034, top, 0.06, 0.011, 10)
    # 완충기 꼴 코등이: 넓은 네모 덩이, 양끝 원통 완충기와 네온
    _slab(bm, [(-0.15, -0.034), (0.15, -0.034), (0.16, -0.02), (0.16, 0.02), (0.15, 0.034), (-0.15, 0.034), (-0.16, 0.02), (-0.16, -0.02)],
          (0, 0, 0), (1, 0, 0), (0, 1, 0), (0, 0, 1), 2 * gz, 0.005, DARK)
    for s in (-1.0, 1.0):
        _rev(bm, [(0.0, 0.0), (0.016, 0.0), (0.016, s * 0.028), (0.02, s * 0.03), (0.02, s * 0.036), (0.0, s * 0.036)], 12, PLATE, (s * 0.16, 0.0, 0.0), "X", sharp=(1, 2, 3, 4))
        _neon(gl, [(s * 0.188, math.cos(a) * 0.0203, math.sin(a) * 0.0203) for a in [k / 10 * math.tau for k in range(10)]], 0.0012, True, 4, mi=RIM)
        _neon(gl, [(s * 0.13, 0.0345, -0.012), (s * 0.13, 0.0345, 0.012)], 0.0014)
        _neon(gl, [(s * 0.13, -0.0345, -0.012), (s * 0.13, -0.0345, 0.012)], 0.0014)
        thruster(bm, gl, s * 0.09, -0.024, -0.07, 0.012)
    _neon(gl, [(-0.12, 0.0, gz + 0.0005), (0.12, 0.0, gz + 0.0005)], 0.0013, mi=RIM)
    hilt(bm, gl, c, gz, r=0.021, ry=0.86, wrap=False, pommel="block", ribs=6)


# ================================================================== 칼마다 다른 마감과 빛(2026-11-26 사용자 "디자인 다 안 비슷하게 해서 똑같다는 느낌이 들지 않게")
# 열두 자루가 모두 짙은 건메탈에 청록이라 한 벌처럼 보였다. 칼마다 몸 마감(칼날·판·고리 색과 광)과 빛 색을 이름·능력에 맞춰 따로 준다.
# 재질 이름은 kat_<부위>_<마감>, glow_kat_<부위>_<빛>(게임의 CyberModel.glow_boost는 glow_kat_edge/line/rim 앞부분으로 세기를 고른다).
# 349 「절단선」만 원래(건메탈·청록) 그대로.
FINISH = {   # 부위: (색, 거칠기, 금속)
    "gun": None,
    "carbon": {"blade": ((0.045, 0.045, 0.052), 0.4, 0.7), "shin": ((0.028, 0.028, 0.032), 0.32, 0.7), "plate": ((0.07, 0.068, 0.078), 0.62, 0.15),
               "dark": ((0.03, 0.03, 0.034), 0.55, 0.3), "pale": ((0.3, 0.26, 0.38), 0.35, 1.0)},
    "ember": {"blade": ((0.11, 0.085, 0.07), 0.3, 1.0), "shin": ((0.06, 0.045, 0.038), 0.26, 1.0), "plate": ((0.3, 0.17, 0.09), 0.38, 1.0),
              "dark": ((0.055, 0.042, 0.036), 0.45, 1.0), "pale": ((0.72, 0.48, 0.28), 0.3, 1.0)},
    "dawn": {"blade": ((0.58, 0.58, 0.6), 0.16, 1.0), "shin": ((0.42, 0.42, 0.45), 0.14, 1.0), "plate": ((0.8, 0.78, 0.74), 0.34, 0.0),
             "dark": ((0.13, 0.12, 0.12), 0.4, 0.6), "pale": ((0.85, 0.66, 0.38), 0.25, 1.0)},
    "lacquer": {"blade": ((0.035, 0.034, 0.04), 0.24, 1.0), "shin": ((0.022, 0.022, 0.026), 0.2, 1.0), "plate": ((0.4, 0.025, 0.03), 0.28, 0.15),
                "dark": ((0.06, 0.02, 0.022), 0.4, 0.4), "pale": ((0.78, 0.6, 0.3), 0.28, 1.0)},
    "jade": {"blade": ((0.085, 0.1, 0.095), 0.28, 1.0), "shin": ((0.05, 0.062, 0.058), 0.24, 1.0), "plate": ((0.1, 0.22, 0.17), 0.5, 0.6),
             "dark": ((0.03, 0.046, 0.04), 0.5, 0.6), "pale": ((0.55, 0.42, 0.24), 0.35, 1.0)},
    "chrome": {"blade": ((0.72, 0.74, 0.78), 0.09, 1.0), "shin": ((0.52, 0.54, 0.6), 0.08, 1.0), "plate": ((0.3, 0.32, 0.4), 0.22, 1.0),
               "dark": ((0.06, 0.066, 0.085), 0.35, 1.0), "pale": ((0.88, 0.9, 0.94), 0.15, 1.0)},
    "glass": {"blade": ((0.64, 0.7, 0.74), 0.07, 1.0), "shin": ((0.46, 0.52, 0.57), 0.06, 1.0), "plate": ((0.86, 0.88, 0.9), 0.22, 0.05),
              "dark": ((0.2, 0.22, 0.25), 0.3, 0.5), "pale": ((0.92, 0.94, 0.96), 0.12, 1.0)},
    "rust": {"blade": ((0.13, 0.095, 0.075), 0.55, 0.8), "shin": ((0.075, 0.055, 0.045), 0.5, 0.8), "plate": ((0.34, 0.15, 0.06), 0.78, 0.25),
             "dark": ((0.055, 0.038, 0.032), 0.7, 0.5), "pale": ((0.5, 0.38, 0.26), 0.5, 1.0)},
    "brass": {"blade": ((0.05, 0.05, 0.056), 0.3, 1.0), "shin": ((0.032, 0.032, 0.036), 0.26, 1.0), "plate": ((0.58, 0.43, 0.17), 0.32, 1.0),
              "dark": ((0.04, 0.038, 0.04), 0.45, 1.0), "pale": ((0.75, 0.62, 0.38), 0.28, 1.0)},
    "olive": {"blade": ((0.15, 0.155, 0.16), 0.36, 1.0), "shin": ((0.095, 0.1, 0.105), 0.3, 1.0), "plate": ((0.17, 0.19, 0.1), 0.72, 0.1),
              "dark": ((0.045, 0.048, 0.04), 0.6, 0.4), "pale": ((0.5, 0.5, 0.46), 0.4, 1.0)},
    "hazard": {"blade": ((0.12, 0.125, 0.135), 0.3, 1.0), "shin": ((0.075, 0.08, 0.088), 0.26, 1.0), "plate": ((0.72, 0.5, 0.04), 0.55, 0.15),
               "dark": ((0.04, 0.04, 0.045), 0.5, 0.6), "pale": ((0.6, 0.62, 0.64), 0.35, 1.0)},
}
GLOW_SET = {   # 빛: (날 끝, 홈·네온관, 고리·총구)의 빛 색. 바탕색은 그 절반쯤
    "cyan": None,
    "violet": ((0.55, 0.18, 1.0), (0.42, 0.12, 1.0), (0.7, 0.35, 1.0)),
    "amber": ((1.0, 0.55, 0.08), (1.0, 0.34, 0.03), (1.0, 0.7, 0.2)),
    "dawn": ((1.0, 0.72, 0.32), (1.0, 0.32, 0.5), (1.0, 0.8, 0.45)),
    "red": ((1.0, 0.07, 0.04), (1.0, 0.12, 0.08), (1.0, 0.25, 0.1)),
    "green": ((0.2, 1.0, 0.32), (0.08, 1.0, 0.48), (0.55, 1.0, 0.2)),
    "volt": ((0.45, 0.52, 1.0), (0.28, 0.36, 1.0), (0.78, 0.82, 1.0)),
    "ice": ((0.72, 0.94, 1.0), (0.5, 0.84, 1.0), (0.9, 1.0, 1.0)),
    "ember": ((1.0, 0.3, 0.04), (1.0, 0.18, 0.0), (1.0, 0.45, 0.08)),
    "pale": ((0.8, 0.7, 1.0), (0.6, 0.48, 1.0), (0.95, 0.9, 1.0)),
    "magenta": ((1.0, 0.08, 0.55), (1.0, 0.04, 0.4), (1.0, 0.3, 0.7)),
    "yellow": ((1.0, 0.82, 0.15), (1.0, 0.66, 0.04), (1.0, 0.95, 0.6)),
}
LOOK = {"384": ("carbon", "violet"), "486": ("ember", "amber"), "349": ("gun", "cyan"), "487": ("dawn", "dawn"),
        "470": ("lacquer", "red"), "482": ("jade", "green"), "423": ("chrome", "volt"), "453": ("glass", "ice"),
        "352": ("rust", "ember"), "490": ("brass", "pale"), "329": ("olive", "magenta"), "377": ("hazard", "yellow")}
BASE_MATS = list(MATS)


def _look(sid):
    """이 칼의 마감·빛 재질을 만들고 MATS(재질 이름 목록)를 이 칼 것으로 바꾼다."""
    global MATS
    fin, glo = LOOK[sid]
    names = []
    for mn in BASE_MATS:
        part = mn.split("_")[-1]
        if mn.startswith("glow_"):
            if GLOW_SET[glo] is None:
                names.append(mn)
                continue
            em = GLOW_SET[glo][("edge", "line", "rim").index(part)]
            nm = "%s_%s" % (mn, glo)
            st = K.GLOWS[mn][2]
            K.GLOWS[nm] = (tuple(c * 0.5 for c in em), em, st)
            names.append(nm)
        elif FINISH[fin] is None or part not in FINISH[fin]:
            names.append(mn)
        else:
            col, rough, metal = FINISH[fin][part]
            nm = "%s_%s" % (mn, fin)
            if bpy.data.materials.get(nm) is None:
                MS._kat_mat(nm, col, rough, metal, part)
            names.append(nm)
    MATS = names


BUILD = {"384": sw_384, "486": sw_486, "349": sw_349, "487": sw_487, "470": sw_470, "482": sw_482,
         "423": sw_423, "453": sw_453, "352": sw_352, "490": sw_490, "329": sw_329, "377": sw_377}


def make(sid):
    MS._kat_materials()
    _look(sid)
    c = Ctx(sid)
    bm, gl = bmesh.new(), bmesh.new()
    BUILD[sid](c, bm, gl)
    _obj("body_%s" % sid, bm)
    _obj("neon_%s" % sid, gl, True)
    print("%s %s (%s, %s) L=%.2f grip=%.3f tip_x=%.4f" % (sid, c.name, c.sub, "·".join(c.powers), c.L, c.grip, c.tip_x))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    want = [a for a in args if a in BUILD] or IDS
    K.run_all({k: (lambda s=k: make(s)) for k in want}, OUT, SIZE, "사이버 검")
