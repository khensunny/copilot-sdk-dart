/// Connection state for the CopilotClient.
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Log level for the CLI server.
enum LogLevel {
  none,
  error,
  warning,
  info,
  debug,
  all,
}

/// Permission kinds for tool execution.
enum PermissionKind {
  shell,
  write,
  read,
  mcp,
  url,
}

/// Result kind for permission requests.
enum PermissionResultKind {
  approved,
  deniedByRules,
  deniedNoApprovalRuleAndCouldNotRequestFromUser,
  deniedInteractivelyByUser,
}

/// Result of a permission request.
class PermissionResult {
  const PermissionResult({
    required this.kind,
    this.rules,
  });

  factory PermissionResult.approved() =>
      const PermissionResult(kind: PermissionResultKind.approved);

  factory PermissionResult.denied(PermissionResultKind kind) =>
      PermissionResult(kind: kind);

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

  final PermissionResultKind kind;
  final List<dynamic>? rules;

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
  success,
  failure,
  rejected,
  denied,
}

/// Handler for custom tool execution.
typedef ToolHandler =
    Future<ToolResult> Function(
      Map<String, dynamic> arguments,
      ToolInvocation invocation,
    );

/// Handler for permission requests.
typedef PermissionHandler =
    Future<PermissionResult> Function(
      PermissionRequest request,
      ToolInvocation invocation,
    );

/// Handler for user input requests.
typedef UserInputHandler =
    Future<UserInputResult> Function(
      UserInputRequest request,
    );

/// Information about a tool invocation.
class ToolInvocation {
  const ToolInvocation({
    required this.sessionId,
    required this.toolCallId,
    required this.toolName,
    required this.arguments,
  });

  factory ToolInvocation.fromJson(Map<String, dynamic> json) {
    return ToolInvocation(
      sessionId: json['sessionId'] as String,
      toolCallId: json['toolCallId'] as String,
      toolName: json['toolName'] as String,
      arguments: (json['arguments'] as Map<String, dynamic>?) ?? {},
    );
  }

  final String sessionId;
  final String toolCallId;
  final String toolName;
  final Map<String, dynamic> arguments;

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
  const ToolBinaryResult({
    required this.data,
    required this.mimeType,
    required this.type,
    this.description,
  });

  factory ToolBinaryResult.fromJson(Map<String, dynamic> json) {
    return ToolBinaryResult(
      data: json['data'] as String,
      mimeType: json['mimeType'] as String,
      type: json['type'] as String,
      description: json['description'] as String?,
    );
  }

  final String data;
  final String mimeType;
  final String type;
  final String? description;

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
  const ToolResult({
    required this.textResultForLlm,
    this.resultType = ToolResultType.success,
    this.binaryResultsForLlm,
    this.error,
    this.sessionLog,
    this.toolTelemetry,
  });

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

  factory ToolResult.success(String text) => ToolResult(
        textResultForLlm: text,
        toolTelemetry: {},
      );

  factory ToolResult.failure(String text, {String? error}) => ToolResult(
    textResultForLlm: text,
    resultType: ToolResultType.failure,
    error: error,
  );

  factory ToolResult.rejected(String text) =>
      ToolResult(textResultForLlm: text, resultType: ToolResultType.rejected);

  factory ToolResult.denied(String text) =>
      ToolResult(textResultForLlm: text, resultType: ToolResultType.denied);

  final String textResultForLlm;
  final ToolResultType resultType;
  final List<ToolBinaryResult>? binaryResultsForLlm;
  final String? error;
  final String? sessionLog;
  final Map<String, dynamic>? toolTelemetry;

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
  const PermissionRequest({
    required this.kind,
    this.toolCallId,
    this.additionalFields,
  });

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

  final PermissionKind kind;
  final String? toolCallId;
  final Map<String, dynamic>? additionalFields;

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
  const UserInputRequest({
    required this.question,
    this.choices,
    this.allowFreeform = true,
  });

  factory UserInputRequest.fromJson(Map<String, dynamic> json) {
    return UserInputRequest(
      question: json['question'] as String,
      choices: (json['choices'] as List<dynamic>?)?.cast<String>(),
      allowFreeform: json['allowFreeform'] as bool? ?? true,
    );
  }

  final String question;
  final List<String>? choices;
  final bool allowFreeform;

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
  const UserInputResult({
    required this.answer,
    this.wasFreeform = false,
  });

  factory UserInputResult.fromJson(Map<String, dynamic> json) {
    return UserInputResult(
      answer: json['answer'] as String,
      wasFreeform: json['wasFreeform'] as bool? ?? false,
    );
  }

  final String answer;
  final bool wasFreeform;

  Map<String, dynamic> toJson() {
    return {
      'answer': answer,
      'wasFreeform': wasFreeform,
    };
  }
}

/// Type of attachment.
enum AttachmentType {
  file,
  directory,
}

/// Attachment for messages.
class Attachment {
  const Attachment({
    required this.type,
    required this.path,
    this.displayName,
  });

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

  factory Attachment.file(String path, {String? displayName}) => Attachment(
    type: AttachmentType.file,
    path: path,
    displayName: displayName,
  );

  factory Attachment.directory(String path, {String? displayName}) =>
      Attachment(
        type: AttachmentType.directory,
        path: path,
        displayName: displayName,
      );

