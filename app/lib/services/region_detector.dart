import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/services.dart';

/// Finds the country the phone is in, so currency, distance unit and mileage
/// rate can follow the user. Uses the mobile network / SIM country (Android,
/// via MainActivity) and falls back to the device region setting. It needs no
/// location permission and sends nothing off the device.
class RegionDetector {
  const RegionDetector();

  static const _channel = MethodChannel('mileworth/region');

  /// Upper-case ISO 3166-1 alpha-2 code, or null when nothing is known.
  Future<String?> detectCountry() async {
    if (Platform.isAndroid) {
      try {
        final code = await _channel.invokeMethod<String>('countryCode');
        if (code != null && code.length == 2) return code.toUpperCase();
      } on PlatformException {
        // fall through to the locale
      } on MissingPluginException {
        // fall through to the locale
      }
    }
    final code = PlatformDispatcher.instance.locale.countryCode;
    return (code != null && code.length == 2) ? code.toUpperCase() : null;
  }
}
