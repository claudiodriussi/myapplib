/// Generated file. Do not edit.
///
/// Original: lib/i18n
/// To regenerate, run: `dart run slang`
///
/// Locales: 2
/// Strings: 66 (33 per locale)
///
/// Built on 2026-01-06 at 19:30 UTC

// coverage:ignore-file
// ignore_for_file: type=lint

import 'package:flutter/widgets.dart';
import 'package:slang/builder/model/node.dart';
import 'package:slang_flutter/slang_flutter.dart';
export 'package:slang_flutter/slang_flutter.dart';

const AppLocale _baseLocale = AppLocale.en;

/// Supported locales, see extension methods below.
///
/// Usage:
/// - LocaleSettings.setLocale(AppLocale.en) // set locale
/// - Locale locale = AppLocale.en.flutterLocale // get flutter locale from enum
/// - if (LocaleSettings.currentLocale == AppLocale.en) // locale check
enum AppLocale with BaseAppLocale<AppLocale, Translations> {
	en(languageCode: 'en', build: Translations.build),
	it(languageCode: 'it', build: _StringsIt.build);

	const AppLocale({required this.languageCode, this.scriptCode, this.countryCode, required this.build}); // ignore: unused_element

	@override final String languageCode;
	@override final String? scriptCode;
	@override final String? countryCode;
	@override final TranslationBuilder<AppLocale, Translations> build;

	/// Gets current instance managed by [LocaleSettings].
	Translations get translations => LocaleSettings.instance.translationMap[this]!;
}

/// Method A: Simple
///
/// No rebuild after locale change.
/// Translation happens during initialization of the widget (call of t).
/// Configurable via 'translate_var'.
///
/// Usage:
/// String a = t.someKey.anotherKey;
/// String b = t['someKey.anotherKey']; // Only for edge cases!
Translations get t => LocaleSettings.instance.currentTranslations;

/// Method B: Advanced
///
/// All widgets using this method will trigger a rebuild when locale changes.
/// Use this if you have e.g. a settings page where the user can select the locale during runtime.
///
/// Step 1:
/// wrap your App with
/// TranslationProvider(
/// 	child: MyApp()
/// );
///
/// Step 2:
/// final t = Translations.of(context); // Get t variable.
/// String a = t.someKey.anotherKey; // Use t variable.
/// String b = t['someKey.anotherKey']; // Only for edge cases!
class TranslationProvider extends BaseTranslationProvider<AppLocale, Translations> {
	TranslationProvider({required super.child}) : super(settings: LocaleSettings.instance);

	static InheritedLocaleData<AppLocale, Translations> of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context);
}

/// Method B shorthand via [BuildContext] extension method.
/// Configurable via 'translate_var'.
///
/// Usage (e.g. in a widget's build method):
/// context.t.someKey.anotherKey
extension BuildContextTranslationsExtension on BuildContext {
	Translations get t => TranslationProvider.of(this).translations;
}

/// Manages all translation instances and the current locale
class LocaleSettings extends BaseFlutterLocaleSettings<AppLocale, Translations> {
	LocaleSettings._() : super(utils: AppLocaleUtils.instance);

	static final instance = LocaleSettings._();

	// static aliases (checkout base methods for documentation)
	static AppLocale get currentLocale => instance.currentLocale;
	static Stream<AppLocale> getLocaleStream() => instance.getLocaleStream();
	static AppLocale setLocale(AppLocale locale, {bool? listenToDeviceLocale = false}) => instance.setLocale(locale, listenToDeviceLocale: listenToDeviceLocale);
	static AppLocale setLocaleRaw(String rawLocale, {bool? listenToDeviceLocale = false}) => instance.setLocaleRaw(rawLocale, listenToDeviceLocale: listenToDeviceLocale);
	static AppLocale useDeviceLocale() => instance.useDeviceLocale();
	@Deprecated('Use [AppLocaleUtils.supportedLocales]') static List<Locale> get supportedLocales => instance.supportedLocales;
	@Deprecated('Use [AppLocaleUtils.supportedLocalesRaw]') static List<String> get supportedLocalesRaw => instance.supportedLocalesRaw;
	static void setPluralResolver({String? language, AppLocale? locale, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver}) => instance.setPluralResolver(
		language: language,
		locale: locale,
		cardinalResolver: cardinalResolver,
		ordinalResolver: ordinalResolver,
	);
}

/// Provides utility functions without any side effects.
class AppLocaleUtils extends BaseAppLocaleUtils<AppLocale, Translations> {
	AppLocaleUtils._() : super(baseLocale: _baseLocale, locales: AppLocale.values);

	static final instance = AppLocaleUtils._();

