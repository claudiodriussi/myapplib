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
/// - Proper focus management for calculations and autofocus
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

  /// Separator used between value and description in display mode
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

  /// Called when the field gains focus
  final VoidCallback? onFocus;

  /// Called when the field loses focus
  final VoidCallback? onFocusLost;


  /// Static cache to avoid repeated decoder calls
  static final Map<String, _CacheEntry> _cache = {};

  /// Creates a ReactiveLookupField.
  ///
  /// Either [formControlName] or [formControl] must be provided.
  /// The [decoder] function is called to convert form values to descriptions.
  /// When [enableManualEdit] is true, users can type values directly.
  /// The [separator] is used to separate value and description in display mode.
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
    this.onFocus,
    this.onFocusLost,
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
        onFocus: onFocus,
        onFocusLost: onFocusLost,
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
  final VoidCallback? onFocus;
  final VoidCallback? onFocusLost;

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
    this.onFocus,
    this.onFocusLost,
  });

  @override
  State<_LookupFieldBuilder<T>> createState() => _LookupFieldBuilderState<T>();
}

class _LookupFieldBuilderState<T> extends State<_LookupFieldBuilder<T>> {
  String? _description;
  bool _isLoading = false;
  T? _lastDecodedValue;
  final FocusNode _focusNode = FocusNode();
  late TextEditingController _textController;
  bool _isEditing = false;

  /// Unique cache key for this field instance
  String get _cacheKey => '${widget.field.control.hashCode}_${T.toString()}';

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _loadDescription();
    _updateDisplayText();
    
