/// Connection state for the CopilotClient.
enum ConnectionState {
  /// Not connected to the CLI server.
  disconnected,

  /// Connection is being established.
  connecting,

  /// Connected and ready to send requests.
  connected,

  /// Connection failed or entered an error state.
  error,
}

/// Log level for the CLI server.
enum LogLevel {
  /// Disable logging.
  none,

  /// Log errors only.
  error,

  /// Log warnings and errors.
  warning,

  /// Log informational messages.
  info,

  /// Log debug output.
  debug,

  /// Log all messages.
  all,
}

/// Permission kinds for tool execution.
enum PermissionKind {
  /// Shell command execution.
  shell,

  /// File write access.
  write,

  /// File read access.
  read,

  /// MCP server access.
  mcp,

  /// URL/network access.
  url,
}

/// Result kind for permission requests.
enum PermissionResultKind {
  /// Permission granted.
  approved,

  /// Permission denied by policy rules.
  deniedByRules,

  /// Permission denied without a matching approval rule.
  deniedNoApprovalRuleAndCouldNotRequestFromUser,

  /// Permission denied interactively by the user.
  deniedInteractivelyByUser,
}

/// Result of a permission request.
class PermissionResult {
  /// Creates a permission result.
  const PermissionResult({
    required this.kind,
    this.rules,
  });

  /// Creates an approved permission result.
  factory PermissionResult.approved() =>
      const PermissionResult(kind: PermissionResultKind.approved);

  /// Creates a denied permission result.
  factory PermissionResult.denied(PermissionResultKind kind) =>
      PermissionResult(kind: kind);

  /// Parses a permission result from JSON.
  factory PermissionResult.fromJson(Map<String, dynamic> json) {
    final kindStr = json['kind'] as String;
    final kind = switch (kindStr) {
      'approved' => PermissionResultKind.approved,
      'denied-by-rules' => PermissionResultKind.deniedByRules,
      'denied-no-approval-rule-and-could-not-request-from-user' =>
        PermissionResultKind.deniedNoApprovalRuleAndCouldNotRequestFromUser,
      'denied-interactively-by-user' =>
        PermissionResultKind.deniedInteractivelyByUser,
      _ => PermissionResultKind.deniedByRules,
    };
    return PermissionResult(
      kind: kind,
      rules: json['rules'] as List<dynamic>?,
    );
  }

  /// The permission result kind.
  final PermissionResultKind kind;

  /// Optional rules that contributed to this decision.
  final List<dynamic>? rules;

  /// Serializes the permission result to JSON.
  Map<String, dynamic> toJson() {
    final kindStr = switch (kind) {
      PermissionResultKind.approved => 'approved',
      PermissionResultKind.deniedByRules => 'denied-by-rules',
      PermissionResultKind.deniedNoApprovalRuleAndCouldNotRequestFromUser =>
        'denied-no-approval-rule-and-could-not-request-from-user',
      PermissionResultKind.deniedInteractivelyByUser =>
        'denied-interactively-by-user',
    };
    return {
      'kind': kindStr,
      if (rules != null) 'rules': rules,
    };
  }
}

/// Type of tool result.
enum ToolResultType {
  /// Tool completed successfully.
  success,

  /// Tool failed while executing.
  failure,

  /// Tool execution was rejected.
  rejected,

  /// Tool execution was denied by permissions.
  denied,
}

/// Handler for custom tool execution.
///
/// Receives parsed arguments and the invocation metadata.
typedef ToolHandler =
    Future<ToolResult> Function(
      Map<String, dynamic> arguments,
      ToolInvocation invocation,
    );

/// Handler for permission requests.
///
/// Receives the permission request and tool invocation details.
typedef PermissionHandler =
    Future<PermissionResult> Function(
      PermissionRequest request,
      ToolInvocation invocation,
    );

/// Handler for user input requests.
///
/// Receives a user-facing prompt and returns a response.
typedef UserInputHandler =
    Future<UserInputResult> Function(
      UserInputRequest request,
    );

