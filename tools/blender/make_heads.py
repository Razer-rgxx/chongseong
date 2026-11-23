# 「검의 언덕」 머리(Heads) 11개를 Blender로 짓고 .glb로 내보낸다. (2026-11-23, 고퀄 판)
#
# PC에서 한 번(chongseong 폴더에서, Blender 4.x):
#   "C:\Program Files\Blender Foundation\Blender 4.2\blender.exe" -b -P tools\blender\make_heads.py
# 결과: assets/heads/<모양>.glb (질감이 구워져 들어 있다). 몇 분 걸린다.
#
# 어떻게 고퀄을 내나:
#   1. 모양: 돌은 한 장씩 쌓고, 뼈는 눈구멍·광대·이빨을 따로 붙이고, 뿔·가지는 굽은 마디로, 모서리는 모두 깎는다(Bevel).
#      울퉁불퉁한 면은 잡음으로 민다(Displace). 눈 틈·십자·숨구멍은 파낸다(Boolean).
#   2. 재질: 절차 재질(잡음 얼룩, 틈의 때(AO), 닳아 반짝이는 모서리(Pointiness), 돌의 이끼, 놋쇠의 녹청, 나뭇결, 뼈의 잔금)을
#      Cycles로 색·거칠기·노멀 세 장에 굽고(512px), 그 세 장으로 단순한 재질을 만들어 내보낸다(glTF는 절차 재질을 못 싣는다).
#   3. 굽기가 실패하면 그 머리는 굽지 않은 채로라도 내보낸다(색만 남는다).
#
# 약속(게임 ObjectHead와):
#   - 바닥 가운데가 원점, 위로 0.35~0.6m, 얼굴은 Blender의 -Y(Godot에서 +Z).
#   - 재질 이름 앞머리: metal_*(게임이 바탕색: 쇠·놋쇠·뼈·녹을 곱한다, metal_steel은 그대로), glow_*(빛 색), 나머지는 바탕색을 곱한다.

import bpy
import math
import os
import random
import tempfile
import traceback
from mathutils import Vector

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "heads"))
BAKE_DIR = os.path.join(tempfile.gettempdir(), "geom_hill_heads_bake")
BAKE_SIZE = 512
os.makedirs(OUT, exist_ok=True)
os.makedirs(BAKE_DIR, exist_ok=True)
random.seed(7)


# ================================================================== 장면
def clear():
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.textures, bpy.data.images):
        for b in list(coll):
            coll.remove(b)


def obj():
    return bpy.context.active_object


def only(o):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o


def smooth(o):
    only(o)
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
    except Exception:
        bpy.ops.object.shade_smooth()
    return o


# ================================================================== 절차 재질
def _link(nt, src, dst):
    if isinstance(src, bpy.types.NodeSocket):
        nt.links.new(src, dst)
    else:
        dst.default_value = src


def _mix(nt, a, b, fac, blend="MIX"):
    """색 섞기(Blender 4: ShaderNodeMix, 옛판: MixRGB)."""
    try:
        n = nt.nodes.new("ShaderNodeMix")
        n.data_type = "RGBA"
        n.blend_type = blend
        ins = {s.identifier: s for s in n.inputs}
        _link(nt, fac, ins["Factor_Float"])
        _link(nt, a, ins["A_Color"])
        _link(nt, b, ins["B_Color"])
        return {s.identifier: s for s in n.outputs}["Result_Color"]
    except Exception:
        n = nt.nodes.new("ShaderNodeMixRGB")
        n.blend_type = blend
        _link(nt, fac, n.inputs[0])
        _link(nt, a, n.inputs[1])
        _link(nt, b, n.inputs[2])
        return n.outputs[0]


def _math(nt, op, a, b=0.0, clamp=True):
    n = nt.nodes.new("ShaderNodeMath")
    n.operation = op
    n.use_clamp = clamp
    _link(nt, a, n.inputs[0])
    _link(nt, b, n.inputs[1])
    return n.outputs[0]


def _ramp(nt, fac, lo, hi):
    """lo~hi 사이를 0→1로(그 밖은 끝값)."""
    n = nt.nodes.new("ShaderNodeMapRange")
    _link(nt, fac, n.inputs["Value"])
    n.inputs["From Min"].default_value = lo
    n.inputs["From Max"].default_value = hi
    n.inputs["To Min"].default_value = 0.0
    n.inputs["To Max"].default_value = 1.0
    n.clamp = True
    return n.outputs["Result"]


def _noise(nt, co, scale, detail=6.0, rough=0.55):
    n = nt.nodes.new("ShaderNodeTexNoise")
    nt.links.new(co, n.inputs["Vector"])
    n.inputs["Scale"].default_value = scale
    n.inputs["Detail"].default_value = detail
    n.inputs["Roughness"].default_value = rough
    return n.outputs["Fac"]


def _voronoi(nt, co, scale, feature="F1"):
    n = nt.nodes.new("ShaderNodeTexVoronoi")
    n.feature = feature
    nt.links.new(co, n.inputs["Vector"])
    n.inputs["Scale"].default_value = scale
    return n.outputs["Distance"]


def _wave(nt, co, scale, distort=6.0):
    n = nt.nodes.new("ShaderNodeTexWave")
    n.wave_type = "BANDS"
    try:
        n.bands_direction = "Z"
    except Exception:
        pass
    nt.links.new(co, n.inputs["Vector"])
    n.inputs["Scale"].default_value = scale
    n.inputs["Distortion"].default_value = distort
    n.inputs["Detail"].default_value = 4.0
    return n.outputs["Fac"]


