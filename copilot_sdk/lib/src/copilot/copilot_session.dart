import 'dart:async';

import 'package:copilot_sdk/copilot_sdk.dart' show CopilotClient;
import 'package:copilot_sdk/src/copilot/copilot.dart' show CopilotClient;
import 'package:copilot_sdk/src/copilot/copilot_client.dart' show CopilotClient;
import 'package:copilot_sdk/src/copilot/copilot_config.dart';
import 'package:copilot_sdk/src/copilot/copilot_types.dart';
import 'package:copilot_sdk/src/jsonrpc/jsonrpc.dart';
import 'package:copilot_sdk/src/models/generated/session_events.dart';

/// Represents a single conversation session with the Copilot CLI.
///
/// A session maintains conversation state, handles events, and manages tool
/// execution. Sessions are created via [CopilotClient.createSession] or
/// resumed via [CopilotClient.resumeSession].
///
/// ## Usage
///
/// ```dart
/// final session = await client.createSession(
///   const SessionConfig(model: 'gpt-4'),
/// );
///
/// // Subscribe to events using typed handlers
/// session.on<AssistantMessage>((event) {
///   print(event.data.content);
/// });
///
/// // Or subscribe to all events
/// session.onAny((event) {
///   switch (event) {
///     case SessionIdle():
///       print('Session is idle');
///     case SessionError(:final data):
///       print('Error: ${data.message}');
///     default:
///       break;
///   }
/// });
///
/// // Send a message and wait for completion
/// final response = await session.sendAndWait('Hello, world!');
/// print(response?.data.content);
///
/// // Clean up
/// await session.destroy();
/// ```
class CopilotSession {
  /// Creates a new [CopilotSession] instance.
  ///
  /// This constructor is internal. Use [CopilotClient.createSession] to
  /// create sessions.
  CopilotSession({
    required this.sessionId,
    required JsonRpcClient rpcClient,
    required SessionConfig config,
    this.workspacePath,
  }) : _rpcClient = rpcClient,
       _config = config;

  /// The session ID.
  final String sessionId;
  final JsonRpcClient _rpcClient;
  final SessionConfig _config;

  /// Path to the session workspace directory when infinite sessions are enabled.
  final String? workspacePath;

  final _toolHandlers = <String, ToolHandler>{};
  final _typedHandlers = <Type, List<void Function(SessionEvent)>>{};
  final _anyHandlers = <void Function(SessionEvent)>[];
  final _eventController = StreamController<SessionEvent>.broadcast();
  final _accumulatedContent = StringBuffer();

  PermissionHandler? _permissionHandler;
  UserInputHandler? _userInputHandler;
  SessionHooks? _hooks;

  bool _destroyed = false;

  /// Stream of all session events.
  ///
  /// Use this for reactive event handling with Dart streams:
  ///
  /// ```dart
  /// session.events.listen((event) {
  ///   if (event is AssistantMessage) {
  ///     print(event.data.content);
  ///   }
  /// });
  /// ```
  Stream<SessionEvent> get events => _eventController.stream;

  /// The accumulated message content from streaming deltas.
  ///
  /// This is automatically updated when [AssistantMessageDelta] events are
  /// received and cleared at the start of each turn.
  String get accumulatedContent => _accumulatedContent.toString();

  /// Whether this session has been destroyed.
  bool get isDestroyed => _destroyed;

  /// Configuration for this session.
  SessionConfig get config => _config;

  /// Subscribes to events of a specific type.
  ///
  /// The handler is called whenever an event matching type [T] is received.
  ///
  /// ```dart
  /// session.on<AssistantMessage>((event) {
  ///   print('Assistant: ${event.data.content}');
  /// });
  ///
  /// session.on<SessionIdle>((event) {
  ///   print('Session is idle');
  /// });
  /// ```
  void on<T extends SessionEvent>(void Function(T) handler) {
    _typedHandlers.putIfAbsent(T, () => []);
    _typedHandlers[T]!.add((event) => handler(event as T));
  }

