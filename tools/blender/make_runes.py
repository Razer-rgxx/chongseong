# 검의 기억 룬 8종(docs/sword_memory.md "룬 모델 약속")을 Blender로 짓고 .glb로 내보낸다. (2026-11-26)
#
# 한 번(chongseong 폴더에서):
#   blender -b -P tools/blender/make_runes.py [-- 키 ...]
# Blender가 없으면 pip의 bpy 모듈로 `python tools/blender/make_runes.py [키 ...]`.
# 결과: assets/runes/<키>.glb (질감 512). 키는 data/runes.tres의 rune_order(룬 종류).
#
# 모양: 손가락 마디만 한 어두운 돌·쇠 조각(종류마다 생김새가 다른 파편·판)에 깊게 판 각진 문양, 홈 바닥만 차가운 푸른 빛.
# 문양은 마름모 테두리와 V자가 바탕이다:
#   keen 예리 = 날카로운 꺾쇠 둘(긴 쐐기 파편)       night 밤 = 초승달로 깎은 마름모(둥근 파편)
#   day 낮   = 작은 마름모에서 곧게 뻗는 빛살(비석)  hunt 사냥 = 화살 V와 살대·깃(화살촉 판)
#   wind 바람 = 비스듬한 줄 셋(기운 판)              grit 불굴 = 두꺼운 마름모와 꽉 찬 속(두꺼운 덩어리)
#   chain 연쇄 = 줄로 이어진 V 셋(긴 육각 고리판)     elite 정예 = 겹친 마름모 둘(방패판)
# 단계 장식은 파일 안의 따로 된 노드(재질 이름이 노드 이름): glow_rune_t2(빛 상감 점 둘), rune_inlay_t3(은 상감 테두리)·glow_rune_t3(점 둘 더).
# 게임(CarveOverlay.show_tier)이 단계에 맞춰 켜고 끈다(단계는 파일을 나누지 않는다).
# 약속(docs/sword_memory.md "룬 모델 약속"): 원점은 모델 가운데, 가장 긴 변이 1.0, 무늬 앞면이 Godot +Z(Blender -Y), 위는 Godot +Y(Blender +Z),
# 두께는 가장 긴 변의 0.15 아래(불굴만 0.15, 나머지 0.12). 정점 800 아래. 짓기는 cm 크기로 하고(굽기의 깎은 모서리·AO가 그 크기에 맞다) 구운 뒤 1.0으로 줄인다.
#
# 짓는 법: 조각 윤곽을 bmesh로 세우고 모서리를 조금 깎은 뒤, 문양 획(각진 막대)과 꽉 찬 면을 불리언으로 파낸다.
# 판 홈의 바닥(앞을 보는 면 중 앞면보다 깊은 것)만 glow_rune로 바꾸고, 홈 벽은 조각 재질이라 AO가 구워져 깊어 보인다.

import bmesh
import math
import traceback
import os
import random
import sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_swords as MS   # noqa: E402  (재질 _kat_mat을 빌린다)
import make_heads as K     # noqa: E402

bpy = MS.bpy
OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "runes"))
SIZE = 512
U = 0.01          # 문양 단위 1 = 1cm (조각 높이 약 ±1.3)
DEPTH = 0.0014    # 홈 깊이
STROKE = 0.16     # 획 너비(단위)
BLUE = (0.35, 0.72, 1.0)

K.GLOWS.update({
    "glow_rune": ((0.08, 0.22, 0.4), BLUE, 6.0),
    "glow_rune_t2": ((0.08, 0.22, 0.4), BLUE, 5.0),
    "glow_rune_t3": ((0.1, 0.26, 0.45), (0.55, 0.85, 1.0), 5.0),
})


def _mats():
    MS._kat_mat("rune_stone", (0.042, 0.044, 0.05), 0.86, 0.0, "plate")
    MS._kat_mat("rune_iron", (0.05, 0.051, 0.056), 0.52, 1.0, "plate")
    MS._kat_mat("rune_inlay_t3", (0.6, 0.64, 0.68), 0.3, 1.0, "pale")