def _reroute(nt, src, name):
    r = nt.nodes.new("NodeReroute")
    r.name = name
    nt.links.new(src, r.inputs[0])
    return r.outputs[0]


# 재질 표: 이름 → (종류, 바탕, 때, 모서리, 거칠기, 쇠)
LOOKS = {
    "metal_iron": ("metal", (0.2, 0.2, 0.21), (0.06, 0.055, 0.05), (0.62, 0.62, 0.64), 0.48, 1.0),
    "metal_brass": ("brass", (0.58, 0.42, 0.18), (0.16, 0.12, 0.06), (0.9, 0.74, 0.42), 0.36, 1.0),
    "metal_steel": ("steel", (0.6, 0.62, 0.66), (0.22, 0.22, 0.24), (0.92, 0.93, 0.95), 0.24, 1.0),
    "stone_grey": ("stone", (0.42, 0.4, 0.37), (0.13, 0.12, 0.11), (0.62, 0.6, 0.56), 0.9, 0.0),
    "stone_dark": ("stone", (0.12, 0.11, 0.1), (0.03, 0.03, 0.03), (0.3, 0.28, 0.26), 0.93, 0.0),
    "bone_old": ("bone", (0.8, 0.74, 0.62), (0.3, 0.23, 0.14), (0.93, 0.9, 0.8), 0.62, 0.0),
    "wood_old": ("wood", (0.33, 0.21, 0.12), (0.09, 0.05, 0.03), (0.48, 0.36, 0.24), 0.82, 0.0),
    "cloth_black": ("cloth", (0.07, 0.07, 0.08), (0.015, 0.015, 0.02), (0.14, 0.14, 0.15), 0.95, 0.0),
    "wax_old": ("bone", (0.86, 0.84, 0.78), (0.5, 0.45, 0.35), (0.95, 0.94, 0.9), 0.45, 0.0),
}
GLOWS = {
    "glow_fire": ((1.0, 0.55, 0.2), (1.0, 0.42, 0.1), 7.0),
    "glow_cold": ((0.6, 0.8, 1.0), (0.45, 0.65, 1.0), 7.0),
    "glow_marsh": ((0.5, 1.0, 0.6), (0.3, 1.0, 0.45), 6.0),
}


def mat(name):
    """이름 하나로 재질을 만든다(같은 머리 안에서는 다시 쓴다)."""
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes.get("Principled BSDF")
    if name in GLOWS:
        col, em, st = GLOWS[name]
        p.inputs["Base Color"].default_value = (*col, 1)
        for key in ("Emission Color", "Emission"):
            if key in p.inputs:
                p.inputs[key].default_value = (*em, 1)
                break
        p.inputs["Emission Strength"].default_value = st
        return m
    kind, base, dark, edge, rough, metal = LOOKS[name]
    m["metal"] = metal
    co = nt.nodes.new("ShaderNodeTexCoord").outputs["Object"]
    big = _noise(nt, co, 6.0, 8.0, 0.6)
    fine = _noise(nt, co, 60.0, 4.0, 0.5)
    ao_n = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao_n.samples = 16
    ao_n.inputs["Distance"].default_value = 0.04
    ao = ao_n.outputs["AO"]
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    edge_m = _ramp(nt, geo.outputs["Pointiness"], 0.5, 0.56)
    edge_m = _math(nt, "MULTIPLY", edge_m, _ramp(nt, fine, 0.35, 0.6))   # 닳은 자리는 띄엄띄엄
    up = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], up.inputs[0])

    # 바탕 얼룩
    color = _mix(nt, (*dark, 1), (*base, 1), _ramp(nt, big, 0.25, 0.75))
    color = _mix(nt, color, (*base, 1), 0.55)
    height = _math(nt, "MULTIPLY", fine, 0.6, False)
    r_add = 0.0
    if kind == "stone":
        cells = _voronoi(nt, co, 14.0, "DISTANCE_TO_EDGE")
        crack = _math(nt, "SUBTRACT", 1.0, _ramp(nt, cells, 0.0, 0.05))
        color = _mix(nt, color, (*dark, 1), _math(nt, "MULTIPLY", crack, 0.8))
        height = _math(nt, "ADD", height, _math(nt, "MULTIPLY", _ramp(nt, cells, 0.0, 0.08), 0.8), False)
        moss = _math(nt, "MULTIPLY", _ramp(nt, up.outputs["Z"], 0.55, 0.9), _ramp(nt, big, 0.45, 0.6))
        color = _mix(nt, color, (0.12, 0.16, 0.07, 1), _math(nt, "MULTIPLY", moss, 0.85))
    elif kind == "wood":
        grain = _wave(nt, co, 9.0, 9.0)
        color = _mix(nt, color, (*dark, 1), _math(nt, "MULTIPLY", _ramp(nt, grain, 0.55, 0.95), 0.7))
        height = _math(nt, "ADD", height, _math(nt, "MULTIPLY", grain, 0.5), False)
    elif kind == "bone":
        cells = _voronoi(nt, co, 22.0, "DISTANCE_TO_EDGE")
        crack = _math(nt, "SUBTRACT", 1.0, _ramp(nt, cells, 0.0, 0.03))
        color = _mix(nt, color, (*dark, 1), _math(nt, "MULTIPLY", crack, 0.55))
        color = _mix(nt, color, (0.55, 0.45, 0.25, 1), _math(nt, "MULTIPLY", _ramp(nt, big, 0.5, 0.8), 0.4))
        height = _math(nt, "SUBTRACT", height, _math(nt, "MULTIPLY", crack, 0.4), False)
    elif kind == "brass":
        patina = _math(nt, "MULTIPLY", _math(nt, "SUBTRACT", 1.0, ao), _ramp(nt, big, 0.4, 0.7))
        color = _mix(nt, color, (0.16, 0.32, 0.24, 1), _math(nt, "MULTIPLY", patina, 1.2))
        r_add = _math(nt, "MULTIPLY", patina, 0.4)
    elif kind == "steel":
        brush = _noise(nt, co, 300.0, 2.0, 0.4)
        color = _mix(nt, color, (*edge, 1), _math(nt, "MULTIPLY", brush, 0.25))
        height = _math(nt, "MULTIPLY", height, 0.2, False)
    elif kind == "metal":
        rust = _math(nt, "MULTIPLY", _math(nt, "SUBTRACT", 1.0, ao), _ramp(nt, big, 0.55, 0.75))
        color = _mix(nt, color, (0.25, 0.12, 0.05, 1), _math(nt, "MULTIPLY", rust, 0.9))
        r_add = _math(nt, "MULTIPLY", rust, 0.35)
    elif kind == "cloth":
        weave = _noise(nt, co, 400.0, 1.0, 0.3)
        height = _math(nt, "MULTIPLY", weave, 0.6, False)
    # 틈의 때, 닳은 모서리
    color = _mix(nt, _mix(nt, color, (*dark, 1), 0.85), color, _ramp(nt, ao, 0.2, 0.95))
    color = _mix(nt, color, (*edge, 1), _math(nt, "MULTIPLY", edge_m, 0.85 if metal > 0.5 else 0.45))
    # 거칠기
    r = _math(nt, "ADD", rough, _math(nt, "MULTIPLY", _math(nt, "SUBTRACT", fine, 0.5, False), 0.25, False))
    r = _math(nt, "ADD", r, _math(nt, "MULTIPLY", _math(nt, "SUBTRACT", 1.0, ao), 0.2))
    r = _math(nt, "SUBTRACT", r, _math(nt, "MULTIPLY", edge_m, 0.25 if metal > 0.5 else 0.1))
    if not isinstance(r_add, float):
        r = _math(nt, "ADD", r, r_add)
    # 노멀(범프)
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.35 if metal > 0.5 else 0.7
    bump.inputs["Distance"].default_value = 0.004
    nt.links.new(height, bump.inputs["Height"])
    nt.links.new(_reroute(nt, color, "OUT_COLOR"), p.inputs["Base Color"])
    nt.links.new(_reroute(nt, r, "OUT_ROUGH"), p.inputs["Roughness"])
    nt.links.new(bump.outputs["Normal"], p.inputs["Normal"])
    p.inputs["Metallic"].default_value = metal
    return m