  /// Subscribes to all events from this session.
  ///
  /// The handler is called for every event received, regardless of type.
  ///
  /// ```dart
  /// session.onAny((event) {
  ///   switch (event) {
  ///     case AssistantMessage(:final data):
  ///       print('Message: ${data.content}');
  ///     case SessionError(:final data):
  ///       print('Error: ${data.message}');
  ///     default:
  ///       break;
  ///   }
  /// });
  /// ```
  void onAny(void Function(SessionEvent) handler) {
    _anyHandlers.add(handler);
  }

  /// Removes a typed event handler.
  void off<T extends SessionEvent>(void Function(T) handler) {
    final handlers = _typedHandlers[T];
    if (handlers != null) {
      handlers.removeWhere((h) => h == handler);
    }
  }

  /// Register a custom tool.
  ///
  /// The tool definition includes the handler and metadata about the tool.
  /// By default, this notifies the CLI server so the assistant can discover
  /// the tool at runtime. Set [notifyServer] to false to skip this.
  void registerTool(
    ToolDefinition tool, {
    bool notifyServer = true,
  }) {
    _toolHandlers[tool.name] = tool.handler;
    if (notifyServer) {
      _notifyServerToolRegistered(tool);
    }
  }

  /// Unregister a custom tool.
  ///
  /// By default, this notifies the CLI server so the assistant knows the tool
  /// is no longer available. Set [notifyServer] to false to skip this.
  void unregisterTool(
    String name, {
    bool notifyServer = true,
  }) {
    _toolHandlers.remove(name);
    if (notifyServer) {
      _notifyServerToolUnregistered(name);
    }
  }

  /// Check if a tool is registered.
  bool hasToolHandler(String name) => _toolHandlers.containsKey(name);

  /// Register tools from definitions.
  ///
  /// Clears existing tools and registers the new ones.
  /// By default, this notifies the CLI server so the assistant can discover
  /// the tools at runtime. Set [notifyServer] to false to skip this.
  void registerTools(
    List<ToolDefinition>? tools, {
    bool notifyServer = true,
  }) {
    _toolHandlers.clear();
    if (tools == null) return;
    for (final tool in tools) {
      _toolHandlers[tool.name] = tool.handler;
    }
    if (notifyServer && tools.isNotEmpty) {
      _notifyServerToolsRegistered(tools);
    }
  }

  void _notifyServerToolRegistered(ToolDefinition tool) {
    try {
      _rpcClient.sendNotification('tools/register', {
        'sessionId': sessionId,
        'tool': tool.toJson(),
      });
    } catch (_) {
      // Silently fail - server may not support dynamic tool registration
    }
  }

  void _notifyServerToolsRegistered(List<ToolDefinition> tools) {
    try {
      _rpcClient.sendNotification('tools/register', {
        'sessionId': sessionId,
        'tools': tools.map((t) => t.toJson()).toList(),
      });
    } catch (_) {
      // Silently fail - server may not support dynamic tool registration
    }
  }

  void _notifyServerToolUnregistered(String toolName) {
    try {
      _rpcClient.sendNotification('tools/unregister', {
        'sessionId': sessionId,
        'toolName': toolName,
      });
    } catch (_) {
      // Silently fail - server may not support dynamic tool registration
    }
  }

  /// Get a registered tool handler by name.
  ToolHandler? getToolHandler(String name) => _toolHandlers[name];

  /// Register a permission handler.
  void registerPermissionHandler(PermissionHandler? handler) {
    _permissionHandler = handler;
  }

  /// Register a user input handler.
  void registerUserInputHandler(UserInputHandler? handler) {
    _userInputHandler = handler;
  }

  /// Register hook handlers.
  void registerHooks(SessionHooks? hooks) {
    _hooks = hooks;
  }

