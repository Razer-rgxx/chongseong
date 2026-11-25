# 「검의 언덕」 최고 등급(무한) 칼 열세 자루(무한 전부)를 Blender로 짓고 .glb로 내보낸다. (2026-11-23)
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
#   293 피의 왕좌         → 기사 왕의 장검(핏빛 피홈, 왕좌 팔걸이 코등이, 보석)
#   297 모든 검의 어머니  → 사인검(곧은 조선 양날, 칼날의 별자리)
#   299 처음이자 마지막 칼 → 비파형 동검(청동, 비파 모양 칼날, 돌 자루끝 추)
#   300 이름을 잃은 검    → 지워진 이름의 단도(흰 나무 손잡이, 긁힌 각인)
#   295 망각              → 빛으로만 남은 컵 손잡이 레이피어
#   288 언덕의 심장       → 창살 속 심장이 뛰는 두 손 대검(핏줄 같은 빛)
#   298 언덕              → 이끼 낀 돌 대검에 작은 칼들이 꽂혔다
#   311 사이버 카타나     → (2026-11-25, 들판 한정) 곧은 외날, 날 끝 청록, 기계 덮개와 네온관, 네온 고리 코등이, 두 손 손잡이.
#                            아래 "사이버 카타나" 절. 하나만 다시 만들기: blender -b -P tools/blender/make_swords.py -- 311

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


# ------------------------------------------------------------------ 2026-11-23 추가 일곱 자루(무한 등급 전부)
def sword_blood_throne():
    """피의 왕좌: 기사 왕의 곧은 장검. 피홈을 따라 핏빛이 흐르고, 금 십자 코등이 끝이 왕좌의 팔걸이처럼 말려 오른다.
    가운데 붉은 보석, 붉은 천 손잡이, 수레바퀴 자루끝에도 보석."""
    L = 1.10
    hw = lambda t: 0.034 - 0.01 * t
    blade("blade", L, hw, 0.006, "metal_steel", single=False, tip=0.14)
    blade("fuller", L * 0.72, lambda t: 0.0045 - 0.002 * t, 0.0063, "glow_edge", single=False, tip=0.3, z0=0.04, segs=40)
    K.box((0.28, 0.03, 0.03), (0, 0, -0.015), "metal_gold", bev=0.006)
    for sx in (-1, 1):
        K.limb(K.arc((sx * 0.14, 0, -0.015), (sx * 0.15, 0, 0.06), (sx * 0.04, 0, -0.01), 6), [0.013 - i * 0.0013 for i in range(7)], "metal_gold", 10)
        K.ball(0.012, (sx * 0.15, 0, 0.065), "metal_gold", sub=3)
    K.box((0.06, 0.036, 0.05), (0, 0, -0.012), "metal_gold", bev=0.008)
    for sy in (-1, 1):
        K.ball(0.012, (0, sy * 0.02, -0.012), "glow_edge", (1, 0.5, 1.3), 3)
    K.cyl(0.016, 0.017, 0.19, (0, 0, -0.125), "cloth_red", 24)
    grip_wrap(-0.03, -0.215, 0.017, "metal_gold", 4, 0.0)
    K.cyl(0.04, 0.04, 0.018, (0, 0, -0.245), "metal_gold", 48, (math.pi / 2, 0, 0))
    K.ring(0.04, 0.004, (0, 0, -0.245), "metal_gold", (math.pi / 2, 0, 0))
    for sy in (-1, 1):
        K.ball(0.011, (0, sy * 0.01, -0.245), "glow_edge", (1, 0.6, 1), 3)


def sword_sain():
    """모든 검의 어머니(사인검): 곧고 가는 조선의 양날 검. 칼날 양면에 별자리가 박혀 빛나고 별끼리 가는 빛줄로 잇는다.
    은 테를 두른 둥근 코등이, 상어 가죽에 남색 줄, 놋쇠 자루끝 고리에 남색 술."""
    L = 1.10
    hw = lambda t: 0.024 - 0.006 * t
    th = 0.0055
    blade("blade", L, hw, th, "metal_steel", single=False, tip=0.12)
    rnd = random.Random(4)
    for sy in (-1, 1):
        stars = []
        for k in range(14):
            z = 0.06 + k * 0.062 + rnd.uniform(-0.015, 0.015)
            x = rnd.uniform(-0.6, 0.6) * hw(z / L) * 0.55
            stars.append((x, sy * (th + 0.0008), z))
        for i, p in enumerate(stars):
            K.ball(0.0032 if i % 3 else 0.0045, p, "glow_edge", (1, 0.4, 1), 2)
            if i > 0:
                K.limb([stars[i - 1], p], [0.0007, 0.0007], "glow_edge", 4)
    K.cyl(0.03, 0.03, 0.007, (0, 0, -0.008), "metal_iron", 48, (0, 0, 0))
    K.ring(0.03, 0.0025, (0, 0, -0.008), "metal_silver")
    K.cyl(0.016, 0.017, 0.2, (0, 0, -0.112), "skin_ray", 32)
    cord_spiral(-0.015, -0.21, 0.0172, "cloth_navy", 9)
    K.cyl(0.018, 0.016, 0.02, (0, 0, -0.222), "metal_brass", 32)
    K.ring(0.014, 0.0032, (0, 0, -0.243), "metal_brass", (math.pi / 2, 0, 0))
    for k in range(8):
        a = k / 8 * math.tau
        K.limb([(0, 0, -0.256), (math.cos(a) * 0.012, math.sin(a) * 0.012, -0.3), (math.cos(a) * 0.015, math.sin(a) * 0.015, -0.37)], [0.0028, 0.0026, 0.0018], "cloth_navy", 6)


