import 'dart:io';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:myapplib/myapplib.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:reactive_forms/reactive_forms.dart';

// Conditional import: load web factory only on web platform
import 'sqldb_web_stub.dart'
    if (dart.library.js_interop) 'sqldb_web_impl.dart';

// Getter for web database factory (only available on web)
DatabaseFactory? get _webFactory => webDatabaseFactory;

// =============================================================================
// SQLITE DATABASE SYSTEM - Cross-platform SQLite with Query Automation
// =============================================================================
//
// SQLite database management with automatic query generation from reactive
// forms. Supports mobile, desktop, and web platforms.
//
// ## Core Components
//
// ### SqlDB
// Database manager with cross-platform support (mobile/desktop/web).
// - SQL-first schema initialization from assets/*.sql
// - Platform-aware: sqflite (mobile), sqflite_ffi (desktop), IndexedDB (web)
// - Transaction support and batch operations
// - Schema introspection for empty row templates
//
// ### SearchForm
// Automatic query builder from FormGroup with JOIN support.
// - String fields → LIKE UPPER('%value%') (case-insensitive)
// - Other types → exact match (=)
// - Fluent JOIN API for related tables
// - Fields starting with '_' are ignored
//
// ### SearchQuery
// Enhanced SearchForm with quick filters.
// - Dynamic filter activation/deactivation
// - Automatic UI generation with FilterChip widgets
// - Conditional filter visibility
//
// ### IdSearch + IdSearchFld
// Foreign key lookup automation.
// - Resolves IDs to descriptions automatically
// - Updates dependent fields on change
// - Useful for master-detail forms
//
// ## Quick Start
//
// ### 1. Setup Database (All Platforms)
// ```dart
// SqlDB sqldb = SqlDB();
// await sqldb.openDatabase('myapp', idField: 'id');
// // Auto-initializes from assets/myapp.sql (or .sqlite fallback)
// ```
//
// **Web support**: Add to pubspec.yaml:
// ```yaml
// dependencies:
//   sqflite_common_ffi_web: ^0.4.0
// ```
//
// ### 2. Schema Initialization (SQL-first)
// Create `assets/myapp.sql`:
// ```sql
// CREATE TABLE customers (id TEXT PRIMARY KEY, name TEXT);
// INSERT INTO customers VALUES ('C001', 'ACME Corp');
// ```
// Schema is executed on first run. Legacy `.sqlite` files still supported.
//
// ### 3. Basic Operations
// ```dart
// // Find by ID
// Map customer = await sqldb.find('customers', 'C001');
//
// // Direct query (use sqldb.db)
// List orders = await sqldb.db.query('orders',
//   where: 'customer_id = ?', whereArgs: ['C001']
// );
//
// // Clear and populate table in transaction
// await sqldb.clearAndPopulate('products', () async {
//   return await fetchProductsFromAPI();
// });
//
// // Compact database
// await sqldb.vacuum();
// ```
//
// ### 4. SearchForm (Automatic Queries)
// ```dart
// SearchForm search = SearchForm(
//   sqldb: sqldb,
//   table: 'customers',
//   group: FormGroup({'name': FormControl<String>()}),
//   orderBy: 'name',
// );
//
// search.group.control('name').value = 'John';
// await search.query();
// // Executes: SELECT * FROM customers WHERE name LIKE UPPER('%JOHN%')
// ```
//
// ### 5. SearchForm with JOIN
// ```dart
// SearchForm search = SearchForm(...)
//   .join('customer',
//     table: 'customers',
//     on: 'customer_id',
//     select: ['name', 'city'],
//   );
// // Results include: order.*, customer_name, customer_city
// ```
//
// ### 6. SearchQuery (Quick Filters)
// ```dart
// SearchQuery search = SearchQuery(...)
//   .quickFilter('Active', where: 'status = ?', args: () => ['active'])
//   .quickFilter('Recent', where: 'date > ?', args: () => [lastWeek]);
//
// // Build UI
// Widget filters = search.buildQuickFilters();
// ```
//
// ### 7. IdSearch (Foreign Key Lookup)
// ```dart
// IdSearch idSearch = IdSearch(sqldb, orderForm);
// idSearch.add(IdSearchFld('customer_id', 'customers',
//   destination: 'customer_name', description: 'name'));
//
// await idSearch.find('customer_id');
// // Auto-fills customer_name from customers table
// ```
//
// ## Force Schema Update
// ```dart
// await sqldb.forceRestoreFromAssets(); // Deletes DB and reloads from assets
// ```
//
// =============================================================================

