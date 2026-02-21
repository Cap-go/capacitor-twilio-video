package ee.forgr.capacitor.twilio.video;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.drawable.Drawable;
import android.os.Looper;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.WebView;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.getcapacitor.JSObject;
import com.getcapacitor.PermissionState;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.getcapacitor.annotation.Permission;
import com.getcapacitor.annotation.PermissionCallback;
import com.twilio.video.ConnectOptions;
import com.twilio.video.LocalAudioTrack;
import com.twilio.video.LocalParticipant;
import com.twilio.video.LocalVideoTrack;
import com.twilio.video.RemoteAudioTrack;
import com.twilio.video.RemoteAudioTrackPublication;
import com.twilio.video.RemoteDataTrack;
import com.twilio.video.RemoteDataTrackPublication;
import com.twilio.video.RemoteParticipant;
import com.twilio.video.RemoteVideoTrack;
import com.twilio.video.RemoteVideoTrackPublication;
import com.twilio.video.Room;
import com.twilio.video.TwilioException;
import com.twilio.video.Video;
import com.twilio.video.VideoTextureView;
import com.twilio.video.VideoView;

import java.util.Collections;
import java.util.Locale;

@CapacitorPlugin(
    name = "CapacitorTwilioVideo",
    permissions = {
        @Permission(alias = "microphone", strings = { Manifest.permission.RECORD_AUDIO }),
        @Permission(alias = "camera", strings = { Manifest.permission.CAMERA })
    }
)
public class CapacitorTwilioVideoPlugin extends Plugin {
    private static final String PREFS_NAME = "CapacitorTwilioVideoPrefs";
    private static final String ACCESS_TOKEN_KEY = "CapacitorTwilioVideoCachedAccessToken";

    private final CapacitorTwilioVideo implementation = new CapacitorTwilioVideo();

    private FrameLayout callOverlayView;
    private VideoView remoteVideoView;
    private VideoTextureView localVideoView;
    private TextView remotePlaceholderLabel;
    private TextView statusLabel;
    private Button micButton;
    private Button cameraButton;

    private LocalVideoTrack renderedLocalVideoTrack;
    private RemoteVideoTrack renderedRemoteVideoTrack;

    private Drawable webViewOriginalBackground;
    private boolean webViewTransparencyApplied = false;

    private final Room.Listener roomListener = new Room.Listener() {
        @Override
        public void onConnected(Room room) {
            implementation.updateRoom(room);
            implementation.setState("connected");
            for (RemoteParticipant participant : room.getRemoteParticipants()) {
                participant.setListener(remoteParticipantListener);
            }
            installCallOverlayIfNeeded();
            attachLocalRendererIfAvailable();
            attachRemoteRendererIfAvailable();
            updateCallOverlayState();
            JSObject payload = new JSObject();
            payload.put("roomName", room.getName());
            payload.put("participantCount", room.getRemoteParticipants().size());
            notifyListeners("roomConnected", payload);
        }

        @Override
        public void onConnectFailure(Room room, TwilioException twilioException) {
            String roomName = room != null ? room.getName() : implementation.getCurrentRoomName();
            implementation.updateRoom(null);
            implementation.setState("disconnected");
            teardownCallUI();
            JSObject payload = new JSObject();
            if (roomName != null) {
                payload.put("roomName", roomName);
            }
            if (twilioException != null) {
                payload.put("error", twilioException.getMessage());
            }
            notifyListeners("roomDisconnected", payload);
        }

        @Override
        public void onReconnecting(Room room, TwilioException twilioException) {
            implementation.setState("reconnecting");
            updateCallOverlayState();
            JSObject payload = new JSObject();
            payload.put("roomName", room.getName());
            if (twilioException != null) {
                payload.put("error", twilioException.getMessage());
            }
            notifyListeners("roomReconnecting", payload);
        }

        @Override
        public void onReconnected(Room room) {
            implementation.setState("connected");
            for (RemoteParticipant participant : room.getRemoteParticipants()) {
                participant.setListener(remoteParticipantListener);
            }
            attachRemoteRendererIfAvailable();
            updateCallOverlayState();
            JSObject payload = new JSObject();
            payload.put("roomName", room.getName());
            notifyListeners("roomReconnected", payload);
        }

        @Override
        public void onDisconnected(Room room, TwilioException twilioException) {
            String roomName = room != null ? room.getName() : implementation.getCurrentRoomName();
            implementation.updateRoom(null);
            implementation.setState("disconnected");
            teardownCallUI();
            JSObject payload = new JSObject();
            if (roomName != null) {
                payload.put("roomName", roomName);
            }
            if (twilioException != null) {
                payload.put("error", twilioException.getMessage());
            }
            notifyListeners("roomDisconnected", payload);
        }

        @Override
        public void onParticipantConnected(Room room, RemoteParticipant remoteParticipant) {
            remoteParticipant.setListener(remoteParticipantListener);
            attachRemoteRendererIfAvailable();
            updateCallOverlayState();
            JSObject payload = new JSObject();
            payload.put("roomName", room.getName());
            payload.put("identity", remoteParticipant.getIdentity());
            payload.put("participantCount", room.getRemoteParticipants().size());
            notifyListeners("participantConnected", payload);
        }

        @Override
        public void onParticipantDisconnected(Room room, RemoteParticipant remoteParticipant) {
            attachRemoteRendererIfAvailable();
            updateCallOverlayState();
            JSObject payload = new JSObject();
            payload.put("roomName", room.getName());
            payload.put("identity", remoteParticipant.getIdentity());
            payload.put("participantCount", room.getRemoteParticipants().size());
            notifyListeners("participantDisconnected", payload);
        }

        @Override
        public void onRecordingStarted(Room room) {}

        @Override
        public void onRecordingStopped(Room room) {}
    };

