import AppKit
import AVFoundation
import CoreMedia
import IOKit.ps
import ScreenCaptureKit
import ServiceManagement
import WebKit

// Orrery: the full alien orrery as a live desktop wallpaper. One borderless window per display, at desktop
// level (below the icons). The drawing and the civilisations live in ../index.html; this app owns the
// windows, the menu, the settings, sound input and the rules for when to pause.

private enum Key {
    static let mode = "mode", view = "view", palette = "palette", zoom = "zoom", change = "changeSeconds"
    static let pauseOnBattery = "pauseOnBattery", paused = "paused", favourites = "favourites"
    static let jMin = "journeyMin", jMax = "journeyMax", pMin = "pauseMin", pMax = "pauseMax"
    static let speed = "orbitSpeed", rate = "historyRate", dust = "dust", chronicle = "chronicle"
    static let realTime = "realTime", span = "span", sound = "sound", eventLog = "eventLog", zoomEvents = "zoomEvents", clickWall = "clickWallpaper"
    static let useCustom = "useCustom", cPaper = "customPaper", cInk = "customInk", cInk2 = "customInk2", cAccent = "customAccent"
}

struct Target {
    let frame: CGRect
    let id: String
    var span: (CGFloat, CGFloat, CGFloat, CGFloat)?
}

/// Answers the first click even if the window wasn't in front.
final class ExploreWebView: WKWebView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class Wallpaper: NSObject, WKNavigationDelegate {
    let window: NSWindow
    let web: WKWebView
    let id: String
    var loaded = false
    var onLoad: (() -> Void)?
    var civ: [String: Any] = [:]

    init(target: Target, html: URL, query: [URLQueryItem], handler: WKScriptMessageHandler, debug: Bool) {
        id = target.id
        window = NSWindow(contentRect: target.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.setFrame(target.frame, display: false)
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true
        window.isOpaque = true
        window.hasShadow = false
        window.backgroundColor = .black
        window.isReleasedWhenClosed = false
        window.title = "Orrery wallpaper"

        let config = WKWebViewConfiguration()
        config.userContentController.add(handler, name: "app")
        if debug {
            let script = """
            addEventListener('error', e => webkit.messageHandlers.log.postMessage('error: ' + e.message + ' line ' + e.lineno));
            addEventListener('unhandledrejection', e => webkit.messageHandlers.log.postMessage('rejection: ' + e.reason));
            """
            config.userContentController.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
            config.userContentController.add(handler, name: "log")
        }
        web = WKWebView(frame: CGRect(origin: .zero, size: target.frame.size), configuration: config)
        web.autoresizingMask = [.width, .height]
        super.init()
        web.navigationDelegate = self
        window.contentView = web

        var parts = URLComponents(url: html, resolvingAgainstBaseURL: false)!
        var items = query
        items.append(URLQueryItem(name: "wallpaper", value: "1"))
        if let s = target.span { items.append(URLQueryItem(name: "span", value: "\(s.0),\(s.1),\(s.2),\(s.3)")) }
        parts.queryItems = items
        web.loadFileURL(parts.url!, allowingReadAccessTo: html.deletingLastPathComponent())
        window.orderBack(nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loaded = true
        onLoad?()
    }

    func run(_ js: String, then done: ((Any?) -> Void)? = nil) {
        guard loaded else { return }
        web.evaluateJavaScript(js) { value, error in
            if let error { NSLog("Orrery JS error: \(error)") }
            done?(value)
        }
    }

    func close() {
        web.stopLoading()
        web.configuration.userContentController.removeAllScriptMessageHandlers()
        window.orderOut(nil)
        window.close()
    }
}

// MARK: - Sound

/// Measures loudness and bass, either from what the Mac is playing or from an input. Nothing is stored.
final class SoundListener: NSObject, SCStreamOutput, SCStreamDelegate {
    var onLevels: ((Float, Float) -> Void)?
    var onProblem: ((String) -> Void)?
    private var stream: SCStream?
    private var engine: AVAudioEngine?
    private let queue = DispatchQueue(label: "orrery.sound")
    private var low: Float = 0
    private var lastSent = Date.distantPast

    func stop() {
        stream?.stopCapture { _ in }
        stream = nil
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
    }

    private func measure(_ samples: UnsafeBufferPointer<Float>, rate: Double) {
        guard !samples.isEmpty else { return }
        let cut = Float(1 - exp(-2 * Double.pi * 150 / max(rate, 8000)))
        var sum: Float = 0, bassSum: Float = 0
        for x in samples {
            low += (x - low) * cut
            sum += x * x
            bassSum += low * low
        }
        let n = Float(samples.count)
        let level = min(1, sqrt(sum / n) * 3.2), bass = min(1, sqrt(bassSum / n) * 5.5)
        let now = Date()
        if now.timeIntervalSince(lastSent) < 0.05 { return }
        lastSent = now
        DispatchQueue.main.async { self.onLevels?(level, bass) }
    }

    func startMicrophone() {
        stop()
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                guard granted else { self.onProblem?("Microphone access was refused in System Settings."); return }
                let engine = AVAudioEngine()
                let input = engine.inputNode
                let format = input.outputFormat(forBus: 0)
                guard format.sampleRate > 0 else { self.onProblem?("No audio input found."); return }
                input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
                    guard let self, let data = buffer.floatChannelData?[0] else { return }
                    self.measure(UnsafeBufferPointer(start: data, count: Int(buffer.frameLength)), rate: format.sampleRate)
                }
                do { try engine.start(); self.engine = engine }
                catch { self.onProblem?("Couldn't start the input: \(error.localizedDescription)") }
            }
        }
    }

    func startSystemAudio() {
        stop()
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { content, error in
            guard let display = content?.displays.first else {
                DispatchQueue.main.async {
                    self.onProblem?("macOS needs Screen & System Audio Recording turned on for Orrery. Only sound levels are used.")
                }
                return
            }
            let config = SCStreamConfiguration()
            config.capturesAudio = true
            config.excludesCurrentProcessAudio = true
            config.width = 2
            config.height = 2
            config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let stream = SCStream(filter: filter, configuration: config, delegate: self)
            do {
                try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: self.queue)
                stream.startCapture { error in
                    if let error { DispatchQueue.main.async { self.onProblem?("Couldn't listen to Mac audio: \(error.localizedDescription)") } }
                }
                self.stream = stream
            } catch {
                DispatchQueue.main.async { self.onProblem?("Couldn't listen to Mac audio: \(error.localizedDescription)") }
            }
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, let format = sampleBuffer.formatDescription?.audioStreamBasicDescription else { return }
        try? sampleBuffer.withAudioBufferList { list, _ in
            guard let first = list.first, let raw = first.mData else { return }
            let count = Int(first.mDataByteSize) / MemoryLayout<Float>.size
            let samples = UnsafeBufferPointer(start: raw.assumingMemoryBound(to: Float.self), count: count)
            self.measure(samples, rate: format.mSampleRate)
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { self.onProblem?("Listening stopped: \(error.localizedDescription)") }
    }
}

