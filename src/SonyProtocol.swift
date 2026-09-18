import Foundation

enum NCMode: Int {
    case off = 0
    case anc = 1
    case ambient = 2
}

enum EQPreset: Int {
    case off = 0x00
    case excited = 0x11
    case mellow = 0x12
    case relaxed = 0x13
    case vocal = 0x14
    case trebleBoost = 0x15
    case bassBoost = 0x16
    case speech = 0x17
    case custom = 0xa0
    
    var displayName: String {
        switch self {
        case .off: return L10n.text("off")
        case .bassBoost: return L10n.text("bassBoost")
        case .excited: return L10n.text("excited")
        case .vocal: return L10n.text("vocal")
        case .trebleBoost: return L10n.text("trebleBoost")
        case .mellow: return L10n.text("mellow")
        case .relaxed: return L10n.text("relaxed")
        case .speech: return L10n.text("speech")
        case .custom: return L10n.text("custom")
        }
    }
}

struct HeadphoneState {
    var leftBattery: Int = 0
    var leftCharging: Bool = false
    var rightBattery: Int = 0
    var rightCharging: Bool = false
    var caseBattery: Int = 0
    var caseCharging: Bool = false
    var ncMode: NCMode = .off
    var ambientLevel: UInt8 = 10
    var voiceFocus: Bool = false
    var currentPreset: EQPreset = .bassBoost
    var clearBass: Int = 0
    var isConnected: Bool = false
}

class SonyProtocol {
    static func buildFrame(type: UInt8, seq: UInt8, payload: [UInt8]) -> [UInt8] {
        var frame = [UInt8]()
        frame.append(0x3E) // Start
        frame.append(type) // 0x0C: Command, 0x01: ACK
        frame.append(seq)
        let len = UInt32(payload.count)
        frame.append(UInt8((len >> 24) & 0xFF))
        frame.append(UInt8((len >> 16) & 0xFF))
        frame.append(UInt8((len >> 8) & 0xFF))
        frame.append(UInt8(len & 0xFF))
        frame.append(contentsOf: payload)
        
        var sum: UInt32 = 0
        for i in 1..<frame.count {
            sum += UInt32(frame[i])
        }
        frame.append(UInt8(sum & 0xFF))
        frame.append(0x3C) // End
        return frame
    }
    
    static func buildAck(seq: UInt8) -> [UInt8] {
        let ackSeq = (seq + 1) & 1
        return [0x3E, 0x01, ackSeq, 0x00, 0x00, 0x00, 0x00, (0x01 + ackSeq) & 0xFF, 0x3C]
    }
    
    // Command Generators
    static func cmdQueryEarbudsBattery() -> [UInt8] {
        return [0x10, 0x01]
    }
    
    static func cmdQueryCaseBattery() -> [UInt8] {
        return [0x10, 0x02]
    }
    
    static func cmdQueryNCStatus() -> [UInt8] {
        return [0x66, 0x02]
    }
    
    static func cmdQueryEQStatus() -> [UInt8] {
        return [0x56, 0x01]
    }
    
    static func cmdSetNC(mode: NCMode, ambientLevel: UInt8, voiceFocus: Bool) -> [UInt8] {
        switch mode {
        case .off:
            return [0x68, 0x02, 0x00, 0x00, 0x01, 0x01, 0x00, 0x00]
        case .anc:
            return [0x68, 0x02, 0x11, 0x00, 0x01, 0x01, 0x00, 0x00]
        case .ambient:
            let level = min(max(ambientLevel, 1), 20)
            let vf: UInt8 = voiceFocus ? 0x01 : 0x00
            return [0x68, 0x02, 0x11, 0x00, 0x00, 0x01, vf, level]
        }
    }
    
    static func cmdSetPresetEQ(preset: EQPreset) -> [UInt8] {
        return [0x58, 0x01, UInt8(preset.rawValue), 0x00]
    }
    
    static func cmdSetClearBass(level: Int) -> [UInt8] {
        let clamped = min(max(level, -10), 10)
        let rawCB = UInt8(clamped + 10)
        return [0x58, 0x01, 0xFF, 0x06, rawCB, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A]
    }
}
