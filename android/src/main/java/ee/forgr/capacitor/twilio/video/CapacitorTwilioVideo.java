package ee.forgr.capacitor.twilio.video;

import android.content.Context;
import android.util.Base64;
import com.twilio.video.Camera2Capturer;
import com.twilio.video.CameraCapturer;
import com.twilio.video.LocalAudioTrack;
import com.twilio.video.LocalVideoTrack;
import com.twilio.video.Room;
import com.twilio.video.VideoCapturer;
import java.nio.charset.StandardCharsets;
import org.json.JSONObject;
import tvi.webrtc.Camera1Enumerator;
import tvi.webrtc.Camera2Enumerator;

public class CapacitorTwilioVideo {

    private String accessToken;
    private Room currentRoom;
    private String currentRoomName;
    private String state = "idle";
    private LocalAudioTrack localAudioTrack;
    private LocalVideoTrack localVideoTrack;
    private VideoCapturer videoCapturer;

    public String getAccessToken() {
        return accessToken;
    }

    public Room getCurrentRoom() {
        return currentRoom;
    }

    public String getCurrentRoomName() {
        return currentRoomName;
    }

    public String getState() {
        return state;
    }

    public LocalAudioTrack getLocalAudioTrack() {
        return localAudioTrack;
    }

    public LocalVideoTrack getLocalVideoTrack() {
        return localVideoTrack;
    }

    public void setAccessToken(String token) {
        accessToken = token;
    }

    public void clearSession() {
        if (currentRoom != null) {
            currentRoom.disconnect();
        }
        currentRoom = null;
        currentRoomName = null;
        state = "idle";
        if (localAudioTrack != null) {
            localAudioTrack.release();
            localAudioTrack = null;
        }
        if (localVideoTrack != null) {
            localVideoTrack.release();
            localVideoTrack = null;
        }
        if (videoCapturer != null) {
            try {
                videoCapturer.stopCapture();
            } catch (InterruptedException ignored) {
                Thread.currentThread().interrupt();
            }
            videoCapturer.dispose();
            videoCapturer = null;
        }
        accessToken = null;
    }

    public void updateRoom(Room room) {
        currentRoom = room;
        currentRoomName = room != null ? room.getName() : null;
    }

    public void setState(String nextState) {
        state = nextState;
    }

    public void ensureLocalTracks(Context context, boolean enableAudio, boolean enableVideo) {
        if (enableAudio && localAudioTrack == null) {
            localAudioTrack = LocalAudioTrack.create(context, true);
        }
        if (enableVideo && localVideoTrack == null) {
            ensureVideoTrack(context);
        }
        if (!enableAudio && localAudioTrack != null) {
            localAudioTrack.enable(false);
        }
        if (!enableVideo && localVideoTrack != null) {
            localVideoTrack.enable(false);
        }
    }

    public void setMicrophoneEnabled(Context context, boolean enabled) {
        if (enabled && localAudioTrack == null) {
            localAudioTrack = LocalAudioTrack.create(context, true);
        }
        if (localAudioTrack != null) {
            localAudioTrack.enable(enabled);
        }
    }

    public void setCameraEnabled(Context context, boolean enabled) {
        if (enabled) {
            ensureVideoTrack(context);
        }
        if (localVideoTrack != null) {
            localVideoTrack.enable(enabled);
        }
    }

    public boolean isTokenValid(String token) {
        try {
            JSONObject payload = decodeJWTPayload(token);
            if (payload == null || !payload.has("exp")) {
                return false;
            }
            long exp = payload.getLong("exp");
            long now = System.currentTimeMillis() / 1000L;
            return exp > now;
        } catch (Exception exception) {
            return false;
        }
    }

    public String extractIdentity(String token) {
        try {
            JSONObject payload = decodeJWTPayload(token);
            if (payload == null || !payload.has("grants")) {
                return null;
            }
            JSONObject grants = payload.optJSONObject("grants");
            if (grants == null) {
                return null;
            }
            return grants.optString("identity", null);
        } catch (Exception exception) {
            return null;
        }
    }

    private void ensureVideoTrack(Context context) {
        if (localVideoTrack != null) {
            return;
        }
        VideoCapturer capturer = createVideoCapturer(context);
        if (capturer == null) {
            return;
        }
        videoCapturer = capturer;
        localVideoTrack = LocalVideoTrack.create(context, true, videoCapturer);
    }

    private VideoCapturer createVideoCapturer(Context context) {
        if (Camera2Capturer.isSupported(context)) {
            Camera2Enumerator camera2Enumerator = new Camera2Enumerator(context);
            String[] cameraIds = camera2Enumerator.getDeviceNames();
            for (String cameraId : cameraIds) {
                if (camera2Enumerator.isFrontFacing(cameraId)) {
                    return new Camera2Capturer(context, cameraId);
                }
            }
            for (String cameraId : cameraIds) {
                if (camera2Enumerator.isBackFacing(cameraId)) {
                    return new Camera2Capturer(context, cameraId);
                }
            }
        }

        Camera1Enumerator camera1Enumerator = new Camera1Enumerator();
        for (String cameraId : camera1Enumerator.getDeviceNames()) {
            if (camera1Enumerator.isFrontFacing(cameraId)) {
                return new CameraCapturer(context, cameraId);
            }
        }
        for (String cameraId : camera1Enumerator.getDeviceNames()) {
            if (camera1Enumerator.isBackFacing(cameraId)) {
                return new CameraCapturer(context, cameraId);
            }
        }

        return null;
    }

    private JSONObject decodeJWTPayload(String token) {
        try {
            String[] parts = token.split("\\.");
            if (parts.length != 3) {
                return null;
            }
            byte[] decoded = Base64.decode(parts[1], Base64.URL_SAFE | Base64.NO_WRAP | Base64.NO_PADDING);
            String payload = new String(decoded, StandardCharsets.UTF_8);
            return new JSONObject(payload);
        } catch (Exception exception) {
            return null;
        }
    }

    public String echo(String value) {
        return value;
    }
}
