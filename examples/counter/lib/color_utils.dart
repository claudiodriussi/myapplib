// to chose the color for the theme you can chose between many flutter packages
// our choice is flutter_colorpicker, and here we have some customized dialogs

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:myapplib/myapplib.dart';

/// open a dialog to pick color theme from standard material colors.
///
void colorPicker1(context) {

  /// support function used build a box with list of material colors
  ///
  Widget pickerLayoutBuilder(
      BuildContext context, List<Color> colors, PickerItem child) {
    return SizedBox(
      width: 300,
      height: 380,
      child: GridView.count(
        crossAxisCount: 4,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        children: [for (Color color in colors) child(color)],
      ),
    );
  }

  // show the dialog, to exit from it just tap outside of it
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Select a color'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: Color(app.settings['themeColor']),
            onColorChanged: changeColor,
            layoutBuilder: pickerLayoutBuilder,
          ),
        ),
      );
    },
  );
}

/// open a dialog to pick color theme from a hsl palette.
///
void colorPicker2(context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        titlePadding: const EdgeInsets.all(0),
        contentPadding: const EdgeInsets.all(0),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: Color(app.settings['themeColor']),
            onColorChanged: changeColor,
            colorPickerWidth: 300,
            pickerAreaHeightPercent: 0.7,
            enableAlpha: true,
            labelTypes: [],
            displayThumbColor: true,
            paletteType: PaletteType.hsl,
            pickerAreaBorderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
            hexInputBar: false,
          ),
        ),
      );
    },
  );
}

/// support function used to change the color
///
void changeColor(Color color) {
  app.settings['themeColor'] = color.value;
  app.saveSettings();
  theTheme.setTheme();
  theTheme.notify();
}
