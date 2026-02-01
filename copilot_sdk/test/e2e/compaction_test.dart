import 'package:copilot_sdk/copilot_sdk.dart';
import 'package:test/test.dart';

import 'harness/sdk_test_context.dart';

void main() {
  final contextFuture = createSdkTestContext();
  registerSdkTestContext(contextFuture);

  group('Compaction', () {
    late SdkTestContext context;

    setUpAll(() async {
      context = await contextFuture;
    });

    test('should trigger compaction with low threshold and emit events', () async {
      final session = await context.copilotClient.createSession(
        const SessionConfig(
          infiniteSessions: InfiniteSessionConfig(
            backgroundCompactionThreshold: 0.005,
            bufferExhaustionThreshold: 0.01,
          ),
        ),
      );

      final events = <SessionEvent>[];
      session.onAny(events.add);

      await session.sendAndWait(
        'Tell me a long story about a dragon. Be very detailed.',
      );
      await session.sendAndWait(
        "Continue the story with more details about the dragon's castle.",
      );
      await session.sendAndWait(
        "Now describe the dragon's treasure in great detail.",
      );

      final compactionStartEvents = events.whereType<SessionCompactionStart>().toList();
      final compactionCompleteEvents = events.whereType<SessionCompactionComplete>().toList();

      expect(compactionStartEvents.length, greaterThanOrEqualTo(1));
      expect(compactionCompleteEvents.length, greaterThanOrEqualTo(1));

      final lastCompactionComplete = compactionCompleteEvents.last;
      expect(lastCompactionComplete.data.success, isTrue);
      final tokensRemoved = lastCompactionComplete.data.tokensRemoved;
      if (tokensRemoved != null) {
        expect(tokensRemoved, greaterThan(0));
      }

      final answer = await session.sendAndWait('What was the story about?');
      expect(answer?.data.content, isNotEmpty);
      expect(answer?.data.content.toLowerCase(), contains('dragon'));
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('should not emit compaction events when infinite sessions disabled', () async {
      final session = await context.copilotClient.createSession(
        const SessionConfig(
          infiniteSessions: InfiniteSessionConfig(enabled: false),
        ),
      );

      final compactionEvents = <SessionEvent>[];
      session.onAny((event) {
        if (event is SessionCompactionStart || event is SessionCompactionComplete) {
          compactionEvents.add(event);
        }
      });

      await session.sendAndWait('What is 2+2?');
      expect(compactionEvents, isEmpty);
    });
  });
}
