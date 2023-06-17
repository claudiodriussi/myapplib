import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:hive/hive.dart';

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

ReactiveButton submitButton({text = 'Ok', onOk}) {
  var rb = ReactiveButton();
  rb.text = text;
  rb.onOk = onOk;
  return rb;
}

class ReactiveButton extends StatelessWidget {
  ReactiveButton({Key? key}) : super(key: key);
  String text = "Invia";
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