    private final RemoteParticipant.Listener remoteParticipantListener = new RemoteParticipant.Listener() {
        @Override
        public void onAudioTrackPublished(RemoteParticipant remoteParticipant, RemoteAudioTrackPublication remoteAudioTrackPublication) {}

        @Override
        public void onAudioTrackUnpublished(RemoteParticipant remoteParticipant, RemoteAudioTrackPublication remoteAudioTrackPublication) {}

        @Override
        public void onDataTrackPublished(RemoteParticipant remoteParticipant, RemoteDataTrackPublication remoteDataTrackPublication) {}

        @Override
        public void onDataTrackUnpublished(RemoteParticipant remoteParticipant, RemoteDataTrackPublication remoteDataTrackPublication) {}

        @Override
        public void onVideoTrackPublished(RemoteParticipant remoteParticipant, RemoteVideoTrackPublication remoteVideoTrackPublication) {}

        @Override
        public void onVideoTrackUnpublished(RemoteParticipant remoteParticipant, RemoteVideoTrackPublication remoteVideoTrackPublication) {}

        @Override
        public void onAudioTrackSubscribed(RemoteParticipant remoteParticipant, RemoteAudioTrackPublication remoteAudioTrackPublication, RemoteAudioTrack remoteAudioTrack) {}

        @Override
        public void onAudioTrackUnsubscribed(RemoteParticipant remoteParticipant, RemoteAudioTrackPublication remoteAudioTrackPublication, RemoteAudioTrack remoteAudioTrack) {}

        @Override
        public void onAudioTrackSubscriptionFailed(RemoteParticipant remoteParticipant, RemoteAudioTrackPublication remoteAudioTrackPublication, TwilioException twilioException) {}

        @Override
        public void onDataTrackSubscribed(RemoteParticipant remoteParticipant, RemoteDataTrackPublication remoteDataTrackPublication, RemoteDataTrack remoteDataTrack) {}

        @Override
        public void onDataTrackUnsubscribed(RemoteParticipant remoteParticipant, RemoteDataTrackPublication remoteDataTrackPublication, RemoteDataTrack remoteDataTrack) {}

        @Override
        public void onDataTrackSubscriptionFailed(RemoteParticipant remoteParticipant, RemoteDataTrackPublication remoteDataTrackPublication, TwilioException twilioException) {}

        @Override
        public void onVideoTrackSubscribed(RemoteParticipant remoteParticipant, RemoteVideoTrackPublication remoteVideoTrackPublication, RemoteVideoTrack remoteVideoTrack) {
            attachRemoteRendererIfAvailable();
        }

        @Override
        public void onVideoTrackUnsubscribed(RemoteParticipant remoteParticipant, RemoteVideoTrackPublication remoteVideoTrackPublication, RemoteVideoTrack remoteVideoTrack) {
            attachRemoteRendererIfAvailable();
        }

        @Override
        public void onVideoTrackSubscriptionFailed(RemoteParticipant remoteParticipant, RemoteVideoTrackPublication remoteVideoTrackPublication, TwilioException twilioException) {
            attachRemoteRendererIfAvailable();
        }

        @Override
        public void onAudioTrackEnabled(RemoteParticipant remoteParticipant, RemoteAudioTrackPublication remoteAudioTrackPublication) {}

        @Override
        public void onAudioTrackDisabled(RemoteParticipant remoteParticipant, RemoteAudioTrackPublication remoteAudioTrackPublication) {}

        @Override
        public void onVideoTrackEnabled(RemoteParticipant remoteParticipant, RemoteVideoTrackPublication remoteVideoTrackPublication) {
            attachRemoteRendererIfAvailable();
        }

        @Override
        public void onVideoTrackDisabled(RemoteParticipant remoteParticipant, RemoteVideoTrackPublication remoteVideoTrackPublication) {
            attachRemoteRendererIfAvailable();
        }
    };

