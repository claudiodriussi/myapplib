#!/usr/bin/env python3
"""
MCP Server for myapplib Flutter Library

Provides centralized context, documentation and tools for working with myapplib
across multiple Flutter projects.
"""

from pathlib import Path
from typing import Any, Sequence

from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Resource, Tool, TextContent, Prompt, PromptMessage


# Get myapplib root directory (parent of mcp_server)
MYAPPLIB_ROOT = Path(__file__).parent.parent


app = Server("myapplib-server")


# ============================================================================
# RESOURCES - Expose documentation and context
# ============================================================================

@app.list_resources()
async def list_resources() -> list[Resource]:
    """List all available resources."""
    return [
        Resource(
            uri="myapplib://quick-reference",
            name="Quick Reference",
            mimeType="text/markdown",
            description="Quick reference guide with common patterns, setup, and MCP usage"
        ),
        Resource(
            uri="myapplib://docs/README.md",
            name="Complete Documentation",
            mimeType="text/markdown",
            description="Full documentation: architecture, components, patterns, getting started, conventions"
        ),
        Resource(
            uri="myapplib://source/appvars",
            name="AppVars Source Code",
            mimeType="text/plain",
            description="Source: lib/src/appvars.dart - Global singleton for app state"
        ),
        Resource(
            uri="myapplib://source/documents",
            name="Document Source Code",
            mimeType="text/plain",
            description="Source: lib/src/documents.dart - Base class for form documents"
        ),
        Resource(
            uri="myapplib://source/restclient",
            name="RestClient Source Code",
            mimeType="text/plain",
            description="Source: lib/src/restclient.dart - HTTP client with token auth"
        ),
        Resource(
            uri="myapplib://source/sqldb",
            name="SqlDB Source Code",
            mimeType="text/plain",
            description="Source: lib/src/sqldb.dart - SQLite wrapper (mobile + desktop)"
        ),
    ]


@app.read_resource()
async def read_resource(uri: str) -> str:
    """Read a specific resource by URI."""

    # Map URIs to file paths
    file_map = {
        "myapplib://quick-reference": MYAPPLIB_ROOT / "docs" / "quick-reference.md",
        "myapplib://docs/README.md": MYAPPLIB_ROOT / "docs" / "README.md",
        "myapplib://source/appvars": MYAPPLIB_ROOT / "lib" / "src" / "appvars.dart",
        "myapplib://source/documents": MYAPPLIB_ROOT / "lib" / "src" / "documents.dart",
        "myapplib://source/restclient": MYAPPLIB_ROOT / "lib" / "src" / "restclient.dart",
        "myapplib://source/sqldb": MYAPPLIB_ROOT / "lib" / "src" / "sqldb.dart",
    }

    file_path = file_map.get(uri)
    if not file_path:
        raise ValueError(f"Unknown resource URI: {uri}")

    if not file_path.exists():
        return f"File not found: {file_path}"

    return file_path.read_text(encoding="utf-8")


# ============================================================================
# TOOLS - Provide utilities for working with myapplib
# ============================================================================

