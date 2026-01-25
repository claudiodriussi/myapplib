import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:myapplib/myapplib.dart';

/// NFC Reader Service for continuous tag reading
///
/// Usage:
/// ```dart
/// final nfcService = NfcReaderService();
/// await nfcService.startContinuousReading((text) {
///   print('Tag read: $text');
/// });
///
/// // When done:
/// await nfcService.stopReading();
/// ```
class NfcReaderService {
  bool _isReading = false;
  bool _isProcessing = false;
  Function(String)? _onTagRead;

  /// Check if NFC is available on device
  Future<bool> isNfcAvailable() async {
    try {
      final availability = await NfcManager.instance.checkAvailability();
      return availability == NfcAvailability.enabled;
    } catch (e) {
      return false;
    }
  }

  /// Start continuous NFC reading
  ///
  /// Uses Reader Mode on Android to suppress system UI completely.
  /// Automatically handles multiple reads without restarting session.
  Future<void> startContinuousReading(Function(String) onTagRead) async {
    if (_isReading) return;

    _onTagRead = onTagRead;
    _isReading = true;
    _isProcessing = false;

    if (Platform.isAndroid) {
      // Android: Use Reader Mode to completely suppress system UI and sounds
      await NfcManagerAndroid.instance.enableReaderMode(
        flags: {
          NfcReaderFlagAndroid.nfcA,
          NfcReaderFlagAndroid.nfcB,
          NfcReaderFlagAndroid.nfcF,
          NfcReaderFlagAndroid.nfcV,
        },
        onTagDiscovered: _handleTagDiscovered,
      );
    } else if (Platform.isIOS) {
      // iOS: Standard session with invalidateAfterFirstRead disabled
      await NfcManager.instance.startSession(
        onDiscovered: _handleTagDiscovered,
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
        invalidateAfterFirstReadIos: false,
      );
    }
  }

  /// Stop continuous reading
  Future<void> stopReading() async {
    if (!_isReading) return;

    _isReading = false;
    _onTagRead = null;
    _isProcessing = false;

    try {
      if (Platform.isAndroid) {
        await NfcManagerAndroid.instance.disableReaderMode();
      } else {
        await NfcManager.instance.stopSession();
      }
    } catch (e) {
      // Ignore errors when stopping
    }
  }

  /// Internal handler for tag discovery
  Future<void> _handleTagDiscovered(NfcTag tag) async {
    // Prevent concurrent processing of same tag
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final text = await _readNdefText(tag);

      if (text != null && text.isNotEmpty && _onTagRead != null) {
        _onTagRead!(text);
      }

      // Small delay to prevent immediate re-read of same tag
      await Future.delayed(const Duration(milliseconds: 800));
    } finally {
      _isProcessing = false;
    }

    // NOTE: Do NOT call stopSession here!
    // Keep session alive for continuous reading
  }

  /// Read NDEF text from tag
  ///
  /// Returns null if tag is empty or not NDEF formatted.
  Future<String?> _readNdefText(NfcTag tag) async {
    try {
      // Get NDEF data (platform-specific)
      NdefMessage? ndefMessage;

      if (Platform.isAndroid) {
        final ndef = NdefAndroid.from(tag);
        ndefMessage = ndef?.cachedNdefMessage;
      } else if (Platform.isIOS) {
        final ndef = NdefIos.from(tag);
        ndefMessage = ndef?.cachedNdefMessage;
      }

      if (ndefMessage == null || ndefMessage.records.isEmpty) {
        return null;
      }

      // Read first record
      final record = ndefMessage.records.first;

      // Check if it's a Well-Known Text record (type 'T')
      if (record.typeNameFormat == TypeNameFormat.wellKnown &&
          record.type.isNotEmpty &&
          record.type[0] == 0x54) {
        // NDEF Text Record format:
        // [0]: Status byte (bit 7: encoding, bits 5-0: language code length)
        // [1..n]: Language code (ISO 639-1)
        // [n+1..]: Text content
        final payload = record.payload;
        if (payload.isNotEmpty) {
          final languageCodeLength = payload[0] & 0x3F;
          final textStart = 1 + languageCodeLength;

          if (payload.length > textStart) {
            return String.fromCharCodes(payload.sublist(textStart));
          }
        }
      }

      // Fallback: try reading raw payload as text
      return String.fromCharCodes(record.payload);
    } catch (e) {
      return null;
    }
  }

  /// Check if currently reading
  bool get isReading => _isReading;
}

