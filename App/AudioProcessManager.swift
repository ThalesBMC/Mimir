import Foundation
import AppKit
import CoreAudio
import Combine
import Darwin


/// Manages detection and tracking of applications that are outputting audio
@MainActor
class AudioProcessManager: ObservableObject {
    @Published var audioApps: [AudioApp] = []
    @Published var hiddenApps: Set<String> = []  // Bundle IDs or names of hidden apps
    @Published var showHiddenApps = false  // Toggle to show hidden apps
    @Published var isMonitoring = false
    
    private var tapManager: AudioTapManagerProtocol?
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let volumeState = VolumeState()
    
    // System apps that are hidden by default
    private let defaultHiddenApps: Set<String> = [
        "com.apple.universalaccessd",
        "universalaccessd",
        "com.apple.SiriNCService",
        "SiriNCService",
        "com.apple.accessibility.AccessibilityUIServer",
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "com.apple.Spotlight",
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.SystemUIServer",
        "com.apple.coreservices.uiagent",
        "com.apple.AmbientDisplayAgent",
        "com.apple.mediaremoted",
        "com.apple.audio.coreaudiod",
        "coreaudiod",
        "com.apple.hidd",
        "Mimir",           // Hide ourselves (New Name)
        "SoundManager",    // Hide ourselves (Old Name)
        "com.soundmanager.app"
    ]
    
    // Bundle ID prefixes for system daemons that should be filtered
    private static let systemDaemonPrefixes: [String] = [
        "com.apple.siri",
        "com.apple.Siri",
        "com.apple.assistant",
        "com.apple.audio",
        "com.apple.coreaudio",
        "com.apple.mediaremote",
        "com.apple.accessibility.heard",
        "com.apple.hearingd",
        "com.apple.voicebankingd",
        "com.apple.systemsound",
    ]
    
    // Process names for system daemons (fallback)
    private static let systemDaemonNames: [String] = [
        "systemsoundserverd",
        "systemsoundserv",
        "coreaudiod",
        "audiomxd",
    ]
    
    private let hiddenAppsKey = "SoundManager.HiddenApps"
    
    init() {
        tapManager = AudioTapManagerFactory.create()
        loadHiddenApps()
        startMonitoring()
    }
    
    /// Start monitoring for audio-outputting applications
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        // Initial scan
        Task {
            await updateAudioApps()
        }
        
