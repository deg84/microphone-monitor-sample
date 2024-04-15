import SwiftUI
import CoreAudio

class MicrophoneMonitor: ObservableObject {
    private var deviceID: AudioDeviceID = 0
    private var deviceAddedObserver: AudioObjectPropertyListenerProc = { (inObjectID, inNumberAddresses, inAddresses, inClientData) -> OSStatus in
        let monitor = Unmanaged<MicrophoneMonitor>.fromOpaque(inClientData!).takeUnretainedValue()
        monitor.updateCurrentMicrophone()
        return noErr
    }
    
    @Published var currentMicrophone: String = ""
    @Published var history: [String] = []
    
    init() {
        setupAudioDeviceMonitoring()
    }
    
    private func setupAudioDeviceMonitoring() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMaster
        )
        
        var deviceID = AudioDeviceID()
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        
        if status == noErr {
            self.deviceID = deviceID
            updateCurrentMicrophone()
            
            address.mSelector = kAudioDevicePropertyDeviceIsAlive
            let unretainedSelf = Unmanaged.passUnretained(self).toOpaque()
            AudioObjectAddPropertyListener(deviceID, &address, deviceAddedObserver, unretainedSelf)
        }
    }
    
    private func updateCurrentMicrophone() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMaster
        )
        
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name)
        
        if status == noErr {
            let microphone = name as String
            currentMicrophone = microphone
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
            let dateString = dateFormatter.string(from: Date())
            
            let historyItem = "[\(dateString)] マイクが切り替わりました: \(microphone)"
            history.append(historyItem)
            
            showNotification(mic: microphone)
        }
    }
    
    private func showNotification(mic: String) {
        let notification = NSUserNotification()
        notification.title = "マイクが切り替わりました"
        notification.informativeText = "新しいマイク: \(mic)"
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
    }
}

struct ContentView: View {
    @StateObject private var micMonitor = MicrophoneMonitor()
    
    var body: some View {
        VStack {
            Text("現在のマイク: \(micMonitor.currentMicrophone)")
                .padding()
            
            List(micMonitor.history, id: \.self) { item in
                Text(item)
            }
        }
    }
}
