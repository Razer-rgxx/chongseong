# 「검의 언덕」 머리(Heads) 11개를 Blender로 짓고 .glb로 내보낸다. (2026-11-23)
#
# PC에서 한 번:
#   "C:\Program Files\Blender Foundation\Blender 4.2\blender.exe" -b -P tools\blender\make_heads.py
# (chongseong 폴더에서. 버전 폴더 이름은 설치한 것에 맞춘다. 4.x면 된다)
# 결과: assets/heads/<모양>.glb  → 게임이 있으면 그것을 쓰고, 없으면 예전 도형으로 그린다(ObjectHead).
#
# 약속(ObjectHead와):
#   - 바닥 가운데가 원점, 위로 0.35~0.55m, 앞(얼굴)은 Blender의 -Y(Godot에서 +Z).
#   - 재질 이름 앞머리로 게임이 색을 바꾼다: metal_*(바탕: 쇠·놋쇠·뼈·녹), glow_*(빛 색), 나머지(stone_/bone_/wood_/cloth_)는 바탕색을 곱한다.
#   - 질감은 굽지 않는다. 모양(깎은 모서리, 울퉁불퉁한 면, 파인 홈)으로 고퀄을 낸다.

import bpy
import math
import os
import random

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "heads")
os.makedirs(OUT, exist_ok=True)
random.seed(7)


# ------------------------------------------------------------------ 바탕
def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.textures):
        for b in list(block):
            if b.users == 0:
                block.remove(b)


def mat(name, color, metal=0.0, rough=0.7, emit=None, strength=4.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rough
    if emit:
        p.inputs["Emission Color"].default_value = (*emit, 1)
        p.inputs["Emission Strength"].default_value = strength
    return m


IRON = lambda: mat("metal_iron", (0.22, 0.22, 0.24), 0.9, 0.42)
BRASS = lambda: mat("metal_brass", (0.62, 0.45, 0.2), 0.95, 0.32)
STONE = lambda: mat("stone_grey", (0.38, 0.36, 0.33), 0.0, 0.92)
DARK = lambda: mat("stone_dark", (0.12, 0.11, 0.1), 0.0, 0.95)
BONE = lambda: mat("bone_old", (0.74, 0.69, 0.58), 0.0, 0.75)
WOOD = lambda: mat("wood_old", (0.26, 0.17, 0.1), 0.0, 0.85)
CLOTH = lambda: mat("cloth_black", (0.05, 0.05, 0.06), 0.0, 0.9)
GLOW = lambda: mat("glow_fire", (1.0, 0.55, 0.2), 0.0, 0.5, (1.0, 0.45, 0.12), 6.0)
GLOW_COLD = lambda: mat("glow_cold", (0.6, 0.8, 1.0), 0.0, 0.5, (0.45, 0.65, 1.0), 6.0)
GLOW_GREEN = lambda: mat("glow_marsh", (0.5, 1.0, 0.6), 0.0, 0.5, (0.3, 1.0, 0.45), 5.0)
STEEL = lambda: mat("metal_steel", (0.7, 0.72, 0.76), 1.0, 0.22)


def obj():
    return bpy.context.active_object


def give(o, m):
    o.data.materials.clear()
    o.data.materials.append(m)
    return o


def smooth(o, angle=40):
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle)) if hasattr(bpy.ops.object, "shade_smooth_by_angle") else bpy.ops.object.shade_smooth()
    return o


def bevel(o, w=0.006, seg=3):
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


def rough_up(o, amount=0.012, size=0.06, kind="CLOUDS"):
    """돌·뼈 표면을 울퉁불퉁하게(Displace + 잡음 질감)."""
    t = bpy.data.textures.new("tex_%s" % o.name, kind)
    if kind == "CLOUDS":
        t.noise_scale = size
    else:
        t.noise_scale = size
    d = o.modifiers.new("disp", "DISPLACE")
    d.texture = t
    d.strength = amount
    d.texture_coords = "OBJECT"
    return o


def cut(o, cutter):
    """cutter 모양으로 o를 파낸다(불리언) 뒤 cutter는 지운다."""
    m = o.modifiers.new("cut", "BOOLEAN")
    m.object = cutter
    m.operation = "DIFFERENCE"
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.data.objects.remove(cutter)
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


def ring(r, t, at, m, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=t, location=at, rotation=rot, major_segments=48, minor_segments=12)
    return smooth(give(obj(), m))


def export(name):
    bpy.ops.object.select_all(action="SELECT")
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True)
    print("made", path)


