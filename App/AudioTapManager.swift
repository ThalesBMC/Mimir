// SoundManager/App/AudioTapManager.swift
import Foundation
import CoreAudio
import AudioToolbox
import AVFoundation

/// Protocol for audio tap management
protocol AudioTapManagerProtocol {
    func setVolume(for pid: pid_t, volume: Float)
    func setMute(for pid: pid_t, muted: Bool)
    func getAudioLevel(for pid: pid_t) -> Float
    func removeTap(for pid: pid_t)
}

/// Factory to create the appropriate tap manager based on OS version
class AudioTapManagerFactory {
    static func create() -> AudioTapManagerProtocol {
        if #available(macOS 14.2, *) {
            return AudioTapManager()
        } else {
            return AudioTapManagerFallback()
        }
    }
}

/// Audio tap manager using ProcessTapController for proper volume/mute control
/// Replaces the previous mute-only approach with real-time audio processing
@available(macOS 14.2, *)
class AudioTapManager: AudioTapManagerProtocol {
    
    /// Active taps for each process
    private var activeTaps: [pid_t: ProcessTapController] = [:]
    private let queue = DispatchQueue(label: "com.soundmanager.audiotap", qos: .userInteractive)
    
    init() {
        print("✅ AudioTap API available - volume/mute control enabled")
        startLevelMonitoring()
    }
    
    deinit {
        for (_, tap) in activeTaps {
            tap.invalidate()
        }
    }
    
    // Debug timer to monitor levels
    private func startLevelMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            for (pid, tap) in self.activeTaps {
                // Print level even if small to verify connection
                if tap.audioLevel > 0.000001 {
                    print("📊 PID \(pid) Level: \(String(format: "%.3f", tap.audioLevel))")
                } else if tap.volume > 0 && !tap.isMuted {
                    // Check if we expect audio but see none
                    // print("⚠️ PID \(pid) Silent (Level 0.0)") 
                }
            }
        }
    }
    
    /// Set volume for a specific process (0.0 - 2.0, supports boost)
    func setVolume(for pid: pid_t, volume: Float) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            if let existingTap = self.activeTaps[pid] {
                // Tap exists - just update volume
                existingTap.volume = volume
            } else {
                // Create tap if we're adjusting volume (not at 100%)
                if volume != 1.0 {
                    self.ensureTapExists(for: pid)
                    self.activeTaps[pid]?.volume = volume
                }
            }
        }
        
        // let displayPercent = Int(volume * 100)
        // print("🔊 Volume for PID \(pid): \(displayPercent)%")
    }
    
    /// Set mute state for a specific process
    func setMute(for pid: pid_t, muted: Bool) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            if let existingTap = self.activeTaps[pid] {
                existingTap.isMuted = muted
                print(muted ? "🔇 Muted PID: \(pid)" : "🔊 Unmuted PID: \(pid)")
            } else {
                self.ensureTapExists(for: pid)
                if let tap = self.activeTaps[pid] {
                    tap.isMuted = muted
                    print(muted ? "🔇 Muted PID: \(pid)" : "🔊 Unmuted PID: \(pid)")
                }
            }
        }
    }
    
    /// Get audio level for VU meter (0.0 - 1.0)
    func getAudioLevel(for pid: pid_t) -> Float {
        return activeTaps[pid]?.audioLevel ?? 0.0
    }
    
    /// Remove tap for a process
    func removeTap(for pid: pid_t) {
        queue.async { [weak self] in
            if let tap = self?.activeTaps.removeValue(forKey: pid) {
                tap.invalidate()
                print("🗑️ Removed tap for PID: \(pid)")
            }
        }
    }
    
    // MARK: - Private Implementation
    
    private func ensureTapExists(for pid: pid_t) {
        guard activeTaps[pid] == nil else { return }
        
        guard let tap = ProcessTapController(pid: pid) else {
            print("❌ Could not create ProcessTapController for PID \(pid)")
            return
        }
        
        do {
            try tap.activate()
            activeTaps[pid] = tap
            print("✅ Created tap for PID: \(pid)")
        } catch {
            print("❌ Failed to activate tap for PID \(pid): \(error.localizedDescription)")
        }
    }
}

// MARK: - Fallback for older macOS

class AudioTapManagerFallback: AudioTapManagerProtocol {
    func setVolume(for pid: pid_t, volume: Float) {
        print("⚠️ Volume control not available on this macOS version")
    }
    func setMute(for pid: pid_t, muted: Bool) {
        print("⚠️ Mute control not available on this macOS version")
    }
    func getAudioLevel(for pid: pid_t) -> Float {
        return 0.0
    }
    func removeTap(for pid: pid_t) {}
    
    init() {
        print("⚠️ AudioTap requires macOS 14.2+")
    }
}

// MARK: - Permission Helper

class AudioPermissionHelper {
    static func checkPermission() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }
    
    static func requestPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    }
}
