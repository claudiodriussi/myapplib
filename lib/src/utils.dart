import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';

import "my.i18n.dart";
import 'appvars.dart';

/// Load a text file, if fails return null
///
Future<String?> loadTextFile(File file) async {
  try {
    return await file.readAsString();
  } catch (e) {
    return null;
  }
}

/// write a text on a file.
///
/// if needed create the directories too
///
Future<void> saveTextFile(File file, String text) async {
  try {
    await Directory(p.dirname(file.path)).create(recursive: true);
  } catch (_) {}
  await file.writeAsString(text);
}

/// read a json file and return it as json
///
Future<dynamic> readJson<Map>(path, name) async {
  File file = File(p.join(path, name));
  String? json = await loadTextFile(file);
  try {
    return jsonDecode(json ?? '');
  } catch (e) {
    return {};
  }
}

/// round numbers
///
/// [type] indicates the type of rounding, 0 = math round, -1 defect round
/// +1 excess round
///
num round(num value, int decimals, {int type = 0}) {
  num roundType = 0;
  if (type != 0) roundType = 4.99999 / pow(10, decimals + 1);
  if (type < 0) roundType = -roundType;
  return num.parse((value + roundType).toStringAsFixed(decimals));
}

/// calc progressive discount
///
/// [discounts] is a list of [dynamics] applied to initial [value], the type
/// is dynamic but works only with numbers
///
num calcDiscount(num value, List discounts) {
  for (var discount in discounts) {
    value -= discount * value / 100;
  }
  return value;
}

/// empty values of a map.
///
/// Recognize standard dart types, objects are lived untouched, DateTime are
/// set to null
///
void map2empty(Map map) {
  map.forEach((k, v) {
    switch (v.runtimeType) {
      case String:
        map[k] = '';
        break;
      case int:
        map[k] = 0;
        break;
      case double:
        map[k] = 0.0;
        break;
      case bool:
        map[k] = false;
        break;
      case List:
        map[k] = [];
        break;
      case Map:
        map[k] = {};
        break;
      case DateTime:
        // map[k] = DateTime.now();
        map[k] = null;
        break;
      default:
      // map[k] = null;
    }
  });
}

/// wrapper around Navigator push
///
Future<void> navPush(context, page, {onStart}) async {
  if (onStart != null) {
    await onStart();
  }
  await Navigator.push<void>(
    context,
    MaterialPageRoute<void>(builder: (BuildContext context) => page),
  );
}

/// standard decoration for input fields, can have a suffix icon
///
/// if [search] is present the icon is an IconButton which call the callback
/// [popMenu] is a list of strings and the icon become a PopupMenuButton, try:
///
/// decoration: inputDecoration('my field', search: () {},
/// decoration: inputDecoration('my field', popMenu: ['one','two'], search: (v) {},
///
InputDecoration inputDecoration(var label, {search, popMenu, suffixIcon}) {
  OutlineInputBorder? border;
  Widget? icon;

  // choose the style of border
  switch (app.settings['borderInput'] ?? 0) {
    case 1:
      border = const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(4.0)));
      break;
    default:
  }

  IconButton searchButton(onPressed, {sIcon}) {
    return IconButton(
      icon: sIcon ?? const Icon(Icons.search),
      onPressed: onPressed,
    );
  }

  PopupMenuButton popButton(onSelected, popMenu, {sIcon}) {
    List<PopupMenuEntry<dynamic>> ll = [];
    for (var item in popMenu) {
      ll.add(PopupMenuItem(value: item, child: Text(item)));
    }
    return PopupMenuButton(
      icon: sIcon ?? const Icon(Icons.arrow_drop_down),
      onSelected: onSelected,
      itemBuilder: (BuildContext ctx) => ll,
    );
  }

  if (popMenu != null) {
    icon = popButton(search, popMenu, sIcon: suffixIcon);
  } else {
    if (search != null || suffixIcon != null) {
      icon = searchButton(search, sIcon: suffixIcon);
    }
  }

  InputDecoration input = InputDecoration(
    labelText: label,
    border: border,
    suffixIcon: icon,
  );
  return input;
}

/// short code for an alert box
///
/// with one button return always false with two buttons return a bool value
///
Future<bool> alertBox(
  BuildContext context, {
  String text = 'ToDo!',
  String title = '',
  List<String> buttons = const ['Ok'],
  bool firstTrue = false,
}) async {
  bool result = false;

  List<Widget> makeButtons() {
    List<Widget> ll = [
      TextButton(
          onPressed: () {
            result = firstTrue;
            Navigator.pop(context);
          },
          child: Text(buttons[0]))
    ];
    if (buttons.length > 1) {
      ll.add(TextButton(
          onPressed: () {
            result = !firstTrue;
            Navigator.pop(context);
          },
          child: Text(buttons[1])));
    }
    return ll;
  }

  await showDialog<String>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: makeButtons(),
    ),
  );
  return result;
}

