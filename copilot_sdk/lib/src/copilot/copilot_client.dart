import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:copilot_sdk/src/copilot/copilot_config.dart';
import 'package:copilot_sdk/src/copilot/copilot_session.dart';
import 'package:copilot_sdk/src/copilot/copilot_types.dart';
import 'package:copilot_sdk/src/copilot/protocol_version.dart';
import 'package:copilot_sdk/src/jsonrpc/jsonrpc.dart';
import 'package:copilot_sdk/src/models/generated/session_events.dart';
import 'package:copilot_sdk/src/transports/transports.dart';
import 'package:mason_logger/mason_logger.dart';

/// Main client for interacting with the Copilot CLI.
///
/// The CopilotClient manages the connection to the Copilot CLI server and
/// provides methods to create and manage conversation sessions. It can either
/// spawn a CLI server process or connect to an existing server.
///
/// ## Usage
///
/// ```dart
/// // Create a client with default options (spawns CLI server)
/// final client = await CopilotClient.create(const CopilotConfig());
///
/// // Or connect to an existing server
/// final client = await CopilotClient.create(
///   const CopilotConfig(cliUrl: 'localhost:3000'),
/// );
///
/// // Create a session
/// final session = await client.createSession(
///   const SessionConfig(model: 'gpt-4'),
/// );
///
/// // Send messages and handle responses
/// session.onAny((event) {
///   if (event is AssistantMessage) {
///     print(event.data.content);
///   }
/// });
/// await session.send('Hello!');
///
/// // Clean up
/// await session.destroy();
/// await client.stop();
/// ```
class CopilotClient {
  CopilotClient._({
    required CopilotConfig config,
  }) : _config = config;

  final CopilotConfig _config;
  Transport? _transport;
  JsonRpcClient? _rpcClient;
  Process? _process;

  final _sessions = <String, CopilotSession>{};
  final _connectionStateController = StreamController<ConnectionState>.broadcast();

  ConnectionState _currentState = ConnectionState.disconnected;
  Completer<void>? _initCompleter;
  StreamSubscription<String>? _transportSubscription;
  List<ModelInfo>? _modelsCache;
  bool _forceStopping = false;

  /// Stream of connection state changes.
  Stream<ConnectionState> get connectionState => _connectionStateController.stream;

  /// Current connection state.
  ConnectionState get currentState => _currentState;

  /// Completes when the client is initialized and connected.
  Future<void> get initialized => _initCompleter?.future ?? Future.value();

  /// The underlying JSON-RPC client.
  JsonRpcClient? get rpcClient => _rpcClient;

  /// Client configuration.
  CopilotConfig get config => _config;

  /// Creates and initializes a [CopilotClient].
  ///
  /// This is the recommended way to create a client. It spawns the CLI server
  /// (or connects to an external one) and verifies protocol compatibility.
  ///
  /// ```dart
  /// final client = await CopilotClient.create(const CopilotConfig());
  /// ```
  static Future<CopilotClient> create(CopilotConfig config) async {
    final client = CopilotClient._(config: config);
    await client._initialize();
    return client;
  }

  /// Creates a [CopilotClient] without blocking on initialization.
  ///
  /// Use [initialized] to wait for the connection to be established.
  ///
  /// ```dart
  /// final client = CopilotClient.createNonBlocking(const CopilotConfig());
  /// await client.initialized;
  /// ```
  // This must be a static method (not a factory) because it initiates
  // async work without awaiting, returning the client immediately.
  // The static method avoids returning a Future while still starting work.
  // ignore: prefer_constructors_over_static_methods
  static CopilotClient createNonBlocking(CopilotConfig config) {
    final client = CopilotClient._(config: config);
    unawaited(client._initialize());
    return client;
  }

  /// Starts the CLI server and establishes a connection.
  ///
  /// If connecting to an external server (via [CopilotConfig.cliUrl]), only
  /// establishes the connection. Otherwise, spawns the CLI server process
  /// and then connects.
  ///
  /// This method is called automatically by [create] and [createNonBlocking].
  /// Use this when you need to manually restart a stopped client.
  ///
  /// ```dart
  /// final client = CopilotClient.createNonBlocking(
  ///   const CopilotConfig(autoStart: false),
  /// );
  /// await client.start();
  /// ```
  Future<void> start() async {
    if (_currentState == ConnectionState.connected) {
      return;
    }
    await _initialize();
  }

