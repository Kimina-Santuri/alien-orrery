/* ---- The site layer: pages as worlds, routes between them, and one continuing story ---- */
function pageFromUrl() {
  if (OPTS.mini) return 'mini';
  if (document.body.classList.contains('orrery-page')) return 'sliders';
  const current = document.querySelector('.side-nav a[aria-current="page"]');
  const name = (current ? current.getAttribute('href') : location.pathname.split('/').pop() || 'index.html').replace(/\.html.*$/, '');
  if (document.body.classList.contains('home') || name === 'index' || name === '') return 'home';
  return ['works', 'performances', 'bookings', 'residencies', 'downloads', 'tech', 'lessons', 'about', 'contact'].includes(name) ? name : 'elsewhere';
}
function assignPages(s) {
  const q = mulberry(s.seed * 2654435761 + 1021);
  const names = ['works', 'performances', 'bookings', 'residencies', 'downloads', 'tech', 'lessons', 'about', 'contact'];
  for (let i = names.length - 1; i > 0; i--) { const j = Math.floor(q() * (i + 1)); [names[i], names[j]] = [names[j], names[i]]; }
  const hub = s.worlds[s.homeIdx];
  const others = s.worlds.filter(o => o !== hub).sort((a, b) => (b.living ? 1 : 0) - (a.living ? 1 : 0));
  s.pageOf = new Map([[hub, 'home']]);
  others.slice(0, names.length).forEach((o, i) => s.pageOf.set(o, names[i]));
  s.worldOf = new Map([...s.pageOf].map(([o, n]) => [n, o]));
}
const SITE = { page: pageFromUrl(), hover: null, cameFrom: null, arrivedAt: 0 };
SITE.chart = ['home', 'sliders', 'mini'].includes(SITE.page);
const onSliders = SITE.page === 'sliders';

function drawPageLabels(s) {
  ctx.font = '400 10px "JetBrains Mono", ui-monospace, Menlo, monospace';
  ctx.textBaseline = 'middle';
  for (const [o, name] of s.pageOf) {
    if (o.gone || o.x < 40 || o.y < 40 || o.x > s.W - 40 || o.y > s.H - 40) continue;
    const text = name.toUpperCase(), w = ctx.measureText(text).width, x = o.x + o.r + 9, y = o.y;
    ctx.fillStyle = 'rgba(255,255,255,.9)';
    ctx.fillRect(x - 3, y - 8, w + 6, 16);
    ctx.fillStyle = s.pal.ink;
    ctx.fillText(text, x, y);
    if (SITE.hover === name) ringAt(o.x, o.y, o.r + 8 + Math.sin(performance.now() / 200) * 2, 0.9, s.pal.ink, 1.2);
  }
  ctx.textBaseline = 'alphabetic';
}

