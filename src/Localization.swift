import Foundation

enum L10n {
    private static var isTurkish: Bool {
        Locale.preferredLanguages.first?.hasPrefix("tr") == true
    }

    static func text(_ key: String) -> String {
        let values: [String: (turkish: String, english: String)] = [
            "refresh": ("Yenile", "Refresh"),
            "refreshReconnect": ("Durumu Yenile / Yeniden Bağlan", "Refresh Status / Reconnect"),
            "controlPanel": ("Sony WF-SP800N Kontrol Paneli", "Sony WF-SP800N Control Panel"),
            "connected": ("Bağlı", "Connected"),
            "connecting": ("Bağlanıyor...", "Connecting..."),
            "disconnected": ("Bağlı Değil", "Disconnected"),
            "leftEarbud": ("Sol Kulaklık", "Left Earbud"),
            "rightEarbud": ("Sağ Kulaklık", "Right Earbud"),
            "chargingCase": ("Şarj Kutusu", "Charging Case"),
            "ambientControl": ("Ortam Sesi Kontrolü", "Ambient Sound Control"),
            "noiseCancelling": ("🔇 Gürültü Kesme (ANC)", "🔇 Noise Cancelling (ANC)"),
            "ambientSound": ("🌐 Ortam Sesi", "🌐 Ambient Sound"),
            "level": ("Seviye", "Level"),
            "passiveIsolation": ("Pasif Yalıtım", "Passive Isolation"),
            "noiseCancellingShort": ("Gürültü Kesme", "Noise Cancelling"),
            "voiceFocus": ("Sese Odaklan (Voice Focus)", "Voice Focus"),
            "equalizer": ("Ekolayzır", "Equalizer"),
            "bassBoost": ("Yüksek Bas", "Bass Boost"),
            "excited": ("Heyecanlı", "Excited"),
            "vocal": ("Vokal", "Vocal"),
            "trebleBoost": ("Tiz Güçlendirme", "Treble Boost"),
            "off": ("Kapalı", "Off"),
            "mellow": ("Yumuşak", "Mellow"),
            "relaxed": ("Rahatlatıcı", "Relaxed"),
            "speech": ("Konuşma", "Speech"),
            "custom": ("Özel", "Custom"),
            "clearBass": ("Clear Bass", "Clear Bass"),
            "quit": ("Çıkış Yap", "Quit")
        ]

        guard let value = values[key] else { return key }
        return isTurkish ? value.turkish : value.english
    }
}
