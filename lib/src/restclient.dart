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
import '../i18n/strings.g.dart' as ml;

/// REST client for data transfer operations
/// Configurable class suitable for myapplib with default behaviors
class RestClient {
  // HTTP client and connection state
  http.Client client = http.Client();
  String address = '';  // Empty = not determined yet, will be set on first request
  String token = '';
  String errorMessage = "Ok";
  String comPath = '';
  BuildContext? context;

  // Server configuration parameters (final, set in constructor)
  final String server;
  final int port;
  final String user;
  final String password;
  final String folder;
  final String prefix;
  final String apiVersion;

  // Fallback server configuration (optional)
  final String server2;     // Alternative server address (e.g., for WiFi local network)
  final int port2;          // Alternative port (if 0, uses port)
  final double timeout;     // Default timeout in seconds for all requests (0 = use method's timeout)
  final double timeout2;    // Timeout in seconds for fallback attempt (default: 2.0)

  // Other configuration
  final Map<String, String> endpoints;
  final String workPath;
  final SqlDB? database;
  final String archivePath;

  // Internal state for address determination
  late final String _addressPrimary;   // Primary server address
  late final String _addressFallback;  // Fallback server address (if configured)
  late final bool _hasFallback;        // Whether fallback is configured

  // Configurable converters
  String Function(dynamic)? _filenameGenerator;
  String Function(dynamic)? _documentConverter;

  /// Constructor
  /// Creates local folders and initializes configuration
  /// [prefix] is optional and will be added between server:port and endpoints
  /// [apiVersion] sets the API version path (default: '/api/v1')
  /// [archivePath] is the folder name for document archive (default: 'documents')
  ///
  /// Timeout configuration (optional):
  /// [timeout] default timeout in seconds for all requests (0 = use method's default)
  /// [timeout2] timeout in seconds for fallback attempts (default: 2.0s)
  /// Supports fractional values (e.g., 0.5, 1.5, 2.5)
  ///
  /// Fallback configuration (optional):
  /// [server2] alternative server address (e.g., local WiFi network address)
  /// [port2] alternative port (if empty but server2 set, uses primary port)
  ///
  /// Fallback logic:
  /// - If server2 is empty but port2 > 0: uses same server, different port
  /// - If server2 is set: uses server2 with port2 (or port if port2=0)
  /// - First tries fallback with timeout2, then primary with timeout (or method's default)
  ///
  /// Example: server="http://example.com", port=5000, prefix="local"
  /// Results in: http://example.com:5000/local/api/v1/token
  RestClient({
    required this.server,
    required this.port,
    required this.user,
    required this.password,
    required this.folder,
    this.prefix = '',
    this.apiVersion = '/api/v1',
    this.context,
    this.endpoints = const {
      'token': '/token',
      'download': '/download_auto',
      'upload': '/upload'
    },
    this.workPath = '',
    this.database,
    this.archivePath = 'documents',
    // Timeout parameters
    this.timeout = 0.0,
    this.timeout2 = 2.0,
    // Fallback parameters
    this.server2 = '',
    this.port2 = 0,
  }) {
    comPath = workPath.isEmpty ? '${app.extDir}/data/' : workPath;
    Directory(comPath).create(recursive: true);

    // Calculate primary and fallback addresses, but don't set address yet
    // address will be determined on first request (primary or fallback)
    _addressPrimary = RestClient.getAddress(server, port, prefix);

    // Initialize fallback configuration
    _hasFallback = server2.isNotEmpty || port2 > 0;
    if (_hasFallback) {
      // Use server2 if provided, otherwise use primary server
      String fallbackServer = server2.isNotEmpty ? server2 : server;
      // Use port2 if provided, otherwise use primary port
      int fallbackPort = port2 > 0 ? port2 : port;
      _addressFallback = RestClient.getAddress(fallbackServer, fallbackPort, prefix);
    } else {
      _addressFallback = '';
    }

    // Note: address remains empty until first request determines which to use
  }

  /// Build server address with port and optional prefix
  /// Can be used as static utility or from instance
  /// Returns formatted address string for API endpoints
  /// Omits standard ports (80 for HTTP, 443 for HTTPS)
  static String getAddress(String server, int port, String prefix) {
    String address = server;
    if (port != 0 && port != 80 && port != 443) {
      address = "$address:$port";
    }
    if (prefix.isNotEmpty) {
      String p = prefix.startsWith('/') ? prefix : '/$prefix';
      if (p.endsWith('/')) {
        p = p.substring(0, p.length - 1);
      }
      address = "$address$p";
    }
    return address;
  }

  /// Test server status endpoint (no authentication required)
  /// Returns status response map on success, null on failure
  /// Uses automatic fallback if configured
  Future<Map<String, dynamic>?> testStatus({int timeout = 5}) async {
    try {
      return await get(
        'status',
        requiresAuth: false,
        timeout: timeout,
      );
    } catch (e) {
      return null;
    }
  }

