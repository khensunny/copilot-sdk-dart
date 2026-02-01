@Tags(['e2e'])
library;

import 'dart:convert';
import 'dart:io' as io;

import 'package:copilot_sdk/copilot_sdk.dart';
import 'package:test/test.dart';

import 'harness/sdk_test_context.dart';

void main() {
  final contextFuture = createSdkTestContext();
  registerSdkTestContext(contextFuture);

  group('Custom tools', () {
    late SdkTestContext context;

    setUpAll(() async {
      context = await contextFuture;
    });

    test('invokes built-in tools', () async {
      final file = io.File('${context.workDir.path}/README.md');
      await file.writeAsString("# ELIZA, the only chatbot you'll ever need");

      final session = await context.copilotClient.createSession();
      final assistantMessage = await session.sendAndWait(
        "What's the first line of README.md in this directory?",
      );
      expect(assistantMessage?.data.content, contains('ELIZA'));
    });

    test('invokes custom tool', () async {
      final session = await context.copilotClient.createSession(
        SessionConfig(
          tools: [
            ToolDefinition(
              name: 'encrypt_string',
              description: 'Encrypts a string',
              parameters: <String, dynamic>{
                'type': 'object',
                'properties': {
                  'input': {
                    'type': 'string',
                    'description': 'String to encrypt',
                  },
                },
                'required': ['input'],
              },
              handler: (args, _) async => ToolResult.success(
                (args['input'] as String?)?.toUpperCase() ?? '',
              ),
            ),
          ],
        ),
      );

      final assistantMessage = await session.sendAndWait(
        'Use encrypt_string to encrypt this string: Hello',
      );
      expect(assistantMessage?.data.content, contains('HELLO'));
    });

    test('handles tool calling errors', () async {
      final session = await context.copilotClient.createSession(
        SessionConfig(
          tools: [
            ToolDefinition(
              name: 'get_user_location',
              description: "Gets the user's location",
              handler: (_, _) async => throw StateError('Melbourne'),
            ),
          ],
        ),
      );

      final answer = await session.sendAndWait(
        "What is my location? If you can't find out, just say 'unknown'.",
      );

      final traffic = await context.openAiEndpoint.getExchanges();
      expect(traffic, isNotEmpty);
      final lastConversation = traffic.last;
      final messages = lastConversation.request['messages'] as List<dynamic>;
      final toolCalls = <Map<String, dynamic>>[];
      for (final message in messages) {
        final msg = message as Map<String, dynamic>;
        if (msg['role'] == 'assistant' && msg['tool_calls'] is List) {
          toolCalls.addAll(
            (msg['tool_calls'] as List<dynamic>).cast<Map<dynamic, dynamic>>().map(
              (call) => call.cast<String, dynamic>(),
            ),
          );
        }
      }
      expect(toolCalls.length, 1);
      final functionMap = toolCalls.first['function'] as Map<String, dynamic>?;
      expect(functionMap?['name'], 'get_user_location');

      final toolResults = messages.where((message) {
        final msg = message as Map<String, dynamic>;
        return msg['role'] == 'tool';
      }).toList();
      expect(toolResults.length, 1);
      final toolResult = toolResults.first as Map<String, dynamic>;
      expect(toolResult['content'], isNot(contains('Melbourne')));

      expect(answer?.data.content.toLowerCase(), contains('unknown'));
    });

    test('can receive and return complex types', () async {
      late CopilotSession session;
      session = await context.copilotClient.createSession(
        SessionConfig(
          tools: [
            ToolDefinition(
              name: 'db_query',
              description: 'Performs a database query',
              parameters: <String, dynamic>{
                'type': 'object',
                'properties': {
                  'query': {
                    'type': 'object',
                    'properties': {
                      'table': {'type': 'string'},
                      'ids': {
                        'type': 'array',
                        'items': {'type': 'number'},
                      },
                      'sortAscending': {'type': 'boolean'},
                    },
                  },
                },
                'required': ['query'],
              },
              handler: (args, invocation) async {
                final query = (args['query'] as Map).cast<String, dynamic>();
                expect(query['table'], 'cities');
                expect(query['ids'], [12, 19]);
                expect(query['sortAscending'], true);
                expect(invocation.sessionId, session.sessionId);

                final results = [
                  {
                    'countryId': 19,
                    'cityName': 'Passos',
                    'population': 135460,
                  },
                  {
                    'countryId': 12,
                    'cityName': 'San Lorenzo',
                    'population': 204356,
                  },
                ];
                return ToolResult.success(jsonEncode(results));
              },
            ),
          ],
        ),
      );

      final assistantMessage = await session.sendAndWait(
        "Perform a DB query for the 'cities' table using IDs 12 and 19, sorting ascending. "
        'Reply only with lines of the form: [cityname] [population]',
      );

      final responseContent = assistantMessage?.data.content ?? '';
      expect(responseContent, contains('Passos'));
      expect(responseContent, contains('San Lorenzo'));
      expect(responseContent.replaceAll(',', ''), contains('135460'));
      expect(responseContent.replaceAll(',', ''), contains('204356'));
    });
  });
}
