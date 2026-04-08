/**
 * Capacitor API for joining Twilio Video rooms with a native in-app call surface.
 */
export interface CapacitorTwilioVideoPlugin {
  /**
   * Store and validate a Twilio Video access token minted by your backend.
   */
  login(options: { accessToken: string }): Promise<{ success: boolean }>;

  /**
   * Clear the cached access token and leave the active room.
   */
  logout(): Promise<{ success: boolean }>;

  /**
   * Check whether a valid Twilio token is currently cached on the device.
   */
  isLoggedIn(): Promise<{ isLoggedIn: boolean; hasValidToken: boolean; identity?: string }>;

  /**
   * Join a Twilio room and present the plugin's native in-app call overlay.
   */
  joinRoom(options: { roomName: string; enableAudio?: boolean; enableVideo?: boolean }): Promise<{ success: boolean }>;

  /**
   * Leave the current room if connected.
   */
  leaveRoom(): Promise<{ success: boolean }>;

  /**
   * Enable/disable local microphone publishing.
   */
  setMicrophoneEnabled(options: { enabled: boolean }): Promise<{ success: boolean; enabled: boolean }>;

  /**
   * Enable/disable local camera publishing.
   */
  setCameraEnabled(options: { enabled: boolean }): Promise<{ success: boolean; enabled: boolean }>;

  /**
   * Return the current room name, media state, and participant count.
   */
  getCallStatus(): Promise<{
    hasActiveCall: boolean;
    callState: 'idle' | 'connecting' | 'connected' | 'reconnecting' | 'disconnected';
    roomName?: string;
    participantCount: number;
    isMicrophoneEnabled: boolean;
    isCameraEnabled: boolean;
  }>;

  /**
   * Check microphone permission state.
   */
  checkMicrophonePermission(): Promise<{ granted: boolean }>;

  /**
   * Request microphone permission.
   */
  requestMicrophonePermission(): Promise<{ granted: boolean }>;

  /**
   * Check camera permission state.
   */
  checkCameraPermission(): Promise<{ granted: boolean }>;

  /**
   * Request camera permission.
   */
  requestCameraPermission(): Promise<{ granted: boolean }>;

  /**
   * Listen for room connected events.
   */
  addListener(
    eventName: 'roomConnected',
    listenerFunc: (data: { roomName: string; participantCount: number }) => void,
  ): Promise<PluginListenerHandle>;

  /**
   * Listen for room disconnected events.
   */
  addListener(
    eventName: 'roomDisconnected',
    listenerFunc: (data: { roomName?: string; error?: string }) => void,
  ): Promise<PluginListenerHandle>;

  /**
   * Listen for participant connected events.
   */
  addListener(
    eventName: 'participantConnected',
    listenerFunc: (data: { roomName: string; identity: string; participantCount: number }) => void,
  ): Promise<PluginListenerHandle>;

  /**
   * Listen for participant disconnected events.
   */
  addListener(
    eventName: 'participantDisconnected',
    listenerFunc: (data: { roomName: string; identity: string; participantCount: number }) => void,
  ): Promise<PluginListenerHandle>;

  /**
   * Listen for reconnection start events.
   */
  addListener(
    eventName: 'roomReconnecting',
    listenerFunc: (data: { roomName: string; error?: string }) => void,
  ): Promise<PluginListenerHandle>;

  /**
   * Listen for reconnection success events.
   */
  addListener(
    eventName: 'roomReconnected',
    listenerFunc: (data: { roomName: string }) => void,
  ): Promise<PluginListenerHandle>;

  /**
   * Remove every listener registered through this plugin instance.
   */
  removeAllListeners(): Promise<void>;
}

export interface PluginListenerHandle {
  remove: () => Promise<void>;
}
