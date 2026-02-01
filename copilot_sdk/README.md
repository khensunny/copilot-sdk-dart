# Copilot SDK

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

A Dart SDK for GitHub Copilot CLI - JSON-RPC client for agentic AI interactions.

## Features

- **JSON-RPC 2.0 Client** - Full implementation of bidirectional JSON-RPC over stdio or TCP
- **Streaming Support** - Real-time message deltas for responsive UI
- **Tool Registration** - Define and register custom tools with typed handlers
- **Permission Handling** - Approve/deny tool execution requests
- **Session Management** - Create, resume, and manage conversation sessions
- **Type-Safe Events** - 35+ sealed class event types generated from schema

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  copilot_sdk:
    path: ../copilot_sdk  # or git/pub reference
```

## Documentation

- [Getting started](docs/getting-started.md)
- [API reference](docs/api.md)
- [MCP servers](docs/mcp.md)

## Quick Start

```dart
import 'package:copilot_sdk/copilot_sdk.dart';

void main() async {
  // Create client (spawns Copilot CLI process)
  final client = await CopilotClient.create(
    CopilotConfig(
      cwd: '/path/to/project',
    ),
  );

  // Create a session with streaming enabled
  final session = await client.createSession(
    SessionConfig(model: 'gpt-4', streaming: true),
  );

  // Listen to streaming events
  session.events.listen((event) {
    switch (event) {
      case AssistantMessageDelta(:final data):
        stdout.write(data.deltaContent);
      case AssistantTurnEnd():
        print('\n--- Turn complete ---');
      case ToolExecutionStart(:final data):
        print('Executing tool: ${data.toolName}');
      default:
        break;
    }
  });

  // Register a custom tool
  session.registerTool('get_weather', (args, invocation) async {
    final city = args['city'] as String;
    return ToolResult.text('Weather in $city: Sunny, 72°F');
  });

  // Send a message
  await session.send('What is the weather in San Francisco?');

  // Cleanup
  await client.stop();
}
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Your Application                      │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                      CopilotClient                       │
│  • create() / createNonBlocking()                       │
│  • createSession() / resumeSession()                    │
│  • stop() / forceStop()                                 │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                     CopilotSession                       │
│  • send() - Send messages                               │
│  • on<T>() - Typed event handlers                       │
│  • registerTool() - Custom tool handlers                │
│  • events stream - All session events                   │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                      JsonRpcClient                       │
│  • Request/response with Completers                     │
│  • Notification streams                                 │
│  • Server-initiated request handling                    │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                       Transport                          │
│  ┌─────────────────┐    ┌─────────────────┐            │
│  │  StdioTransport │    │   TcpTransport  │            │
│  │  (spawn CLI)    │    │  (external srv) │            │
│  └─────────────────┘    └─────────────────┘            │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                   Copilot CLI (server)                   │
└─────────────────────────────────────────────────────────┘
```

## Configuration

### CopilotConfig

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `cliPath` | `String?` | `'copilot'` | Path to Copilot CLI executable |
| `cliArgs` | `List<String>?` | `null` | Extra CLI arguments |
| `cwd` | `String?` | `null` | Working directory |
| `port` | `int?` | `null` | TCP port (for TCP mode) |
| `useStdio` | `bool` | `true` | Use stdio transport |
| `cliUrl` | `String?` | `null` | URL of external CLI server |
| `logLevel` | `LogLevel?` | `null` | CLI log level |
| `autoStart` | `bool` | `true` | Auto-start CLI on first use |
| `autoRestart` | `bool` | `true` | Auto-reconnect on disconnect |
| `env` | `Map<String, String?>?` | `null` | Environment variables |
| `githubToken` | `String?` | `null` | GitHub token for auth |
| `timeout` | `Duration` | `30s` | Request timeout |

### SessionConfig

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `sessionId` | `String?` | `null` | Session ID for resumption |
| `model` | `String?` | `null` | Model selection |
| `streaming` | `bool` | `false` | Enable streaming deltas |
| `tools` | `List<ToolDefinition>?` | `null` | Custom tool definitions |
| `systemMessage` | `SystemMessageConfig?` | `null` | System message config |
| `mcpServers` | `Map<String, MCPServerConfig>?` | `null` | MCP servers |
| `customAgents` | `List<CustomAgentConfig>?` | `null` | Custom agents |
| `hooks` | `SessionHooks?` | `null` | Lifecycle hooks |
| `infiniteSessions` | `InfiniteSessionConfig?` | `null` | Infinite session config |

## Event Types

The SDK includes 35+ typed events via sealed classes:

**Session Events:**
- `SessionStart`, `SessionResume`, `SessionError`, `SessionIdle`

**Assistant Events:**
- `AssistantTurnStart`, `AssistantTurnEnd`
- `AssistantMessage`, `AssistantMessageDelta` (streaming)
- `AssistantReasoning`, `AssistantReasoningDelta` (streaming)

**Tool Events:**
- `ToolExecutionStart`, `ToolExecutionComplete`, `ToolExecutionProgress`

**User Events:**
- `UserMessage`

## Non-Blocking Initialization

For UI applications that need responsive startup:

```dart
// Returns immediately, initializes in background
final client = CopilotClient.createNonBlocking(CopilotConfig());

// Messages sent before init completes are queued
await client.initialized;  // Wait for ready if needed
```

## TCP Connection

Connect to an externally running Copilot CLI server:

```dart
final client = await CopilotClient.create(
  CopilotConfig(
    host: 'localhost',
    port: 8080,
  ),
);
```

## Running Tests

```sh
dart test
```

## Protocol Version

The SDK protocol version is defined in `sdk-protocol-version.json` and
generated into `lib/src/copilot/protocol_version.dart`.

Update it by running:

```sh
dart run tool/update_protocol_version.dart
```

## Related Projects

- [GitHub Copilot SDK (TypeScript)](https://github.com/github/copilot-sdk) - Original SDK
- [vide_cli](https://github.com/khensunny/vide_cli) - Terminal AI assistant using this SDK

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
