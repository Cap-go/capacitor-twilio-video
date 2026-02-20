import { WebPlugin } from '@capacitor/core';

import type { CapacitorTwilioVideoPlugin } from './definitions';

export class CapacitorTwilioVideoWeb extends WebPlugin implements CapacitorTwilioVideoPlugin {
  async echo(options: { value: string }): Promise<{ value: string }> {
    console.log('ECHO', options);
    return options;
  }
}
