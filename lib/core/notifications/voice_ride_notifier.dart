import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../settings/app_settings.dart';
import 'ride_notifier.dart';

/// Says a short sentence out loud.
abstract interface class Speaker {
  Future<void> speak(String text);
}

class TtsSpeaker implements Speaker {
  TtsSpeaker([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _ready = false;

  @override
  Future<void> speak(String text) async {
    try {
      if (!_ready) {
        await _tts.setLanguage('en-US');
        await _tts.setSpeechRate(0.5);
        // Lower Google Maps' voice and music while speaking, not stop them.
        await _tts.setAudioAttributesForNavigation();
        _ready = true;
      }
      await _tts.speak(text);
    } on Exception catch (e) {
      debugPrint('voice: speak failed: $e');
    }
  }
}

/// Ride alerts as notifications, also spoken when Settings → Voice prompts
/// is on, so riders don't have to look at the phone.
class VoiceRideNotifier implements RideNotifier {
  VoiceRideNotifier(
    this._inner, {
    required this.settings,
    required this.speaker,
  });

  final RideNotifier _inner;
  final AppSettings settings;
  final Speaker speaker;

  Future<void> _say(String text) async {
    if (settings.voicePrompts) await speaker.speak(text);
  }

  @override
  Future<void> prepare() => _inner.prepare();

  @override
  Future<void> arrivedAtStop(String stopName) async {
    await _inner.arrivedAtStop(stopName);
    await _say('You made it to $stopName. Pull over safely to take photos.');
  }

  @override
  Future<void> leftLoop() async {
    await _inner.leftLoop();
    await _say("You've left the loop.");
  }

  @override
  Future<void> backOnLoop() => _inner.backOnLoop();

  @override
  Future<void> backHome() async {
    await _inner.backHome();
    await _say("You're back home. Tap finish ride to save your loop.");
  }

  @override
  Future<void> rideFinished(String summary) async {
    await _inner.rideFinished(summary);
    await _say('Loop done. Nice ride!');
  }

  @override
  Future<void> clearAlerts() => _inner.clearAlerts();
}
