import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'package:myapplib/myapplib.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initApp();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: Counter()),
        ChangeNotifierProvider.value(value: theTheme),
      ],
      child: const MyApp(),
    ),
  );
}

Future<void> initApp() async {
  app.appName = 'counter';
  app.appVersion = '0.2.0';
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

  app.defaultSetting('my_name', 'claudio');
  app.saveSettings();
}

class Counter with ChangeNotifier {
  int value = 0;

  void increment() {
    value += 1;
    notifyListeners();
  }
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
        title: const Text('Counter with theme changer'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You have pushed the button this many times:'),
            Consumer<Counter>(
              builder: (context, counter, child) => Text(
                '${counter.value}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Change theme color'),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  child: const Text('Blue'),
                  onPressed: () async => await _setColor('blue'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  child: const Text('Green'),
                  onPressed: () async => await _setColor('green'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  child: const Text('Grey'),
                  onPressed: () async => await _setColor('grey'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Switch light/dark theme'),
            ElevatedButton(
              child: const Text('Switch'),
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
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          var counter = context.read<Counter>();
          counter.increment();
        },
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _setColor(String color) async {
    app.settings['themeColor'] = color;
    app.settings['darkTheme'] = false;
    theTheme.setLightMode();
    app.saveSettings();
  }
}