  Future<void> _initialize() async {
    _initCompleter = Completer<void>();
    _setConnectionState(ConnectionState.connecting);

    try {
      if (_config.cliUrl != null) {
        // Connect to existing TCP server
        await _connectTcp();
      } else if (!_config.useStdio) {
        // Spawn CLI in TCP mode
        await _spawnTcpProcess();
      } else {
        // Spawn CLI in stdio mode
        await _spawnProcess();
      }

      _setupRpcClient();
      await _verifyProtocolVersion();
      _setConnectionState(ConnectionState.connected);
      _initCompleter?.complete();
    } catch (e) {
      _setConnectionState(ConnectionState.error);
      _initCompleter?.completeError(e);
      rethrow;
    }
  }

  Future<void> _verifyProtocolVersion() async {
    final rpc = _rpcClient;
    if (rpc == null) return;

    final result = await rpc.sendRequest('ping', <String, dynamic>{});
    final resultMap = result! as Map<String, dynamic>;
    final serverVersion = resultMap['protocolVersion'] as int?;

    if (serverVersion == null) {
      throw StateError(
        'SDK protocol version mismatch: SDK expects version '
        '$sdkProtocolVersion, but server does not report a protocol version. '
        'Please update your server to ensure compatibility.',
      );
    }

    if (serverVersion != sdkProtocolVersion) {
      throw StateError(
        'SDK protocol version mismatch: SDK expects version '
        '$sdkProtocolVersion, but server reports version $serverVersion. '
        'Please update your SDK or server to ensure compatibility.',
      );
    }
  }

  Future<void> _connectTcp() async {
    final cliUrl = _config.cliUrl!;
    final (host, port) = _parseCliUrl(cliUrl);
    _transport = await TcpTransport.connect(host, port);
  }

  (String, int) _parseCliUrl(String cliUrl) {
    if (cliUrl.startsWith('http://')) {
      final uri = Uri.parse(cliUrl);
      return (uri.host, uri.port);
    }
    if (cliUrl.contains(':')) {
      final parts = cliUrl.split(':');
      return (parts[0], int.parse(parts[1]));
    }
    return ('localhost', int.parse(cliUrl));
  }

