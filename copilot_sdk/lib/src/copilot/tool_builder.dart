import 'package:copilot_sdk/src/copilot/copilot_config.dart';
import 'package:copilot_sdk/src/copilot/copilot_types.dart';

/// Builder for creating JSON Schema definitions with a fluent API.
///
/// This provides Zod-like ergonomics for defining tool parameter schemas.
///
/// ## Usage
///
/// ```dart
/// final tool = defineTool(
///   'lookup_fact',
///   description: 'Retrieve a fact from the knowledge base',
///   parameters: (s) => {
///     'key': s.string(description: 'The key to look up', required: true),
///     'namespace': s.string(description: 'Optional namespace'),
///   },
///   handler: (args, invocation) async {
///     final key = args['key'] as String;
///     return ToolResult.success('Fact for $key');
///   },
/// );
/// ```
class SchemaBuilder {
  /// Creates an object schema property.
  SchemaProperty object(
    Map<String, SchemaProperty> properties, {
    String? description,
    List<String>? required,
  }) {
    return SchemaProperty.object(
      properties: properties,
      description: description,
      required: required ??
          properties.entries
              .where((e) => e.value.isRequired)
              .map((e) => e.key)
              .toList(),
    );
  }

  /// Creates a string schema property.
  SchemaProperty string({
    String? description,
    List<String>? enumValues,
    String? pattern,
    int? minLength,
    int? maxLength,
    String? defaultValue,
    bool required = false,
  }) {
    return SchemaProperty.string(
      description: description,
      enumValues: enumValues,
      pattern: pattern,
      minLength: minLength,
      maxLength: maxLength,
      defaultValue: defaultValue,
      required: required,
    );
  }

  /// Creates an integer schema property.
  SchemaProperty integer({
    String? description,
    int? minimum,
    int? maximum,
    int? defaultValue,
    bool required = false,
  }) {
    return SchemaProperty.integer(
      description: description,
      minimum: minimum,
      maximum: maximum,
      defaultValue: defaultValue,
      required: required,
    );
  }

  /// Creates a number (double) schema property.
  SchemaProperty number({
    String? description,
    double? minimum,
    double? maximum,
    double? defaultValue,
    bool required = false,
  }) {
    return SchemaProperty.number(
      description: description,
      minimum: minimum,
      maximum: maximum,
      defaultValue: defaultValue,
      required: required,
    );
  }

  /// Creates a boolean schema property.
  SchemaProperty boolean({
    String? description,
    bool? defaultValue,
    bool required = false,
  }) {
    return SchemaProperty.boolean(
      description: description,
      defaultValue: defaultValue,
      required: required,
    );
  }

  /// Creates an array schema property.
  SchemaProperty array({
    required SchemaProperty items,
    String? description,
    int? minItems,
    int? maxItems,
    bool required = false,
  }) {
    return SchemaProperty.array(
      items: items,
      description: description,
      minItems: minItems,
      maxItems: maxItems,
      required: required,
    );
  }

  /// Creates a property that can be one of several types.
  SchemaProperty union(
    List<SchemaProperty> types, {
    String? description,
    bool required = false,
  }) {
    return SchemaProperty.union(
      types: types,
      description: description,
      required: required,
    );
  }

  /// Creates a property that can be any type.
  SchemaProperty any({
    String? description,
    bool required = false,
  }) {
    return SchemaProperty.any(
      description: description,
      required: required,
    );
  }

  /// Creates a property that can be null or the specified type.
  SchemaProperty nullable(SchemaProperty type, {String? description}) {
    return type.copyWith(
      description: description ?? type.description,
      nullable: true,
      required: false,
    );
  }
}

/// Represents a schema property for tool parameters.
class SchemaProperty {

  factory SchemaProperty.object({
    required Map<String, SchemaProperty> properties,
    String? description,
    List<String>? required,
  }) {
    return SchemaProperty._(
      type: 'object',
      description: description,
      properties: properties,
      required: required?.isNotEmpty ?? false,
    );
  }

  factory SchemaProperty.string({
    String? description,
    List<String>? enumValues,
    String? pattern,
    int? minLength,
    int? maxLength,
    String? defaultValue,
    bool required = false,
  }) {
    return SchemaProperty._(
      type: 'string',
      description: description,
      required: required,
      enumValues: enumValues,
      pattern: pattern,
      minLength: minLength,
      maxLength: maxLength,
      defaultValue: defaultValue,
    );
  }

  factory SchemaProperty.integer({
    String? description,
    int? minimum,
    int? maximum,
    int? defaultValue,
    bool required = false,
  }) {
    return SchemaProperty._(
      type: 'integer',
      description: description,
      required: required,
      minimum: minimum,
      maximum: maximum,
      defaultValue: defaultValue,
    );
  }

  factory SchemaProperty.number({
    String? description,
    double? minimum,
    double? maximum,
    double? defaultValue,
    bool required = false,
  }) {
    return SchemaProperty._(
      type: 'number',
      description: description,
      required: required,
      minimum: minimum,
      maximum: maximum,
      defaultValue: defaultValue,
    );
  }

  factory SchemaProperty.boolean({
    String? description,
    bool? defaultValue,
    bool required = false,
  }) {
    return SchemaProperty._(
      type: 'boolean',
      description: description,
      required: required,
      defaultValue: defaultValue,
    );
  }

  factory SchemaProperty.array({
    required SchemaProperty items,
    String? description,
    int? minItems,
    int? maxItems,
    bool required = false,
  }) {
    return SchemaProperty._(
      type: 'array',
      description: description,
      required: required,
      items: items,
      minimum: minItems,
      maximum: maxItems,
    );
  }

