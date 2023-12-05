import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:reactive_date_time_picker/reactive_date_time_picker.dart';
import 'package:intl/intl.dart';

import 'package:myapplib/myapplib.dart';
import '../globals.dart';
import '../main.i18n.dart';
import '../utils.dart';

class EditSettings extends StatelessWidget {
  const EditSettings({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider.value(value: settings)],
      child: Consumer<HiveMap>(
        builder: (context, doc, child) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: Text('Settings'.i18n),
            bottom: TabBar(
              tabs: [
                Tab(child: Text('Preferences'.i18n)),
                Tab(child: Text('Visual'.i18n)),
              ],
            ),
          ),
          body: _tabView(context),
        ),
      ),
    ));
  }

  Widget _tabView(context) {
    return TabBarView(
      children: [
        _preferences(context),
        _visual(context),
      ],
    );
  }

  Widget _preferences(context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ReactiveForm(
        formGroup: settings.fgMap,
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                height: 32,
                child: Text(
                  "Setting fields".i18n,
                  style: TextStyle(fontSize: 18),
                ),
              ),
              ReactiveTextField<String>(
                formControlName: 'myName',
                decoration: inputDecoration('My name'.i18n),
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
                      decoration: inputDecoration('Date last updated'.i18n,
                          suffixIcon: const Icon(Icons.calendar_today)),
                    ),
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

  Widget _visual(context) {
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
                  "Visual components",
                  style: TextStyle(fontSize: 18),
                ),
              ),
              Row(
                children: [
                  ElevatedButton(
                    child: Text('Dark/Light'.i18n),
                    onPressed: () => setDarkTheme(),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    child: Text('Color picker'.i18n),
                    onPressed: () => colorPicker(context),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    child: Text('Default'.i18n),
                    onPressed: () => setThemeColor(defaultColor),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton(
                    child: Text(app.settings['borderInput'] == 1 ? 'Thin Border'.i18n : 'Full  Border'.i18n),
                    onPressed: () async {
                      app.settings['borderInput'] =
                          app.settings['borderInput'] == 1 ? 0 : 1;
                      app.saveSettings();
                      Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (BuildContext context) =>
                                  EditSettings()));
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
