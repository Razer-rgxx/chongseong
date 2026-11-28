# 마을의 집 둘레 소품을 Blender로 짓고 .glb로 내보낸다. (2026-11-27, docs/village_models.md)
#
# 한 번(chongseong 폴더에서, Blender 4.x):
#   blender -b -P tools/blender/make_village.py [-- 이름 ...]
# 결과: assets/village/models/<이름>.glb. 이름을 주면 그것만 다시 짓는다.
#
# 이 스크립트는 질감을 굽지 않는다. 재질은 "이름만" 싣고(wood, plank, log, stone, roof, iron, cloth, ...), 게임이
# (scripts/lobby/village_models.gd) 이름마다 assets/village/ 의 Poly Haven(CC0) 질감을 입힌다. UV는 1 = 1m라서
# 어느 크기로 올려도 질감 밀도가 같다. 꼭짓점 색(COLOR_0)에 땅 쪽 어둡기·얼룩을 넣어 닳은 느낌을 낸다.
#
# 만드는 법: 널빤지·들보는 모서리를 깎고(Bevel) 길이 방향으로 휘고 비틀며(부드러운 잡음 변형), 돌은 잡음으로 민 공,
# 통은 휜 널 열여섯 장, 지붕은 겹쳐 올린 널. 모든 모양은 Godot 좌표(Y 위, 앞이 +Z)로 짓고 마지막에 Blender 좌표로 바꾼다.
# 크기와 발자국은 옛 기본 도형(VillageBuilder, VillageProps)과 같다: 막힘 표는 그대로다.

import bmesh
import bpy
import math
import os
import random
import sys
import traceback
from mathutils import Euler, Matrix, Vector, noise

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "village", "models"))
TAU = math.tau
PI = math.pi

COLORS = {   # Blender 쪽 보기용 색(게임은 이름으로 다시 칠한다)
    "wood": (0.25, 0.17, 0.11), "plank": (0.3, 0.22, 0.15), "log": (0.14, 0.1, 0.07), "logend": (0.45, 0.34, 0.22),
    "stone": (0.35, 0.34, 0.32), "stone_dark": (0.12, 0.12, 0.12), "roof": (0.3, 0.2, 0.17), "iron": (0.07, 0.07, 0.08),
    "steel": (0.55, 0.57, 0.6), "brass": (0.5, 0.4, 0.2), "rope": (0.38, 0.3, 0.18), "cloth": (0.3, 0.1, 0.1),
    "cloth_gold": (0.55, 0.42, 0.14), "cloth_red": (0.35, 0.07, 0.09), "sack": (0.38, 0.32, 0.22), "straw": (0.62, 0.5, 0.26),
    "paper": (0.62, 0.55, 0.4), "glow": (1.0, 0.6, 0.25), "water": (0.02, 0.03, 0.04), "mirror": (0.3, 0.33, 0.37),
    "dirt": (0.3, 0.22, 0.15), "leather": (0.22, 0.14, 0.09), "wicker": (0.4, 0.3, 0.16), "ember": (1.0, 0.35, 0.1),
    "burnt": (0.05, 0.04, 0.035), "mortar": (0.2, 0.19, 0.18),
}


def _o(seed, k):
    return Vector((seed * 7.13 + k * 31.7, seed * 3.31 + k * 17.9, seed * 11.7 + k * 5.3))


