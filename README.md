# Alien Orrery

Charts of imagined solar systems, as the civilisations living in them might draw them. A live macOS desktop
wallpaper and a single web page, with nothing to install for the web version and no libraries.

Each civilisation has its own suns, worlds, colours and invented script. It changes over real days and weeks:
gates open, sister worlds are settled, shipping lanes reach further out, and some civilisations decline, fall silent
and sometimes return. The view drifts from the home world out to the supercluster and back.

## Mac app

Download `Orrery` from [Releases](../../releases). It's for Apple Silicon Macs on macOS 14 or later.

The app isn't signed by Apple, so macOS will stop it the first time. Open it once, then go to
**System Settings > Privacy & Security** and choose **Open Anyway**.

It lives in the menu bar and draws behind your desktop icons. From the menu you can read the civilisation's chronicle,
discover another, save favourites, change the view and colours, zoom to a star, moon, gate, wormhole, space station,
occupied asteroid or black hole, make it react to sound, and save images and videos.
By default it pauses on battery and in Low Power Mode; untick **Pause on battery** to keep it moving.

Rough cost on an M1 Pro at 3600 x 2338: 13 to 47% of one CPU core when moving, about 0.1% when paused, and
330 to 730 MB of memory.

Reacting to sound is off until you choose it. It asks macOS for microphone or screen and system audio permission, and only
measures loudness. Nothing is recorded or sent anywhere.

## Web page

Open `index.html` in a browser. `index.html#42` always shows chart 42 at the same window size.

## Building the app

Needs the Xcode command line tools.

```sh
cd mac
./scripts/build.sh            # makes build/Orrery.app
./scripts/build.sh --install  # also copies it to /Applications and opens it
```

## How it works

- Dust is placed in time using Kepler's equation, so it gathers where orbits run slowest. Worlds sit in whole-number
  period ratios, and orbit sizes follow Kepler's third law. Rings look off-centre because the suns sit at a focus of each ellipse.
- Home view measures everything from the home world, so the suns circle it and other worlds trace rosettes.
- A civilisation's history replays from its seed and age, so it carries on correctly even after the Mac has been off.
- The script is invented and has no meaning. The app's menu has plain-language translations of the chronicle.

The first idea came from looking at generative work by [@0010_888](https://x.com/0010_888) (grain, arcs and flat discs).
This is an original system, with its own concept, code and palettes.

## Licence

MIT. See [LICENSE](LICENSE).