/* A view from this page's world: it looms in one corner, and the other pages hang across the sky with routes between them. */
function* paintScene(s) {
  const { W, H, pal, dpr } = s;
  const r = mulberry(s.seed * 2654435761 + 1031 + SITE.page.length * 17 + SITE.page.charCodeAt(0));
  const landscape = W >= H, min = Math.min(W, H), lite = LITE;
  const hero = s.worldOf.get(SITE.page) || s.worlds.filter(o => !s.pageOf.has(o))[0] || s.worlds[s.homeIdx];
  s.heroWorld = hero;
  const hx = landscape ? W * 0.84 : W * 0.78, hy = landscape ? H * 0.84 : H * 0.16;
  const HR = landscape ? min * 0.46 : W * 0.44;
  const u = 1 / dpr;
  /* Real positions set the order round the sky and how far away each one is. */
  const pos = o => { const p = [0, 0]; orbitXY(o.a, o.e, o.w, o.phase, p); return p; };
  const hp = pos(hero);
  const away = [...s.pageOf.keys()].filter(o => o !== hero).map(o => {
    const p = pos(o);
    return { o, ang: Math.atan2(p[1] - hp[1], p[0] - hp[0]), dist: Math.hypot(p[0] - hp[0], p[1] - hp[1]) };
  }).sort((a, b) => a.ang - b.ang);
  const far = Math.max(...away.map(n => n.dist), 1);
  /* Spread them across the open sky, clear of the menu, the top bar and each other's labels. */
  const a0 = landscape ? Math.PI * 1.03 : Math.PI * 0.56, a1 = landscape ? Math.PI * 1.47 : Math.PI * 0.94;
  const left = W >= 820 ? 175 : 24, top = W >= 820 ? 84 : 66, bottom = W >= 820 ? 34 : 96;
  const rx = landscape ? hx - left : hx - left, ry = landscape ? hy - top : H - bottom - hy;
  const inner = (HR * 1.28) / Math.min(rx, ry);
  away.forEach((n, i) => {
    const at = lerp(a0, a1, (i + 0.5) / away.length);
    const f = lerp(Math.min(inner, 0.7), 0.98, (i % 3 === 1 ? 0.2 : i % 3 === 2 ? 0.55 : 0.95) * (0.65 + 0.35 * Math.sqrt(n.dist / far)));
    n.o.x = clamp(hx + Math.cos(at) * rx * f, left, W - 90);
    n.o.y = clamp(hy + Math.sin(at) * ry * f, top, H - bottom);
    n.o.r = clamp(n.o.r, 5, 15) * clamp(min / 700, 0.75, 1.2);
  });
  hero.x = hx; hero.y = hy; hero.r = HR;
  /* The sun: top-left in the sky, or wherever the far side of the arc leaves room. */
  /* The sun sits in the top bar's empty stretch, above any heading; on a phone, low in the sky between the routes. */
  const sun = landscape ? { x: W * 0.44, y: 46, r: clamp(min * 0.024, 11, 22) } : { x: W * 0.16, y: H * 0.62, r: clamp(min * 0.03, 10, 16) };

  const layer = document.createElement('canvas');
  layer.width = Math.round(W * dpr);
  layer.height = Math.round(H * dpr);
  const g = layer.getContext('2d', { alpha: false });
  g.scale(dpr, dpr);
  g.fillStyle = pal.paper;
  g.fillRect(0, 0, W, H);
  /* Orbits and dust round the sun, sweeping through the view. */
  const orbit = Math.hypot(hx - sun.x, hy - sun.y);
  const dots = dotBuckets([pal.ink, pal.ink2]);
  const budget = W * H * (lite ? 0.045 : 0.09);
  for (let band = 0; band < 4; band++) {
    const r0 = orbit * (0.34 + band * 0.42 + r() * 0.08), r1 = r0 + orbit * (0.1 + r() * 0.16), fall = 1.8 + r() * 1.4;
    for (let i = 0, n = budget / 4; i < n; i++) {
      if ((i & 4095) === 0) yield;
      const a = r() * TAU, t = Math.pow(r(), fall), rad = lerp(r0, r1, t), x = sun.x + Math.cos(a) * rad, y = sun.y + Math.sin(a) * rad;
      if (x < -3 || y < -3 || x > W + 3 || y > H + 3) continue;
      dots.add(t < 0.3 ? 0 : 1, x, y, 0.5 + r() * r() * 0.8 * (1 - t));
    }
  }
  yield* dots.steps(g, 0.72);
  g.strokeStyle = alpha(pal.ink, 0.28);
  g.lineWidth = 0.7;
  for (const m of [0.72, 1, 1.32]) { g.beginPath(); g.arc(sun.x, sun.y, orbit * m, 0, TAU); g.stroke(); }
  s.layer = layer;

  /* The world itself, made of grain, turned away from the sun. */
  const dx = sun.x - hx, dy = sun.y - hy, dl = Math.hypot(dx, dy) || 1, lx = dx / dl, ly = dy / dl;
  const surf = makeSurface(hero.surface, mulberry(s.seed * 2654435761 + 1033 + hero.i * 7));
  const pad = HR * 1.2, size = Math.ceil(pad * 2 * dpr);
  const heroC = document.createElement('canvas');
  heroC.width = heroC.height = size;
  const hg = heroC.getContext('2d');
  hg.setTransform(dpr, 0, 0, dpr, pad * dpr, pad * dpr);
  hg.fillStyle = pal.paper;
  hg.beginPath(); hg.arc(0, 0, HR, 0, TAU); hg.fill();
  const hd = dotBuckets([pal.ink, pal.ink2]);
  const n = Math.PI * (HR / u) * (HR / u) * (lite ? 0.28 : 0.5);
  for (let i = 0; i < n; i++) {
    if ((i & 4095) === 0) yield;
    const a = r() * TAU, t = Math.sqrt(r()), x = Math.cos(a) * t, y = Math.sin(a) * t;
    const lit = clamp(0.5 + (x * lx + y * ly) * 0.95, 0, 1);
    const h = surf.field(x, y) + gauss(r) * 0.2, land = h > 0;
    if (r() > (land ? 0.5 : surf.sea * 0.6 + 0.06) * (0.04 + 0.96 * lit) + (t > 0.985 ? 0.5 : 0)) continue;
    hd.add(land ? 0 : 1, x * HR, y * HR, (0.5 + r() * r() * (land ? 1 : 0.5)) * Math.max(u, 0.55));
  }
  yield* hd.steps(hg, 0.7);
  /* A calendar and a line of their script round it. */
  hg.strokeStyle = alpha(pal.ink, 0.7);
  const tickR = HR * 1.04, ticks = s.base * s.base;
  for (let i = 0; i < ticks; i++) {
    const a = (i / ticks) * TAU, major = i % s.base === 0;
    hg.lineWidth = major ? 1 : 0.6;
    hg.beginPath();
    hg.moveTo(Math.cos(a) * tickR, Math.sin(a) * tickR);
    hg.lineTo(Math.cos(a) * (tickR + (major ? 8 : 4)), Math.sin(a) * (tickR + (major ? 8 : 4)));
    hg.stroke();
  }
  const scriptR = HR * 1.04 + 22, step = 13 / scriptR;
  hg.strokeStyle = pal.ink; hg.fillStyle = pal.ink; hg.lineWidth = 1; hg.lineCap = 'round';
  let word = 3;
  for (let m = 0; m < TAU - step; m += step) {
    const gl = makeGlyph(r);
    if (word-- <= 0) { word = 2 + Math.floor(r() * 5); continue; }
    hg.save(); hg.translate(Math.cos(m) * scriptR, Math.sin(m) * scriptR); hg.rotate(m + Math.PI / 2);
    drawGlyph(hg, gl, -4, -6.5, 8, 13, 1.1);
    hg.restore();
  }
  hg.lineCap = 'butt';
  yield;

  /* Routes: from here to everywhere, and a web between neighbours. */
  const tq = mulberry(s.seed * 2654435761 + 1039 + SITE.page.length);
  const nodes = away.map(n => n.o);
  const lanes = nodes.map(o => makeLane(tq, hero, o, 1 + Math.floor(tq() * 3), 40, o === s.worldOf.get('home') || o.living));
  for (let i = 1; i < nodes.length; i++) if (tq() < 0.7) lanes.push(makeLane(tq, nodes[i - 1], nodes[i], 1 + Math.floor(tq() * 2), 46, false));
  s.routes = new Map(nodes.map((o, i) => [o, lanes[i]]));
  s.lanes = lanes;
  s.ports = [];
  s.features = [];
  /* A couple of gates hang along the way. */
  const gateSpots = [];
  s.gates.slice(0, 2).forEach((g, i) => {
    const a = nodes[(i * 3 + 1) % nodes.length];
    g.x = lerp(a.x, hx, 0.4 + i * 0.1) + (tq() - 0.5) * 60;
    g.y = lerp(a.y, hy, 0.4 + i * 0.1) + (tq() - 0.5) * 60;
    g.r = clamp(g.r, 8, 15);
    gateSpots.push(g);
  });
  s.gates = gateSpots;
  s.comms = makeComms(tq, gateSpots.map(g => [g, hero]).concat(nodes.filter(o => o.living).map(o => [o, hero])), [hero], 12, 13, min * 0.5);
  s.scene = { sun, hero, nodes, heroC, pad, lx, ly, HR };
}

