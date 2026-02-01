# E2E Tests for Copilot SDK

Integration tests that mirror the TypeScript reference implementation tests in `reference/copilot-sdk-ts/test/`.

## Overview

These tests use a **snapshot-based testing** approach:
- Real API calls are recorded once as YAML snapshots
- Subsequent test runs replay recorded responses (deterministic, offline, fast)
- Snapshots are shared with the TypeScript reference implementation

## Prerequisites

### 1. Install TypeScript Dependencies

The test harness uses a TypeScript-based HTTP proxy server. Install its dependencies:

```bash
# Install main SDK dependencies
cd reference/copilot-sdk-ts/nodejs
npm install

# Install test harness dependencies
cd reference/copilot-sdk-ts/test
npm install
```

### 2. Copilot CLI

The tests spawn the GitHub Copilot CLI. It should be available at:
- Environment variable: `COPILOT_CLI_PATH`
- Or at: `/opt/homebrew/bin/copilot` (macOS Homebrew)
- Or auto-downloaded from `reference/copilot-sdk-ts/nodejs/node_modules/@github/copilot/`

## Running Tests

### Run all E2E tests
```bash
cd copilot_sdk
fvm dart test test/e2e/
```

### Run specific test file
```bash
fvm dart test test/e2e/client_test.dart
fvm dart test test/e2e/session_test.dart
```

### Run specific test by name
```bash
fvm dart test test/e2e/client_test.dart -N "should start and connect"
```

### Run with verbose output
```bash
fvm dart test test/e2e/ --chain-stack-traces
```

## Test Files

| File | Description | Status |
|------|-------------|--------|
| `client_test.dart` | Client lifecycle (stdio/tcp), ping, status | ✅ Passing (6 tests) |
| `session_test.dart` | Session CRUD, resume, streaming, config | ✅ Passing (19 tests) |
| `tools_test.dart` | Built-in and custom tools | ✅ Passing (4 tests) |
| `hooks_test.dart` | Pre/post tool use hooks | ✅ Passing (4 tests) |
| `compaction_test.dart` | Session compaction | ✅ Passing (2 tests) |
| `skills_test.dart` | Skill loading | ✅ Passing (2 tests) |
| `ask_user_test.dart` | User input handling | ✅ Passing (3 tests) |
| `permissions_test.dart` | Permission handlers | ⚠️ Handler error (4 tests) |
| `mcp_and_agents_test.dart` | MCP servers & custom agents | ⚠️ Pending |

## Architecture

### Test Harness (`harness/`)

- **`sdk_test_context.dart`** - Test lifecycle management, temp directories, snapshot configuration
- **`capi_proxy.dart`** - Dart wrapper around TypeScript CapiProxy server
- **`sdk_test_helper.dart`** - Test utilities (getFinalAssistantMessage, retry, etc.)

### CapiProxy Server

A TypeScript-based HTTP proxy (from reference impl) that:
- Records API requests/responses
- Normalizes data (removes timestamps, sorts JSON, etc.)
- Replays stored snapshots on subsequent runs
- Provides deterministic, offline testing

## Snapshots

Snapshots are stored in YAML format at:
```
reference/copilot-sdk-ts/test/snapshots/
```

Each test has its own snapshot file (e.g., `session/should_list_sessions.yaml`).

### Adding New Tests

When adding a test that needs snapshots:
1. First run creates the snapshot (hits real API)
2. Subsequent runs use the snapshot (offline)
3. Snapshots are committed to git

## Known Issues

### Type Cast Errors - ✅ FIXED

**Status**: Fixed via post-processing in `tool/generate_session_events.dart`

The generated model code had type cast issues where it expected `double` but received `int` from JSON. This was caused by schema2dart generating `as double` casts for JSON Schema "number" types.

**Fix Applied**: Post-processing script now converts:
```dart
// Before:
final inputTokens = json['inputTokens'] as double?;  // ❌ Failed at runtime

// After:
final inputTokens = (json['inputTokens'] as num?)?.toDouble();  // ✅ Works
```

### Other Post-Processing Fixes

The generation script also handles:
1. **Reserved class names**: Renames `class Function` to `class Function$` (Dart reserved word)
2. **Import ordering**: Ensures `dart:` imports come before `package:` imports

### Permission Handler Error

`permissions_test.dart` has a "Bad state: Handler error" - this is a logic issue in the permission handler implementation, not a type generation issue.

## Model Selection

The tests use recorded snapshots and don't call AI models during runs. Model selection is irrelevant for testing - the snapshots contain pre-recorded responses.

To update snapshots with different models, modify the TypeScript test configuration and regenerate.

## Debugging

### Enable verbose logging
```bash
fvm dart test test/e2e/ --chain-stack-traces --verbose-trace
```

### Check CapiProxy server
```bash
# Run server manually to see output
cd reference/copilot-sdk-ts/nodejs
npx tsx ../test/harness/server.ts
```

### Common Issues

1. **"Bad state: No element"** - CapiProxy server failed to start
   - Check that npm dependencies are installed in both directories
   
2. **"Can't call tearDown()"** - Fixed by moving `registerSdkTestContext` to top level

3. **Timeout on TCP tests** - Check that CLI outputs port on stdout (not stderr)

## Contributing

When adding new E2E tests:
1. Follow existing patterns in test files
2. Use `createSdkTestContext()` and `registerSdkTestContext()` at top level of `main()`
3. Add snapshots to `reference/copilot-sdk-ts/test/snapshots/`
4. Run `dart analyze` to check for issues
