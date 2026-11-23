# 「검의 언덕」 최고 등급(무한) 칼 여섯 자루를 Blender로 짓고 .glb로 내보낸다. (2026-11-23)
#
# PC에서 한 번(chongseong 폴더에서, Blender 4.x):
#   "C:\Program Files\Blender Foundation\Blender 4.2\blender.exe" -b -P tools\blender\make_swords.py
# 결과: assets/swords/<칼 번호>.glb. 게임(SwordModel)은 그 번호의 파일이 있으면 코드 모양 대신 그것을 쓴다.
# 도구(재질·굽기·내보내기)는 make_heads.py의 것을 빌린다.
#
# 약속(SwordModel과): 코등이가 원점, 칼날은 +Z(Godot +Y), 손잡이는 -Z, 날은 ±X, 칼 두께는 Y.
# 칼날 길이는 형태 표(data/forms)를 따른다: 단검 0.55, 장검 1.10, 대검 1.61, 세검 1.42(m).
# glow_* 재질은 게임이 등급 빛깔로 바꾼다. ghost_* 는 반투명한 빛(부러진 칼의 옛 칼날).
#
# 여섯 자루(칼 번호 → 모양):
#   292 백 년 전쟁        → 환도(조선의 휜 외날 칼, 꽃잎 코등이, 줄 감은 손잡이, 자루끝 고리와 붉은 술)
#   296 두 번째 기회      → 카타나(휜 외날, 하몬, 둥근 쓰바, 마름모로 감은 손잡이)
#   290 겨울의 끝         → 레이피어(가는 마름모 칼날, 휘감는 손잡이 테와 고리, 은)
#   294 떨어진 검         → 몰락한 왕의 부러진 대검(톱니처럼 빠진 날, 꺾인 자리 너머 반투명한 옛 칼날, 왕관 코등이, 깨진 보석, 해진 천)
#   291 꺼지지 않는 불    → 플랑베르주(불꽃처럼 물결치는 대검 날, 날을 따라 타오르는 빛, 갈고리 리카소)
#   289 그림자 왕         → 그림자 왕의 단검(검은 물결 칼날, 박쥐 날개 코등이, 왕관 자루끝)

import bpy
import bmesh
import math
import os
import random
import sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_heads as K   # noqa: E402

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "swords"))
random.seed(11)


# ================================================================== 칼날 짓기
def blade(name, length, half_w, half_t, mat, curve=0.0, single=True, wave=0.0, waves=0, tip=0.12, segs=90, z0=0.0, profile=None):
    """칼날 하나를 단면을 따라 짓는다.
    half_w(t)·half_t: 칼날 반너비·반두께(t=0 코등이 쪽, 1 칼끝). 함수나 숫자.
    curve: 칼끝이 칼등(-X) 쪽으로 휘는 양(m). single: 외날(칼등 -X, 날 +X)이면 참, 양날이면 거짓.
    wave/waves: 날이 물결치는 크기·수(플랑베르주, 크리스). tip: 칼끝이 좁아지는 구간(비율)."""
    hw = half_w if callable(half_w) else (lambda t, v=half_w: v)
    ht = half_t if callable(half_t) else (lambda t, v=half_t: v)
    bm = bmesh.new()
    rings = []
    for i in range(segs + 1):
        t = i / segs
        w = hw(t)
        th = ht(t)
        if waves > 0:
            w *= 1.0 + wave * math.sin(t * waves * math.pi * 2.0) * (1.0 - t) ** 0.3
        k = 1.0
        if t > 1.0 - tip:
            u = (t - (1.0 - tip)) / tip
            k = max(0.0, 1.0 - u ** 1.6) if single else max(0.02, 1.0 - u)
        cx = -curve * (t ** 1.7)
        z = z0 + t * length
        if profile:
            pts = profile(w, th, k)
        elif single:
            # 외날: 날(+X) 점, 시노기(두께 가장 큰 곳), 칼등(-X)의 등마루. 칼끝 쪽은 칼등 쪽으로 오므린다
            e = -w + 2.0 * w * k
            pts = [(e, 0.0), (-w * 0.3 * k - w * (1 - k), th * max(k, 0.25)), (-w, th * 0.55), (-w * 1.04, 0.0), (-w, -th * 0.55), (-w * 0.3 * k - w * (1 - k), -th * max(k, 0.25))]
        else:
            # 양날: 가운데 등마루가 있는 마름모에 얕은 피홈
            ww = w * k
            tt = th * max(k, 0.2)
            pts = [(ww, 0.0), (ww * 0.45, tt * 0.75), (ww * 0.12, tt * 0.6), (0.0, tt), (-ww * 0.12, tt * 0.6), (-ww * 0.45, tt * 0.75), (-ww, 0.0),
                   (-ww * 0.45, -tt * 0.75), (-ww * 0.12, -tt * 0.6), (0.0, -tt), (ww * 0.12, -tt * 0.6), (ww * 0.45, -tt * 0.75)]
        rings.append([bm.verts.new((cx + px, py, z)) for px, py in pts])
    n = len(rings[0])
    for i in range(segs):
        for j in range(n):
            try:
                bm.faces.new((rings[i][j], rings[i][(j + 1) % n], rings[i + 1][(j + 1) % n], rings[i + 1][j]))
            except ValueError:
                pass
    bm.faces.new(list(reversed(rings[0])))
    try:
        bm.faces.new(rings[-1])
    except ValueError:
        pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.00005)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    K.give(o, mat)
    K.smooth(o)
    return o


