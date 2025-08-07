import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:provider/provider.dart';

import 'package:myapplib/myapplib.dart';

import '../globals.dart'; // in global dell'app deve essere dichiarato settings

/// open a dialog to pick color theme from a hue ring.
///
void colorPickerHueRing(context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        titlePadding: const EdgeInsets.all(0),
        contentPadding: const EdgeInsets.all(0),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(400),
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
            colorPickerHeight: 200.0,
            hueRingStrokeWidth: 20.0,
          ),
        ),
      );
    },
  );
}

void colorPickerMaterial(context) {
  Widget pickerLayoutBuilder(
    BuildContext context,
    List<Color> colors,
    PickerItem child,
  ) {
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

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
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

void colorPickerSlider(context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        titlePadding: const EdgeInsets.all(0),
        contentPadding: const EdgeInsets.all(0),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(5)),
        ),
        content: SingleChildScrollView(
          child: SlidePicker(
            pickerColor: Color(app.settings['themeColor']),
            onColorChanged: changeColor,
            colorModel: ColorModel.rgb,
            enableAlpha: false,
            displayThumbColor: true,
            showParams: false,
            showIndicator: true,
            indicatorBorderRadius: const BorderRadius.vertical(
              top: Radius.circular(5),
            ),
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


class VisualEffects extends StatelessWidget {
  const VisualEffects({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider.value(value: settings)],
      child: Consumer<HiveMap>(
        builder: (context, doc, child) => Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: const Text('Preferenze'),
          ),
          body: _form(context),
        ),
      ),
    );
  }

  Widget _form(context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ReactiveForm(
        formGroup: settings.fgMap,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(
                height: 32,
                child: Text(
                  "Componenti visive",
                  style: TextStyle(fontSize: 18),
                ),
              ),
              Row(
                children: [
                  ElevatedButton(
                    child: const Text('Scuro/Chiaro'),
                    onPressed: () => setDarkTheme(),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    child: const Text('Colore'),
                    // onPressed: () => colorPickerSlider(context),
                    onPressed: () => colorPickerHueRing(context),
                  ),
                  const SizedBox(width: 10),

                  // vedi: https://stackoverflow.com/questions/73193127/popupmenubutton-that-looks-like-elevatedbutton-in-flutter
                  // PopupMenuButton(
                  //   onSelected: (selectedValue) {
                  //     switch (selectedValue) {
                  //       case 1:
                  //         colorPickerHueRing(context);
                  //         break;
                  //       case 2:
                  //         colorPickerMaterial(context);
                  //         break;
                  //       case 3:
                  //         colorPickerSlider(context);
                  //         break;
                  //     }
                  //   },
                  //   // child: Text('eccolo'),
                  //   icon: const Icon(Icons.color_lens_outlined),
                  //   itemBuilder: (BuildContext ctx) => [
                  //     const PopupMenuItem(
                  //       value: 1,
                  //       child: Text('Ruota colori'),
                  //     ),
                  //     const PopupMenuItem(
                  //       value: 2,
                  //       child: Text('Colori standard'),
                  //     ),
                  //     const PopupMenuItem(
                  //       value: 3,
                  //       child: Text('Colori RGB'),
                  //     ),
                  //   ],
                  // ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton(
                    child: const Text('Predefinito'),
                    onPressed: () => setThemeColor(defaultColor),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    child: Text(
                      app.settings['borderInput'] == 1
                          ? 'Bordo sottile'
                          : 'Bordo completo',
                    ),
                    onPressed: () async {
                      app.settings['borderInput'] =
                          app.settings['borderInput'] == 1 ? 0 : 1;
                      app.saveSettings();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (BuildContext context) => VisualEffects(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  submitButton(
                    onOk: () {
                      settings.save();
                      defaultSettings(values: settings.box!.toMap());
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
