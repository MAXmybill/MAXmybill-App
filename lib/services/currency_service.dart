import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:maxmybill/utils/firestore_service.dart';

/// Centralized Currency Service
/// Provides currency symbol, conversion rates, and formatting based on selected currency
class CurrencyService {
  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;
  CurrencyService._internal();

  String _currencySymbol = '';
  String _currencyCode = '';
  bool _isLoaded = false;
  final Map<String, double> _liveRates = {};

  /// Currency code to symbol mapping
  static const Map<String, String> currencySymbols = {
    // Popular currencies
    'USD': '\$', 'EUR': '€', 'GBP': '£', 'INR': '₹', 'CNY': '¥', 'JPY': '¥',

    // Asia-Pacific
    'AED': 'د.إ', 'AFN': '؋', 'AMD': '֏', 'AUD': 'A\$', 'AZN': '₼',
    'BDT': '৳', 'BHD': '.د.ب', 'BND': 'B\$', 'BTN': 'Nu.', 'FJD': 'FJ\$',
    'GEL': '₾', 'HKD': 'HK\$', 'IDR': 'Rp', 'ILS': '₪', 'IQD': 'ع.د',
    'IRR': '﷼', 'JOD': 'د.ا', 'KHR': '៛', 'KRW': '₩', 'KWD': 'د.ك',
    'KZT': '₸', 'LAK': '₭', 'LBP': 'ل.ل', 'LKR': 'Rs', 'MMK': 'K',
    'MNT': '₮', 'MOP': 'MOP\$', 'MVR': 'Rf', 'MYR': 'RM', 'NPR': 'Rs',
    'NZD': 'NZ\$', 'OMR': 'ر.ع.', 'PHP': '₱', 'PKR': 'Rs', 'QAR': 'ر.ق',
    'SAR': '﷼', 'SGD': 'S\$', 'SYP': '£S', 'THB': '฿', 'TJS': 'ЅМ',
    'TMT': 'm', 'TRY': '₺', 'TWD': 'NT\$', 'UZS': 'so\'m', 'VND': '₫',

    // Europe
    'ALL': 'L', 'BAM': 'KM', 'BGN': 'лв', 'BYN': 'Br', 'CHF': 'Fr',
    'CZK': 'Kč', 'DKK': 'kr', 'HRK': 'kn', 'HUF': 'Ft', 'ISK': 'kr',
    'MDL': 'L', 'MKD': 'ден', 'NOK': 'kr', 'PLN': 'zł', 'RON': 'lei',
    'RSD': 'дин', 'RUB': '₽', 'SEK': 'kr', 'UAH': '₴',

    // Americas
    'ARS': '\$', 'BOB': 'Bs.', 'BRL': 'R\$', 'CAD': 'C\$', 'CLP': '\$',
    'COP': '\$', 'CRC': '₡', 'CUP': '\$', 'DOP': 'RD\$', 'GTQ': 'Q',
    'HNL': 'L', 'HTG': 'G', 'JMD': 'J\$', 'MXN': 'Mex\$', 'NIO': 'C\$',
    'PAB': 'B/.', 'PEN': 'S/', 'PYG': '₲', 'TTD': 'TT\$', 'UYU': '\$U',
    'VES': 'Bs.S',

    // Africa
    'DZD': 'د.ج', 'EGP': 'E£', 'ETB': 'Br', 'GHS': 'GH₵', 'KES': 'KSh',
    'MAD': 'د.م.', 'MUR': '₨', 'MWK': 'MK', 'NAD': 'N\$', 'NGN': '₦',
    'RWF': 'FRw', 'TND': 'د.ت', 'TZS': 'TSh', 'UGX': 'USh', 'XAF': 'Fcfa',
    'XOF': 'Cfa', 'ZAR': 'R', 'ZMW': 'ZK',
  };

