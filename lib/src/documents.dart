// import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:hive/hive.dart';
// import 'package:i18n_extension/i18n_widget.dart';

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

class Document with ChangeNotifier {
  List rows = []; // document rows
  List rowsList = []; // rows for filtered listView
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

  Future<void> editHeader({required editFn}) async {
    editOk = true;
    await editFn();
    if (editOk) {
      modified = true;
      notifyListeners();
    }
  }

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

  Future<void> reset({List<String>? exceptFields}) async {
    formGroupReset(fgHeader, exceptFields: exceptFields);
    rows = [];
    key = null;
    modified = false;
    notifyListeners();
  }

  Future<void> save() async {
    // le derivate gestiscono la persistenza
  }

  Future<void> load(key) async {
    // le derivate gestiscono la persistenza
  }

  /// restituisce una map con i valori di self
  ///
  /// escludo i campi nascosti, quelli la cui chiave inizia con "_", i campi
  /// nascosti servono quando ho bisogno di campi nelle form che non vanno
  /// salvati nel documento.
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

  /// serializza il document in una stringa json
  ///
  /// trasforma tutte le variabili non serializzabili in string ed alla fine
  /// chiama la funzione jsonEncode
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

mixin Document2Hive on Document {
  Box? _box;

  void setBox(box) => _box = box;

  @override
  Future<void> save() async {
    _box?.put(key, toMap());
  }

  @override
  Future<void> load(key) async {
    var value = _box?.get(key);
    get(value);
  }

  ///
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

ReactiveButton submitButton({text = 'Ok', onOk}) {
  var rb = ReactiveButton();
  rb.text = text;
  rb.onOk = onOk;
  return rb;
}

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