    @Override
    public void load() {
        super.load();
        SharedPreferences preferences = getContext().getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        String cachedToken = preferences.getString(ACCESS_TOKEN_KEY, null);
        if (cachedToken != null && implementation.isTokenValid(cachedToken)) {
            implementation.setAccessToken(cachedToken);
        } else {
            preferences.edit().remove(ACCESS_TOKEN_KEY).apply();
        }
    }

    @PluginMethod
    public void login(PluginCall call) {
        String accessToken = call.getString("accessToken");
        if (accessToken == null || accessToken.isEmpty()) {
            call.reject("accessToken is required");
            return;
        }
        if (!implementation.isTokenValid(accessToken)) {
            call.reject("Invalid or expired access token");
            return;
        }

        implementation.setAccessToken(accessToken);
        SharedPreferences preferences = getContext().getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        preferences.edit().putString(ACCESS_TOKEN_KEY, accessToken).apply();

        JSObject result = new JSObject();
        result.put("success", true);
        call.resolve(result);
    }

    @PluginMethod
    public void logout(PluginCall call) {
        disconnectCurrentRoom();
        implementation.clearSession();
        SharedPreferences preferences = getContext().getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        preferences.edit().remove(ACCESS_TOKEN_KEY).apply();

        JSObject result = new JSObject();
        result.put("success", true);
        call.resolve(result);
    }

    @PluginMethod
    public void isLoggedIn(PluginCall call) {
        String accessToken = implementation.getAccessToken();
        if (accessToken == null || !implementation.isTokenValid(accessToken)) {
            JSObject result = new JSObject();
            result.put("isLoggedIn", false);
            result.put("hasValidToken", false);
            call.resolve(result);
            return;
        }

        JSObject result = new JSObject();
        result.put("isLoggedIn", true);
        result.put("hasValidToken", true);
        String identity = implementation.extractIdentity(accessToken);
        if (identity != null) {
            result.put("identity", identity);
        }
        call.resolve(result);
    }

    @PluginMethod
    public void joinRoom(PluginCall call) {
        String roomName = call.getString("roomName");
        if (roomName == null || roomName.isEmpty()) {
            call.reject("roomName is required");
            return;
        }

        String accessToken = implementation.getAccessToken();
        if (accessToken == null || !implementation.isTokenValid(accessToken)) {
            call.reject("No valid access token. Please call login() first.");
            return;
        }

        if (implementation.getCurrentRoom() != null) {
            call.reject("Already connected to a room. Leave current room first.");
            return;
        }

        boolean enableAudio = call.getBoolean("enableAudio", true);
        boolean enableVideo = call.getBoolean("enableVideo", false);

        if (enableAudio && !hasMicrophonePermission()) {
            call.reject("Microphone permission is required to enable audio.");
            return;
        }
        if (enableVideo && !hasCameraPermission()) {
            call.reject("Camera permission is required to enable video.");
            return;
        }

        Context context = getContext();
        if (context == null) {
            call.reject("Android context is unavailable");
            return;
        }

        implementation.ensureLocalTracks(context, enableAudio, enableVideo);
        if (enableVideo && implementation.getLocalVideoTrack() == null) {
            call.reject("Unable to initialize camera video track.");
            return;
        }
        implementation.setState("connecting");
        installCallOverlayIfNeeded();
        updateCallOverlayState();
        attachLocalRendererIfAvailable();

        ConnectOptions.Builder builder = new ConnectOptions.Builder(accessToken).roomName(roomName);
        if (enableAudio && implementation.getLocalAudioTrack() != null) {
            builder.audioTracks(Collections.singletonList(implementation.getLocalAudioTrack()));
        }
        if (enableVideo && implementation.getLocalVideoTrack() != null) {
            builder.videoTracks(Collections.singletonList(implementation.getLocalVideoTrack()));
        }

        Room room = Video.connect(context, builder.build(), roomListener);
        implementation.updateRoom(room);

        JSObject result = new JSObject();
        result.put("success", true);
        call.resolve(result);
    }

