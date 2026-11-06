# Alien Orrery

Generative charts of imagined solar systems, as the civilisations living in them might draw them. One self-contained
`index.html` with no build step, libraries, fonts or images. Open the file in a browser to run it.

Started from a look at generative work by @0010_888 on X (grain, arcs, flat discs). This is an original system with its
own concept and palettes; don't copy that work's compositions or colours, since it is someone's work for sale.

## How it works
- `index.html#42` shows chart 42. The same number at the same screen size always draws the same chart. "New" picks a
  random number; "Save" downloads a PNG of the current view; "Home view" and "Zoom off" are toggles.
- Test options: `?still=1` draws one frame and stops, `?t=30` starts 30 seconds in, `?z=2` starts at a scale (-1 to 4,
  fractions show mid-zoom), `?view=home` starts in home view.
- Scales (`LEVELS`): -1 home world, 0 system, 1 stellar neighbourhood, 2 galaxy, 3 galaxy group, 4 supercluster. The
  camera (`stepCam`) picks a random scale, travels for a random 8-15 s, pauses, and repeats. A plate shrinks into the
  accent "home" marker on the plate above.
- Sharpness (`layerMix`): each scale has three forms. A full-resolution print at rest, a round sprite while shrinking,
  and while growing a replay (`recording`, `replay`, `drawDots`) of its recorded lines plus a sample of its grain, redrawn
  sharp every frame. Never enlarge a raster far; that was the blur. Plates are built twice from the same seed, so their
  grain unit `u` must stay fixed or the two prints stop matching. They build in the background and the camera waits for
  `s.ready`. Changing `u` or anything using a plate's `r` re-rolls the far scales (the charts are unaffected).
- The light-year figures in the caption are round illustrative numbers, and the zoom is not to scale.
- Charts are seeded. Changing the order of `build`'s `r` calls changes every chart, so give new features their own
  `mulberry` stream (traffic uses salts 401 to 541).
- Almost everything is drawn once into a static layer. Each frame only redraws worlds, suns, comets, traffic, alignment
  lines and a few hundred to about 1,400 loose grains. Up to 60 frames a second while the camera moves on capable
  devices, otherwise 30. Pixel density capped at 2. Lower `quality` (adaptive, in `loop`) draws fewer grains.
- Honours reduced-motion (a single still frame).

## What the chart encodes
- Dust is sampled in time with Kepler's equation, so it gathers where orbits run slowest.
- Worlds sit in whole-number period ratios; orbit sizes follow Kepler's third law.
- Sizes are not to scale: they follow importance (huge suns, large home world).
- The engraved band is the home world's habitable zone. Calendar ticks around it are equal in time, not distance, and
  every base-th tick is longer.
- The curved script and world names are invented glyphs with no meaning. Each world's year is written in the
  civilisation's number base (5 to 9) as rows of dots.
- Thin lines mark worlds in alignment. The dotted path is a comet.
- Home view is the same system measured from the home world: position minus home's position at the same moment. The
  suns circle home, other worlds trace rosettes, and grain gathers at the turning points of their retrograde loops.
  Alignments there are measured from home.

## 2026-11-06
Built the first version (local only, not under git, not deployed).

Verified in headless Chrome: charts rendered at 1280x800 and 390x844 across several seeds and palettes; the animation
runs (pixels change over 3 seconds), New system and Save image fire, no page errors; a chart builds in about 0.2-0.3 s on
this Mac.

Not verified: a real budget Android phone (build time and frame rate are the risk), iOS Safari, and viewing the motion
by eye (only stills and pixel counts). Saved PNG contents weren't opened.

## 2026-11-06 (later): random zoom and home view
Added both at the user's request. They asked for a simple random zoom out to supercluster scale and the home-centred view.

Verified in headless Chrome: star view is pixel-identical to the previous version at z=0 (charts 42 and 108 at 1280x800
above the caption, chart 1 at 390x844); every scale and mid-zoom frames looked at as stills, on desktop and phone; a
sped-up real-time run took 10 random journeys at about 30 fps with no page errors; Home view, Zoom off (camera holds
still), New and Save fired. Plates built in 22-82 ms each and the home view in about 400 ms on this Mac. Longest
JavaScript frame about 38 ms, though that doesn't measure GPU work.

Not verified: real budget Android or iOS (memory is the new risk: up to six large sprites; `liteDevice` caps them at
1200 px), normal-speed zoom pacing watched by eye, and saved PNG contents. Not deployed, not under git.

