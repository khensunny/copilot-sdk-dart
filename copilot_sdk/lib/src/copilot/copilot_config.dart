import 'package:copilot_sdk/src/copilot/copilot_types.dart';

/// Configuration for the CopilotClient.
class CopilotConfig {
  /// Creates a configuration for the Copilot CLI client.
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

  /// Creates a copy with updated values.
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
  /// Append to the default system message.
  append,

  /// Replace the default system message entirely.
  replace,
}

/// System message configuration for session creation.
sealed class SystemMessageConfig {
  const SystemMessageConfig();

  /// Creates an append-mode system message config.
  factory SystemMessageConfig.append({String? content}) = SystemMessageAppendConfig;

  /// Creates a replace-mode system message config.
  factory SystemMessageConfig.replace({required String content}) = SystemMessageReplaceConfig;

  /// Serializes the system message config to JSON.
  Map<String, dynamic> toJson();
}

/// Append mode: Use CLI foundation with optional appended content.
final class SystemMessageAppendConfig extends SystemMessageConfig {
  /// Creates an append-mode system message config.
  const SystemMessageAppendConfig({this.content});

  /// Optional appended content.
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
  /// Creates a replace-mode system message config.
  const SystemMessageReplaceConfig({required this.content});

  /// Replacement system message content.
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

  /// Creates a local/stdio MCP server configuration.
  factory MCPServerConfig.local({
    required String command,
    required List<String> args,
    required List<String> tools,
    Map<String, String>? env,
    String? cwd,
    int? timeout,
  }) = MCPLocalServerConfig;

  /// Creates a remote MCP server configuration.
  factory MCPServerConfig.remote({
    required String type,
    required String url,
    required List<String> tools,
    Map<String, String>? headers,
    int? timeout,
  }) = MCPRemoteServerConfig;

  /// Tool allowlist for the MCP server.
  final List<String> tools;

  /// Optional timeout in milliseconds.
  final int? timeout;

  /// Serializes the MCP server config to JSON.
  Map<String, dynamic> toJson();
}

/// Configuration for a local/stdio MCP server.
final class MCPLocalServerConfig extends MCPServerConfig {
  /// Creates configuration for a local MCP server.
  const MCPLocalServerConfig({
    required this.command,
    required this.args,
    required super.tools,
    this.env,
    this.cwd,
    super.timeout,
    this.type,
  });

  /// Optional override type.
  final String? type;

  /// Command to execute.
  final String command;

  /// Command arguments.
  final List<String> args;

  /// Optional environment variables.
  final Map<String, String>? env;

  /// Optional working directory.
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
  /// Creates configuration for a remote MCP server.
  const MCPRemoteServerConfig({
    required this.type,
    required this.url,
    required super.tools,
    this.headers,
    super.timeout,
  });

  /// Remote server type identifier.
  final String type;

  /// Remote server URL.
  final String url;

  /// Optional headers to send.
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
  /// Creates a configuration for a custom agent.
  const CustomAgentConfig({
    required this.name,
    required this.prompt,
    this.displayName,
    this.description,
    this.tools,
    this.mcpServers,
    this.infer = true,
  });

  /// Unique agent name.
  final String name;

  /// Optional display name shown to users.
  final String? displayName;

  /// Optional agent description.
  final String? description;

  /// Optional tool allowlist for the agent.
  final List<String>? tools;

  /// Prompt used to initialize the agent.
  final String prompt;

  /// Optional MCP server configuration for the agent.
  final Map<String, MCPServerConfig>? mcpServers;

  /// Whether to infer missing fields from defaults.
  final bool infer;

  /// Serializes the agent config to JSON.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (displayName != null) 'displayName': displayName,
      if (description != null) 'description': description,
      if (tools != null) 'tools': tools,
      'prompt': prompt,
      if (mcpServers != null) 'mcpServers': mcpServers!.map((k, v) => MapEntry(k, v.toJson())),
      'infer': infer,
    };
  }
}