def give(o, name):
    o.data.materials.clear()
    o.data.materials.append(mat(name))
    return o


# ================================================================== 모양 도구
def bevel(o, w=0.005, seg=3):
    b = o.modifiers.new("bevel", "BEVEL")
    b.width = w
    b.segments = seg
    b.limit_method = "ANGLE"
    return o


def subsurf(o, lv=2):
    s = o.modifiers.new("sub", "SUBSURF")
    s.levels = lv
    s.render_levels = lv
    return o


def displace(o, amount=0.01, size=0.05, kind="CLOUDS", mid=0.5):
    t = bpy.data.textures.new("tex_%s" % o.name, kind)
    t.noise_scale = size
    if kind == "CLOUDS":
        t.noise_depth = 4
    d = o.modifiers.new("disp", "DISPLACE")
    d.texture = t
    d.strength = amount
    d.mid_level = mid
    d.texture_coords = "OBJECT"
    return o


def cut(o, cutter):
    """cutter 모양으로 o를 파낸다(그 자리에서 적용, cutter는 지운다). 다른 수정자보다 먼저 부른다."""
    m = o.modifiers.new("cut", "BOOLEAN")
    m.object = cutter
    m.operation = "DIFFERENCE"
    only(o)
    bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.data.objects.remove(cutter, do_unlink=True)
    return o


def cyl(r1, r2, h, at, m, verts=48, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=h, location=at, rotation=rot)
    return smooth(give(obj(), m))


def box(size, at, m, rot=(0, 0, 0), bev=0.004):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at, rotation=rot)
    o = obj()
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    give(o, m)
    if bev > 0:
        bevel(o, bev)
    return o


def ball(r, at, m, scale=(1, 1, 1), sub=4):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=r, location=at)
    o = obj()
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return smooth(give(o, m))


def ring(r, t, at, m, rot=(0, 0, 0), scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=t, location=at, rotation=rot, major_segments=64, minor_segments=12)
    o = obj()
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return smooth(give(o, m))


def limb(pts, radii, m, verts=20):
    """굽은 마디(뿔·가지·부리·테): 점을 따라 가늘어지는 원뿔을 잇고 마디에 공."""
    out = []
    for i in range(len(pts) - 1):
        a, b = Vector(pts[i]), Vector(pts[i + 1])
        d = b - a
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radii[i], radius2=radii[i + 1], depth=d.length, location=(a + b) / 2)
        o = obj()
        o.rotation_mode = "QUATERNION"
        o.rotation_quaternion = d.to_track_quat("Z", "Y")
        out.append(smooth(give(o, m)))
        if i > 0 and radii[i] > 0.003:
            out.append(ball(radii[i], a, m, sub=3))
    return out


