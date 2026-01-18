import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:hive/hive.dart';

import 'utils.dart';
import '../i18n/strings.g.dart' as ml;

// =============================================================================
// DOCUMENT SYSTEM - Flexible Form-based Data Management
// =============================================================================
//
// This library provides a complete document management system with reactive
// forms integration and flexible persistence options.
//
// ## Core Components
//
// ### Document
// Manages structured data with header/detail pattern (invoices, orders, reports).
// - Header: single FormGroup for main document fields
// - Details: one or more ListRows for detail lines
// - Supports complex multi-section documents (e.g., invoice with items + payments)
//
// ### ListRows
// Manages lists of rows, usable standalone or within a Document.
// - Each row follows a FormGroup schema
// - Built-in filtering support via callback
// - Can be used independently for simple lists
//
// ### HiveMap
// Simple key-value storage with FormGroup integration for settings/preferences.
// - Direct Hive box binding
// - Automatic load/save
// - Useful for app settings and configuration
//
// ### FormsMixin
// Shared utilities for type conversion, JSON handling, and FormGroup operations.
// Used by all classes above for consistent behavior.
//
// ## Hidden Fields Pattern
//
// Fields starting with "_" (underscore) are excluded from persistence.
// Useful for UI-only fields that shouldn't be saved:
//
// ```dart
// FormGroup({
//   'name': FormControl<String>(),        // saved
//   '_displayName': FormControl<String>(), // NOT saved (UI helper)
// })
// ```
//
// ## Quick Examples
//
// ### Simple Document (Note/Memo)
// ```dart
// class Note extends Document with Document2Hive {
//   Note() {
//     fgHeader = FormGroup({
//       'title': FormControl<String>(),
//       'content': FormControl<String>(),
//       'date': FormControl<DateTime>(),
//     });
//     setBox(app.hiveBoxes['notes']);
//   }
// }
//
// // Usage
// Note note = Note();
// await note.reset();
// note.H('title').value = 'My Note';
// note.H('date').value = DateTime.now();
// await note.save();
// ```
//
// ### Document with Detail Rows (Invoice)
// ```dart
// class Invoice extends Document with Document2Hive {
//   Invoice() {
//     fgHeader = FormGroup({
//       'customer': FormControl<String>(),
//       'date': FormControl<DateTime>(),
//       'total': FormControl<double>(),
//     });
//
//     // Add detail rows schema
//     addDocRows(FormGroup({
//       'item': FormControl<String>(),
//       'qty': FormControl<int>(),
//       'price': FormControl<double>(),
//     }));
//
//     setBox(app.hiveBoxes['invoices']);
//   }
// }
//
// // Usage
// Invoice inv = Invoice();
// await inv.reset();
// inv.H('customer').value = 'ACME Corp';
// inv.H('date').value = DateTime.now();
//
// // Add detail rows
// inv.rows().addRow(data: {'item': 'Widget', 'qty': 10, 'price': 5.0});
// inv.rows().addRow(data: {'item': 'Gadget', 'qty': 5, 'price': 12.0});
//
// await inv.save();
// ```
//
// ### Settings with HiveMap
// ```dart
// HiveMap settings = HiveMap(
//   app.hiveBoxes['settings'],
//   FormGroup({
//     'theme': FormControl<String>(value: 'light'),
//     'language': FormControl<String>(value: 'en'),
//     'fontSize': FormControl<int>(value: 14),
//   })
// );
//
// // Load from storage
// await settings.load();
//
// // Update single value
// await settings.update('theme', 'dark');
//
// // Access value
// String theme = settings.get('theme');
// ```
//
// ### Standalone List (Simple TODO list)
// ```dart
// ListRows todos = ListRows(FormGroup({
//   'task': FormControl<String>(),
//   'done': FormControl<bool>(value: false),
// }));
//
// todos.addRow(data: {'task': 'Buy milk', 'done': false});
// todos.addRow(data: {'task': 'Call John', 'done': true});
//
// // Filter completed tasks
// todos.setFilter((row) => row['done'] == true);
// print('Completed: ${todos.displayCount}');
// ```
//
// ## Document Lifecycle
//
// 1. **Create/Reset**: `await doc.reset()` - clears all data
// 2. **Edit Header**: `await doc.editHeader(editFn: () => Navigator.push(...))`
// 3. **Edit Rows**: `await doc.rows().editRow(numRow: 0, editFn: ...)`
// 4. **Save**: `await doc.save()` (with Document2Hive mixin)
// 5. **Load**: `await doc.load(key)` (with Document2Hive mixin)
//
// =============================================================================

