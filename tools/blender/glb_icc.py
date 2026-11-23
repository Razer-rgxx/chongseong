"""glb 안의 JPEG에서 ICC 색 프로필(APP2 "ICC_PROFILE")을 뺀다.

Blender 5.x는 sRGB 그림(색·거칠기)을 JPEG로 낼 때 ICC 프로필을 붙이는데, Godot 4.6의 JPEG 읽기가
그 그림을 못 읽는다(읽기 오류 43, 모델이 질감 없이 하얗게 나온다). 그림은 그대로 두고 프로필 조각만 뺀다.

Blender 없이 돌린다(파이썬만): python tools/blender/glb_icc.py assets/heads/*.glb assets/swords/*.glb
make_heads.finish가 내보낸 뒤 스스로 부른다.
"""
import json
import struct
import sys


def strip_jpeg(data):
    """JPEG 바이트에서 ICC APP2 조각을 뺀 바이트. JPEG가 아니거나 모양이 이상하면 그대로."""
    if data[:2] != b"\xff\xd8":
        return data
    out = bytearray(data[:2])
    i = 2
    while i + 4 <= len(data):
        if data[i] != 0xFF:
            return data
        m = data[i + 1]
        if m == 0xDA:   # 그림 자료의 시작: 나머지는 그대로
            out += data[i:]
            return bytes(out)
        n = int.from_bytes(data[i + 2:i + 4], "big")
        seg = data[i:i + 2 + n]
        if not (m == 0xE2 and seg[4:16] == b"ICC_PROFILE\0"):
            out += seg
        i += 2 + n
    return data


def strip_glb(path):
    """glb 파일 하나를 고쳐 쓴다. 뺀 그림 수를 돌려준다."""
    with open(path, "rb") as f:
        b = f.read()
    magic, ver, _ = struct.unpack("<4sII", b[:12])
    if magic != b"glTF":
        return 0
    jlen, _ = struct.unpack("<II", b[12:20])
    doc = json.loads(b[20:20 + jlen])
    off = 20 + jlen
    blen, _ = struct.unpack("<II", b[off:off + 8])
    binc = b[off + 8:off + 8 + blen]
    views = doc.get("bufferViews", [])
    img_views = {im["bufferView"] for im in doc.get("images", []) if im.get("mimeType") == "image/jpeg" and "bufferView" in im}
    fixed = 0
    new_bin = bytearray()
    for k, v in enumerate(views):
        start = v.get("byteOffset", 0)
        chunk = binc[start:start + v["byteLength"]]
        if k in img_views:
            s = strip_jpeg(chunk)
            if len(s) != len(chunk):
                fixed += 1
            chunk = s
        while len(new_bin) % 4:
            new_bin += b"\0"
        v["byteOffset"] = len(new_bin)
        v["byteLength"] = len(chunk)
        new_bin += chunk
    if fixed == 0:
        return 0
    while len(new_bin) % 4:
        new_bin += b"\0"
    doc["buffers"][0]["byteLength"] = len(new_bin)
    js = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    while len(js) % 4:
        js += b" "
    total = 12 + 8 + len(js) + 8 + len(new_bin)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", ver, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A))
        f.write(js)
        f.write(struct.pack("<II", len(new_bin), 0x004E4942))
        f.write(new_bin)
    return fixed


if __name__ == "__main__":
    for p in sys.argv[1:]:
        print(p, "ICC 뺀 그림", strip_glb(p))