    @PluginMethod
    public void leaveRoom(PluginCall call) {
        disconnectCurrentRoom();
        JSObject result = new JSObject();
        result.put("success", true);
        call.resolve(result);
    }

    @PluginMethod
    public void setMicrophoneEnabled(PluginCall call) {
        Boolean enabled = call.getBoolean("enabled");
        if (enabled == null) {
            call.reject("enabled is required");
            return;
        }
        if (enabled && !hasMicrophonePermission()) {
            call.reject("Microphone permission is required.");
            return;
        }

        setMicrophoneEnabledInternal(enabled);

        JSObject result = new JSObject();
        result.put("success", true);
        result.put("enabled", enabled);
        call.resolve(result);
    }

    @PluginMethod
    public void setCameraEnabled(PluginCall call) {
        Boolean enabled = call.getBoolean("enabled");
        if (enabled == null) {
            call.reject("enabled is required");
            return;
        }
        if (enabled && !hasCameraPermission()) {
            call.reject("Camera permission is required.");
            return;
        }

        if (enabled) {
            Context context = getContext();
            if (context == null) {
                call.reject("Android context is unavailable");
                return;
            }
            implementation.ensureLocalTracks(context, implementation.getLocalAudioTrack() != null, true);
            if (implementation.getLocalVideoTrack() == null) {
                call.reject("Unable to initialize camera video track.");
                return;
            }
        }

        setCameraEnabledInternal(enabled);

        JSObject result = new JSObject();
        result.put("success", true);
        result.put("enabled", enabled);
        call.resolve(result);
    }

    @PluginMethod
    public void getCallStatus(PluginCall call) {
        boolean isConnected = implementation.getCurrentRoom() != null &&
            ("connecting".equals(implementation.getState()) ||
                "connected".equals(implementation.getState()) ||
                "reconnecting".equals(implementation.getState()));

        JSObject result = new JSObject();
        result.put("hasActiveCall", isConnected);
        result.put("callState", implementation.getState());
        result.put("participantCount", implementation.getCurrentRoom() != null ? implementation.getCurrentRoom().getRemoteParticipants().size() : 0);
        result.put("isMicrophoneEnabled", implementation.getLocalAudioTrack() != null && implementation.getLocalAudioTrack().isEnabled());
        result.put("isCameraEnabled", implementation.getLocalVideoTrack() != null && implementation.getLocalVideoTrack().isEnabled());
        if (implementation.getCurrentRoomName() != null) {
            result.put("roomName", implementation.getCurrentRoomName());
        }
        call.resolve(result);
    }

    @PluginMethod
    public void checkMicrophonePermission(PluginCall call) {
        JSObject result = new JSObject();
        result.put("granted", hasMicrophonePermission());
        call.resolve(result);
    }

    @PluginMethod
    public void requestMicrophonePermission(PluginCall call) {
        if (hasMicrophonePermission()) {
            JSObject result = new JSObject();
            result.put("granted", true);
            call.resolve(result);
            return;
        }
        requestPermissionForAlias("microphone", call, "microphonePermissionCallback");
    }

    @PermissionCallback
    private void microphonePermissionCallback(PluginCall call) {
        JSObject result = new JSObject();
        result.put("granted", hasMicrophonePermission());
        call.resolve(result);
    }

    @PluginMethod
    public void checkCameraPermission(PluginCall call) {
        JSObject result = new JSObject();
        result.put("granted", hasCameraPermission());
        call.resolve(result);
    }

    @PluginMethod
    public void requestCameraPermission(PluginCall call) {
        if (hasCameraPermission()) {
            JSObject result = new JSObject();
            result.put("granted", true);
            call.resolve(result);
            return;
        }
        requestPermissionForAlias("camera", call, "cameraPermissionCallback");
    }