/// Common FormGroup utilities for Document and HiveMap
/// Provides consistent handling of FormGroup operations, type conversions, and JSON serialization
mixin FormsMixin on ChangeNotifier {

  /// Assign a value to a ReactiveForm control with automatic type conversion.
  /// Handles String to DateTime conversion for JSON imports
  void assignValue(FormControl control, dynamic value) {
    try {
      if (control is FormControl<DateTime> && value is String) {
        control.value = DateTime.parse(value);
      } else {
        control.value = value;
      }
    } catch (_) {
      // Keep default/current value on conversion error - more robust than setting null
    }
  }

  /// Prepare a value to be encoded in JSON.
  /// DateTime converted to ISO String, others handled appropriately
  dynamic toJsonVar(dynamic value) {
    if (value is String || value is num || value == null) return value;
    if (value is DateTime) return value.toIso8601String();
    try {
      return value.toJson();
    } catch (e) {
      return value.toString();
    }
  }

  /// Reset FormGroup with optional field exclusions and automatic change notification
  Future<void> resetFormGroup(FormGroup formGroup, {List<String>? exceptFields}) async {
    formGroupReset(formGroup, exceptFields: exceptFields);
    notifyListeners();
  }

  /// Clone FormGroup with empty values for search forms
  /// Useful for creating search forms from existing data schemas
  FormGroup cloneFormGroupEmpty(FormGroup source) {
    final Map<String, AbstractControl> controls = {};
    source.controls.forEach((key, control) {
      if (control is FormControl<String>) {
        controls[key] = FormControl<String>();
      } else if (control is FormControl<int>) {
        controls[key] = FormControl<int>();
      } else if (control is FormControl<double>) {
        controls[key] = FormControl<double>();
      } else if (control is FormControl<DateTime>) {
        controls[key] = FormControl<DateTime>();
      } else {
        controls[key] = FormControl();
      }
    });
    return FormGroup(controls);
  }

  /// Convert FormGroup to Map excluding hidden fields (fields starting with "_")
  Map<String, dynamic> toMapExcludeHidden(FormGroup formGroup) {
    final Map<String, dynamic> result = {};
    for (String key in formGroup.controls.keys) {
      if (key.startsWith('_')) continue;
      result[key] = toJsonVar(formGroup.control(key).value);
    }
    return result;
  }

  /// Load Map values into FormGroup, excluding hidden fields
  void fromMapExcludeHidden(FormGroup formGroup, Map<String, dynamic> data) {
    for (String key in formGroup.controls.keys) {
      if (key.startsWith('_')) continue;
      if (data.containsKey(key)) {
        assignValue(formGroup.control(key) as FormControl, data[key]);
      }
    }
  }
}

/// Simple key-value storage with reactive forms integration
///
/// HiveMap provides persistent storage for app settings, preferences, or any
/// simple key-value data that needs to be bound to UI forms.
///
/// ## Features
/// - Direct Hive box binding for persistence
/// - Automatic FormGroup integration
/// - Individual field updates with `update()`
/// - Batch operations with `load()` and `save()`
/// - Hidden fields support (fields starting with "_")
///
/// ## Usage Example
/// ```dart
/// // Create settings storage
/// HiveMap settings = HiveMap(
///   app.hiveBoxes['settings'],
///   FormGroup({
///     'theme': FormControl<String>(value: 'light'),
///     'notifications': FormControl<bool>(value: true),
///     'fontSize': FormControl<int>(value: 14),
///   })
/// );
///
/// // Load persisted values
/// await settings.load();
///
/// // Read value
/// String theme = settings.get('theme');
///
/// // Update single value (saves immediately)
/// await settings.update('theme', 'dark');
///
/// // Bulk update
/// settings.set('theme', 'dark');
/// settings.set('fontSize', 16);
/// await settings.save(); // Save all changes at once
/// ```
///
/// ## Integration with reactive_forms
/// ```dart
/// // Use in UI with ReactiveForm
/// ReactiveTextField<String>(
///   formControlName: 'theme',
/// )
/// ```
///
class HiveMap with ChangeNotifier, FormsMixin {
  final Box? box;
  FormGroup fgMap = FormGroup({});

  HiveMap(this.box, this.fgMap) {
    load();
  }

  Future<void> reset({List<String>? exceptFields}) async {
    await resetFormGroup(fgMap, exceptFields: exceptFields);
    // notifyListeners() already called by resetFormGroup
  }

  /// the fields key starting with "_" are not loaded
  Future<void> load() async {
    await resetFormGroup(fgMap); // Use MixIn method
    for (String key in fgMap.controls.keys) {
      if (key.startsWith('_')) continue;
      try {
        fgMap.control(key).value = box!.get(key);
      } catch (_) {}
    }
    // Additional notifyListeners() in case values changed after resetFormGroup
    notifyListeners();
  }

  /// the fields key starting with "_" are not saved
  Future<void> save() async {
    for (String key in fgMap.controls.keys) {
      if (key.startsWith('_')) continue;
      box!.put(key, fgMap.control(key).value);
    }
    notifyListeners();
  }

  dynamic get(key) => fgMap.control(key).value;

  void set(key, value) => fgMap.control(key).value = value;

  /// short code for fgMap.control
  AbstractControl<dynamic> F(key) => fgMap.control(key);