# ================================================================== 문양 정의(단위 좌표, x 가로, y 위)
def diamond(cx, cy, hx, hy):
    return [(cx, cy + hy), (cx + hx, cy), (cx, cy - hy), (cx - hx, cy)]


def arc(cx, cy, r, a0, a1, n):
    return [(cx + math.cos(math.radians(a0 + (a1 - a0) * k / n)) * r, cy + math.sin(math.radians(a0 + (a1 - a0) * k / n)) * r) for k in range(n + 1)]


# 종류: 윤곽(볼록에 가까운 파편), 두께, 재질, 획(열린 줄 [점…] 또는 ("closed", [점…])), 꽉 찬 면, 굵은 획 배수
RUNES = {
    "keen": dict(outline=[(0.0, 1.5), (0.42, 0.55), (0.5, -0.85), (0.16, -1.32), (-0.34, -1.18), (-0.5, -0.38), (-0.38, 0.62)],
                 t=0.12, mat="rune_iron",
                 strokes=[[(-0.3, -0.12), (0.0, 0.58), (0.3, -0.12)], [(-0.3, -0.72), (0.0, -0.02), (0.3, -0.72)], [(0.0, 0.82), (0.0, 1.12)]]),
    "night": dict(outline=[(0.0, 1.1), (0.72, 0.82), (1.02, 0.08), (0.8, -0.72), (0.18, -1.08), (-0.55, -0.92), (-0.98, -0.25), (-0.86, 0.58)],
                  t=0.12, mat="rune_stone",
                  strokes=[("closed", diamond(0.0, 0.0, 0.62, 0.8)), arc(0.14, 0.02, 0.4, 70, 290, 7), arc(0.36, 0.02, 0.34, 100, 260, 5)]),
    "day": dict(outline=[(-0.52, 1.3), (0.5, 1.26), (0.62, 1.1), (0.64, -1.12), (0.5, -1.28), (-0.5, -1.26), (-0.62, -1.1), (-0.6, 1.14)],
                t=0.12, mat="rune_stone",
                strokes=[("closed", diamond(0.0, 0.66, 0.26, 0.32)), [(0.0, 0.3), (0.0, -0.98)], [(-0.1, 0.34), (-0.42, -0.86)], [(0.1, 0.34), (0.42, -0.86)]]),
    "hunt": dict(outline=[(0.0, 1.38), (0.86, -0.5), (0.52, -1.06), (-0.5, -1.02), (-0.9, -0.48)],
                 t=0.12, mat="rune_iron",
                 strokes=[[(-0.4, 0.0), (0.0, 0.66), (0.4, 0.0)], [(0.0, 0.62), (0.0, -0.72)], [(-0.24, -0.86), (0.0, -0.6), (0.24, -0.86)]]),
    "wind": dict(outline=[(-0.78, -1.12), (0.24, -1.16), (0.82, 1.1), (-0.2, 1.16)],
                 t=0.12, mat="rune_stone",
                 strokes=[[(-0.5, -0.78), (0.06, 0.82)], [(-0.16, -0.86), (0.4, 0.74)], [(0.2, -0.86), (0.48, 0.0)], [(-0.46, 0.12), (-0.26, 0.7)]]),
    "grit": dict(outline=[(-0.86, -0.78), (-0.6, -0.96), (0.8, -0.9), (0.92, -0.6), (0.88, 0.78), (0.6, 0.94), (-0.74, 0.9), (-0.9, 0.62)],
                 t=0.15, mat="rune_stone", wide=1.8,
                 strokes=[("closed", diamond(0.0, 0.0, 0.58, 0.66))],
                 fill=[diamond(0.0, 0.0, 0.2, 0.24)]),
    "chain": dict(outline=[(0.0, 1.34), (0.52, 0.88), (0.52, -0.88), (0.0, -1.34), (-0.52, -0.88), (-0.52, 0.88)],
                  t=0.12, mat="rune_iron",
                  strokes=[[(-0.28, 0.92), (0.0, 0.52), (0.28, 0.92)], [(0.0, 0.52), (0.0, 0.26)],
                           [(-0.28, 0.26), (0.0, -0.14), (0.28, 0.26)], [(0.0, -0.14), (0.0, -0.4)],
                           [(-0.28, -0.4), (0.0, -0.8), (0.28, -0.4)]]),
    "elite": dict(outline=[(0.0, 1.22), (0.7, 0.86), (0.82, -0.18), (0.42, -1.0), (0.0, -1.26), (-0.42, -1.0), (-0.82, -0.18), (-0.7, 0.86)],
                  t=0.12, mat="rune_iron",
                  strokes=[("closed", diamond(0.0, 0.26, 0.46, 0.58)), ("closed", diamond(0.0, -0.26, 0.46, 0.58)), [(0.0, 0.98), (0.0, 1.0)]]),
}
ORDER = ["keen", "night", "day", "hunt", "wind", "grit", "chain", "elite"]


