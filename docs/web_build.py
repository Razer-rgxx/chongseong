#!/usr/bin/env python3
"""웹판을 만들어 GitHub Pages(gh-pages 가지)에 올릴 준비를 한다.

쓰는 법(저장소 맨 위에서):  python3 docs/web_build.py <godot 실행 파일> <내보낼 폴더>
1. export_presets.cfg의 "Web"으로 내보낸다(스레드 없음: Pages는 COOP/COEP 머리를 못 붙인다).
2. GitHub은 파일 하나가 100MB를 넘으면 받지 않아서 index.pck를 90MB씩 자른다(index.pck.0, .1, …).
3. index.html이 조각을 차례로 받아 이어 붙여 엔진에 넘기게 고친다. 받는 동안은 게임식 불러오기 화면(OVERLAY_*),
   받은 조각은 브라우저에 남겨 두고 다음에 다시 쓴다(Cache Storage).
사운드 팩(assets/sound/)은 약관이 없어 공개 웹판에서도 뺀다(코드로 만든 소리가 대신 난다).
"""
import json
import os
import subprocess
import sys
import time

CHUNK = 90 * 1024 * 1024
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 첫 불러오기 화면(2026-11-24 사용자: "처음에 시작할 때 계속 기다려야 하는데 로딩 화면 만들자").
# 게임 그림(assets/ui/loading/hill.jpg: 시작 화면을 찍은 것, 게임 안 SceneLoader와 같은 것)을 어둡게 깔고 가운데 제목, 아래에 놋쇠 줄·받은 MB·도움말(SceneLoader.TIPS와 같음)·바닥 불씨.
# 받은 조각은 브라우저 Cache Storage에 남겨(geom-hill-<판 번호>) 다음부터는 받지 않고 바로 읽는다. 새 판이 오르면 옛 것은 지운다.
OVERLAY_CSS = """
@font-face { font-family: 'DNFForgedBlade'; src: url('fonts/DNFForgedBlade-Medium.otf') format('opentype'); font-display: swap; }
#status { display: none !important; }
#status.gh-fail { display: flex !important; background: rgba(8,6,5,0.85); z-index: 30; }
#gh-load { position: fixed; inset: 0; z-index: 20; background: #080605; color: #ddd4c4; overflow: hidden;
	font-family: 'DNFForgedBlade', 'Noto Serif KR', 'Batang', serif; transition: opacity 0.6s ease; user-select: none; }
#gh-load.gone { opacity: 0; pointer-events: none; }
#gh-load .bg { position: absolute; inset: -2%; background: url('loading.jpg') center/cover no-repeat; filter: brightness(0.42) saturate(0.85);
	animation: gh-drift 40s ease-in-out infinite alternate; }
#gh-load .vig { position: absolute; inset: 0; background: radial-gradient(ellipse at center, rgba(0,0,0,0) 35%, rgba(0,0,0,0.85) 100%),
	linear-gradient(to bottom, rgba(0,0,0,0.25), rgba(0,0,0,0) 30%, rgba(0,0,0,0) 55%, rgba(0,0,0,0.9)); }
#gh-embers { position: absolute; inset: 0; width: 100%; height: 100%; }
#gh-load .title { position: absolute; top: 30%; width: 100%; text-align: center; font-size: clamp(40px, 7vw, 92px); letter-spacing: 0.18em;
	color: #eddcb0; text-shadow: 0 0 24px rgba(0,0,0,0.9), 0 2px 2px rgba(0,0,0,0.8); }
#gh-load .orn { position: absolute; top: calc(30% + clamp(62px, 10vw, 128px)); left: 50%; transform: translateX(-50%); width: min(520px, 70vw); height: 9px; }
#gh-load .orn::before { content: ''; position: absolute; left: 0; right: 0; top: 4px; height: 1px;
	background: linear-gradient(to right, rgba(168,143,97,0), rgba(168,143,97,0.75), rgba(168,143,97,0)); }
#gh-load .orn::after { content: ''; position: absolute; left: 50%; top: 0; width: 7px; height: 7px; background: #a88f61; transform: translateX(-50%) rotate(45deg); }
#gh-load .low { position: absolute; bottom: 9%; left: 50%; transform: translateX(-50%); width: min(760px, 88vw); text-align: center; }
#gh-what { font-size: 22px; color: #eddcb0; letter-spacing: 0.06em; text-shadow: 0 2px 6px #000; }
#gh-load .bar { margin: 14px auto 8px; width: min(440px, 70vw); height: 3px; background: rgba(168,143,97,0.2); position: relative; }
#gh-fill { position: absolute; left: 0; top: -1px; height: 5px; width: 0; background: linear-gradient(to right, #7d6640, #d8bb7a);
	box-shadow: 0 0 10px rgba(255,170,80,0.55); transition: width 0.25s linear; }
#gh-num { font-size: 14px; color: #9a917f; letter-spacing: 0.04em; min-height: 18px; }
#gh-tip { margin-top: 22px; font-size: 16px; color: #b8ad98; min-height: 44px; transition: opacity 0.6s ease; text-shadow: 0 2px 4px #000; }
#gh-note { margin-top: 10px; font-size: 13px; color: #7a7262; }
@keyframes gh-drift { from { transform: scale(1.0) translateX(0); } to { transform: scale(1.06) translateX(-1.5%); } }
"""

