import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:reactive_date_time_picker/reactive_date_time_picker.dart';
import 'package:intl/intl.dart';

import 'package:myapplib/myapplib.dart';
import '../globals.dart';
import '../utils.dart';

class EditSettings extends StatelessWidget {
  const EditSettings({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider.value(value: settings)],
      child: Consumer<HiveMap>(
        builder: (context, doc, child) => Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
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
                  "Setting fields",
                  style: TextStyle(fontSize: 18),
                ),
              ),
                ReactiveTextField<String>(
                  formControlName: 'myName',
                  decoration: inputDecoration('My name'),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ReactiveDateTimePicker(
                      formControlName: 'lastUpdate',
                      valueAccessor: DateTimeValueAccessor(
                        dateTimeFormat: DateFormat('dd/MM/yyyy'),
                      ),
                      decoration: inputDecoration('Date last updated',
                          suffixIcon: const Icon(Icons.calendar_today)),
                    ),
                  ),

                ],
              ),
              const SizedBox(height: 8),
              const SizedBox(
                height: 32,
                child: Text(
                  "Visual components",
                  style: TextStyle(fontSize: 18),
                ),
              ),
              Row(
                children: [
                  ElevatedButton(
                    child: const Text('Color'),
                    onPressed: () async {
                      String s = await mainColorPicker(
                          context, app.settings['themeColor']);
                      app.settings['themeColor'] = s;
                      app.settings['darkTheme'] = false;
                      theTheme.setLightMode();
                      app.saveSettings();
                    },
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    child: const Text('Theme'),
                    onPressed: () async {
                      app.settings['darkTheme'] = !app.settings['darkTheme'];
                      app.saveSettings();
                      if (app.settings['darkTheme']) {
                        theTheme.setDarkMode();
                      } else {
                        theTheme.setLightMode();
                      }
                    },
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    child: const Text('Border'),
                    onPressed: () async {
                      app.settings['borderInput'] =
                          app.settings['borderInput'] == 1 ? 0 : 1;
                      app.saveSettings();
                      await alertBox(context,
                          title: "Now the border of input fields is:",
                          text: app.settings['borderInput'] == 1
                              ? 'Full'
                              : 'Thin');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  submitButton(onOk: () {
                    settings.save();
                    defaultSettings(values: settings.box!.toMap());
                  }),
                ],
              ),
            ],
          ),
        ),
      ),

    );
  }
}