/// Information about a tool invocation.
class ToolInvocation {
  /// Creates a tool invocation payload.
  const ToolInvocation({
    required this.sessionId,
    required this.toolCallId,
    required this.toolName,
    required this.arguments,
  });

  /// Parses a tool invocation from JSON.
  factory ToolInvocation.fromJson(Map<String, dynamic> json) {
    return ToolInvocation(
      sessionId: json['sessionId'] as String,
      toolCallId: json['toolCallId'] as String,
      toolName: json['toolName'] as String,
      arguments: (json['arguments'] as Map<String, dynamic>?) ?? {},
    );
  }

  /// Session identifier for the tool call.
  final String sessionId;

  /// Unique tool call identifier.
  final String toolCallId;

  /// Name of the tool being invoked.
  final String toolName;

  /// Arguments passed to the tool.
  final Map<String, dynamic> arguments;

  /// Serializes the invocation to JSON.
  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'toolCallId': toolCallId,
      'toolName': toolName,
      'arguments': arguments,
    };
  }
}

/// Binary result for tool execution.
class ToolBinaryResult {
  /// Creates a binary tool result.
  const ToolBinaryResult({
    required this.data,
    required this.mimeType,
    required this.type,
    this.description,
  });

  /// Parses a binary tool result from JSON.
  factory ToolBinaryResult.fromJson(Map<String, dynamic> json) {
    return ToolBinaryResult(
      data: json['data'] as String,
      mimeType: json['mimeType'] as String,
      type: json['type'] as String,
      description: json['description'] as String?,
    );
  }

  /// Base64-encoded data payload.
  final String data;

  /// MIME type of the binary data.
  final String mimeType;

  /// Result type identifier (e.g. image, file).
  final String type;

  /// Optional description of the payload.
  final String? description;

  /// Serializes the binary result to JSON.
  Map<String, dynamic> toJson() {
    return {
      'data': data,
      'mimeType': mimeType,
      'type': type,
      if (description != null) 'description': description,
    };
  }
}

/// Result of a tool execution.
class ToolResult {
  /// Creates a tool result.
  const ToolResult({
    required this.textResultForLlm,
    this.resultType = ToolResultType.success,
    this.binaryResultsForLlm,
    this.error,
    this.sessionLog,
    this.toolTelemetry,
  });

  /// Parses a tool result from JSON.
  factory ToolResult.fromJson(Map<String, dynamic> json) {
    return ToolResult(
      textResultForLlm: json['textResultForLlm'] as String,
      resultType: ToolResultType.values.firstWhere(
        (e) => e.name == json['resultType'],
        orElse: () => ToolResultType.success,
      ),
      binaryResultsForLlm: (json['binaryResultsForLlm'] as List<dynamic>?)
          ?.map((e) => ToolBinaryResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      error: json['error'] as String?,
      sessionLog: json['sessionLog'] as String?,
      toolTelemetry: json['toolTelemetry'] as Map<String, dynamic>?,
    );
  }

  /// Creates a successful tool result with text output.
  factory ToolResult.success(String text) => ToolResult(
    textResultForLlm: text,
    toolTelemetry: {},
  );

  /// Creates a failed tool result with optional error details.
  factory ToolResult.failure(String text, {String? error}) => ToolResult(
    textResultForLlm: text,
    resultType: ToolResultType.failure,
    error: error,
  );

  /// Creates a rejected tool result.
  factory ToolResult.rejected(String text) =>
      ToolResult(textResultForLlm: text, resultType: ToolResultType.rejected);

  /// Creates a denied tool result.
  factory ToolResult.denied(String text) =>
      ToolResult(textResultForLlm: text, resultType: ToolResultType.denied);

  /// Text output returned to the model.
  final String textResultForLlm;

  /// Result type for the tool execution.
  final ToolResultType resultType;

  /// Optional binary payloads for the model.
  final List<ToolBinaryResult>? binaryResultsForLlm;

  /// Optional error message for failures.
  final String? error;

  /// Optional session log text.
  final String? sessionLog;

  /// Optional telemetry data for the tool call.
  final Map<String, dynamic>? toolTelemetry;

  /// Serializes the tool result to JSON.
  Map<String, dynamic> toJson() {
    return {
      'textResultForLlm': textResultForLlm,
      'resultType': resultType.name,
      if (binaryResultsForLlm != null)
        'binaryResultsForLlm': binaryResultsForLlm!
            .map((b) => b.toJson())
            .toList(),
      if (error != null) 'error': error,
      if (sessionLog != null) 'sessionLog': sessionLog,
      'toolTelemetry': toolTelemetry ?? {},
    };
  }
}

/// A request for permission to execute a tool.
class PermissionRequest {
  /// Creates a permission request payload.
  const PermissionRequest({
    required this.kind,
    this.toolCallId,
    this.additionalFields,
  });

