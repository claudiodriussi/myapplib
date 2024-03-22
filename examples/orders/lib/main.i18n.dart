
import 'package:i18n_extension_importer/i18n_extension_importer.dart';
import 'package:i18n_extension/i18n_extension.dart';

class MyI18n {
  static var translations = Translations.byLocale("en");

  static Future<void> loadTranslations() async {
    translations +=
        await GettextImporter().fromAssetDirectory("assets/locales");
  }
}

extension Localization on String {
  String get i18n => localize(this, MyI18n.translations);
  String plural(value) => localizePlural(value, this, MyI18n.translations);
  String fill(List<Object> params) => localizeFill(this, params);
}

/*
import 'package:i18n_extension/i18n_extension.dart';

extension Localization on String {

  static final _t = Translations("en_us") +
      const {
        "en_us": "Yes",
        "it_it": "Si",
      } +
      {
        "en_us": "Products",
        "it_it": "Prodotti",
      } +
      {
        "en_us": "Product name",
        "it_it": "Descrizione",
      } +
      {
        "en_us": "ProductID",
        "it_it": "Codice prodotto",
      } +
      {
        "en_us": "Settings",
        "it_it": "Configurazione",
      } +
      {
        "en_us": "Preferences",
        "it_it": "Preferenze",
      } +
      {
        "en_us": "Visual",
        "it_it": "Componenti visuali",
      };

  String get i18n => localize(this, _t);
  String fill(List<Object> params) => localizeFill(this, params);
  String plural(value) => localizePlural(value, this, _t);
  String version(Object modifier) => localizeVersion(modifier, this, _t);
}


 */

