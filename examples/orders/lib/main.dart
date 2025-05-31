import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:i18n_extension/i18n_extension.dart';

import 'package:myapplib/myapplib.dart';
import "src/settings.dart";
import "src/products.dart";
import 'globals.dart';
import "main.i18n.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initApp();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: theTheme),
      ],
      child: const MyApp(),
    ),
  );
}

Future<void> initApp() async {
  app.appName = 'orders';
  app.appVersion = '0.1.0';
  await app.start();

  if (app.isMobile()) {
    app.isStorage = !(await Permission.storage.request()).isDenied;
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    app.settings['deviceInfo'] = androidInfo.toMap();
    // app.settings['deviceId'] = androidInfo.androidId;
  } else {
    app.settings['deviceInfo'] = {};
    app.settings['deviceId'] = 'ok';
  }

  app.isBluetooth = false;
  app.isLocation = false;
  app.saveSettings();
  app.addBox('products');
  defaultSettings();

  MyI18n.loadTranslations();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => theTheme,
      child: Consumer<ThemeNotifier>(
        builder: (context, theme, child) => MaterialApp(
          // debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', 'EN'),
            Locale('it', 'IT'),
            Locale('es', 'ES'),
            Locale('de', 'DE'),
            Locale('fr', 'FR'),
          ],
          theme: theme.setTheme(),
          darkTheme: theme.setTheme(),
          themeMode: ThemeMode.light,
          home: I18n(
            child: MyHomePage(),
          ),

          // home: const MyHomePage(),
        ),
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Ordes app'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
                child: Text('Alert box'.i18n),
                onPressed: () async {
                  bool isOk = await alertBox(context,
                      text: "Is Flutter awesome?".i18n, buttons: ['No'.i18n, 'Yes'.i18n]);
                  if (isOk) {
                    // ignore: use_build_context_synchronously
                    await textBox(context, text: "Yeah!", barcode: true);
                  }
                }),
            const SizedBox(height: 10),
            ElevatedButton(
              child: Text('Settings'.i18n),
              onPressed: () => {navPush(context, const EditSettings())},
            ),
            const SizedBox(height: 10),
            ElevatedButton(
                child: Text('Products'.i18n),
                onPressed: () async {
                  products.load("products");
                  navPush(context, const EditProducts());
                }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
