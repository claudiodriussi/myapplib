import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'appvars.dart';
import 'utils.dart';

/// Trap uncaught errors, keep the last ones on a file and raise a flag
///
/// On a device uncaught errors are silent, this makes them visible from the
/// app itself. Not active under debug, where the console already shows them
/// and the guarded zone would hide them from the debugger.
class ErrorLog {
  /// How many errors are kept on file
  static const int maxErrors = 5;
  static const String _sep = '\n<<<< >>>>\n';

  /// Snackbar host: assign it to MaterialApp.scaffoldMessengerKey
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  static File get file => File('${app.extDir}/errors.log');

  /// True when an error was recorded and not yet seen
  static bool get pending => app.settings['errorPending'] == true;

  /// Record an error: file, flag and a snackbar when the app is running
  static void record(Object error, StackTrace? stack, {String source = 'app'}) {
    String entry = '${DateTime.now().toString().substring(0, 19)} '
        '[$source] ${app.appName} ${app.appVersion}\n$error\n'
        '${'${stack ?? ''}'.split('\n').take(8).join('\n')}';
    try {
      var all = file.existsSync() ? file.readAsStringSync().split(_sep) : <String>[];
      all = [...all, entry].where((e) => e.trim().isNotEmpty).toList();
      if (all.length > maxErrors) all = all.sublist(all.length - maxErrors);
      file.writeAsStringSync(all.join(_sep));
      app.saveSettings(key: 'errorPending', value: true);

      messengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          backgroundColor: Colors.red,
          content: Text('Error: $error', maxLines: 2, overflow: TextOverflow.ellipsis),
        ));
    } catch (_) {} // logging must never throw
  }

  /// Open the log page and turn the flag off
  static Future<void> show(BuildContext context) async {
    app.saveSettings(key: 'errorPending', value: false);
    await navPush(context, const ErrorLogPage());
  }

  /// Ready made button to drop in a settings page
  static Widget button(BuildContext context) => ElevatedButton.icon(
        icon: const Icon(Icons.bug_report),
        label: const Text('Error log'),
        onPressed: () => show(context),
      );

  /// Raise an unhandled async error, to check the trapping on a device
  ///
  /// Under debug it just shows up on the console, in release it goes through
  /// the whole cycle: file, flag and snackbar. Drop it in a settings page,
  /// commented out, and enable it when the trapping has to be verified:
  ///
  /// ```dart
  /// Row(children: [
  ///   ErrorLog.button(context),
  ///   // const SizedBox(width: 10),
  ///   // ErrorLog.testButton(),
  /// ]),
  /// ```
  static Widget testButton() => ElevatedButton.icon(
        icon: const Icon(Icons.warning),
        label: const Text('Test error'),
        onPressed: () => Future(() => throw Exception('Test error')),
      );
}

/// Start the app with error trapping
///
/// Replaces the main() boilerplate: [init] failures show a plain error screen
/// instead of hanging on the splash, [builder] returns the app widget and
/// [onStarted] runs right after runApp (desktop window setup and the like).
///
/// Errors keep reaching the console as usual, so debugging is unaffected, but
/// the guarded zone handles them and the debugger no longer breaks on its own:
/// set [debugTrap] to false when that is needed. It only applies to debug
/// builds, a release always traps.
void runAppGuarded({
  required Future<void> Function() init,
  required Widget Function() builder,
  void Function()? onStarted,
  bool debugTrap = true,
}) {
  if (kDebugMode && !debugTrap) {
    _start(init, builder, onStarted);
    return;
  }
  runZonedGuarded(() {
    FlutterError.onError = (details) {
      if (!details.silent) ErrorLog.record(details.exception, details.stack, source: 'flutter');
      FlutterError.presentError(details);
    };
    _start(init, builder, onStarted);
  }, (error, stack) {
    ErrorLog.record(error, stack, source: 'async');
    debugPrint('$error\n$stack'); // console output as without the zone
  });
}

Future<void> _start(Future<void> Function() init, Widget Function() builder,
    void Function()? onStarted) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await init();
  } catch (e, s) {
    ErrorLog.record(e, s, source: 'boot');
    runApp(_BootError('$e'));
    return;
  }
  runApp(builder());
  onStarted?.call();
}

/// Minimal app shown when the initialization fails
class _BootError extends StatelessWidget {
  final String message;
  const _BootError(this.message);

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Startup error'), backgroundColor: Colors.red),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: SingleChildScrollView(child: SelectableText(message))),
              ElevatedButton(
                onPressed: () => Clipboard.setData(ClipboardData(text: message)),
                child: const Text('Copy'),
              ),
            ]),
          ),
        ),
      );
}

/// Show the recorded errors, last one at the bottom
class ErrorLogPage extends StatefulWidget {
  const ErrorLogPage({super.key});
  @override
  State<ErrorLogPage> createState() => _ErrorLogPageState();
}

class _ErrorLogPageState extends State<ErrorLogPage> {
  String text = '';

  @override
  void initState() {
    super.initState();
    text = ErrorLog.file.existsSync() ? ErrorLog.file.readAsStringSync() : 'No errors';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Error log'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () => Clipboard.setData(ClipboardData(text: text)),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                if (ErrorLog.file.existsSync()) ErrorLog.file.deleteSync();
                setState(() => text = 'No errors');
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: SelectableText(text,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ),
      );
}