/// SQLite database manager with cross-platform support
///
/// Handles SQLite databases on both mobile (sqflite) and desktop (sqflite_ffi)
/// platforms. Automatically restores database from assets on first run.
///
/// ## Basic Usage
/// ```dart
/// SqlDB sqldb = SqlDB();
/// await sqldb.openDatabase('/path/to/database.db', idField: 'id');
///
/// // Find record by ID
/// Map customer = await sqldb.find('customers', 'C001');
///
/// // Check if found
/// if (customer.isNotEmpty) {
///   print('Customer: ${customer['name']}');
/// }
/// ```
///
/// ## Assets Pattern
/// Place database file in assets folder and it will be automatically copied
/// on first run:
/// ```dart
/// // pubspec.yaml:
/// // flutter:
/// //   assets:
/// //     - assets/myapp.db
///
/// await sqldb.openDatabase('$documentsPath/myapp.db');
/// // First run: copies from assets/myapp.db
/// // Subsequent runs: uses existing database
/// ```
///
/// ## Batch Operations
/// ```dart
/// // Clear and populate table with transaction
/// await sqldb.clearAndPopulate('products', () async {
///   var response = await http.get(apiUrl);
///   return jsonDecode(response.body);
/// });
///
/// // Compact database
/// await sqldb.vacuum();
/// ```
///
/// ## Empty Row Generation
/// ```dart
/// // Get empty row with default values based on schema
/// Map emptyCustomer = await sqldb.toEmpty('customers');
/// // Returns: {'id': '', 'name': '', 'email': '', 'age': 0, ...}
/// ```
///
/// ## Force Schema Update
/// ```dart
/// // Delete existing DB and restore from assets (updates schema)
/// await sqldb.forceRestoreFromAssets();
/// ```
///
class SqlDB {
  String fileName = '';
  String dbPath = '';
  String dbName = '';
  String idName = 'id'; // default id field name of tables
  Map emptyRows = {};
  DatabaseFactory? _customFactory; // optional custom database factory

  var db;

