# @capgo/capacitor-twilio-video

Integrates the Twilio Video SDK into Capacitor

## Install

```bash
npm install @capgo/capacitor-twilio-video
npx cap sync
```

## API

<docgen-index>

* [`login(...)`](#login)
* [`logout()`](#logout)
* [`isLoggedIn()`](#isloggedin)
* [`joinRoom(...)`](#joinroom)
* [`leaveRoom()`](#leaveroom)
* [`setMicrophoneEnabled(...)`](#setmicrophoneenabled)
* [`setCameraEnabled(...)`](#setcameraenabled)
* [`getCallStatus()`](#getcallstatus)
* [`checkMicrophonePermission()`](#checkmicrophonepermission)
* [`requestMicrophonePermission()`](#requestmicrophonepermission)
* [`checkCameraPermission()`](#checkcamerapermission)
* [`requestCameraPermission()`](#requestcamerapermission)
* [`addListener('roomConnected', ...)`](#addlistenerroomconnected-)
* [`addListener('roomDisconnected', ...)`](#addlistenerroomdisconnected-)
* [`addListener('participantConnected', ...)`](#addlistenerparticipantconnected-)
* [`addListener('participantDisconnected', ...)`](#addlistenerparticipantdisconnected-)
* [`addListener('roomReconnecting', ...)`](#addlistenerroomreconnecting-)
* [`addListener('roomReconnected', ...)`](#addlistenerroomreconnected-)
* [`removeAllListeners()`](#removealllisteners)
* [Interfaces](#interfaces)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

### login(...)

```typescript
login(options: { accessToken: string; }) => Promise<{ success: boolean; }>
```

Store and validate a Twilio Video access token.

| Param         | Type                                  |
| ------------- | ------------------------------------- |
| **`options`** | <code>{ accessToken: string; }</code> |

**Returns:** <code>Promise&lt;{ success: boolean; }&gt;</code>

--------------------


### logout()

```typescript
logout() => Promise<{ success: boolean; }>
```

Clear the current session and leave the active room.

**Returns:** <code>Promise&lt;{ success: boolean; }&gt;</code>

--------------------


### isLoggedIn()

```typescript
isLoggedIn() => Promise<{ isLoggedIn: boolean; hasValidToken: boolean; identity?: string; }>
```

Check whether a valid token is currently stored.

**Returns:** <code>Promise&lt;{ isLoggedIn: boolean; hasValidToken: boolean; identity?: string; }&gt;</code>

--------------------


### joinRoom(...)

```typescript
joinRoom(options: { roomName: string; enableAudio?: boolean; enableVideo?: boolean; }) => Promise<{ success: boolean; }>
```

Connect to a Twilio Video room without rendering UI.

| Param         | Type                                                                             |
| ------------- | -------------------------------------------------------------------------------- |
| **`options`** | <code>{ roomName: string; enableAudio?: boolean; enableVideo?: boolean; }</code> |

**Returns:** <code>Promise&lt;{ success: boolean; }&gt;</code>

--------------------


### leaveRoom()

```typescript
leaveRoom() => Promise<{ success: boolean; }>
```

Leave the current room if connected.

**Returns:** <code>Promise&lt;{ success: boolean; }&gt;</code>

--------------------


### setMicrophoneEnabled(...)

```typescript
setMicrophoneEnabled(options: { enabled: boolean; }) => Promise<{ success: boolean; enabled: boolean; }>
```

Enable/disable local microphone publishing.

| Param         | Type                               |
| ------------- | ---------------------------------- |
| **`options`** | <code>{ enabled: boolean; }</code> |

**Returns:** <code>Promise&lt;{ success: boolean; enabled: boolean; }&gt;</code>

--------------------


### setCameraEnabled(...)

```typescript
setCameraEnabled(options: { enabled: boolean; }) => Promise<{ success: boolean; enabled: boolean; }>
```

Enable/disable local camera publishing.

| Param         | Type                               |
| ------------- | ---------------------------------- |
| **`options`** | <code>{ enabled: boolean; }</code> |

**Returns:** <code>Promise&lt;{ success: boolean; enabled: boolean; }&gt;</code>

--------------------


### getCallStatus()

```typescript
getCallStatus() => Promise<{ hasActiveCall: boolean; callState: 'idle' | 'connecting' | 'connected' | 'reconnecting' | 'disconnected'; roomName?: string; participantCount: number; isMicrophoneEnabled: boolean; isCameraEnabled: boolean; }>
```

Get current room and media state.

**Returns:** <code>Promise&lt;{ hasActiveCall: boolean; callState: 'idle' | 'connecting' | 'connected' | 'reconnecting' | 'disconnected'; roomName?: string; participantCount: number; isMicrophoneEnabled: boolean; isCameraEnabled: boolean; }&gt;</code>

--------------------


### checkMicrophonePermission()

```typescript
checkMicrophonePermission() => Promise<{ granted: boolean; }>
```

Check microphone permission state.

**Returns:** <code>Promise&lt;{ granted: boolean; }&gt;</code>

--------------------


### requestMicrophonePermission()

```typescript
requestMicrophonePermission() => Promise<{ granted: boolean; }>
```

Request microphone permission.

**Returns:** <code>Promise&lt;{ granted: boolean; }&gt;</code>

--------------------


### checkCameraPermission()

```typescript
checkCameraPermission() => Promise<{ granted: boolean; }>
```

Check camera permission state.

**Returns:** <code>Promise&lt;{ granted: boolean; }&gt;</code>

--------------------


### requestCameraPermission()

```typescript
requestCameraPermission() => Promise<{ granted: boolean; }>
```

Request camera permission.

**Returns:** <code>Promise&lt;{ granted: boolean; }&gt;</code>

--------------------


### addListener('roomConnected', ...)

```typescript
addListener(eventName: 'roomConnected', listenerFunc: (data: { roomName: string; participantCount: number; }) => void) => Promise<PluginListenerHandle>
```

Listen for room connected events.

| Param              | Type                                                                            |
| ------------------ | ------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'roomConnected'</code>                                                    |
| **`listenerFunc`** | <code>(data: { roomName: string; participantCount: number; }) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('roomDisconnected', ...)

```typescript
addListener(eventName: 'roomDisconnected', listenerFunc: (data: { roomName?: string; error?: string; }) => void) => Promise<PluginListenerHandle>
```

Listen for room disconnected events.

| Param              | Type                                                                   |
| ------------------ | ---------------------------------------------------------------------- |
| **`eventName`**    | <code>'roomDisconnected'</code>                                        |
| **`listenerFunc`** | <code>(data: { roomName?: string; error?: string; }) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('participantConnected', ...)

```typescript
addListener(eventName: 'participantConnected', listenerFunc: (data: { roomName: string; identity: string; participantCount: number; }) => void) => Promise<PluginListenerHandle>
```

Listen for participant connected events.

| Param              | Type                                                                                              |
| ------------------ | ------------------------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'participantConnected'</code>                                                               |
| **`listenerFunc`** | <code>(data: { roomName: string; identity: string; participantCount: number; }) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('participantDisconnected', ...)

```typescript
addListener(eventName: 'participantDisconnected', listenerFunc: (data: { roomName: string; identity: string; participantCount: number; }) => void) => Promise<PluginListenerHandle>
```

Listen for participant disconnected events.

| Param              | Type                                                                                              |
| ------------------ | ------------------------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'participantDisconnected'</code>                                                            |
| **`listenerFunc`** | <code>(data: { roomName: string; identity: string; participantCount: number; }) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('roomReconnecting', ...)

```typescript
addListener(eventName: 'roomReconnecting', listenerFunc: (data: { roomName: string; error?: string; }) => void) => Promise<PluginListenerHandle>
```

Listen for reconnection start events.

| Param              | Type                                                                  |
| ------------------ | --------------------------------------------------------------------- |
| **`eventName`**    | <code>'roomReconnecting'</code>                                       |
| **`listenerFunc`** | <code>(data: { roomName: string; error?: string; }) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('roomReconnected', ...)

```typescript
addListener(eventName: 'roomReconnected', listenerFunc: (data: { roomName: string; }) => void) => Promise<PluginListenerHandle>
```

Listen for reconnection success events.

| Param              | Type                                                  |
| ------------------ | ----------------------------------------------------- |
| **`eventName`**    | <code>'roomReconnected'</code>                        |
| **`listenerFunc`** | <code>(data: { roomName: string; }) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### removeAllListeners()

```typescript
removeAllListeners() => Promise<void>
```

--------------------


### Interfaces


#### PluginListenerHandle

| Prop         | Type                                      |
| ------------ | ----------------------------------------- |
| **`remove`** | <code>() =&gt; Promise&lt;void&gt;</code> |

</docgen-api>