def sword(at, tilt, length, m_blade, m_trim, scale=1.0):
    """꽂힌 검 한 자루: 칼날(가운데 홈, 뾰족한 끝), 코등이, 감은 손잡이, 구슬."""
    parts = []
    w = 0.045 * scale
    bpy.ops.mesh.primitive_cube_add(size=1)
    b = obj()
    b.scale = (w, 0.01 * scale, length)
    bpy.ops.object.transform_apply(scale=True)
    # 끝을 뾰족하게: 위쪽 꼭짓점 둘을 가운데로
    for v in b.data.vertices:
        if v.co.z > 0:
            v.co.x *= 0.05
    b.location = (0, 0, length / 2)
    give(b, m_blade)
    bevel(b, 0.002, 2)
    parts.append(b)
    parts.append(box((w * 3.2, 0.025 * scale, 0.02 * scale), (0, 0, length + 0.01 * scale), m_trim, bev=0.004))
    parts.append(cyl(0.012 * scale, 0.014 * scale, 0.08 * scale, (0, 0, length + 0.06 * scale), WOOD(), 24))
    for k in range(3):
        parts.append(ring(0.014 * scale, 0.003, (0, 0, length + 0.035 * scale + k * 0.022 * scale), m_trim))
    parts.append(ball(0.02 * scale, (0, 0, length + 0.11 * scale), m_trim))
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    o = obj()
    o.location = at
    o.rotation_euler = tilt
    return o


# ------------------------------------------------------------------ 머리들
def head_hill():
    """주인공 기본: 검의 언덕. 갈라진 바위 무더기, 틈의 불씨, 검 다섯."""
    clear()
    core = ball(0.17, (0, 0, 0.08), DARK(), (1.2, 1.05, 0.62), 5)
    rough_up(core, 0.03, 0.05, "VORONOI")
    for k in range(4):
        a = k * 1.6 + 0.3
        s = ball(0.08, (math.cos(a) * 0.12, math.sin(a) * 0.1, 0.1), STONE(), (1, 1, 0.8), 4)
        rough_up(s, 0.015, 0.03)
    ball(0.15, (0, 0, 0.08), GLOW(), (1.15, 1.0, 0.55), 3)   # 틈으로 비치는 불
    tilts = [(0, 0, 0), (0.35, 0.15, 0.4), (-0.3, -0.25, 1.2), (0.25, -0.4, 2.4), (-0.4, 0.3, 3.6)]
    spots = [(0, 0, 0.12), (0.09, -0.07, 0.1), (-0.11, -0.04, 0.09), (0.07, 0.09, 0.09), (-0.06, 0.1, 0.1)]
    for k in range(5):
        sword(spots[k], tilts[k], 0.34 if k == 0 else 0.2 + 0.025 * k, STEEL() if k == 0 else IRON(), BRASS() if k == 0 else IRON(), 1.0 if k == 0 else 0.8)
    export("hill")


def head_wolf():
    """늑대왕: 길쭉한 늑대 두개골(눈구멍·이빨), 쇠 왕관."""
    clear()
    skull = ball(0.12, (0, 0.02, 0.15), BONE(), (1.0, 1.15, 0.95), 5)
    snout = box((0.1, 0.2, 0.08), (0, -0.14, 0.11), BONE(), bev=0.02)
    subsurf(snout, 2)
    for o in (skull, snout):
        rough_up(o, 0.006, 0.02)
    for sx in (-1, 1):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.035, location=(sx * 0.055, -0.08, 0.17))
        cut(skull, obj())
        ball(0.02, (sx * 0.055, -0.07, 0.17), GLOW(), (1, 0.6, 1), 3)
        for k in range(3):
            cyl(0.0, 0.008, 0.04, (sx * (0.035 - k * 0.012), -0.2 + k * 0.02, 0.06), BONE(), 12, (math.pi, 0, 0))
        horn = cyl(0.0, 0.035, 0.18, (sx * 0.09, 0.07, 0.27), BONE(), 24, (0.4, -sx * 0.45, 0))
        bevel(horn, 0.003)
    ring(0.11, 0.012, (0, 0.02, 0.25), IRON())
    for k in range(7):
        a = k / 7 * math.tau
        cyl(0.0, 0.022, 0.08, (math.cos(a) * 0.11, 0.02 + math.sin(a) * 0.11, 0.3), IRON(), 4)
    export("wolf")


