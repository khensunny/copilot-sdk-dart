@Tags(['e2e'])
library;

import 'dart:async';
import 'dart:io';

import 'package:copilot_sdk/copilot_sdk.dart';
import 'package:test/test.dart';

import 'harness/capi_proxy.dart';
import 'harness/sdk_test_context.dart';
import 'harness/sdk_test_helper.dart';

void main() {
  final contextFuture = createSdkTestContext();
  registerSdkTestContext(contextFuture);

  group('Sessions', () {
    late SdkTestContext context;

    setUpAll(() async {
      context = await contextFuture;
    });

    test('should create and destroy sessions', () async {
      final session = await context.copilotClient.createSession(
        const SessionConfig(model: 'fake-test-model'),
      );
      expect(session.sessionId, isNotEmpty);

      final messages = await session.getMessages();
      expect(messages.first, isA<SessionStart>());
      final start = messages.first as SessionStart;
      expect(start.data.sessionId, session.sessionId);
      expect(start.data.selectedModel, 'fake-test-model');

      await session.destroy();
      expect(session.getMessages, throwsA(isA<StateError>()));
    });

    test('should have stateful conversation', () async {
      final session = await context.copilotClient.createSession();
      final first = await session.sendAndWait('What is 1+1?');
      expect(first?.data.content, contains('2'));

      final second = await session.sendAndWait(
        'Now if you double that, what do you get?',
      );
      expect(second?.data.content, contains('4'));
    });

    test('should create a session with appended systemMessage config', () async {
      const systemMessageSuffix = "End each response with the phrase 'Have a nice day!'";
      final session = await context.copilotClient.createSession(
        const SessionConfig(
          systemMessage: SystemMessageAppendConfig(content: systemMessageSuffix),
        ),
      );

      final assistantMessage = await session.sendAndWait('What is your full name?');
      expect(assistantMessage?.data.content, contains('GitHub'));
      expect(assistantMessage?.data.content, contains('Have a nice day!'));

      final traffic = await context.openAiEndpoint.getExchanges();
      expect(traffic, isNotEmpty);
      final systemMessage = _getSystemMessage(traffic.first);
      expect(systemMessage, contains('GitHub'));
      expect(systemMessage, contains(systemMessageSuffix));
    });

    test('should create a session with replaced systemMessage config', () async {
      const testSystemMessage = 'You are an assistant called Testy McTestface. Reply succinctly.';
      final session = await context.copilotClient.createSession(
        const SessionConfig(
          systemMessage: SystemMessageReplaceConfig(content: testSystemMessage),
        ),
      );

      final assistantMessage = await session.sendAndWait('What is your full name?');
      expect(assistantMessage?.data.content, isNot(contains('GitHub')));
      expect(assistantMessage?.data.content, contains('Testy'));

      final traffic = await context.openAiEndpoint.getExchanges();
      expect(traffic, isNotEmpty);
      final systemMessage = _getSystemMessage(traffic.first);
      expect(systemMessage, testSystemMessage);
    });

    test('should create a session with availableTools', () async {
      final session = await context.copilotClient.createSession(
        const SessionConfig(availableTools: ['view', 'edit']),
      );

      await session.sendAndWait('What is 1+1?');

      final traffic = await context.openAiEndpoint.getExchanges();
      final tools = traffic.first.request['tools'] as List<dynamic>?;
      final functionNames = tools
          ?.map((tool) => (tool as Map<String, dynamic>)['function'] as Map?)
          .map((fn) => fn?['name'] as String?)
          .whereType<String>()
          .toList();
      expect(functionNames, containsAll(['view', 'edit']));
    });

    test('should create a session with excludedTools', () async {
      final session = await context.copilotClient.createSession(
        const SessionConfig(excludedTools: ['view']),
      );

      await session.sendAndWait('What is 1+1?');

      final traffic = await context.openAiEndpoint.getExchanges();
      final tools = traffic.first.request['tools'] as List<dynamic>?;
      final functionNames = tools
          ?.map((tool) => (tool as Map<String, dynamic>)['function'] as Map?)
          .map((fn) => fn?['name'] as String?)
          .whereType<String>()
          .toList();
      expect(functionNames, isNot(contains('view')));
      expect(functionNames, contains('edit'));
    });

    test('should resume a session using the same client', () async {
      final session1 = await context.copilotClient.createSession();
      final sessionId = session1.sessionId;
      final answer = await session1.sendAndWait('What is 1+1?');
      expect(answer?.data.content, contains('2'));

      final session2 = await context.copilotClient.resumeSession(sessionId);
      expect(session2.sessionId, sessionId);
      final messages = await session2.getMessages();
      final assistantMessages = messages.whereType<AssistantMessage>().toList();
      expect(assistantMessages.last.data.content, contains('2'));
    });

    test('should resume a session using a new client', () async {
      final session1 = await context.copilotClient.createSession();
      final sessionId = session1.sessionId;
      final answer = await session1.sendAndWait('What is 1+1?');
      expect(answer?.data.content, contains('2'));

      final newClient = await CopilotClient.create(
        CopilotConfig(
          cliPath: Platform.environment['COPILOT_CLI_PATH'] ?? 'copilot',
          env: {
            ...context.env,
            'XDG_CONFIG_HOME': context.homeDir.path,
            'XDG_STATE_HOME': context.homeDir.path,
          },
        ),
      );

      addTearDown(() async {
        await newClient.forceStop();
      });

      final session2 = await newClient.resumeSession(sessionId);
      expect(session2.sessionId, sessionId);

      final messages = await session2.getMessages();
      expect(messages.any((m) => m is UserMessage), isTrue);
      expect(messages.any((m) => m is SessionResume), isTrue);
    });

    test('should throw error when resuming non-existent session', () async {
      expect(
        () => context.copilotClient.resumeSession('non-existent-session-id'),
        throwsA(isA<Exception>()),
      );
    });

    test('should create session with custom tool', () async {
      final session = await context.copilotClient.createSession(
        SessionConfig(
          tools: [
            ToolDefinition(
              name: 'get_secret_number',
              description: 'Gets the secret number',
              parameters: <String, dynamic>{
                'type': 'object',
                'properties': {
                  'key': {
                    'type': 'string',
                    'description': 'Key',
                  },
                },
                'required': ['key'],
              },
              handler: (args, _) async => ToolResult.success(
                args['key'] == 'ALPHA' ? '54321' : 'unknown',
              ),
            ),
          ],
        ),
      );

      final answer = await session.sendAndWait(
        'What is the secret number for key ALPHA?',
      );
      expect(answer?.data.content, contains('54321'));
    });

    test('should resume session with a custom provider', () async {
      final session = await context.copilotClient.createSession();
      final sessionId = session.sessionId;

      final session2 = await context.copilotClient.resumeSession(
        sessionId,
        const ResumeSessionConfig(
          provider: ProviderConfig(
            type: 'openai',
            baseUrl: 'https://api.openai.com/v1',
            apiKey: 'fake-key',
          ),
        ),
      );

      expect(session2.sessionId, sessionId);
    });

    test('should abort a session', () async {
      final session = await context.copilotClient.createSession();

      final nextToolStart = getNextEventOfType<ToolExecutionStart>(session);
      final nextIdle = getNextEventOfType<SessionIdle>(session);

      await session.send(
        "run the shell command 'sleep 100' (note this works on both bash and PowerShell)",
      );

      await nextToolStart;
      await session.abort();
      await nextIdle;

      final messages = await session.getMessages();
      expect(messages.any((m) => m is Abort), isTrue);

      final answer = await session.sendAndWait('What is 2+2?');
      expect(answer?.data.content, contains('4'));
    });

    test('should receive streaming delta events when streaming is enabled', () async {
      final session = await context.copilotClient.createSession(
        const SessionConfig(streaming: true),
      );

      final deltaContents = <String>[];
      AssistantMessage? finalMessage;

      session.onAny((event) {
        if (event is AssistantMessageDelta) {
          deltaContents.add(event.data.deltaContent);
        } else if (event is AssistantMessage) {
          finalMessage = event;
        }
      });

      final assistantMessage = await session.sendAndWait('What is 2+2?');

      expect(deltaContents, isNotEmpty);
      final accumulated = deltaContents.join();
      expect(accumulated, assistantMessage?.data.content);
      expect(finalMessage?.data.content, contains('4'));
    });

    test('should pass streaming option to session creation', () async {
      final session = await context.copilotClient.createSession(
        const SessionConfig(streaming: true),
      );

      expect(session.sessionId, isNotEmpty);
      final assistantMessage = await session.sendAndWait('What is 1+1?');
      expect(assistantMessage?.data.content, contains('2'));
    });

    test('should receive session events', () async {
      final session = await context.copilotClient.createSession();
      final receivedEvents = <SessionEvent>[];

      session.onAny(receivedEvents.add);

      final assistantMessage = await session.sendAndWait('What is 100+200?');
      expect(receivedEvents, isNotEmpty);
      expect(receivedEvents.any((e) => e is UserMessage), isTrue);
      expect(receivedEvents.any((e) => e is AssistantMessage), isTrue);
      expect(receivedEvents.any((e) => e is SessionIdle), isTrue);
      expect(assistantMessage?.data.content, contains('300'));
    });

    test('should create session with custom config dir', () async {
      final customConfigDir = '${context.homeDir.path}/custom-config';
      final session = await context.copilotClient.createSession(
        SessionConfig(configDir: customConfigDir),
      );

      await session.send('What is 1+1?');
      final assistantMessage = await getFinalAssistantMessage(session);
      expect(assistantMessage.data.content, contains('2'));
    });

    test('should list sessions', () async {
      // Create a couple of sessions and send messages to persist them
      final session1 = await context.copilotClient.createSession();
      await session1.sendAndWait('Say hello');

      final session2 = await context.copilotClient.createSession();
      await session2.sendAndWait('Say goodbye');

      // Small delay to ensure session files are written to disk
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // List sessions and verify they're included
      final sessions = await context.copilotClient.listSessions();
      expect(sessions, isA<List<SessionMetadata>>());

      final sessionIds = sessions.map((s) => s.sessionId).toList();
      expect(sessionIds, contains(session1.sessionId));
      expect(sessionIds, contains(session2.sessionId));

      // Verify session metadata structure
      for (final sessionData in sessions) {
        expect(sessionData.sessionId, isNotEmpty);
        expect(sessionData.startTime, isA<DateTime>());
        expect(sessionData.modifiedTime, isA<DateTime>());
        expect(sessionData.isRemote, isA<bool>());
      }
    });

    test('should delete session', () async {
      // Create a session and send a message to persist it
      final session = await context.copilotClient.createSession();
      await session.sendAndWait('Hello');
      final sessionId = session.sessionId;

      // Small delay to ensure session file is written to disk
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Verify session exists in the list
      final sessions = await context.copilotClient.listSessions();
      final sessionIds = sessions.map((s) => s.sessionId).toList();
      expect(sessionIds, contains(sessionId));

      // Delete the session
      await session.destroy();

      // Verify the session object is no longer usable
      // After destroy, attempting to use the session should throw
      expect(
        () => session.sendAndWait('Hello again'),
        throwsA(isA<StateError>()),
      );

      // Note: We don't verify that listSessions() excludes destroyed sessions
      // because the CLI may keep the session in the list until cleanup.
      // Other SDKs (TypeScript/C#) only verify the session object becomes unusable.
    });
  });

  final sendBlockingContextFuture = createSdkTestContext();
  registerSdkTestContext(sendBlockingContextFuture);

  group('Send blocking behavior', () {
    late SdkTestContext context;

    setUpAll(() async {
      context = await sendBlockingContextFuture;
    });

    test('send returns immediately while events stream in background', () async {
      final session = await context.copilotClient.createSession();
      final events = <SessionEvent>[];

      session.onAny(events.add);

      await session.send("Run 'sleep 2 && echo done'");

      expect(events.whereType<SessionIdle>(), isEmpty);

      final message = await getFinalAssistantMessage(session);
      expect(message.data.content, contains('done'));
      expect(events.whereType<SessionIdle>(), isNotEmpty);
      expect(events.whereType<AssistantMessage>(), isNotEmpty);
    });

    test('sendAndWait blocks until session.idle and returns final assistant message', () async {
      final session = await context.copilotClient.createSession();
      final events = <SessionEvent>[];

      session.onAny(events.add);

      final response = await session.sendAndWait('What is 2+2?');
      expect(response, isNotNull);
      expect(response?.data.content, contains('4'));
      expect(events.whereType<SessionIdle>(), isNotEmpty);
      expect(events.whereType<AssistantMessage>(), isNotEmpty);
    });

    test('sendAndWait throws on timeout', () async {
      final session = await context.copilotClient.createSession();
      expect(
        () => session.sendAndWait(
          "Run 'sleep 2 && echo done'",
          timeout: const Duration(milliseconds: 100),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}

String? _getSystemMessage(ParsedHttpExchange exchange) {
  final messages = exchange.request['messages'] as List<dynamic>?;
  if (messages == null) return null;
  for (final message in messages) {
    final role = (message as Map<String, dynamic>)['role'];
    if (role == 'system') {
      return message['content'] as String?;
    }
  }
  return null;
}