  factory SchemaProperty.union({
    required List<SchemaProperty> types,
    String? description,
    bool required = false,
  }) {
    return SchemaProperty._(
      type: 'union',
      description: description,
      required: required,
      anyOf: types,
    );
  }

  factory SchemaProperty.any({
    String? description,
    bool required = false,
  }) {
    return SchemaProperty._(
      type: 'object',
      description: description,
      required: required,
    );
  }
  const SchemaProperty._({
    required this.type,
    this.description,
    this.required = false,
    this.nullable = false,
    this.properties,
    this.items,
    this.enumValues,
    this.pattern,
    this.minLength,
    this.maxLength,
    this.minimum,
    this.maximum,
    this.defaultValue,
    this.anyOf,
  });

  final String type;
  final String? description;
  final bool required;
  final bool nullable;
  final Map<String, SchemaProperty>? properties;
  final SchemaProperty? items;
  final List<dynamic>? enumValues;
  final String? pattern;
  final int? minLength;
  final int? maxLength;
  final num? minimum;
  final num? maximum;
  final dynamic defaultValue;
  final List<SchemaProperty>? anyOf;

  bool get isRequired => required;

  SchemaProperty copyWith({
    String? type,
    String? description,
    bool? required,
    bool? nullable,
    Map<String, SchemaProperty>? properties,
    SchemaProperty? items,
    List<dynamic>? enumValues,
    String? pattern,
    int? minLength,
    int? maxLength,
    num? minimum,
    num? maximum,
    dynamic defaultValue,
    List<SchemaProperty>? anyOf,
  }) {
    return SchemaProperty._(
      type: type ?? this.type,
      description: description ?? this.description,
      required: required ?? this.required,
      nullable: nullable ?? this.nullable,
      properties: properties ?? this.properties,
      items: items ?? this.items,
      enumValues: enumValues ?? this.enumValues,
      pattern: pattern ?? this.pattern,
      minLength: minLength ?? this.minLength,
      maxLength: maxLength ?? this.maxLength,
      minimum: minimum ?? this.minimum,
      maximum: maximum ?? this.maximum,
      defaultValue: defaultValue ?? this.defaultValue,
      anyOf: anyOf ?? this.anyOf,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'type': type,
      if (description != null) 'description': description,
      if (nullable) 'nullable': true,
    };

    if (properties != null) {
      json['properties'] = properties!.map((k, v) => MapEntry(k, v.toJson()));
      final requiredProps = properties!.entries
          .where((e) => e.value.required)
          .map((e) => e.key)
          .toList();
      if (requiredProps.isNotEmpty) {
        json['required'] = requiredProps;
      }
    }

    if (items != null) {
      json['items'] = items!.toJson();
    }

    if (enumValues != null) {
      json['enum'] = enumValues;
    }

    if (pattern != null) {
      json['pattern'] = pattern;
    }

    if (minLength != null) {
      json['minLength'] = minLength;
    }

    if (maxLength != null) {
      json['maxLength'] = maxLength;
    }

    if (minimum != null) {
      json['minimum'] = minimum;
    }

    if (maximum != null) {
      json['maximum'] = maximum;
    }

    if (defaultValue != null) {
      json['default'] = defaultValue;
    }

    if (anyOf != null) {
      json['anyOf'] = anyOf!.map((t) => t.toJson()).toList();
    }

    return json;
  }
}

/// Defines a tool with a fluent API for parameter schemas.
///
/// This provides Zod-like ergonomics for defining tools with typed parameters.
///
/// ## Example
///
/// ```dart
/// final lookupTool = defineTool(
///   'lookup_fact',
///   description: 'Retrieve a fact from the knowledge base',
///   parameters: (s) => {
///     'key': s.string(
///       description: 'The key to look up',
///       required: true,
///     ),
///     'namespace': s.string(
///       description: 'Optional namespace',
///     ),
///   },
///   handler: (args, invocation) async {
///     final key = args['key'] as String;
///     final namespace = args['namespace'] as String?;
///     // ... fetch and return result
///     return ToolResult.success('Fact for $key');
///   },
/// );
///
/// // Use in session config
/// final session = await client.createSession(
///   SessionConfig(
///     tools: [lookupTool],
///   ),
/// );
///
/// // Or register dynamically
/// session.registerTool(lookupTool);
/// ```
ToolDefinition defineTool(
  String name, {
  required Map<String, SchemaProperty> Function(SchemaBuilder s) parameters, required ToolHandler handler, String? description,
}) {
  final builder = SchemaBuilder();
  final params = parameters(builder);

  // Build JSON schema
  final schema = <String, dynamic>{
    'type': 'object',
    'properties': <String, dynamic>{},
  };

  final required = <String>[];
  for (final entry in params.entries) {
    schema['properties']![entry.key] = entry.value.toJson();
    if (entry.value.required) {
      required.add(entry.key);
    }
  }

  if (required.isNotEmpty) {
    schema['required'] = required;
  }

  return ToolDefinition(
    name: name,
    description: description,
    parameters: schema,
    handler: handler,
  );
}

/// Creates a simple tool with no parameters.
///
/// ## Example
///
/// ```dart
/// final helloTool = defineSimpleTool(
///   'hello',
///   description: 'Say hello',
///   handler: (args, invocation) async {
///     return ToolResult.success('Hello, world!');
///   },
/// );
/// ```
ToolDefinition defineSimpleTool(
  String name, {
  required ToolHandler handler, String? description,
}) {
  return ToolDefinition(
    name: name,
    description: description,
    parameters: {
      'type': 'object',
      'properties': <String, dynamic>{},
    },
    handler: handler,
  );
}
