import 'dart:async';

/// Abstract transport interface for sending and receiving messages.
abstract class Transport {
  /// A stream of incoming messages.
  Stream<String> get incoming;

  /// Sends a [message] through the transport.
  void send(String message);

  /// Closes the transport and releases resources.
  Future<void> close();

  /// Whether the transport is currently connected.
  bool get isConnected;
}
