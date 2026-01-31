import Foundation
import AppKit

import CoreAudio

/// Represents an application that is currently outputting audio
struct AudioApp: Identifiable, Equatable, Hashable {
    let id: pid_t
    let objectID: AudioObjectID // CoreAudio Object ID
    let name: String
    let bundleIdentifier: String?
    let icon: NSImage?
    var volume: Float  // 0.0 - 1.0
    var isMuted: Bool
    var additionalPids: Set<pid_t> = [] // Helper processes (e.g. WebKit GPU)
    
    var allPids: Set<pid_t> {
        var pids = additionalPids
        pids.insert(id)
        return pids
    }
    
    static func == (lhs: AudioApp, rhs: AudioApp) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Represents the state of an audio tap for a process
struct AudioTapState {
    let processID: pid_t
    var tapID: UInt32?
    var aggregateDeviceID: UInt32?
    var isActive: Bool
}