  /// Test complete connection including status and authentication
  /// Returns result string with test results for display
  /// Uses automatic fallback if configured
  Future<String> testConnection() async {
    String result = "";

    // Test 1: Status endpoint
    result += "${ml.t.checkingServer}\n";
    var status = await testStatus();

    if (status != null) {
      result += "- ${ml.t.serverOnlineVersion(version: status['version'])}\n\n";
    } else {
      return "- ${ml.t.cannotConnectToServer}";
    }

    // Test 2: Authentication
    try {
      result += "${ml.t.testingCredentials}\n";
      if (await getToken()) {
        result += "- ${ml.t.authenticationSuccessful}";
      } else {
        result += "- $errorMessage";
      }
    } catch (e) {
      result += "- ${ml.t.authError(error: e.toString())}";
    }

    return result;
  }

  /// Set custom filename generator
  void setFilenameGenerator(String Function(dynamic) generator) {
    _filenameGenerator = generator;
  }

  /// Set custom document converter
  void setDocumentConverter(String Function(dynamic) converter) {
    _documentConverter = converter;
  }

  /// Reset active address to force re-detection on next request
  ///
  /// Useful when network conditions change (e.g., switching from WiFi to mobile data)
  /// Next request will re-test fallback server if configured
  void resetActiveAddress() {
    address = '';  // Empty triggers re-detection on next request
  }

  /// Show alert if context is available
  Future<void> alert(error) async {
    errorMessage = error;
    if (context != null) {
      await alertBox(context!, text: errorMessage);
    }
  }

