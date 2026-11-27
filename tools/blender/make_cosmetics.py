# 「검의 언덕」 영주 꾸미기(망토·머리) 모양을 Blender로 짓고 .glb로 내보낸다. (2026-11-27, docs/cosmetics.md)
#
#   blender -b -P tools/blender/make_cosmetics.py            # 표의 망토·머리 전부
#   blender -b -P tools/blender/make_cosmetics.py -- cape_night head_helm   # 몇 개만
# 결과: assets/cosmetics/<항목 id>.glb. 색은 scripts/debug/build_cosmetics.gd의 표에서 그대로 읽는다(한 곳).
# 손으로 모델링한 것이 아니라 스크립트로 짓는다(AI 생성 에셋이 아니다). 어두운 사실풍: 닳은 쇠, 낡은 천.
#
# 약속(게임 CosmeticArt와 같은 크기·방향):
#   - 망토: 천 시뮬레이션으로 굳힌 모양(아래 "망토" 절). 원점 = 등 뼈에 다는 자리(CosmeticRig: 등 뼈 + (0, 0.15, 0.13)), 크기 1(CHAR_CAPE_SCALE),
#     아래(Blender -Z = Godot -Y)로 늘어진다, 길이 ~1.04m, 등은 Godot +Z(= Blender -Y). 뼈 CapeBone0~2(CosmeticArt.sway가 아래쪽만 흔든다), 질감은 glb 안에 든다.
#     환경 변수: COS_PREVIEW=폴더(Workbench로 뒤·옆을 찍는다), COS_FAST=1(거친 격자로 빠르게), COS_DEBUG=1.
#   - 머리: 머리 반지름 1, 머리 가운데가 원점, 얼굴은 Godot -Z(= Blender +Y), 위는 Blender +Z.
#   - 재질: 망토 천은 꼭짓점 색(무늬), 룬 자수만 빛나는 두 번째 재질. 머리는 쇠·장식·천·빛 재질을 항목 색으로.

import bpy
import bmesh
import math
import os
import re
import sys
from mathutils import Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "assets", "cosmetics")
os.makedirs(OUT, exist_ok=True)


# ================================================================== 표 읽기
def read_rows():
    src = open(os.path.join(ROOT, "scripts", "debug", "build_cosmetics.gd"), encoding="utf-8").read()
    rows = []
    pat = re.compile(r'\["(\w+)", "(\w+)", "[^"]*", "\w+", \d+, "\w*", "(\w+)", (Color\([^)]*\)|Color\.WHITE), (Color\([^)]*\)|Color\.WHITE)\]')
    for m in pat.finditer(src):
        def col(s):
            if s == "Color.WHITE":
                return (1.0, 1.0, 1.0)
            v = [float(x) for x in s[6:-1].split(",")]
            return tuple(v[:3])
        rows.append(dict(id=m.group(1), slot=m.group(2), style=m.group(3), c1=col(m.group(4)), c2=col(m.group(5))))
    return rows


# ================================================================== 장면 도구
def clear():
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.textures, bpy.data.images):
        for b in list(coll):
            coll.remove(b)


def lin(c):
    f = lambda x: x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4
    return (f(c[0]), f(c[1]), f(c[2]), 1.0)


def mat(name, color, rough=0.8, metal=0.0, glow=0.0, vcol=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    n = m.node_tree.nodes
    b = n["Principled BSDF"]
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if vcol:
        cn = n.new("ShaderNodeVertexColor")
        cn.layer_name = "Col"
        m.node_tree.links.new(cn.outputs["Color"], b.inputs["Base Color"])
    else:
        b.inputs["Base Color"].default_value = lin(color)
    if glow > 0.0:
        b.inputs["Emission Color"].default_value = lin(color)
        b.inputs["Emission Strength"].default_value = glow
    return m


def hmat(name, color, rough=0.6, metal=0.0, grime=0.2, rust=0.0):
    """머리 재질: 색은 꼭짓점 색(때·얼룩·녹을 굽는다)으로 싣는다. rough/metal은 닳은 쇠 느낌(반사가 하얗게 뜨지 않게 낮춘다)."""
    m = mat(name, color, rough, metal, 0.0, vcol=True)
    m["bc"] = list(color)
    m["grime"] = grime
    m["rust"] = rust
    return m


def paint_grime(obj):
    """꼭짓점 색 = 재질 색 x (잡음 얼룩 + 아래를 보는 면은 어둡게 + 녹 기운). 머리 조각마다 다른 값."""
    m = obj.data.materials[0] if obj.data.materials else None
    if m is None or "bc" not in m:
        return
    from mathutils import noise
    bc, gr, rust = m["bc"], m["grime"], m["rust"]
    me = obj.data
    ca = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    off = Vector((hash01(len(me.vertices), 1) * 9, hash01(len(me.vertices), 2) * 9, hash01(len(me.vertices), 3) * 9))
    for li, lp in enumerate(me.loops):
        v = me.vertices[lp.vertex_index]
        p = (v.co + off) * 2.2
        n = noise.fractal(p, 0.55, 2.2, 3)            # 큰 얼룩
        f = noise.turbulence(p * 4.0, 2, False)       # 잔 긁힘
        nz = me.vertices[lp.vertex_index].normal.z
        k = 1.0 + gr * (n * 0.9 - 0.15) - gr * 0.4 * f + 0.08 * (nz * 0.5 - 0.3)
        r = rust * max(0.0, f - 0.35) * 2.0
        c = tuple(max(0.0, min(1.0, bc[i] * k * (1 - r) + (0.34, 0.2, 0.1)[i] * r * 0.5)) for i in range(3))
        ca.data[li].color = lin(c)


def finish(obj, material, bevel=0.0, smooth=True, wear=0.0, subsurf=0):
    obj.data.materials.clear()
    obj.data.materials.append(material)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    if bevel > 0.0:
        md = obj.modifiers.new("bevel", "BEVEL")
        md.width = bevel
        md.segments = 2
        md.limit_method = "ANGLE"
    if subsurf:
        md = obj.modifiers.new("sub", "SUBSURF")
        md.levels = subsurf
        md.render_levels = subsurf
    if wear > 0.0:   # 닳고 우그러진 면: 잡음으로 민다
        tex = bpy.data.textures.new("wear_" + obj.name, "CLOUDS")
        tex.noise_scale = 0.35
        md = obj.modifiers.new("wear", "DISPLACE")
        md.texture = tex
        md.strength = wear
        md.mid_level = 0.5
    for md in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=md.name)
    if smooth:
        bpy.ops.object.shade_smooth()
    paint_grime(obj)
    obj.select_set(False)
    return obj


