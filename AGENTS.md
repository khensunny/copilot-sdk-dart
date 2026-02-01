# AGENTS.md

## Build & Test Commands
Run all commands from `copilot_sdk/` directory using `fvm`:

### Dependencies
- **Get dependencies**: `dart pub get`

### Unit Tests (fast, no external deps)
- **Run all unit tests**: `dart test test/src/`
- **Run single unit test file**: `dart test test/src/<file>_test.dart`

### E2E Tests (requires CLI setup)
E2E tests are tagged with `@Tags(['e2e'])` and require the Copilot CLI to be available.

**Prerequisites:**
1. Install TypeScript harness dependencies:
   ```bash
   cd reference/copilot-sdk-ts/nodejs && npm install
   cd reference/copilot-sdk-ts/test && npm install
   ```
2. Ensure Copilot CLI is available at `/opt/homebrew/bin/copilot` or set `COPILOT_CLI_PATH`

**Run E2E tests:**
- **Run all E2E tests**: `dart test test/e2e/`
- **Run E2E tests with tag**: `dart test --tags e2e`
- **Exclude E2E tests**: `dart test --exclude-tags e2e`
- **Run specific E2E file**: `dart test test/e2e/client_test.dart`

**Note:** Permission tests require CI environment with `COPILOT_HMAC_KEY` for authentication.

### All Tests
- **Run all tests**: `dart test`
- **Run with verbose output**: `dart test --chain-stack-traces`

### Code Quality
- **Analyze/lint**: `dart analyze`
- **Format code**: `dart format --line-length=120 .`
- **Build runner (code gen)**: `dart run build_runner build --delete-conflicting-outputs`

## Architecture
- **copilot_sdk/** - Main Dart package (SDK for GitHub Copilot CLI via JSON-RPC)
  - `lib/src/copilot/` - CopilotClient, CopilotSession, configs
  - `lib/src/jsonrpc/` - JSON-RPC 2.0 protocol client
  - `lib/src/transports/` - Stdio and TCP transports
  - `lib/src/models/generated/` - Freezed models from schema
- **reference/** - TypeScript SDK reference implementation

## Code Style
- Uses **very_good_analysis** for strict linting
- Package imports: `package:copilot_sdk/src/...`
- Prefer relative imports within same directory
- Document public APIs with `///` comments template docs to avoid duplication in class and default constructor
- Use sealed classes for event hierarchies (pattern matching)
