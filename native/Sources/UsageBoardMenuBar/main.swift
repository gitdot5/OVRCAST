import AppKit
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

@MainActor final class BoardWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let store: UsageStore
    var onLoad: (() -> Void)?
    private(set) var loaded = false
    init(store: UsageStore) { self.store = store }
    func show() {
        if let window { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let frame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: min(1080, frame.width - 60), height: min(740, frame.height - 60)),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "OVRCAST"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: FullBoardView(store: store))
        self.window = window
        window.center(); window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        loaded = true; onLoad?()
    }
    func windowWillClose(_ notification: Notification) { window = nil }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, UNUserNotificationCenterDelegate {
    private let store = UsageStore.shared
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var boardWindow: BoardWindow!
    private var previewWindow: NSWindow?
    private var floatingPanel: NSPanel?
    private var settingsWindow: NSWindow?
    private let shortcut = BoardShortcut()
    private var shortcutEnabled: Bool?
    private var floatingEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "floatingBoard") }
        set { UserDefaults.standard.set(newValue, forKey: "floatingBoard") }
    }
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var previewPath: String?
    private var diagnosticsPath: String?
    private var popoverEverShown = false
    private var menuHeight: CGFloat {
        max(360, min(710, (NSScreen.main?.visibleFrame.height ?? 800) - 50))
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UNUserNotificationCenter.current().delegate = self
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: "--snapshot"), args.indices.contains(index + 1) { previewPath = args[index + 1] }
        if let index = args.firstIndex(of: "--diagnostics"), args.indices.contains(index + 1) { diagnosticsPath = args[index + 1] }
        if args.contains("--night") { store.theme = "night" }
        if args.contains("--day") { store.theme = "day" }
        if args.contains("--privacy") { store.preferences.privacyMode = true }
        if let index = args.firstIndex(of: "--provider"), args.indices.contains(index + 1) { store.selectedProvider = args[index + 1] }
        boardWindow = BoardWindow(store: store)
        boardWindow.onLoad = { [weak self] in self?.writeDiagnostics() }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "UsageBoardMainStatusItem"
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "cloud", accessibilityDescription: "OVRCAST")
            button.image?.isTemplate = true
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
            button.target = self
            button.action = #selector(togglePopover)
            button.setAccessibilityLabel("OVRCAST menu")
        }
        let controller = NSHostingController(rootView: MenuView(store: store, openBoard: { [weak self] in self?.openBoard() }, maxHeight: menuHeight,
                                                               toggleFloating: { [weak self] in self?.setFloating(true) }))
        popover.contentViewController = controller
        popover.contentSize = NSSize(width: 430, height: menuHeight)
        popover.behavior = .transient
        popover.animates = true
        store.onChange = { [weak self] in self?.updateStatus() }
        store.onSettingsChanged = { [weak self] visible in self?.presentSettings(visible) }
        store.onPreferencesChanged = { [weak self] in self?.updatePreferences() }
        shortcut.action = { [weak self] in
            guard let self else { return }
            if self.floatingEnabled && self.floatingPanel?.isVisible == true { self.floatingPanel?.orderOut(nil) }
            else { self.togglePopover() }
        }
        updatePreferences()
        store.start()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.popover.performClose(nil) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.popover.performClose(nil) }
            return event
        }
        if previewPath != nil { showPreview() }
        else if args.contains("--floating") { setFloating(true) }
        else if args.contains("--show") || floatingEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.togglePopover() }
        }
        if args.contains("--board") { openBoard() }
        if args.contains("--setup"), previewPath == nil { store.showSettings = true }
        writeDiagnostics()
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                           withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner])
    }
    private func updatePreferences() {
        if shortcutEnabled != store.preferences.shortcutEnabled {
            shortcutEnabled = store.preferences.shortcutEnabled
            if store.preferences.shortcutEnabled {
                store.shortcutStatus = shortcut.register() ? "⌘⇧U to show or hide the board" : "⌘⇧U is already in use. Disable it here or free it in the other app."
            } else { shortcut.unregister(); store.shortcutStatus = "Keyboard shortcut is off" }
        }
        let appearance = store.theme == "system" ? nil : NSAppearance(named: store.theme == "night" ? .darkAqua : .aqua)
        floatingPanel?.appearance = appearance
        settingsWindow?.appearance = appearance
        updateStatus()
    }
    private func presentSettings(_ visible: Bool) {
        guard visible else { settingsWindow?.orderOut(nil); return }
        popover.performClose(nil)
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 584, height: 574), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "OVRCAST Settings"
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentViewController = NSHostingController(rootView: SettingsView(store: store))
            window.center(); settingsWindow = window
        }
        settingsWindow?.level = .floating
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    private func updateStatus() {
        statusItem?.button?.title = store.accounts.isEmpty ? "" : " \(store.available)/\(store.accounts.count)"
        statusItem?.button?.toolTip = "OVRCAST · \(store.available) of \(store.accounts.count) accounts available"
        writeDiagnostics()
    }
    @objc private func togglePopover() {
        if floatingEnabled { showFloating(); return }
        if popover.isShown { popover.performClose(nil); return }
        guard let button = statusItem.button else { return }
        store.load()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popoverEverShown = popoverEverShown || popover.isShown
        popover.contentViewController?.view.window?.makeKey()
        writeDiagnostics()
    }
    private func setFloating(_ enabled: Bool) {
        floatingEnabled = enabled
        popover.performClose(nil)
        if enabled { showFloating() }
        else { floatingPanel?.orderOut(nil); togglePopover() }
        writeDiagnostics()
    }
    private func showFloating() {
        store.load()
        if floatingPanel == nil {
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 430, height: menuHeight),
                                styleMask: [.titled, .closable, .utilityWindow], backing: .buffered, defer: false)
            panel.title = "OVRCAST"
            panel.isReleasedWhenClosed = false
            panel.isMovable = true
            panel.isMovableByWindowBackground = true
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            panel.delegate = self
            panel.contentViewController = NSHostingController(rootView:
                MenuView(store: store, openBoard: { [weak self] in self?.openBoard() }, maxHeight: menuHeight,
                         floating: true, toggleFloating: { [weak self] in self?.setFloating(false) }))
            panel.center()
            panel.setFrameAutosaveName("UsageBoardFloatingPanel")
            // Bring a restored panel back onto a connected display after a monitor is removed.
            if !NSScreen.screens.contains(where: { $0.visibleFrame.intersection(panel.frame).width >= 100 && $0.visibleFrame.intersection(panel.frame).height >= 50 }) {
                panel.center()
            }
            floatingPanel = panel
        }
        floatingPanel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        writeDiagnostics()
    }
    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === settingsWindow { store.showSettings = false }
        // Closing hides the board; the menu bar icon brings it back in the same place.
        DispatchQueue.main.async { [weak self] in self?.writeDiagnostics() }
    }
    private func openBoard() { popover.performClose(nil); boardWindow.show() }
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "usageboard" && url.host == "refresh" && ["", "/"].contains(url.path) { store.refresh() }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { togglePopover() }
        return true
    }
    func applicationWillTerminate(_ notification: Notification) {
        shortcut.unregister()
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
    }
    private func writeDiagnostics() {
        guard let diagnosticsPath else { return }
        let result: [String: Any] = ["statusItemCreated": statusItem?.button != nil,
                                   "accessoryApplication": NSApp.activationPolicy() == .accessory,
                                   "accounts": store.accounts.count, "available": store.available,
                                   "popoverShown": popover.isShown, "popoverEverShown": popoverEverShown,
                                   "fullBoardLoaded": boardWindow?.loaded == true,
                                   "floatingEnabled": floatingEnabled,
                                   "floatingVisible": floatingPanel?.isVisible == true,
                                   "floatingMovable": floatingPanel?.isMovable == true,
                                   "floatingBackgroundDrag": floatingPanel?.isMovableByWindowBackground == true,
                                   "floatingStaysOnTop": floatingPanel?.level == .floating,
                                   "theme": store.theme, "nativeCollection": store.nativeMode,
                                   "settingsVisible": settingsWindow?.isVisible == true,
                                   "privacyMode": store.preferences.privacyMode, "historySamples": store.history.count,
                                   "shortcut": store.shortcutStatus]
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: diagnosticsPath), options: .atomic)
        }
    }
    private func showPreview() {
        let setup = CommandLine.arguments.contains("--setup")
        let height: CGFloat = setup ? 574 : menuHeight
        let content = setup ? AnyView(SettingsView(store: store)) : AnyView(MenuView(store: store, openBoard: { [weak self] in self?.openBoard() }, maxHeight: height,
            toggleFloating: { [weak self] in self?.setFloating(true) }))
        let host = NSHostingView(rootView: content)
        host.frame = NSRect(x: 0, y: 0, width: setup ? 584 : 430, height: height)
        let window = NSWindow(contentRect: host.frame, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "OVRCAST · Menu preview"
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.center()
        window.makeKeyAndOrderFront(nil)
        previewWindow = window
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self, weak host] in
            guard let path = self?.previewPath, let host else { return }
            host.layoutSubtreeIfNeeded()
            if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                host.cacheDisplay(in: host.bounds, to: rep)
                if let png = rep.representation(using: .png, properties: [:]) { try? png.write(to: URL(fileURLWithPath: path)) }
            }
            self?.writeDiagnostics()
            if CommandLine.arguments.contains("--exit-after-snapshot") { NSApp.terminate(nil) }
        }
    }
}

MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    withExtendedLifetime(delegate) { application.run() }
}
