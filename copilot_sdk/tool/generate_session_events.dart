import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:schema2dart/schema2dart.dart';

void main() async {
  final logger = Logger();
  const schemaPath = 'schemas/session-events.schema.json';
  const outputPath = 'lib/src/models/generated/session_events.dart';

  logger.info('Loading schema from: $schemaPath');

  final schemaFile = File(schemaPath);
  if (!schemaFile.existsSync()) {
    logger.err('Schema file not found at $schemaPath');
    exit(1);
  }

  final schemaJson =
      jsonDecode(schemaFile.readAsStringSync()) as Map<String, dynamic>;

  logger.info('Schema loaded, generating Dart types...');

  const options = SchemaGeneratorOptions(
    rootClassName: 'SessionEvent',
    emitValidationHelpers: true,
    generateHelpers: true,
    sourcePath: schemaPath,
  );

  final generator = SchemaGenerator(options: options);
  final dartCode = generator.generate(schemaJson);

  final outputFile = File(outputPath);
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(dartCode);

  // Log completion after the output file is written.
  logger
    ..success('Dart types generated at: $outputPath')
    ..detail('Generated ${dartCode.split('\n').length} lines of code');
}