  /// update a single value
  Future<void> update(key, value) async {
    set(key, value);
    box!.put(key, fgMap.control(key).value);
    notifyListeners();
  }
}

/// Structured document with header/detail pattern
///
/// Document manages complex structured data like invoices, orders, reports,
/// or any data with a header section and one or more detail sections (rows).
///
/// ## Architecture
/// - **Header**: Single FormGroup for document-level fields (date, customer, total, etc.)
/// - **Detail Rows**: Zero or more ListRows collections for detail lines
/// - **Multiple Sections**: Supports documents with multiple row types (e.g., invoice items + payments)
///
/// ## Key Features
/// - Automatic dirty tracking (`isModified`, `hasAnyChanges`)
/// - Edit callbacks for header and rows with validation
/// - JSON serialization/deserialization
/// - Hidden fields support (fields starting with "_")
/// - Optional persistence via Document2Hive mixin
///
/// ## Basic Usage
/// ```dart
/// // Define your document
/// class Invoice extends Document with Document2Hive {
///   Invoice() {
///     // Define header schema
///     fgHeader = FormGroup({
///       'invoiceNumber': FormControl<String>(),
///       'date': FormControl<DateTime>(),
///       'customer': FormControl<String>(),
///       'total': FormControl<double>(),
///     });
///
///     // Define detail rows schema
///     addDocRows(FormGroup({
///       'item': FormControl<String>(),
///       'quantity': FormControl<int>(),
///       'price': FormControl<double>(),
///     }));
///
///     setBox(app.hiveBoxes['invoices']);
///   }
/// }
///
/// // Use the document
/// Invoice invoice = Invoice();
/// await invoice.reset(); // Clear data
///
/// // Set header fields
/// invoice.H('invoiceNumber').value = 'INV-001';
/// invoice.H('date').value = DateTime.now();
/// invoice.H('customer').value = 'ACME Corp';
///
/// // Add detail rows
/// invoice.rows().addRow(data: {
///   'item': 'Widget',
///   'quantity': 10,
///   'price': 25.0
/// });
///
/// // Save document
/// invoice.key = 'INV-001';
/// await invoice.save();
///
/// // Load document
/// await invoice.load('INV-001');
/// ```
///
/// ## Advanced: Multiple Row Types
/// ```dart
/// class ComplexDoc extends Document with Document2Hive {
///   ComplexDoc() {
///     fgHeader = FormGroup({...});
///
///     // Multiple detail sections
///     addDocRows(FormGroup({...}), key: 'items');
///     addDocRows(FormGroup({...}), key: 'payments');
///     addDocRows(FormGroup({...}), key: 'notes');
///   }
/// }
///
/// // Access specific row collection
/// doc.rows(key: 'items').addRow(...);
/// doc.rows(key: 'payments').addRow(...);
/// ```
///
/// ## Edit Pattern with UI
/// ```dart
/// // Edit header with validation
/// await invoice.editHeader(
///   editFn: () async {
///     await Navigator.push(context,
///       MaterialPageRoute(builder: (_) => EditInvoiceScreen())
///     );
///     // If user cancels, set invoice.editOk = false
///   }
/// );
///
/// // Edit specific row
/// await invoice.rows().editRow(
///   numRow: 0, // Edit first row
///   editFn: () async {
///     await Navigator.push(context,
///       MaterialPageRoute(builder: (_) => EditRowScreen())
///     );
///   }
/// );
/// ```
///
class Document with ChangeNotifier, FormsMixin {
  dynamic key; // document key (null = new document)
  bool modified = false; // the document was modified, should be saved
  bool editOk = true; // the form is validated, must be false before editing
  Map<String, ListRows> docRows = {}; // zero or more ListRows can be handled

  FormGroup fgHeader = FormGroup({}); // all field of the header

  /// short code for fgHeader.control
  AbstractControl<dynamic> H(name) => fgHeader.control(name);

  /// add a list to docRows map. The default key of the list is "rows" and
  /// often a single list of rows is enough.
  ///
  void addDocRows(fgRow, {key = 'rows'}) {
    docRows[key] = ListRows(fgRow, document: this);
  }

  /// convenient function to get a ListRows.
  ///
  ListRows rows({key = 'rows'}) => docRows[key]!;

  /// check if the document was modified.
  /// return true if the header or a row in each ListRows defined id docRows
  /// are modified
  ///
  bool get isModified {
    if (!modified) {
      modified = docRows.values.any((row) => row.modified);
    }
    return modified;
  }

  /// check if document has any changes including form fields
  /// return true if header form is dirty, document is modified, or any rows are modified
  ///
  bool get hasAnyChanges {
    // Check if form fields have been modified (dirty)
    if (!fgHeader.pristine) return true;

    // Check document modified flag and rows
    return isModified;
  }

  /// call the editFn to modify the header.
  ///
  Future<void> editHeader({required editFn}) async {
    editOk = true;
    await editFn();
    if (editOk) {
      modified = true;
      notifyListeners();
    }
  }

