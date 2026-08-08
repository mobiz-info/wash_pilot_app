// Centralized country configuration for the Mobiz Autocare Pro app.
//
// HOW TO USE:
// -----------
// 1. Set the country once (e.g. from a settings/onboarding screen):
//       CountryConfig.setCountry(CountryCode.saudiArabia);
//
// 2. Read the current config anywhere in your app:
//       final config = CountryConfig.current;
//       config.phoneIsoCode      // 'SA'
//       config.phoneDialCode     // '+966'
//       config.currencySymbol    // 'SAR'
//       config.currencyName      // 'Saudi Riyal'
//       config.flag              // '🇸🇦'
//
// 3. Use in IntlPhoneField:
//       initialCountryCode: CountryConfig.current.phoneIsoCode
//
// 4. Use in invoice / price display:
//       Text('${CountryConfig.current.currencySymbol} ${price.toStringAsFixed(2)}')

import 'package:shared_preferences/shared_preferences.dart';
import 'app_defaults.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Supported Countries Enum
// ─────────────────────────────────────────────────────────────────────────────

enum CountryCode {
  india,
  saudiArabia,
  uae,
  kuwait,
  qatar,
  bahrain,
  oman,
  usa,
  uk,
  vietnam,
  thailand,
  russia,
  china,
}

// ─────────────────────────────────────────────────────────────────────────────
// Country Configuration Model
// ─────────────────────────────────────────────────────────────────────────────

class CountrySettings {
  final CountryCode code;

  /// Display name shown in country selector UI
  final String displayName;

  /// ISO 3166-1 alpha-2 code used by IntlPhoneField (e.g. 'IN', 'SA', 'AE')
  final String phoneIsoCode;

  /// E.164 dial code prefix (e.g. '+91', '+966')
  final String phoneDialCode;

  /// Symbol shown in invoices / prices (e.g. '₹', 'SAR', 'AED')
  final String currencySymbol;

  /// Full currency name (e.g. 'Indian Rupee', 'Saudi Riyal')
  final String currencyName;

  /// ISO 4217 currency code (e.g. 'INR', 'SAR', 'AED')
  final String currencyCode;

  /// Unicode flag emoji
  final String flag;

  /// BCP 47 locale tag (used for number formatting, date formatting, etc.)
  final String localeTag;