OVERLAY_HTML = """
		<div id="gh-load">
			<div class="bg"></div><div class="vig"></div><canvas id="gh-embers"></canvas>
			<div class="title">검의 언덕</div><div class="orn"></div>
			<div class="low">
				<div id="gh-what">언덕으로 가는 길을 여는 중</div>
				<div class="bar"><div id="gh-fill"></div></div>
				<div id="gh-num"></div>
				<div id="gh-tip"></div>
				<div id="gh-note"></div>
			</div>
		</div>
"""

LOADER = """const exe = GODOT_CONFIG['executable'];
		const PARTS = %(parts)s;
		const TOTAL = %(total)d;
		const VERSION = '%(version)d';
		const TIPS = %(tips)s;
		const load = document.getElementById('gh-load');
		const what = document.getElementById('gh-what');
		const fill = document.getElementById('gh-fill');
		const num = document.getElementById('gh-num');
		const tip = document.getElementById('gh-tip');
		const note = document.getElementById('gh-note');
		const pack = new Uint8Array(TOTAL);
		let got = 0;
		const mb = (n) => (n / 1048576).toFixed(0);
		function show(done) {
			fill.style.width = (done * 100).toFixed(1) + '%%';
		}
		// 도움말: 6초마다 바뀐다
		let ti = Math.floor(Math.random() * TIPS.length);
		tip.textContent = TIPS[ti];
		setInterval(function () {
			tip.style.opacity = 0;
			setTimeout(function () { ti = (ti + 1) %% TIPS.length; tip.textContent = TIPS[ti]; tip.style.opacity = 1; }, 600);
		}, 6000);
		// 바닥 불씨
		(function () {
			const c = document.getElementById('gh-embers');
			const g = c.getContext('2d');
			const sparks = [];
			function size() { c.width = innerWidth; c.height = innerHeight; }
			size(); addEventListener('resize', size);
			function spawn() { return { x: Math.random() * c.width, y: c.height + 5, v: 14 + Math.random() * 40, r: 0.8 + Math.random() * 1.8, t: 0, life: 3 + Math.random() * 3, w: Math.random() * 6 }; }
			for (let i = 0; i < 60; i++) { const s = spawn(); s.t = Math.random() * s.life; s.y = c.height - s.v * s.t; sparks.push(s); }
			let last = performance.now();
			function step(now) {
				if (!document.body.contains(c)) { return; }
				const dt = Math.min(0.05, (now - last) / 1000); last = now;
				g.clearRect(0, 0, c.width, c.height);
				for (const s of sparks) {
					s.t += dt; s.y -= s.v * dt; s.x += Math.sin(s.t * 1.3 + s.w) * 8 * dt;
					if (s.t > s.life) { Object.assign(s, spawn()); }
					const k = s.t / s.life; const a = k < 0.15 ? k / 0.15 : (1 - k);
					g.fillStyle = 'rgba(255,' + Math.floor(150 - 80 * k) + ',' + Math.floor(60 - 40 * k) + ',' + (a * 0.85).toFixed(3) + ')';
					g.beginPath(); g.arc(s.x, s.y, s.r, 0, 6.283); g.fill();
				}
				requestAnimationFrame(step);
			}
			requestAnimationFrame(step);
		}());
		// 받은 조각을 남겨 두는 곳(브라우저 Cache Storage). 안 되면(시크릿 창 등) 매번 받는다.
		async function openCache() {
			try {
				if (!('caches' in window)) { return null; }
				const name = 'geom-hill-' + VERSION;
				for (const k of await caches.keys()) {
					if (k.startsWith('geom-hill-') && k !== name) { await caches.delete(k); }
				}
				return await caches.open(name);
			} catch (e) {
				return null;
			}
		}
		async function fetchParts() {
			const cache = await openCache();
			let saved = 0;
			for (const part of PARTS) {
				const start = got;
				let res = null;
				try { res = cache ? await cache.match(part) : null; } catch (e) { res = null; }
				const fromCache = !!res;
				if (fromCache) {
					saved++;
					what.textContent = '남겨 둔 언덕을 꺼내는 중';
				} else {
					what.textContent = '언덕으로 가는 길을 여는 중';
					res = await fetch(part + '?v=' + VERSION);  // 조각 이름이 늘 같아서, 옛 조각이 캐시에서 섞이지 않게
					if (!res.ok) {
						throw new Error('Failed to load ' + part + ' (' + res.status + ')');
					}
				}
				const reader = res.body.getReader();
				for (;;) {
					const { done, value } = await reader.read();
					if (done) {
						break;
					}
					pack.set(value, got);
					got += value.length;
					show(got / TOTAL * 0.96);
					num.textContent = mb(got) + ' / ' + mb(TOTAL) + ' MB';
				}
				if (!fromCache && cache) {
					try { await cache.put(part, new Response(pack.subarray(start, got))); } catch (e) { /* 자리가 모자라면 다음에 다시 받는다 */ }
				}
			}
			note.textContent = cache ? (saved === PARTS.length ? '' : '처음 한 번만 오래 걸린다. 다음부터는 이 브라우저에 남겨 둔 것을 쓴다.') : '';
			return pack;
		}
		note.textContent = '처음 한 번만 오래 걸린다. 다음부터는 이 브라우저에 남겨 둔 것을 쓴다.';
		Promise.all([engine.init(exe), fetchParts()]).then(function (res) {
			what.textContent = '언덕을 깨우는 중';
			num.textContent = '';
			show(0.98);
			return engine.preloadFile(res[1].buffer, 'index.pck');  // 배열 그대로 넘기면 fileSizes 키로 문자열이 되어 터진다
		}).then(function () {
			return engine.start({ 'args': ['--main-pack', 'index.pck'] });
		}).then(() => {
			show(1);
			setStatusMode('hidden');
			setTimeout(function () { load.classList.add('gone'); setTimeout(function () { load.remove(); }, 800); }, 400);
		}, function (err) {
			document.getElementById('status').classList.add('gh-fail');
			load.remove();
			displayFailureNotice(err);
		});
	}
}());"""


