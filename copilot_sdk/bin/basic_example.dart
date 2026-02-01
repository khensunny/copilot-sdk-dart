/// Dart SDK for GitHub Copilot CLI - Basic Example
///
/// This example demonstrates:
/// - Creating a CopilotClient and session
/// - Registering custom tools
/// - Listening to session events
/// - Sending messages and receiving responses
///
/// Run with: fvm dart run bin/basic_example.dart
///
/// Prerequisites:
/// - GitHub Copilot CLI installed and in PATH or set via COPILOT_CLI_PATH
/// - GitHub authentication configured
// ignore_for_file: avoid_print, dangling_library_doc_comments

import 'dart:async';

import 'package:copilot_sdk/copilot_sdk.dart';

Future<void> main() async {
  print('🚀 Starting Copilot SDK Example\n');

  // Define some facts for the tool
  final facts = <String, String>{
    'javascript': 'JavaScript was created in 10 days by Brendan Eich in 1995.',
    'dart': 'Dart is an open-source, scalable language for building apps.',
    'node': 'Node.js lets you run JavaScript outside the browser.',
  };

  // Define the lookup_fact tool using the new defineTool helper
  final lookupFactTool = defineTool(
    'lookup_fact',
    description: 'Retrieve a fact about a programming topic',
    parameters: (s) => {
      'topic': s.string(
        description: 'The topic to look up (e.g., dart, javascript, node)',
        required: true,
      ),
    },
    handler: (args, invocation) async {
      final topic = (args['topic'] as String?)?.toLowerCase() ?? '';
      final fact = facts[topic] ?? 'No fact stored for "$topic".';
      return ToolResult.success(fact);
    },
  );

  try {
    // Create client - will auto-start CLI server
    print('📦 Creating CopilotClient...');
    final client = await CopilotClient.create(
      const CopilotConfig(logLevel: LogLevel.info),
    );
    print('✅ Client connected\n');

    // Create a session with the custom tool
    print('🔧 Creating session with custom tool...');
    final session = await client.createSession(
      SessionConfig(
        model: 'gpt-4-turbo',
        tools: [lookupFactTool],
      ),
    );
    print('✅ Session created: ${session.sessionId}\n');

    // Listen to all events
    session.onAny((event) {
      print(
        '📢 Event [${event.runtimeType}]: '
        '${_eventToString(event)}',
      );
    });

    // Example 1: Simple math question
    print('\n💬 Sending message: "Tell me 2+2"');
    final result1 = await session.sendAndWait(
      'Tell me 2+2',
      timeout: const Duration(seconds: 30),
    );
    print('📝 Response: ${result1?.data.content}\n');

    // Example 2: Tool usage - lookup facts
    print('💬 Sending message: "Use lookup_fact to tell me about Dart"');
    final result2 = await session.sendAndWait(
      'Use lookup_fact to tell me about Dart',
      timeout: const Duration(minutes: 2),
    );
    print('📝 Response: ${result2?.data.content}\n');

    // Clean up
    print('🧹 Cleaning up...');
    await session.destroy();
    await client.stop();
    print('✅ Done!');
  } catch (e) {
    print('❌ Error: $e');
    rethrow;
  }
}

/// Convert a SessionEvent to a readable string
String _eventToString(SessionEvent event) {
  switch (event) {
    case AssistantMessage(:final data):
      return 'content="${data.content.length} chars"';
    case AssistantMessageDelta(:final data):
      return 'delta="${data.deltaContent.length} chars"';
    case AssistantTurnStart():
      return 'turn started';
    case AssistantTurnEnd():
      return 'turn ended';
    case SessionIdle():
      return 'session idle';
    case SessionError(:final data):
      return 'error="${data.message}"';
    default:
      return event.runtimeType.toString();
  }
}