def arc(p0, p1, bulge, n=6, jitter=0.0):
    """p0→p1을 bulge 방향으로 휜 점 n+1개."""
    p0, p1, bulge = Vector(p0), Vector(p1), Vector(bulge)
    pts = []
    for i in range(n + 1):
        t = i / n
        q = p0.lerp(p1, t) + bulge * math.sin(math.pi * t)
        if jitter > 0 and 0 < i < n:
            q += Vector((random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(-1, 1))) * jitter
        pts.append(tuple(q))
    return pts


def sword(at, tilt, length, blade, trim, s=1.0):
    """꽂힌 검: 가운데 홈이 팬 뾰족한 칼날, 끝이 말린 코등이, 가죽 감은 손잡이와 띠, 구슬 칼자루 끝."""
    parts = []
    bpy.ops.mesh.primitive_cube_add(size=1)
    b = obj()
    b.scale = (0.048 * s, 0.011 * s, length)
    bpy.ops.object.transform_apply(scale=True)
    for v in b.data.vertices:
        if v.co.z < 0:
            v.co.x *= 0.04   # 땅에 박힌 쪽이 칼끝
    b.location = (0, 0, length / 2)
    give(b, blade)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.011 * s, length * 0.55))
    f = obj()
    f.scale = (0.012 * s, 0.006 * s, length * 0.7)
    bpy.ops.object.transform_apply(scale=True)
    cut(b, f)
    bevel(b, 0.0015, 2)
    parts.append(b)
    parts.append(box((0.15 * s, 0.026 * s, 0.022 * s), (0, 0, length + 0.011 * s), trim, bev=0.005))
    for sx in (-1, 1):
        parts.append(ball(0.016 * s, (sx * 0.078 * s, 0, length + 0.02 * s), trim, (1, 1, 1.3), 3))
    parts.append(cyl(0.013 * s, 0.015 * s, 0.085 * s, (0, 0, length + 0.065 * s), "cloth_black", 24))
    for k in range(4):
        parts.append(ring(0.0155 * s, 0.0028, (0, 0, length + 0.032 * s + k * 0.02 * s), trim))
    parts.append(ball(0.022 * s, (0, 0, length + 0.122 * s), trim, (1, 1, 0.9), 3))
    for p in parts:
        p.parent = None
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    o = obj()
    o.location = Vector(at)
    o.rotation_euler = tilt
    return o


# ================================================================== 굽기와 내보내기
def _apply_all():
    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in bpy.context.scene.objects if o.type in ("MESH", "CURVE")]
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.convert(target="MESH")


def _split_by_material():
    for o in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
        if len(o.data.materials) > 1:
            only(o)
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.select_all(action="SELECT")
            bpy.ops.mesh.separate(type="MATERIAL")
            bpy.ops.object.mode_set(mode="OBJECT")


def _used_material(o):
    if not o.data.polygons:
        return None
    return o.material_slots[o.data.polygons[0].material_index].material


def _join_groups():
    groups = {}
    for o in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
        m = _used_material(o)
        if m is None:
            bpy.data.objects.remove(o, do_unlink=True)
            continue
        groups.setdefault(m.name, []).append(o)
    out = {}
    for name, objs in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        j = obj()
        j.name = name
        try:
            bpy.ops.object.material_slot_remove_unused()
        except Exception:
            pass
        out[name] = j
    return out


def _bake(o, tag):
    """o(재질 하나짜리 묶음)의 절차 재질을 색·거칠기·노멀 세 장으로 굽고 단순한 재질로 바꾼다."""
    src = o.material_slots[0].material
    nt = src.node_tree
    if nt.nodes.get("OUT_COLOR") is None:
        return
    only(o)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    imgs = {}
    for k in ("col", "rough", "nor"):
        img = bpy.data.images.new("%s_%s" % (tag, k), BAKE_SIZE, BAKE_SIZE, alpha=False)
        if k != "col":
            img.colorspace_settings.name = "Non-Color"
        imgs[k] = img
    target = nt.nodes.new("ShaderNodeTexImage")
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    shader = out.inputs["Surface"].links[0].from_socket
    sc = bpy.context.scene
    for k in ("col", "rough", "nor"):
        target.image = imgs[k]
        for n in nt.nodes:
            n.select = False
        target.select = True
        nt.nodes.active = target
        if k == "nor":
            sc.cycles.samples = 1
            bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", margin=6, use_clear=True)
        else:
            sc.cycles.samples = 12
            em = nt.nodes.new("ShaderNodeEmission")
            nt.links.new(nt.nodes["OUT_COLOR" if k == "col" else "OUT_ROUGH"].outputs[0], em.inputs["Color"])
            nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
            bpy.ops.object.bake(type="EMIT", margin=6, use_clear=True)
            nt.links.new(shader, out.inputs["Surface"])
            nt.nodes.remove(em)
        path = os.path.join(BAKE_DIR, "%s_%s.png" % (tag, k))
        imgs[k].filepath_raw = path
        imgs[k].file_format = "PNG"
        imgs[k].save()
    # 구운 세 장으로 단순한 재질(이름은 그대로: 게임이 앞머리로 색을 바꾼다)
    name = src.name
    src.name = name + "_src"
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    mt = m.node_tree
    p = mt.nodes.get("Principled BSDF")
    tc = mt.nodes.new("ShaderNodeTexImage")
    tc.image = imgs["col"]
    mt.links.new(tc.outputs["Color"], p.inputs["Base Color"])
    tr = mt.nodes.new("ShaderNodeTexImage")
    tr.image = imgs["rough"]
    sep = mt.nodes.new("ShaderNodeSeparateColor")
    mt.links.new(tr.outputs["Color"], sep.inputs[0])
    mt.links.new(sep.outputs[1], p.inputs["Roughness"])
    tn = mt.nodes.new("ShaderNodeTexImage")
    tn.image = imgs["nor"]
    nm = mt.nodes.new("ShaderNodeNormalMap")
    mt.links.new(tn.outputs["Color"], nm.inputs["Color"])
    mt.links.new(nm.outputs["Normal"], p.inputs["Normal"])
    p.inputs["Metallic"].default_value = float(src.get("metal", 0.0))
    o.data.materials.clear()
    o.data.materials.append(m)


