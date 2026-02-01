import 'dart:io' as io;

import 'package:copilot_sdk/copilot_sdk.dart';
import 'package:test/test.dart';

import 'harness/sdk_test_context.dart';

void main() {
  final contextFuture = createSdkTestContext();
  registerSdkTestContext(contextFuture);

  group('Permission callbacks', () {
    late SdkTestContext context;

    setUpAll(() async {
      context = await contextFuture;
    });

    test('should invoke permission handler for write operations', () async {
      final permissionRequests = <PermissionRequest>[];
      String? sessionId;

      final session = await context.copilotClient.createSession(
        SessionConfig(
          onPermissionRequest: (request, invocation) async {
            permissionRequests.add(request);
            if (sessionId != null) {
              expect(invocation.sessionId, sessionId);
            }
            expect(invocation.sessionId, isNotEmpty);
            return PermissionResult.approved();
          },
        ),
      );
      sessionId = session.sessionId;

      final file = io.File('${context.workDir.path}/test.txt');
      await file.writeAsString('original content');

      await session.sendAndWait(
        "Edit test.txt and replace 'original' with 'modified'",
      );

      expect(permissionRequests, isNotEmpty);
      expect(
        permissionRequests.any((req) => req.kind == PermissionKind.write),
        isTrue,
      );

      await session.destroy();
    });

    test('should deny permission when handler returns denied', () async {
      final session = await context.copilotClient.createSession(
        SessionConfig(
          onPermissionRequest: (_, _) async => PermissionResult.denied(
            PermissionResultKind.deniedInteractivelyByUser,
          ),
        ),
      );

      final file = io.File('${context.workDir.path}/protected.txt');
      await file.writeAsString('protected content');

      await session.sendAndWait(
        "Edit protected.txt and replace 'protected' with 'hacked'.",
      );

      final content = await file.readAsString();
      expect(content, 'protected content');

      await session.destroy();
    });

    test('should work without permission handler (default behavior)', () async {
      final session = await context.copilotClient.createSession();

      final message = await session.sendAndWait('What is 2+2?');
      expect(message?.data.content, contains('4'));

      await session.destroy();
    });

    test('should handle async permission handler', () async {
      final permissionRequests = <PermissionRequest>[];

      final session = await context.copilotClient.createSession(
        SessionConfig(
          onPermissionRequest: (request, _) async {
            permissionRequests.add(request);
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return PermissionResult.approved();
          },
        ),
      );

      await session.sendAndWait("Run 'echo test' and tell me what happens");
      expect(permissionRequests, isNotEmpty);

      await session.destroy();
    });

    test('should resume session with permission handler', () async {
      final permissionRequests = <PermissionRequest>[];

      final session1 = await context.copilotClient.createSession();
      final sessionId = session1.sessionId;
      await session1.sendAndWait('What is 1+1?');

      final session2 = await context.copilotClient.resumeSession(
        sessionId,
        ResumeSessionConfig(
          onPermissionRequest: (request, _) async {
            permissionRequests.add(request);
            return PermissionResult.approved();
          },
        ),
      );

      await session2.sendAndWait("Run 'echo resumed' for me");
      expect(permissionRequests, isNotEmpty);

      await session2.destroy();
    });

    test('should handle permission handler errors gracefully', () async {
      final session = await context.copilotClient.createSession(
        SessionConfig(
          onPermissionRequest: (_, _) async {
            throw StateError('Handler error');
          },
        ),
      );

      final message = await session.sendAndWait(
        "Run 'echo test'. If you can't, say 'failed'.",
      );

      expect(
        message?.data.content.toLowerCase(),
        matches(RegExp('fail|cannot|unable|permission')),
      );

      await session.destroy();
    });

    test('should receive toolCallId in permission requests', () async {
      var receivedToolCallId = false;

      final session = await context.copilotClient.createSession(
        SessionConfig(
          onPermissionRequest: (request, _) async {
            if (request.toolCallId != null && request.toolCallId!.isNotEmpty) {
              receivedToolCallId = true;
            }
            return PermissionResult.approved();
          },
        ),
      );

      await session.sendAndWait("Run 'echo test'");

      expect(receivedToolCallId, isTrue);

      await session.destroy();
    });
  });
}