function renderScene(s, t) {
  const c = s.scene, { pal, dpr } = s, hero = c.hero, k = 1;
  lastCamT = t;
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.globalAlpha = 1;
  ctx.drawImage(s.layer, 0, 0);
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  const st = s.civState;
  const enclosed = st && st.final && st.final.kind === 'transcended';
  /* The sun, unless it has been enclosed. */
  if (!enclosed) {
    ctx.fillStyle = pal.ink;
    ctx.beginPath(); ctx.arc(c.sun.x, c.sun.y, c.sun.r * (1 + sound.bass * 0.05), 0, TAU); ctx.fill();
    ctx.strokeStyle = alpha(pal.ink, 0.4);
    ctx.lineWidth = 0.7;
    ctx.beginPath(); ctx.arc(c.sun.x, c.sun.y, c.sun.r * 1.5, 0, TAU); ctx.stroke();
  }
  drawComms(s.commsNow || s.comms, t, 1, pal, k);
  /* A route lights up when you point at its page in the menu. */
  if (SITE.hover) {
    const o = s.worldOf.get(SITE.hover), l = o && s.routes.get(o);
    if (l && l.cx !== undefined) {
      ctx.strokeStyle = pal.ink;
      ctx.lineWidth = 1.8;
      ctx.beginPath(); ctx.moveTo(l.from.x, l.from.y); ctx.quadraticCurveTo(l.cx, l.cy, l.to.x, l.to.y); ctx.stroke();
    }
  }
  drawLanes(s.lanesNow || s.lanes, t, 1, pal, k, fleetOf(s), 1);
  for (const g of s.gatesNow || s.gates) drawGate(g, t, 1, pal, k);
  /* The other pages. */
  ctx.font = '400 10px "JetBrains Mono", ui-monospace, Menlo, monospace';
  ctx.textBaseline = 'middle';
  for (const o of c.nodes) {
    if (o.gone) continue;
    if (o.sprite && !o.shattered) {
      ctx.save();
      ctx.beginPath(); ctx.arc(o.x, o.y, o.r, 0, TAU); ctx.clip();
      ctx.drawImage(o.sprite, o.x - o.r, o.y - o.r, o.r * 2, o.r * 2);
      ctx.restore();
    }
    ctx.strokeStyle = pal.ink;
    ctx.lineWidth = o.living && o.settled !== false ? 1.2 : 0.7;
    ctx.beginPath(); ctx.arc(o.x, o.y, o.shattered ? o.r * 0.42 : o.r, 0, TAU); ctx.stroke();
    const name = s.pageOf.get(o);
    if (name) {
      const text = name.toUpperCase(), w = ctx.measureText(text).width, x = o.x + o.r + 7;
      ctx.fillStyle = 'rgba(255,255,255,.88)';
      ctx.fillRect(x - 3, o.y - 8, w + 6, 16);
      ctx.fillStyle = pal.ink;
      ctx.fillText(text, x, o.y);
      if (SITE.hover === name) ringAt(o.x, o.y, o.r + 7 + Math.sin(performance.now() / 200) * 2, 0.9, pal.ink, 1.2);
    }
  }
  ctx.textBaseline = 'alphabetic';
  /* This page's world. */
  if (!hero.gone) {
    ctx.globalAlpha = hero.shattered ? 0.3 : 1;
    ctx.drawImage(c.heroC, hero.x - c.pad, hero.y - c.pad, c.pad * 2, c.pad * 2);
    ctx.globalAlpha = 1;
  }
  drawArrival(s, t);
  drawStory(s, t, 1, k);
  drawEvents(s, t, 1, k);
}