def finish(name):
    """수정자 적용 → 재질별로 묶기 → 굽기 → .glb."""
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    try:
        sc.cycles.device = "CPU"
    except Exception:
        pass
    _apply_all()
    _split_by_material()
    groups = _join_groups()
    for gname, o in groups.items():
        if gname.startswith("glow"):
            continue
        try:
            _bake(o, "%s_%s" % (name, gname))
        except Exception:
            print("굽기 실패(굽지 않고 내보낸다):", name, gname)
            traceback.print_exc()
            if bpy.context.object and bpy.context.object.mode != "OBJECT":
                bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="SELECT")
    path = os.path.join(OUT, name + ".glb")
    kw = dict(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True)
    try:
        bpy.ops.export_scene.gltf(export_image_format="JPEG", **kw)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)
    print("만듦", path)


# ================================================================== 머리들
def head_hill():
    """주인공 기본 「검의 언덕」: 겹친 바위 무더기, 틈으로 비치는 불, 기울어 꽂힌 검 다섯(가운데 하나만 희다)."""
    ball(0.15, (0, 0, 0.075), "glow_fire", (1.15, 1.0, 0.5), 3)
    core = ball(0.17, (0, 0, 0.08), "stone_dark", (1.2, 1.05, 0.6), 5)
    displace(core, 0.045, 0.05, "VORONOI")
    for k in range(6):
        a = k * 1.05 + 0.3
        r = random.uniform(0.05, 0.09)
        s = ball(r, (math.cos(a) * 0.14, math.sin(a) * 0.12, 0.07 + random.uniform(0, 0.04)), "stone_grey", (1.2, 1, 0.75), 4)
        displace(s, 0.012, 0.025, "VORONOI")
        bevel(s, 0.003)
    tilts = [(0, 0, 0), (0.35, 0.15, 0.4), (-0.3, -0.25, 1.2), (0.28, -0.42, 2.4), (-0.42, 0.3, 3.6)]
    spots = [(0, 0, 0.12), (0.09, -0.07, 0.1), (-0.11, -0.04, 0.09), (0.07, 0.09, 0.09), (-0.06, 0.1, 0.1)]
    for k in range(5):
        big = k == 0
        sword(spots[k], tilts[k], 0.34 if big else 0.18 + 0.025 * k, "metal_steel" if big else "metal_iron", "metal_brass" if big else "metal_iron", 1.0 if big else 0.8)
    for k in range(3):   # 부러진 칼날 조각
        box((0.035, 0.008, 0.06), (random.uniform(-0.15, 0.15), random.uniform(-0.12, 0.12), 0.12), "metal_iron", (random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(0, 3)), 0.001)


def head_wolf():
    """늑대왕: 눈구멍 깊은 늑대 두개골(광대·이빨·아래턱), 굽은 뿔, 쇠 왕관과 붉은 보석."""
    skull = ball(0.12, (0, 0.03, 0.17), "bone_old", (0.92, 1.12, 0.85), 5)
    for sx in (-1, 1):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.038, location=(sx * 0.058, -0.07, 0.175))
        cut(skull, obj())
    displace(skull, 0.004, 0.02)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.14, 0.125))
    sn = obj()
    sn.scale = (0.1, 0.2, 0.075)
    bpy.ops.object.transform_apply(scale=True)
    for v in sn.data.vertices:
        if v.co.y < 0:
            v.co.x *= 0.55
            v.co.z *= 0.7
    give(sn, "bone_old")
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.022, location=(0, -0.235, 0.14))
    nose = obj()
    nose.scale = (1, 0.7, 1.3)
    cut(sn, nose)
    subsurf(sn, 2)
    bevel(sn, 0.003)
    for sx in (-1, 1):
        ball(0.045, (sx * 0.05, -0.06, 0.215), "bone_old", (1.25, 0.8, 0.45), 4)    # 눈두덩
        ball(0.018, (sx * 0.058, -0.06, 0.172), "glow_fire", (1, 0.7, 1), 3)
        limb([(sx * 0.07, 0.0, 0.13), (sx * 0.09, -0.06, 0.125), (sx * 0.06, -0.12, 0.11)], [0.014, 0.013, 0.01], "bone_old")   # 광대
        for k in range(4):
            big = k == 0
            cyl(0.0, 0.011 if big else 0.007, 0.05 if big else 0.028, (sx * (0.038 - k * 0.006), -0.215 + k * 0.035, 0.07 if big else 0.08), "bone_old", 12, (math.pi, 0, 0))
        horn = arc((sx * 0.08, 0.06, 0.24), (sx * 0.2, 0.12, 0.42), (sx * 0.07, 0.06, -0.02), 7)
        limb(horn, [0.035 - i * 0.0048 for i in range(8)], "bone_old")
    jaw = box((0.085, 0.17, 0.025), (0, -0.1, 0.065), "bone_old", (0.12, 0, 0), 0.008)
    subsurf(jaw, 1)
    ring(0.105, 0.012, (0, 0.03, 0.255), "metal_iron", scale=(1, 1.12, 1))
    for k in range(9):
        a = k / 9 * math.tau
        cyl(0.0, 0.02, 0.085, (math.cos(a) * 0.105, 0.03 + math.sin(a) * 0.117, 0.3), "metal_iron", 6)
    ball(0.016, (0, -0.088, 0.255), "glow_fire", (1, 0.6, 1.2), 3)


