import 'package:copilot_sdk/copilot_sdk.dart';
import 'package:test/test.dart';

import 'harness/sdk_test_context.dart';

void main() {
  final contextFuture = createSdkTestContext();
  registerSdkTestContext(contextFuture);

  group('MCP Servers and Custom Agents', () {
    late SdkTestContext context;

    setUpAll(() async {
      context = await contextFuture;
    });

    group('MCP Servers', () {
      test('should accept MCP server configuration on session create', () async {
        final mcpServers = <String, MCPServerConfig>{
          'test-server': const MCPLocalServerConfig(
            command: 'echo',
            args: ['hello'],
            tools: ['*'],
          ),
        };

        final session = await context.copilotClient.createSession(
          SessionConfig(mcpServers: mcpServers),
        );

        final message = await session.sendAndWait('What is 2+2?');
        expect(message?.data.content, contains('4'));

        await session.destroy();
      });

      test('should accept MCP server configuration on session resume', () async {
        final session1 = await context.copilotClient.createSession();
        final sessionId = session1.sessionId;
        await session1.sendAndWait('What is 1+1?');

        final mcpServers = <String, MCPServerConfig>{
          'test-server': const MCPLocalServerConfig(
            command: 'echo',
            args: ['hello'],
            tools: ['*'],
          ),
        };

        final session2 = await context.copilotClient.resumeSession(
          sessionId,
          ResumeSessionConfig(mcpServers: mcpServers),
        );

        final message = await session2.sendAndWait('What is 3+3?');
        expect(message?.data.content, contains('6'));

        await session2.destroy();
      });

      test('should handle multiple MCP servers', () async {
        final mcpServers = <String, MCPServerConfig>{
          'server1': const MCPLocalServerConfig(
            command: 'echo',
            args: ['server1'],
            tools: ['*'],
          ),
          'server2': const MCPLocalServerConfig(
            command: 'echo',
            args: ['server2'],
            tools: ['*'],
          ),
        };

        final session = await context.copilotClient.createSession(
          SessionConfig(mcpServers: mcpServers),
        );

        expect(session.sessionId, isNotEmpty);
        await session.destroy();
      });
    });

    group('Custom Agents', () {
      test('should accept custom agent configuration on session create', () async {
        final customAgents = [
          const CustomAgentConfig(
            name: 'test-agent',
            displayName: 'Test Agent',
            description: 'A test agent for SDK testing',
            prompt: 'You are a helpful test agent.',
          ),
        ];

        final session = await context.copilotClient.createSession(
          SessionConfig(customAgents: customAgents),
        );

        final message = await session.sendAndWait('What is 5+5?');
        expect(message?.data.content, contains('10'));

        await session.destroy();
      });

      test('should accept custom agent configuration on session resume', () async {
        final session1 = await context.copilotClient.createSession();
        final sessionId = session1.sessionId;
        await session1.sendAndWait('What is 1+1?');

        final customAgents = [
          const CustomAgentConfig(
            name: 'resume-agent',
            displayName: 'Resume Agent',
            description: 'An agent added on resume',
            prompt: 'You are a resume test agent.',
          ),
        ];

        final session2 = await context.copilotClient.resumeSession(
          sessionId,
          ResumeSessionConfig(customAgents: customAgents),
        );

        final message = await session2.sendAndWait('What is 6+6?');
        expect(message?.data.content, contains('12'));

        await session2.destroy();
      });

      test('should handle custom agent with tools configuration', () async {
        final customAgents = [
          const CustomAgentConfig(
            name: 'tool-agent',
            displayName: 'Tool Agent',
            description: 'An agent with specific tools',
            prompt: 'You are an agent with specific tools.',
            tools: ['bash', 'edit'],
          ),
        ];

        final session = await context.copilotClient.createSession(
          SessionConfig(customAgents: customAgents),
        );

        expect(session.sessionId, isNotEmpty);
        await session.destroy();
      });

      test('should handle custom agent with MCP servers', () async {
        final customAgents = [
          const CustomAgentConfig(
            name: 'mcp-agent',
            displayName: 'MCP Agent',
            description: 'An agent with MCP servers.',
            prompt: 'You are an agent with MCP servers.',
            mcpServers: {
              'agent-server': MCPLocalServerConfig(
                command: 'echo',
                args: ['agent-mcp'],
                tools: ['*'],
              ),
            },
          ),
        ];

        final session = await context.copilotClient.createSession(
          SessionConfig(customAgents: customAgents),
        );

        expect(session.sessionId, isNotEmpty);
        await session.destroy();
      });

      test('should handle multiple custom agents', () async {
        final customAgents = [
          const CustomAgentConfig(
            name: 'agent1',
            displayName: 'Agent One',
            description: 'First agent',
            prompt: 'You are agent one.',
          ),
          const CustomAgentConfig(
            name: 'agent2',
            displayName: 'Agent Two',
            description: 'Second agent',
            prompt: 'You are agent two.',
            infer: false,
          ),
        ];

        final session = await context.copilotClient.createSession(
          SessionConfig(customAgents: customAgents),
        );

        expect(session.sessionId, isNotEmpty);
        await session.destroy();
      });
    });

    group('Combined Configuration', () {
      test('should accept both MCP servers and custom agents', () async {
        final mcpServers = <String, MCPServerConfig>{
          'shared-server': const MCPLocalServerConfig(
            command: 'echo',
            args: ['shared'],
            tools: ['*'],
          ),
        };

        final customAgents = [
          const CustomAgentConfig(
            name: 'combined-agent',
            displayName: 'Combined Agent',
            description: 'An agent using shared MCP servers',
            prompt: 'You are a combined test agent.',
          ),
        ];

        final session = await context.copilotClient.createSession(
          SessionConfig(
            mcpServers: mcpServers,
            customAgents: customAgents,
          ),
        );

        final message = await session.sendAndWait('What is 7+7?');
        expect(message?.data.content, contains('14'));

        await session.destroy();
      });
    });
  });
}
