import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Alignment;
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:myapplib/myapplib.dart';

/// Desktop window position and size management using bitsdojo_window
///
/// Saves and restores window geometry using app.settings['desktopWindowPos']
/// Format: "x;y;width;height" (e.g., "100;100;800;600")
///
/// Usage:
/// ```dart
/// // In main.dart, AFTER runApp():
/// initDesktopWindow(defaultWidth: 800, defaultHeight: 600);
/// // Optional: auto-save position every 10 seconds (captures resize/move)
/// startAutoSaveWindowPosition(intervalSeconds: 10);
/// ```

/// Initialize desktop window management
///
/// Call this in main() AFTER runApp() - bitsdojo_window requirement
/// Automatically restores saved position or uses defaults
///
/// Parameters:
/// - [defaultWidth]: Default window width if no saved position (default: 800)
/// - [defaultHeight]: Default window height if no saved position (default: 600)
/// - [minWidth]: Minimum window width (default: 400)
/// - [minHeight]: Minimum window height (default: 300)
void initDesktopWindow({
  double defaultWidth = 800,
  double defaultHeight = 600,
  double minWidth = 400,
  double minHeight = 300,
}) {
  // Only on desktop platforms
  if (kIsWeb || (Platform.isAndroid || Platform.isIOS)) return;

  doWhenWindowReady(() {
    // Get saved position
    String saved = app.settings['desktopWindowPos'] ?? '';

    Size windowSize;
    Offset? windowPosition;

    if (saved.isNotEmpty) {
      // Parse saved position: "x;y;width;height"
      List<String> parts = saved.split(';');
      if (parts.length == 4) {
        double x = double.tryParse(parts[0]) ?? 100;
        double y = double.tryParse(parts[1]) ?? 100;
        double width = double.tryParse(parts[2]) ?? defaultWidth;
        double height = double.tryParse(parts[3]) ?? defaultHeight;

        // Validate position is visible (prevents off-screen windows)
        if (_isPositionVisible(x, y, width, height)) {
          windowSize = Size(width, height);
          windowPosition = Offset(x, y);
        } else {
          // Position is off-screen (e.g., second monitor disconnected)
          // Use saved size but center window
          windowSize = Size(width, height);
          windowPosition = null; // Will center
        }
      } else {
        // Invalid format - use defaults
        windowSize = Size(defaultWidth, defaultHeight);
      }
    } else {
      // No saved position - use defaults
      windowSize = Size(defaultWidth, defaultHeight);
    }

    // Set minimum size
    appWindow.minSize = Size(minWidth, minHeight);

    // Set size
    appWindow.size = windowSize;

    // Set position if we have one
    if (windowPosition != null) {
      appWindow.position = windowPosition;
    } else {
      // Center window on first run
      appWindow.alignment = Alignment.center;
    }

    // Show window
    appWindow.show();

  });
}

/// Save window position manually (call before exit or periodically)
///
/// Call this in your exit handler or from a WidgetsBindingObserver
Future<void> saveDesktopWindowPosition() async {
  if (kIsWeb || (Platform.isAndroid || Platform.isIOS)) return;
  await _saveWindowPosition();
}

/// Start auto-save timer (optional - saves position every N seconds)
///
/// Useful to capture window resizing/moving in real-time
/// Call this after initDesktopWindow() if you want periodic saves
///
/// Parameters:
/// - [intervalSeconds]: How often to save (default: 10 seconds)
void startAutoSaveWindowPosition({int intervalSeconds = 10}) {
  if (kIsWeb || (Platform.isAndroid || Platform.isIOS)) return;

  // Periodic save
  Stream.periodic(Duration(seconds: intervalSeconds)).listen((_) {
    _saveWindowPosition();
  });
}

/// Save current window position and size to settings
Future<void> _saveWindowPosition() async {
  try {
    Rect bounds = appWindow.rect;

    // Don't save if dimensions are invalid (window minimized or bad state)
    if (bounds.width < 100 || bounds.height < 100) return;

    // Don't save if position is completely off-screen
    if (!_isPositionVisible(bounds.left, bounds.top, bounds.width, bounds.height)) return;

    // Format: "x;y;width;height"
    String posString = '${bounds.left};${bounds.top};${bounds.width};${bounds.height}';

    app.settings['desktopWindowPos'] = posString;
    app.saveSettings();
  } catch (e) {
    // Silent failure - not critical
  }
}

/// Check if window position would be visible on screen
///
/// Returns true if at least 100x100 pixels would be visible
/// This prevents windows from being completely off-screen
bool _isPositionVisible(double x, double y, double width, double height) {
  try {
    // Get screen bounds from dart:ui
    final view = PlatformDispatcher.instance.views.first;
    final screenWidth = view.physicalSize.width / view.devicePixelRatio;
    final screenHeight = view.physicalSize.height / view.devicePixelRatio;

    // Check if at least 100x100 pixels are visible
    final windowRight = x + width;
    final windowBottom = y + height;

    final visibleWidth = (windowRight.clamp(0, screenWidth) - x.clamp(0, screenWidth)).clamp(0, width);
    final visibleHeight = (windowBottom.clamp(0, screenHeight) - y.clamp(0, screenHeight)).clamp(0, height);

    return visibleWidth >= 100 && visibleHeight >= 100;
  } catch (e) {
    // Error checking - assume valid (safe fallback)
    return true;
  }
}