def sword_bronze():
    """처음이자 마지막 칼(비파형 동검): 비파처럼 아래가 불룩하고 허리에 돌기가 솟은 청동 칼날, 가운데 둥근 등대,
    T자 청동 손잡이, 돌로 된 자루끝 추(검파두식). 녹청이 앉았다."""
    L = 1.10

    def hw(t):
        bulge = 0.042 * math.sin(math.pi * min(t / 0.62, 1.0)) ** 0.8
        notch = 0.012 * math.exp(-((t - 0.6) / 0.03) ** 2)
        return 0.016 + bulge * (1.0 if t < 0.62 else 0.0) + notch + (0.012 * (1.0 - t) if t >= 0.62 else 0.0)

    def prof(w, th, k):
        ww = w * k
        r1 = min(0.012, ww * 0.6)     # 등대(가운데 둥근 마루): 칼끝으로 갈수록 같이 가늘어진다
        r2 = min(0.006, ww * 0.3)
        tr = th * (0.5 + 1.1 * k)
        return [(ww, 0.0), (max(ww * 0.5, r1 * 1.05), th * 0.35), (r1, th * 0.7), (r2, tr), (-r2, tr), (-r1, th * 0.7), (-max(ww * 0.5, r1 * 1.05), th * 0.35), (-ww, 0.0),
                (-max(ww * 0.5, r1 * 1.05), -th * 0.35), (-r1, -th * 0.7), (-r2, -tr), (r2, -tr), (r1, -th * 0.7), (max(ww * 0.5, r1 * 1.05), -th * 0.35)]
    blade("blade", L, hw, 0.0065, "metal_bronze", single=False, tip=0.1, profile=prof, segs=120)
    K.cyl(0.014, 0.016, 0.06, (0, 0, -0.02), "metal_bronze", 24)
    K.limb([(-0.07, 0, -0.05), (0, 0, -0.05), (0.07, 0, -0.05)], [0.012, 0.016, 0.012], "metal_bronze", 12)
    K.cyl(0.015, 0.016, 0.17, (0, 0, -0.14), "metal_bronze", 24)
    for k in range(5):
        K.ring(0.0165, 0.003, (0, 0, -0.07 - k * 0.035), "metal_bronze")
    w = K.ball(0.035, (0, 0, -0.24), "stone_dark", (1.6, 0.8, 0.7), 4)
    K.displace(w, 0.004, 0.02, "VORONOI")


def sword_nameless():
    """이름을 잃은 검: 코등이 없는 흰 나무 칼집 손잡이(시라사야)의 짧은 외날. 칼날에 새긴 이름은 긁혀 지워졌고,
    그 자국만 희미하게 빛난다. 손잡이에 금이 갔다."""
    L = 0.55
    blade("blade", L, lambda t: 0.019 - 0.003 * t, 0.0045, "metal_hamon", curve=0.012, single=True, tip=0.14)
    rnd = random.Random(9)
    for k in range(6):
        z = 0.05 + k * 0.028
        K.box((0.004 + rnd.uniform(0, 0.006), 0.0006, 0.012), (-0.008 + rnd.uniform(-0.002, 0.002), 0.0047, z), "glow_edge", (0, 0, rnd.uniform(-0.8, 0.8)), 0)
    K.box((0.042, 0.013, 0.022), (-0.001, 0, -0.008), "metal_brass", bev=0.002)
    h = K.cyl(0.019, 0.017, 0.14, (0, 0, -0.088), "wood_pale", 32)
    h.scale = (1.0, 0.72, 1.0)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0.015, 0, -0.11), rotation=(0, 0.3, 0))
    c = bpy.context.active_object
    c.scale = (0.003, 0.05, 0.05)
    K.cut(h, c)
    K.cyl(0.0195, 0.0195, 0.006, (0, 0, -0.161), "wood_pale", 32)


def sword_oblivion():
    """망각: 칼날이 반투명한 빛으로만 남은 레이피어. 그 안에 은빛 심 하나. 구멍 뚫린 반구 컵 코등이, 끝이 구슬인 곧은 키용,
    손등 테, 은실 손잡이, 둥근 자루끝."""
    L = 1.42
    blade("ghost", L, lambda t: 0.013 - 0.004 * t, 0.005, "ghost_blade", single=False, tip=0.2)
    blade("core", L * 0.96, lambda t: 0.0016, 0.0016, "metal_silver", single=False, tip=0.1)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.065, location=(0, 0, -0.005), segments=48, ring_count=24)
    cup = bpy.context.active_object
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.09))
    top = bpy.context.active_object
    top.scale = (0.2, 0.2, 0.2)
    K.cut(cup, top)
    K.give(cup, "metal_silver")
    sol = cup.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = 0.003
    rnd = random.Random(3)
    for k in range(10):
        a = k / 10 * math.tau
        bpy.ops.mesh.primitive_cylinder_add(radius=0.006, depth=0.05, location=(math.cos(a) * 0.05, math.sin(a) * 0.05, -0.035), rotation=(math.cos(a) * 0.9, math.sin(a) * 0.9, 0))
        cut_c = bpy.context.active_object
        cup.modifiers.remove(sol)
        K.cut(cup, cut_c)
        sol = cup.modifiers.new("solid", "SOLIDIFY")
        sol.thickness = 0.003
    K.smooth(cup)
    K.limb([(-0.17, 0, -0.012), (0, 0, -0.012), (0.17, 0, -0.012)], [0.005, 0.007, 0.005], "metal_silver", 12)
    for sx in (-1, 1):
        K.ball(0.012, (sx * 0.17, 0, -0.012), "metal_silver", sub=3)
    K.limb(K.arc((0.05, 0, -0.03), (0.02, 0, -0.17), (0.04, 0, 0), 8), [0.0045] * 9, "metal_silver", 10)
    K.cyl(0.012, 0.013, 0.12, (0, 0, -0.1), "leather_dark", 24)
    cord_spiral(-0.045, -0.155, 0.0135, "metal_silver", 11)
    K.ball(0.024, (0, 0, -0.18), "metal_silver", sub=4)


