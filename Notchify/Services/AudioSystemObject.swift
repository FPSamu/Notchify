import CoreAudio

struct AudioSystemObject {
    static var defaultOutputDeviceID: AudioDeviceID {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        return deviceID
    }
    
    static func deviceName(for deviceID: AudioDeviceID) -> String? {
        var size = UInt32(MemoryLayout<CFString?>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var ref: CFString? = nil
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &ref)
        if status == noErr, let cfName = ref {
            return cfName as String
        }
        return nil
    }

    static func transportType(for deviceID: AudioDeviceID) -> UInt32? {
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &transport)
        return status == noErr ? transport : nil
    }

    static func iconName(for deviceID: AudioDeviceID) -> String {
        let name = (deviceName(for: deviceID) ?? "").lowercased()
        let transport = transportType(for: deviceID)

        func contains(_ words: [String]) -> Bool {
            words.contains { name.contains($0) }
        }

        let headphoneWords = ["headphone", "headset", "buds", "earphone", "earbud"]
        let speakerWords = ["speaker", "boom", "jbl", "soundcore", "flip", "charge", "homepod", "sonos", "bose soundlink"]

        switch transport {
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            if name.contains("airpods max") { return "airpodsmax" }
            if name.contains("airpods pro") { return "airpodspro" }
            if name.contains("airpods") { return "airpods" }
            if name.contains("beats") { return "beats.headphones" }
            if contains(speakerWords) { return "hifispeaker.fill" }
            return "headphones"
        case kAudioDeviceTransportTypeBuiltIn:
            return contains(["headphone"]) ? "headphones" : "laptopcomputer"
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort:
            return "display"
        case kAudioDeviceTransportTypeAirPlay:
            return "airplayaudio"
        case kAudioDeviceTransportTypeUSB:
            return contains(headphoneWords) ? "headphones" : "hifispeaker.fill"
        default:
            if contains(headphoneWords) { return "headphones" }
            return "speaker.wave.2.fill"
        }
    }
}
