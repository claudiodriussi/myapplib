import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:myapplib/myapplib.dart';

/// Get or generate persistent device UUID
///
/// The UUID is stored in ${app.extDir}/.device_uuid and persists across
/// app reinstalls (stored in external directory).
///
/// This UUID is used for server-side device authentication when syncing data.
///
/// Returns the device UUID string (format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
///
/// NOTE: This requires 'uuid' package in pubspec.yaml:
/// ```yaml
/// dependencies:
///   uuid: ^4.0.0
/// ```
Future<String> getDeviceUuid() async {
  final file = File('${app.extDir}/.device_uuid');

  if (await file.exists()) {
    return await file.readAsString();
  } else {
    final uuid = const Uuid().v4();
    await file.writeAsString(uuid);
    return uuid;
  }
}