  /// Sends a message to this session and returns immediately.
  ///
  /// The message is processed asynchronously. Subscribe to events via [on]
  /// or [onAny] to receive streaming responses and other session events.
  ///
  /// Returns the message ID of the sent message.
  ///
  /// ```dart
  /// final messageId = await session.send(
  ///   'Explain this code',
  ///   attachments: [Attachment.file('./src/index.ts')],
  /// );
  /// ```
  Future<String> send(
    String message, {
    List<Attachment>? attachments,
    String? mode,
  }) async {
    _checkNotDestroyed();

    final params = <String, dynamic>{
      'sessionId': sessionId,
      'prompt': message,
      if (attachments != null && attachments.isNotEmpty)
        'attachments': attachments.map((a) => a.toJson()).toList(),
      if (mode != null) 'mode': mode,
    };

    final result = await _rpcClient.sendRequest('session.send', params);
    final resultMap = result! as Map<String, dynamic>;
    return resultMap['messageId'] as String? ?? '';
  }

  /// Sends a message and waits until the session becomes idle.
  ///
  /// This is a convenience method that combines [send] with waiting for
  /// the `session.idle` event. Use this when you want to block until the
  /// assistant has finished processing the message.
  ///
  /// Events are still delivered to handlers registered via [on] and [onAny]
  /// while waiting.
  ///
  /// Returns the final assistant message, or null if none was received.
  ///
  /// Throws [TimeoutException] if the timeout is reached before the session
  /// becomes idle.
  ///
  /// ```dart
  /// // Send and wait for completion with default 60s timeout
  /// final response = await session.sendAndWait('What is 2+2?');
  /// print(response?.data.content); // "4"
  ///
  /// // With custom timeout
  /// final response = await session.sendAndWait(
  ///   'Long running task',
  ///   timeout: const Duration(minutes: 5),
  /// );
  /// ```
  Future<AssistantMessage?> sendAndWait(
    String message, {
    List<Attachment>? attachments,
    String? mode,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    _checkNotDestroyed();

    late void Function() resolveIdle;
    late void Function(Object) rejectWithError;
    final idleCompleter = Completer<void>();

    resolveIdle = () {
      if (!idleCompleter.isCompleted) {
        idleCompleter.complete();
      }
    };
    rejectWithError = (Object error) {
      if (!idleCompleter.isCompleted) {
        idleCompleter.completeError(error);
      }
    };

    AssistantMessage? lastAssistantMessage;

    void eventHandler(SessionEvent event) {
      if (event is AssistantMessage) {
        lastAssistantMessage = event;
      } else if (event is SessionIdle) {
        resolveIdle();
      } else if (event is SessionError) {
        rejectWithError(Exception(event.data.message));
      }
    }

    _anyHandlers.add(eventHandler);

    try {
      await send(message, attachments: attachments, mode: mode);

      await idleCompleter.future.timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException(
            'Timeout after ${timeout.inMilliseconds}ms waiting for session.idle',
          );
        },
      );

      return lastAssistantMessage;
    } finally {
      _anyHandlers.remove(eventHandler);
    }
  }

  /// Retrieves all events and messages from this session's history.
  ///
  /// Returns the complete conversation history including user messages,
  /// assistant responses, tool executions, and other session events.
  ///
  /// ```dart
  /// final events = await session.getMessages();
  /// for (final event in events) {
  ///   if (event is AssistantMessage) {
  ///     print('Assistant: ${event.data.content}');
  ///   }
  /// }
  /// ```
  Future<List<SessionEvent>> getMessages() async {
    _checkNotDestroyed();

    final result = await _rpcClient.sendRequest(
      'session.getMessages',
      {'sessionId': sessionId},
    );
    final resultMap = result! as Map<String, dynamic>;
    final eventsList = resultMap['events'] as List<dynamic>;

    return eventsList
        .cast<Map<String, dynamic>>()
        .map(SessionEvent.fromJson)
        .toList();
  }

  /// Aborts the currently processing message in this session.
  ///
  /// Use this to cancel a long-running request. The session remains valid
  /// and can continue to be used for new messages.
  ///
  /// ```dart
  /// // Start a long-running request
  /// unawaited(session.send('Write a very long story...'));
  ///
  /// // Abort after 5 seconds
  /// await Future<void>.delayed(const Duration(seconds: 5));
  /// await session.abort();
  /// ```
  Future<void> abort() async {
    _checkNotDestroyed();
    await _rpcClient.sendRequest('session.abort', {'sessionId': sessionId});
  }

  /// Destroys this session and releases all associated resources.
  ///
  /// After calling this method, the session can no longer be used. All event
  /// handlers and tool handlers are cleared. To continue the conversation,
  /// use [CopilotClient.resumeSession] with the session ID.
  ///
  /// ```dart
  /// // Clean up when done
  /// await session.destroy();
  /// ```
  Future<void> destroy() async {
    if (_destroyed) return;

    _destroyed = true;
    await _rpcClient.sendRequest('session.destroy', {'sessionId': sessionId});
    await _eventController.close();
    _toolHandlers.clear();
    _typedHandlers.clear();
    _anyHandlers.clear();
    _permissionHandler = null;
    _userInputHandler = null;
    _hooks = null;
  }

  void _checkNotDestroyed() {
    if (_destroyed) {
      throw StateError('Session has been destroyed');
    }
  }

  void _handleStreamingDelta(SessionEvent event) {
    if (event is AssistantMessageDelta) {
      _accumulatedContent.write(event.data.deltaContent);
    } else if (event is AssistantTurnStart) {
      _accumulatedContent.clear();
    }
  }

  /// Handle a tool call request. Called by CopilotClient.
  Future<ToolResult?> handleToolCall(
    String toolName,
    Map<String, dynamic> arguments,
    String toolCallId,
  ) async {
    final handler = _toolHandlers[toolName];
    if (handler == null) return null;

    final invocation = ToolInvocation(
      sessionId: sessionId,
      toolCallId: toolCallId,
      toolName: toolName,
      arguments: arguments,
    );

    return handler(arguments, invocation);
  }

  /// Handle a permission request. Called by CopilotClient.
  Future<PermissionResult> handlePermissionRequest(
    PermissionRequest request,
  ) async {
    if (_permissionHandler == null) {
      return PermissionResult.denied(
        PermissionResultKind.deniedNoApprovalRuleAndCouldNotRequestFromUser,
      );
    }

    try {
      final invocation = ToolInvocation(
        sessionId: sessionId,
        toolCallId: request.toolCallId ?? '',
        toolName: '',
        arguments: request.additionalFields ?? {},
      );
      return await _permissionHandler!(request, invocation);
    } catch (_) {
      return PermissionResult.denied(
        PermissionResultKind.deniedNoApprovalRuleAndCouldNotRequestFromUser,
      );
    }
  }

  /// Handle a user input request. Called by CopilotClient.
  Future<UserInputResult> handleUserInputRequest(
    UserInputRequest request,
  ) async {
    if (_userInputHandler == null) {
      throw StateError('User input requested but no handler registered');
    }

    return _userInputHandler!(request);
  }

  /// Handle a hooks invocation. Called by CopilotClient.
  Future<Object?> handleHooksInvoke(String hookType, Object? input) async {
    if (_hooks == null) return null;

    final invocation = ToolInvocation(
      sessionId: sessionId,
      toolCallId: '',
      toolName: hookType,
      arguments: input is Map<String, dynamic> ? input : {},
    );

    try {
      switch (hookType) {
        case 'preToolUse':
          if (_hooks!.onPreToolUse == null) return null;
          final hookInput = _parsePreToolUseInput(input);
          final result = await _hooks!.onPreToolUse!(hookInput, invocation);
          return result?.toJson();

        case 'postToolUse':
          if (_hooks!.onPostToolUse == null) return null;
          final hookInput = _parsePostToolUseInput(input);
          final result = await _hooks!.onPostToolUse!(hookInput, invocation);
          return result?.toJson();

        case 'userPromptSubmitted':
          if (_hooks!.onUserPromptSubmitted == null) return null;
          final hookInput = _parseUserPromptSubmittedInput(input);
          final result = await _hooks!.onUserPromptSubmitted!(
            hookInput,
            invocation,
          );
          return result?.toJson();

        case 'sessionStart':
          if (_hooks!.onSessionStart == null) return null;
          final hookInput = _parseSessionStartInput(input);
          final result = await _hooks!.onSessionStart!(hookInput, invocation);
          return result?.toJson();

        case 'sessionEnd':
          if (_hooks!.onSessionEnd == null) return null;
          final hookInput = _parseSessionEndInput(input);
          final result = await _hooks!.onSessionEnd!(hookInput, invocation);
          return result?.toJson();

        case 'errorOccurred':
          if (_hooks!.onErrorOccurred == null) return null;
          final hookInput = _parseErrorOccurredInput(input);
          final result = await _hooks!.onErrorOccurred!(hookInput, invocation);
          return result?.toJson();

        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  PreToolUseHookInput _parsePreToolUseInput(Object? input) {
    final map = input! as Map<String, dynamic>;
    return PreToolUseHookInput(
      timestamp: map['timestamp'] as int? ?? 0,
      cwd: map['cwd'] as String? ?? '',
      toolName: map['toolName'] as String? ?? '',
      toolArgs: map['toolArgs'],
    );
  }

  PostToolUseHookInput _parsePostToolUseInput(Object? input) {
    final map = input! as Map<String, dynamic>;
    return PostToolUseHookInput(
      timestamp: map['timestamp'] as int? ?? 0,
      cwd: map['cwd'] as String? ?? '',
      toolName: map['toolName'] as String? ?? '',
      toolArgs: map['toolArgs'],
      toolResult: ToolResult.fromJson(
        map['toolResult'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  UserPromptSubmittedHookInput _parseUserPromptSubmittedInput(Object? input) {
    final map = input! as Map<String, dynamic>;
    return UserPromptSubmittedHookInput(
      timestamp: map['timestamp'] as int? ?? 0,
      cwd: map['cwd'] as String? ?? '',
      prompt: map['prompt'] as String? ?? '',
    );
  }

  SessionStartHookInput _parseSessionStartInput(Object? input) {
    final map = input! as Map<String, dynamic>;
    final sourceStr = map['source'] as String? ?? 'startup';
    final source = SessionStartSource.values.firstWhere(
      (e) =>
          e.name == sourceStr ||
          (sourceStr == 'new' && e == SessionStartSource.new_),
      orElse: () => SessionStartSource.startup,
    );
    return SessionStartHookInput(
      timestamp: map['timestamp'] as int? ?? 0,
      cwd: map['cwd'] as String? ?? '',
      source: source,
      initialPrompt: map['initialPrompt'] as String?,
    );
  }

  SessionEndHookInput _parseSessionEndInput(Object? input) {
    final map = input! as Map<String, dynamic>;
    final reasonStr = map['reason'] as String? ?? 'complete';
    final reason = SessionEndReason.values.firstWhere(
      (e) => e.name == reasonStr,
      orElse: () => SessionEndReason.complete,
    );
    return SessionEndHookInput(
      timestamp: map['timestamp'] as int? ?? 0,
      cwd: map['cwd'] as String? ?? '',
      reason: reason,
      finalMessage: map['finalMessage'] as String?,
      error: map['error'] as String?,
    );
  }

  ErrorOccurredHookInput _parseErrorOccurredInput(Object? input) {
    final map = input! as Map<String, dynamic>;
    final contextStr = map['errorContext'] as String? ?? 'system';
    final errorContext = ErrorContext.values.firstWhere(
      (e) => e.name == contextStr,
      orElse: () => ErrorContext.system,
    );
    return ErrorOccurredHookInput(
      timestamp: map['timestamp'] as int? ?? 0,
      cwd: map['cwd'] as String? ?? '',
      error: map['error'] as String? ?? '',
      errorContext: errorContext,
      recoverable: map['recoverable'] as bool? ?? false,
    );
  }

  /// Dispatch an event to handlers. Called by CopilotClient.
  void dispatchEvent(SessionEvent event) {
    if (_destroyed) return;

    _eventController.add(event);

    for (final handler in _anyHandlers) {
      try {
        handler(event);
      } catch (_) {}
    }

    final handlers = _typedHandlers[event.runtimeType];
    if (handlers != null) {
      for (final handler in handlers) {
        try {
          handler(event);
        } catch (_) {}
      }
    }

    _handleStreamingDelta(event);
  }
}
