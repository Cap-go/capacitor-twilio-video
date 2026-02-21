import { WebPlugin } from '@capacitor/core';

import type { CapacitorTwilioVideoPlugin } from './definitions';

export class CapacitorTwilioVideoWeb extends WebPlugin implements CapacitorTwilioVideoPlugin {
  async login(_options: { accessToken: string }): Promise<{ success: boolean }> {
    throw this.unimplemented('Not implemented on web.');
  }

  async logout(): Promise<{ success: boolean }> {
    throw this.unimplemented('Not implemented on web.');
  }

  async isLoggedIn(): Promise<{ isLoggedIn: boolean; hasValidToken: boolean; identity?: string }> {
    throw this.unimplemented('Not implemented on web.');
  }

  async joinRoom(_options: {
    roomName: string;
    enableAudio?: boolean;
    enableVideo?: boolean;
  }): Promise<{ success: boolean }> {
    throw this.unimplemented('Not implemented on web.');
  }

  async leaveRoom(): Promise<{ success: boolean }> {
    throw this.unimplemented('Not implemented on web.');
  }

  async setMicrophoneEnabled(_options: { enabled: boolean }): Promise<{ success: boolean; enabled: boolean }> {
    throw this.unimplemented('Not implemented on web.');
  }

  async setCameraEnabled(_options: { enabled: boolean }): Promise<{ success: boolean; enabled: boolean }> {
    throw this.unimplemented('Not implemented on web.');
  }

  async getCallStatus(): Promise<{
    hasActiveCall: boolean;
    callState: 'idle' | 'connecting' | 'connected' | 'reconnecting' | 'disconnected';
    roomName?: string;
    participantCount: number;
    isMicrophoneEnabled: boolean;
    isCameraEnabled: boolean;
  }> {
    throw this.unimplemented('Not implemented on web.');
  }

  async checkMicrophonePermission(): Promise<{ granted: boolean }> {
    throw this.unimplemented('Not implemented on web.');
  }

  async requestMicrophonePermission(): Promise<{ granted: boolean }> {
    throw this.unimplemented('Not implemented on web.');
  }

  async checkCameraPermission(): Promise<{ granted: boolean }> {
    throw this.unimplemented('Not implemented on web.');
  }

  async requestCameraPermission(): Promise<{ granted: boolean }> {
    throw this.unimplemented('Not implemented on web.');
  }
}
