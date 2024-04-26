import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:hive/hive.dart';

import "my.i18n.dart";
import 'utils.dart';

/// uses a hive box to store key values Fields integrated with reactive_forms
/// and provider
///
class HiveMap with ChangeNotifier {
  final Box? box;
  FormGroup fgMap = FormGroup({});

  HiveMap(this.box, this.fgMap) {
    load();
  }

  Future<void> reset({List<String>? exceptFields}) async {
    formGroupReset(fgMap, exceptFields: exceptFields);
    notifyListeners();
  }

  /// the fields key starting with "_" are not loaded
  Future<void> load() async {
    formGroupReset(fgMap);
    for (String key in fgMap.controls.keys) {
      if (key.startsWith('_')) continue;
      try {
        fgMap.control(key).value = box!.get(key);
      } catch (_) {}
    }
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
class Document with ChangeNotifier {
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
    // rows = [];
    docRows.forEach((k, v) => v.reset());
    key = null;
    modified = false;
    notifyListeners();
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
        // if the assignment fail, I will try to convert a string in DateTime
        // and reassign to the control.
        value['header'].forEach((k, v) => _assignValue(fgHeader.control(k), v));
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

    data['key'] = _toJsonVar(data['key']);
    data['header'].forEach((k, v) => data['header'][k] = _toJsonVar(v));

    // convert all values in list to the format serializable in json
    docRows.forEach((k, v) {
      for (var row in data[k]) {
        row.forEach((kk, v) => row[kk] = _toJsonVar(v));
      }
    });

    return jsonEncode(data);
  }

  void notify() => notifyListeners();
}

/// prepare a value to be encoded in json.
///
/// data types different from String, num and null are converted to string.
/// often used to convert DataTime values
///
dynamic _toJsonVar(value) {
  if (value is String || value is num || value == null) return value;
  return value.toString();
}

/// assign a value to a ReactiveForm control.
///
/// data are usually coming from a Map and should be of the correct type.
/// if data are coming from a json string, dates are represented as String
/// and then we try to decode it.
///
void _assignValue(control, value) {
  try {
    if (control is FormControl<DateTime> && value is String) {
      control.value = DateTime.parse(value);
    } else {
      control.value = value;
    }
  } catch (_) {
    control.value = null;
  }
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
  /// TODO: value must be checked for DateTime fields and hidden fields
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

/// the default submit button used with reactive_forms
///
ReactiveButton submitButton({text = 'Ok', onOk}) {
  var rb = ReactiveButton();
  rb.text = text;
  rb.onOk = onOk;
  return rb;
}

/// a ReactiveButton is a button that validate a reactive_forms form and pop it.
// ignore: must_be_immutable
class ReactiveButton extends StatelessWidget {
  ReactiveButton({super.key});
  String text = "Send";
  Function? onOk;
  @override
  Widget build(BuildContext context) {
    final form = ReactiveForm.of(context);
    void valid() async {
      if (form != null && form.valid) {
        if (onOk != null) await onOk!();
        Navigator.pop(context);
      }
    }

    return ElevatedButton(
      onPressed: valid,
      child: Text(text),
    );
  }
}