  /// Private helper to open web database with onCreate callback
  Future<void> _openWebDatabase(String dbFileName, String baseName) async {
    db = await _customFactory!.openDatabase(
      dbFileName,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await _loadSchemaFromSQL(db, baseName);
        },
      ),
    );
  }

  /// Open database with automatic platform detection (recommended)
  ///
  /// This is the standard method for opening databases. It automatically handles
  /// platform differences and provides SQL-first schema initialization.
  ///
  /// The database name will be automatically adjusted for each platform:
  /// - Web: uses simple name (e.g., 'myapp.db') for IndexedDB
  /// - Mobile/Desktop: uses full path with .sqlite extension
  ///
  /// Schema initialization (SQL-first):
  /// - Looks for a .sql file in assets (e.g., assets/myapp.sql)
  /// - If found, creates empty database and executes SQL to create schema
  /// - Fallback: copies .sqlite file from assets (legacy compatibility)
  ///
  /// Usage:
  /// ```dart
  /// // All platforms (mobile/desktop/web)
  /// await sqldb.openDatabase('myapp');
  /// ```
  ///
  /// Web support:
  /// To enable web support, add sqflite_common_ffi_web to your app's pubspec.yaml:
  /// ```yaml
  /// dependencies:
  ///   sqflite_common_ffi_web: ^0.4.0
  /// ```
  /// No code changes needed - web support is automatic when dependency is present.
  ///
  /// Parameters:
  /// - [baseName]: Base name of database (without extension)
  /// - [idField]: Name of ID field in tables (default: 'id')
  ///
  /// Assets needed:
  /// - assets/[baseName].sql (schema SQL file) - PREFERRED
  /// - assets/[baseName].sqlite (legacy fallback)
  ///
  /// For advanced usage with custom paths or factories, use [openDatabaseCustom].
  Future<void> openDatabase(
    String baseName, {
    String? idField,
  }) async {
    if (idField != null) idName = idField;

    if (app.isWeb()) {
      // Web platform - use automatic web factory
      _customFactory = _webFactory;
      final dbFileName = baseName.endsWith('.db') ? baseName : '$baseName.db';

      // Open with onCreate callback for schema initialization
      await _openWebDatabase(dbFileName, baseName);

      fileName = dbFileName;
      dbPath = '/web';
      dbName = dbFileName;

    } else {
      // Mobile/Desktop platform
      final dbFileName = baseName.endsWith('.sqlite') ? baseName : '$baseName.sqlite';
      final dbFullPath = '${app.extDir}/db/$dbFileName';

      // Use standard openDatabaseCustom with SQL-first support
      await openDatabaseCustom(dbFullPath, idField: idField);
    }
  }

  /// Open database with custom path or factory (advanced usage)
  ///
  /// Use this method when you need custom control over database location or factory.
  /// For standard usage, prefer [openDatabase] instead.
  ///
  /// If [factory] is provided, it will be used instead of the default platform factory.
  /// This allows using custom factories like databaseFactoryFfiWeb for web support.
  ///
  /// Note: On web platforms, database files cannot be copied from assets since
  /// IndexedDB is used. Instead, a schema.sql file from assets will be executed
  /// if the database is empty. Name the schema file to match your database
  /// (e.g., myapp.sqlite -> myapp.sql or use schema.sql as default).
  Future<void> openDatabaseCustom(String fileName, {String? idField, DatabaseFactory? factory}) async {
    dbPath = dirname(fileName);
    dbName = basename(fileName);
    this.fileName = fileName;
    if (idField != null) idName = idField;

    if (factory != null) {
      // Use custom factory (e.g., databaseFactoryFfiWeb for web)
      _customFactory = factory;

      if (app.isWeb()) {
        // Web: Use onCreate callback to initialize schema from assets
        await _openWebDatabase(fileName, dbName.replaceAll('.db', '').replaceAll('.sqlite', ''));
      } else {
        // Other platforms with custom factory
        db = await _customFactory!.openDatabase(fileName);
      }
    } else if (app.isMobile()) {
      // Mobile: use sqflite
      await checkAssets(fileName);
      db = await sqflite.openDatabase(fileName);
    } else {
      // Desktop: use sqflite_ffi
      await checkAssets(fileName);
      db = await databaseFactoryFfi.openDatabase(fileName);
    }
  }

  /// if database file doesn't exist, copy demo data from assets (unified for mobile/desktop)
  /// SQL-first: Tries to load .sql schema first, fallback to .sqlite file
  Future<void> checkAssets(fileName) async {
    // Check if database exists (platform-specific)
    bool exists;
    if (app.isMobile()) {
      exists = await sqflite.databaseExists(fileName);
    } else {
      exists = await File(fileName).exists();
    }

    if (!exists) {
      try {
        await Directory(dirname(fileName)).create(recursive: true);
      } catch (_) {}

      // SQL-first approach: try .sql file first
      String sqlFileName = dbName.replaceAll('.sqlite', '.sql').replaceAll('.db', '.sql');
      bool sqlExists = false;

      try {
        await rootBundle.loadString(join("assets", sqlFileName));
        sqlExists = true;
      } catch (_) {
        // SQL file doesn't exist, will try .sqlite file
      }

      if (sqlExists) {
        // Create empty database and initialize from SQL (platform-specific)
        dynamic tempDb;
        if (app.isMobile()) {
          tempDb = await sqflite.openDatabase(fileName);
        } else {
          tempDb = await databaseFactoryFfi.openDatabase(fileName);
        }
        await _loadSchemaFromSQL(tempDb, dbName.replaceAll('.sqlite', '').replaceAll('.db', ''));
        await tempDb.close();
      } else {
        // Fallback: copy .sqlite file from assets (legacy)
        ByteData data = await rootBundle.load(join("assets", dbName));
        List<int> bytes =
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await File(fileName).writeAsBytes(bytes, flush: true);
      }
    }
  }

  /// Loads and executes SQL schema and data from assets
  /// Unified method for all platforms (web, mobile, desktop)
  ///
  /// Executes ALL SQL statements in the file, including:
  /// - CREATE TABLE (schema definition)
  /// - INSERT INTO (demo/initial data)
  /// - CREATE INDEX (indexes)
  /// - Any other valid SQL statements
  ///
  /// SQL file format example (assets/myapp.sql):
  /// ```sql
  /// -- Create tables
  /// CREATE TABLE users (
  ///   id INTEGER PRIMARY KEY,
  ///   name TEXT NOT NULL
  /// );
  ///
  /// -- Insert demo data
  /// INSERT INTO users (id, name) VALUES (1, 'Admin');
  /// INSERT INTO users (id, name) VALUES (2, 'User');
  /// ```
  ///
  /// [db]: Database instance to execute SQL on
  /// [baseName]: Base name of database (without extension) to find matching .sql file
  Future<void> _loadSchemaFromSQL(dynamic db, String baseName) async {
    try {
      // Determine schema file name
      String schemaName = '$baseName.sql';

      try {
        String schemaSQL = await rootBundle.loadString(join("assets", schemaName));

        // Execute each SQL statement (CREATE, INSERT, etc.)
        // Split only on semicolons at end of line (allows ; inside string values)
        List<String> statements = schemaSQL
            .split(RegExp(r';\s*$', multiLine: true))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty && !s.startsWith('--'))  // Skip empty and comments
            .toList();

        int creates = 0, inserts = 0, others = 0;

        for (String statement in statements) {
          try {
            await db.execute(statement);

            // Count statement types
            String stmtUpper = statement.toUpperCase();
            if (stmtUpper.startsWith('CREATE')) {
              creates++;
            } else if (stmtUpper.startsWith('INSERT')) {
              inserts++;
            } else {
              others++;
            }
          } catch (e) {
            // Error executing statement - skip
          }
        }
      } catch (e) {
        // Could not load schema from assets
      }
    } catch (e) {
      // Error loading database
    }
  }

  /// Forces database restoration from assets even if it already exists
  /// Useful for updating the database schema
  ///
  /// On web: Deletes the database from IndexedDB and recreates it from schema.sql
  /// On mobile/desktop: Deletes the database file and copies it from assets
  Future<void> forceRestoreFromAssets() async {
    await db.close();

    if (app.isWeb()) {
      // Web: Delete database from IndexedDB
      if (_customFactory != null) {
        try {
          await _customFactory!.deleteDatabase(fileName);
        } catch (e) {
          // Error deleting web database
        }
      }
    } else {
      // Mobile/Desktop: Delete physical file
      var file = File(fileName);
      if (await file.exists()) {
        await file.delete();
      }
    }

    // Reopen database (will restore from assets automatically)
    await openDatabaseCustom(fileName, idField: idName, factory: _customFactory);
  }

  /// find the row with the given id.
  ///
  /// [idField] is optional, if not given uses the default one. If the key
  /// value is not found the optional parameter [empty] let choose to return an
  /// empty map or a row with empty values, the second can be used when is
  /// acceptable to have a result with empty values.
  ///
  Future<Map<String, Object?>> find(String table, dynamic value,
      {String? idField, bool empty = false}) async {
    List q;
    idField ??= idName;
    q = await db.query(table,
        where: "$table.$idField = ?", whereArgs: [value], limit: 1);
    if (q.isEmpty) return empty ? await toEmpty(table) : {};
    return q.first;
  }

  /// return an empty row for the [table].
  ///
  /// the empty rows of tables are stored in the emptyRows variable which is
  /// populated on demand.
  ///
  Future<Map<String, Object?>> toEmpty(String table) async {
    if (emptyRows.containsKey(table)) return emptyRows[table];
    // https://stackoverflow.com/questions/66897013/sqlite-how-to-return-the-output-of-pragma-table-info-in-a-pandas-dataframe
    var sk = await await db.rawQuery("PRAGMA table_info('$table')");
    Map<String, Object?> result = {};
    for (Map row in sk) {
      switch (row['type']) {
        case 'INTEGER':
          result[row['name']] = 0;
          break;
        case 'REAL':
          result[row['name']] = 0.0;
          break;
        default:
          result[row['name']] = '';
      }
    }
    emptyRows[table] = result;
    return result;
  }

  /// replace db with the given one the old db is copied to a *.old file
  ///
  Future<void> copyDB(String newFile) async {
    await db.close();
    File f = File(fileName);
    await f.copy("$fileName.old");
    f = File(newFile);
    await f.copy(fileName);
    await openDatabase(dbName);
  }

  /// Clear a table and repopulate it with data from a callback function
  ///
  /// [table] is the table name to clear and populate
  /// [dataProvider] is a callback function that returns a List of Maps with the data to insert
  /// The function is executed within a transaction for data integrity
  ///
  /// Example:
  /// ```dart
  /// await sqldb.clearAndPopulate('utenti', () async {
  ///   var response = await http.get(Uri.parse('$server/api/utenti'));
  ///   return jsonDecode(response.body);
  /// });
  /// ```
  ///
  Future<void> clearAndPopulate(
    String table,
    Future<List<Map<String, dynamic>>> Function() dataProvider,
  ) async {
    await db.transaction((txn) async {
      // Clear table
      await txn.delete(table);

      // Get data from provider
      List<Map<String, dynamic>> data = await dataProvider();

      // Insert all records
      for (var record in data) {
        await txn.insert(table, record);
      }
    });
  }

  /// Compact the database using VACUUM command
  ///
  /// This reclaims unused space and optimizes the database file.
  /// Should be called periodically to keep the database file size under control.
  /// Note: VACUUM cannot be run inside a transaction.
  ///
  Future<void> vacuum() async {
    await db.execute('VACUUM');
  }
}

