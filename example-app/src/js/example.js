import { CapacitorUpdater } from '@capgo/capacitor-updater';
import { CapacitorTwilioVideo } from '@capgo/capacitor-twilio-video';
import { Capacitor } from '@capacitor/core';

const outputEl = document.getElementById('output');
const eventsEl = document.getElementById('events');
const statusEl = document.getElementById('status');
const backendUrlEl = document.getElementById('backendUrl');
const identityEl = document.getElementById('identity');
const accessTokenEl = document.getElementById('accessToken');
const roomNameEl = document.getElementById('roomName');

const setOutput = (value) => {
  outputEl.textContent = typeof value === 'string' ? value : JSON.stringify(value, null, 2);
};

const setStatus = (message, isError = false) => {
  statusEl.textContent = message;
  statusEl.classList.toggle('err', isError);
  statusEl.classList.toggle('ok', !isError);
};

const logEvent = (name, payload) => {
  const line = `${new Date().toISOString()} ${name}: ${JSON.stringify(payload)}`;
  eventsEl.textContent = `${line}\n${eventsEl.textContent}`.trim();
};

const runAction = async (action) => {
  try {
    const result = await action();
    setOutput(result);
    setStatus('Action completed.');
    return result;
  } catch (error) {
    const payload = { error: error?.message ?? String(error) };
    setOutput(payload);
    setStatus(payload.error, true);
    return null;
  }
};

const getPlatformEndpoint = () => {
  const platform = Capacitor.getPlatform();
  return platform === 'ios' ? 'ios' : 'android';
};

const fetchAccessToken = async () => {
  const backendUrl = backendUrlEl.value.trim().replace(/\/+$/, '');
  const identity = identityEl.value.trim() || 'alice';
  if (!backendUrl) {
    throw new Error('Backend URL is required.');
  }

  const endpoint = getPlatformEndpoint();
  const tokenUrl = `${backendUrl}/accessToken/${endpoint}?identity=${encodeURIComponent(identity)}`;
  const response = await fetch(tokenUrl);

  if (!response.ok) {
    throw new Error(`Token request failed: ${response.status} ${response.statusText}`);
  }

  const token = (await response.text()).trim();
  if (!token) {
    throw new Error('Backend returned an empty token.');
  }

  accessTokenEl.value = token;
  setOutput({ accessTokenPreview: `${token.slice(0, 24)}...`, identity, endpoint });
  setStatus(`Fetched token for "${identity}" (${endpoint}).`);
  return token;
};

document.getElementById('fetchTokenBtn').addEventListener('click', async () => {
  await runAction(() => fetchAccessToken());
});

document.getElementById('fetchTokenAndLoginBtn').addEventListener('click', async () => {
  await runAction(async () => {
    const token = await fetchAccessToken();
    const result = await CapacitorTwilioVideo.login({ accessToken: token });
    setStatus(`Logged in as "${identityEl.value.trim() || 'alice'}".`);
    return result;
  });
});

document.getElementById('loginBtn').addEventListener('click', async () => {
  await runAction(() =>
    CapacitorTwilioVideo.login({
      accessToken: accessTokenEl.value.trim(),
    }),
  );
});

document.getElementById('isLoggedInBtn').addEventListener('click', async () => {
  await runAction(() => CapacitorTwilioVideo.isLoggedIn());
});

document.getElementById('logoutBtn').addEventListener('click', async () => {
  await runAction(() => CapacitorTwilioVideo.logout());
});

document.getElementById('checkMicBtn').addEventListener('click', async () => {
  await runAction(() => CapacitorTwilioVideo.checkMicrophonePermission());
});

document.getElementById('requestMicBtn').addEventListener('click', async () => {
  await runAction(() => CapacitorTwilioVideo.requestMicrophonePermission());
});

document.getElementById('checkCameraBtn').addEventListener('click', async () => {
  await runAction(() => CapacitorTwilioVideo.checkCameraPermission());
});

document.getElementById('requestCameraBtn').addEventListener('click', async () => {
  await runAction(() => CapacitorTwilioVideo.requestCameraPermission());
});

document.getElementById('joinRoomBtn').addEventListener('click', async () => {
  await runAction(() =>
    CapacitorTwilioVideo.joinRoom({
      roomName: roomNameEl.value.trim(),
      enableAudio: true,
      enableVideo: false,
    }),
  );
});

document.getElementById('leaveRoomBtn').addEventListener('click', async () => {
  await runAction(() => CapacitorTwilioVideo.leaveRoom());
});

document.getElementById('statusBtn').addEventListener('click', async () => {
  await runAction(() => CapacitorTwilioVideo.getCallStatus());
});

document.getElementById('micOnBtn').addEventListener('click', async () => {
  await runAction(() => CapacitorTwilioVideo.setMicrophoneEnabled({ enabled: true }));
});

document.getElementById('micOffBtn').addEventListener('click', async () => {
  await runAction(() => CapacitorTwilioVideo.setMicrophoneEnabled({ enabled: false }));
});

document.getElementById('cameraOnBtn').addEventListener('click', async () => {
  await runAction(() => CapacitorTwilioVideo.setCameraEnabled({ enabled: true }));
});

document.getElementById('cameraOffBtn').addEventListener('click', async () => {
  await runAction(() => CapacitorTwilioVideo.setCameraEnabled({ enabled: false }));
});

const wireEvent = async (eventName) => {
  await CapacitorTwilioVideo.addListener(eventName, (payload) => {
    logEvent(eventName, payload);
  });
};

await wireEvent('roomConnected');
await wireEvent('roomDisconnected');
await wireEvent('participantConnected');
await wireEvent('participantDisconnected');
await wireEvent('roomReconnecting');
await wireEvent('roomReconnected');

setStatus('Ready.');

if (Capacitor.isNativePlatform()) {
  CapacitorUpdater.notifyAppReady().catch((error) => {
    console.error('Capgo notifyAppReady failed', error);
  });
}