def edge_ribbon(length, half_w, mat, side, wave=0.0, waves=0, tip=0.12, z0=0.0, segs=90):
    """날을 따라 붙는 가는 빛 띠(플랑베르주의 타오르는 날)."""
    def prof(w, th, k):
        x = side * w * k
        return [(x + side * 0.0015, 0.0), (x - side * 0.004, 0.0016), (x - side * 0.004, -0.0016)]
    return blade("edge%d" % side, length, half_w, 0.002, mat, 0.0, False, wave, waves, tip, segs, z0, prof)


def grip_wrap(z_top, z_bot, r, mat, n=8, tilt=0.55, scale=(1, 0.8, 1)):
    """마름모로 감은 손잡이 끈: 엇갈려 기운 고리들."""
    for k in range(n):
        z = z_top - (k + 0.5) * (z_top - z_bot) / n
        for s in (-1, 1):
            K.ring(r, r * 0.22, (0, 0, z), mat, (0, s * tilt, 0), scale)


def cord_spiral(z_top, z_bot, r, mat, turns=10):
    """나선으로 감은 줄(환도·레이피어 손잡이)."""
    pts = []
    n = turns * 10
    for i in range(n + 1):
        t = i / n
        a = t * turns * math.tau
        pts.append((math.cos(a) * r, math.sin(a) * r * 0.85, z_top + (z_bot - z_top) * t))
    K.limb(pts, [r * 0.18] * len(pts), mat, 8)


# ================================================================== 칼들
def sword_hwando():
    """환도: 살짝 휜 외날, 끝이 날카롭게 솟는다. 꽃잎 여덟 장 쇠 코등이, 놋쇠 칼코, 상어 가죽 위에 검은 줄을 나선으로,
    자루끝 놋쇠 고리에 붉은 술(유소)."""
    L = 1.10
    blade("blade", L, lambda t: 0.026 - 0.006 * t, 0.0042, "metal_hamon", curve=0.045, single=True, tip=0.1)
    K.box((0.058, 0.016, 0.03), (0.0, 0, -0.012), "metal_brass", bev=0.003)            # 칼코(하바키)
    for k in range(8):                                                                    # 꽃잎 코등이
        a = k / 8 * math.tau
        K.ball(0.022, (math.cos(a) * 0.03, math.sin(a) * 0.03 * 0.7, -0.034), "metal_iron", (1, 1, 0.22), 3)
    K.cyl(0.036, 0.036, 0.008, (0, 0, -0.034), "metal_iron", 48)
    K.ring(0.036, 0.0028, (0, 0, -0.03), "metal_brass")
    K.cyl(0.02, 0.021, 0.02, (0, 0, -0.05), "metal_brass", 32)                           # 손잡이 머리쇠
    K.cyl(0.017, 0.018, 0.2, (0, 0, -0.16), "skin_ray", 32)
    cord_spiral(-0.06, -0.255, 0.0185, "cloth_black", 9)
    K.cyl(0.019, 0.017, 0.022, (0, 0, -0.27), "metal_brass", 32)                         # 자루끝
    K.ring(0.016, 0.0035, (0, 0, -0.296), "metal_brass", (math.pi / 2, 0, 0))            # 고리
    for k in range(9):                                                                    # 붉은 술
        a = k / 9 * math.tau
        K.limb([(0, 0, -0.31), (math.cos(a) * 0.012, math.sin(a) * 0.012, -0.36), (math.cos(a) * 0.016 + 0.01, math.sin(a) * 0.016, -0.43 - k * 0.003)], [0.003, 0.0028, 0.002], "cloth_red", 6)
    K.ball(0.01, (0, 0, -0.31), "cloth_red", (1, 1, 1.4), 3)


