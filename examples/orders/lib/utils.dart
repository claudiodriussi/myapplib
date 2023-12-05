import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:myapplib/myapplib.dart';


/// open a dialog to pick color theme from a hue ring.
///
void colorPicker(context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        titlePadding: const EdgeInsets.all(0),
        contentPadding: const EdgeInsets.all(0),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
                      top: Radius.circular(500),
                      bottom: Radius.circular(100),
                    ),
        ),
        content: SingleChildScrollView(
          child: HueRingPicker(
            pickerColor: Color(app.settings['themeColor']),
            portraitOnly: true,
            onColorChanged: changeColor,
            enableAlpha: false,
            displayThumbColor: false,
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