/// JOIN configuration class
class _JoinDef {
  final String table, on, type;
  final List<String> select;
  _JoinDef(this.table, this.on, this.type, this.select);
}

/// Quick filter configuration class
class _QuickFilter {
  final String where;
  final List<dynamic> Function()? args;
  final bool Function()? condition;
  final String? icon;
  _QuickFilter(this.where, this.args, this.condition, this.icon);
}

/// Automatic query builder from FormGroup with JOIN support
///
/// SearchForm maps FormGroup field values to SQL WHERE conditions automatically:
/// - String fields → `LIKE UPPER('%value%')` (case-insensitive partial match)
/// - Other types → `= value` (exact match)
/// - Fields starting with '_' → ignored (use for UI-only fields)
///
/// ## Basic Usage
/// ```dart
/// // Create search form
/// SearchForm searchCustomers = SearchForm(
///   sqldb: sqldb,
///   table: 'customers',
///   group: FormGroup({
///     'name': FormControl<String>(),
///     'city': FormControl<String>(),
///     'age': FormControl<int>(),
///   }),
///   orderBy: 'name',
/// );
///
/// // Query all customers (empty form)
/// await searchCustomers.query();
/// // SQL: SELECT * FROM customers ORDER BY name
///
/// // User searches for "John" in "Rome"
/// searchCustomers.group.control('name').value = 'John';
/// searchCustomers.group.control('city').value = 'Rome';
/// await searchCustomers.query();
/// // SQL: SELECT * FROM customers
/// //      WHERE name LIKE UPPER('%JOHN%')
/// //        AND city LIKE UPPER('%ROME%')
/// //      ORDER BY name
///
/// // Use results in ListView
/// ListView.builder(
///   itemCount: searchCustomers.q.length,
///   itemBuilder: (context, index) {
///     Map customer = searchCustomers.q[index];
///     return ListTile(title: Text(customer['name']));
///   },
/// )
/// ```
///
/// ## JOIN Support
/// ```dart
/// // Search orders with customer information
/// SearchForm searchOrders = SearchForm(
///   sqldb: sqldb,
///   table: 'orders',
///   group: FormGroup({
///     'order_number': FormControl<String>(),
///   }),
/// ).join('customer',
///   table: 'customers',
///   on: 'customer_id',  // orders.customer_id = customers.id
///   select: ['name', 'email'],
/// );
///
/// await searchOrders.query();
/// // Results include: all order fields + customer_name, customer_email
/// // Access joined fields: row['customer_name'], row['customer_email']
/// ```
///
/// ## Multiple JOINs
/// ```dart
/// SearchForm searchInvoices = SearchForm(
///   sqldb: sqldb,
///   table: 'invoices',
///   group: FormGroup({'invoice_number': FormControl<String>()}),
/// )
/// .join('customer', table: 'customers', on: 'customer_id', select: ['name'])
/// .join('product', table: 'products', on: 'product_id', select: ['description']);
/// ```
///
/// ## Progressive Search
/// ```dart
/// // Auto-query when user types 3+ characters
/// ReactiveTextField(
///   formControlName: 'name',
///   onChanged: (control) async {
///     await searchCustomers.search('name', numChars: 3);
///   },
/// )
/// ```
///
/// ## Lookup Mode Pattern (isSearch/result)
/// Use SearchForm as a lookup dialog to let users pick a record:
///
/// ```dart
/// // 1. Setup SearchForm
/// SearchForm searchCustomers = SearchForm(
///   sqldb: sqldb,
///   table: 'customers',
///   group: FormGroup({'name': FormControl<String>()}),
/// );
/// searchCustomers.isSearch = true; // Enable lookup mode
///
/// // 2. Show in dialog/screen
/// await Navigator.push(context,
///   MaterialPageRoute(builder: (_) => CustomerPickerScreen())
/// );
///
/// // 3. In ListView, add selection button
/// ListView.builder(
///   itemCount: searchCustomers.q.length,
///   itemBuilder: (context, index) {
///     Map customer = searchCustomers.q[index];
///     return ListTile(
///       title: Text(customer['name']),
///       trailing: searchCustomers.isSearch
///         ? IconButton(
///             icon: Icon(Icons.check),
///             onPressed: () {
///               // Store selected ID in result and pop
///               searchCustomers.found(context, customer['id']);
///             },
///           )
///         : null,
///     );
///   },
/// )
///
/// // 4. After Navigator.pop, check result
/// if (searchCustomers.result != null) {
///   orderForm.control('customer_id').value = searchCustomers.result;
/// }
/// ```
///
/// ## Hidden Fields Pattern
/// ```dart
/// FormGroup({
///   'name': FormControl<String>(),      // Used in WHERE clause
///   '_displayMode': FormControl<String>(), // Ignored by query (UI helper)
/// })
/// ```
///
/// ## Custom WHERE Conditions
/// ```dart
/// // Add custom conditions beyond FormGroup fields
/// await searchCustomers.query(
///   extraWhere: 'created_date > ?',
///   extraArgs: ['2024-01-01'],
/// );
/// // Combined with FormGroup conditions using AND
/// ```
///
class SearchForm with ChangeNotifier {
  SqlDB sqldb;
  String table = '';
  FormGroup group = FormGroup({});
  List<String>? columns;
  String? orderBy;
  int? limit;
  bool isSearch = true;
  dynamic result;
  dynamic q = [];