def sword_heart():
    """언덕의 심장: 두 손 대검(츠바이헨더). 검은 칼날에 핏줄 같은 빛이 갈라져 흐르고, 넓은 코등이 가운데 쇠창살 안에서
    심장 모양 빛이 뛴다. 양쪽 고리, 금띠 두른 긴 손잡이, 배 모양 자루끝."""
    L = 1.61
    hw = lambda t: 0.055 - 0.018 * t
    th = 0.0075
    blade("blade", L, hw, th, "metal_dark", single=False, tip=0.12)
    rnd = random.Random(21)
    for sy in (-1, 1):
        for b in range(5):
            x0 = rnd.uniform(-0.01, 0.01)
            z = 0.1 + b * 0.25
            pts = [(x0, sy * (th + 0.0006), z)]
            for k in range(6):
                q = pts[-1]
                nz = q[2] + rnd.uniform(0.03, 0.06)
                nx = max(-hw(nz / L) * 0.7, min(hw(nz / L) * 0.7, q[0] + rnd.uniform(-0.015, 0.015)))
                pts.append((nx, q[1], nz))
            K.limb(pts, [0.0016 - i * 0.0002 for i in range(7)], "glow_edge", 5)
    K.box((0.42, 0.04, 0.035), (0, 0, -0.02), "metal_iron", bev=0.006)
    for sx in (-1, 1):
        K.ring(0.03, 0.005, (sx * 0.08, 0, 0.02), "metal_iron", (math.pi / 2, 0, 0))
        K.limb(K.arc((sx * 0.21, 0, -0.02), (sx * 0.24, 0, -0.08), (sx * 0.03, 0, 0), 5), [0.012, 0.011, 0.01, 0.008, 0.006, 0.004], "metal_iron", 10)
    # 창살 안의 심장
    K.ball(0.018, (-0.011, 0, 0.005), "glow_edge", (1, 0.7, 1), 3)
    K.ball(0.018, (0.011, 0, 0.005), "glow_edge", (1, 0.7, 1), 3)
    K.cyl(0.0, 0.024, 0.032, (0, 0, -0.018), "glow_edge", 24, (math.pi, 0, 0))
    for k in range(6):
        a = k / 6 * math.tau
        K.limb(K.arc((math.cos(a) * 0.01, math.sin(a) * 0.01, -0.045), (math.cos(a) * 0.01, math.sin(a) * 0.01, 0.04), (math.cos(a) * 0.03, math.sin(a) * 0.03, 0), 6), [0.003] * 7, "metal_iron", 6)
    K.cyl(0.023, 0.025, 0.42, (0, 0, -0.26), "leather_dark", 24)
    for z in (-0.06, -0.26, -0.46):
        K.ring(0.026, 0.005, (0, 0, z), "metal_gold")
    K.ball(0.038, (0, 0, -0.5), "metal_iron", (1, 1, 1.35), 4)


def sword_hill():
    """언덕: 언덕의 돌을 깎아 만든 거대한 석검. 이끼 낀 거친 돌 칼날에 작은 칼 여러 자루가 꽂혀 있다.
    돌덩이 코등이, 나무껍질과 천으로 감은 손잡이, 바위 자루끝."""
    L = 1.61
    b = blade("blade", L, lambda t: 0.075 - 0.03 * t, 0.022, "stone_grey", single=False, tip=0.16)
    K.displace(b, 0.008, 0.03, "VORONOI")
    rnd = random.Random(8)
    for k in range(6):
        z = 0.25 + k * 0.2
        sx = 1 if k % 2 else -1
        K.sword((sx * 0.03, rnd.uniform(-0.01, 0.01), z), (rnd.uniform(-0.3, 0.3), sx * rnd.uniform(0.9, 1.3), 0), 0.12, "metal_iron", "metal_iron", 0.5)
    g = K.ball(0.07, (0, 0, -0.02), "stone_grey", (2.4, 0.9, 0.6), 4)
    K.displace(g, 0.01, 0.03, "VORONOI")
    K.cyl(0.026, 0.028, 0.4, (0, 0, -0.26), "wood_old", 16)
    grip_wrap(-0.06, -0.44, 0.028, "cloth_black", 6, 0.4)
    p = K.ball(0.05, (0, 0, -0.5), "stone_grey", (1, 0.9, 1.1), 4)
    K.displace(p, 0.008, 0.03, "VORONOI")


SWORDS.update({
    "293": sword_blood_throne,
    "297": sword_sain,
    "299": sword_bronze,
    "300": sword_nameless,
    "295": sword_oblivion,
    "288": sword_heart,
    "298": sword_hill,
})

