import 'package:copilot_sdk/src/copilot/copilot_types.dart';

/// Configuration for the CopilotClient.
class CopilotConfig {
  const CopilotConfig({
    this.cliPath,
    this.cliArgs,
    this.cwd,
    this.port,
    this.useStdio = true,
    this.cliUrl,
    this.logLevel,
    this.autoStart = true,
    this.autoRestart = true,
    this.env,
    this.githubToken,
    this.useLoggedInUser,
    this.timeout = const Duration(seconds: 30),
  });

  /// Path to copilot CLI executable.
  final String? cliPath;

  /// Extra arguments to pass to the CLI executable.
  final List<String>? cliArgs;

  /// Working directory for the CLI process.
  final String? cwd;

  /// Port for the CLI server (TCP mode only).
  final int? port;

  /// Use stdio transport instead of TCP.
  final bool useStdio;

  /// URL of an existing Copilot CLI server to connect to over TCP.
  final String? cliUrl;

  /// Log level for the CLI server.
  final LogLevel? logLevel;

  /// Auto-start the CLI server on first use.
  final bool autoStart;

  /// Auto-restart the CLI server if it crashes.
  final bool autoRestart;

  /// Environment variables to pass to the CLI process.
  final Map<String, String?>? env;

  /// GitHub token to use for authentication.
  final String? githubToken;

  /// Whether to use the logged-in user for authentication.
  final bool? useLoggedInUser;

  /// Request timeout.
  final Duration timeout;

  /// Whether this config uses TCP connection.
  bool get usesTcp => cliUrl != null || !useStdio;

  CopilotConfig copyWith({
    String? cliPath,
    List<String>? cliArgs,
    String? cwd,
    int? port,
    bool? useStdio,
    String? cliUrl,
    LogLevel? logLevel,
    bool? autoStart,
    bool? autoRestart,
    Map<String, String?>? env,
    String? githubToken,
    bool? useLoggedInUser,
    Duration? timeout,
  }) {
    return CopilotConfig(
      cliPath: cliPath ?? this.cliPath,
      cliArgs: cliArgs ?? this.cliArgs,
      cwd: cwd ?? this.cwd,
      port: port ?? this.port,
      useStdio: useStdio ?? this.useStdio,
      cliUrl: cliUrl ?? this.cliUrl,
      logLevel: logLevel ?? this.logLevel,
      autoStart: autoStart ?? this.autoStart,
      autoRestart: autoRestart ?? this.autoRestart,
      env: env ?? this.env,
      githubToken: githubToken ?? this.githubToken,
      useLoggedInUser: useLoggedInUser ?? this.useLoggedInUser,
      timeout: timeout ?? this.timeout,
    );
  }
}

/// System message configuration mode.
enum SystemMessageMode {
  append,
  replace,
}

/// System message configuration for session creation.
sealed class SystemMessageConfig {
  const SystemMessageConfig();

  factory SystemMessageConfig.append({String? content}) =
      SystemMessageAppendConfig;

  factory SystemMessageConfig.replace({required String content}) =
      SystemMessageReplaceConfig;

  Map<String, dynamic> toJson();
}

/// Append mode: Use CLI foundation with optional appended content.
final class SystemMessageAppendConfig extends SystemMessageConfig {
  const SystemMessageAppendConfig({this.content});

  final String? content;

  @override
  Map<String, dynamic> toJson() {
    return {
      'mode': 'append',
      if (content != null) 'content': content,
    };
  }
}

/// Replace mode: Use caller-provided system message entirely.
final class SystemMessageReplaceConfig extends SystemMessageConfig {
  const SystemMessageReplaceConfig({required this.content});

  final String content;

  @override
  Map<String, dynamic> toJson() {
    return {
      'mode': 'replace',
      'content': content,
    };
  }
}

/// Base interface for MCP server configuration.
sealed class MCPServerConfig {
  const MCPServerConfig({
    required this.tools,
    this.timeout,
  });

  factory MCPServerConfig.local({
    required String command,
    required List<String> args,
    required List<String> tools,
    Map<String, String>? env,
    String? cwd,
    int? timeout,
  }) = MCPLocalServerConfig;

  factory MCPServerConfig.remote({
    required String type,
    required String url,
    required List<String> tools,
    Map<String, String>? headers,
    int? timeout,
  }) = MCPRemoteServerConfig;