    @PermissionCallback
    private void cameraPermissionCallback(PluginCall call) {
        JSObject result = new JSObject();
        result.put("granted", hasCameraPermission());
        call.resolve(result);
    }

    @Override
    protected void handleOnDestroy() {
        disconnectCurrentRoom();
        super.handleOnDestroy();
    }

    @PluginMethod
    public void echo(PluginCall call) {
        String value = call.getString("value", "");
        JSObject result = new JSObject();
        result.put("value", implementation.echo(value));
        call.resolve(result);
    }

    private boolean hasMicrophonePermission() {
        return getPermissionState("microphone") == PermissionState.GRANTED;
    }

    private boolean hasCameraPermission() {
        return getPermissionState("camera") == PermissionState.GRANTED;
    }

    private void setMicrophoneEnabledInternal(boolean enabled) {
        Context context = getContext();
        if (context == null) {
            return;
        }
        implementation.setMicrophoneEnabled(context, enabled);
        Room room = implementation.getCurrentRoom();
        LocalParticipant localParticipant = room != null ? room.getLocalParticipant() : null;
        LocalAudioTrack localAudioTrack = implementation.getLocalAudioTrack();
        if (localParticipant != null && localAudioTrack != null) {
            if (enabled) {
                localParticipant.publishTrack(localAudioTrack);
            } else {
                localParticipant.unpublishTrack(localAudioTrack);
            }
        }
        updateCallOverlayState();
    }

    private void setCameraEnabledInternal(boolean enabled) {
        Context context = getContext();
        if (context == null) {
            return;
        }
        implementation.setCameraEnabled(context, enabled);
        Room room = implementation.getCurrentRoom();
        LocalParticipant localParticipant = room != null ? room.getLocalParticipant() : null;
        LocalVideoTrack localVideoTrack = implementation.getLocalVideoTrack();
        if (localParticipant != null && localVideoTrack != null) {
            if (enabled) {
                localParticipant.publishTrack(localVideoTrack);
            } else {
                localParticipant.unpublishTrack(localVideoTrack);
            }
        }
        attachLocalRendererIfAvailable();
        updateCallOverlayState();
    }

    private void disconnectCurrentRoom() {
        Room room = implementation.getCurrentRoom();
        if (room != null) {
            room.disconnect();
        }
        implementation.updateRoom(null);
        implementation.setState("disconnected");
        teardownCallUI();
    }

    private void runOnMain(Runnable action) {
        Activity activity = getActivity();
        if (activity == null) {
            return;
        }
        if (Looper.myLooper() == Looper.getMainLooper()) {
            action.run();
        } else {
            activity.runOnUiThread(action);
        }
    }

