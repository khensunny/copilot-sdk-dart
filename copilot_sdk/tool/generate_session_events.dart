import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:schema2dart/schema2dart.dart';

/// Post-processes generated Dart code to fix known schema2dart issues.
///
/// Issues addressed:
/// 1. Number type casting: Changes `as double` to `(as num).toDouble()` to handle
///    integer values from JSON (schema "number" type can be int or float)
/// 2. Reserved class names: Renames class `Function` to `Function$` to avoid
///    conflict with Dart's Function type
/// 3. Import ordering: Ensures dart: imports come before package: imports
String postProcessGeneratedCode(String code) {
  var processed = code;

  // Fix 1: Number type casting - handle both nullable and non-nullable
  // Change: `json['key'] as double` → `(json['key'] as num).toDouble()`
  // Change: `json['key'] as double?` → `(json['key'] as num?)?.toDouble()`
  processed = processed.replaceAllMapped(
    RegExp(
      r"(json\['[^']+'\]) as double\?",
      multiLine: true,
    ),
    (match) => '(${match.group(1)} as num?)?.toDouble()',
  );

  processed = processed.replaceAllMapped(
    RegExp(
      r"(json\['[^']+'\]) as double(?![?])",
      multiLine: true,
    ),
    (match) => '(${match.group(1)} as num).toDouble()',
  );

  // Fix 2: Rename class Function to Function$
  // schema2dart handles reserved keywords in field names (e.g., `class$`)
  // but doesn't handle a generated class named "Function"
  //
  // We need to rename:
  // 1. Class declaration: `class Function` → `class Function$`
  // 2. Constructor calls: `Function(...)` → `Function$(...)`
  // 3. Static access: `Function.fromJson` → `Function$.fromJson`
  // 4. Type references: `Function ` → `Function$ ` (when used as a type)
  //
  // We must NOT touch:
  // - Function type syntax: `T Function(params)` (Dart's type syntax for functions)
  //
  // Strategy: Use a placeholder to avoid double-replacement

  const placeholder = '___FUNCTION_CLASS___';

  // Step 1: Replace class declaration with placeholder
  processed = processed.replaceAll(
    RegExp(r'\bclass Function\b'),
    'class $placeholder',
  );

  // Step 2: Replace constructor calls: `Function(` but NOT function type syntax
  //
  // Constructor call patterns (replace these):
  // - `= Function(` - assignment
  // - `: Function(` - named parameter or type annotation with constructor
  // - `, Function(` - parameter list
  // - `; Function(` - after semicolon
  // - `return Function(` - return statement
  //
  // Function type syntax (DON'T replace):
  // - `TYPE Function(TYPE)` - function type declaration
  //   The key difference: Function is preceded by a TYPE NAME (identifier), not punctuation
  //
  // Pattern: match Function( when preceded by punctuation or keywords
  // Don't match when preceded by an identifier (which would be function type syntax)
  processed = processed.replaceAllMapped(
    RegExp(r'([=:,;]\s*)Function\s*\('),
    (match) => '${match.group(1)}$placeholder(',
  );

  // Also match at start of line or after opening brace/paren (but be careful with function types)
  // This handles constructor calls in lists, maps, etc.
  processed = processed.replaceAllMapped(
    RegExp(r'(\{\s*)Function\s*\('),
    (match) => '${match.group(1)}$placeholder(',
  );
  processed = processed.replaceAllMapped(
    RegExp(r'(\(\s*)Function\s*\('),
    (match) => '${match.group(1)}$placeholder(',
  );
  processed = processed.replaceAllMapped(
    RegExp(r'\breturn\s+Function\s*\('),
    (match) => 'return $placeholder(',
  );

  // Step 3: Replace static method calls
  processed = processed.replaceAll(
    RegExp(r'\bFunction\.'),
    '$placeholder.',
  );

  // Step 4: Replace when used as a standalone type (followed by space or generic params)
  // e.g., `Function ` or `Function<...>`
  // But be careful not to match function type syntax
  processed = processed.replaceAllMapped(
    RegExp(r'\bFunction\b(?=\s+\w+|<|\s*\{)'),
    (match) => placeholder,
  );

  // Step 5: Replace placeholder with final name
  processed = processed.replaceAll(placeholder, r'Function$');

  // Step 6: Fix constructor declarations
  // The unnamed constructor `const Function({` needs to become `const Function$({`
  // This happens when the class has an unnamed constructor with the original class name
  processed = processed.replaceAll(
    RegExp(r'\bconst Function\s*\({'),
    r'const Function$({',
  );
  processed = processed.replaceAll(
    RegExp(r'\bFunction\s*\({'),
    r'Function$({',
  );

  // Fix 3: Reorder imports to ensure dart: comes before package:
  final lines = processed.split('\n');
  final dartImports = <String>[];
  final packageImports = <String>[];
  final otherLines = <String>[];

  for (final line in lines) {
    if (line.startsWith("import 'dart:")) {
      dartImports.add(line);
    } else if (line.startsWith("import 'package:")) {
      packageImports.add(line);
    } else {
      otherLines.add(line);
    }
  }

  // Rebuild with proper ordering
  return [
    ...dartImports,
    if (dartImports.isNotEmpty && packageImports.isNotEmpty) '',
    ...packageImports,
    if ((dartImports.isNotEmpty || packageImports.isNotEmpty) && otherLines.isNotEmpty) '',
    ...otherLines,
  ].join('\n');
}

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

  final schemaJson = jsonDecode(schemaFile.readAsStringSync()) as Map<String, dynamic>;

  logger.info('Schema loaded, generating Dart types...');

  const options = SchemaGeneratorOptions(
    rootClassName: 'SessionEvent',
    emitValidationHelpers: true,
    generateHelpers: true,
    sourcePath: schemaPath,
  );

  final generator = SchemaGenerator(options: options);
  var dartCode = generator.generate(schemaJson);

  logger.info('Post-processing generated code...');

  // Apply post-processing fixes
  dartCode = postProcessGeneratedCode(dartCode);

  final outputFile = File(outputPath);
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(dartCode);

  // Log completion after the output file is written.
  logger
    ..success('Dart types generated at: $outputPath')
    ..detail('Generated ${dartCode.split('\n').length} lines of code');
}
