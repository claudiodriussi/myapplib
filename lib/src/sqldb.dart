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
/// query can be automated using the "LIKE UPPER(?)" sql clause on String
/// fields, and the equal clause on the other fields.
///
/// Fields starting with dot can be used to give the [extraWhere] clause to the
/// [query()] method.
///
/// the result query can be used to popolate a ListView. The field isSearch
/// can be used to say to the ListView if add the button used to chose the row.
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

  /// once a row of the query is selected, the id is put on result field, and
  /// the value of isSearch is put to true which is the default behavior
  void found(context, value) {
    isSearch = true;
    result = value;
    Navigator.pop(context);
  }
}

/// Implements a search system for values inserted into a reactive_forms
/// [FormGroup] using an [SqlDB],
///
/// You have to add an [IdSearchFld] for every field that you would like to
/// search. Then you can call the method find to search the field and once
/// the record is found you can call the method cur to get the map of the
/// found record.
///
/// If you pass a reference to a class capable to notifyListeners, the changes
/// are notified, otherwise you must to do it by yourself.
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
  /// If the value of field in the [FormGroup] is changed, the field is searched
  /// into the [SqlDB] table and stored into the current record.
  /// Then if the destination FormGroup field is passed, it is filled with the
  /// content of fields passed in the description fields.
  /// At last if the notified class instance is passed, the notifyListeners
  /// method is performed.
  /// Return true if the field was changed.
  ///
  Future<bool> find(id) async {
    IdSearchFld f = fields[id];
    if (f.curId == null || f.curId != fg.control(id).value) {
      f.curValue = await sqldb.find(f.table, fg.control(id).value, empty: true);
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
          s += ' ${f.curValue[fld]}';
        }
        fg.control(f.destination!).value = s.trim();
      }
      if (notifier != null) notifier.notifyListeners();
      return true;
    }
    return false;
  }

  /// returns the value of the last searched [IdSearchFld] field
  Map cur(id) => fields[id].curValue;
}

/// this class represents a field used by [IdSearch] class.
///
/// It store all data needed to search a value into a [SqlDB] table.
///
class IdSearchFld {
  late String id; // id name of field to search into the FormGroup
  late String table; // table name to search into sql db
  late String?
      destination; // optional destination field into FormGroup used to store names coming from table
  dynamic
      description; // String or List of strings containing the fields of table which must be stored in the description field.
  dynamic
      curId; // the last id searched used to avoid to search again if it is the same of last search
  dynamic curValue; // store the current value of the last record found
  IdSearchFld(
    this.id,
    this.table, {
    this.destination,
    this.description,
  });
}