  // JOIN functionality
  final Map<String, _JoinDef> _joins = {};

  SearchForm(
      {required this.sqldb,
      required this.table,
      required this.group,
      this.columns,
      this.orderBy,
      int? limit}) {
    reset();
  }

  /// set value of a field in the search form group
  void setVal(String key, var value) => group.control(key).value = value;

  /// Add JOIN to query with fluent API
  SearchForm join(
    String alias, {
    required String table,
    required String on,
    String type = 'LEFT',
    List<String>? select,
  }) {
    _joins[alias] = _JoinDef(table, on, type, select ?? []);
    return this;
  }

  /// perform a progressive search.
  /// Once the len of string is almost [numChars] length call the query to
  /// to do an automatic filter, it works only on String data.
  ///
  Future<void> search(key, {numChars = 1}) async {
    if (group.control(key).value.length >= numChars) {
      query();
    }
  }

  /// set default value to [FormGroup] fields.
  ///
  /// all fields not present in [exceptFields] or if its value is [null] are
  /// set to '' (empty string)
  ///
  void reset({List<String>? exceptFields}) {
    formGroupReset(group, exceptFields: exceptFields);
  }

  /// execute the query on values coming from the [FormGroup]
  ///
  Future<List<Map<String, Object?>>> query(
      {String? extraWhere, List<String>? extraArgs}) async {

    if (_joins.isEmpty) {
      // Simple query without JOINs (original logic)
      return _simpleQuery(extraWhere: extraWhere, extraArgs: extraArgs);
    } else {
      // Complex query with JOINs
      return _joinQuery(extraWhere: extraWhere, extraArgs: extraArgs);
    }
  }

