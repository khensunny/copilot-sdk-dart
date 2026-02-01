import 'dart:async';

import 'package:copilot_sdk/copilot_sdk.dart';

Future<AssistantMessage> getFinalAssistantMessage(CopilotSession session) async {
  try {
    return await _getExistingFinalResponse(session);
    // StateError is thrown when no final response exists yet; this is a control flow pattern
    // to fall back to waiting for a future response.
    // ignore: avoid_catching_errors
  } on StateError {
    return _getFutureFinalResponse(session);
  }
}

Future<AssistantMessage> _getFutureFinalResponse(
  CopilotSession session,
) {
  final completer = Completer<AssistantMessage>();
  AssistantMessage? finalAssistantMessage;

  session.onAny((event) {
    if (event is AssistantMessage) {
      finalAssistantMessage = event;
    } else if (event is SessionIdle) {
      if (finalAssistantMessage == null) {
        completer.completeError(
          StateError('Received session.idle without assistant.message'),
        );
      } else {
        completer.complete(finalAssistantMessage!);
      }
    } else if (event is SessionError) {
      completer.completeError(StateError(event.data.message));
    }
  });

  return completer.future;
}

Future<AssistantMessage> _getExistingFinalResponse(
  CopilotSession session,
) async {
  final messages = await session.getMessages();
  final finalUserIndex = messages.lastIndexWhere((m) => m is UserMessage);
  final currentTurnMessages = finalUserIndex < 0 ? messages : messages.sublist(finalUserIndex);

  final currentTurnError = currentTurnMessages.whereType<SessionError>().cast<SessionError?>().firstWhere(
    (event) => event != null,
    orElse: () => null,
  );
  if (currentTurnError != null) {
    throw StateError(currentTurnError.data.message);
  }

  final sessionIdleIndex = currentTurnMessages.indexWhere(
    (m) => m is SessionIdle,
  );
  if (sessionIdleIndex != -1) {
    final assistantMessage = currentTurnMessages.sublist(0, sessionIdleIndex).whereType<AssistantMessage>().lastOrNull;
    if (assistantMessage != null) {
      return assistantMessage;
    }
  }

  throw StateError('No completed assistant message found yet.');
}

Future<T> getNextEventOfType<T extends SessionEvent>(
  CopilotSession session,
) {
  final completer = Completer<T>();
  session.onAny((event) {
    if (event is T) {
      if (!completer.isCompleted) {
        completer.complete(event);
      }
    } else if (event is SessionError) {
      if (!completer.isCompleted) {
        completer.completeError(StateError(event.data.message));
      }
    }
  });
  return completer.future;
}

Future<void> retry(
  String message,
  Future<void> Function() fn, {
  int maxTries = 5,
  Duration delay = const Duration(milliseconds: 200),
}) async {
  var failedAttempts = 0;
  while (true) {
    try {
      await fn();
      return;
    } catch (error) {
      failedAttempts++;
      if (failedAttempts >= maxTries) {
        throw StateError('Failed to $message after $maxTries attempts: $error');
      }
      await Future<void>.delayed(delay);
    }
  }
}

extension _IterableLastOrNull<T> on Iterable<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