# ================================================================== 짓기
def _prism(bm, poly, y0, y1):
    """단위 좌표 다각형(x, z) → y0~y1 사이 각기둥(앞이 -Y)."""
    a = [bm.verts.new((x * U, y0, z * U)) for x, z in poly]
    b = [bm.verts.new((x * U, y1, z * U)) for x, z in poly]
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    n = len(poly)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([a[i], a[j], b[j], b[i]])


def _seg_quad(p, q, w):
    """p → q 획의 사각형(양 끝을 w/2만큼 늘려 꺾인 자리를 채운다)."""
    p, q = Vector(p), Vector(q)
    d = (q - p)
    if d.length < 1e-6:
        d = Vector((0.0, 1.0))
    d.normalize()
    nrm = Vector((-d.y, d.x)) * (w / 2.0)
    p2, q2 = p - d * (w / 2.0), q + d * (w / 2.0)
    return [tuple(p2 - nrm), tuple(q2 - nrm), tuple(q2 + nrm), tuple(p2 + nrm)]


def _mesh_obj(name, bm, mats):
    me = bpy.data.meshes.new(name)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    for m in mats:
        me.materials.append(K.mat(m))
    return o


def _jitter(poly, seed, amt=0.04):
    r = random.Random(seed)
    return [(x + r.uniform(-amt, amt), y + r.uniform(-amt, amt)) for x, y in poly]


