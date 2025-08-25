import 'package:i18n_extension/i18n_extension.dart';

extension Localization on String {
  static final _t = Translations.byText("en-US") +
      {
        "en-US": "Cancel",
        "it-IT": "Annulla",
      } +
      {
        "en-US": "Enter text",
        "it-IT": "Inserisci il testo",
      } +
      {
        "en-US": "Confirm delete?",
        "it-IT": "Confermi la cancellazione?",
      } +
      {
        "en-US": "Barcode not allowed.",
        "it-IT": "Barcode non disponibile.",
      } +
      {
        "en-US": "Yes",
        "it-IT": "Si",
      } +
      {
        "en-US": "Error in field '\$campo'",
        "it-IT": "Errore nel campo '\$campo'",
      } +
      {
        "en-US": "Check entered data!",
        "it-IT": "Controlla i dati inseriti!",
      };

  String get i18n => localize(this, _t);
  String fill(List<Object> params) => localizeFill(this, params);
  String plural(value) => localizePlural(value, this, _t);
  String version(Object modifier) => localizeVersion(modifier, this, _t);
}