@app.list_tools()
async def list_tools() -> list[Tool]:
    """List all available tools."""
    return [
        Tool(
            name="generate_document_template",
            description="Generate a Document subclass template with specified header and row fields",
            inputSchema={
                "type": "object",
                "properties": {
                    "class_name": {
                        "type": "string",
                        "description": "Name for the Document subclass (e.g. InvoiceDocument)"
                    },
                    "header_fields": {
                        "type": "array",
                        "description": "Header field definitions as [name, type] pairs",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string"},
                                "type": {"type": "string", "enum": ["String", "int", "double", "bool", "DateTime"]}
                            },
                            "required": ["name", "type"]
                        }
                    },
                    "row_fields": {
                        "type": "array",
                        "description": "Row field definitions as [name, type] pairs",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string"},
                                "type": {"type": "string", "enum": ["String", "int", "double", "bool", "DateTime"]}
                            },
                            "required": ["name", "type"]
                        }
                    }
                },
                "required": ["class_name", "header_fields"]
            }
        ),
        Tool(
            name="check_dependencies",
            description="Check if a pubspec.yaml file contains all required myapplib dependencies",
            inputSchema={
                "type": "object",
                "properties": {
                    "pubspec_path": {
                        "type": "string",
                        "description": "Path to pubspec.yaml file to check"
                    }
                },
                "required": ["pubspec_path"]
            }
        ),
        Tool(
            name="explain_pattern",
            description="Explain a specific myapplib pattern or component",
            inputSchema={
                "type": "object",
                "properties": {
                    "topic": {
                        "type": "string",
                        "enum": [
                            "Document",
                            "FormGroup",
                            "ListRows",
                            "AppVars",
                            "RestClient",
                            "SqlDB",
                            "ReactiveLookupField",
                            "FormsMixin",
                            "Initialization",
                            "Internationalization"
                        ],
                        "description": "The pattern or component to explain"
                    }
                },
                "required": ["topic"]
            }
        ),
    ]


