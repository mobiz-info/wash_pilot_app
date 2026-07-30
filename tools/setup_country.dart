#!/usr/bin/env dart
// tools/setup_country.dart
//
// Run this script from the Flutter project root:
//   dart tools/setup_country.dart
//
// It will:
//   1. Show a numbered menu of supported countries
//   2. Let you pick one
//   3. Read the app version from pubspec.yaml
//   4. Rewrite lib/config/app_defaults.dart with the chosen country and version
//   5. Update android/gradle.properties with selectedCountryName so Gradle can rename the output APK

import 'dart:io';

// ─── Country data (mirrors lib/config/country_config.dart) ────────────────────

class _Country {
  final String enumName;        // must match CountryCode enum in country_config.dart
  final String displayName;
  final String flag;
  final String phoneDialCode;
  final String phoneIsoCode;
  final String currencySymbol;
  final String currencyCode;
  final String currencyName;
  final String localeTag;

  const _Country({
    required this.enumName,
    required this.displayName,
    required this.flag,
    required this.phoneDialCode,
    required this.phoneIsoCode,
    required this.currencySymbol,
    required this.currencyCode,
    required this.currencyName,
    required this.localeTag,
  });
}

const _countries = [
  _Country(
    enumName: 'saudiArabia',
    displayName: 'Saudi Arabia',
    flag: '🇸🇦',
    phoneDialCode: '+966',
    phoneIsoCode: 'SA',
    currencySymbol: 'SAR',
    currencyCode: 'SAR',
    currencyName: 'Saudi Riyal',
    localeTag: 'ar_SA',
  ),
  _Country(
    enumName: 'india',
    displayName: 'India',
    flag: '🇮🇳',
    phoneDialCode: '+91',
    phoneIsoCode: 'IN',
    currencySymbol: '₹',
    currencyCode: 'INR',
    currencyName: 'Indian Rupee',
    localeTag: 'en_IN',
  ),
  _Country(
    enumName: 'uae',
    displayName: 'UAE',
    flag: '🇦🇪',
    phoneDialCode: '+971',
    phoneIsoCode: 'AE',
    currencySymbol: 'AED',
    currencyCode: 'AED',
    currencyName: 'UAE Dirham',
    localeTag: 'ar_AE',
  ),
  _Country(
    enumName: 'kuwait',
    displayName: 'Kuwait',
    flag: '🇰🇼',
    phoneDialCode: '+965',
    phoneIsoCode: 'KW',
    currencySymbol: 'KWD',
    currencyCode: 'KWD',
    currencyName: 'Kuwaiti Dinar',
    localeTag: 'ar_KW',
  ),
  _Country(
    enumName: 'qatar',
    displayName: 'Qatar',
    flag: '🇶🇦',
    phoneDialCode: '+974',
    phoneIsoCode: 'QA',
    currencySymbol: 'QAR',
    currencyCode: 'QAR',
    currencyName: 'Qatari Riyal',
    localeTag: 'ar_QA',
  ),
  _Country(
    enumName: 'bahrain',
    displayName: 'Bahrain',
    flag: '🇧🇭',
    phoneDialCode: '+973',
    phoneIsoCode: 'BH',
    currencySymbol: 'BHD',
    currencyCode: 'BHD',
    currencyName: 'Bahraini Dinar',
    localeTag: 'ar_BH',
  ),
  _Country(
    enumName: 'oman',
    displayName: 'Oman',
    flag: '🇴🇲',
    phoneDialCode: '+968',
    phoneIsoCode: 'OM',
    currencySymbol: 'OMR',
    currencyCode: 'OMR',
    currencyName: 'Omani Rial',
    localeTag: 'ar_OM',
  ),
  _Country(
    enumName: 'usa',
    displayName: 'United States',
    flag: '🇺🇸',
    phoneDialCode: '+1',
    phoneIsoCode: 'US',
    currencySymbol: '\$',
    currencyCode: 'USD',
    currencyName: 'US Dollar',
    localeTag: 'en_US',
  ),
  _Country(
    enumName: 'uk',
    displayName: 'United Kingdom',
    flag: '🇬🇧',
    phoneDialCode: '+44',
    phoneIsoCode: 'GB',
    currencySymbol: '£',
    currencyCode: 'GBP',
    currencyName: 'British Pound',
    localeTag: 'en_GB',
  ),
  _Country(
    enumName: 'vietnam',
    displayName: 'Vietnam',
    flag: '🇻🇳',
    phoneDialCode: '+84',
    phoneIsoCode: 'VN',
    currencySymbol: '₫',
    currencyCode: 'VND',
    currencyName: 'Vietnamese Dong',
    localeTag: 'vi_VN',
  ),
  _Country(
    enumName: 'thailand',
    displayName: 'Thailand',
    flag: '🇹🇭',
    phoneDialCode: '+66',
    phoneIsoCode: 'TH',
    currencySymbol: '฿',
    currencyCode: 'THB',
    currencyName: 'Thai Baht',
    localeTag: 'th_TH',
  ),
  _Country(
    enumName: 'russia',
    displayName: 'Russia',
    flag: '🇷🇺',
    phoneDialCode: '+7',
    phoneIsoCode: 'RU',
    currencySymbol: '₽',
    currencyCode: 'RUB',
    currencyName: 'Russian Ruble',
    localeTag: 'ru_RU',
  ),
  _Country(
    enumName: 'china',
    displayName: 'China',
    flag: '🇨🇳',
    phoneDialCode: '+86',
    phoneIsoCode: 'CN',
    currencySymbol: '¥',
    currencyCode: 'CNY',
    currencyName: 'Chinese Yuan',
    localeTag: 'zh_CN',
  ),
];