def head_tower():
    """망루 궁수장: 돌을 한 장씩 엇갈려 쌓은 망루, 총안 불빛, 기둥 위 원뿔 지붕, 박힌 화살."""
    cyl(0.12, 0.125, 0.3, (0, 0, 0.15), "stone_dark", 24)
    for row in range(5):
        for k in range(10):
            a = (k + 0.5 * (row % 2)) / 10 * math.tau
            w = 0.078 * random.uniform(0.9, 1.05)
            b = box((w, 0.045, 0.054), (math.cos(a) * 0.132, math.sin(a) * 0.132, 0.03 + row * 0.058), "stone_grey", (0, 0, a + math.pi / 2), 0.007)
            displace(b, 0.004, 0.015)
    for k in range(8):
        a = k / 8 * math.tau
        m = box((0.06, 0.05, 0.065), (math.cos(a) * 0.135, math.sin(a) * 0.135, 0.33), "stone_grey", (0, 0, a + math.pi / 2), 0.007)
        displace(m, 0.004, 0.015)
    box((0.022, 0.03, 0.1), (0, -0.155, 0.2), "glow_fire", bev=0)
    for k in range(4):
        a = k / 4 * math.tau + math.pi / 4
        cyl(0.008, 0.008, 0.16, (math.cos(a) * 0.12, math.sin(a) * 0.12, 0.44), "wood_old", 12)
    roof = cyl(0.19, 0.0, 0.16, (0, 0, 0.6), "wood_old", 12)
    bevel(roof, 0.004)
    for k in range(3):
        a = (k - 1) * 0.4
        d = Vector((math.sin(a) * 0.4, -0.9, 0.35)).normalized()
        base = Vector((math.sin(a) * 0.13, -0.11, 0.12 + k * 0.06))
        limb([tuple(base - d * 0.02), tuple(base + d * 0.2)], [0.005, 0.005], "wood_old", 8)
        for f in range(3):
            fa = f / 3 * math.tau
            box((0.002, 0.03, 0.025), tuple(base + d * 0.19 + Vector((math.cos(fa), 0, math.sin(fa))) * 0.008), "cloth_black", (0, fa, 0), 0)


def head_boulder():
    """발치 거인: 큰 바위, 툭 튀어나온 이마 바위 밑 깊이 박힌 두 눈빛, 이끼, 자갈."""
    r = ball(0.19, (0, 0, 0.16), "stone_grey", (1.12, 1.0, 0.95), 5)
    for sx in (-1, 1):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(sx * 0.06, -0.17, 0.18), rotation=(0, sx * 0.15, 0))
        e = obj()
        e.scale = (0.065, 0.08, 0.028)
        bpy.ops.object.transform_apply(scale=True)
        cut(r, e)
        box((0.05, 0.012, 0.012), (sx * 0.06, -0.15, 0.18), "glow_fire", (0, sx * 0.15, 0), 0)
    displace(r, 0.04, 0.08, "VORONOI")
    brow = ball(0.11, (0, -0.08, 0.25), "stone_grey", (1.6, 0.8, 0.5), 4)
    displace(brow, 0.02, 0.05, "VORONOI")
    for k in range(4):
        a = k * 1.7
        s = ball(random.uniform(0.04, 0.07), (math.cos(a) * 0.13, math.sin(a) * 0.1 + 0.05, 0.31), "stone_grey", (1, 1, 0.8), 3)
        displace(s, 0.012, 0.03, "VORONOI")


def head_shield():
    """방패대장: 판자를 이은 연 모양 방패가 얼굴, 쇠 테·징, 가운데 돌기, 놋쇠 십자."""
    for i in range(6):
        x = -0.125 + i * 0.05
        bottom = 0.03 + abs(x) * 1.25
        h = 0.44 - bottom
        b = box((0.049, 0.03 + random.uniform(0, 0.006), h), (x, random.uniform(-0.003, 0.003), bottom + h / 2), "wood_old", bev=0.004)
        displace(b, 0.002, 0.01)
    outline = [(-0.15, -0.02, 0.44), (-0.15, -0.02, 0.22), (0.0, -0.02, 0.02), (0.15, -0.02, 0.22), (0.15, -0.02, 0.44), (-0.15, -0.02, 0.44)]
    limb(outline, [0.012] * 6, "metal_iron", 12)
    for i in range(5):
        t = i / 5
        for p0, p1 in ((outline[1], outline[2]), (outline[2], outline[3])):
            q = Vector(p0).lerp(Vector(p1), t + 0.1)
            ball(0.008, tuple(q + Vector((0, -0.012, 0))), "metal_brass", sub=2)
    box((0.026, 0.012, 0.3), (0, -0.026, 0.27), "metal_brass", bev=0.003)
    box((0.2, 0.012, 0.026), (0, -0.026, 0.34), "metal_brass", bev=0.003)
    ring(0.052, 0.009, (0, -0.03, 0.3), "metal_iron", (math.pi / 2, 0, 0))
    ball(0.045, (0, -0.035, 0.3), "metal_iron", (1, 0.6, 1))


