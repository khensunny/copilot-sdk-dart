# AGENTS.md

## Build & Test Commands
Run all commands from `copilot_sdk/` directory using `fvm`:
- **Get dependencies**: `dart pub get`
- **Run all tests**: `dart test`
- **Run single test**: `dart test test/src/<file>_test.dart`
- **Analyze/lint**: `dart analyze`
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