def sword_katana():
    """카타나: 휜 외날과 하몬, 물방울처럼 솟는 칼끝(기시사키), 놋쇠 하바키, 구멍 뚫린 둥근 쓰바와 세파,
    흰 상어 가죽 위로 남색 끈을 마름모로 감은 손잡이, 메누키 장식, 검은 쇠 카시라."""
    L = 1.10
    blade("blade", L, lambda t: 0.024 - 0.004 * t, 0.0038, "metal_hamon", curve=0.06, single=True, tip=0.09)
    K.box((0.052, 0.014, 0.028), (-0.002, 0, -0.012), "metal_brass", bev=0.002)
    for z in (-0.028, -0.046):
        K.cyl(0.03, 0.03, 0.003, (0, 0, z), "metal_brass", 48, (0, 0, 0))
    tsuba = K.cyl(0.042, 0.042, 0.007, (0, 0, -0.037), "metal_dark", 64)
    for sx in (-1, 1):
        bpy.ops.mesh.primitive_cylinder_add(radius=0.007, depth=0.03, location=(sx * 0.028, 0, -0.037))
        K.cut(tsuba, bpy.context.active_object)
    K.ring(0.042, 0.0022, (0, 0, -0.037), "metal_gold")
    K.cyl(0.017, 0.018, 0.018, (0, 0, -0.057), "metal_dark", 32)                          # 후치
    K.cyl(0.0155, 0.0165, 0.24, (0, 0, -0.186), "skin_ray", 32)
    grip_wrap(-0.066, -0.3, 0.0168, "cloth_navy", 9, 0.6, (1, 0.78, 1))
    for sx in (-1, 1):
        K.ball(0.008, (0, sx * 0.014, -0.17 + sx * 0.03), "metal_gold", (1.8, 0.5, 1), 3)    # 메누키
    K.ball(0.018, (0, 0, -0.31), "metal_dark", (1, 0.82, 0.7), 4)                         # 카시라


def sword_rapier():
    """레이피어(겨울의 끝): 아주 가는 마름모 칼날, 곧은 키용, 손등을 감싸는 활 모양 테, 양쪽의 고리와 휘어 감기는 가지, 은과 놋쇠,
    은실을 감은 손잡이, 달걀 모양 자루끝."""
    L = 1.42
    blade("blade", L, lambda t: 0.012 - 0.004 * t, 0.0045, "metal_silver", single=False, tip=0.2)
    K.box((0.03, 0.012, 0.06), (0, 0, 0.03), "metal_silver", bev=0.004)                    # 리카소
    K.limb([(-0.13, 0, -0.012), (0.0, 0, -0.012), (0.13, 0, -0.012)], [0.005, 0.007, 0.005], "metal_silver", 12)
    for sx in (-1, 1):
        K.ball(0.01, (sx * 0.13, 0, -0.012), "metal_gold", sub=3)
    # 손등 테: 코등이에서 자루끝까지 활처럼
    K.limb(K.arc((0.03, 0, -0.012), (0.02, 0, -0.17), (0.06, 0, 0), 8), [0.0045] * 9, "metal_silver", 10)
    # 양쪽 고리와 휘감는 가지
    for sy in (-1, 1):
        K.ring(0.032, 0.0035, (0.0, sy * 0.02, 0.02), "metal_silver", (math.pi / 2, 0, 0))
        for k in range(3):
            K.limb(K.arc((0.0, 0, -0.012), (0.04 + k * 0.012, sy * 0.01, -0.15 + k * 0.03), (0.03, sy * (0.03 + k * 0.012), 0.0), 8), [0.0035] * 9, "metal_silver" if k != 1 else "metal_gold", 8)
    K.cyl(0.012, 0.013, 0.13, (0, 0, -0.08), "leather_dark", 24)
    cord_spiral(-0.02, -0.14, 0.0135, "metal_silver", 12)
    K.ball(0.022, (0, 0, -0.17), "metal_silver", (1, 1, 1.3), 4)
    K.ball(0.008, (0, 0, -0.2), "metal_gold", sub=3)