def head_marsh():
    """늪의 부르는 자: 그루터기에서 뻗은 비틀린 가지 왕관, 쇠창살 등 안의 초록 불, 등을 매단 사슬."""
    st = cyl(0.04, 0.055, 0.1, (0, 0, 0.05), "wood_old", 16)
    displace(st, 0.006, 0.02)
    for k in range(6):
        a = k / 6 * math.tau + random.uniform(-0.2, 0.2)
        top = (math.cos(a) * 0.16, math.sin(a) * 0.16, 0.36 + random.uniform(-0.03, 0.05))
        pts = arc((math.cos(a) * 0.03, math.sin(a) * 0.03, 0.09), top, (math.cos(a) * 0.04, math.sin(a) * 0.04, 0.03), 6, 0.012)
        limb(pts, [0.02 - i * 0.0028 for i in range(7)], "wood_old", 12)
        mid = Vector(pts[3])
        limb([tuple(mid), tuple(mid + Vector((math.cos(a + 0.8), math.sin(a + 0.8), 1.2)) * 0.06)], [0.009, 0.003], "wood_old", 8)
    ball(0.055, (0, 0, 0.23), "glow_marsh", sub=4)
    for k in range(6):
        a = k / 6 * math.tau
        limb([(math.cos(a) * 0.06, math.sin(a) * 0.06, 0.16), (math.cos(a) * 0.072, math.sin(a) * 0.072, 0.23), (math.cos(a) * 0.06, math.sin(a) * 0.06, 0.3)], [0.004, 0.004, 0.004], "metal_iron", 8)
    ring(0.062, 0.006, (0, 0, 0.16), "metal_iron")
    ring(0.062, 0.006, (0, 0, 0.3), "metal_iron")
    cyl(0.03, 0.0, 0.04, (0, 0, 0.32), "metal_iron", 16)
    for k in range(3):
        ring(0.011, 0.003, (0, 0, 0.35 + k * 0.018), "metal_iron", (0, (k % 2) * math.pi / 2, 0))


def head_pick():
    """채석장 감독: 깨진 돌덩이에 박힌 곡괭이(휜 쇠날, 쇠띠 두른 자루)."""
    r = ball(0.14, (0, 0, 0.1), "stone_grey", (1.15, 1, 0.75), 4)
    displace(r, 0.025, 0.05, "VORONOI")
    bevel(r, 0.003)
    cyl(0.021, 0.025, 0.3, (0, 0, 0.26), "wood_old", 16)
    for z in (0.2, 0.34):
        ring(0.026, 0.005, (0, 0, z), "metal_iron")
    box((0.07, 0.065, 0.075), (0, 0, 0.4), "metal_iron", bev=0.008)
    for sx in (-1, 1):
        pts = arc((sx * 0.03, 0, 0.4), (sx * 0.26, 0, 0.32), (0, 0, 0.05), 6)
        limb(pts, [0.028 - i * 0.0042 for i in range(7)], "metal_iron", 6)


def head_burnt():
    """불탄 거인: 숯이 된 머리, 깊게 갈라진 틈 사이로 안쪽 불이 이글거린다, 부러진 뿔 그루터기."""
    ball(0.152, (0, 0, 0.17), "glow_fire", (1, 1, 1.05), 4)
    r = ball(0.17, (0, 0, 0.17), "stone_dark", (1, 1, 1.05), 6)
    displace(r, 0.06, 0.045, "VORONOI")
    for k in range(5):
        a = k * 1.3
        p0 = Vector((math.cos(a) * 0.1, math.sin(a) * 0.1, 0.26))
        d = Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, 1)).normalized()
        limb([tuple(p0), tuple(p0 + d * random.uniform(0.05, 0.09))], [0.025, 0.012], "stone_dark", 8)


def head_raven():
    """까마귀 기사: 둥근 투구, 아래로 굽은 새부리 면갑, 눈 틈의 찬 빛, 부채처럼 뒤로 뻗은 검은 깃털, 놋쇠 테."""
    cyl(0.12, 0.13, 0.22, (0, 0, 0.11), "metal_iron", 48)
    ball(0.125, (0, 0, 0.22), "metal_iron", (1, 1, 0.75))
    beak = arc((0, -0.1, 0.15), (0, -0.33, 0.06), (0, -0.02, 0.04), 6)
    limb(beak, [0.07 - i * 0.0115 for i in range(7)], "metal_iron", 24)
    for sx in (-1, 1):
        box((0.06, 0.02, 0.014), (sx * 0.045, -0.123, 0.19), "glow_cold", (0, sx * 0.2, sx * -0.12), 0)
    for k in range(11):
        f = (k - 5) / 5
        bpy.ops.mesh.primitive_cube_add(size=1)
        fe = obj()
        fe.scale = (0.036, 0.004, 0.24 - abs(f) * 0.06)
        bpy.ops.object.transform_apply(scale=True)
        for v in fe.data.vertices:
            if v.co.z > 0:
                v.co.x *= 0.25
        give(fe, "cloth_black")
        bevel(fe, 0.0015)
        fe.location = (f * 0.06, 0.08, 0.3)
        fe.rotation_euler = (-0.6 - abs(f) * 0.25, 0, f * 0.5)
        limb([(f * 0.06, 0.07, 0.24), (f * 0.11, 0.17, 0.4 - abs(f) * 0.04)], [0.0025, 0.001], "bone_old", 6)
    ring(0.132, 0.01, (0, 0, 0.04), "metal_brass")
    ring(0.127, 0.007, (0, 0, 0.2), "metal_brass")