# ------------------------------------------------------------------ 2026-11-25 사이버 카타나(311, docs/stranger.md)
# 총 든 낯선 사람이 떨군 칼. 진짜 카타나 비율의 곧은 외날(소리는 아주 조금), 날 끝을 따라서만 은은한 청록 빛,
# 칼뿌리를 감싼 기계 덮개(겹친 판과 홈, 홈 안의 가는 네온관, 판 위의 글자 없는 네온사인 무늬), 둥글고 두툼한 코등이와
# 네온 고리 테, 검은 끈을 마름모로 감은 두 손 손잡이(칼날의 1/4), 옅은 고리 둘, 네모 끝마개와 네온 줄.
# 네온은 빨강을 뺀 청록·파랑이라 밝아도 하얗게 날지 않는다. 빛 알갱이 없음. 정점 3천 개 아래(bmesh로 직접 짓는다), 질감 1K.
# 손잡이의 마름모 감김은 모양이 아니라 구운 질감(색·노멀)이다.
# 길이·원점·방향은 SwordModel의 약속 그대로: 코등이 가운데가 원점, 칼날 +Z(세검 1.42m), 날 +X, 칼끝은 (KAT_TIP_X, 0, 1.42).
# 게임 쪽 값: SwordModel.KATANA_GRIP(= KAT_GRIP), KATANA_TIP_X(= KAT_TIP_X). 바꾸면 같이 바꾼다.
KAT_L = 1.42                     # 칼날 길이(data/forms/3_rapier.tres, 311은 세검 형태)
KAT_GRIP = 0.355                 # 코등이 아래부터 끝마개까지(칼날의 1/4)
KAT_COVER = 0.285                # 기계 덮개 끝(날 길이의 1/5)
KAT_SORI = 0.035                 # 칼끝이 칼등(-X) 쪽으로 비켜나는 양(m). 휜 깊이(소리)는 그 1/4인 0.9cm쯤
KAT_W0, KAT_WY = 0.058, 0.041    # 칼날 너비: 덮개 끝(모토하바), 요코테(사키하바)
KAT_T0, KAT_TY = 0.0062, 0.0044  # 시노기의 반두께
KAT_KISSAKI = 0.08               # 킷사키 길이
KAT_M0 = -KAT_W0 / 2.0           # 덮개 속 칼등 자리(칼날이 덮개 가운데에 오게)
KAT_TIP_X = KAT_M0 - KAT_SORI    # 칼끝 x

K.GLOWS.update({
    "glow_kat_edge": ((0.0, 0.42, 0.5), (0.0, 0.8, 1.0), 2.4),      # 날 끝(청록)
    "glow_kat_line": ((0.0, 0.22, 0.6), (0.04, 0.42, 1.0), 4.0),    # 덮개의 네온관(파랑)
    "glow_kat_rim": ((0.0, 0.45, 0.55), (0.0, 0.85, 1.0), 3.5),     # 코등이 네온 고리, 끝마개 네온 줄(청록)
})