// ─── Target file path (relative to project root) ──────────────────────────────

const _targetFile = 'lib/config/app_defaults.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

void _printLine([String char = '─', int width = 55]) {
  print(char * width);
}

void _printBanner() {
  _printLine('═');
  print('  🌍  Mobiz Autocare Pro — Country Setup');
  _printLine('═');
  print('');
}

void _printMenu() {
  print('  Select your country:');
  print('');
  for (var i = 0; i < _countries.length; i++) {
    final c = _countries[i];
    final num = (i + 1).toString().padLeft(2);
    print('  $num.  ${c.flag}  ${c.displayName.padRight(20)}  '
        '${c.phoneDialCode.padRight(6)}  ${c.currencySymbol} (${c.currencyCode})');
  }
  print('');
  _printLine();
}

// ─── Generate app_defaults.dart content ───────────────────────────────────────

String _generateDartFile(_Country c, String version) {
  return '''// AUTO-GENERATED by tools/setup_country.dart
// ⚠️  Do NOT edit manually. Run:  dart tools/setup_country.dart
//
// Current: ${c.flag}  ${c.displayName}
//   Phone dial code : ${c.phoneDialCode}
//   Phone ISO       : ${c.phoneIsoCode}
//   Currency symbol : ${c.currencySymbol}
//   Currency code   : ${c.currencyCode}

// ignore_for_file: constant_identifier_names

import 'country_config.dart';

/// The default country compiled into this build.
/// Change it by running:  dart tools/setup_country.dart
const CountryCode kDefaultCountry = CountryCode.${c.enumName};

/// App Version name extracted from pubspec.yaml
const String kAppVersion = '$version';
''';
}

// ─── Patch country_config.dart ───────────────────────────────────────────────

void _patchCountryConfig() {
  final configPath = 'lib/config/country_config.dart';
  final file = File(configPath);
  if (!file.existsSync()) return;

  var content = file.readAsStringSync();

  // Replace the import block to add the app_defaults import if not present
  if (!content.contains("import 'app_defaults.dart'")) {
    content = content.replaceFirst(
      "import 'package:shared_preferences/shared_preferences.dart';",
      "import 'package:shared_preferences/shared_preferences.dart';\nimport 'app_defaults.dart';",
    );
  }

  // Replace the hard-coded default:
  //   static CountrySettings _current = _countryMap[CountryCode.india]!;
  // with:
  //   static CountrySettings _current = _countryMap[kDefaultCountry]!;
  final oldDefault = RegExp(
    r'static CountrySettings _current = _countryMap\[CountryCode\.\w+\]!;',
  );
  content = content.replaceFirst(
    oldDefault,
    'static CountrySettings _current = _countryMap[kDefaultCountry]!;',
  );

  // Same for the load() fallback and logout() reset — replace any CountryCode.india fallback
  // with kDefaultCountry so everything stays consistent.
  content = content.replaceAll(
    '_countryMap[CountryCode.india]!;',
    '_countryMap[kDefaultCountry]!;',
  );

  file.writeAsStringSync(content);
}