/* You came along a route: a ship carries you in from the page you just left. */
function drawArrival(s, t) {
  const o = SITE.cameFrom && s.worldOf.get(SITE.cameFrom);
  if (!o || !SITE.arrivedAt) return;
  const u = (performance.now() - SITE.arrivedAt) / 6000;
  if (u < 0) return;
  if (u >= 1) { SITE.cameFrom = null; return; }
  const hero = s.scene.hero, e = u * u * (3 - 2 * u), { pal } = s;
  const stop = 1 - (hero.r * 1.1) / (Math.hypot(hero.x - o.x, hero.y - o.y) || 1);
  const p = e * stop, x = lerp(o.x, hero.x, p), y = lerp(o.y, hero.y, p);
  ctx.strokeStyle = alpha(pal.ink, 0.9 * (1 - u * 0.5));
  ctx.lineWidth = 1.4;
  ctx.beginPath(); ctx.moveTo(o.x, o.y); ctx.lineTo(x, y); ctx.stroke();
  const a = Math.atan2(hero.y - o.y, hero.x - o.x), c = Math.cos(a), sn = Math.sin(a), rs = 7;
  ctx.fillStyle = pal.ink;
  ctx.beginPath();
  for (const [px, py] of [[2.2, 0], [-1.2, 1.3], [-0.5, 0], [-1.2, -1.3]]) ctx.lineTo(x + (px * c - py * sn) * rs, y + (px * sn + py * c) * rs);
  ctx.closePath();
  ctx.fill();
}

