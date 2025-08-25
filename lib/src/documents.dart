import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:hive/hive.dart';

import "my.i18n.dart";
import 'utils.dart';

/// Common FormGroup utilities for Document, HiveTable, and HiveMap
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

/// uses a hive box to store key values Fields integrated with reactive_forms
/// and provider
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

/// A document is composed by an header and some rows. The header and each row
/// can be edited with a reactive_forms formGroup.
/// The class contains methods to manipulate data ahd to notify changes to
/// provider.
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

/// handle a list of rows within a Document or stand alone.
///
/// rows are stored in a list of maps. Each row contain the fields defined
/// in a FormGroup and are present all methods to handle the rows. If the
/// list belongs to a Document, changes are notified to listeners.
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
      text ??= 'Confirm delete?'.i18n;
      if (!await alertBox(
        context,
        text: text,
        buttons: ['No'.i18n, 'Yes'.i18n],
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

/// add persistence to a Document using a hiveBox.
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
  String? campo = getFirstErrorField(formGroup);
  String testo = campo != null 
      ? "Error in field '\$campo'".i18n.replaceAll('\$campo', campo)
      : "Check entered data!".i18n;
  
  await alertBox(
    context,
    text: testo,
  );
}

/// the default submit button used with reactive_forms
///
ReactiveButton submitButton({text = 'Ok', onOk, onError}) {
  var rb = ReactiveButton();
  rb.text = text;
  rb.onOk = onOk;
  rb.onError = onError;
  return rb;
}

/// a ReactiveButton is a button that validate a reactive_forms form and pop it.
class ReactiveButton extends StatelessWidget {
  ReactiveButton({super.key});
  String text = "Send";
  Function? onOk;
  Function? onError;
  @override
  Widget build(BuildContext context) {
    final form = ReactiveForm.of(context);
    void valid() async {
      if (form != null && form.valid) {
        if (onOk != null) await onOk!();
        Navigator.pop(context);
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