@app.call_tool()
async def call_tool(name: str, arguments: Any) -> Sequence[TextContent]:
    """Execute a tool."""

    if name == "generate_document_template":
        class_name = arguments["class_name"]
        header_fields = arguments["header_fields"]
        row_fields = arguments.get("row_fields", [])

        # Generate header FormGroup
        header_controls = []
        for field in header_fields:
            field_name = field["name"]
            field_type = field["type"]
            header_controls.append(f"      '{field_name}': FormControl<{field_type}>()")

        # Generate row FormGroup if specified
        row_code = ""
        if row_fields:
            row_controls = []
            for field in row_fields:
                field_name = field["name"]
                field_type = field["type"]
                row_controls.append(f"      '{field_name}': FormControl<{field_type}>()")

            row_code = f"""
    // Define row structure
    FormGroup fgRow = FormGroup({{
{','.join(row_controls)}
    }});
    addDocRows(fgRow);  // Creates ListRows with key 'rows'
"""

        template = f"""import 'package:myapplib/myapplib.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// {class_name} - Document class for ...
class {class_name} extends Document {{
  {class_name}() {{
    // Define header fields
    fgHeader = FormGroup({{
{','.join(header_controls)}
    }});
{row_code}  }}

  // Convenience getters for type-safe access
{chr(10).join(f"  {field['type']}? get {field['name']} => H('{field['name']}').value;" for field in header_fields)}
{chr(10).join(f"  set {field['name']}({field['type']}? value) => H('{field['name']}').value = value;"
              for field in header_fields)}
}}
"""

        return [TextContent(type="text", text=template)]

    elif name == "check_dependencies":
        pubspec_path = Path(arguments["pubspec_path"])

        if not pubspec_path.exists():
            return [TextContent(type="text", text=f"Error: {pubspec_path} not found")]

        required_deps = {
            "reactive_forms": "^17.0.0",
            "hive": "^2.2.3",
            "hive_flutter": "^1.1.0",
            "sqflite": "^2.3.0",
            "sqflite_common_ffi": "^2.3.0",
            "http": "^1.1.0",
            "path_provider": "^2.1.1",
            "path": "^1.8.3",
            "device_info_plus": "^9.1.0",
            "intl": "^0.18.0",
            "slang": "^3.32.0",
            "slang_flutter": "^3.32.0",
        }

        pubspec_content = pubspec_path.read_text(encoding="utf-8")

        missing = []
        present = []

        for dep, version in required_deps.items():
            if dep in pubspec_content:
                present.append(f"✓ {dep}")
            else:
                missing.append(f"✗ {dep}: {version}")

        result = "## Dependency Check Results\n\n"

        if present:
            result += "### Present:\n" + "\n".join(present) + "\n\n"

        if missing:
            result += "### Missing:\n" + "\n".join(missing) + "\n\n"
            result += "Add these to your dependencies section in pubspec.yaml:\n```yaml\n"
            for dep in missing:
                dep_name = dep.split(":")[0].replace("✗ ", "")
                result += f"  {dep_name}: {required_deps[dep_name.strip()]}\n"
            result += "```\n"
        else:
            result += "✓ All required dependencies are present!\n"

        return [TextContent(type="text", text=result)]

    elif name == "explain_pattern":
        topic = arguments["topic"]

        explanations = {
            "Document": """
# Document Pattern

Document is the base class for form-based documents with header/rows pattern.

## Key Features
- fgHeader: FormGroup for header fields
- docRows: Map of ListRows objects (typically 'rows' key)
- H(name): Shortcut to access header FormControl
- rows(): Shortcut to access default ListRows
- modified: Tracks if document has been modified
- editOk: Validation state

## Example
```dart
class InvoiceDocument extends Document {
  InvoiceDocument() {
    fgHeader = FormGroup({
      'id': FormControl<int>(),
      'customer': FormControl<String>(),
      'date': FormControl<DateTime>(),
    });

    FormGroup fgRow = FormGroup({
      'item': FormControl<String>(),
      'qty': FormControl<double>(),
      'price': FormControl<double>(),
    });
    addDocRows(fgRow);
  }
}

// Usage
var invoice = InvoiceDocument();
invoice.H('customer').value = 'ACME Corp';
invoice.rows().newRow();
invoice.rows().R('item').value = 'Widget';
```
""",
            "FormGroup": """
# FormGroup Pattern

FormGroup is from reactive_forms package and represents a collection of FormControls.

## Structure
```dart
FormGroup({
  'fieldName': FormControl<Type>(value: initialValue),
  ...
});
```

## Access
```dart
// Get control
var control = formGroup.control('fieldName');

// Get/set value
var value = control.value;
control.value = newValue;

// Validation
if (formGroup.valid) { ... }
```

## In myapplib
- Document uses FormGroup for fgHeader
- ListRows stores FormGroups for each row
- FormsMixin provides utilities for FormGroup operations
""",
            "ListRows": """
# ListRows Pattern

ListRows manages a list of FormGroup objects representing table rows.

## Features
- newRow(): Add new row from template
- delRow(index): Delete row at index
- R(name): Shortcut to access current row's FormControl
- current: Currently selected row index
- rowsCount: Number of rows
- toJson() / fromJson(): Serialization

## Example
```dart
// In Document subclass
FormGroup fgRow = FormGroup({
  'item': FormControl<String>(),
  'qty': FormControl<double>(),
});
addDocRows(fgRow);  // Creates ListRows with key 'rows'

// Usage
doc.rows().newRow();  // Add first row
doc.rows().R('item').value = 'Widget';  // Current row
doc.rows().R('qty').value = 5.0;

doc.rows().newRow();  // Add second row
doc.rows().current = 0;  // Switch to first row
doc.rows().delRow(1);  // Delete second row
```
""",
            "AppVars": """
# AppVars Singleton

Global application state manager.

## Usage
```dart
import 'package:myapplib/myapplib.dart';

// Access singleton (already created)
final app = AppVars();  // or just use 'app' directly

// Initialize (call once in main)
await app.start();
```

## Features
- Platform-specific directories (docsDir, tempDir, extDir)
- Hive box management via addBox(name)
- Settings persistence in 'settings' box
- Device info via setDeviceInfo()
- Locale initialization (reads --dart-define=LOCALE)
- Platform detection: isDesktop(), isMobile()

## Important
- Call app.start() before runApp()
- First addBox() initializes Hive
- Settings auto-persisted in Hive 'settings' box
""",
            "RestClient": """
# RestClient

HTTP client for REST API integration with myapplib.

## Setup
```dart
var client = RestClient(
  serverAddress: 'https://api.example.com',
  urlPrefix: '/api/v1',  // optional
);

// Authenticate
await client.authenticate(username, password);
```

## Features
- Token-based auth (/api/v1/token endpoint)
- upload(doc, endpoint): Send Document as JSON
- download(endpoint): Receive data and populate Document
- Automatic DateTime serialization
- SqlDB integration for batch operations

## Custom Converters
```dart
client.setDocumentConverter((doc) => customToJson(doc));
client.setFilenameGenerator((doc) => 'file_${doc.id}.json');
```
""",
            "SqlDB": """
# SqlDB

Cross-platform SQLite wrapper supporting mobile and desktop.

## Setup
```dart
var db = SqlDB();
await db.open('mydb.db', fromAsset: 'assets/mydb.db');
```

## CRUD Operations
```dart
// Find single
var row = await db.find('customers', where: 'id = ?', whereArgs: [42]);

// Find all
var rows = await db.findAll('customers', where: 'city = ?', whereArgs: ['Rome']);

// Insert
await db.insert('customers', {'name': 'ACME', 'city': 'Rome'});

// Update
await db.update('customers', {'city': 'Milan'}, where: 'id = ?', whereArgs: [42]);

// Delete
await db.delete('customers', where: 'id = ?', whereArgs: [42]);
```

## reactive_forms Integration
```dart
// Generate empty FormGroup from table structure
var fg = await db.toFormGroup('customers');

// Convert FormGroup to map
var data = db.fromFormGroup(fg);
await db.insert('customers', data);
```
""",
            "ReactiveLookupField": """
# ReactiveLookupField

Custom reactive form widget combining lookup button and optional manual editing.

## Features
- Async decoder function to show readable descriptions
- Built-in caching to avoid repeated decoder calls
- onFocus, onFocusLost, onEditingComplete callbacks
- Shows format: "value - description"

## Example
```dart
ReactiveLookupField(
  formControlName: 'customerId',
  decoration: InputDecoration(labelText: 'Customer'),
  decoder: (value) async {
    // Fetch customer name from database
    var customer = await db.find('customers', where: 'id = ?', whereArgs: [value]);
    return customer?['name'] ?? 'Unknown';
  },
  onLookup: () async {
    // Show lookup dialog
    var selected = await showCustomerLookup(context);
    return selected?.id;
  },
  separator: ' - ',  // "123 - ACME Corp"
)
```
""",
            "FormsMixin": """
# FormsMixin

Mixin providing utilities for FormGroup operations.

## Methods

### assignValue(formGroup, name, value)
Assigns value to FormControl with automatic String→DateTime conversion.

### toJsonVar(formControl)
Serializes FormControl value (DateTime→ISO string).

### resetFormGroup(formGroup, {exclude})
Resets FormGroup, optionally excluding specific fields.

### cloneFormGroupEmpty(formGroup)
Creates empty clone for search forms.

### toMapExcludeHidden(formGroup)
Converts to Map excluding fields starting with '_'.

### fromMapExcludeHidden(formGroup, map)
Populates FormGroup from Map excluding hidden fields.

## Used By
- Document class
- FilterDocument class
""",
            "Initialization": """
# App Initialization

Complete guide at myapplib://docs/initialization

## Quick Start
```dart
import 'package:myapplib/myapplib.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.start();  // Initializes everything
  runApp(MyApp());
}
```

## What app.start() Does
1. Initializes platform-specific directories
2. Reads --dart-define=LOCALE or uses device locale
3. Sets up LocaleSettings for myapplib strings
4. Prepares Hive (first addBox() call actually initializes it)

## Force Locale
```bash
flutter run --dart-define=LOCALE=en
flutter run --dart-define=LOCALE=it
```
""",
            "Internationalization": """
# Internationalization (i18n)

myapplib uses Slang for type-safe translations.

## Internal Strings (myapplib)
- Stored in lib/i18n/strings.i18n.json
- Generated code in lib/i18n/strings.g.dart
- Imported with alias: `import '../i18n/strings.g.dart' as ml;`
- Used internally: `ml.t.cancel`, `ml.t.ok`, `ml.t.confirmDelete`
- NOT exposed to apps

## Exported Classes
Apps can import to sync locale:
```dart
import 'package:myapplib/myapplib.dart';

// Sync app locale with myapplib
LocaleSettings.setLocale(AppLocale.it);
```

## App's Own Strings
Apps can have separate Slang system:
```dart
// App's strings (no conflict)
import 'i18n/strings.g.dart';

Text(t.welcome)  // App strings
// myapplib internally uses ml.t.cancel
```

## Supported Languages
- English (base)
- Italian

## Generate Translations
```bash
cd myapplib
dart run slang
```
"""
        }

        explanation = explanations.get(topic, f"No explanation available for topic: {topic}")
        return [TextContent(type="text", text=explanation)]

    else:
        raise ValueError(f"Unknown tool: {name}")


