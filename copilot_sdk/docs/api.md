# API Reference (Dart)

This page highlights the most commonly used public APIs in the Copilot SDK for
Dart. For full details, consult dartdoc or the inline `///` comments.

## CopilotClient

```dart
final client = await CopilotClient.create(const CopilotConfig());
final session = await client.createSession(
  const SessionConfig(model: 'gpt-4.1'),
);
```

Key methods:

- `CopilotClient.create()` - initialize and connect (recommended).
- `CopilotClient.createNonBlocking()` - initialize in the background.
- `createSession()` / `resumeSession()` - manage sessions.
- `listModels()` - get available models.
- `getAuthStatus()` - check GitHub auth status.
- `stop()` / `forceStop()` - shut down the client.

## CopilotSession

```dart
session.on<AssistantMessageDelta>((event) {
  stdout.write(event.data.deltaContent);
});

await session.send(const MessageOptions(prompt: 'Hello'));
```

Key methods:

- `send()` - fire-and-forget message sending.
- `sendAndWait()` - await a response.
- `registerTool()` / `registerTools()` - register custom tools.
- `registerPermissionHandler()` - approve/deny tool permissions.
- `registerUserInputHandler()` - respond to user input requests.

## Configuration

### CopilotConfig

```dart
const config = CopilotConfig(
  useStdio: true,
  logLevel: LogLevel.info,
  timeout: Duration(seconds: 30),
);
```

### SessionConfig

```dart
const config = SessionConfig(
  model: 'gpt-4.1',
  streaming: true,
  tools: [],
);
```

## Tools

```dart
final tool = defineTool(
  'lookup_fact',
  description: 'Retrieve a fact',
  parameters: (schema) => {
    'topic': schema.string(required: true),
  },
  handler: (args, invocation) async {
    return ToolResult.success('result');
  },
);
```

## Events

The SDK exposes typed events (sealed classes):

```dart
session.onAny((event) {
  switch (event) {
    case AssistantMessage(:final data):
      print(data.content);
    case ToolExecutionStart(:final data):
      print(data.toolName);
    default:
      break;
  }
});
```

## Protocol Version

The SDK protocol version is exposed as:

```dart
import 'package:copilot_sdk/copilot_sdk.dart';

print(sdkProtocolVersion);
```

Update it via:

```bash
dart run tool/update_protocol_version.dart
```
