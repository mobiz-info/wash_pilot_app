import 'dart:io';

void main(List<String> args) async {
  final apps = [
    AppConfig(
        appName: "Wash Pilot",
        iconPath: "assets/icons/Wash-Pilot_Blue-Icon.png",
        packageName: "com.mobiz.washpilot",
        baseUrl: "http://68.183.94.11:78/api"),
    AppConfig(
        appName: "Car Wash",
        iconPath: "assets/icons/mobiz_logo_launcher.png",
        packageName: "com.mobiz.carwash",
        baseUrl: "http://68.183.94.11:78/api"),
  ];

  print('Flutter Android Setup Tool\n');
  print("Available Apps:");
  for (var i = 0; i < apps.length; i++) {
    print('${i + 1}. ${apps[i].appName} → ${apps[i].packageName} → ${apps[i].iconPath}');
  }

  stdout.write("\nEnter your App (1-${apps.length}): ");
  final choice = int.tryParse(stdin.readLineSync() ?? "");
  if (choice == null || choice < 1 || choice > apps.length) {
    print("Invalid choice");
    exit(1);
  }
  final app = apps[choice - 1];

  print('\n⚙️ Running setup for:');
  print('   App Name     : ${app.appName}');
  print('   Package Name : ${app.packageName}');
  print('   Icon Path    : ${app.iconPath}\n');

  await updateGradle(app.packageName);
  await updateManifest(app.appName);
  await updateMainActivity(app.packageName);
  await updateAppIcon(app.appName, app.iconPath);
  await updateBaseUrl(app.baseUrl);
  await updateAppNameAndIcon(app.appName, app.iconPath);
}

Future<void> updateGradle(String packageName) async {
  final gradleFile = File("android/app/build.gradle.kts");
  if (!gradleFile.existsSync()) {
    print('⚠️ build.gradle.kts not found.');
    return;
  }

  var content = gradleFile.readAsStringSync();
  content = content.replaceAllMapped(
      RegExp(r'namespace\s*=\s*"[^"]+"'), (match) => 'namespace = "$packageName"');
  content = content.replaceAllMapped(
      RegExp(r'applicationId\s*=\s*"[^"]+"'), (match) => 'applicationId = "$packageName"');

  gradleFile.writeAsStringSync(content);
  print('✅ Updated build.gradle.kts namespace and applicationId.');
}

Future<void> updateManifest(String appName) async {
  final manifest = File("android/app/src/main/AndroidManifest.xml");
  if (!manifest.existsSync()) {
    print("Manifest not found");
    return;
  }
  var content = manifest.readAsStringSync();
  content = content.replaceAll(
      RegExp(r'android:label="[^"]+"'), 'android:label="$appName"');

  manifest.writeAsStringSync(content);
  print('✅ Updated AndroidManifest label');
}

Future<void> updateMainActivity(String packageName) async {
  final kotlinDir = Directory("android/app/src/main/kotlin");
  if (!kotlinDir.existsSync()) {
    print("Kotlin dir not found");
    return;
  }

  final mainFile = kotlinDir
      .listSync(recursive: true)
      .whereType<File>()
      .firstWhere((e) => e.path.endsWith("MainActivity.kt"),
          orElse: () => File(""));

  if (!mainFile.existsSync()) {
    print("Main activity not found");
    return;
  }

  var content = mainFile.readAsStringSync();
  content =
      content.replaceAll(RegExp(r'package\s+[\w.]+'), 'package $packageName');
  mainFile.writeAsStringSync(content);
  print('✅ Updated MainActivity.kt package name.');
}

Future<void> updateAppIcon(String appName, String iconPath) async {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    print('⚠️ pubspec.yaml not found.');
    return;
  }

  var content = pubspec.readAsStringSync();
  
  String configBlock;
  if (appName == "Car Wash") {
    configBlock = '''flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icons/mobiz_logo_launcher.png"
  adaptive_icon_background: "#000080"
  adaptive_icon_foreground: "assets/icons/mobiz_logo_foreground.png"
  min_sdk_android: 21
  web:
    generate: false
  windows:
    generate: false
  macos:
    generate: false''';
  } else {
    configBlock = '''flutter_launcher_icons:
  android: true
  ios: true
  image_path: "$iconPath"
  min_sdk_android: 21
  web:
    generate: false
  windows:
    generate: false
  macos:
    generate: false''';
  }

  final regex = RegExp(r'flutter_launcher_icons:[\s\S]*');
  if (regex.hasMatch(content)) {
    content = content.replaceFirst(regex, configBlock);
  } else {
    content = content + "\n\n" + configBlock;
  }

  pubspec.writeAsStringSync(content);
  print('✅ Updated launcher icons config in pubspec.yaml');

  print('⚙️ Running flutter_launcher_icons...');
  final result = await Process.run(
      'flutter', ['pub', 'run', 'flutter_launcher_icons:main']);
  if (result.exitCode == 0) {
    print('✅ App icons updated successfully!');
  } else {
    print('❌ Failed to update icons:\n${result.stderr}');
  }
}

Future<void> updateBaseUrl(String baseUrl) async {
  final apiFile = File('lib/services/api_service.dart');
  if (!apiFile.existsSync()) {
    print('⚠️ lib/services/api_service.dart not found.');
    return;
  }

  var content = apiFile.readAsStringSync();
  final regex = RegExp(r'static\s+const\s+String\s+baseUrl\s*=\s*"[^"]*";');
  if (regex.hasMatch(content)) {
    content = content.replaceAll(regex, 'static const String baseUrl = "$baseUrl";');
    apiFile.writeAsStringSync(content);
    print('✅ Updated baseUrl in lib/services/api_service.dart → $baseUrl');
  } else {
    print('⚠️ Could not find baseUrl declaration in lib/services/api_service.dart');
  }
}

Future<void> updateAppNameAndIcon(String appName, String appIconPath) async {
  final apiFile = File('lib/services/api_service.dart');
  if (!apiFile.existsSync()) {
    print('⚠️ lib/services/api_service.dart not found.');
    return;
  }

  var content = apiFile.readAsStringSync();
  final nameRegex = RegExp(r'static\s+const\s+String\s+appName\s*=\s*"[^"]*";');
  if (nameRegex.hasMatch(content)) {
    content = content.replaceAll(nameRegex, 'static const String appName = "$appName";');
    print('✅ Updated appName in lib/services/api_service.dart → $appName');
  } else {
    print('⚠️ Could not find appName declaration in lib/services/api_service.dart');
  }

  final iconRegex = RegExp(r'static\s+const\s+String\s+appIconPath\s*=\s*"[^"]*";');
  if (iconRegex.hasMatch(content)) {
    content = content.replaceAll(iconRegex, 'static const String appIconPath = "$appIconPath";');
    print('✅ Updated appIconPath in lib/services/api_service.dart → $appIconPath');
  } else {
    print('⚠️ Could not find appIconPath declaration in lib/services/api_service.dart');
  }

  apiFile.writeAsStringSync(content);
}

class AppConfig {
  final String appName;
  final String packageName;
  final String iconPath;
  final String baseUrl;
  AppConfig({
    required this.appName,
    required this.iconPath,
    required this.packageName,
    required this.baseUrl,
  });
}
