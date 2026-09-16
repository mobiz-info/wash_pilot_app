import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FontSizeOption {
  extraSmall,
  small,
  medium,
  large,
  extraLarge,
}

extension FontSizeOptionExtension on FontSizeOption {
  String get key {
    switch (this) {
      case FontSizeOption.extraSmall:
        return 'extra_small';
      case FontSizeOption.small:
        return 'small';
      case FontSizeOption.medium:
        return 'medium';
      case FontSizeOption.large:
        return 'large';
      case FontSizeOption.extraLarge:
        return 'extra_large';
    }
  }

  String get displayName {
    switch (this) {
      case FontSizeOption.extraSmall:
        return 'Extra Small';
      case FontSizeOption.small:
        return 'Small';
      case FontSizeOption.medium:
        return 'Medium (Default)';
      case FontSizeOption.large:
        return 'Large';
      case FontSizeOption.extraLarge:
        return 'Extra Large';
    }
  }

  double get scaleFactor {
    switch (this) {
      case FontSizeOption.extraSmall:
        return 0.85;
      case FontSizeOption.small:
        return 0.92;
      case FontSizeOption.medium:
        return 1.00;
      case FontSizeOption.large:
        return 1.10;
      case FontSizeOption.extraLarge:
        return 1.22;
    }
  }
}

class FontSizeProvider extends ChangeNotifier {
  static const String _prefKey = 'app_font_size_option';

  FontSizeOption _selectedOption = FontSizeOption.medium;

  FontSizeOption get selectedOption => _selectedOption;
  double get scaleFactor => _selectedOption.scaleFactor;

  FontSizeProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKey = prefs.getString(_prefKey);
      if (savedKey != null) {
        final matched = FontSizeOption.values.firstWhere(
          (e) => e.key == savedKey,
          orElse: () => FontSizeOption.medium,
        );
        _selectedOption = matched;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setFontSize(FontSizeOption option) async {
    if (_selectedOption == option) return;
    _selectedOption = option;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, option.key);
    } catch (_) {}
  }
}
