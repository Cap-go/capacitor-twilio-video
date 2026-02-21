import Foundation
import TwilioVideo
import AVFoundation

@objc public class CapacitorTwilioVideo: NSObject {
    private enum CallState: String {
        case idle
        case connecting
        case connected
        case reconnecting
        case disconnected
    }

    private(set) var accessToken: String?
    private(set) var currentRoom: Room?
    private(set) var currentRoomName: String?
    private(set) var state: String = CallState.idle.rawValue
    private(set) var localAudioTrack: LocalAudioTrack?
    private(set) var localVideoTrack: LocalVideoTrack?
    private(set) var cameraSource: CameraSource?
    private var isCameraCapturing = false

    func setAccessToken(_ token: String) {
        accessToken = token
    }

    func clearSession() {
        currentRoom?.disconnect()
        currentRoom = nil
        currentRoomName = nil
        state = CallState.idle.rawValue
        stopCameraCapture()
        localAudioTrack = nil
        localVideoTrack = nil
        cameraSource = nil
        isCameraCapturing = false
        accessToken = nil
    }

    func updateRoom(_ room: Room?) {
        currentRoom = room
        currentRoomName = room?.name
    }

    func setState(_ next: String) {
        state = next
    }

    func isTokenValid(_ token: String) -> Bool {
        guard let payload = decodeJWTPayload(token), let exp = payload["exp"] as? TimeInterval else {
            return false
        }
        return exp > Date().timeIntervalSince1970
    }

    func extractIdentity(from token: String) -> String? {
        guard let payload = decodeJWTPayload(token),
              let grants = payload["grants"] as? [String: Any]
        else {
            return nil
        }
        return grants["identity"] as? String
    }

    func ensureLocalTracks(enableAudio: Bool, enableVideo: Bool) {
        if enableAudio && localAudioTrack == nil {
            localAudioTrack = LocalAudioTrack()
        }
        if enableVideo && localVideoTrack == nil {
            ensureVideoTrack()
        }
        if !enableAudio {
            localAudioTrack?.isEnabled = false
        }
        if !enableVideo {
            localVideoTrack?.isEnabled = false
        }
    }

    func setMicrophoneEnabled(_ enabled: Bool) {
        if enabled && localAudioTrack == nil {
            localAudioTrack = LocalAudioTrack()
        }
        localAudioTrack?.isEnabled = enabled
    }

    func setCameraEnabled(_ enabled: Bool) {
        if enabled {
            ensureVideoTrack()
            startCameraCaptureIfNeeded()
        } else {
            stopCameraCapture()
        }
        localVideoTrack?.isEnabled = enabled
    }

    private func ensureVideoTrack() {
        if localVideoTrack != nil {
            return
        }
        let source = CameraSource(delegate: nil)
        cameraSource = source
        if let source = source {
            localVideoTrack = LocalVideoTrack(source: source)
        }
    }

    private func startCameraCaptureIfNeeded() {
        if isCameraCapturing {
            return
        }
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            return
        }
        guard let source = cameraSource else {
            return
        }
        guard let captureDevice = CameraSource.captureDevice(position: .front) ?? CameraSource.captureDevice(position: .back) else {
            return
        }

        DispatchQueue.main.async {
            source.startCapture(device: captureDevice) { _, _, error in
                self.isCameraCapturing = (error == nil)
            }
        }
    }

    private func stopCameraCapture() {
        guard isCameraCapturing, let source = cameraSource else {
            return
        }
        DispatchQueue.main.async {
            source.stopCapture()
        }
        isCameraCapturing = false
    }

    private func decodeJWTPayload(_ token: String) -> [String: Any]? {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else {
            return nil
        }

        var payload = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = payload.count % 4
        if remainder > 0 {
            payload += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: payload) else {
            return nil
        }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    @objc public func echo(_ value: String) -> String {
        print(value)
        return value
    }
}