class Model:
    def __init__(self, name, seed=1):
        self.name = name
        self.seed = seed
        self.rng = random.Random(seed)
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.col = self.bm.loops.layers.color.new("Col")
        self.mats = []
        self.n = 0
        self.root = Matrix.Identity(4)   # 모든 조각에 앞서 곱하는 변환(누운 모델 등)

    def mi(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    # ------------------------------------------------------------ 한 조각을 따로 만들어 합친다
    def _tmp(self):
        t = bmesh.new()
        t.loops.layers.uv.new("UVMap")
        t.loops.layers.color.new("Col")
        return t

    def _merge(self, t, mat, xf, smooth, tone, wear):
        """t(조각)를 변환 xf로 옮겨 합친다. 꼭짓점 색(어둡기)을 넣는다."""
        uvt = t.loops.layers.uv.active
        idx = self.mi(mat)
        vm = {}
        for v in t.verts:
            vm[v] = self.bm.verts.new(xf @ v.co)
        self.n += 1
        for f in t.faces:
            try:
                nf = self.bm.faces.new([vm[v] for v in f.verts])
            except ValueError:
                continue
            nf.material_index = idx
            nf.smooth = smooth
            for lo, ln in zip(f.loops, nf.loops):
                ln[self.uv].uv = lo[uvt].uv
                p = vm[lo.vert].co
                ln[self.col] = self._tone(p, tone, wear)

    def _tone(self, p, tone, wear):
        """어둡기: 땅에 가까울수록 어둡고(때), 얼룩(잡음), 가끔 닳은 밝은 점."""
        n1 = noise.noise(p * 2.3 + _o(self.seed, 1))
        n2 = noise.noise(p * 9.0 + _o(self.seed, 2))
        g = 0.82 + 0.16 * n1 + 0.06 * n2
        ground = min(1.0, max(0.0, p.y / 0.55))
        g *= 0.62 + 0.38 * ground ** 0.7
        g *= tone
        w = 1.0 + wear * max(0.0, n2)
        return (min(1.0, g * w), min(1.0, g * w * 0.98), min(1.0, g * w * 0.95), 1.0)

    # ------------------------------------------------------------ 모양 만들기 보조
    @staticmethod
    def _geom(t):
        return list(t.verts) + list(t.edges) + list(t.faces)

    def _cut(self, t, size, cuts):
        for a in range(3):
            n = cuts[a]
            if n <= 0:
                continue
            nv = Vector((1 if a == 0 else 0, 1 if a == 1 else 0, 1 if a == 2 else 0))
            for k in range(1, n + 1):
                c = -size[a] / 2.0 + size[a] * k / (n + 1.0)
                bmesh.ops.bisect_plane(t, geom=self._geom(t), dist=1e-5, plane_co=nv * c, plane_no=nv)

    @staticmethod
    def _bevel(t, w, segs=1, ang=0.6):
        if w <= 0:
            return
        es = [e for e in t.edges if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > ang]
        if es:
            bmesh.ops.bevel(t, geom=es, offset=w, segments=segs, affect="EDGES", profile=0.5)

    def _jitter(self, t, amp, freq=3.0, k=0):
        if amp <= 0:
            return
        sd = self.rng.random() * 50.0 + k
        for v in t.verts:
            p = v.co * freq
            v.co += Vector((noise.noise(p + _o(sd, 1)), noise.noise(p + _o(sd, 2)), noise.noise(p + _o(sd, 3)))) * amp

    def _uv_box(self, t, size):
        """로컬 좌표에서 면의 큰 방향 축으로 투영. u는 두 접선축 중 긴 쪽(결이 길이를 따라간다). 1 = 1m."""
        uvl = t.loops.layers.uv.active
        ox, oy = self.rng.random() * 20.0, self.rng.random() * 20.0
        t.normal_update()
        for f in t.faces:
            n = f.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            ta = [i for i in range(3) if i != ax]
            if size[ta[0]] < size[ta[1]]:
                ta.reverse()
            for lo in f.loops:
                c = lo.vert.co
                lo[uvl].uv = (c[ta[0]] + ox, c[ta[1]] + oy)

    def _uv_cyl(self, t, axis=1):
        uvl = t.loops.layers.uv.active
        ox = self.rng.random() * 10.0
        t.normal_update()
        for f in t.faces:
            n = f.normal
            if abs(n[axis]) > 0.85:
                for lo in f.loops:
                    c = lo.vert.co
                    a = [i for i in range(3) if i != axis]
                    lo[uvl].uv = (c[a[0]] + ox, c[a[1]])
                continue
            us = []
            for lo in f.loops:
                c = lo.vert.co
                a = [i for i in range(3) if i != axis]
                ang = math.atan2(c[a[1]], c[a[0]])
                r = math.hypot(c[a[0]], c[a[1]])
                us.append((ang, r, c[axis]))
            # 이음매를 지나는 면은 각도를 이어 붙인다
            base = us[0][0]
            for lo, (ang, r, y) in zip(f.loops, us):
                d = ang - base
                if d > PI:
                    d -= TAU
                if d < -PI:
                    d += TAU
                lo[uvl].uv = ((base + d) * max(r, 0.05) + ox, y)

    def _xf(self, pos, rot, xf):
        if xf is not None:
            return self.root @ xf
        return self.root @ Matrix.Translation(Vector(pos)) @ Euler(rot, "XYZ").to_matrix().to_4x4()

    # ------------------------------------------------------------ 조각 종류
    def box(self, mat, size, pos=(0, 0, 0), rot=(0, 0, 0), cuts=(0, 0, 0), bevel=0.008, bseg=1, jit=0.0, jfreq=3.0, warp=None,
            smooth=False, xf=None, tone=1.0, wear=0.0):
        t = self._tmp()
        bmesh.ops.create_cube(t, size=1.0)
        for v in t.verts:
            v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
        self._cut(t, size, cuts)
        self._bevel(t, bevel, bseg)
        if warp:
            for v in t.verts:
                v.co = warp(v.co.copy())
        self._jitter(t, jit, jfreq)
        self._uv_box(t, size)
        bmesh.ops.recalc_face_normals(t, faces=t.faces)
        self._merge(t, mat, self._xf(pos, rot, xf), smooth, tone, wear)
        t.free()

    def cyl(self, mat, r0, r1, h, pos=(0, 0, 0), rot=(0, 0, 0), segs=8, rings=1, caps=True, jit=0.0, jfreq=3.0, warp=None,
            smooth=True, xf=None, bevel=0.0, tone=1.0, wear=0.0, endmat=None):
        """원통(밑 r0, 위 r1). 가운데가 원점, 축은 Y."""
        t = self._tmp()
        rowsp = []
        for k in range(rings + 1):
            f = k / rings
            r = r0 + (r1 - r0) * f
            y = -h / 2 + h * f
            rowsp.append([Vector((math.cos(TAU * j / segs) * r, y, math.sin(TAU * j / segs) * r)) for j in range(segs)])
        vs = [[t.verts.new(p) for p in row] for row in rowsp]
        for k in range(rings):
            for j in range(segs):
                j2 = (j + 1) % segs
                try:
                    t.faces.new([vs[k][j], vs[k][j2], vs[k + 1][j2], vs[k + 1][j]])
                except ValueError:
                    pass
        endf = []
        if caps:
            for ring, up in ((vs[0], False), (vs[-1], True)):
                try:
                    endf.append(t.faces.new(ring if up else list(reversed(ring))))
                except ValueError:
                    pass
        if bevel > 0:
            self._bevel(t, bevel, 1, 0.7)
        if warp:
            for v in t.verts:
                v.co = warp(v.co.copy())
        self._jitter(t, jit, jfreq)
        self._uv_cyl(t)
        bmesh.ops.recalc_face_normals(t, faces=t.faces)
        self._merge(t, mat, self._xf(pos, rot, xf), smooth, tone, wear)
        t.free()

    def lathe(self, mat, prof, pos=(0, 0, 0), rot=(0, 0, 0), segs=16, closed=False, jit=0.0, jfreq=3.0, warp=None, smooth=True,
              xf=None, tone=1.0, wear=0.0, uvmode="cyl"):
        """prof: [(반지름, 높이), ...]. closed면 마지막과 처음을 이어 닫힌 고리 단면."""
        t = self._tmp()
        vs = []
        for (r, y) in prof:
            vs.append([t.verts.new(Vector((math.cos(TAU * j / segs) * r, y, math.sin(TAU * j / segs) * r))) for j in range(segs)])
        n = len(prof)
        for k in range(n if closed else n - 1):
            k2 = (k + 1) % n
            for j in range(segs):
                j2 = (j + 1) % segs
                try:
                    t.faces.new([vs[k][j], vs[k][j2], vs[k2][j2], vs[k2][j]])
                except ValueError:
                    pass
        bmesh.ops.remove_doubles(t, verts=t.verts, dist=1e-5)
        if warp:
            for v in t.verts:
                v.co = warp(v.co.copy())
        self._jitter(t, jit, jfreq)
        self._uv_cyl(t)
        bmesh.ops.recalc_face_normals(t, faces=t.faces)
        self._merge(t, mat, self._xf(pos, rot, xf), smooth, tone, wear)
        t.free()

    def blob(self, mat, rad, pos=(0, 0, 0), rot=(0, 0, 0), jit=0.05, jfreq=2.0, sub=2, warp=None, smooth=True, xf=None, tone=1.0,
             wear=0.0, bevel=0.0):
        """잡음으로 민 공(돌, 자루). rad: 세 축 반지름."""
        t = self._tmp()
        bmesh.ops.create_icosphere(t, subdivisions=sub, radius=1.0)
        for v in t.verts:
            v.co = Vector((v.co.x * rad[0], v.co.y * rad[1], v.co.z * rad[2]))
        if warp:
            for v in t.verts:
                v.co = warp(v.co.copy())
        self._jitter(t, jit, jfreq)
        self._uv_box(t, rad)
        bmesh.ops.recalc_face_normals(t, faces=t.faces)
        self._merge(t, mat, self._xf(pos, rot, xf), smooth, tone, wear)
        t.free()

    def sheet(self, mat, pts, pos=(0, 0, 0), rot=(0, 0, 0), thick=0.0, smooth=True, xf=None, tone=1.0, wear=0.0, close=False, jit=0.0):
        """점 격자 pts[행][열](Vector)로 만든 한 겹 천/판(양면 재질). thick>0이면 뒷면을 안쪽으로 한 장 더 얹는다."""
        t = self._tmp()
        uvl = t.loops.layers.uv.active
        rows, cols = len(pts), len(pts[0])
        vs = [[t.verts.new(Vector(p)) for p in row] for row in pts]
        cu = [[0.0] * cols for _ in range(rows)]
        cv = [[0.0] * cols for _ in range(rows)]
        for i in range(rows):
            for j in range(1, cols):
                cu[i][j] = cu[i][j - 1] + (vs[i][j].co - vs[i][j - 1].co).length
        for j in range(cols):
            for i in range(1, rows):
                cv[i][j] = cv[i - 1][j] + (vs[i][j].co - vs[i - 1][j].co).length
        fl = []
        for i in range(rows - 1):
            for j in range(cols - 1):
                try:
                    f = t.faces.new([vs[i][j], vs[i][j + 1], vs[i + 1][j + 1], vs[i + 1][j]])
                except ValueError:
                    continue
                for lo, (a, b) in zip(f.loops, [(i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j)]):
                    lo[uvl].uv = (cu[a][b], cv[a][b])
                fl.append(f)
        self._jitter(t, jit, 3.0)
        if thick > 0:
            bmesh.ops.solidify(t, geom=list(t.faces), thickness=thick)
        t.normal_update()
        self._merge(t, mat, self._xf(pos, rot, xf), smooth, tone, wear)
        t.free()

    def poly(self, mat, outline, thick, pos=(0, 0, 0), rot=(0, 0, 0), bevel=0.004, jit=0.0, xf=None, smooth=False, tone=1.0, wear=0.0):
        """윤곽(x,y 점들, 앞이 +Z)을 두께 thick(z)로 민 판: 칼날, 널, 종이."""
        t = self._tmp()
        vs = [t.verts.new(Vector((x, y, thick / 2))) for (x, y) in outline]
        f = t.faces.new(vs)
        r = bmesh.ops.extrude_face_region(t, geom=[f])
        nv = [e for e in r["geom"] if isinstance(e, bmesh.types.BMVert)]
        bmesh.ops.translate(t, vec=Vector((0, 0, -thick)), verts=nv)
        self._bevel(t, bevel, 1, 0.7)
        self._jitter(t, jit, 3.0)
        self._uv_box(t, (1.0, 1.0, 0.1))
        bmesh.ops.recalc_face_normals(t, faces=t.faces)
        self._merge(t, mat, self._xf(pos, rot, xf), smooth, tone, wear)
        t.free()

    # ------------------------------------------------------------ 내보내기
    def export(self):
        bm = self.bm
        # Godot(Y 위, 앞 +Z) → Blender(Z 위, 앞 -Y)
        for v in bm.verts:
            v.co = Vector((v.co.x, -v.co.z, v.co.y))
        bmesh.ops.recalc_face_normals(bm, faces=[]) if False else None
        me = bpy.data.meshes.new(self.name)
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        for m in self.mats:
            mt = bpy.data.materials.get(m) or bpy.data.materials.new(m)
            mt.use_nodes = True
            b = mt.node_tree.nodes.get("Principled BSDF")
            c = COLORS.get(m, (0.5, 0.5, 0.5))
            b.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1.0)
            if m in ("glow", "ember"):
                b.inputs["Emission Color"].default_value = (c[0], c[1], c[2], 1.0)
                b.inputs["Emission Strength"].default_value = 3.0
            me.materials.append(mt)
        os.makedirs(OUT, exist_ok=True)
        path = os.path.join(OUT, self.name + ".glb")
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        kw = dict(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True, export_image_format="NONE")
        try:
            bpy.ops.export_scene.gltf(export_vertex_color="ACTIVE", **kw)
        except TypeError:
            bpy.ops.export_scene.gltf(**kw)
        tris = sum(len(p.vertices) - 2 for p in me.polygons)
        print("만듦 %s 삼각형 %d 크기 %d KB" % (path, tris, os.path.getsize(path) // 1024))
        bpy.data.objects.remove(ob, do_unlink=True)


def rows_of_boards(m, mat, x0, x1, y0, y1, z, n, gap=0.008, thick=0.03, jit=0.003, bevel=0.004, rng=None, vary=0.0):
    """세로 널빤지 n장을 나란히(x0..x1, 높이 y0..y1, 앞면 z)."""
    rng = rng or m.rng
    w = (x1 - x0) / n
    for i in range(n):
        d = rng.uniform(-vary, vary)
        m.box(mat, (w - gap, y1 - y0 + d, thick), (x0 + w * (i + 0.5), (y0 + y1 + d) / 2, z + rng.uniform(-0.004, 0.004)),
              cuts=(0, 1, 0), bevel=bevel, jit=jit)


def lap_roof(m, mat, o, ux, Lx, dv, Ld, rows, thick=0.035, tilt=0.12, rng=None, wmin=0.35, wmax=0.8, lift=0.0):
    """겹쳐 올린 널 지붕. o: 처마 한쪽 모서리, ux: 용마루 방향 단위벡터, dv: 처마에서 용마루로 올라가는 비탈 단위벡터,
    n: 비탈에서 위로 향하는 법선. rows 줄, 한 줄은 폭 wmin~wmax의 널을 이어 붙인다."""
    rng = rng or m.rng
    nrm = ux.cross(dv).normalized()
    if nrm.y < 0:
        nrm = -nrm
    step = Ld / rows
    for r in range(rows):
        x = rng.uniform(0.0, 0.3)
        k = 0
        while x < Lx:
            w = min(rng.uniform(wmin, wmax), Lx - x + 0.0)
            if w < 0.12:
                break
            along = r * step + lift
            c = o + ux * (x + w / 2) + dv * (along + step * 0.9)
            c = c + nrm * (thick * 0.5 + 0.012 * (r % 2))
            # 널 한 장: 폭 w(ux), 두께 thick(nrm), 길이 step*1.9(dv). 처마 쪽이 살짝 들리게 tilt
            zz = ux.cross(nrm).normalized()
            basis = Matrix((ux, nrm, zz)).transposed()
            sgn = 1.0 if zz.dot(dv) > 0 else -1.0
            xf = Matrix.Translation(c) @ basis.to_4x4() @ Matrix.Rotation(sgn * (tilt + rng.uniform(-0.03, 0.03)), 4, "X")
            m.box(mat, (w - 0.012, thick, step * 1.9), xf=xf, bevel=0.0, jit=0.004, tone=rng.uniform(0.85, 1.05))
            x += w
            k += 1


# ================================================================== 소품들
def barrel():
    m = Model("barrel", 3)
    h = 1.0
    n = 16

    def R(y):
        f = max(0.0, min(1.0, y / h))
        return 0.335 + 0.062 * math.sin(PI * f) ** 0.9

    for i in range(n):
        a0 = TAU * i / n
        dy = m.rng.uniform(-0.012, 0.01)
        w = TAU * 0.395 / n * 0.97

        def warp(c, a0=a0, dy=dy):
            y = c.y + h / 2 + (dy if c.y > 0 else 0.0)
            r = R(y) + c.z
            th = a0 + c.x / R(y)
            return Vector((math.cos(th) * r, y, math.sin(th) * r))

        m.box("plank", (w, h, 0.034), cuts=(0, 6, 0), bevel=0.004, warp=warp, jit=0.0015, smooth=False, tone=m.rng.uniform(0.85, 1.05))
    # 뚜껑(안으로 들어간 널판)과 쇠 테
    m.lathe("wood", [(0.0, h - 0.07), (0.33, h - 0.07), (0.33, h - 0.12), (0.0, h - 0.12)], closed=True, segs=20, smooth=False, jit=0.004)
    for y, t in ((0.09, 0.05), (0.27, 0.045), (0.73, 0.045), (0.91, 0.05)):
        r = R(y)
        m.lathe("iron", [(r + 0.004, y - t / 2), (r + 0.03, y - t / 2), (r + 0.03, y + t / 2), (r + 0.004, y + t / 2)], closed=True, segs=24,
                smooth=False, wear=0.25)
    m.export()


def crate():
    m = Model("crate", 5)
    s = 0.8
    pl = 4
    for side, rot in ((0, 0.0), (1, PI / 2), (2, PI), (3, -PI / 2)):
        rm = Euler((0, rot, 0), "XYZ").to_matrix().to_4x4()
        for k in range(pl):
            hh = (s - 0.02) / pl
            xf = rm @ Matrix.Translation(Vector((0, 0.012 + hh * (k + 0.5), s / 2 - 0.012)))
            m.box("plank", (s - 0.03, hh - 0.008, 0.024), xf=xf, cuts=(3, 0, 0), bevel=0.004, jit=0.003 + 0.002 * k, tone=m.rng.uniform(0.85, 1.05))
        for x in (-s / 2 + 0.05, s / 2 - 0.05):
            xf = rm @ Matrix.Translation(Vector((x, s / 2, s / 2 + 0.006)))
            m.box("wood", (0.075, s - 0.01, 0.026), xf=xf, bevel=0.006, jit=0.002, cuts=(0, 3, 0))
        if side == 0:
            xf = rm @ Matrix.Translation(Vector((0, s / 2, s / 2 + 0.014))) @ Euler((0, 0, math.atan2(s - 0.12, s - 0.16)), "XYZ").to_matrix().to_4x4()
            m.box("wood", (0.07, math.hypot(s - 0.12, s - 0.16), 0.024), xf=xf, bevel=0.005, jit=0.002)
    for i in range(5):
        wv = (s - 0.02) / 5
        m.box("plank", (wv - 0.008, 0.025, s - 0.04), (-s / 2 + 0.01 + wv * (i + 0.5), s - 0.014, 0), cuts=(0, 0, 3), bevel=0.004, jit=0.003)
    for z in (-s / 2 + 0.07, s / 2 - 0.07):
        m.box("wood", (s - 0.02, 0.022, 0.07), (0, s, z), bevel=0.005, jit=0.002, cuts=(3, 0, 0))
    for x, z in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        m.box("wood", (0.07, s, 0.07), (x * (s / 2 - 0.035), s / 2, z * (s / 2 - 0.035)), bevel=0.008, jit=0.002, cuts=(0, 3, 0))
    m.export()


def rope_coil(m, center, axis_rot, r, turns, rr=0.012, y0=0.0, dy=0.0, segs=14):
    """줄 한 겹 고리(원통 둘레에 감은 줄). 가운데 center, 반지름 r."""
    for k in range(turns):
        m.lathe("rope", [(r - rr, -rr), (r + rr, -rr), (r + rr, rr), (r - rr, rr)], pos=(center[0], center[1] + k * dy, center[2]), rot=axis_rot,
                closed=True, segs=segs, smooth=True)


def hay():
    m = Model("hay", 7)
    m.root = Matrix.Translation((0, 0.6, 0)) @ Matrix.Rotation(PI / 2, 4, "Z")
    R, L = 0.6, 1.1
    prof = [(0.0, -L / 2), (R * 0.86, -L / 2), (R * 0.97, -L / 2 + 0.06)]
    for k in range(1, 10):
        prof.append((R * (1.0 + 0.02 * math.sin(k)), -L / 2 + 0.06 + (L - 0.12) * k / 10))
    prof += [(R * 0.97, L / 2 - 0.06), (R * 0.86, L / 2), (0.0, L / 2)]
    m.lathe("straw", prof, segs=36, jit=0.028, jfreq=7.0, smooth=True)
    for y in (-0.3, 0.3):
        m.lathe("rope", [(R - 0.02, y - 0.022), (R + 0.034, y - 0.022), (R + 0.034, y + 0.022), (R - 0.02, y + 0.022)], closed=True, segs=36,
                jit=0.004, smooth=True)
    for i in range(34):   # 삐져나온 짚
        a = m.rng.uniform(0, TAU)
        y = m.rng.uniform(-L / 2, L / 2)
        L2 = m.rng.uniform(0.12, 0.3)
        r0 = R * (0.97 if abs(y) < L / 2 - 0.1 else 0.9)
        xf = Matrix.Rotation(-a, 4, "Y") @ Matrix.Translation((r0 + L2 * 0.4, y, 0)) @ Matrix.Rotation(-m.rng.uniform(0.9, 1.5), 4, "Z") @ \
            Matrix.Rotation(m.rng.uniform(-0.5, 0.5), 4, "X")
        m.box("straw", (L2, 0.006, 0.008), xf=xf, bevel=0.0, jit=0.0)
    m.export()


def firewood():
    m = Model("firewood", 11)
    for row in range(4):
        for i in range(6 - row):
            r = m.rng.uniform(0.085, 0.115)
            ln = m.rng.uniform(0.92, 1.04)
            x = (i - (5 - row) / 2.0) * 0.23 + m.rng.uniform(-0.01, 0.01)
            y = 0.1 + row * 0.19
            z = m.rng.uniform(-0.04, 0.04)
            m.cyl("log", r, r * 0.98, ln, pos=(x, y, z), rot=(PI / 2, 0, 0), segs=9, jit=0.006, jfreq=5.0)
            for sgn in (-1, 1):
                m.cyl("logend", r * 0.97, r * 0.97, 0.012, pos=(x, y, z + sgn * ln / 2), rot=(PI / 2, 0, 0), segs=9, jit=0.004)
    for x in (-0.66, 0.66):
        for z in (-0.32, 0.32):
            m.cyl("log", 0.032, 0.026, 0.8, pos=(x + m.rng.uniform(-0.01, 0.01), 0.4, z), rot=(0, 0, -x * 0.08), segs=6, jit=0.004)
    m.export()


def bench():
    m = Model("bench", 13)
    for dz in (-0.1, 0.1):
        m.box("plank", (1.8, 0.05, 0.19), (0, 0.44 + m.rng.uniform(-0.004, 0.004), dz), cuts=(5, 0, 0), bevel=0.006, jit=0.004, wear=0.2)
    for x in (-0.72, 0.72):
        for sz in (-1, 1):
            m.box("wood", (0.07, 0.46, 0.07), (x, 0.21, sz * 0.14), rot=(sz * 0.18, 0, 0), bevel=0.007, jit=0.002, cuts=(0, 2, 0))
        m.box("wood", (0.06, 0.05, 0.4), (x, 0.38, 0), bevel=0.006, jit=0.002)
    m.box("wood", (1.5, 0.05, 0.05), (0, 0.17, 0), bevel=0.006, jit=0.003, cuts=(4, 0, 0))
    m.export()


def stone_ring(m, n, r_in, r_out, y0, h, mat="stone", half=False, seed=0):
    """둥글게 쌓은 돌 한 단: n개의 깎은 돌."""
    for i in range(n):
        a = TAU * (i + (0.5 if half else 0.0)) / n
        r = (r_in + r_out) / 2
        w = TAU * r / n * m.rng.uniform(0.92, 1.0)
        hh = h * m.rng.uniform(0.9, 1.0)
        d = (r_out - r_in) * m.rng.uniform(0.92, 1.05)
        xf = Matrix.Rotation(-a, 4, "Y") @ Matrix.Translation((r, y0 + hh / 2, 0))
        m.box(mat, (d, hh, w), xf=xf, bevel=0.03, bseg=2, jit=0.014, jfreq=4.0, cuts=(1, 1, 1), smooth=True, tone=m.rng.uniform(0.8, 1.05))


def well():
    m = Model("well", 17)
    stone_ring(m, 15, 0.76, 1.04, 0.0, 0.46)
    stone_ring(m, 14, 0.76, 1.0, 0.45, 0.45, half=True)
    stone_ring(m, 12, 0.72, 1.08, 0.88, 0.1, mat="stone_dark")   # 갓돌
    m.lathe("stone_dark", [(0.0, 0.1), (0.8, 0.1), (0.8, 0.8), (0.76, 0.84)], segs=20, smooth=True)       # 속 벽
    m.lathe("water", [(0.0, 0.62), (0.77, 0.62)], segs=20)
    # 기둥 둘, 가운데 보, 도르래 막대, 지붕 보
    for sx in (-1, 1):
        m.box("wood", (0.15, 2.45, 0.15), (sx * 0.86, 1.22, 0.0), rot=(0, sx * 0.04, sx * 0.012), cuts=(0, 4, 0), bevel=0.012, bseg=2, jit=0.008, wear=0.15)
        for sz in (-1, 1):
            m.box("wood", (0.07, 0.8, 0.06), (sx * 0.86, 2.05, sz * 0.2), rot=(sz * 0.62, 0, 0), bevel=0.006, jit=0.003)
        m.box("stone_dark", (0.3, 0.12, 0.3), (sx * 0.86, 0.06, 0.0), bevel=0.02, bseg=2, jit=0.01, smooth=True)
    m.box("wood", (1.95, 0.11, 0.11), (0, 2.16, 0.0), bevel=0.01, bseg=2, jit=0.006, cuts=(6, 0, 0))
    m.cyl("log", 0.085, 0.085, 1.9, pos=(0, 1.55, 0), rot=(0, 0, PI / 2), segs=10, jit=0.005)   # 도르래 막대
    for k in range(5):   # 감긴 줄
        m.cyl("rope", 0.1, 0.1, 0.03, pos=(-0.18 + k * 0.09, 1.55, 0), rot=(0, 0, PI / 2), segs=10)
    m.box("wood", (0.06, 0.06, 0.4), (1.0, 1.55, 0.2), bevel=0.006, jit=0.002)             # 손잡이
    m.cyl("log", 0.025, 0.025, 0.2, pos=(1.0, 1.55, 0.42), rot=(0, 0, PI / 2), segs=6)
    m.cyl("rope", 0.011, 0.011, 0.4, pos=(0.0, 1.35, 0.0), segs=5)                          # 늘어진 줄
    m.lathe("wood", [(0.15, 0.0), (0.18, 0.0), (0.185, 0.3), (0.16, 0.3)], pos=(0, 0.95, 0), closed=True, segs=10, smooth=False, jit=0.004)
    m.lathe("iron", [(0.185, 0.06), (0.2, 0.06), (0.2, 0.1), (0.185, 0.1)], pos=(0, 0.95, 0), closed=True, segs=10, smooth=False)
    # 지붕: 두 비탈의 겹친 널과 용마루
    for side in (-1, 1):
        o = Vector((-1.2, 2.42, side * 0.98))
        dv = Vector((0, 0.5, -side * 0.98)).normalized()
        lap_roof(m, "roof", o, Vector((1, 0, 0)), 2.4, dv, math.hypot(0.5, 0.98) + 0.06, 6, thick=0.03, tilt=0.14, wmin=0.3, wmax=0.7)
        m.box("wood", (2.4, 0.07, 0.07), (0, 2.34, side * 0.92), bevel=0.006, jit=0.003)
    m.box("wood", (2.46, 0.1, 0.12), (0, 2.96, 0), rot=(0, 0, 0), bevel=0.01, jit=0.004)
    m.export()
def sack(m, pos, s=1.0, rot=(0, 0, 0), mat="sack"):
    """묶은 자루: 밑이 납작하고 허리가 불룩하며, 목을 줄로 묶고 주름진 아가리가 벌어진다."""
    prof = [(0.0, 0.0), (0.17, 0.0), (0.235, 0.05), (0.25, 0.17), (0.22, 0.29), (0.13, 0.38), (0.07, 0.42), (0.085, 0.45), (0.15, 0.5), (0.12, 0.52), (0.0, 0.5)]
    prof = [(r * s, y * s) for (r, y) in prof]
    m.lathe(mat, prof, pos=pos, rot=rot, segs=14, jit=0.03 * s, jfreq=5.0, smooth=True,
            warp=lambda c: Vector((c.x * (1.0 + 0.12 * math.sin(math.atan2(c.z, c.x) * 3.0 + c.y * 4)), c.y, c.z * 0.85)))
    m.lathe("rope", [(0.065 * s, 0.0), (0.095 * s, 0.0), (0.095 * s, 0.03 * s), (0.065 * s, 0.03 * s)], pos=(pos[0], pos[1] + 0.41 * s, pos[2]), rot=rot,
            closed=True, segs=8)


def sword(m, xf, L=1.0, w=0.07, blade="steel", guard="iron"):
    """칼 한 자루: 칼자루 아래, 날 위(원점은 날밑)."""
    m.poly(blade, [(-w / 2, 0.0), (w / 2, 0.0), (w / 2 * 0.95, L * 0.9), (0.0, L), (-w / 2 * 0.95, L * 0.9)], 0.012, xf=xf, bevel=0.002)
    m.box(guard, (w * 3.0, 0.028, 0.034), xf=xf @ Matrix.Translation((0, -0.012, 0)), bevel=0.004, jit=0.001)
    m.cyl("leather", 0.017, 0.017, 0.2, xf=xf @ Matrix.Translation((0, -0.12, 0)), segs=6)
    m.blob("brass", (0.026, 0.026, 0.026), xf=xf @ Matrix.Translation((0, -0.235, 0)), jit=0.002, sub=1)


def stall():
    m = Model("stall", 19)
    for k in range(4):   # 탁자 윗판
        m.box("plank", (2.6, 0.06, 0.29), (0, 0.9, -0.44 + 0.295 * k), cuts=(5, 0, 0), bevel=0.006, jit=0.004, wear=0.2)
    rows_of_boards(m, "plank", -1.28, 1.28, 0.08, 0.87, 0.54, 9, thick=0.03, vary=0.03)
    m.box("wood", (2.6, 0.07, 0.06), (0, 0.84, 0.5), bevel=0.006, jit=0.002, cuts=(4, 0, 0))
    for x in (-1.25, 1.25):
        m.box("wood", (0.11, 2.0, 0.11), (x, 1.0, 0.55), rot=(0, 0, 0.01 * x), bevel=0.01, jit=0.005, cuts=(0, 4, 0), wear=0.12)
        m.box("wood", (0.11, 2.32, 0.11), (x, 1.16, -0.55), rot=(0, 0, -0.01 * x), bevel=0.01, jit=0.005, cuts=(0, 4, 0), wear=0.12)
        m.box("wood", (0.07, 0.07, 1.1), (x, 0.25, 0), bevel=0.006, jit=0.002)
        m.box("wood", (0.06, 0.06, 1.4), (x, 2.0, 0.1), rot=(0.25, 0, 0), bevel=0.006, jit=0.003)
    m.box("plank", (2.4, 0.04, 0.9), (0, 0.3, 0), cuts=(4, 0, 3), bevel=0.005, jit=0.004)
    # 천 차양: 뒤가 높고 앞이 낮다. 가운데가 처진다. 앞에 늘어진 천 자락
    cols, rws = 13, 8
    pts = []
    for i in range(rws):
        u = i / (rws - 1)
        row = []
        for j in range(cols):
            v = j / (cols - 1)
            x = -1.45 + 2.9 * v
            z = -0.66 + 1.55 * u
            y = 2.32 - 0.42 * u - 0.07 * math.sin(PI * v) * math.sin(PI * u) + 0.02 * math.sin(v * 17 + i)
            row.append(Vector((x, y, z)))
        pts.append(row)
    m.sheet("cloth", pts, jit=0.004)
    hang = []
    for k in range(2):
        row = []
        for j in range(cols):
            v = j / (cols - 1)
            tooth = 0.05 if (j % 2 == 0) else 0.0
            row.append(Vector((-1.45 + 2.9 * v, (1.9 - 0.0) - 0.0 - k * (0.22 + tooth) + 0.0, 0.89 + 0.012 * math.sin(v * 25))))
        hang.append(row)
    m.sheet("cloth", hang)
    for x in (-1.1, 0.0, 1.1):
        m.box("wood", (0.05, 0.05, 1.5), (x, 2.12, 0.1), rot=(0.25, 0, 0), bevel=0.005)
    for i in range(3):   # 탁자 위 자루, 궤짝, 바구니
        sack(m, (-0.95 + i * 0.5, 0.93, m.rng.uniform(-0.25, 0.1)), 0.9, rot=(m.rng.uniform(-0.1, 0.1), m.rng.uniform(0, TAU), m.rng.uniform(-0.1, 0.1)))
    m.box("plank", (0.5, 0.3, 0.4), (0.85, 1.08, -0.05), rot=(0, 0.2, 0), bevel=0.01, jit=0.003, cuts=(2, 1, 1))
    m.box("iron", (0.52, 0.03, 0.05), (0.85, 1.02, -0.05), rot=(0, 0.2, 0), bevel=0.004)
    m.lathe("wicker", [(0.12, 0.0), (0.2, 0.2), (0.21, 0.24), (0.19, 0.24), (0.11, 0.02)], pos=(0.2, 0.93, 0.15), segs=10, jit=0.006, jfreq=9.0)
    m.export()


def lantern():
    m = Model("lantern", 23)
    m.box("wood", (0.14, 2.8, 0.14), (0, 1.4, 0), rot=(0.0, 0, 0.012), cuts=(0, 5, 0), bevel=0.012, bseg=2, jit=0.006, wear=0.12)
    m.box("stone_dark", (0.34, 0.2, 0.34), (0, 0.1, 0), bevel=0.025, bseg=2, jit=0.012, smooth=True)
    m.box("wood", (0.09, 0.09, 0.78), (0, 2.7, 0.3), bevel=0.008, jit=0.004, cuts=(0, 0, 3))
    m.box("wood", (0.06, 0.06, 0.62), (0, 2.28, 0.2), rot=(0.78, 0, 0), bevel=0.006, jit=0.003)
    m.box("iron", (0.1, 0.03, 0.1), (0, 2.65, 0.04), bevel=0.005)
    m.cyl("iron", 0.008, 0.008, 0.2, pos=(0, 2.62, 0.6), segs=4)
    m.box("iron", (0.3, 0.03, 0.3), (0, 2.2, 0.6), bevel=0.005, wear=0.2)
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.box("iron", (0.022, 0.4, 0.022), (sx * 0.12, 2.4, 0.6 + sz * 0.12), bevel=0.003)
    m.box("glow", (0.22, 0.34, 0.22), (0, 2.38, 0.6), bevel=0.0)
    m.lathe("iron", [(0.2, 2.56), (0.12, 2.64), (0.025, 2.7), (0.0, 2.7)], pos=(0, 0, 0.6), rot=(0, PI / 4, 0), segs=4, smooth=False)
    m.lathe("iron", [(0.03, 2.69), (0.05, 2.69), (0.05, 2.72), (0.03, 2.72)], pos=(0, 0, 0.6), closed=True, segs=8)
    m.export()


def torch():
    m = Model("torch", 29)
    m.cyl("log", 0.045, 0.034, 0.7, pos=(0, 0, 0), segs=7, jit=0.004)
    m.cyl("iron", 0.058, 0.058, 0.035, pos=(0, 0.15, 0), segs=8)
    m.blob("burnt", (0.085, 0.14, 0.085), pos=(0, 0.4, 0), jit=0.015, jfreq=6.0, sub=2)
    m.lathe("glow", [(0.0, 0.36), (0.075, 0.42), (0.1, 0.5), (0.065, 0.6), (0.02, 0.7), (0.0, 0.74)], segs=8, jit=0.01)
    m.export()


def board():
    m = Model("board", 31)
    for sx in (-1, 1):
        m.box("wood", (0.18, 2.5, 0.18), (sx * 1.3, 1.25, 0), rot=(0, 0, sx * 0.01), cuts=(0, 5, 0), bevel=0.014, bseg=2, jit=0.008, wear=0.12)
        m.box("stone_dark", (0.36, 0.14, 0.36), (sx * 1.3, 0.05, 0), bevel=0.02, bseg=2, jit=0.01, smooth=True)
        m.box("wood", (0.2, 0.08, 0.2), (sx * 1.3, 2.52, 0), bevel=0.01, jit=0.004)
    rows_of_boards(m, "plank", -1.45, 1.45, 0.8, 2.3, 0.07, 6, gap=0.012, thick=0.05, jit=0.004, bevel=0.006, vary=0.05)
    for y in (1.0, 2.1):
        m.box("wood", (2.9, 0.1, 0.06), (0, y, 0.0), cuts=(6, 0, 0), bevel=0.006, jit=0.004)
    for k in range(5):
        w, h = m.rng.uniform(0.38, 0.55), m.rng.uniform(0.5, 0.68)
        x, y = -1.05 + k * 0.52, 1.55 + m.rng.uniform(-0.2, 0.2)
        rz = m.rng.uniform(-0.1, 0.1)

        def curl(c, w=w, h=h):
            return Vector((c.x, c.y, c.z + 0.012 * (c.x / w) ** 2 + 0.01 * (c.y / h) ** 2 * 2))
        m.box("paper", (w, h, 0.004), (x, y, 0.108), rot=(0, 0, rz), cuts=(3, 3, 0), bevel=0.0, warp=curl, jit=0.002, tone=m.rng.uniform(0.7, 1.1))
        m.cyl("iron", 0.008, 0.008, 0.02, pos=(x, y + h / 2 - 0.05, 0.12), rot=(PI / 2, 0, 0), segs=5)
    m.box("paper", (0.9, 0.5, 0.004), (0.0, 1.95, 0.112), rot=(0, 0, 0.02), cuts=(4, 3, 0), bevel=0.0, jit=0.003, tone=0.85)
    # 겹친 널 지붕(앞으로 비스듬히)
    o = Vector((-1.7, 2.66, 0.62))
    dv = Vector((0, 0.3, -0.7)).normalized()
    lap_roof(m, "roof", o, Vector((1, 0, 0)), 3.4, dv, 0.8, 3, thick=0.03, tilt=0.12, wmin=0.3, wmax=0.7)
    m.box("wood", (3.4, 0.06, 0.06), (0, 2.62, 0.6), bevel=0.006, jit=0.003, cuts=(6, 0, 0))
    m.export()


def wheel(m, c, r=0.5, w=0.09):
    W = Matrix.Translation(c) @ Matrix.Rotation(PI / 2, 4, "X")
    m.lathe("wood", [(r - 0.07, -w / 2), (r, -w / 2), (r, w / 2), (r - 0.07, w / 2)], xf=W, closed=True, segs=16, smooth=False, jit=0.004)
    m.lathe("iron", [(r - 0.004, -w / 2 - 0.006), (r + 0.016, -w / 2 - 0.006), (r + 0.016, w / 2 + 0.006), (r - 0.004, w / 2 + 0.006)], xf=W, closed=True,
            segs=32, smooth=False, wear=0.3)
    m.cyl("wood", 0.085, 0.085, w * 1.7, xf=W, segs=10, jit=0.003)
    for k in range(10):
        a = TAU * k / 10
        m.box("wood", (0.04, 0.035, r - 0.06), xf=W @ Matrix.Rotation(a, 4, "Y") @ Matrix.Translation((0, 0, (r - 0.06) / 2 + 0.05)), bevel=0.005, jit=0.002)


def cart():
    m = Model("cart", 37)
    for z in (-0.74, 0.74):
        wheel(m, (0.1, 0.5, z))
    m.box("wood", (0.1, 0.1, 1.7), (0.1, 0.5, 0), bevel=0.01, jit=0.004, cuts=(0, 0, 3))
    for i in range(5):
        m.box("plank", (2.2, 0.05, 0.255), (0, 0.78, -0.51 + i * 0.255), cuts=(4, 0, 0), bevel=0.005, jit=0.004, wear=0.2)
    for x in (-0.8, 0.9):
        m.box("wood", (0.11, 0.11, 1.3), (x, 0.69, 0), bevel=0.008, jit=0.003, cuts=(0, 0, 3))
    for sz in (-1, 1):
        for k in range(2):
            m.box("plank", (2.2, 0.21, 0.035), (0, 0.97 + k * 0.23, sz * 0.62), cuts=(4, 0, 0), bevel=0.005, jit=0.004, wear=0.15)
        for x in (-1.0, -0.35, 0.35, 1.0):
            m.box("wood", (0.07, 0.62, 0.07), (x, 1.05, sz * 0.66), bevel=0.007, jit=0.002, cuts=(0, 2, 0))
    m.box("plank", (0.04, 0.45, 1.25), (1.08, 1.0, 0), bevel=0.005, jit=0.003, cuts=(0, 2, 3))
    for sz in (-1, 1):   # 끌채(끝이 땅 가까이로 처진다)
        m.box("wood", (2.4, 0.075, 0.085), (-1.75, 0.54, sz * 0.4), rot=(0, 0, 0.1), bevel=0.01, jit=0.006, cuts=(6, 0, 0), wear=0.15)
    m.box("wood", (0.07, 0.07, 0.9), (-2.8, 0.46, 0), bevel=0.008, jit=0.003)
    # 포장: 네 기둥 위에 걸친 천(가운데가 불룩하고 가장자리가 처진다)
    for x in (-0.8, 0.9):
        for z in (-0.6, 0.6):
            m.cyl("wood", 0.04, 0.035, 1.3, pos=(x, 1.52, z), segs=6, jit=0.003)
    for z in (-0.6, 0.6):
        m.box("wood", (1.9, 0.05, 0.05), (0.05, 2.17, z), bevel=0.005, jit=0.003, cuts=(3, 0, 0))
    for x in (-0.8, 0.9):
        m.box("wood", (0.05, 0.05, 1.3), (x, 2.2, 0), bevel=0.005, jit=0.003)
    pts = []
    for i in range(9):
        u = i / 8
        row = []
        for j in range(9):
            v = j / 8
            x = -1.0 + 2.1 * u
            z = -0.8 + 1.6 * v
            y = 2.28 - 0.38 * ((v - 0.5) * 2) ** 2 - 0.06 * math.sin(PI * u) * 0 + 0.025 * math.sin(i * 1.7 + j * 0.8)
            row.append(Vector((x, y, z)))
        pts.append(row)
    m.sheet("cloth", pts, jit=0.003)
    for i in range(3):
        sack(m, (-0.6 + i * 0.5, 0.8, 0.1 * (i - 1)), 0.95, rot=(0, m.rng.uniform(0, TAU), 0))
    # 작은 통
    m.cyl("plank", 0.2, 0.2, 0.45, pos=(0.75, 1.03, -0.2), segs=12, jit=0.003, smooth=False)
    m.lathe("iron", [(0.205, 0.0), (0.215, 0.0), (0.215, 0.03), (0.205, 0.03)], pos=(0.75, 0.88, -0.2), closed=True, segs=12)
    m.lathe("iron", [(0.205, 0.0), (0.215, 0.0), (0.215, 0.03), (0.205, 0.03)], pos=(0.75, 1.15, -0.2), closed=True, segs=12)
    m.export()


def mirror():
    m = Model("mirror", 41)
    m.lathe("dirt", [(0.0, 0.0), (0.82, 0.0), (0.85, 0.03), (0.8, 0.06), (0.0, 0.06)], segs=20, smooth=True, jit=0.004)
    for sx in (-1, 1):
        m.box("wood", (0.1, 2.3, 0.12), (sx * 0.58, 1.18, 0), cuts=(0, 5, 0), bevel=0.012, bseg=2, jit=0.004, wear=0.1)
        m.blob("brass", (0.05, 0.05, 0.05), (sx * 0.58, 2.38, 0), jit=0.002, sub=2)
        m.box("wood", (0.12, 0.08, 0.7), (sx * 0.58, 0.04, -0.1), bevel=0.01, jit=0.003)
        m.box("wood", (0.05, 2.0, 0.04), (sx * 0.5, 1.24, 0.045), bevel=0.006)
    m.box("wood", (1.26, 0.13, 0.12), (0, 2.3, 0), bevel=0.012, bseg=2, jit=0.003, cuts=(4, 0, 0))
    m.box("wood", (1.26, 0.11, 0.12), (0, 0.18, 0), bevel=0.012, bseg=2, jit=0.003)
    m.box("wood", (1.0, 0.05, 0.04), (0, 2.22, 0.045), bevel=0.006)
    m.box("wood", (1.0, 0.05, 0.04), (0, 0.26, 0.045), bevel=0.006)
    m.box("mirror", (1.0, 1.96, 0.02), (0, 1.24, 0.02), bevel=0.0)
    m.box("brass", (0.34, 0.12, 0.14), (0, 2.42, 0), bevel=0.02, bseg=2, jit=0.002, wear=0.2)
    m.blob("brass", (0.07, 0.07, 0.04), (0, 2.5, 0.06), jit=0.002, sub=2)
    # 옆 걸대: 기둥, 가로대, 걸린 망토, 쇠모자
    m.box("wood", (0.09, 1.9, 0.09), (1.25, 0.95, 0.1), cuts=(0, 4, 0), bevel=0.01, jit=0.004)
    m.box("wood", (0.72, 0.07, 0.07), (1.25, 1.75, 0.1), bevel=0.008, jit=0.003, cuts=(3, 0, 0))
    m.box("wood", (0.3, 0.06, 0.3), (1.25, 0.03, 0.1), bevel=0.01)
    pts = []
    for i in range(7):
        u = i / 6
        row = []
        for j in range(8):
            v = j / 7
            row.append(Vector((1.0 + 0.5 * v, 1.74 - 0.95 * u * (1.0 - 0.08 * math.sin(v * 9)), 0.17 + 0.03 * math.sin(v * 15 + 0.5) * u + 0.03 * u)))
        pts.append(row)
    m.sheet("cloth_red", pts)
    m.lathe("steel", [(0.0, 1.87), (0.15, 1.87), (0.18, 1.92), (0.17, 2.0), (0.13, 2.1), (0.05, 2.16), (0.0, 2.17)], pos=(1.25, 0.0, 0.1), segs=14, jit=0.003)
    m.box("steel", (0.04, 0.04, 0.2), (1.25, 2.1, 0.28), bevel=0.003)
    m.export()


def duel_post():
    m = Model("duel_post", 43)
    m.lathe("dirt", [(0.0, 0.0), (2.0, 0.0), (2.1, 0.03), (2.0, 0.055), (0.0, 0.055)], segs=36, jit=0.005, smooth=True)
    for i in range(10):
        a = TAU * i / 10
        xf = Matrix.Rotation(-a, 4, "Y") @ Matrix.Translation((1.95, 0.1, 0))
        m.box("stone", (0.26, 0.2, 0.36), xf=xf, bevel=0.04, bseg=2, jit=0.016, jfreq=5.0, cuts=(1, 1, 1), smooth=True, tone=m.rng.uniform(0.8, 1.05))
    m.box("wood", (0.3, 2.5, 0.3), (0, 1.25, 0), rot=(0, 0, 0.008), cuts=(0, 6, 0), bevel=0.025, bseg=2, jit=0.014, jfreq=2.5, wear=0.15)
    for y in (0.5, 1.9):
        m.box("iron", (0.34, 0.07, 0.34), (0, y, 0), bevel=0.01, wear=0.25)
    m.box("wood", (1.5, 0.12, 0.14), (0, 2.1, 0), cuts=(6, 0, 0), bevel=0.012, bseg=2, jit=0.005)
    for k in (-1, 1):
        sword(m, Matrix.Translation((0, 1.8, 0.2)) @ Matrix.Rotation(k * 0.7, 4, "Z") @ Matrix.Translation((0, -0.25, 0)), L=1.1, w=0.075)
    m.box("iron", (0.3, 0.1, 0.12), (0, 1.55, 0.18), bevel=0.01)
    for x, mat in ((-0.6, "cloth_gold"), (0.6, "cloth_red")):
        pts = []
        for i in range(8):
            u = i / 7
            row = []
            for j in range(6):
                v = j / 5
                hem = 0.0
                if i == 7:
                    hem = 0.14 * (1 - abs(v - 0.5) * 2)
                row.append(Vector((x - 0.18 + 0.36 * v, 2.04 - 0.7 * u + hem, 0.03 + 0.03 * math.sin(v * 6 + u * 3 + x) * u)))
            pts.append(row)
        m.sheet(mat, pts)
        m.cyl("iron", 0.012, 0.012, 0.42, pos=(x, 2.04, 0.02), rot=(0, 0, PI / 2), segs=5)
    m.export()
def fence_post(m, h=1.05, w=0.13, x=0.0, z=0.0):
    m.box("wood", (w, h, w), (x, h / 2 - 0.02, z), rot=(m.rng.uniform(-0.02, 0.02), 0, m.rng.uniform(-0.02, 0.02)), cuts=(0, 3, 0), bevel=0.012, bseg=2,
          jit=0.006, wear=0.15)
    m.box("wood", (w * 0.8, 0.06, w * 0.8), (x, h - 0.0, z), rot=(0, 0.4, 0), bevel=0.01, jit=0.003)   # 깎은 머리


def fence_unit():
    """울타리 한 칸: 왼쪽 말뚝 하나와 +Z로 0.6m 뻗는 가로대 둘(말뚝 간격). 게임이 칸마다 놓고 z를 늘려 맞춘다."""
    m = Model("fence_unit", 47)
    fence_post(m)
    for y in (0.4, 0.82):
        m.box("wood", (0.075, 0.075, 0.66), (0.0, y + m.rng.uniform(-0.01, 0.01), 0.3), cuts=(0, 0, 3), bevel=0.01, jit=0.005, warp=None, wear=0.12)
        m.lathe("rope", [(0.04, -0.012), (0.056, -0.012), (0.056, 0.012), (0.04, 0.012)], rot=(PI / 2, 0, 0), pos=(0, y, 0.0), closed=True, segs=8)
    m.export()


def fence_end():
    m = Model("fence_end", 49)
    fence_post(m)
    m.export()


def scarecrow():
    m = Model("scarecrow", 53)
    m.box("wood", (0.12, 1.75, 0.12), (0, 0.87, 0), rot=(0, 0, 0.01), cuts=(0, 4, 0), bevel=0.012, bseg=2, jit=0.008)
    m.box("wood", (1.15, 0.09, 0.09), (0, 1.27, 0), rot=(0, 0, 0.03), cuts=(4, 0, 0), bevel=0.01, jit=0.006)
    # 자루옷 몸통과 소매
    m.lathe("sack", [(0.0, 0.55), (0.2, 0.58), (0.27, 0.75), (0.28, 1.05), (0.22, 1.3), (0.12, 1.4), (0.0, 1.42)], segs=14, jit=0.02, jfreq=5.0)
    for sx in (-1, 1):
        m.lathe("sack", [(0.0, 0.0), (0.085, 0.04), (0.1, 0.2), (0.09, 0.5), (0.075, 0.6), (0.0, 0.62)], pos=(sx * 0.07, 1.27, 0), rot=(0, 0, -sx * PI / 2), segs=9,
                jit=0.012, jfreq=5.0)
        for k in range(8):   # 소매 끝으로 삐져나온 짚
            a = m.rng.uniform(-0.5, 0.5)
            m.box("straw", (0.2, 0.006, 0.008), (sx * (0.7 + 0.08), 1.27 + m.rng.uniform(-0.05, 0.05), m.rng.uniform(-0.05, 0.05)), rot=(0, a, sx * m.rng.uniform(-0.3, 0.2)), bevel=0.0)
    for k in range(46):   # 옷자락 아래 짚
        a = TAU * k / 46 + m.rng.uniform(-0.05, 0.05)
        ln = m.rng.uniform(0.18, 0.36)
        xf = Matrix.Rotation(-a, 4, "Y") @ Matrix.Translation((0.27, 0.58, 0)) @ Matrix.Rotation(m.rng.uniform(0.15, 0.55), 4, "Z") @ Matrix.Translation((0.0, -ln / 2, 0))
        m.box("straw", (0.008, ln, 0.012), xf=xf, bevel=0.0)
    m.lathe("rope", [(0.2, 1.02), (0.3, 1.02), (0.3, 1.05), (0.2, 1.05)], closed=True, segs=14, jit=0.004)
    # 자루 머리, 꿰맨 얼굴, 낡은 모자
    def head(c):
        t = max(0.0, (c.y - 0.1) / 0.14)
        k = 1.0 - 0.35 * t * t
        return Vector((c.x * k, c.y, c.z * k))
    m.blob("sack", (0.19, 0.22, 0.19), (0, 1.66, 0), jit=0.016, jfreq=4.0, warp=head)
    for sx in (-1, 1):
        m.box("burnt", (0.05, 0.015, 0.01), (sx * 0.075, 1.68, 0.18), rot=(0, 0, sx * 0.6), bevel=0.0)
        m.box("burnt", (0.05, 0.015, 0.01), (sx * 0.075, 1.68, 0.18), rot=(0, 0, -sx * 0.6), bevel=0.0)
    for k in range(5):
        m.box("burnt", (0.012, 0.045, 0.008), (-0.07 + k * 0.035, 1.58, 0.183), rot=(0, 0, 0.1 * (k - 2)), bevel=0.0)
    m.lathe("leather", [(0.0, 1.86), (0.12, 1.88), (0.15, 1.83), (0.19, 1.8), (0.32, 1.77), (0.34, 1.78), (0.3, 1.8), (0.17, 1.83)], rot=(0.12, 0, 0.1), segs=14, jit=0.008)
    m.export()


def sword_rack():
    m = Model("sword_rack", 59)
    for sx in (-1, 1):
        m.box("wood", (0.12, 1.55, 0.12), (sx * 0.9, 0.77, 0), cuts=(0, 4, 0), bevel=0.012, bseg=2, jit=0.006, wear=0.12)
        m.box("wood", (0.09, 0.07, 0.4), (sx * 0.9, 0.04, 0), bevel=0.008)
    for y in (0.82, 1.3):
        m.box("wood", (2.0, 0.08, 0.09), (0, y, -0.03), cuts=(5, 0, 0), bevel=0.01, jit=0.004)
    for i in range(4):
        x = -0.6 + i * 0.4
        sword(m, Matrix.Translation((x, 1.52, 0.06)) @ Matrix.Rotation(PI + m.rng.uniform(-0.08, 0.08), 4, "Z") @ Matrix.Translation((0, 0.0, 0.0)), L=0.78 + 0.05 * (i % 2), w=0.06)
    for y in (0.82, 1.3):
        for x in (-0.6, -0.2, 0.2, 0.6):
            m.box("leather", (0.06, 0.03, 0.08), (x, y, 0.03), bevel=0.004)
    m.export()


def palisade_post(name, seed, h=3.1):
    m = Model(name, seed)
    r = 0.18
    prof = [(r * 1.05, 0.0), (r * 1.08, 0.12), (r * 1.0, 0.8), (r * 0.98, 1.6), (r * 0.96, 2.4), (r * 0.94, h - 0.5), (r * 0.8, h - 0.32), (r * 0.5, h - 0.16), (r * 0.2, h - 0.05), (0.0, h)]

    def warp(c):
        # 뾰족한 끝을 한쪽으로 쏠리게 깎고 몸통을 살짝 휘게
        lean = 0.015 * math.sin(c.y * 1.3 + seed)
        c.x += lean
        if c.y > h - 0.55:
            f = (c.y - (h - 0.55)) / 0.55
            c.x += f * f * 0.03
        return c

    m.lathe("log", prof, segs=9, jit=0.012, jfreq=3.0, warp=warp, smooth=True)
    if seed % 2 == 0:
        m.lathe("rope", [(r * 0.99, 2.0), (r * 1.06, 2.0), (r * 1.06, 2.05), (r * 0.99, 2.05)], closed=True, segs=9, jit=0.004)
    m.export()


def palisade_a():
    palisade_post("palisade_a", 2)


def palisade_b():
    palisade_post("palisade_b", 3)


def palisade_c():
    palisade_post("palisade_c", 4)


def palisade_rail():
    """목책 가로대: +Z로 1m인 통나무 한 토막, 끝에 줄 묶음."""
    m = Model("palisade_rail", 61)
    m.cyl("log", 0.065, 0.06, 1.06, pos=(0, 0, 0.5), rot=(PI / 2, 0, 0), segs=7, jit=0.006, jfreq=4.0, warp=lambda c: Vector((c.x, c.y, c.z + 0.015 * math.sin(c.y * 4))))
    m.lathe("rope", [(0.06, -0.02), (0.085, -0.02), (0.085, 0.02), (0.06, 0.02)], pos=(0, 0, 0.02), rot=(PI / 2, 0, 0), closed=True, segs=8)
    m.export()


def forge_shed():
    """대장간 차양(원점은 대장간 기준점): 기울인 널 지붕 7.6 x 3.6, 기둥 둘, 들보, 서까래."""
    m = Model("forge_shed", 67)
    for sx in (-1, 1):
        m.box("wood", (0.2, 1.95, 0.2), (sx * 3.4, 0.97, 3.7), cuts=(0, 5, 0), bevel=0.016, bseg=2, jit=0.01, wear=0.12)
        m.box("stone_dark", (0.42, 0.16, 0.42), (sx * 3.4, 0.06, 3.7), bevel=0.03, bseg=2, jit=0.015, smooth=True)
        m.box("wood", (0.12, 1.0, 0.1), (sx * 3.05, 1.45, 3.7), rot=(0, 0, -sx * 0.65), bevel=0.008, jit=0.004)
    m.box("wood", (7.2, 0.2, 0.22), (0, 1.88, 3.7), cuts=(10, 0, 0), bevel=0.016, bseg=2, jit=0.008, wear=0.1)
    ang = 0.32
    dvv = Vector((0, math.sin(ang), -math.cos(ang)))
    eave = Vector((-3.8, 2.35 - 1.8 * math.sin(ang), 2.2 + 1.8 * math.cos(ang)))
    for i in range(9):   # 서까래: 비탈 방향의 둥근 막대
        x = -3.5 + i * 0.875
        c = eave + dvv * 1.8 + Vector((x + 3.8, 0, 0))
        m.cyl("log", 0.055, 0.05, 3.7, xf=Matrix.Translation(c - Vector((0, 0.06, 0))) @ Matrix.Rotation(ang - PI / 2, 4, "X"), segs=6, jit=0.004)
    lap_roof(m, "roof", eave + Vector((0, 0.0, 0)), Vector((1, 0, 0)), 7.6, dvv, 3.64, 12, thick=0.04, tilt=0.1, wmin=0.4, wmax=0.95)
    m.box("wood", (7.8, 0.12, 0.12), (0, 2.35 + 1.8 * math.sin(ang) + 0.02, 2.2 - 1.8 * math.cos(ang) + 0.05), bevel=0.012, jit=0.005, cuts=(8, 0, 0))
    m.box("wood", (7.8, 0.1, 0.12), (0, 2.35 - 1.8 * math.sin(ang) - 0.02, 2.2 + 1.8 * math.cos(ang) + 0.04), bevel=0.01, jit=0.005, cuts=(8, 0, 0))
    m.export()


def forge_furnace():
    """대장간 화덕(원점은 바닥 가운데, 앞이 +Z): 돌로 쌓은 몸통, 아궁이 속의 불, 굴뚝."""
    m = Model("forge_furnace", 71)
    W, D = 1.6, 1.2
    m.box("stone_dark", (W - 0.1, 1.0, D - 0.1), (0, 0.5, 0), bevel=0.0)
    courses = [(0.0, 0.34), (0.34, 0.34), (0.68, 0.32)]
    for (y0, hh) in courses:
        for side in range(4):
            horiz = side in (0, 1)
            L = W if horiz else D
            sgn = 1 if side % 2 == 0 else -1
            x = -L / 2
            while x < L / 2 - 0.05:
                w = min(m.rng.uniform(0.3, 0.55), L / 2 - x)
                if w < 0.12:
                    break
                cx = x + w / 2
                skip = side == 0 and abs(cx) < 0.46 and y0 >= 0.2 and y0 < 0.7
                if not skip:
                    d = m.rng.uniform(0.16, 0.22)
                    h2 = hh * m.rng.uniform(0.9, 1.0)
                    if horiz:
                        pos = (cx, y0 + h2 / 2, sgn * (D / 2 - d / 2 + 0.01))
                        sz = (w - 0.015, h2, d)
                    else:
                        pos = (sgn * (W / 2 - d / 2 + 0.01), y0 + h2 / 2, cx)
                        sz = (d, h2, w - 0.015)
                    m.box("stone", sz, pos, bevel=0.025, bseg=2, jit=0.012, jfreq=5.0, cuts=(1, 1, 1), smooth=True, tone=m.rng.uniform(0.75, 1.05))
                x += w
    # 아궁이: 이마돌, 속 그을음, 숯불
    m.box("stone", (1.0, 0.2, 0.3), (0, 0.76, D / 2 - 0.12), bevel=0.03, bseg=2, jit=0.012, smooth=True)
    m.box("burnt", (0.88, 0.5, 0.06), (0, 0.45, 0.2), bevel=0.0)
    m.box("ember", (0.82, 0.1, 0.34), (0, 0.27, 0.36), bevel=0.01, jit=0.012, cuts=(4, 0, 2))
    for k in range(6):
        m.blob("ember", (0.07, 0.05, 0.06), (-0.34 + k * 0.14, 0.34, 0.38 + m.rng.uniform(-0.08, 0.08)), jit=0.015, sub=1)
    m.box("glow", (0.7, 0.22, 0.02), (0, 0.5, 0.24), bevel=0.0)
    # 갓과 굴뚝
    def taper(c):
        f = max(0.0, min(1.0, (c.y + 0.35) / 0.7))
        k = 1.0 - 0.55 * f
        return Vector((c.x * k, c.y, c.z * k))
    m.box("stone", (W - 0.05, 0.7, D - 0.05), (0, 1.35, 0), cuts=(0, 3, 0), bevel=0.02, warp=taper, jit=0.01, smooth=False)
    m.box("stone", (0.46, 1.0, 0.46), (0, 2.2, 0), cuts=(0, 4, 0), bevel=0.025, bseg=2, jit=0.01, smooth=True)
    m.box("stone_dark", (0.56, 0.1, 0.56), (0, 2.65, 0), bevel=0.02, jit=0.008)
    m.export()


def anvil():
    """모루와 그루터기(원점은 그루터기 바닥 가운데). 모루 윗면 높이 0.96, 뿔은 +X."""
    m = Model("anvil", 73)
    m.cyl("log", 0.5, 0.45, 0.6, pos=(0, 0.3, 0), segs=14, jit=0.012, jfreq=3.0)
    m.cyl("logend", 0.45, 0.45, 0.012, pos=(0, 0.605, 0), segs=14, jit=0.006)
    for k in range(3):
        a = m.rng.uniform(0, TAU)
        m.box("burnt", (0.18, 0.012, 0.012), (math.cos(a) * 0.15, 0.612, math.sin(a) * 0.15), rot=(0, a, 0), bevel=0.0)
    out = [(-0.55, 0.96), (0.35, 0.96), (0.6, 0.93), (0.78, 0.9), (0.98, 0.86), (1.14, 0.8), (0.36, 0.76), (0.27, 0.7), (0.24, 0.52), (0.3, 0.46), (0.4, 0.36), (-0.4, 0.36), (-0.3, 0.46), (-0.24, 0.52), (-0.27, 0.7), (-0.5, 0.76)]
    m.poly("iron", out, 0.34, pos=(0, 0.0, 0.0), bevel=0.012, jit=0.003, wear=0.4)
    m.box("iron", (0.6, 0.06, 0.4), (0.0, 0.62, 0), bevel=0.01)
    m.box("steel", (0.86, 0.015, 0.34), (-0.1, 0.962, 0), bevel=0.003, wear=0.4)
    m.cyl("iron", 0.03, 0.03, 0.2, pos=(-0.26, 0.97, 0), segs=6)
    m.export()


def grindstone():
    """숫돌(원점은 바닥, 바퀴 축은 Z, 높이 0.75)."""
    m = Model("grindstone", 79)
    W = Matrix.Translation((0, 0.75, 0)) @ Matrix.Rotation(PI / 2, 4, "X")
    m.lathe("stone_dark", [(0.0, -0.08), (0.38, -0.08), (0.4, -0.05), (0.4, 0.05), (0.38, 0.08), (0.0, 0.08)], xf=W, segs=22, jit=0.006, jfreq=5.0)
    m.cyl("iron", 0.03, 0.03, 0.4, xf=W, segs=6)
    for sz in (-1, 1):
        m.box("wood", (0.1, 0.8, 0.07), (0, 0.38, sz * 0.17), rot=(0, 0, 0.0), cuts=(0, 3, 0), bevel=0.008, jit=0.004)
        m.box("wood", (0.07, 0.4, 0.07), (0.17, 0.2, sz * 0.2), rot=(0, 0, 0.35), bevel=0.006)
        m.box("wood", (0.07, 0.4, 0.07), (-0.17, 0.2, sz * 0.2), rot=(0, 0, -0.35), bevel=0.006)
    m.box("wood", (0.5, 0.05, 0.45), (0, 0.04, 0), bevel=0.008, jit=0.004)
    m.box("iron", (0.18, 0.025, 0.025), (0.1, 0.75, 0.25), bevel=0.003)
    m.cyl("iron", 0.012, 0.012, 0.18, pos=(0.19, 0.75, 0.25), rot=(PI / 2, 0, 0), segs=5)
    m.export()


def blades():
    """벽에 기댄 칼 셋(원점은 첫 칼의 바닥, 칼마다 +0.35m, 앞으로 0.18rad 기대었다)."""
    m = Model("blades", 83)
    for i in range(3):
        sword(m, Matrix.Translation((i * 0.35, 1.28, 0)) @ Matrix.Rotation(0.18, 4, "X") @ Matrix.Rotation(PI, 4, "Z"), L=0.95 + 0.05 * (i % 2), w=0.075)
    m.export()


NAMES = ["barrel", "crate", "hay", "firewood", "bench", "well", "stall", "lantern", "torch", "board", "cart", "mirror", "duel_post", "fence_unit", "fence_end", "scarecrow", "sword_rack", "palisade_a", "palisade_b", "palisade_c", "palisade_rail", "forge_shed", "forge_furnace", "anvil", "grindstone", "blades"]
MAKERS = {k: globals()[k] for k in NAMES}


def main():
    argv = sys.argv
    names = argv[argv.index("--") + 1:] if "--" in argv else []
    for nm in names or list(MAKERS):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        try:
            MAKERS[nm]()
        except Exception:
            print("실패:", nm)
            traceback.print_exc()


if __name__ == "__main__":
    main()