  Future<List<Map<String, Object?>>> _simpleQuery({String? extraWhere, List<String>? extraArgs}) async {
    String where = extraWhere ?? '';
    List<String> args = extraArgs ?? [];

    // Build WHERE conditions from FormGroup
    for (String key in group.controls.keys) {
      if (key.startsWith('_')) continue;
      if (group.value[key].runtimeType == String) {
        if (group.value[key] != '') {
          where += where == '' ? '' : ' AND ';
          where += '$table.$key LIKE UPPER(?)';
          args.add('%${(group.value[key].toString()).toUpperCase()}%');
        }
      } else {
        if (group.value[key] != 0) {
          where += where == '' ? '' : ' AND ';
          where += '$table.$key = ?';
          args.add(group.value[key].toString());
        }
      }
    }

    if (where.isEmpty) {
      q = await sqldb.db.query(table, columns: columns, orderBy: orderBy, limit: limit);
    } else {
      q = await sqldb.db.query(table, columns: columns, where: where, whereArgs: args, orderBy: orderBy, limit: limit);
    }

    notifyListeners();
    result = null;
    return q;
  }

  Future<List<Map<String, Object?>>> _joinQuery({String? extraWhere, List<String>? extraArgs}) async {
    String sql = _buildJoinQuery();
    List<String> args = _buildJoinArgs(extraWhere, extraArgs);
    String whereClause = _buildJoinWhereClause();

    if (extraWhere != null && extraWhere.isNotEmpty) {
      if (whereClause.isNotEmpty) {
        whereClause += ' AND $extraWhere';
      } else {
        whereClause = extraWhere;
      }
    }

    if (whereClause.isNotEmpty) {
      sql += ' WHERE $whereClause';
    }

    if (orderBy != null) sql += ' ORDER BY $orderBy';
    if (limit != null) sql += ' LIMIT $limit';

    var rawResult = await sqldb.db.rawQuery(sql, args);
    q = rawResult;
    notifyListeners();
    result = null;
    return rawResult.cast<Map<String, Object?>>();
  }

  String _buildJoinQuery() {
    List<String> selectFields = [];
    selectFields.addAll(columns?.map((c) => '$table.$c') ?? ['$table.*']);

    _joins.forEach((alias, join) {
      for (String field in join.select) {
        selectFields.add('${join.table}.$field as ${alias}_$field');
      }
    });

    String sql = 'SELECT ${selectFields.join(', ')} FROM $table';

    _joins.forEach((alias, join) {
      sql += ' ${join.type} JOIN ${join.table} ON $table.${join.on} = ${join.table}.id';
    });

    return sql;
  }

  List<String> _buildJoinArgs(String? extraWhere, List<String>? extraArgs) {
    List<String> args = extraArgs ?? [];

    // Arguments from FormGroup
    for (String key in group.controls.keys) {
      if (key.startsWith('_')) continue;
      var value = group.value[key];

      if (value is String) {
        if (value.isNotEmpty) {
          args.add('%${value.toUpperCase()}%');
        }
      } else if (value != null && value != 0) {
        args.add(value.toString());
      }
    }

    return args;
  }

  String _buildJoinWhereClause() {
    List<String> conditions = [];

    // Conditions from FormGroup
    for (String key in group.controls.keys) {
      if (key.startsWith('_')) continue;
      var value = group.value[key];
      if (value is String) {
        if (value.isNotEmpty) {
          conditions.add('$table.$key LIKE UPPER(?)');
        }
      } else if (value != null && value != 0) {
        conditions.add('$table.$key = ?');
      }
    }

    return conditions.join(' AND ');
  }

  /// Update query results with custom data and notify listeners
  ///
  /// Use this method when you need to set query results from a custom SQL query
  /// instead of using the standard [query()] method. Automatically resets [result]
  /// and notifies listeners to update the UI.
  void updateResults(List<Map<String, Object?>> newResults) {
    q = newResults;
    result = null;
    notifyListeners();
  }

  /// once a row of the query is selected, the id is put on result field, and
  /// the value of isSearch is put to true which is the default behavior
  void found(context, value) {
    isSearch = true;
    result = value;
    Navigator.pop(context);
  }
}

/// Enhanced search form with quick filters
///
/// Extends [SearchForm] with quick filter management and advanced UI generation.
/// Inherits all JOIN functionality from the parent class.
///
/// Additional features beyond [SearchForm]:
/// - Quick filters with conditional display via [quickFilter()] method
/// - Automatic UI generation for quick filters via [buildQuickFilters()]
/// - Dynamic filter activation/deactivation
///
class SearchQuery extends SearchForm {
  // Quick filters functionality
  final Map<String, _QuickFilter> _quickFilters = {};
  final List<String> _activeFilters = [];

  SearchQuery({
    required SqlDB sqldb,
    required String table,
    required FormGroup group,
    List<String>? columns,
    String? orderBy,
    int? limit,
  }) : super(
    sqldb: sqldb,
    table: table,
    group: group,
    columns: columns,
    orderBy: orderBy,
    limit: limit,
  );

  /// Override join to return SearchQuery instead of SearchForm for fluent API
  @override
  SearchQuery join(String alias, {required String table, required String on, String type = 'LEFT', List<String>? select}) {
    super.join(alias, table: table, on: on, type: type, select: select);
    return this;
  }

  /// Add quick filter button with optional parameters and conditions
  SearchQuery quickFilter(
    String name, {
    required String where,
    List<dynamic> Function()? args,
    bool Function()? condition,
    String? icon,
  }) {
    _quickFilters[name] = _QuickFilter(where, args, condition, icon);
    return this;
  }

