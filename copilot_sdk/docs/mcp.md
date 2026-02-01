# Using MCP Servers with the Copilot SDK (Dart)

The Copilot SDK can integrate with **MCP servers** (Model Context Protocol) to
extend the assistant's capabilities with external tools. MCP servers run as
separate processes and expose tools (functions) that Copilot can invoke during
conversations.

> Note: This is an evolving feature.

## What is MCP?

[Model Context Protocol (MCP)](https://modelcontextprotocol.io/) is an open
standard for connecting AI assistants to external tools and data sources. MCP
servers can:

- Execute code or scripts
- Query databases
- Access file systems
- Call external APIs
- And much more

## Server Types

The SDK supports two types of MCP servers:

| Type | Description | Use Case |
|------|-------------|----------|
| **Local/Stdio** | Runs as a subprocess, communicates via stdin/stdout | Local tools, file access, custom scripts |
| **HTTP/SSE** | Remote server accessed via HTTP | Shared services, cloud-hosted tools |

## Configuration

```dart
final session = await client.createSession(
  SessionConfig(
    model: 'gpt-5',
    mcpServers: {
      'filesystem': MCPLocalServerConfig(
        command: 'npx',
        args: ['-y', '@modelcontextprotocol/server-filesystem', '/tmp'],
        tools: ['*'],
      ),
      'github': MCPRemoteServerConfig(
        url: 'https://api.githubcopilot.com/mcp/',
        headers: {'Authorization': 'Bearer $token'},
        tools: ['*'],
      ),
    },
  ),
);
```

## Notes

- Use `tools: ['*']` to expose all tools from the MCP server.
- Prefer local servers for filesystem access and custom scripting.
- Use remote servers for shared services or centralized APIs.