  /// reset documento to empty
  ///
  Future<void> reset({List<String>? exceptFields}) async {
    formGroupReset(fgHeader, exceptFields: exceptFields);
    docRows.forEach((k, v) => v.reset());
    key = null;
    modified = false;
    notifyListeners();
  }

  /// this is an abstract method, derived classes can handle initializations
  /// before adding a new document. The context parameter can be used to
  /// interact with user, i.e. using un AlertBox
  Future<bool> newDocument(context) async {
    return true;
  }

  Future<void> save() async {
    // derived classes handle persistence
  }

  Future<void> load(key) async {
    // derived classes handle persistence
  }

  /// return a Map with the values of self.
  ///
  /// the fields names that begin with "_" are hidden and are excluded form
  /// Map. Are used when we need fields on the form that don't need to be saved
  /// on document.
  ///
  Map<String, dynamic> toMap() {
    // hidden fields exclusion from the header
    Map<String, dynamic> head = {};
    for (String key in fgHeader.controls.keys) {
      if (key.startsWith('_')) continue;
      head[key] = fgHeader.control(key).value;
    }

    var m = {
      "class": runtimeType.toString(),
      "key": key,
      "header": head,
    };

    // add all row lists to the map
    docRows.forEach((k, v) {
      m[k] = v.toMap();
    });

    return m;
  }

  /// Restore the Document from a map.
  ///
  void fromMap(value) {
    reset();
    if (value != null && value['class'] == runtimeType.toString()) {
      key = value['key'];
      try {
        // Use FormsMixin assignValue for consistent type conversion
        value['header'].forEach((k, v) => assignValue(fgHeader.control(k) as FormControl, v));
      } catch (_) {}

      // add all row lists to the map
      docRows.forEach((k, v) {
        if (value.containsKey(k)) {
          v.fromMap(value[k]);
        }
      });
    }
  }

  /// restore a document from a json file and return the intermediate map
  ///
  Map fromJson(s) {
    Map m = jsonDecode(s);
    fromMap(m);
    return m;
  }

  /// transform all not serializable variables in string and the call the
  /// function jsonEncode
  ///
  String toJson({data}) {
    data ??= toMap();

    data['key'] = toJsonVar(data['key']);
    data['header'].forEach((k, v) => data['header'][k] = toJsonVar(v));

    // convert all values in list to the format serializable in json
    docRows.forEach((k, v) {
      for (var row in data[k]) {
        row.forEach((kk, v) => row[kk] = toJsonVar(v));
      }
    });

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  void notify() => notifyListeners();
}

/// Manages a list of rows within a Document or standalone
///
/// ListRows provides a flexible way to manage collections of structured data.
/// Each row follows a schema defined by a FormGroup. Can be used as part of
/// a Document (for detail lines) or independently for simple lists.
///
/// ## Features
/// - Schema-based rows via FormGroup
/// - Add, edit, remove operations
/// - Built-in filtering with `setFilter()`
/// - Display vs actual rows (`displayRows` vs `rows`)
/// - Optional Document integration for change notifications
///
/// ## Standalone Usage
/// ```dart
/// // Create a simple task list
/// ListRows tasks = ListRows(FormGroup({
///   'title': FormControl<String>(),
///   'done': FormControl<bool>(value: false),
///   'priority': FormControl<int>(value: 0),
/// }));
///
/// // Add rows
/// tasks.addRow(data: {'title': 'Buy groceries', 'priority': 1});
/// tasks.addRow(data: {'title': 'Call client', 'priority': 2});
///
/// // Access rows
/// print('Total tasks: ${tasks.rows.length}');
/// for (var task in tasks.rows) {
///   print('${task['title']} - Priority: ${task['priority']}');
/// }
/// ```
///
/// ## Filtering
/// ```dart
/// // Show only incomplete tasks
/// tasks.setFilter((row) => row['done'] == false);
/// print('Incomplete tasks: ${tasks.displayCount}'); // Uses filter
/// print('Total tasks: ${tasks.rows.length}');       // All rows
///
/// // Access filtered rows
/// for (var task in tasks.displayRows) {
///   // Only shows rows matching filter
/// }
///
/// // Clear filter
/// tasks.clearFilter();
/// ```
///
/// ## Editing Rows
/// ```dart
/// // Edit existing row
/// await tasks.editRow(
///   numRow: 0, // Edit first row
///   editFn: () async {
///     // Show edit form
///     await showDialog(...);
///     // Form values are automatically saved if editOk remains true
///   }
/// );
///
/// // Add new row (numRow: -1 or >= length)
/// await tasks.editRow(
///   numRow: -1,
///   editFn: () async {
///     // Show add form
///   }
/// );
/// ```
///
/// ## Integration with Document
/// ```dart
/// class Invoice extends Document {
///   Invoice() {
///     addDocRows(FormGroup({
///       'item': FormControl<String>(),
///       'qty': FormControl<int>(),
///     }));
///   }
/// }
///
/// Invoice inv = Invoice();
/// inv.rows().addRow(data: {'item': 'Widget', 'qty': 5});
/// // Changes automatically notify Document listeners
/// ```
///
/// ## Helper Methods
/// ```dart
/// // Get specific row by field value
/// Map item = tasks.getFirst('title', 'Buy groceries');
///
/// // Generate dropdown menu items
/// List<DropdownMenuItem> items = tasks.menuItems('id', 'title');
///
/// // Remove row with confirmation
/// await tasks.removeRow(0, context: context, text: 'Delete this task?');
/// ```
///
class ListRows {
  List rows = []; // document rows
  bool modified = false; // the document was modified, should be saved
  bool editOk = true; // the form is validated, must be false before editing
  int curRow = -1; // current row, -1 for new rows
  FormGroup fgRow = FormGroup({}); // all fields of each row
  Document? doc; // if the row belong to a document, we can notify listeners.