  @override
  Future<List<Map<String, Object?>>> query({String? extraWhere, List<String>? extraArgs}) async {
    // Build quick filters WHERE and args
    String quickFiltersWhere = _buildQuickFiltersWhere();
    List<String> quickFiltersArgs = _buildQuickFiltersArgs();

    // Combine with extraWhere
    String combinedWhere = extraWhere ?? '';
    if (quickFiltersWhere.isNotEmpty) {
      if (combinedWhere.isNotEmpty) {
        combinedWhere += ' AND $quickFiltersWhere';
      } else {
        combinedWhere = quickFiltersWhere;
      }
    }

    // Combine args
    List<String> combinedArgs = [...(extraArgs ?? []), ...quickFiltersArgs];

    // Call parent query with combined filters
    return super.query(extraWhere: combinedWhere, extraArgs: combinedArgs);
  }

  String _buildQuickFiltersWhere() {
    List<String> conditions = [];
    for (String filterName in _activeFilters) {
      var filter = _quickFilters[filterName];
      if (filter?.condition?.call() ?? true) {
        conditions.add(filter!.where);
      }
    }
    return conditions.join(' AND ');
  }

  List<String> _buildQuickFiltersArgs() {
    List<String> args = [];
    for (String filterName in _activeFilters) {
      var filter = _quickFilters[filterName];
      if (filter?.condition?.call() ?? true) {
        if (filter!.args != null) {
          args.addAll(filter.args!().map((e) => e.toString()));
        }
      }
    }
    return args;
  }

  /// Toggle quick filter on/off
  void toggleQuickFilter(String name) {
    if (_activeFilters.contains(name)) {
      _activeFilters.remove(name);
    } else {
      _activeFilters.add(name);
    }
    query();
  }

  /// Build quick filters UI widget
  Widget buildQuickFilters() {
    return Wrap(
      spacing: 8,
      children: _quickFilters.entries.map((entry) {
        bool isActive = _activeFilters.contains(entry.key);
        bool canShow = entry.value.condition?.call() ?? true;

        if (!canShow) return const SizedBox.shrink();

        return FilterChip(
          label: Text(entry.key),
          selected: isActive,
          onSelected: (_) => toggleQuickFilter(entry.key),
        );
      }).toList(),
    );
  }

  @override
  void reset({List<String>? exceptFields}) {
    super.reset(exceptFields: exceptFields);
    _activeFilters.clear();
  }
}



/// Foreign key lookup automation system
///
/// Automatically resolves ID fields to descriptions by looking up values in
/// related tables. Useful for master-detail forms where you need to display
/// human-readable descriptions alongside IDs.
///
/// ## Use Case
/// In an order form, when user enters a customer ID, automatically fill the
/// customer name field by looking up the ID in the customers table.
///
/// ## Basic Usage
/// ```dart
/// // Setup form
/// FormGroup orderForm = FormGroup({
///   'customer_id': FormControl<String>(),
///   'customer_name': FormControl<String>(),  // Auto-filled by IdSearch
///   'product_id': FormControl<String>(),
///   'product_name': FormControl<String>(),   // Auto-filled by IdSearch
/// });
///
/// // Create IdSearch instance
/// IdSearch idSearch = IdSearch(sqldb, orderForm, notifier: orderDoc);
///
/// // Add fields to monitor
/// idSearch.add(IdSearchFld(
///   'customer_id',              // FormGroup field to monitor
///   'customers',                // Table to search
///   destination: 'customer_name',  // FormGroup field to fill
///   description: 'name',        // Column to copy from table
/// ));
///
/// idSearch.add(IdSearchFld(
///   'product_id',
///   'products',
///   destination: 'product_name',
///   description: 'description',
/// ));
///
/// // When user enters customer_id
/// orderForm.control('customer_id').value = 'C001';
/// await idSearch.find('customer_id');
/// // orderForm.control('customer_name').value is now 'ACME Corporation'
/// // (automatically retrieved from customers table)
/// ```
///
/// ## Multiple Description Fields
/// ```dart
/// // Combine multiple fields into description
/// idSearch.add(IdSearchFld(
///   'customer_id',
///   'customers',
///   destination: 'customer_info',
///   description: ['name', 'city', 'country'],  // List of fields
/// ));
///
/// await idSearch.find('customer_id');
/// // customer_info = 'ACME Corporation Rome Italy'
/// ```
///
/// ## Integration with ReactiveLookupField
/// ```dart
/// // In UI, use with lookup button
/// ReactiveLookupField(
///   formControlName: 'customer_id',
///   labelText: 'Customer',
///   onLookup: () async {
///     await Navigator.push(context,
///       MaterialPageRoute(builder: (_) => CustomerPickerScreen())
///     );
///     if (searchCustomers.result != null) {
///       orderForm.control('customer_id').value = searchCustomers.result;
///       await idSearch.find('customer_id');  // Auto-fill name
///     }
///   },
/// )
///
/// // Display field shows customer name automatically
/// ReactiveTextField(
///   formControlName: 'customer_name',
///   readOnly: true,  // Auto-filled, not editable
/// )
/// ```
///
/// ## Check if Value Changed
/// ```dart
/// if (idSearch.isChanged('customer_id')) {
///   // Customer was changed, update dependent calculations
/// }
/// ```
///
/// ## Access Full Record
/// ```dart
/// // Get complete record from last find
/// Map customerRecord = idSearch.cur('customer_id');
/// String email = customerRecord['email'];
/// String phone = customerRecord['phone'];
/// ```
///
/// ## Validation Pattern
/// ```dart
/// // Find returns false if ID not found
/// bool found = await idSearch.find('customer_id');
/// if (!found) {
///   // Show error: invalid customer ID
///   await alertBox(context, text: 'Customer not found');
/// }
/// ```
///
class IdSearch {
  late SqlDB sqldb;
  late FormGroup fg;
  late var notifier;
  Map fields = {};