  /// Parses a permission request from JSON.
  factory PermissionRequest.fromJson(Map<String, dynamic> json) {
    final knownKeys = {'kind', 'toolCallId'};
    final additionalFields = <String, dynamic>{};
    for (final entry in json.entries) {
      if (!knownKeys.contains(entry.key)) {
        additionalFields[entry.key] = entry.value;
      }
    }
    return PermissionRequest(
      kind: PermissionKind.values.firstWhere(
        (e) => e.name == json['kind'],
        orElse: () => PermissionKind.read,
      ),
      toolCallId: json['toolCallId'] as String?,
      additionalFields: additionalFields.isNotEmpty ? additionalFields : null,
    );
  }

  /// Permission kind being requested.
  final PermissionKind kind;

  /// Optional tool call identifier associated with the request.
  final String? toolCallId;

  /// Additional payload fields for the request.
  final Map<String, dynamic>? additionalFields;

  /// Serializes the permission request to JSON.
  Map<String, dynamic> toJson() {
    return {
      'kind': kind.name,
      if (toolCallId != null) 'toolCallId': toolCallId,
      if (additionalFields != null) ...additionalFields!,
    };
  }
}

/// A request for user input.
class UserInputRequest {
  /// Creates a user input request.
  const UserInputRequest({
    required this.question,
    this.choices,
    this.allowFreeform = true,
  });

  /// Parses a user input request from JSON.
  factory UserInputRequest.fromJson(Map<String, dynamic> json) {
    return UserInputRequest(
      question: json['question'] as String,
      choices: (json['choices'] as List<dynamic>?)?.cast<String>(),
      allowFreeform: json['allowFreeform'] as bool? ?? true,
    );
  }

  /// Prompt presented to the user.
  final String question;

  /// Optional list of selectable choices.
  final List<String>? choices;

  /// Whether freeform input is allowed.
  final bool allowFreeform;

  /// Serializes the request to JSON.
  Map<String, dynamic> toJson() {
    return {
      'question': question,
      if (choices != null) 'choices': choices,
      'allowFreeform': allowFreeform,
    };
  }
}

/// Result of a user input request.
class UserInputResult {
  /// Creates a user input result.
  const UserInputResult({
    required this.answer,
    this.wasFreeform = false,
  });

  /// Parses a user input result from JSON.
  factory UserInputResult.fromJson(Map<String, dynamic> json) {
    return UserInputResult(
      answer: json['answer'] as String,
      wasFreeform: json['wasFreeform'] as bool? ?? false,
    );
  }

  /// User-provided answer.
  final String answer;

  /// Whether the answer was freeform.
  final bool wasFreeform;

  /// Serializes the result to JSON.
  Map<String, dynamic> toJson() {
    return {
      'answer': answer,
      'wasFreeform': wasFreeform,
    };
  }
}

/// Type of attachment.
enum AttachmentType {
  /// File attachment.
  file,

  /// Directory attachment.
  directory,
}

/// Attachment for messages.
class Attachment {
  /// Creates a message attachment.
  const Attachment({
    required this.type,
    required this.path,
    this.displayName,
  });

