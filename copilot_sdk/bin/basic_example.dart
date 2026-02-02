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
import 'dart:convert';

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
      final eventType = _getEventType(event);
      final eventData = _eventToString(event);
      print('📢 Event [$eventType]: $eventData');
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

/// Convert a SessionEvent to a verbose JSON string (like TypeScript SDK)
String _eventToString(SessionEvent event) {
  final jsonData = _extractEventData(event);
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(jsonData);
}

/// Extract the data payload from an event (similar to event.data in TypeScript)
Map<String, dynamic> _extractEventData(SessionEvent event) {
  // Events have their data in a `data` field - access via pattern matching
  return switch (event) {
    SessionStart(:final data) => data.toJson(),
    SessionResume(:final data) => data.toJson(),
    SessionError(:final data) => data.toJson(),
    SessionIdle(:final data) => data.toJson(),
    SessionInfo(:final data) => data.toJson(),
    SessionModelChange(:final data) => data.toJson(),
    SessionImportLegacy(:final data) => data.toJson(),
    SessionHandoff(:final data) => data.toJson(),
    SessionTruncation(:final data) => data.toJson(),
    SessionSnapshotRewind(:final data) => data.toJson(),
    SessionUsageInfo(:final data) => data.toJson(),
    SessionCompactionStart(:final data) => data.toJson(),
    SessionCompactionComplete(:final data) => data.toJson(),
    UserMessage(:final data) => data.toJson(),
    PendingMessagesModified(:final data) => data.toJson(),
    AssistantTurnStart(:final data) => data.toJson(),
    AssistantIntent(:final data) => data.toJson(),
    AssistantReasoning(:final data) => data.toJson(),
    AssistantReasoningDelta(:final data) => data.toJson(),
    AssistantMessage(:final data) => data.toJson(),
    AssistantMessageDelta(:final data) => data.toJson(),
    AssistantTurnEnd(:final data) => data.toJson(),
    AssistantUsage(:final data) => data.toJson(),
    Abort(:final data) => data.toJson(),
    ToolUserRequested(:final data) => data.toJson(),
    ToolExecutionStart(:final data) => data.toJson(),
    ToolExecutionPartialResult(:final data) => data.toJson(),
    ToolExecutionProgress(:final data) => data.toJson(),
    ToolExecutionComplete(:final data) => data.toJson(),
    SkillInvoked(:final data) => data.toJson(),
    SubagentStarted(:final data) => data.toJson(),
    SubagentCompleted(:final data) => data.toJson(),
    SubagentFailed(:final data) => data.toJson(),
    SubagentSelected(:final data) => data.toJson(),
    HookStart(:final data) => data.toJson(),
    HookEnd(:final data) => data.toJson(),
    SystemMessage(:final data) => data.toJson(),
    _ => {'type': event.runtimeType.toString()},
  };
}

/// Get the event type string (e.g., "assistant.message", "session.idle")
String _getEventType(SessionEvent event) {
  return switch (event) {
    SessionStart() => 'session.start',
    SessionResume() => 'session.resume',
    SessionError() => 'session.error',
    SessionIdle() => 'session.idle',
    SessionInfo() => 'session.info',
    SessionModelChange() => 'session.model_change',
    SessionImportLegacy() => 'session.import_legacy',
    SessionHandoff() => 'session.handoff',
    SessionTruncation() => 'session.truncation',
    SessionSnapshotRewind() => 'session.snapshot_rewind',
    SessionUsageInfo() => 'session.usage_info',
    SessionCompactionStart() => 'session.compaction_start',
    SessionCompactionComplete() => 'session.compaction_complete',
    UserMessage() => 'user.message',
    PendingMessagesModified() => 'pending_messages.modified',
    AssistantTurnStart() => 'assistant.turn_start',
    AssistantIntent() => 'assistant.intent',
    AssistantReasoning() => 'assistant.reasoning',
    AssistantReasoningDelta() => 'assistant.reasoning_delta',
    AssistantMessage() => 'assistant.message',
    AssistantMessageDelta() => 'assistant.message_delta',
    AssistantTurnEnd() => 'assistant.turn_end',
    AssistantUsage() => 'assistant.usage',
    Abort() => 'abort',
    ToolUserRequested() => 'tool.user_requested',
    ToolExecutionStart() => 'tool.execution_start',
    ToolExecutionPartialResult() => 'tool.execution_partial_result',
    ToolExecutionProgress() => 'tool.execution_progress',
    ToolExecutionComplete() => 'tool.execution_complete',
    SkillInvoked() => 'skill.invoked',
    SubagentStarted() => 'subagent.started',
    SubagentCompleted() => 'subagent.completed',
    SubagentFailed() => 'subagent.failed',
    SubagentSelected() => 'subagent.selected',
    HookStart() => 'hook.start',
    HookEnd() => 'hook.end',
    SystemMessage() => 'system.message',
    _ => event.runtimeType.toString(),
  };
}
