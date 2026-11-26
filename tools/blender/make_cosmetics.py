# 「검의 언덕」 영주 꾸미기(망토·머리) 모양을 Blender로 짓고 .glb로 내보낸다. (2026-11-27, docs/cosmetics.md)
#
#   blender -b -P tools/blender/make_cosmetics.py            # 표의 망토·머리 전부
#   blender -b -P tools/blender/make_cosmetics.py -- cape_night head_helm   # 몇 개만
# 결과: assets/cosmetics/<항목 id>.glb. 색은 scripts/debug/build_cosmetics.gd의 표에서 그대로 읽는다(한 곳).
# 손으로 모델링한 것이 아니라 스크립트로 짓는다(AI 생성 에셋이 아니다). 어두운 사실풍: 닳은 쇠, 낡은 천.
#
# 약속(게임 CosmeticArt와 같은 크기·방향):
#   - 망토: 어깨 가운데가 원점, 아래(Blender -Z = Godot -Y)로 늘어진다, 폭 0.62(아래로 갈수록 1.5배), 높이 1.0, 등은 Godot +Z(= Blender -Y).
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
    iron = mat("iron", c1, 0.5, 0.75)
    trim = mat("trim", c2, 0.55, 0.45)
    cloth = mat("cloth", c1, 0.95)
    cloth2 = mat("cloth2", c2, 0.95)
    glow = mat("glow", c2, 0.4, 0.0, 3.0)
    dark = mat("dark", tuple(x * 0.35 for x in c1), 0.7, 0.6)

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
        finish(band(0.9, 1.18, 0.5, -0.95, 1.0), cloth, 0.0, wear=0.02)   # 어깨로 내려오는 깃
        finish(band(0.97, 1.02, 0.07, 0.3, 1.0), cloth2, 0.0)             # 얼굴 둘레 가는 줄
    elif st == "kettle":
        cap(1.08, 0.28)
        finish(cylinder(1.95, 1.95, 0.07, (0, 0, 0.3), (0, 0, 0), 64, (1.0, 1.05, 1.0)), iron, 0.012, wear=0.01)
        finish(band(1.0, 1.1, 0.1, 0.3, 1.05), trim, 0.01)
        rivets(0.5, 1.02, 10, 0.045, trim, 1.03)
    elif st in ("helm", "plume", "horn"):
        cap(1.1, 0.1)
        finish(band(1.0, 1.14, 0.12, 0.1, 1.04), trim, 0.01)               # 아래 테
        finish(box((0.2, 0.08, 0.95), (0, 1.06, -0.28)), iron, 0.01)        # 코가리개
        for k in (-1.0, 1.0):
            finish(box((0.08, 0.62, 0.7), (k * 1.04, 0.18, -0.22), (0, 0, k * -6)), iron, 0.012)   # 볼가리개
        rivets(0.42, 1.04, 12, 0.04, trim, 1.04)
        finish(box((0.06, 1.7, 0.06), (0, 0, 1.1), (0, 0, 0)), trim, 0.01)  # 이마에서 뒤로 가는 능선
        if st == "plume":
            finish(box((0.1, 1.7, 0.5), (0, -0.1, 1.2), (8, 0, 0)), mat("plume", c2, 0.9), 0.02, wear=0.02)   # 투구 꼬리
        if st == "horn":
            for k in (-1.0, 1.0):   # 뿔: 옆으로 나갔다가 위로 굽는 일곱 토막(끝으로 갈수록 가늘다)
                px, pz, ang = k * 1.02, 0.45, 0.0
                for i in range(7):
                    seg = 0.34
                    ang += 0.2 + 0.05 * i                       # 점점 위로 굽는다(0이 옆, 90도가 위)
                    dx, dz = math.cos(ang) * seg, math.sin(ang) * seg
                    r0, r1 = 0.22 - 0.028 * i, 0.22 - 0.028 * (i + 1)
                    finish(cylinder(r0, max(r1, 0.02), seg * 1.08, (px + k * dx / 2, 0, pz + dz / 2), (0, k * (90 - math.degrees(ang)), 0), 20), trim, 0.006, wear=0.006)
                    px, pz = px + k * dx, pz + dz
    elif st in ("circlet", "spikes"):
        finish(band(0.98, 1.1, 0.18, 0.46, 1.04), iron, 0.012, wear=0.006)
        if st == "circlet":
            finish(box((0.2, 0.1, 0.2), (0, 1.07, 0.5), (0, 45, 0)), glow)
            for a in (-0.7, 0.7):
                finish(sphere(0.07, (math.sin(a) * 1.07, math.cos(a) * 1.07, 0.5), seg=12, rings=8), trim)
        else:
            for i in range(7):
                a = math.tau * i / 7 + 0.2
                h = 0.55 + 0.25 * (i % 3)
                finish(cylinder(0.0, 0.13, h, (math.sin(a) * 1.04, math.cos(a) * 1.04 * 1.04, 0.46 + h / 2), (-math.cos(a) * -10, math.sin(a) * 10, 0), 12), iron, 0.0, wear=0.01)
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
CAPE_W, CAPE_H = 0.62, 1.0
TEX_W, TEX_H = 96, 128


