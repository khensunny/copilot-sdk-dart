import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:copilot_sdk/src/transports/transport.dart';

/// Stdio transport for communicating with a spawned CLI process.
class StdioTransport implements Transport {
  /// Creates a new [StdioTransport] for the given process.
  StdioTransport(this._process) {
    _subscription = _process.stdout.listen(
      _handleChunk,
      onError: _incomingController.addError,
      onDone: _handleDone,
    );

    unawaited(
      _process.exitCode.then((_) {
        _isConnected = false;
        unawaited(_incomingController.close());
      }),
    );
  }

  final Process _process;
  final StreamController<String> _incomingController = StreamController<String>.broadcast();
  late final StreamSubscription<List<int>> _subscription;
  final List<int> _buffer = <int>[];
  bool _isConnected = true;

  @override
  Stream<String> get incoming => _incomingController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  void send(String message) {
    if (!_isConnected) {
      throw StateError('Transport is not connected');
    }
    final messageBytes = utf8.encode(message);
    final header = 'Content-Length: ${messageBytes.length}\r\n\r\n';
    _process.stdin.add(utf8.encode(header));
    _process.stdin.add(messageBytes);
    unawaited(_process.stdin.flush());
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await _incomingController.close();
    _process.kill();
    _isConnected = false;
  }

  void _handleDone() {
    _isConnected = false;
    unawaited(_incomingController.close());
  }

  void _handleChunk(List<int> chunk) {
    _buffer.addAll(chunk);
    _drainBuffer();
  }

  void _drainBuffer() {
    while (true) {
      final headerEnd = _indexOfSubsequence(_buffer, _headerDelimiter);
      if (headerEnd == -1) {
        return;
      }

      final headerBytes = _buffer.sublist(0, headerEnd);
      final headerText = ascii.decode(headerBytes, allowInvalid: true);
      final contentLength = _parseContentLength(headerText);
      if (contentLength == null || contentLength < 0) {
        _buffer.removeRange(0, headerEnd + _headerDelimiter.length);
        continue;
      }

      final messageStart = headerEnd + _headerDelimiter.length;
      final messageEnd = messageStart + contentLength;
      if (_buffer.length < messageEnd) {
        return;
      }

      final messageBytes = _buffer.sublist(messageStart, messageEnd);
      _buffer.removeRange(0, messageEnd);

      try {
        final message = utf8.decode(messageBytes);
        _incomingController.add(message);
      } on Exception catch (error) {
        _incomingController.addError(error);
      }
    }
  }
}

const List<int> _headerDelimiter = <int>[13, 10, 13, 10];

int _indexOfSubsequence(List<int> buffer, List<int> pattern) {
  if (buffer.length < pattern.length) {
    return -1;
  }
  for (var i = 0; i <= buffer.length - pattern.length; i++) {
    var match = true;
    for (var j = 0; j < pattern.length; j++) {
      if (buffer[i + j] != pattern[j]) {
        match = false;
        break;
      }
    }
    if (match) {
      return i;
    }
  }
  return -1;
}

int? _parseContentLength(String headerText) {
  final lines = headerText.split('\r\n');
  for (final line in lines) {
    final separatorIndex = line.indexOf(':');
    if (separatorIndex == -1) {
      continue;
    }
    final name = line.substring(0, separatorIndex).trim().toLowerCase();
    if (name != 'content-length') {
      continue;
    }
    final valueText = line.substring(separatorIndex + 1).trim();
    return int.tryParse(valueText);
  }
  return null;
}
