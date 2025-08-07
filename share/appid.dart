import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Calc anc uuid unique for the app.
/// 
Future<String> getUniqueId() async {
  final prefs = await SharedPreferences.getInstance();
  String? uniqueId = prefs.getString('app_unique_id');

  if (uniqueId == null) {
    uniqueId = Uuid().v4(); // Genera un UUID v4
    await prefs.setString('app_unique_id', uniqueId);
  }
  return uniqueId;
}


/// Calc an one way key scrambling a string with some parameters.
///
/// The result is not ensured to be unique and it is not possible to return to
/// the original string used for calculation.
///
/// Parameters are: [serial] is the string used for calculation, can be any
/// combination of serial numbers and names. [prefix] is a prefix string should
/// be unique along an application, [suffix] like prefix should be unique for
/// app. [keyLenght] is the lenght of resulting key, multiplier is the number
/// of times that string is multiplied before calculation, should not be a
/// multiple of keyLenght.
///
/// The result key is a string of uppercase chars.
///
String calcKey(
  String serial,
  String prefix,
  String suffix, {
  keyLenght = 5,
  multiplier = 9,
}) {
  String s = (prefix + serial + suffix) * multiplier;
  dynamic key = [0];
  for (int i = 0; i < keyLenght - 1; i++) {
    key.add(0);
  }

  // sum char codes on each key position
  for (var i = 0; i < s.length; i++) {
    key[i % keyLenght] += s.codeUnitAt(i);
  }

  // calc the modulus ok key positions and add to the first uppercase char
  for (var i = 0; i < key.length; i++) {
    key[i] = key[i] % 26 + 65;
  }

  // resulting string
  return String.fromCharCodes(key);
}
