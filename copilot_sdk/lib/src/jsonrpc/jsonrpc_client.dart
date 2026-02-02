import 'dart:async';

import 'package:copilot_sdk/src/jsonrpc/jsonrpc_protocol.dart';
import 'package:uuid/uuid.dart';

/// {@template json_rpc_exception}
/// Exception raised when a JSON-RPC error response is received.
/// {@endtemplate}
/// {@macro json_rpc_exception}
class JsonRpcException implements Exception {
  /// {@macro json_rpc_exception}
  const JsonRpcException(this.error);

  /// Error details from the JSON-RPC response.
  final JsonRpcError error;

  @override
  String toString() => 'JsonRpcException: ${error.message} (${error.code})';
}

/// Sends encoded JSON-RPC messages to the transport.
typedef MessageSender = void Function(String message);

/// Handles server-initiated JSON-RPC requests.
typedef RequestHandler =
    Future<Object?> Function(
      String method,
      Object? params,
    );

/// {@template json_rpc_client}
/// JSON-RPC 2.0 client implementation.
/// {@endtemplate}
/// {@macro json_rpc_client}
class JsonRpcClient {
  /// {@macro json_rpc_client}
  JsonRpcClient({
    required this.sendMessage,
    RequestHandler? requestHandler,
  }) : _requestHandler = requestHandler;

  /// Function used to send encoded JSON-RPC messages.
  final MessageSender sendMessage;
  final RequestHandler? _requestHandler;

  final _uuid = const Uuid();
  final _pendingRequests = <String, Completer<Object?>>{};

  final _notificationController = StreamController<JsonRpcNotification>.broadcast();
  final _requestController = StreamController<JsonRpcRequest>.broadcast();

  /// Stream of incoming JSON-RPC notifications.
  Stream<JsonRpcNotification> get onNotification => _notificationController.stream;

  /// Stream of incoming JSON-RPC requests.
  Stream<JsonRpcRequest> get onRequest => _requestController.stream;

  /// Sends a JSON-RPC request and returns the response result.
  Future<Object?> sendRequest(String method, [Object? params]) {
    final id = _uuid.v4();
    final request = JsonRpcRequest(id: id, method: method, params: params);
    final completer = Completer<Object?>();

    _pendingRequests[id] = completer;
    sendMessage(request.encode());

    return completer.future;
  }

  /// Sends a JSON-RPC notification.
  void sendNotification(String method, [Object? params]) {
    final notification = JsonRpcNotification(method: method, params: params);
    sendMessage(notification.encode());
  }

  /// Sends a JSON-RPC response with a result.
  void sendResponse(Object? id, Object? result) {
    final response = JsonRpcResponse(id: id, result: result);
    final message = response.encode();
    sendMessage(message);
  }

  /// Sends a JSON-RPC response with an error.
  void sendErrorResponse(Object? id, JsonRpcError error) {
    final response = JsonRpcErrorResponse(id: id, error: error);
    sendMessage(response.encode());
  }

  /// Handles an incoming JSON-RPC message.
  Future<void> handleMessage(String data) async {
    final message = JsonRpcMessage.decode(data);

    switch (message) {
      case JsonRpcResponse(:final id, :final result):
        final idKey = id is int ? id.toString() : id as String?;
        final completer = _pendingRequests.remove(idKey);
        completer?.complete(result);

      case JsonRpcErrorResponse(:final id, :final error):
        final idKey = id is int ? id.toString() : id as String?;
        final completer = _pendingRequests.remove(idKey);
        completer?.completeError(JsonRpcException(error));

      case JsonRpcNotification():
        _notificationController.add(message);

      case JsonRpcRequest(:final id, :final method, :final params):
        _requestController.add(message);
        if (_requestHandler != null) {
          try {
            final result = await _requestHandler(method, params);
            sendResponse(id, result);
          } on JsonRpcException catch (e) {
            sendErrorResponse(id, e.error);
            // Must catch all thrown values (Exception, Error, etc.) to ensure
            // the RPC response is always sent and the CLI doesn't hang
            // ignore: avoid_catches_without_on_clauses
          } catch (e) {
            sendErrorResponse(
              id,
              JsonRpcError(
                code: internalError,
                message: e.toString(),
              ),
            );
          }
        }
    }
  }

  /// Disposes the client and completes any pending requests with errors.
  Future<void> dispose() async {
    for (final completer in _pendingRequests.values) {
      completer.completeError(
        const JsonRpcException(
          JsonRpcError(
            code: internalError,
            message: 'Client disposed',
          ),
        ),
      );
    }
    _pendingRequests.clear();
    await _notificationController.close();
    await _requestController.close();
  }
}