    private void installCallOverlayIfNeeded() {
        runOnMain(() -> {
            if (callOverlayView != null) {
                return;
            }
            Activity activity = getActivity();
            if (activity == null) {
                return;
            }

            ViewGroup root = activity.findViewById(android.R.id.content);
            if (root == null) {
                return;
            }

            FrameLayout overlay = new FrameLayout(activity);
            overlay.setLayoutParams(new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
            overlay.setBackgroundColor(Color.BLACK);
            overlay.setClickable(true);

            VideoView remoteView = new VideoView(activity);
            remoteView.setLayoutParams(new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
            remoteView.setVisibility(View.GONE);
            overlay.addView(remoteView);

            TextView placeholder = new TextView(activity);
            FrameLayout.LayoutParams placeholderParams = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            placeholderParams.gravity = Gravity.CENTER;
            placeholder.setLayoutParams(placeholderParams);
            placeholder.setText("Waiting for remote video...");
            placeholder.setTextColor(Color.WHITE);
            overlay.addView(placeholder);

            VideoTextureView localView = new VideoTextureView(activity);
            FrameLayout.LayoutParams localParams = new FrameLayout.LayoutParams(dp(120), dp(180));
            localParams.gravity = Gravity.TOP | Gravity.END;
            localParams.topMargin = dp(16);
            localParams.rightMargin = dp(16);
            localView.setLayoutParams(localParams);
            localView.setVisibility(View.GONE);
            localView.setOpaque(false);
            localView.setMirror(true);
            overlay.addView(localView);

            TextView stateLabel = new TextView(activity);
            FrameLayout.LayoutParams stateParams = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            stateParams.gravity = Gravity.BOTTOM;
            stateParams.leftMargin = dp(16);
            stateParams.rightMargin = dp(16);
            stateParams.bottomMargin = dp(88);
            stateLabel.setLayoutParams(stateParams);
            stateLabel.setTextColor(Color.WHITE);
            overlay.addView(stateLabel);

            LinearLayout controls = new LinearLayout(activity);
            controls.setOrientation(LinearLayout.HORIZONTAL);
            controls.setGravity(Gravity.CENTER_VERTICAL);
            controls.setWeightSum(3f);
            FrameLayout.LayoutParams controlsParams = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(48));
            controlsParams.gravity = Gravity.BOTTOM;
            controlsParams.leftMargin = dp(16);
            controlsParams.rightMargin = dp(16);
            controlsParams.bottomMargin = dp(20);
            controls.setLayoutParams(controlsParams);

            Button mic = createControlButton(activity);
            Button camera = createControlButton(activity);
            Button leave = createControlButton(activity);
            leave.setBackgroundColor(Color.parseColor("#D32F2F"));
            leave.setText("Leave");

            mic.setOnClickListener(view -> toggleMicrophoneFromOverlay());
            camera.setOnClickListener(view -> toggleCameraFromOverlay());
            leave.setOnClickListener(view -> disconnectCurrentRoom());

            controls.addView(mic);
            controls.addView(camera);
            controls.addView(leave);
            overlay.addView(controls);

            callOverlayView = overlay;
            remoteVideoView = remoteView;
            localVideoView = localView;
            remotePlaceholderLabel = placeholder;
            statusLabel = stateLabel;
            micButton = mic;
            cameraButton = camera;

            root.addView(overlay);
            setWebViewTransparent(true);
        });
    }

    private Button createControlButton(Context context) {
        Button button = new Button(context);
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1f);
        params.leftMargin = dp(6);
        params.rightMargin = dp(6);
        button.setLayoutParams(params);
        button.setAllCaps(false);
        button.setTextColor(Color.WHITE);
        button.setBackgroundColor(Color.parseColor("#33FFFFFF"));
        return button;
    }

    private int dp(int value) {
        Context context = getContext();
        if (context == null) {
            return value;
        }
        float density = context.getResources().getDisplayMetrics().density;
        return Math.round(value * density);
    }

    private void teardownCallUI() {
        runOnMain(() -> {
            detachLocalRenderer();
            detachRemoteRenderer();
            if (callOverlayView != null) {
                ViewGroup parent = (ViewGroup) callOverlayView.getParent();
                if (parent != null) {
                    parent.removeView(callOverlayView);
                }
            }
            callOverlayView = null;
            remoteVideoView = null;
            localVideoView = null;
            remotePlaceholderLabel = null;
            statusLabel = null;
            micButton = null;
            cameraButton = null;
            setWebViewTransparent(false);
        });
    }

    private void setWebViewTransparent(boolean transparent) {
        runOnMain(() -> {
            WebView webView = bridge != null ? bridge.getWebView() : null;
            if (webView == null) {
                return;
            }

            if (transparent) {
                if (!webViewTransparencyApplied) {
                    webViewOriginalBackground = webView.getBackground();
                    webViewTransparencyApplied = true;
                }
                webView.setBackgroundColor(Color.TRANSPARENT);
                webView.evaluateJavascript("document.documentElement.style.background='transparent';document.body.style.background='transparent';", null);
                return;
            }

            if (webViewTransparencyApplied) {
                if (webViewOriginalBackground != null) {
                    webView.setBackground(webViewOriginalBackground);
                } else {
                    webView.setBackgroundColor(Color.WHITE);
                }
                webView.evaluateJavascript("document.documentElement.style.background='';document.body.style.background='';", null);
            }
            webViewOriginalBackground = null;
            webViewTransparencyApplied = false;
        });
    }

    private void toggleMicrophoneFromOverlay() {
        boolean nextEnabled = !(implementation.getLocalAudioTrack() != null && implementation.getLocalAudioTrack().isEnabled());
        setMicrophoneEnabledInternal(nextEnabled);
    }

    private void toggleCameraFromOverlay() {
        boolean nextEnabled = !(implementation.getLocalVideoTrack() != null && implementation.getLocalVideoTrack().isEnabled());
        if (nextEnabled && !hasCameraPermission()) {
            updateCallOverlayState();
            return;
        }
        setCameraEnabledInternal(nextEnabled);
    }