def tips() -> list:
    """SceneLoader.TIPS(게임 안 불러오기 화면의 도움말)를 그대로 가져온다."""
    import re
    src = open(os.path.join(ROOT, "scripts", "ui", "scene_loader.gd"), encoding="utf-8").read()
    block = src[src.index("const TIPS"):]
    block = block[block.index("= ["):block.index("\n]") + 2]   # Array[String]의 ]가 아니라 목록 끝의 ]까지
    return re.findall(r'"([^"]+)"', block)


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
    html = html[:a] + LOADER % {"parts": json.dumps(parts), "total": len(data), "version": int(time.time()),
                                "tips": json.dumps(tips(), ensure_ascii=False)} + html[b:]
    html = html.replace("<html lang=\"en\">", "<html lang=\"ko\">")
    html = html.replace("\t\t</style>", OVERLAY_CSS + "\t\t</style>", 1)
    html = html.replace("\t\t<div id=\"status\">", OVERLAY_HTML + "\t\t<div id=\"status\">", 1)
    # 불러오기 화면의 그림과 글꼴(DNF 연단된 칼날, 받은 파일 그대로·안내문 같이)
    import shutil
    shutil.copy(os.path.join(ROOT, "assets", "ui", "loading", "hill.jpg"), os.path.join(out, "loading.jpg"))
    os.makedirs(os.path.join(out, "fonts"), exist_ok=True)
    for f in ("DNFForgedBlade-Medium.otf", "LICENSE-DNF.txt"):
        shutil.copy(os.path.join(ROOT, "assets", "ui", "fonts", f), os.path.join(out, "fonts", f))
    open(html_path, "w", encoding="utf-8").write(html)
    open(os.path.join(out, ".nojekyll"), "w").close()
    print(f"웹판: {out} · pck {len(data) / 1048576:.0f}MB → {len(parts)}조각")


if __name__ == "__main__":
    main()
