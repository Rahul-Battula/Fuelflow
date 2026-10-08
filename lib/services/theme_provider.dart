import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device storage for small preferences. Loaded once in `main()` before the
/// app starts and injected via a ProviderScope override; null if loading
/// failed, in which case the theme simply isn't remembered.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

const _themeModeKey = 'theme_mode';

/// Holds the user's manually selected theme mode (defaults to system) and
/// remembers it on the device across app restarts.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final saved = ref.read(sharedPreferencesProvider)?.getString(_themeModeKey);
    return ThemeMode.values.where((m) => m.name == saved).firstOrNull ?? ThemeMode.system;
  }

  void setMode(ThemeMode mode) {
    state = mode;
    // Best-effort: the theme still changes for this session if saving fails.
    ref.read(sharedPreferencesProvider)?.setString(_themeModeKey, mode.name).catchError((_) => false);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