// MARK: - App

final class App: NSObject, NSApplicationDelegate, NSMenuDelegate, WKScriptMessageHandler {
    private var walls: [Wallpaper] = []
    private var item: NSStatusItem!
    private let defaults = UserDefaults.standard
    private var html: URL!
    private var powerSource: CFRunLoopSource?
    private var asleep = false
    private let listener = SoundListener()
    private var soundNote: String?
    private var settingsWindow: NSWindow?
    private var exploreWindow: NSWindow?
    private var exploreWeb: WKWebView?
    private var spanTimer: Timer?

    private let palettes: [(String, String)] = [
        ("verdigris", "Verdigris"), ("ultramarine", "Ultramarine"), ("amethyst", "Amethyst"), ("lichen", "Lichen"),
        ("gill", "Gill"), ("sulphur", "Sulphur"), ("ember", "Ember"), ("tide", "Tide"), ("bone", "Bone"), ("moss", "Moss"),
        ("rose", "Rose"), ("sand", "Sand"), ("carbon", "Carbon"), ("nacre", "Nacre"), ("forest", "Forest"), ("dusk", "Dusk"),
        ("site", "White, green and red"),
    ]
    private let changes: [(Int, String)] = [
        (60, "Every minute"), (300, "Every 5 minutes"), (900, "Every 15 minutes"), (3600, "Every hour"),
    ]

