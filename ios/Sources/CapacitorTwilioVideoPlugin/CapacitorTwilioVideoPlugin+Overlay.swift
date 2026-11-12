import AVFoundation
import Capacitor
import Foundation
import TwilioVideo
import UIKit

extension CapacitorTwilioVideoPlugin {
    func isMicrophonePermissionGranted() -> Bool {
        if #available(iOS 17.0, *) {
            return AVAudioApplication.shared.recordPermission == .granted
        }
        return AVAudioSession.sharedInstance().recordPermission == .granted
    }

    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
            return
        }
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    func configureAudioSessionForVideoCall() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .videoChat, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true)
    }

    func clearRemoteParticipantDelegates(in room: Room) {
        for participant in room.remoteParticipants {
            participant.delegate = nil
        }
    }

    func disconnectCurrentRoom() {
        implementation.currentRoom?.disconnect()
        implementation.updateRoom(nil)
        implementation.setState("disconnected")
        teardownCallUI()
    }

    func onMain(_ work: () -> Void) {
        if Thread.isMainThread {
            work()
            return
        }
        DispatchQueue.main.sync(execute: work)
    }

    func installCallOverlayIfNeeded() {
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

    func teardownCallUI() {
        onMain {
            detachLocalRenderer()
            detachRemoteRenderer()
            callOverlayView?.removeFromSuperview()
            callOverlayView = nil
            setWebViewTransparent(false)
        }
    }

    func setWebViewTransparent(_ transparent: Bool) {
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

    func toggleMicrophoneFromOverlay() {
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

    func toggleCameraFromOverlay() {
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

    func updateCallOverlayState() {
        onMain {
            callOverlayView?.setControls(
                microphoneEnabled: implementation.localAudioTrack?.isEnabled ?? false,
                cameraEnabled: implementation.localVideoTrack?.isEnabled ?? false,
                participantCount: implementation.currentRoom?.remoteParticipants.count ?? 0,
                state: implementation.state
            )
        }
    }

    func attachLocalRendererIfAvailable() {
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

    func attachRemoteRendererIfAvailable() {
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

    func detachLocalRenderer() {
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

    func detachRemoteRenderer() {
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

final class TwilioCallOverlayView: UIView {
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
