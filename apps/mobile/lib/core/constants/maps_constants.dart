/// Google Maps API key configuration.
///
/// Run [scripts/setup-google-maps.sh] to write the key to Android, iOS, and web.
/// Optional dart-define: `--dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY`
abstract final class MapsConstants {
  static const String apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  static bool get isConfigured => apiKey.isNotEmpty;
}
