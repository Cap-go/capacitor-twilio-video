import { registerPlugin } from '@capacitor/core';

import type { CapacitorTwilioVideoPlugin } from './definitions';

const CapacitorTwilioVideo = registerPlugin<CapacitorTwilioVideoPlugin>('CapacitorTwilioVideo', {
  web: () => import('./web').then((m) => new m.CapacitorTwilioVideoWeb()),
});

export * from './definitions';
export { CapacitorTwilioVideo };