        // Periodic updates every 2 seconds
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.updateAudioApps()
            }
        }
        
        // Observe app launch and termination for immediate updates
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .merge(with: NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification))
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.updateAudioApps()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Stop monitoring
    func stopMonitoring() {
        isMonitoring = false
        updateTimer?.invalidate()
        updateTimer = nil
        cancellables.removeAll()
    }
    
    /// Update the list of audio-outputting apps
    func updateAudioApps() async {
        // Use CoreAudio to get all processes with audio I/O
        let processIDs = await getAudioProcessIDs()
        let runningApps = NSWorkspace.shared.runningApplications
        let myPID = ProcessInfo.processInfo.processIdentifier
        
        var appGroups: [String: (app: NSRunningApplication, objectID: AudioObjectID, pids: Set<pid_t>)] = [:]
        
        for objectID in processIDs {
             // Basic checks
             guard objectID.readProcessIsRunning() else { continue }
             guard let pid = try? objectID.readProcessPID(), pid != myPID else { continue }
             
             // Find responsible app
             let directApp = runningApps.first { $0.processIdentifier == pid }
             let isRealApp = directApp?.bundleURL?.pathExtension == "app"
             var resolvedApp = isRealApp ? directApp : findResponsibleApp(for: pid, in: runningApps)
             
             // Get metadata
             let bundleID = resolvedApp?.bundleIdentifier ?? objectID.readProcessBundleID()
             var name = resolvedApp?.localizedName
                ?? objectID.readProcessBundleID()?.components(separatedBy: ".").last
                ?? "Unknown"
             
             // Filter system daemons
             if isSystemDaemon(bundleID: bundleID, name: name) { continue }
             
             // Grouping Key: Prefer Bundle ID, fallback to Name
             var groupKey = bundleID ?? name
             
             // MAP HELPER PROCESSES TO PARENT APPS
             // 1. Known WebKit/Safari Helpers
             if let bid = bundleID, (bid == "com.apple.WebKit.GPU" || bid == "com.apple.WebKit.WebContent" || bid == "com.apple.WebKit.Networking") {
                 if let safari = runningApps.first(where: { $0.bundleIdentifier == "com.apple.Safari" }) {
                     // Found Safari running, remap this process to Safari
                     resolvedApp = safari
                     groupKey = safari.bundleIdentifier!
                     // Use Safari's localized name if available
                     if let safariName = safari.localizedName {
                         name = safariName // Update local name var for fallback
                     }
                 }
             }
             
             // 2. Generic "Helper" or "GPU" suffix matching
             // If the name is generic, try to find a parent app with matching prefix
             if (name == "GPU" || name.contains("Helper") || name.contains("Service")) {
                 // Try to strip the suffix from BundleID and find a match
                 if let bid = bundleID {
                     // e.g. com.google.Chrome.helper -> com.google.Chrome
                     let parts = bid.components(separatedBy: ".")
                     if parts.count > 2 {
                         // Try removing last component
                         let potentialParentID = parts.dropLast().joined(separator: ".")
                         if let parent = runningApps.first(where: { $0.bundleIdentifier == potentialParentID }) {
                             resolvedApp = parent
                             groupKey = potentialParentID
                         }
                     }
                 }
             }

             
             if var existing = appGroups[groupKey] {
                 existing.pids.insert(pid)
                 // If we found a "better" app object (e.g. the main app vs a helper), update it
                 // Prefer the one that matched a running application
                 if existing.app.processIdentifier == -1 && resolvedApp != nil {
                     appGroups[groupKey] = (resolvedApp!, objectID, existing.pids) // Use main app's objectID primarily? Actually helper objectID might be safer to keep separate if we tap individually.
                     // IMPORTANT: For one-tap-fits-all, we'd want the main PID.
                     // But here we are just grouping for UI display.
                 } else {
                     appGroups[groupKey] = (existing.app, existing.objectID, existing.pids)
                 }
             } else {
                 appGroups[groupKey] = (resolvedApp ?? NSRunningApplication(), objectID, [pid])
             }
        }
        
        var newApps: [AudioApp] = []
        
        for (groupKey, group) in appGroups {
            let app = group.app
            let allPids = group.pids
            let mainObjectID = group.objectID // Use the objectID of the first found process for now (usually sufficient for icon/name)
            
            // Determine Main PID: Prefer the one that matches the NSRunningApplication
            let mainPid = (app.processIdentifier != -1) ? app.processIdentifier : allPids.first!
            
            // Load persisted settings
            let volume = volumeState.loadSavedVolume(for: mainPid, identifier: groupKey) ?? 1.0
            let muted = volumeState.loadSavedMute(for: mainPid, identifier: groupKey) ?? false
            
            // Identify additional PIDs
            let additional = allPids.subtracting([mainPid])
            
            // Fallback metadata if NSRunningApplication is empty
            let finalName = app.localizedName ?? mainObjectID.readProcessBundleID()?.components(separatedBy: ".").last ?? "Unknown App"
            let finalIcon = app.icon ?? NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil)
            
            var audioApp = AudioApp(
                id: mainPid,
                objectID: mainObjectID,
                name: finalName,
                bundleIdentifier: groupKey, // simplified
                icon: finalIcon,
                volume: volume,
                isMuted: muted
            )
            audioApp.additionalPids = additional
            newApps.append(audioApp)
        }
        
        // Sort by name
        newApps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        // Publish changes
        self.audioApps = newApps
    }
    
    // MARK: - Private Helper Methods
    
    /// Get all AudioObjectIDs for processes from Core Audio
    private func getAudioProcessIDs() async -> [AudioObjectID] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var propertySize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize
        )
        
        guard status == noErr else { return [] }
        
        let count = Int(propertySize) / MemoryLayout<AudioObjectID>.size
        var objectList = [AudioObjectID](repeating: 0, count: count)
        
        let dataStatus = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &objectList
        )
        
        guard dataStatus == noErr else { return [] }
        
        return objectList
    }
    
    /// Finds the responsible application for a helper/XPC process.
    private func findResponsibleApp(for pid: pid_t, in runningApps: [NSRunningApplication]) -> NSRunningApplication? {
        // Walk up the process tree (works for Chrome/Brave helpers)
        var currentPID = pid
        var visited = Set<pid_t>()

        while currentPID > 1 && !visited.contains(currentPID) {
            visited.insert(currentPID)

            // Check if this PID is a proper app bundle (.app)
            if let app = runningApps.first(where: { $0.processIdentifier == currentPID }),
               app.bundleURL?.pathExtension == "app" {
                return app
            }

            // Get parent PID using sysctl
            var info = kinfo_proc()
            var size = MemoryLayout<kinfo_proc>.size
            var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, currentPID]

            guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { break }

            let parentPID = info.kp_eproc.e_ppid
            if parentPID == currentPID { break }
            currentPID = parentPID
        }

        return nil
    }
    
    private func isSystemDaemon(bundleID: String?, name: String) -> Bool {
        if let bundleID {
            if Self.systemDaemonPrefixes.contains(where: { bundleID.hasPrefix($0) }) {
                return true
            }
        }
        let lowercaseName = name.lowercased()
        if Self.systemDaemonNames.contains(where: { lowercaseName.hasPrefix($0) }) {
            return true
        }
        return false
    }
    
    /// Set volume for an app (and its helpers)
    func setVolume(for app: AudioApp, volume: Float) {
        guard let index = audioApps.firstIndex(where: { $0.id == app.id }) else { return }
        
        let identifier = app.bundleIdentifier ?? app.name
        audioApps[index].volume = volume
        volumeState.setVolume(for: app.id, to: volume, identifier: identifier)
        
        // Apply volume through tap manager for ALL grouped PIDs
        for pid in app.allPids {
            tapManager?.setVolume(for: pid, volume: volume)
        }
    }
    
    /// Toggle mute for an app (and its helpers)
    func toggleMute(for app: AudioApp) {
        guard let index = audioApps.firstIndex(where: { $0.id == app.id }) else { return }
        
        let identifier = app.bundleIdentifier ?? app.name
        audioApps[index].isMuted.toggle()
        let isMuted = audioApps[index].isMuted
        volumeState.setMute(for: app.id, to: isMuted, identifier: identifier)
        
        // Apply mute through tap manager for ALL grouped PIDs
        for pid in app.allPids {
            tapManager?.setMute(for: pid, muted: isMuted)
        }
    }
    
    // MARK: - Hidden Apps Management
    
    /// Get visible apps (filtered by hidden status)
    var visibleApps: [AudioApp] {
        if showHiddenApps {
            return audioApps
        }
        return audioApps.filter { app in
            !isAppHidden(app)
        }
    }
    
    /// Get only hidden apps
    var hiddenAppsList: [AudioApp] {
        audioApps.filter { isAppHidden($0) }
    }
    
    /// Check if an app should be hidden
    func isAppHidden(_ app: AudioApp) -> Bool {
        // Check if manually hidden by user
        if let bundleID = app.bundleIdentifier, hiddenApps.contains(bundleID) {
            return true
        }
        if hiddenApps.contains(app.name) {
            return true
        }
        
        // Check if in default hidden list
        if let bundleID = app.bundleIdentifier, defaultHiddenApps.contains(bundleID) {
            return true
        }
        if defaultHiddenApps.contains(app.name) {
            return true
        }
        
        return false
    }
    
    /// Hide an app
    func hideApp(_ app: AudioApp) {
        let identifier = app.bundleIdentifier ?? app.name
        hiddenApps.insert(identifier)
        saveHiddenApps()
    }
    
    /// Unhide an app
    func unhideApp(_ app: AudioApp) {
        if let bundleID = app.bundleIdentifier {
            hiddenApps.remove(bundleID)
        }
        hiddenApps.remove(app.name)
        saveHiddenApps()
    }
    
    /// Check if an app is manually hidden (can be unhidden)
    func isManuallyHidden(_ app: AudioApp) -> Bool {
        if let bundleID = app.bundleIdentifier, hiddenApps.contains(bundleID) {
            return true
        }
        return hiddenApps.contains(app.name)
    }
    
    /// Load hidden apps from UserDefaults
    private func loadHiddenApps() {
        if let saved = UserDefaults.standard.array(forKey: hiddenAppsKey) as? [String] {
            hiddenApps = Set(saved)
        }
    }
    
    /// Save hidden apps to UserDefaults
    private func saveHiddenApps() {
        UserDefaults.standard.set(Array(hiddenApps), forKey: hiddenAppsKey)
    }
}

