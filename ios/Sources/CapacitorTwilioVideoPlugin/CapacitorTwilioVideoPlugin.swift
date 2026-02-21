import Foundation
import Capacitor
import TwilioVideo
import AVFoundation
import UIKit

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@objc(CapacitorTwilioVideoPlugin)
public class CapacitorTwilioVideoPlugin: CAPPlugin, CAPBridgedPlugin, RoomDelegate, RemoteParticipantDelegate {
    private let cachedAccessTokenKey = "CapacitorTwilioVideoCachedAccessToken"

    public let identifier = "CapacitorTwilioVideoPlugin"
    public let jsName = "CapacitorTwilioVideo"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "login", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "logout", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "isLoggedIn", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "joinRoom", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "leaveRoom", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setMicrophoneEnabled", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setCameraEnabled", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getCallStatus", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "checkMicrophonePermission", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "requestMicrophonePermission", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "checkCameraPermission", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "requestCameraPermission", returnType: CAPPluginReturnPromise)
    ]

    private let implementation = CapacitorTwilioVideo()
    private var callOverlayView: TwilioCallOverlayView?
    private var renderedLocalTrack: LocalVideoTrack?
    private var renderedRemoteTrack: RemoteVideoTrack?
    private var webViewOriginalIsOpaque: Bool?
    private var webViewOriginalBackgroundColor: UIColor?
    private var webViewOriginalScrollBackgroundColor: UIColor?

    override public func load() {
        super.load()
        if let token = UserDefaults.standard.string(forKey: cachedAccessTokenKey), implementation.isTokenValid(token) {
            implementation.setAccessToken(token)
        } else {
            UserDefaults.standard.removeObject(forKey: cachedAccessTokenKey)
        }
    }

    @objc func login(_ call: CAPPluginCall) {
        guard let accessToken = call.getString("accessToken"), !accessToken.isEmpty else {
            call.reject("accessToken is required")
            return
        }

        guard implementation.isTokenValid(accessToken) else {
            call.reject("Invalid or expired access token")
            return
        }

        implementation.setAccessToken(accessToken)
        UserDefaults.standard.set(accessToken, forKey: cachedAccessTokenKey)
        call.resolve(["success": true])
    }

    @objc func logout(_ call: CAPPluginCall) {
        teardownCallUI()
        implementation.clearSession()
        UserDefaults.standard.removeObject(forKey: cachedAccessTokenKey)
        call.resolve(["success": true])
    }

    @objc func isLoggedIn(_ call: CAPPluginCall) {
        guard let token = implementation.accessToken, implementation.isTokenValid(token) else {
            call.resolve([
                "isLoggedIn": false,
                "hasValidToken": false
            ])
            return
        }

        var response: [String: Any] = [
            "isLoggedIn": true,
            "hasValidToken": true
        ]
        if let identity = implementation.extractIdentity(from: token) {
            response["identity"] = identity
        }
        call.resolve(response)
    }

    @objc func joinRoom(_ call: CAPPluginCall) {
        guard let roomName = call.getString("roomName"), !roomName.isEmpty else {
            call.reject("roomName is required")
            return
        }
        guard let accessToken = implementation.accessToken, implementation.isTokenValid(accessToken) else {
            call.reject("No valid access token. Please call login() first.")
            return
        }
        guard implementation.currentRoom == nil else {
            call.reject("Already connected to a room. Leave current room first.")
            return
        }

        let enableAudio = call.getBool("enableAudio") ?? true
        let enableVideo = call.getBool("enableVideo") ?? false

        if enableAudio, AVAudioSession.sharedInstance().recordPermission != .granted {
            call.reject("Microphone permission is required to enable audio.")
            return
        }
        if enableVideo, AVCaptureDevice.authorizationStatus(for: .video) != .authorized {
            call.reject("Camera permission is required to enable video.")
            return
        }

        implementation.ensureLocalTracks(enableAudio: enableAudio, enableVideo: enableVideo)
        implementation.setState("connecting")
        installCallOverlayIfNeeded()
        updateCallOverlayState()
        attachLocalRendererIfAvailable()

        let connectOptions = ConnectOptions(token: accessToken) { builder in
            builder.roomName = roomName
            if enableAudio, let audioTrack = self.implementation.localAudioTrack {
                builder.audioTracks = [audioTrack]
            }
            if enableVideo, let videoTrack = self.implementation.localVideoTrack {
                builder.videoTracks = [videoTrack]
            }
        }
        let room = TwilioVideoSDK.connect(options: connectOptions, delegate: self)
        implementation.updateRoom(room)
        call.resolve(["success": true])
    }

    @objc func leaveRoom(_ call: CAPPluginCall) {
        disconnectCurrentRoom()
        call.resolve(["success": true])
    }

    @objc func setMicrophoneEnabled(_ call: CAPPluginCall) {
        guard let enabled = call.getBool("enabled") else {
            call.reject("enabled is required")
            return
        }
        if enabled, AVAudioSession.sharedInstance().recordPermission != .granted {
            call.reject("Microphone permission is required.")
            return
        }

        implementation.setMicrophoneEnabled(enabled)
        if let room = implementation.currentRoom, let participant = room.localParticipant, let track = implementation.localAudioTrack {
            if enabled {
                _ = participant.publishAudioTrack(track)
            } else {
                participant.unpublishAudioTrack(track)
            }
        }
        updateCallOverlayState()
        call.resolve([
            "success": true,
            "enabled": enabled
        ])
    }

    @objc func setCameraEnabled(_ call: CAPPluginCall) {
        guard let enabled = call.getBool("enabled") else {
            call.reject("enabled is required")
            return
        }
        if enabled, AVCaptureDevice.authorizationStatus(for: .video) != .authorized {
            call.reject("Camera permission is required.")
            return
        }

        implementation.setCameraEnabled(enabled)
        if let room = implementation.currentRoom, let participant = room.localParticipant, let track = implementation.localVideoTrack {
            if enabled {
                _ = participant.publishVideoTrack(track)
            } else {
                participant.unpublishVideoTrack(track)
            }
        }
        attachLocalRendererIfAvailable()
        updateCallOverlayState()
        call.resolve([
            "success": true,
            "enabled": enabled
        ])
    }

    @objc func getCallStatus(_ call: CAPPluginCall) {
        let isConnected = implementation.currentRoom != nil &&
            (implementation.state == "connecting" ||
             implementation.state == "connected" ||
             implementation.state == "reconnecting")

        var response: [String: Any] = [
            "hasActiveCall": isConnected,
            "callState": implementation.state,
            "participantCount": implementation.currentRoom?.remoteParticipants.count ?? 0,
            "isMicrophoneEnabled": implementation.localAudioTrack?.isEnabled ?? false,
            "isCameraEnabled": implementation.localVideoTrack?.isEnabled ?? false
        ]
        if let roomName = implementation.currentRoomName {
            response["roomName"] = roomName
        }
        call.resolve(response)
    }

    @objc func checkMicrophonePermission(_ call: CAPPluginCall) {
        call.resolve(["granted": AVAudioSession.sharedInstance().recordPermission == .granted])
    }

    @objc func requestMicrophonePermission(_ call: CAPPluginCall) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                call.resolve(["granted": granted])
            }
        }
    }

    @objc func checkCameraPermission(_ call: CAPPluginCall) {
        call.resolve(["granted": AVCaptureDevice.authorizationStatus(for: .video) == .authorized])
    }

    @objc func requestCameraPermission(_ call: CAPPluginCall) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                call.resolve(["granted": granted])
            }
        }
    }

    // MARK: RoomDelegate

    public func roomDidConnect(room: Room) {
        implementation.updateRoom(room)
        implementation.setState("connected")
        for participant in room.remoteParticipants {
            participant.delegate = self
        }
        installCallOverlayIfNeeded()
        attachLocalRendererIfAvailable()
        attachRemoteRendererIfAvailable()
        updateCallOverlayState()
        notifyListeners("roomConnected", data: [
            "roomName": room.name,
            "participantCount": room.remoteParticipants.count
        ])
    }

    public func roomDidDisconnect(room: Room, error: Error?) {
        let roomName = room.name
        implementation.updateRoom(nil)
        implementation.setState("disconnected")
        teardownCallUI()
        var payload: [String: Any] = ["roomName": roomName]
        if let error = error {
            payload["error"] = error.localizedDescription
        }
        notifyListeners("roomDisconnected", data: payload)
    }

    public func roomDidFailToConnect(room: Room, error: Error) {
        implementation.updateRoom(nil)
        implementation.setState("disconnected")
        teardownCallUI()
        notifyListeners("roomDisconnected", data: [
            "roomName": room.name,
            "error": error.localizedDescription
        ])
    }

    public func roomIsReconnecting(room: Room, error: Error) {
        implementation.setState("reconnecting")
        updateCallOverlayState()
        notifyListeners("roomReconnecting", data: [
            "roomName": room.name,
            "error": error.localizedDescription
        ])
    }

    public func roomDidReconnect(room: Room) {
        implementation.setState("connected")
        for participant in room.remoteParticipants {
            participant.delegate = self
        }
        attachRemoteRendererIfAvailable()
        updateCallOverlayState()
        notifyListeners("roomReconnected", data: ["roomName": room.name])
    }

    public func participantDidConnect(room: Room, participant: RemoteParticipant) {
        participant.delegate = self
        attachRemoteRendererIfAvailable()
        updateCallOverlayState()
        notifyListeners("participantConnected", data: [
            "roomName": room.name,
            "identity": participant.identity,
            "participantCount": room.remoteParticipants.count
        ])
    }

    public func participantDidDisconnect(room: Room, participant: RemoteParticipant) {
        if room.remoteParticipants.isEmpty {
            detachRemoteRenderer()
        } else {
            attachRemoteRendererIfAvailable()
        }
        updateCallOverlayState()
        notifyListeners("participantDisconnected", data: [
            "roomName": room.name,
            "identity": participant.identity,
            "participantCount": room.remoteParticipants.count
        ])
    }

    public func didSubscribeToVideoTrack(videoTrack: RemoteVideoTrack, publication: RemoteVideoTrackPublication, participant: RemoteParticipant) {
        attachRemoteRendererIfAvailable()
    }

    public func didUnsubscribeFromVideoTrack(videoTrack: RemoteVideoTrack, publication: RemoteVideoTrackPublication, participant: RemoteParticipant) {
        attachRemoteRendererIfAvailable()
    }

    public func didFailToSubscribeToVideoTrack(publication: RemoteVideoTrackPublication, error: Error, participant: RemoteParticipant) {
        attachRemoteRendererIfAvailable()
    }

    private func disconnectCurrentRoom() {
        implementation.currentRoom?.disconnect()
        implementation.updateRoom(nil)
        implementation.setState("disconnected")
        teardownCallUI()
    }

    private func onMain(_ work: () -> Void) {
        if Thread.isMainThread {
            work()
            return
        }
        DispatchQueue.main.sync(execute: work)
    }

    private func installCallOverlayIfNeeded() {
        onMain {
            guard callOverlayView == nil else {
                return
            }
            guard let rootView = bridge?.viewController?.view else {
                return
            }

            let overlay = TwilioCallOverlayView()
            overlay.translatesAutoresizingMaskIntoConstraints = false
            overlay.onToggleMicrophone = { [weak self] in
                self?.toggleMicrophoneFromOverlay()
            }
            overlay.onToggleCamera = { [weak self] in
                self?.toggleCameraFromOverlay()
            }
            overlay.onLeave = { [weak self] in
                self?.disconnectCurrentRoom()
            }

            rootView.addSubview(overlay)
            NSLayoutConstraint.activate([
                overlay.topAnchor.constraint(equalTo: rootView.topAnchor),
                overlay.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
                overlay.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: rootView.trailingAnchor)
            ])

            callOverlayView = overlay
            setWebViewTransparent(true)
        }
    }

    private func teardownCallUI() {
        onMain {
            detachLocalRenderer()
            detachRemoteRenderer()
            callOverlayView?.removeFromSuperview()
            callOverlayView = nil
            setWebViewTransparent(false)
        }
    }

    private func setWebViewTransparent(_ transparent: Bool) {
        onMain {
            guard let webView = bridge?.webView else {
                return
            }

            if transparent {
                if webViewOriginalIsOpaque == nil {
                    webViewOriginalIsOpaque = webView.isOpaque
                }
                if webViewOriginalBackgroundColor == nil {
                    webViewOriginalBackgroundColor = webView.backgroundColor
                }
                if webViewOriginalScrollBackgroundColor == nil {
                    webViewOriginalScrollBackgroundColor = webView.scrollView.backgroundColor
                }
                webView.isOpaque = false
                webView.backgroundColor = .clear
                webView.scrollView.backgroundColor = .clear
                return
            }

            if let originalIsOpaque = webViewOriginalIsOpaque {
                webView.isOpaque = originalIsOpaque
            }
            if let originalBackground = webViewOriginalBackgroundColor {
                webView.backgroundColor = originalBackground
            }
            if let originalScrollBackground = webViewOriginalScrollBackgroundColor {
                webView.scrollView.backgroundColor = originalScrollBackground
            }
            webViewOriginalIsOpaque = nil
            webViewOriginalBackgroundColor = nil
            webViewOriginalScrollBackgroundColor = nil
        }
    }

    private func toggleMicrophoneFromOverlay() {
        let nextEnabled = !(implementation.localAudioTrack?.isEnabled ?? false)
        implementation.setMicrophoneEnabled(nextEnabled)

        if let room = implementation.currentRoom,
           let participant = room.localParticipant,
           let track = implementation.localAudioTrack {
            if nextEnabled {
                _ = participant.publishAudioTrack(track)
            } else {
                participant.unpublishAudioTrack(track)
            }
        }
        updateCallOverlayState()
    }

    private func toggleCameraFromOverlay() {
        let nextEnabled = !(implementation.localVideoTrack?.isEnabled ?? false)
        if nextEnabled, AVCaptureDevice.authorizationStatus(for: .video) != .authorized {
            updateCallOverlayState()
            return
        }
        implementation.setCameraEnabled(nextEnabled)

        if let room = implementation.currentRoom,
           let participant = room.localParticipant,
           let track = implementation.localVideoTrack {
            if nextEnabled {
                _ = participant.publishVideoTrack(track)
            } else {
                participant.unpublishVideoTrack(track)
            }
        }

        attachLocalRendererIfAvailable()
        updateCallOverlayState()
    }

    private func updateCallOverlayState() {
        onMain {
            callOverlayView?.setControls(
                microphoneEnabled: implementation.localAudioTrack?.isEnabled ?? false,
                cameraEnabled: implementation.localVideoTrack?.isEnabled ?? false,
                participantCount: implementation.currentRoom?.remoteParticipants.count ?? 0,
                state: implementation.state
            )
        }
    }

    private func attachLocalRendererIfAvailable() {
        onMain {
            guard let overlay = callOverlayView else {
                return
            }

            let videoEnabled = implementation.localVideoTrack?.isEnabled ?? false
            guard videoEnabled, let localTrack = implementation.localVideoTrack else {
                detachLocalRenderer()
                overlay.showLocalVideo(false)
                return
            }

            if renderedLocalTrack !== localTrack {
                renderedLocalTrack?.removeRenderer(overlay.localVideoView)
                localTrack.addRenderer(overlay.localVideoView)
                renderedLocalTrack = localTrack
            }
            overlay.showLocalVideo(true)
        }
    }

    private func attachRemoteRendererIfAvailable() {
        onMain {
            guard let overlay = callOverlayView else {
                return
            }

            guard let room = implementation.currentRoom else {
                detachRemoteRenderer()
                overlay.showRemoteVideo(false)
                return
            }

            for participant in room.remoteParticipants {
                for publication in participant.remoteVideoTracks {
                    if publication.isTrackSubscribed, let remoteTrack = publication.remoteTrack {
                        if renderedRemoteTrack !== remoteTrack {
                            renderedRemoteTrack?.removeRenderer(overlay.remoteVideoView)
                            remoteTrack.addRenderer(overlay.remoteVideoView)
                            renderedRemoteTrack = remoteTrack
                        }
                        overlay.showRemoteVideo(true)
                        return
                    }
                }
            }

            detachRemoteRenderer()
            overlay.showRemoteVideo(false)
        }
    }

    private func detachLocalRenderer() {
        onMain {
            guard let overlay = callOverlayView else {
                renderedLocalTrack = nil
                return
            }
            renderedLocalTrack?.removeRenderer(overlay.localVideoView)
            renderedLocalTrack = nil
            overlay.showLocalVideo(false)
        }
    }

    private func detachRemoteRenderer() {
        onMain {
            guard let overlay = callOverlayView else {
                renderedRemoteTrack = nil
                return
            }
            renderedRemoteTrack?.removeRenderer(overlay.remoteVideoView)
            renderedRemoteTrack = nil
            overlay.showRemoteVideo(false)
        }
    }
}