def _kat_mat(name, base, rough, metal, kind):
    """사이버 카타나 재질(굽기용). OUT_COLOR·OUT_ROUGH와 노멀을 make_heads._bake가 굽는다."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m["metal"] = metal
    nt = m.node_tree
    p = nt.nodes.get("Principled BSDF")
    co = nt.nodes.new("ShaderNodeTexCoord").outputs["Object"]
    big = K._noise(nt, co, 5.0, 6.0, 0.55)
    fine = K._noise(nt, co, 80.0, 4.0, 0.5)
    dark = tuple(c * 0.55 for c in base)
    lite = tuple(min(1.0, c * 1.6 + 0.04) for c in base)
    color = K._mix(nt, (*dark, 1), (*base, 1), K._ramp(nt, big, 0.2, 0.7))
    color = K._mix(nt, color, (*base, 1), 0.6)
    height = K._math(nt, "MULTIPLY", fine, 0.08, False)
    r = K._math(nt, "ADD", rough, K._math(nt, "MULTIPLY", K._math(nt, "SUBTRACT", fine, 0.5, False), 0.08, False))
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    normal_in = None
    if kind in ("blade", "shin"):
        # 길이 방향으로 간 결: 좌표를 Z만 늘린 잡음
        vm = nt.nodes.new("ShaderNodeVectorMath")
        vm.operation = "MULTIPLY"
        nt.links.new(co, vm.inputs[0])
        vm.inputs[1].default_value = (520.0, 520.0, 3.0)
        streak = K._noise(nt, vm.outputs["Vector"], 1.0, 3.0, 0.5)
        amt = 0.22 if kind == "blade" else 0.12
        color = K._mix(nt, color, (*lite, 1), K._math(nt, "MULTIPLY", K._ramp(nt, streak, 0.45, 0.8), amt))
        r = K._math(nt, "ADD", r, K._math(nt, "MULTIPLY", K._math(nt, "SUBTRACT", streak, 0.5, False), 0.1, False))
        height = K._math(nt, "ADD", height, K._math(nt, "MULTIPLY", streak, 0.12, False), False)
    elif kind in ("plate", "dark", "pale"):
        # 깎은 모서리(베벨 노멀)를 노멀에 굽고, 모서리는 닳아 밝게·매끈하게, 틈은 어둡게
        bev = nt.nodes.new("ShaderNodeBevel")
        bev.samples = 8
        bev.inputs["Radius"].default_value = 0.0012
        normal_in = bev.outputs["Normal"]
        dot = nt.nodes.new("ShaderNodeVectorMath")
        dot.operation = "DOT_PRODUCT"
        nt.links.new(bev.outputs["Normal"], dot.inputs[0])
        nt.links.new(geo.outputs["Normal"], dot.inputs[1])
        edge = K._math(nt, "SUBTRACT", 1.0, K._ramp(nt, dot.outputs["Value"], 0.93, 0.995))
        edge = K._math(nt, "MULTIPLY", edge, K._ramp(nt, fine, 0.3, 0.55))
        ao_n = nt.nodes.new("ShaderNodeAmbientOcclusion")
        ao_n.samples = 16
        ao_n.inputs["Distance"].default_value = 0.01
        color = K._mix(nt, K._mix(nt, color, (*dark, 1), 0.8), color, K._ramp(nt, ao_n.outputs["AO"], 0.3, 0.95))
        color = K._mix(nt, color, (*lite, 1), K._math(nt, "MULTIPLY", edge, 0.7))
        r = K._math(nt, "SUBTRACT", r, K._math(nt, "MULTIPLY", edge, 0.15))
        r = K._math(nt, "ADD", r, K._math(nt, "MULTIPLY", K._math(nt, "SUBTRACT", 1.0, ao_n.outputs["AO"]), 0.15))
    elif kind == "wrap":
        # 마름모 감김: 손잡이 축(Z) 둘레 각도와 높이로 엇갈린 두 나선 끈. 끈 사이 마름모 창은 어두운 쇠빛 가죽.
        xyz = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(co, xyz.inputs[0])
        th = K._math(nt, "ARCTAN2", xyz.outputs["Y"], xyz.outputs["X"], False)
        tp = K._math(nt, "DIVIDE", th, math.pi, False)
        zq = K._math(nt, "DIVIDE", xyz.outputs["Z"], 0.0342, False)   # 마름모 하나의 길이
        w = 0.24   # 끈의 반너비(마름모 한 칸에 대한 비율). 작을수록 마름모 창이 크다
        hs = []
        for sgn in (1.0, -1.0):
            a = K._math(nt, "ADD", zq, K._math(nt, "MULTIPLY", tp, sgn, False), False)
            d = K._math(nt, "ABSOLUTE", K._math(nt, "SUBTRACT", a, K._math(nt, "ROUND", a, 0.0, False), False), 0.0, False)
            q = K._math(nt, "DIVIDE", d, w, False)
            hs.append(K._math(nt, "SUBTRACT", 1.0, K._math(nt, "MULTIPLY", q, q, False)))   # 끈의 둥근 단면(0~1)
        cord = K._math(nt, "MAXIMUM", hs[0], hs[1])
        on = K._ramp(nt, cord, 0.0, 0.08)
        fiber = K._noise(nt, co, 900.0, 2.0, 0.5)
        cord_col = K._mix(nt, (0.006, 0.006, 0.008, 1), (0.03, 0.031, 0.036, 1), K._math(nt, "MULTIPLY", K._math(nt, "MULTIPLY", cord, cord), fiber))
        dots = K._voronoi(nt, co, 900.0)
        win_col = K._mix(nt, (0.035, 0.038, 0.045, 1), (0.075, 0.08, 0.09, 1), K._ramp(nt, dots, 0.0, 0.5))
        color = K._mix(nt, win_col, cord_col, on)
        r = K._mix(nt, (0.5, 0.5, 0.5, 1), (0.82, 0.82, 0.82, 1), on)
        height = K._math(nt, "ADD", K._math(nt, "MULTIPLY", cord, 0.9, False), K._math(nt, "MULTIPLY", K._ramp(nt, dots, 0.0, 0.4), 0.08, False), False)
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = {"wrap": 1.0, "blade": 0.15, "shin": 0.1}.get(kind, 0.3)
    bump.inputs["Distance"].default_value = 0.0025 if kind == "wrap" else 0.001
    nt.links.new(height, bump.inputs["Height"])
    if normal_in is not None:
        nt.links.new(normal_in, bump.inputs["Normal"])
    nt.links.new(K._reroute(nt, color, "OUT_COLOR"), p.inputs["Base Color"])
    nt.links.new(K._reroute(nt, r, "OUT_ROUGH"), p.inputs["Roughness"])
    nt.links.new(bump.outputs["Normal"], p.inputs["Normal"])
    p.inputs["Metallic"].default_value = metal
    return m


def _kat_materials():
    _kat_mat("kat_blade", (0.105, 0.112, 0.128), 0.26, 1.0, "blade")    # 짙은 건메탈, 살짝 광
    _kat_mat("kat_shin", (0.07, 0.075, 0.087), 0.22, 1.0, "shin")       # 시노기지·칼등: 조금 더 짙고 매끈
    _kat_mat("kat_plate", (0.2, 0.212, 0.235), 0.4, 1.0, "plate")       # 덮개 판, 끝마개
    _kat_mat("kat_dark", (0.045, 0.048, 0.056), 0.42, 1.0, "dark")      # 덮개 속, 코등이
    _kat_mat("kat_pale", (0.56, 0.6, 0.64), 0.32, 1.0, "pale")          # 옅은 고리
    _kat_mat("kat_wrap", (0.03, 0.03, 0.035), 0.8, 0.0, "wrap")         # 검은 끈과 마름모 창


def _kat_obj(name, bm, mats, round_all=False):
    """bmesh를 물체로(재질 여러 개는 면의 material_index). 모서리는 35도로 매끈/각지게. round_all이면 모두 매끈(네온관)."""
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    for mn in mats:
        me.materials.append(K.mat(mn))
    if round_all:
        me.shade_smooth()
    else:
        K.smooth(o)
    return o


def _kat_round(pts, d):
    """꺾인 점마다 모서리를 d만큼 둥글게(네온관을 구부린 자리)."""
    P = [Vector(p) for p in pts]
    out = [P[0]]
    for i in range(1, len(P) - 1):
        a, c, b = P[i - 1], P[i], P[i + 1]
        p0 = c + (a - c).normalized() * min(d, (a - c).length * 0.45)
        p2 = c + (b - c).normalized() * min(d, (b - c).length * 0.45)
        out += [p0, p0 * 0.25 + c * 0.5 + p2 * 0.25, p2]
    out.append(P[-1])
    return out


def _kat_tube(bm, pts, r, mi, segs=6, closed=False):
    """점들을 따라가는 둥근 네온관(closed면 고리). 끝은 막는다."""
    P = [Vector(p) for p in pts]
    n = len(P)
    rings = []
    nrm = None
    for i in range(n):
        if closed:
            t = (P[(i + 1) % n] - P[i - 1]).normalized()
        else:
            t = (P[min(i + 1, n - 1)] - P[max(i - 1, 0)]).normalized()
        ref = nrm if nrm is not None else (Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0)))
        nrm = (ref - t * ref.dot(t)).normalized()
        bi = t.cross(nrm)
        rings.append([bm.verts.new(P[i] + (nrm * math.cos(k / segs * math.tau) + bi * math.sin(k / segs * math.tau)) * r) for k in range(segs)])
    for i in range(n if closed else n - 1):
        a, b = rings[i], rings[(i + 1) % n]
        mid = (P[i] + P[(i + 1) % n]) / 2.0
        for k in range(segs):
            _kat_face(bm, [a[k], a[(k + 1) % segs], b[(k + 1) % segs], b[k]], mi, mid)
    if not closed:
        _kat_face(bm, rings[0], mi, P[0] + (P[1] - P[0]).normalized() * r)
        _kat_face(bm, rings[-1], mi, P[-1] + (P[-2] - P[-1]).normalized() * r)


def _kat_face(bm, vs, mi, inside):
    """면 하나. inside(안쪽 한 점)에서 멀어지는 쪽이 앞면이 되게 뒤집는다."""
    f = bm.faces.new(vs)
    f.normal_update()
    c = f.calc_center_median()
    if f.normal.dot(c - Vector(inside)) < 0:
        f.normal_flip()
    f.material_index = mi
    return f


def _kat_revolve(bm, prof, segs, sx, sy, mats, sharp=()):
    """옆모습 [(반지름, z)]을 Z축 둘레로 돌린다(sx·sy로 타원). 반지름 0인 끝은 한 점으로 닫는다.
    mats[i]: i번째와 i+1번째 점 사이 띠의 재질 번호. sharp: 각지게 할 점 번호. 앞면은 몸 가운데(축 위)에서 바깥쪽."""
    mid = (0.0, 0.0, (prof[0][1] + prof[-1][1]) / 2.0)
    rings = []
    for r, z in prof:
        if r <= 0.0:
            rings.append([bm.verts.new((0.0, 0.0, z))])
        else:
            rings.append([bm.verts.new((math.cos(k / segs * math.tau) * r * sx, math.sin(k / segs * math.tau) * r * sy, z)) for k in range(segs)])
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        for k in range(segs):
            k2 = (k + 1) % segs
            if len(a) == 1:
                vs = [a[0], b[k], b[k2]]
            elif len(b) == 1:
                vs = [a[k], a[k2], b[0]]
            else:
                vs = [a[k], a[k2], b[k2], b[k]]
            _kat_face(bm, vs, mats[i], mid)
    for i in sharp:
        ring = rings[i]
        for k in range(len(ring)):
            e = bm.edges.get((ring[k], ring[(k + 1) % len(ring)]))
            if e:
                e.smooth = False


def _kat_inset(poly, c):
    """볼록한 2D 다각형을 안쪽으로 c만큼 줄인다."""
    n = len(poly)
    cx = sum(p[0] for p in poly) / n
    cy = sum(p[1] for p in poly) / n
    lines = []
    for i in range(n):
        a, b = Vector(poly[i]), Vector(poly[(i + 1) % n])
        d = (b - a).normalized()
        nrm = Vector((-d.y, d.x))
        if nrm.dot(Vector((cx, cy)) - a) < 0:
            nrm = -nrm
        lines.append((a + nrm * c, d))
    out = []
    for i in range(n):
        p1, d1 = lines[i - 1]
        p2, d2 = lines[i]
        den = d1.x * d2.y - d1.y * d2.x
        if abs(den) < 1e-9:
            out.append(tuple(p2))
            continue
        t = ((p2.x - p1.x) * d2.y - (p2.y - p1.y) * d2.x) / den
        out.append(tuple(p1 + d1 * t))
    return out


def _kat_slab(bm, poly, base_y, t, c, sy, mi):
    """면(XZ) 위에 얹는 판: 바깥 면은 c만큼 줄이고 t만큼 띄운다(비스듬한 옆면). base_y(z)는 붙는 면의 |y|, sy는 ±1."""
    top = _kat_inset(poly, c)
    inner = [bm.verts.new((x, sy * base_y(z), z)) for x, z in poly]
    outer = [bm.verts.new((x, sy * (base_y(z) + t), z)) for x, z in top]
    cx = sum(p[0] for p in poly) / len(poly)
    cz = sum(p[1] for p in poly) / len(poly)
    ins = (cx, sy * (base_y(cz) - 0.004), cz)
    _kat_face(bm, outer, mi, ins)
    n = len(poly)
    for i in range(n):
        j = (i + 1) % n
        _kat_face(bm, [inner[i], inner[j], outer[j], outer[i]], mi, ins)


def _kat_blade():
    """칼날: 마디마다 단면 10점(날, 빛 경계, 지 가운데, 시노기, 칼등 어깨, 칼등 마루 … 반대쪽).
    날 끝의 좁은 면만 glow_kat_edge. 킷사키는 평평한 면으로 각지게 접고(요코테 선), 칼끝은 칼등 선에서 모인다."""
    L, zc, zy = KAT_L, KAT_COVER, KAT_L - KAT_KISSAKI

    def M(z):
        s = max(0.0, (z - zc) / (L - zc))
        return KAT_M0 - KAT_SORI * s * s

    def lin(a, b, z):
        s = min(1.0, max(0.0, (z - zc) / (zy - zc)))
        return a + (b - a) * s

    def main(z):
        m, w, t = M(z), lin(KAT_W0, KAT_WY, z), lin(KAT_T0, KAT_TY, z)
        g, tg = lin(0.0048, 0.0038, z), lin(0.0009, 0.0007, z)
        return [(m + w, 0.0), (m + w - g, tg), (m + 0.62 * w, 0.6 * t + 0.2 * tg), (m + 0.3 * w, t), (m, 0.68 * t), (m - 0.3 * t, 0.0)]

    def kiss(u):
        z = zy + u * KAT_KISSAKI
        m, w, t = M(z), KAT_WY, KAT_TY * (1.0 - u)
        ex = m + w * (1.0 - u ** 1.4)               # 후쿠라: 날이 칼등 선으로 오른다(거의 곧게, 각진 끝)
        sx = m + 0.3 * w * (1.0 - u)                # 고시노기
        g = 0.0038 * (1.0 - 0.6 * u)
        gx, gy = ex - g, 0.0007 * (1.0 - u)
        return [(ex, 0.0), (gx, gy), ((sx + gx) / 2.0, (t + gy) / 2.0), (sx, t), (m, 0.68 * t), (m - 0.3 * t, 0.0)]

    zs = [zc - 0.045, zc] + [zc + (zy - zc) * k / 8.0 for k in range(1, 9)]
    kus = (0.14, 0.28, 0.42, 0.56, 0.69, 0.8, 0.89, 0.96)
    secs = [(z, main(z)) for z in zs] + [(zy + u * KAT_KISSAKI, kiss(u)) for u in kus]
    yokote = len(zs) - 1
    bm = bmesh.new()
    rings = []
    for z, s in secs:
        e, g, j, sh, mu, pk = s
        pts = [e, g, j, sh, mu, pk, (mu[0], -mu[1]), (sh[0], -sh[1]), (j[0], -j[1]), (g[0], -g[1])]
        rings.append([bm.verts.new((x, y, z)) for x, y in pts])
    tip = bm.verts.new((M(L), 0.0, L))
    mats = [0, 1, 1, 2, 2, 2, 2, 1, 1, 0]   # 0 빛, 1 지, 2 시노기지·칼등
    kmats = [0, 2, 2, 2, 2, 2, 2, 2, 2, 0]  # 킷사키는 지도 짙게: 요코테에서 빛깔이 끊겨 각져 보인다
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        mid = sum((v.co for v in a + b), Vector()) / 20.0   # 단면이 볼록해서 두 마디의 무게중심은 늘 안쪽
        for k in range(10):
            k2 = (k + 1) % 10
            _kat_face(bm, [a[k], a[k2], b[k2], b[k]], (kmats if i >= yokote else mats)[k], mid)
    last = rings[-1]
    mid = (sum((v.co for v in last), Vector()) + tip.co) / 11.0
    for k in range(10):
        _kat_face(bm, [last[k], last[(k + 1) % 10], tip], kmats[k], mid)
    # 날·시노기·칼등의 긴 모서리와 요코테 선은 각지게
    for i in range(len(rings) - 1):
        for k in (0, 3, 4, 5, 6, 7):
            e = bm.edges.get((rings[i][k], rings[i + 1][k]))
            if e:
                e.smooth = False
    for k in range(10):
        e = bm.edges.get((rings[yokote][k], rings[yokote][(k + 1) % 10]))
        if e:
            e.smooth = False
    return _kat_obj("blade", bm, ["glow_kat_edge", "kat_blade", "kat_shin"])


def _kat_cover():
    """칼뿌리 기계 덮개(코등이 위 ~ 날 길이의 1/5): 칼날 꼴의 어두운 속, 위로 좁아지는 밝은 칼코(하바키),
    양면에 겹친 판(바닥 판 위에 판 셋), 판 사이와 칼등 쪽 홈에 가는 네온관, 가운데 판 위에 꺾인 네온관 무늬(글자 없음)."""
    z0, z1, z2 = 0.0085, 0.248, KAT_COVER
    sec = [(0.043, 0.0), (0.030, 0.0165), (-0.034, 0.0165), (-0.040, 0.0065), (-0.040, -0.0065), (-0.034, -0.0165), (0.030, -0.0165)]

    def sc(z):   # 위로 갈수록 조금 좁아진다
        s = (z - z0) / (z1 - z0)
        return 1.0 - 0.05 * s, 1.0 - 0.1 * s

    bm = bmesh.new()
    rings = []
    for z, (kx, ky) in ((z0, sc(z0)), (z1, sc(z1)), (z2, (0.76, 0.55))):
        rings.append([bm.verts.new((x * kx, y * ky, z)) for x, y in sec])
    n = len(sec)
    for i in range(2):
        cz = (rings[i][0].co.z + rings[i + 1][0].co.z) / 2.0
        for k in range(n):
            _kat_face(bm, [rings[i][k], rings[i][(k + 1) % n], rings[i + 1][(k + 1) % n], rings[i + 1][k]], 0 if i == 0 else 1, (0.0, 0.0, cz))
    _kat_face(bm, rings[2], 1, (0.0, 0.0, z2 - 0.01))
    for ring in rings[1:2]:
        for k in range(n):
            e = bm.edges.get((ring[k], ring[(k + 1) % n]))
            if e:
                e.smooth = False

    def face_y(z):   # 덮개 넓은 면의 |y|
        return 0.0165 * sc(z)[1]

    glows = bmesh.new()
    for sy in (1.0, -1.0):
        a_t = 0.0022
        _kat_slab(bm, [(-0.0315, 0.018), (0.027, 0.018), (0.027, 0.205), (0.012, 0.238), (-0.0315, 0.238)], face_y, a_t, 0.0012, sy, 0)

        def on_a(z, add=0.0):
            return face_y(z) + a_t + add

        for poly in ([(-0.026, 0.026), (0.022, 0.026), (0.022, 0.082), (-0.026, 0.098)],
                     [(-0.026, 0.108), (0.022, 0.092), (0.022, 0.158), (-0.026, 0.172)],
                     [(-0.026, 0.182), (0.022, 0.168), (0.022, 0.19), (0.008, 0.226), (-0.026, 0.226)]):
            _kat_slab(bm, poly, on_a, 0.0026, 0.0014, sy, 2)
        # 판 사이 두 홈과 칼등 쪽 세로 홈의 네온관(바닥 판 위에 반쯤 묻힌다)
        r = 0.0012
        for (xa, za), (xb, zb) in (((-0.0262, 0.103), (0.0222, 0.087)), ((-0.0262, 0.177), (0.0222, 0.163))):
            _kat_tube(glows, [(xa, sy * on_a(za, r * 0.5), za), (xb, sy * on_a(zb, r * 0.5), zb)], r, 0)
        _kat_tube(glows, [(-0.0289, sy * on_a(z, r * 0.4), z) for z in (0.03, 0.226)], 0.001, 0)

        # 가운데 판 위의 네온사인 무늬: 기운 ∩ 꼴로 꺾은 관과 작은 고리(글자 아님)
        def on_b(z, add=0.0):
            return on_a(z) + 0.0026 + add
        r2 = 0.0011
        sign = _kat_round([(-0.019, 0.12), (-0.019, 0.151), (0.013, 0.138), (0.013, 0.117)], 0.004)
        _kat_tube(glows, [(p.x, sy * on_b(p.y, r2 * 0.7), p.y) for p in sign], r2, 0)
        dot = [(-0.003 + math.cos(k / 10 * math.tau) * 0.0034, 0.1285 + math.sin(k / 10 * math.tau) * 0.0034) for k in range(10)]
        _kat_tube(glows, [(x, sy * on_b(z, r2 * 0.7), z) for x, z in dot], 0.0009, 0, closed=True)
    # 칼등의 평평한 면을 따라 가는 빛
    _kat_tube(glows, [(-0.040 * sc(z)[0] + 0.0004, 0.0, z) for z in (0.03, 0.235)], 0.0013, 0)
    _kat_obj("cover", bm, ["kat_dark", "kat_plate", "kat_plate"])
    _kat_obj("cover_glow", glows, ["glow_kat_line"], True)


def _kat_guard():
    """코등이: 둥글고 두툼한 어두운 쇠. 둘레 가운데 얕은 홈에 청록 네온 고리, 칼 쪽 면에도 가는 네온 고리."""
    prof = [(0.0, 0.0085), (0.05, 0.0085), (0.0572, 0.0079), (0.0601, 0.0066), (0.0614, 0.0045), (0.0616, 0.0025),
            (0.0607, 0.0019), (0.0607, -0.0019), (0.0616, -0.0025), (0.0614, -0.0045), (0.0601, -0.0066), (0.0572, -0.0079), (0.05, -0.0085), (0.0, -0.0085)]
    bm = bmesh.new()
    _kat_revolve(bm, prof, 36, 1.0, 1.0, [0] * 13, sharp=(5, 6, 7, 8))
    _kat_obj("guard", bm, ["kat_dark"])
    gb = bmesh.new()
    _kat_tube(gb, [(math.cos(k / 36 * math.tau) * 0.0611, math.sin(k / 36 * math.tau) * 0.0611, 0.0) for k in range(36)], 0.0016, 0, closed=True)
    _kat_tube(gb, [(math.cos(k / 30 * math.tau) * 0.047, math.sin(k / 30 * math.tau) * 0.047, 0.0091) for k in range(30)], 0.001, 0, segs=5, closed=True)
    _kat_obj("guard_glow", gb, ["glow_kat_rim"], True)


def _kat_hilt():
    """손잡이: 타원 단면, 가운데가 살짝 잘록. 위아래 옅은 고리, 네모 끝마개와 가는 빛 줄."""
    g = KAT_GRIP
    zt, zb = -0.0085, -g - 0.0085            # 코등이 아래 ~ 끝마개 끝
    bm = bmesh.new()
    prof = [(0.0186, -0.02), (0.0181, -0.1), (0.0176, -0.18), (0.0179, -0.26), (0.0184, zb + 0.03)]
    _kat_revolve(bm, prof, 20, 1.0, 0.82, [0, 0, 0, 0])
    _kat_obj("grip", bm, ["kat_wrap"])
    rb = bmesh.new()
    for top, bot, r in ((zt, -0.027, 0.0204), (zb + 0.034, zb + 0.026, 0.0197)):
        h = top - bot
        prof = [(0.0, top), (r - 0.0012, top), (r - 0.0003, top - 0.0006), (r, top - min(0.0022, h * 0.25)),
                (r, bot + min(0.0022, h * 0.25)), (r - 0.0003, bot + 0.0006), (r - 0.0012, bot), (0.0, bot)]
        _kat_revolve(rb, prof, 20, 1.0, 0.84, [0] * 7)
    _kat_obj("rings", rb, ["kat_pale"])
    # 네모 끝마개(모서리를 깎은 상자)
    cb = bmesh.new()
    bmesh.ops.create_cube(cb, size=1.0)
    hx, hy, hz = 0.0215, 0.0188, 0.013
    zc = zb + 0.013
    for v in cb.verts:
        v.co = Vector((v.co.x * 2 * hx, v.co.y * 2 * hy, v.co.z * 2 * hz + zc))
    bmesh.ops.bevel(cb, geom=list(cb.edges), offset=0.0026, segments=1, affect="EDGES", profile=0.5)
    for f in cb.faces:
        f.material_index = 0
    bmesh.ops.recalc_face_normals(cb, faces=cb.faces)
    _kat_obj("cap", cb, ["kat_plate"])
    # 끝마개 둘레를 한 바퀴 도는 네온 줄(깎은 네모를 따라)
    gb = bmesh.new()
    c = 0.0026
    oct_ = [(hx, -hy + c), (hx, hy - c), (hx - c, hy), (-hx + c, hy), (-hx, hy - c), (-hx, -hy + c), (-hx + c, -hy), (hx - c, -hy)]
    zg = zc + 0.002
    _kat_tube(gb, [(x, y, zg) for x, y in oct_], 0.0012, 0, closed=True)
    _kat_obj("cap_glow", gb, ["glow_kat_rim"], True)


def sword_cyber_katana():
    """사이버 카타나(311). 위 KAT_* 설명."""
    _kat_materials()
    _kat_blade()
    _kat_cover()
    _kat_guard()
    _kat_hilt()


SWORDS["311"] = sword_cyber_katana

if __name__ == "__main__":
    K.run_all(K._pick({str(k): v for k, v in SWORDS.items()}), OUT, 1024, "칼")