  /// Parses an attachment from JSON.
  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      type: AttachmentType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AttachmentType.file,
      ),
      path: json['path'] as String,
      displayName: json['displayName'] as String?,
    );
  }

  /// Creates a file attachment.
  factory Attachment.file(String path, {String? displayName}) => Attachment(
    type: AttachmentType.file,
    path: path,
    displayName: displayName,
  );

  /// Creates a directory attachment.
  factory Attachment.directory(String path, {String? displayName}) =>
      Attachment(
        type: AttachmentType.directory,
        path: path,
        displayName: displayName,
      );

  /// Attachment type.
  final AttachmentType type;

  /// File or directory path.
  final String path;

  /// Optional display name for UI rendering.
  final String? displayName;

  /// Serializes the attachment to JSON.
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'path': path,
      if (displayName != null) 'displayName': displayName,
    };
  }
}

/// Model capabilities.
class ModelCapabilities {
  /// Creates model capability metadata.
  const ModelCapabilities({
    required this.supportsVision,
    required this.supportsReasoningEffort,
    required this.maxContextWindowTokens,
    this.maxPromptTokens,
    this.vision,
  });

  /// Parses model capabilities from JSON.
  factory ModelCapabilities.fromJson(Map<String, dynamic> json) {
    final supports = json['supports'] as Map<String, dynamic>? ?? {};
    final limits = json['limits'] as Map<String, dynamic>? ?? {};
    return ModelCapabilities(
      supportsVision: supports['vision'] as bool? ?? false,
      supportsReasoningEffort: supports['reasoningEffort'] as bool? ?? false,
      maxPromptTokens: limits['max_prompt_tokens'] as int?,
      maxContextWindowTokens: limits['max_context_window_tokens'] as int? ?? 0,
      vision: limits['vision'] != null
          ? VisionCapabilities.fromJson(
              limits['vision'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  /// Whether the model supports vision input.
  final bool supportsVision;

  /// Whether the model supports reasoning effort settings.
  final bool supportsReasoningEffort;

  /// Maximum prompt token limit, if provided.
  final int? maxPromptTokens;

  /// Maximum context window size in tokens.
  final int maxContextWindowTokens;

  /// Vision capability details, if available.
  final VisionCapabilities? vision;

  /// Serializes the capabilities to JSON.
  Map<String, dynamic> toJson() {
    return {
      'supports': {
        'vision': supportsVision,
        'reasoningEffort': supportsReasoningEffort,
      },
      'limits': {
        if (maxPromptTokens != null) 'max_prompt_tokens': maxPromptTokens,
        'max_context_window_tokens': maxContextWindowTokens,
        if (vision != null) 'vision': vision!.toJson(),
      },
    };
  }
}

/// Vision capabilities for a model.
class VisionCapabilities {
  /// Creates vision capability metadata.
  const VisionCapabilities({
    required this.supportedMediaTypes,
    required this.maxPromptImages,
    required this.maxPromptImageSize,
  });

  /// Parses vision capabilities from JSON.
  factory VisionCapabilities.fromJson(Map<String, dynamic> json) {
    return VisionCapabilities(
      supportedMediaTypes:
          (json['supported_media_types'] as List<dynamic>?)?.cast<String>() ??
          [],
      maxPromptImages: json['max_prompt_images'] as int? ?? 0,
      maxPromptImageSize: json['max_prompt_image_size'] as int? ?? 0,
    );
  }

  /// Supported MIME types for vision inputs.
  final List<String> supportedMediaTypes;

  /// Maximum number of images in a prompt.
  final int maxPromptImages;

  /// Maximum size per prompt image in bytes.
  final int maxPromptImageSize;

  /// Serializes the vision capabilities to JSON.
  Map<String, dynamic> toJson() {
    return {
      'supported_media_types': supportedMediaTypes,
      'max_prompt_images': maxPromptImages,
      'max_prompt_image_size': maxPromptImageSize,
    };
  }
}

/// Model policy state.
class ModelPolicy {
  /// Creates model policy metadata.
  const ModelPolicy({
    required this.state,
    required this.terms,
  });

  /// Parses model policy from JSON.
  factory ModelPolicy.fromJson(Map<String, dynamic> json) {
    return ModelPolicy(
      state: json['state'] as String,
      terms: json['terms'] as String,
    );
  }

  /// Policy state value.
  final String state;

  /// Policy terms associated with the model.
  final String terms;

  /// Serializes the policy to JSON.
  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'terms': terms,
    };
  }
}

/// Model billing information.
class ModelBilling {
  /// Creates billing metadata.
  const ModelBilling({
    required this.multiplier,
  });

  /// Parses billing metadata from JSON.
  factory ModelBilling.fromJson(Map<String, dynamic> json) {
    return ModelBilling(
      multiplier: (json['multiplier'] as num).toDouble(),
    );
  }

  /// Billing multiplier for the model.
  final double multiplier;

  /// Serializes billing metadata to JSON.
  Map<String, dynamic> toJson() {
    return {
      'multiplier': multiplier,
    };
  }
}

/// Reasoning effort levels.
enum ReasoningEffort {
  /// Low reasoning effort.
  low,

  /// Medium reasoning effort.
  medium,

  /// High reasoning effort.
  high,

  /// Extra high reasoning effort.
  xhigh,
}

/// Model information returned from listModels.
class ModelInfo {
  /// Creates model metadata.
  const ModelInfo({
    required this.id,
    required this.name,
    required this.capabilities,
    this.policy,
    this.billing,
    this.supportedReasoningEfforts,
    this.defaultReasoningEffort,
  });

  /// Parses model information from JSON.
  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      capabilities: ModelCapabilities.fromJson(
        json['capabilities'] as Map<String, dynamic>,
      ),
      policy: json['policy'] != null
          ? ModelPolicy.fromJson(json['policy'] as Map<String, dynamic>)
          : null,
      billing: json['billing'] != null
          ? ModelBilling.fromJson(json['billing'] as Map<String, dynamic>)
          : null,
      supportedReasoningEfforts:
          (json['supportedReasoningEfforts'] as List<dynamic>?)
              ?.map(
                (e) => ReasoningEffort.values.firstWhere(
                  (r) => r.name == e,
                  orElse: () => ReasoningEffort.medium,
                ),
              )
              .toList(),
      defaultReasoningEffort: json['defaultReasoningEffort'] != null
          ? ReasoningEffort.values.firstWhere(
              (e) => e.name == json['defaultReasoningEffort'],
              orElse: () => ReasoningEffort.medium,
            )
          : null,
    );
  }

