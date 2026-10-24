import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where settings are kept. Replaceable in tests.
abstract interface class SettingsStore {
  Future<bool?> getBool(String key);
  Future<void> setBool(String key, bool value);
}

class PrefsSettingsStore implements SettingsStore {
  const PrefsSettingsStore();

  @override
  Future<bool?> getBool(String key) => SharedPreferencesAsync().getBool(key);

  @override
  Future<void> setBool(String key, bool value) =>
      SharedPreferencesAsync().setBool(key, value);
}

/// Settings on this phone (Me → Settings). Distances are always in km.
class AppSettings extends ChangeNotifier {
  AppSettings([this._store = const PrefsSettingsStore()]);

  final SettingsStore _store;

  static const _voiceKey = 'settings.voice_prompts';
  static const _safetyKey = 'settings.first_ride_safety_seen';

  bool _voicePrompts = true;
  bool _firstRideSafetySeen = false;

  /// The safety reminders were shown before a first ride (once per phone).
  bool get firstRideSafetySeen => _firstRideSafetySeen;

  /// Spoken ride alerts (main stop, off the loop, back home). On by
  /// default: riders shouldn't look at the phone while moving.
  bool get voicePrompts => _voicePrompts;

  /// Reads the saved settings; keeps the defaults if that fails.
  Future<void> load() async {
    try {
      _voicePrompts = await _store.getBool(_voiceKey) ?? true;
      _firstRideSafetySeen = await _store.getBool(_safetyKey) ?? false;
      notifyListeners();
    } on Exception catch (e) {
      debugPrint('settings: load failed: $e');
    }
  }

  Future<void> setVoicePrompts(bool on) async {
    if (_voicePrompts == on) return;
    _voicePrompts = on;
    notifyListeners();
    await _store.setBool(_voiceKey, on);
  }

  Future<void> setFirstRideSafetySeen() async {
    if (_firstRideSafetySeen) return;
    _firstRideSafetySeen = true;
    notifyListeners();
    await _store.setBool(_safetyKey, true);
  }
}
