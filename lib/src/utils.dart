import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

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
/// Recognize standard dart types, objects are lived untouched except DateTime
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
        map[k] = DateTime.now();
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
      ll.add(PopupMenuItem(child: Text(item), value: item));
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

/// set default value to reactive_forms [FormGroup] fields.
///
/// all fields not present in [exceptFields] or if its value is [null] are
/// set to '' (empty string)
///
void formGroupReset(formGroup, {List<String>? exceptFields}) {
  exceptFields ??= [];
  for (String key in formGroup.controls.keys) {
    if (key.startsWith('_')) continue;
    if (!exceptFields.contains(key) || formGroup.value[key] == null) {
      try {
        formGroup.control(key).value = '';
        continue;
      } catch (_) {}
      try {
        formGroup.control(key).value = 0;
        continue;
      } catch (_) {}
      try {
        formGroup.control(key).value = 0.0;
        continue;
      } catch (_) {}
      try {
        formGroup.control(key).value = false;
        continue;
      } catch (_) {}
      try {
        formGroup.control(key).value = DateTime.now();
        continue;
      } catch (_) {}
    }
  }
}

/// reactive_forms validator for double numbers
///
Map<String, dynamic>? floatNumber(AbstractControl<dynamic> control) {
  final RegExp numberRegex = RegExp(r'[+-]?([0-9]*[.])?[0-9]+$');
  if (control.isNull || !numberRegex.hasMatch(control.value.toString())) {
    return {'Non valido': true};
  }
  return null;
}

/// A theme changer which use ChangeNotifier to use Provider package as state
/// manager.
/// The persistence is managed by app.settings fields "themeColor" and
/// "darkTheme"
///
class ThemeNotifier with ChangeNotifier {
  final darkTheme = ThemeData(
    useMaterial3: true,
    primarySwatch: Colors.grey,
    primaryColor: Colors.black,
    brightness: Brightness.dark,
    dividerColor: Colors.black12,
  );

  var lightTheme = ThemeData(
    primarySwatch: themeColors[app.settings['themeColor']],
  );

  late ThemeData _themeData;
  ThemeData getTheme() => _themeData;

  ThemeNotifier() {
    if (app.settings['darkTheme']) {
      _themeData = darkTheme;
    } else {
      _themeData = lightTheme;
    }
    notifyListeners();
  }

  void setDarkMode() async {
    _themeData = darkTheme;
    notifyListeners();
  }

  void setLightMode() async {
    lightTheme = ThemeData(
      primarySwatch: themeColors[app.settings['themeColor']],
    );
    _themeData = lightTheme;
    notifyListeners();
  }
}

// global variable used to handle themes
ThemeNotifier theTheme = ThemeNotifier();

// map with material color themes
Map themeColors = {
  'red': Colors.red,
  'pink': Colors.pink,
  'purple': Colors.purple,
  'deepPurple': Colors.deepPurple,
  'indigo': Colors.indigo,
  'blue': Colors.blue,
  'lightBlue': Colors.lightBlue,
  'cyan': Colors.cyan,
  'teal': Colors.teal,
  'green': Colors.green,
  'lightGreen': Colors.lightGreen,
  'lime': Colors.lime,
  'yellow': Colors.yellow,
  'amber': Colors.amber,
  'orange': Colors.orange,
  'deepOrange': Colors.deepOrange,
  'brown': Colors.brown,
  'grey': Colors.grey,
  'blueGrey': Colors.blueGrey,
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