  final List<String> tools;
  final int? timeout;

  Map<String, dynamic> toJson();
}

/// Configuration for a local/stdio MCP server.
final class MCPLocalServerConfig extends MCPServerConfig {
  const MCPLocalServerConfig({
    required this.command,
    required this.args,
    required super.tools,
    this.env,
    this.cwd,
    super.timeout,
    this.type,
  });

  final String? type;
  final String command;
  final List<String> args;
  final Map<String, String>? env;
  final String? cwd;

  @override
  Map<String, dynamic> toJson() {
    return {
      if (type != null) 'type': type,
      'command': command,
      'args': args,
      'tools': tools,
      if (env != null) 'env': env,
      if (cwd != null) 'cwd': cwd,
      if (timeout != null) 'timeout': timeout,
    };
  }
}

/// Configuration for a remote MCP server (HTTP or SSE).
final class MCPRemoteServerConfig extends MCPServerConfig {
  const MCPRemoteServerConfig({
    required this.type,
    required this.url,
    required super.tools,
    this.headers,
    super.timeout,
  });

  final String type;
  final String url;
  final Map<String, String>? headers;

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'url': url,
      'tools': tools,
      if (headers != null) 'headers': headers,
      if (timeout != null) 'timeout': timeout,
    };
  }
}

/// Configuration for a custom agent.
class CustomAgentConfig {
  const CustomAgentConfig({
    required this.name,
    required this.prompt, this.displayName,
    this.description,
    this.tools,
    this.mcpServers,
    this.infer = true,
  });

  final String name;
  final String? displayName;
  final String? description;
  final List<String>? tools;
  final String prompt;
  final Map<String, MCPServerConfig>? mcpServers;
  final bool infer;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (displayName != null) 'displayName': displayName,
      if (description != null) 'description': description,
      if (tools != null) 'tools': tools,
      'prompt': prompt,
      if (mcpServers != null)
        'mcpServers': mcpServers!.map((k, v) => MapEntry(k, v.toJson())),
      'infer': infer,
    };
  }
}

/// Configuration for infinite sessions.
class InfiniteSessionConfig {
  const InfiniteSessionConfig({
    this.enabled = true,
    this.backgroundCompactionThreshold,
    this.bufferExhaustionThreshold,
  });

  final bool enabled;
  final double? backgroundCompactionThreshold;
  final double? bufferExhaustionThreshold;

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      if (backgroundCompactionThreshold != null)
        'backgroundCompactionThreshold': backgroundCompactionThreshold,
      if (bufferExhaustionThreshold != null)
        'bufferExhaustionThreshold': bufferExhaustionThreshold,
    };
  }
}

/// Configuration for a custom API provider.
class ProviderConfig {
  const ProviderConfig({
    required this.baseUrl, this.type,
    this.wireApi,
    this.apiKey,
    this.bearerToken,
    this.azure,
  });

  final String? type;
  final String? wireApi;
  final String baseUrl;
  final String? apiKey;
  final String? bearerToken;
  final AzureProviderConfig? azure;

  Map<String, dynamic> toJson() {
    return {
      if (type != null) 'type': type,
      if (wireApi != null) 'wireApi': wireApi,
      'baseUrl': baseUrl,
      if (apiKey != null) 'apiKey': apiKey,
      if (bearerToken != null) 'bearerToken': bearerToken,
      if (azure != null) 'azure': azure!.toJson(),
    };
  }
}

/// Azure-specific provider options.
class AzureProviderConfig {
  const AzureProviderConfig({
    this.apiVersion,
  });

  final String? apiVersion;

  Map<String, dynamic> toJson() {
    return {
      if (apiVersion != null) 'apiVersion': apiVersion,
    };
  }
}

/// Configuration for creating or resuming a session.
class SessionConfig {
  const SessionConfig({
    this.sessionId,
    this.model,
    this.reasoningEffort,
    this.configDir,
    this.tools,
    this.systemMessage,
    this.availableTools,
    this.excludedTools,
    this.provider,
    this.onPermissionRequest,
    this.onUserInputRequest,
    this.hooks,
    this.workingDirectory,
    this.streaming = false,
    this.mcpServers,
    this.customAgents,
    this.skillDirectories,
    this.disabledSkills,
    this.infiniteSessions,
  });

  /// Session ID for resuming sessions.
  final String? sessionId;