    func applicationDidFinishLaunching(_ note: Notification) {
        defaults.register(defaults: [
            Key.mode: "living", Key.view: "random", Key.palette: "", Key.zoom: true, Key.change: 300,
            Key.pauseOnBattery: true, Key.paused: false,
            Key.jMin: 8.0, Key.jMax: 15.0, Key.pMin: 8.0, Key.pMax: 18.0, Key.speed: 1.0, Key.rate: 1.0, Key.dust: 1.0,
            Key.chronicle: true, Key.eventLog: true, Key.zoomEvents: true, Key.clickWall: true, Key.realTime: true, Key.span: false, Key.sound: "off", Key.useCustom: false,
            Key.cPaper: "#101418", Key.cInk: "#f2efe0", Key.cInk2: "#6f8df0", Key.cAccent: "#ff5c38",
        ])
        NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.desktopClick(at: NSEvent.mouseLocation, clicks: event.clickCount)
        }
        html = Bundle.main.url(forResource: "orrery", withExtension: "html")
        guard html != nil else { NSLog("Orrery: orrery.html is missing from the app"); NSApp.terminate(nil); return }

        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "circle.circle", accessibilityDescription: "Orrery")
            button.toolTip = "Orrery wallpaper"
        }
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu

        listener.onLevels = { [weak self] level, bass in
            self?.toAll(String(format: "orrery.setAudio(%.3f,%.3f)", level, bass))
        }
        listener.onProblem = { [weak self] message in self?.soundNote = message }
        applySound()

        rebuildWalls()

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        center.addObserver(self, selector: #selector(applyPause), name: .NSProcessInfoPowerStateDidChange, object: nil)
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            workspace.addObserver(self, selector: #selector(wentAway), name: name, object: nil)
        }
        for name in [NSWorkspace.screensDidWakeNotification, NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            workspace.addObserver(self, selector: #selector(cameBack), name: name, object: nil)
        }
        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            Unmanaged<App>.fromOpaque(ctx).takeUnretainedValue().applyPause()
        }, context)?.takeRetainedValue() {
            powerSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        startDebugHooks()
    }

    // MARK: Windows

    private var isSpanning: Bool { defaults.bool(forKey: Key.span) }
    private var isLiving: Bool { defaults.string(forKey: Key.mode) == "living" }

    private func targets() -> [Target] {
        var list: [Target]
        if ProcessInfo.processInfo.environment["ORRERY_FAKE_SPLIT"] != nil, let main = NSScreen.main {
            // Testing a second display on a Mac with one: two windows, each half of the screen.
            let f = main.frame
            list = [
                Target(frame: CGRect(x: f.minX, y: f.minY, width: f.width / 2, height: f.height), id: "left"),
                Target(frame: CGRect(x: f.midX, y: f.minY, width: f.width / 2, height: f.height), id: "right"),
            ]
        } else {
            list = NSScreen.screens.map { screen in
                let n = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
                return Target(frame: screen.frame, id: String(n))
            }
        }
        if isSpanning && list.count > 1 {
            let all = list.reduce(CGRect.null) { $0.union($1.frame) }
            list = list.map { t in
                var t = t
                t.span = (t.frame.minX - all.minX, all.maxY - t.frame.maxY, all.width, all.height)
                return t
            }
        }
        return list
    }

    private func civ(for id: String) -> (seed: Int, founded: Double?) {
        let key = "civ.\(id)"
        if isLiving, let saved = defaults.dictionary(forKey: key), let seed = saved["seed"] as? Int {
            return (seed, saved["founded"] as? Double)
        }
        let seed = Int.random(in: 1...99998)
        guard isLiving else { return (seed, nil) }
        // The first civilisation you meet has already been going for a month or two.
        let founded = Date().timeIntervalSince1970 * 1000 - Double.random(in: 30...60) * 86_400_000
        defaults.set(["seed": seed, "founded": founded], forKey: key)
        return (seed, founded)
    }

    private func query(id: String, shared: (Int, Double?)?) -> [URLQueryItem] {
        let c = shared ?? civ(for: id)
        var items = [URLQueryItem(name: "seed", value: String(c.0))]
        if let f = c.1 { items.append(URLQueryItem(name: "founded", value: String(f))) }
        if isLiving, let story = defaults.dictionary(forKey: "civ.\(id)")?["story"] as? [[String: Any]], !story.isEmpty,
           JSONSerialization.isValidJSONObject(story), let data = try? JSONSerialization.data(withJSONObject: story),
           let text = String(data: data, encoding: .utf8) {
            items.append(URLQueryItem(name: "story", value: text))
        }
        let dust = defaults.double(forKey: Key.dust)
        if dust != 1 { items.append(URLQueryItem(name: "dust", value: String(dust))) }
        if defaults.bool(forKey: Key.useCustom) {
            for (name, key) in [("paper", Key.cPaper), ("ink", Key.cInk), ("ink2", Key.cInk2), ("accent", Key.cAccent)] {
                items.append(URLQueryItem(name: name, value: defaults.string(forKey: key)))
            }
        } else if let p = defaults.string(forKey: Key.palette), !p.isEmpty {
            items.append(URLQueryItem(name: "palette", value: p))
        }
        return items
    }

    private func rebuildWalls() {
        walls.forEach { $0.close() }
        spanTimer?.invalidate()
        let debugging = ProcessInfo.processInfo.environment["ORRERY_DEBUG"] != nil
        let list = targets()
        // Spanning shows one system on every display, so they all share the first display's civilisation.
        let shared = list.first?.span != nil ? civ(for: list[0].id) : nil
        walls = list.map { target in
            let wall = Wallpaper(target: target, html: html, query: query(id: target.id, shared: shared), handler: self, debug: debugging)
            wall.onLoad = { [weak self, weak wall] in
                guard let self, let wall else { return }
                self.applySettings(to: wall)
            }
            return wall
        }
        if shared != nil && !isLiving {
            spanTimer = Timer.scheduledTimer(withTimeInterval: Double(max(60, defaults.integer(forKey: Key.change))), repeats: true) { [weak self] _ in
                let seed = Int.random(in: 1...99998)
                self?.toAll("orrery.load(\(seed), null)")
            }
        }
    }

    private func applySettings(to wall: Wallpaper) {
        wall.run("orrery.setView('\(defaults.string(forKey: Key.view) ?? "random")')")
        let spanning = isSpanning && walls.count > 1
        wall.run("orrery.setZoom(\(defaults.bool(forKey: Key.zoom) && !spanning))")
        wall.run("orrery.setChange(\(isLiving || spanning ? 0 : defaults.integer(forKey: Key.change)))")
        applyTiming(wall)
        wall.run("orrery.setChronicle(\(defaults.bool(forKey: Key.chronicle)))")
        wall.run("orrery.setEventLog(\(defaults.bool(forKey: Key.eventLog)))")
        wall.run("orrery.setZoomToEvents(\(defaults.bool(forKey: Key.zoomEvents)))")
        wall.run("orrery.setRealTime(\(defaults.bool(forKey: Key.realTime)))")
        wall.run("orrery.setRate(\(defaults.double(forKey: Key.rate)))")
        wall.run("orrery.setPaused(\(shouldPause))")
        wall.run("orrery.report()")
    }

    private func applyTiming(_ wall: Wallpaper) {
        let jMin = defaults.double(forKey: Key.jMin), pMin = defaults.double(forKey: Key.pMin)
        let jMax = max(jMin, defaults.double(forKey: Key.jMax)), pMax = max(pMin, defaults.double(forKey: Key.pMax))
        wall.run("orrery.setTiming(\(jMin),\(jMax),\(pMin),\(pMax)); orrery.setSpeed(\(defaults.double(forKey: Key.speed)))")
    }

    private func toAll(_ js: String) { walls.forEach { $0.run(js) } }
    /// For anything that rebuilds a picture: one display after another, so they don't all start at once.
    private func toAllInTurn(_ js: String) {
        for (index, wall) in walls.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 * Double(index)) { wall.run(js) }
        }
    }

    private func applySound() {
        switch defaults.string(forKey: Key.sound) {
        case "system": soundNote = nil; listener.startSystemAudio()
        case "mic": soundNote = nil; listener.startMicrophone()
        default: soundNote = nil; listener.stop()
        }
    }

    // MARK: Pausing

    private var onBattery: Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() else { return false }
        return (type as String) == kIOPSBatteryPowerValue
    }

    private var shouldPause: Bool {
        if asleep || defaults.bool(forKey: Key.paused) { return true }
        if ProcessInfo.processInfo.isLowPowerModeEnabled { return true }
        return defaults.bool(forKey: Key.pauseOnBattery) && onBattery
    }

    @objc func applyPause() {
        DispatchQueue.main.async { self.toAll("orrery.setPaused(\(self.shouldPause))") }
    }
    @objc private func wentAway() { asleep = true; applyPause() }
    @objc private func cameBack() { asleep = false; applyPause() }
    @objc private func screensChanged() {
        let now = targets().map { "\($0.frame)" }.sorted()
        let was = walls.map { "\($0.window.frame)" }.sorted()
        if now != was { rebuildWalls() }
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let info = walls.first?.civ ?? [:]
        let people = info["people"] as? String ?? "Orrery"
        let age = Int(info["age"] as? Double ?? 0)
        let status = (info["status"] as? String ?? "rising").capitalized
        menu.addItem(note("\(people) · day \(age) · \(status)"))
        if let type = info["systemType"] as? String { menu.addItem(note(type.capitalized)) }
        if let home = info["home"] as? String, let surface = info["surface"] as? String {
            menu.addItem(note("Home world \(home): \(surface)"))
        }
        let chronicle = NSMenuItem(title: "Chronicle", action: nil, keyEquivalent: "")
        let list = NSMenu()
        let events = info["events"] as? [[String: Any]] ?? []
        for e in events {
            let day = Int(e["d"] as? Double ?? 0)
            list.addItem(note("Day \(day): \(e["text"] as? String ?? "")"))
        }
        if events.isEmpty { list.addItem(note("Nothing recorded yet")) }
        chronicle.submenu = list
        menu.addItem(chronicle)
        menu.addItem(.separator())

        let zoomTo = NSMenuItem(title: "Zoom to", action: nil, keyEquivalent: "")
        let places = NSMenu()
        places.autoenablesItems = false
        // Only what's on screen somewhere right now can be reached; the rest is greyed out.
        let reachable = Set(walls.flatMap { $0.civ["places"] as? [String] ?? [] })
        for (kind, label) in [("home", "Home world"), ("sister", "A sister world"), ("colonised", "A colonised moon"), ("moon", "A moon"), ("star", "A star"), ("pulsar", "A pulsar"), ("gate", "A ring gate"), ("wormhole", "A wormhole"), ("station", "A space station"), ("asteroid", "An occupied asteroid"), ("blackhole", "A black hole")] {
            let item = action(label, #selector(visit))
            item.representedObject = kind
            item.isEnabled = !shouldPause && reachable.contains(kind)
            places.addItem(item)
        }
        places.addItem(.separator())
        let back = action("Back to the chart", #selector(backToChart))
        back.isEnabled = !shouldPause
        places.addItem(back)
        if shouldPause { places.addItem(note("Paused: resume to zoom")) }
        zoomTo.submenu = places
        menu.addItem(zoomTo)
        menu.addItem(.separator())
        let history = NSMenuItem(title: "Make history", action: nil, keyEquivalent: "")
        let stories = NSMenu()
        for (kind, label, minutes) in [("war", "Start a war", 6), ("ascend", "Let them transcend", 12), ("destroy", "Let them destroy themselves", 3)] {
            let item = action(label, #selector(makeHistory))
            item.representedObject = "\(kind):\(minutes)"
            stories.addItem(item)
        }
        stories.addItem(.separator())
        let undo = action("Undo what you started", #selector(makeHistory))
        undo.representedObject = "clear:0"
        stories.addItem(undo)
        history.submenu = stories
        menu.addItem(history)
        menu.addItem(.separator())
        menu.addItem(action("Explore this system…", #selector(openExplore), key: "e"))
        menu.addItem(.separator())
        menu.addItem(action("Discover another civilisation", #selector(discover), key: "n"))
        menu.addItem(action("Found a new one from nothing", #selector(foundNew)))
        menu.addItem(favouritesItem())
        let mode = defaults.string(forKey: Key.mode) ?? "living"
        let change = String(defaults.integer(forKey: Key.change))
        let selected = mode == "living" ? "stay" : change
        menu.addItem(submenu("Follow", [("stay", "Stay with this civilisation")] + changes.map { (String($0.0), "Tour: \($0.1.lowercased())") }, selected: selected, #selector(pickFollow)))
        menu.addItem(.separator())

        let view = defaults.string(forKey: Key.view) ?? "random"
        menu.addItem(submenu("View", [("random", "Random"), ("star", "Star view"), ("home", "Home view")], selected: view, #selector(pickView)))
        let palette = defaults.bool(forKey: Key.useCustom) ? "custom" : (defaults.string(forKey: Key.palette) ?? "")
        menu.addItem(submenu("Colours", [("", "Random")] + palettes + [("custom", "Custom (set in Settings)")], selected: palette, #selector(pickPalette)))
        let sound = defaults.string(forKey: Key.sound) ?? "off"
        menu.addItem(submenu("React to sound", [("off", "Off"), ("system", "What the Mac is playing"), ("mic", "Microphone or audio input")], selected: sound, #selector(pickSound)))
        if let soundNote { menu.addItem(note(soundNote)) }
        let zoom = action("Random zoom", #selector(toggleZoom))
        zoom.state = defaults.bool(forKey: Key.zoom) ? .on : .off
        menu.addItem(zoom)
        menu.addItem(action("Settings…", #selector(openSettings), key: ","))
        menu.addItem(.separator())

        menu.addItem(action(defaults.bool(forKey: Key.paused) ? "Resume" : "Pause", #selector(togglePause), key: "p"))
        let battery = action("Pause on battery", #selector(toggleBattery))
        battery.state = defaults.bool(forKey: Key.pauseOnBattery) ? .on : .off
        menu.addItem(battery)
        if shouldPause && !defaults.bool(forKey: Key.paused) {
            menu.addItem(note(ProcessInfo.processInfo.isLowPowerModeEnabled ? "Paused: Low Power Mode is on" : "Paused: on battery"))
        }
        menu.addItem(.separator())

        menu.addItem(action("Save image to Pictures", #selector(saveImage), key: "s"))
        menu.addItem(action("Save a 20-second video to Movies", #selector(saveVideo)))
        let login = action("Open at login", #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(action("Quit Orrery", #selector(quit), key: "q"))
    }

    private func note(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func action(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        return item
    }

    private func submenu(_ title: String, _ options: [(String, String)], selected: String, _ selector: Selector) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for (value, label) in options {
            let item = action(label, selector)
            item.representedObject = value
            item.state = value == selected ? .on : .off
            sub.addItem(item)
        }
        parent.submenu = sub
        return parent
    }

    private func favouritesItem() -> NSMenuItem {
        let parent = NSMenuItem(title: "Favourites", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        sub.addItem(action("Add this civilisation", #selector(addFavourite), key: "d"))
        let saved = defaults.array(forKey: Key.favourites) as? [[String: Any]] ?? []
        if !saved.isEmpty { sub.addItem(.separator()) }
        for (index, f) in saved.enumerated() {
            let item = action(f["name"] as? String ?? "Unnamed", #selector(openFavourite))
            item.tag = index
            sub.addItem(item)
        }
        parent.submenu = sub
        return parent
    }

    private func nowMs() -> Double { Date().timeIntervalSince1970 * 1000 }

    private func load(seed: Int, founded: Double?) {
        // Each display gets its own civilisation unless they're spanned.
        if isSpanning && walls.count > 1 {
            toAll("orrery.load(\(seed), \(founded.map { String($0) } ?? "null"))")
            if let first = walls.first, isLiving { remember(first, seed: seed, founded: founded) }
            return
        }
        for (index, wall) in walls.enumerated() {
            let s = index == 0 ? seed : Int.random(in: 1...99998)
            let f = founded.map { index == 0 ? $0 : nowMs() - Double.random(in: 30...60) * 86_400_000 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 * Double(index)) { wall.run("orrery.load(\(s), \(f.map { String($0) } ?? "null"))") }
            if isLiving { remember(wall, seed: s, founded: f) }
        }
    }

    private func remember(_ wall: Wallpaper, seed: Int, founded: Double?) {
        var d: [String: Any] = ["seed": seed]
        if let founded { d["founded"] = founded }
        defaults.set(d, forKey: "civ.\(wall.id)")
    }

    @objc private func visit(_ sender: NSMenuItem) {
        // Each display goes if it has one; a system without a black hole simply stays put.
        toAll("orrery.visit('\(sender.representedObject as? String ?? "home")')")
    }
    @objc private func makeHistory(_ sender: NSMenuItem) {
        let parts = (sender.representedObject as? String ?? "").split(separator: ":")
        guard parts.count == 2 else { return }
        toAll("orrery.story('\(parts[0])', \(parts[1]))")
    }
    @objc private func backToChart() { toAll("orrery.chart()") }
    @objc private func discover() {
        load(seed: Int.random(in: 1...99998), founded: isLiving ? nowMs() - Double.random(in: 30...90) * 86_400_000 : nil)
    }
    @objc private func foundNew() {
        load(seed: Int.random(in: 1...99998), founded: nowMs())
    }
    @objc private func addFavourite() {
        guard let info = walls.first?.civ, let seed = info["seed"] as? Int else { return }
        let age = info["age"] as? Double ?? 0
        let rate = max(1, defaults.double(forKey: Key.rate))
        let founded = info["founded"] as? Double ?? (nowMs() - age / rate * 86_400_000)
        var saved = defaults.array(forKey: Key.favourites) as? [[String: Any]] ?? []
        if saved.contains(where: { $0["seed"] as? Int == seed }) { return }
        saved.append(["name": info["people"] as? String ?? "Unnamed", "seed": seed, "founded": founded])
        defaults.set(saved, forKey: Key.favourites)
    }
    @objc private func openFavourite(_ sender: NSMenuItem) {
        let saved = defaults.array(forKey: Key.favourites) as? [[String: Any]] ?? []
        guard sender.tag < saved.count, let seed = saved[sender.tag]["seed"] as? Int else { return }
        defaults.set("living", forKey: Key.mode)
        toAll("orrery.setChange(0)")
        load(seed: seed, founded: saved[sender.tag]["founded"] as? Double)
    }
    @objc private func pickFollow(_ sender: NSMenuItem) {
        let value = sender.representedObject as? String ?? "stay"
        if value == "stay" {
            defaults.set("living", forKey: Key.mode)
            toAll("orrery.setChange(0)")
            for wall in walls {
                guard let seed = wall.civ["seed"] as? Int else { continue }
                let age = wall.civ["age"] as? Double ?? 0
                let founded = wall.civ["founded"] as? Double ?? (nowMs() - age / max(1, defaults.double(forKey: Key.rate)) * 86_400_000)
                remember(wall, seed: seed, founded: founded)
                wall.run("orrery.setCiv(\(founded), \(defaults.double(forKey: Key.rate)))")
            }
        } else {
            let seconds = Int(value) ?? 300
            defaults.set("tour", forKey: Key.mode)
            defaults.set(seconds, forKey: Key.change)
            toAll("orrery.setChange(\(seconds))")
        }
    }
    @objc private func pickView(_ sender: NSMenuItem) {
        let value = sender.representedObject as? String ?? "random"
        defaults.set(value, forKey: Key.view)
        toAll("orrery.setView('\(value)')")
    }
    @objc private func pickPalette(_ sender: NSMenuItem) {
        let value = sender.representedObject as? String ?? ""
        if value == "custom" {
            defaults.set(true, forKey: Key.useCustom)
            applyCustom()
            return
        }
        defaults.set(false, forKey: Key.useCustom)
        defaults.set(value, forKey: Key.palette)
        toAll("orrery.setCustom(null)")
        toAllInTurn("orrery.setPalette(\(value.isEmpty ? "null" : "'\(value)'"))")
    }
    private func applyCustom() {
        func c(_ k: String) -> String { defaults.string(forKey: k) ?? "#000000" }
        toAllInTurn("orrery.setCustom('\(c(Key.cPaper))','\(c(Key.cInk))','\(c(Key.cInk2))','\(c(Key.cAccent))')")
    }
    @objc private func pickSound(_ sender: NSMenuItem) {
        defaults.set(sender.representedObject as? String ?? "off", forKey: Key.sound)
        applySound()
    }
    @objc private func toggleZoom() {
        let on = !defaults.bool(forKey: Key.zoom)
        defaults.set(on, forKey: Key.zoom)
        toAll("orrery.setZoom(\(on))")
    }
    @objc private func togglePause() {
        defaults.set(!defaults.bool(forKey: Key.paused), forKey: Key.paused)
        applyPause()
    }
    @objc private func toggleBattery() {
        defaults.set(!defaults.bool(forKey: Key.pauseOnBattery), forKey: Key.pauseOnBattery)
        applyPause()
    }
    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            NSLog("Orrery: open at login failed: \(error)")
        }
    }
    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: Saving

    @objc private func saveImage() {
        let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures/Orrery")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = Int(Date().timeIntervalSince1970)
        for (index, wall) in walls.enumerated() {
            snapshot(wall, to: folder.appendingPathComponent("orrery-\(stamp)-\(index + 1).png"))
        }
    }
    @objc private func saveVideo() {
        walls.first?.run("orrery.record(20)")
    }

    private func snapshot(_ wall: Wallpaper, to url: URL) {
        wall.web.takeSnapshot(with: nil) { image, error in
            guard let image, let tiff = image.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
                NSLog("Orrery: snapshot failed: \(String(describing: error))")
                return
            }
            try? png.write(to: url)
        }
    }

    // MARK: Messages from the page

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "log" { NSLog("Orrery page: \(message.body)"); return }
        guard let text = message.body as? String, let data = text.data(using: .utf8),
              let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        switch body["type"] as? String {
        case "civ":
            guard let wall = walls.first(where: { $0.web === message.webView }) else { return }
            wall.civ = body
            if isLiving, var saved = defaults.dictionary(forKey: "civ.\(wall.id)"), saved["seed"] as? Int == body["seed"] as? Int {
                saved["story"] = body["story"]
                defaults.set(saved, forKey: "civ.\(wall.id)")
            }
        case "still":
            guard let b64 = body["data"] as? String, let png = Data(base64Encoded: b64) else { return }
            let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures/Orrery")
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let file = folder.appendingPathComponent("orrery-\(body["seed"] as? Int ?? 0)-\(Int(Date().timeIntervalSince1970)).png")
            do { try png.write(to: file); NSWorkspace.shared.activateFileViewerSelecting([file]) }
            catch { NSLog("Orrery: could not save the still: \(error)") }
        case "useSeed":
            guard let seed = body["seed"] as? Int else { return }
            load(seed: seed, founded: isLiving ? (body["founded"] as? Double) : nil)
        case "video":
            guard let b64 = body["data"] as? String, let video = Data(base64Encoded: b64) else { return }
            let folder = videoFolder()
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent("orrery-\(Int(Date().timeIntervalSince1970)).\(body["ext"] as? String ?? "mp4")")
            try? video.write(to: url)
            NSLog("Orrery: saved video \(url.path)")
        default: break
        }
    }

    private func videoFolder() -> URL {
        if let d = ProcessInfo.processInfo.environment["ORRERY_DEBUG"] { return URL(fileURLWithPath: d) }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies/Orrery")
    }

    // MARK: Settings window

    /// True when nothing but the desktop is under this point (screen coordinates, origin bottom left).
    private func isBareDesktop(_ point: NSPoint) -> Bool {
        guard let main = NSScreen.screens.first else { return false }
        let flipped = CGPoint(x: point.x, y: main.frame.maxY - point.y)
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        for info in list {
            guard let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary), rect.contains(flipped) else { continue }
            if (info[kCGWindowAlpha as String] as? CGFloat ?? 1) <= 0.01 { continue }
            if (info[kCGWindowLayer as String] as? Int ?? 0) < 0 { continue }
            return false
        }
        return true
    }

    /// The wallpaper can't receive clicks, since Finder's desktop sits above it, so the app watches for ones that land on the bare desktop.
    private func desktopClick(at point: NSPoint, clicks: Int) {
        guard defaults.bool(forKey: Key.clickWall), !defaults.bool(forKey: Key.paused), isBareDesktop(point) else { return }
        guard let wall = walls.first(where: { $0.window.frame.contains(point) }) else { return }
        let x = point.x - wall.window.frame.minX, y = wall.window.frame.maxY - point.y
        wall.run("orrery.clickAt(\(x), \(y))") { value in NSLog("Orrery: desktop click at \(x),\(y): \(value ?? "nil")") }
    }

    /// The wallpaper sits below the desktop icons and can't be clicked, so touching a system happens in its own window.
    @objc private func openExplore() {
        if let open = exploreWindow {
            NSApp.activate(ignoringOtherApps: true)
            open.makeKeyAndOrderFront(nil)
            return
        }
        let info = walls.first?.civ ?? [:]
        var items = [URLQueryItem(name: "explore", value: "1")]
        if let seed = info["seed"] as? Int { items.append(URLQueryItem(name: "seed", value: String(seed))) }
        if let founded = info["founded"] as? Double { items.append(URLQueryItem(name: "founded", value: String(founded))) }
        if let palette = info["palette"] as? String { items.append(URLQueryItem(name: "palette", value: palette)) }

        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        w.title = "Explore"
        w.minSize = NSSize(width: 720, height: 480)
        w.isReleasedWhenClosed = false
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "app")
        let web = ExploreWebView(frame: w.contentView!.bounds, configuration: config)
        web.autoresizingMask = [.width, .height]
        w.contentView = web
        w.acceptsMouseMovedEvents = true
        var parts = URLComponents(url: html, resolvingAgainstBaseURL: false)!
        parts.queryItems = items
        web.loadFileURL(parts.url!, allowingReadAccessTo: html.deletingLastPathComponent())
        exploreWindow = w
        exploreWeb = web
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: w, queue: .main) { [weak self] _ in
            self?.exploreWeb?.stopLoading()
            self?.exploreWeb?.configuration.userContentController.removeAllScriptMessageHandlers()
            self?.exploreWeb = nil
            self?.exploreWindow = nil
            NSApp.setActivationPolicy(.accessory)
        }
        // A menu-bar app's window can stay behind others; while Explore is open this is an ordinary app.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        w.center()
        w.makeKeyAndOrderFront(nil)
        w.orderFrontRegardless()
        w.makeFirstResponder(web)
    }

    /// Debug only: moves to the first world that's on screen and clicks it with real events, then reports what the page saw.
    private func clickTest(_ out: String) {
        guard let web = exploreWeb, let w = exploreWindow else { return }
        var log = ""
        let say = { (s: String) in log += s + "\n"; try? log.write(toFile: out + ".txt", atomically: true, encoding: .utf8) }
        say("key=\(w.isKeyWindow) main=\(w.isMainWindow) active=\(NSApp.isActive) firstResponder=\(String(describing: w.firstResponder))")
        web.evaluateJavaScript("orrery.pos()") { value, _ in
            guard let text = value as? String, let data = text.data(using: .utf8), let all = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { say("no positions"); return }
            let size = web.bounds.size
            let worlds = all.filter { ($0["kind"] as? String) == "world" && ($0["id"] as? String) != "home" }
            let pick = worlds.first { o in
                let x = o["drawnX"] as? Double ?? -1, y = o["drawnY"] as? Double ?? -1
                return x > 40 && y > 40 && x < Double(size.width) - 340 && y < Double(size.height) - 40
            } ?? all.first { ($0["id"] as? String) == "home" }
            guard let o = pick else { say("nothing on screen"); return }
            let x = (o["drawnX"] as? Double) ?? (o["x"] as? Double ?? 0), y = (o["drawnY"] as? Double) ?? (o["y"] as? Double ?? 0)
            say("target \(o)")
            let loc = web.convert(CGPoint(x: x, y: y), to: nil)
            let send = { (type: NSEvent.EventType) in
                if let e = NSEvent.mouseEvent(with: type, location: loc, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: w.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1) { w.sendEvent(e) }
            }
            send(.mouseMoved)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                web.evaluateJavaScript("orrery.explored()") { v, _ in say("after move \(v ?? "nil")") }
                send(.leftMouseDown); send(.leftMouseUp)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    web.evaluateJavaScript("orrery.explored()") { v, _ in say("after click \(v ?? "nil")") }
                    web.takeSnapshot(with: nil) { image, _ in
                        if let tiff = image?.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) { try? png.write(to: URL(fileURLWithPath: out)) }
                    }
                }
            }
        }
    }

    @objc private func openSettings() {
        if settingsWindow == nil { settingsWindow = buildSettings() }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func buildSettings() -> NSWindow {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 520), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "Orrery Settings"
        w.isReleasedWhenClosed = false
        var rows: [[NSView]] = []
        func label(_ s: String) -> NSTextField { NSTextField(labelWithString: s) }
        func slider(_ key: String, _ lo: Double, _ hi: Double, _ unit: String) {
            let s = SettingSlider(value: defaults.double(forKey: key), minValue: lo, maxValue: hi, target: self, action: #selector(sliderMoved))
            s.key = key
            s.unit = unit
            s.isContinuous = true
            s.widthAnchor.constraint(equalToConstant: 220).isActive = true
            let value = label("")
            s.readout = value
            s.update()
            rows.append([label(titleFor(key)), s, value])
        }
        slider(Key.jMin, 3, 60, " s")
        slider(Key.jMax, 3, 90, " s")
        slider(Key.pMin, 2, 90, " s")
        slider(Key.pMax, 2, 180, " s")
        slider(Key.speed, 0.1, 3, "×")
        slider(Key.dust, 0.4, 2.5, "×")

        let rate = NSPopUpButton(frame: .zero, pullsDown: false)
        let rates: [(String, Double)] = [("Real time", 1), ("10× faster", 10), ("100× faster", 100), ("1000× faster", 1000)]
        rate.addItems(withTitles: rates.map { $0.0 })
        if let i = rates.firstIndex(where: { $0.1 == defaults.double(forKey: Key.rate) }) { rate.selectItem(at: i) }
        rate.target = self
        rate.action = #selector(rateChanged)
        rows.append([label("History speed"), rate, label("")])

        for (title, key) in [("Show their chronicle on the desktop", Key.chronicle), ("Show the event log", Key.eventLog), ("Zoom to events as they happen", Key.zoomEvents), ("Click the wallpaper to visit what's there", Key.clickWall), ("Follow Nairobi's day and night, and this Mac's clock", Key.realTime), ("Show one system across all displays (no zoom)", Key.span)] {
            let box = SettingCheck(checkboxWithTitle: title, target: self, action: #selector(checkChanged))
            box.key = key
            box.state = defaults.bool(forKey: key) ? .on : .off
            rows.append([label(""), box, label("")])
        }

        for (title, key) in [("Custom background", Key.cPaper), ("Custom ink", Key.cInk), ("Custom second ink", Key.cInk2), ("Custom accent", Key.cAccent)] {
            let well = SettingWell(frame: NSRect(x: 0, y: 0, width: 44, height: 24))
            well.key = key
            well.color = NSColor(hex: defaults.string(forKey: key) ?? "#000000")
            well.target = self
            well.action = #selector(colourChanged)
            well.widthAnchor.constraint(equalToConstant: 44).isActive = true
            rows.append([label(title), well, label("")])
        }
        let hint = NSTextField(wrappingLabelWithString: "Dust and the across-displays option rebuild the picture. Changing a custom colour switches to Custom colours.")
        hint.textColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: 11)

        let grid = NSGridView(views: rows)
        grid.rowSpacing = 9
        grid.columnSpacing = 10
        grid.column(at: 0).xPlacement = .trailing
        let stack = NSStackView(views: [grid, hint])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        hint.widthAnchor.constraint(equalToConstant: 500).isActive = true
        grid.column(at: 2).width = 52
        w.contentView = stack
        stack.layoutSubtreeIfNeeded()
        w.setContentSize(stack.fittingSize)
        return w
    }

    private func titleFor(_ key: String) -> String {
        switch key {
        case Key.jMin: return "Shortest zoom"
        case Key.jMax: return "Longest zoom"
        case Key.pMin: return "Shortest pause"
        case Key.pMax: return "Longest pause"
        case Key.speed: return "Orbit speed"
        case Key.dust: return "Dust density"
        default: return key
        }
    }

    @objc private func sliderMoved(_ sender: SettingSlider) {
        sender.update()
        defaults.set(sender.doubleValue, forKey: sender.key)
        if sender.key == Key.dust {
            guard NSApp.currentEvent?.type == .leftMouseUp else { return }
            toAllInTurn("orrery.setDust(\(sender.doubleValue))")
        } else {
            walls.forEach(applyTiming)
        }
    }
    @objc private func rateChanged(_ sender: NSPopUpButton) {
        let value = [1.0, 10, 100, 1000][sender.indexOfSelectedItem]
        defaults.set(value, forKey: Key.rate)
        toAll("orrery.setRate(\(value))")
    }
    @objc private func checkChanged(_ sender: SettingCheck) {
        let on = sender.state == .on
        defaults.set(on, forKey: sender.key)
        switch sender.key {
        case Key.chronicle: toAll("orrery.setChronicle(\(on))")
        case Key.eventLog: toAll("orrery.setEventLog(\(on))")
        case Key.zoomEvents: toAll("orrery.setZoomToEvents(\(on))")
        case Key.realTime: toAll("orrery.setRealTime(\(on))")
        case Key.span: rebuildWalls()
        default: break
        }
    }
    @objc private func colourChanged(_ sender: SettingWell) {
        defaults.set(sender.color.hexString, forKey: sender.key)
        defaults.set(true, forKey: Key.useCustom)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(applyCustomLater), object: nil)
        perform(#selector(applyCustomLater), with: nil, afterDelay: 0.5)
    }
    @objc private func applyCustomLater() { applyCustom() }

    // MARK: Testing

    /// With ORRERY_DEBUG set: logs each wallpaper's state, snapshots its own window only (unless ORRERY_NOSNAP), and runs ORRERY_JS.
    private func startDebugHooks() {
        let env = ProcessInfo.processInfo.environment
        guard let dir = env["ORRERY_DEBUG"] else { return }
        if let js = env["ORRERY_JS"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { self.toAll(js) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self else { return }
            let menu = NSMenu()
            self.menuNeedsUpdate(menu)
            func dump(_ m: NSMenu, _ pad: String) -> String {
                m.items.map { i in
                    (i.isSeparatorItem ? "\(pad)---" : "\(pad)\(i.state == .on ? "[x] " : "")\(i.title)") + "\n" + (i.submenu.map { dump($0, pad + "    ") } ?? "")
                }.joined()
            }
            try? dump(menu, "").write(toFile: dir + "/menu.txt", atomically: true, encoding: .utf8)
            if let want = env["ORRERY_MENU"] {
                let sub = menu.items.compactMap { $0.submenu }.first { $0.items.contains { $0.title == want } }
                if let sub, let i = sub.items.firstIndex(where: { $0.title == want }) {
                    NSLog("Orrery test: pressing \(want), enabled=\(sub.items[i].isEnabled)")
                    sub.performActionForItem(at: i)
                } else { NSLog("Orrery test: no item \(want)") }
            }
            // Check wallpaper clicks from a script: click the first thing on screen, then come back.
            if let out = env["ORRERY_WALL_TEST"], let wall = self.walls.first {
                wall.run("orrery.setZoom(false); orrery.pos()") { value in
                    guard let text = value as? String, let data = text.data(using: .utf8),
                          let all = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                          let o = all.first(where: { ($0["id"] as? String) == "home" }), let x = o["x"] as? Double, let y = o["y"] as? Double else { try? "no positions".write(toFile: out, atomically: true, encoding: .utf8); return }
                    let f = wall.window.frame
                    let p = NSPoint(x: f.minX + x, y: f.maxY - y)
                    var log = "bare=\(self.isBareDesktop(p)) target=\(x),\(y)\n"
                    wall.run("orrery.clickAt(\(x), \(y))") { v in
                        log += "click \(v ?? "nil")\n"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                            wall.run("orrery.state()") { s in
                                log += "state \(s ?? "nil")\n"
                                wall.web.takeSnapshot(with: nil) { image, _ in
                                    if let tiff = image?.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) { try? png.write(to: URL(fileURLWithPath: out + ".png")) }
                                    try? log.write(toFile: out, atomically: true, encoding: .utf8)
                                }
                            }
                        }
                    }
                }
            }
            // Open Explore and send real mouse events through its window, to check clicking from a script.
            if let out = env["ORRERY_EXPLORE_SHOT"] {
                self.openExplore()
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) { self.clickTest(out) }
            }
            if env["ORRERY_OPEN_SETTINGS"] != nil {
                self.openSettings()
                try? String(self.settingsWindow?.windowNumber ?? 0).write(toFile: dir + "/settings-window.txt", atomically: true, encoding: .utf8)
            }
        }
        var tick = 0
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self else { return }
            tick += 1
            for (index, wall) in self.walls.enumerated() {
                wall.run("orrery.state()") { value in
                    let line = "\(tick) wall \(index) level=\(wall.window.level.rawValue) \(value ?? "nil")\n"
                    let url = URL(fileURLWithPath: dir).appendingPathComponent("state.log")
                    if let handle = try? FileHandle(forWritingTo: url) {
                        handle.seekToEndOfFile(); handle.write(Data(line.utf8)); try? handle.close()
                    } else { try? line.write(to: url, atomically: true, encoding: .utf8) }
                }
                if env["ORRERY_NOSNAP"] == nil {
                    self.snapshot(wall, to: URL(fileURLWithPath: dir).appendingPathComponent("wall\(index)-\(tick % 6).png"))
                }
            }
        }
    }
}

final class SettingSlider: NSSlider {
    var key = "", unit = ""
    weak var readout: NSTextField?
    func update() { readout?.stringValue = String(format: unit == " s" ? "%.0f%@" : "%.1f%@", doubleValue, unit) }
}
final class SettingCheck: NSButton { var key = "" }
final class SettingWell: NSColorWell { var key = "" }

extension NSColor {
    convenience init(hex: String) {
        let n = Int(hex.dropFirst(), radix: 16) ?? 0
        self.init(srgbRed: CGFloat((n >> 16) & 255) / 255, green: CGFloat((n >> 8) & 255) / 255, blue: CGFloat(n & 255) / 255, alpha: 1)
    }
    var hexString: String {
        let c = usingColorSpace(.sRGB) ?? self
        return String(format: "#%02x%02x%02x", Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255))
    }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
withExtendedLifetime(delegate) { app.run() }