  /// Static standard conversion rate table (1 INR -> Target Currency)
  static const Map<String, double> inrToCurrencyRates = {
    'INR': 1.0,
    'USD': 0.0116,    // 1 USD ≈ 86.2 INR
    'EUR': 0.0106,    // 1 EUR ≈ 94.3 INR
    'GBP': 0.0089,    // 1 GBP ≈ 112.3 INR
    'AED': 0.0425,    // 1 AED ≈ 23.5 INR
    'SAR': 0.0434,    // 1 SAR ≈ 23.0 INR
    'CAD': 0.0161,    // 1 CAD ≈ 62.1 INR
    'AUD': 0.0179,    // 1 AUD ≈ 55.8 INR
    'SGD': 0.0153,    // 1 SGD ≈ 65.3 INR
    'JPY': 1.724,     // 1 JPY ≈ 0.58 INR
    'CNY': 0.0833,    // 1 CNY ≈ 12.0 INR
    'CHF': 0.0102,    // 1 CHF ≈ 98.0 INR
    'KWD': 0.00355,   // 1 KWD ≈ 282 INR
    'BHD': 0.00435,   // 1 BHD ≈ 230 INR
    'OMR': 0.00444,   // 1 OMR ≈ 225 INR
    'QAR': 0.0421,    // 1 QAR ≈ 23.8 INR
    'NZD': 0.0194,    // 1 NZD ≈ 51.5 INR
    'MYR': 0.0513,    // 1 MYR ≈ 19.5 INR
    'THB': 0.392,     // 1 THB ≈ 2.55 INR
    'PHP': 0.658,     // 1 PHP ≈ 1.52 INR
    'IDR': 185.0,     // 1 IDR ≈ 0.0054 INR
    'PKR': 3.22,      // 1 PKR ≈ 0.31 INR
    'BDT': 1.39,      // 1 BDT ≈ 0.72 INR
    'LKR': 3.45,      // 1 LKR ≈ 0.29 INR
    'NPR': 1.60,      // 1 NPR ≈ 0.625 INR
    'ZAR': 0.208,     // 1 ZAR ≈ 4.80 INR
    'NGN': 17.5,      // 1 NGN ≈ 0.057 INR
    'BRL': 0.0667,    // 1 BRL ≈ 15.0 INR
    'RUB': 1.05,      // 1 RUB ≈ 0.95 INR
    'TRY': 0.408,     // 1 TRY ≈ 2.45 INR
    'KRW': 15.8,      // 1 KRW ≈ 0.063 INR
    'HKD': 0.090,     // 1 HKD ≈ 11.1 INR
    'TWD': 0.370,     // 1 TWD ≈ 2.70 INR
    'VND': 295.0,     // 1 VND ≈ 0.0034 INR
    'EGP': 0.58,      // 1 EGP ≈ 1.72 INR
    'KES': 1.50,      // 1 KES ≈ 0.67 INR
    'GHS': 0.178,     // 1 GHS ≈ 5.62 INR
    'ILS': 0.0417,    // 1 ILS ≈ 24.0 INR
    'MXN': 0.235,     // 1 MXN ≈ 4.25 INR
    'PLN': 0.0455,    // 1 PLN ≈ 22.0 INR
    'SEK': 0.118,     // 1 SEK ≈ 8.5 INR
    'NOK': 0.122,     // 1 NOK ≈ 8.2 INR
    'DKK': 0.079,     // 1 DKK ≈ 12.6 INR
    'CZK': 0.263,     // 1 CZK ≈ 3.80 INR
    'HUF': 4.25,      // 1 HUF ≈ 0.235 INR
    'RON': 0.0526,    // 1 RON ≈ 19.0 INR
    'BGN': 0.0207,    // 1 BGN ≈ 48.3 INR
    'HRK': 0.0798,    // 1 HRK ≈ 12.5 INR
    'ISK': 1.58,      // 1 ISK ≈ 0.63 INR
    'CLP': 11.2,      // 1 CLP ≈ 0.089 INR
    'COP': 48.0,      // 1 COP ≈ 0.021 INR
    'PEN': 0.043,     // 1 PEN ≈ 23.2 INR
    'ARS': 12.0,      // 1 ARS ≈ 0.083 INR
    'UYU': 0.49,      // 1 UYU ≈ 2.04 INR
    'DOP': 0.70,      // 1 DOP ≈ 1.43 INR
    'GTQ': 0.089,     // 1 GTQ ≈ 11.2 INR
    'CRC': 5.9,       // 1 CRC ≈ 0.17 INR
    'JMD': 1.82,      // 1 JMD ≈ 0.55 INR
    'TTD': 0.078,     // 1 TTD ≈ 12.8 INR
    'FJD': 0.026,     // 1 FJD ≈ 38.5 INR
    'MVR': 0.178,     // 1 MVR ≈ 5.62 INR
    'MUR': 0.53,      // 1 MUR ≈ 1.89 INR
    'BWP': 0.156,     // 1 BWP ≈ 6.4 INR
    'NAD': 0.208,     // 1 NAD ≈ 4.80 INR
    'TZS': 30.2,      // 1 TZS ≈ 0.033 INR
    'UGX': 43.0,      // 1 UGX ≈ 0.023 INR
    'RWF': 15.8,      // 1 RWF ≈ 0.063 INR
    'ETB': 1.42,      // 1 ETB ≈ 0.70 INR
    'MAD': 0.114,     // 1 MAD ≈ 8.77 INR
    'DZD': 1.54,      // 1 DZD ≈ 0.65 INR
    'TND': 0.0357,    // 1 TND ≈ 28.0 INR
    'XAF': 6.95,      // 1 XAF ≈ 0.144 INR
    'XOF': 6.95,      // 1 XOF ≈ 0.144 INR
  };

  /// Get currency symbol for a given code
  /// Returns empty string if code is null/empty or not found
  static String getSymbol(String? code) {
    if (code == null || code.isEmpty) return '₹';
    return currencySymbols[code.toUpperCase()] ?? (code.toUpperCase() == 'INR' ? '₹' : code);
  }

