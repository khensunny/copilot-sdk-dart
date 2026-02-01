import 'dart:convert';
import 'dart:io';

import 'package:schema2dart/schema2dart.dart';

void main() async {
  const schemaPath = 'schemas/session-events.schema.json';
  const outputPath = 'lib/src/models/generated/session_events.dart';

  print('Loading schema from: $schemaPath');

  final schemaFile = File(schemaPath);
  if (!schemaFile.existsSync()) {
    print('Error: Schema file not found at $schemaPath');
    exit(1);
  }

  final schemaJson =
      jsonDecode(schemaFile.readAsStringSync()) as Map<String, dynamic>;

  print('Schema loaded, generating Dart types...');

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

  print('Dart types generated at: $outputPath');
  print('Generated ${dartCode.split('\n').length} lines of code');
}
