import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'utils.dart';

/// A reactive form field that combines a lookup button with optional manual editing
/// and automatic value decoding for better UX in business applications.
///
/// Features:
/// - Displays decoded descriptions instead of raw codes
/// - Optional manual editing with real-time decoding
/// - Async decoder function support with caching
/// - Customizable separator for display formatting
/// - Full integration with ReactiveForns FormControl
class ReactiveLookupField<T> extends ReactiveFormField<T, T> {
  /// Function to decode the form control value into a human-readable description
  final Future<String?> Function(T? value)? decoder;

  /// Callback when the lookup button is pressed
  final VoidCallback? onLookup;

  /// Whether to enable manual editing of the field value
  final bool enableManualEdit;

  /// Hint text displayed when the field is empty
  final String? hint;

  /// Label text for the field
  final String? labelText;

  /// Separator used between value and description in edit mode
  final String separator;

  /// Input decoration for the text field
  final InputDecoration? decoration;

  /// Keyboard type for the text field
  final TextInputType? keyboardType;

  /// Whether the field should autofocus
  final bool autofocus;

  /// Text input action for the text field
  final TextInputAction? textInputAction;

  /// Called when the user indicates they are done editing
  final VoidCallback? onEditingComplete;

  /// Called when the text field value changes (useful for progressive filtering)
  final ValueChanged<String>? onChanged;

  /// Static cache to avoid repeated decoder calls
  static final Map<String, _CacheEntry> _cache = {};

  /// Creates a ReactiveLookupField.
  ///
  /// Either [formControlName] or [formControl] must be provided.
  /// The [decoder] function is called to convert form values to descriptions.
  /// When [enableManualEdit] is true, users can type values directly.
  /// The [separator] is used to separate value and description in edit mode.
  ReactiveLookupField({
    Key? key,
    String? formControlName,
    FormControl<T>? formControl,
    this.decoder,
    this.onLookup,
    this.enableManualEdit = false,
    this.hint,
    this.labelText,
    this.separator = ' - ',
    this.decoration,
    this.keyboardType,
    this.autofocus = false,
    this.textInputAction,
    this.onEditingComplete,
    this.onChanged,
  }) : super(
    key: key,
    formControl: formControl,
    formControlName: formControlName,
    builder: (field) {
      return _LookupFieldBuilder<T>(
        field: field,
        decoder: decoder,
        onLookup: onLookup,
        enableManualEdit: enableManualEdit,
        hint: hint,
        labelText: labelText,
        separator: separator,
        decoration: decoration,
        keyboardType: keyboardType,
        autofocus: autofocus,
        textInputAction: textInputAction,
        onEditingComplete: onEditingComplete,
        onChanged: onChanged,
      );
    },
  );
}

/// Cache entry for storing decoded values with timestamp
class _CacheEntry {
  final dynamic value;
  final String? description;
  final DateTime timestamp;

  _CacheEntry(this.value, this.description) : timestamp = DateTime.now();
}

/// Internal widget builder for the lookup field functionality
class _LookupFieldBuilder<T> extends StatefulWidget {
  final ReactiveFormFieldState<T, T> field;
  final Future<String?> Function(T? value)? decoder;
  final VoidCallback? onLookup;
  final bool enableManualEdit;
  final String? hint;
  final String? labelText;
  final String separator;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onChanged;

  const _LookupFieldBuilder({
    required this.field,
    this.decoder,
    this.onLookup,
    this.enableManualEdit = false,
    this.hint,
    this.labelText,
    this.separator = ' - ',
    this.decoration,
    this.keyboardType,
    this.autofocus = false,
    this.textInputAction,
    this.onEditingComplete,
    this.onChanged,
  });

  @override
  State<_LookupFieldBuilder<T>> createState() => _LookupFieldBuilderState<T>();
}

class _LookupFieldBuilderState<T> extends State<_LookupFieldBuilder<T>> {
  String? _description;
  bool _isLoading = false;
  T? _lastValue;