  /// Filter callback for displaying a subset of rows
  bool Function(Map<String, dynamic> row)? _filterCallback;

  /// Get rows for display - uses filter if set, otherwise returns all rows
  List get displayRows => _filterCallback == null
    ? rows
    : rows.where((row) => _filterCallback!(row)).toList();

  /// Get count of rows for display
  int get displayCount => displayRows.length;

  /// initialize a ListRows. The document parameter is optional, this mean
  /// that the rows can belong to a Document, or used stand alone.
  ///
  ListRows(this.fgRow, {document}) {
    doc = document;
  }

  /// check if a row is new
  bool get isNewRow => curRow < 0 || curRow >= rows.length;

  /// short code for fgRow.control
  AbstractControl<dynamic> R(name) => fgRow.control(name);

  /// reset the list
  void reset() {
    rows = [];
    modified = false;
    editOk = true;
    curRow = -1;
    _filterCallback = null; // Clear any filter
  }

  /// Set filter callback for displaying subset of rows
  /// The callback should return true for rows to display
  void setFilter(bool Function(Map<String, dynamic> row)? filter) {
    _filterCallback = filter;
    if (doc != null) doc!.notify(); // Notify Document to refresh UI
  }

  /// Clear current filter - show all rows
  void clearFilter() {
    setFilter(null);
  }

  /// return the list of rows with the exclusion of hidden fields
  ///
  /// the fields names that begin with "_" are hidden and are excluded form
  /// Map. Are used when we need fields on the form that don't need to be saved.
  ///
  List toMap() {
    List rm = [];
    for (var item in rows) {
      var x = {};
      for (String key in item.keys) {
        if (key.startsWith('_')) continue;
        x[key] = item[key];
      }
      rm.add(x);
    }
    return rm;
  }

  /// restore rows from a list of maps.
  ///
  /// ToDo: value must be checked for DateTime fields and hidden fields
  ///
  void fromMap(value) {
    value.forEach((val) {
      Map<String, Object?> m = {};
      val.forEach((k, v) => m[k] = v);
      rows.add(m);
    });
  }

  /// edit the given row, or add a new row.
  ///
  Future<void> editRow(
      {required int numRow,
      required editFn,
      List<String>? exceptFields}) async {
    editOk = true;
    curRow = numRow;

    if (isNewRow) {
      formGroupReset(fgRow, exceptFields: exceptFields);
    } else {
      fgRow.value = rows[numRow];
    }
    await editFn();
    if (editOk) {
      var row = fgRow.rawValue;
      if (isNewRow) {
        rows.add(row);
      } else {
        rows[numRow] = row;
      }
      modified = true;
    }
    if (doc != null) doc?.notify();
  }

  /// prepare an empty Map in the row format
  ///
  Map emptyRow() {
    formGroupReset(fgRow);
    return fgRow.rawValue;
  }

  /// find the first row where the field id [id] is equal to the passed key
  /// [key]. If not found return an empty row.
  ///
  Map<String, dynamic> getFirst(String id, String key) {
    for (var item in rows) {
      if (item[id] == key) return item;
    }
    Map<String, dynamic> row = fgRow.rawValue;
    map2empty(row);
    return row;
  }

  /// Add an empty row in the format of rows
  ///
  void addRow({Map data = const {}, bool toEmpty = true}) {
    Map row = fgRow.rawValue;
    if (toEmpty) {
      map2empty(row);
    }
    data.forEach((k, v) => row[k] = v);
    rows.add(row);
  }

  /// ask for permission and remove a row
  ///
  Future<void> removeRow(int index, {context, text}) async {
    if (context != null) {
      text ??= ml.t.confirmDelete;
      if (!await alertBox(
        context,
        text: text,
        buttons: [ml.t.no, ml.t.yes],
      )) {
        return;
      }
    }
    rows.removeAt(index);
    modified = true;
    if (doc != null) doc?.notify();
  }