def head_grave_helm():
    """무덤 기사: 통투구, 파낸 눈 틈 안의 찬 빛, 숨구멍, 징 박은 테, 놋쇠 관."""
    h = cyl(0.13, 0.14, 0.27, (0, 0, 0.135), "metal_iron", 64)
    for z, w in ((0.19, 0.2), (0.16, 0.03)):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.14, z))
        c = obj()
        c.scale = (w, 0.1, 0.022) if w > 0.1 else (0.024, 0.1, 0.12)   # 깊이 파서 안쪽 빛이 보이게
        bpy.ops.object.transform_apply(scale=True)
        cut(h, c)
    for k in range(8):
        bpy.ops.mesh.primitive_cylinder_add(radius=0.006, depth=0.09, location=(-0.06 + (k % 4) * 0.04, -0.14, 0.075 - (k // 4) * 0.025), rotation=(math.pi / 2, 0, 0))
        cut(h, obj())
    bevel(h, 0.003)
    ball(0.12, (0, 0, 0.15), "glow_cold", (1, 1, 1.2), 3)    # 틈 안쪽 빛
    ball(0.135, (0, 0, 0.27), "metal_iron", (1, 1, 0.45))
    ring(0.142, 0.009, (0, 0, 0.11), "metal_iron")
    for k in range(16):
        a = k / 16 * math.tau
        ball(0.007, (math.cos(a) * 0.145, math.sin(a) * 0.145, 0.11), "metal_brass", sub=2)
    ring(0.142, 0.01, (0, 0, 0.275), "metal_brass")
    for k in range(6):
        a = k / 6 * math.tau
        p = Vector((math.cos(a) * 0.14, math.sin(a) * 0.14, 0.28))
        limb([tuple(p), tuple(p + Vector((0, 0, 0.06)))], [0.016, 0.0], "metal_brass", 4)


def head_tomb():
    """무덤 주인: 이 빠진 둥근 묘비, 금, 새긴 십자, 받침돌, 촛농 흐르는 초 셋."""
    t = box((0.26, 0.085, 0.3), (0, 0, 0.17), "stone_grey", bev=0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=0.13, depth=0.085, location=(0, 0, 0.32), rotation=(math.pi / 2, 0, 0))
    top = obj()
    bpy.ops.object.select_all(action="DESELECT")
    t.select_set(True)
    top.select_set(True)
    bpy.context.view_layer.objects.active = t
    bpy.ops.object.join()
    t = obj()
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0.12, 0, 0.42), rotation=(0, 0.7, 0.3))
    ch = obj()
    ch.scale = (0.08, 0.2, 0.08)
    cut(t, ch)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(-0.06, -0.04, 0.2), rotation=(0, 0.4, 0))
    cr = obj()
    cr.scale = (0.005, 0.03, 0.18)
    cut(t, cr)
    for loc, sc in (((0, -0.045, 0.26), (0.03, 0.03, 0.16)), ((0, -0.045, 0.3), (0.11, 0.03, 0.03))):
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
        c = obj()
        c.scale = sc
        cut(t, c)
    bevel(t, 0.006)
    displace(t, 0.004, 0.02, "VORONOI")
    b = box((0.32, 0.12, 0.04), (0, 0, 0.02), "stone_grey", bev=0.006)
    displace(b, 0.004, 0.02, "VORONOI")
    for k in range(3):
        x = -0.08 + k * 0.08
        hgt = 0.05 + k * 0.012
        z0 = 0.455 if k != 2 else 0.43
        cyl(0.014, 0.016, hgt, (x, 0, z0 + hgt / 2), "wax_old", 24)
        for d in range(4):
            a = d * 1.6 + k
            dl = random.uniform(0.012, 0.03)
            limb([(x + math.cos(a) * 0.015, math.sin(a) * 0.015, z0 + hgt), (x + math.cos(a) * 0.016, math.sin(a) * 0.016, z0 + hgt - dl)], [0.004, 0.0035], "wax_old", 8)
        limb([(x, 0, z0 + hgt), (x, 0, z0 + hgt + 0.012)], [0.0015, 0.0015], "cloth_black", 6)
        ball(0.011, (x, 0, z0 + hgt + 0.025), "glow_fire", (1, 1, 1.9), 3)


HEADS = {
    "hill": head_hill, "wolf": head_wolf, "tower": head_tower, "boulder": head_boulder, "shield": head_shield, "marsh": head_marsh,
    "pick": head_pick, "burnt": head_burnt, "raven": head_raven, "grave_helm": head_grave_helm, "tomb": head_tomb,
}

made, failed = [], []
for name, fn in HEADS.items():
    try:
        clear()
        fn()
        finish(name)
        made.append(name)
    except Exception:
        print("실패:", name)
        traceback.print_exc()
        failed.append(name)
print("머리 %d개를 %s에 만들었다. 실패: %s" % (len(made), OUT, ", ".join(failed) or "없음"))