/* Transcendence as seen from a world: others pour towards the sun; the swarm grows; if this one goes, only dust is left. */
function sceneStory(s, t, k) {
  const st = s.civState, c = s.scene, { pal } = s;
  const going = (st.arc && st.arc.kind === 'ascend') || (st.final && st.final.kind === 'transcended');
  if (going) {
    const u = st.final ? 1 : st.arc.progress;
    const gone = s.worlds.filter(o => o.gone && (o === c.hero || c.nodes.includes(o)));
    if (gone.length && u < 1) {
      ctx.fillStyle = pal.ink;
      ctx.beginPath();
      for (const p of streamSeeds) {
        const o = gone[Math.floor(p.band * gone.length)], f = 1 - ((t * p.sp * 3 + p.ph) % 1);
        const bend = Math.sin(f * Math.PI) * 60 * Math.sin(p.a);
        const dx = o.x - c.sun.x, dy = o.y - c.sun.y, l = Math.hypot(dx, dy) || 1;
        const x = c.sun.x + dx * f - (dy / l) * bend, y = c.sun.y + dy * f + (dx / l) * bend, r = p.s;
        ctx.moveTo(x + r, y);
        ctx.arc(x, y, r, 0, TAU);
      }
      ctx.fill();
    }
    const swarm = swarmSprite(s), scale = (c.sun.r * 3.4) / swarm.R;
    ctx.save();
    ctx.globalAlpha *= smooth(0.02, 0.8, u);
    ctx.translate(c.sun.x, c.sun.y);
    ctx.rotate(t * 0.02);
    ctx.scale(scale, scale);
    ctx.drawImage(swarm.c, -swarm.R, -swarm.R, swarm.R * 2, swarm.R * 2);
    ctx.restore();
    if (u >= 1) {
      const closed = enclosedSprite(s), sc = (c.sun.r * 2.4) / closed.R;
      ctx.save();
      ctx.translate(c.sun.x, c.sun.y);
      ctx.rotate(-t * 0.012);
      ctx.scale(sc, sc);
      ctx.drawImage(closed.c, -closed.R, -closed.R, closed.R * 2, closed.R * 2);
      ctx.restore();
    }
  }
  if (s.ended) {
    ctx.fillStyle = pal.ink;
    ctx.beginPath();
    for (const o of s.worlds) {
      if (!o.shattered || !(o === c.hero || c.nodes.includes(o))) continue;
      const big = o === c.hero;
      for (const p of shardSeeds) {
        const a = p.a + t * p.w, d = o.r * (big ? 0.55 + p.d * 0.3 : 0.45 + p.d * 1.3), r = p.s * (big ? 2 : 1);
        const x = o.x + Math.cos(a) * d, y = o.y + Math.sin(a) * d;
        ctx.moveTo(x + r, y);
        ctx.arc(x, y, r, 0, TAU);
      }
    }
    ctx.fill();
  }
}