  /// prepare the items for a DropdownMenu
  ///
  /// All row in the list are used for the menu. As argument we have to pass
  /// the name of field used for value and the one used for the description
  ///
  List<DropdownMenuItem<String>> menuItems(String value, String description) {
    List<DropdownMenuItem<String>> ll = [];
    for (var i in rows) {
      ll.add(DropdownMenuItem(value: i[value], child: Text(i[description])));
    }
    return ll;
  }
}

/// Adds Hive-based persistence to Document
///
/// Document2Hive is a mixin that separates persistence logic from business logic.
/// The Document class focuses on data structure and manipulation, while this
/// mixin provides the storage implementation.
///
/// ## Design Pattern: Separation of Concerns
///
/// This separation allows:
/// - **Flexibility**: Easy to swap storage (Hive → SQLite → Cloud → etc.)
/// - **Testability**: Test Document logic without persistence
/// - **Clean architecture**: Document defines "what", mixin defines "where"
///
/// ## Usage
///
/// Simply add the mixin to your Document class:
/// ```dart
/// class Invoice extends Document with Document2Hive {
///   Invoice() {
///     fgHeader = FormGroup({
///       'number': FormControl<String>(),
///       'date': FormControl<DateTime>(),
///     });
///
///     // Specify which Hive box to use for persistence
///     setBox(app.hiveBoxes['invoices']);
///   }
/// }
/// ```
///
/// ## Persistence Operations
/// ```dart
/// Invoice inv = Invoice();
/// inv.key = 'INV-001';
/// inv.H('number').value = 'INV-001';
/// inv.H('date').value = DateTime.now();
///
/// // Save to Hive (async operation)
/// await inv.save();
///
/// // Load from Hive
/// await inv.load('INV-001');
/// ```
///
/// ## Storage Format
///
/// Documents are stored as Maps in Hive with this structure:
/// ```dart
/// {
///   "class": "Invoice",           // Document class name
///   "key": "INV-001",             // Document key
///   "header": {                   // Header fields
///     "number": "INV-001",
///     "date": "2024-01-15T10:30:00.000"
///   },
///   "rows": [                     // Detail rows (if any)
///     {"item": "Widget", "qty": 5},
///     {"item": "Gadget", "qty": 3}
///   ]
/// }
/// ```
///
/// ## Alternative Persistence
///
/// You can implement different persistence strategies by creating other mixins:
/// ```dart
/// // Example: SQLite persistence
/// mixin Document2SQLite on Document {
///   @override
///   Future<void> save() async {
///     // Store in SQLite
///   }
///
///   @override
///   Future<void> load(key) async {
///     // Load from SQLite
///   }
/// }
///
/// // Example: Cloud persistence
/// mixin Document2Firestore on Document {
///   @override
///   Future<void> save() async {
///     // Store in Firestore
///   }
///
///   @override
///   Future<void> load(key) async {
///     // Load from Firestore
///   }
/// }
/// ```
///
/// ## Benefits of this Pattern
///
/// 1. **Single Responsibility**: Document handles structure, mixin handles storage
/// 2. **Open/Closed Principle**: Extend storage without modifying Document
/// 3. **Dependency Inversion**: Document doesn't depend on specific storage
/// 4. **Reusability**: Same Document logic, different storage backends
///
mixin Document2Hive on Document {
  Box? _box;

  void setBox(box) => _box = box;

  /// the document is transformed in Map and then stored to the box indexed by
  /// the key.
  ///
  @override
  Future<void> save() async {
    _box?.put(key, toMap());
  }

  /// load the document form the hive box.
  @override
  Future<void> load(key) async {
    var value = _box?.get(key);
    fromMap(value);
  }
}

/// Returns the name of the first field with validation errors
/// Returns null if no errors found
String? getFirstErrorField(FormGroup formGroup) {
  for (var entry in formGroup.controls.entries) {
    if (entry.value.hasErrors) {
      return entry.key;
    }
  }
  return null;
}

/// Default error handler for form validation failures
/// Shows an alert with field-specific or generic error message
Future<void> defaultFormErrorHandler(BuildContext context, FormGroup formGroup) async {
  String? field = getFirstErrorField(formGroup);
  String message = field != null
      ? ml.t.errorInField(field: field)
      : ml.t.checkData;

  await alertBox(
    context,
    text: message,
  );
}

// ----------------------------------------------------------------------------
// REACTIVE FORMS HELPERS
// ----------------------------------------------------------------------------

/// Creates a submit button for reactive forms with automatic validation
///
/// Validates the form, executes onOk callback if valid, then pops navigation.
/// Shows error dialog if invalid (or executes custom onError callback).
///
/// ```dart
/// submitButton(
///   text: 'Save',
///   onOk: () async => await document.save(),
/// )
/// ```
///
ReactiveButton submitButton({text = 'Ok', onOk, onError, popOnSuccess = true}) {
  var rb = ReactiveButton();
  rb.text = text;
  rb.onOk = onOk;
  rb.onError = onError;
  rb.popOnSuccess = popOnSuccess;
  return rb;
}

/// Submit button widget for reactive_forms with validation and navigation
///
/// Finds parent ReactiveForm, validates on tap, executes callbacks based on
/// validation result. Automatically pops navigation on success (unless popOnSuccess=false).
///
/// Use `submitButton()` factory function instead of creating instances directly.
///
class ReactiveButton extends StatelessWidget {
  ReactiveButton({super.key});
  String text = "Send";
  Function? onOk;
  Function? onError;
  bool popOnSuccess = true;
  @override
  Widget build(BuildContext context) {
    final form = ReactiveForm.of(context);
    void valid() async {
      if (form != null && form.valid) {
        if (onOk != null) await onOk!();
        if (popOnSuccess) Navigator.pop(context);
      } else {
        // Form validation failed, execute error callback or use default
        if (onError != null) {
          await onError!();
        } else if (form != null && form is FormGroup) {
          await defaultFormErrorHandler(context, form as FormGroup);
        }
      }
    }
    return ElevatedButton(
      onPressed: valid,
      child: Text(text),
    );
  }
}

/// Async validator to check if a value exists in a SQL table
///
/// Usage:
/// ```dart
/// 'userId': FormControl<String>(
///   asyncValidators: [ValidateTableRecord('users', sqldb)],
/// )
/// ```
///
/// Returns validation error {'Not found': true} if record doesn't exist
class ValidateTableRecord extends AsyncValidator<dynamic> {
  String table = "";
  dynamic db;