  /// Generic GET request with optional authentication
  ///
  /// Endpoint resolution (simple rule):
  /// - Starts with '/' → absolute path, use as-is
  /// - No leading '/'  → relative path, prepend apiVersion
  ///
  /// Examples:
  ///   'inventory'          → /api/v1/inventory
  ///   'status'             → /api/v1/status
  ///   '/inventory'         → /inventory (absolute)
  ///   '/api/v2/new'        → /api/v2/new (absolute)
  ///   '/legacy/endpoint'   → /legacy/endpoint (absolute)
  ///
  /// [queryParams] are added as query string
  /// [requiresAuth] adds Authorization header if true (default: true - secure by default)
  /// Returns parsed JSON response
  ///
  /// Automatically uses fallback server if configured (transparent to caller)
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParams,
    bool requiresAuth = true,
    int timeout = 10,
  }) async {
    // Simple rule: starts with / = absolute, otherwise relative
    String fullEndpoint = endpoint.startsWith('/')
        ? endpoint
        : '$apiVersion/$endpoint';

    // Add query parameters
    if (queryParams != null && queryParams.isNotEmpty) {
      String query = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      fullEndpoint += '?$query';
    }

    // Prepare headers with authentication if required
    Map<String, String>? headers;
    if (requiresAuth) {
      if (token.isEmpty) {
        throw Exception('Authentication required but no token available. Call getToken() first.');
      }
      headers = {'Authorization': 'Bearer $token'};
    }

    // Make request with automatic fallback
    var response = await _requestWithFallback(
      endpoint: fullEndpoint,
      headers: headers,
      method: 'GET',
      methodTimeout: timeout,
    );

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    return json.decode(response.body);
  }

  /// Generic POST request with optional authentication
  ///
  /// Endpoint resolution (simple rule):
  /// - Starts with '/' → absolute path, use as-is
  /// - No leading '/'  → relative path, prepend apiVersion
  ///
  /// Examples:
  ///   'upload'             → /api/v1/upload
  ///   'token'              → /api/v1/token
  ///   '/upload'            → /upload (absolute)
  ///   '/api/v2/new'        → /api/v2/new (absolute)
  ///   '/legacy/endpoint'   → /legacy/endpoint (absolute)
  ///
  /// [body] is sent as form data
  /// [requiresAuth] adds Authorization header if true (default: true - secure by default)
  /// Returns parsed JSON response
  ///
  /// Automatically uses fallback server if configured (transparent to caller)
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
    int timeout = 10,
  }) async {
    // Simple rule: starts with / = absolute, otherwise relative
    String fullEndpoint = endpoint.startsWith('/')
        ? endpoint
        : '$apiVersion/$endpoint';

    // Prepare headers with authentication if required
    Map<String, String>? headers;
    if (requiresAuth) {
      if (token.isEmpty) {
        throw Exception('Authentication required but no token available. Call getToken() first.');
      }
      headers = {'Authorization': 'Bearer $token'};
    }

    // Make request with automatic fallback
    var response = await _requestWithFallback(
      endpoint: fullEndpoint,
      headers: headers,
      method: 'POST',
      body: body,
      methodTimeout: timeout,
    );

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    return json.decode(response.body);
  }

  /// Get authentication token from server
  Future<bool> getToken({timeout = 5}) async {
    try {
      String endPoint = endpoints['token']!;
      Map data = {
        'user': user,
        'password': password,
        'folder': folder,
        'deviceId': app.settings['deviceId'] ?? '',
      };
      var r = await client
          .post(Uri.parse(address + apiVersion + endPoint), body: data)
          .timeout(Duration(seconds: timeout));

      var response = json.decode(r.body);
      if (response['error'] == true) {
        await alert(response['message']);
        return false;
      }

      token = response['token'];
    } catch (e) {
      await alert(ml.t.unableToConnectToServer);
      return false;
    }
    return true;
  }

  /// Import database automatically with backup
  Future<bool> importDbAuto() async {
    if (database == null) {
      await alert(ml.t.noDatabaseConfigured);
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
      var r = await client.post(Uri.parse(address + apiVersion + endPoint), body: data);

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
      await alert(ml.t.errorDownloading(filename: filename, error: e.toString()));
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
      String archiveDir = "${app.extDir}/$archivePath/";
      localFilePath = "$archiveDir$fileName";

      await Directory(archiveDir).create(recursive: true);
      var file = File(localFilePath);
      await saveTextFile(file, jsonContent);
    } catch (e) {
      await alert(ml.t.errorPreparingDocument(filename: fileName, error: e.toString()));
      return false;
    }

    // Upload file to server
    try {
      String endPoint = endpoints['upload']!;
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(address + apiVersion + endPoint),
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
          ml.t.uploadFailed(message: response['message'] ?? ml.t.unknownError),
        );
        return false;
      }

      return true;
    } catch (e) {
      await alert(ml.t.errorUploading(filename: fileName, error: e.toString()));
      return false;
    }
  }

  /// Upload all documents from a Hive box (convenience method)
  Future<bool> uploadAllDocuments(String boxName) async {
    var box = app.hiveBoxes[boxName];
    if (box == null) {
      await alert(ml.t.boxNotFound(boxName: boxName));
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
      await alert(ml.t.boxNotFound(boxName: boxName));
      return false;
    }

    var document = box.get(documentKey);
    if (document == null) {
      await alert(ml.t.documentNotFound(documentKey: documentKey));
      return false;
    }

    bool success = await uploadDocument(document);

    if (success && removeAfterUpload) {
      box.delete(documentKey);
    }

    return success;
  }

  /// Delete all JSON files in the archive directory
  Future<void> deleteDocs() async {
    String path = "${app.extDir}/$archivePath";
    final Directory directory = Directory(path);

    if (!directory.existsSync()) return;

    final List<FileSystemEntity> files = directory.listSync();
    for (final FileSystemEntity file in files) {
      if (file.path.endsWith('.json')) {
        file.delete();
      }
    }
  }

  /// Internal method: determines active server address and makes HTTP request
  ///
  /// On first call (address is empty), if fallback is configured:
  /// 1. Tests fallback with timeout2 (for fast local network)
  /// 2. If fallback succeeds, sets address = fallback for all subsequent requests
  /// 3. If fallback fails, sets address = primary for all subsequent requests
  ///
  /// On subsequent calls (address already set), uses the determined address.
  /// This is transparent to the caller - just returns the successful response.
  ///
  /// [endpoint] the API endpoint path
  /// [headers] HTTP headers (including Authorization if needed)
  /// [method] HTTP method: 'GET' or 'POST'
  /// [body] request body for POST (null for GET)
  /// [methodTimeout] timeout in seconds from the calling method (get/post)
  Future<http.Response> _requestWithFallback({
    required String endpoint,
    required Map<String, String>? headers,
    required String method,
    dynamic body,
    required int methodTimeout,
  }) async {
    // Determine effective timeout: use constructor timeout if set, otherwise method timeout
    double effectiveTimeout = timeout > 0 ? timeout : methodTimeout.toDouble();

    // First call: determine which address to use
    if (address.isEmpty) {
      // If fallback configured, try it first with timeout2
      if (_hasFallback) {
        try {
          String fallbackUrl = _addressFallback + endpoint;
          Uri fallbackUri = Uri.parse(fallbackUrl);

          http.Response response;
          if (method == 'GET') {
            response = await client
                .get(fallbackUri, headers: headers)
                .timeout(Duration(milliseconds: (timeout2 * 1000).round()));
          } else if (method == 'POST') {
            response = await client
                .post(fallbackUri, headers: headers, body: body)
                .timeout(Duration(milliseconds: (timeout2 * 1000).round()));
          } else {
            throw Exception('Unsupported HTTP method: $method');
          }

          // Fallback works! Set address to fallback for all future requests
          address = _addressFallback;
          return response;
        } catch (e) {
          // Fallback failed, will use primary below
        }
      }

      // No fallback or fallback failed: use primary
      address = _addressPrimary;
    }

    // Use the determined address (either just set or from previous call)
    String url = address + endpoint;
    Uri uri = Uri.parse(url);

    http.Response response;
    if (method == 'GET') {
      response = await client
          .get(uri, headers: headers)
          .timeout(Duration(milliseconds: (effectiveTimeout * 1000).round()));
    } else if (method == 'POST') {
      response = await client
          .post(uri, headers: headers, body: body)
          .timeout(Duration(milliseconds: (effectiveTimeout * 1000).round()));
    } else {
      throw Exception('Unsupported HTTP method: $method');
    }

    return response;
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
}
