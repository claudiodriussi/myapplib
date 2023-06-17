// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:device_info_plus/device_info_plus.dart';
import 'package:hive/hive.dart';
import 'package:reactive_forms/reactive_forms.dart';


import 'package:myapplib/myapplib.dart';

void defaultSettings(values) {
  app.settings = values;

  app.defaultSetting('my_name', 'claudio');
  app.saveSettings();
}

HiveMap settings = HiveMap(
  app.hiveBoxes['settings'],
  FormGroup({
    'my_name': FormControl<String>(),
  }),
);