/* One universe per visit, kept as you move between pages. A minute of your time is a day of theirs. */
const UNIVERSE_KEY = 'kimina.universe';
const DAY_MS = 86400000, RATE = 1440;
function plannedStories(seed, age) {
  const q = mulberry(seed * 2654435761 + 1049), list = [];
  let d = age + 1.5 + q() * 2.5;
  for (let i = 0; i < 8; i++) {
    const roll = q();
    const kind = roll < 0.55 ? 'war' : roll < 0.8 ? 'ascend' : 'destroy';
    const dur = kind === 'war' ? 1.5 + q() * 1.5 : kind === 'ascend' ? 5 + q() * 3 : 1;
    list.push({ kind, d, dur });
    d += dur + 2 + q() * 3;
  }
  return list;
}
function freshUniverse() {
  const seed = 1 + Math.floor(Math.random() * 99998);
  const age = 30 + Math.random() * 60;
  return { seed, founded: Date.now() - (age * DAY_MS) / RATE, age, at: Date.now(), last: null };
}
function readUniverse() {
  try {
    const u = JSON.parse(localStorage.getItem(UNIVERSE_KEY));
    if (u && u.seed && Date.now() - u.at < 6 * 3600000) return u;
  } catch (e) { /* private window: a new universe per page */ }
  return freshUniverse();
}
function saveUniverse(u) { try { localStorage.setItem(UNIVERSE_KEY, JSON.stringify(u)); } catch (e) { /* fine */ } }

let universe = readUniverse();
const forcedSeed = parseInt(params.get('seed'), 10);
if (forcedSeed) universe = { seed: forcedSeed, founded: parseFloat(params.get('founded')) || Date.now() - (60 * DAY_MS) / RATE, age: 60, at: Date.now(), last: null };

function useUniverse(u) {
  civFounded = u.founded;
  civRate = RATE;
  civStory = params.get('story') ? JSON.parse(params.get('story')) : plannedStories(u.seed, u.age);
}
/* When a civilisation is finished, watch the ruins for a minute, then another begins. */
function siteTick() {
  sliderTick();
  const c = sys && sys.civState;
  if (!c || !c.final || pendingBuild || forcedSeed || OPTS.mini) return;
  if (c.age - c.final.d0 > 1) {
    universe = freshUniverse();
    saveUniverse(universe);
    loadSeed(universe.seed, universe.founded);
    civStory = plannedStories(universe.seed, universe.age);
  }
}

function start(seed, built) {
  cancelAnimationFrame(raf);
  raf = 0;
  const W = canvas.clientWidth || window.innerWidth, H = canvas.clientHeight || window.innerHeight;
  sys = built && built.W === W && built.H === H ? built : build(seed, W, H);
  const home = sys.worlds[sys.homeIdx];
  sys.vs = (Math.min(W, H) * 0.34) / home.a;
  sys.hx = 0; sys.hy = 0;
  canvas.width = Math.round(W * sys.dpr);
  canvas.height = Math.round(H * sys.dpr);
  simT = 0;
  lastT = 0;
  liveEvents.length = 0;
  cam.planned = null;
  pendingBuild = null;
  applyCiv(true);
  cam.z = testZ !== null ? clamp(testZ, LEVEL_MIN, LEVEL_MAX) : 0;
  cam.k = 0;
  cam.u = 1;
  cam.hold = 20;
  /* Only the home page wanders through the scales, and only on devices with room. */
  cam.auto = !frozen && (onSliders || (!LITE && SITE.page === 'home'));
  cam.stay = onSliders;
  exp.want = null;
  render(startAt);
  /* Full strength on the map; quieter behind a page's text. */
  canvas.style.opacity = SITE.chart ? '1' : '0.4';
  if (frozen) return;
  startedAt = performance.now();
  lastDraw = startedAt;
  if (SITE.cameFrom && sys.scene) SITE.arrivedAt = startedAt + 700;
  if (!sys.scene && cam.auto) preload(sys); else sys.ready = true;
  resume();
}
function resume() {
  if (frozen || raf || !sys || !inView || document.hidden) return;
  lastDraw = performance.now();
  raf = requestAnimationFrame(loop);
}

let inView = true;
function newSeed() { return 1 + Math.floor(Math.random() * 99998); }