    // Setup focus listener
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && !_isEditing) {
        // Just gained focus - enter edit mode
        _isEditing = true;
        final value = widget.field.control.value;
        final editText = value?.toString() ?? '';
        
        _textController.value = TextEditingValue(
          text: editText,
          selection: TextSelection.collapsed(offset: editText.length),
        );
        
        widget.onFocus?.call();
      } else if (!_focusNode.hasFocus && _isEditing) {
        // Lost focus - exit edit mode
        _isEditing = false;
        widget.onFocusLost?.call();
        // Forza sempre il reload della descrizione quando esce dall'editing
        _loadDescription(force: true);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  /// Updates the display text based on current state
  void _updateDisplayText() {
    if (!_isEditing) {
      final value = widget.field.control.value;
      String displayText;
      
      if (_description != null && value != null) {
        displayText = '${value}${widget.separator}$_description';
      } else {
        displayText = value?.toString() ?? '';
      }
      
      _textController.value = TextEditingValue(
        text: displayText,
        selection: TextSelection.collapsed(offset: 0),
      );
    }
  }

  /// Loads description from decoder function with caching
  Future<void> _loadDescription({bool force = false}) async {
    if (widget.decoder == null) return;
    
    final value = widget.field.control.value;
    
    // Skip if same value already decoded (unless forced)
    if (!force && value == _lastDecodedValue && _description != null) return;

    // Check cache first
    final cacheEntry = ReactiveLookupField._cache[_cacheKey];
    if (cacheEntry != null &&
        cacheEntry.value == value &&
        DateTime.now().difference(cacheEntry.timestamp).inMinutes < 5) {
      setState(() {
        _description = cacheEntry.description;
        _lastDecodedValue = value;
      });
      _updateDisplayText();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final description = await widget.decoder!(value);
      if (mounted) {
        // Save to cache
        ReactiveLookupField._cache[_cacheKey] = _CacheEntry(value, description);
        
        setState(() {
          _description = description;
          _lastDecodedValue = value;
          _isLoading = false;
        });
        _updateDisplayText();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _description = null;
          _lastDecodedValue = value;
          _isLoading = false;
        });
        _updateDisplayText();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ReactiveValueListenableBuilder<T>(
      formControl: widget.field.control,
      builder: (context, formControl, child) {
        // Reload description if value changed and we're not editing
        if (formControl.value != _lastDecodedValue && !_isEditing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadDescription();
          });
        }

        if (widget.enableManualEdit) {
          return _buildEditableField();
        } else {
          return _buildReadonlyField();
        }
      },
    );
  }

  /// Builds the readonly version with description and lookup button  
  Widget _buildReadonlyField() {
    final control = widget.field.control;
    final value = control.value;
    final displayText = _isLoading
        ? 'Loading...'
        : (_description != null && value != null 
            ? '${value}${widget.separator}$_description'
            : value?.toString() ?? widget.hint ?? 'Not selected');

    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: TextEditingController(text: displayText),
            readOnly: true, // Solo lettura ma mantiene pulsanti attivi
            decoration: widget.decoration ?? 
              inputDecoration(
                widget.labelText ?? '',
                search: widget.onLookup,
              ),
          ),
        ),
      ],
    );
  }

  /// Builds the editable version with description inside the field
  Widget _buildEditableField() {
    final control = widget.field.control as FormControl<T>;

    return Row(
      children: [
        Expanded(
          child: TextFormField(
            focusNode: _focusNode,
            controller: _textController,
            decoration: widget.decoration ?? 
              inputDecoration(
                widget.labelText ?? '',
                search: widget.onLookup,
              ),
            keyboardType: widget.keyboardType ?? 
              (T == int ? TextInputType.number : null),
            autofocus: widget.autofocus,
            textInputAction: widget.textInputAction,
            onEditingComplete: widget.onEditingComplete,
            onChanged: (text) {
              if (_isEditing) {
                // Extract only the value part before separator when editing
                String valueOnly = text;
                final separatorIndex = text.indexOf(widget.separator);
                if (separatorIndex != -1) {
                  valueOnly = text.substring(0, separatorIndex);
                }
                
                // Update the FormControl
                if (T == int) {
                  final intValue = int.tryParse(valueOnly.trim());
                  (control as FormControl<int>).value = intValue;
                } else {
                  (control as FormControl<String>).value = valueOnly;
                }
                
                widget.onChanged?.call(text);
              }
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// ReactiveLookupField2 - Conservative Implementation
// ============================================================================

/// Conservative implementation of lookup field using only stable ReactiveForns APIs
/// This is a fallback version in case ReactiveLookupField breaks with future versions
class ReactiveLookupField2<T> extends StatefulWidget {
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

  /// Separator used between value and description in display mode
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

  /// Called when the text field value changes
  final ValueChanged<String>? onChanged;

  /// Called when the field gains focus
  final VoidCallback? onFocus;

  /// Called when the field loses focus
  final VoidCallback? onFocusLost;

  /// Form control name for reactive forms
  final String? formControlName;

  /// Direct form control reference
  final FormControl<T>? formControl;

  /// Creates a ReactiveLookupField2 - conservative version
  const ReactiveLookupField2({
    Key? key,
    this.formControlName,
    this.formControl,
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
    this.onFocus,
    this.onFocusLost,
  }) : super(key: key);

  @override
  State<ReactiveLookupField2<T>> createState() => _ReactiveLookupField2State<T>();
}

class _ReactiveLookupField2State<T> extends State<ReactiveLookupField2<T>> {
  String? _description;
  T? _lastValue;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    
    // Setup focus listener for callbacks
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        widget.onFocus?.call();
      } else {
        widget.onFocusLost?.call();
        // Note: decoder will be called through onChanged callback
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Get current form control value
  T? _getCurrentValue() {
    if (widget.formControl != null) {
      return widget.formControl!.value;
    }
    // For formControlName, we need to access through ReactiveForm context
    // Conservative approach: return null if we can't easily access the value
    // The decoder will be called through onChanged callback instead
    return null;
  }

  /// Update description when value changes
  Future<void> _updateDescription(T? value) async {
    if (widget.decoder == null || value == _lastValue) return;
    
    _lastValue = value;
    
    try {
      final description = await widget.decoder!(value);
      if (mounted) {
        setState(() {
          _description = description;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _description = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ReactiveValueListenableBuilder<T>(
      formControlName: widget.formControlName,
      formControl: widget.formControl,
      builder: (context, control, child) {
        // Update description when value changes or on first build
        if (control.value != _lastValue) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateDescription(control.value);
          });
        }
        
        return Row(
          children: [
            Expanded(
              child: ReactiveTextField<T>(
                formControlName: widget.formControlName,
                formControl: widget.formControl,
                focusNode: _focusNode,
                readOnly: !widget.enableManualEdit,
                decoration: widget.decoration ?? 
                  inputDecoration(
                    widget.labelText ?? '',
                    search: widget.onLookup,
                  ),
                keyboardType: widget.keyboardType,
                autofocus: widget.autofocus,
                textInputAction: widget.textInputAction,
                onEditingComplete: (_) => widget.onEditingComplete?.call(),
                onChanged: (control) {
                  // Update description when value changes
                  _updateDescription(control.value);
                  // Call user callback
                  if (widget.onChanged != null) {
                    widget.onChanged!(control.value?.toString() ?? '');
                  }
                },
              ),
            ),
            // Display description as separate text widget
            if (_description != null && _description!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                _description!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        );
      },
    );
  }
}