import 'dart:io';
import 'package:flutter/material.dart';
import 'package:myapplib/myapplib.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// helper class to handle Sqlite databases.
class SqlDB {
  String fileName = '';
  String dbPath = '';
  String dbName = '';
  String idName = 'id'; // default id field name of tables
  Map emptyRows = {};

  var db;

  /// open database depending on platform
  Future<void> openDatabase(String fileName, {String? idField}) async {
    dbPath = dirname(fileName);
    dbName = basename(fileName);
    this.fileName = fileName;
    if (idField != null) idName = idField;
    if (app.isMobile()) {
      await checkAssets(fileName);
      db = await sqflite.openDatabase(fileName);
    } else {
      db = await databaseFactoryFfi.openDatabase(fileName);
    }
  }

  /// if database file does'nt exists copy demo data from assets
  Future<void> checkAssets(fileName) async {
    var exists = await sqflite.databaseExists(fileName);
    if (!exists) {
      try {
        await Directory(dirname(fileName)).create(recursive: true);
      } catch (_) {}
      ByteData data = await rootBundle.load(join("assets", dbName));
      List<int> bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(fileName).writeAsBytes(bytes, flush: true);
    }
  }

  /// find the row with the given id.
  ///
  /// [idField] is optional, if not given uses the default one. If the key
  /// value is not found the optional parameter [empty] let choose to return an
  /// empty map or a row whith empty values, the second can be used when is
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
    await openDatabase(fileName);
  }
}

/// uses a [FormGroup] to automate queries in a [Database]
///
/// the names of controls of the [FormGroup] must match the names of Database
/// fields, or start with a dot '.' and the type must be String. In this way
/// query can be automated using the "LIKE UPPER(?)" sql clause.
///
/// Fields starting with dot can be used ro give the [extraWhere] clause to the
/// [query()] method.
///
class SearchForm with ChangeNotifier {
  SqlDB sqldb;
  String table = '';
  FormGroup group = FormGroup({});
  List<String>? columns;
  String? orderBy;
  int? limit;
  dynamic result;
  dynamic q = [];

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
    String where = extraWhere ?? '';
    List<String> args = extraArgs ?? [];

    // the keys which starts with a dot '.' are not handled automatically.
    // the strings are searched with like, the other types are searched for
    // equality
    for (String key in group.controls.keys) {
      if (key.startsWith('.')) continue;
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
      q = await sqldb.db
          .query(table, columns: columns, orderBy: orderBy, limit: limit);
    } else {
      q = await sqldb.db.query(table,
          columns: columns,
          where: where,
          whereArgs: args,
          orderBy: orderBy,
          limit: limit);
    }

    notifyListeners();
    result = null;
    return q;
  }
}

// !!! Non serve. posso usare formgroup.rawValue
//
// Map<String, dynamic> formGroup2Map(FormGroup formGroup) {
//   Map<String, dynamic> map = {};
//   for (String key in formGroup.controls.keys) {
//     map[key] = formGroup.control(key).value;
//   }
//   return map;
// }



/*
  OLD NOT WORKING!!!

  // this was the call
  print('wait...');
  var f = File(app.dataDir + '/db/anagrafiche.sql');
  var s = await loadTextFile(f);
  if (s != null) {
    var ok = await sqldb.importSql(s);
  }
  print('done!');

  /// import a whole database from a single string with many sql commands.
  /// nultiline commands are forbidden and each line must contain a single command
  /// ensure that string contain all needed to recreate database.
  ///
  /// the string must be a valid utf-8, and be aware that the execution can be slow
  ///
  Future<bool> importSql(String sql) async {
    String tempFile = "$dbPath/_temp.sqlite";

    // split string into lines and ensure that in not empty
    List<String> commands = sql.split('\n');
    if (commands.isEmpty) {
      return false;
    }

    try {
      File f = File(tempFile);
      await f.delete();
    } catch (e) {
      print(e);
    }

    try {
      await db.close();
      await openDatabase(tempFile);
      for (String command in commands) {
        try {
          await db.execute(command);
        } catch (e) {
          // the line is invalid
        }
      }
      await db.close();
    } catch (e) {
      // if something goes wrong try to reuse the old database
      await db.close();
      await openDatabase(fileName);
      return false;
    }
    try {
      File f = File(tempFile);
      f.copy(fileName);
    } catch (e) {
      await openDatabase(fileName);
      return false;
    }
    // the command succeded
    await openDatabase(fileName);
    return true;
  }

*/
