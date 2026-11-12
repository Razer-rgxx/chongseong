/* 참고용: prototype/yeongji_pc.html 안에 들어 있는 영지 시연판 코드만 떼어 둔 것이다.
   이 파일만으로는 돌지 않는다(뽑기 데모의 TIERS, play, tone 같은 전역에 기댄다). 규칙과 수치를 읽는 용도로만 쓴다.
   [표] [규칙] [화면] [입력] [관리] 순서로 나뉘어 있다. 고치지 않는다. */
/* ===== 영지 시연판 (PC) =====
   영주를 직접 움직인다. 낮에는 나무와 돌을 캐고, 설계함을 열어 건물을 짓고, 모집 건물에 들어가 말을 걸어 사람을 뽑는다.
   밤에는 성벽에 세운 사람들과 함께 직접 싸운다. 7일째 밤의 우두머리를 넘기면 이 지역을 지킨 것이다.
   고도로 옮길 때: [표] → data/*.tres, [규칙] → 화면과 섞지 않은 스크립트, [화면] → 씬, [입력] → InputMap */
{
// ===================== [표] =====================
const MN = 33, HX = 16, HY = 16, HALL = HY * MN + HX, CELL = 34, N4 = [[1, 0], [-1, 0], [0, 1], [0, -1]];
const DAYS = 7, T_DAY = 80, BOX_DAY = 3, BOX_GOLD = 2, VIS = 3, WALL_S = 3, WALL_HP = 260, HALL_HP = 1600, BP_MAX = 6, REVEAL = 3;
// 건물: [이름, 역할, 종류]. R 모집, M 생산, D 방어, P 홍보
const BLD = [
  [['주막', 'R'], ['벌목장', 'M', 'wood'], ['채석장', 'M', 'stone'], ['목책 탑', 'D', 'shoot'], ['마름쇠 밭', 'D', 'slow'], ['게시판', 'P']],
  [['여관', 'R'], ['제재소', 'M', 'wood'], ['석공소', 'M', 'stone'], ['쇠살문', 'D', 'block'], ['투석기', 'D', 'splash'], ['광장', 'P']],
  [['기사단 숙소', 'R'], ['광산', 'M', 'stone'], ['망루', 'D', 'shoot'], ['대투석기', 'D', 'splash'], ['전령탑', 'P']],
  [['별의 성탑', 'R']], [['길드의 심장석', 'D', 'heart']], [['첫 번째 설계도', 'M', 'both']], [['끝없는 성', 'R']], [['상자 속의 성', 'R']],
];
BLD.forEach((l, t) => { TIERS[t].items = l.map(b => b[0]); });
Object.entries({ '기사단 숙소': '이름난 검은 이름난 지붕 아래로 모인다', '광산': '성은 돌에서 시작해 돌로 끝난다', '망루': '가장 먼저 본 자가 가장 오래 산다', '대투석기': '성벽 너머로 던지는 것은 돌만이 아니다', '전령탑': '이름이 퍼지면 친구도 적도 몰려온다' }).forEach(([k, v]) => { if (!QUOTE[k]) QUOTE[k] = v; });
const ROLE = { R: '모집', M: '생산', D: '방어', P: '홍보' };
const CW = [6, 14, 30, 50, 80, 120, 160, 200], CST = [4, 10, 24, 40, 60, 90, 120, 150];   // 짓는 값(나무, 돌)
const PROD = [10, 22, 45, 90, 150, 120, 400, 2000];                                        // 생산 건물이 아침마다 주는 양
const RL = [1, 1.4, 2, 3, 5, 10, 25, 400], DEFK = 2;                                       // 모집 건물의 손님 운, 방어 건물 등급 배수
const DEF = { shoot: { dmg: 6, r: 4.5, cd: 0.8, proj: 'arrow' }, splash: { dmg: 12, r: 4.2, cd: 2.4, rad: 1.3, proj: 'stone' }, slow: { dmg: 2.5, r: 1.8, cd: 0.5 }, block: {}, heart: {} };
const DESC = { R: '사람들이 찾아온다. 가까이 가서 E로 들어가.', M: '아침마다 자원이 들어온다.', P: '명성이 올라 적이 세지는 대신 손님과 설계함 운이 오른다.', shoot: '밤에 화살을 쏜다.', splash: '밤에 적 무리에 돌을 던진다.', slow: '곁을 지나는 적을 느리게 하고 다치게 한다.', block: '아주 단단해서 적의 길을 막는다.', heart: '영주관이 받는 피해가 절반이 되고 밤새 성벽을 고친다.' };
const KIND = [
  { n: '창병', dmg: 7, r: 1.9, cd: 0.7 },
  { n: '궁수', dmg: 5, r: 5.2, cd: 0.9, proj: 'arrow' },
  { n: '방패병', dmg: 3, r: 1.7, cd: 0.9, guard: 1 },
  { n: '포수', dmg: 10, r: 3.8, cd: 2, proj: 'stone', rad: 1 },
  { n: '술사', dmg: 4, r: 3.8, cd: 1.1, proj: 'bolt', slow: 1 },
  { n: '사제', dmg: 0, r: 2.6, cd: 1, heal: 5 },
];
const SKILL = ['회전 베기', '관통 화살', '불굴', '대포격', '연쇄 번개', '축복'];
const GR = [['병졸', 1, 1, '#9aa4b2'], ['정병', 4, 2.5, '#4d96ff'], ['정예', 25, 6, '#ffc23d'], ['장수', 150, 15, '#c65bff'], ['영웅', 1500, 40, '#ffffff'], ['군신', 30000, 120, '#ff7a3d']];
const UP = [0.5, 0.4, 0.3, 0.2, 0.1, 0];            // 더 캐물으면 한 등급 오를 확률(실패하면 떠난다)
const GUARD = [0.2, 0.3, 0.4, 0.5, 0.75, 1];        // 영주가 쓰러질 때 곁의 사람이 대신 막아설 확률
const EN = {
  raider: { n: '약탈자', hp: 34, dmg: 6, spd: 1.5, r: 0.3, gold: 2, col: '#d9483f', cd: 1 },
  wolf: { n: '늑대', hp: 18, dmg: 4, spd: 2.9, r: 0.26, gold: 1, col: '#c08a55', cd: 0.7 },
  ram: { n: '공성추', hp: 160, dmg: 16, spd: 0.75, r: 0.46, gold: 6, col: '#7b4b2a', cd: 1.4, siege: 3, deaf: 1 },
  boss: { n: '약탈왕', hp: 2600, dmg: 28, spd: 1.1, r: 0.8, gold: 80, col: '#901425', cd: 1.3, siege: 2, boss: 1 },
};
const LORD = { hp: 140, spd: 4.3, dmg: 20, reach: 1.55, arc: 1.9, cd: 0.38, dashV: 13, dashT: 0.16, dashCd: 1.1, regen: 8, aggro: 2.6, rsp: [8, 15, 25] };
const NAMES = ['카일', '로엔', '에단', '루카', '세라', '아린', '테오', '리아', '바렌', '유릭', '노아', '엘린', '다리온', '미라', '하젤', '케인', '이솔', '라온', '벨라', '진', '오르카', '세인', '율리', '가온', '레나', '도르', '아셀', '티아', '루벤', '하린'];
const HELLO = [
  ['"영주님이십니까. 창 한 자루로 먹고삽니다."', '"줄 서는 건 자신 있습니다. 찌르는 것도요."'],
  ['"…멀리서 쏘는 쪽이 제 성미에 맞습니다."', '"바람만 읽으면 됩니다. 나머지는 화살이 합니다."'],
  ['"앞에 서는 건 제가 하겠습니다."', '"밀리지 않는 것, 그거 하나는 합니다."'],
  ['"화약 냄새가 싫지 않으시다면야."', '"한 방이면 됩니다. 대신 좀 느립니다."'],
  ['"…책에서 본 것보다 성벽이 낮군요."', '"발을 묶는 주문이라면 몇 개 압니다."'],
  ['"다친 이가 있으면 불러 주십시오."', '"기도는 길고, 붕대는 짧게 감습니다."'],
];
const HINT = ['평범한 차림이다.', '손에 굳은살이 박여 있다.', '눈빛이 예사롭지 않다.', '서 있는 자세에 빈틈이 없다.', '주위 공기가 무겁다.', '눈을 마주치기가 어렵다.'];
const STEP = ['', '"싸움이라면 조금 해 봤습니다."', '"…변경에서 세 해를 버텼습니다."', '"부대 하나를 맡았었습니다."', '"제 이름, 들어 보신 적 있을 겁니다."', '(주변 사람들이 하나둘 무릎을 꿇는다.)'];
const FINAL = ['"잘 부탁드립니다."', '"맡겨만 주십시오."', '"성벽 하나는 제가 지키겠습니다."', '"제 깃발 아래 모일 자들이 있을 겁니다."', '"이 영지, 오래가겠군요."', '"…영주여. 그대의 성은 무너지지 않는다."'];

// ===================== [상태] =====================
const newLord = () => ({ x: HX + 0.5, y: HY + 2.5, hp: LORD.hp, face: -Math.PI / 2, cd: 0, combo: 0, swing: 0, big: false, dash: 0, dx: 0, dy: 1, dashCd: 0, down: 0, downs: 0, inv: 0 });
const G = { day: 1, night: false, tDay: T_DAY, res: { wood: 40, stone: 40, gold: 0 }, boxes: BOX_DAY, bought: 0, cells: Array(MN * MN).fill(null),
  lord: newLord(), men: [], uid: 1, en: [], proj: [], fx: [], nums: [], bps: [], pick: null, talk: 4, inn: null, sides: [0], raid: null,
  shake: 0, hitstop: 0, slow: 0, flash: null, banner: null, over: null, t: 0, pend: null, force: -1, noRev: false, saved: false, dark: 0,
  st: { kills: 0, fallen: [], downs: 0, best: -1, bestName: '' }, rolls: 0,
  thr: 0, auto: false, autoT: 0, sold: 0,
  dbg: { ts: 1, god: false, ehp: 1, en: 1, forceG: -1, tday: T_DAY, fps: 60 } };
const rnd = n => Math.floor(Math.random() * n), clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const cIdx = (x, y) => { const X = Math.floor(x), Y = Math.floor(y); return X < 0 || Y < 0 || X >= MN || Y >= MN ? -1 : Y * MN + X; };
const isB = o => !!o && o.k === 'b', liveB = o => isB(o) && !o.ruin, solid = o => !!o && (o.k === 'wall' || o.k === 'hall' || liveB(o));
const blds = r => G.cells.filter(o => liveB(o) && o.r === r);
const fame = () => blds('P').reduce((s, o) => s + o.t + 1, 0), fameMul = () => 1 + 0.15 * fame();
const popCap = () => 5 + 2 * blds('R').length, talkMax = () => 3 + Math.min(5, blds('R').length);
const hasHeart = () => blds('D').some(o => o.d === 'heart');
const manAt = i => G.men.find(p => p.at === i);
const ppw = p => GR[p.g][2] * (1 + 0.2 * (p.lv - 1)) * (G.lord.down > 0 ? 0.75 : 1);
const bn = o => TIERS[o.t].name + ' ' + o.item;
const afford = t => G.res.wood >= CW[t] && G.res.stone >= CST[t];
const pay = (t, k = 1) => { G.res.wood -= Math.ceil(CW[t] * k); G.res.stone -= Math.ceil(CST[t] * k); };
const say = s => { const el = $('toast'); el.textContent = s; el.classList.add('on'); clearTimeout(say.k); say.k = setTimeout(() => el.classList.remove('on'), 2800); };
const sfx = f => { try { if (soundOn) f(); } catch (e) {} };
let lastHit = 0;
const hitSnd = v => { const n = performance.now(); if (n - lastHit < 45) return; lastHit = n; sfx(() => { tone('sine', 130, 50, 0.12, v); noise(0.06, v * 0.7, 2600, 400); }); };

// ===================== [규칙] 길찾기: 영주관에서 거꾸로 퍼지는 거리 =====================
const dist = new Float32Array(MN * MN);
function cost(i) {
  const o = G.cells[i]; if (!o) return 1;
  if (o.k === 'tree' || o.k === 'rock') return Infinity;
  if (o.k === 'hall') return 1; if (o.k === 'wall') return 10;
  if (o.k === 'b') return o.ruin ? 1.5 : o.d === 'block' ? 18 : 6;
  return 1;
}
function flow() {
  dist.fill(1e9); dist[HALL] = 0; const Q = [[0, HALL]];
  const up = i => { while (i > 0) { const p = (i - 1) >> 1; if (Q[p][0] <= Q[i][0]) break; [Q[p], Q[i]] = [Q[i], Q[p]]; i = p; } };
  const dn = i => { for (;;) { let m = i; const l = 2 * i + 1, r = l + 1; if (l < Q.length && Q[l][0] < Q[m][0]) m = l; if (r < Q.length && Q[r][0] < Q[m][0]) m = r; if (m === i) return; [Q[m], Q[i]] = [Q[i], Q[m]]; i = m; } };
  while (Q.length) {
    const [d, u] = Q[0], last = Q.pop(); if (Q.length) { Q[0] = last; dn(0); }
    if (d > dist[u]) continue;
    const cu = cost(u); if (!isFinite(cu)) continue;
    const ux = u % MN, uy = (u / MN) | 0;
    for (const [dx, dy] of N4) {
      const x = ux + dx, y = uy + dy; if (x < 0 || y < 0 || x >= MN || y >= MN) continue;
      const v = y * MN + x, nd = d + cu; if (nd < dist[v]) { dist[v] = nd; Q.push([nd, v]); up(Q.length - 1); }
    }
  }
}
// ===================== [규칙] 건물, 사람, 설계함 =====================
function grade(lu) { for (let i = GR.length - 1; i > 0; i--) if (Math.random() < lu / GR[i][1]) return i; return 0; }
function genVis(b) {
  return Array.from({ length: VIS }, () => {
    let g = grade(RL[b.t] * fameMul()); if (b.t === 7) g = Math.max(g, 4);
    const r = Math.random(), hg = clamp(g + (r < 0.55 ? 0 : r < 0.8 ? -1 : 1), 0, 5);
    return { k: rnd(KIND.length), g, hg, name: NAMES[rnd(NAMES.length)], hi: rnd(2), seen: false, gone: false };
  });
}
function mkB(h) { const mx = 140 * 1.6 ** h.t * (h.d === 'block' ? 4 : 1); const b = { k: 'b', t: h.t, item: h.item, r: h.r, d: h.d || null, hp: mx, max: mx, ruin: false, vis: [], cd: 0 }; if (b.r === 'R') b.vis = genVis(b); return b; }
function mkMan(v) { const p = { id: G.uid++, name: v.name, k: v.k, g: v.g, lv: 1, at: -1, down: 0, cd: 0, scd: 3 }; G.men.push(p); if (v.g > G.st.best) { G.st.best = v.g; G.st.bestName = GR[v.g][0] + ' ' + KIND[v.k].n + ' ' + v.name; } return p; }
function genMap() {
  const C = G.cells;
  for (let y = 2; y < MN - 2; y++) for (let x = 2; x < MN - 2; x++) {
    if (Math.max(Math.abs(x - HX), Math.abs(y - HY)) < 6) continue;
    const r = Math.random(); if (r < 0.1) C[y * MN + x] = { k: 'tree', hp: 4 }; else if (r < 0.14) C[y * MN + x] = { k: 'rock', hp: 5 };
  }
  C[HALL] = { k: 'hall', hp: HALL_HP, max: HALL_HP };
  for (let y = HY - 3; y <= HY + 3; y++) for (let x = HX - 3; x <= HX + 3; x++) if (Math.max(Math.abs(x - HX), Math.abs(y - HY)) === 3) C[y * MN + x] = { k: 'wall', hp: WALL_HP, max: WALL_HP };
  C[(HY - 1) * MN + HX - 1] = mkB({ t: 0, item: '주막', r: 'R' });
  C[(HY - 1) * MN + HX + 1] = mkB({ t: 0, item: '벌목장', r: 'M', d: 'wood' });
  C[(HY + 1) * MN + HX + 1] = mkB({ t: 0, item: '채석장', r: 'M', d: 'stone' });
  [0, 1, 2].forEach(k => mkMan({ k, g: 0, name: NAMES[rnd(NAMES.length)] }));
}
const boxPrice = () => BOX_GOLD;   // 확률은 뽑기 데모 그대로, 대신 많이 열 수 있게 싸게
const THR = ['거르기 끔', '흔함 거르기', '귀함까지 거르기', '전설까지 거르기'];
function openBox(quiet) {
  if (G.inn || G.over || S) return;
  if (G.boxes > 0) G.boxes--;
  else if (G.res.gold >= boxPrice()) { G.res.gold -= boxPrice(); G.bought++; }
  else { if (!quiet) say('설계함이 없어. 금화 ' + boxPrice() + '개로 하나 살 수 있어.'); return; }
  const l = fameMul();
  let t = 0; for (let i = TIERS.length - 1; i >= 1; i--) if (Math.random() < l / TIERS[i].odds) { t = i; break; }
  if (G.force >= 0) { t = G.force; G.force = -1; }
  const e = BLD[t][rnd(BLD[t].length)], b = { t, item: e[0], r: e[1], d: e[2] || null };
  G.rolls++;
  if (t >= REVEAL && !G.noRev) { G.pend = b; play(t, b.item, false); if (S) return; G.pend = null; }
  else { rolls++; owned[b.item] = (owned[b.item] || 0) + 1; save(); }
  got(b);
}
// 거른 설계도와 칸이 넘친 설계도는 짓는 값의 절반을 자원으로 돌려준다
function sell(b) { G.res.wood += Math.ceil(CW[b.t] / 2); G.res.stone += Math.ceil(CST[b.t] / 2); G.sold++; }
function got(b) {
  if (b.t >= 2) G.banner = { txt: bn(b), sub: ROLE[b.r] + ' 건물 설계도', c: TIERS[b.t].col, t: 0 };
  if (b.t < G.thr) { sell(b); if (!G.auto) say('거름: ' + bn(b) + ' → 자원'); drawBar(); return; }
  if (G.bps.length >= BP_MAX) {
    // 칸이 차면 가장 낮은 설계도를 자원으로 바꾸고 새 것을 넣는다. 새 것이 제일 낮으면 새 것을 바꾼다.
    let m = 0; G.bps.forEach((h, i) => { if (h.t < G.bps[m].t) m = i; });
    if (G.bps[m].t >= b.t) { sell(b); if (!G.auto) say('칸이 가득 차서 ' + b.item + '을(를) 자원으로 바꿨어.'); drawBar(); return; }
    sell(G.bps[m]); G.bps.splice(m, 1); if (G.pick && G.pick.bp != null) G.pick = null;
  }
  G.bps.push(b); drawBar(); if (!G.auto || b.t >= 1) say('설계함: ' + bn(b) + ' · ' + ROLE[b.r]);
}
function toggleAuto() { G.auto = !G.auto; G.autoT = 0; say(G.auto ? '자동 열기 켬. 설계함이 없으면 금화로 사서 연다.' : '자동 열기 끔.'); hud(); }
function cycleThr() { G.thr = (G.thr + 1) % THR.length; say(THR[G.thr] + (G.thr ? '. 걸러진 설계도는 자원이 된다.' : '')); hud(); }
function placeAt(i, drag) {
  const pk = G.pick; if (!pk || i < 0) return;
  const o = G.cells[i];
  if (pk.wall) {
    if (i === HALL) return;
    if (!o && pk.mode !== 'del') { if (G.res.stone < WALL_S) { if (!drag) say('돌이 모자라(성벽 ' + WALL_S + ').'); return; } if (Math.hypot(i % MN + 0.5 - G.lord.x, ((i / MN) | 0) + 0.5 - G.lord.y) < 0.6) return; G.res.stone -= WALL_S; G.cells[i] = { k: 'wall', hp: WALL_HP, max: WALL_HP }; pk.mode = 'add'; flow(); }
    else if (o && o.k === 'wall' && pk.mode !== 'add') { const m = manAt(i); if (m) m.at = -1; G.cells[i] = null; G.res.stone += 1; pk.mode = 'del'; flow(); drawRoster(); }
    return;
  }
  if (drag) return;
  if (pk.bp != null) {
    const h = G.bps[pk.bp]; if (!h) { G.pick = null; return; }
    if (o && !(isB(o) && o.ruin)) return say('빈 땅이나 폐허 위에만 지을 수 있어. 나무와 바위는 먼저 캐.');
    if (!afford(h.t)) return say('자원이 모자라(나무 ' + CW[h.t] + ', 돌 ' + CST[h.t] + ').');
    pay(h.t); G.cells[i] = mkB(h); G.bps.splice(pk.bp, 1); G.pick = null; flow(); drawBar();
    G.fx.push({ k: 'ring', x: i % MN + 0.5, y: ((i / MN) | 0) + 0.5, c: TIERS[h.t].col, t: 0, T: 0.6, r: 1.4 });
    sfx(() => { tone('sine', 90, 50, 0.3, 0.3); noise(0.15, 0.2, 1200, 200); });
    say(bn(h) + ' 완성. ' + DESC[h.d && DESC[h.d] ? h.d : h.r]);
    return;
  }
  if (pk.man) {
    const p = G.men.find(q => q.id === pk.man); G.pick = null;
    if (p && o && o.k === 'wall') { if (p.down) say('부상 중이라 못 서.'); else { const q = manAt(i); if (q && q !== p) q.at = p.at; p.at = i; say(GR[p.g][0] + ' ' + p.name + ', 성벽에 섰어.'); } }
    else say('사람은 성벽 위에만 세울 수 있어.');
    drawRoster();
  }
}
function nearInteract() {
  const L = G.lord; let best = -1, bd = 1.9;
  for (let y = Math.floor(L.y) - 2; y <= Math.floor(L.y) + 2; y++) for (let x = Math.floor(L.x) - 2; x <= Math.floor(L.x) + 2; x++) {
    const i = cIdx(x, y); if (i < 0) continue; const o = G.cells[i]; if (!o || (o.k !== 'b' && o.k !== 'hall')) continue;
    const d = Math.hypot(x + 0.5 - L.x, y + 0.5 - L.y); if (d < bd) { bd = d; best = i; }
  }
  return best;
}
function interact() {
  if (G.inn || G.over || G.lord.down > 0) return;
  const i = nearInteract(); if (i < 0) return;
  const o = G.cells[i];
  if (o.k === 'hall') return say('영주관 ' + Math.ceil(o.hp) + '/' + o.max + '. 여기가 무너지면 영지를 잃는다.');
  if (o.ruin) { if (!afford(o.t)) return say('고치려면 나무 ' + Math.ceil(CW[o.t] / 2) + ', 돌 ' + Math.ceil(CST[o.t] / 2) + '.'); pay(o.t, 0.5); o.ruin = false; o.hp = o.max; if (o.r === 'R' && !G.night) o.vis = genVis(o); flow(); return say(bn(o) + ' 다시 세웠어.'); }
  if (o.r === 'R') { if (G.night) return say('밤에는 문을 닫았어.'); return enter(i); }
  say(bn(o) + ' · ' + (o.r === 'M' ? '아침마다 ' + ({ wood: '나무', stone: '돌', both: '나무와 돌' })[o.d] + ' +' + PROD[o.t] : o.r === 'P' ? '명성 +' + (o.t + 1) + '. ' + DESC.P : DESC[o.d]));
}
// ===================== [규칙] 모집 건물 안: 말을 걸면 등급이 한 칸씩 드러난다 =====================
const cur = () => G.inn.b.vis[G.inn.sel];
function enter(i) { G.inn = { c: i, b: G.cells[i], sel: -1, st: 'idle', t: 0, ts: 0, step: -1, hold: 0, ps: [], shake: 0, line: '' }; G.pick = null; closeRoster(); innUI(); }
function leaveInn() { if (!G.inn || ['climb', 'press', 'leave'].includes(G.inn.st)) return; G.inn = null; innUI(); }
function innPick(i) { const I = G.inn, v = I.b.vis[i]; if (!v || v.gone || ['climb', 'press', 'leave'].includes(I.st)) return; I.sel = i; I.st = v.seen ? 'shown' : 'look'; I.t = 9; innUI(); }
function talk() { const I = G.inn; if (I.st !== 'look') return; if (G.talk <= 0) { $('inTxt').textContent = '오늘은 더 말을 걸 기운이 없다. 내일 다시 오자.'; return; } G.talk--; if (G.dbg.forceG >= 0) cur().g = G.dbg.forceG; I.st = 'climb'; I.step = -1; I.hold = 0.5; I.line = ''; innUI(); }
function stepFx(s) { const I = G.inn; I.ts = I.t; I.shake = 0.25 + 0.12 * s; I.line = ''; G.flash = { c: GR[s][3], a: 0.1 + 0.06 * s }; sfx(() => { tone('sine', 95 - s * 9, 36, 0.45, 0.28 + 0.08 * s); noise(0.1 + 0.04 * s, 0.14 + 0.05 * s, 1400, 160); }); }
function reveal() {
  const I = G.inn, v = cur(), g = v.g, x = innX(I.sel);
  v.seen = true; I.st = 'shown'; I.t = 0; I.shake = 0.4 + 0.3 * g; G.flash = { c: GR[g][3], a: 0.25 + 0.12 * g }; if (g >= 4) G.slow = 0.7;
  for (let i = 0, n = 10 + 30 * g; i < n; i++) { const a = Math.random() * 6.283, sp = 60 + Math.random() * (90 + 70 * g); I.ps.push({ x, y: IR.q * 0.62, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 60, l: 0, m: 0.8 + Math.random() * (0.6 + 0.3 * g), c: Math.random() < 0.3 ? '#ffffff' : GR[g][3] }); }
  sfx(() => { noise(0.4 + 0.25 * g, 0.1 + 0.06 * g, 3500, 180); tone('sine', 72, 30, 0.7 + 0.35 * g, 0.3 + 0.09 * g); if (g >= 3) choir([196, 246.9, 293.7].map(f => f * (g >= 5 ? 1.335 : 1)), 2 + 0.6 * g, 0.05 + 0.025 * (g - 3)); });
  innUI();
}
function press() { const I = G.inn; if (!I) return; const v = cur(); if (I.st !== 'shown' || v.g >= 5) return; if (G.talk <= 0) { $('inTxt').textContent = '오늘은 더 캐물을 기운이 없다.'; return; } G.talk--; I.st = 'press'; I.hold = 1.4; I.ok = Math.random() < UP[v.g]; I.shake = 0.15; innUI(); }
function hire() {
  const I = G.inn, v = cur(); if (!v || !v.seen || v.gone) return;
  if (G.men.length >= popCap()) { $('inTxt').textContent = '자리가 없어(' + popCap() + '명). 사람 목록에서 누군가 내보내야 해. 모집 건물을 지으면 늘어나.'; return; }
  mkMan(v); v.gone = true; I.sel = -1; I.st = 'idle'; innUI(); drawRoster(); say(GR[v.g][0] + ' ' + KIND[v.k].n + ' ' + v.name + ' 영입. 사람 목록(Tab)에서 성벽에 세워.');
}
function innUpdate(dt) {
  const I = G.inn; I.t += dt; I.shake = Math.max(0, I.shake - dt * 2.5);
  for (let i = I.ps.length - 1; i >= 0; i--) { const p = I.ps[i]; p.l += dt; p.x += p.vx * dt; p.y += p.vy * dt; p.vy += 120 * dt; p.vx *= 0.985; if (p.l > p.m) I.ps.splice(i, 1); }
  if (I.st === 'climb') { I.hold -= dt; if (I.hold <= 0) { const v = cur(); if (I.step < v.g) { I.step++; stepFx(I.step); I.hold = (0.75 + 0.15 * I.step) * (0.75 + Math.random() * 0.6); innUI(); } else reveal(); } }
  else if (I.st === 'press') { I.hold -= dt; if (I.hold <= 0) { const v = cur(); if (I.ok) { v.g++; v.seen = false; I.st = 'climb'; I.step = v.g - 1; I.ts = I.t; I.hold = 0.01; I.line = '"…들켰군요."'; } else { I.st = 'leave'; I.hold = 1.5; sfx(() => tone('sine', 60, 40, 0.5, 0.2)); } innUI(); } }
  else if (I.st === 'leave') { I.hold -= dt; if (I.hold <= 0) { cur().gone = true; I.st = 'idle'; I.sel = -1; innUI(); } }
}
// ===================== [규칙] 영주 =====================
function swing() {
  const L = G.lord; L.cd = LORD.cd; L.combo = (L.combo + 1) % 3; const big = L.combo === 2; L.swing = 0.2; L.big = big;
  const reach = LORD.reach * (big ? 1.25 : 1), arc = LORD.arc * (big ? 1.3 : 1), dmg = LORD.dmg * (big ? 1.7 : 1);
  let hit = 0;
  for (const e of G.en) {
    const dx = e.x - L.x, dy = e.y - L.y, d = Math.hypot(dx, dy); if (d > reach + e.r || e.dead) continue;
    let da = Math.atan2(dy, dx) - L.face; da = Math.atan2(Math.sin(da), Math.cos(da));
    if (Math.abs(da) > arc / 2 && d > e.r + 0.35) continue;
    hurtE(e, dmg, true, dx / (d || 1), dy / (d || 1)); hit++;
  }
  const fx = L.x + Math.cos(L.face) * 0.95, fy = L.y + Math.sin(L.face) * 0.95, i = cIdx(fx, fy), o = i >= 0 && G.cells[i];
  if (o && (o.k === 'tree' || o.k === 'rock')) {
    const tree = o.k === 'tree', n = (tree ? 3 : 2) + (big ? 2 : 0); o.hp--; o.shk = 0.15;
    if (tree) G.res.wood += n; else G.res.stone += n;
    G.nums.push({ x: i % MN + 0.5, y: ((i / MN) | 0) + 0.2, txt: '+' + n + (tree ? ' 나무' : ' 돌'), c: tree ? '#9fdc7c' : '#c9d2e6', t: 0 });
    if (o.hp <= 0) { G.cells[i] = null; flow(); G.fx.push({ k: 'burst', x: i % MN + 0.5, y: ((i / MN) | 0) + 0.5, c: tree ? '#4d7a3a' : '#8a90a3', t: 0, T: 0.6, n: 14 }); }
    sfx(() => { tone('triangle', tree ? 220 : 330, tree ? 120 : 180, 0.09, 0.18); noise(0.05, 0.12, 3000, 800); });
    hit++;
  }
  if (hit) { G.hitstop = big ? 0.07 : 0.035; G.shake = Math.max(G.shake, big ? 0.32 : 0.14); hitSnd(big ? 0.45 : 0.3); }
  else sfx(() => noise(0.09, 0.07, 1800, 600));
}
function hurtE(e, d, fromLord, kx, ky) {
  if (e.dead) return;
  e.hp -= d; e.flash = 0.1;
  if (fromLord) { const kb = EN[e.k].boss ? 0.05 : e.k === 'ram' ? 0.1 : 0.38; e.x += kx * kb; e.y += ky * kb; G.nums.push({ x: e.x, y: e.y - 0.4, txt: String(Math.round(d)), c: '#ffffff', t: 0, big: G.lord.big }); }
  if (e.hp <= 0) kill(e);
}
function kill(e) {
  e.dead = true; const D = EN[e.k]; G.res.gold += D.gold; G.st.kills++;
  G.fx.push({ k: 'burst', x: e.x, y: e.y, c: D.col, t: 0, T: 0.5, n: D.boss ? 60 : 10 });
  if (D.boss) { G.shake = 1; G.slow = 1.2; G.banner = { txt: D.n + ' 쓰러짐', sub: '금화 +' + D.gold, c: '#ffd76a', t: 0 }; sfx(() => { tone('sine', 60, 25, 2, 0.6); noise(1.4, 0.4, 3000, 100); }); }
}
function hurtLord(d) {
  const L = G.lord; if (L.inv > 0 || L.down > 0 || G.dbg.god) return;
  L.hp -= d; L.inv = 0.12; G.shake = Math.max(G.shake, 0.22); G.flash = { c: '#ff2a2a', a: 0.12 };
  sfx(() => { tone('sine', 90, 40, 0.18, 0.35); noise(0.08, 0.25, 900, 200); });
  if (L.hp > 0) return;
  if (!G.saved && guard()) return;
  L.hp = 0; L.down = LORD.rsp[Math.min(L.downs, 2)]; L.downs++; G.st.downs++; G.pick = null;
  G.banner = { txt: '영주가 쓰러졌다', sub: Math.round(L.down) + '초 뒤 영주관에서 일어난다 · 그동안 병사의 힘 -25%', c: '#ff5a5a', t: 0 }; G.shake = 0.8; G.flash = { c: '#ff0000', a: 0.4 };
  sfx(() => { tone('sine', 70, 30, 1.2, 0.5); noise(0.6, 0.3, 1500, 100); });
}
// 충신: 영주가 쓰러질 피해를 곁의 사람이 대신 받는다(한 밤에 한 번)
function guard() {
  const L = G.lord, c = G.men.filter(p => p.at >= 0 && !p.down && Math.hypot(p.at % MN + 0.5 - L.x, ((p.at / MN) | 0) + 0.5 - L.y) < 3.5).sort((a, z) => z.g - a.g);
  const p = c[0]; if (!p || Math.random() > GUARD[p.g]) return false;
  G.saved = true; L.hp = Math.max(1, LORD.hp * 0.25); L.inv = 1.5; G.slow = 1.1; G.shake = 0.6; G.flash = { c: GR[p.g][3], a: 0.45 };
  const x = p.at % MN + 0.5, y = ((p.at / MN) | 0) + 0.5; G.fx.push({ k: 'ring', x, y, c: GR[p.g][3], t: 0, T: 1, r: 3 });
  if (p.g >= 4) { p.down = 2; p.at = -1; G.banner = { txt: GR[p.g][0] + ' ' + p.name + ', 영주를 감쌌다', sub: '크게 다쳐 이틀을 쉰다', c: GR[p.g][3], t: 0 }; }
  else { G.men = G.men.filter(q => q !== p); G.st.fallen.push(GR[p.g][0] + ' ' + KIND[p.k].n + ' ' + p.name); G.banner = { txt: GR[p.g][0] + ' ' + p.name + ', 영주를 감쌌다', sub: '…그리고 일어나지 못했다', c: GR[p.g][3], t: 0 }; }
  sfx(() => { tone('sine', 110, 55, 1.6, 0.4); choir([220, 261.6, 329.6], 2.5, 0.06); });
  drawRoster(); return true;
}
function lordUpdate(dt, inp) {
  const L = G.lord;
  if (L.down > 0) { L.down -= dt; if (L.down <= 0) { L.x = HX + 0.5; L.y = HY + 1.5; L.hp = LORD.hp; L.inv = 2; G.fx.push({ k: 'ring', x: L.x, y: L.y, c: '#7fb2ff', t: 0, T: 0.8, r: 2 }); say('영주가 다시 일어났다.'); } return; }
  L.cd -= dt; L.swing -= dt; L.inv -= dt; L.dashCd -= dt;
  let mx = inp.x, my = inp.y; const m = Math.hypot(mx, my); if (m > 1) { mx /= m; my /= m; }
  if (m > 0.1) { L.dx = mx; L.dy = my; }
  if (inp.dash && L.dashCd <= 0 && L.dash <= 0) { L.dash = LORD.dashT; L.dashCd = LORD.dashCd; L.inv = Math.max(L.inv, LORD.dashT); sfx(() => noise(0.15, 0.12, 900, 3000, 0, true)); }
  let vx, vy;
  if (L.dash > 0) { L.dash -= dt; vx = L.dx * LORD.dashV; vy = L.dy * LORD.dashV; G.fx.push({ k: 'ghost', x: L.x, y: L.y, t: 0, T: 0.2, f: L.face }); }
  else { vx = mx * LORD.spd; vy = my * LORD.spd; }
  const blocked = (x, y) => { const o = G.cells[cIdx(x, y)]; return o && (o.k === 'tree' || o.k === 'rock'); };
  const nx = clamp(L.x + vx * dt, 0.3, MN - 0.3); if (!blocked(nx, L.y)) L.x = nx;
  const ny = clamp(L.y + vy * dt, 0.3, MN - 0.3); if (!blocked(L.x, ny)) L.y = ny;
  if (inp.aim) L.face = Math.atan2(inp.aim.y - L.y, inp.aim.x - L.x);
  else if (inp.auto) { let tg = null, td = 3.2; for (const e of G.en) { const d = Math.hypot(e.x - L.x, e.y - L.y); if (d < td) { td = d; tg = e; } } L.face = tg ? Math.atan2(tg.y - L.y, tg.x - L.x) : Math.atan2(L.dy, L.dx); }
  else if (m > 0.1) L.face = Math.atan2(my, mx);
  if (inp.atk && L.cd <= 0 && !G.pick) swing();
  if (!G.night) L.hp = Math.min(LORD.hp, L.hp + LORD.regen * dt);
}
// ===================== [규칙] 낮과 밤 =====================
const sidesFor = d => [0, 1, 2, 3].sort(() => Math.random() - 0.5).slice(0, d <= 3 ? 1 : d <= 5 ? 2 : 3);
function wave(d) {
  const n = Math.round((8 + 5 * d + Math.ceil(fame() / 2)) * G.dbg.en), L = [];
  for (let i = 0; i < n; i++) L.push(d >= 5 && i % 7 === 6 ? 'ram' : d >= 3 && i % 3 === 1 ? 'wolf' : 'raider');
  if (d >= 4) L.splice(Math.floor(n / 2), 0, 'ram');
  if (d === DAYS) L.push('boss');
  return L;
}
function startNight() {
  if (G.night) return;
  G.inn = null; innUI(); G.night = true; G.saved = false; G.pick = null;
  const list = wave(G.day); G.raid = { list, t: 1.5, n: list.length, hpk: 1.28 ** (G.day - 1) * 1.06 ** fame(), dk: 1.15 ** (G.day - 1) };
  G.banner = { txt: G.day + '일째 밤', sub: '적 ' + list.length + (G.sides.length > 1 ? ' · ' + G.sides.length + '방향' : '') + (G.day === DAYS ? ' · 약탈왕이 온다' : ''), c: '#ff6a5a', t: 0 };
  sfx(() => { tone('sine', 55, 30, 2.2, 0.5); noise(1.2, 0.2, 400, 60); });
}
function spawn(k) {
  const s = G.sides[rnd(G.sides.length)], q = 1 + rnd(MN - 2), D = EN[k];
  const [x, y] = [[q + 0.5, -0.7], [MN + 0.7, q + 0.5], [q + 0.5, MN + 0.7], [-0.7, q + 0.5]][s];
  const [ex, ey] = [[q, 0], [MN - 1, q], [q, MN - 1], [0, q]][s];
  const hp = D.hp * (D.boss ? 2.2 : G.raid.hpk) * G.dbg.ehp;
  G.en.push({ k, x, y, hp, max: hp, dmg: D.dmg * (D.boss ? 1.6 : G.raid.dk), r: D.r, st: 'move', nx: ex, ny: ey, tb: -1, acd: 0.5, flash: 0, lunge: 0, sl: 0, ang: 0, dead: false });
  if (D.boss) { G.banner = { txt: D.n + ' 등장', sub: '쓰러뜨리면 이 땅을 지킨다', c: '#ff5a5a', t: 0 }; G.shake = 0.6; sfx(() => { tone('sine', 45, 30, 2.5, 0.6); noise(1.5, 0.3, 300, 60); }); }
}
function dawn() {
  G.night = false; G.raid = null; G.en.length = 0; G.proj.length = 0; G.day++;
  if (G.day > DAYS) return gameOver(true);
  let w = 0, s = 0;
  for (const o of blds('M')) { const n = PROD[o.t]; if (o.d === 'wood') w += n; else if (o.d === 'stone') s += n; else { w += n; s += n; } }
  G.res.wood += w; G.res.stone += s; G.boxes += BOX_DAY; G.bought = 0; G.talk = talkMax(); G.tDay = G.dbg.tday; G.sides = sidesFor(G.day);
  for (const p of G.men) { p.lv++; if (p.down) p.down--; p.cd = 0; p.scd = 3; }
  for (const o of G.cells) { if (!o) continue; if (o.k === 'wall') o.hp = o.max; else if (liveB(o)) { o.hp = o.max; if (o.r === 'R') o.vis = genVis(o); } else if (o.k === 'hall') o.hp = Math.min(o.max, o.hp + o.max * 0.4); }
  const L = G.lord; L.downs = 0; if (L.down <= 0) L.hp = LORD.hp;
  G.banner = { txt: G.day + '일째 아침', sub: '나무 +' + w + ' · 돌 +' + s + ' · 설계함 +' + BOX_DAY + ' · 모든 사람 레벨 +1', c: '#ffd27a', t: 0 };
  drawRoster(); drawBar();
}
function gameOver(win) {
  G.over = { win }; G.inn = null; innUI();
  $('ovT').textContent = win ? '영지를 지켜냈다' : '영지가 함락됐다';
  $('ovP').innerHTML = (win ? DAYS + '일의 밤을 모두 넘기고 약탈왕을 물리쳤다.' : G.day + '일째 밤, 영주관이 무너졌다.') + '<br>처치 ' + G.st.kills + ' · 사람 ' + G.men.length + '명 · 영주가 쓰러진 횟수 ' + G.st.downs +
    (G.st.bestName ? '<br>가장 높은 사람: ' + G.st.bestName : '') + (G.st.fallen.length ? '<br>영주를 감싸고 떠난 사람: ' + G.st.fallen.join(', ') : '');
  $('td').classList.add('ov');
  sfx(() => { if (win) choir([196, 246.9, 293.7, 392], 4, 0.08); else tone('sine', 50, 25, 3, 0.5); });
}
function enemyUpdate(e, dt) {
  const D = EN[e.k], L = G.lord; e.flash -= dt; e.lunge -= dt; e.sl -= dt; e.acd -= dt;
  const spd = D.spd * (e.sl > 0 ? 0.5 : 1);
  if (!D.deaf && L.down <= 0) {
    const dx = L.x - e.x, dy = L.y - e.y, d = Math.hypot(dx, dy);
    if (d < LORD.aggro || (e.tb === 'L' && d < LORD.aggro + 1.5)) {
      e.ang = Math.atan2(dy, dx);
      if (d < e.r + 0.55) { e.tb = 'L'; if (e.acd <= 0) { e.acd = D.cd; e.lunge = 0.15; hurtLord(e.dmg); } return; }
      const nx = e.x + dx / d * spd * dt, ny = e.y + dy / d * spd * dt, c = cIdx(nx, ny);
      if (c >= 0 && c !== cIdx(e.x, e.y) && solid(G.cells[c])) { attackCell(e, c); return; }
      e.x = nx; e.y = ny; e.tb = 'L'; e.st = 'pick'; return;
    }
  }
  if (e.tb === 'L') { e.tb = -1; e.st = 'pick'; }
  if (e.st === 'pick') pickNext(e);
  if (e.st === 'move') {
    const tx = e.nx + 0.5, ty = e.ny + 0.5, dx = tx - e.x, dy = ty - e.y, d = Math.hypot(dx, dy), st = spd * dt;
    e.ang = Math.atan2(dy, dx);
    if (d <= Math.max(st, 0.22)) { e.st = 'pick'; } else { e.x += dx / d * st; e.y += dy / d * st; }
  } else if (e.st === 'atk') { if (solid(G.cells[e.tb])) attackCell(e, e.tb); else e.st = 'pick'; }
}
function pickNext(e) {
  const X = clamp(Math.floor(e.x), 0, MN - 1), Y = clamp(Math.floor(e.y), 0, MN - 1), c = Y * MN + X;
  if (solid(G.cells[c])) { e.st = 'atk'; e.tb = c; return; }
  let best = -1, bd = Infinity;
  for (const [dx, dy] of N4) { const x = X + dx, y = Y + dy; if (x < 0 || y < 0 || x >= MN || y >= MN) continue; const n = y * MN + x, v = cost(n) + dist[n] + Math.random() * 0.3; if (v < bd) { bd = v; best = n; } }
  if (best < 0) return;
  if (solid(G.cells[best])) { e.st = 'atk'; e.tb = best; } else { e.st = 'move'; e.nx = best % MN; e.ny = (best / MN) | 0; }
}
function attackCell(e, c) {
  const D = EN[e.k]; e.ang = Math.atan2(((c / MN) | 0) + 0.5 - e.y, c % MN + 0.5 - e.x);
  if (e.acd > 0) return; e.acd = D.cd; e.lunge = 0.15; hitCell(c, e.dmg * (D.siege || 1));
}
function hitCell(c, d) {
  const o = G.cells[c], x = c % MN + 0.5, y = ((c / MN) | 0) + 0.5;
  if (o.k === 'hall') { o.hp -= d * (hasHeart() ? 0.5 : 1); o.shk = 0.15; if (o.hp <= 0) gameOver(false); return; }
  if (o.k === 'wall') {
    const m = manAt(c); o.hp -= d * (m && KIND[m.k].guard ? 1 / (1 + 0.6 * Math.sqrt(ppw(m))) : 1); o.shk = 0.12;
    if (o.hp <= 0) {
      G.cells[c] = null; flow(); G.fx.push({ k: 'burst', x, y, c: '#8a90a3', t: 0, T: 0.6, n: 16 }); G.shake = Math.max(G.shake, 0.25);
      sfx(() => { noise(0.4, 0.3, 800, 80); tone('sine', 60, 30, 0.5, 0.3); });
      if (m) { m.down = 2; m.at = -1; drawRoster(); say('성벽이 뚫렸어! ' + GR[m.g][0] + ' ' + m.name + ' 다쳐서 이틀 쉬어야 해.'); } else say('성벽이 뚫렸어!');
    }
    return;
  }
  o.hp -= d; o.shk = 0.12;
  if (o.hp <= 0) { o.ruin = true; o.vis = []; flow(); G.fx.push({ k: 'burst', x, y, c: TIERS[o.t].col, t: 0, T: 0.7, n: 20 }); say(bn(o) + ' 무너졌어. 아침에 가까이 가서 E로 고쳐.'); G.shake = Math.max(G.shake, 0.3); sfx(() => noise(0.6, 0.3, 1000, 80)); }
}
function nearestE(x, y, r) { let tg = null, td = r * r; for (const e of G.en) { if (e.dead) continue; const d = (e.x - x) ** 2 + (e.y - y) ** 2; if (d <= td) { td = d; tg = e; } } return tg; }
function shoot(kind, x, y, tg, dmg, o = {}) {
  if (kind === 'stone') { const tx = tg.x, ty = tg.y, d = Math.hypot(tx - x, ty - y); G.proj.push({ kind, x0: x, y0: y, x, y, tx, ty, t: 0, T: Math.max(0.35, d / 8), dmg, rad: o.rad || 1, h: 0 }); }
  else G.proj.push({ kind, x, y, tg, tx: tg.x, ty: tg.y, spd: kind === 'bolt' ? 18 : 15, dmg, slow: o.slow });
}
function skill(p, x, y, tg) {
  const k = p.k, pw = ppw(p), col = GR[p.g][3]; p.scd = 9;
  G.nums.push({ x, y: y - 0.9, txt: SKILL[k], c: col, t: 0, big: true }); G.fx.push({ k: 'ring', x, y, c: col, t: 0, T: 0.7, r: 2.4 });
  if (k === 0) { for (const e of G.en) if (Math.hypot(e.x - x, e.y - y) < 2.4) hurtE(e, 6 * pw); }
  else if (k === 1) { const a = Math.atan2(tg.y - y, tg.x - x); for (const e of G.en) { const dx = e.x - x, dy = e.y - y, along = dx * Math.cos(a) + dy * Math.sin(a), off = Math.abs(-dx * Math.sin(a) + dy * Math.cos(a)); if (along > 0 && along < 9 && off < 0.7) hurtE(e, 5 * pw); } G.fx.push({ k: 'beam', x, y, a, c: col, t: 0, T: 0.35 }); }
  else if (k === 2) { for (let d = 0; d < MN * MN; d++) { const o = G.cells[d]; if (o && o.k === 'wall' && Math.hypot(d % MN + 0.5 - x, ((d / MN) | 0) + 0.5 - y) < 3) o.hp = Math.min(o.max * 1.5, o.hp + o.max * 0.5); } }
  else if (k === 3) { for (const e of G.en) if (Math.hypot(e.x - tg.x, e.y - tg.y) < 2) hurtE(e, 10 * pw); G.fx.push({ k: 'ring', x: tg.x, y: tg.y, c: '#ff9a3c', t: 0, T: 0.6, r: 2 }); G.shake = Math.max(G.shake, 0.3); }
  else if (k === 4) { let a = tg; const hit = new Set(); for (let i = 0; i < 5 && a; i++) { hit.add(a); hurtE(a, 4 * pw); a.sl = 1.5; const n = G.en.filter(e => !hit.has(e) && !e.dead).sort((u, v) => Math.hypot(u.x - a.x, u.y - a.y) - Math.hypot(v.x - a.x, v.y - a.y))[0]; if (n) G.fx.push({ k: 'zap', x: a.x, y: a.y, x2: n.x, y2: n.y, t: 0, T: 0.3 }); a = n && Math.hypot(n.x - a.x, n.y - a.y) < 3 ? n : null; } }
  else { const L = G.lord; if (L.down <= 0 && Math.hypot(L.x - x, L.y - y) < 4) L.hp = Math.min(LORD.hp, L.hp + 45); for (let d = 0; d < MN * MN; d++) { const o = G.cells[d]; if (o && o.k === 'wall' && Math.hypot(d % MN + 0.5 - x, ((d / MN) | 0) + 0.5 - y) < 3) o.hp = Math.min(o.max, o.hp + o.max * 0.4); } }
  sfx(() => { tone('sine', 160, 60, 0.5, 0.3); noise(0.3, 0.2, 4000, 300); });
}
function nightUpdate(dt) {
  const R = G.raid; R.t -= dt;
  if (R.list.length && R.t <= 0) { R.t = 0.5; spawn(R.list.shift()); }
  for (const e of G.en) if (!e.dead) enemyUpdate(e, dt);
  // 서로 겹치지 않게 살짝 민다
  for (let i = 0; i < G.en.length; i++) { const a = G.en[i]; for (let j = i + 1; j < G.en.length; j++) { const b = G.en[j], dx = b.x - a.x, dy = b.y - a.y, d = Math.hypot(dx, dy), m = a.r + b.r; if (d > 0.001 && d < m) { const k = (m - d) / d * 0.5; a.x -= dx * k * 0.5; a.y -= dy * k * 0.5; b.x += dx * k * 0.5; b.y += dy * k * 0.5; } } }
  for (const p of G.men) {
    if (p.at < 0 || p.down) continue;
    const K = KIND[p.k], x = p.at % MN + 0.5, y = ((p.at / MN) | 0) + 0.5, pw = ppw(p);
    p.cd -= dt; p.scd -= dt;
    if (K.heal) {
      for (let d = 0; d < MN * MN; d++) { const o = G.cells[d]; if (o && o.k === 'wall' && Math.hypot(d % MN + 0.5 - x, ((d / MN) | 0) + 0.5 - y) < K.r) o.hp = Math.min(o.max, o.hp + K.heal * pw * dt); }
      const L = G.lord; if (L.down <= 0 && Math.hypot(L.x - x, L.y - y) < K.r + 1) L.hp = Math.min(LORD.hp, L.hp + K.heal * pw * 0.4 * dt);
      if (p.g >= 3 && p.scd <= 0 && G.en.length) skill(p, x, y, null);
      continue;
    }
    const tg = nearestE(x, y, K.r); if (!tg) continue;
    if (p.g >= 3 && p.scd <= 0) { skill(p, x, y, tg); continue; }
    if (p.cd > 0) continue; p.cd = K.cd; p.atk = 0.15; p.ang = Math.atan2(tg.y - y, tg.x - x);
    if (K.proj) shoot(K.proj, x, y - 0.3, tg, K.dmg * pw, { rad: K.rad, slow: K.slow });
    else { hurtE(tg, K.dmg * pw); G.fx.push({ k: 'slash', x: tg.x, y: tg.y, a: p.ang, c: '#ffffff', t: 0, T: 0.15 }); }
  }
  for (let c = 0; c < MN * MN; c++) {
    const o = G.cells[c]; if (!liveB(o) || o.r !== 'D') continue;
    const x = c % MN + 0.5, y = ((c / MN) | 0) + 0.5, k = DEFK ** o.t; o.cd -= dt;
    if (o.d === 'heart') { for (const w of G.cells) if (w && w.k === 'wall') w.hp = Math.min(w.max, w.hp + 3 * k * dt); continue; }
    const D = DEF[o.d]; if (!D.r || o.cd > 0) continue;
    if (o.d === 'slow') { let any = false; for (const e of G.en) if (!e.dead && Math.hypot(e.x - x, e.y - y) < D.r) { hurtE(e, D.dmg * k); e.sl = 0.6; any = true; } if (any) { o.cd = D.cd; G.fx.push({ k: 'ring', x, y, c: '#c65bff', t: 0, T: 0.4, r: D.r }); } continue; }
    const tg = nearestE(x, y, D.r); if (!tg) continue; o.cd = D.cd;
    shoot(D.proj, x, y - 0.6, tg, D.dmg * k, { rad: D.rad });
  }
  for (let i = G.proj.length - 1; i >= 0; i--) {
    const q = G.proj[i];
    if (q.kind === 'stone') {
      q.t += dt; const k = Math.min(1, q.t / q.T); q.x = q.x0 + (q.tx - q.x0) * k; q.y = q.y0 + (q.ty - q.y0) * k; q.h = 4 * k * (1 - k) * Math.min(3, q.T * 3);
      if (k >= 1) { for (const e of G.en) if (Math.hypot(e.x - q.tx, e.y - q.ty) < q.rad) hurtE(e, q.dmg); G.fx.push({ k: 'ring', x: q.tx, y: q.ty, c: '#ffae5a', t: 0, T: 0.35, r: q.rad }); hitSnd(0.15); G.proj.splice(i, 1); }
      continue;
    }
    if (q.tg && !q.tg.dead) { q.tx = q.tg.x; q.ty = q.tg.y; }
    const dx = q.tx - q.x, dy = q.ty - q.y, d = Math.hypot(dx, dy), st = q.spd * dt; q.a = Math.atan2(dy, dx);
    if (d <= st + 0.1) { if (q.tg && !q.tg.dead) { hurtE(q.tg, q.dmg); if (q.slow) q.tg.sl = 0.8; } G.proj.splice(i, 1); }
    else { q.x += dx / d * st; q.y += dy / d * st; }
  }
  G.en = G.en.filter(e => !e.dead);
  if (!G.over && !R.list.length && !G.en.length) dawn();
}
// 적이 걸어올 길을 따라가 보고, 두드려질 성벽에 방패병부터, 그 곁에 센 사람 순으로 세운다
function autoStation() {
  const hitN = new Map();
  for (const s of G.sides) for (let q = 1; q < MN - 1; q += 2) {
    let [x, y] = [[q, 0], [MN - 1, q], [q, MN - 1], [0, q]][s];
    for (let st = 0; st < 120; st++) {
      let best = -1, bd = Infinity;
      for (const [dx, dy] of N4) { const X = x + dx, Y = y + dy; if (X < 0 || Y < 0 || X >= MN || Y >= MN) continue; const n = Y * MN + X, v = cost(n) + dist[n]; if (v < bd) { bd = v; best = n; } }
      if (best < 0 || best === HALL) break;
      if (solid(G.cells[best])) { if (G.cells[best].k === 'wall') hitN.set(best, (hitN.get(best) || 0) + 1); break; }
      x = best % MN; y = (best / MN) | 0;
    }
  }
  const score = c => { let v = 0; for (const [h, n] of hitN) v += n / (1 + (c % MN - h % MN) ** 2 + (((c / MN) | 0) - ((h / MN) | 0)) ** 2); return v + (hitN.has(c) ? 100 : 0); };
  const walls = []; G.cells.forEach((o, c) => { if (o && o.k === 'wall') walls.push(c); });
  walls.sort((a, z) => score(z) - score(a));
  const men = G.men.filter(p => !p.down).sort((a, z) => (KIND[z.k].guard || 0) - (KIND[a.k].guard || 0) || ppw(z) - ppw(a));
  for (const p of G.men) p.at = -1;
  men.forEach((p, i) => { if (i < walls.length) p.at = walls[i]; });
  drawRoster(); say(walls.length ? '적이 두드릴 성벽부터 세웠어.' : '성벽이 없어. F로 성벽을 쌓아.');
}
function update(dt, inp) {
  G.t += dt;
  for (const f of G.fx) f.t += dt; G.fx = G.fx.filter(f => f.t < f.T);
  for (const n of G.nums) n.t += dt; G.nums = G.nums.filter(n => n.t < 0.9);
  if (G.banner && (G.banner.t += dt) > 3) G.banner = null;
  for (const o of G.cells) if (o && o.shk > 0) o.shk -= dt;
  if (G.over) return;
  if (G.inn) { innUpdate(dt); return; }
  if (G.auto && (G.autoT -= dt) <= 0) { G.autoT = 1; if (G.boxes > 0 || G.res.gold >= boxPrice()) openBox(true); }
  lordUpdate(dt, inp);
  for (const p of G.men) if (p.atk > 0) p.atk -= dt;
  if (!G.night) { G.tDay -= dt; if (G.tDay <= 0) startNight(); else if (Math.abs(G.tDay - 15) < dt) say('곧 밤이 온다. 빨간 쪽에서 적이 와.'); return; }
  nightUpdate(dt);
}

// ===================== [화면] =====================
const cv = $('tdCv'), c = cv.getContext('2d'), lc = document.createElement('canvas'), lx = lc.getContext('2d');
let W = 0, H = 0, DPR = 1, Z = 1; const cam = { x: HX + 0.5, y: HY + 1.5 }, IR = { q: 300, ox: 0, oy: 60 };
const PX = () => CELL * Z, sx = x => (x - cam.x) * PX() + W / 2, sy = y => (y - cam.y) * PX() + H / 2;
const wx = X => (X - W / 2) / PX() + cam.x, wy = Y => (Y - H / 2) / PX() + cam.y;
const innX = i => IR.q * (0.2 + 0.3 * i);
function layout() {
  DPR = Math.min(2, devicePixelRatio || 1); W = innerWidth; H = innerHeight;
  cv.width = Math.round(W * DPR); cv.height = Math.round(H * DPR); cv.style.width = W + 'px'; cv.style.height = H + 'px';
  lc.width = Math.ceil(W / 2); lc.height = Math.ceil(H / 2);
  if (!layout.z) { Z = W < 700 ? 0.8 : 1.05; layout.z = 1; }
  IR.q = Math.min(W - 24, H - 250, 620); IR.ox = (W - IR.q) / 2; IR.oy = Math.max(56, (H - 230 - IR.q) / 2 + 40);
}
const hash = i => { let h = i * 374761393; h = (h ^ (h >> 13)) * 1274126177; return ((h ^ (h >> 16)) >>> 0) / 4294967296; };
function rr(x, y, w, h, r) { c.beginPath(); c.roundRect(x, y, w, h, r); }
// 칸 하나를 높이가 있는 덩어리로 그린다(윗면은 높이만큼 위로, 앞면은 그 아래)
function block(x, y, s, h, top, front, line) { c.fillStyle = front; c.fillRect(x, y + s - h, s, h); c.fillStyle = top; c.fillRect(x, y - h, s, s); if (line) { c.strokeStyle = line; c.lineWidth = 1.5; c.strokeRect(x + 0.75, y - h + 0.75, s - 1.5, s - 1.5); } }
function sol(x, y, h, k, g, mono) {
  const col = mono || GR[g][3], pale = mono || '#dfe6f0', u = h / 40 * (mono ? 1 : g === 5 ? 1.2 : g === 4 ? 1.1 : 1);
  c.save(); c.translate(x, y); c.scale(u, u);
  if (!mono && g >= 4) { c.strokeStyle = g === 5 ? '#ffc23d' : 'rgba(255,255,255,.5)'; c.lineWidth = 1.2; c.beginPath(); c.arc(0, -20, 23, 0, 7); c.stroke(); }
  if (!mono && g >= 3) { c.fillStyle = 'rgba(0,0,0,.45)'; c.beginPath(); c.moveTo(-9, -26); c.lineTo(-15, 2); c.lineTo(6, 2); c.lineTo(5, -26); c.fill(); }
  c.fillStyle = col; c.beginPath();
  if (k === 2) c.rect(-8, -26, 16, 26); else if (k === 3) c.ellipse(2, -12, 9, 12, 0, 0, 7); else if (k === 4) { c.moveTo(-10, 0); c.lineTo(10, 0); c.lineTo(0, -28); }
  else { const w = k === 1 ? 6 : k === 5 ? 11 : 8, v = Math.min(5, w - 2); c.moveTo(-w, 0); c.lineTo(w, 0); c.lineTo(v, -26); c.lineTo(-v, -26); }
  c.fill();
  if (!mono && g >= 1 && k !== 3 && k !== 4) { c.fillStyle = g >= 3 ? '#ffc23d' : '#dfe6f0'; c.fillRect(-5, -14, 10, 3); }
  const hx = k === 3 ? 2 : 0; c.fillStyle = mono || '#e9e4da'; c.beginPath(); c.arc(hx, -33, 6, 0, 7); c.fill();
  if (k === 4) { c.fillStyle = mono || (g >= 2 ? GR[g][3] : '#5a6a90'); c.beginPath(); c.moveTo(-7, -36); c.lineTo(0, -53); c.lineTo(7, -36); c.fill(); }
  else if (!mono && g >= 2) { c.fillStyle = g >= 4 ? '#ffc23d' : '#ff5a4d'; c.beginPath(); c.moveTo(hx - 4, -38); c.lineTo(hx, -48); c.lineTo(hx + 4, -38); c.fill(); }
  c.strokeStyle = pale; c.fillStyle = pale; c.lineWidth = 2;
  if (k === 0) { c.beginPath(); c.moveTo(12, 2); c.lineTo(12, -50); c.stroke(); c.beginPath(); c.moveTo(12, -58); c.lineTo(9, -50); c.lineTo(15, -50); c.fill(); }
  else if (k === 1) { c.beginPath(); c.moveTo(-12, -34); c.quadraticCurveTo(-25, -17, -12, 0); c.stroke(); }
  else if (k === 2) { c.beginPath(); c.roundRect(-18, -25, 15, 22, 3); c.fill(); }
  else if (k === 3) { c.fillRect(-25, -13, 18, 7); c.fillStyle = mono || '#8892a6'; c.beginPath(); c.arc(-13, -4, 4.5, 0, 7); c.fill(); }
  else if (k === 4) { c.fillStyle = mono || '#7df9ff'; c.beginPath(); c.arc(15, -24, 4.5, 0, 7); c.fill(); }
  else { c.beginPath(); c.moveTo(-15, 2); c.lineTo(-15, -40); c.stroke(); c.beginPath(); c.arc(-15, -44, 3.5, 0, 7); c.stroke(); c.strokeStyle = mono || '#ffc23d'; c.beginPath(); c.ellipse(0, -44, 7, 2.5, 0, 0, 7); c.stroke(); }
  c.restore();
}
function glyph(o, x, y, s) {   // 건물 윗면의 역할 그림
  const m = x + s / 2; c.fillStyle = TIERS[o.t].col; c.strokeStyle = TIERS[o.t].col; c.lineWidth = 2;
  if (o.r === 'R') { c.beginPath(); c.moveTo(x + s * 0.15, y + s * 0.5); c.lineTo(m, y + s * 0.12); c.lineTo(x + s * 0.85, y + s * 0.5); c.fill(); c.fillStyle = '#0b1020'; c.fillRect(m - s * 0.08, y + s * 0.5, s * 0.16, s * 0.3); }
  else if (o.r === 'M') { const b = s * 0.22; c.fillRect(m - b - 1, y + s * 0.5, b, b); c.fillRect(m + 1, y + s * 0.5, b, b); c.fillRect(m - b / 2, y + s * 0.5 - b - 2, b, b); }
  else if (o.r === 'P') { c.beginPath(); c.moveTo(x + s * 0.32, y + s * 0.85); c.lineTo(x + s * 0.32, y + s * 0.15); c.stroke(); c.beginPath(); c.moveTo(x + s * 0.34, y + s * 0.18); c.lineTo(x + s * 0.8, y + s * 0.32); c.lineTo(x + s * 0.34, y + s * 0.46); c.fill(); }
  else if (o.d === 'shoot') { c.fillRect(m - s * 0.14, y + s * 0.3, s * 0.28, s * 0.5); for (let i = 0; i < 3; i++) c.fillRect(m - s * 0.18 + i * s * 0.13, y + s * 0.18, s * 0.09, s * 0.13); }
  else if (o.d === 'slow') { c.beginPath(); for (let i = 0; i < 4; i++) { const a = x + s * (0.18 + i * 0.16); c.moveTo(a, y + s * 0.75); c.lineTo(a + s * 0.08, y + s * 0.35); c.lineTo(a + s * 0.16, y + s * 0.75); } c.fill(); }
  else if (o.d === 'splash') { c.fillRect(x + s * 0.2, y + s * 0.68, s * 0.6, s * 0.12); c.beginPath(); c.moveTo(x + s * 0.36, y + s * 0.68); c.lineTo(x + s * 0.7, y + s * 0.26); c.stroke(); c.beginPath(); c.arc(x + s * 0.72, y + s * 0.24, s * 0.08, 0, 7); c.fill(); }
  else if (o.d === 'block') { for (let i = 0; i < 4; i++) c.fillRect(x + s * (0.22 + i * 0.16), y + s * 0.2, 2.5, s * 0.6); c.fillRect(x + s * 0.2, y + s * 0.4, s * 0.6, 2.5); c.fillRect(x + s * 0.2, y + s * 0.62, s * 0.6, 2.5); }
  else { c.beginPath(); c.moveTo(m, y + s * 0.14); c.lineTo(x + s * 0.76, y + s * 0.5); c.lineTo(m, y + s * 0.86); c.lineTo(x + s * 0.24, y + s * 0.5); c.fill(); }
}
function bar(x, y, w, k, col) { c.fillStyle = 'rgba(0,0,0,.6)'; c.fillRect(x - 1, y - 1, w + 2, 5); c.fillStyle = col; c.fillRect(x, y, w * clamp(k, 0, 1), 3); }
function drawCell(i, o) {
  const s = PX(), X = i % MN, Y = (i / MN) | 0, sh = o.shk > 0 ? (Math.random() - 0.5) * 4 : 0, x = sx(X) + sh, y = sy(Y);
  if (o.k === 'tree') {
    c.fillStyle = 'rgba(0,0,0,.25)'; c.beginPath(); c.ellipse(x + s / 2, y + s * 0.85, s * 0.38, s * 0.13, 0, 0, 7); c.fill();
    c.fillStyle = '#5a3d24'; c.fillRect(x + s * 0.44, y + s * 0.45, s * 0.12, s * 0.4);
    const v = hash(i); c.fillStyle = v < 0.5 ? '#2f5a2a' : '#356630'; c.beginPath(); c.arc(x + s / 2, y + s * 0.25, s * (0.42 + 0.08 * v), 0, 7); c.fill();
    c.fillStyle = 'rgba(255,255,255,.07)'; c.beginPath(); c.arc(x + s * 0.4, y + s * 0.12, s * 0.2, 0, 7); c.fill();
  } else if (o.k === 'rock') {
    c.fillStyle = 'rgba(0,0,0,.25)'; c.beginPath(); c.ellipse(x + s / 2, y + s * 0.8, s * 0.4, s * 0.13, 0, 0, 7); c.fill();
    c.fillStyle = '#6f7486'; c.beginPath(); c.moveTo(x + s * 0.12, y + s * 0.8); c.lineTo(x + s * 0.25, y + s * 0.3); c.lineTo(x + s * 0.6, y + s * 0.18); c.lineTo(x + s * 0.88, y + s * 0.5); c.lineTo(x + s * 0.85, y + s * 0.8); c.fill();
    c.fillStyle = '#8a90a3'; c.beginPath(); c.moveTo(x + s * 0.25, y + s * 0.3); c.lineTo(x + s * 0.6, y + s * 0.18); c.lineTo(x + s * 0.55, y + s * 0.48); c.fill();
  } else if (o.k === 'wall') {
    const h = s * 0.55; block(x, y, s, h, '#8a90a3', '#4f5568');
    c.fillStyle = '#9aa0b4'; for (let k = 0; k < 3; k++) c.fillRect(x + 2 + k * (s - 4) / 3, y - h - s * 0.14, (s - 4) / 3 - 3, s * 0.16);
    if (o.hp < o.max) bar(x + 3, y + s - 6, s - 6, o.hp / o.max, '#c9d2e6');
    const m = manAt(i); if (m) {
      if (G.pick && G.pick.man === m.id) { c.strokeStyle = '#fff'; c.lineWidth = 2; c.strokeRect(x + 1, y - h + 1, s - 2, s - 2); }
      const bob = m.atk > 0 ? -3 : 0; sol(x + s / 2, y - h + s * 0.72 + bob, s * 0.62, m.k, m.g);
      if (m.g >= 3 && G.night) { const k = clamp(1 - m.scd / 9, 0, 1); c.strokeStyle = GR[m.g][3]; c.lineWidth = 2; c.beginPath(); c.arc(x + s / 2, y - h - s * 0.35, 4, -Math.PI / 2, -Math.PI / 2 + k * 6.283); c.stroke(); }
    }
  } else if (o.k === 'hall') {
    const h = s * 1.2, ox = x - s * 0.25, w = s * 1.5;
    c.fillStyle = 'rgba(0,0,0,.3)'; c.fillRect(ox, y + s * 0.8, w, s * 0.25);
    c.fillStyle = '#5b3d63'; c.fillRect(ox, y + s - h, w, h); c.fillStyle = '#7d5a88'; c.fillRect(ox, y - h, w, s);
    c.fillStyle = '#ff5a8a'; c.beginPath(); c.moveTo(ox - 2, y - h + 2); c.lineTo(ox + w / 2, y - h - s * 0.6); c.lineTo(ox + w + 2, y - h + 2); c.fill();
    c.fillStyle = '#2a1a30'; c.beginPath(); c.moveTo(ox + w / 2 - s * 0.16, y + s); c.lineTo(ox + w / 2 - s * 0.16, y + s * 0.6); c.arc(ox + w / 2, y + s * 0.6, s * 0.16, Math.PI, 0); c.lineTo(ox + w / 2 + s * 0.16, y + s); c.fill();
    c.fillStyle = '#ffd76a'; c.fillRect(ox + w / 2 - 1, y - h - s * 1.05, 2, s * 0.5); c.beginPath(); c.moveTo(ox + w / 2 + 1, y - h - s * 1.05); c.lineTo(ox + w / 2 + s * 0.4, y - h - s * 0.92); c.lineTo(ox + w / 2 + 1, y - h - s * 0.8); c.fill();
    bar(ox, y + s + 3, w, o.hp / o.max, '#ff5a8a');
  } else if (o.k === 'b') {
    if (o.ruin) { c.fillStyle = '#3a3f50'; for (let k = 0; k < 5; k++) { const a = hash(i + k), b = hash(i * 7 + k); c.fillRect(x + s * (0.1 + a * 0.6), y + s * (0.45 + b * 0.35), s * 0.25, s * 0.16); } return; }
    const h = s * 0.75; block(x, y, s, h, '#2c3657', '#1b2238', TIERS[o.t].col); glyph(o, x, y - h, s);
    if (o.r === 'R') { const nv = o.vis.filter(v => !v.gone && !v.seen).length; for (let k = 0; k < nv; k++) { c.fillStyle = '#ffe9a8'; c.beginPath(); c.arc(x + s / 2 + (k - (nv - 1) / 2) * 7, y + s * 0.8, 2.4, 0, 7); c.fill(); } }
    if (o.hp < o.max) bar(x + 3, y + s - 5, s - 6, o.hp / o.max, '#ff5a4d');
  }
}
function drawEnemy(e) {
  const D = EN[e.k], s = PX(), x = sx(e.x), y = sy(e.y), r = e.r * s, lg = e.lunge > 0 ? 0.25 * s : 0, ax = x + Math.cos(e.ang) * lg, ay = y + Math.sin(e.ang) * lg;
  c.fillStyle = 'rgba(0,0,0,.3)'; c.beginPath(); c.ellipse(x, y + r * 0.6, r * 1.05, r * 0.4, 0, 0, 7); c.fill();
  const col = e.flash > 0 ? '#ffffff' : e.sl > 0 ? '#a04ad0' : D.col;
  c.save(); c.translate(ax, ay - r * 0.4); c.rotate(e.ang);
  if (e.k === 'wolf') { c.fillStyle = col; c.beginPath(); c.moveTo(r * 1.3, 0); c.lineTo(-r, -r * 0.7); c.lineTo(-r * 0.6, 0); c.lineTo(-r, r * 0.7); c.fill(); }
  else if (e.k === 'ram') { c.fillStyle = col; c.fillRect(-r, -r * 0.7, r * 2, r * 1.4); c.fillStyle = e.flash > 0 ? '#fff' : '#a8763f'; c.fillRect(r * 0.2, -r * 0.25, r * 1.3, r * 0.5); c.fillStyle = '#3a2a1a'; c.fillRect(-r * 0.8, -r * 0.85, r * 0.4, r * 0.2); c.fillRect(-r * 0.8, r * 0.65, r * 0.4, r * 0.2); }
  else {
    c.fillStyle = col; c.beginPath(); c.arc(0, 0, r, 0, 7); c.fill();
    c.strokeStyle = '#d8d0c0'; c.lineWidth = Math.max(1.5, r * 0.18); c.beginPath(); c.moveTo(r * 0.3, r * 0.5); c.lineTo(r * 1.9, r * 0.5); c.stroke();
    if (D.boss) { c.fillStyle = '#ffd76a'; for (const sg of [-1, 1]) { c.beginPath(); c.moveTo(-r * 0.2, sg * r * 0.6); c.lineTo(-r * 0.9, sg * r * 1.25); c.lineTo(r * 0.2, sg * r * 0.85); c.fill(); } }
    c.fillStyle = '#1a0a0a'; c.beginPath(); c.arc(r * 0.45, -r * 0.3, r * 0.13, 0, 7); c.arc(r * 0.45, r * 0.3, r * 0.13, 0, 7); c.fill();
  }
  c.restore();
  if (e.hp < e.max && !D.boss) bar(x - r, y - r * 1.9, r * 2, e.hp / e.max, '#ff9aa8');
}
function drawLord() {
  const L = G.lord; if (L.down > 0) return;
  const s = PX(), x = sx(L.x), y = sy(L.y), r = 0.36 * s;
  if (L.inv > 0.2 && Math.floor(G.t * 20) % 2) c.globalAlpha = 0.5;
  c.fillStyle = 'rgba(0,0,0,.35)'; c.beginPath(); c.ellipse(x, y + r * 0.6, r * 1.1, r * 0.42, 0, 0, 7); c.fill();
  c.save(); c.translate(x, y - r * 0.5);
  c.fillStyle = '#8a1c2c'; c.beginPath(); c.moveTo(-Math.cos(L.face) * r * 1.5, -Math.sin(L.face) * r * 1.5 + r * 0.4); c.lineTo(Math.cos(L.face + 1.6) * r, Math.sin(L.face + 1.6) * r); c.lineTo(Math.cos(L.face - 1.6) * r, Math.sin(L.face - 1.6) * r); c.fill();
  c.fillStyle = '#2d6cdf'; c.beginPath(); c.arc(0, 0, r, 0, 7); c.fill(); c.strokeStyle = '#ffd76a'; c.lineWidth = 2; c.stroke();
  c.fillStyle = '#ffd76a'; c.beginPath(); c.moveTo(-r * 0.45, -r * 0.55); c.lineTo(-r * 0.45, -r * 1.05); c.lineTo(-r * 0.2, -r * 0.8); c.lineTo(0, -r * 1.15); c.lineTo(r * 0.2, -r * 0.8); c.lineTo(r * 0.45, -r * 1.05); c.lineTo(r * 0.45, -r * 0.55); c.fill();
  // 칼: 휘두를 때는 부채꼴로 지나간 자리를 남긴다
  const reach = LORD.reach * s * (L.big ? 1.25 : 1);
  if (L.swing > 0) {
    const k = 1 - L.swing / 0.2, arc = LORD.arc * (L.big ? 1.3 : 1), dir = L.combo % 2 ? 1 : -1, a0 = L.face - dir * arc / 2, a1 = a0 + dir * arc * Math.min(1, k * 1.6);
    c.fillStyle = L.big ? 'rgba(255,215,106,.35)' : 'rgba(255,255,255,.22)'; c.beginPath(); c.moveTo(0, 0); c.arc(0, 0, reach, Math.min(a0, a1), Math.max(a0, a1)); c.fill();
    c.strokeStyle = '#ffffff'; c.lineWidth = 3; c.beginPath(); c.moveTo(Math.cos(a1) * r, Math.sin(a1) * r); c.lineTo(Math.cos(a1) * reach, Math.sin(a1) * reach); c.stroke();
  } else { const a = L.face + 0.9; c.strokeStyle = '#e8ecf5'; c.lineWidth = 3; c.beginPath(); c.moveTo(Math.cos(a) * r * 0.8, Math.sin(a) * r * 0.8); c.lineTo(Math.cos(a) * r * 2, Math.sin(a) * r * 2); c.stroke(); }
  c.restore(); c.globalAlpha = 1;
  if (L.hp < LORD.hp) bar(x - r * 1.3, y - r * 2.6, r * 2.6, L.hp / LORD.hp, '#6dff9a');
}
function drawWorld() {
  const s = PX(), x0 = Math.max(0, Math.floor(wx(0)) - 1), x1 = Math.min(MN - 1, Math.ceil(wx(W)) + 1), y0 = Math.max(0, Math.floor(wy(0)) - 1), y1 = Math.min(MN - 1, Math.ceil(wy(H)) + 2);
  c.fillStyle = '#10161f'; c.fillRect(0, 0, W, H);
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) { const v = hash(y * MN + x); c.fillStyle = v < 0.33 ? '#30472b' : v < 0.66 ? '#34502e' : '#2d4429'; c.fillRect(sx(x), sy(y), s + 0.5, s + 0.5); }
  if (G.pick) { c.strokeStyle = 'rgba(255,255,255,.07)'; c.lineWidth = 1; for (let x = x0; x <= x1 + 1; x++) { c.beginPath(); c.moveTo(sx(x), sy(y0)); c.lineTo(sx(x), sy(y1 + 1)); c.stroke(); } for (let y = y0; y <= y1 + 1; y++) { c.beginPath(); c.moveTo(sx(x0), sy(y)); c.lineTo(sx(x1 + 1), sy(y)); c.stroke(); } }
  // 습격이 올 쪽
  if (G.night || G.tDay < 20) {
    const a = G.night ? 0.5 : 0.25 + 0.25 * Math.sin(G.t * 6); c.fillStyle = 'rgba(255,60,60,' + a + ')';
    for (const sd of G.sides) { if (sd === 0) c.fillRect(sx(0), sy(0) - 6, MN * s, 6); else if (sd === 1) c.fillRect(sx(MN), sy(0), 6, MN * s); else if (sd === 2) c.fillRect(sx(0), sy(MN), MN * s, 6); else c.fillRect(sx(0) - 6, sy(0), 6, MN * s); }
  }
  const L = [];
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) { const i = y * MN + x, o = G.cells[i]; if (o) L.push([y + 1, () => drawCell(i, o)]); }
  for (const e of G.en) L.push([e.y + 0.3, () => drawEnemy(e)]);
  L.push([G.lord.y + 0.3, drawLord]);
  L.sort((a, b) => a[0] - b[0]); for (const d of L) d[1]();
  for (const q of G.proj) {
    const x = sx(q.x), y = sy(q.y) - (q.h || 0) * s - s * 0.3;
    if (q.kind === 'stone') { c.fillStyle = '#5a5f70'; c.beginPath(); c.arc(x, y, s * 0.13, 0, 7); c.fill(); }
    else if (q.kind === 'bolt') { c.fillStyle = '#c65bff'; c.beginPath(); c.arc(x, y, s * 0.1, 0, 7); c.fill(); }
    else { c.strokeStyle = '#ffe9a8'; c.lineWidth = 2; c.beginPath(); c.moveTo(x, y); c.lineTo(x - Math.cos(q.a) * s * 0.4, y - Math.sin(q.a) * s * 0.4); c.stroke(); }
  }
  for (const f of G.fx) {
    const k = f.t / f.T, x = sx(f.x), y = sy(f.y); c.globalAlpha = 1 - k;
    if (f.k === 'ring') { c.strokeStyle = f.c; c.lineWidth = 3; c.beginPath(); c.arc(x, y, s * f.r * (0.3 + 0.7 * k), 0, 7); c.stroke(); }
    else if (f.k === 'burst') { c.fillStyle = f.c; for (let j = 0; j < f.n; j++) { const a = hash(j * 31 + f.x * 7) * 6.283, d = (0.3 + hash(j * 17) * 0.9) * k * s * 1.2; c.fillRect(x + Math.cos(a) * d - 2, y + Math.sin(a) * d - 2 - 10 * k, 4, 4); } }
    else if (f.k === 'slash') { c.strokeStyle = f.c; c.lineWidth = 2; c.beginPath(); c.moveTo(x - Math.cos(f.a + 1) * s * 0.3, y - Math.sin(f.a + 1) * s * 0.3); c.lineTo(x + Math.cos(f.a + 1) * s * 0.3, y + Math.sin(f.a + 1) * s * 0.3); c.stroke(); }
    else if (f.k === 'beam') { c.strokeStyle = f.c; c.lineWidth = 5 * (1 - k) + 1; c.beginPath(); c.moveTo(x, y); c.lineTo(x + Math.cos(f.a) * s * 9, y + Math.sin(f.a) * s * 9); c.stroke(); }
    else if (f.k === 'zap') { c.strokeStyle = '#d9a8ff'; c.lineWidth = 2.5; c.beginPath(); c.moveTo(x, y); c.lineTo((x + sx(f.x2)) / 2 + (Math.random() - 0.5) * 10, (y + sy(f.y2)) / 2 + (Math.random() - 0.5) * 10); c.lineTo(sx(f.x2), sy(f.y2)); c.stroke(); }
    else if (f.k === 'ghost') { c.globalAlpha = 0.25 * (1 - k); c.fillStyle = '#7fb2ff'; c.beginPath(); c.arc(x, y - s * 0.18, s * 0.36, 0, 7); c.fill(); }
    c.globalAlpha = 1;
  }
  for (const n of G.nums) { const k = n.t / 0.9; c.globalAlpha = 1 - k * k; c.fillStyle = n.c; c.font = '700 ' + (n.big ? 18 : 13) + 'px system-ui'; c.textAlign = 'center'; c.fillText(n.txt, sx(n.x), sy(n.y) - k * 24); c.globalAlpha = 1; }
  // 짓기 미리보기
  if (G.pick && (G.pick.bp != null || G.pick.wall) && IN.mouse) {
    const X = Math.floor(wx(IN.mx)), Y = Math.floor(wy(IN.my)), i = cIdx(X + 0.5, Y + 0.5);
    if (i >= 0) { const o = G.cells[i], ok = G.pick.wall ? (!o || o.k === 'wall') : (!o || (isB(o) && o.ruin)); c.fillStyle = ok ? 'rgba(120,255,160,.25)' : 'rgba(255,80,80,.3)'; c.fillRect(sx(X), sy(Y), s, s); c.strokeStyle = ok ? '#8dffb0' : '#ff6a6a'; c.lineWidth = 2; c.strokeRect(sx(X) + 1, sy(Y) + 1, s - 2, s - 2); }
  }
  // 밤: 어둠 위에 불빛 구멍을 뚫는다
  const tgt = G.night ? 0.64 : G.tDay < 12 ? 0.64 * (1 - G.tDay / 12) : 0; G.dark += (tgt - G.dark) * 0.05;
  if (G.dark > 0.02) {
    const q = 0.5; lx.globalCompositeOperation = 'source-over'; lx.clearRect(0, 0, lc.width, lc.height); lx.fillStyle = 'rgba(3,6,18,' + G.dark + ')'; lx.fillRect(0, 0, lc.width, lc.height);
    lx.globalCompositeOperation = 'destination-out';
    const light = (x, y, r, a) => { const X = sx(x) * q, Y = sy(y) * q, R = r * s * q, g = lx.createRadialGradient(X, Y, 0, X, Y, R); g.addColorStop(0, 'rgba(0,0,0,' + a + ')'); g.addColorStop(1, 'rgba(0,0,0,0)'); lx.fillStyle = g; lx.fillRect(X - R, Y - R, R * 2, R * 2); };
    if (G.lord.down <= 0) light(G.lord.x, G.lord.y, 4.5, 0.95);
    light(HX + 0.5, HY + 0.5, 6, 0.9);
    for (const p of G.men) if (p.at >= 0) light(p.at % MN + 0.5, ((p.at / MN) | 0) + 0.5, 2.3, 0.7);
    G.cells.forEach((o, i) => { if (liveB(o) && o.r === 'D') light(i % MN + 0.5, ((i / MN) | 0) + 0.5, 2.6, 0.7); });
    for (const f of G.fx) if (f.k === 'ring' || f.k === 'burst') light(f.x, f.y, 2.2, 0.6 * (1 - f.t / f.T));
    for (const q2 of G.proj) light(q2.x, q2.y, 1, 0.5);
    c.drawImage(lc, 0, 0, W, H);
  }
  // 영주 곁의 건물 안내
  const ii = !G.inn && G.lord.down <= 0 ? nearInteract() : -1;
  if (ii >= 0) { const o = G.cells[ii], t = o.k === 'hall' ? 'E 영주관' : o.ruin ? 'E 고치기 · 나무 ' + Math.ceil(CW[o.t] / 2) + ' 돌 ' + Math.ceil(CST[o.t] / 2) : o.r === 'R' ? (G.night ? '밤에는 닫힘' : 'E 들어가기') : 'E 살펴보기'; const X = sx(ii % MN + 0.5), Y = sy(((ii / MN) | 0)) - s * 1.1; c.font = '600 12px system-ui'; const w = c.measureText(t).width + 16; c.fillStyle = 'rgba(6,9,20,.85)'; rr(X - w / 2, Y - 18, w, 22, 6); c.fill(); c.fillStyle = '#e4e9f2'; c.textAlign = 'center'; c.fillText(t, X, Y - 3); }
  const boss = G.en.find(e => EN[e.k].boss);
  if (boss) { const w = Math.min(520, W - 40); c.fillStyle = '#ff9aa8'; c.font = '600 13px system-ui'; c.textAlign = 'center'; c.fillText(EN.boss.n, W / 2, H - 112); bar(W / 2 - w / 2, H - 104, w, boss.hp / boss.max, '#e0344a'); }
}
function drawInn() {
  const I = G.inn, b = I.b, col = TIERS[b.t].col, Q = IR.q, fy = Q * 0.64, v0 = b.vis[I.sel], focus = ['climb', 'press', 'shown', 'leave'].includes(I.st);
  c.fillStyle = '#070a14'; c.fillRect(0, 0, W, H);
  c.save(); c.translate(IR.ox + (Math.random() - 0.5) * I.shake * 10, IR.oy + (Math.random() - 0.5) * I.shake * 10);
  c.beginPath(); c.roundRect(0, 0, Q, Q, 14); c.clip();
  c.fillStyle = '#161d33'; c.fillRect(-20, -20, Q + 40, fy + 20);
  c.globalAlpha = 0.07 + 0.03 * b.t; c.fillStyle = col; c.fillRect(-20, -20, Q + 40, fy + 20); c.globalAlpha = 1;
  c.fillStyle = '#251d17'; c.fillRect(-20, fy, Q + 40, Q - fy + 40);
  c.strokeStyle = 'rgba(0,0,0,.25)'; c.lineWidth = 1; for (let i = 1; i < 6; i++) { const yy = fy + (Q - fy) * i / 6; c.beginPath(); c.moveTo(-20, yy); c.lineTo(Q + 20, yy); c.stroke(); }
  for (const p of [0.05, 0.95]) { c.fillStyle = '#0f1424'; c.fillRect(Q * p - 12, -20, 24, fy + 28); }
  for (const p of [0.35, 0.65]) { c.fillStyle = col; c.globalAlpha = 0.8; c.beginPath(); c.moveTo(Q * p - 15, Q * 0.1); c.lineTo(Q * p + 15, Q * 0.1); c.lineTo(Q * p + 15, Q * 0.3); c.lineTo(Q * p, Q * 0.26); c.lineTo(Q * p - 15, Q * 0.3); c.fill(); c.globalAlpha = 1; }
  c.fillStyle = col; c.font = '600 14px system-ui'; c.textAlign = 'center'; c.fillText(bn(b), Q / 2, Q * 0.065);
  if (focus) {
    const step = I.st === 'climb' ? Math.max(0, I.step) : v0.g; c.fillStyle = 'rgba(3,5,12,' + (0.55 + 0.06 * step) + ')'; c.fillRect(-20, -20, Q + 40, Q + 40);
    const x = innX(I.sel), cl = I.st === 'climb' ? (I.step >= 0 ? GR[I.step][3] : '#5a6a90') : GR[v0.g][3];
    const gr = c.createLinearGradient(0, 0, 0, Q); gr.addColorStop(0, cl + '00'); gr.addColorStop(0.6, cl + '40'); gr.addColorStop(1, cl + '10');
    c.fillStyle = gr; c.beginPath(); c.moveTo(x - Q * 0.06, -20); c.lineTo(x + Q * 0.06, -20); c.lineTo(x + Q * 0.17, Q * 0.92); c.lineTo(x - Q * 0.17, Q * 0.92); c.fill();
    if (I.st === 'shown' && v0.g >= 3) { c.save(); c.translate(x, Q * 0.58); c.rotate(I.t * 0.4); c.fillStyle = GR[v0.g][3]; c.globalAlpha = Math.max(0.05, 0.22 - I.t * 0.03); for (let i = 0; i < 14; i++) { c.rotate(Math.PI / 7); c.beginPath(); c.moveTo(0, 0); c.lineTo(-Q * 0.05, Q); c.lineTo(Q * 0.05, Q); c.fill(); } c.restore(); c.globalAlpha = 1; }
  }
  b.vis.forEach((v, i) => {
    if (v.gone) return;
    const on = i === I.sel, x = innX(i) + (on && I.st === 'leave' ? (1.5 - I.hold) * Q * 0.3 : 0), y = Q * 0.9;
    let h = Q * 0.25; if (on && focus) h *= 1.3;
    c.globalAlpha = focus && !on ? 0.22 : on && I.st === 'leave' ? Math.max(0, I.hold / 1.5) : 1;
    c.fillStyle = 'rgba(0,0,0,.35)'; c.beginPath(); c.ellipse(x, y + 3, h * 0.32, h * 0.07, 0, 0, 7); c.fill();
    if (on && I.st === 'climb') {
      const s = I.step, cl = s >= 0 ? GR[s][3] : '#2f3a60', jit = s >= 0 ? Math.sin(I.t * 50) * (0.5 + s) : 0;
      if (s >= 1) { const rg = c.createRadialGradient(x, y - h * 0.55, 0, x, y - h * 0.55, h * (0.7 + 0.12 * s)); rg.addColorStop(0, cl + '66'); rg.addColorStop(1, cl + '00'); c.fillStyle = rg; c.fillRect(x - h * 1.6, y - h * 2.2, h * 3.2, h * 2.6); }
      sol(x + jit, y, h, v.k, 0, cl);
      if (s >= 0) { const k = clamp((I.t - I.ts) / 0.3, 0, 1); c.strokeStyle = cl; c.lineWidth = 3; c.globalAlpha = 1 - k; c.beginPath(); c.arc(x, y - h * 0.55, h * (0.4 + k * 1.1), 0, 7); c.stroke(); c.globalAlpha = 1; c.fillStyle = cl; c.font = '700 ' + Math.round((24 + 6 * s) * (1 + 0.7 * (1 - k))) + 'px system-ui'; c.textAlign = 'center'; c.fillText(GR[s][0], x, y - h * 1.75); }
    } else if (v.seen) {
      sol(x, y, h, v.k, v.g); const pop = on && I.st === 'shown' ? Math.max(0, 1 - I.t / 0.35) : 0; c.fillStyle = GR[v.g][3]; c.textAlign = 'center';
      if (on && focus) { c.font = '700 ' + Math.round((26 + 6 * v.g) * (1 + pop)) + 'px system-ui'; c.fillText(GR[v.g][0], x, y - h * 1.75); }
      else { c.font = '600 13px system-ui'; c.fillText(GR[v.g][0], x, y + 18); c.fillStyle = '#9aa4b2'; c.font = '11px system-ui'; c.fillText(v.name, x, y + 32); }
    } else {
      if (v.hg >= 2) { const a = (0.14 + 0.09 * v.hg) * (0.75 + 0.25 * Math.sin(G.t * 2.5 + i * 2)), cl = GR[v.hg][3], rg = c.createRadialGradient(x, y - h * 0.5, 0, x, y - h * 0.5, h * 0.95); rg.addColorStop(0, cl + Math.round(a * 255).toString(16).padStart(2, '0')); rg.addColorStop(1, cl + '00'); c.fillStyle = rg; c.fillRect(x - h, y - h * 1.6, h * 2, h * 2); }
      sol(x, y, h, v.k, 0, on ? '#4a5680' : '#333d60');
      c.fillStyle = on ? '#c9d2e6' : '#6a77a0'; c.textAlign = 'center'; c.font = '600 18px system-ui'; c.fillText(on && I.st === 'press' ? '…' : '?', x, y - h * 1.55); c.font = '11px system-ui'; c.fillText(KIND[v.k].n, x, y + 18);
    }
    c.globalAlpha = 1;
  });
  if (I.st === 'press' && v0) { c.fillStyle = GR[v0.g][3]; c.font = '700 30px system-ui'; c.textAlign = 'center'; c.globalAlpha = 0.5 + 0.5 * Math.sin(I.t * 8); c.fillText('…', innX(I.sel), Q * 0.3); c.globalAlpha = 1; }
  for (const p of I.ps) { c.globalAlpha = Math.max(0, 1 - p.l / p.m); c.fillStyle = p.c; c.fillRect(p.x - 2, p.y - 2, 4, 4); }
  c.globalAlpha = 1; c.restore();
}
function draw() {
  c.setTransform(DPR, 0, 0, DPR, 0, 0);
  if (G.inn) drawInn();
  else {
    const sh = G.shake * 8; c.save(); c.translate((Math.random() - 0.5) * sh, (Math.random() - 0.5) * sh); drawWorld(); c.restore();
  }
  if (G.banner) {
    const k = G.banner.t, a = Math.min(1, k * 4) * Math.min(1, (3 - k) * 2), y = H * 0.24;
    c.globalAlpha = a; c.fillStyle = 'rgba(4,6,14,.72)'; c.fillRect(0, y - 40, W, 70);
    c.fillStyle = G.banner.c; c.font = '700 26px system-ui'; c.textAlign = 'center'; c.fillText(G.banner.txt, W / 2, y);
    if (G.banner.sub) { c.fillStyle = '#c9d2e6'; c.font = '13px system-ui'; c.fillText(G.banner.sub, W / 2, y + 22); }
    c.globalAlpha = 1;
  }
  if (G.flash) { c.globalAlpha = G.flash.a; c.fillStyle = G.flash.c; c.fillRect(0, 0, W, H); c.globalAlpha = 1; }
}
// ----- 화면: HTML 쪽 -----
function drawBar() {
  const el = $('bar'); el.textContent = '';
  G.bps.forEach((h, i) => {
    const b = document.createElement('button'); b.type = 'button'; b.className = 'card' + (G.pick && G.pick.bp === i ? ' sel' : '') + (afford(h.t) ? '' : ' poor'); b.style.color = TIERS[h.t].col;
    b.innerHTML = '<i></i><span class="nm">' + h.item + '</span><span class="sub">' + ROLE[h.r] + ' · ' + CW[h.t] + '/' + CST[h.t] + '</span><kbd>' + (i + 1) + '</kbd>';
    b.onclick = () => pickBp(i); el.appendChild(b);
  });
  const w = document.createElement('button'); w.type = 'button'; w.className = 'card wall' + (G.pick && G.pick.wall ? ' sel' : ''); w.innerHTML = '<span class="nm">성벽</span><span class="sub">돌 ' + WALL_S + ' · 다시 누르면 헐기</span><kbd>F</kbd>'; w.onclick = toggleWall; el.appendChild(w);
}
function pickBp(i) { if (!G.bps[i] || G.inn) return; G.pick = G.pick && G.pick.bp === i ? null : { bp: i }; drawBar(); if (G.pick) say(G.bps[i].item + ': ' + DESC[G.bps[i].d && DESC[G.bps[i].d] ? G.bps[i].d : G.bps[i].r] + ' 땅을 클릭해 지어. 오른쪽 클릭이나 Esc로 취소.'); }
function toggleWall() { if (G.inn) return; G.pick = G.pick && G.pick.wall ? null : { wall: 1 }; drawBar(); if (G.pick) say('땅을 클릭하거나 끌어서 성벽을 쌓아. 성벽을 클릭하면 헐어.'); }
function drawRoster() {
  const el = $('rList'); if (!el) return; el.textContent = '';
  if (!G.men.length) el.innerHTML = '<p class="none">아직 아무도 없어. 모집 건물에 들어가서 말을 걸어.</p>';
  for (const p of [...G.men].sort((a, z) => ppw(z) - ppw(a))) {
    const b = document.createElement('button'); b.type = 'button'; b.className = 'man' + (G.pick && G.pick.man === p.id ? ' sel' : '') + (p.down ? ' down' : ''); b.style.color = GR[p.g][3];
    b.innerHTML = '<b>' + GR[p.g][0] + ' ' + KIND[p.k].n + '</b><span>' + p.name + ' · Lv ' + p.lv + (p.g >= 3 ? ' · ' + SKILL[p.k] : '') + '</span><em>' + (p.down ? '부상' : p.at >= 0 ? '성벽' : '대기') + '</em>';
    b.onclick = () => { G.pick = G.pick && G.pick.man === p.id ? null : { man: p.id }; drawRoster(); if (G.pick) say(p.name + '을(를) 세울 성벽을 클릭해.'); };
    el.appendChild(b);
  }
  $('rCnt').textContent = G.men.length + '/' + popCap(); $('bFire').disabled = !(G.pick && G.pick.man);
}
function toggleRoster() { if (G.inn) return; $('td').classList.toggle('ros'); drawRoster(); }
function closeRoster() { $('td').classList.remove('ros'); }
function innUI() {
  const I = G.inn; $('td').classList.toggle('in', !!I); if (!I) return;
  const v = I.b.vis[I.sel], who = $('inWho'), txt = $('inTxt'), bs = [$('inA'), $('inB'), $('inC')];
  bs.forEach(x => { x.style.display = 'none'; x.disabled = false; });
  const show = (i, s, off) => { bs[i].style.display = ''; bs[i].textContent = s; bs[i].disabled = !!off; };
  $('inX').style.visibility = ['climb', 'press', 'leave'].includes(I.st) ? 'hidden' : ''; who.style.color = '';
  if (I.st === 'idle') { who.style.color = TIERS[I.b.t].col; who.textContent = bn(I.b); txt.textContent = I.b.vis.some(x => !x.gone) ? '누구에게 말을 걸까? 사람을 클릭해. 오늘 대화 ' + G.talk + '번 남음.' : '오늘 온 사람은 다 만났다. 내일 새 손님이 온다.'; }
  else if (I.st === 'look') { who.textContent = '낯선 ' + KIND[v.k].n; txt.textContent = HINT[v.hg]; show(0, '말 걸기 · ' + G.talk + '번 남음', G.talk <= 0); }
  else if (I.st === 'climb') { who.style.color = I.step >= 0 ? GR[I.step][3] : ''; who.textContent = I.step >= 0 ? GR[I.step][0] + '…?' : '낯선 ' + KIND[v.k].n; txt.textContent = I.line || (I.step <= 0 ? (I.step < 0 ? '…' : HELLO[v.k][v.hi]) : STEP[I.step]); }
  else if (I.st === 'press') { who.style.color = GR[v.g][3]; who.textContent = GR[v.g][0] + ' ' + KIND[v.k].n + ' ' + v.name; txt.textContent = '"…아직 숨기는 게 있지 않나?"'; }
  else if (I.st === 'leave') { who.textContent = v.name; txt.textContent = '"실례군요. 이만 가 보겠습니다."'; }
  else { who.style.color = GR[v.g][3]; who.textContent = GR[v.g][0] + ' ' + KIND[v.k].n + ' ' + v.name + (v.g ? '  1/' + GR[v.g][1].toLocaleString() : ''); txt.textContent = FINAL[v.g] + (v.g >= 3 ? '  · 기술: ' + SKILL[v.k] : ''); show(0, '영입'); if (v.g < 5) show(1, '더 캐묻기 · ' + Math.round(UP[v.g] * 100) + '%', G.talk <= 0); show(2, '다음에'); }
}
let hudT = 0, admT = 0;
function hud() {
  const L = G.lord;
  $('rW').textContent = Math.floor(G.res.wood); $('rS').textContent = Math.floor(G.res.stone); $('rG').textContent = Math.floor(G.res.gold);
  $('hDay').textContent = G.day + '일째 ' + (G.night ? '밤' : '낮') + ' · ' + DAYS + '일 중';
  $('hSub').textContent = G.night ? '남은 적 ' + (G.raid.list.length + G.en.length) : '밤까지 ' + Math.ceil(G.tDay) + '초 · ' + G.sides.length + '방향에서 온다';
  $('hBarI').style.width = (G.night ? 100 : 100 * (1 - G.tDay / G.dbg.tday)) + '%'; $('td').classList.toggle('night', G.night);
  $('hpI').style.width = (100 * L.hp / LORD.hp) + '%'; $('hpT').textContent = L.down > 0 ? '쓰러짐 · ' + Math.ceil(L.down) + '초' : Math.ceil(L.hp) + '/' + LORD.hp;
  $('bBox').innerHTML = (G.boxes > 0 ? '설계함 열기 · ' + G.boxes : '설계함 사기 · 금화 ' + boxPrice()) + '<kbd>R</kbd>'; $('bBox').disabled = G.boxes <= 0 && G.res.gold < boxPrice();
  $('bNight').disabled = G.night;
  $('bAutoBox').innerHTML = '자동 ' + (G.auto ? '켜짐' : '꺼짐') + '<kbd>T</kbd>'; $('bAutoBox').classList.toggle('on', G.auto);
  $('bThr').innerHTML = THR[G.thr] + '<kbd>G</kbd>'; $('bThr').classList.toggle('on', G.thr > 0);
}
// ===================== [입력] =====================
const K = {}, IN = { mouse: false, mx: 0, my: 0, down: false, touch: false, jx: 0, jy: 0, tAtk: false, tDash: false };
const active = () => document.body.classList.contains('td') && !S && !document.body.classList.contains('bk');
addEventListener('keydown', e => {
  if (!active()) return;
  if (e.code === 'Backquote' || e.code === 'F2') { e.preventDefault(); toggleAdm(); return; }
  if (e.target && /INPUT|SELECT/.test(e.target.tagName)) return;
  if (['Tab', 'Space', 'ArrowUp', 'ArrowDown'].includes(e.code)) e.preventDefault();
  K[e.code] = true; if (e.repeat || G.over) return;
  if (G.inn) { if (e.code === 'Escape') leaveInn(); else if (e.code === 'Space' || e.code === 'Enter') $('inA').click(); return; }
  const n = Number(e.key);
  if (e.code === 'KeyE') interact(); else if (e.code === 'KeyR') openBox(); else if (e.code === 'KeyF') toggleWall(); else if (e.code === 'Tab') toggleRoster(); else if (e.code === 'KeyN') callNight(); else if (e.code === 'KeyT') toggleAuto(); else if (e.code === 'KeyG') cycleThr();
  else if (e.code === 'Escape') { G.pick = null; drawBar(); drawRoster(); closeRoster(); } else if (n >= 1 && n <= 6) pickBp(n - 1);
});
addEventListener('keyup', e => { K[e.code] = false; });
addEventListener('blur', () => { for (const k in K) K[k] = false; IN.down = false; });
function callNight() { if (G.night || G.inn) return; const bonus = Math.floor(G.tDay / 4); G.res.gold += bonus; G.tDay = 0; say('밤을 당겼어. 금화 +' + bonus); }
cv.addEventListener('contextmenu', e => e.preventDefault());
cv.addEventListener('pointermove', e => { IN.mx = e.clientX; IN.my = e.clientY; if (e.pointerType === 'mouse') { IN.mouse = true; IN.touch = false; } if (IN.down && G.pick && G.pick.wall) placeAt(cIdx(wx(e.clientX), wy(e.clientY)), true); });
cv.addEventListener('pointerdown', e => {
  audio(); IN.mx = e.clientX; IN.my = e.clientY; if (e.pointerType !== 'mouse') { IN.touch = true; IN.mouse = false; $('td').classList.add('touch'); }
  if (G.over) return;
  if (G.inn) { const lxp = (e.clientX - IR.ox) / IR.q, lyp = (e.clientY - IR.oy) / IR.q; if (lxp >= 0 && lxp <= 1 && lyp >= 0 && lyp <= 1) innPick(clamp(Math.round((lxp - 0.2) / 0.3), 0, VIS - 1)); return; }
  if (e.button === 2) { G.pick = null; drawBar(); drawRoster(); return; }
  if (G.pick) { if (G.pick.wall) G.pick.mode = null; IN.down = true; placeAt(cIdx(wx(e.clientX), wy(e.clientY)), false); return; }
  if (e.pointerType === 'mouse') IN.down = true;
});
addEventListener('pointerup', () => { IN.down = false; });
cv.addEventListener('wheel', e => { e.preventDefault(); Z = clamp(Z * (e.deltaY < 0 ? 1.1 : 1 / 1.1), 0.55, 1.8); }, { passive: false });
// 터치: 왼쪽 원으로 걷고, 오른쪽 버튼으로 싸운다
{
  const joy = $('joy'), knob = $('joyK'); let jid = null;
  const setJ = e => { const r = joy.getBoundingClientRect(), dx = e.clientX - (r.left + r.width / 2), dy = e.clientY - (r.top + r.height / 2), m = Math.min(1, Math.hypot(dx, dy) / (r.width / 2)) / (Math.hypot(dx, dy) || 1); IN.jx = dx * m; IN.jy = dy * m; knob.style.transform = 'translate(' + IN.jx * r.width / 2 + 'px,' + IN.jy * r.width / 2 + 'px)'; };
  joy.addEventListener('pointerdown', e => { jid = e.pointerId; joy.setPointerCapture(jid); setJ(e); audio(); });
  joy.addEventListener('pointermove', e => { if (e.pointerId === jid) setJ(e); });
  const end = e => { if (e.pointerId !== jid) return; jid = null; IN.jx = IN.jy = 0; knob.style.transform = ''; };
  joy.addEventListener('pointerup', end); joy.addEventListener('pointercancel', end);
  const hold = (id, k) => { const b = $(id); b.addEventListener('pointerdown', e => { e.preventDefault(); IN[k] = true; audio(); }); b.addEventListener('pointerup', () => { IN[k] = false; }); b.addEventListener('pointerleave', () => { IN[k] = false; }); };
  hold('tA', 'tAtk'); hold('tD', 'tDash'); $('tE').addEventListener('pointerdown', e => { e.preventDefault(); interact(); });
  if (matchMedia('(pointer: coarse)').matches) { $('td').classList.add('touch'); IN.touch = true; }
}
function readInput() {
  let x = (K.KeyD || K.ArrowRight ? 1 : 0) - (K.KeyA || K.ArrowLeft ? 1 : 0), y = (K.KeyS || K.ArrowDown ? 1 : 0) - (K.KeyW || K.ArrowUp ? 1 : 0);
  if (IN.jx || IN.jy) { x = IN.jx; y = IN.jy; }
  return { x, y, atk: K.Space || K.KeyJ || (IN.down && !G.pick) || IN.tAtk, dash: K.ShiftLeft || K.ShiftRight || K.KeyK || IN.tDash, aim: IN.mouse && !IN.touch ? { x: wx(IN.mx), y: wy(IN.my) } : null, auto: IN.touch };
}
$('bBox').onclick = () => openBox(); $('bAutoBox').onclick = toggleAuto; $('bThr').onclick = cycleThr; $('bMen').onclick = toggleRoster; $('bNight').onclick = callNight;
$('bAuto').onclick = autoStation; $('bRClose').onclick = closeRoster;
$('bFire').onclick = () => { if (!G.pick || !G.pick.man) return; G.men = G.men.filter(p => p.id !== G.pick.man); G.pick = null; drawRoster(); say('내보냈어.'); };
$('bBook').onclick = () => { book(); document.body.classList.add('bk'); };
$('bBack').onclick = () => document.body.classList.remove('bk');
$('inA').onclick = () => { const I = G.inn; if (!I) return; if (I.st === 'look') talk(); else if (I.st === 'shown') hire(); };
$('inB').onclick = press;
$('inC').onclick = () => { const I = G.inn; if (I && I.st === 'shown') { I.st = 'idle'; I.sel = -1; innUI(); } };
$('inX').onclick = leaveInn;
$('bAgain').onclick = () => location.reload();
// ===================== [관리] 시험용 패널: 고도에서는 디버그용 CanvasLayer 하나로 옮긴다 =====================
function toggleAdm() { const on = $('td').classList.toggle('adm'); if (on) admBuild(); }
function admSpawn(k, n) { if (G.over) return; if (!G.night) { startNight(); G.raid.list = []; } for (let i = 0; i < n; i++) spawn(k); }
function admBuild() {
  const el = $('admBody'); el.textContent = '';
  const sec = t => { const d = document.createElement('section'); d.innerHTML = '<h3>' + t + '</h3>'; el.appendChild(d); return d; };
  const row = p => { const d = document.createElement('div'); d.className = 'arow'; p.appendChild(d); return d; };
  const btn = (p, t, f) => { const b = document.createElement('button'); b.type = 'button'; b.className = 'btn'; b.textContent = t; b.onclick = () => { f(); drawBar(); drawRoster(); admInfo(); }; p.appendChild(b); return b; };
  const fld = (p, t) => { const w = document.createElement('label'); w.className = 'fld'; w.innerHTML = '<span>' + t + '</span>'; p.appendChild(w); return w; };
  const sel = (p, t, opts, val, f) => { const w = fld(p, t), s = document.createElement('select'); for (const [v, n] of opts) { const o = document.createElement('option'); o.value = v; o.textContent = n; s.appendChild(o); } s.value = String(val); s.onchange = () => f(Number(s.value)); w.appendChild(s); return s; };
  const rng = (p, t, a, b, st, get, set, unit) => { const w = fld(p, t), r = document.createElement('input'), v = document.createElement('b'); r.type = 'range'; r.min = a; r.max = b; r.step = st; r.value = get(); const show = () => { v.textContent = (+r.value).toFixed(st < 1 ? 2 : 0).replace(/\.?0+$/, '') + (unit || ''); }; r.oninput = () => { set(+r.value); show(); }; show(); w.appendChild(r); w.appendChild(v); return r; };
  const chk = (p, t, get, set) => { const w = fld(p, t), c2 = document.createElement('input'); c2.type = 'checkbox'; c2.checked = get(); c2.onchange = () => set(c2.checked); w.appendChild(c2); return c2; };
  const tiers = [[-1, '무작위'], ...TIERS.map((T, i) => [i, T.name])], grades = GR.map((g, i) => [i, g[0]]);
  let s1 = sec('정보'); const info = document.createElement('div'); info.id = 'admInfo'; s1.appendChild(info);
  s1 = sec('자원'); let r = row(s1);
  btn(r, '나무 +100', () => { G.res.wood += 100; }); btn(r, '돌 +100', () => { G.res.stone += 100; }); btn(r, '금화 +100', () => { G.res.gold += 100; });
  btn(r, '전부 +1000', () => { G.res.wood += 1000; G.res.stone += 1000; G.res.gold += 1000; }); btn(r, '설계함 +5', () => { G.boxes += 5; });
  s1 = sec('설계함');
  sel(s1, '다음 등급', tiers, G.force, v => { G.force = v; });
  chk(s1, '신화 이상은 연출 보기', () => !G.noRev, v => { G.noRev = !v; });
  r = row(s1); btn(r, '지금 열기', () => { G.boxes++; openBox(); });
  s1 = sec('사람');
  const kS = sel(s1, '병과', KIND.map((k, i) => [i, k.n]), 0, () => {}), gS = sel(s1, '등급', grades, 0, () => {});
  r = row(s1); btn(r, '이 사람 추가', () => { mkMan({ k: +kS.value, g: +gS.value, name: NAMES[rnd(NAMES.length)] }); say('관리: ' + GR[+gS.value][0] + ' ' + KIND[+kS.value].n + ' 추가'); });
  sel(s1, '다음 대화 등급', [[-1, '무작위'], ...grades], G.dbg.forceG, v => { G.dbg.forceG = v; });
  r = row(s1); btn(r, '손님 새로 고침', () => { for (const o of blds('R')) o.vis = genVis(o); }); btn(r, '대화 채우기', () => { G.talk = talkMax(); }); btn(r, '모두 레벨 +1', () => { for (const p of G.men) p.lv++; }); btn(r, '부상 치료', () => { for (const p of G.men) p.down = 0; });
  s1 = sec('시간');
  rng(s1, '배속', 0.25, 4, 0.25, () => G.dbg.ts, v => { G.dbg.ts = v; }, '×');
  rng(s1, '낮 길이', 20, 240, 10, () => G.dbg.tday, v => { G.dbg.tday = v; if (!G.night) G.tDay = Math.min(G.tDay, v); }, '초');
  const dS = sel(s1, '날짜', Array.from({ length: DAYS }, (_, i) => [i + 1, (i + 1) + '일째']), G.day, () => {});
  r = row(s1); btn(r, '그날 낮으로', () => { if (G.night || G.over) return say('관리: 낮에만 바꿀 수 있어.'); G.day = +dS.value; G.sides = sidesFor(G.day); G.tDay = G.dbg.tday; }); btn(r, '밤 시작', startNight); btn(r, '밤 끝내기', () => { if (!G.night) return; for (const e of G.en) e.dead = true; G.raid.list = []; });
  s1 = sec('적 (낮이면 밤이 시작된다)'); r = row(s1);
  btn(r, '약탈자 5', () => admSpawn('raider', 5)); btn(r, '늑대 5', () => admSpawn('wolf', 5)); btn(r, '공성추 2', () => admSpawn('ram', 2)); btn(r, '약탈왕', () => admSpawn('boss', 1));
  rng(s1, '적 체력', 0.25, 4, 0.25, () => G.dbg.ehp, v => { G.dbg.ehp = v; }, '×');
  rng(s1, '적 수', 0.5, 3, 0.25, () => G.dbg.en, v => { G.dbg.en = v; }, '×');
  s1 = sec('영주');
  chk(s1, '무적', () => G.dbg.god, v => { G.dbg.god = v; });
  rng(s1, '이동 속도', 2, 9, 0.1, () => LORD.spd, v => { LORD.spd = v; });
  rng(s1, '공격력', 5, 100, 1, () => LORD.dmg, v => { LORD.dmg = v; });
  rng(s1, '공격 간격', 0.15, 1, 0.01, () => LORD.cd, v => { LORD.cd = v; }, '초');
  rng(s1, '사거리', 0.8, 3, 0.05, () => LORD.reach, v => { LORD.reach = v; }, '칸');
  r = row(s1); btn(r, '체력 채우기', () => { G.lord.hp = LORD.hp; }); btn(r, '쓰러뜨리기', () => { const g0 = G.dbg.god; G.dbg.god = false; G.lord.inv = 0; G.saved = true; hurtLord(9999); G.dbg.god = g0; }); btn(r, '충신 시험', () => { const g0 = G.dbg.god; G.dbg.god = false; G.lord.inv = 0; G.saved = false; const p = G.men.filter(q => q.at >= 0 && !q.down).sort((a, z) => z.g - a.g)[0]; if (!p) return say('관리: 성벽에 선 사람이 없어.'); G.lord.x = p.at % MN + 0.5; G.lord.y = ((p.at / MN) | 0) + 1.5; const k = GUARD[p.g]; GUARD[p.g] = 1; hurtLord(9999); GUARD[p.g] = k; G.dbg.god = g0; });
  s1 = sec('영지'); r = row(s1);
  btn(r, '모두 고치기', () => { for (const o of G.cells) { if (!o) continue; if (o.k === 'b') { o.ruin = false; o.hp = o.max; } else if (o.hp != null) o.hp = o.max; } flow(); });
  btn(r, '성벽 한 겹 더', () => { const rr2 = 5; for (let y = HY - rr2; y <= HY + rr2; y++) for (let x = HX - rr2; x <= HX + rr2; x++) { const i = y * MN + x; if (Math.max(Math.abs(x - HX), Math.abs(y - HY)) === rr2 && !G.cells[i]) G.cells[i] = { k: 'wall', hp: WALL_HP, max: WALL_HP }; } flow(); });
  btn(r, '나무·바위 다시 심기', () => { for (let y = 2; y < MN - 2; y++) for (let x = 2; x < MN - 2; x++) { const i = y * MN + x; if (!G.cells[i] && Math.max(Math.abs(x - HX), Math.abs(y - HY)) >= 6 && Math.random() < 0.1) G.cells[i] = Math.random() < 0.7 ? { k: 'tree', hp: 4 } : { k: 'rock', hp: 5 }; } flow(); });
  r = row(s1); btn(r, '승리 화면', () => gameOver(true)); btn(r, '패배 화면', () => gameOver(false));
  admInfo();
}
function admInfo() {
  const el = $('admInfo'); if (!el || !$('td').classList.contains('adm')) return;
  const nd = G.night ? G.raid.list.length + G.en.length : wave(G.day).length;
  el.innerHTML = 'FPS ' + Math.round(G.dbg.fps) + ' · 적 ' + G.en.length + ' · 투사체 ' + G.proj.length + '<br>사람 ' + G.men.length + '/' + popCap() + ' · 명성 ' + fame() + ' · 대화 ' + G.talk + '/' + talkMax() + '<br>' + (G.night ? '이번 밤 남은 적 ' : '오늘 밤 적 ') + nd + ' · 방향 ' + G.sides.length + ' · 영주관 ' + Math.round(G.cells[HALL].hp) + '/' + HALL_HP;
}
$('bAdm').onclick = toggleAdm; $('bAdmX').onclick = toggleAdm;
addEventListener('resize', layout);
roll = () => {}; reward = () => {};
document.body.classList.add('td');
window.TD = { G, MN, HX, HY, flow, openBox, placeAt, interact, enter, innPick, talk, press, hire, autoStation, startNight, mkB, mkMan, cIdx, update: (dt, inp) => update(dt, inp || { x: 0, y: 0 }) };
genMap(); flow(); G.sides = sidesFor(1); autoStation(); drawBar(); layout();
say('WASD로 걷고, 클릭으로 나무와 돌을 캐. R로 설계함을 열고, 주막 앞에서 E로 들어가 사람을 뽑아.');
let prev = performance.now();
(function loop(now) {
  const real = Math.min(0.05, (now - prev) / 1000); prev = now;
  document.body.classList.toggle('rev', !!S);
  if (!S && G.pend) { const b = G.pend; G.pend = null; got(b); }
  if (!S && !document.body.classList.contains('bk')) {
    try {
      if (G.slow > 0) G.slow -= real;
      if (G.flash && (G.flash.a -= real * 1.5) <= 0) G.flash = null;
      G.shake = Math.max(0, G.shake - real * 2.5);
      const L = G.lord, tx = L.down > 0 ? HX + 0.5 : L.x, ty = L.down > 0 ? HY + 0.5 : L.y; cam.x += (tx - cam.x) * Math.min(1, real * 6); cam.y += (ty - cam.y) * Math.min(1, real * 6);
      if (G.hitstop > 0) G.hitstop -= real; else update(real * (G.slow > 0 ? 0.3 : 1) * G.dbg.ts, readInput());
      G.dbg.fps += ((1 / Math.max(real, 1e-3)) - G.dbg.fps) * 0.05; if ((admT += real) > 0.25) { admT = 0; admInfo(); }
      draw(); if ((hudT += real) > 0.1) { hudT = 0; hud(); }
    } catch (e) { console.error(e); }
  }
  requestAnimationFrame(loop);
})(prev);
}
