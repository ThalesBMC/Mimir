import SwiftUI
import AppKit

@main
struct SoundManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var audioManager: AudioProcessManager?
    var eventMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request audio permission first
        requestAudioPermission()
        
        // Initialize audio manager
        audioManager = AudioProcessManager()
        
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // Create popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 360, height: 450)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(
            rootView: ContentView(audioManager: audioManager!)
        )
        
        // Monitor for clicks outside popover to close it
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.popover?.isShown == true {
                self?.popover?.performClose(nil)
            }
        }
    }
    
    private func requestAudioPermission() {
        AudioPermissionHelper.requestPermission { granted in
            if granted {
                print("✅ Audio permission granted")
            } else {
                print("⚠️ Audio permission denied - volume control may not work")
            }
        }
    }
    
    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }
        
        if popover?.isShown == true {
            popover?.performClose(nil)
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            
            // Activate the app to bring popover to front
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