  final AttachmentType type;
  final String path;
  final String? displayName;

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
  const ModelCapabilities({
    required this.supportsVision,
    required this.supportsReasoningEffort,
    required this.maxContextWindowTokens, this.maxPromptTokens,
    this.vision,
  });

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

  final bool supportsVision;
  final bool supportsReasoningEffort;
  final int? maxPromptTokens;
  final int maxContextWindowTokens;
  final VisionCapabilities? vision;

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
  const VisionCapabilities({
    required this.supportedMediaTypes,
    required this.maxPromptImages,
    required this.maxPromptImageSize,
  });

  factory VisionCapabilities.fromJson(Map<String, dynamic> json) {
    return VisionCapabilities(
      supportedMediaTypes:
          (json['supported_media_types'] as List<dynamic>?)?.cast<String>() ??
          [],
      maxPromptImages: json['max_prompt_images'] as int? ?? 0,
      maxPromptImageSize: json['max_prompt_image_size'] as int? ?? 0,
    );
  }

  final List<String> supportedMediaTypes;
  final int maxPromptImages;
  final int maxPromptImageSize;

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
  const ModelPolicy({
    required this.state,
    required this.terms,
  });

  factory ModelPolicy.fromJson(Map<String, dynamic> json) {
    return ModelPolicy(
      state: json['state'] as String,
      terms: json['terms'] as String,
    );
  }

  final String state;
  final String terms;

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'terms': terms,
    };
  }
}

/// Model billing information.
class ModelBilling {
  const ModelBilling({
    required this.multiplier,
  });

  factory ModelBilling.fromJson(Map<String, dynamic> json) {
    return ModelBilling(
      multiplier: (json['multiplier'] as num).toDouble(),
    );
  }

  final double multiplier;

  Map<String, dynamic> toJson() {
    return {
      'multiplier': multiplier,
    };
  }
}

/// Reasoning effort levels.
enum ReasoningEffort {
  low,
  medium,
  high,
  xhigh,
}

/// Model information returned from listModels.
class ModelInfo {
  const ModelInfo({
    required this.id,
    required this.name,
    required this.capabilities,
    this.policy,
    this.billing,
    this.supportedReasoningEfforts,
    this.defaultReasoningEffort,
  });

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

  final String id;
  final String name;
  final ModelCapabilities capabilities;
  final ModelPolicy? policy;
  final ModelBilling? billing;
  final List<ReasoningEffort>? supportedReasoningEfforts;
  final ReasoningEffort? defaultReasoningEffort;

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
  const SessionMetadata({
    required this.sessionId,
    required this.startTime,
    required this.modifiedTime,
    required this.isRemote, this.summary,
  });

  factory SessionMetadata.fromJson(Map<String, dynamic> json) {
    return SessionMetadata(
      sessionId: json['sessionId'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      modifiedTime: DateTime.parse(json['modifiedTime'] as String),
      summary: json['summary'] as String?,
      isRemote: json['isRemote'] as bool? ?? false,
    );
  }

  final String sessionId;
  final DateTime startTime;
  final DateTime modifiedTime;
  final String? summary;
  final bool isRemote;

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
  const GetStatusResponse({
    required this.version,
    required this.protocolVersion,
  });

  factory GetStatusResponse.fromJson(Map<String, dynamic> json) {
    return GetStatusResponse(
      version: json['version'] as String,
      protocolVersion: json['protocolVersion'] as int,
    );
  }

  final String version;
  final int protocolVersion;

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'protocolVersion': protocolVersion,
    };
  }
}

/// Response from auth.getStatus.
class GetAuthStatusResponse {
  const GetAuthStatusResponse({
    required this.isAuthenticated,
    this.authType,
    this.host,
    this.login,
    this.statusMessage,
  });

  factory GetAuthStatusResponse.fromJson(Map<String, dynamic> json) {
    return GetAuthStatusResponse(
      isAuthenticated: json['isAuthenticated'] as bool,
      authType: json['authType'] as String?,
      host: json['host'] as String?,
      login: json['login'] as String?,
      statusMessage: json['statusMessage'] as String?,
    );
  }

  final bool isAuthenticated;
  final String? authType;
  final String? host;
  final String? login;
  final String? statusMessage;

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
  const MessageOptions({
    required this.prompt,
    this.attachments,
    this.mode,
  });

  factory MessageOptions.fromJson(Map<String, dynamic> json) {
    return MessageOptions(
      prompt: json['prompt'] as String,
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map((e) => Attachment.fromJson(e as Map<String, dynamic>))
          .toList(),
      mode: json['mode'] as String?,
    );
  }

  final String prompt;
  final List<Attachment>? attachments;
  final String? mode;

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
  const PingResponse({
    required this.message,
    required this.timestamp,
    this.protocolVersion,
  });

  factory PingResponse.fromJson(Map<String, dynamic> json) {
    return PingResponse(
      message: json['message'] as String? ?? '',
      timestamp: json['timestamp'] as int,
      protocolVersion: json['protocolVersion'] as int?,
    );
  }

  final String message;
  final int timestamp;
  final int? protocolVersion;

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'timestamp': timestamp,
      if (protocolVersion != null) 'protocolVersion': protocolVersion,
    };
  }
}
