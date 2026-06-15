/// Google Maps API key configuration.
///
/// Set the same key in each platform:
/// - **Android:** `android/local.properties` → `google.maps.api.key=YOUR_KEY`
/// - **iOS:** `ios/Runner/Info.plist` → `GoogleMapsApiKey`
/// - **Web:** `web/index.html` Maps JavaScript script `key=` parameter
/// - **Optional:** `--dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY` (used for web fallback checks)
abstract final class MapsConstants {
  static const String apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  static bool get isConfigured => apiKey.isNotEmpty;
}