  /// Model to use for this session.
  final String? model;

  /// Reasoning effort level for models that support it.
  final ReasoningEffort? reasoningEffort;

  /// Override the default configuration directory location.
  final String? configDir;

  /// Custom tools to register.
  final List<ToolDefinition>? tools;

  /// System message configuration.
  final SystemMessageConfig? systemMessage;

  /// List of tool names to allow.
  final List<String>? availableTools;

  /// List of tool names to disable.
  final List<String>? excludedTools;

  /// Custom provider configuration (BYOK).
  final ProviderConfig? provider;

  /// Handler for permission requests.
  final PermissionHandler? onPermissionRequest;

  /// Handler for user input requests.
  final UserInputHandler? onUserInputRequest;

  /// Hook handlers for intercepting session lifecycle events.
  final SessionHooks? hooks;

  /// Working directory for the session.
  final String? workingDirectory;

  /// Enable streaming of assistant message and reasoning chunks.
  final bool streaming;

  /// MCP server configurations for the session.
  final Map<String, MCPServerConfig>? mcpServers;

  /// Custom agent configurations for the session.
  final List<CustomAgentConfig>? customAgents;

  /// Directories to load skills from.
  final List<String>? skillDirectories;

  /// List of skill names to disable.
  final List<String>? disabledSkills;

  /// Infinite session configuration.
  final InfiniteSessionConfig? infiniteSessions;

  SessionConfig copyWith({
    String? sessionId,
    String? model,
    ReasoningEffort? reasoningEffort,
    String? configDir,
    List<ToolDefinition>? tools,
    SystemMessageConfig? systemMessage,
    List<String>? availableTools,
    List<String>? excludedTools,
    ProviderConfig? provider,
    PermissionHandler? onPermissionRequest,
    UserInputHandler? onUserInputRequest,
    SessionHooks? hooks,
    String? workingDirectory,
    bool? streaming,
    Map<String, MCPServerConfig>? mcpServers,
    List<CustomAgentConfig>? customAgents,
    List<String>? skillDirectories,
    List<String>? disabledSkills,
    InfiniteSessionConfig? infiniteSessions,
  }) {
    return SessionConfig(
      sessionId: sessionId ?? this.sessionId,
      model: model ?? this.model,
      reasoningEffort: reasoningEffort ?? this.reasoningEffort,
      configDir: configDir ?? this.configDir,
      tools: tools ?? this.tools,
      systemMessage: systemMessage ?? this.systemMessage,
      availableTools: availableTools ?? this.availableTools,
      excludedTools: excludedTools ?? this.excludedTools,
      provider: provider ?? this.provider,
      onPermissionRequest: onPermissionRequest ?? this.onPermissionRequest,
      onUserInputRequest: onUserInputRequest ?? this.onUserInputRequest,
      hooks: hooks ?? this.hooks,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      streaming: streaming ?? this.streaming,
      mcpServers: mcpServers ?? this.mcpServers,
      customAgents: customAgents ?? this.customAgents,
      skillDirectories: skillDirectories ?? this.skillDirectories,
      disabledSkills: disabledSkills ?? this.disabledSkills,
      infiniteSessions: infiniteSessions ?? this.infiniteSessions,
    );
  }
}

/// Configuration for resuming a session.
class ResumeSessionConfig {
  const ResumeSessionConfig({
    this.tools,
    this.provider,
    this.streaming = false,
    this.reasoningEffort,
    this.onPermissionRequest,
    this.onUserInputRequest,
    this.hooks,
    this.workingDirectory,
    this.mcpServers,
    this.customAgents,
    this.skillDirectories,
    this.disabledSkills,
    this.disableResume = false,
  });

  final List<ToolDefinition>? tools;
  final ProviderConfig? provider;
  final bool streaming;
  final ReasoningEffort? reasoningEffort;
  final PermissionHandler? onPermissionRequest;
  final UserInputHandler? onUserInputRequest;
  final SessionHooks? hooks;
  final String? workingDirectory;
  final Map<String, MCPServerConfig>? mcpServers;
  final List<CustomAgentConfig>? customAgents;
  final List<String>? skillDirectories;
  final List<String>? disabledSkills;
  final bool disableResume;
}

/// Definition of a custom tool.
class ToolDefinition {
  const ToolDefinition({
    required this.name,
    required this.handler, this.description,
    this.parameters,
  });