  /// Unique model identifier.
  final String id;

  /// Display name for the model.
  final String name;

  /// Capability metadata for the model.
  final ModelCapabilities capabilities;

  /// Optional policy metadata.
  final ModelPolicy? policy;

  /// Optional billing metadata.
  final ModelBilling? billing;

  /// Reasoning effort values supported by the model.
  final List<ReasoningEffort>? supportedReasoningEfforts;

  /// Default reasoning effort if provided by the server.
  final ReasoningEffort? defaultReasoningEffort;

  /// Serializes model information to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'capabilities': capabilities.toJson(),
      if (policy != null) 'policy': policy!.toJson(),
      if (billing != null) 'billing': billing!.toJson(),
      if (supportedReasoningEfforts != null)
        'supportedReasoningEfforts': supportedReasoningEfforts!
            .map((e) => e.name)
            .toList(),
      if (defaultReasoningEffort != null)
        'defaultReasoningEffort': defaultReasoningEffort!.name,
    };
  }
}

/// Session metadata.
class SessionMetadata {
  /// Creates session metadata.
  const SessionMetadata({
    required this.sessionId,
    required this.startTime,
    required this.modifiedTime,
    required this.isRemote,
    this.summary,
  });

  /// Parses session metadata from JSON.
  factory SessionMetadata.fromJson(Map<String, dynamic> json) {
    return SessionMetadata(
      sessionId: json['sessionId'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      modifiedTime: DateTime.parse(json['modifiedTime'] as String),
      summary: json['summary'] as String?,
      isRemote: json['isRemote'] as bool? ?? false,
    );
  }

  /// Session identifier.
  final String sessionId;

  /// Session start time.
  final DateTime startTime;

  /// Last modified time.
  final DateTime modifiedTime;

  /// Optional summary text.
  final String? summary;

  /// Whether the session is hosted remotely.
  final bool isRemote;

  /// Serializes session metadata to JSON.
  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'startTime': startTime.toIso8601String(),
      'modifiedTime': modifiedTime.toIso8601String(),
      if (summary != null) 'summary': summary,
      'isRemote': isRemote,
    };
  }
}

