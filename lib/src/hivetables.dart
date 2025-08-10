import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:reactive_forms/reactive_forms.dart';

import "documents.dart";
import 'appvars.dart';

/// Base class for CRUD operations on Hive-based tables
/// Provides filtering, sorting, and reactive form integration
/// Designed to replace SQLite lookup tables with more flexible Hive storage
abstract class HiveTable extends ChangeNotifier with FormsMixin {
  late String boxName; // Hive box name for this table
  late Box box; // Reference to the Hive box
  late FormGroup dataForm; // Form group defining table schema and default values
  late FormGroup searchForm; // Form group for search/filter operations

  /// Reference indexes to filtered/sorted data (optimization)
  List<int> _filteredIndexes = [];

  /// Current sort field and direction
  String? _sortField;
  bool _sortAscending = true;

  /// Custom sort comparator for complex sorting
  int Function(Map<String, dynamic> a, Map<String, dynamic> b)? _customSortComparator;

  /// Lookup mode flag - when true, behaves like SearchForm for readonly operations
  bool isLookupMode = false;

  HiveTable({required this.boxName});

  /// Helper methods for accessing form controls
  /// Access data form controls: F('fieldname')
  AbstractControl<dynamic> F(String name) => dataForm.control(name);

  /// Access search form controls: S('fieldname')
  AbstractControl<dynamic> S(String name) => searchForm.control(name);

  /// Reset data form to default values (similar to Document pattern)
  /// Can exclude specific fields from reset
  Future<void> resetDataForm({List<String>? exceptFields}) async {
    await resetFormGroup(dataForm, exceptFields: exceptFields);
    // notifyListeners() already called by resetFormGroup
  }

  /// Initialize the HiveTable instance
  Future<void> initialize() async {
    await _initializeBox();
    initializeDataForm();
    initializeSearchForm();
  }

  /// Initialize the Hive box
  Future<void> _initializeBox() async {
    // Add box if it doesn't exist, then get reference
    await app.addBox(boxName);
    box = app.hiveBoxes[boxName]!;
  }

  /// Initialize data form schema - to be implemented by subclasses
  void initializeDataForm();

  /// Initialize search form - cloned from dataForm by default
  /// Can be overridden by subclasses for custom search fields
  void initializeSearchForm() {
    searchForm = cloneFormGroupEmpty(dataForm);
  }

  /// Get all data count
  int get allCount => box.length;

  /// Get filtered data count
  int get filteredCount => _filteredIndexes.length;

  /// Get item directly from box by index
  Map<String, dynamic>? _getBoxItem(int boxIndex) {
    if (boxIndex >= 0 && boxIndex < box.length) {
      final item = box.getAt(boxIndex);
      return item != null ? Map<String, dynamic>.from(item) : null;
    }
    return null;
  }

  /// Get item by filtered index
  Map<String, dynamic>? getFilteredItem(int filteredIndex) {
    if (filteredIndex >= 0 && filteredIndex < _filteredIndexes.length) {
      final boxIndex = _filteredIndexes[filteredIndex];
      return _getBoxItem(boxIndex);
    }
    return null;
  }

  /// Get filtered data (compatibility - lazy evaluation)
  List<Map<String, dynamic>> get filteredData {
    return _filteredIndexes
        .map((index) => _getBoxItem(index))
        .where((item) => item != null)
        .cast<Map<String, dynamic>>()
        .toList();
  }

  /// Get all data as list of maps (compatibility - lazy evaluation)
  List<Map<String, dynamic>> get allData {
    final result = <Map<String, dynamic>>[];
    for (int i = 0; i < box.length; i++) {
      final item = _getBoxItem(i);
      if (item != null) result.add(item);
    }
    return result;
  }

  /// Get current sort configuration
  String? get sortField => _sortField;
  bool get sortAscending => _sortAscending;

  /// Load data and apply filters (optimized - no data duplication)
  void loadData() {
    applyFilters();
  }

  /// Apply current filters and sort to the data (optimized with references)
  void applyFilters() {
    _filteredIndexes.clear();

    // Build list of matching indexes
    for (int i = 0; i < box.length; i++) {
      final item = _getBoxItem(i);
      if (item != null && matchesFilter(item)) {
        _filteredIndexes.add(i);
      }
    }

    // Apply sorting
    _applySorting();

    notifyListeners();
  }

  /// Apply sorting on reference indexes
  void _applySorting() {
    if (_customSortComparator != null) {
      // Custom sorting with comparator
      _filteredIndexes.sort((indexA, indexB) {
        final itemA = _getBoxItem(indexA);
        final itemB = _getBoxItem(indexB);
        if (itemA == null || itemB == null) return 0;
        return _customSortComparator!(itemA, itemB);
      });
    } else if (_sortField != null) {
      // Simple field-based sorting
      _filteredIndexes.sort((indexA, indexB) {
        final itemA = _getBoxItem(indexA);
        final itemB = _getBoxItem(indexB);
        if (itemA == null || itemB == null) return 0;

        final aValue = itemA[_sortField] ?? '';
        final bValue = itemB[_sortField] ?? '';
        final comparison = aValue.toString().compareTo(bValue.toString());
        return _sortAscending ? comparison : -comparison;
      });
    }
  }