## 2026-11-06 (later still): sharper transitions, 8-15 s journeys
The user loved it and said the pacing is right, but transitions were blurry, and asked for pacing that drifts between
8 and 15 seconds. I took that as journey length; pauses between journeys are unchanged. Cause of the blur: rasters
enlarged up to about 5x, and sprites below retina resolution even at rest.

Verified in headless Chrome: before and after crops at 2x show grain, lines and script crisp at the same moments; star
view still pixel-identical (charts 42 and 108, phone chart 1); steady 30 fps at 1440x900 2x in motion, at all three
smoothing settings, over about 45 s; no page errors; camera, Home view, Zoom off, New and Save still work. Slowest
background build job about 160 ms on this Mac; first press of Home view about 600 ms.

Caveats: the galaxies, webs and neighbourhoods re-rolled for every chart, because the grain unit changed. The 30 fps
figure is callback timing in headless Chrome and may not capture all GPU work; forcing each frame to finish with a
readback gave a median of 65 ms in motion, which inflates the cost. Memory is estimated, not measured: roughly 300 MB
at worst on a retina Mac, about 55 MB on a lite phone. Still not verified: real budget Android or iOS, smoothness by eye,
saved PNG contents. Not deployed, not under git.

## 2026-11-06 (evening): variation, traffic, detail and lag
The user reported sharp but less detailed transitions and some lag, and asked for random home worlds (bigger, more moons),
several habitable worlds, a more random home system, then wormholes or gates, ships and shipping lanes.

**Chart numbers now show different systems.** The previous version is kept as `index-v3-before-variation.html`.

Added: 1-3 suns, 3-10 worlds, 1-3 living worlds in one engraved band, 0-3 comets, wild orbits, dust from sparse to thick,
four compositions (`shot`). Home world in four size classes, 0-7 moons, sometimes rings, six surfaces. Sister worlds show
in the close-up sky. Gates and wormholes, dashed flowing lanes, and ships drawn live at all six scales (`drawLanes`,
`drawGate`, `makeLane`). Detail: a soft tone layer (smallest mip) under sharp grain, chart marks in the zoom sprite.

Measuring lag: **don't use readback timing or headless Chrome for this.** `getImageData` pushes the canvas off the GPU and
gave false results (over 2 s a frame), and headless showed a flat 30 fps. Measure rAF gaps in real Chrome, in a temporary
profile with the window off-screen. Findings there, 1440x900, 120 Hz display: the previous version fell to about 40 fps
at several mid-zoom moments; image stamps for grain were slower than one large path of arcs (40-60 vs a steady 120 fps),
so stamps were removed; `imageSmoothingQuality = 'high'` on large sprites was replaced by mip pyramids.

Verified: final build a steady 120 fps with the frame cap removed at 12 fixed zoom levels (charts 42 and 58, star and
home view); 40 random systems at 11 zoom levels in both views with no page errors; buttons work; phone layouts viewed as
stills. Not verified: real phones (a budget Android is still the main risk; `LITE` and adaptive `quality` are untested
there), very long sessions, memory (estimated only), saved PNG contents, and how the traffic looks in motion by eye.

## 2026-11-06 (night): alien hulls, ship registries, distance-based speeds
The user said the ships are perfect but asked for a different icon, an alien name or serial number on each ship, and
slower ships at larger scales because of the distances.

Six hull shapes (`HULLS`), and each civilisation flies three (`fleetOf`). Each ship has two glyphs and a serial in the
civilisation's number base, drawn upright; a registry is hidden near docking and where it would overlap another.
Crossing times (`makeLane` base, seconds): world 15-18, system 22-30, neighbourhood 70-90, galaxy 200, group 420,
supercluster 900, each varied per ship by 0.7-1.5x. Lane dashes follow (`flow`); far gates turn and swirl slower. Registries come
from a stream seeded by the ship's phase, so charts keep their systems, gates and lanes.

Verified: stills at 2x and phone size; a 12 s system-to-supercluster journey in real GPU Chrome at a steady 60 fps
(gap median 16.7 ms, p95 17.5 ms); 40 random systems at 11 zoom levels in both views with no page errors; buttons work.
Not verified: speeds or labels by eye in motion, a real phone.

## 2026-11-06: copy on kimina.co.ke
`~/Documents/kimina-website-main/orrery.js` is a separate adapted copy for the site's landing page (see that project's
AGENTS.md). Changes here don't reach it by themselves. `index-v3-before-variation.html` is the version before varied systems.