  ValidateTableRecord(this.table, this.db);

  @override
  Future<Map<String, dynamic>?> validate(
    AbstractControl<dynamic> control,
  ) async {
    var error = {'Not found': true};
    try {
      var t = await db.find(table, control.value);
      if (t.isEmpty) return error;
    } catch (e) {
      return error;
    }
    return null;
  }
}

// ----------------------------------------------------------------------------
// REUSABLE FILTER SYSTEM
// ----------------------------------------------------------------------------

/// Abstract base class for document filtering and sorting
///
/// Provides a flexible filter system with various operators:
/// - Equality: field == value
/// - Not equal: field != value
/// - Range: value >= from && value <= to
/// - Contains: string contains substring (case insensitive)
/// - Date equal: all records of a specific date (ignores time)
///
/// And a sorting system with:
/// - Field-based sorting (addOrder)
/// - Custom sorting with callbacks (addCustomOrder)
/// - Ascending/descending toggle
/// - Automatic PopupMenu generation
///
/// Derived classes must:
/// 1. Initialize fgFiltri in the constructor
/// 2. Implement applyFilters() to read values and set filters
/// 3. Add sort orders with addOrder() or addCustomOrder()
///
abstract class FilterDocument with ChangeNotifier {
  final Map<String, dynamic> _filters = {};
  bool _isActive = true; // If false, filters are disabled (show all)
  late FormGroup fgFiltri; // FormGroup to be initialized in derived classes

  // Sorting system
  // Can contain List<String> (fields) or Function (custom callback)
  final Map<String, dynamic> _orders = {};
  String? _currentOrder; // Current order key
  bool _reverseOrder = false; // true = descending order

  bool get isActive => _isActive;

  // Sorting getters
  bool get isReversed => _reverseOrder;
  String? get currentOrderName => _currentOrder;
  List<String> get availableOrders => _orders.keys.toList();

  /// Abstract method to be implemented in derived classes
  /// Must read values from FormGroup and call appropriate set* methods
  void applyFilters();

  /// Toggle filters on/off
  void toggleActive() {
    _isActive = !_isActive;
    notifyListeners();
  }

  /// Reset FormGroup and filters to default values
  void resetFilters() {
    formGroupReset(fgFiltri);
    applyFilters();
  }

  /// Add field-based sorting
  /// The first order added becomes the default
  void addOrder(String name, List<String> fields) {
    _orders[name] = fields;
    _currentOrder ??= name; // first added is default
  }

  /// Add custom sorting with comparison function
  /// The function receives two Map (record headers) and returns int (-1, 0, 1)
  void addCustomOrder(String name, int Function(Map, Map) compareFn) {
    _orders[name] = compareFn;
    _currentOrder ??= name;
  }

  /// Set current sort order
  void setOrder(String name) {
    if (_orders.containsKey(name)) {
      _currentOrder = name;
      notifyListeners();
    }
  }

  /// Toggle current order (ascending/descending)
  void toggleReverse() {
    _reverseOrder = !_reverseOrder;
    notifyListeners();
  }

  /// Reset to default sort order (first added, not reversed)
  void resetOrder() {
    if (_orders.isNotEmpty) {
      _currentOrder = _orders.keys.first;
      _reverseOrder = false;
      notifyListeners();
    }
  }