/// NFC Writer Page
///
/// Dedicated page for reading and writing NFC tags.
/// Uses Reader Mode pattern.
class NfcWriterPage extends StatefulWidget {
  const NfcWriterPage({super.key});

  @override
  State<NfcWriterPage> createState() => NfcWriterPageState();
}

class NfcWriterPageState extends State<NfcWriterPage> {
  FormGroup fg = FormGroup({
    'tagText': FormControl<String>(value: ''),
  });

  String notify = "Ready - approach tag to read";
  bool isProcessing = false;
  bool isReading = false;

  @override
  void initState() {
    super.initState();
    _startContinuousReading();
  }

  @override
  void dispose() {
    _stopReading();
    super.dispose();
  }

  /// Start continuous NFC reading
  Future<void> _startContinuousReading() async {
    if (isReading) return;

    setState(() {
      isReading = true;
      notify = "Ready - approach tag to read";
    });

    if (Platform.isAndroid) {
      await NfcManagerAndroid.instance.enableReaderMode(
        flags: {
          NfcReaderFlagAndroid.nfcA,
          NfcReaderFlagAndroid.nfcB,
          NfcReaderFlagAndroid.nfcF,
          NfcReaderFlagAndroid.nfcV,
        },
        onTagDiscovered: _onTagDiscovered,
      );
    } else {
      await NfcManager.instance.startSession(
        onDiscovered: _onTagDiscovered,
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
        invalidateAfterFirstReadIos: false,
      );
    }
  }

  /// Stop NFC reading
  Future<void> _stopReading() async {
    if (!isReading) return;

    isReading = false;

    try {
      if (Platform.isAndroid) {
        await NfcManagerAndroid.instance.disableReaderMode();
      } else {
        await NfcManager.instance.stopSession();
      }
    } catch (e) {
      // Ignore errors when stopping
    }
  }