  /// Get currency symbol with trailing space (for formatting)
  static String getSymbolWithSpace(String? code) {
    final symbol = getSymbol(code);
    return symbol.isNotEmpty ? '$symbol ' : '';
  }

  /// Get exchange rate from INR to target currency
  static double getRate(String? targetCode) {
    if (targetCode == null || targetCode.isEmpty || targetCode.toUpperCase() == 'INR') {
      return 1.0;
    }
    final code = targetCode.toUpperCase();
    final live = _instance._liveRates[code];
    if (live != null && live > 0) return live;
    return inrToCurrencyRates[code] ?? 1.0;
  }

  /// Convert an amount in INR to target currency
  static double convertFromINR(double inrAmount, [String? targetCode]) {
    final code = targetCode ?? (_instance._currencyCode.isNotEmpty ? _instance._currencyCode : 'INR');
    if (code.toUpperCase() == 'INR') return inrAmount;
    final rate = getRate(code);
    return inrAmount * rate;
  }

  /// Format an INR amount as the target currency with symbol
  /// e.g. 199 in INR -> "₹199" (if INR) or "$2.31" / "€2.11" (if USD/EUR)
  static String formatPlanPrice(num inrAmount, {String? targetCode}) {
    if (inrAmount == 0) return 'Free';
    final code = targetCode ?? (_instance._currencyCode.isNotEmpty ? _instance._currencyCode : 'INR');
    final symbol = getSymbol(code);

    if (code.toUpperCase() == 'INR') {
      return '$symbol${inrAmount.toInt()}';
    }

    final double converted = convertFromINR(inrAmount.toDouble(), code);
    
    // Formatting rules depending on value range:
    if (converted < 10) {
      // E.g. $2.31
      final formatted = converted.toStringAsFixed(2);
      return '$symbol$formatted';
    } else if (converted < 100) {
      // E.g. $11.59 or $22.16
      final formatted = converted.toStringAsFixed(2);
      return '$symbol$formatted';
    } else if (converted < 1000) {
      // E.g. AED 84.6 or CHF 95.9
      final formatted = converted.toStringAsFixed(1);
      return '$symbol$formatted';
    } else {
      // Large figures like JPY 1,720 or IDR 36,800
      final formatted = converted.toStringAsFixed(0);
      return '$symbol$formatted';
    }
  }

  /// Current currency symbol (loaded from store)
  String get symbol => _currencySymbol.isNotEmpty ? _currencySymbol : '₹';

  /// Current currency symbol with space
  String get symbolWithSpace => _currencySymbol.isNotEmpty ? '$_currencySymbol ' : '₹ ';

  /// Current currency code
  String get code => _currencyCode.isNotEmpty ? _currencyCode : 'INR';

  /// Check if currency is loaded
  bool get isLoaded => _isLoaded;

  /// Load currency from store settings
  Future<void> loadCurrency() async {
    try {
      final store = await FirestoreService().getCurrentStoreDoc();
      if (store != null && store.exists) {
        final data = store.data() as Map<String, dynamic>?;
        final code = data?['currency'] as String?;
        _currencyCode = (code != null && code.isNotEmpty) ? code : 'INR';
        _currencySymbol = getSymbol(_currencyCode);
        _isLoaded = true;
      } else {
        _currencyCode = 'INR';
        _currencySymbol = '₹';
        _isLoaded = true;
      }
    } catch (e) {
      _currencyCode = 'INR';
      _currencySymbol = '₹';
      _isLoaded = true;
    }
    // Fetch live rates in background (non-blocking)
    fetchLiveRates();
  }

  /// Asynchronously fetch latest exchange rates
  Future<void> fetchLiveRates() async {
    try {
      final response = await http.get(Uri.parse('https://open.er-api.com/v6/latest/INR')).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['rates'] is Map) {
          final rates = data['rates'] as Map<String, dynamic>;
          rates.forEach((key, val) {
            if (val is num) {
              _liveRates[key.toUpperCase()] = val.toDouble();
            }
          });
        }
      }
    } catch (_) {
      // Gracefully silent fallback to static rates
    }
  }

  /// Update currency (called when user changes currency in settings)
  void updateCurrency(String? code) {
    _currencyCode = (code != null && code.isNotEmpty) ? code : 'INR';
    _currencySymbol = getSymbol(_currencyCode);
    _isLoaded = true;
  }

  /// Format amount with currency symbol
  /// Returns amount with currency symbol (or ₹ if none set)
  String format(double amount, {int decimals = 2}) {
    final formattedAmount = amount.toStringAsFixed(decimals);
    final sym = symbol;
    return '$sym$formattedAmount';
  }

  /// Format amount with currency symbol and space
  String formatWithSpace(double amount, {int decimals = 2}) {
    final formattedAmount = amount.toStringAsFixed(decimals);
    final sym = symbolWithSpace;
    return '$sym$formattedAmount';
  }
}

