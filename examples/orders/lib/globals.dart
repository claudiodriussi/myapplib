import 'package:reactive_forms/reactive_forms.dart';

import 'package:myapplib/myapplib.dart';

//
int defaultColor = themeColors['indigo'].value;

void defaultSettings({values = Null}) {
  if (values != Null) {
    app.settings = values;
  }
  app.defaultSetting('borderInput', 1);
  app.defaultSetting('themeColor', defaultColor);
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

// ----------------------------------------------------------------------------
// Products
// ----------------------------------------------------------------------------

Products products = Products(
  fgHeader: FormGroup({}),
  fgRow: FormGroup({
    'id': FormControl<String>(),
    'name': FormControl<String>(),
    'unit': FormControl<String>(),
    'vat': FormControl<double>(validators: [const FloatValidator()]),
    'price': FormControl<double>(validators: [const FloatValidator()]),
    'notes': FormControl<String>(),
  }),
);

class Products extends Document with Document2Hive {
  Products({fgHeader, fgRow}) {
    this.fgHeader = fgHeader;
    // this.fgRow = fgRow;
    key = "products"; // only one record in this box
    setBox(app.hiveBoxes['products']);
  }
}

