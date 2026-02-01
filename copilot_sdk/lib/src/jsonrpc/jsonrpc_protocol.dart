import 'dart:convert';

/// JSON-RPC protocol version.
const jsonRpcVersion = '2.0';

/// JSON-RPC parse error code.
const parseError = -32700;

/// JSON-RPC invalid request error code.
const invalidRequest = -32600;

/// JSON-RPC method not found error code.
const methodNotFound = -32601;

/// JSON-RPC invalid params error code.
const invalidParams = -32602;

/// JSON-RPC internal error code.
const internalError = -32603;

/// Converts a JSON-RPC ID (String, int, or null) to a String.
String _idToString(Object? id) {
  if (id == null) return '';
  if (id is String) return id;
  if (id is int) return id.toString();
  return id.toString();
}

/// Base class for JSON-RPC messages.
sealed class JsonRpcMessage {
  const JsonRpcMessage();

  /// Serializes the message to a JSON map.
  Map<String, dynamic> toJson();

  /// Encodes the message to a JSON string.
  String encode() => jsonEncode(toJson());

  /// Decodes a JSON string into a JSON-RPC message.
  static JsonRpcMessage decode(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    return fromJson(data);
  }

  /// Creates a JSON-RPC message from a JSON map.
  static JsonRpcMessage fromJson(Map<String, dynamic> json) {
    if (json.containsKey('error')) {
      return JsonRpcErrorResponse.fromJson(json);
    }
    if (json.containsKey('result')) {
      return JsonRpcResponse.fromJson(json);
    }
    if (json.containsKey('id')) {
      return JsonRpcRequest.fromJson(json);
    }
    return JsonRpcNotification.fromJson(json);
  }
}

/// {@template json_rpc_request}
/// JSON-RPC request with an ID and method.
/// {@endtemplate}
/// {@macro json_rpc_request}
final class JsonRpcRequest extends JsonRpcMessage {
  /// {@macro json_rpc_request}
  const JsonRpcRequest({
    required this.id,
    required this.method,
    this.params,
  });

  /// Parses a JSON-RPC request from JSON.
  factory JsonRpcRequest.fromJson(Map<String, dynamic> json) {
    return JsonRpcRequest(
      id: json['id'],
      method: json['method'] as String,
      params: json['params'],
    );
  }

  /// Request identifier.
  final Object? id;

  /// Method name to invoke.
  final String method;

  /// Optional request parameters.
  final Object? params;

  @override
  Map<String, dynamic> toJson() {
    return {
      'jsonrpc': jsonRpcVersion,
      'id': id,
      'method': method,
      if (params != null) 'params': params,
    };
  }

  /// Returns the ID as a string for use as a map key.
  String get idAsString => _idToString(id);
}

/// {@template json_rpc_notification}
/// JSON-RPC notification without an ID.
/// {@endtemplate}
/// {@macro json_rpc_notification}
final class JsonRpcNotification extends JsonRpcMessage {
  /// {@macro json_rpc_notification}
  const JsonRpcNotification({
    required this.method,
    this.params,
  });

  /// Parses a JSON-RPC notification from JSON.
  factory JsonRpcNotification.fromJson(Map<String, dynamic> json) {
    return JsonRpcNotification(
      method: json['method'] as String,
      params: json['params'],
    );
  }

  /// Method name to invoke.
  final String method;

  /// Optional notification parameters.
  final Object? params;

  @override
  Map<String, dynamic> toJson() {
    return {
      'jsonrpc': jsonRpcVersion,
      'method': method,
      if (params != null) 'params': params,
    };
  }
}

/// {@template json_rpc_response}
/// JSON-RPC response with a result.
/// {@endtemplate}
/// {@macro json_rpc_response}
final class JsonRpcResponse extends JsonRpcMessage {
  /// {@macro json_rpc_response}
  const JsonRpcResponse({
    required this.id,
    required this.result,
  });

  /// Parses a JSON-RPC response from JSON.
  factory JsonRpcResponse.fromJson(Map<String, dynamic> json) {
    return JsonRpcResponse(
      id: json['id'],
      result: json['result'],
    );
  }

  /// Response identifier (matches request ID).
  final Object? id;

  /// Result payload.
  final Object? result;

  @override
  Map<String, dynamic> toJson() {
    return {
      'jsonrpc': jsonRpcVersion,
      'id': id,
      'result': result,
    };
  }
}

/// {@template json_rpc_error}
/// JSON-RPC error object.
/// {@endtemplate}
/// {@macro json_rpc_error}
final class JsonRpcError {
  /// {@macro json_rpc_error}
  const JsonRpcError({
    required this.code,
    required this.message,
    this.data,
  });

  /// Parses a JSON-RPC error from JSON.
  factory JsonRpcError.fromJson(Map<String, dynamic> json) {
    return JsonRpcError(
      code: json['code'] as int,
      message: json['message'] as String,
      data: json['data'],
    );
  }

  /// Error code.
  final int code;

  /// Human-readable error message.
  final String message;

  /// Optional error data.
  final Object? data;

  /// Serializes the error to JSON.
  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'message': message,
      if (data != null) 'data': data,
    };
  }
}

/// {@template json_rpc_error_response}
/// JSON-RPC response that contains an error.
/// {@endtemplate}
/// {@macro json_rpc_error_response}
final class JsonRpcErrorResponse extends JsonRpcMessage {
  /// {@macro json_rpc_error_response}
  const JsonRpcErrorResponse({
    required this.id,
    required this.error,
  });

  /// Parses a JSON-RPC error response from JSON.
  factory JsonRpcErrorResponse.fromJson(Map<String, dynamic> json) {
    return JsonRpcErrorResponse(
      id: json['id'],
      error: JsonRpcError.fromJson(json['error'] as Map<String, dynamic>),
    );
  }

  /// Response identifier (matches request ID).
  final Object? id;

  /// Error payload.
  final JsonRpcError error;

  @override
  Map<String, dynamic> toJson() {
    return {
      'jsonrpc': jsonRpcVersion,
      'id': id,
      'error': error.toJson(),
    };
  }
}