def sword_fallen_king():
    """몰락한 왕의 부러진 대검(떨어진 검): 넓은 양날 대검이 3분의 2쯤에서 비스듬히 꺾였고, 날 곳곳이 톱니처럼 빠졌다.
    꺾인 자리 너머로 옛 칼날의 혼이 반투명하게 이어진다. 왕관 모양 코등이 가운데 깨진 보석, 해진 붉은 천이 감긴 손잡이, 왕관 자루끝."""
    L = 1.61
    b = blade("blade", L, lambda t: 0.07 - 0.025 * t, 0.007, "metal_dark", single=False, tip=0.15)
    # 꺾인 자리: 비스듬한 큰 상자로 위를 잘라 낸다(잘린 면은 울퉁불퉁하게)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0.0, 0, 1.06 + 0.4), rotation=(0, 0.45, 0))
    c = bpy.context.active_object
    c.scale = (0.5, 0.2, 0.8)
    K.cut(b, c)
    for k in range(7):                                                                    # 빠진 날
        z = random.uniform(0.15, 0.95)
        sx = random.choice((-1, 1))
        bpy.ops.mesh.primitive_ico_sphere_add(radius=random.uniform(0.008, 0.018), location=(sx * (0.07 - 0.025 * z / L), 0, z))
        K.cut(b, bpy.context.active_object)
    K.bevel(b, 0.0012, 2)
    blade("ghost", L - 0.95, lambda t: (0.07 - 0.025 * (0.6 + 0.4 * t)), 0.006, "ghost_blade", single=False, tip=0.25, z0=0.95, segs=40)
    # 왕관 코등이
    K.box((0.36, 0.05, 0.045), (0, 0, -0.022), "metal_gold", bev=0.008)
    for k in range(5):
        x = -0.14 + k * 0.07
        K.limb([(x, 0, 0.0), (x, 0, 0.045 + (0.02 if k == 2 else 0.0))], [0.012, 0.0], "metal_gold", 6)
        K.ball(0.008, (x, 0, 0.05 + (0.02 if k == 2 else 0.0)), "metal_gold", sub=2)
    for sx in (-1, 1):
        K.limb(K.arc((sx * 0.18, 0, -0.022), (sx * 0.22, 0, 0.05), (sx * 0.02, 0, 0), 5), [0.012 - i * 0.0018 for i in range(6)], "metal_gold", 10)
    gem = K.ball(0.026, (0, -0.026, -0.02), "glow_edge", (1, 0.6, 1.2), 3)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0.015, -0.04, -0.005), rotation=(0.3, 0.6, 0.4))
    cc = bpy.context.active_object
    cc.scale = (0.03, 0.03, 0.03)
    K.cut(gem, cc)                                                                        # 깨진 보석
    K.cyl(0.024, 0.026, 0.34, (0, 0, -0.215), "leather_dark", 24)
    grip_wrap(-0.05, -0.38, 0.026, "cloth_red", 7, 0.5)
    for k in range(3):                                                                    # 해진 천 자락
        K.box((0.03, 0.002, 0.14 + k * 0.04), (0.02 + k * 0.012, 0.028, -0.2 - k * 0.04), "cloth_red", (0.1, 0, 0.15 * k), 0.0005)
    K.cyl(0.04, 0.03, 0.03, (0, 0, -0.4), "metal_gold", 8)                                 # 왕관 자루끝
    for k in range(8):
        a = k / 8 * math.tau
        K.limb([(math.cos(a) * 0.035, math.sin(a) * 0.035, -0.415), (math.cos(a) * 0.04, math.sin(a) * 0.04, -0.45)], [0.006, 0.0], "metal_gold", 4)