// ─── Patch gradle.properties ─────────────────────────────────────────────────

void _patchGradleProperties(_Country c) {
  final propertiesFile = File('android/gradle.properties');
  if (!propertiesFile.existsSync()) return;

  var content = propertiesFile.readAsStringSync();
  final key = 'selectedCountryName';
  final value = c.displayName;

  final regExp = RegExp('^$key=.*', multiLine: true);
  if (content.contains(regExp)) {
    content = content.replaceFirst(regExp, '$key=$value');
  } else {
    // If not present, append it
    if (!content.endsWith('\n')) {
      content += '\n';
    }
    content += '$key=$value\n';
  }

  propertiesFile.writeAsStringSync(content);
}

// ─── Parse version from pubspec.yaml ─────────────────────────────────────────

String _parseVersion() {
  var appVersion = '1.3.4'; // Default fallback
  final pubspecFile = File('pubspec.yaml');
  if (pubspecFile.existsSync()) {
    final pubspecLines = pubspecFile.readAsLinesSync();
    for (final line in pubspecLines) {
      if (line.trim().startsWith('version:')) {
        final parts = line.split(':');
        if (parts.length > 1) {
          final verPart = parts[1].trim();
          // Split by '+' to remove the build number if present
          appVersion = verPart.split('+')[0];
          break;
        }
      }
    }
  }
  return appVersion;
}

// ─── Main ─────────────────────────────────────────────────────────────────────

void main() async {
  _printBanner();
  _printMenu();

  stdout.write('  Enter number (1–${_countries.length}): ');
  final input = stdin.readLineSync()?.trim() ?? '';
  final choice = int.tryParse(input);

  if (choice == null || choice < 1 || choice > _countries.length) {
    print('');
    print('  ❌  Invalid choice. Please enter a number between 1 and ${_countries.length}.');
    exit(1);
  }

  final selected = _countries[choice - 1];
  final version = _parseVersion();

  print('');
  print('  ✅  Selected: ${selected.flag}  ${selected.displayName}');
  print('  📦  App Version: $version');
  print('');

  // 1. Write lib/config/app_defaults.dart
  final outFile = File(_targetFile);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(_generateDartFile(selected, version));
  print('  📝  Written → $_targetFile');

  // 2. Patch country_config.dart to reference kDefaultCountry
  _patchCountryConfig();
  print('  🔧  Patched → lib/config/country_config.dart');

  // 3. Patch gradle.properties for APK renaming
  _patchGradleProperties(selected);
  print('  ⚙️  Updated gradle.properties selectedCountryName → ${selected.displayName}');

  print('');
  _printLine('─');
  print('  ${selected.flag}  App is now configured for ${selected.displayName} (V $version):');
  print('     Phone code  →  ${selected.phoneDialCode}  (${selected.phoneIsoCode})');
  print('     Currency    →  ${selected.currencySymbol}  (${selected.currencyCode} — ${selected.currencyName})');
  _printLine('─');
  print('');
  print('  🚀  Next steps:');
  print('       flutter run               ← hot restart picks up the change');
  print('       dart tools/build_apk.dart  ← build custom release APK directly');
  print('');

  stdout.write('  🛠️  Would you like to build the release APK now? (y/n): ');
  final buildChoice = stdin.readLineSync()?.trim().toLowerCase() ?? '';
  if (buildChoice == 'y' || buildChoice == 'yes') {
    print('');
    print('  Starting APK build via tools/build_apk.dart...');
    print('');
    final buildProcess = await Process.start(
      'dart',
      ['tools/build_apk.dart'],
      mode: ProcessStartMode.inheritStdio,
    );
    await buildProcess.exitCode;
  }
}
