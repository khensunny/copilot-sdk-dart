import 'dart:io' as io;

import 'package:copilot_sdk/copilot_sdk.dart';
import 'package:test/test.dart';
// Using Invoker for suite metadata until test exposes it publicly.
import 'package:test_api/src/backend/invoker.dart';

import 'capi_proxy.dart';
import 'sdk_test_helper.dart';

class SdkTestContext {
  SdkTestContext({
    required this.homeDir,
    required this.workDir,
    required this.openAiEndpoint,
    required this.copilotClient,
    required this.env,
  });

  final io.Directory homeDir;
  final io.Directory workDir;
  final CapiProxy openAiEndpoint;
  final CopilotClient copilotClient;
  final Map<String, String> env;
}

final io.Directory _snapshotsDir = io.Directory(
  '${io.Directory.current.path}/../reference/copilot-sdk-ts/test/snapshots',
).absolute;

String _defaultCliPath() {
  final envPath = io.Platform.environment['COPILOT_CLI_PATH'];
  if (envPath != null && envPath.isNotEmpty) {
    return envPath;
  }

  final fallback = io.Directory.current.parent.uri
      .resolve('reference/copilot-sdk-ts/nodejs/node_modules/@github/copilot/index.js')
      .toFilePath();
  return fallback;
}

Future<SdkTestContext> createSdkTestContext({
  LogLevel logLevel = LogLevel.error,
}) async {
  final homeDir = io.Directory.systemTemp.createTempSync('copilot-test-config-');
  final workDir = io.Directory.systemTemp.createTempSync('copilot-test-work-');

  final openAiEndpoint = CapiProxy();
  final proxyUrl = await openAiEndpoint.start();

  final env = Map<String, String>.from(io.Platform.environment)
    ..['COPILOT_API_URL'] = proxyUrl
    ..['XDG_CONFIG_HOME'] = homeDir.path
    ..['XDG_STATE_HOME'] = homeDir.path;

  final copilotClient = await CopilotClient.create(
    CopilotConfig(
      cliPath: _defaultCliPath(),
      cwd: workDir.path,
      env: env,
      logLevel: logLevel,
    ),
  );

  final harness = SdkTestContext(
    homeDir: homeDir,
    workDir: workDir,
    openAiEndpoint: openAiEndpoint,
    copilotClient: copilotClient,
    env: env,
  );
  return harness;
}

void registerSdkTestContext(Future<SdkTestContext> contextFuture) {
  var anyTestFailed = false;

  tearDown(() {
    if (Invoker.current?.liveTest.state.result.isPassing == false) {
      anyTestFailed = true;
    }
  });

  setUp(() async {
    final context = await contextFuture;
    final testInfo = _currentTestInfo();
    await context.openAiEndpoint.updateConfig(
      filePath: _snapshotFilePath(testInfo),
      workDir: context.workDir.path,
      testInfo: testInfo,
    );
  });

  tearDown(() async {
    final context = await contextFuture;
    await _deleteContents(context.homeDir);
    await _deleteContents(context.workDir);
  });

  tearDownAll(() async {
    final context = await contextFuture;
    await context.copilotClient.stop();
    await context.openAiEndpoint.stop(skipWritingCache: anyTestFailed);
    await retry(
      'remove e2e test homeDir',
      () => context.homeDir.delete(recursive: true),
    );
    await retry(
      'remove e2e test workDir',
      () => context.workDir.delete(recursive: true),
    );
  });
}

Future<void> _deleteContents(io.Directory directory) async {
  if (!directory.existsSync()) return;
  final entries = directory.listSync();
  for (final entry in entries) {
    try {
      if (entry is io.Directory) {
        await entry.delete(recursive: true);
      } else if (entry is io.File) {
        await entry.delete();
      } else if (entry is io.Link) {
        await entry.delete();
      }
    } on io.FileSystemException {
      // Ignore cleanup errors, will retry on teardown all.
    }
  }
}

({String file, int? line, String name}) _currentTestInfo() {
  final invoker = Invoker.current;
  final liveTest = invoker?.liveTest;
  final testName = liveTest?.individualName ?? liveTest?.test.name ?? 'unknown';
  final rawPath = liveTest?.suite.path ?? 'unknown_suite';
  final suitePath = rawPath.startsWith('file:') ? Uri.parse(rawPath).toFilePath() : rawPath;
  final line = liveTest?.test.trace?.frames.first.line ?? liveTest?.test.trace?.frames.first.column;
  return (file: suitePath, line: line, name: testName);
}

String _snapshotFilePath(({String file, int? line, String name}) testInfo) {
  const suffix = '.dart';
  if (!testInfo.file.endsWith(suffix)) {
    throw StateError(
      "Test file path does not end with expected suffix '$suffix': ${testInfo.file}",
    );
  }

  final testFileName = testInfo.file.split(io.Platform.pathSeparator).last;
  var basename = testFileName.substring(
    0,
    testFileName.length - suffix.length,
  );

  // Remove '_test' suffix to match TypeScript snapshot directory naming
  // TypeScript uses: permissions.test.ts -> snapshots/permissions/
  // Dart uses: permissions_test.dart -> should match snapshots/permissions/
  if (basename.endsWith('_test')) {
    basename = basename.substring(0, basename.length - 5);
  }

  final taskName = testInfo.name.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '_');
  return _snapshotsDir.uri.resolve('$basename/$taskName.yaml').toFilePath();
}