def sword_flamberge():
    """플랑베르주(꺼지지 않는 불): 불꽃처럼 물결치는 양날 대검, 날을 따라 타오르는 빛 띠, 날 없는 리카소와 갈고리 돌기,
    곧고 긴 코등이 끝의 소용돌이, 두 손 손잡이, 무거운 자루끝."""
    L = 1.61
    hw = lambda t: 0.052 - 0.014 * t
    blade("blade", L - 0.18, hw, 0.0065, "metal_dark", single=False, wave=0.2, waves=11, tip=0.14, z0=0.18)
    for side in (-1, 1):
        edge_ribbon(L - 0.18, hw, "glow_edge", side, 0.2, 11, 0.14, 0.18)
        K.limb(K.arc((side * 0.03, 0, 0.16), (side * 0.085, 0, 0.2), (side * 0.0, 0, 0.03), 5), [0.012, 0.012, 0.011, 0.009, 0.007, 0.004], "metal_iron", 10)
    K.box((0.06, 0.013, 0.19), (0, 0, 0.09), "metal_iron", bev=0.004)                     # 리카소
    K.limb([(-0.26, 0, -0.015), (0, 0, -0.015), (0.26, 0, -0.015)], [0.011, 0.014, 0.011], "metal_iron", 12)
    for sx in (-1, 1):
        K.limb(K.arc((sx * 0.26, 0, -0.015), (sx * 0.27, 0, 0.04), (sx * 0.04, 0, 0.0), 6), [0.011 - i * 0.0012 for i in range(7)], "metal_iron", 10)
    K.cyl(0.022, 0.024, 0.4, (0, 0, -0.23), "leather_dark", 24)
    grip_wrap(-0.04, -0.42, 0.023, "leather_dark", 8, 0.45)
    K.ring(0.026, 0.004, (0, 0, -0.04), "metal_iron")
    K.ball(0.04, (0, 0, -0.46), "metal_iron", (1, 0.7, 1.1), 4)


def sword_shadow_king():
    """그림자 왕의 단검: 검고 물결치는 양날(크리스처럼), 등마루를 따라 찬 빛, 박쥐 날개처럼 아래로 휜 코등이, 왕관 자루끝."""
    L = 0.55
    hw = lambda t: 0.028 - 0.01 * t
    blade("blade", L, hw, 0.005, "metal_dark", single=False, wave=0.3, waves=5, tip=0.22)
    blade("spine_glow", L * 0.85, lambda t: 0.0018, 0.0058, "glow_edge", single=False, tip=0.2, segs=40)
    for sx in (-1, 1):
        K.limb(K.arc((0, 0, -0.01), (sx * 0.1, 0, -0.05), (0, 0, 0.04), 6), [0.009, 0.008, 0.007, 0.006, 0.004, 0.003, 0.0], "metal_dark", 10)
        for k in range(2):
            K.limb(K.arc((sx * (0.03 + k * 0.03), 0, 0.005), (sx * (0.05 + k * 0.035), 0, -0.04), (0, 0, -0.01), 4), [0.003, 0.0025, 0.002, 0.0015, 0.0], "metal_dark", 6)
    K.cyl(0.013, 0.014, 0.11, (0, 0, -0.065), "leather_dark", 24)
    cord_spiral(-0.015, -0.115, 0.0142, "metal_silver", 8)
    K.cyl(0.024, 0.017, 0.022, (0, 0, -0.13), "metal_gold", 8)
    for k in range(6):
        a = k / 6 * math.tau
        K.limb([(math.cos(a) * 0.02, math.sin(a) * 0.02, -0.142), (math.cos(a) * 0.024, math.sin(a) * 0.024, -0.168)], [0.004, 0.0], "metal_gold", 4)
    K.ball(0.009, (0, 0, -0.15), "glow_edge", sub=3)


SWORDS = {
    "292": sword_hwando,
    "296": sword_katana,
    "290": sword_rapier,
    "294": sword_fallen_king,
    "291": sword_flamberge,
    "289": sword_shadow_king,
}

if __name__ == "__main__":
    K.run_all(SWORDS, OUT, 1024, "칼")
