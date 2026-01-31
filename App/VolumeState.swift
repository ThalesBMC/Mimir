// SoundManager/App/VolumeState.swift
// Based on FineTune's VolumeState - centralized audio state management
import Foundation

/// Consolidated state for a single app's audio settings
struct AppAudioState {
    var volume: Float
    var muted: Bool
    var persistenceIdentifier: String
}

/// Manages per-app volume and mute state with persistence
@MainActor
final class VolumeState: ObservableObject {
    /// Single source of truth for per-app audio state
    private var states: [pid_t: AppAudioState] = [:]
    
    // UserDefaults keys
    private let volumeKeyPrefix = "SoundManager.Volume."
    private let muteKeyPrefix = "SoundManager.Mute."
    
    // MARK: - Volume
    
    func getVolume(for pid: pid_t) -> Float {
        states[pid]?.volume ?? 1.0
    }
    
    func setVolume(for pid: pid_t, to volume: Float, identifier: String? = nil) {
        if var state = states[pid] {
            state.volume = volume
            if let identifier = identifier {
                state.persistenceIdentifier = identifier
            }
            states[pid] = state
            saveVolume(for: state.persistenceIdentifier, volume: volume)
        } else if let identifier = identifier {
            states[pid] = AppAudioState(volume: volume, muted: false, persistenceIdentifier: identifier)
            saveVolume(for: identifier, volume: volume)
        }
    }
    
    func loadSavedVolume(for pid: pid_t, identifier: String) -> Float? {
        ensureState(for: pid, identifier: identifier)
        let key = volumeKeyPrefix + identifier
        if UserDefaults.standard.object(forKey: key) != nil {
            let volume = UserDefaults.standard.float(forKey: key)
            states[pid]?.volume = volume
            return volume
        }
        return nil
    }
    
    // MARK: - Mute State
    
    func getMute(for pid: pid_t) -> Bool {
        states[pid]?.muted ?? false
    }
    
    func setMute(for pid: pid_t, to muted: Bool, identifier: String? = nil) {
        if var state = states[pid] {
            state.muted = muted
            if let identifier = identifier {
                state.persistenceIdentifier = identifier
            }
            states[pid] = state
            saveMute(for: state.persistenceIdentifier, muted: muted)
        } else if let identifier = identifier {
            states[pid] = AppAudioState(volume: 1.0, muted: muted, persistenceIdentifier: identifier)
            saveMute(for: identifier, muted: muted)
        }
    }
    
    func loadSavedMute(for pid: pid_t, identifier: String) -> Bool? {
        ensureState(for: pid, identifier: identifier)
        let key = muteKeyPrefix + identifier
        if UserDefaults.standard.object(forKey: key) != nil {
            let muted = UserDefaults.standard.bool(forKey: key)
            states[pid]?.muted = muted
            return muted
        }
        return nil
    }
    
    // MARK: - Cleanup
    
    func removeState(for pid: pid_t) {
        states.removeValue(forKey: pid)
    }
    
    func cleanup(keeping pids: Set<pid_t>) {
        states = states.filter { pids.contains($0.key) }
    }
    
    // MARK: - Private Persistence
    
    private func saveVolume(for identifier: String, volume: Float) {
        UserDefaults.standard.set(volume, forKey: volumeKeyPrefix + identifier)
    }
    
    private func saveMute(for identifier: String, muted: Bool) {
        UserDefaults.standard.set(muted, forKey: muteKeyPrefix + identifier)
    }
    
    private func ensureState(for pid: pid_t, identifier: String) {
        if states[pid] == nil {
            states[pid] = AppAudioState(volume: 1.0, muted: false, persistenceIdentifier: identifier)
        } else if states[pid]?.persistenceIdentifier != identifier {
            states[pid]?.persistenceIdentifier = identifier
        }
    }
}
