import 'package:copilot_sdk/copilot_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('CopilotConfig', () {
    test('creates with defaults', () {
      const config = CopilotConfig();
      expect(config.useStdio, isTrue);
      expect(config.autoStart, isTrue);
      expect(config.autoRestart, isTrue);
      expect(config.timeout, const Duration(seconds: 30));
    });

    test('usesTcp returns true when cliUrl is set', () {
      const config = CopilotConfig(cliUrl: 'localhost:8080');
      expect(config.usesTcp, isTrue);
    });

    test('usesTcp returns true when useStdio is false', () {
      const config = CopilotConfig(useStdio: false);
      expect(config.usesTcp, isTrue);
    });

    test('usesTcp returns false when useStdio is true and no cliUrl', () {
      const config = CopilotConfig();
      expect(config.usesTcp, isFalse);
    });

    test('copyWith creates a new config with updated values', () {
      const config = CopilotConfig(cliPath: '/usr/bin/copilot');
      final updated = config.copyWith(logLevel: LogLevel.debug);
      expect(updated.cliPath, '/usr/bin/copilot');
      expect(updated.logLevel, LogLevel.debug);
    });

    test('supports githubToken option', () {
      const config = CopilotConfig(githubToken: 'gho_test_token');
      expect(config.githubToken, 'gho_test_token');
    });

    test('supports cliArgs option', () {
      const config = CopilotConfig(cliArgs: ['--verbose', '--no-color']);
      expect(config.cliArgs, ['--verbose', '--no-color']);
    });
  });

  group('SessionConfig', () {
    test('creates with defaults', () {
      const config = SessionConfig();
      expect(config.sessionId, isNull);
      expect(config.streaming, isFalse);
    });

    test('supports model selection', () {
      const config = SessionConfig(model: 'gpt-4');
      expect(config.model, 'gpt-4');
    });

    test('supports tools list', () {
      final tools = [
        ToolDefinition(
          name: 'test_tool',
          description: 'A test tool',
          parameters: <String, dynamic>{'type': 'object'},
          handler: (args, inv) async => ToolResult.success('ok'),
        ),
      ];
      final config = SessionConfig(tools: tools);
      expect(config.tools?.length, 1);
      expect(config.tools?[0].name, 'test_tool');
    });

    test('supports system message config', () {
      final systemMessage = SystemMessageConfig.append(
        content: 'Additional instructions',
      );
      final config = SessionConfig(systemMessage: systemMessage);
      expect(config.systemMessage, isA<SystemMessageConfig>());
    });
  });

  group('SystemMessageConfig', () {
    test('append mode creates correct config', () {
      final config = SystemMessageConfig.append(
        content: 'Extra instructions',
      );
      expect(config, isA<SystemMessageAppendConfig>());
      final appendConfig = config as SystemMessageAppendConfig;
      expect(appendConfig.content, 'Extra instructions');
      final json = config.toJson();
      expect(json['mode'], 'append');
      expect(json['content'], 'Extra instructions');
    });

    test('replace mode creates correct config', () {
      final config = SystemMessageConfig.replace(
        content: 'Complete custom message',
      );
      expect(config, isA<SystemMessageReplaceConfig>());
      final replaceConfig = config as SystemMessageReplaceConfig;
      expect(replaceConfig.content, 'Complete custom message');
      final json = config.toJson();
      expect(json['mode'], 'replace');
      expect(json['content'], 'Complete custom message');
    });
  });

  group('ToolDefinition', () {
    test('serializes to JSON', () {
      final tool = ToolDefinition(
        name: 'test_tool',
        description: 'A test tool',
        parameters: <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{},
        },
        handler: (args, inv) async => ToolResult.success('result'),
      );
      final json = tool.toJson();
      expect(json['name'], 'test_tool');
      expect(json['description'], 'A test tool');
      expect(json['parameters'], isA<Map<String, dynamic>>());
    });
  });

  group('PermissionResult', () {
    test('approved creates correct result', () {
      final result = PermissionResult.approved();
      expect(result.kind, PermissionResultKind.approved);
    });

    test('denied creates correct result', () {
      final result = PermissionResult.denied(
        PermissionResultKind.deniedByRules,
      );
      expect(result.kind, PermissionResultKind.deniedByRules);
    });

    test('serializes to JSON with kebab-case kind', () {
      final result = PermissionResult.denied(
        PermissionResultKind.deniedInteractivelyByUser,
      );
      final json = result.toJson();
      expect(json['kind'], 'denied-interactively-by-user');
    });

    test('deserializes from JSON', () {
      final json = <String, dynamic>{
        'kind': 'denied-no-approval-rule-and-could-not-request-from-user',
      };
      final result = PermissionResult.fromJson(json);
      expect(
        result.kind,
        PermissionResultKind.deniedNoApprovalRuleAndCouldNotRequestFromUser,
      );
    });
  });

  group('ToolResult', () {
    test('success creates a successful result', () {
      final result = ToolResult.success('Hello, world!');
      expect(result.textResultForLlm, 'Hello, world!');
      expect(result.resultType, ToolResultType.success);
    });

    test('failure creates a failed result', () {
      final result = ToolResult.failure(
        'Invoking this tool produced an error.',
        error: 'Something went wrong',
      );
      expect(result.textResultForLlm, 'Invoking this tool produced an error.');
      expect(result.error, 'Something went wrong');
      expect(result.resultType, ToolResultType.failure);
    });

    test('supports binary results', () {
      const result = ToolResult(
        textResultForLlm: 'Image result',
        binaryResultsForLlm: [
          ToolBinaryResult(
            data: 'base64data',
            mimeType: 'image/png',
            type: 'image',
          ),
        ],
      );
      expect(result.binaryResultsForLlm?.length, 1);
      expect(result.binaryResultsForLlm?[0].mimeType, 'image/png');
    });

    test('serializes to JSON', () {
      final result = ToolResult.success('Result text');
      final json = result.toJson();
      expect(json['textResultForLlm'], 'Result text');
      expect(json['resultType'], 'success');
    });
  });

  group('MCPServerConfig', () {
    test('local config serializes correctly', () {
      const config = MCPLocalServerConfig(
        command: 'node',
        args: ['server.js'],
        tools: ['tool1', 'tool2'],
      );
      final json = config.toJson();
      expect(json['command'], 'node');
      expect(json['args'], ['server.js']);
      expect(json['tools'], ['tool1', 'tool2']);
    });

    test('remote config serializes correctly', () {
      const config = MCPRemoteServerConfig(
        type: 'http',
        url: 'http://localhost:3000/mcp',
        tools: ['*'],
      );
      final json = config.toJson();
      expect(json['type'], 'http');
      expect(json['url'], 'http://localhost:3000/mcp');
    });
  });

  group('JsonRpcMessage', () {
    test('parses request', () {
      final json = <String, dynamic>{
        'jsonrpc': '2.0',
        'id': '123',
        'method': 'test',
        'params': {'key': 'value'},
      };
      final message = JsonRpcMessage.fromJson(json);
      expect(message, isA<JsonRpcRequest>());
      final request = message as JsonRpcRequest;
      expect(request.id, '123');
      expect(request.method, 'test');
      expect(request.params, {'key': 'value'});
    });

    test('parses notification', () {
      final json = <String, dynamic>{
        'jsonrpc': '2.0',
        'method': 'notify',
        'params': {'data': 123},
      };
      final message = JsonRpcMessage.fromJson(json);
      expect(message, isA<JsonRpcNotification>());
      final notification = message as JsonRpcNotification;
      expect(notification.method, 'notify');
      expect(notification.params, {'data': 123});
    });

    test('parses response', () {
      final json = <String, dynamic>{
        'jsonrpc': '2.0',
        'id': '456',
        'result': {'status': 'ok'},
      };
      final message = JsonRpcMessage.fromJson(json);
      expect(message, isA<JsonRpcResponse>());
      final response = message as JsonRpcResponse;
      expect(response.id, '456');
      expect(response.result, {'status': 'ok'});
    });

    test('parses error response', () {
      final json = <String, dynamic>{
        'jsonrpc': '2.0',
        'id': '789',
        'error': {
          'code': -32600,
          'message': 'Invalid Request',
        },
      };
      final message = JsonRpcMessage.fromJson(json);
      expect(message, isA<JsonRpcErrorResponse>());
      final error = message as JsonRpcErrorResponse;
      expect(error.id, '789');
      expect(error.error.code, -32600);
      expect(error.error.message, 'Invalid Request');
    });
  });

  group('SessionEvent', () {
    test('parses session.start event', () {
      final json = <String, dynamic>{
        'id': '550e8400-e29b-41d4-a716-446655440000',
        'timestamp': '2024-01-15T10:30:00Z',
        'parentId': null,
        'type': 'session.start',
        'data': {
          'sessionId': 'test-session',
          'version': 1.0,
          'producer': 'test',
          'copilotVersion': '1.0.0',
          'startTime': '2024-01-15T10:30:00Z',
        },
      };
      final event = SessionEvent.fromJson(json);
      expect(event, isA<SessionStart>());
      final start = event as SessionStart;
      expect(start.type, 'session.start');
      expect(start.data.sessionId, 'test-session');
    });

    test('parses assistant.message_delta event', () {
      final json = <String, dynamic>{
        'id': '550e8400-e29b-41d4-a716-446655440001',
        'timestamp': '2024-01-15T10:30:01Z',
        'parentId': '550e8400-e29b-41d4-a716-446655440000',
        'ephemeral': true,
        'type': 'assistant.message_delta',
        'data': {
          'messageId': 'msg-123',
          'deltaContent': 'Hello',
        },
      };
      final event = SessionEvent.fromJson(json);
      expect(event, isA<AssistantMessageDelta>());
      final delta = event as AssistantMessageDelta;
      expect(delta.ephemeral, isTrue);
      expect(delta.data.messageId, 'msg-123');
      expect(delta.data.deltaContent, 'Hello');
    });

    test('parses tool.execution_start event', () {
      final json = <String, dynamic>{
        'id': '550e8400-e29b-41d4-a716-446655440002',
        'timestamp': '2024-01-15T10:30:02Z',
        'parentId': '550e8400-e29b-41d4-a716-446655440001',
        'type': 'tool.execution_start',
        'data': {
          'toolName': 'read_file',
          'toolCallId': 'call-123',
        },
      };
      final event = SessionEvent.fromJson(json);
      expect(event, isA<ToolExecutionStart>());
    });

    test('parses assistant.turn_end event', () {
      final json = <String, dynamic>{
        'id': '550e8400-e29b-41d4-a716-446655440003',
        'timestamp': '2024-01-15T10:30:03Z',
        'parentId': null,
        'type': 'assistant.turn_end',
        'data': {
          'turnId': 'turn-123',
        },
      };
      final event = SessionEvent.fromJson(json);
      expect(event, isA<AssistantTurnEnd>());
    });
  });

  group('Attachment', () {
    test('file attachment serializes correctly', () {
      final attachment = Attachment.file('/path/to/file.txt');
      final json = attachment.toJson();
      expect(json['type'], 'file');
      expect(json['path'], '/path/to/file.txt');
    });

    test('directory attachment serializes correctly', () {
      final attachment = Attachment.directory('/path/to/dir');
      final json = attachment.toJson();
      expect(json['type'], 'directory');
      expect(json['path'], '/path/to/dir');
    });
  });

  group('SessionHooks', () {
    test('can be created with all handlers', () {
      final hooks = SessionHooks(
        onPreToolUse: (input, invocation) async => null,
        onPostToolUse: (input, invocation) async => null,
        onUserPromptSubmitted: (input, invocation) async => null,
        onSessionStart: (input, invocation) async => null,
        onSessionEnd: (input, invocation) async => null,
        onErrorOccurred: (input, invocation) async => null,
      );
      expect(hooks.onPreToolUse, isNotNull);
      expect(hooks.onPostToolUse, isNotNull);
    });
  });

  group('InfiniteSessionConfig', () {
    test('creates with defaults', () {
      const config = InfiniteSessionConfig();
      expect(config.enabled, isTrue);
    });

    test('supports custom thresholds', () {
      const config = InfiniteSessionConfig(
        backgroundCompactionThreshold: 0.7,
        bufferExhaustionThreshold: 0.9,
      );
      expect(config.backgroundCompactionThreshold, 0.7);
      expect(config.bufferExhaustionThreshold, 0.9);
    });
  });

  group('CustomAgentConfig', () {
    test('creates and serializes correctly', () {
      const config = CustomAgentConfig(
        name: 'code-reviewer',
        displayName: 'Code Reviewer',
        description: 'Reviews code for best practices',
        prompt: 'You are a code reviewer...',
        tools: ['read_file', 'grep'],
      );
      final json = config.toJson();
      expect(json['name'], 'code-reviewer');
      expect(json['displayName'], 'Code Reviewer');
      expect(json['tools'], ['read_file', 'grep']);
    });
  });

  group('PingResponse', () {
    test('creates and serializes correctly', () {
      const response = PingResponse(
        message: 'pong',
        timestamp: 1234567890,
        protocolVersion: 1,
      );
      final json = response.toJson();
      expect(json['message'], 'pong');
      expect(json['timestamp'], 1234567890);
      expect(json['protocolVersion'], 1);
    });

    test('deserializes from JSON', () {
      final json = <String, dynamic>{
        'message': 'hello',
        'timestamp': 9999,
        'protocolVersion': 2,
      };
      final response = PingResponse.fromJson(json);
      expect(response.message, 'hello');
      expect(response.timestamp, 9999);
      expect(response.protocolVersion, 2);
    });
  });

  group('ResumeSessionConfig', () {
    test('creates with defaults', () {
      const config = ResumeSessionConfig();
      expect(config.streaming, isFalse);
      expect(config.disableResume, isFalse);
    });

    test('supports custom values', () {
      const config = ResumeSessionConfig(
        streaming: true,
        reasoningEffort: ReasoningEffort.high,
        disableResume: true,
      );
      expect(config.streaming, isTrue);
      expect(config.reasoningEffort, ReasoningEffort.high);
      expect(config.disableResume, isTrue);
    });
  });

  group('GetStatusResponse', () {
    test('serializes and deserializes', () {
      const response = GetStatusResponse(
        version: '1.0.0',
        protocolVersion: 1,
      );
      final json = response.toJson();
      expect(json['version'], '1.0.0');
      expect(json['protocolVersion'], 1);

      final parsed = GetStatusResponse.fromJson(json);
      expect(parsed.version, '1.0.0');
      expect(parsed.protocolVersion, 1);
    });
  });

  group('GetAuthStatusResponse', () {
    test('serializes and deserializes', () {
      const response = GetAuthStatusResponse(
        isAuthenticated: true,
        authType: 'user',
        host: 'github.com',
        login: 'testuser',
      );
      final json = response.toJson();
      expect(json['isAuthenticated'], isTrue);
      expect(json['authType'], 'user');
      expect(json['login'], 'testuser');

      final parsed = GetAuthStatusResponse.fromJson(json);
      expect(parsed.isAuthenticated, isTrue);
      expect(parsed.login, 'testuser');
    });
  });

  group('UserInputRequest', () {
    test('creates with defaults', () {
      const request = UserInputRequest(question: 'What is your name?');
      expect(request.allowFreeform, isTrue);
      expect(request.choices, isNull);
    });

    test('serializes with choices', () {
      const request = UserInputRequest(
        question: 'Pick one',
        choices: ['A', 'B', 'C'],
        allowFreeform: false,
      );
      final json = request.toJson();
      expect(json['question'], 'Pick one');
      expect(json['choices'], ['A', 'B', 'C']);
      expect(json['allowFreeform'], isFalse);
    });
  });

  group('UserInputResult', () {
    test('creates and serializes', () {
      const result = UserInputResult(
        answer: 'Test answer',
        wasFreeform: true,
      );
      final json = result.toJson();
      expect(json['answer'], 'Test answer');
      expect(json['wasFreeform'], isTrue);
    });
  });

  group('ModelInfo', () {
    test('serializes and deserializes', () {
      const modelInfo = ModelInfo(
        id: 'gpt-4',
        name: 'GPT-4',
        capabilities: ModelCapabilities(
          supportsVision: true,
          supportsReasoningEffort: true,
          maxContextWindowTokens: 128000,
        ),
        policy: ModelPolicy(state: 'enabled', terms: 'https://...'),
        billing: ModelBilling(multiplier: 1),
        supportedReasoningEfforts: [ReasoningEffort.low, ReasoningEffort.high],
        defaultReasoningEffort: ReasoningEffort.medium,
      );

      final json = modelInfo.toJson();
      expect(json['id'], 'gpt-4');
      expect(json['name'], 'GPT-4');
      // Capabilities uses nested 'supports' object
      final caps = json['capabilities'] as Map<String, dynamic>;
      expect((caps['supports'] as Map)['vision'], isTrue);

      final parsed = ModelInfo.fromJson(json);
      expect(parsed.id, 'gpt-4');
      expect(parsed.capabilities.supportsVision, isTrue);
      expect(parsed.defaultReasoningEffort, ReasoningEffort.medium);
    });
  });

  group('SessionMetadata', () {
    test('serializes and deserializes', () {
      final metadata = SessionMetadata(
        sessionId: 'session-123',
        startTime: DateTime.utc(2024, 1, 15, 10, 30),
        modifiedTime: DateTime.utc(2024, 1, 15, 11, 45),
        summary: 'Test session',
        isRemote: false,
      );

      final json = metadata.toJson();
      expect(json['sessionId'], 'session-123');
      expect(json['summary'], 'Test session');
      expect(json['isRemote'], isFalse);

      final parsed = SessionMetadata.fromJson(json);
      expect(parsed.sessionId, 'session-123');
      expect(parsed.summary, 'Test session');
    });
  });

  group('ProviderConfig', () {
    test('OpenAI provider serializes correctly', () {
      const config = ProviderConfig(
        type: 'openai',
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'sk-test',
      );
      final json = config.toJson();
      expect(json['type'], 'openai');
      expect(json['baseUrl'], 'https://api.openai.com/v1');
      expect(json['apiKey'], 'sk-test');
    });

    test('Azure provider config serializes with API version', () {
      const azureConfig = AzureProviderConfig(apiVersion: '2024-02-15');
      final json = azureConfig.toJson();
      expect(json['apiVersion'], '2024-02-15');

      // Full provider with azure options
      const provider = ProviderConfig(
        type: 'azure',
        baseUrl: 'https://myresource.azure.com',
        apiKey: 'azure-key',
        azure: azureConfig,
      );
      final providerJson = provider.toJson();
      expect(providerJson['type'], 'azure');
      final azureJson = providerJson['azure']! as Map<String, dynamic>;
      expect(azureJson['apiVersion'], '2024-02-15');
    });
  });

  group('ToolInvocation', () {
    test('serializes and deserializes', () {
      const invocation = ToolInvocation(
        sessionId: 'sess-1',
        toolCallId: 'call-1',
        toolName: 'read_file',
        arguments: {'path': '/test.txt'},
      );
      final json = invocation.toJson();
      expect(json['sessionId'], 'sess-1');
      expect(json['toolName'], 'read_file');

      final parsed = ToolInvocation.fromJson(json);
      expect(parsed.sessionId, 'sess-1');
      expect(parsed.arguments, {'path': '/test.txt'});
    });
  });
}