  final String name;
  final String? description;
  final Map<String, dynamic>? parameters;
  final ToolHandler handler;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (description != null) 'description': description,
      if (parameters != null) 'parameters': parameters,
    };
  }
}

// ============================================================================
// Hook Types
// ============================================================================

/// Base interface for all hook inputs.
class BaseHookInput {
  const BaseHookInput({
    required this.timestamp,
    required this.cwd,
  });

  final int timestamp;
  final String cwd;
}

/// Input for pre-tool-use hook.
class PreToolUseHookInput extends BaseHookInput {
  const PreToolUseHookInput({
    required super.timestamp,
    required super.cwd,
    required this.toolName,
    required this.toolArgs,
  });

  final String toolName;
  final dynamic toolArgs;
}

/// Permission decision for pre-tool-use hook.
enum PermissionDecision {
  allow,
  deny,
  ask,
}

/// Output for pre-tool-use hook.
class PreToolUseHookOutput {
  const PreToolUseHookOutput({
    this.permissionDecision,
    this.permissionDecisionReason,
    this.modifiedArgs,
    this.additionalContext,
    this.suppressOutput,
  });

  final PermissionDecision? permissionDecision;
  final String? permissionDecisionReason;
  final dynamic modifiedArgs;
  final String? additionalContext;
  final bool? suppressOutput;

  Map<String, dynamic> toJson() {
    return {
      if (permissionDecision != null)
        'permissionDecision': permissionDecision!.name,
      if (permissionDecisionReason != null)
        'permissionDecisionReason': permissionDecisionReason,
      if (modifiedArgs != null) 'modifiedArgs': modifiedArgs,
      if (additionalContext != null) 'additionalContext': additionalContext,
      if (suppressOutput != null) 'suppressOutput': suppressOutput,
    };
  }
}

/// Handler for pre-tool-use hook.
typedef PreToolUseHandler =
    Future<PreToolUseHookOutput?> Function(
      PreToolUseHookInput input,
      ToolInvocation invocation,
    );

/// Input for post-tool-use hook.
class PostToolUseHookInput extends BaseHookInput {
  const PostToolUseHookInput({
    required super.timestamp,
    required super.cwd,
    required this.toolName,
    required this.toolArgs,
    required this.toolResult,
  });

  final String toolName;
  final dynamic toolArgs;
  final ToolResult toolResult;
}

/// Output for post-tool-use hook.
class PostToolUseHookOutput {
  const PostToolUseHookOutput({
    this.modifiedResult,
    this.additionalContext,
    this.suppressOutput,
  });

  final ToolResult? modifiedResult;
  final String? additionalContext;
  final bool? suppressOutput;

  Map<String, dynamic> toJson() {
    return {
      if (modifiedResult != null) 'modifiedResult': modifiedResult!.toJson(),
      if (additionalContext != null) 'additionalContext': additionalContext,
      if (suppressOutput != null) 'suppressOutput': suppressOutput,
    };
  }
}

/// Handler for post-tool-use hook.
typedef PostToolUseHandler =
    Future<PostToolUseHookOutput?> Function(
      PostToolUseHookInput input,
      ToolInvocation invocation,
    );

/// Input for user-prompt-submitted hook.
class UserPromptSubmittedHookInput extends BaseHookInput {
  const UserPromptSubmittedHookInput({
    required super.timestamp,
    required super.cwd,
    required this.prompt,
  });

  final String prompt;
}

/// Output for user-prompt-submitted hook.
class UserPromptSubmittedHookOutput {
  const UserPromptSubmittedHookOutput({
    this.modifiedPrompt,
    this.additionalContext,
    this.suppressOutput,
  });

  final String? modifiedPrompt;
  final String? additionalContext;
  final bool? suppressOutput;

  Map<String, dynamic> toJson() {
    return {
      if (modifiedPrompt != null) 'modifiedPrompt': modifiedPrompt,
      if (additionalContext != null) 'additionalContext': additionalContext,
      if (suppressOutput != null) 'suppressOutput': suppressOutput,
    };
  }
}

/// Handler for user-prompt-submitted hook.
typedef UserPromptSubmittedHandler =
    Future<UserPromptSubmittedHookOutput?> Function(
      UserPromptSubmittedHookInput input,
      ToolInvocation invocation,
    );

