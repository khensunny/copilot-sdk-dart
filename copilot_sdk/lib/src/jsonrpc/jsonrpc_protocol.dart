import 'dart:convert';

const jsonRpcVersion = '2.0';

const parseError = -32700;
const invalidRequest = -32600;
const methodNotFound = -32601;
const invalidParams = -32602;
const internalError = -32603;

/// Converts a JSON-RPC ID (String, int, or null) to a String.
String _idToString(Object? id) {
  if (id == null) return '';
  if (id is String) return id;
  if (id is int) return id.toString();
  return id.toString();
}

sealed class JsonRpcMessage {
  const JsonRpcMessage();

  Map<String, dynamic> toJson();

  String encode() => jsonEncode(toJson());

  static JsonRpcMessage decode(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    return fromJson(data);
  }

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

final class JsonRpcRequest extends JsonRpcMessage {
  const JsonRpcRequest({
    required this.id,
    required this.method,
    this.params,
  });

  factory JsonRpcRequest.fromJson(Map<String, dynamic> json) {
    return JsonRpcRequest(
      id: json['id'],
      method: json['method'] as String,
      params: json['params'],
    );
  }

  final Object? id;
  final String method;
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

final class JsonRpcNotification extends JsonRpcMessage {
  const JsonRpcNotification({
    required this.method,
    this.params,
  });

  factory JsonRpcNotification.fromJson(Map<String, dynamic> json) {
    return JsonRpcNotification(
      method: json['method'] as String,
      params: json['params'],
    );
  }

  final String method;
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

final class JsonRpcResponse extends JsonRpcMessage {
  const JsonRpcResponse({
    required this.id,
    required this.result,
  });

  factory JsonRpcResponse.fromJson(Map<String, dynamic> json) {
    return JsonRpcResponse(
      id: json['id'],
      result: json['result'],
    );
  }

  final Object? id;
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

final class JsonRpcError {
  const JsonRpcError({
    required this.code,
    required this.message,
    this.data,
  });

  factory JsonRpcError.fromJson(Map<String, dynamic> json) {
    return JsonRpcError(
      code: json['code'] as int,
      message: json['message'] as String,
      data: json['data'],
    );
  }

  final int code;
  final String message;
  final Object? data;

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'message': message,
      if (data != null) 'data': data,
    };
  }
}

final class JsonRpcErrorResponse extends JsonRpcMessage {
  const JsonRpcErrorResponse({
    required this.id,
    required this.error,
  });

  factory JsonRpcErrorResponse.fromJson(Map<String, dynamic> json) {
    return JsonRpcErrorResponse(
      id: json['id'],
      error: JsonRpcError.fromJson(json['error'] as Map<String, dynamic>),
    );
  }

  final Object? id;
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
