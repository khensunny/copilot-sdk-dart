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
    final harnessPath = Directory.current.parent.uri
        .resolve('reference/copilot-sdk-ts/test/harness/server.ts')
        .toFilePath();

    final nodejsDir = Directory.current.parent.uri.resolve('reference/copilot-sdk-ts/nodejs/').toFilePath();

    _serverProcess = await Process.start(
      'npx',
      ['tsx', harnessPath],
      workingDirectory: nodejsDir,
      runInShell: true,
    );

    final line = await _serverProcess!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .firstWhere((event) => event.trim().isNotEmpty);
    final match = RegExp(r'Listening: (http://[^\s]+)').firstMatch(line);
    if (match == null) {
      throw StateError('Unable to parse proxy URL from: $line');
    }
    _proxyUrl = match.group(1);
    return _proxyUrl!;
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