def head_tower():
    """망루 궁수장: 돌을 쌓은 망루, 총안, 그 안의 불빛, 꽂힌 화살."""
    clear()
    body = cyl(0.13, 0.15, 0.3, (0, 0, 0.15), STONE(), 16)
    rough_up(body, 0.006, 0.02, "VORONOI")
    for k in range(8):
        a = k / 8 * math.tau
        m = box((0.055, 0.055, 0.06), (math.cos(a) * 0.135, math.sin(a) * 0.135, 0.33), STONE(), (0, 0, a), 0.006)
        rough_up(m, 0.004, 0.02)
    box((0.03, 0.05, 0.09), (0, -0.14, 0.2), GLOW(), bev=0)
    ring(0.15, 0.01, (0, 0, 0.29), WOOD())
    for k in range(3):
        a = (k - 1) * 0.35
        cyl(0.005, 0.005, 0.34, (k * 0.04 - 0.04, 0.03, 0.42), WOOD(), 8, (a, 0.2, 0))
        box((0.002, 0.03, 0.04), (k * 0.04 - 0.04 + math.sin(0.2) * 0.17, 0.03 - math.sin(a) * 0.17, 0.57), CLOTH(), (a, 0.2, 0), 0)
    export("tower")


def head_boulder():
    """발치 거인: 큰 바위 머리, 이마 아래 갈라진 눈빛."""
    clear()
    r = ball(0.19, (0, 0, 0.16), STONE(), (1.1, 1.0, 0.95), 5)
    rough_up(r, 0.04, 0.08, "VORONOI")
    for sx in (-1, 1):
        box((0.06, 0.02, 0.012), (sx * 0.06, -0.17, 0.18), GLOW(), (0, 0, sx * 0.15), 0)
    s = ball(0.09, (0.1, 0.05, 0.3), STONE(), (1, 1, 0.8), 4)
    rough_up(s, 0.02, 0.05)
    export("boulder")


def head_shield():
    """방패대장: 얼굴이 곧 연 모양 방패, 쇠 테·징·가운데 돌기."""
    clear()
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.18, depth=0.04, location=(0, 0, 0.2), rotation=(math.pi / 2, 0, 0))
    sh = obj()
    for v in sh.data.vertices:
        if v.co.y < -0.05:
            v.co.y *= 1.7   # 아래가 길게(연 모양)
    give(sh, WOOD())
    bevel(sh, 0.008, 3)
    rim = ring(0.18, 0.012, (0, -0.02, 0.2), IRON(), (math.pi / 2, 0, 0))
    rim.scale = (1, 1.2, 1)
    ball(0.05, (0, -0.04, 0.22), IRON(), (1, 0.6, 1))
    for k in range(10):
        a = k / 10 * math.tau
        ball(0.009, (math.cos(a) * 0.14, -0.035, 0.2 + math.sin(a) * 0.17), BRASS(), (1, 1, 1), 2)
    export("shield")


def head_marsh():
    """늪의 부르는 자: 이끼 낀 가지 고리에 매달린 초록 등, 쇠창살."""
    clear()
    cyl(0.03, 0.04, 0.12, (0, 0, 0.06), WOOD(), 12)
    br = ring(0.14, 0.022, (0, 0, 0.27), WOOD(), (math.pi / 2, 0, 0))
    rough_up(br, 0.01, 0.03)
    for k in range(5):
        a = k / 5 * math.tau
        cyl(0.004, 0.012, 0.12, (math.cos(a) * 0.12, 0, 0.27 + math.sin(a) * 0.12), WOOD(), 8, (0, a, 0))
    ball(0.06, (0, 0, 0.24), GLOW_GREEN())
    for k in range(6):
        a = k / 6 * math.tau
        cyl(0.004, 0.004, 0.14, (math.cos(a) * 0.07, math.sin(a) * 0.07, 0.24), IRON(), 8)
    ring(0.07, 0.006, (0, 0, 0.31), IRON())
    ring(0.07, 0.006, (0, 0, 0.17), IRON())
    export("marsh")


def head_pick():
    """채석장 감독: 굽은 곡괭이 날이 가로로 박힌 돌덩이."""
    clear()
    r = ball(0.13, (0, 0, 0.1), STONE(), (1.1, 1, 0.75), 4)
    rough_up(r, 0.02, 0.05, "VORONOI")
    cyl(0.022, 0.026, 0.28, (0, 0, 0.25), WOOD(), 16)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.36))
    h = obj()
    h.scale = (0.46, 0.04, 0.05)
    bpy.ops.object.transform_apply(scale=True)
    for v in h.data.vertices:
        v.co.z -= (v.co.x ** 2) * 1.2   # 아래로 굽힌다
        if abs(v.co.x) > 0.2:
            v.co.y *= 0.2
            v.co.z *= 0.4
    give(h, IRON())
    bevel(h, 0.004)
    subsurf(h, 1)
    box((0.07, 0.06, 0.07), (0, 0, 0.36), IRON(), bev=0.008)
    export("pick")


