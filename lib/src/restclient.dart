import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

// Local imports within myapplib
import 'appvars.dart';
import 'documents.dart';
import 'utils.dart';
import 'sqldb.dart';

/// REST client for data transfer operations
/// Configurable class suitable for myapplib with default behaviors
class RestClient {
  http.Client client = http.Client();
  String address = '';
  String token = '';

  String errorMessage = "Ok";
  String comPath = '';
  BuildContext? context;

  // Server configuration parameters
  final String server;
  final int port;
  final String user;
  final String password;
  final String folder;

  final Map<String, String> endpoints;
  final String workPath;
  final SqlDB? database;

  // Configurable converters
  String Function(dynamic)? _filenameGenerator;
  String Function(dynamic)? _documentConverter;

  /// Constructor
  /// Creates local folders and initializes configuration
  RestClient({
    required this.server,
    required this.port,
    required this.user,
    required this.password,
    required this.folder,
    this.context,
    this.endpoints = const {
      'token': '/api/v1/token',
      'download': '/api/v1/download_auto',
      'upload': '/api/v1/upload'
    },
    this.workPath = '',
    this.database,
  }) {
    comPath = workPath.isEmpty ? '${app.extDir}/data/' : workPath;
    Directory(comPath).create(recursive: true);
    address = getAddress();
  }

  /// Set custom filename generator
  void setFilenameGenerator(String Function(dynamic) generator) {
    _filenameGenerator = generator;
  }

  /// Set custom document converter
  void setDocumentConverter(String Function(dynamic) converter) {
    _documentConverter = converter;
  }

  /// Default document converter
  /// Uses Document.toJson() if available, otherwise JsonEncoder with indent and DateTime handling
  String _defaultDocumentConverter(dynamic document) {
    if (document is Document) {
      return document.toJson();
    }
    // For complex generic objects with nested DateTime
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(_prepareForJson(document));
  }

  /// Recursive function to handle DateTime in nested structures
  dynamic _prepareForJson(dynamic obj) {
    if (obj is String || obj is num || obj == null) return obj;
    if (obj is DateTime) return obj.toIso8601String();
    if (obj is Map) {
      return obj.map((key, value) => MapEntry(key, _prepareForJson(value)));
    }
    if (obj is List) {
      return obj.map(_prepareForJson).toList();
    }
    return obj.toString();
  }

  /// Default filename generator
  /// Uses Document class name or provided prefix + timestamp
  String _defaultFilenameGenerator(dynamic document, {String prefix = "DOC"}) {
    // If it's a Document, use class name as prefix
    if (document is Document) {
      prefix = document.runtimeType.toString();
    }
    String timestamp = DateFormat('yyyyMMdd-HHmmss-S').format(DateTime.now());
    return "${prefix}_$timestamp.json";
  }

  /// Compose server address with port
  String getAddress() {
    String address = server;
    if (port != 0 && port != 80) {
      address = "$address:$port";
    }
    return address;
  }

  /// Show alert if context is available
  Future<void> alert(error) async {
    errorMessage = error;
    if (context != null) {
      await alertBox(context!, text: errorMessage);
    }
  }

  /// Get authentication token from server
  Future<bool> getToken({timeout = 5}) async {
    try {
      String endPoint = endpoints['token']!;
      Map data = {
        'user': user,
        'password': password,
        'folder': folder,
      };
      var r = await client
          .post(Uri.parse(address + endPoint), body: data)
          .timeout(Duration(seconds: timeout));

      var response = json.decode(r.body);
      if (response['error'] == true) {
        await alert(response['message']);
        return false;
      }

      token = response['token'];
    } catch (e) {
      await alert("Unable to connect to server!");
      return false;
    }
    return true;
  }

  /// Import database automatically with backup
  Future<bool> importDbAuto() async {
    if (database == null) {
      await alert("No database configured");
      return false;
    }
    SqlDB db = database!;
    String filename = db.dbName;
    
    bool isOk = await downloadFile(filename);
    if (isOk) await db.copyDB('$comPath$filename');
    return isOk;
  }

