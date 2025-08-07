import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// barTextBox
///
/// let the user to enter a string. If the app is on mobile platform the field
/// can be read from barcode scanner emulated with the camera.
///
Future<String> barTextBox(
  BuildContext context, {
  String text = 'Enter text',
  String title = '',
  String value = '',
  bool barcode = false,
}) async {
  TextEditingController textFieldController = TextEditingController();
  String result = value;
  textFieldController.text = result;
  IconButton? bars;

  if (barcode) {
    bars = IconButton(
      onPressed: () async {
        // Navigate to scanner page and wait for result
        final scannedValue = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (context) => const BarcodeScannerPage()),
        );

        if (scannedValue != null) {
          textFieldController.text = scannedValue;
          result = scannedValue;
        }
      },
      icon: const Icon(Icons.barcode_reader),
    );
  }

  await showDialog<String>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: textFieldController,
        decoration: InputDecoration(hintText: text, suffixIcon: bars),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        TextButton(
          onPressed: () {
            result = textFieldController.text;
            Navigator.pop(context);
          },
          child: const Text('Ok'),
        ),
      ],
    ),
  );
  return result;
}

// Separate scanner page
class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({Key? key}) : super(key: key);

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}




// class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
//   final MobileScannerController cameraController = MobileScannerController();

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Scan Barcode'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.flash_on),
//             onPressed: () => cameraController.toggleTorch(),
//           ),
//         ],
//       ),
//       body: MobileScanner(
//         controller: cameraController,
//         onDetect: (capture) {
//           if (capture.barcodes.isNotEmpty) {
//             final barcode = capture.barcodes.first.rawValue;
//             if (barcode != null) {
//               Navigator.pop(context, barcode);
//             }
//           }
//         },
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     cameraController.dispose();
//     super.dispose();
//   }
// }


class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final MobileScannerController cameraController = MobileScannerController();
  bool isFlashOn = false;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan Barcode'),
        actions: [
          IconButton(
            icon: Icon(isFlashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleFlash,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera view
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (_isProcessing) return;
              if (capture.barcodes.isNotEmpty) {
                final barcode = capture.barcodes.first.rawValue;
                if (barcode != null) {
                  _isProcessing = true;
                  HapticFeedback.lightImpact();
                  Navigator.pop(context, barcode);
                }
              }
            },
          ),

          // Scanning overlay
          _buildScanningOverlay(),
        ],
      ),
    );
  }

  Widget _buildScanningOverlay() {
    return Container(
      decoration: ShapeDecoration(
        shape: _ScannerOverlay(
          borderColor: Colors.white,
          borderWidth: 3,
          borderLength: 30,
          borderRadius: 12,
          cutOutSize: MediaQuery.of(context).size.width * 0.75,
        ),
      ),
    );
  }

  void _toggleFlash() {
    setState(() => isFlashOn = !isFlashOn);
    cameraController.toggleTorch();
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}

// Simple overlay shape
class _ScannerOverlay extends ShapeBorder {
  const _ScannerOverlay({
    required this.borderColor,
    required this.borderWidth,
    required this.borderLength,
    required this.borderRadius,
    required this.cutOutSize,
  });

  final Color borderColor;
  final double borderWidth;
  final double borderLength;
  final double borderRadius;
  final double cutOutSize;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path path = Path()..addRect(rect);

    final cutOutRect = Rect.fromCenter(
      center: rect.center,
      width: cutOutSize,
      height: cutOutSize,
    );

    path.addRRect(
      RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)),
    );

    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final cutOutRect = Rect.fromCenter(
      center: rect.center,
      width: cutOutSize,
      height: cutOutSize,
    );

    final paint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(rect),
        Path()..addRRect(
          RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)),
        ),
      ),
      paint,
    );

    // Draw corner borders
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    _drawCornerBorders(canvas, cutOutRect, borderPaint);
  }

  void _drawCornerBorders(Canvas canvas, Rect rect, Paint paint) {
    // Top-left corner
    canvas.drawPath(
      Path()
        ..moveTo(rect.left, rect.top + borderLength)
        ..lineTo(rect.left, rect.top + borderRadius)
        ..arcToPoint(
          Offset(rect.left + borderRadius, rect.top),
          radius: Radius.circular(borderRadius),
        )
        ..lineTo(rect.left + borderLength, rect.top),
      paint,
    );

    // Top-right corner
    canvas.drawPath(
      Path()
        ..moveTo(rect.right - borderLength, rect.top)
        ..lineTo(rect.right - borderRadius, rect.top)
        ..arcToPoint(
          Offset(rect.right, rect.top + borderRadius),
          radius: Radius.circular(borderRadius),
        )
        ..lineTo(rect.right, rect.top + borderLength),
      paint,
    );

    // Bottom-left corner
    canvas.drawPath(
      Path()
        ..moveTo(rect.left, rect.bottom - borderLength)
        ..lineTo(rect.left, rect.bottom - borderRadius)
        ..arcToPoint(
          Offset(rect.left + borderRadius, rect.bottom),
          radius: Radius.circular(borderRadius),
          clockwise: false,
        )
        ..lineTo(rect.left + borderLength, rect.bottom),
      paint,
    );

    // Bottom-right corner
    canvas.drawPath(
      Path()
        ..moveTo(rect.right - borderLength, rect.bottom)
        ..lineTo(rect.right - borderRadius, rect.bottom)
        ..arcToPoint(
          Offset(rect.right, rect.bottom - borderRadius),
          radius: Radius.circular(borderRadius),
          clockwise: false,
        )
        ..lineTo(rect.right, rect.bottom - borderLength),
      paint,
    );
  }

  @override
  ShapeBorder scale(double t) => _ScannerOverlay(
    borderColor: borderColor,
    borderWidth: borderWidth,
    borderLength: borderLength,
    borderRadius: borderRadius,
    cutOutSize: cutOutSize,
  );
}