  /// Handle tag discovered (continuous reading mode)
  Future<void> _onTagDiscovered(NfcTag tag) async {
    if (isProcessing) return; // Ignore if writing

    try {
      final text = await _readTagText(tag);

      if (mounted && text != null && text.isNotEmpty) {
        fg.control('tagText').value = text;
        setState(() => notify = "Read: ${text.length} chars");
      }

      // Small delay to prevent immediate re-read
      await Future.delayed(const Duration(milliseconds: 800));
    } catch (e) {
      if (mounted) {
        setState(() => notify = "Error reading: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("NFC Tag Writer"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _form(context),
    );
  }

  Widget _form(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ReactiveForm(
        formGroup: fg,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Text field for tag content
              ReactiveTextField<String>(
                formControlName: 'tagText',
                decoration: inputDecoration('Tag text'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Buttons (only Write and Close - continuous reading is automatic)
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text("Write"),
                    onPressed: isProcessing ? null : _handleWrite,
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.close),
                    label: const Text("Close"),
                    onPressed: isProcessing ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Status container (like DataSync notify)
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  border: Border.all(),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [Expanded(child: Text(notify))],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleWrite() async {
    final text = fg.control('tagText').value?.toString() ?? '';

    // Stop continuous reading temporarily
    await _stopReading();

    setState(() {
      notify = text.isEmpty
          ? "Approach NFC tag to reset..."
          : "Approach NFC tag to write...";
      isProcessing = true;
    });

    try {
      final completer = Completer<bool>();

      if (Platform.isAndroid) {
        // Android: Reader Mode for single write
        await NfcManagerAndroid.instance.enableReaderMode(
          flags: {
            NfcReaderFlagAndroid.nfcA,
            NfcReaderFlagAndroid.nfcB,
            NfcReaderFlagAndroid.nfcF,
            NfcReaderFlagAndroid.nfcV,
          },
          onTagDiscovered: (NfcTag tag) async {
            if (!completer.isCompleted) {
              try {
                final success = await _writeTagText(tag, text);
                completer.complete(success);
              } catch (e) {
                completer.completeError(e);
              } finally {
                await NfcManagerAndroid.instance.disableReaderMode();
              }
            }
          },
        );
      } else {
        // iOS: Standard session for single write
        await NfcManager.instance.startSession(
          onDiscovered: (NfcTag tag) async {
            if (!completer.isCompleted) {
              try {
                final success = await _writeTagText(tag, text);
                completer.complete(success);
              } catch (e) {
                completer.completeError(e);
              } finally {
                await NfcManager.instance.stopSession();
              }
            }
          },
          pollingOptions: {
            NfcPollingOption.iso14443,
            NfcPollingOption.iso15693,
          },
        );
      }

      // Wait for write to complete (with timeout)
      final writeSuccess = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );

      if (mounted) {
        setState(() {
          if (writeSuccess) {
            notify = text.isEmpty
                ? "Tag reset successfully!"
                : "Tag written successfully!";
          } else {
            notify = "Write failed - tag not writable";
          }
          isProcessing = false;
        });

        // Restart continuous reading
        await _startContinuousReading();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          notify = "Error writing: $e";
          isProcessing = false;
        });

        // Restart continuous reading even on error
        await _startContinuousReading();
      }
    }
  }
}

/// Read text from NFC tag (internal helper for dialog)
Future<String?> _readTagText(NfcTag tag) async {
  try {
    // Get NDEF data (platform-specific)
    NdefMessage? ndefMessage;

    if (Platform.isAndroid) {
      final ndef = NdefAndroid.from(tag);
      ndefMessage = ndef?.cachedNdefMessage;
    } else if (Platform.isIOS) {
      final ndef = NdefIos.from(tag);
      ndefMessage = ndef?.cachedNdefMessage;
    }

    if (ndefMessage == null || ndefMessage.records.isEmpty) {
      return null;
    }

    final record = ndefMessage.records.first;

    // Check for Well-Known Text record (type 'T')
    if (record.typeNameFormat == TypeNameFormat.wellKnown &&
        record.type.isNotEmpty &&
        record.type[0] == 0x54) {
      final payload = record.payload;
      if (payload.isNotEmpty) {
        final languageCodeLength = payload[0] & 0x3F;
        final textStart = 1 + languageCodeLength;

        if (payload.length > textStart) {
          return String.fromCharCodes(payload.sublist(textStart));
        }
      }
    }

    // Fallback: raw payload
    return String.fromCharCodes(record.payload);
  } catch (e) {
    return null;
  }
}

/// Write text to NFC tag (internal helper for dialog)
Future<bool> _writeTagText(NfcTag tag, String text) async {
  try {
    final NdefMessage message;

    if (text.isEmpty) {
      // Reset tag: write empty NDEF record
      final emptyRecord = NdefRecord(
        typeNameFormat: TypeNameFormat.empty,
        type: Uint8List(0),
        identifier: Uint8List(0),
        payload: Uint8List(0),
      );
      message = NdefMessage(records: [emptyRecord]);
    } else {
      // Write NDEF Text Record
      final languageCode = 'en';
      final statusByte = languageCode.length; // UTF-8 encoding (bit 7 = 0)

      final textBytes = <int>[
        statusByte,
        ...languageCode.codeUnits,
        ...text.codeUnits,
      ];

      final record = NdefRecord(
        typeNameFormat: TypeNameFormat.wellKnown,
        type: Uint8List.fromList([0x54]), // 'T' for Text
        identifier: Uint8List(0),
        payload: Uint8List.fromList(textBytes),
      );

      message = NdefMessage(records: [record]);
    }

    // Write to tag (platform-specific)
    if (Platform.isAndroid) {
      final ndef = NdefAndroid.from(tag);
      if (ndef == null || !ndef.isWritable) {
        return false;
      }
      await ndef.writeNdefMessage(message);
      return true;
    } else if (Platform.isIOS) {
      final ndef = NdefIos.from(tag);
      if (ndef == null) {
        return false;
      }
      // iOS doesn't expose isWritable directly, try to write
      await ndef.writeNdef(message);
      return true;
    }

    return false;
  } catch (e) {
    return false;
  }
}