  /// Standard filter matching - substring case-insensitive for strings, exact for others
  bool _matchesStandardFilters(Map<String, dynamic> item) {
    for (final entry in searchForm.controls.entries) {
      final fieldName = entry.key;
      final control = entry.value;
      final filterValue = control.value;

      // Skip empty filters
      if (filterValue == null ||
          (filterValue is String && filterValue.isEmpty) ||
          (filterValue is num && filterValue == 0)) {
        continue;
      }

      final itemValue = item[fieldName] ?? '';

      // String: case-insensitive substring search
      if (filterValue is String) {
        if (!itemValue.toString().toLowerCase().contains(filterValue.toLowerCase())) {
          return false;
        }
      }
      // Numbers: exact match
      else if (filterValue is num) {
        if (itemValue != filterValue) {
          return false;
        }
      }
      // Other types: exact matchDelete
      else {
        if (itemValue != filterValue) {
          return false;
        }
      }
    }
    return true;
  }

  /// Check if an item matches current search filters
  /// Override for custom filtering logic, or use standard filters + custom logic
  bool matchesFilter(Map<String, dynamic> item) {
    return _matchesStandardFilters(item);
  }

  /// Set simple sorting by field name
  void setSorting(String field, {bool ascending = true}) {
    _sortField = field;
    _sortAscending = ascending;
    _customSortComparator = null; // Clear custom comparator
    applyFilters();
  }

  /// Set custom sorting with comparator function
  void setCustomSorting(int Function(Map<String, dynamic> a, Map<String, dynamic> b) comparator) {
    _customSortComparator = comparator;
    _sortField = null; // Clear simple sort
    _sortAscending = true;
    applyFilters();
  }

  /// Clear all filters
  void clearFilters() {
    searchForm.reset();
    applyFilters();
  }

  /// Add new item to the table
  Future<void> addItem(Map<String, dynamic> item) async {
    await box.add(item);
    loadData();
  }

  /// Update item at specific box index (use with caution - prefer updateFilteredItem)
  Future<void> updateItem(int index, Map<String, dynamic> item) async {
    await box.putAt(index, item);
    loadData();
  }

  /// Delete item at specific box index (use with caution - prefer deleteFilteredItem)
  Future<void> deleteItem(int index) async {
    await box.deleteAt(index);
    loadData();
  }

  /// Update item by filtered position (recommended)
  Future<void> updateFilteredItem(int filteredIndex, Map<String, dynamic> item) async {
    if (filteredIndex >= 0 && filteredIndex < _filteredIndexes.length) {
      final boxIndex = _filteredIndexes[filteredIndex];
      await box.putAt(boxIndex, item);
      notifyListeners(); // No need to reload, reference still valid
    }
  }

  /// Delete item by filtered position (recommended)
  Future<void> deleteFilteredItem(int filteredIndex) async {
    if (filteredIndex >= 0 && filteredIndex < _filteredIndexes.length) {
      final boxIndex = _filteredIndexes[filteredIndex];
      await box.deleteAt(boxIndex);
      // Rebuild references after deletion (indexes shift)
      applyFilters();
    }
  }

  /// Get item by index in original data
  Map<String, dynamic>? getItem(int index) {
    if (index >= 0 && index < box.length) {
      final item = box.getAt(index);
      return item != null ? Map<String, dynamic>.from(item) : null;
    }
    return null;
  }

  /// Find index in original data by key-value pair
  int findIndex(String key, dynamic value) {
    for (int i = 0; i < box.length; i++) {
      final item = box.getAt(i);
      if (item != null && item[key] == value) {
        return i;
      }
    }
    return -1;
  }

  /// Import data from JSON list (typically from server)
  Future<void> importFromJson(List<dynamic> jsonData) async {
    await box.clear();
    for (final item in jsonData) {
      if (item is Map) {
        await box.add(processImportItem(Map<String, dynamic>.from(item)));
      }
    }
    loadData();
  }

  /// Export all data to JSON list (typically to server)
  List<Map<String, dynamic>> exportToJson() {
    return allData.map((item) => processExportItem(item)).toList();
  }

  /// Process item during import - handle missing fields with defaults from dataForm
  /// Uses assignValue for type conversions (e.g., String to DateTime)
  Map<String, dynamic> processImportItem(Map<String, dynamic> item) {
    final result = <String, dynamic>{};

    // Fill with defaults from dataForm
    for (final entry in dataForm.controls.entries) {
      result[entry.key] = entry.value.value;
    }

    // Override with imported values, using assignValue for type conversions
    for (final entry in item.entries) {
      if (dataForm.controls.containsKey(entry.key)) {
        final control = dataForm.control(entry.key) as FormControl;
        assignValue(control, entry.value);
        result[entry.key] = control.value;
      } else {
        result[entry.key] = entry.value;
      }
    }

    return result;
  }

  /// Process item during export - convert types for JSON serialization
  /// Uses toJsonVar for type conversions (e.g., DateTime to String)
  Map<String, dynamic> processExportItem(Map<String, dynamic> item) {
    final result = <String, dynamic>{};
    item.forEach((key, value) {
      result[key] = toJsonVar(value);
    });
    return result;
  }




  /// Get lookup-style result similar to SearchForm
  /// Returns list of items matching current search
  List<Map<String, dynamic>> getLookupResults() {
    return filteredData;
  }

  /// Lookup mode toggle
  void setLookupMode(bool enabled) {
    isLookupMode = enabled;
    notifyListeners();
  }
}