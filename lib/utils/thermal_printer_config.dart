import 'package:shared_preferences/shared_preferences.dart';

class ThermalPrinterConfig {
  static const String _printerWidthKey = 'printer_width';
  static const String _thermalPageSizeKey = 'thermal_page_size';

  static String resolveWidthFromPrefs(SharedPreferences prefs) {
    final width = _normalizeWidth(prefs.getString(_printerWidthKey));
    final legacy = _normalizeWidth(prefs.getString(_thermalPageSizeKey));

    if (width != null && legacy != null && width != legacy) {
      return _minWidth(width, legacy);
    }

    return width ?? legacy ?? '58mm';
  }

  static int charsPerLine(String width) {
    return width == '80mm' ? 48 : 32;
  }

  static String? _normalizeWidth(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final match = RegExp(r'(\d+)').firstMatch(raw);
    if (match == null) return null;
    final value = int.tryParse(match.group(1) ?? '');
    if (value == null) return null;
    return value >= 70 ? '80mm' : '58mm';
  }

  static String _minWidth(String a, String b) {
    final aVal = a == '80mm' ? 80 : 58;
    final bVal = b == '80mm' ? 80 : 58;
    return aVal <= bVal ? a : b;
  }
}

