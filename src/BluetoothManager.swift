import Foundation
import IOBluetooth

@objcMembers
class BluetoothManager: NSObject, ObservableObject, IOBluetoothRFCOMMChannelDelegate {
    static let shared = BluetoothManager()
    
    var device: IOBluetoothDevice?
    var channel: IOBluetoothRFCOMMChannel?
    @Published var state = HeadphoneState()
    var onStateUpdate: ((HeadphoneState) -> Void)?
    var seq: UInt8 = 0
    
    var targetAddress = "94-db-56-63-a6-96"
    var isConnecting = false
    var connectionTimer: Timer?
    var lastUserActionTime: Date = Date.distantPast
    
    func logDebug(_ text: String) {
        let line = "\(Date()) [BM]: \(text)\n"
        if let data = line.data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: "/tmp/sony_debug.log")) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: URL(fileURLWithPath: "/tmp/sony_debug.log"))
            }
        }
    }
    
    override init() {
        super.init()
    }
    
    func nextSeq() -> UInt8 {
        let s = seq
        seq = (seq + 1) & 1
        return s
    }
    
    func connect() {
        logDebug("connect() called. channel=\(String(describing: channel)), isOpen=\(channel?.isOpen() ?? false)")
        if let ch = channel, ch.isOpen() {
            refreshStatus()
            return
        }
        
        isConnecting = true
        state.isConnected = false
        onStateUpdate?(state)
        
        connectionTimer?.invalidate()
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 7.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.channel == nil || !self.channel!.isOpen() {
                self.logDebug("connectionTimer timed out waiting for channel open")
                print("[\u{23F1}\u{FE0F}] RFCOMM bağlantısı zaman aşımına uğradı.")
                self.isConnecting = false
                self.state.isConnected = false
                DispatchQueue.main.async {
                    self.onStateUpdate?(self.state)
                }
            }
        }
        
        // Find device
        guard let dev = IOBluetoothDevice(addressString: targetAddress) else {
            logDebug("Device address not found: \(targetAddress)")
            print("[\u{274C}] Cihaz adresi bulunamadı.")
            isConnecting = false
            connectionTimer?.invalidate()
            return
        }
        self.device = dev
        
        if !dev.isConnected() {
            logDebug("Device not connected to Mac, opening connection...")
            print("[\u{1F504}] Cihaza temel Bluetooth bağlantısı kuruluyor...")
            let res = dev.openConnection()
            if res != kIOReturnSuccess {
                logDebug("dev.openConnection failed: \(res)")
                print("[\u{274C}] Cihaza bağlanılamadı: \(res)")
                isConnecting = false
                connectionTimer?.invalidate()
                return
            }
        }
        
        logDebug("Device is connected. Calling openRFCOMMChannelAsync on channel 9...")
        print("[\u{2705}] Cihaz bağlı, RFCOMM Kanal 9 açılıyor...")
        var rfcommChannel: IOBluetoothRFCOMMChannel?
        let openRes = dev.openRFCOMMChannelAsync(&rfcommChannel, withChannelID: 9, delegate: self)
        logDebug("openRFCOMMChannelAsync return code: \(openRes)")
        if openRes != kIOReturnSuccess {
            logDebug("openRFCOMMChannelAsync failed: \(openRes)")
            print("[\u{274C}] openRFCOMMChannelAsync başarısız: \(openRes)")
            isConnecting = false
            connectionTimer?.invalidate()
        }
    }
    
    func refreshStatus() {
        guard let ch = channel, ch.isOpen() else {
            connect()
            return
        }
        sendCmd(SonyProtocol.cmdQueryEarbudsBattery())
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.sendCmd(SonyProtocol.cmdQueryCaseBattery())
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.sendCmd(SonyProtocol.cmdQueryNCStatus())
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            self.sendCmd(SonyProtocol.cmdQueryEQStatus())
        }
    }
    
    func sendCmd(_ payload: [UInt8]) {
        guard let ch = channel, ch.isOpen() else {
            logDebug("sendCmd: CHANNEL NOT OPEN! Payload: \(payload.map { String(format: "%02x", $0) }.joined(separator: " "))")
            print("[\u{26A0}\u{FE0F}] Kanal açık değil, komut gönderilemedi.")
            return
        }
        let frame = SonyProtocol.buildFrame(type: 0x0C, seq: nextSeq(), payload: payload)
        var buffer = frame
        let res = ch.writeSync(&buffer, length: UInt16(buffer.count))
        logDebug("sendCmd: sent \(payload.map { String(format: "%02x", $0) }.joined(separator: " ")) res=\(res)")
    }
    
    func sendAck(seq: UInt8) {
        guard let ch = channel, ch.isOpen() else { return }
        var ackFrame = SonyProtocol.buildAck(seq: seq)
        _ = ch.writeSync(&ackFrame, length: UInt16(ackFrame.count))
    }
    
    // RFCOMM Delegate Callbacks
    func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel?, status error: IOReturn) {
        connectionTimer?.invalidate()
        connectionTimer = nil
        isConnecting = false
        if error == kIOReturnSuccess, let ch = rfcommChannel {
            logDebug("RFCOMM Channel 9 Open Success!")
            print("[\u{2705}] RFCOMM Kanal 9 Başarıyla Açıldı!")
            self.channel = ch
            self.state.isConnected = true
            DispatchQueue.main.async {
                self.onStateUpdate?(self.state)
            }
            
            // İlk sorguları gönder
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.refreshStatus()
            }
        } else {
            logDebug("RFCOMM Channel Open Error: \(error)")
            print("[\u{274C}] RFCOMM Kanal açma hatası: \(error)")
            self.state.isConnected = false
            DispatchQueue.main.async {
                self.onStateUpdate?(self.state)
            }
        }
    }
    
    func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel?) {
        logDebug("RFCOMM Channel Closed")
        print("[\u{1F51A}] RFCOMM Kanalı Kapandı.")
        connectionTimer?.invalidate()
        connectionTimer = nil
        self.channel = nil
        self.state.isConnected = false
        DispatchQueue.main.async {
            self.onStateUpdate?(self.state)
        }
    }
    
    func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel?, data dataPointer: UnsafeMutableRawPointer?, length dataLength: Int) {
        guard let dp = dataPointer else { return }
        let buffer = dp.bindMemory(to: UInt8.self, capacity: dataLength)
        let bytes = Array(UnsafeBufferPointer(start: buffer, count: dataLength))
        
        var i = 0
        while i < bytes.count {
            if bytes[i] == 0x3E && i + 8 < bytes.count {
                let ftype = bytes[i+1]
                let fseq = bytes[i+2]
                let plen = Int((UInt32(bytes[i+3]) << 24) | (UInt32(bytes[i+4]) << 16) | (UInt32(bytes[i+5]) << 8) | UInt32(bytes[i+6]))
                let frameEnd = i + 7 + plen + 2
                if frameEnd <= bytes.count && bytes[frameEnd-1] == 0x3C {
                    let payload = Array(bytes[i+7..<i+7+plen])
                    handlePayload(ftype: ftype, fseq: fseq, payload: payload)
                    i = frameEnd
                    continue
                }
            }
            i += 1
        }
    }
    
    private func handlePayload(ftype: UInt8, fseq: UInt8, payload: [UInt8]) {
        if ftype == 0x0C || ftype == 0x0E {
            sendAck(seq: fseq)
        }
        
        guard payload.count >= 2 else { return }
        let cmd = payload[0]
        let sub = payload[1]
        logDebug("handlePayload: [\(String(format: "%02x", cmd)) \(String(format: "%02x", sub))] data: \(payload.map { String(format: "%02x", $0) }.joined(separator: " "))")
        
        var updated = false
        
        // Earbuds Battery (0x11 0x01)
        if cmd == 0x11 && sub == 0x01 && payload.count >= 6 {
            state.leftBattery = Int(payload[2])
            state.leftCharging = payload[3] == 1
            state.rightBattery = Int(payload[4])
            state.rightCharging = payload[5] == 1
            updated = true
        }
        // Case Battery (0x11 0x02)
        else if cmd == 0x11 && sub == 0x02 && payload.count >= 4 {
            state.caseBattery = Int(payload[2])
            state.caseCharging = payload[3] == 1
            updated = true
        }
        // NC / Ambient Status (0x67 0x02 or 0x69 0x02)
        else if (cmd == 0x67 || cmd == 0x69) && sub == 0x02 && payload.count >= 8 {
            if cmd == 0x67 && Date().timeIntervalSince(lastUserActionTime) < 1.5 {
                logDebug("Ignoring stale 0x67 query response due to recent user action")
                return
            }
            
            let b2 = payload[2]
            let b4 = payload[4]
            let b6 = payload[6]
            let b7 = payload[7]
            
            if b2 == 0x00 {
                state.ncMode = .off
            } else {
                if b4 == 0x01 {
                    state.ncMode = .anc
                    state.voiceFocus = false
                } else if b4 == 0x00 {
                    state.ncMode = .ambient
                    state.voiceFocus = (b6 == 0x01)
                    state.ambientLevel = b7
                }
            }
            logDebug("NC parsed -> ncMode=\(state.ncMode), level=\(state.ambientLevel), vf=\(state.voiceFocus)")
            updated = true
        }
        // EQ Status (0x57 0x01 or 0x59 0x01)
        else if (cmd == 0x57 || cmd == 0x59) && sub == 0x01 && payload.count >= 10 {
            if cmd == 0x57 && Date().timeIntervalSince(lastUserActionTime) < 1.5 {
                logDebug("Ignoring stale 0x57 query response due to recent user action")
                return
            }
            let presetVal = Int(payload[2])
            if let p = EQPreset(rawValue: presetVal) {
                state.currentPreset = p
            }
            state.clearBass = Int(payload[4]) - 10
            updated = true
        }
        
        if updated {
            DispatchQueue.main.async {
                self.onStateUpdate?(self.state)
            }
        }
    }
    
    // User Control Actions
    func setNoiseMode(_ mode: NCMode, ambientLevel: UInt8? = nil, voiceFocus: Bool? = nil) {
        lastUserActionTime = Date()
        if let lvl = ambientLevel {
            state.ambientLevel = lvl
        }
        if let vf = voiceFocus {
            state.voiceFocus = vf
        }
        state.ncMode = mode
        logDebug("setNoiseMode: mode=\(mode), level=\(state.ambientLevel), vf=\(state.voiceFocus)")
        sendCmd(SonyProtocol.cmdSetNC(mode: mode, ambientLevel: state.ambientLevel, voiceFocus: state.voiceFocus))
        DispatchQueue.main.async {
            self.onStateUpdate?(self.state)
        }
    }
    
    func setEqualizer(_ preset: EQPreset) {
        lastUserActionTime = Date()
        state.currentPreset = preset
        sendCmd(SonyProtocol.cmdSetPresetEQ(preset: preset))
        DispatchQueue.main.async {
            self.onStateUpdate?(self.state)
        }
    }
    
    func setClearBass(_ level: Int) {
        lastUserActionTime = Date()
        state.clearBass = level
        sendCmd(SonyProtocol.cmdSetClearBass(level: level))
        DispatchQueue.main.async {
            self.onStateUpdate?(self.state)
        }
    }
}