def sphere(r, loc, scale=(1, 1, 1), seg=48, rings=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=r, location=loc)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return o


def dome(r, loc, scale=(1, 1, 1), cut=0.0):
    """위쪽 반구(cut: 이 높이 아래를 자른다, 반지름 비율)."""
    o = sphere(r, loc, scale, 56, 28)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    z0 = loc[2] + cut * r * scale[2]
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, z0), plane_no=(0, 0, 1), clear_inner=True)
    cut_edges = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
    bmesh.ops.holes_fill(bm, edges=cut_edges) if False else None
    bm.to_mesh(o.data)
    bm.free()
    return o


def cylinder(r1, r2, h, loc, rot=(0, 0, 0), seg=32, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_cone_add(vertices=seg, radius1=r1, radius2=r2, depth=h, location=loc, rotation=[math.radians(a) for a in rot])
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return o


def box(size, loc, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=[math.radians(a) for a in rot])
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return o


def band(r_in, r_out, h, z, squash=1.0, seg=64):
    """속이 빈 띠(머리를 두르는 고리). 머리가 약간 길어 앞뒤를 squash로 맞춘다."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=seg, radius=r_out, depth=h, location=(0, 0, z))
    o = bpy.context.object
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if abs(f.normal.z) > 0.9], context="FACES")
    bm.to_mesh(o.data)
    bm.free()
    o.scale = (1, squash, 1)
    bpy.ops.object.transform_apply(scale=True)
    md = o.modifiers.new("solid", "SOLIDIFY")
    md.thickness = -(r_out - r_in)
    bpy.ops.object.modifier_apply(modifier="solid")
    return o


def rivets(z, r, n, size, material, y_squash=1.0, start=0.0):
    out = []
    for i in range(n):
        a = start + math.tau * i / n
        s = sphere(size, (math.sin(a) * r, math.cos(a) * r * y_squash, z), seg=12, rings=8)
        finish(s, material)
        out.append(s)
    return out


# ================================================================== 머리
def build_head(row):
    c1, c2, st = row["c1"], row["c2"], row["style"]
    iron = hmat("iron", c1, 0.62, 0.55, 0.13, 0.25)      # 닳은 쇠: 거칠기 0.62, 금속 0.55, 얼룩과 녹 기운
    tc = tuple(0.6 * x + 0.4 * (sum(c2) / 3) for x in c2)   # 테두리는 원색이 튀지 않게 채도를 낮춘다
    trim = hmat("trim", tuple(0.85 * x for x in tc) if st in ("plume", "helm", "horn") else c2, 0.55, 0.5, 0.12, 0.12)
    cloth = hmat("cloth", c1, 0.95, 0.0, 0.12)
    cloth2 = hmat("cloth2", c2, 0.95, 0.0, 0.12)
    glow = mat("glow", c2, 0.4, 0.0, 2.2)
    dark = hmat("dark", tuple(x * 0.35 for x in c1), 0.6, 0.55, 0.15)

    def cap(r=1.1, z=0.1, wear=0.012, sc=(1.0, 1.05, 1.0)):
        finish(dome(r, (0, 0, z), sc), iron, 0.01, wear=wear)

    if st == "none":
        return
    if st == "band":
        finish(band(0.96, 1.08, 0.2, 0.34, 1.02), cloth, 0.005)
        finish(box((0.46, 0.04, 0.2), (0.0, -1.04, 0.32), (0, 0, 0)), cloth, 0.01)   # 뒤로 묶은 매듭
        finish(box((0.12, 0.03, 0.55), (0.12, -1.06, 0.1), (0, 0, 10)), cloth, 0.005)
        finish(box((0.12, 0.03, 0.5), (-0.1, -1.06, 0.06), (0, 0, -14)), cloth, 0.005)
    elif st == "hood":
        finish(dome(1.2, (0, -0.3, 0.1), (1.0, 1.0, 1.05), -0.35), cloth, 0.0, wear=0.03)
        finish(cylinder(0.0, 0.5, 0.9, (0, -1.05, 0.95), (-65, 0, 0), 14), cloth2, 0.0, wear=0.02)
        finish(band(1.0, 1.13, 0.34, -0.88, 1.0), cloth, 0.0, wear=0.02)   # 어깨로 내려오는 깃
        finish(band(0.97, 1.02, 0.07, 0.3, 1.0), cloth2, 0.0)             # 얼굴 둘레 가는 줄
    elif st == "kettle":
        cap(1.06, 0.3, 0.016, (1.0, 1.05, 1.08))
        finish(cylinder(1.62, 1.1, 0.2, (0, 0, 0.22), (0, 0, 0), 64, (1.0, 1.04, 1.0)), iron, 0.014, wear=0.014)   # 아래로 처진 챙
        finish(band(1.55, 1.64, 0.05, 0.12, 1.04), trim, 0.01)                # 챙 가장자리 말림
        finish(band(1.0, 1.1, 0.1, 0.32, 1.05), trim, 0.01)
        rivets(0.5, 1.02, 10, 0.04, trim, 1.03)
    elif st in ("helm", "plume", "horn"):
        cap(1.1, 0.1)
        finish(band(1.0, 1.14, 0.12, 0.1, 1.04), trim, 0.01)               # 아래 테
        finish(box((0.2, 0.08, 0.95), (0, 1.06, -0.28)), iron, 0.01)        # 코가리개
        for k in (-1.0, 1.0):
            finish(box((0.08, 0.62, 0.7), (k * 1.04, 0.18, -0.22), (0, 0, k * -6)), iron, 0.012)   # 볼가리개
        rivets(0.42, 1.04, 12, 0.04, trim, 1.04)
        finish(box((0.06, 1.7, 0.06), (0, 0, 1.1), (0, 0, 0)), trim, 0.01)  # 이마에서 뒤로 가는 능선
        if st == "plume":   # 투구 꼬리: 이마에서 뒤로 휘어 넘어가는 말총 갈기. 얇은 가닥 열여섯 장이 겹쳐 서고, 가운데가 가장 높고 끝은 처진다
            pl = hmat("plume", c2, 0.9, 0.0, 0.14)
            for i in range(16):
                t = i / 15.0
                y = 0.78 - 1.75 * t                                   # 앞(+Y)에서 뒤로
                h = (0.28 + 0.5 * math.sin(math.pi * min(1.0, t * 0.92 + 0.04)) ** 0.8) * (0.9 + 0.2 * hash01(i, 11))
                zb = 1.08 * math.sqrt(max(0.0, 1.0 - (y / 1.1) ** 2)) * 1.0 + 0.06   # 지붕 높이
                tilt = -(10 + 38 * t) + 6 * (hash01(i, 12) - 0.5)                    # 뒤로 갈수록 눕는다
                o = box((0.06, 0.13, h), (0.015 * (hash01(i, 13) - 0.5), y, zb + h * 0.38), (tilt * -0.0 + 0, 0, 0))
                o.rotation_euler[0] = math.radians(-tilt * 0.5)
                bpy.ops.object.transform_apply(rotation=True)
                finish(o, pl, 0.012, wear=0.01)
        if st == "horn":
            for k in (-1.0, 1.0):   # 뿔: 옆으로 나갔다가 위로 굽는 여덟 토막(끝으로 갈수록 가늘다, 소 뿔처럼 가늘고 길게)
                px, pz, ang = k * 1.02, 0.45, 0.0
                for i in range(8):
                    seg = 0.27
                    ang += 0.17 + 0.045 * i                     # 점점 위로 굽는다(0이 옆, 90도가 위)
                    dx, dz = math.cos(ang) * seg, math.sin(ang) * seg
                    r0, r1 = 0.15 - 0.017 * i, 0.15 - 0.017 * (i + 1)
                    finish(cylinder(r0, max(r1, 0.02), seg * 1.08, (px + k * dx / 2, 0, pz + dz / 2), (0, k * (90 - math.degrees(ang)), 0), 20), trim, 0.006, wear=0.006)
                    px, pz = px + k * dx, pz + dz
    elif st in ("circlet", "spikes"):
        finish(band(0.98, 1.1, 0.18, 0.34, 1.04), iron, 0.012, wear=0.006)
        if st == "circlet":
            finish(box((0.15, 0.08, 0.15), (0, 1.07, 0.38), (0, 45, 0)), glow, 0.01)
            for a in (-0.7, 0.7):
                finish(sphere(0.07, (math.sin(a) * 1.07, math.cos(a) * 1.07, 0.38), seg=12, rings=8), trim)
        else:
            for i in range(9):   # 부러진 뼈 조각: 높이·기울기·굵기를 고르지 않게
                a = math.tau * i / 9 + 0.2 + 0.18 * hash01(i, 5)
                h = 0.34 + 0.5 * hash01(i, 6)
                lean = 8 + 14 * hash01(i, 7)
                finish(cylinder(0.0, 0.07 + 0.05 * hash01(i, 8), h, (math.sin(a) * 1.04, math.cos(a) * 1.04 * 1.04, 0.5 + h / 2), (-math.cos(a) * -lean, math.sin(a) * lean, 0), 10), iron, 0.0, wear=0.02)
    elif st == "visor":
        finish(box((2.0, 0.3, 0.34), (0, 0.82, 0.05)), dark, 0.02)
        finish(box((1.8, 0.05, 0.1), (0, 0.98, 0.05)), glow)
        for k in (-1.0, 1.0):
            finish(box((0.08, 1.7, 0.16), (k * 1.0, 0, 0.05)), dark, 0.015)
        finish(band(0.98, 1.04, 0.04, 0.2, 1.0), dark, 0.0)
    elif st == "runeband":
        finish(band(0.96, 1.08, 0.2, 0.36, 1.02), cloth, 0.005)
        finish(box((0.26, 0.06, 0.26), (0, 1.1, 0.36), (0, 45, 0)), glow)
        finish(box((0.46, 0.04, 0.2), (0.0, -1.04, 0.36)), cloth, 0.01)


# ================================================================== 망토
# 진짜 천 시뮬레이션: 평평하고 넓은 천을 어깨 호(목 뒤로 모이는 선)에 핀으로 걸고, 영주 몸을 닮은 충돌체 위로 늘어뜨려
# 주름을 굳힌 뒤(적용) 두께를 주고 뼈 네 마디(어깨 고정, 아래로 갈수록 흔들림)로 묶어 내보낸다.
# 영주 몸 단면 표: scripts/debug/dump_body_profile.gd(anim)가 서 있는 자세(싸움 서기)의 여덟 순간을 겹쳐 찍은 값.
# 망토 받침 좌표(Godot): 원점 = 등 뼈에 다는 자리, 몸이 도는 쪽만 따른다. 위 +Y, 등 쪽 +Z. 싸움 서기는 상체를 숙여 엉덩이·종아리가 받침보다 뒤로(+Z) 나온다.
CAPE_H = float(os.environ.get("COS_H", "1.04"))
TOP_W, BOT_W = float(os.environ.get("COS_TOPW", "1.0")), float(os.environ.get("COS_BOTW", "1.25"))   # 천의 윗폭·아랫폭(어깨 호보다 넓어 목 뒤에서 모여 주름이 진다)
FAST = bool(os.environ.get("COS_FAST"))
NX, NY = (28, 36) if FAST else (48, 64)
TEX_W, TEX_H = 256, 320
# (높이, 반폭, 등 쪽 z, 앞쪽 z)
BODY = [
    (0.30, 0.07, -0.10, -0.24), (0.20, 0.09, -0.08, -0.27), (0.12, 0.12, -0.065, -0.30), (0.05, 0.22, -0.03, -0.31),
    (0.0, 0.29, -0.01, -0.30), (-0.06, 0.30, 0.04, -0.30), (-0.15, 0.28, 0.045, -0.33), (-0.25, 0.20, 0.045, -0.36),
    (-0.35, 0.18, 0.055, -0.40), (-0.45, 0.20, 0.085, -0.42), (-0.55, 0.23, 0.125, -0.35), (-0.70, 0.24, 0.14, -0.28),
    (-0.85, 0.21, 0.13, -0.30), (-1.00, 0.19, 0.12, -0.30), (-1.20, 0.18, 0.10, -0.30), (-1.60, 0.18, 0.10, -0.30),
]
GAP = 0.014   # 천이 몸에서 뜨는 거리


def body_at(gy):
    if gy >= BODY[0][0]:
        return BODY[0][1:]
    for a, b in zip(BODY, BODY[1:]):
        if gy <= a[0] and gy >= b[0]:
            t = (a[0] - gy) / (a[0] - b[0])
            return tuple(a[k] + (b[k] - a[k]) * t for k in (1, 2, 3))
    return BODY[-1][1:]


def push_out(p, extra=GAP):
    """Blender 좌표 점이 몸 단면 안이면 겉으로 민다."""
    gx, gz, gy = p[0], -p[1], p[2]
    hw, zb, zf = body_at(gy)
    cz, a, b = (zb + zf) / 2, hw + extra, (zb - zf) / 2 + extra
    d = (gx / a) ** 2 + ((gz - cz) / b) ** 2
    if d < 1.0:
        if d < 1e-6:
            return (p[0], -(cz + b), p[2])
        k = 1.0 / math.sqrt(d)
        return (gx * k, -(cz + (gz - cz) * k), gy)
    return p


def body_collider():
    me = bpy.data.meshes.new("body")
    vs, fs = [], []
    seg = 24
    rows = [(BODY[0][0] + 0.12, BODY[0][1], BODY[0][2], BODY[0][3])] + list(BODY)
    for gy, hw, zb, zf in rows:
        cz, b = (zb + zf) / 2, (zb - zf) / 2
        for k in range(seg):
            t = math.tau * k / seg
            vs.append((math.cos(t) * hw, -(cz + math.sin(t) * b), gy))
    n = len(rows)
    for r in range(n - 1):
        for k in range(seg):
            a, b2 = r * seg + k, r * seg + (k + 1) % seg
            fs.append((a, b2, b2 + seg, a + seg))
    vs.append((0, -(BODY[0][2] + BODY[0][3]) / 2, rows[0][0]))
    vs.append((0, -(BODY[-1][2] + BODY[-1][3]) / 2, rows[-1][0]))
    for k in range(seg):
        fs.append((len(vs) - 2, (k + 1) % seg, k))
        o = (n - 1) * seg
        fs.append((len(vs) - 1, o + k, o + (k + 1) % seg))
    me.from_pydata(vs, [], fs)
    me.update()
    o = bpy.data.objects.new("Body", me)
    bpy.context.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    o.modifiers.new("collision", "COLLISION")
    c = o.collision
    c.thickness_outer = 0.012
    c.thickness_inner = 0.02
    c.cloth_friction = 6.0
    c.damping = 0.4
    return o


def despike(me, limit=0.05, passes=3):
    """시뮬이 이따금 한 꼭짓점을 몸 속으로 끼워 뾰족한 가시를 남긴다: 이웃 평균에서 멀리 떨어진 꼭짓점을 이웃 평균으로 돌린다."""
    for _ in range(passes):
        nb = [[] for _ in me.vertices]
        for e in me.edges:
            a, b = e.vertices
            nb[a].append(b)
            nb[b].append(a)
        for i, v in enumerate(me.vertices):
            if len(nb[i]) < 2:
                continue
            avg = sum((me.vertices[j].co for j in nb[i]), Vector()) / len(nb[i])
            if (v.co - avg).length > limit:
                v.co = avg


def pin_point(s, jit):
    """어깨 호: s -1..1(왼쪽 → 오른쪽). 목 뒤가 가장 높고 안쪽, 어깨 끝은 낮고 앞으로 넘어간다."""
    x = 0.255 * s + jit * 0.01 * math.sin(s * 3.0)
    gz = -0.05 - 0.062 * s * s
    gy = 0.072 - 0.055 * abs(s) ** 1.7
    return push_out((x, -gz, gy), 0.016)


def hash01(*a):
    h = 0
    for v in a:
        h = (h * 1000003 + int(v * 7919) + 1315423911) & 0xFFFFFFFF
    h ^= h >> 13
    h = (h * 0x5BD1E995) & 0xFFFFFFFF
    h ^= h >> 15
    return (h & 0xFFFF) / 65535.0


def cape_edge(i, st, seed):
    """찢어진 아랫단의 높이 비율(열 i마다). 1이면 곧은 끝. 격자를 이 비율로 눌러 가장자리 선이 들쭉날쭉해도 계단이 안 생긴다."""
    if st == "ragged":
        u = i / NX
        e = 0.9 + 0.045 * math.sin(u * 14 + seed) + 0.03 * math.sin(u * 37 + seed * 2) - 0.1 * hash01(i, seed) ** 2 - 0.035 * ((u * 5 + seed * 0.1) % 1.0)
        return max(0.72, min(0.97, e))
    return 1.0


def make_cape_texture(row, seed):
    """천 질감: 짜임·얼룩·때·무늬를 한 장에(UV가 천을 따라 휘니 줄무늬·체크·문장이 천과 함께 휜다). (색, 빛)."""
    import numpy as np
    base, acc, st = np.array(row["c1"]), np.array(row["c2"]), row["style"]
    rng = np.random.default_rng(seed)
    ys, xs = np.mgrid[0:TEX_H, 0:TEX_W]
    u = (xs + 0.5) / TEX_W
    v = (ys + 0.5) / TEX_H            # 0 위(어깨) → 1 아래(끝단)
    Xm = (u - 0.5) * (TOP_W + (BOT_W - TOP_W) * v)
    Ym = v * CAPE_H
    px = TEX_W / 1.0

    def sm(e0, e1, x):
        t = np.clip((x - e0) / (e1 - e0), 0, 1)
        return t * t * (3 - 2 * t)

    col = np.ones((TEX_H, TEX_W, 3)) * base
    glow = np.zeros((TEX_H, TEX_W))
    edge_w = 1.5 / px * 4
    if st == "trim":
        m = np.maximum(sm(0.94 - 0.004, 0.94 + 0.004, v), np.maximum(sm(0.035, 0.03, u), sm(0.965, 0.97, u)))
        col = col * (1 - m[..., None]) + (acc * 0.82) * m[..., None]
        sl = np.exp(-(((v - 0.915) / 0.004) ** 2)) + np.exp(-(((u - 0.058) / 0.004) ** 2)) + np.exp(-(((u - 0.942) / 0.004) ** 2))
        col = col * (1 - 0.35 * sl[..., None]) + acc * 0.35 * sl[..., None] * 0.6   # 꿰맨 선
    elif st == "stripe":
        f = (u * 5.0 + 0.1 * np.sin(v * 3)) % 1.0
        m = sm(0.0, 0.015, f) * (1 - sm(0.27, 0.285, f))
        col = col * (1 - m[..., None]) + (acc * 1.0) * m[..., None]
        m2 = sm(0.0, 0.01, f) * (1 - sm(0.045, 0.06, f))
        col = col * (1 - 0.25 * m2[..., None])
    elif st == "check":
        a = ((u * 6.0) % 1.0)
        b = ((v * 7.5) % 1.0)
        ca = sm(0.45, 0.5, a) * (1 - sm(0.97, 1.0, a)) + sm(0.0, 0.03, 1 - a) * 0
        cb = sm(0.45, 0.5, b) * (1 - sm(0.97, 1.0, b))
        m = np.abs(ca - cb)                      # 어긋 체크
        line = np.maximum(np.exp(-(((a - 0.25) / 0.05) ** 2)), np.exp(-(((b - 0.25) / 0.05) ** 2))) * 0.25
        col = col * (1 - m[..., None]) + acc * 1.15 * m[..., None]
        col = col * (1 - 0.2 * line[..., None])
    elif st == "emblem":
        edge = np.maximum(sm(0.945, 0.95, v), np.maximum(sm(0.03, 0.025, u), sm(0.97, 0.975, u)))
        col = col * (1 - edge[..., None]) + acc * 0.7 * edge[..., None]
        # 위로 선 검: 칼날(뾰족), 날밑, 손잡이, 마개
        bw = np.clip((Ym - 0.2) / 0.38, 0, 1)
        blade = ((Ym > 0.2) & (Ym < 0.58)) * (np.abs(Xm) < (0.003 + 0.024 * np.clip(bw * 1.3, 0, 1)) * (Ym > 0.2))
        tip = ((Ym > 0.2) & (Ym < 0.3)) * (np.abs(Xm) < 0.027 * (Ym - 0.2) / 0.1)
        blade = ((Ym >= 0.3) & (Ym < 0.58) & (np.abs(Xm) < 0.027)) | tip
        guard = (Ym >= 0.58) & (Ym < 0.615) & (np.abs(Xm) < 0.11 - 0.02 * np.abs(Ym - 0.597) / 0.017)
        grip = (Ym >= 0.615) & (Ym < 0.74) & (np.abs(Xm) < 0.011)
        pom = ((Xm) ** 2 + (Ym - 0.755) ** 2) < 0.02 ** 2
        ring = np.abs(np.sqrt(Xm ** 2 + (Ym - 0.46) ** 2) - 0.28) < 0.006
        sw = (blade | guard | grip | pom).astype(float)
        thread = 0.85 + 0.15 * ((ys % 2) == 0)
        col = col * (1 - sw[..., None]) + (acc * 0.88 * thread[..., None]) * sw[..., None]
        col = col * (1 - 0.6 * (ring & (v < 0.9))[..., None]) + (acc * 0.55) * (0.6 * (ring & (v < 0.9)))[..., None]
        mid = (np.abs(Xm) < 0.004) & (Ym > 0.32) & (Ym < 0.58)
        col = col * (1 - 0.35 * mid[..., None])
    elif st == "rune":
        cw = 32
        cx, cy = xs // cw, ys // cw
        lx, ly = (xs % cw - cw / 2 + 0.5) * 16 / cw, (ys % cw - cw / 2 + 0.5) * 16 / cw
        k = (cx * 7 + cy * 3) % 4
        g0 = ((np.abs(lx) <= 1.3) & (np.abs(ly) <= 5.5)) | ((np.abs(ly) <= 1.3) & (np.abs(lx) <= 3.5))
        g1 = ((np.abs(lx + ly) <= 1.5) & (np.abs(ly) <= 5.5)) | ((np.abs(lx) <= 1.3) & (ly > 1) & (ly <= 5.5))
        g2 = np.abs(np.abs(lx) + np.abs(ly) - 5.2) <= 1.3
        g3 = ((np.abs(ly) <= 1.3) & (np.abs(lx) <= 5.5)) | ((np.abs(lx) <= 1.3) & (ly >= -5.5) & (ly <= 0))
        g = np.where(k == 0, g0, np.where(k == 1, g1, np.where(k == 2, g2, g3)))
        ok = (cy % 2 == 1) & (cy >= 1) & (cy <= 6) & (cx >= 1) & (cx <= 6) & (v < 0.9)
        # 가장자리는 룬이 번지지 않게 누그러뜨린다
        g = (g & ok).astype(float)
        glow = g * (0.85 + 0.15 * rng.random(g.shape))
        col = col * (1 - 0.55 * g[..., None]) + acc * 0.45 * g[..., None]
        hem = sm(0.93, 0.935, v)
        col = col * (1 - hem[..., None]) + acc * 0.35 * hem[..., None]
    if st == "ragged":
        hem = sm(edge_w * 0, 1, v) * 0
    # --- 천의 결: 능직(사선) 짜임 + 올 불균일 + 얼룩 + 아랫단 때
    twill = 0.93 + 0.07 * (((xs + ys) // 2) % 2)
    yarn = 0.97 + 0.03 * np.sin(xs * 2.2) * np.sin(ys * 0.35)
    noise = rng.random((TEX_H, TEX_W))
    lowf = np.zeros((TEX_H, TEX_W))
    for _ in range(5):
        fx, fy, ph = rng.uniform(2, 9), rng.uniform(2, 9), rng.uniform(0, 6)
        lowf += np.sin(u * fx * 3 + v * fy * 2 + ph) * np.sin(v * fy * 3 - u * fx + ph * 2)
    lowf = lowf / 5
    grime = 1 - 0.30 * v ** 2.4 - 0.05 * np.clip(lowf, 0, 1)
    col = col * (twill * yarn * (0.96 + 0.08 * noise) * (1 + 0.12 * lowf) * grime)[..., None]
    if st == "ragged":
        col = col * (1 - 0.15 * sm(0.78, 0.9, v))[..., None]
    col = np.clip(col, 0, 1)
    return col, glow


def np_image(name, arr, srgb=True):
    import numpy as np
    h, w = arr.shape[0], arr.shape[1]
    img = bpy.data.images.new(name, w, h, alpha=False)
    rgba = np.ones((h, w, 4))
    rgba[..., :3] = arr[..., :3] if arr.ndim == 3 else arr[..., None]
    img.colorspace_settings.name = "sRGB" if srgb else "Non-Color"   # 픽셀을 넣기 전에(나중에 바꾸면 버퍼가 비워진다)
    img.file_format = "PNG"
    img.pixels.foreach_set(np.ascontiguousarray(rgba[::-1].astype(np.float32)).ravel())   # Blender는 아래 줄부터
    if os.environ.get("COS_PREVIEW"):
        img.filepath_raw = os.path.join(os.environ["COS_PREVIEW"], name + ".png")
        os.makedirs(os.environ["COS_PREVIEW"], exist_ok=True)
        img.save()
    img.pack()
    return img


def cloth_material(name, row, seed):
    import numpy as np
    col, glow = make_cape_texture(row, seed)
    img = np_image(name + "_col", col)
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.93
    try:
        b.inputs["Sheen Weight"].default_value = 0.35
        b.inputs["Sheen Roughness"].default_value = 0.5
    except KeyError:
        pass
    tx = nt.nodes.new("ShaderNodeTexImage")
    tx.image = img
    tx.interpolation = "Linear"
    nt.links.new(tx.outputs["Color"], b.inputs["Base Color"])
    if row["style"] == "rune":
        gi = np_image(name + "_glow", glow * np.array(row["c2"]) [None, None, :] if False else (glow[..., None] * np.array(row["c2"])[None, None, :]))
        g = nt.nodes.new("ShaderNodeTexImage")
        g.image = gi
        nt.links.new(g.outputs["Color"], b.inputs["Emission Color"])
        b.inputs["Emission Strength"].default_value = 0.8
    return m


def pick_weights(st):
    # (질량, 굽힘 단단함): 얇은 천은 잔주름, 두꺼운 모직은 굵은 주름
    return {"ragged": (0.10, 1.2), "rune": (0.2, 2.4), "stripe": (0.2, 2.5), "trim": (0.25, 3.5), "emblem": (0.3, 4.0), "check": (0.22, 2.5), "plain": (0.2, 2.5)}.get(st, (0.2, 2.5))


def build_cape(row):
    base, acc, st = row["c1"], row["c2"], row["style"]
    seed = int(sum(ord(c) * (i + 3) for i, c in enumerate(row["id"])) % 997)
    rs = lambda k: hash01(seed, k)
    # ---- 천 격자(평평하고 몸 뒤 12cm 떨어진 곳에서 시작: 겹침 없이)
    vs, uvs = [], []
    for j in range(NY + 1):
        v = j / NY
        w = TOP_W + (BOT_W - TOP_W) * v
        for i in range(NX + 1):
            u = i / NX
            vs.append(((u - 0.5) * w, -0.17, -v * cape_edge(i, st, seed) * CAPE_H + 0.06))
            uvs.append((u, 1.0 - v))
    faces, drop = [], 0
    holes = [(int(rs(10 + k) * (NX - 8)) + 4, 0.18 + 0.4 * rs(20 + k)) for k in range(6)] if st == "ragged" else []   # 찢긴 틈(열, 위쪽에서 어디까지)
    for j in range(NY):
        for i in range(NX):
            v = (j + 0.5) / NY
            if any(i == hc and v > 1.0 - hh for hc, hh in holes):
                continue
            faces.append((j * (NX + 1) + i, j * (NX + 1) + i + 1, (j + 1) * (NX + 1) + i + 1, (j + 1) * (NX + 1) + i))
    me = bpy.data.meshes.new("cape")
    me.from_pydata(vs, [], faces)
    me.update()
    uvl = me.uv_layers.new(name="UV")
    for f in me.polygons:
        for li, vi in zip(f.loop_indices, f.vertices):
            uvl.data[li].uv = uvs[vi]
    # 안 쓰는 꼭짓점은 지운다
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("Cape", me)
    bpy.context.collection.objects.link(obj)
    me.materials.append(cloth_material("cloth", row, seed))
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    # ---- 핀: 맨 윗줄, 어깨 호로 모은다(모양 키)
    vg = obj.vertex_groups.new(name="pin")
    top = [v for v in me.vertices if abs(v.co.z - 0.06) < 1e-6]
    umin, umax = min(v.co.x for v in top), max(v.co.x for v in top)
    for v in top:
        vg.add([v.index], 1.0, "REPLACE")
    obj.shape_key_add(name="Basis")
    sk = obj.shape_key_add(name="hang")
    for v in top:
        s = (2 * (v.co.x - umin) / (umax - umin) - 1)
        s = math.copysign(abs(s) ** float(os.environ.get("COS_PEXP", "1.1")), s)
        sk.data[v.index].co = pin_point(s, rs(1) - 0.5)
    # 둘째 줄은 윗줄을 따라 올라와 목깃처럼 모이게 한다(조금만)
    sk.value = 0.0
    sk.keyframe_insert("value", frame=1)
    sk.value = 1.0
    sk.keyframe_insert("value", frame=24)
    for fc in obj.data.shape_keys.animation_data.action.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"
    # ---- 충돌체와 바람(끝단이 한쪽으로 쏠리는 첫 흔들림: 비대칭 주름)
    body = body_collider()
    mass, bend = pick_weights(st)
    bend *= float(os.environ.get("COS_BEND", "1"))
    md = obj.modifiers.new("cloth", "CLOTH")
    s = md.settings
    s.quality = 12
    s.mass = mass
    s.tension_stiffness = 18
    s.compression_stiffness = float(os.environ.get("COS_COMP", "3"))
    s.shear_stiffness = 18
    s.bending_stiffness = bend
    s.tension_damping = 6
    s.compression_damping = 6
    s.shear_damping = 6
    s.bending_damping = 0.6
    s.air_damping = 1.6
    s.vertex_group_mass = "pin"
    s.pin_stiffness = 1.0
    md.collision_settings.use_collision = True
    md.collision_settings.distance_min = 0.016
    md.collision_settings.collision_quality = 6
    md.collision_settings.use_self_collision = False   # 켜면 몇 분씩 걸리고 구겨진다. 굽힘 단단함으로 겹침을 막는다
    md.collision_settings.self_distance_min = 0.008
    md.collision_settings.self_friction = 5
    md.point_cache.frame_start = 1
    md.point_cache.frame_end = 150
    bpy.ops.object.effector_add(type="WIND", location=(0.7 * math.cos(rs(2) * 6.28), 0.7 * math.sin(rs(2) * 6.28), -0.6), rotation=(0, 0, 0))
    wind = bpy.context.object
    wind.field.strength = 0.0
    wind.field.flow = 0.0
    tgt = Vector((0, 0.0, -0.6)) - wind.location
    wind.rotation_euler = tgt.to_track_quat("-Z", "Y").to_euler()
    wind.field.strength = 0.0
    wind.field.keyframe_insert("strength", frame=16)
    wind.field.strength = (30.0 + 25 * rs(3)) * (0.5 if st == "ragged" else 1.0) * float(os.environ.get("COS_WIND", "1"))
    wind.field.keyframe_insert("strength", frame=30)
    wind.field.strength = 0.0
    wind.field.keyframe_insert("strength", frame=64)
    sc = bpy.context.scene
    sc.frame_start, sc.frame_end = 1, 150
    for f in range(1, 151):
        sc.frame_set(f)
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    nm = bpy.data.meshes.new_from_object(ev)
    # ---- 새 메쉬로 갈아 끼운다: 사이 시뮬을 벗기고, 겉으로 밀어 뚫림을 없애고, 부드럽게
    bpy.data.objects.remove(wind, do_unlink=True)
    bpy.data.objects.remove(body, do_unlink=True)
    obj.modifiers.clear()
    obj.shape_key_clear() if hasattr(obj, "shape_key_clear") else None
    old = obj.data
    nm.materials.clear()
    nm.materials.append(old.materials[0])
    nobj = bpy.data.objects.new("Cape", nm)
    bpy.context.collection.objects.link(nobj)
    bpy.data.objects.remove(obj, do_unlink=True)
    bpy.context.view_layer.objects.active = nobj
    obj = nobj
    me = nm
    if os.environ.get("COS_DEBUG"):
        far = [(i, tuple(round(c, 3) for c in v.co)) for i, v in enumerate(me.vertices) if abs(v.co.x) > 0.75 or v.co.z > 0.2 or v.co.y > 0.5 or v.co.y < -0.6]
        print("FAR", far[:10], len(far))
    dbg = lambda tag: print("DBG", tag, max(((abs(v.co.x) + abs(v.co.y) + abs(v.co.z), v.index, tuple(round(c, 2) for c in v.co)) for v in me.vertices)))
    if os.environ.get("COS_DEBUG"):
        dbg("sim")
    despike(me)
    if os.environ.get("COS_DEBUG"):
        dbg("despike")
    for v in me.vertices:
        p = push_out(tuple(v.co), GAP)
        v.co = p
    # 가볍게 매끄럽게(주름은 남기고 격자 들쭉날쭉만 편다)
    sm_md = obj.modifiers.new("smooth", "SMOOTH")
    sm_md.factor = 0.5
    sm_md.iterations = 2
    if os.environ.get("COS_DEBUG"):
        dbg("pushed")
    bpy.ops.object.modifier_apply(modifier="smooth")
    if os.environ.get("COS_DEBUG"):
        dbg("smoothed")
    for v in me.vertices:
        v.co = push_out(tuple(v.co), GAP * 0.8)
    # 두께
    so = obj.modifiers.new("solid", "SOLIDIFY")
    so.thickness = 0.007 if st != "ragged" else 0.004
    so.offset = 1.0
    so.use_even_offset = False   # 켜면 뾰족한 주름 끝에서 가시가 솟는다
    bpy.ops.object.modifier_apply(modifier="solid")
    obj.data.polygons.foreach_set("use_smooth", [True] * len(obj.data.polygons))
    # 어깨 줄(걸쇠): 목깃을 도는 가는 끈과 단추 둘, 모두 맨 윗 뼈
    clasp_c = acc if st in ("trim", "emblem") else (0.16, 0.14, 0.12)
    clasp = mat("clasp", clasp_c, 0.5, 0.8)
    cord = mat("cord", tuple(x * 0.5 for x in base), 0.9)
    pts = [pin_point(-1 + 2 * k / 20.0, rs(1) - 0.5) for k in range(21)]
    pts = [(p[0], p[1] + 0.012, p[2] + 0.004) for p in pts]
    cu = bpy.data.curves.new("cord", "CURVE")
    cu.dimensions = "3D"
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for p, q in zip(sp.points, pts):
        p.co = (q[0], q[1], q[2], 1.0)
    cu.bevel_depth = 0.008
    cu.bevel_resolution = 3
    co = bpy.data.objects.new("Cord", cu)
    bpy.context.collection.objects.link(co)
    bpy.context.view_layer.objects.active = co
    co.select_set(True)
    bpy.ops.object.convert(target="MESH")
    co = bpy.context.object
    co.data.materials.append(cord)
    for k in (-1.0, 1.0):
        q = pin_point(k * 0.98, 0.0)
        sb = sphere(0.022, (q[0], q[1] + 0.016, q[2] + 0.006), (1, 0.6, 1), 16, 10)
        finish(sb, clasp)
        sb.select_set(True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in [obj, co] + [o for o in bpy.data.objects if o.name.startswith("Sphere")]:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = "Cape"
    for l in list(obj.data.uv_layers):
        if l.name != "UV":
            obj.data.uv_layers.remove(l)
    obj.data.polygons.foreach_set("use_smooth", [True] * len(obj.data.polygons))
    if os.environ.get("COS_DEBUG"):
        print("JOINED", [(v.index, tuple(round(c, 2) for c in v.co), [g.group for g in v.groups]) for v in obj.data.vertices if abs(v.co.x) > 0.7 or v.co.z > 0.2][:8])
    add_cape_armature(obj)


def add_cape_armature(obj):
    """뼈 네 마디(CapeA~C, 맨 위는 고정 뿌리): 아래로 갈수록 뒤로 흔들린다. 높이로 가중치."""
    arm = bpy.data.armatures.new("CapeRig")
    ao = bpy.data.objects.new("CapeRig", arm)
    bpy.context.collection.objects.link(ao)
    bpy.context.view_layer.objects.active = ao
    bpy.ops.object.mode_set(mode="EDIT")
    ys = [0.0, -0.30, -0.62, -0.96]
    prev = None
    for k in range(3):
        b = arm.edit_bones.new("CapeBone%d" % k)
        b.head = (0, -0.05, ys[k])
        b.tail = (0, -0.05, ys[k + 1])
        if prev:
            b.parent = prev
            b.use_connect = True
        prev = b
    bpy.ops.object.mode_set(mode="OBJECT")
    for k in range(3):
        obj.vertex_groups.new(name="CapeBone%d" % k)
    for v in obj.data.vertices:
        s = max(0.0, min(3.0, -v.co.z / 0.32))
        w = [max(0.0, 1.0 - abs(s - (k + 0.5))) for k in range(3)]
        tot = sum(w) or 1.0
        for k in range(3):
            if w[k] > 0.001:
                obj.vertex_groups["CapeBone%d" % k].add([v.index], w[k] / tot, "REPLACE")
    obj.parent = ao
    md = obj.modifiers.new("arm", "ARMATURE")
    md.object = ao


# ================================================================== 내보내기
def preview(row):
    """작업 확인용: 몸 단면 위에 얹은 모습을 뒤·옆에서 Workbench로 찍는다(COS_PREVIEW=폴더)."""
    out = os.environ["COS_PREVIEW"]
    os.makedirs(out, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x, sc.render.resolution_y = 640, 800
    bd = body_collider()
    bd.modifiers.clear()
    bd.data.materials.append(mat("bodygrey", (0.45, 0.4, 0.35), 0.8))
    bpy.ops.object.empty_add(location=(0, 0, -0.45))
    tgt = bpy.context.object
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    bpy.context.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2.2
    c = cam.constraints.new("TRACK_TO")
    c.target = tgt
    c.track_axis = "TRACK_NEGATIVE_Z"
    c.up_axis = "UP_Y"
    sc.camera = cam
    for name, loc in (("back", (0.0, -4.0, -0.45)), ("side", (4.0, -0.5, -0.45)), ("back34", (2.5, -3.0, -0.2))):
        cam.location = loc
        sc.render.filepath = os.path.join(out, "%s_%s.png" % (row["id"], name))
        bpy.ops.render.render(write_still=True)


def export(row):
    clear()
    if row["slot"] == "cape":
        build_cape(row)
    else:
        build_head(row)
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    if not objs:
        return None
    if os.environ.get("COS_PREVIEW"):
        preview(row)
    path = os.path.join(OUT, row["id"] + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, export_yup=True, export_materials="EXPORT", export_vertex_color="MATERIAL", export_cameras=False, export_lights=False)
    return path


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    rows = [r for r in read_rows() if r["slot"] in ("cape", "head") and r["style"] != "none"]
    if argv:
        rows = [r for r in rows if r["id"] in argv]
    for r in rows:
        try:
            p = export(r)
            print("OK", r["id"], os.path.getsize(p) if p else 0)
            for f in os.listdir(OUT):   # 내보내기가 곁에 흘린 질감 파일은 glb 안에 들어 있으니 지운다
                if f.endswith(".png"):
                    os.remove(os.path.join(OUT, f))
        except Exception as e:
            import traceback
            traceback.print_exc()
            print("FAIL", r["id"], e)


main()