# ============================================================================
# PROMPTS - Reusable prompt templates
# ============================================================================

@app.list_prompts()
async def list_prompts() -> list[Prompt]:
    """List all available prompts."""
    return [
        Prompt(
            name="create_document_class",
            description="Generate a complete Document subclass with header and row fields",
            arguments=[
                {"name": "class_name", "description": "Name for the Document class", "required": True},
                {"name": "header_fields", "description": "Comma-separated header fields (name:type)", "required": True},
                {"name": "row_fields", "description": "Comma-separated row fields (name:type)", "required": False},
            ]
        ),
        Prompt(
            name="setup_new_app",
            description="Generate initialization code and dependencies for a new app using myapplib",
            arguments=[
                {"name": "app_name", "description": "Name of the Flutter app", "required": True},
                {"name": "use_own_strings", "description": "Whether app has its own Slang strings (yes/no)",
                 "required": False},
            ]
        ),
    ]


@app.get_prompt()
async def get_prompt(name: str, arguments: dict[str, str] | None) -> Prompt:
    """Get a specific prompt with arguments."""

    if name == "create_document_class":
        class_name = arguments.get("class_name", "MyDocument")
        header_fields_str = arguments.get("header_fields", "")
        row_fields_str = arguments.get("row_fields", "")

        prompt_text = f"""Create a Document subclass named {class_name} for myapplib.

Class name: {class_name}
Header fields: {header_fields_str}
Row fields: {row_fields_str}

Use the generate_document_template tool to create the code template.
Ensure:
1. Proper imports (myapplib/myapplib.dart, reactive_forms)
2. Header FormGroup with specified fields
3. Row FormGroup if row_fields specified
4. Type-safe getters/setters for header fields
5. Proper formatting and documentation
"""

        return Prompt(
            name=name,
            description="Generate Document subclass",
            arguments=[],
            messages=[
                PromptMessage(
                    role="user",
                    content=TextContent(type="text", text=prompt_text)
                )
            ]
        )

    elif name == "setup_new_app":
        app_name = arguments.get("app_name", "my_app")
        use_own_strings = arguments.get("use_own_strings", "no").lower() == "yes"

        prompt_text = f"""Set up a new Flutter app named {app_name} to use myapplib.

Generate:
1. Required dependencies section for pubspec.yaml (use check_dependencies tool)
2. main.dart initialization code
3. MaterialApp setup with localization
{"4. Slang setup for app's own strings" if use_own_strings else ""}

App name: {app_name}
Own Slang strings: {"Yes" if use_own_strings else "No"}

Refer to myapplib://docs/initialization for complete setup guide.
"""

        return Prompt(
            name=name,
            description="Setup new Flutter app with myapplib",
            arguments=[],
            messages=[
                PromptMessage(
                    role="user",
                    content=TextContent(type="text", text=prompt_text)
                )
            ]
        )

    else:
        raise ValueError(f"Unknown prompt: {name}")


# ============================================================================
# MAIN - Server entry point
# ============================================================================

async def main():
    """Run the MCP server."""
    async with stdio_server() as (read_stream, write_stream):
        await app.run(
            read_stream,
            write_stream,
            app.create_initialization_options()
        )


if __name__ == "__main__":
    import asyncio
    asyncio.run(main())