def rune_glyph(x, y):
    cw = 16
    cx, cy = x // cw, y // cw
    if cy % 2 != 0 or cy < 1 or cy > 6 or cx < 1 or cx > 4:
        return 0
    lx, ly = x % cw - 8, y % cw - 8
    k = (cx * 7 + cy * 3) % 4
    if k == 0:
        return 1 if (abs(lx) <= 1 and abs(ly) <= 5) or (abs(ly) <= 1 and abs(lx) <= 3) else 0
    if k == 1:
        return 1 if (abs(lx + ly) <= 1 and abs(ly) <= 5) or (abs(lx) <= 1 and 1 < ly <= 5) else 0
    if k == 2:
        return 1 if abs(abs(lx) + abs(ly) - 5) <= 1 else 0
    return 1 if (abs(ly) <= 1 and abs(lx) <= 5) or (abs(lx) <= 1 and -5 <= ly <= 0) else 0


def emblem(base, acc, u, v):
    dk = lambda c, f: tuple(x * (1 - f) for x in c)
    if v > 0.94 or u < 0.03 or u > 0.97:
        return dk(acc, 0.25)
    cx = abs(u - 0.5)
    if cx < 0.025 and 0.28 < v < 0.66:
        return acc
    if cx < 0.13 and 0.66 < v < 0.7:
        return acc
    if cx < 0.025 and 0.7 <= v < 0.8:
        return dk(acc, 0.2)
    if cx < 0.04 and 0.8 <= v < 0.84:
        return dk(acc, 0.2)
    return base


def build_cape(row):
    base, acc, st = row["c1"], row["c2"], row["style"]
    nx, ny = 64, 80
    vs = []
    for j in range(ny + 1):
        v = j / ny
        for i in range(nx + 1):
            u = i / nx
            fold = math.sin(u * math.tau * 2 + 0.6) * 0.035 * v
            fold += math.sin(u * math.tau * 5 + v * 3.1) * 0.009 * v + math.sin(u * math.tau * 9 - v * 5.0) * 0.003 * v   # 잔주름
            side = (2 * u - 1) ** 2
            wrap = -0.13 * side * (0.3 + 0.7 * v)
            g_z = fold + wrap     # Godot z(+는 등 쪽)
            vs.append(((u - 0.5) * CAPE_W * (1 + 0.5 * v), -g_z, -v * CAPE_H))
    faces, fcol, fmat = [], [], []
    for j in range(ny):
        for i in range(nx):
            u, v = (i + 0.5) / nx, (j + 0.5) / ny
            x, y = int(u * TEX_W), int(v * TEX_H)
            c = base
            glyph = 0
            if st == "ragged":
                edge = 0.9 + 0.07 * math.sin(u * 31) + 0.05 * math.sin(u * 13 + 1.3) - 0.04 * ((u * 9) % 1.0)
                if v > edge:
                    continue
                if v > edge - 0.07:
                    c = acc
            elif st == "trim":
                if v > 0.9 or u < 0.04 or u > 0.96:
                    c = acc
            elif st == "stripe":
                if (u * 5.0) % 1.0 < 0.28:
                    c = acc
            elif st == "check":
                if (int(u * 6.0) + int(v * 8.0)) % 2 == 0:
                    c = acc
            elif st == "emblem":
                c = emblem(base, acc, u, v)
            elif st == "rune":
                glyph = rune_glyph(x, y)
                if glyph:
                    c = tuple(b * 0.4 + a * 0.6 for b, a in zip(base, acc))
                if v > 0.93:
                    c = tuple(a * 0.5 for a in acc)
            shade = 1.0 + 0.1 * math.sin(u * math.tau * 2 + 0.6) - 0.16 * v
            grain = 0.97 + 0.03 * math.sin(y * 2.1 + x * 0.4)
            faces.append((j * (nx + 1) + i, j * (nx + 1) + i + 1, (j + 1) * (nx + 1) + i + 1, (j + 1) * (nx + 1) + i))
            fcol.append((c[0] * shade * grain, c[1] * shade * grain, c[2] * shade * grain, 1.0))
            fmat.append(1 if glyph else 0)
    me = bpy.data.meshes.new("cape")
    me.from_pydata(vs, [], faces)
    me.update()
    ca = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    k = 0
    for fi, f in enumerate(me.polygons):
        for li in f.loop_indices:
            ca.data[li].color = lin(fcol[fi][:3])
        f.material_index = fmat[fi]
    obj = bpy.data.objects.new("Cape", me)
    bpy.context.collection.objects.link(obj)
    me.materials.append(mat("cloth", base, 0.95, 0.0, 0.0, vcol=True))
    me.materials.append(mat("glow_runes", acc, 0.6, 0.0, 1.4))
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.shade_smooth()   # 얇은 천이라 양면(재질의 뒷면 컬링을 끈다)으로 내보낸다
    obj.select_set(False)
    # 어깨 줄(걸쇠): 위 가장자리를 따라 가는 천 띠와 두 개의 단추
    clasp = mat("clasp", acc if st in ("trim", "emblem") else (0.16, 0.14, 0.12), 0.45, 0.8)
    for k in (-1.0, 1.0):
        finish(sphere(0.03, (k * CAPE_W * 0.4, 0.035, -0.02), seg=14, rings=8), clasp)


# ================================================================== 내보내기
def export(row):
    clear()
    if row["slot"] == "cape":
        build_cape(row)
    else:
        build_head(row)
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    if not objs:
        return None
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
        except Exception as e:
            import traceback
            traceback.print_exc()
            print("FAIL", r["id"], e)


main()
