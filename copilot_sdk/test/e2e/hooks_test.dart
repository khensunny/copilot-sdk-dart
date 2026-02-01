@Tags(['e2e'])
library;

import 'dart:io' as io;

import 'package:copilot_sdk/copilot_sdk.dart';
import 'package:test/test.dart';

import 'harness/sdk_test_context.dart';

void main() {
  final contextFuture = createSdkTestContext();
  registerSdkTestContext(contextFuture);

  group('Session hooks', () {
    late SdkTestContext context;

    setUpAll(() async {
      context = await contextFuture;
    });

    test('should invoke preToolUse hook when model runs a tool', () async {
      final preToolUseInputs = <PreToolUseHookInput>[];
      String? sessionId;

      final session = await context.copilotClient.createSession(
        SessionConfig(
          hooks: SessionHooks(
            onPreToolUse: (input, invocation) async {
              preToolUseInputs.add(input);
              if (sessionId != null) {
                expect(invocation.sessionId, sessionId);
              }
              expect(invocation.sessionId, isNotEmpty);
              return const PreToolUseHookOutput(
                permissionDecision: PermissionDecision.allow,
              );
            },
          ),
        ),
      );
      sessionId = session.sessionId;

      final file = io.File('${context.workDir.path}/hello.txt');
      await file.writeAsString('Hello from the test!');

      await session.sendAndWait(
        'Read the contents of hello.txt and tell me what it says',
      );

      expect(preToolUseInputs, isNotEmpty);
      expect(preToolUseInputs.any((input) => input.toolName.isNotEmpty), isTrue);

      await session.destroy();
    });

    test('should invoke postToolUse hook after model runs a tool', () async {
      final postToolUseInputs = <PostToolUseHookInput>[];
      String? sessionId;

      final session = await context.copilotClient.createSession(
        SessionConfig(
          hooks: SessionHooks(
            onPostToolUse: (input, invocation) async {
              postToolUseInputs.add(input);
              if (sessionId != null) {
                expect(invocation.sessionId, sessionId);
              }
              expect(invocation.sessionId, isNotEmpty);
              return null;
            },
          ),
        ),
      );
      sessionId = session.sessionId;

      final file = io.File('${context.workDir.path}/world.txt');
      await file.writeAsString('World from the test!');

      await session.sendAndWait(
        'Read the contents of world.txt and tell me what it says',
      );

      expect(postToolUseInputs, isNotEmpty);
      expect(
        postToolUseInputs.any((input) => input.toolName.isNotEmpty),
        isTrue,
      );
      expect(
        postToolUseInputs.any((input) => input.toolResult.textResultForLlm.isNotEmpty),
        isTrue,
      );

      await session.destroy();
    });

    test('should invoke both preToolUse and postToolUse hooks for a single tool call', () async {
      final preToolUseInputs = <PreToolUseHookInput>[];
      final postToolUseInputs = <PostToolUseHookInput>[];
      String? sessionId;

      final session = await context.copilotClient.createSession(
        SessionConfig(
          hooks: SessionHooks(
            onPreToolUse: (input, _) async {
              preToolUseInputs.add(input);
              return const PreToolUseHookOutput(
                permissionDecision: PermissionDecision.allow,
              );
            },
            onPostToolUse: (input, _) async {
              postToolUseInputs.add(input);
              return null;
            },
          ),
        ),
      );
      sessionId = session.sessionId;

      final file = io.File('${context.workDir.path}/both.txt');
      await file.writeAsString('Testing both hooks!');

      await session.sendAndWait('Read the contents of both.txt');

      expect(preToolUseInputs, isNotEmpty);
      expect(postToolUseInputs, isNotEmpty);

      final preToolNames = preToolUseInputs.map((input) => input.toolName);
      final postToolNames = postToolUseInputs.map((input) => input.toolName);
      expect(session.sessionId, sessionId);
      final commonTool = preToolNames.firstWhere(
        postToolNames.contains,
        orElse: () => '',
      );
      expect(commonTool, isNotEmpty);

      await session.destroy();
    });

    test('should deny tool execution when preToolUse returns deny', () async {
      final preToolUseInputs = <PreToolUseHookInput>[];

      final session = await context.copilotClient.createSession(
        SessionConfig(
          hooks: SessionHooks(
            onPreToolUse: (input, _) async {
              preToolUseInputs.add(input);
              return const PreToolUseHookOutput(
                permissionDecision: PermissionDecision.deny,
              );
            },
          ),
        ),
      );

      final file = io.File('${context.workDir.path}/protected.txt');
      await file.writeAsString('Original content that should not be modified');

      final response = await session.sendAndWait(
        "Edit protected.txt and replace 'Original' with 'Modified'",
      );

      expect(preToolUseInputs, isNotEmpty);
      expect(response, isNotNull);

      await session.destroy();
    });
  });
}