	// static aliases (checkout base methods for documentation)
	static AppLocale parse(String rawLocale) => instance.parse(rawLocale);
	static AppLocale parseLocaleParts({required String languageCode, String? scriptCode, String? countryCode}) => instance.parseLocaleParts(languageCode: languageCode, scriptCode: scriptCode, countryCode: countryCode);
	static AppLocale findDeviceLocale() => instance.findDeviceLocale();
	static List<Locale> get supportedLocales => instance.supportedLocales;
	static List<String> get supportedLocalesRaw => instance.supportedLocalesRaw;
}

// translations

// Path: <root>
class Translations implements BaseTranslations<AppLocale, Translations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final t = Translations.of(context);
	static Translations of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	Translations.build({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = TranslationMetadata(
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	dynamic operator[](String key) => $meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	// Translations
	String get cancel => 'Cancel';
	String get ok => 'Ok';
	String get enterText => 'Enter text';
	String get confirmDelete => 'Confirm delete?';
	String get barcodeNotAllowed => 'Barcode not allowed.';
	String get yes => 'Yes';
	String get no => 'No';
	String errorInField({required Object field}) => 'Error in field ${field}';
	String get checkData => 'Check entered data!';
	String get preferences => 'Preferences';
	String get colorPreferences => 'Color Preferences';
	String get theme => 'Theme';
	String get darkMode => 'Dark Mode';
	String get lightMode => 'Light Mode';
	String get resetColor => 'Reset Color';
	String get inputStyle => 'Input Style';
	String get fullBorder => 'Full Border';
	String get bottomBorder => 'Bottom Border';
	String get checkingServer => 'Checking server...';
	String serverOnlineVersion({required Object version}) => 'Server online (v${version})';
	String get cannotConnectToServer => 'Cannot connect to server';
	String get testingCredentials => 'Testing credentials...';
	String get authenticationSuccessful => 'Authentication successful';
	String authError({required Object error}) => 'Auth error: ${error}';
	String get unableToConnectToServer => 'Unable to connect to server!';
	String get noDatabaseConfigured => 'No database configured';
	String errorDownloading({required Object filename, required Object error}) => 'Error downloading ${filename}: ${error}';
	String errorPreparingDocument({required Object filename, required Object error}) => 'Error preparing document ${filename}: ${error}';
	String uploadFailed({required Object message}) => 'Upload failed: ${message}';
	String get unknownError => 'Unknown error';
	String errorUploading({required Object filename, required Object error}) => 'Error uploading ${filename}: ${error}';
	String boxNotFound({required Object boxName}) => 'Box not found: ${boxName}';
	String documentNotFound({required Object documentKey}) => 'Document not found: ${documentKey}';
}

// Path: <root>
class _StringsIt implements Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	_StringsIt.build({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = TranslationMetadata(
		    locale: AppLocale.it,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <it>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key);

	@override late final _StringsIt _root = this; // ignore: unused_field

	// Translations
	@override String get cancel => 'Annulla';
	@override String get ok => 'Ok';
	@override String get enterText => 'Inserisci il testo';
	@override String get confirmDelete => 'Confermi la cancellazione?';
	@override String get barcodeNotAllowed => 'Barcode non disponibile.';
	@override String get yes => 'Si';
	@override String get no => 'No';
	@override String errorInField({required Object field}) => 'Errore nel campo ${field}';
	@override String get checkData => 'Controlla i dati inseriti!';
	@override String get preferences => 'Preferenze';
	@override String get colorPreferences => 'Preferenze Colore';
	@override String get theme => 'Tema';
	@override String get darkMode => 'Modalità Scura';
	@override String get lightMode => 'Modalità Chiara';
	@override String get resetColor => 'Ripristina';
	@override String get inputStyle => 'Stile Input';
	@override String get fullBorder => 'Bordo Completo';
	@override String get bottomBorder => 'Bordo Inferiore';
	@override String get checkingServer => 'Verifica server...';
	@override String serverOnlineVersion({required Object version}) => 'Server online (v${version})';
	@override String get cannotConnectToServer => 'Impossibile connettersi al server';
	@override String get testingCredentials => 'Test credenziali...';
	@override String get authenticationSuccessful => 'Autenticazione riuscita';
	@override String authError({required Object error}) => 'Errore di autenticazione: ${error}';
	@override String get unableToConnectToServer => 'Impossibile connettersi al server!';
	@override String get noDatabaseConfigured => 'Nessun database configurato';
	@override String errorDownloading({required Object filename, required Object error}) => 'Errore scaricamento ${filename}: ${error}';
	@override String errorPreparingDocument({required Object filename, required Object error}) => 'Errore preparazione documento ${filename}: ${error}';
	@override String uploadFailed({required Object message}) => 'Upload fallito: ${message}';
	@override String get unknownError => 'Errore sconosciuto';
	@override String errorUploading({required Object filename, required Object error}) => 'Errore upload ${filename}: ${error}';
	@override String boxNotFound({required Object boxName}) => 'Box non trovato: ${boxName}';
	@override String documentNotFound({required Object documentKey}) => 'Documento non trovato: ${documentKey}';
}

/// Flat map(s) containing all translations.
/// Only for edge cases! For simple maps, use the map function of this library.

extension on Translations {
	dynamic _flatMapFunction(String path) {
		switch (path) {
			case 'cancel': return 'Cancel';
			case 'ok': return 'Ok';
			case 'enterText': return 'Enter text';
			case 'confirmDelete': return 'Confirm delete?';
			case 'barcodeNotAllowed': return 'Barcode not allowed.';
			case 'yes': return 'Yes';
			case 'no': return 'No';
			case 'errorInField': return ({required Object field}) => 'Error in field ${field}';
			case 'checkData': return 'Check entered data!';
			case 'preferences': return 'Preferences';
			case 'colorPreferences': return 'Color Preferences';
			case 'theme': return 'Theme';
			case 'darkMode': return 'Dark Mode';
			case 'lightMode': return 'Light Mode';
			case 'resetColor': return 'Reset Color';
			case 'inputStyle': return 'Input Style';
			case 'fullBorder': return 'Full Border';
			case 'bottomBorder': return 'Bottom Border';
			case 'checkingServer': return 'Checking server...';
			case 'serverOnlineVersion': return ({required Object version}) => 'Server online (v${version})';
			case 'cannotConnectToServer': return 'Cannot connect to server';
			case 'testingCredentials': return 'Testing credentials...';
			case 'authenticationSuccessful': return 'Authentication successful';
			case 'authError': return ({required Object error}) => 'Auth error: ${error}';
			case 'unableToConnectToServer': return 'Unable to connect to server!';
			case 'noDatabaseConfigured': return 'No database configured';
			case 'errorDownloading': return ({required Object filename, required Object error}) => 'Error downloading ${filename}: ${error}';
			case 'errorPreparingDocument': return ({required Object filename, required Object error}) => 'Error preparing document ${filename}: ${error}';
			case 'uploadFailed': return ({required Object message}) => 'Upload failed: ${message}';
			case 'unknownError': return 'Unknown error';
			case 'errorUploading': return ({required Object filename, required Object error}) => 'Error uploading ${filename}: ${error}';
			case 'boxNotFound': return ({required Object boxName}) => 'Box not found: ${boxName}';
			case 'documentNotFound': return ({required Object documentKey}) => 'Document not found: ${documentKey}';
			default: return null;
		}
	}
}

extension on _StringsIt {
	dynamic _flatMapFunction(String path) {
		switch (path) {
			case 'cancel': return 'Annulla';
			case 'ok': return 'Ok';
			case 'enterText': return 'Inserisci il testo';
			case 'confirmDelete': return 'Confermi la cancellazione?';
			case 'barcodeNotAllowed': return 'Barcode non disponibile.';
			case 'yes': return 'Si';
			case 'no': return 'No';
			case 'errorInField': return ({required Object field}) => 'Errore nel campo ${field}';
			case 'checkData': return 'Controlla i dati inseriti!';
			case 'preferences': return 'Preferenze';
			case 'colorPreferences': return 'Preferenze Colore';
			case 'theme': return 'Tema';
			case 'darkMode': return 'Modalità Scura';
			case 'lightMode': return 'Modalità Chiara';
			case 'resetColor': return 'Ripristina';
			case 'inputStyle': return 'Stile Input';
			case 'fullBorder': return 'Bordo Completo';
			case 'bottomBorder': return 'Bordo Inferiore';
			case 'checkingServer': return 'Verifica server...';
			case 'serverOnlineVersion': return ({required Object version}) => 'Server online (v${version})';
			case 'cannotConnectToServer': return 'Impossibile connettersi al server';
			case 'testingCredentials': return 'Test credenziali...';
			case 'authenticationSuccessful': return 'Autenticazione riuscita';
			case 'authError': return ({required Object error}) => 'Errore di autenticazione: ${error}';
			case 'unableToConnectToServer': return 'Impossibile connettersi al server!';
			case 'noDatabaseConfigured': return 'Nessun database configurato';
			case 'errorDownloading': return ({required Object filename, required Object error}) => 'Errore scaricamento ${filename}: ${error}';
			case 'errorPreparingDocument': return ({required Object filename, required Object error}) => 'Errore preparazione documento ${filename}: ${error}';
			case 'uploadFailed': return ({required Object message}) => 'Upload fallito: ${message}';
			case 'unknownError': return 'Errore sconosciuto';
			case 'errorUploading': return ({required Object filename, required Object error}) => 'Errore upload ${filename}: ${error}';
			case 'boxNotFound': return ({required Object boxName}) => 'Box non trovato: ${boxName}';
			case 'documentNotFound': return ({required Object documentKey}) => 'Documento non trovato: ${documentKey}';
			default: return null;
		}
	}
}
