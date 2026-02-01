import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

void main() {
  final logger = Logger();
  const versionFilePath = 'sdk-protocol-version.json';
  const outputPath = 'lib/src/copilot/protocol_version.dart';

  final versionFile = File(versionFilePath);
  if (!versionFile.existsSync()) {
    logger.err('Version file not found at $versionFilePath');
    exit(1);
  }

  final raw = versionFile.readAsStringSync();
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final version = json['version'];

  if (version is! int) {
    logger.err('Expected integer "version" in $versionFilePath');
    exit(1);
  }

  final buffer = StringBuffer()
    ..writeln('/// SDK protocol version for compatibility checking.')
    ..writeln('const int sdkProtocolVersion = $version;');

  File(outputPath)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(buffer.toString());

  logger.success('Updated $outputPath with protocol version $version');
}
