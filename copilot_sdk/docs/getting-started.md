# Build Your First Copilot-Powered App (Dart)

In this tutorial, you'll use the Copilot SDK for Dart to build a command-line
assistant. You'll start with the basics, add streaming responses, then add custom
tools - giving Copilot the ability to call your code.

## Prerequisites

Before you begin, make sure you have:

- **GitHub Copilot CLI** installed and authenticated
  ([Installation guide](https://docs.github.com/en/copilot/how-tos/set-up/install-copilot-cli))
- **Dart SDK 3.9+** installed (`dart --version`)

Verify the CLI is working:

```bash
copilot --version
```

## Step 1: Install the SDK

Create a new directory and initialize your Dart project:

```bash
mkdir copilot-demo && cd copilot-demo
dart create -t console-simple .
```

Add the SDK in `pubspec.yaml`:

```yaml
dependencies:
  copilot_sdk:
    path: ../copilot_sdk  # or git/pub reference
```

Then fetch dependencies:

```bash
dart pub get
```

## Step 2: Send Your First Message

Replace `bin/copilot_demo.dart` with:

```dart
import 'package:copilot_sdk/copilot_sdk.dart';

Future<void> main() async {
  final client = await CopilotClient.create(const CopilotConfig());
  final session = await client.createSession(
    const SessionConfig(model: 'gpt-4.1'),
  );

  final response = await session.sendAndWait(
    const MessageOptions(prompt: 'What is 2 + 2?'),
  );

  print(response?.data.content);

  await session.destroy();
  await client.stop();
}
```

Run it:

```bash
dart run
```

## Step 3: Stream Responses

Use streaming deltas for responsive output:

```dart
final session = await client.createSession(
  const SessionConfig(model: 'gpt-4.1', streaming: true),
);

session.on<AssistantMessageDelta>((event) {
  stdout.write(event.data.deltaContent);
});

await session.send(const MessageOptions(prompt: 'Explain JSON-RPC briefly.'));
```

## Step 4: Add a Custom Tool

Tools let Copilot call your code.

```dart
final tool = defineTool(
  'get_time',
  description: 'Get the current time',
  parameters: (schema) => {},
  handler: (args, invocation) async {
    return ToolResult.success(DateTime.now().toString());
  },
);

session.registerTool(tool);
await session.send(const MessageOptions(prompt: 'What time is it?'));
```

## Troubleshooting

- If you see connection errors, ensure `copilot` is on your PATH or set
  `COPILOT_CLI_PATH`.
- If you see protocol version mismatch, update the SDK or your Copilot CLI.

## Next Steps

- Learn about MCP servers in [docs/mcp.md](mcp.md)
- Explore the API reference in [docs/api.md](api.md)
