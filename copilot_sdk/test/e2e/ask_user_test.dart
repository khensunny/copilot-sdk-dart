@Tags(['e2e'])
library;

import 'package:copilot_sdk/copilot_sdk.dart';
import 'package:test/test.dart';

import 'harness/sdk_test_context.dart';

void main() {
  final contextFuture = createSdkTestContext();
  registerSdkTestContext(contextFuture);

  group('User input (ask_user)', () {
    late SdkTestContext context;

    setUpAll(() async {
      context = await contextFuture;
    });

    test('should invoke user input handler when model uses ask_user tool', () async {
      final userInputRequests = <UserInputRequest>[];

      final session = await context.copilotClient.createSession(
        SessionConfig(
          onUserInputRequest: (request) async {
            userInputRequests.add(request);
            return UserInputResult(
              answer: request.choices?.first ?? 'freeform answer',
              wasFreeform: !(request.choices?.isNotEmpty ?? false),
            );
          },
        ),
      );

      await session.sendAndWait(
        "Ask me to choose between 'Option A' and 'Option B' using the ask_user tool. "
        'Wait for my response before continuing.',
      );

      expect(userInputRequests, isNotEmpty);
      expect(
        userInputRequests.any((req) => req.question.isNotEmpty),
        isTrue,
      );

      await session.destroy();
    });

    test('should receive choices in user input request', () async {
      final userInputRequests = <UserInputRequest>[];

      final session = await context.copilotClient.createSession(
        SessionConfig(
          onUserInputRequest: (request) async {
            userInputRequests.add(request);
            return UserInputResult(
              answer: request.choices?.first ?? 'default',
            );
          },
        ),
      );

      await session.sendAndWait(
        "Use the ask_user tool to ask me to pick between exactly two options: 'Red' and 'Blue'. "
        'These should be provided as choices. Wait for my answer.',
      );

      expect(userInputRequests, isNotEmpty);
      expect(
        userInputRequests.any((req) => req.choices?.isNotEmpty ?? false),
        isTrue,
      );

      await session.destroy();
    });

    test('should handle freeform user input response', () async {
      final userInputRequests = <UserInputRequest>[];
      const freeformAnswer = 'This is my custom freeform answer that was not in the choices';

      final session = await context.copilotClient.createSession(
        SessionConfig(
          onUserInputRequest: (request) async {
            userInputRequests.add(request);
            return const UserInputResult(
              answer: freeformAnswer,
              wasFreeform: true,
            );
          },
        ),
      );

      final response = await session.sendAndWait(
        'Ask me a question using ask_user and then include my answer in your response. '
        "The question should be 'What is your favorite color?'.",
      );

      expect(userInputRequests, isNotEmpty);
      expect(response, isNotNull);

      await session.destroy();
    });
  });
}
