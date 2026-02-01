import 'package:copilot_sdk/copilot_sdk.dart';
import 'package:test/test.dart';

import 'harness/sdk_test_context.dart';

void main() {
  final contextFuture = createSdkTestContext();
  registerSdkTestContext(contextFuture);

  group('Client', () {
    late SdkTestContext context;

    setUpAll(() async {
      context = await contextFuture;
    });

    test('should start and connect to server using stdio', () async {
      final client = await CopilotClient.create(
        CopilotConfig(cliPath: context.copilotClient.config.cliPath),
      );
      addTearDown(client.forceStop);

      expect(client.getState(), ConnectionState.connected);

      final pong = await client.ping('test message');
      expect(pong.message, isNotEmpty);
      expect(pong.timestamp, greaterThanOrEqualTo(0));

      final errors = await client.stop();
      expect(errors, isEmpty);
      expect(client.getState(), ConnectionState.disconnected);
    });

    test('should start and connect to server using tcp', () async {
      final client = await CopilotClient.create(
        CopilotConfig(
          cliPath: context.copilotClient.config.cliPath,
          useStdio: false,
        ),
      );
      addTearDown(client.forceStop);

      expect(client.getState(), ConnectionState.connected);

      final pong = await client.ping('test message');
      expect(pong.message, isNotEmpty);
      expect(pong.timestamp, greaterThanOrEqualTo(0));

      final errors = await client.stop();
      expect(errors, isEmpty);
      expect(client.getState(), ConnectionState.disconnected);
    });

    test('should forceStop without cleanup', () async {
      final client = await CopilotClient.create(
        CopilotConfig(cliPath: context.copilotClient.config.cliPath),
      );
      addTearDown(client.forceStop);

      await client.createSession();
      await client.forceStop();
      expect(client.getState(), ConnectionState.disconnected);
    });

    test('should get status with version and protocol info', () async {
      final client = await CopilotClient.create(
        CopilotConfig(cliPath: context.copilotClient.config.cliPath),
      );
      addTearDown(client.forceStop);

      final status = await client.getStatus();
      expect(status.version, isNotEmpty);
      expect(status.protocolVersion, greaterThanOrEqualTo(1));

      await client.stop();
    });

    test('should get auth status', () async {
      final client = await CopilotClient.create(
        CopilotConfig(cliPath: context.copilotClient.config.cliPath),
      );
      addTearDown(client.forceStop);

      final authStatus = await client.getAuthStatus();
      expect(authStatus.isAuthenticated, isA<bool>());
      if (authStatus.isAuthenticated) {
        expect(authStatus.authType, isNotNull);
        expect(authStatus.statusMessage, isNotNull);
      }

      await client.stop();
    });

    test('should list models when authenticated', () async {
      final client = await CopilotClient.create(
        CopilotConfig(cliPath: context.copilotClient.config.cliPath),
      );
      addTearDown(client.forceStop);

      final authStatus = await client.getAuthStatus();
      if (!authStatus.isAuthenticated) {
        await client.stop();
        return;
      }

      final models = await client.listModels();
      expect(models, isA<List<ModelInfo>>());
      if (models.isNotEmpty) {
        final model = models.first;
        expect(model.id, isNotEmpty);
        expect(model.name, isNotEmpty);
        expect(model.capabilities, isNotNull);
      }

      await client.stop();
    });
  });
}
