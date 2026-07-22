#!/usr/bin/env dart
// tools/build_apk.dart
//
// Run this script from the Flutter project root:
//   dart tools/build_apk.dart
//
// It will:
//   1. Run "flutter build apk --release"
//   2. Read the selected country name from android/gradle.properties
//   3. Read the app version from pubspec.yaml
//   4. Copy the output app-release.apk to "Car wash [Country] V [Version].apk" in the flutter-apk outputs folder.

import 'dart:io';

void main() async {
  print('🚀 Starting Flutter Release APK Build...');
  print('');

  // 1. Run flutter build apk --release
  final process = await Process.start(
    'flutter',
    ['build', 'apk', '--release'],
    mode: ProcessStartMode.inheritStdio,
  );

  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    print('');
    print('❌ Flutter build failed with exit code $exitCode');
    exit(exitCode);
  }

  // 2. Read selected country from android/gradle.properties
  var country = 'India';
  final propertiesFile = File('android/gradle.properties');
  if (propertiesFile.existsSync()) {
    final lines = propertiesFile.readAsLinesSync();
    for (final line in lines) {
      if (line.trim().startsWith('selectedCountryName=')) {
        country = line.split('=')[1].trim();
        break;
      }
    }
  }

  // 3. Read version from pubspec.yaml
  var version = '1.3.5';
  final pubspecFile = File('pubspec.yaml');
  if (pubspecFile.existsSync()) {
    final lines = pubspecFile.readAsLinesSync();
    for (final line in lines) {
      if (line.trim().startsWith('version:')) {
        version = line.split(':')[1].trim().split('+')[0];
        break;
      }
    }
  }

  // 4. Copy build/app/outputs/flutter-apk/app-release.apk to the custom name
  final srcFile = File('build/app/outputs/flutter-apk/app-release.apk');
  if (srcFile.existsSync()) {
    final newName = 'Car wash $country V $version.apk';
    final destFile = File('build/app/outputs/flutter-apk/$newName');

    // Copy to destination
    srcFile.copySync(destFile.path);

    print('');
    print('═══════════════════════════════════════════════════════');
    print('🎉 APK Built & Renamed Successfully!');
    print('═══════════════════════════════════════════════════════');
    print('📂 Filename: $newName');
    print('📂 Location: ${destFile.path}');
    print('═══════════════════════════════════════════════════════');
    print('');
  } else {
    print('❌ Error: Could not locate app-release.apk at ${srcFile.path}');
  }
}
