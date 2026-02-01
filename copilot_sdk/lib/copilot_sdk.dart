/// Dart SDK for GitHub Copilot CLI - JSON-RPC client for agentic AI
/// interactions.
///
/// This library provides a Dart interface to communicate with the GitHub
/// Copilot CLI in server mode via stdio or TCP transports using JSON-RPC 2.0.
///
/// ## Usage
///
/// ```dart
/// import 'package:copilot_sdk/copilot_sdk.dart';
///
/// void main() async {
///   // Create client with default config (spawns CLI process)
///   final client = await CopilotClient.create(
///     CopilotConfig(streaming: true),
///   );
///
///   // Create a session
///   final session = await client.createSession(
///     SessionConfig(model: 'gpt-4'),
///   );
///
///   // Listen to events
///   session.events.listen((event) {
///     switch (event) {
///       case AssistantMessageDelta(:final data):
///         print(data.deltaContent);
///       case AssistantTurnEnd():
///         print('Turn complete');
///       default:
///         break;
///     }
///   });
///
///   // Send a message
///   await session.send('Hello, Copilot!');
///
///   // Cleanup
///   await client.stop();
/// }
/// ```
library;

// Core client and session
export 'src/copilot/copilot.dart';
// JSON-RPC layer (for advanced usage)
export 'src/jsonrpc/jsonrpc.dart';
// Generated session event types
export 'src/models/generated/session_events.dart';
// Transport layer (for custom transports)
export 'src/transports/transports.dart';
