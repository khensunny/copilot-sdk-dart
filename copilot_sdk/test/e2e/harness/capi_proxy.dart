import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

class ParsedHttpExchange {
  ParsedHttpExchange({
    required this.request,
    required this.response,
  });

  factory ParsedHttpExchange.fromJson(Map<String, dynamic> json) {
    return ParsedHttpExchange(
      request: (json['request'] as Map<dynamic, dynamic>).cast<String, dynamic>(),
      response: json['response'] as Map<String, dynamic>?,
    );
  }

  final Map<String, dynamic> request;
  final Map<String, dynamic>? response;
}

class CapiProxy {
  String? _proxyUrl;
  Process? _serverProcess;

  Future<String> start() async {
    // Find the copilot-sdk-ts repository root
    final repoRoot = _findRepoRoot();
    final harnessDir = Directory('$repoRoot/test/harness');

    _serverProcess = await Process.start(
      'npm',
      ['run', 'start'],
      workingDirectory: harnessDir.path,
      runInShell: true,
    );

    final stdoutStream = _serverProcess!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    
    final errorBuffer = StringBuffer();
    _serverProcess!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => errorBuffer.writeln(line));

    // Wait for "Listening: http://..." message with 10 second timeout
    // Skip npm output lines and wait for the actual server output
    final listeningPattern = RegExp(r'Listening: (http://[^\s]+)');
    String? line;
    await for (final event in stdoutStream.timeout(const Duration(seconds: 10))) {
      if (event.trim().isEmpty) continue;
      final match = listeningPattern.firstMatch(event);
      if (match != null) {
        _proxyUrl = match.group(1);
        break;
      }
      // Keep track of lines that don't match for error reporting
      line = event;
    }
    
    if (_proxyUrl == null) {
      throw TimeoutException(
        'Proxy failed to start within 10 seconds. Last line: $line. Stderr: $errorBuffer',
      );
    }
    return _proxyUrl!;
  }

  static String _findRepoRoot() {
    var dir = Directory.current;
    while (dir != null) {
      // Check for reference/copilot-sdk-ts/nodejs directory structure
      final nodejsDir = Directory('${dir.path}/reference/copilot-sdk-ts/nodejs');
      if (nodejsDir.existsSync()) {
        return '${dir.path}/reference/copilot-sdk-ts';
      }
      dir = dir.parent;
    }
    throw StateError(
      'Could not find copilot-sdk-ts repository root. '
      'Looking for reference/copilot-sdk-ts/nodejs directory.',
    );
  }

  Future<void> updateConfig({
    required String filePath,
    required String workDir,
    required ({String file, int? line, String name}) testInfo,
  }) async {
    final response = await http.post(
      Uri.parse('$_proxyUrl/config'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({
        'filePath': filePath,
        'workDir': workDir,
        'testInfo': {
          'file': testInfo.file,
          if (testInfo.line != null) 'line': testInfo.line,
        },
      }),
    );
    expect(response.statusCode, 200);
  }

  Future<List<ParsedHttpExchange>> getExchanges() async {
    final response = await http.get(Uri.parse('$_proxyUrl/exchanges'));
    expect(response.statusCode, 200);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.cast<Map<String, dynamic>>().map(ParsedHttpExchange.fromJson).toList();
  }

  Future<void> stop({bool skipWritingCache = false}) async {
    if (_proxyUrl == null) return;
    final url = skipWritingCache ? '$_proxyUrl/stop?skipWritingCache=true' : '$_proxyUrl/stop';
    final response = await http.post(Uri.parse(url));
    expect(response.statusCode, 200);
    _proxyUrl = null;
    _serverProcess = null;
  }
}
