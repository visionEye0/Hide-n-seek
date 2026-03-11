import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class GameSettings extends ChangeNotifier {
  bool _soundEnabled = true;
  int _availableStepBacks = 0;

  bool get soundEnabled => _soundEnabled;
  int get availableStepBacks => _availableStepBacks;

  static const _soundKey = 'game_sound_enabled';
  static const _stepBackKey = 'game_step_backs';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool(_soundKey) ?? true;
    _availableStepBacks = prefs.getInt(_stepBackKey) ?? 0;
    notifyListeners();
  }

  Future<void> toggleSound() async {
    _soundEnabled = !_soundEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundKey, _soundEnabled);
    notifyListeners();
  }

  Future<void> incrementStepBacks() async {
    _availableStepBacks++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_stepBackKey, _availableStepBacks);
    notifyListeners();
  }

  Future<void> decrementStepBacks() async {
    if (_availableStepBacks > 0) {
      _availableStepBacks--;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_stepBackKey, _availableStepBacks);
      notifyListeners();
    }
  }

  Future<void> resetStepBacks() async {
    _availableStepBacks = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_stepBackKey, _availableStepBacks);
    notifyListeners();
  }
}

// Global singleton for game settings
final globalSettings = GameSettings();