  /// Resolves the CLI command based on the platform and file extension.
  List<String> _resolveCliCommand(String cliPath) {
    // If it's a .js file, use node to run it
    if (cliPath.endsWith('.js')) {
      return ['node', cliPath];
    }

    // On Windows, if cliPath doesn't contain path separators, use cmd /c
    if (Platform.isWindows && !cliPath.contains('/') && !cliPath.contains(r'\')) {
      return ['cmd', '/c', cliPath];
    }

    return [cliPath];
  }

  Future<void> _spawnProcess() async {
    // Use COPILOT_CLI_PATH environment variable if available,
    // otherwise use config or default
    final cliPath = _config.cliPath ?? Platform.environment['COPILOT_CLI_PATH'] ?? 'copilot';
    final command = _resolveCliCommand(cliPath);

    final args = <String>[
      ...?_config.cliArgs,
      '--server',
      '--stdio',
    ];

    if (_config.logLevel != null) {
      args.addAll(['--log-level', _config.logLevel!.name]);
    }

    // Add auth-related flags (matching TypeScript SDK behavior)
    if (_config.githubToken != null) {
      args
        ..add('--auth-token-env')
        ..add('COPILOT_SDK_AUTH_TOKEN');
    }
    if (_config.useLoggedInUser == false) {
      args.add('--no-auto-login');
    }

    final environment = <String, String>{
      ...?_config.env?.cast<String, String>(),
    };
    // Set auth token in environment if provided
    if (_config.githubToken != null) {
      environment['COPILOT_SDK_AUTH_TOKEN'] = _config.githubToken!;
    }

    _process = await Process.start(
      command.first,
      [...command.skip(1), ...args],
      workingDirectory: _config.cwd,
      environment: environment.isNotEmpty ? environment : null,
    );

    // Forward stderr to debug output
    final logger = Logger();
    _process!.stderr.transform(utf8.decoder).listen((data) {
      if (data.isNotEmpty) {
        // In debug mode, log stderr output
        if (!const bool.fromEnvironment('dart.vm.product')) {
          logger.info('[Copilot CLI stderr] $data');
        }
      }
    });

    _transport = StdioTransport(_process!);
  }

  Future<void> _spawnTcpProcess() async {
    // Use COPILOT_CLI_PATH environment variable if available,
    // otherwise use config or default
    final cliPath = _config.cliPath ?? Platform.environment['COPILOT_CLI_PATH'] ?? 'copilot';
    final command = _resolveCliCommand(cliPath);

    final args = <String>[
      ...?_config.cliArgs,
      '--server',
    ];

    // Only add --port if a specific port is configured
    if (_config.port != null && _config.port! > 0) {
      args.addAll(['--port', _config.port.toString()]);
    }

    if (_config.logLevel != null) {
      args.addAll(['--log-level', _config.logLevel!.name]);
    }

    // Add auth-related flags (matching TypeScript SDK behavior)
    if (_config.githubToken != null) {
      args
        ..add('--auth-token-env')
        ..add('COPILOT_SDK_AUTH_TOKEN');
    }
    if (_config.useLoggedInUser == false) {
      args.add('--no-auto-login');
    }

    final environment = <String, String>{
      ...?_config.env?.cast<String, String>(),
    };
    // Set auth token in environment if provided
    if (_config.githubToken != null) {
      environment['COPILOT_SDK_AUTH_TOKEN'] = _config.githubToken!;
    }

    _process = await Process.start(
      command.first,
      [...command.skip(1), ...args],
      workingDirectory: _config.cwd,
      environment: environment.isNotEmpty ? environment : null,
    );

    // Listen for port announcement on stdout
    final portCompleter = Completer<int>();
    final startupTimeout = _config.timeout;

    _process!.stdout
        .transform(utf8.decoder)
        .listen(
          (data) {
            if (data.isNotEmpty) {
              // In debug mode, log stdout output
              if (!const bool.fromEnvironment('dart.vm.product')) {
                Logger().info('[Copilot CLI stdout] $data');
              }

              // Look for port announcement: "listening on port XXXX" (CLI outputs on stdout)
              final portMatch = RegExp(
                r'listening on port (\d+)',
                caseSensitive: false,
              ).firstMatch(data);
              if (portMatch != null && !portCompleter.isCompleted) {
                final port = int.parse(portMatch.group(1)!);
                portCompleter.complete(port);
              }
            }
          },
          onError: (Object error) {
            if (!portCompleter.isCompleted) {
              portCompleter.completeError(
                StateError('Failed to read CLI stdout: $error'),
              );
            }
          },
        );

    // Wait for port with timeout
    final port = await portCompleter.future.timeout(
      startupTimeout,
      onTimeout: () {
        _process?.kill();
        throw TimeoutException(
          'Copilot CLI failed to start within '
          '${startupTimeout.inSeconds} seconds',
        );
      },
    );

    // Connect via TCP
    _transport = await TcpTransport.connect('localhost', port);
  }

  void _setupRpcClient() {
    final transport = _transport;
    if (transport == null) {
      throw StateError('Transport not initialized');
    }

    _rpcClient = JsonRpcClient(
      sendMessage: transport.send,
      requestHandler: _handleRequest,
    );

    _transportSubscription = transport.incoming.listen(
      (message) {
        unawaited(_rpcClient?.handleMessage(message));
      },
      onError: (Object error) {
        _setConnectionState(ConnectionState.error);
        if (_config.autoRestart && !_forceStopping) {
          unawaited(_reconnect());
        }
      },
      onDone: () {
        _setConnectionState(ConnectionState.disconnected);
        if (_config.autoRestart && !_forceStopping) {
          unawaited(_reconnect());
        }
      },
    );

    _rpcClient!.onNotification.listen(_handleNotification);
  }

  Future<void> _reconnect() async {
    await _cleanup();
    await _initialize();
  }

  void _setConnectionState(ConnectionState state) {
    if (_currentState != state) {
      _currentState = state;
      _connectionStateController.add(state);
    }
  }

  Future<Object?> _handleRequest(String method, Object? params) async {
    switch (method) {
      case 'tool.call':
        return _handleToolCall(params);
      case 'permission.request':
        return _handlePermissionRequest(params);
      case 'userInput.request':
        return _handleUserInputRequest(params);
      case 'hooks.invoke':
        return _handleHooksInvoke(params);
      default:
        throw JsonRpcException(
          JsonRpcError(
            code: methodNotFound,
            message: 'Unknown method: $method',
          ),
        );
    }
  }

  Future<Object?> _handleToolCall(Object? params) async {
    if (params is! Map<String, dynamic>) {
      throw const JsonRpcException(
        JsonRpcError(code: invalidParams, message: 'Invalid params'),
      );
    }

    final sessionId = params['sessionId'] as String?;
    final toolName = params['toolName'] as String?;
    final toolCallId = params['toolCallId'] as String?;
    final arguments = (params['arguments'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    if (sessionId == null || toolName == null || toolCallId == null) {
      throw const JsonRpcException(
        JsonRpcError(
          code: invalidParams,
          message: 'Missing required parameters',
        ),
      );
    }

    final session = _sessions[sessionId];
    if (session == null) {
      throw JsonRpcException(
        JsonRpcError(
          code: invalidParams,
          message: 'Unknown session: $sessionId',
        ),
      );
    }

    final handler = session.getToolHandler(toolName);
    if (handler == null) {
      return {'result': _buildUnsupportedToolResult(toolName)};
    }

    try {
      final result = await session.handleToolCall(
        toolName,
        arguments,
        toolCallId,
      );
      final normalized = _normalizeToolResult(result);
      // Wrap in { result: ... } as expected by CLI
      return {'result': normalized};
    } on Exception catch (e) {
      return {
        'result': _normalizeToolResult(
          ToolResult.failure(
            'Invoking this tool produced an error. '
            'Detailed information is not available.',
            error: e.toString(),
          ),
        ),
      };
    }
  }

  Map<String, dynamic> _buildUnsupportedToolResult(String toolName) {
    return {
      'textResultForLlm': "Tool '$toolName' is not supported by this client instance.",
      'resultType': 'failure',
      'error': "tool '$toolName' not supported",
      'toolTelemetry': <String, dynamic>{},
    };
  }

  Map<String, dynamic> _normalizeToolResult(Object? result) {
    if (result == null) {
      return ToolResult.failure(
        'Tool returned no result',
        error: 'tool returned no result',
      ).toJson();
    }

    if (result is ToolResult) {
      return result.toJson();
    }

    // Duck-type check for ToolResult-like object
    if (result is Map<String, dynamic> && result.containsKey('textResultForLlm') && result.containsKey('resultType')) {
      // Ensure toolTelemetry is present
      if (!result.containsKey('toolTelemetry')) {
        result['toolTelemetry'] = <String, dynamic>{};
      }
      return result;
    }

    final textResult = result is String ? result : result.toString();
    return ToolResult.success(textResult).toJson();
  }

  Future<Object?> _handlePermissionRequest(Object? params) async {
    if (params is! Map<String, dynamic>) {
      throw const JsonRpcException(
        JsonRpcError(code: invalidParams, message: 'Invalid params'),
      );
    }

    final sessionId = params['sessionId'] as String?;
    final permissionRequest = params['permissionRequest'] as Map<String, dynamic>?;

    if (sessionId == null || permissionRequest == null) {
      throw const JsonRpcException(
        JsonRpcError(
          code: invalidParams,
          message: 'Invalid permission request payload',
        ),
      );
    }

    final session = _sessions[sessionId];
    if (session == null) {
      throw JsonRpcException(
        JsonRpcError(
          code: invalidParams,
          message: 'Session not found: $sessionId',
        ),
      );
    }

    try {
      final request = PermissionRequest.fromJson(permissionRequest);
      final result = await session.handlePermissionRequest(request);
      return {'result': result.toJson()};
    } on Exception {
      return {
        'result': PermissionResult.denied(
          PermissionResultKind.deniedNoApprovalRuleAndCouldNotRequestFromUser,
        ).toJson(),
      };
    }
  }

  Future<Object?> _handleUserInputRequest(Object? params) async {
    if (params is! Map<String, dynamic>) {
      throw const JsonRpcException(
        JsonRpcError(code: invalidParams, message: 'Invalid params'),
      );
    }

    final sessionId = params['sessionId'] as String?;
    final question = params['question'] as String?;

    if (sessionId == null || question == null) {
      throw const JsonRpcException(
        JsonRpcError(
          code: invalidParams,
          message: 'Invalid user input request payload',
        ),
      );
    }

    final session = _sessions[sessionId];
    if (session == null) {
      throw JsonRpcException(
        JsonRpcError(
          code: invalidParams,
          message: 'Session not found: $sessionId',
        ),
      );
    }

    final request = UserInputRequest(
      question: question,
      choices: (params['choices'] as List<dynamic>?)?.cast<String>(),
      allowFreeform: params['allowFreeform'] as bool? ?? true,
    );

    final result = await session.handleUserInputRequest(request);
    return {
      'answer': result.answer,
      'wasFreeform': result.wasFreeform,
    };
  }

  Future<Object?> _handleHooksInvoke(Object? params) async {
    if (params is! Map<String, dynamic>) {
      throw const JsonRpcException(
        JsonRpcError(code: invalidParams, message: 'Invalid params'),
      );
    }

    final sessionId = params['sessionId'] as String?;
    final hookType = params['hookType'] as String?;

    if (sessionId == null || hookType == null) {
      throw const JsonRpcException(
        JsonRpcError(
          code: invalidParams,
          message: 'Invalid hooks invoke payload',
        ),
      );
    }

    final session = _sessions[sessionId];
    if (session == null) {
      throw JsonRpcException(
        JsonRpcError(
          code: invalidParams,
          message: 'Session not found: $sessionId',
        ),
      );
    }

    final output = await session.handleHooksInvoke(hookType, params['input']);
    return {'output': output};
  }

  void _handleNotification(JsonRpcNotification notification) {
    if (notification.method == 'session.event') {
      _handleSessionEvent(notification.params);
    }
  }

  void _handleSessionEvent(Object? params) {
    if (params is! Map<String, dynamic>) return;

    final sessionId = params['sessionId'] as String?;
    if (sessionId == null) return;

    final session = _sessions[sessionId];
    if (session == null) return;

    final eventData = params['event'] as Map<String, dynamic>?;
    if (eventData == null) return;

    final event = _tryParseEvent(eventData);
    if (event != null) {
      session.dispatchEvent(event);
    }
  }

  SessionEvent? _tryParseEvent(Map<String, dynamic> eventData) {
    try {
      return SessionEvent.fromJson(eventData);
    } on Exception {
      return null;
    }
  }

  /// Create a new session.
  Future<CopilotSession> createSession([
    SessionConfig config = const SessionConfig(),
  ]) async {
    await initialized;

    final rpc = _rpcClient;
    if (rpc == null) {
      throw StateError('Client not connected');
    }

    final params = <String, dynamic>{
      if (config.model != null) 'model': config.model,
      if (config.sessionId != null) 'sessionId': config.sessionId,
      if (config.reasoningEffort != null) 'reasoningEffort': config.reasoningEffort!.name,
      if (config.tools != null) 'tools': config.tools!.map((t) => t.toJson()).toList(),
      if (config.systemMessage != null) 'systemMessage': config.systemMessage!.toJson(),
      if (config.availableTools != null) 'availableTools': config.availableTools,
      if (config.excludedTools != null) 'excludedTools': config.excludedTools,
      if (config.provider != null) 'provider': config.provider!.toJson(),
      'requestPermission': config.onPermissionRequest != null,
      'requestUserInput': config.onUserInputRequest != null,
      'hooks': config.hooks != null && _hasAnyHook(config.hooks!),
      if (config.workingDirectory != null) 'workingDirectory': config.workingDirectory,
      'streaming': config.streaming,
      if (config.mcpServers != null) 'mcpServers': config.mcpServers!.map((k, v) => MapEntry(k, v.toJson())),
      if (config.customAgents != null) 'customAgents': config.customAgents!.map((a) => a.toJson()).toList(),
      if (config.configDir != null) 'configDir': config.configDir,
      if (config.skillDirectories != null) 'skillDirectories': config.skillDirectories,
      if (config.disabledSkills != null) 'disabledSkills': config.disabledSkills,
      if (config.infiniteSessions != null) 'infiniteSessions': config.infiniteSessions!.toJson(),
    };

    final result = await rpc.sendRequest('session.create', params);
    final resultMap = result! as Map<String, dynamic>;
    final sessionId = resultMap['sessionId'] as String;
    final workspacePath = resultMap['workspacePath'] as String?;

    final session = CopilotSession(
      sessionId: sessionId,
      rpcClient: rpc,
      config: config,
      workspacePath: workspacePath,
    );

    // Don't notify server during initial registration
    // (tools already sent in session.create)
    // These methods don't return the session, so cascade notation won't work.
    // Keeping explicit calls mirrors the TypeScript SDK registration flow.
    session.registerTools(config.tools, notifyServer: false);
    session.registerPermissionHandler(config.onPermissionRequest);
    session.registerUserInputHandler(config.onUserInputRequest);
    session.registerHooks(config.hooks);

    _sessions[sessionId] = session;
    return session;
  }

  bool _hasAnyHook(SessionHooks hooks) {
    return hooks.onPreToolUse != null ||
        hooks.onPostToolUse != null ||
        hooks.onUserPromptSubmitted != null ||
        hooks.onSessionStart != null ||
        hooks.onSessionEnd != null ||
        hooks.onErrorOccurred != null;
  }

  /// Resume an existing session.
  Future<CopilotSession> resumeSession(
    String sessionId, [
    ResumeSessionConfig config = const ResumeSessionConfig(),
  ]) async {
    await initialized;

    final rpc = _rpcClient;
    if (rpc == null) {
      throw StateError('Client not connected');
    }

    final params = <String, dynamic>{
      'sessionId': sessionId,
      if (config.reasoningEffort != null) 'reasoningEffort': config.reasoningEffort!.name,
      if (config.tools != null) 'tools': config.tools!.map((t) => t.toJson()).toList(),
      if (config.provider != null) 'provider': config.provider!.toJson(),
      'requestPermission': config.onPermissionRequest != null,
      'requestUserInput': config.onUserInputRequest != null,
      'hooks': config.hooks != null && _hasAnyHook(config.hooks!),
      if (config.workingDirectory != null) 'workingDirectory': config.workingDirectory,
      'streaming': config.streaming,
      if (config.mcpServers != null) 'mcpServers': config.mcpServers!.map((k, v) => MapEntry(k, v.toJson())),
      if (config.customAgents != null) 'customAgents': config.customAgents!.map((a) => a.toJson()).toList(),
      if (config.skillDirectories != null) 'skillDirectories': config.skillDirectories,
      if (config.disabledSkills != null) 'disabledSkills': config.disabledSkills,
      if (config.disableResume) 'disableResume': config.disableResume,
    };

    final result = await rpc.sendRequest('session.resume', params);
    final resultMap = result! as Map<String, dynamic>;
    final resumedSessionId = resultMap['sessionId'] as String;
    final workspacePath = resultMap['workspacePath'] as String?;

    final sessionConfig = SessionConfig(
      sessionId: resumedSessionId,
      tools: config.tools,
      provider: config.provider,
      streaming: config.streaming,
      reasoningEffort: config.reasoningEffort,
      onPermissionRequest: config.onPermissionRequest,
      onUserInputRequest: config.onUserInputRequest,
      hooks: config.hooks,
      workingDirectory: config.workingDirectory,
      mcpServers: config.mcpServers,
      customAgents: config.customAgents,
      skillDirectories: config.skillDirectories,
      disabledSkills: config.disabledSkills,
    );

    final session = CopilotSession(
      sessionId: resumedSessionId,
      rpcClient: rpc,
      config: sessionConfig,
      workspacePath: workspacePath,
    );

    // Don't notify server during initial registration
    // (tools already sent in session.resume)
    // These methods don't return the session, so cascade notation won't work.
    // Keeping explicit calls mirrors the TypeScript SDK registration flow.
    session.registerTools(config.tools, notifyServer: false);
    session.registerPermissionHandler(config.onPermissionRequest);
    session.registerUserInputHandler(config.onUserInputRequest);
    session.registerHooks(config.hooks);

    _sessions[resumedSessionId] = session;
    return session;
  }

  /// Gets a session by ID if it's currently tracked by this client.
  CopilotSession? getSession(String sessionId) => _sessions[sessionId];

  /// Returns the current connection state.
  ConnectionState getState() => _currentState;

  /// Pings the server and returns timing/version information.
  ///
  /// ```dart
  /// final response = await client.ping();
  /// print('Protocol version: ${response.protocolVersion}');
  /// ```
  Future<PingResponse> ping([String? message]) async {
    await initialized;

    final rpc = _rpcClient;
    if (rpc == null) {
      throw StateError('Client not connected');
    }

    final result = await rpc.sendRequest('ping', <String, dynamic>{
      'message': ?message,
    });
    final resultMap = result! as Map<String, dynamic>;
    return PingResponse(
      message: resultMap['message'] as String? ?? '',
      timestamp: resultMap['timestamp'] as int,
      protocolVersion: resultMap['protocolVersion'] as int?,
    );
  }

  /// Gets CLI status including version and protocol information.
  ///
  /// ```dart
  /// final status = await client.getStatus();
  /// print('CLI version: ${status.version}');
  /// ```
  Future<GetStatusResponse> getStatus() async {
    await initialized;

    final rpc = _rpcClient;
    if (rpc == null) {
      throw StateError('Client not connected');
    }

    final result = await rpc.sendRequest('status.get', <String, dynamic>{});
    return GetStatusResponse.fromJson(result! as Map<String, dynamic>);
  }

  /// Gets current authentication status.
  ///
  /// ```dart
  /// final authStatus = await client.getAuthStatus();
  /// if (authStatus.isAuthenticated) {
  ///   print('Logged in as: ${authStatus.login}');
  /// }
  /// ```
  Future<GetAuthStatusResponse> getAuthStatus() async {
    await initialized;

    final rpc = _rpcClient;
    if (rpc == null) {
      throw StateError('Client not connected');
    }

    final result = await rpc.sendRequest('auth.getStatus', <String, dynamic>{});
    return GetAuthStatusResponse.fromJson(result! as Map<String, dynamic>);
  }

  /// Lists available models with their metadata.
  ///
  /// Results are cached after the first successful call.
  ///
  /// ```dart
  /// final models = await client.listModels();
  /// for (final model in models) {
  ///   print('${model.id}: ${model.name}');
  /// }
  /// ```
  Future<List<ModelInfo>> listModels() async {
    await initialized;

    final rpc = _rpcClient;
    if (rpc == null) {
      throw StateError('Client not connected');
    }

    if (_modelsCache != null) {
      return List.from(_modelsCache!);
    }

    final result = await rpc.sendRequest('models.list', <String, dynamic>{});
    final resultMap = result! as Map<String, dynamic>;
    final modelsList = resultMap['models'] as List<dynamic>;

    _modelsCache = modelsList.cast<Map<String, dynamic>>().map(ModelInfo.fromJson).toList();

    return List.from(_modelsCache!);
  }

  /// Gets the ID of the most recently updated session.
  ///
  /// This is useful for resuming the last conversation when the session ID
  /// was not stored.
  ///
  /// ```dart
  /// final lastId = await client.getLastSessionId();
  /// if (lastId != null) {
  ///   final session = await client.resumeSession(lastId);
  /// }
  /// ```
  Future<String?> getLastSessionId() async {
    await initialized;

    final rpc = _rpcClient;
    if (rpc == null) {
      throw StateError('Client not connected');
    }

    final result = await rpc.sendRequest(
      'session.getLastId',
      <String, dynamic>{},
    );
    final resultMap = result! as Map<String, dynamic>;
    return resultMap['sessionId'] as String?;
  }

  /// Deletes a session and its data from disk.
  ///
  /// This permanently removes the session and all its conversation history.
  /// The session cannot be resumed after deletion.
  ///
  /// ```dart
  /// await client.deleteSession('session-123');
  /// ```
  Future<void> deleteSession(String sessionId) async {
    await initialized;

    final rpc = _rpcClient;
    if (rpc == null) {
      throw StateError('Client not connected');
    }

    final result = await rpc.sendRequest('session.delete', <String, dynamic>{
      'sessionId': sessionId,
    });
    final resultMap = result! as Map<String, dynamic>;
    final success = resultMap['success'] as bool? ?? false;
    final error = resultMap['error'] as String?;

    if (!success) {
      throw StateError(
        'Failed to delete session $sessionId: ${error ?? "Unknown error"}',
      );
    }

    _sessions.remove(sessionId);
  }

  /// Lists all available sessions known to the server.
  ///
  /// Returns metadata about each session including ID, timestamps, and summary.
  ///
  /// ```dart
  /// final sessions = await client.listSessions();
  /// for (final session in sessions) {
  ///   print('${session.sessionId}: ${session.summary}');
  /// }
  /// ```
  Future<List<SessionMetadata>> listSessions() async {
    await initialized;

    final rpc = _rpcClient;
    if (rpc == null) {
      throw StateError('Client not connected');
    }

    final result = await rpc.sendRequest('session.list', <String, dynamic>{});
    final resultMap = result! as Map<String, dynamic>;
    final sessionsList = resultMap['sessions'] as List<dynamic>;

    return sessionsList.cast<Map<String, dynamic>>().map(SessionMetadata.fromJson).toList();
  }

  /// Stops the CLI server and closes all active sessions.
  ///
  /// This method performs graceful cleanup:
  /// 1. Destroys all active sessions with retry logic
  /// 2. Closes the JSON-RPC connection
  /// 3. Terminates the CLI server process (if spawned by this client)
  ///
  /// Returns a list of errors encountered during cleanup.
  ///
  /// ```dart
  /// final errors = await client.stop();
  /// if (errors.isNotEmpty) {
  ///   print('Cleanup errors: $errors');
  /// }
  /// ```
  Future<List<Exception>> stop() async {
    final errors = <Exception>[];

    for (final session in _sessions.values) {
      final sessionId = session.sessionId;
      Exception? lastError;

      for (var attempt = 1; attempt <= 3; attempt++) {
        try {
          await session.destroy();
          lastError = null;
          break;
        } on Exception catch (e) {
          lastError = e;
          if (attempt < 3) {
            final delay = Duration(milliseconds: 100 * (1 << (attempt - 1)));
            await Future<void>.delayed(delay);
          }
        }
      }

      if (lastError != null) {
        errors.add(
          Exception(
            'Failed to destroy session $sessionId after 3 attempts: $lastError',
          ),
        );
      }
    }
    _sessions.clear();
    _modelsCache = null;
    await _cleanup();
    return errors;
  }

  /// Forcefully stops the CLI server without graceful cleanup.
  ///
  /// Use this when [stop] fails or takes too long. This method:
  /// - Clears all sessions immediately without destroying them
  /// - Force closes the connection
  /// - Sends SIGKILL to the CLI process (if spawned by this client)
  ///
  /// ```dart
  /// // If normal stop hangs, force stop
  /// try {
  ///   await client.stop().timeout(const Duration(seconds: 5));
  /// } catch (_) {
  ///   await client.forceStop();
  /// }
  /// ```
  Future<void> forceStop() async {
    _forceStopping = true;
    _sessions.clear();
    _modelsCache = null;

    try {
      await _rpcClient?.dispose();
    } on Exception {
      // Ignore cleanup errors during force stop
    }
    _rpcClient = null;

    try {
      await _transport?.close();
    } on Exception {
      // Ignore cleanup errors during force stop
    }
    _transport = null;

    try {
      _process?.kill(ProcessSignal.sigkill);
    } on Exception {
      // Ignore cleanup errors during force stop
    }
    _process = null;

    await _transportSubscription?.cancel();
    _transportSubscription = null;

    _setConnectionState(ConnectionState.disconnected);
    _forceStopping = false;
  }

  Future<void> _cleanup() async {
    await _transportSubscription?.cancel();
    _transportSubscription = null;

    await _rpcClient?.dispose();
    _rpcClient = null;

    await _transport?.close();
    _transport = null;

    if (!_config.usesTcp) {
      _process?.kill();
    }
    _process = null;

    _setConnectionState(ConnectionState.disconnected);
  }

  /// Dispose the client.
  Future<void> dispose() async {
    await stop();
    await _connectionStateController.close();
  }
}
