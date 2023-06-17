import 'package:reactive_forms/reactive_forms.dart';

import 'package:myapplib/myapplib.dart';

void defaultSettings({values=Null}) {
  if (values != Null) {
    app.settings = values;
  }
  app.defaultSetting('borderInput', 1);
  app.defaultSetting('themeColor', 'blue');
  app.defaultSetting('darkTheme', false);

  app.defaultSetting('myName', 'claudio');
  app.defaultSetting('lastUpdate', DateTime.now());

  app.saveSettings();
}

HiveMap settings = HiveMap(
  app.hiveBoxes['settings'],
  FormGroup({
    'myName': FormControl<String>(),
    'lastUpdate': FormControl<DateTime>(),
  }),
);
