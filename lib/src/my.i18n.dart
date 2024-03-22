import 'package:i18n_extension/i18n_extension.dart';

extension Localization on String {
  static final _t = Translations.byText("en_us") +
      {
        "en_us": "Cancel",
        "it_it": "Annulla",
      } +
      {
        "en_us": "Enter text",
        "it_it": "Inserisci il testo",
      } +
      {
        "en_us": "Confirm delete?",
        "it_it": "Confermi la cancellazione?",
      } +
      {
        "en_us": "Barcode not allowed.",
        "it_it": "Barcode non disponibile.",
      } +
      {
        "en_us": "Yes",
        "it_it": "Si",
      };

  String get i18n => localize(this, _t);
  String fill(List<Object> params) => localizeFill(this, params);
  String plural(value) => localizePlural(value, this, _t);
  String version(Object modifier) => localizeVersion(modifier, this, _t);
}
