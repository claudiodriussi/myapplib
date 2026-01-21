import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'utils.dart';
import '../i18n/strings.g.dart' as ml;

// app is a global variable used as singleton
final AppVars app = AppVars();

class AppVars {
  // folders recognized by app. See path_provider
  String curDir = '';
  String docDir = '';
  String tmpDir = '';
  String extDir = '';
  List<Directory>? extDirs = [];

  // identity
  String appName = 'flutter_app';
  String appVersion = '0.1.0';
  String appDate = '0000-00-00';
  bool isEnabled = true; // if you wish you can protect you app in some way

  // android permissions
  bool isStorage = true;
  bool isLocation = true;
  bool isBluetooth = true;

  // app wide settings and hive boxes
  Map settings = {};
  Map<String, Box> hiveBoxes = {};

  /// add a hive box, the first time is called it initialize hive, and each
  /// time the app starts compact the box.
  ///
  Future<void> addBox(name) async {
    if (hiveBoxes.isEmpty) {
      if (isWeb()) {
        // On web Hive uses IndexedDB automatically
        Hive.init('hive'); // symbolic path
      } else {
        Hive.init('$extDir/hive');
      }
    }
    hiveBoxes[name] = await Hive.openBox(name);
    await hiveBoxes[name]!.compact();
  }

  /// set default value for a settings Key
  ///
  void defaultSetting(key, value) {
    if (!settings.containsKey(key) || settings[key] == null) {
      settings[key] = value;
    }
  }

  /// save settings to hive box
  /// if key and value are provided, saves only that single setting
  ///
  void saveSettings({String? key, dynamic value}) {
    if (key != null) {
      settings[key] = value;
      hiveBoxes['settings']!.put(key, value);
    } else {
      hiveBoxes['settings']!.putAll(settings);
    }
  }

  /// start the app, set app folders and init the settings
  ///
  Future<void> start() async {
    // initialize myapplib locale (check --dart-define=LOCALE first)
    const String envLocale = String.fromEnvironment('LOCALE');
    if (envLocale.isNotEmpty) {
      if (envLocale == 'en') {
        ml.LocaleSettings.setLocale(ml.AppLocale.en);
      } else if (envLocale == 'it') {
        ml.LocaleSettings.setLocale(ml.AppLocale.it);
      } else {
        ml.LocaleSettings.useDeviceLocale();
      }
    } else {
      ml.LocaleSettings.useDeviceLocale();
    }

    // setup app folders
    if (isWeb()) {
      // On web use virtual paths (Hive uses IndexedDB)
      curDir = '/web';
      docDir = '/web/documents';
      tmpDir = '/web/tmp';
      extDir = '/web/storage';
    } else {
      // Mobile/Desktop platforms
      curDir = Directory.current.path;
      try {
        docDir = (await getApplicationDocumentsDirectory()).path;
      } catch (e) {
        docDir = curDir;
      }
      try {
        tmpDir = (await getTemporaryDirectory()).path;
      } catch (e) {
        tmpDir = docDir;
      }
      try {
        extDir = (await getExternalStorageDirectory())!.path;
      } catch (e) {
        extDir = docDir;
      }
      if (isDesktop()) {
        extDir = p.join(curDir, 'data');
      }
      try {
        extDirs = await getExternalStorageDirectories();
      } catch (_) {}
    }

    // setup settings, the app always have a box called settings
    await addBox('settings');
    // retrive settings from hive
    settings = hiveBoxes['settings']!.toMap();
    // set some standard settings
    defaultSetting('deviceInfo', await setDeviceInfo());
    defaultSetting('deviceId', 'ok');
    defaultSetting('activationKey', '');
    defaultSetting('activationUser', '');
    defaultSetting('borderInput', 1);
    defaultSetting('themeColor', themeColor);
    defaultSetting('darkTheme', false);

    // Network/server communication settings (pattern for RestClient)
    defaultSetting('server', '');
    defaultSetting('port', 0);
    defaultSetting('server2', '');     // Fallback server (e.g., WiFi vs mobile)
    defaultSetting('port2', 0);        // Fallback port
    defaultSetting('timeout', 0.0);    // Default timeout in seconds (0 = use method default)
    defaultSetting('timeout2', 2.0);   // Fallback timeout in seconds
    defaultSetting('protocol', 0);     // protocol used for communications, (0 = standard rest)
    defaultSetting('prefix', '');
    defaultSetting('user', '');
    defaultSetting('password', '');

    // store settings again to hive
    saveSettings();
  }

  /// get the root of an external dir
  ///
  String storageDir({path}) {
    path ??= extDir;
    var i = path.indexOf('Android');
    if (i != -1) {
      path = extDir.substring(0, i);
    }
    return path;
  }

  /// Normalizes device info into standardized format
  /// Supports Android, iOS, Desktop and Web with uniform structure: {model, brand, device}
  /// Returns the Map to be used with defaultSetting
  Future<Map<String, String>> setDeviceInfo() async {
    Map<String, String> deviceInfo = {};

    if (isWeb()) {
      // Web: generic values
      deviceInfo = {
        'model': 'Web Browser',
        'brand': 'Web',
        'device': 'Browser',
      };
    } else if (isMobile()) {
      DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;
        deviceInfo = {
          'model': androidInfo.model,
          'brand': androidInfo.brand,
          'device': androidInfo.device,
        };
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfoPlugin.iosInfo;
        deviceInfo = {
          'model': iosInfo.model,
          'brand': 'Apple',
          'device': iosInfo.model,
        };
      }
    } else {
      // Desktop: use Platform.operatingSystem
      String platform = Platform.operatingSystem;
      deviceInfo = {
        'model': Platform.localHostname,
        'brand': platform,
        'device': platform,
      };
    }

    return deviceInfo;
  }

  /// default homeDir is on the root of external storage plus the appName
  ///
  /// try this:
  /// ```
  /// try {
  ///   var f = File('${app.homeDir}/hello.txt');
  ///   await saveTextFile(f, 'Hello Flutter!');
  /// } catch (e) {
  ///   print(e);
  /// }
  /// ```
  ///
  String get homeDir => storageDir() + appName;

  /// check if platform is mobile
  ///
  bool isMobile() {
    if (isWeb()) return false;
    return Platform.isIOS || Platform.isAndroid;
  }

  /// check if it is a web app
  ///
  bool isWeb() {
    return kIsWeb;
  }

  /// check if it is a desktop app
  ///
  bool isDesktop() {
    return !isMobile() && !isWeb();
  }
}