/// Configuration for infinite sessions.
class InfiniteSessionConfig {
  /// Creates infinite session configuration.
  const InfiniteSessionConfig({
    this.enabled = true,
    this.backgroundCompactionThreshold,
    this.bufferExhaustionThreshold,
  });

  /// Whether infinite sessions are enabled.
  final bool enabled;

  /// Threshold for background compaction.
  final double? backgroundCompactionThreshold;

  /// Threshold for buffer exhaustion.
  final double? bufferExhaustionThreshold;

  /// Serializes the config to JSON.
  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      if (backgroundCompactionThreshold != null) 'backgroundCompactionThreshold': backgroundCompactionThreshold,
      if (bufferExhaustionThreshold != null) 'bufferExhaustionThreshold': bufferExhaustionThreshold,
    };
  }
}

/// Configuration for a custom API provider.
class ProviderConfig {
  /// Creates custom provider configuration.
  const ProviderConfig({
    required this.baseUrl,
    this.type,
    this.wireApi,
    this.apiKey,
    this.bearerToken,
    this.azure,
  });

  /// Provider type identifier.
  final String? type;

  /// Wire API identifier.
  final String? wireApi;

  /// Base URL for the provider.
  final String baseUrl;

  /// Optional API key for authentication.
  final String? apiKey;

  /// Optional bearer token for authentication.
  final String? bearerToken;

  /// Optional Azure provider settings.
  final AzureProviderConfig? azure;

  /// Serializes the provider config to JSON.
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
  /// Creates Azure-specific provider settings.
  const AzureProviderConfig({
    this.apiVersion,
  });

  /// Optional Azure API version.
  final String? apiVersion;

  /// Serializes the Azure config to JSON.
  Map<String, dynamic> toJson() {
    return {
      if (apiVersion != null) 'apiVersion': apiVersion,
    };
  }
}

/// Configuration for creating or resuming a session.
class SessionConfig {
  /// Creates configuration for creating or resuming a session.
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

  /// Creates a copy with updated values.
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
  /// Creates configuration for resuming a session.
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

  /// Optional tools to register for the session.
  final List<ToolDefinition>? tools;

  /// Provider configuration for the session.
  final ProviderConfig? provider;

  /// Whether to enable streaming responses.
  final bool streaming;

  /// Reasoning effort setting for supported models.
  final ReasoningEffort? reasoningEffort;

  /// Handler for permission requests.
  final PermissionHandler? onPermissionRequest;

  /// Handler for user input requests.
  final UserInputHandler? onUserInputRequest;

  /// Hook handlers for lifecycle events.
  final SessionHooks? hooks;

  /// Working directory for the session.
  final String? workingDirectory;

  /// MCP servers configured for the session.
  final Map<String, MCPServerConfig>? mcpServers;

  /// Custom agents configured for the session.
  final List<CustomAgentConfig>? customAgents;

  /// Directories to load skills from.
  final List<String>? skillDirectories;

  /// Skill names to disable.
  final List<String>? disabledSkills;

  /// Whether to disable session resumption.
  final bool disableResume;
}

/// Definition of a custom tool.
class ToolDefinition {
  /// Creates a tool definition.
  const ToolDefinition({
    required this.name,
    required this.handler,
    this.description,
    this.parameters,
  });

  /// Tool name used for invocation.
  final String name;

  /// Optional tool description for the model.
  final String? description;

  /// JSON schema parameters for the tool.
  final Map<String, dynamic>? parameters;

  /// Handler invoked when the tool executes.
  final ToolHandler handler;

  /// Serializes the tool definition to JSON.
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
  /// Creates a base hook input.
  const BaseHookInput({
    required this.timestamp,
    required this.cwd,
  });

  /// Unix timestamp for the hook event.
  final int timestamp;

  /// Working directory associated with the event.
  final String cwd;
}

