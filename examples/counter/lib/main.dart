import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:myapplib/myapplib.dart';

import 'color_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initApp();
  runApp(
    // to handle states, our choice is https://pub.dev/packages/provider
    // here we have 2 providers, one for the Counter and another for the theme
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: counter),
        // theTheme is a global variable defined in myapplib used to handle theme
        ChangeNotifierProvider.value(value: theTheme),
      ],
      child: const MyApp(),
    ),
  );
}

/// initialize AppVars app from myapplib
///
Future<void> initApp() async {
  // app is a global singleton containing a some variables app wide available
  app.appName = 'counter';
  app.appVersion = '0.2.0';
  await app.start();

  // depending on the current platform you can activate different
  // functionalities suck as ask permissions and get device ID
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
  // global settings are stored on a Hive Box handled for you by myapplib
  app.saveSettings();

  // you can add your Hive Boxes
  app.addBox('some_box');

  // theme info are stored in settings, here you can change the defaults
  app.defaultSetting('themeColor', 0xFF673AB7); // deepPurple
  app.defaultSetting('darkTheme', false);

  // save your own data on settings
  app.defaultSetting('my_name', 'claudio');
  app.saveSettings();
}

/// MyHomePage is embedded into a ChangeNotifierProvider used to handle
/// persistence of the theme
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => theTheme,
      child: Consumer<ThemeNotifier>(
        builder: (context, theme, child) => MaterialApp(
          title: 'Flutter Demo',
          // debugShowCheckedModeBanner: false,
          theme: theme.setTheme(),
          darkTheme: theme.setTheme(),
          themeMode: ThemeMode.light,
          home: const MyHomePage(title: 'Flutter Counter with theme changer'),
        ),
      ),
    );
  }
}

/// this class handle the Counter state
class Counter with ChangeNotifier {
  int value = 0;

  void increment() {
    value += 1;
    notifyListeners();
  }
}
Counter counter = Counter();

/// since the counter is handled by provider, we don't need a stateful widget
class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
        elevation: 2,
        shadowColor: Theme.of(context).shadowColor,
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
                  child: const Text('Deep Purple'),
                  onPressed: () => setThemeColor(0xFF673AB7),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  child: const Text('Blue'),
                  onPressed: () => setThemeColor(0xFF2196F3),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  child: const Text('Green'),
                  onPressed: () => setThemeColor(0xFF4CAF50),
                ),
                const SizedBox(width: 10),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  child: const Text('Material colors'),
                  onPressed: () => colorPicker1(context),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  child: const Text('Pick color'),
                  onPressed: () => colorPicker2(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Switch light/dark theme'),
            ElevatedButton(
              child: const Text('Switch'),
              onPressed: () => setDarkTheme(),
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
}