  /// Unique cache key for this field instance
  String get _cacheKey => '${widget.field.control.hashCode}_${T.toString()}';

  @override
  void initState() {
    super.initState();
    _updateDescription(widget.field.control.value, force: true);
  }

  /// Updates the description by calling the decoder function
  /// Uses caching to avoid repeated calls for the same value
  Future<void> _updateDescription(T? value, {bool force = false}) async {
    if (widget.decoder == null) return;

    // Check cache first
    final cacheEntry = ReactiveLookupField._cache[_cacheKey];
    if (!force &&
        cacheEntry != null &&
        cacheEntry.value == value &&
        DateTime.now().difference(cacheEntry.timestamp).inMinutes < 5) {
      if (_description != cacheEntry.description) {
        setState(() {
          _description = cacheEntry.description;
          _lastValue = value;
        });
      }
      return;
    }

    // Only decode if value actually changed
    if (!force && value == _lastValue) return;

    // Decode the new value

    setState(() {
      _isLoading = true;
      _lastValue = value;
    });

    try {
      final description = await widget.decoder!(value);
      if (mounted && value == widget.field.control.value) {
        // Save to cache
        ReactiveLookupField._cache[_cacheKey] = _CacheEntry(value, description);

        setState(() {
          _description = description;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _description = null;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ReactiveValueListenableBuilder<T>(
      formControl: widget.field.control,
      builder: (context, formControl, child) {
        // Update description only if value changed
        if (formControl.value != _lastValue) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateDescription(formControl.value);
          });
        }

        final value = formControl.value;
        final displayText = _isLoading
            ? (value?.toString() ?? widget.hint ?? 'Loading...')
            : (_description ?? value?.toString() ?? widget.hint ?? 'Not selected');

        if (widget.enableManualEdit) {
          return _buildEditableField(widget.field.control, displayText);
        } else {
          return _buildReadonlyField(displayText);
        }
      },
    );
  }

  /// Builds the readonly version with description and lookup button
  Widget _buildReadonlyField(String displayText) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: inputDecoration(widget.labelText ?? '').border != null
                ? BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  )
                : null,
            child: Text(
              displayText,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: widget.onLookup,
          tooltip: 'Open lookup',
        ),
      ],
    );
  }

  /// Builds the editable version with combined value/description display
  Widget _buildEditableField(FormControl<T> control, String displayText) {
    // Create combined text for the TextField showing "value - description"
    final combinedText = _description != null && control.value != null
        ? '${control.value}${widget.separator}$_description'
        : control.value?.toString() ?? '';

    final textController = TextEditingController(text: combinedText);

    /// Extracts only the value part when user edits the text
    void onTextChanged(String newText) {
      final separatorIndex = newText.indexOf(widget.separator);
      String valueOnly;

      if (separatorIndex != -1) {
        valueOnly = newText.substring(0, separatorIndex);
      } else {
        valueOnly = newText;
      }

      // Convert to appropriate type and update FormControl
      if (T == int) {
        final intValue = int.tryParse(valueOnly.trim());
        if (intValue != control.value) {
          (control as FormControl<int>).value = intValue;
        }
      } else {
        final stringValue = valueOnly;
        if (stringValue != control.value) {
          (control as FormControl<String>).value = stringValue;
        }
      }

      // Call user's onChanged callback if provided
      widget.onChanged?.call(newText);
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: textController,
            decoration: widget.decoration ?? inputDecoration(
              widget.labelText ?? '',
              search: widget.onLookup,
            ),
            keyboardType: widget.keyboardType ?? (T == int ? TextInputType.number : null),
            autofocus: widget.autofocus,
            textInputAction: widget.textInputAction,
            onEditingComplete: widget.onEditingComplete,
            onChanged: onTextChanged,
          ),
        ),
      ],
    );
  }
}