/// Input for pre-tool-use hook.
class PreToolUseHookInput extends BaseHookInput {
  /// Creates input for pre-tool-use hooks.
  const PreToolUseHookInput({
    required super.timestamp,
    required super.cwd,
    required this.toolName,
    required this.toolArgs,
  });

  /// Name of the tool being invoked.
  final String toolName;

  /// Arguments supplied to the tool.
  final dynamic toolArgs;
}

/// Permission decision for pre-tool-use hook.
enum PermissionDecision {
  /// Allow the tool invocation.
  allow,

  /// Deny the tool invocation.
  deny,

  /// Ask the user for permission.
  ask,
}

/// Output for pre-tool-use hook.
class PreToolUseHookOutput {
  /// Creates output for pre-tool-use hooks.
  const PreToolUseHookOutput({
    this.permissionDecision,
    this.permissionDecisionReason,
    this.modifiedArgs,
    this.additionalContext,
    this.suppressOutput,
  });

  /// Requested permission decision.
  final PermissionDecision? permissionDecision;

  /// Optional reason for the permission decision.
  final String? permissionDecisionReason;

  /// Optional modified tool arguments.
  final dynamic modifiedArgs;

  /// Optional extra context for the model.
  final String? additionalContext;

  /// Whether to suppress output.
  final bool? suppressOutput;

