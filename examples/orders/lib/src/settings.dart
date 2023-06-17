// import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reactive_forms/reactive_forms.dart';

// import 'package:http/http.dart' as http;
// import 'package:url_launcher/url_launcher.dart';
// import 'package:expandable/expandable.dart';

// import 'package:applib/applib.dart';
// import 'agenti.dart';
// import 'stampa.dart';

import 'package:myapplib/myapplib.dart';
import '../globals.dart';

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
                ReactiveTextField<String>(
                  formControlName: 'my_name',
                  decoration: inputDecoration('My name'),
                ),
              const SizedBox(height: 16),

              Row(
                children: [
                  submitButton(onOk: () {
                    settings.save();
                    defaultSettings(settings.box!.toMap());
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