def head_burnt():
    """불탄 거인: 숯이 된 머리, 깊은 틈에서 이글거리는 불."""
    clear()
    ball(0.15, (0, 0, 0.16), GLOW(), (1, 1, 1.05), 4)
    r = ball(0.17, (0, 0, 0.16), DARK(), (1, 1, 1.05), 5)
    rough_up(r, 0.05, 0.05, "VORONOI")   # 깊은 틈 사이로 안쪽 불이 보인다
    for k in range(5):
        a = k * 1.3
        c = cyl(0.0, 0.02, 0.06, (math.cos(a) * 0.12, math.sin(a) * 0.12, 0.3), DARK(), 8, (0.4 * math.sin(a), 0.4 * math.cos(a), 0))
    export("burnt")


def head_raven():
    """까마귀 기사: 새부리 면갑, 눈 틈, 뒤로 뻗은 검은 깃털."""
    clear()
    helm = cyl(0.12, 0.13, 0.22, (0, 0, 0.11), IRON(), 48)
    dome = ball(0.125, (0, 0, 0.22), IRON(), (1, 1, 0.7))
    beak = cyl(0.0, 0.075, 0.24, (0, -0.2, 0.12), IRON(), 24, (math.pi / 2 + 0.25, 0, 0))
    bevel(beak, 0.004)
    box((0.16, 0.02, 0.014), (0, -0.125, 0.18), GLOW_COLD(), bev=0)
    for k in range(9):
        f = box((0.03, 0.006, 0.22 - k * 0.012), (0, 0.06 + k * 0.012, 0.3 - k * 0.008), CLOTH(), (-0.5 - k * 0.12, 0, (k - 4) * 0.06), 0.002)
    ring(0.13, 0.01, (0, 0, 0.04), BRASS())
    export("raven")


def head_grave_helm():
    """무덤 기사: 통투구, 십자 눈 틈 안의 찬 빛, 숨구멍, 왕관 모양 테."""
    clear()
    h = cyl(0.13, 0.14, 0.27, (0, 0, 0.135), IRON(), 48)
    top = ball(0.135, (0, 0, 0.27), IRON(), (1, 1, 0.45))
    box((0.2, 0.06, 0.022), (0, -0.13, 0.18), DARK(), bev=0.003)
    box((0.022, 0.06, 0.12), (0, -0.13, 0.14), DARK(), bev=0.003)
    box((0.18, 0.01, 0.012), (0, -0.115, 0.18), GLOW_COLD(), bev=0)
    for k in range(6):
        ball(0.006, (-0.05 + (k % 3) * 0.05, -0.135, 0.07 - (k // 3) * 0.02), DARK(), (1, 1, 1), 2)
    ring(0.142, 0.009, (0, 0, 0.27), BRASS())
    for k in range(4):
        a = k / 4 * math.tau
        box((0.015, 0.015, 0.05), (math.cos(a) * 0.14, math.sin(a) * 0.14, 0.3), BRASS(), (0, 0, a), 0.002)
    export("grave_helm")


def head_tomb():
    """무덤 주인: 금 간 묘비, 새긴 십자, 위에 촛불 셋."""
    clear()
    t = box((0.26, 0.08, 0.3), (0, 0, 0.15), STONE(), bev=0.01)
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=0.13, depth=0.08, location=(0, 0, 0.3), rotation=(math.pi / 2, 0, 0))
    a = obj()
    give(a, STONE())
    bpy.ops.object.select_all(action="DESELECT")
    t.select_set(True)
    a.select_set(True)
    bpy.context.view_layer.objects.active = t
    bpy.ops.object.join()
    rough_up(t, 0.006, 0.02, "VORONOI")
    box((0.026, 0.05, 0.15), (0, -0.04, 0.22), DARK(), bev=0)
    box((0.1, 0.05, 0.026), (0, -0.04, 0.25), DARK(), bev=0)
    for k in range(3):
        x = -0.08 + k * 0.08
        cyl(0.014, 0.016, 0.06 + k * 0.01, (x, 0, 0.45 + k * 0.005), BONE(), 16)
        ball(0.01, (x, 0, 0.49 + k * 0.01), GLOW(), (1, 1, 1.8), 2)
    export("tomb")


for fn in (head_hill, head_wolf, head_tower, head_boulder, head_shield, head_marsh, head_pick, head_burnt, head_raven, head_grave_helm, head_tomb):
    fn()
print("머리 %d개를 %s에 만들었다" % (11, os.path.abspath(OUT)))