/// textBox
///
/// let the user to enter a string. If the app is on mobile platform the field
/// can be read from barcode scanner emulate4d with the camera.
///
Future<String> textBox(
  BuildContext context, {
  String text = 'Enter text',
  String title = '',
  String value = '',
  bool barcode = false,
}) async {
  TextEditingController _textFieldController = TextEditingController();
  String result = value;
  _textFieldController.text = result;
  IconButton? bars;

  if (barcode && app.isMobile()) {
    bars = IconButton(
      onPressed: () async {
        String barcodeScanRes;
        try {
          barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
              '#ff6666', 'Annulla', true, ScanMode.BARCODE);
          if (barcodeScanRes != '-1') {
            _textFieldController.text = barcodeScanRes;
          }
        } catch (_) {
          await alertBox(context, text: "Barcode not allowed.".i18n);
        }
      },
      icon: const Icon(Icons.barcode_reader), // Icons.line_weight
    );
  }

  await showDialog<String>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: _textFieldController,
        decoration: InputDecoration(
          hintText: text.i18n,
          suffixIcon: bars,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text('Cancel'.i18n),
        ),
        TextButton(
          onPressed: () {
            result = _textFieldController.text;
            Navigator.pop(context);
          },
          child: Text('Ok'.i18n),
        ),
      ],
    ),
  );
  return result;
}

/// set default value to reactive_forms [FormGroup] fields.
///
/// all fields not presents in [exceptFields] or if its value is [null] are
/// set to '' (empty string), objects and dates are set to null
///
void formGroupReset(formGroup, {List<String>? exceptFields}) {
  exceptFields ??= [];
  for (String key in formGroup.controls.keys) {
    if (key.startsWith('_')) continue;
    if (!exceptFields.contains(key) || formGroup.value[key] == null) {
      switch (formGroup.control(key).runtimeType) {
        case FormControl<String>:
          formGroup.control(key).value = '';
          break;
        case FormControl<int>:
          formGroup.control(key).value = 0;
          break;
        case FormControl<double>:
          formGroup.control(key).value = 0.0;
          break;
        case FormControl<bool>:
          formGroup.control(key).value = false;
          break;
        case FormControl<DateTime>:
          // formGroup.control(key).value = DateTime.now();
          formGroup.control(key).value = null;
          break;
        default:
          formGroup.control(key).value = null;
      }
    }
  }
}

/// reactive_forms validator for double numbers
///
class FloatValidator extends Validator<dynamic> {
  /// The regex expression of a numeric string value.
  static final RegExp numberRegex = RegExp(r'[+-]?([0-9]*[.])?[0-9]+$');
  const FloatValidator() : super();
  @override
  Map<String, dynamic>? validate(AbstractControl<dynamic> control) {
    return (control.value == null) ||
            !numberRegex.hasMatch(control.value.toString())
        ? <String, dynamic>{ValidationMessage.number: true}
        : null;
  }
}

/// set the current theme color from an integer
///
void setThemeColor(int color) {
  app.settings['themeColor'] = color;
  app.saveSettings();
  theTheme.setTheme();
  theTheme.notify();
}

/// switch or force dark and light theme
///
void setDarkTheme({bool? dark}) {
  if (dark == null) {
    app.settings['darkTheme'] = !app.settings['darkTheme'];
  } else {
    app.settings['darkTheme'] = dark;
  }
  app.saveSettings();
  theTheme.setTheme();
  theTheme.notify();
}

/// A theme changer which use ChangeNotifier to use Provider package as state
/// manager.
/// The persistence is managed by app.settings fields "themeColor" and
/// "darkTheme"
/// It uses Material Design 3
///
class ThemeNotifier with ChangeNotifier {
  ThemeData theTheme = ThemeData(useMaterial3: true);

  ThemeData setTheme() {
    theTheme = ThemeData(
      useMaterial3: true,
      brightness:
          app.settings['darkTheme'] ? Brightness.dark : Brightness.light,
      colorSchemeSeed: Color(app.settings['themeColor']),
    );
    return theTheme;
  }

  void notify() {
    notifyListeners();
  }
}

// global variable used to handle themes
ThemeNotifier theTheme = ThemeNotifier();

// map with material color themes
Map themeColors = {
  'red': Colors.red, // 0xFFF44336
  'pink': Colors.pink, // 0xFFE91E63
  'purple': Colors.purple, // 0xFF9C27B0
  'deepPurple': Colors.deepPurple, // 0xFF673AB7
  'indigo': Colors.indigo, // 0xFF3F51B5
  'blue': Colors.blue, // 0xFF2196F3
  'lightBlue': Colors.lightBlue, // 0xFF03A9F4
  'cyan': Colors.cyan, // 0xFF00BCD4
  'teal': Colors.teal, // 0xFF009688
  'green': Colors.green, // 0xFF4CAF50
  'lightGreen': Colors.lightGreen, // 0xFF8BC34A
  'lime': Colors.lime, // 0xFFCDDC39
  'yellow': Colors.yellow, // 0xFFFFEB3B
  'amber': Colors.amber, // 0xFFFFC107
  'orange': Colors.orange, // 0xFFFF9800
  'deepOrange': Colors.deepOrange, // 0xFFFF5722
  'brown': Colors.brown, // 0xFF795548
  'grey': Colors.grey, // 0xFF9E9E9E
  'blueGrey': Colors.blueGrey, // 0xFF607D8B
};

/// find the name of color starting from material colors.
///
/// i.e. findThemeColor(Color.green) returns 'green'
///
String findThemeColor(var checkColor) {
  for (String key in themeColors.keys) {
    if (themeColors[key] == checkColor) return key;
  }
  return "";
}