  const CountrySettings({
    required this.code,
    required this.displayName,
    required this.phoneIsoCode,
    required this.phoneDialCode,
    required this.currencySymbol,
    required this.currencyName,
    required this.currencyCode,
    required this.flag,
    required this.localeTag,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// All Country Definitions
// ─────────────────────────────────────────────────────────────────────────────

const Map<CountryCode, CountrySettings> _countryMap = {
  CountryCode.india: CountrySettings(
    code: CountryCode.india,
    displayName: 'India',
    phoneIsoCode: 'IN',
    phoneDialCode: '+91',
    currencySymbol: '₹',
    currencyName: 'Indian Rupee',
    currencyCode: 'INR',
    flag: '🇮🇳',
    localeTag: 'en_IN',
  ),
  CountryCode.saudiArabia: CountrySettings(
    code: CountryCode.saudiArabia,
    displayName: 'Saudi Arabia',
    phoneIsoCode: 'SA',
    phoneDialCode: '+966',
    currencySymbol: 'SAR',
    currencyName: 'Saudi Riyal',
    currencyCode: 'SAR',
    flag: '🇸🇦',
    localeTag: 'ar_SA',
  ),
  CountryCode.uae: CountrySettings(
    code: CountryCode.uae,
    displayName: 'UAE',
    phoneIsoCode: 'AE',
    phoneDialCode: '+971',
    currencySymbol: 'AED',
    currencyName: 'UAE Dirham',
    currencyCode: 'AED',
    flag: '🇦🇪',
    localeTag: 'ar_AE',
  ),
  CountryCode.kuwait: CountrySettings(
    code: CountryCode.kuwait,
    displayName: 'Kuwait',
    phoneIsoCode: 'KW',
    phoneDialCode: '+965',
    currencySymbol: 'KWD',
    currencyName: 'Kuwaiti Dinar',
    currencyCode: 'KWD',
    flag: '🇰🇼',
    localeTag: 'ar_KW',
  ),
  CountryCode.qatar: CountrySettings(
    code: CountryCode.qatar,
    displayName: 'Qatar',
    phoneIsoCode: 'QA',
    phoneDialCode: '+974',
    currencySymbol: 'QAR',
    currencyName: 'Qatari Riyal',
    currencyCode: 'QAR',
    flag: '🇶🇦',
    localeTag: 'ar_QA',
  ),
  CountryCode.bahrain: CountrySettings(
    code: CountryCode.bahrain,
    displayName: 'Bahrain',
    phoneIsoCode: 'BH',
    phoneDialCode: '+973',
    currencySymbol: 'BHD',
    currencyName: 'Bahraini Dinar',
    currencyCode: 'BHD',
    flag: '🇧🇭',
    localeTag: 'ar_BH',
  ),
  CountryCode.oman: CountrySettings(
    code: CountryCode.oman,
    displayName: 'Oman',
    phoneIsoCode: 'OM',
    phoneDialCode: '+968',
    currencySymbol: 'OMR',
    currencyName: 'Omani Rial',
    currencyCode: 'OMR',
    flag: '🇴🇲',
    localeTag: 'ar_OM',
  ),
  CountryCode.usa: CountrySettings(
    code: CountryCode.usa,
    displayName: 'United States',
    phoneIsoCode: 'US',
    phoneDialCode: '+1',
    currencySymbol: '\$',
    currencyName: 'US Dollar',
    currencyCode: 'USD',
    flag: '🇺🇸',
    localeTag: 'en_US',
  ),
  CountryCode.uk: CountrySettings(
    code: CountryCode.uk,
    displayName: 'United Kingdom',
    phoneIsoCode: 'GB',
    phoneDialCode: '+44',
    currencySymbol: '£',
    currencyName: 'British Pound',
    currencyCode: 'GBP',
    flag: '🇬🇧',
    localeTag: 'en_GB',
  ),
  CountryCode.vietnam: CountrySettings(
    code: CountryCode.vietnam,
    displayName: 'Vietnam',
    phoneIsoCode: 'VN',
    phoneDialCode: '+84',
    currencySymbol: '₫',
    currencyName: 'Vietnamese Dong',
    currencyCode: 'VND',
    flag: '🇻🇳',
    localeTag: 'vi_VN',
  ),
  CountryCode.thailand: CountrySettings(
    code: CountryCode.thailand,
    displayName: 'Thailand',
    phoneIsoCode: 'TH',
    phoneDialCode: '+66',
    currencySymbol: '฿',
    currencyName: 'Thai Baht',
    currencyCode: 'THB',
    flag: '🇹🇭',
    localeTag: 'th_TH',
  ),
  CountryCode.russia: CountrySettings(
    code: CountryCode.russia,
    displayName: 'Russia',
    phoneIsoCode: 'RU',
    phoneDialCode: '+7',
    currencySymbol: '₽',
    currencyName: 'Russian Ruble',
    currencyCode: 'RUB',
    flag: '🇷🇺',
    localeTag: 'ru_RU',
  ),
  CountryCode.china: CountrySettings(
    code: CountryCode.china,
    displayName: 'China',
    phoneIsoCode: 'CN',
    phoneDialCode: '+86',
    currencySymbol: '¥',
    currencyName: 'Chinese Yuan',
    currencyCode: 'CNY',
    flag: '🇨🇳',
    localeTag: 'zh_CN',
  ),
};

// ─────────────────────────────────────────────────────────────────────────────
// CountryConfig — Static Manager
// ─────────────────────────────────────────────────────────────────────────────

class CountryConfig {
  // SharedPreferences key
  static const _prefKey = 'selected_country_code';

  /// Currently active country settings. Defaults to India.
  static CountrySettings _current = _countryMap[kDefaultCountry]!;

  /// Read the active config from anywhere.
  static CountrySettings get current => _current;

  /// All supported countries (for UI dropdown / picker).
  static List<CountrySettings> get all => _countryMap.values.toList();

  /// Set country by enum value and persist to SharedPreferences.
  static Future<void> setCountry(CountryCode code) async {
    _current = _countryMap[code] ?? _countryMap[kDefaultCountry]!;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, code.name);
  }

  /// Set country by ISO code string (e.g. 'IN', 'SA', 'AE').
  /// Useful when backend returns an ISO code.
  static Future<void> setCountryByIso(String isoCode) async {
    final match = _countryMap.values.firstWhere(
      (c) => c.phoneIsoCode == isoCode.toUpperCase(),
      orElse: () => _countryMap[CountryCode.india]!,
    );
    await setCountry(match.code);
  }

  /// Set country by currency code string (e.g. 'INR', 'SAR').
  static Future<void> setCountryByCurrency(String currencyCode) async {
    final match = _countryMap.values.firstWhere(
      (c) => c.currencyCode == currencyCode.toUpperCase(),
      orElse: () => _countryMap[CountryCode.india]!,
    );
    await setCountry(match.code);
  }

  /// Load the previously saved country from SharedPreferences.
  /// Call this once in main() before runApp().
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null) {
      try {
        final code = CountryCode.values.firstWhere((e) => e.name == saved);
        _current = _countryMap[code] ?? _countryMap[kDefaultCountry]!;
      } catch (_) {
        _current = _countryMap[kDefaultCountry]!;
      }
    }
  }

  // ─── Shortcut Getters ────────────────────────────────────────────────────

  /// e.g. 'IN', 'SA', 'AE'
  static String get phoneIsoCode => _current.phoneIsoCode;

  /// e.g. '+91', '+966'
  static String get phoneDialCode => _current.phoneDialCode;

  /// e.g. '₹ ', 'SAR ', 'AED ' — includes a trailing space for display formatting
  static String get currencySymbol => '${_current.currencySymbol} ';

  /// e.g. 'INR', 'SAR', 'AED'
  static String get currencyCode => _current.currencyCode;

  /// e.g. '🇮🇳', '🇸🇦'
  static String get flag => _current.flag;

  /// e.g. 'en_IN', 'ar_SA'
  static String get localeTag => _current.localeTag;

  /// e.g. 'India', 'Saudi Arabia'
  static String get displayName => _current.displayName;

  /// Formats phone number for wa.me / WhatsApp links correctly without double-prefixing.
  static String formatPhoneForWhatsapp(String phone) {
    return formatPhoneWithCountryCode(phone, phoneDialCode);
  }

  /// Formats a raw input mobile number with the selected dial code, avoiding duplicate country codes.
  static String formatPhoneWithCountryCode(String input, String selectedDialCode) {
    String cleaned = input.replaceAll(RegExp(r'\D'), '');
    if (cleaned.isEmpty) return '';

    // Known country dial codes sorted by length descending
    final knownCodes = ['971', '966', '965', '968', '974', '973', '91', '84', '66', '44', '86', '7', '1'];

    for (final code in knownCodes) {
      if (cleaned.startsWith(code)) {
        return cleaned; // Already has country dial code!
      }
    }

    final cleanCode = selectedDialCode.replaceAll('+', '');
    return '$cleanCode$cleaned';
  }
}