  IdSearch(this.sqldb, this.fg, {this.notifier});

  /// add a [IdSearchFld] into the list of fields to search
  void add(IdSearchFld field) {
    fields[field.id] = field;
  }

  /// search a record into the database for the [IdSearchFld] if passed.
  ///
  /// The field is searched into the [SqlDB] table and stored into the current
  /// record.
  /// Then if the destination FormGroup field is passed, it is filled with the
  /// content of fields passed in the description fields.
  /// At last if the notified class instance is passed, the notifyListeners
  /// method is performed.
  /// Return true if the field was found.
  ///
  Future<bool> find(id) async {
    bool result = true;
    IdSearchFld f = fields[id];
    f.prevId = f.curId;
    f.curValue = await sqldb.find(f.table, fg.control(id).value, empty: true);
    if (f.curValue.isEmpty) {
      result = false;
      f.curValue = sqldb.toEmpty(f.table);
    }
    f.curId = f.curValue[sqldb.idName];
    if (f.destination != null) {
      List dsc;
      if (f.description is String) {
        dsc = [f.description];
      } else {
        dsc = f.description;
      }
      var s = '';
      for (String fld in dsc) {
        s += ' ${toStr(f.curValue[fld])}';
      }
      fg.control(f.destination!).value = s.trim();
    }
    if (notifier != null) notifier.notifyListeners();
    return result;
  }

  /// check if the id of the field is changed since last search
  bool isChanged(id) => fields[id].curId != fields[id].prevId;

  /// returns the value of the last searched [IdSearchFld] field
  Map cur(id) => fields[id].curValue;
}

/// Field configuration for IdSearch
///
/// Defines how an ID field should be resolved to its description.
///
/// ```dart
/// IdSearchFld(
///   'customer_id',              // FormGroup field name
///   'customers',                // Database table
///   destination: 'customer_name',  // Field to update with description
///   description: 'name',        // Column(s) to read from table
/// )
/// ```
///
class IdSearchFld {
  late String id; // id name of field to search into the FormGroup
  late String table; // table name to search into sql db
  late String?
      destination; // optional destination field into FormGroup used to store names coming from table
  dynamic
      description; // String or List of strings containing the fields of table which must be stored in the description field.
  dynamic curId; // the last id searched
  dynamic prevId; // the value present before search
  dynamic curValue; // store the current value of the last record found
  IdSearchFld(
    this.id,
    this.table, {
    this.destination,
    this.description,
  });
}


// ----------------------------------------------------------------------------
// utility
// ----------------------------------------------------------------------------

/// Provide a standard way to get groups of strings from DB to use as popMenu
///
/// Parameters are <sqldb> <tableName>, <group> and <description>. Load popStrings at
/// start of program with:
///   popStrings = await DBPopStrings(sqldb, 'dsc_table', 'group', 'description');
/// then you can get the the lists of your popMenu with:
///   popMenu: popStringsGroup('colors'),
///
Future<Map<String, List<String>>> DBPopStrings(
  SqlDB sqldb,
  String tableName,
  String group,
  String description,
) async {
  Map<String, List<String>> strings = {};

  List q = await sqldb.db.query(tableName);
  for (var row in q) {
    if (!strings.containsKey(row[group])) strings[row[group]] = [];
    strings[row[group]]?.add(row[description]);
  }
  return strings;
}

/// Return a list of strings to be used as popMenu
///
/// strings are contained in a Map which can be loaded from a DB and/or integrated
/// adding static list of strings:
///   popStrings = await DBPopStrings('dsc_table', 'group', 'description');
///   popStrings['colors'] = ['white', 'yellow', 'blue']
/// then use in your widget with:
///   popMenu: popStringsGroup('colors'),
///
List<String>? popStringsGroup(key, popStrings) {
  if (!popStrings.containsKey(key)) return [];
  return popStrings[key];
}

/// Helper function to safely get a popMenu list
///
/// Returns a list with an empty string if the list is null or empty.
/// This ensures inputDecoration always creates a popMenu, allowing
/// search functions with parameters to work correctly.
///
/// Usage:
///   popMenu: getPopMenu(popStrings['ZONE']),
///
List<String> getPopMenu(List<String>? list) {
  if (list == null || list.isEmpty) return [''];
  return list;
}
