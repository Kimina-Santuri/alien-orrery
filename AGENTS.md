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

## 2026-11-06 (night): more zoom destinations, Orrery 0.3.0
User's request: more zoom items for desktop: space stations, occupied asteroids, wormholes, black holes, stars, moons if colonised, and more.

Zoom level -1 is no longer only the home world. `s.focus` picks what it shows, and `buildCloseup` dispatches to `buildWorld` (any world), `buildMoon`, `buildStar`,
`buildGateClose` (ring gate or wormhole), `buildStation`, `buildAsteroid` and `buildBlackHole`. `focusOptions` lists what exists and is on screen, `chooseFocus` picks by weight,
`prepareFocus` paints the next one during a pause so the journey doesn't stall, `rememberCloseup` keeps the home world and two others in memory. From the chart, 40% of journeys are dives.
`s.features` holds stations, occupied asteroids and the black hole (about 45% of systems roll one, and it needs a spot in view). `civHistory` adds their dates from its own stream `q2`, so
existing histories keep their past. `orrery.visit(kind)`, `orrery.chart()` and the app's Zoom to menu go there on demand. Test with `?z=-1&focus=blackhole`.
Close-ups paint a moon's or star's civ state at build time, so one kept in memory can lag a new colony until it's rebuilt. Black holes are only in the home system; the galaxy's core isn't a destination.

