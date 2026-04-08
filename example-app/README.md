## Example App for `@capgo/capacitor-twilio-video`

This Vite project links directly to the local plugin source so you can validate Twilio login, room lifecycle, native media rendering, and typed listener payloads while developing.

### Getting started

```bash
bun install
bun run start
```

To refresh the native shells:

```bash
bunx cap sync
```

Use the example UI to:

- fetch a Twilio access token from a backend endpoint,
- cache that token with `login()`,
- join and leave rooms,
- toggle microphone and camera state,
- and inspect emitted room and participant events.
