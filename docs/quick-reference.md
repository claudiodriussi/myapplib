# myapplib Quick Reference

Quick reference guide for **myapplib**, a Flutter package library providing reusable utilities and components for building business applications.

---

## Project Overview

**myapplib** is a Flutter package library (NOT an app) providing utilities for building business applications. It is used as a dependency by other Flutter apps.

**Core Technologies:**
- Reactive Forms (reactive_forms package)
- Data Persistence (Hive + SQLite)
- Cross-platform support (Mobile + Desktop)

---

## Core Components

- **AppVars** (`lib/src/appvars.dart`) - Global singleton for app state
- **Document** (`lib/src/documents.dart`) - Base class for form documents (header/rows pattern)
- **RestClient** (`lib/src/restclient.dart`) - HTTP client with token auth
- **SqlDB** (`lib/src/sqldb.dart`) - SQLite wrapper (mobile/desktop/web) with SearchForm/SearchQuery
- **ReactiveLookupField** (`lib/src/lookupfield.dart`) - Custom lookup widget
- **Utilities** (`lib/src/utils.dart`, `lib/src/dateutils.dart`) - Helper functions
- **i18n** (`lib/i18n/`) - Internal Slang translations (en/it)

---

## Key Patterns

1. **Global Singleton**: Use `app` (AppVars instance) for global state
2. **Field Shortcuts**: `H(name)` for Document headers, `R(name)` for ListRows
3. **Hidden Fields**: Fields starting with `_` excluded from JSON/map serialization
4. **Zero Dependencies**: Apps must declare all myapplib dependencies explicitly

---

## Common Tasks

### Initialize an app using myapplib

```dart
import 'package:myapplib/myapplib.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.start();  // Auto-init locale + Hive + dirs
  runApp(MyApp());
}
```

### Create a Document subclass

```dart
class InvoiceDocument extends Document {
  InvoiceDocument() {
    fgHeader = FormGroup({
      'id': FormControl<int>(),
      'customer': FormControl<String>(),
    });

    FormGroup fgRow = FormGroup({
      'item': FormControl<String>(),
      'qty': FormControl<double>(),
    });
    addDocRows(fgRow);
  }
}
```

### Force locale via command line

```bash
flutter run --dart-define=LOCALE=en  # English
flutter run --dart-define=LOCALE=it  # Italian
```

---

## MCP Server

A Model Context Protocol server is available in `mcp_server/` to provide centralized context for AI coding assistants across multiple projects.

### What is the MCP Server?

The MCP server provides:
- **Centralized documentation**: All myapplib docs accessible via resources
- **Reduced token usage**: 85-95% savings compared to reading files directly
- **Consistent context**: Same info across all projects using myapplib
- **Specialized tools**: Generate Document templates, check dependencies, explain patterns

### Setup

1. **Install dependencies:**
   ```bash
   cd mcp_server
   uv venv
   source .venv/bin/activate
   uv pip install -r requirements.txt
   ```

2. **Configure your AI assistant** (Claude Code, Cursor, Zed, etc.)

   See `mcp_server/README.md` for detailed configuration instructions.

3. **Restart your AI assistant**

### How to Use

Your AI assistant automatically uses MCP resources when working with myapplib. Just ask questions naturally:
- "How do I initialize myapplib?"
- "Create an OrderDocument with fields x, y, z"
- "Explain the Document pattern"

### Available Resources

- `myapplib://quick-reference` - This file
- `myapplib://docs/README.md` - Complete documentation
- `myapplib://source/appvars` - AppVars source code
- `myapplib://source/documents` - Document source code
- `myapplib://source/restclient` - RestClient source code
- `myapplib://source/sqldb` - SqlDB source code

### Available Tools

- `generate_document_template` - Generate Document subclass code
- `check_dependencies` - Verify pubspec.yaml has required dependencies
- `explain_pattern` - Get detailed explanation of myapplib patterns

---

## Documentation

**Complete documentation:** [docs/README.md](README.md)

The documentation covers:
- Architecture and design patterns
- Key components (AppVars, Document, RestClient, SqlDB, etc.)
- Reactive forms pattern
- Dependencies and zero-dependency design
- Getting started guide
- Conventions and best practices

---

## Development Notes

- **No Tests**: Testing happens in consumer apps, not in the library itself
- **No Examples**: Usage patterns documented in code comments and docs
- **Platform Handling**: RestClient and SqlDB auto-detect mobile vs desktop
- **Code Generation**: Run `dart run slang` to regenerate translations
- **State Management**: Document and HiveMap extend ChangeNotifier

---

## Recent Changes

- **Slang migration**: Replaced i18n_extension with Slang (type-safe, no context required)
- **String aliasing**: Internal strings use `ml.t.*` alias to avoid app conflicts
- **`--dart-define=LOCALE`**: `app.start()` reads locale from command line or device
- **Removed hivetables.dart**: Obsolete class removed
- **Standardized terminology**: All English nomenclature

---

## Links

- **Repository**: [GitHub](https://github.com/your-username/myapplib)
- **Issues**: [GitHub Issues](https://github.com/your-username/myapplib/issues)
- **Complete Docs**: [docs/README.md](README.md)
- **MCP Server**: [mcp_server/README.md](../mcp_server/README.md)
