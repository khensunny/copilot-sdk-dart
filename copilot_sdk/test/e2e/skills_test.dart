import 'dart:io' as io;

import 'package:copilot_sdk/copilot_sdk.dart';
import 'package:test/test.dart';

import 'harness/sdk_test_context.dart';

void main() {
  final contextFuture = createSdkTestContext(logLevel: LogLevel.debug);
  registerSdkTestContext(contextFuture);

  group('Skills Configuration', () {
    late SdkTestContext context;

    setUpAll(() async {
      context = await contextFuture;
    });

    const skillMarker = 'PINEAPPLE_COCONUT_42';

    io.Directory skillsDir() => io.Directory('${context.workDir.path}/.test_skills');

    setUp(() {
      final rootDir = skillsDir();
      if (rootDir.existsSync()) {
        rootDir.deleteSync(recursive: true);
      }
    });

    String createSkillDir() {
      final rootDir = skillsDir();
      rootDir.createSync(recursive: true);

      final skillSubdir = io.Directory('${rootDir.path}/test-skill');
      skillSubdir.createSync(recursive: true);

      const skillContent =
          '''
---
name: test-skill
description: A test skill that adds a marker to responses
---

# Test Skill Instructions

IMPORTANT: You MUST include the exact text "$skillMarker" somewhere in EVERY response you give.
This is a mandatory requirement. Include it naturally in your response.
''';

      io.File('${skillSubdir.path}/SKILL.md').writeAsStringSync(skillContent);
      return rootDir.path;
    }

    test('should load and apply skill from skillDirectories', () async {
      final skillDirPath = createSkillDir();
      final session = await context.copilotClient.createSession(
        SessionConfig(skillDirectories: [skillDirPath]),
      );

      final message = await session.sendAndWait(
        'Say hello briefly using the test skill.',
      );

      expect(message?.data.content, contains(skillMarker));
      await session.destroy();
    });

    test('should not apply skill when disabled via disabledSkills', () async {
      final skillDirPath = createSkillDir();
      final session = await context.copilotClient.createSession(
        SessionConfig(
          skillDirectories: [skillDirPath],
          disabledSkills: ['test-skill'],
        ),
      );

      final message = await session.sendAndWait(
        'Say hello briefly using the test skill.',
      );

      expect(message?.data.content, isNot(contains(skillMarker)));
      await session.destroy();
    });
  });
}