  /// Sort a list of records according to current order
  /// Assumes each element has a 'header' map
  void sortRows(List<dynamic> rows) {
    if (_orders.isEmpty || _currentOrder == null) return;

    var orderDef = _orders[_currentOrder];

    rows.sort((a, b) {
      int cmp;

      if (orderDef is Function) {
        // Custom sorting with callback
        cmp = orderDef(a['header'], b['header']);
      } else if (orderDef is List<String>) {
        // Field-based sorting
        cmp = _compareByFields(a['header'], b['header'], orderDef);
      } else {
        return 0;
      }

      return _reverseOrder ? -cmp : cmp;
    });
  }

  /// Compare two records based on a list of fields
  int _compareByFields(Map a, Map b, List<String> fields) {
    for (String field in fields) {
      dynamic valA = a[field];
      dynamic valB = b[field];

      // Handle null values
      if (valA == null && valB == null) continue;
      if (valA == null) return 1;
      if (valB == null) return -1;

      // Compare
      int cmp = 0;
      if (valA is Comparable) {
        cmp = valA.compareTo(valB);
      } else {
        cmp = valA.toString().compareTo(valB.toString());
      }

      // If different, return
      if (cmp != 0) return cmp;
    }
    return 0;
  }

  /// Generate menu entries for sorting
  List<PopupMenuEntry<String>> buildOrderMenu() {
    List<PopupMenuEntry<String>> items = [];

    // Add all available sort orders
    for (String name in _orders.keys) {
      items.add(PopupMenuItem(
        value: name,
        child: Row(
          children: [
            if (_currentOrder == name) const Icon(Icons.check, size: 16),
            if (_currentOrder == name) const SizedBox(width: 8),
            Text(name),
          ],
        ),
      ));
    }

    // Divider
    items.add(const PopupMenuDivider());

    // Toggle ascending/descending
    items.add(PopupMenuItem(
      value: '__toggle__',
      child: Row(
        children: [
          Icon(
            _reverseOrder ? Icons.arrow_upward : Icons.arrow_downward,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(_reverseOrder ? 'Ascending' : 'Descending'),
        ],
      ),
    ));

    return items;
  }

  /// Handle selection from sort menu
  void handleOrderSelection(String value) {
    if (value == '__toggle__') {
      toggleReverse();
    } else {
      setOrder(value);
    }
  }

  /// Set equality filter
  void setEqual(String field, dynamic value) {
    if (value == null) {
      _filters.remove(field);
    } else {
      _filters[field] = {'type': 'equal', 'value': value};
    }
    notifyListeners();
  }

  /// Set not-equal filter
  void setNotEqual(String field, dynamic value) {
    if (value == null) {
      _filters.remove(field);
    } else {
      _filters[field] = {'type': 'notEqual', 'value': value};
    }
    notifyListeners();
  }

  /// Set range filter (from/to)
  void setRange(String field, {dynamic from, dynamic to}) {
    if (from == null && to == null) {
      _filters.remove(field);
    } else {
      _filters[field] = {'type': 'range', 'from': from, 'to': to};
    }
    notifyListeners();
  }

  /// Set contains filter (case insensitive)
  void setContains(String field, String? value) {
    if (value == null || value.isEmpty) {
      _filters.remove(field);
    } else {
      _filters[field] = {'type': 'contains', 'value': value.toUpperCase()};
    }
    notifyListeners();
  }

  /// Set date equality filter (ignores time)
  void setDateEqual(String field, DateTime? date) {
    if (date == null) {
      _filters.remove(field);
    } else {
      _filters[field] = {
        'type': 'dateEqual',
        'value': DateTime(date.year, date.month, date.day)
      };
    }
    notifyListeners();
  }

  /// Check if a record passes all filters
  bool check(Map record) {
    // If filters disabled, pass everything
    if (!_isActive) return true;

    // If no filters set, pass everything
    if (_filters.isEmpty) return true;

    // Check each filter
    for (var entry in _filters.entries) {
      String field = entry.key;
      Map filterDef = entry.value;
      String type = filterDef['type'];

      dynamic fieldValue = record[field];

      switch (type) {
        case 'equal':
          if (fieldValue != filterDef['value']) return false;
          break;

        case 'notEqual':
          if (fieldValue == filterDef['value']) return false;
          break;

        case 'range':
          dynamic from = filterDef['from'];
          dynamic to = filterDef['to'];
          if (from != null && fieldValue < from) return false;
          if (to != null && fieldValue > to) return false;
          break;

        case 'contains':
          if (fieldValue == null) return false;
          String strValue = fieldValue.toString().toUpperCase();
          if (!strValue.contains(filterDef['value'])) return false;
          break;

        case 'dateEqual':
          if (fieldValue == null) return false;
          if (fieldValue is! DateTime) return false;
          DateTime checkDate = DateTime(
            fieldValue.year,
            fieldValue.month,
            fieldValue.day,
          );
          if (checkDate != filterDef['value']) return false;
          break;

        default:
          return false;
      }
    }

    return true;
  }

  /// Return the number of active filters
  int get count => _filters.length;

  /// Check if a specific field is filtered
  bool hasFilter(String field) => _filters.containsKey(field);
}