    private void updateCallOverlayState() {
        runOnMain(() -> {
            if (statusLabel == null || micButton == null || cameraButton == null) {
                return;
            }
            boolean micEnabled = implementation.getLocalAudioTrack() != null && implementation.getLocalAudioTrack().isEnabled();
            boolean cameraEnabled = implementation.getLocalVideoTrack() != null && implementation.getLocalVideoTrack().isEnabled();
            int participantCount = implementation.getCurrentRoom() != null ? implementation.getCurrentRoom().getRemoteParticipants().size() : 0;

            micButton.setText(micEnabled ? "Mute" : "Unmute");
            cameraButton.setText(cameraEnabled ? "Camera Off" : "Camera On");

            String state = implementation.getState();
            if (state != null && !state.isEmpty()) {
                String normalizedState = state.substring(0, 1).toUpperCase(Locale.US) + state.substring(1);
                statusLabel.setText(normalizedState + " • Remote participants: " + participantCount);
            } else {
                statusLabel.setText("Idle • Remote participants: " + participantCount);
            }
        });
    }

    private void attachLocalRendererIfAvailable() {
        runOnMain(() -> {
            if (localVideoView == null) {
                return;
            }
            LocalVideoTrack localTrack = implementation.getLocalVideoTrack();
            boolean localEnabled = localTrack != null && localTrack.isEnabled();
            if (!localEnabled) {
                detachLocalRenderer();
                localVideoView.setVisibility(View.GONE);
                return;
            }

            if (renderedLocalVideoTrack != localTrack) {
                if (renderedLocalVideoTrack != null) {
                    renderedLocalVideoTrack.removeSink(localVideoView);
                }
                localTrack.addSink(localVideoView);
                renderedLocalVideoTrack = localTrack;
            }
            localVideoView.bringToFront();
            localVideoView.setVisibility(View.VISIBLE);
        });
    }

    private void attachRemoteRendererIfAvailable() {
        runOnMain(() -> {
            if (remoteVideoView == null) {
                return;
            }

            Room room = implementation.getCurrentRoom();
            if (room == null) {
                detachRemoteRenderer();
                remoteVideoView.setVisibility(View.GONE);
                if (remotePlaceholderLabel != null) {
                    remotePlaceholderLabel.setVisibility(View.VISIBLE);
                }
                return;
            }

            RemoteVideoTrack firstSubscribedTrack = null;
            for (RemoteParticipant participant : room.getRemoteParticipants()) {
                for (RemoteVideoTrackPublication publication : participant.getRemoteVideoTracks()) {
                    if (publication.isTrackSubscribed() && publication.getRemoteVideoTrack() != null) {
                        firstSubscribedTrack = publication.getRemoteVideoTrack();
                        break;
                    }
                }
                if (firstSubscribedTrack != null) {
                    break;
                }
            }

            if (firstSubscribedTrack == null) {
                detachRemoteRenderer();
                remoteVideoView.setVisibility(View.GONE);
                if (remotePlaceholderLabel != null) {
                    remotePlaceholderLabel.setVisibility(View.VISIBLE);
                }
                return;
            }

            if (renderedRemoteVideoTrack != firstSubscribedTrack) {
                if (renderedRemoteVideoTrack != null) {
                    renderedRemoteVideoTrack.removeSink(remoteVideoView);
                }
                firstSubscribedTrack.addSink(remoteVideoView);
                renderedRemoteVideoTrack = firstSubscribedTrack;
            }

            remoteVideoView.setVisibility(View.VISIBLE);
            if (remotePlaceholderLabel != null) {
                remotePlaceholderLabel.setVisibility(View.GONE);
            }
        });
    }

    private void detachLocalRenderer() {
        runOnMain(() -> {
            if (localVideoView != null && renderedLocalVideoTrack != null) {
                renderedLocalVideoTrack.removeSink(localVideoView);
            }
            renderedLocalVideoTrack = null;
        });
    }

    private void detachRemoteRenderer() {
        runOnMain(() -> {
            if (remoteVideoView != null && renderedRemoteVideoTrack != null) {
                renderedRemoteVideoTrack.removeSink(remoteVideoView);
            }
            renderedRemoteVideoTrack = null;
        });
    }
}
