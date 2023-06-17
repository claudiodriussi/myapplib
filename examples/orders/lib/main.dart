import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:myapplib/myapplib.dart';
import "src/settings.dart";
import 'globals.dart';

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
    app.settings['deviceId'] = androidInfo.androidId;
  } else {
    app.settings['deviceInfo'] = {};
    app.settings['deviceId'] = 'ok';
  }

  app.isBluetooth = false;
  app.isLocation = false;
  app.saveSettings();
  app.addBox('some_box');
  defaultSettings();
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
          theme: theme.getTheme(),
          home: const MyHomePage(),
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
        title: const Text('Ordes app'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
                child: const Text('Alert box'),
                onPressed: () async {
                  bool isOk = await alertBox(context,
                      text: "Is Flutter awesome?", buttons: ['No', 'Yes']);
                  if (isOk) {
                    // ignore: use_build_context_synchronously
                    await alertBox(context, text: "Yeah!");
                  }
                }),
            const SizedBox(height: 10),
            ElevatedButton(
              child: const Text('Settings'),
              onPressed: () => {navPush(context, const EditSettings())},
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              child: const Text('Alert box'),
              onPressed: () => {},
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