def make(key):
    _mats()
    R = RUNES[key]
    seed = ORDER.index(key) * 13 + 5
    outline = _jitter(R["outline"], seed)
    ext = max(max(p[0] for p in outline) - min(p[0] for p in outline), max(p[1] for p in outline) - min(p[1] for p in outline)) * U
    t = R["t"] * ext   # 두께 = 가장 긴 변의 몫
    yf = -t   # 앞면
    # 조각
    bm = bmesh.new()
    _prism(bm, outline, 0.0, yf)
    plate = _mesh_obj("rune_" + key, bm, [R["mat"], "glow_rune"])
    bev = plate.modifiers.new("bev", "BEVEL")
    bev.width = 0.0005
    bev.segments = 1
    bev.limit_method = "ANGLE"
    K.only(plate)
    bpy.ops.object.modifier_apply(modifier="bev")
    # 문양 자르개(한 덩이)
    w = STROKE * R.get("wide", 1.0)
    cb = bmesh.new()
    for st in R["strokes"]:
        closed = isinstance(st, tuple)
        pts = st[1] if closed else st
        segs = list(zip(pts, pts[1:])) + ([(pts[-1], pts[0])] if closed else [])
        for p, q in segs:
            _prism(cb, _seg_quad(p, q, w), yf - 0.002, yf + DEPTH)
    for poly in R.get("fill", []):
        _prism(cb, poly, yf - 0.002, yf + DEPTH)
    cutter = _mesh_obj("cut_" + key, cb, [])
    boo = plate.modifiers.new("cut", "BOOLEAN")
    boo.operation = "DIFFERENCE"
    boo.object = cutter
    boo.solver = "EXACT"
    try:
        boo.use_self = True   # 자르개 획이 서로 겹친다
    except Exception:
        pass
    K.only(plate)
    bpy.ops.object.modifier_apply(modifier="cut")
    bpy.data.objects.remove(cutter, do_unlink=True)
    # 홈 바닥 = 빛
    me = plate.data
    for f in me.polygons:
        f.material_index = 1 if (f.normal.y < -0.9 and f.center.y > yf + DEPTH * 0.5) else 0
    K.smooth(plate)
    # 단계 장식: 2단계 빛 상감 점 둘(위·아래), 3단계 은 상감 테두리와 점 둘 더(좌·우)
    cx = sum(p[0] for p in outline) / len(outline)
    cy = sum(p[1] for p in outline) / len(outline)
    top = max(outline, key=lambda p: p[1])
    bot = min(outline, key=lambda p: p[1])
    lef = min(outline, key=lambda p: p[0])
    rig = max(outline, key=lambda p: p[0])

    def stud(gl, p, k=0.8, s=0.075):
        x, y = cx + (p[0] - cx) * k, cy + (p[1] - cy) * k
        _prism(gl, diamond(x, y, s, s * 1.3), yf + 0.0003, yf - 0.00025)

    g2 = bmesh.new()
    stud(g2, top)
    stud(g2, bot)
    _mesh_obj("t2_" + key, g2, ["glow_rune_t2"])
    g3 = bmesh.new()
    stud(g3, lef, 0.78)
    stud(g3, rig, 0.78)
    _mesh_obj("t3g_" + key, g3, ["glow_rune_t3"])
    # 은 상감 테두리: 윤곽 안쪽 띠(바깥 0.09 · 안 0.15 안으로)
    outer = MS._kat_inset(outline, 0.09)
    inner = MS._kat_inset(outline, 0.15)
    ib = bmesh.new()
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        _prism(ib, [outer[i], outer[j], inner[j], inner[i]], yf + 0.0002, yf - 0.0002)
    _mesh_obj("t3_" + key, ib, ["rune_inlay_t3"])
    nv = sum(len(o.data.vertices) for o in bpy.context.scene.objects if o.type == "MESH")
    print("%s 정점 %d, 가장 긴 변 %.1fmm, 두께 %.1fmm" % (key, nv, ext * 1000.0, t * 1000.0))
    cx_m = (max(p[0] for p in outline) + min(p[0] for p in outline)) / 2.0 * U
    cz_m = (max(p[1] for p in outline) + min(p[1] for p in outline)) / 2.0 * U
    return Vector((-cx_m, t / 2.0, -cz_m)), 1.0 / ext


def finish(name, off, k):
    """make_heads.finish와 같되, 구운 뒤 내보내기 전에 모든 정점을 (v + off) × k로(가운데 원점, 가장 긴 변 1.0)."""
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    try:
        sc.cycles.device = "CPU"
    except Exception:
        pass
    K._apply_all()
    K._split_by_material()
    groups = K._join_groups()
    for gname, o in groups.items():
        if gname.startswith("glow"):
            continue
        try:
            K._bake(o, "%s_%s" % (name, gname), SIZE)
        except Exception:
            print("굽기 실패(굽지 않고 내보낸다):", name, gname)
            traceback.print_exc()
            if bpy.context.object and bpy.context.object.mode != "OBJECT":
                bpy.ops.object.mode_set(mode="OBJECT")
    for o in groups.values():
        for v in o.data.vertices:
            v.co = (v.co + off) * k
        o.data.update()
    bpy.ops.object.select_all(action="SELECT")
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".glb")
    kw = dict(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True)
    try:
        bpy.ops.export_scene.gltf(export_image_format="JPEG", **kw)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)
    try:
        import glb_icc
        glb_icc.strip_glb(path)
    except Exception:
        traceback.print_exc()
    print("만듦", path)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    want = [a for a in args if a in RUNES] or ORDER
    made, failed = [], []
    for key in want:
        try:
            K.clear()
            off, k = make(key)
            finish(key, off, k)
            made.append(key)
        except Exception:
            traceback.print_exc()
            failed.append(key)
    print("룬 %d개를 %s에 만들었다. 실패: %s" % (len(made), OUT, ", ".join(failed) or "없음"))