/* The sliders on the Orrery's own page. Nothing on the universe itself is clickable here. */
let sliderScale = 0;
function sliderTick() {
  if (!onSliders || !sys || frozen || cam.u < 1 || exp.want !== null) return;
  if (sliderScale !== Math.round(cam.z)) zoomLevel(sliderScale);
}
function setHistoryRate(rate) {
  /* Keep today's date in their history: only how fast it runs from here changes. */
  const age = (Date.now() - civFounded) * civRate / DAY_MS;
  civRate = rate;
  civFounded = Date.now() - age * DAY_MS / rate;
  civTimer = 0;
}
function wireSliders() {
  const box = document.querySelector('.orrery-sliders');
  if (!box) return;
  if (frozen) { box.hidden = true; return; }
  const words = { scale: ['A solar system', 'Nearby stars', 'A galaxy', 'A galaxy group', 'A supercluster'] };
  const show = (i, text) => { const o = i.parentElement.querySelector('output'); if (o) o.textContent = text; };
  box.querySelectorAll('input[type=range]').forEach(i => {
    const kind = i.dataset.control;
    const apply = () => {
      const v = parseFloat(i.value);
      if (kind === 'speed') { simSpeed = v; show(i, `${v.toFixed(2)}×`); }
      if (kind === 'history') { setHistoryRate(RATE * v); show(i, `${(v * 24 * 60 / 60).toFixed(v < 1 ? 1 : 0)} hours a minute`); }
      if (kind === 'scale') { sliderScale = v; show(i, words.scale[v]); }
      if (kind === 'dust') show(i, `${v.toFixed(1)}×`);
    };
    i.addEventListener('input', apply);
    /* Dust is painted into the chart, so it redraws only when you let go. */
    if (kind === 'dust') i.addEventListener('change', () => { dustMul = parseFloat(i.value); swapSystem(sys.seed); });
    apply();
  });
}

if (!OPTS.mini) {
/* Pointing at a page in the menu lights up its route. */
document.querySelectorAll('.side-nav a').forEach(a => {
  const name = (a.getAttribute('href') || '').replace(/\.html.*$/, '');
  a.addEventListener('mouseenter', () => { SITE.hover = name; });
  a.addEventListener('mouseleave', () => { SITE.hover = null; });
});
/* Nothing is drawn while the home page's first screen is scrolled away, or the tab is hidden. */
const intro = document.querySelector('.intro');
if (intro && 'IntersectionObserver' in window) {
  new IntersectionObserver(entries => {
    inView = entries[entries.length - 1].isIntersecting;
    resume();
  }).observe(intro);
}
document.addEventListener('visibilitychange', resume);

/* Only a real size change rebuilds: a phone's address bar sliding away must not. */
let resizeTimer = 0;
window.addEventListener('resize', () => {
  clearTimeout(resizeTimer);
  resizeTimer = setTimeout(() => {
    if (!sys || (canvas.clientWidth === sys.W && canvas.clientHeight === sys.H)) return;
    start(sys.seed);
  }, 200);
});

}

viewMode = 'star';
changeEvery = 0;
if (OPTS.mini) {
  /* Painted only once it scrolls into view, and resting whenever it's out of view. */
  civFounded = Date.now() - 60 * DAY_MS / RATE;
  civRate = RATE;
  civStory = [];
  let begun = false;
  const begin = () => {
    begun = true;
    if (frozen) { start(OPTS.seed); return; }
    const gen = buildGen(OPTS.seed, canvas.clientWidth, canvas.clientHeight);
    const step = () => {
      const until = performance.now() + 6;
      while (performance.now() < until) {
        const x = gen.next();
        if (x.done) { start(OPTS.seed, x.value); return; }
      }
      requestAnimationFrame(step);
    };
    requestAnimationFrame(step);
  };
  new IntersectionObserver(entries => {
    inView = entries[entries.length - 1].isIntersecting;
    if (inView && !begun) begin(); else resume();
  }, { rootMargin: '200px' }).observe(canvas);
  document.addEventListener('visibilitychange', resume);
  return;
}
useUniverse(universe);
if (onSliders) wireSliders();
if (!onSliders) {
  if (universe.last && universe.last !== SITE.page) SITE.cameFrom = universe.last;
  universe.last = SITE.page;
  universe.at = Date.now();
  saveUniverse(universe);
}

/* The page's words come first; the universe is painted a slice at a time behind them, and fades in. */
if (frozen) start(universe.seed);
else {
  const W0 = canvas.clientWidth || window.innerWidth, H0 = canvas.clientHeight || window.innerHeight;
  const gen = buildGen(universe.seed, W0, H0);
  const step = () => {
    const until = performance.now() + 10;
    while (performance.now() < until) {
      const x = gen.next();
      if (x.done) { start(universe.seed, x.value); return; }
    }
    requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
}
