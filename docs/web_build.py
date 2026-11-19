#!/usr/bin/env python3
"""웹판을 만들어 GitHub Pages(gh-pages 가지)에 올릴 준비를 한다.

쓰는 법(저장소 맨 위에서):  python3 docs/web_build.py <godot 실행 파일> <내보낼 폴더>
1. export_presets.cfg의 "Web"으로 내보낸다(스레드 없음: Pages는 COOP/COEP 머리를 못 붙인다).
2. GitHub은 파일 하나가 100MB를 넘으면 받지 않아서 index.pck를 90MB씩 자른다(index.pck.0, .1, …).
3. index.html이 조각을 차례로 받아 이어 붙여 엔진에 넘기게 고친다.
사운드 팩(assets/sound/)은 약관이 없어 공개 웹판에서도 뺀다(코드로 만든 소리가 대신 난다).
"""
import json
import os
import subprocess
import sys

CHUNK = 90 * 1024 * 1024
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

LOADER = """setStatusMode('progress');
		const exe = GODOT_CONFIG['executable'];
		const PARTS = %(parts)s;
		const TOTAL = %(total)d;
		const pack = new Uint8Array(TOTAL);
		let got = 0;
		async function fetchParts() {
			for (const part of PARTS) {
				const res = await fetch(part);
				if (!res.ok) {
					throw new Error('Failed to load ' + part + ' (' + res.status + ')');
				}
				const reader = res.body.getReader();
				for (;;) {
					const { done, value } = await reader.read();
					if (done) {
						break;
					}
					pack.set(value, got);
					got += value.length;
					statusProgress.value = got;
					statusProgress.max = TOTAL;
				}
			}
			return pack;
		}
		Promise.all([engine.init(exe), fetchParts()]).then(function (res) {
			return engine.preloadFile(res[1].buffer, 'index.pck');  // 배열 그대로 넘기면 fileSizes 키로 문자열이 되어 터진다
		}).then(function () {
			return engine.start({ 'args': ['--main-pack', 'index.pck'] });
		}).then(() => {
			setStatusMode('hidden');
		}, displayFailureNotice);
	}
}());"""


def main() -> None:
    godot, out = sys.argv[1], os.path.abspath(sys.argv[2])
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        if f.startswith("index."):
            os.remove(os.path.join(out, f))
    subprocess.run([godot, "--headless", "--path", ROOT, "--export-release", "Web",
                    os.path.join(out, "index.html")], check=True)
    pck = os.path.join(out, "index.pck")
    data = open(pck, "rb").read()
    parts = []
    for i in range(0, len(data), CHUNK):
        name = f"index.pck.{len(parts)}"
        open(os.path.join(out, name), "wb").write(data[i:i + CHUNK])
        parts.append(name)
    os.remove(pck)
    html_path = os.path.join(out, "index.html")
    html = open(html_path, encoding="utf-8").read()
    a = html.index("setStatusMode('progress');\n\t\tengine.startGame(")
    b = html.index("}());", a) + len("}());")
    html = html[:a] + LOADER % {"parts": json.dumps(parts), "total": len(data)} + html[b:]
    html = html.replace("<html lang=\"en\">", "<html lang=\"ko\">")
    open(html_path, "w", encoding="utf-8").write(html)
    open(os.path.join(out, ".nojekyll"), "w").close()
    print(f"웹판: {out} · pck {len(data) / 1048576:.0f}MB → {len(parts)}조각")


if __name__ == "__main__":
    main()
