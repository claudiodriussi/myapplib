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
  List rows = []; // document rows
  dynamic key; // document key (null = new document)
  bool modified = false; // the document was modified, should be saved
  bool editOk = true; // the form is validated, must be false before editing
  int curRow = -1; // current row, -1 for new rows

  // check if a row is new
  bool get isNewRow => curRow < 0 || curRow >= rows.length;

  FormGroup fgHeader = FormGroup({}); // all field of the header
  FormGroup fgRow = FormGroup({}); // all fields of each row

  /// shortcode for fgHeader.control
  AbstractControl<dynamic> H(name) => fgHeader.control(name);

  /// shortcode for fgRow.control
  AbstractControl<dynamic> R(name) => fgRow.control(name);

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

  /// edi the give row, or add a new row.
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
      notifyListeners();
    }
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
        buttons: ['No', 'Yes'.i18n],
      )) {
        return;
      }
    }
    rows.removeAt(index);
    modified = true;
    notifyListeners();
  }

  /// reset documento to empty
  ///
  Future<void> reset({List<String>? exceptFields}) async {
    formGroupReset(fgHeader, exceptFields: exceptFields);
    rows = [];
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
    // esclusione campi nascosti della header
    Map<String, dynamic> head = {};
    for (String key in fgHeader.controls.keys) {
      if (key.startsWith('_')) continue;
      head[key] = fgHeader.control(key).value;
    }
    // escludo i campi nascosti dalle righe
    List rm = [];
    for (var item in rows) {
      var x = {};
      for (String key in item.keys) {
        if (key.startsWith('_')) continue;
        x[key] = item[key];
      }
      rm.add(x);
    }

    return {
      "class": runtimeType.toString(),
      "key": key,
      "header": head,
      "rows": rm,
    };
  }

  /// serialize the document in a json string.
  ///
  /// transform all not serializable variables in string and the call the
  /// function jsonEncode
  ///
  String toJson({data}) {
    data ??= toMap();
    dynamic toVar(value) {
      if (value.runtimeType != String && value.runtimeType != num) {
        return value.toString();
      }
      return value;
    }

    data['key'] = toVar(data['key']);
    data['header'].forEach((k, v) => data['header'][k] = toVar(v));
    for (var row in data['rows']) {
      row.forEach((k, v) => row[k] = toVar(v));
    }

    return jsonEncode(data);
  }

  /// prepara gli items per un DropdownMenu
  /// passo come argomento il nome del campo value e quello della descrizione
  ///
  List<DropdownMenuItem<String>> menuItems(String value, String description) {
    List<DropdownMenuItem<String>> ll = [];
    for (var i in rows) {
      ll.add(DropdownMenuItem(value: i[value], child: Text(i[description])));
    }
    return ll;
  }

  void notify() => notifyListeners();
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

  /// load the documento form the hive box.
  @override
  Future<void> load(key) async {
    var value = _box?.get(key);
    get(value);
  }

  /// called by load method to restore the Document from a map.
  ///
  void get(value) {
    reset();
    if (value != null && value['class'] == runtimeType.toString()) {
      key = value['key'];
      try {
        value['header'].forEach((k, v) => fgHeader.control(k).value = v);
      } catch (_) {}
      value['rows'].forEach((val) {
        Map<String, Object?> m = {};
        val.forEach((k, v) => m[k] = v);
        rows.add(m);
      });
    }
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
  ReactiveButton({Key? key}) : super(key: key);
  String text = "Send";
  Function? onOk;
  @override
  Widget build(BuildContext context) {
    final form = ReactiveForm.of(context);
    void _valid() async {
      if (form != null && form.valid) {
        if (onOk != null) await onOk!();
        Navigator.pop(context);
      }
    }

    return ElevatedButton(
      child: Text(text),
      onPressed: _valid,
    );
  }
}