/// Response from status.get.
class GetStatusResponse {
  /// Creates a status response.
  const GetStatusResponse({
    required this.version,
    required this.protocolVersion,
  });

  /// Parses a status response from JSON.
  factory GetStatusResponse.fromJson(Map<String, dynamic> json) {
    return GetStatusResponse(
      version: json['version'] as String,
      protocolVersion: json['protocolVersion'] as int,
    );
  }

  /// CLI version string.
  final String version;

  /// Protocol version reported by the server.
  final int protocolVersion;

  /// Serializes the status response to JSON.
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'protocolVersion': protocolVersion,
    };
  }
}

/// Response from auth.getStatus.
class GetAuthStatusResponse {
  /// Creates an auth status response.
  const GetAuthStatusResponse({
    required this.isAuthenticated,
    this.authType,
    this.host,
    this.login,
    this.statusMessage,
  });

  /// Parses an auth status response from JSON.
  factory GetAuthStatusResponse.fromJson(Map<String, dynamic> json) {
    return GetAuthStatusResponse(
      isAuthenticated: json['isAuthenticated'] as bool,
      authType: json['authType'] as String?,
      host: json['host'] as String?,
      login: json['login'] as String?,
      statusMessage: json['statusMessage'] as String?,
    );
  }

  /// Whether the user is authenticated.
  final bool isAuthenticated;

  /// Authentication type (e.g. user or oauth).
  final String? authType;

  /// Hostname used for authentication.
  final String? host;

  /// Logged-in username, if available.
  final String? login;

  /// Optional status message from the server.
  final String? statusMessage;

  /// Serializes the auth status response to JSON.
  Map<String, dynamic> toJson() {
    return {
      'isAuthenticated': isAuthenticated,
      if (authType != null) 'authType': authType,
      if (host != null) 'host': host,
      if (login != null) 'login': login,
      if (statusMessage != null) 'statusMessage': statusMessage,
    };
  }
}

/// Options for sending a message to a session.
class MessageOptions {
  /// Creates message options for a session prompt.
  const MessageOptions({
    required this.prompt,
    this.attachments,
    this.mode,
  });

  /// Parses message options from JSON.
  factory MessageOptions.fromJson(Map<String, dynamic> json) {
    return MessageOptions(
      prompt: json['prompt'] as String,
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map((e) => Attachment.fromJson(e as Map<String, dynamic>))
          .toList(),
      mode: json['mode'] as String?,
    );
  }

  /// Prompt text to send to the model.
  final String prompt;

  /// Optional attachments to include with the prompt.
  final List<Attachment>? attachments;

  /// Optional message mode.
  final String? mode;

  /// Serializes message options to JSON.
  Map<String, dynamic> toJson() {
    return {
      'prompt': prompt,
      if (attachments != null)
        'attachments': attachments!.map((a) => a.toJson()).toList(),
      if (mode != null) 'mode': mode,
    };
  }
}

/// Response from ping request.
class PingResponse {
  /// Creates a ping response payload.
  const PingResponse({
    required this.message,
    required this.timestamp,
    this.protocolVersion,
  });

  /// Parses a ping response from JSON.
  factory PingResponse.fromJson(Map<String, dynamic> json) {
    return PingResponse(
      message: json['message'] as String? ?? '',
      timestamp: json['timestamp'] as int,
      protocolVersion: json['protocolVersion'] as int?,
    );
  }

  /// Response message payload.
  final String message;

  /// Response timestamp.
  final int timestamp;

  /// Optional protocol version reported by the server.
  final int? protocolVersion;

  /// Serializes the ping response to JSON.
  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'timestamp': timestamp,
      if (protocolVersion != null) 'protocolVersion': protocolVersion,
    };
  }
}
