import 'package:flutter/material.dart';
import 'package:flutter_material_color_picker/flutter_material_color_picker.dart';
import 'package:myapplib/myapplib.dart';

/// uses MaterialColorPicker to pick a color from material colors.
/// return a string with name of color, if no color is choosen return an empty
/// string
///
Future<String> mainColorPicker(
    BuildContext context, String currentColor) async {
  MaterialColor? _current = themeColors[currentColor];
  String result = "";

  bool ok = await _colorPickerDialog(
    context,
    "Select color",
    MaterialColorPicker(
      selectedColor: _current,
      allowShades: false,
      onMainColorChange: (color) {
        result = findThemeColor(color);
      },
    ),
  );
  if (ok) return result;
  return '';
}

/// internal function used to build the dialog with MaterialColorPicker
///
Future<bool> _colorPickerDialog(
  BuildContext context,
  String title,
  Widget content,
) async {
  bool result = false;

  await showDialog(
    context: context,
    builder: (_) {
      return AlertDialog(
        contentPadding: const EdgeInsets.all(6.0),
        title: Text(title),
        content: content,
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Cancel'),
          ),
          TextButton(
            child: const Text('Ok'),
            onPressed: () {
              result = true;
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
  return result;
}
