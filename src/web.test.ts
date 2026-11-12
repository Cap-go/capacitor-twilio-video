import { describe, expect, test } from 'bun:test';

import { CapacitorTwilioVideoWeb } from './web';

describe('CapacitorTwilioVideoWeb', () => {
  const plugin = new CapacitorTwilioVideoWeb();

  test('login throws unimplemented on web', async () => {
    await expect(plugin.login({ accessToken: 'token' })).rejects.toThrow(/Not implemented on web/i);
  });

  test('getCallStatus throws unimplemented on web', async () => {
    await expect(plugin.getCallStatus()).rejects.toThrow(/Not implemented on web/i);
  });

  test('checkMicrophonePermission throws unimplemented on web', async () => {
    await expect(plugin.checkMicrophonePermission()).rejects.toThrow(/Not implemented on web/i);
  });
});