## 2026-11-06: Mac wallpaper app, fixed ports, comms
User's requests: lanes on small orbits swung wildly; a macOS wallpaper program; radio or FTL comms.

Ports: lanes to worlds with orbits under 90 s end at a fixed port on the orbit, and `syncShips` times each trip so its wrap lands
as the world passes (the same applies to moons in the close-up). Measured over 60 systems: no lane tied to a quick world, 0 px
miss. Comms: `makeComms`, `drawComms`: radio from living worlds and home, out to neighbourhood scale; FTL flashes at every scale.
Both are also in the website's `orrery.js`, patched by hand, so keep them in step. Rings look off-centre from the suns on purpose:
orbits have the suns' centre of mass at a focus (`e` up to 0.24 in `wild` systems) and binary suns circle that point.

`mac/`: Swift package, no Xcode. `scripts/build.sh` builds `build/Orrery.app` with the current `../index.html` inside as
`orrery.html`; `--install` copies to /Applications and opens it. One borderless window per display at desktop level (below icons),
on all Spaces, ignoring the mouse, with a WKWebView loading `orrery.html?wallpaper=1`, which hides the controls and exposes
`window.orrery` (`next`, `setPalette`, `setView`, `setZoom`, `setChange`, `setPaused`, `state`). Menu bar: New system, View, Colours,
Change system, Random zoom, Pause, Pause on battery (default on), Save image (~/Pictures/Orrery), Open at login, Quit. It pauses on
sleep, lock and Low Power Mode, and rebuilds when displays change. Set `ORRERY_DEBUG=<dir>` for a state log and snapshots of its own window
only (`ORRERY_NOSNAP`, `ORRERY_JS`). Settings live in `defaults` domain `ke.co.kimina.orrery`.

Measured on an M1 Pro on battery at 3600x2338 (ps CPU time, app plus its WebKit processes): chart 13% of one core, Home view 24%, with zoom
33%, paused 0.1%; memory about 350-730 MB. Not verified: GPU or battery draw in watts (needs sudo), several displays, Spaces and
full-screen behaviour, whether icons stay clickable by hand, the menu by hand, open at login, sleep and wake, a long session.

## 2026-11-06 (evening): living civilisations and Orrery 0.2.0
User's request: everything offered for the wallpaper (persistent civilisations, chronicle, first contact, real time, reacts to sound,
settings, bigger visuals, saving), random continents and water worlds, a public MIT repo, and an unsigned app download.

Engine (`index.html`): `makeSurface` gives each world its own surface (continents, pangaea, archipelago, water with storms, desert, ice,
banded, lava, barren), shown on the chart through `worldSprite` and in the close-up. `civHistory` replays a history from seed and age in
six-hour ticks with fixed draws per tick, so a longer history always starts with the same past. `applyCiv` and `applyPlateCiv` decide which
gates, lanes, ships, comms and city lights exist. `pushEvent` and `drawEvents` play gate openings, comets, contact, strangers, festivals
and beats. `drawNightSide` draws the close-up's night live from the Mac's clock; `drawOverlays` draws the chronicle and dims the
wallpaper after Nairobi's sunset. `window.orrery` is the API. The website's `orrery.js` doesn't have any of this.

App (`mac/`, 0.2.0): follow one civilisation (saved per display in defaults as `civ.<display id>`) or tour; the first one you meet is already
30 to 60 days old. Chronicle, favourites, 16 palettes plus site plus custom, Settings window, sound from Mac audio (ScreenCaptureKit) or an
input (AVAudioEngine), 20-second video through MediaRecorder, one system across displays (full-desktop canvas offset per window, time from the
shared clock, zoom off). Launch arguments such as `-pauseOnBattery NO` override settings for testing without saving them; `ORRERY_FAKE_SPLIT=1`
simulates two displays and `ORRERY_OPEN_SETTINGS=1` opens Settings.

Verified: histories across 40 seeds and 8 ages; every API call and event with no errors in Chrome; inside the app's WebKit: a civilisation carried
across restarts, events and `setAudio` drawn, a real H.264 video file, menu contents dumped, Settings window viewed, span seamless across two
half-screen windows.
Not verified: real audio capture from either source (permission prompts, needs the user), real second display, menu clicks by hand,
the Open Anyway flow on another Mac, sleep and wake, multi-day running, GPU power.
Intel Macs: not built. Universal builds need Xcode's build system.
