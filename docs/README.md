# myapplib Documentation

Complete documentation for **myapplib**, a Flutter package library providing reusable utilities and components for building business applications.

## Table of Contents

- [Overview](#overview)
- [Core Architecture](#core-architecture)
- [Key Components](#key-components)
- [Reactive Forms Pattern](#reactive-forms-pattern)
- [Dependencies](#dependencies)
- [Getting Started](#getting-started)
- [Conventions](#conventions)

---

## Overview

**myapplib** is a Flutter package library (NOT an app) that provides a complete stack for building business applications using reactive forms and data persistence.

### What is myapplib?

- **Type**: Flutter package library (not an executable app)
- **Purpose**: Reusable utilities for CRUD operations in business apps
- **Core Technologies**: reactive_forms + Hive + SQLite
- **Platform Support**: Mobile (Android/iOS) and Desktop (Linux/macOS/Windows)
- **Distribution**: `publish_to: 'none'` (used as path dependency)

### Project Structure

```
myapplib/
├── lib/
│   ├── src/
│   │   ├── appvars.dart           # Global app state singleton
│   │   ├── documents.dart         # Document base class (header/rows pattern)
│   │   ├── restclient.dart        # REST API client with auth
│   │   ├── sqldb.dart             # SQLite wrapper (mobile + desktop)
│   │   ├── lookupfield.dart       # ReactiveLookupField widget
│   │   ├── utils.dart             # Utilities (forms, I/O, conversions)
│   │   └── dateutils.dart         # DateTime utilities
│   ├── i18n/                      # Internal Slang translations (en/it)
│   └── myapplib.dart              # Main export file
├── docs/                          # Documentation
├── mcp_server/                    # MCP server for Claude Code
└── pubspec.yaml
```

---

## Core Architecture

myapplib is built around three pillars:

1. **Reactive Forms**: All data classes use the `reactive_forms` package for form management and validation
2. **Data Persistence**: Dual storage with Hive (NoSQL key-value) and SQLite (relational)
3. **Zero-Dependency Design**: No runtime dependencies declared to avoid version conflicts (see [Dependencies](#dependencies))

### Design Philosophy

- **Form-Centric**: Everything revolves around FormGroups and FormControls
- **Document Pattern**: Header/rows pattern for business documents (invoices, orders, etc.)
- **Platform-Agnostic**: Single codebase works on mobile and desktop
- **Type-Safe**: Strong typing with proper generics throughout

---

## Key Components

### 1. AppVars (`lib/src/appvars.dart`)

Global singleton managing application state and initialization.

```dart
import 'package:myapplib/myapplib.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.start();  // Initialize everything
  runApp(MyApp());
}
```

**Features:**
- Singleton instance: `final AppVars app = AppVars()`
- Platform-specific directories (`docsDir`, `tempDir`, `extDir`)
- Hive box lifecycle management via `addBox(name)`
- Settings persistence in Hive 'settings' box
- Automatic locale initialization (reads `--dart-define=LOCALE` or uses device locale)
- Device info via `setDeviceInfo()`
- Platform detection: `isDesktop()`, `isMobile()`

**Important:**
- Call `app.start()` before `runApp()`
- First `addBox()` call initializes Hive in `${app.extDir}/hive`
- Use the singleton `app`, never create new AppVars instances

### 2. Document (`lib/src/documents.dart`)

Base class for form-based documents with header/rows pattern.

```dart
class InvoiceDocument extends Document {
  InvoiceDocument() {
    // Define header fields
    fgHeader = FormGroup({
      'id': FormControl<int>(),
      'customer': FormControl<String>(),
      'date': FormControl<DateTime>(),
    });

    // Define row structure
    FormGroup fgRow = FormGroup({
      'item': FormControl<String>(),
      'qty': FormControl<double>(),
      'price': FormControl<double>(),
    });
    addDocRows(fgRow);  // Creates ListRows with key 'rows'
  }
}

// Usage
var doc = InvoiceDocument();
doc.H('customer').value = 'ACME Corp';
doc.rows().newRow();
doc.rows().R('item').value = 'Widget';
```

**Features:**
- `fgHeader`: FormGroup for header fields
- `docRows`: Map of ListRows objects (typically 'rows' key)
- `H(name)`: Shortcut to access header FormControl
- `rows()`: Shortcut to access default ListRows
- `modified`: Tracks document changes
- `editOk`: Validation state
- JSON serialization with automatic DateTime handling
- Extends `ChangeNotifier` for reactive updates
- Includes `FormsMixin` for utility methods

### 3. RestClient (`lib/src/restclient.dart`)

HTTP client for REST API integration with token-based authentication.

```dart
var client = RestClient(
  serverAddress: 'https://api.example.com',
  urlPrefix: '/api/v1',
);

await client.authenticate(username, password);
await client.upload(document, '/orders');
var data = await client.download('/orders/123');
```

**Features:**
- Token-based auth via `/api/v1/token` endpoint
- `upload(doc, endpoint)`: Send Document as JSON
- `download(endpoint)`: Fetch data and populate Document
- Automatic DateTime serialization
- SqlDB integration for batch operations
- Customizable via `setFilenameGenerator()` and `setDocumentConverter()`

### 4. SqlDB (`lib/src/sqldb.dart`)

Cross-platform SQLite wrapper supporting mobile and desktop.

```dart
var db = SqlDB();
await db.open('mydb.db', fromAsset: 'assets/mydb.db');

// CRUD operations
var customer = await db.find('customers', where: 'id = ?', whereArgs: [42]);
var customers = await db.findAll('customers', where: 'city = ?', whereArgs: ['Rome']);
await db.insert('customers', {'name': 'ACME', 'city': 'Rome'});
await db.update('customers', {'city': 'Milan'}, where: 'id = ?', whereArgs: [42]);
await db.delete('customers', where: 'id = ?', whereArgs: [42]);

// reactive_forms integration
var fg = await db.toFormGroup('customers');  // Generate FormGroup from table
var data = db.fromFormGroup(fg);             // Convert FormGroup to map
```

**Features:**
- Automatic platform detection (sqflite vs sqflite_ffi)
- Database initialization from assets
- CRUD operations: `find()`, `findAll()`, `insert()`, `update()`, `delete()`
- `toEmpty(table)`: Generate empty row templates via PRAGMA introspection
- `toFormGroup()` / `fromFormGroup()`: reactive_forms integration

### 5. ReactiveLookupField (`lib/src/lookupfield.dart`)

Custom reactive form widget combining lookup button and optional manual editing.

```dart
ReactiveLookupField(
  formControlName: 'customerId',
  decoration: InputDecoration(labelText: 'Customer'),
  decoder: (value) async {
    var customer = await db.find('customers', where: 'id = ?', whereArgs: [value]);
    return customer?['name'] ?? 'Unknown';
  },
  onLookup: () async {
    var selected = await showCustomerLookup(context);
    return selected?.id;
  },
  separator: ' - ',  // Shows: "123 - ACME Corp"
)
```

**Features:**
- Async decoder function with built-in caching
- Shows format: "value - description"
- Focus callbacks: `onFocus`, `onFocusLost`, `onEditingComplete`
- Optional manual editing

### 6. Utilities (`lib/src/utils.dart`)

Collection of utility functions.

**Type Conversions:**
- `toStr()`, `toInt()`, `toDbl()`, `toBool()`

**Form Utilities:**
- `inputDecoration()`: Standard input decoration
- `formGroupReset()`: Reset FormGroup
- `alertChoice()`: Show choice dialog
- `alertBox()`: Show alert dialog

**File I/O:**
- `loadTextFile()`, `saveTextFile()`, `readJson()`

**Math:**
- `round()`, `calcDiscount()`

**Platform Detection:**
- `isDesktop()`, `isMobile()`

### 7. Date Utilities (`lib/src/dateutils.dart`)

DateTime manipulation and comparison functions.

- `isSameDay()`, `isSameWeek()`, `isSameMonth()`, `isSameYear()`
- `calculateDecimalHours()`: Convert time spans to decimal hours

### 8. Internationalization (`lib/i18n/`)

**Slang-based** type-safe translations for internal library messages.

**Internal Usage:**
- Import with alias: `import '../i18n/strings.g.dart' as ml;`
- Access strings: `ml.t.cancel`, `ml.t.ok`, `ml.t.confirmDelete`
- Parametrized: `ml.t.errorInField(field: 'name')`
- Strings are **internal only** and not exposed to apps

**Exported Classes:**
- `LocaleSettings`: For apps to sync locale with myapplib
- `AppLocale`: Enum of supported locales (en, it)

**Supported Languages:**
- English (base)
- Italian

**Source Files:**
- `lib/i18n/strings.i18n.json` (English base)
- `lib/i18n/strings_it.i18n.json` (Italian)
- `lib/i18n/strings.g.dart` (generated code)

**Generate Translations:**
```bash
dart run slang
```

---

## Reactive Forms Pattern

All data classes in myapplib follow the `reactive_forms` pattern.

### FormGroup Structure

```dart
FormGroup fgHeader = FormGroup({
  'id': FormControl<int>(),
  'date': FormControl<DateTime>(),
  'description': FormControl<String>(),
});

// Access controls
fgHeader.control('id').value = 42;
```

### Document Pattern

The Document class provides shortcuts for cleaner code:

```dart
// Instead of: doc.fgHeader.control('customer').value = 'ACME';
doc.H('customer').value = 'ACME Corp';

// Instead of: doc.docRows['rows']!.formGroups[index].control('item').value = 'Widget';
doc.rows().R('item').value = 'Widget';
```

### FormsMixin Utilities

Document includes FormsMixin with utility methods:

- **`assignValue(fg, name, value)`**: Assign value with automatic String→DateTime conversion
- **`toJsonVar(control)`**: Serialize FormControl value (DateTime→ISO string)
- **`resetFormGroup(fg, {exclude})`**: Reset FormGroup with optional field exclusions
- **`cloneFormGroupEmpty(fg)`**: Create empty clone for search forms
- **`toMapExcludeHidden(fg)`**: Convert to Map excluding fields starting with `_`
- **`fromMapExcludeHidden(fg, map)`**: Populate from Map excluding hidden fields

### ListRows Pattern

ListRows manages collections of FormGroups (table rows).

```dart
// Add rows
doc.rows().newRow();
doc.rows().newRow();

// Access current row
doc.rows().R('item').value = 'Widget';
doc.rows().R('qty').value = 5.0;

// Navigate rows
doc.rows().current = 0;  // Switch to first row

// Delete row
doc.rows().delRow(1);

// Row count
int count = doc.rows().rowsCount;
```

---

## Dependencies

### Zero-Dependency Design Pattern

**myapplib does NOT declare runtime dependencies** in its `pubspec.yaml` to avoid version conflicts in consumer apps. Each app controls the exact package versions to use.

### Required Runtime Dependencies

Consumer apps **MUST** declare these dependencies:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  myapplib:
    path: ../myapplib  # or appropriate path

  # Required by myapplib
  reactive_forms: ^17.0.0
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  sqflite: ^2.3.0                    # mobile
  sqflite_common_ffi: ^2.3.0         # desktop
  http: ^1.1.0
  path_provider: ^2.1.1
  path: ^1.8.3
  device_info_plus: ^9.1.0
  intl: ^0.18.0
  slang: ^3.32.0
  slang_flutter: ^3.32.0
```

**Note:** Check pub.dev for latest compatible versions.

### Development Dependencies

Only myapplib declares these (not needed in consumer apps):

```yaml
dev_dependencies:
  build_runner: ^2.4.0
  slang_build_runner: ^3.32.0
```

---

## Getting Started

### Basic App Setup

**1. Add dependencies** to your app's `pubspec.yaml` (see [Dependencies](#dependencies))

**2. Initialize in `main()`:**

```dart
import 'package:myapplib/myapplib.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.start();  // Auto-initializes locale + Hive + directories
  runApp(MyApp());
}
```

**3. Run with locale control:**

```bash
flutter run                          # Use device locale
flutter run --dart-define=LOCALE=en  # Force English
flutter run --dart-define=LOCALE=it  # Force Italian
```

### App with Own Slang Strings

If your app has its own Slang translations:

```dart
import 'package:myapplib/myapplib.dart';
import 'i18n/strings.g.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.start();  // myapplib handles --dart-define=LOCALE

  // Optional: sync app locale with myapplib
  const String envLocale = String.fromEnvironment('LOCALE');
  if (envLocale.isNotEmpty) {
    if (envLocale == 'en') {
      LocaleSettings.setLocale(AppLocale.en);
    } else if (envLocale == 'it') {
      LocaleSettings.setLocale(AppLocale.it);
    }
  } else {
    LocaleSettings.useDeviceLocale();
  }

  runApp(TranslationProvider(child: MyApp()));
}
```

### MaterialApp Configuration

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'EN'),
        Locale('it', 'IT'),
      ],
      home: MyHomePage(),
    );
  }
}
```

### Adding App-Specific Strings

Apps can have their own Slang translation system (no conflicts with myapplib):

**1. Add dev dependencies:**
```yaml
dev_dependencies:
  build_runner: ^2.4.0
  slang_build_runner: ^3.32.0
```

**2. Create `lib/i18n/strings.i18n.json`:**
```json
{
  "welcome": "Welcome",
  "loginButton": "Login"
}
```

**3. Generate:**
```bash
dart run slang
```

**4. Use in app:**
```dart
import 'i18n/strings.g.dart';

Text(t.welcome)  // App strings
// myapplib internally uses ml.t.cancel (no conflict)
```

---

## Conventions

### Key Patterns

1. **Global Singleton**: Use `app` (AppVars instance) for global state, never create new AppVars instances

2. **Hive Initialization**: First `app.addBox()` call initializes Hive in `${app.extDir}/hive`

3. **Field Access Shortcuts**:
   - Document: `H(name)` for header fields
   - ListRows: `R(name)` for row fields

4. **Hidden Fields**: Fields starting with `_` are excluded from JSON serialization and map conversions

5. **Platform-Specific Code**: Check `app.isDesktop()` or `app.isMobile()` before platform-specific code

6. **DateTime Handling**: All DateTime values serialize to ISO8601 strings in JSON; automatic parsing on import

7. **Error Handling**: Methods use try/catch with sensible defaults instead of throwing exceptions

### State Management

- Document and HiveMap extend `ChangeNotifier`
- Use `modified` flag to track document changes
- Use `editOk` flag for validation state

### Code Generation

- Translations are auto-generated and committed to git as `strings.g.dart`
- Generate with `dart run slang` when modifying translation files

---

## Additional Resources

- **Source Code**: See `lib/src/` for implementation details
- **MCP Server**: See `mcp_server/` for Claude Code integration
- **Examples**: Test by importing myapplib in a Flutter app project

---

## Recent Changes

- **`--dart-define=LOCALE` support**: `app.start()` now reads `--dart-define=LOCALE=en|it` to force language
- **Slang migration**: Replaced i18n_extension with Slang for type-safe internationalization
- **String aliasing**: Import with alias `ml` to avoid conflicts with app strings
- **Removed hivetables.dart**: Obsolete class removed, replaced by Document + FilterDocument
- **Translation files**: JSON files in `lib/i18n/` for multilingual support (en/it)
- **Terminology**: Standardized English nomenclature throughout

---

## License

[Add license information]

## Contributing

[Add contribution guidelines]
