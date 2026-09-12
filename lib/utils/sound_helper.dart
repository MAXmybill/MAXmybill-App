import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SoundHelper {
  static const MethodChannel _channel = MethodChannel('maxmybill/sound');

  /// Plays a loud, crisp barcode scanner beep.
  static Future<void> playScanBeep() async {
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await _channel.invokeMethod('playBeep');
      } else {
        await SystemSound.play(SystemSoundType.click);
      }
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  /// Plays an error/nack tone for invalid or out-of-stock items.
  static Future<void> playErrorBeep() async {
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await _channel.invokeMethod('playError');
      } else {
        await SystemSound.play(SystemSoundType.alert);
      }
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }
}