  /// Serializes the hook output to JSON.
  Map<String, dynamic> toJson() {
    return {
      if (permissionDecision != null) 'permissionDecision': permissionDecision!.name,
      if (permissionDecisionReason != null) 'permissionDecisionReason': permissionDecisionReason,
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
  /// Creates input for post-tool-use hooks.
  const PostToolUseHookInput({
    required super.timestamp,
    required super.cwd,
    required this.toolName,
    required this.toolArgs,
    required this.toolResult,
  });

  /// Name of the tool that executed.
  final String toolName;

  /// Arguments supplied to the tool.
  final dynamic toolArgs;

  /// Result returned from the tool.
  final ToolResult toolResult;
}

/// Output for post-tool-use hook.
class PostToolUseHookOutput {
  /// Creates output for post-tool-use hooks.
  const PostToolUseHookOutput({
    this.modifiedResult,
    this.additionalContext,
    this.suppressOutput,
  });

  /// Optional modified tool result.
  final ToolResult? modifiedResult;

  /// Optional extra context for the model.
  final String? additionalContext;

  /// Whether to suppress output.
  final bool? suppressOutput;

  /// Serializes the hook output to JSON.
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
  /// Creates input for user-prompt-submitted hooks.
  const UserPromptSubmittedHookInput({
    required super.timestamp,
    required super.cwd,
    required this.prompt,
  });

  /// Prompt submitted by the user.
  final String prompt;
}

/// Output for user-prompt-submitted hook.
class UserPromptSubmittedHookOutput {
  /// Creates output for user-prompt-submitted hooks.
  const UserPromptSubmittedHookOutput({
    this.modifiedPrompt,
    this.additionalContext,
    this.suppressOutput,
  });

  /// Optional modified prompt text.
  final String? modifiedPrompt;

  /// Optional extra context for the model.
  final String? additionalContext;

  /// Whether to suppress output.
  final bool? suppressOutput;

  /// Serializes the hook output to JSON.
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
  /// Session started during process startup.
  startup,

  /// Session resumed from an existing session ID.
  resume,

  /// Session created as a new conversation.
  new_,
}

/// Input for session-start hook.
class SessionStartHookInput extends BaseHookInput {
  /// Creates input for session-start hooks.
  const SessionStartHookInput({
    required super.timestamp,
    required super.cwd,
    required this.source,
    this.initialPrompt,
  });

  /// Source of the session start.
  final SessionStartSource source;

  /// Optional initial prompt provided at session start.
  final String? initialPrompt;
}

/// Output for session-start hook.
class SessionStartHookOutput {
  /// Creates output for session-start hooks.
  const SessionStartHookOutput({
    this.additionalContext,
    this.modifiedConfig,
  });

  /// Optional extra context for the model.
  final String? additionalContext;

  /// Optional modified session config fields.
  final Map<String, dynamic>? modifiedConfig;

  /// Serializes the hook output to JSON.
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
  /// Session completed normally.
  complete,

  /// Session ended due to an error.
  error,

  /// Session aborted by the user or system.
  abort,

  /// Session ended due to timeout.
  timeout,

  /// Session ended because the user exited.
  userExit,
}

/// Input for session-end hook.
class SessionEndHookInput extends BaseHookInput {
  /// Creates input for session-end hooks.
  const SessionEndHookInput({
    required super.timestamp,
    required super.cwd,
    required this.reason,
    this.finalMessage,
    this.error,
  });

  /// Reason the session ended.
  final SessionEndReason reason;

  /// Optional final message content.
  final String? finalMessage;

  /// Optional error message.
  final String? error;
}

/// Output for session-end hook.
class SessionEndHookOutput {
  /// Creates output for session-end hooks.
  const SessionEndHookOutput({
    this.suppressOutput,
    this.cleanupActions,
    this.sessionSummary,
  });

  /// Whether to suppress output.
  final bool? suppressOutput;

  /// Optional cleanup actions to run.
  final List<String>? cleanupActions;

  /// Optional session summary text.
  final String? sessionSummary;

  /// Serializes the hook output to JSON.
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
  /// Error occurred during a model call.
  modelCall,

  /// Error occurred during tool execution.
  toolExecution,

  /// Error occurred in system processing.
  system,

  /// Error occurred while handling user input.
  userInput,
}

/// Input for error-occurred hook.
class ErrorOccurredHookInput extends BaseHookInput {
  /// Creates input for error-occurred hooks.
  const ErrorOccurredHookInput({
    required super.timestamp,
    required super.cwd,
    required this.error,
    required this.errorContext,
    required this.recoverable,
  });

  /// Error message.
  final String error;

  /// Context in which the error occurred.
  final ErrorContext errorContext;

  /// Whether the error is recoverable.
  final bool recoverable;
}

/// Error handling strategy.
enum ErrorHandling {
  /// Retry the failed operation.
  retry,

  /// Skip the failed operation.
  skip,

  /// Abort the session.
  abort,
}

/// Output for error-occurred hook.
class ErrorOccurredHookOutput {
  /// Creates output for error-occurred hooks.
  const ErrorOccurredHookOutput({
    this.suppressOutput,
    this.errorHandling,
    this.retryCount,
    this.userNotification,
  });

  /// Whether to suppress output.
  final bool? suppressOutput;

  /// Error handling strategy.
  final ErrorHandling? errorHandling;

  /// Optional retry count.
  final int? retryCount;

  /// Optional user-facing notification.
  final String? userNotification;

  /// Serializes the hook output to JSON.
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
  /// Creates configuration for session hooks.
  const SessionHooks({
    this.onPreToolUse,
    this.onPostToolUse,
    this.onUserPromptSubmitted,
    this.onSessionStart,
    this.onSessionEnd,
    this.onErrorOccurred,
  });

  /// Handler for pre-tool-use hooks.
  final PreToolUseHandler? onPreToolUse;

  /// Handler for post-tool-use hooks.
  final PostToolUseHandler? onPostToolUse;

  /// Handler for user-prompt-submitted hooks.
  final UserPromptSubmittedHandler? onUserPromptSubmitted;

  /// Handler for session-start hooks.
  final SessionStartHandler? onSessionStart;

  /// Handler for session-end hooks.
  final SessionEndHandler? onSessionEnd;

  /// Handler for error-occurred hooks.
  final ErrorOccurredHandler? onErrorOccurred;
}