/// Session start source.
enum SessionStartSource {
  startup,
  resume,
  // ignore: constant_identifier_names
  new_,
}

/// Input for session-start hook.
class SessionStartHookInput extends BaseHookInput {
  const SessionStartHookInput({
    required super.timestamp,
    required super.cwd,
    required this.source,
    this.initialPrompt,
  });

  final SessionStartSource source;
  final String? initialPrompt;
}

/// Output for session-start hook.
class SessionStartHookOutput {
  const SessionStartHookOutput({
    this.additionalContext,
    this.modifiedConfig,
  });

  final String? additionalContext;
  final Map<String, dynamic>? modifiedConfig;

  Map<String, dynamic> toJson() {
    return {
      if (additionalContext != null) 'additionalContext': additionalContext,
      if (modifiedConfig != null) 'modifiedConfig': modifiedConfig,
    };
  }
}

/// Handler for session-start hook.
typedef SessionStartHandler =
    Future<SessionStartHookOutput?> Function(
      SessionStartHookInput input,
      ToolInvocation invocation,
    );

/// Session end reason.
enum SessionEndReason {
  complete,
  error,
  abort,
  timeout,
  userExit,
}

/// Input for session-end hook.
class SessionEndHookInput extends BaseHookInput {
  const SessionEndHookInput({
    required super.timestamp,
    required super.cwd,
    required this.reason,
    this.finalMessage,
    this.error,
  });

  final SessionEndReason reason;
  final String? finalMessage;
  final String? error;
}

/// Output for session-end hook.
class SessionEndHookOutput {
  const SessionEndHookOutput({
    this.suppressOutput,
    this.cleanupActions,
    this.sessionSummary,
  });

  final bool? suppressOutput;
  final List<String>? cleanupActions;
  final String? sessionSummary;

  Map<String, dynamic> toJson() {
    return {
      if (suppressOutput != null) 'suppressOutput': suppressOutput,
      if (cleanupActions != null) 'cleanupActions': cleanupActions,
      if (sessionSummary != null) 'sessionSummary': sessionSummary,
    };
  }
}

/// Handler for session-end hook.
typedef SessionEndHandler =
    Future<SessionEndHookOutput?> Function(
      SessionEndHookInput input,
      ToolInvocation invocation,
    );

/// Error context for error-occurred hook.
enum ErrorContext {
  modelCall,
  toolExecution,
  system,
  userInput,
}

/// Input for error-occurred hook.
class ErrorOccurredHookInput extends BaseHookInput {
  const ErrorOccurredHookInput({
    required super.timestamp,
    required super.cwd,
    required this.error,
    required this.errorContext,
    required this.recoverable,
  });

  final String error;
  final ErrorContext errorContext;
  final bool recoverable;
}

/// Error handling strategy.
enum ErrorHandling {
  retry,
  skip,
  abort,
}

/// Output for error-occurred hook.
class ErrorOccurredHookOutput {
  const ErrorOccurredHookOutput({
    this.suppressOutput,
    this.errorHandling,
    this.retryCount,
    this.userNotification,
  });

  final bool? suppressOutput;
  final ErrorHandling? errorHandling;
  final int? retryCount;
  final String? userNotification;

  Map<String, dynamic> toJson() {
    return {
      if (suppressOutput != null) 'suppressOutput': suppressOutput,
      if (errorHandling != null) 'errorHandling': errorHandling!.name,
      if (retryCount != null) 'retryCount': retryCount,
      if (userNotification != null) 'userNotification': userNotification,
    };
  }
}

/// Handler for error-occurred hook.
typedef ErrorOccurredHandler =
    Future<ErrorOccurredHookOutput?> Function(
      ErrorOccurredHookInput input,
      ToolInvocation invocation,
    );

/// Configuration for session hooks.
class SessionHooks {
  const SessionHooks({
    this.onPreToolUse,
    this.onPostToolUse,
    this.onUserPromptSubmitted,
    this.onSessionStart,
    this.onSessionEnd,
    this.onErrorOccurred,
  });

  final PreToolUseHandler? onPreToolUse;
  final PostToolUseHandler? onPostToolUse;
  final UserPromptSubmittedHandler? onUserPromptSubmitted;
  final SessionStartHandler? onSessionStart;
  final SessionEndHandler? onSessionEnd;
  final ErrorOccurredHandler? onErrorOccurred;
}