  /// Download specific file with auto-fallback
  Future<bool> downloadFile(String filename, {String? localPath}) async {
    localPath ??= '$comPath$filename';

    try {
      String endPoint = endpoints['download']!;
      Map data = {'token': token, 'file': filename};
      var r = await client.post(Uri.parse(address + endPoint), body: data);

      // Always check JSON content for API error pattern first
      if (r.headers['content-type']?.startsWith('application/json') == true) {
        try {
          var jsonResponse = json.decode(r.body);

          // Check for API error pattern: {"error": true, "message": "..."}
          if (jsonResponse is Map &&
              jsonResponse.containsKey('error') &&
              jsonResponse['error'] == true &&
              jsonResponse.containsKey('message')) {
            // This is an API error response
            await alert(jsonResponse['message']);
            return false;
          }

          // Valid JSON file (no error pattern) - save it
          File(localPath).writeAsBytes(r.bodyBytes);
          return true;
        } catch (_) {
          // Malformed JSON - treat as binary file
          File(localPath).writeAsBytes(r.bodyBytes);
          return true;
        }
      } else {
        // Non-JSON content - save as binary
        File(localPath).writeAsBytes(r.bodyBytes);
        return true;
      }
    } catch (e) {
      await alert("Error downloading $filename: $e");
      return false;
    }
  }

  /// Download multiple files
  Future<bool> downloadFiles(List<String> filenames) async {
    for (String filename in filenames) {
      if (!await downloadFile(filename)) {
        return false; // Stop on first error
      }
    }
    return true;
  }

  /// Upload single document (core method)
  /// Uses configured or default converters
  Future<bool> uploadDocument(dynamic document) async {
    String fileName = '';
    String localFilePath = '';

    try {
      // Generate filename using configured or default generator
      fileName = (_filenameGenerator ?? _defaultFilenameGenerator)(document);

      // Convert document using configured or default converter  
      String jsonContent = (_documentConverter ?? _defaultDocumentConverter)(document);

      // Save to local archive
      String archivePath = "${app.extDir}/documenti/";
      localFilePath = "$archivePath$fileName";

      await Directory(archivePath).create(recursive: true);
      var file = File(localFilePath);
      await saveTextFile(file, jsonContent);
    } catch (e) {
      await alert("Error preparing document $fileName: $e");
      return false;
    }

    // Upload file to server
    try {
      String endPoint = endpoints['upload']!;
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(address + endPoint),
      );
      request.fields['token'] = token;

      var ct = MediaType('application', 'json');
      var file = await http.MultipartFile.fromPath(
        'file',
        localFilePath,
        contentType: ct,
      );
      request.files.add(file);

      var r = await request.send();

      if (r.statusCode != 200) {
        String responseBody = await r.stream.bytesToString();
        var response = json.decode(responseBody);
        await alert(
          "Upload failed: ${response['message'] ?? 'Unknown error'}",
        );
        return false;
      }

      return true;
    } catch (e) {
      await alert("Error uploading $fileName: $e");
      return false;
    }
  }

  /// Upload all documents from a Hive box (convenience method)
  Future<bool> uploadAllDocuments(String boxName) async {
    var box = app.hiveBoxes[boxName];
    if (box == null) {
      await alert("Box not found: $boxName");
      return false;
    }

    for (var document in box.values) {
      if (!await uploadDocument(document)) {
        return false; // Stop on first error
      }
    }
    return true;
  }

  /// Upload single document by key from Hive box
  Future<bool> uploadDocumentByKey(String boxName, String documentKey, {bool removeAfterUpload = false}) async {
    var box = app.hiveBoxes[boxName];
    if (box == null) {
      await alert("Box not found: $boxName");
      return false;
    }

    var document = box.get(documentKey);
    if (document == null) {
      await alert("Document not found: $documentKey");
      return false;
    }

    bool success = await uploadDocument(document);

    if (success && removeAfterUpload) {
      box.delete(documentKey);
    }

    return success;
  }
}