private final class TwilioCallOverlayView: UIView {
    let remoteVideoView = VideoView()
    let localVideoView = VideoView()

    var onToggleMicrophone: (() -> Void)?
    var onToggleCamera: (() -> Void)?
    var onLeave: (() -> Void)?

    private let remotePlaceholderLabel = UILabel()
    private let statusLabel = UILabel()
    private let micButton = UIButton(type: .system)
    private let cameraButton = UIButton(type: .system)
    private let leaveButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    func setControls(microphoneEnabled: Bool, cameraEnabled: Bool, participantCount: Int, state: String) {
        micButton.setTitle(microphoneEnabled ? "Mute" : "Unmute", for: .normal)
        cameraButton.setTitle(cameraEnabled ? "Camera Off" : "Camera On", for: .normal)

        let remoteCount = max(participantCount, 0)
        let stateLabel = state.capitalized
        statusLabel.text = "\(stateLabel) • Remote participants: \(remoteCount)"
    }

    func showLocalVideo(_ visible: Bool) {
        localVideoView.isHidden = !visible
    }

    func showRemoteVideo(_ visible: Bool) {
        remoteVideoView.isHidden = !visible
        remotePlaceholderLabel.isHidden = visible
    }

    private func setupUI() {
        backgroundColor = .black

        remoteVideoView.translatesAutoresizingMaskIntoConstraints = false
        remoteVideoView.contentMode = .scaleAspectFill
        remoteVideoView.backgroundColor = UIColor.black.withAlphaComponent(0.7)

        remotePlaceholderLabel.translatesAutoresizingMaskIntoConstraints = false
        remotePlaceholderLabel.text = "Waiting for remote video..."
        remotePlaceholderLabel.textColor = .white
        remotePlaceholderLabel.font = .systemFont(ofSize: 16, weight: .medium)

        localVideoView.translatesAutoresizingMaskIntoConstraints = false
        localVideoView.contentMode = .scaleAspectFill
        localVideoView.backgroundColor = UIColor.darkGray.withAlphaComponent(0.9)
        localVideoView.layer.cornerRadius = 12
        localVideoView.layer.masksToBounds = true

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        statusLabel.numberOfLines = 2

        micButton.translatesAutoresizingMaskIntoConstraints = false
        cameraButton.translatesAutoresizingMaskIntoConstraints = false
        leaveButton.translatesAutoresizingMaskIntoConstraints = false

        configureControlButton(micButton)
        configureControlButton(cameraButton)
        configureControlButton(leaveButton, background: .systemRed)
        leaveButton.setTitle("Leave", for: .normal)

        micButton.addTarget(self, action: #selector(didTapMic), for: .touchUpInside)
        cameraButton.addTarget(self, action: #selector(didTapCamera), for: .touchUpInside)
        leaveButton.addTarget(self, action: #selector(didTapLeave), for: .touchUpInside)

        let controlsStack = UIStackView(arrangedSubviews: [micButton, cameraButton, leaveButton])
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        controlsStack.axis = .horizontal
        controlsStack.alignment = .fill
        controlsStack.distribution = .fillEqually
        controlsStack.spacing = 12

        addSubview(remoteVideoView)
        addSubview(remotePlaceholderLabel)
        addSubview(localVideoView)
        addSubview(statusLabel)
        addSubview(controlsStack)

        NSLayoutConstraint.activate([
            remoteVideoView.topAnchor.constraint(equalTo: topAnchor),
            remoteVideoView.bottomAnchor.constraint(equalTo: bottomAnchor),
            remoteVideoView.leadingAnchor.constraint(equalTo: leadingAnchor),
            remoteVideoView.trailingAnchor.constraint(equalTo: trailingAnchor),

            remotePlaceholderLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            remotePlaceholderLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            localVideoView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 16),
            localVideoView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            localVideoView.widthAnchor.constraint(equalToConstant: 120),
            localVideoView.heightAnchor.constraint(equalToConstant: 180),

            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            statusLabel.bottomAnchor.constraint(equalTo: controlsStack.topAnchor, constant: -12),

            controlsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            controlsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            controlsStack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -20),
            controlsStack.heightAnchor.constraint(equalToConstant: 48)
        ])

        showLocalVideo(false)
        showRemoteVideo(false)
        setControls(microphoneEnabled: false, cameraEnabled: false, participantCount: 0, state: "idle")
    }

    private func configureControlButton(_ button: UIButton, background: UIColor = UIColor.white.withAlphaComponent(0.2)) {
        button.backgroundColor = background
        button.layer.cornerRadius = 10
        button.layer.masksToBounds = true
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
    }

    @objc private func didTapMic() {
        onToggleMicrophone?()
    }

    @objc private func didTapCamera() {
        onToggleCamera?()
    }

    @objc private func didTapLeave() {
        onLeave?()
    }
}
