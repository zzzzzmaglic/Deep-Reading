import 'package:shared_preferences/shared_preferences.dart';

class PreferenceStore {
  PreferenceStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _fontSizeKey = 'reader.font_size';
  static const _themeKey = 'reader.theme';

  final SharedPreferencesAsync _preferences;

  Future<double?> readReaderFontSize() {
    return _preferences.getDouble(_fontSizeKey);
  }

  Future<void> saveReaderFontSize(double value) {
    return _preferences.setDouble(_fontSizeKey, value);
  }

  Future<String?> readReaderTheme() {
    return _preferences.getString(_themeKey);
  }

  Future<void> saveReaderTheme(String value) {
    return _preferences.setString(_themeKey, value);
  }
}