Verified: 28 systems with every kind of destination visited at z -0.6 and -1 and no page errors; the same civilisation at day 3 and day 300 shows the right items; each close-up viewed;
the real app ran 95 s with non-stop zooming and no page errors, using very roughly 33-47% of one core and 330-460 MB (CPU pids found by a looser method than before, so treat as approximate).
Not verified: Zoom to clicked by hand (menu contents were dumped), a long session. Released as 0.3.0 with the grain redraw below (user's go-ahead).

## 2026-11-06 (night): close-ups redrawn in grain
User's request: give the station, star and other new close-ups "the same grainy aesthetic". Flat fills and vector hulls are gone. `grainDisc`, `grainBand` and `grainBar` draw shaded
balls, belts with one hard edge, and struts; `grainSprite` stipples a turning part once (habitat, gate collar) so it can rotate without redrawing its dots; `grainNight` gives moons a dithered
night instead of a flat tint. Watch density: dots overlap into solid colour above about `dens` 1.5, so check at full resolution. Sprites are built only in the recording pass (`g.__ops`).
Home and other worlds keep their earlier flat night tint. Lanes, ships, labels and range rings are still vector, as on the chart. The chart's small station, asteroid and black hole icons are vector too.

## 2026-11-06 (night): Zoom to fixes, released in 0.4.0
User's report: "zoom to doesnt work". Cause: it used the Settings zoom sliders, and theirs were at about 60 s, so a journey with a gentle ease-in looked like nothing happening. Now `ASKED_JOURNEY` is a fixed 7 s.
Also: Zoom to can reach anything that exists, off-screen too (`focusOptions(s, true)`), and items grey out if no display has one or while paused. Each display goes only if its own system has that thing.
`ORRERY_MENU="A star"` presses a real menu item. **Testing trap:** two copies running stack at desktop level, so the lower one reports `document.hidden` with no animation frames, and any test of it is meaningless. Quit other copies first.
Any window covering the desktop also stops animation (rAF), which saves power. App icon: the user chose the black hole (option B of four). Source is `mac/Support/AppIcon.png`, built into `AppIcon.icns`.

## 2026-11-06 (night): continuous transitions and a flipping chronicle, released in 0.4.0
User's request: the local system's harsh rectangle and transparency fades during transitions; the script at the bottom should sometimes flip letter by letter to English with the planet's name, size and development.
Transitions (`layerMix`, `render`, `clearAround`): the screen-sized print is only used within about 3% of true size, then the round edgeless sprite takes over. Two scales share one space: the wider arrives early as sharp grain, the one left stays solid until it's small, then fades with a soft clearing beneath it. `s.hideFocus` hides a close-up's small chart self until they hand over at z of about -0.82. `CAP_PLATE` is now 3072.
Chronicle (`drawChronicle`, `panelLines`, `cipherGlyph`): the panel is now a real cipher, one glyph per character per civilisation, so its text does mean something, unlike the inscriptions round the charts. Flips every 25-75 s, holds 9-15 s. `orrery.flip()` forces one.
WebKit bug found the same night: a single canvas path with very many dots is silently not drawn in Apple's WebKit (Chrome draws it), so a whole colour of grain vanished. `dotBuckets.flush` and `drawStatic` now fill in batches of 20,000 (`DOT_BATCH`). Check close-ups in the real app, not only Chrome (`ORRERY_DEBUG` snapshots, with no other copy running). The website's `orrery.js` doesn't have this fix yet, and iPhones use WebKit.
Verified: frame gaps a steady 120 fps at 14 transition depths, at dust 1x and 2x, in GPU Chrome; flip and Zoom to in the real app with no page errors, frames viewed. Not verified: a whole journey watched by eye at normal speed.

## 2026-11-06 (late): faster switching, real system types, half-size close-ups, building traditions (released in 0.4.0)
User's request: switching colours or civilisation lagged, so go through the code; use NASA and sci-fi for system structure (a black hole beside three suns made no sense); half-size stations and asteroids in close-up; designs that vary by civilisation.
Speed: measured in the real app with 2x dust and two displays, `drawStatic` froze for 250-870 ms per display, then up to 14 more jobs of up to 600 ms. Now `buildGen`, `drawStatic`, `starDiscGen`, `homeLayerGen`, `homeDiscGen` and `paintHomeSky` are generators sliced across frames (`advanceBuild`, `runBacklog`, `finished`); the old system keeps running and the newest request wins. `planNext` decides the next journey during the pause and prepares only that. Off-screen grain is rejected before Kepler; `solveE` uses 2 rounds below e 0.3; `mix` and `alpha` are memoised. Plate builders are not sliced, so one job can still take up to about 250 ms during a pause.
System types (`ARCHETYPES`, picked by own stream, so seeds keep their palette and rough layout logic but look different from before): single; binary (Kepler-16, Kepler-47); triple (Alpha Centauri); compact (TRAPPIST-1, with tidally locked 'eyeball' worlds); debris (HR 8799); pulsar (PSR B1257+12); starhole (Gaia BH1, no planets known there); hole (Gargantua in Interstellar, fiction: no confirmed planets orbit a black hole). Black holes now only exist as central bodies. Living worlds round a pulsar or black hole are artistic licence.
Close-ups: station, asteroid, gate and wormhole at half size (0.135 to 0.155 of the short screen side). Black holes, stars, moons and worlds keep their size.
Traditions (`CULTURES`, `s.culture`): arc (wheels, double wheels, O'Neill-style cylinders, ring gates, domes), lattice (ISS-style trusses, open frames, hexagonal gates, grid towns, scaffolded asteroids), bloom (pods on stalks, seeds, petal gates, bulbs and tendrils). Variation per object through `f.variant`.
Sources read: NASA TRAPPIST-1 page, plus Wikipedia on PSR B1257+12, Kepler-47, HR 8799, Gaia BH1, O'Neill cylinder, Bishop Ring and Interstellar.

## 2026-11-06 (late): big stories, and the screenshot's transition bugs
User's screenshot showed a moon close-up shrinking with straight cut edges on its planet, and a ghost of that planet behind it. Plate sprites now fade to round (`destination-in` in `plateDisc`), and `s.hideParent` hides the parent world until hand-over.
Stories: `civHistory` has arcs from its own stream `q3`: war (truce 72%, ruin 18%, escalates to self-destruction 10%), ascend (swarm, then worlds taken apart outermost first, then the star enclosed; a Dyson-style idea) and destroy (flash, shockwave, shattered peopled worlds). `drawStory` draws them, `applyCiv` applies them. Odds by simulation over 3,000 civilisations at 365 days: 0.57 wars, 9% transcended, 6.5% destroyed; at 1,000 days 1.5 wars, 23%, 15%. Both endings are permanent for that civilisation. `orrery.story(kind, minutes)` and the Make history menu start one on purpose; those are saved per display as `story` in `civ.<id>` and replay at load. Testing: export and restore `defaults` when pressing real menu items in living mode.

## 2026-11-07: Orrery 0.4.0 released
Published at the user's request: all of the above, with the black hole icon. Not tested on another Mac: the Open Anyway steps, or a machine without these settings.

## 2026-11-06: site build tool
`tools/make_site_orrery.py` + `tools/site_layer.js` generate the website's `orrery.js` from this `index.html`: monochrome, one universe across all pages, each page a world. It patches exact strings and stops with an error if one no longer matches, so re-run it after engine changes and fix what it names. This replaces the old hand-patched copy described above.

## 2026-11-07: Explore (released in 0.5.0)
User's request after looking at 0010's vigil: make each system collectable and touchable, in the app first. The wallpaper sits below the desktop icons with `ignoresMouseEvents`, so this lives in its own window: menu bar → "Explore this system…" (`index.html?explore=1`).
Panel: seed box, five traits with their shares (a click opens another system with that trait), "about 1 in N" (simple product of the shares, assumes they're independent), the civilisation lines, New system, Home view, Wander, Save still (to Pictures/Orrery), Use as wallpaper, zoom buttons and a keyboard-friendly list of places. Canvas: hover ring and name, click selects with a card (Zoom in, Send a ship), double-click zooms, wheel moves through the scales, Esc goes back. Ships are the visitor's own (`exp.flights`), not part of the deterministic history, and go when the system changes.
`TRAITS` is a table sampled from 400 seeds by `tools/sample_traits.py` (system, base and culture use exact odds, surface and size are sampled, so about +/-3 points). Re-sample if the rolls change. Size differs on some seeds on portrait screens; Explore is landscape, so it's accurate there, and a few of those seeds could show otherwise at unusual shapes.
Verified: real-time Chrome run on 1280x800 with no page errors: hover, click, card, ship left and reached, zoom in and back, wheel to level 2 and back, trait click, typed seed, new seed, home view. The real app window opened and drew through `ORRERY_EXPLORE_SHOT`, no page errors logged. Not verified by hand: real mouse and trackpad scrolling in the app window, Save still and Use as wallpaper in the app (their messages compile but weren't pressed).


## 2026-11-07: event log, event zoom, clickable wallpaper (released in 0.5.1)
User's requests: civilisation updates should zoom to the event with a small log at the bottom right; and clicks "don't work" in the app after 0.5.0.
Log and zoom (`followEvents`, wallpaper only, stripped from the website): new events go into a five-line log; if the event has a place (`eventPlace`), the camera goes there, holds 18 s and returns, at most one trip per 30 s, big events taking priority; `reach` events go out to that scale; contact and stranger are log-only. Settings has a checkbox each.
Clicks: real mouse events through the real Explore window selected worlds correctly, so what the user hit wasn't reproduced; the cause isn't proven. Two likely causes fixed: Explore now makes the app a regular foreground app while open and answers the first click (`ExploreWebView`), and the wallpaper is now clickable through a global mouse monitor that checks the click landed on the bare desktop (`isBareDesktop`, `desktopClick`, `orrery.clickAt`): click a place to visit it, click again or mid-journey to return to the chart. Each click is logged with NSLog ("desktop click").
Not verified: the global monitor with a real hardware click, whether macOS asks for permission, spanned displays, Explore with a real pointer (`ORRERY_WALL_TEST` and `ORRERY_EXPLORE_SHOT` send events from inside the app).
The user then tried the installed build and reported the clicks work and everything is perfect ("the explore is so fun"). They didn't say whether they tested the wallpaper clicks or Explore separately. Not tested: another Mac, spanned displays.

## 2026-11-07: lock screen picture (released in 0.5.2)
The user wants the orrery on the lock screen. Public APIs can't draw a live window there, so `refreshLockImage` saves each display's chart as a JPEG in Application Support/Orrery/LockScreen and sets it as the desktop picture every 5 minutes and on `com.apple.screenIsLocked`; macOS shows the desktop picture on the lock screen. A new file name each time, since macOS won't reload an unchanged path. Setting "Show on the lock screen", default off because it changes the desktop picture; turned on for this user. The original path is kept in `lockOriginal.<display>` and restored when it's turned off or on Quit from the menu.
A live version would need private SkyLight calls, which could break with any macOS update; not attempted. Not verified at build time: the lock screen itself (can't lock the user's Mac from here), other Spaces (only the current Space's picture changes).
The user locked their Mac and confirmed it works on the lock screen. Not tested: another Mac, several Spaces, several displays.

## 2026-11-07: lid stop and pixel stories (installed for the user, not released or committed)
User's requests: stop the desktop orrery whenever the lid is closed, to save power; make events more dynamic, e.g. a dismantled sun or destroyed world pixelates and floats away.
Lid: the app only paused on sleep notifications, but this Mac reported `AppleClamshellCausesSleep = No` (no external display, a `caffeinate` assertion present at the time; cause not established), so a closed lid may not mean sleep. `watchLid` now reads `AppleClamshellState` from IOPMrootDomain and listens for changes; `lidMoved` pauses and stops the sound listener, and the lock picture timer skips. Menu bar: "Stop when the lid is closed", on by default. It also stops with the lid closed on an external display; that's what the toggle is for.
Pieces (`crumble`, `crumbleTick`, `crumbleStart`, `crumbleCells`, `crumblePieces`, `drawCrumbleChart`, `drawCrumbleClose`, SITE-SKIP): the subject is copied into a small canvas (no readback), then each pixel is drawn as a block with `drawImage`. Modes: `dismantle` (peels from the side facing the star, carried towards it), `destroy` (blast from one side, flash; home goes first and sisters follow), `sun` (outside in), `drift` (worlds after the sun), `impact` (comet: crater and spray, world survives). A piece is held up to 45 s if the camera is on its way (`crumbleWaiting`), so it happens in close-up; otherwise it plays on the chart. Timing uses `clock`, so a pause freezes it. A used close-up is thrown away on return to the chart.
New story `starlift`: the star shrinks and sheds pixels, then `final.kind === 'sunless'`: suns go, then worlds one by one. Natural odds about 0.005% per tick after day 45, stars only (no black hole or pulsar). Menu: Make history → "Let them take their sun apart"; a system with no plain star logs a line instead. This slightly changes some histories past day 45. `crumbles` is false on the website, where the story can't happen and `applyCiv` keeps the old behaviour (shared code now has square wreckage and a comet that flies in). Website `orrery.js` not regenerated; the generator was run on a throwaway copy and passes.
Comet events now go to the world actually named in the log, instead of a random one.
Testing: `orrery.setCiv` is needed in Chrome, or the age never advances. The wallpaper stops drawing while windows cover the desktop, so a story there doesn't progress in a test; `ORRERY_CRUMBLE_SHOT=<dir>` runs it in the Explore window instead. `ORRERY_LID_TEST` runs the lid path with the sensor's answer stood in. Export and restore `defaults` around any story test.
Verified: real-time Chrome: destroy (close-up with camera), dismantle and sun (chart), comet (close-up), no page errors. App's WebKit: sun in close-up and worlds on the chart, frames viewed, `quality` stayed 1. Lid path in the app: paused 0, 1, 0 and the log lines fired, with the sensor stood in.
Not verified: a real lid closing (user to try); destroy, dismantle and comet in WebKit (same drawing calls as the sun); CPU during pieces on an uncovered desktop; pieces watched by eye in motion at normal speed; Undo ("clear") after a sunless ending; reduced motion.

## 2026-11-07: stipple, and a private build option
User's request: stipple rather than blocks in the story effects; some additions for their own Mac only.
Stipple: `crumbleCells` now makes grains (10,000 up close, up to 3,600 on the chart), each coloured from a small copy read once with `getImageData`, grouped by colour and drawn in batches; they shrink rather than fade. `crumbleErode` eats the surface in a persistent `e.mask` canvas with one blot per grain, so its cost isn't per-frame. Wreckage and comet spray are round grain again.
Private build: `mac/scripts/build.sh --mine` inlines `local/setups.js` (git-ignored; never in the repo or a release) as `window.ORRERY_LOCAL`. The engine only has generic hooks: `apply`, `s.setup.history`, `under`, `over`, `goneBy`, `sun.veiled`. **Release only from a plain `build.sh`**; check `grep -c 'ORRERY_LOCAL = ' mac/build/Orrery.app/Contents/Resources/orrery.html` prints 0. `/Applications/Orrery.app` on this Mac is a private build, so never zip that.
Verified: Chrome: destroy close-up and chart, no page errors; each private setup viewed as a still. App's WebKit: sun close-up in stipple, 63 colour groups, quality stayed 1, frames viewed; a plain build has no private code. One WebKit test run ignored its scripted calls (the page stayed on its first seed) and the next, with logging added, worked; cause not found.
Not verified: stipple motion by eye, CPU on an uncovered desktop, setups' stories playing out live, real lid.

## 2026-11-07: Orrery 0.6.0 released
Published at the user's request from a plain `build.sh`: lid stop, stipple stories, the star-taking story and comet strikes. Checked before upload: the build holds no `ORRERY_LOCAL` code. Not tested on another Mac; a real lid closing wasn't tested before release.
