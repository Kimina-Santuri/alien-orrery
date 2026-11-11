#!/usr/bin/env python3
"""Builds kimina.co.ke's orrery.js from the full orrery in ../index.html, plus the site layer below.
Run after changing the engine, then bump ?v= on the website's script tags."""
import os, re
HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, '..', 'index.html')).read()
s = re.search(r"<script>\n(.*)</script>", src, re.S).group(1)
def sub(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:90])
    s = s.replace(a, b)
def between(start, end, new):
    global s
    assert s.count(start) == 1, (s.count(start), start[:90])
    i = s.index(start); j = s.index(end, i)
    s = s[:i] + new + s[j:]

# Monochrome: black, grey and white only.
between("const PALETTES = [", "const TAU = Math.PI * 2;", """const PALETTES = [
  { name: 'site', paper: '#ffffff', ink: '#050505', ink2: '#8e8e8e', accent: '#000000' },
  { name: 'carbon', paper: '#0a0a0c', ink: '#e8e8ea', ink2: '#5a5a63', accent: '#e83f3f' },
];

""")
sub("const rolledPalette = PALETTES[Math.floor(r() * (wallpaper ? 16 : 6))];", "const rolledPalette = PALETTES[0];")
# Page and canvas.
sub("const canvas = document.getElementById('c');\nconst ctx = canvas.getContext('2d', { alpha: false });", """const canvas = OPTS.canvas || document.querySelector('.orrery-canvas');
if (!canvas) return;
/* Set here as well as in the stylesheet: a cached old stylesheet must never leave the canvas in the page flow. */
if (OPTS.mini) Object.assign(canvas.style, { opacity: '0', transition: 'opacity .9s ease' });
else {
  Object.assign(canvas.style, { position: 'fixed', top: '0', left: '0', zIndex: '-1', width: '100%', pointerEvents: 'none', opacity: '0', transition: 'opacity .9s ease' });
  canvas.style.height = '100vh';
  canvas.style.height = '100lvh';
}
const ctx = canvas.getContext('2d', { alpha: false });""")
sub("const frozen = params.has('still') || reduceMotion;", "const saveData = !!(navigator.connection && navigator.connection.saveData);\nconst lowEnd = (navigator.hardwareConcurrency || 4) <= 4 || (navigator.deviceMemory || 8) <= 4;\nconst frozen = params.has('still') || reduceMotion || saveData || !!(OPTS.mini && lowEnd);")
sub("const explore = params.has('explore'); /* the Mac app's Explore window: clickable, with a panel */\nconst wallpaper = params.has('wallpaper') || explore; /* run by the Mac app: no controls, driven through window.orrery */", "const explore = false; /* clicking is the Mac app's for now */\nconst wallpaper = true; /* civilisations and stories on */")
s = re.sub(r"/\*SITE-SKIP\*/.*?/\*END-SITE-SKIP\*/\n", "", s, flags=re.S)
sub("const followEvents = params.has('wallpaper'); /* on the desktop, the camera goes to what just happened */", "const followEvents = false;")
sub("const crumbles = followEvents || explore; /* worlds and suns come apart in grain; the website keeps the simpler story */", "const crumbles = !OPTS.mini; /* worlds and suns come apart in grain */")
sub("let forcedPalette = null,", "let forcedPalette = OPTS.palette || null,")
sub("window.orrery = {", "window[OPTS.mini ? 'orreryMini' : 'orrery'] = {")
s = re.sub(r"    /\* A click on the wallpaper, passed in by the app.*?(?=    explored\(\) \{)", "", s, flags=re.S)
sub("  const target = 1000 / (moving && !LITE && quality > 0.7 ? frameRate.move : frameRate.rest);", "  const target = OPTS.mini ? 66 : 1000 / (moving && !LITE && quality > 0.7 ? frameRate.move : frameRate.rest);")
sub("  document.getElementById('scale').textContent = `${label} · ${size}`;\n", "  void label; void size;\n")
# Enough worlds for every page; suns kept right or top, clear of the navigation.
s = re.sub(r"  const n = kind === 'compact' \? (.*?);\n", lambda m: "  const n = Math.max(11, kind === 'compact' ? " + m.group(1) + ");\n", s, count=1)
sub("  const nearStart = !landscape || r() < 0.5;\n", "  const coin0 = r();\n  void coin0;\n  const nearStart = !landscape;\n")
sub("const shot = shotRoll < 0.5 ? 'edge' : shotRoll < 0.68 ? 'corner' : shotRoll < 0.86 ? 'inset' : 'beyond';", "const shot = shotRoll < 0.6 ? 'edge' : shotRoll < 0.8 ? 'corner' : 'beyond';")
# Slower pacing on the site.
sub("const pacing = { jMin: 8, jMax: 15, pMin: 8, pMax: 18 };", "const pacing = { jMin: 20, jMax: 30, pMin: 20, pMax: 30 };")
sub("  let E = M + e * Math.sin(M);", "  let E = M + e * Math.sin(M);")
sub("let simT = 0, simSpeed = 1, lastT = 0, civTimer = 30;", "let simT = 0, simSpeed = 0.43, lastT = 0, civTimer = 30;")
sub("function place(s, x, y) {\n  VX = s.cx + x; VY = s.cy + y;", "function place(s, x, y) {\n  if (s.scene) { VX = s.scene.sun.x + x * 0.05; VY = s.scene.sun.y + y * 0.05; return; }\n  VX = s.cx + x; VY = s.cy + y;")
# Each page: a view from its own world. Home: the full chart.
sub("  yield* drawStatic(sysObj, r, R);\n  yield;\n", "  assignPages(sysObj);\n  if (SITE.chart) yield* drawStatic(sysObj, r, R); else sysObj.scene = true;\n  yield;\n")
sub("  worlds.forEach(o => { if (o.r > 3 * px) o.sprite = worldSprite(sysObj, o); });\n", "  worlds.forEach(o => { if (o.r > 3 * px || sysObj.scene) o.sprite = worldSprite(sysObj, o); });\n")
sub("  drawCometPaths(sysObj, sysObj.g);\n", "  if (!sysObj.scene) drawCometPaths(sysObj, sysObj.g);\n")
sub("  sysObj.closeups = {};\n", "  sysObj.closeups = {};\n  if (sysObj.scene) yield* paintScene(sysObj);\n")
sub("function render(t) {\n  const s = sys;\n", "function render(t) {\n  const s = sys;\n  if (s.scene) { renderScene(s, t); return; }\n")
sub("  /* Transcendence: worlds pour in as spiralling grain, and a swarm thickens round the star. */\n", "  if (s.scene) { sceneStory(s, t, k); return; }\n  /* Transcendence: worlds pour in as spiralling grain, and a swarm thickens round the star. */\n")
sub("  for (const o of worlds) drawWorld(s, o, t);\n", "  for (const o of worlds) drawWorld(s, o, t);\n  if (scale === 1 && cam.k === 0 && SITE.page === 'home') drawPageLabels(s);\n")
# Panel on the right, out of the player's way, and naming this page.
sub("const CELL_W = 8.4, CELL_H = 12, ROW_H = 19, PANEL_LEFT = 28, PANEL_BOTTOM = 104;", "const CELL_W = 8.4, CELL_H = 12, ROW_H = 19, PANEL_BOTTOM = 66;\nlet PANEL_LEFT = 28;")
sub("  const rows = flipper.rows;\n  const top = s.H - PANEL_BOTTOM - rows.length * ROW_H;\n", "  const rows = flipper.rows;\n  if (s.W < 820 || SITE.page !== 'home') return;\n  PANEL_LEFT = s.W - 32 - Math.max(...rows.map(r => r.text.length)) * CELL_W;\n  const top = s.H - PANEL_BOTTOM - rows.length * ROW_H;\n")
sub("  ctx.font = '500 10.5px ui-monospace, SFMono-Regular, Menlo, monospace';", "  ctx.font = '400 10.5px \"JetBrains Mono\", ui-monospace, Menlo, monospace';")
sub("    if (civTimer <= 0) {", "    siteTick();\n    if (civTimer <= 0) {")
sub("function loop(now) {\n", "function loop(now) {\n  if (!inView || document.hidden) { raf = 0; return; }\n")
# Replace the page's own ending.
i = s.index("function currentSeed() {")
s = s[:i] + open(os.path.join(HERE, 'site_layer.js')).read() + """
};
bootOrrery({});
/* A small live chart wherever a page asks for one, using this same script, so it costs no extra download. */
document.querySelectorAll('.orrery-mini').forEach(c => bootOrrery({ canvas: c, mini: true, seed: parseInt(c.dataset.seed, 10) || 314, palette: 'carbon' }));
"""
assert s.startswith('(() => {') or s.lstrip().startswith('(() => {'), s[:40]
s = s.replace('(() => {', 'const bootOrrery = OPTS => {', 1)
header = """/* The site's background: one universe across all the pages. Each page is a world in the same system, joined by routes,
   with the same civilisation and stories carrying on as you move between them. Generated from the Alien Orrery
   (github.com/Kimina-Santuri/alien-orrery) by tools/make_site_orrery.py there; change it there, not here. */
"""
out = os.path.join(HERE, '..', '..', 'kimina-website-main', 'orrery.js')
open(out, 'w').write(header + s)
print('wrote', os.path.normpath(out), len(s))
