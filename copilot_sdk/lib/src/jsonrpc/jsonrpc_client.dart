import 'dart:async';

import 'package:copilot_sdk/src/jsonrpc/jsonrpc_protocol.dart';
import 'package:uuid/uuid.dart';

class JsonRpcException implements Exception {
  const JsonRpcException(this.error);

  final JsonRpcError error;

  @override
  String toString() => 'JsonRpcException: ${error.message} (${error.code})';
}

typedef MessageSender = void Function(String message);

typedef RequestHandler =
    Future<Object?> Function(
      String method,
      Object? params,
    );

class JsonRpcClient {
  JsonRpcClient({
    required this.sendMessage,
    RequestHandler? requestHandler,
  }) : _requestHandler = requestHandler;

  final MessageSender sendMessage;
  final RequestHandler? _requestHandler;

  final _uuid = const Uuid();
  final _pendingRequests = <String, Completer<Object?>>{};

  final _notificationController =
      StreamController<JsonRpcNotification>.broadcast();
  final _requestController = StreamController<JsonRpcRequest>.broadcast();

  Stream<JsonRpcNotification> get onNotification =>
      _notificationController.stream;

  Stream<JsonRpcRequest> get onRequest => _requestController.stream;

  Future<Object?> sendRequest(String method, [Object? params]) {
    final id = _uuid.v4();
    final request = JsonRpcRequest(id: id, method: method, params: params);
    final completer = Completer<Object?>();

    _pendingRequests[id] = completer;
    sendMessage(request.encode());

    return completer.future;
  }

  void sendNotification(String method, [Object? params]) {
    final notification = JsonRpcNotification(method: method, params: params);
    sendMessage(notification.encode());
  }

  void sendResponse(Object? id, Object? result) {
    final response = JsonRpcResponse(id: id, result: result);
    final message = response.encode();
    sendMessage(message);
  }

  void sendErrorResponse(Object? id, JsonRpcError error) {
    final response = JsonRpcErrorResponse(id: id, error: error);
    sendMessage(response.encode());
  }

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
