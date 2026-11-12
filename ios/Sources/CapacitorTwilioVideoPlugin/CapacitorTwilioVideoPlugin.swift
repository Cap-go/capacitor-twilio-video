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

    let implementation = CapacitorTwilioVideo()
    var callOverlayView: TwilioCallOverlayView?
    var renderedLocalTrack: LocalVideoTrack?
    var renderedRemoteTrack: RemoteVideoTrack?
    var webViewOriginalIsOpaque: Bool?
    var webViewOriginalBackgroundColor: UIColor?
    var webViewOriginalScrollBackgroundColor: UIColor?

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

        if enableAudio, !isMicrophonePermissionGranted() {
            call.reject("Microphone permission is required to enable audio.")
            return
        }
        if enableVideo, AVCaptureDevice.authorizationStatus(for: .video) != .authorized {
            call.reject("Camera permission is required to enable video.")
            return
        }

        do {
            try configureAudioSessionForVideoCall()
        } catch {
            call.reject("Unable to configure audio session: \(error.localizedDescription)")
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
        if enabled, !isMicrophonePermissionGranted() {
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
        call.resolve(["granted": isMicrophonePermissionGranted()])
    }

    @objc func requestMicrophonePermission(_ call: CAPPluginCall) {
        requestMicrophonePermission { granted in
            call.resolve(["granted": granted])
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
        clearRemoteParticipantDelegates(in: room)
        implementation.updateRoom(nil)
        implementation.setState("disconnected")
        implementation.endRoomMediaCapture()
        teardownCallUI()
        var payload: [String: Any] = ["roomName": roomName]
        if let error = error {
            payload["error"] = error.localizedDescription
        }
        notifyListeners("roomDisconnected", data: payload)
    }

    public func roomDidFailToConnect(room: Room, error: Error) {
        clearRemoteParticipantDelegates(in: room)
        implementation.updateRoom(nil)
        implementation.setState("disconnected")
        implementation.endRoomMediaCapture()
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
        participant.delegate = nil
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
}
